from flask import Blueprint, request, jsonify, current_app
from app import db
from app.models import OAuthCode, User, Employee
from datetime import datetime, timedelta
import re
import base64
import io
try:
    from PIL import Image
except ImportError:
    Image = None

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

def get_user_by_session_token(session_token):
    """получить пользователя по session_token из заголовка или данных"""
    if not session_token:
        return None
    clean_token = session_token.strip('"\' ')
    user = User.query.filter_by(session_token=clean_token).first()
    if user and user.token_expires_at and user.token_expires_at < datetime.utcnow():
        return None
    return user

def compress_image(image_data, max_size=(400, 400), quality=85):
    """сжатие изображения"""
    if Image is None:
        raise ImportError("PIL/Pillow не установлен")
    try:
        img = Image.open(io.BytesIO(image_data))
        
        # Конвертируем в RGB если нужно
        if img.mode in ('RGBA', 'LA', 'P'):
            background = Image.new('RGB', img.size, (255, 255, 255))
            if img.mode == 'P':
                img = img.convert('RGBA')
            background.paste(img, mask=img.split()[-1] if img.mode == 'RGBA' else None)
            img = background
        elif img.mode != 'RGB':
            img = img.convert('RGB')
        
        # Изменяем размер если нужно
        img.thumbnail(max_size, Image.Resampling.LANCZOS)
        
        # Сохраняем в байты
        output = io.BytesIO()
        img.save(output, format='JPEG', quality=quality, optimize=True)
        output.seek(0)
        
        return output.getvalue()
    except Exception as e:
        current_app.logger.error(f"Error compressing image: {str(e)}")
        raise

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
        query = query.filter(~OAuthCode.used, OAuthCode.expires_at > _dt.utcnow())
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
        
        avatar_base64 = None
        if user.avatar:
            try:
                avatar_base64 = base64.b64encode(user.avatar).decode('utf-8')
            except Exception:
                pass
        
        response_data = {
            'success': True,
            'user': {
                'id': user.id,
                'telegram_id': user.telegram_id,
                'name': sanitize_input(user.name),
                'phone': sanitize_input(user.phone) if user.phone else "",
                'session_token': session_token,
                'avatar': avatar_base64
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


@bp.route('/me', methods=['GET', 'POST'])
def me():
    """получить актуальные данные пользователя/роли по session_token"""
    try:
        # Получаем токен из заголовка Authorization (приоритет) или из тела запроса (для обратной совместимости)
        auth_header = request.headers.get('Authorization')
        session_token = auth_header if auth_header else None
        
        if not session_token and request.is_json:
            data = request.get_json()
            if data:
                session_token = data.get('session_token')
        
        if not session_token or not isinstance(session_token, str):
            return jsonify({'success': False, 'error': 'Недействительная сессия'}), 401
        
        user = get_user_by_session_token(session_token)
        if not user:
            return jsonify({'success': False, 'error': 'Недействительная сессия'}), 401

        avatar_base64 = None
        if user.avatar:
            try:
                avatar_base64 = base64.b64encode(user.avatar).decode('utf-8')
            except Exception:
                pass
        
        response_data = {
            'success': True,
            'message': 'OK',
            'user': {
                'id': user.id,
                'telegram_id': user.telegram_id,
                'name': sanitize_input(user.name),
                'phone': sanitize_input(user.phone) if user.phone else "",
                'session_token': user.session_token,
                'avatar': avatar_base64
            }
        }

        employee = Employee.query.filter_by(telegram_id=user.telegram_id).first()
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

    except Exception as e:
        current_app.logger.error(f"Error in auth.me: {str(e)}")
        return jsonify({'success': False, 'error': 'Что-то пошло не так'}), 500
    
@bp.route('/update_profile', methods=['POST'])
def update_profile():
    try:
        # Получаем токен из заголовка Authorization (приоритет) или из тела запроса (для обратной совместимости)
        auth_header = request.headers.get('Authorization')
        session_token = auth_header if auth_header else None
        
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
        
        if not session_token:
            session_token = data.get('session_token')
        
        if not session_token or not isinstance(session_token, str):
            return jsonify({
                'success': False,
                'error': 'Недействительная сессия'
            }), 401
        
        name = data.get('name')
        phone = data.get('phone')
        
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
        
        user = get_user_by_session_token(session_token)
        if not user:
            return jsonify({
                'success': False,
                'error': 'Пользователь не найден'
            }), 404
        
        user.name = sanitized_name
        user.phone = formatted_phone
        user.updated_at = datetime.utcnow()
        
        db.session.commit()
        
        avatar_base64 = None
        if user.avatar:
            try:
                avatar_base64 = base64.b64encode(user.avatar).decode('utf-8')
            except Exception:
                pass
        
        return jsonify({
            'success': True,
            'message': 'Профиль успешно обновлен',
            'user': {
                'id': user.id,
                'telegram_id': user.telegram_id,
                'name': user.name,
                'phone': user.phone,
                'avatar': avatar_base64
            }
        }), 200
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Error in update_profile: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Внутренняя ошибка сервера'
        }), 500

@bp.route('/avatar', methods=['POST'])
def upload_avatar():
    """загрузка/изменение аватарки пользователя"""
    try:
        # Получаем токен из заголовка Authorization
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return jsonify({
                'success': False,
                'error': 'Токен сессии не предоставлен'
            }), 401
        
        user = get_user_by_session_token(auth_header)
        if not user:
            return jsonify({
                'success': False,
                'error': 'Недействительная сессия'
            }), 401
        
        # Проверяем наличие файла в запросе
        if 'avatar' not in request.files:
            return jsonify({
                'success': False,
                'error': 'Файл аватарки не предоставлен'
            }), 400
        
        file = request.files['avatar']
        if file.filename == '':
            return jsonify({
                'success': False,
                'error': 'Файл не выбран'
            }), 400
        
        # Проверяем формат файла
        allowed_extensions = {'png', 'jpg', 'jpeg', 'gif', 'webp'}
        if not ('.' in file.filename and 
                file.filename.rsplit('.', 1)[1].lower() in allowed_extensions):
            return jsonify({
                'success': False,
                'error': 'Неподдерживаемый формат изображения'
            }), 400
        
        # Читаем данные файла
        image_data = file.read()
        
        # Проверяем размер файла (максимум 10MB)
        if len(image_data) > 10 * 1024 * 1024:
            return jsonify({
                'success': False,
                'error': 'Размер файла превышает 10MB'
            }), 400
        
        # Сжимаем изображение
        try:
            compressed_image = compress_image(image_data)
        except Exception as e:
            current_app.logger.error(f"Error compressing avatar: {str(e)}")
            return jsonify({
                'success': False,
                'error': 'Ошибка обработки изображения'
            }), 400
        
        # Сохраняем в БД
        user.avatar = compressed_image
        user.updated_at = datetime.utcnow()
        db.session.commit()
        
        # Возвращаем base64 для удобства
        avatar_base64 = base64.b64encode(compressed_image).decode('utf-8')
        
        return jsonify({
            'success': True,
            'message': 'Аватарка успешно загружена',
            'avatar': avatar_base64
        }), 200
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Error in upload_avatar: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Внутренняя ошибка сервера'
        }), 500

@bp.route('/avatar', methods=['GET'])
def get_avatar():
    """получение аватарки пользователя"""
    try:
        # Получаем токен из заголовка Authorization
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return jsonify({
                'success': False,
                'error': 'Токен сессии не предоставлен'
            }), 401
        
        user = get_user_by_session_token(auth_header)
        if not user:
            return jsonify({
                'success': False,
                'error': 'Недействительная сессия'
            }), 401
        
        if not user.avatar:
            return jsonify({
                'success': False,
                'error': 'Аватарка не найдена'
            }), 404
        
        # Возвращаем base64
        avatar_base64 = base64.b64encode(user.avatar).decode('utf-8')
        
        return jsonify({
            'success': True,
            'avatar': avatar_base64
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Error in get_avatar: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Внутренняя ошибка сервера'
        }), 500