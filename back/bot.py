import logging
import os
import re
from dataclasses import dataclass
from typing import Optional

from dotenv import load_dotenv
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy import inspect
from telegram.error import Conflict
from telegram import InlineKeyboardButton, InlineKeyboardMarkup, Update
from telegram.ext import Application, CallbackContext, CallbackQueryHandler, CommandHandler

from app import create_app, db
from app.models import Employee, OAuthCode, Position, User

logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO,
)
logger = logging.getLogger(__name__)

DEVICE_ID_PATTERN = re.compile(r"^[A-Za-z0-9_.:-]{1,255}$")
REFRESH_CALLBACK_PATTERN = re.compile(r"^refresh:(\d{1,10})$")


class ValidationError(Exception):
    pass


class NotFoundError(Exception):
    pass


class ServiceError(Exception):
    pass


def ensure_database_ready(flask_app):
    with flask_app.app_context():
        db.create_all()

        inspector = inspect(db.engine)
        required_tables = {'users', 'employees', 'positions', 'oauth_codes'}
        existing_tables = set(inspector.get_table_names())
        missing_tables = required_tables - existing_tables
        if missing_tables:
            raise RuntimeError(
                f'База данных не инициализирована корректно. '
                f'Отсутствуют таблицы: {", ".join(sorted(missing_tables))}'
            )


@dataclass(frozen=True)
class BotConfig:
    token: str
    database_url: str
    code_ttl_minutes: int = 10
    enable_debug_admin: bool = False

    @classmethod
    def from_env(cls):
        load_dotenv()

        token = (os.getenv('BOT_TOKEN') or '').strip()
        if not token:
            raise ValueError('BOT_TOKEN не установлен в переменных окружения.')

        database_url = cls._normalize_database_url(os.getenv('DATABASE_URL'))
        code_ttl_minutes = cls._parse_ttl(os.getenv('BOT_CODE_TTL_MINUTES'), default=10)
        enable_debug_admin = cls._parse_bool(os.getenv('BOT_ENABLE_DEBUG_ADMIN'))

        return cls(
            token=token,
            database_url=database_url,
            code_ttl_minutes=code_ttl_minutes,
            enable_debug_admin=enable_debug_admin,
        )

    @staticmethod
    def _normalize_database_url(raw_value: Optional[str]) -> str:
        value = (raw_value or '').strip()
        if not value:
            return 'sqlite:///flower_shop.db'
        if '://' not in value:
            return f'sqlite:///{value}'
        return value

    @staticmethod
    def _parse_ttl(raw_value: Optional[str], default: int) -> int:
        if raw_value is None:
            return default
        try:
            parsed = int(raw_value)
        except (TypeError, ValueError):
            return default
        if parsed < 1:
            return 1
        if parsed > 30:
            return 30
        return parsed

    @staticmethod
    def _parse_bool(raw_value: Optional[str]) -> bool:
        if raw_value is None:
            return False
        return raw_value.strip().lower() in {'1', 'true', 'yes', 'on'}


@dataclass
class AuthCodeResult:
    oauth_code_id: int
    code: str
    is_employee: bool
    position_title: Optional[str]


def normalize_device_id(raw_device_id: Optional[str]) -> Optional[str]:
    if not isinstance(raw_device_id, str):
        return None

    device_id = raw_device_id.strip()
    if not device_id or len(device_id) > 255:
        return None

    if not DEVICE_ID_PATTERN.fullmatch(device_id):
        return None

    return device_id


class AuthRepository:
    @staticmethod
    def get_or_create_user(telegram_user) -> User:
        user, _ = User.get_or_create_by_telegram(
            telegram_id=telegram_user.id,
            first_name=getattr(telegram_user, 'first_name', None),
            last_name=getattr(telegram_user, 'last_name', None),
            username=getattr(telegram_user, 'username', None),
            phone='',
        )
        return user

    @staticmethod
    def get_active_role(telegram_id: int):
        employee = Employee.query.filter_by(telegram_id=telegram_id, is_active=True).first()
        if not employee:
            return False, None
        if employee.position:
            return True, employee.position.title
        return True, None

    @staticmethod
    def get_oauth_code_for_user(oauth_code_id: int, telegram_id: int):
        return OAuthCode.get_for_user_by_id(oauth_code_id=oauth_code_id, telegram_id=telegram_id)


class AuthService:
    def __init__(self, repository: AuthRepository, code_ttl_minutes: int):
        self.repository = repository
        self.code_ttl_minutes = code_ttl_minutes

    @staticmethod
    def _require_telegram_user(telegram_user) -> int:
        telegram_id = getattr(telegram_user, 'id', None)
        if not isinstance(telegram_id, int) or telegram_id <= 0:
            raise ValidationError('Некорректный Telegram-пользователь.')
        return telegram_id

    def issue_code_for_device(self, telegram_user, device_id: str) -> AuthCodeResult:
        telegram_id = self._require_telegram_user(telegram_user)

        if not normalize_device_id(device_id):
            raise ValidationError('Некорректный идентификатор устройства.')

        try:
            self.repository.get_or_create_user(telegram_user)
            db.session.flush()

            oauth_code, _ = OAuthCode.issue_or_refresh(
                telegram_id=telegram_id,
                device_id=device_id,
                ttl_minutes=self.code_ttl_minutes,
                force_refresh=False,
            )

            is_employee, position_title = self.repository.get_active_role(telegram_id=telegram_id)
            db.session.commit()

            return AuthCodeResult(
                oauth_code_id=oauth_code.id,
                code=oauth_code.code,
                is_employee=is_employee,
                position_title=position_title,
            )
        except ValueError as exc:
            db.session.rollback()
            logger.exception('Code generation error while issuing auth code')
            raise ServiceError('Не удалось сгенерировать код авторизации.') from exc
        except SQLAlchemyError as exc:
            db.session.rollback()
            logger.exception('Database error while issuing auth code')
            raise ServiceError('Ошибка при работе с базой данных.') from exc

    def refresh_code_by_record(self, telegram_user, oauth_code_id: int) -> AuthCodeResult:
        telegram_id = self._require_telegram_user(telegram_user)
        if not isinstance(oauth_code_id, int) or oauth_code_id <= 0:
            raise ValidationError('Некорректный идентификатор кода.')

        try:
            existing_code = self.repository.get_oauth_code_for_user(
                oauth_code_id=oauth_code_id,
                telegram_id=telegram_id,
            )
            if not existing_code:
                db.session.rollback()
                raise NotFoundError('Код не найден.')

            oauth_code, _ = OAuthCode.issue_or_refresh(
                telegram_id=telegram_id,
                device_id=existing_code.device_id,
                ttl_minutes=self.code_ttl_minutes,
                force_refresh=True,
                oauth_code_id=oauth_code_id,
            )

            is_employee, position_title = self.repository.get_active_role(telegram_id=telegram_id)
            db.session.commit()

            return AuthCodeResult(
                oauth_code_id=oauth_code.id,
                code=oauth_code.code,
                is_employee=is_employee,
                position_title=position_title,
            )
        except NotFoundError:
            raise
        except ValueError as exc:
            db.session.rollback()
            logger.exception('Code generation error while refreshing auth code')
            raise ServiceError('Не удалось обновить код авторизации.') from exc
        except SQLAlchemyError as exc:
            db.session.rollback()
            logger.exception('Database error while refreshing auth code')
            raise ServiceError('Ошибка при работе с базой данных.') from exc

    def make_admin_debug(self, telegram_user, position_id: int = 4):
        telegram_id = self._require_telegram_user(telegram_user)

        try:
            self.repository.get_or_create_user(telegram_user)
            db.session.flush()

            position = db.session.get(Position, position_id)
            if not position:
                position = Position(
                    id=position_id,
                    title='Администратор (debug)',
                    responsibilities='Debug access',
                    requirements='Debug only',
                )
                db.session.add(position)
                db.session.flush()

            employee = Employee.query.filter_by(telegram_id=telegram_id).first()
            if employee:
                employee.position_id = position_id
                employee.is_active = True
            else:
                db.session.add(
                    Employee(
                        telegram_id=telegram_id,
                        position_id=position_id,
                        salary=0,
                        is_active=True,
                    )
                )

            db.session.commit()
        except NotFoundError:
            raise
        except SQLAlchemyError as exc:
            db.session.rollback()
            logger.exception('Database error while assigning debug admin role')
            raise ServiceError('Ошибка при обновлении роли.') from exc


class FlowerShopBot:
    def __init__(self, config: BotConfig, auth_service: AuthService, flask_app):
        self.config = config
        self.auth_service = auth_service
        self.flask_app = flask_app
        self.application = Application.builder().token(config.token).build()

        self.application.add_handler(CommandHandler('start', self.start_handler))
        self.application.add_handler(CommandHandler('help', self.help_handler))
        self.application.add_handler(CommandHandler('auth', self.auth_disabled_handler))
        self.application.add_handler(CommandHandler('debug_make_admin', self.debug_make_admin_handler))
        self.application.add_handler(CallbackQueryHandler(self.button_handler))
        self.application.add_error_handler(self.application_error_handler)

    def _build_main_menu_keyboard(self):
        rows = [
            [InlineKeyboardButton('🔐 Как авторизоваться', callback_data='auth_help')],
            [InlineKeyboardButton('❓ Помощь', callback_data='help')],
            [InlineKeyboardButton('⭐ Сделать меня админом (debug)', callback_data='debug:make_admin')],
        ]

        return InlineKeyboardMarkup(rows)

    @staticmethod
    def _build_code_keyboard(oauth_code_id: int):
        return InlineKeyboardMarkup(
            [
                [InlineKeyboardButton('🔄 Обновить код', callback_data=f'refresh:{oauth_code_id}')],
                [InlineKeyboardButton('❓ Помощь', callback_data='help')],
            ]
        )

    @staticmethod
    def _build_role_text(is_employee: bool, position_title: Optional[str]) -> str:
        if not is_employee:
            return '👤 Роль: Клиент'
        if position_title:
            return f'👔 Роль: Сотрудник ({position_title})'
        return '👔 Роль: Сотрудник'

    def _build_auth_code_text(self, result: AuthCodeResult, refreshed: bool) -> str:
        title = '✅ Код подтверждения обновлен' if refreshed else '✅ Код подтверждения сгенерирован'
        role_text = self._build_role_text(result.is_employee, result.position_title)

        return (
            f'{title}\n\n'
            f'{role_text}\n'
            f'🔢 Код: {result.code}\n'
            f'⏰ Действует {self.config.code_ttl_minutes} минут\n\n'
            'Введите этот код в мобильном приложении для завершения авторизации.'
        )

    @staticmethod
    def _build_auth_help_text() -> str:
        return (
            '🔐 Авторизация в мобильном приложении\n\n'
            '1. Откройте мобильное приложение\n'
            '2. Нажмите «Войти через Telegram»\n'
            '3. Перейдите по ссылке, которую откроет приложение\n\n'
            'После перехода бот автоматически выдаст код подтверждения.'
        )

    @staticmethod
    def _build_help_text() -> str:
        return (
            '🌸 Цветочный магазин — помощь\n\n'
            'Доступные команды:\n'
            '/start — открыть меню\n'
            '/help — показать помощь\n\n'
            '/debug_make_admin — назначить себя админом (debug)\n\n'
            'Авторизация выполняется только через кнопку «Войти через Telegram» в мобильном приложении.'
        )

    async def start_handler(self, update: Update, context: CallbackContext):
        message = update.effective_message
        user = update.effective_user

        if message is None:
            return

        if user is None:
            await message.reply_text('❌ Не удалось определить Telegram-пользователя.')
            return

        args = context.args or []
        if not args:
            await message.reply_text(
                f'👋 Привет, {user.first_name or "друг"}!\n\n'
                'Я бот цветочного магазина.\n'
                'Для входа в мобильное приложение используйте кнопку «Войти через Telegram».',
                reply_markup=self._build_main_menu_keyboard(),
            )
            return

        if len(args) != 1:
            await message.reply_text(
                '❌ Некорректная ссылка авторизации.\n'
                'Запустите вход снова из мобильного приложения.'
            )
            return

        device_id = normalize_device_id(args[0])
        if not device_id:
            await message.reply_text(
                '❌ Некорректная ссылка авторизации.\n'
                'Запустите вход снова из мобильного приложения.'
            )
            return

        try:
            result = self.auth_service.issue_code_for_device(user, device_id)
            await message.reply_text(
                self._build_auth_code_text(result=result, refreshed=False),
                reply_markup=self._build_code_keyboard(result.oauth_code_id),
            )
        except ValidationError:
            await message.reply_text(
                '❌ Неверные данные авторизации.\n'
                'Запустите вход снова из мобильного приложения.'
            )
        except ServiceError:
            await message.reply_text('❌ Временная ошибка сервера. Попробуйте еще раз позже.')

    async def help_handler(self, update: Update, context: CallbackContext):
        message = update.effective_message
        if message is None:
            return
        await message.reply_text(self._build_help_text(), reply_markup=self._build_main_menu_keyboard())

    async def auth_disabled_handler(self, update: Update, context: CallbackContext):
        message = update.effective_message
        if message is None:
            return

        await message.reply_text(
            '🔒 Ручной ввод кода отключен.\n'
            'Используйте кнопку «Войти через Telegram» в мобильном приложении.'
        )

    async def debug_make_admin_handler(self, update: Update, context: CallbackContext):
        message = update.effective_message
        user = update.effective_user
        if message is None:
            return

        if user is None:
            await message.reply_text('❌ Не удалось определить пользователя.')
            return

        try:
            self.auth_service.make_admin_debug(user)
            await message.reply_text('✅ Вы назначены администратором (debug-режим).')
        except NotFoundError as exc:
            await message.reply_text(f'❌ {exc}')
        except ServiceError:
            await message.reply_text('❌ Ошибка при обновлении роли.')

    async def button_handler(self, update: Update, context: CallbackContext):
        query = update.callback_query
        user = update.effective_user

        if query is None:
            return

        callback_data = (query.data or '').strip()

        if callback_data == 'auth_help':
            await query.answer()
            await query.edit_message_text(
                self._build_auth_help_text(),
                reply_markup=InlineKeyboardMarkup(
                    [[InlineKeyboardButton('❓ Помощь', callback_data='help')]]
                ),
            )
            return

        if callback_data == 'help':
            await query.answer()
            await query.edit_message_text(
                self._build_help_text(),
                reply_markup=self._build_main_menu_keyboard(),
            )
            return

        if callback_data == 'debug:make_admin':
            if user is None:
                await query.answer('❌ Не удалось определить пользователя.', show_alert=True)
                return

            try:
                self.auth_service.make_admin_debug(user)
                await query.answer()
                await query.edit_message_text(
                    '✅ Вы назначены администратором (debug-режим).',
                    reply_markup=self._build_main_menu_keyboard(),
                )
            except NotFoundError as exc:
                await query.answer(str(exc), show_alert=True)
            except ServiceError:
                await query.answer('❌ Ошибка при обновлении роли.', show_alert=True)
            return

        match = REFRESH_CALLBACK_PATTERN.fullmatch(callback_data)
        if not match:
            await query.answer('❌ Некорректная команда.', show_alert=True)
            return

        if user is None:
            await query.answer('❌ Не удалось определить пользователя.', show_alert=True)
            return

        oauth_code_id = int(match.group(1))

        try:
            result = self.auth_service.refresh_code_by_record(user, oauth_code_id)
            await query.answer('Код обновлен')
            await query.edit_message_text(
                self._build_auth_code_text(result=result, refreshed=True),
                reply_markup=self._build_code_keyboard(result.oauth_code_id),
            )
        except ValidationError:
            await query.answer('❌ Некорректные данные запроса.', show_alert=True)
        except NotFoundError:
            await query.answer('❌ Код не найден или больше недоступен.', show_alert=True)
        except ServiceError:
            await query.answer('❌ Ошибка при обновлении кода.', show_alert=True)

    async def application_error_handler(self, update: object, context: CallbackContext):
        error = context.error
        if isinstance(error, Conflict):
            logger.error(
                'Telegram 409 Conflict: обнаружен второй инстанс бота с этим же токеном. '
                'Останавливаю текущий polling.'
            )
            context.application.stop_running()
            return

        logger.exception('Unhandled telegram application error', exc_info=error)

    def run(self):
        logger.info('Bot is starting...')
        with self.flask_app.app_context():
            self.application.run_polling(drop_pending_updates=True)


def main():
    try:
        config = BotConfig.from_env()
    except ValueError as exc:
        print(f'Ошибка конфигурации: {exc}')
        return

    os.environ['DATABASE_URL'] = config.database_url
    flask_app = create_app()
    try:
        ensure_database_ready(flask_app)
    except Exception as exc:
        print(f'Ошибка инициализации БД: {exc}')
        return

    auth_service = AuthService(
        repository=AuthRepository(),
        code_ttl_minutes=config.code_ttl_minutes,
    )

    bot = FlowerShopBot(
        config=config,
        auth_service=auth_service,
        flask_app=flask_app,
    )
    bot.run()


if __name__ == '__main__':
    main()
