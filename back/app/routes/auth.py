from flask import Blueprint, request, jsonify, current_app
from app import db
from app.models import OAuthCode, User, Employee
from datetime import datetime, timedelta
import random
import re

bp = Blueprint('auth', __name__, url_prefix='/api/auth')

def generate_auth_code():
    """Генерация 4-значного кода"""
    while True:
        code = str(random.randint(1000, 9999))
        existing_code = OAuthCode.query.filter_by(code=code).first()
        if not existing_code:
            return code

def validate_telegram_id(telegram_id):
    """Валидация telegram_id"""
    if not telegram_id:
        return False
    try:
        return isinstance(telegram_id, int) or (isinstance(telegram_id, str) and telegram_id.isdigit())
    except (ValueError, TypeError):
        return False

def validate_code_format(code):
    """Валидация формата кода"""
    return isinstance(code, str) and len(code) == 4 and code.isdigit()

def validate_user_id(user_id):
    """Валидация user_id"""
    if not user_id:
        return False
    try:
        return isinstance(user_id, int) or (isinstance(user_id, str) and user_id.isdigit())
    except (ValueError, TypeError):
        return False

def safe_int(value, default=None):
    """Безопасное преобразование в int"""
    try:
        return int(value)
    except (ValueError, TypeError):
        return default

@bp.route('/bot/generate_code', methods=['POST'])
def bot_generate_code():
    """Бот генерирует код"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({
                'success': False,
                'error': 'No data provided'
            }), 400
        
        telegram_id = data.get('telegram_id')
        if not validate_telegram_id(telegram_id):
            return jsonify({
                'success': False,
                'error': 'Valid telegram_id is required'
            }), 400
        
        telegram_id = safe_int(telegram_id)
        if telegram_id is None:
            return jsonify({
                'success': False,
                'error': 'Invalid telegram_id format'
            }), 400

        user_name = data.get('user_name', 'User')
        if user_name:
            user_name = re.sub(r'[<>"\']', '', user_name[:100])

        code = generate_auth_code()
        
        user = User.query.filter_by(telegram_id=telegram_id).first()
        if not user:
            user = User(
                telegram_id=telegram_id,
                name=user_name,
                phone=''
            )
            db.session.add(user)
            db.session.flush()
        
        auth_code = OAuthCode(
            code=code,
            user_id=user.id,
            expires_at=datetime.utcnow() + timedelta(minutes=10),
            used=False
        )
        
        db.session.add(auth_code)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'code': code,
            'expires_in': 10,
            'user_id': user.id
        }), 200
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Error generating code: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Failed to generate code'
        }), 500

@bp.route('/verify', methods=['POST'])
def verify_code():
    """Приложение проверяет код"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({
                'success': False,
                'error': 'No data provided'
            }), 400
        
        code = data.get('code')
        if not validate_code_format(code):
            return jsonify({
                'success': False,
                'error': 'Valid 4-digit code is required'
            }), 400
        
        auth_code = OAuthCode.query.filter_by(code=code).first()
        
        if not auth_code:
            return jsonify({
                'success': False,
                'error': 'Invalid code'
            }), 404
        
        if auth_code.expires_at < datetime.utcnow():
            return jsonify({
                'success': False,
                'error': 'Code has expired'
            }), 410
        
        if auth_code.used:
            return jsonify({
                'success': False,
                'error': 'Code already used'
            }), 409
        
        user = User.query.get(auth_code.user_id)
        if not user:
            return jsonify({
                'success': False,
                'error': 'User not found'
            }), 404
        
        employee = Employee.query.filter_by(telegram_id=user.telegram_id).first()
        
        auth_code.used = True
        auth_code.used_at = datetime.utcnow()
        db.session.commit()
        
        response_data = {
            'success': True,
            'user': user.to_dict(),
            'message': 'Authentication successful'
        }
        
        if employee:
            response_data['employee'] = employee.to_dict()
            response_data['is_employee'] = True
            response_data['position'] = employee.position.to_dict() if employee.position else None
        else:
            response_data['is_employee'] = False
        
        return jsonify(response_data), 200
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Error verifying code: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Verification failed'
        }), 500

@bp.route('/check_status/<code>', methods=['GET'])
def check_code_status(code):
    """
    Проверка статуса кода авторизации
    """
    try:
        if not validate_code_format(code):
            return jsonify({
                'success': False,
                'error': 'Invalid code format'
            }), 400

        auth_code = OAuthCode.query.filter_by(code=code).first()
        
        if not auth_code:
            return jsonify({
                'success': False,
                'error': 'Code not found'
            }), 404
        
        status = {
            'code': auth_code.code,
            'expires_at': auth_code.expires_at.isoformat() if auth_code.expires_at else None,
            'used': auth_code.used,
            'user_linked': auth_code.user_id is not None,
            'is_valid': auth_code.is_valid()
        }
        
        if auth_code.user_id:
            user = User.query.get(auth_code.user_id)
            if user:
                status['user'] = user.to_dict()
                
                employee = Employee.query.filter_by(telegram_id=user.telegram_id).first()
                if employee:
                    status['employee'] = employee.to_dict()
                    status['is_employee'] = True
                else:
                    status['is_employee'] = False
        
        return jsonify({
            'success': True,
            'status': status
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Error checking code status: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Failed to check code status'
        }), 500

@bp.route('/cleanup_expired', methods=['POST'])
def cleanup_expired_codes():
    """
    Очистка просроченных кодов
    """
    try:
        cutoff_time = datetime.utcnow() - timedelta(hours=1)
        expired_count = OAuthCode.query.filter(
            OAuthCode.expires_at < cutoff_time
        ).delete()
        
        db.session.commit()
        
        return jsonify({
            'success': True,
            'cleaned_count': expired_count,
            'message': f'Cleaned {expired_count} expired codes'
        }), 200
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Error cleaning expired codes: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Cleanup failed'
        }), 500

@bp.route('/user/profile', methods=['GET'])
def get_user_profile():
    """
    Получение профиля пользователя
    """
    try:
        user_id = request.args.get('user_id')
        if not user_id:
            return jsonify({
                'success': False,
                'error': 'User ID is required'
            }), 400
        
        if not validate_user_id(user_id):
            return jsonify({
                'success': False,
                'error': 'Invalid user ID format'
            }), 400
        
        user_id = safe_int(user_id)
        if user_id is None:
            return jsonify({
                'success': False,
                'error': 'Invalid user ID'
            }), 400

        user = User.query.get(user_id)
        if not user:
            return jsonify({
                'success': False,
                'error': 'User not found'
            }), 404
        
        employee = Employee.query.filter_by(telegram_id=user.telegram_id).first()
        
        response_data = {
            'success': True,
            'user': user.to_dict()
        }
        
        if employee:
            response_data['employee'] = employee.to_dict()
            response_data['is_employee'] = True
            response_data['position'] = employee.position.to_dict() if employee.position else None
        else:
            response_data['is_employee'] = False
        
        return jsonify(response_data), 200
        
    except Exception as e:
        current_app.logger.error(f"Error getting user profile: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Failed to get user profile'
        }), 500

@bp.route('/employee/check/<telegram_id>', methods=['GET'])
def check_employee_status(telegram_id):
    """
    Проверка, является ли пользователь сотрудником
    """
    try:
        if not validate_telegram_id(telegram_id):
            return jsonify({
                'success': False,
                'error': 'Invalid telegram ID format'
            }), 400
        
        telegram_id = safe_int(telegram_id)
        if telegram_id is None:
            return jsonify({
                'success': False,
                'error': 'Invalid telegram ID'
            }), 400

        employee = Employee.query.filter_by(telegram_id=telegram_id).first()
        
        if employee:
            return jsonify({
                'success': True,
                'is_employee': True,
                'employee': employee.to_dict(),
                'position': employee.position.to_dict() if employee.position else None
            }), 200
        else:
            return jsonify({
                'success': True,
                'is_employee': False
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Error checking employee status: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Failed to check employee status'
        }), 500