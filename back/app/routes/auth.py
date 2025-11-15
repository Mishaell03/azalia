from flask import Blueprint, request, jsonify, current_app
from app import db
from app.models import OAuthCode, User, Employee
from datetime import datetime, timedelta
import random
import re
from sqlalchemy import text

bp = Blueprint('auth', __name__, url_prefix='/api/auth')

def validate_telegram_id(telegram_id):
    """Валидация telegram_id с защитой от инъекций"""
    if not telegram_id:
        return False
    try:
        telegram_id = int(telegram_id)
        return 1 <= telegram_id <= 2**63 - 1
    except (ValueError, TypeError):
        return False

def validate_code_format(code):
    """Валидация формата кода с защитой от инъекций"""
    if not isinstance(code, str):
        return False
    return bool(re.match(r'^\d{4}$', code))

def safe_int(value, default=None):
    """Безопасное преобразование в int с защитой от переполнения"""
    try:
        num = int(value)
        if -2**31 <= num <= 2**31 - 1:
            return num
        return default
    except (ValueError, TypeError, OverflowError):
        return default

def sanitize_input(input_str, max_length=100):
    """Очистка входных данных"""
    if not input_str:
        return ""
    sanitized = re.sub(r'[<>"\'\{\}\[\]\(\)\\\/]', '', str(input_str))
    return sanitized[:max_length]

# backend/auth.py (обновленный для поддержки session_token)
@bp.route('/verify', methods=['POST'])
def verify_code():
    """Приложение проверяет код"""
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
        
        auth_code = OAuthCode.query.filter_by(code=code).first()
        
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
            # Генерируем session token
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
                'session_token': session_token,  # Добавляем session_token
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
    """
    Проверка статуса кода авторизации - ЗАЩИЩЕННАЯ ВЕРСИЯ
    """
    try:
        if not validate_code_format(code):
            return jsonify({
                'success': False,
                'error': 'Что-то пошло не так'
            }), 400

        auth_code = OAuthCode.query.filter_by(code=code).first()
        
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