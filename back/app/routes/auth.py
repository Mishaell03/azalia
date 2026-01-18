from flask import Blueprint, request, jsonify, current_app
from app import db
from app.models import OAuthCode, User, Employee
from datetime import datetime, timedelta
import random
import re
from sqlalchemy import text

bp = Blueprint('auth', __name__, url_prefix='/api/auth')

def validate_telegram_id(telegram_id):
    """валидация telegram_id с защитой"""
    if not telegram_id:
        return False
    try:
        telegram_id = int(telegram_id)
        return 1 <= telegram_id <= 2**63 - 1
    except (ValueError, TypeError):
        return False

def validate_code_format(code):
    """валидация формата кода с защитой"""
    if not isinstance(code, str):
        return False
    return bool(re.match(r'^\d{4}$', code))

def safe_int(value, default=None):
    """преобразование в int с защитой от переполнения"""
    try:
        num = int(value)
        if -2**31 <= num <= 2**31 - 1:
            return num
        return default
    except (ValueError, TypeError, OverflowError):
        return default

def sanitize_input(input_str, max_length=100):
    """очистка входных данных"""
    if not input_str:
        return ""
    sanitized = re.sub(r'[<>"\'\{\}\[\]\(\)\\\/]', '', str(input_str))
    return sanitized[:max_length]

@bp.route('/verify', methods=['POST'])
def verify_code():
    """приложение проверяет код"""
    try:
        if not request.is_json:
            return jsonify({
                'success': False,
                'error': 'Что-то пошло не так'
            }), 400
        
        data = request.get_json()
        if not data:
            return jsonify({
                'success': False,
                'error': 'Что-то пошло не так'
            }), 400
        
        code = data.get('code')
        device_id = data.get('device_id')
        
        if not code:
            return jsonify({
                'success': False,
                'error': 'Что-то пошло не так'
            }), 400
        
        if not validate_code_format(code):
            return jsonify({
                'success': False,
                'error': 'Что-то пошло не так'
            }), 400
        
        # Ищем валидный (не использованный и не истёкший) код.
        query = OAuthCode.query.filter_by(code=code)
        # если указан device_id — предпочитаем точное совпадение по устройству
        if device_id:
            query = query.filter_by(device_id=device_id)
        # только неиспользованные и не истёкшие
        from datetime import datetime as _dt
        query = query.filter(OAuthCode.used == False, OAuthCode.expires_at > _dt.utcnow())
        auth_code = query.order_by(OAuthCode.id.desc()).first()
        
        if not auth_code:
            return jsonify({
                'success': False,
                'error': 'Что-то пошло не так'
            }), 404
        
        if auth_code.expires_at < datetime.utcnow():
            return jsonify({
                'success': False,
                'error': 'Что-то пошло не так'
            }), 410
        
        if auth_code.used:
            return jsonify({
                'success': False,
                'error': 'Что-то пошло не так'
            }), 409
        
        user = User.query.filter_by(telegram_id=auth_code.telegram_id).first()
        if not user:
            return jsonify({
                'success': False,
                'error': 'Что-то пошло не так'
            }), 404
        
        employee = Employee.query.filter_by(telegram_id=user.telegram_id).first()
        
        try:
            import secrets
            session_token = secrets.token_hex(32)
            user.session_token = session_token
            user.token_expires_at = datetime.utcnow() + timedelta(days=30)
            
            auth_code.used = True
            auth_code.used_at = datetime.utcnow()
            db.session.commit()
        except Exception:
            db.session.rollback()
            return jsonify({
                'success': False,
                'error': 'Что-то пошло не так'
            }), 500
        
        response_data = {
            'success': True,
            'user': {
                'id': user.id,
                'telegram_id': user.telegram_id,
                'name': sanitize_input(user.name),
                'phone': sanitize_input(user.phone) if user.phone else "",
                'session_token': session_token,
            },
            'message': 'Authentication successful'
        }
        
        if employee:
            response_data['employee'] = {
                'id': employee.id,
                'position_id': employee.position_id,
                'is_active': employee.is_active
            }
            response_data['is_employee'] = True
            if employee.position:
                response_data['position'] = {
                    'id': employee.position.id,
                    'title': sanitize_input(employee.position.title)
                }
        else:
            response_data['is_employee'] = False
        
        return jsonify(response_data), 200
        
    except Exception:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': 'Что-то пошло не так'
        }), 500

@bp.route('/check_status/<code>', methods=['GET'])
def check_code_status(code):
    """проверка статуса кода авторизации"""
    try:
        if not validate_code_format(code):
            return jsonify({
                'success': False,
                'error': 'Что-то пошло не так'
            }), 400

        # Для статуса возвращаем наиболее свежую запись с этим кодом
        auth_code = OAuthCode.query.filter_by(code=code).order_by(OAuthCode.id.desc()).first()
        
        if not auth_code:
            return jsonify({
                'success': False,
                'error': 'Что-то пошло не так'
            }), 404
        
        status = {
            'code': auth_code.code,
            'expires_at': auth_code.expires_at.isoformat() if auth_code.expires_at else None,
            'used': auth_code.used,
            'user_linked': auth_code.telegram_id is not None,
            'is_valid': (
                not auth_code.used and 
                auth_code.expires_at and 
                auth_code.expires_at > datetime.utcnow()
            )
        }
        
        if auth_code.telegram_id:
            user = User.query.filter_by(telegram_id=auth_code.telegram_id).first()
            if user:
                status['user'] = {
                    'id': user.id,
                    'telegram_id': user.telegram_id,
                    'name': sanitize_input(user.name)
                }
                
                employee = Employee.query.filter_by(telegram_id=user.telegram_id).first()
                if employee:
                    status['employee'] = {
                        'id': employee.id,
                        'position_id': employee.position_id
                    }
                    status['is_employee'] = True
                else:
                    status['is_employee'] = False
        
        return jsonify({
            'success': True,
            'status': status
        }), 200
        
    except Exception:
        return jsonify({
            'success': False,
            'error': 'Что-то пошло не так'
        }), 500
    
@bp.route('/update_profile', methods=['POST'])
def update_profile():
    try:
        if not request.is_json:
            return jsonify({
                'success': False,
                'error': 'Неверный формат запроса'
            }), 400
        
        data = request.get_json()
        if not data:
            return jsonify({
                'success': False,
                'error': 'Отсутствуют данные'
            }), 400
        
        session_token = data.get('session_token')
        name = data.get('name')
        phone = data.get('phone')
        
        if not session_token or not isinstance(session_token, str):
            return jsonify({
                'success': False,
                'error': 'Недействительная сессия'
            }), 401
        
        if not name or not isinstance(name, str) or len(name.strip()) < 2:
            return jsonify({
                'success': False,
                'error': 'Имя должно содержать минимум 2 символа'
            }), 400
        
        if not phone or not isinstance(phone, str):
            return jsonify({
                'success': False,
                'error': 'Некорректный номер телефона'
            }), 400
        
        sanitized_name = re.sub(r'[^\w\sа-яА-ЯёЁ\-\.]', '', name.strip())[:100]
        phone_digits = re.sub(r'\D', '', phone)
        
        if len(phone_digits) < 10:
            return jsonify({
                'success': False,
                'error': 'Некорректный номер телефона'
            }), 400
        
        formatted_phone = f"+7{phone_digits[-10:]}"
        
        user = User.query.filter_by(session_token=session_token).first()
        if not user:
            return jsonify({
                'success': False,
                'error': 'Пользователь не найден'
            }), 404
        
        if user.token_expires_at and user.token_expires_at < datetime.utcnow():
            return jsonify({
                'success': False,
                'error': 'Сессия истекла'
            }), 401
        
        user.name = sanitized_name
        user.phone = formatted_phone
        user.updated_at = datetime.utcnow()
        
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Профиль успешно обновлен',
            'user': {
                'id': user.id,
                'telegram_id': user.telegram_id,
                'name': user.name,
                'phone': user.phone,
            }
        }), 200
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Error in update_profile: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Внутренняя ошибка сервера'
        }), 500