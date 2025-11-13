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

@bp.route('/verify', methods=['POST'])
def verify_code():
    """Приложение проверяет код"""
    try:
        if not request.is_json:
            return jsonify({
                'success': False,
                'error': 'Content-Type must be application/json'
            }), 400
        
        data = request.get_json()
        if not data:
            return jsonify({
                'success': False,
                'error': 'No data provided'
            }), 400
        
        code = data.get('code')
        if not code:
            return jsonify({
                'success': False,
                'error': 'Code is required'
            }), 400
        
        if not validate_code_format(code):
            return jsonify({
                'success': False,
                'error': 'Valid 4-digit code is required'
            }), 400
        
        auth_code = OAuthCode.query.filter_by(code=code).first()
        
        if not auth_code:
            # лог попытки использования несуществующего кода
            current_app.logger.warning(f"Attempt to verify non-existent code: {code}")
            return jsonify({
                'success': False,
                'error': 'Invalid code'
            }), 404
        
        # срок действия
        if auth_code.expires_at < datetime.utcnow():
            current_app.logger.info(f"Expired code attempted: {code}")
            return jsonify({
                'success': False,
                'error': 'Code has expired'
            }), 410
        
        if auth_code.used:
            current_app.logger.warning(f"Attempt to reuse code: {code}")
            return jsonify({
                'success': False,
                'error': 'Code already used'
            }), 409
        
        user = User.query.get(auth_code.user_id)
        if not user:
            current_app.logger.error(f"User not found for code: {code}, user_id: {auth_code.user_id}")
            return jsonify({
                'success': False,
                'error': 'User not found'
            }), 404
        
        # проверка сотрудника
        employee = Employee.query.filter_by(telegram_id=user.telegram_id).first()
        
        try:
            auth_code.used = True
            auth_code.used_at = datetime.utcnow()
            db.session.commit()
        except Exception as commit_error:
            db.session.rollback()
            current_app.logger.error(f"Commit error for code {code}: {str(commit_error)}")
            return jsonify({
                'success': False,
                'error': 'Database error'
            }), 500
        
        # безопасный ответ
        response_data = {
            'success': True,
            'user': {
                'id': user.id,
                'telegram_id': user.telegram_id,
                'name': sanitize_input(user.name),
                'phone': sanitize_input(user.phone) if user.phone else ""
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
        
        current_app.logger.info(f"Successful verification for code: {code}, user: {user.id}")
        return jsonify(response_data), 200
        
    except Exception as e:
        db.session.rollback()
        # не раскрываем детали ошибки
        current_app.logger.error(f"Error verifying code: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Verification failed'
        }), 500

@bp.route('/check_status/<code>', methods=['GET'])
def check_code_status(code):
    """
    Проверка статуса кода авторизации - ЗАЩИЩЕННАЯ ВЕРСИЯ
    """
    try:
        if not validate_code_format(code):
            current_app.logger.warning(f"Invalid code format in check_status: {code}")
            return jsonify({
                'success': False,
                'error': 'Invalid code format'
            }), 400

        # безопасный запрос
        auth_code = OAuthCode.query.filter_by(code=code).first()
        
        if not auth_code:
            return jsonify({
                'success': False,
                'error': 'Code not found'
            }), 404
        
        # безопасный ответ
        status = {
            'code': auth_code.code,
            'expires_at': auth_code.expires_at.isoformat() if auth_code.expires_at else None,
            'used': auth_code.used,
            'user_linked': auth_code.user_id is not None,
            'is_valid': auth_code.is_valid() if hasattr(auth_code, 'is_valid') else (
                not auth_code.used and 
                auth_code.expires_at and 
                auth_code.expires_at > datetime.utcnow()
            )
        }
        
        if auth_code.user_id:
            user = User.query.get(auth_code.user_id)
            if user:
                status['user'] = {
                    'id': user.id,
                    'telegram_id': user.telegram_id,
                    'name': sanitize_input(user.name)
                }
                
                # проверка сотрудника
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
        
    except Exception as e:
        # не раскрываем детали ошибки
        current_app.logger.error(f"Error checking code status: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Failed to check code status'
        }), 500
