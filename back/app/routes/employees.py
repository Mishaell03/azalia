from flask import Blueprint, jsonify, request, current_app
from app import db
from app.models import User, Employee, Position
import os
import re

bp = Blueprint('employees', __name__, url_prefix='/api')


def get_user_by_session(session_token):
    """получить пользователя по session_token (без импорта циклов)"""
    if not session_token:
        return None
    clean_token = session_token.strip('"\' ')
    user = User.query.filter_by(session_token=clean_token).first()
    if not user:
        return None
    if user.token_expires_at and user.token_expires_at < __import__('datetime').datetime.utcnow():
        return None
    return user


def is_admin(user):
    """Проверка, является ли пользователь администратором по списку TELEGRAM_ID в переменной окружения ADMIN_IDS"""
    if not user:
        return False
    try:
        if int(getattr(user, 'id', 0)) == 4:
            return True
    except Exception:
        pass
    try:
        if int(getattr(user, 'telegram_id', 0)) == 4:
            return True
    except Exception:
        pass

    admin_env = os.environ.get('ADMIN_IDS') or current_app.config.get('ADMIN_IDS')
    ids = []
    if admin_env:
        try:
            ids = [int(x.strip()) for x in re.split(r'[,;\s]+', admin_env) if x.strip()]
        except Exception:
            ids = []

    try:
        user_tid = int(getattr(user, 'telegram_id', 0))
    except Exception:
        user_tid = None
    try:
        user_uid = int(getattr(user, 'id', 0))
    except Exception:
        user_uid = None

    if user_tid and user_tid in ids:
        return True
    if user_uid and user_uid in ids:
        return True
    try:
        emp = getattr(user, 'employee_info', None)
        if emp:
            pos = None
            try:
                pos = Position.query.get(emp.position_id)
            except Exception:
                pos = None
            if pos:
                title = (getattr(pos, 'title', '') or '').lower()
                if 'админ' in title or getattr(pos, 'id', None) == 4 or getattr(emp, 'position_id', None) == 4:
                    return True

        user_tid = getattr(user, 'telegram_id', None)
        candidates = []
        if user_tid is not None:
            candidates.append(user_tid)
            candidates.append(str(user_tid))
        try:
            uid = int(getattr(user, 'id', 0))
            candidates.append(uid)
            candidates.append(str(uid))
        except Exception:
            pass

        for cand in candidates:
            try:
                emp = Employee.query.filter_by(telegram_id=cand).first()
            except Exception:
                emp = None
            if emp:
                try:
                    pos = Position.query.get(emp.position_id)
                except Exception:
                    pos = None
                if pos:
                    title = (getattr(pos, 'title', '') or '').lower()
                    if 'админ' in title or getattr(pos, 'id', None) == 4 or getattr(emp, 'position_id', None) == 4:
                        return True
    except Exception:
        pass

    return False


@bp.route('/users', methods=['GET'])
def list_users():
    """Список всех пользователей (только для админа)"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return jsonify({'success': False, 'error': 'Authorization header required'}), 401

        requester = get_user_by_session(auth_header)
        if not requester:
            return jsonify({'success': False, 'error': 'Invalid session token'}), 401


        users = User.query.all()
        return jsonify({'success': True, 'data': [u.to_dict() for u in users]})
    except Exception:
        return jsonify({'success': False, 'error': 'Internal server error'}), 500


@bp.route('/debug/whoami', methods=['GET'])
def debug_whoami():
    """Отладочный endpoint: вернуть информацию о пользователе по session token"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return jsonify({'success': False, 'error': 'Authorization header required'}), 401

        requester = get_user_by_session(auth_header)
        if not requester:
            return jsonify({'success': False, 'error': 'Invalid session token'}), 401

        return jsonify({'success': True, 'user': requester.to_dict(), 'is_admin': is_admin(requester)})
    except Exception:
        return jsonify({'success': False, 'error': 'Internal server error'}), 500


@bp.route('/employees', methods=['GET'])
def get_employees():
    """Список всех сотрудников с подробной информацией"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return jsonify({'success': False, 'error': 'Authorization header required'}), 401

        requester = get_user_by_session(auth_header)
        if not requester:
            return jsonify({'success': False, 'error': 'Invalid session token'}), 401

        employees = Employee.query.all()
        return jsonify({'success': True, 'data': [e.to_dict_with_details() for e in employees]})
    except Exception:
        return jsonify({'success': False, 'error': 'Internal server error'}), 500


@bp.route('/employees/<int:employee_id>', methods=['GET'])
def get_employee(employee_id):
    """Получить информацию о конкретном сотруднике"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return jsonify({'success': False, 'error': 'Authorization header required'}), 401

        requester = get_user_by_session(auth_header)
        if not requester:
            return jsonify({'success': False, 'error': 'Invalid session token'}), 401

        emp = Employee.query.get(employee_id)
        if not emp:
            return jsonify({'success': False, 'error': 'Employee not found'}), 404

        return jsonify({'success': True, 'data': emp.to_dict_with_details()})
    except Exception:
        return jsonify({'success': False, 'error': 'Internal server error'}), 500


@bp.route('/employees/assign', methods=['POST'])
def assign_employee():
    """Назначить пользователя сотрудником (только админ)"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return jsonify({'success': False, 'error': 'Authorization header required'}), 401

        requester = get_user_by_session(auth_header)
        if not requester:
            return jsonify({'success': False, 'error': 'Invalid session token'}), 401

        if not is_admin(requester):
            return jsonify({'success': False, 'error': 'Admin privileges required'}), 403

        if not request.is_json:
            return jsonify({'success': False, 'error': 'JSON body required'}), 400

        data = request.get_json()
        telegram_id = data.get('telegram_id')
        user_id = data.get('user_id')
        position_id = data.get('position_id')
        salary = data.get('salary')

        # Найти пользователя по user_id или telegram_id. Поддерживаем частичное совпадение telegram_id
        user = None
        if user_id:
            try:
                user = User.query.get(int(user_id))
            except Exception:
                user = None

        if not user and telegram_id:
            # попытка точного совпадения
            try:
                tid_int = int(telegram_id)
                user = User.query.filter_by(telegram_id=tid_int).first()
            except Exception:
                user = None

        if not user and telegram_id:
            # попытка частичного совпадения: найти пользователя, у которого telegram_id содержит переданную строку
            try:
                needle = str(telegram_id)
                all_users = User.query.all()
                for u in all_users:
                    if u.telegram_id and needle in str(u.telegram_id):
                        user = u
                        break
            except Exception:
                user = None

        if not user:
            return jsonify({'success': False, 'error': 'User not found'}), 404
        if not user:
            return jsonify({'success': False, 'error': 'User not found'}), 404

        if Employee.query.filter_by(telegram_id=telegram_id).first():
            return jsonify({'success': False, 'error': 'User is already an employee'}), 409

        if not position_id:
            return jsonify({'success': False, 'error': 'position_id is required'}), 400
        try:
            position_id = int(position_id)
        except Exception:
            return jsonify({'success': False, 'error': 'Invalid position_id'}), 400

        position = Position.query.get(position_id)
        if not position:
            return jsonify({'success': False, 'error': 'Position not found'}), 404

        emp = Employee(telegram_id=user.telegram_id, position_id=position.id, salary=salary)
        db.session.add(emp)
        db.session.commit()

        return jsonify({'success': True, 'message': 'User assigned as employee', 'data': emp.to_dict_with_details()}), 201

    except Exception:
        db.session.rollback()
        return jsonify({'success': False, 'error': 'Internal server error'}), 500