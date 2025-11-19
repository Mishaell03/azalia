from flask import Blueprint, request, jsonify
from app import db
from app.models import CartItem, WishlistItem, User, PotPlant, PotPrice
from datetime import datetime
import re

bp = Blueprint('cart', __name__, url_prefix='/api/cart')

def safe_int(value, default=None, min_val=None, max_val=None):
    """преобразование в int с валидацией"""
    if value is None:
        return default
    try:
        result = int(value)
        if min_val is not None and result < min_val:
            return default
        if max_val is not None and result > max_val:
            return default
        return result
    except (ValueError, TypeError):
        return default

def get_user_by_session(session_token):
    """получить пользователя по session_token"""
    if not session_token:
        return None
    clean_token = session_token.strip('"\' ')
    return User.query.filter_by(session_token=clean_token).first()

# КОРЗИНА 

@bp.route('/items', methods=['GET'])
def get_cart_items():
    """получить все товары в корзине пользователя"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return jsonify({'success': False, 'error': 'Authorization header required'}), 401
        
        user = get_user_by_session(auth_header)
        if not user:
            return jsonify({'success': False, 'error': 'Invalid session token'}), 401

        cart_items = CartItem.query.filter_by(user_id=user.id).all()
        
        total_items = sum(item.quantity for item in cart_items)
        total_price = sum(item.total_price for item in cart_items)
        
        return jsonify({
            'success': True,
            'data': {
                'items': [item.to_dict() for item in cart_items],
                'summary': {
                    'total_items': total_items,
                    'total_price': float(total_price),
                    'items_count': len(cart_items)
                }
            }
        })
    
    except Exception as e:
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@bp.route('/items', methods=['POST'])
def add_to_cart():
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return jsonify({'success': False, 'error': 'Authorization header required'}), 401
        
        user = get_user_by_session(auth_header)
        if not user:
            return jsonify({'success': False, 'error': 'Invalid session token'}), 401

        data = request.get_json()
        if not data:
            return jsonify({'success': False, 'error': 'No data provided'}), 400
        
        plant_id = safe_int(data.get('plant_id'), min_val=1)
        if not plant_id:
            return jsonify({'success': False, 'error': 'Invalid plant ID'}), 400
        
        quantity = safe_int(data.get('quantity', 1), min_val=1, max_val=100)

        plant = PotPlant.query.get(plant_id)
        if not plant:
            return jsonify({'success': False, 'error': 'Plant not found'}), 404
        
        if not plant.in_stock:
            return jsonify({'success': False, 'error': 'Plant is out of stock'}), 400

        existing_item = CartItem.query.filter_by(
            user_id=user.id,
            plant_id=plant_id,
            pot_color=data.get('pot_color'),
            pot_size=data.get('pot_size'),
            pot_material=data.get('pot_material')
        ).first()
        
        # Проверяем доступное количество
        requested_quantity = quantity
        if existing_item:
            requested_quantity += existing_item.quantity
        
        if requested_quantity > plant.stock_quantity:
            return jsonify({
                'success': False, 
                'error': f'Недостаточно товара в наличии. Доступно: {plant.stock_quantity}'
            }), 400
        
        pot_color = data.get('pot_color')
        pot_size = data.get('pot_size')
        pot_material = data.get('pot_material')
        
        pot_unit_price = 0
        if pot_size and pot_material:
            pot_price = PotPrice.query.filter_by(size=pot_size, material=pot_material).first()
            if pot_price:
                pot_unit_price = float(pot_price.price)
        
        if existing_item:
            existing_item.quantity += quantity
            existing_item.total_price = (existing_item.plant_unit_price + existing_item.pot_unit_price) * existing_item.quantity
            db.session.commit()
            return jsonify({
                'success': True,
                'message': 'Количество товара обновлено в корзине',
                'data': existing_item.to_dict()
            }), 200
        else:
            cart_item = CartItem(
                user_id=user.id,
                plant_id=plant_id,
                quantity=quantity,
                pot_color=pot_color,
                pot_size=pot_size,
                pot_material=pot_material,
                plant_unit_price=plant.base_price,
                pot_unit_price=pot_unit_price,
                total_price=(plant.base_price + pot_unit_price) * quantity
            )
            db.session.add(cart_item)
            db.session.commit()
            
            return jsonify({
                'success': True,
                'message': 'Товар добавлен в корзину',
                'data': cart_item.to_dict()
            }), 201
    
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@bp.route('/items/<int:item_id>', methods=['PUT'])
def update_cart_item(item_id):
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return jsonify({'success': False, 'error': 'Authorization header required'}), 401
        
        user = get_user_by_session(auth_header)
        if not user:
            return jsonify({'success': False, 'error': 'Invalid session token'}), 401

        item_id = safe_int(item_id, min_val=1)
        if not item_id:
            return jsonify({'success': False, 'error': 'Invalid item ID'}), 400
        
        cart_item = CartItem.query.filter_by(id=item_id, user_id=user.id).first()
        if not cart_item:
            return jsonify({'success': False, 'error': 'Cart item not found'}), 404
        
        data = request.get_json()
        if not data:
            return jsonify({'success': False, 'error': 'No data provided'}), 400
        
        quantity = safe_int(data.get('quantity'), min_val=0, max_val=100)
        if quantity is None:
            return jsonify({'success': False, 'error': 'Invalid quantity'}), 400
        
        # проверяем доступное количество при обновлении
        if quantity > 0:
            plant = PotPlant.query.get(cart_item.plant_id)
            if quantity > plant.stock_quantity:
                return jsonify({
                    'success': False, 
                    'error': f'Недостаточно товара в наличии. Доступно: {plant.stock_quantity}'
                }), 400
        
        if quantity == 0:
            db.session.delete(cart_item)
            db.session.commit()
            return jsonify({
                'success': True,
                'message': 'Товар удален из корзины',
                'data': None
            })
        
        cart_item.quantity = quantity
        cart_item.total_price = (cart_item.plant_unit_price + cart_item.pot_unit_price) * quantity
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Корзина обновлена',
            'data': cart_item.to_dict()
        })
    
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@bp.route('/items/<int:item_id>', methods=['DELETE'])
def remove_from_cart(item_id):
    """удалить товар из корзины"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return jsonify({'success': False, 'error': 'Authorization header required'}), 401
        
        user = get_user_by_session(auth_header)
        if not user:
            return jsonify({'success': False, 'error': 'Invalid session token'}), 401

        item_id = safe_int(item_id, min_val=1)
        if not item_id:
            return jsonify({'success': False, 'error': 'Invalid item ID'}), 400
        
        cart_item = CartItem.query.filter_by(id=item_id, user_id=user.id).first()
        if not cart_item:
            return jsonify({'success': False, 'error': 'Cart item not found'}), 404
        
        db.session.delete(cart_item)
        db.session.commit()
        
        return jsonify({'success': True, 'message': 'Товар удален из корзины'})
    
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@bp.route('/clear', methods=['DELETE'])
def clear_cart():
    """очистить всю корзину"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return jsonify({'success': False, 'error': 'Authorization header required'}), 401
        
        user = get_user_by_session(auth_header)
        if not user:
            return jsonify({'success': False, 'error': 'Invalid session token'}), 401

        CartItem.query.filter_by(user_id=user.id).delete()
        db.session.commit()
        
        return jsonify({'success': True, 'message': 'Корзина очищена'})
    
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

# ИЗБРАННОЕ

@bp.route('/wishlist', methods=['GET'])
def get_wishlist():
    """Получить избранное пользователя"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return jsonify({'success': False, 'error': 'Authorization header required'}), 401
        
        user = get_user_by_session(auth_header)
        if not user:
            return jsonify({'success': False, 'error': 'Invalid session token'}), 401

        wishlist_items = WishlistItem.query.filter_by(user_id=user.id).all()
        
        return jsonify({
            'success': True,
            'data': {
                'items': [item.to_dict() for item in wishlist_items],
                'count': len(wishlist_items)
            }
        })
    
    except Exception as e:
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@bp.route('/wishlist', methods=['POST'])
def add_to_wishlist():
    """добавить товар в избранное"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return jsonify({'success': False, 'error': 'Authorization header required'}), 401
        
        user = get_user_by_session(auth_header)
        if not user:
            return jsonify({'success': False, 'error': 'Invalid session token'}), 401

        data = request.get_json()
        if not data:
            return jsonify({'success': False, 'error': 'No data provided'}), 400
        
        plant_id = safe_int(data.get('plant_id'), min_val=1)
        if not plant_id:
            return jsonify({'success': False, 'error': 'Invalid plant ID'}), 400
        
        # проверяем существование растения
        plant = PotPlant.query.get(plant_id)
        if not plant:
            return jsonify({'success': False, 'error': 'Plant not found'}), 404
        
        # проверяем, есть ли уже в избранном
        existing_item = WishlistItem.query.filter_by(user_id=user.id, plant_id=plant_id).first()
        if existing_item:
            return jsonify({'success': False, 'error': 'Товар уже в избранном'}), 400
        
        wishlist_item = WishlistItem(user_id=user.id, plant_id=plant_id)
        db.session.add(wishlist_item)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Товар добавлен в избранное',
            'data': wishlist_item.to_dict()
        }), 201
    
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@bp.route('/wishlist/<int:plant_id>', methods=['DELETE'])
def remove_from_wishlist(plant_id):
    """удалить товар из избранного"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return jsonify({'success': False, 'error': 'Authorization header required'}), 401
        
        user = get_user_by_session(auth_header)
        if not user:
            return jsonify({'success': False, 'error': 'Invalid session token'}), 401

        plant_id = safe_int(plant_id, min_val=1)
        if not plant_id:
            return jsonify({'success': False, 'error': 'Invalid plant ID'}), 400
        
        wishlist_item = WishlistItem.query.filter_by(user_id=user.id, plant_id=plant_id).first()
        if not wishlist_item:
            return jsonify({'success': False, 'error': 'Wishlist item not found'}), 404
        
        db.session.delete(wishlist_item)
        db.session.commit()
        
        return jsonify({'success': True, 'message': 'Товар удален из избранного'})
    
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@bp.route('/wishlist/check/<int:plant_id>', methods=['GET'])
def check_wishlist(plant_id):
    """проверить, есть ли товар в избранном"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return jsonify({'success': False, 'error': 'Authorization header required'}), 401
        
        user = get_user_by_session(auth_header)
        if not user:
            return jsonify({'success': False, 'error': 'Invalid session token'}), 401

        plant_id = safe_int(plant_id, min_val=1)
        if not plant_id:
            return jsonify({'success': False, 'error': 'Invalid plant ID'}), 400
        
        exists = WishlistItem.query.filter_by(user_id=user.id, plant_id=plant_id).first() is not None
        
        return jsonify({
            'success': True,
            'data': {'in_wishlist': exists}
        })
    
    except Exception as e:
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@bp.route('/pot/price', methods=['GET'])
def get_pot_price():
    """получить цену горшка по материалу и размеру"""
    try:
        material = request.args.get('material')
        size = request.args.get('size')
        
        if not material or not size:
            return jsonify({'success': False, 'error': 'Material and size parameters required'}), 400
        
        pot_price = PotPrice.query.join(PotMaterial).join(PotSize)\
            .filter(PotMaterial.name == material, PotSize.code == size)\
            .first()
        
        if not pot_price:
            return jsonify({'success': False, 'error': 'Price not found'}), 404
        
        return jsonify({
            'success': True,
            'data': {
                'price': float(pot_price.price),
                'material': material,
                'size': size
            }
        })
    
    except Exception as e:
        return jsonify({'success': False, 'error': 'Internal server error'}), 500