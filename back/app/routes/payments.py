from flask import Blueprint, request, jsonify, current_app
from app import db
from app.models import User, PaymentLink, Order, CartItem, PotPlant, PotPrice, PotColor, PotSize, PotMaterial, OrderItem
from datetime import datetime, timedelta
import uuid
import os
from dotenv import load_dotenv
from yookassa import Configuration, Payment

# Загружаем переменные окружения из .env
load_dotenv()

bp = Blueprint('payments', __name__, url_prefix='/api/payments')

# ---------- Инициализация Yookassa (единая функция) ----------
def init_yookassa():
    """Инициализация клиента Yookassa. Возвращает True если успешно."""
    shop_id = os.environ.get('YOOKASSA_SHOP_ID')
    api_key = os.environ.get('YOOKASSA_API_KEY')
    if not shop_id or not api_key:
        current_app.logger.warning("Yookassa credentials not configured")
        return False
    try:
        Configuration.account_id = shop_id
        Configuration.secret_key = api_key
        current_app.logger.info("Yookassa configured")
        return True
    except Exception as e:
        current_app.logger.error(f"Failed to configure Yookassa: {str(e)}")
        return False

# ---------- Помощники ----------
def get_user_by_session(session_token):
    """получить пользователя по session_token"""
    if not session_token:
        return None
    clean_token = session_token.strip('"\' ')
    user = User.query.filter_by(session_token=clean_token).first()
    if user and user.token_expires_at and user.token_expires_at < datetime.utcnow():
        return None
    return user

def validate_cart_items(cart_items):
    """
    Валидация товаров в корзине:
    - Проверяет наличие товара в БД
    - Проверяет цены
    - Проверяет доступное количество
    Возвращает (is_valid, error_message, total_price)
    """
    if not cart_items:
        return False, 'Корзина пуста', 0.0

    total_price = 0.0

    for item in cart_items:
        plant = PotPlant.query.get(item.plant_id)
        if not plant:
            return False, f'Растение ID {item.plant_id} не найдено', 0.0

        if not plant.in_stock or plant.stock_quantity <= 0:
            return False, f'Растение "{plant.name}" больше не в наличии', 0.0

        if item.quantity > plant.stock_quantity:
            return False, f'Недостаточно "{plant.name}" в наличии. Доступно: {plant.stock_quantity}, запрошено: {item.quantity}', 0.0

        # сравниваем цены как строки/числа - предположим что оба NUMERIC
        if float(item.plant_unit_price) != float(plant.base_price):
            return False, f'Цена растения "{plant.name}" изменилась. Пожалуйста, обновите корзину', 0.0

        pot_price = 0.0
        if item.pot_size_id and item.pot_material_id:
            pot_price_obj = PotPrice.query.filter_by(
                material_id=item.pot_material_id,
                size_id=item.pot_size_id
            ).first()
            if not pot_price_obj:
                return False, 'Выбранный горшок больше не доступен', 0.0
            if float(item.pot_unit_price) != float(pot_price_obj.price):
                return False, 'Цена горшка изменилась. Пожалуйста, обновите корзину', 0.0
            pot_price = float(pot_price_obj.price)
        else:
            if float(item.pot_unit_price) != 0.0:
                return False, 'Некорректные данные о горшке', 0.0

        item_total = (float(item.plant_unit_price) + float(item.pot_unit_price)) * int(item.quantity)
        total_price += item_total

    return True, None, round(total_price, 2)

def sync_payment_link_with_yookassa(payment_link):
    """
    Попытка синхронизировать статус payment_link с Yookassa.
    Возвращает обновлённый payment_link (или None при ошибке).
    """
    if not payment_link or not payment_link.payment_system_id:
        return payment_link

    if not init_yookassa():
        current_app.logger.warning("Yookassa not initialized for sync")
        return payment_link

    try:
        payment = Payment.find_one(str(payment_link.payment_system_id))
    except Exception as e:
        current_app.logger.error(f"Yookassa: failed to find payment {payment_link.payment_system_id}: {e}")
        return payment_link

    # возможные статусы Yookassa: 'succeeded', 'canceled', 'pending', 'waiting_for_capture', 'refunded', 'expired' и т.д.
    y_status = getattr(payment, 'status', None)
    if y_status == 'succeeded' and payment_link.status != 'paid':
        payment_link.status = 'paid'
        payment_link.payment_confirmed_at = datetime.utcnow()
        if payment_link.order_id:
            order = Order.query.get(payment_link.order_id)
            if order:
                order.status = 'processing'
                order.is_paid = True
    elif y_status == 'canceled' and payment_link.status != 'cancelled':
        payment_link.status = 'cancelled'
        if payment_link.order_id:
            order = Order.query.get(payment_link.order_id)
            if order and order.status != 'delivered':
                order.status = 'cancelled'
    elif y_status == 'expired' and payment_link.status != 'expired':
        payment_link.status = 'expired'
    # другие правила можно добавить при необходимости

    try:
        db.session.commit()
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Failed to commit sync changes: {e}")

    return payment_link

def format_payment_link_response(payment_link):
    """Сформировать словарь-ответ для payment_link (без зависимости от модели .to_dict())."""
    if not payment_link:
        return None
    return {
        'id': payment_link.id,
        'user_id': payment_link.user_id,
        'order_id': payment_link.order_id,
        'amount': float(payment_link.amount) if payment_link.amount is not None else None,
        'payment_url': payment_link.payment_url,
        'status': payment_link.status,
        'payment_system_id': payment_link.payment_system_id,
        'created_at': payment_link.created_at.isoformat() if payment_link.created_at else None,
        'expires_at': payment_link.expires_at.isoformat() if payment_link.expires_at else None,
        'payment_confirmed_at': payment_link.payment_confirmed_at.isoformat() if payment_link.payment_confirmed_at else None,
    }

# ---------- Эндпоинты ----------
@bp.route('/generate-link', methods=['POST'])
def generate_payment_link():
    try:
        session_id = request.headers.get('X-Session-Id')
        if not session_id:
            return jsonify({'success': False, 'error': 'X-Session-Id header required'}), 401

        user = get_user_by_session(session_id)
        if not user:
            return jsonify({'success': False, 'error': 'Invalid or expired session ID'}), 401

        data = request.get_json() or {}
        address = data.get('address', '').strip()
        payment_method = data.get('payment_method', 'card')

        if not address:
            return jsonify({'success': False, 'error': 'Delivery address is required'}), 400
        if len(address) < 5 or len(address) > 500:
            return jsonify({'success': False, 'error': 'Address must be between 5 and 500 characters'}), 400
        if payment_method not in ['cash', 'card']:
            return jsonify({'success': False, 'error': 'Invalid payment method. Must be "cash" or "card"'}), 400

        cart_items = CartItem.query.filter_by(user_id=user.id).all()
        is_valid, error_message, total_price = validate_cart_items(cart_items)
        if not is_valid:
            return jsonify({'success': False, 'error': error_message}), 400

        order = Order(
            user_id=user.id,
            address=address,
            total_price=total_price,
            payment_method=payment_method,
            status='new',
            order_date=datetime.utcnow()
        )
        db.session.add(order)
        db.session.flush()

        for cart_item in cart_items:
            order_item = OrderItem(
                order_id=order.id,
                plant_id=cart_item.plant_id,
                quantity=cart_item.quantity,
                plant_unit_price=cart_item.plant_unit_price,
                pot_color=None,
                pot_size=None,
                pot_material=None,
                pot_unit_price=cart_item.pot_unit_price,
                total_price=cart_item.total_price
            )
            if cart_item.pot_color_id:
                pot_color = PotColor.query.get(cart_item.pot_color_id)
                if pot_color:
                    order_item.pot_color = pot_color.name
            if cart_item.pot_size_id:
                pot_size = PotSize.query.get(cart_item.pot_size_id)
                if pot_size:
                    order_item.pot_size = pot_size.code
            if cart_item.pot_material_id:
                pot_material = PotMaterial.query.get(cart_item.pot_material_id)
                if pot_material:
                    order_item.pot_material = pot_material.name
            db.session.add(order_item)

        # Создаём платёж в Yookassa (с копейками)
        if not init_yookassa():
            current_app.logger.error("Yookassa not initialized")
            db.session.rollback()
            return jsonify({'success': False, 'error': 'Payment gateway not configured'}), 500

        try:
            amount_str = "{:.2f}".format(float(total_price))
            payment = Payment.create({
                "amount": {"value": amount_str, "currency": "RUB"},
                "confirmation": {
                    "type": "redirect",
                    "return_url": f"{os.environ.get('API_BASE_URL', 'http://localhost:5000')}/api/payments/callback"
                },
                "capture": True,
                "description": f"Заказ растений. Товаров: {len(cart_items)} шт. ID заказа: #{order.id}",
                "metadata": {"order_id": order.id, "user_id": user.id, "items_count": len(cart_items)}
            }, uuid.uuid4())
            payment_url = payment.confirmation.confirmation_url
            payment_system_id = str(payment.id)
        except Exception as e:
            current_app.logger.error(f"Yookassa payment creation error: {str(e)}")
            db.session.rollback()
            return jsonify({'success': False, 'error': f'Payment gateway error: {str(e)}'}), 500

        expires_at = datetime.utcnow() + timedelta(hours=24)
        payment_link = PaymentLink(
            user_id=user.id,
            order_id=order.id,
            amount=total_price,
            payment_url=payment_url,
            status='pending',
            expires_at=expires_at,
            payment_system_id=payment_system_id
        )
        db.session.add(payment_link)

        # очищаем корзину
        CartItem.query.filter_by(user_id=user.id).delete()
        db.session.commit()

        items_list = []
        for cart_item in cart_items:
            plant = PotPlant.query.get(cart_item.plant_id)
            items_list.append({
                'plant_id': cart_item.plant_id,
                'plant_name': plant.name if plant else 'Unknown',
                'quantity': cart_item.quantity,
                'plant_price': float(cart_item.plant_unit_price),
                'pot_price': float(cart_item.pot_unit_price),
                'item_total': float(cart_item.total_price)
            })

        return jsonify({
            'success': True,
            'data': {
                'payment_link_id': payment_link.id,
                'order_id': order.id,
                'payment_url': payment_link.payment_url,
                'amount': float(total_price),
                'currency': 'RUB',
                'expires_at': payment_link.expires_at.isoformat(),
                'items_count': len(cart_items),
                'items': items_list,
                'address': address,
                'payment_method': payment_method,
                'message': 'Оплатите заказ по ссылке выше. После успешной оплаты заказ будет обработан.'
            }
        }), 201

    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Error generating payment link: {str(e)}")
        return jsonify({'success': False, 'error': 'Internal server error', 'debug': str(e) if current_app.debug else None}), 500

@bp.route('/link/<int:link_id>', methods=['GET'])
def get_payment_link(link_id):
    try:
        session_id = request.headers.get('X-Session-Id')
        if not session_id:
            return jsonify({'success': False, 'error': 'X-Session-Id header required'}), 401
        user = get_user_by_session(session_id)
        if not user:
            return jsonify({'success': False, 'error': 'Invalid or expired session ID'}), 401

        payment_link = PaymentLink.query.get(link_id)
        if not payment_link:
            return jsonify({'success': False, 'error': 'Payment link not found'}), 404
        if payment_link.user_id != user.id:
            return jsonify({'success': False, 'error': 'Access denied'}), 403

        # автоматическое помечание expired если просрочена
        if payment_link.expires_at and payment_link.expires_at < datetime.utcnow() and payment_link.status == 'pending':
            payment_link.status = 'expired'
            db.session.commit()

        return jsonify({'success': True, 'data': format_payment_link_response(payment_link)}), 200

    except Exception as e:
        current_app.logger.error(f"Error getting payment link: {str(e)}")
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@bp.route('/link/<int:link_id>/cancel', methods=['POST'])
def cancel_payment_link(link_id):
    try:
        session_id = request.headers.get('X-Session-Id')
        if not session_id:
            return jsonify({'success': False, 'error': 'X-Session-Id header required'}), 401
        user = get_user_by_session(session_id)
        if not user:
            return jsonify({'success': False, 'error': 'Invalid or expired session ID'}), 401

        payment_link = PaymentLink.query.get(link_id)
        if not payment_link:
            return jsonify({'success': False, 'error': 'Payment link not found'}), 404
        if payment_link.user_id != user.id:
            return jsonify({'success': False, 'error': 'Access denied'}), 403
        if payment_link.status in ['paid', 'expired', 'cancelled']:
            return jsonify({'success': False, 'error': f'Cannot cancel payment link with status: {payment_link.status}'}), 400

        payment_link.status = 'cancelled'
        if payment_link.order_id:
            order = Order.query.get(payment_link.order_id)
            if order and order.status in ['new', 'processing']:
                order.status = 'cancelled'
        db.session.commit()
        return jsonify({'success': True, 'message': 'Payment link cancelled successfully'}), 200

    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Error cancelling payment link: {str(e)}")
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

# ---------- Webhook от Yookassa ----------
@bp.route('/callback', methods=['POST'])
def payment_callback():
    try:
        init_yookassa()
        data = request.get_json()
        if not data or 'object' not in data:
            return jsonify({'success': False}), 400

        payment_data = data.get('object', {})
        payment_id = payment_data.get('id')
        status = payment_data.get('status')

        payment_link = PaymentLink.query.filter_by(payment_system_id=payment_id).first()
        if not payment_link:
            current_app.logger.warning(f"Payment link not found for payment_id: {payment_id}")
            return jsonify({'success': False}), 404

        if status == 'succeeded':
            payment_link.status = 'paid'
            payment_link.payment_confirmed_at = datetime.utcnow()
            if payment_link.order_id:
                order = Order.query.get(payment_link.order_id)
                if order:
                    order.status = 'processing'
                    order.is_paid = True
            current_app.logger.info(f"Payment {payment_id} confirmed")
        elif status == 'canceled':
            payment_link.status = 'cancelled'
            if payment_link.order_id:
                order = Order.query.get(payment_link.order_id)
                if order and order.status != 'delivered':
                    order.status = 'cancelled'
            current_app.logger.info(f"Payment {payment_id} cancelled")
        elif status == 'expired':
            payment_link.status = 'expired'
            current_app.logger.info(f"Payment {payment_id} expired")

        db.session.commit()
        return jsonify({'success': True}), 200

    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Error processing payment callback: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500

# ---------- Внутренняя проверка статуса по payment_id ----------
@bp.route('/status/<payment_id>', methods=['GET'])
def check_payment_status(payment_id):
    try:
        if not init_yookassa():
            current_app.logger.warning("Yookassa not initialized for status check")
        try:
            payment = Payment.find_one(str(payment_id))
        except Exception as e:
            current_app.logger.error(f"Yookassa find_one error: {e}")
            payment = None

        payment_link = PaymentLink.query.filter_by(payment_system_id=str(payment_id)).first()
        if not payment_link:
            return jsonify({'success': False, 'error': 'Payment not found'}), 404

        if payment:
            # sync local link with received Yookassa payment status
            sync_payment_link_with_yookassa(payment_link)

        return jsonify({
            'success': True,
            'data': {
                'payment_id': payment_id,
                'status': payment_link.status,
                'yookassa_status': getattr(payment, 'status', None) if payment else None,
                'amount': float(payment_link.amount),
                'confirmed_at': payment_link.payment_confirmed_at.isoformat() if payment_link.payment_confirmed_at else None
            }
        }), 200

    except Exception as e:
        current_app.logger.error(f"Error checking payment status: {str(e)}")
        return jsonify({'success': False, 'error': 'Payment gateway error'}), 500

# ---------- Пользовательские эндпоинты для проверки статуса ----------
@bp.route('/status/link/<int:link_id>', methods=['GET'])
def user_check_payment_link_status(link_id):
    """
    Пользовательская проверка статуса ссылки (требует X-Session-Id).
    Синхронизирует статус с Yookassa при наличии payment_system_id.
    """
    try:
        session_id = request.headers.get('X-Session-Id')
        if not session_id:
            return jsonify({'success': False, 'error': 'X-Session-Id header required'}), 401
        user = get_user_by_session(session_id)
        if not user:
            return jsonify({'success': False, 'error': 'Invalid or expired session ID'}), 401

        payment_link = PaymentLink.query.get(link_id)
        if not payment_link:
            return jsonify({'success': False, 'error': 'Payment link not found'}), 404
        if payment_link.user_id != user.id:
            return jsonify({'success': False, 'error': 'Access denied'}), 403

        # проверка на истечение
        if payment_link.expires_at and payment_link.expires_at < datetime.utcnow() and payment_link.status == 'pending':
            payment_link.status = 'expired'
            db.session.commit()
            return jsonify({'success': True, 'data': format_payment_link_response(payment_link)}), 200

        # синхронизируем с Yookassa если есть id платежной системы
        if payment_link.payment_system_id:
            sync_payment_link_with_yookassa(payment_link)

        return jsonify({'success': True, 'data': format_payment_link_response(payment_link)}), 200

    except Exception as e:
        current_app.logger.error(f"Error in user_check_payment_link_status: {e}")
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@bp.route('/status/order/<int:order_id>', methods=['GET'])
def user_check_order_status(order_id):
    """
    Пользовательская проверка статуса заказа (требует X-Session-Id).
    Возвращает статус заказа и связанную ссылку на оплату (если есть).
    """
    try:
        session_id = request.headers.get('X-Session-Id')
        if not session_id:
            return jsonify({'success': False, 'error': 'X-Session-Id header required'}), 401
        user = get_user_by_session(session_id)
        if not user:
            return jsonify({'success': False, 'error': 'Invalid or expired session ID'}), 401

        order = Order.query.get(order_id)
        if not order:
            return jsonify({'success': False, 'error': 'Order not found'}), 404
        if order.user_id != user.id:
            return jsonify({'success': False, 'error': 'Access denied'}), 403

        # Найдём связанную ссылку на оплату (если есть)
        payment_link = PaymentLink.query.filter_by(order_id=order.id).first()
        if payment_link and payment_link.payment_system_id:
            sync_payment_link_with_yookassa(payment_link)

        resp = {
            'order_id': order.id,
            'order_status': order.status,
            'is_paid': bool(order.is_paid),
            'total_price': float(order.total_price),
            'payment_link': format_payment_link_response(payment_link) if payment_link else None
        }
        return jsonify({'success': True, 'data': resp}), 200

    except Exception as e:
        current_app.logger.error(f"Error in user_check_order_status: {e}")
        return jsonify({'success': False, 'error': 'Internal server error'}), 500