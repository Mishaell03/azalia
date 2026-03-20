from __future__ import annotations

import logging
import os
import random
import re
import secrets
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Optional
from pathlib import Path

from dotenv import load_dotenv
from telegram import InlineKeyboardButton, InlineKeyboardMarkup, Update
from telegram.error import Conflict, TimedOut
from telegram.ext import (
    Application,
    CallbackContext,
    CallbackQueryHandler,
    CommandHandler,
)

from app.core.database import create_database, get_connection, validate_schema

logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO,
)
logger = logging.getLogger(__name__)

DEVICE_ID_PATTERN = re.compile(r"^[A-Za-z0-9_.:-]{1,255}$")
REFRESH_CALLBACK_PATTERN = re.compile(r"^refresh:(\d{1,10})$")
USER_AVATAR_DIR = Path(__file__).resolve().parent / "img" / "users"
ALLOWED_AVATAR_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".gif"}


def _available_user_avatars() -> list[str]:
    if not USER_AVATAR_DIR.exists():
        return []

    avatars: list[str] = []
    for path in USER_AVATAR_DIR.iterdir():
        if not path.is_file():
            continue
        if path.name.lower() == "blocked.png":
            continue
        if path.suffix.lower() not in ALLOWED_AVATAR_EXTS:
            continue
        avatars.append(f"img/users/{path.name}")
    return avatars


def _avatar_exists(rel_path: Optional[str]) -> bool:
    if not rel_path:
        return False
    return (Path(__file__).resolve().parent / rel_path.lstrip("/")).exists()


class ValidationError(Exception):
    pass


class NotFoundError(Exception):
    pass


class ServiceError(Exception):
    pass


def utc_now() -> datetime:
    return datetime.utcnow()


def utc_now_str() -> str:
    return utc_now().strftime("%Y-%m-%d %H:%M:%S")


def normalize_device_id(raw_device_id: Optional[str]) -> Optional[str]:
    if not isinstance(raw_device_id, str):
        return None

    device_id = raw_device_id.strip()
    if not device_id or len(device_id) > 255:
        return None

    if not DEVICE_ID_PATTERN.fullmatch(device_id):
        return None

    return device_id


def ensure_database_ready() -> None:
    create_database()
    validate_schema()


@dataclass(frozen=True)
class BotConfig:
    token: str
    code_ttl_minutes: int = 10
    enable_debug_admin: bool = False
    notification_poll_seconds: int = 20

    @classmethod
    def from_env(cls) -> "BotConfig":
        load_dotenv()

        token = (os.getenv("BOT_TOKEN") or "").strip()
        if not token:
            raise ValueError("BOT_TOKEN не установлен в переменных окружения.")

        return cls(
            token=token,
            code_ttl_minutes=cls._parse_ttl(
                os.getenv("BOT_CODE_TTL_MINUTES"),
                default=10,
            ),
            enable_debug_admin=cls._parse_bool(
                os.getenv("BOT_ENABLE_DEBUG_ADMIN"),
            ),
            notification_poll_seconds=cls._parse_notification_poll_seconds(
                os.getenv("BOT_NOTIFICATION_POLL_SECONDS"),
                default=20,
            ),
        )

    @staticmethod
    def _parse_ttl(raw_value: Optional[str], default: int) -> int:
        if raw_value is None:
            return default
        try:
            parsed = int(raw_value)
        except (TypeError, ValueError):
            return default
        return max(1, min(parsed, 30))

    @staticmethod
    def _parse_bool(raw_value: Optional[str]) -> bool:
        if raw_value is None:
            return False
        return raw_value.strip().lower() in {"1", "true", "yes", "on"}

    @staticmethod
    def _parse_notification_poll_seconds(raw_value: Optional[str], default: int) -> int:
        if raw_value is None:
            return default
        try:
            parsed = int(raw_value)
        except (TypeError, ValueError):
            return default
        return max(5, min(parsed, 300))


@dataclass
class AuthCodeResult:
    auth_code_id: int
    code: str
    is_employee: bool
    position_title: Optional[str]


class AuthRepository:
    def get_or_create_user(self, telegram_user) -> sqlite3.Row:
        telegram_id = getattr(telegram_user, "id", None)
        if not isinstance(telegram_id, int) or telegram_id <= 0:
            raise ValidationError("Некорректный Telegram-пользователь.")

        first_name = (getattr(telegram_user, "first_name", None) or "").strip()
        last_name = (getattr(telegram_user, "last_name", None) or "").strip()
        username = (getattr(telegram_user, "username", None) or "").strip()

        full_name = " ".join(part for part in [first_name, last_name] if part)
        if not full_name:
            full_name = username or f"Telegram User {telegram_id}"

        conn = get_connection()
        try:
            existing = conn.execute(
                "SELECT * FROM users WHERE telegram_id = ? LIMIT 1",
                (telegram_id,),
            ).fetchone()
            if existing:
                updates: list[str] = []
                params: list[object] = []
                if existing["full_name"] != full_name and full_name:
                    updates.append("full_name = ?")
                    params.append(full_name)

                avatar_url = (existing["avatar_url"] or "").strip()
                if avatar_url and not _avatar_exists(avatar_url):
                    avatar_url = ""

                if not avatar_url:
                    pool = _available_user_avatars()
                    if pool:
                        updates.append("avatar_url = ?")
                        params.append(random.choice(pool))

                if updates:
                    conn.execute(
                        f"""
                        UPDATE users
                        SET {", ".join(updates)},
                            updated_at = CURRENT_TIMESTAMP
                        WHERE id = ?
                        """,
                        (*params, existing["id"]),
                    )
                    conn.commit()
                    existing = conn.execute(
                        "SELECT * FROM users WHERE id = ? LIMIT 1",
                        (existing["id"],),
                    ).fetchone()
                return existing

            avatar_url = None
            pool = _available_user_avatars()
            if pool:
                avatar_url = random.choice(pool)

            conn.execute(
                """
                INSERT INTO users (
                    telegram_id, full_name, phone, avatar_url, status
                )
                VALUES (?, ?, ?, ?, 'active')
                """,
                (telegram_id, full_name, "", avatar_url),
            )
            conn.commit()
            created = conn.execute(
                "SELECT * FROM users WHERE telegram_id = ? LIMIT 1",
                (telegram_id,),
            ).fetchone()
            if not created:
                raise ServiceError("Не удалось создать пользователя.")
            return created
        finally:
            conn.close()

    def get_active_role(self, telegram_id: int) -> tuple[bool, Optional[str]]:
        conn = get_connection()
        try:
            row = conn.execute(
                """
                SELECT p.title AS position_title
                FROM employees e
                JOIN users u ON u.id = e.user_id
                JOIN positions p ON p.id = e.position_id
                WHERE u.telegram_id = ?
                  AND e.is_active = 1
                LIMIT 1
                """,
                (telegram_id,),
            ).fetchone()
            if not row:
                return False, None
            return True, row["position_title"]
        finally:
            conn.close()

    def get_auth_code_for_user(self, auth_code_id: int, telegram_id: int) -> Optional[sqlite3.Row]:
        conn = get_connection()
        try:
            return conn.execute(
                """
                SELECT ac.*, u.telegram_id
                FROM auth_codes ac
                JOIN users u ON u.id = ac.user_id
                WHERE ac.id = ?
                  AND u.telegram_id = ?
                LIMIT 1
                """,
                (auth_code_id, telegram_id),
            ).fetchone()
        finally:
            conn.close()

    def upsert_auth_code(
        self,
        *,
        user_id: int,
        device_id: str,
        ttl_minutes: int,
        force_refresh: bool,
        auth_code_id: Optional[int] = None,
    ) -> sqlite3.Row:
        expires_at = (utc_now() + timedelta(minutes=ttl_minutes)).strftime(
            "%Y-%m-%d %H:%M:%S"
        )

        conn = get_connection()
        try:
            cur = conn.cursor()
            code = self._generate_unique_code(cur)

            if force_refresh and auth_code_id is not None:
                existing = cur.execute(
                    """
                    SELECT *
                    FROM auth_codes
                    WHERE id = ? AND user_id = ?
                    LIMIT 1
                    """,
                    (auth_code_id, user_id),
                ).fetchone()
                if not existing:
                    raise NotFoundError("Код не найден.")

                cur.execute(
                    """
                    UPDATE auth_codes
                    SET code = ?,
                        device_id = ?,
                        expires_at = ?,
                        used_at = NULL,
                        created_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                    """,
                    (code, device_id, expires_at, auth_code_id),
                )
                target_id = auth_code_id
            else:
                existing = cur.execute(
                    """
                    SELECT id
                    FROM auth_codes
                    WHERE user_id = ?
                      AND device_id = ?
                      AND used_at IS NULL
                    ORDER BY id DESC
                    LIMIT 1
                    """,
                    (user_id, device_id),
                ).fetchone()

                if existing:
                    cur.execute(
                        """
                        UPDATE auth_codes
                        SET code = ?,
                            expires_at = ?,
                            used_at = NULL,
                            created_at = CURRENT_TIMESTAMP
                        WHERE id = ?
                        """,
                        (code, expires_at, existing["id"]),
                    )
                    target_id = int(existing["id"])
                else:
                    cur.execute(
                        """
                        INSERT INTO auth_codes (user_id, device_id, code, expires_at, used_at)
                        VALUES (?, ?, ?, ?, NULL)
                        """,
                        (user_id, device_id, code, expires_at),
                    )
                    target_id = int(cur.lastrowid)

            conn.commit()
            row = cur.execute(
                "SELECT * FROM auth_codes WHERE id = ? LIMIT 1",
                (target_id,),
            ).fetchone()
            if not row:
                raise ServiceError("Не удалось сохранить код авторизации.")
            return row
        finally:
            conn.close()

    def ensure_debug_admin(self, telegram_user, position_id: int = 4) -> None:
        user = self.get_or_create_user(telegram_user)
        telegram_id = int(user["telegram_id"])

        conn = get_connection()
        try:
            cur = conn.cursor()

            position = cur.execute(
                "SELECT id FROM positions WHERE id = ? LIMIT 1",
                (position_id,),
            ).fetchone()
            if not position:
                cur.execute(
                    """
                    INSERT INTO positions (id, title, description)
                    VALUES (?, ?, ?)
                    """,
                    (
                        position_id,
                        "Администратор (debug)",
                        "Временная debug-роль для Telegram-бота",
                    ),
                )

            store = cur.execute(
                "SELECT id FROM stores WHERE is_active = 1 ORDER BY id ASC LIMIT 1"
            ).fetchone()
            if not store:
                cur.execute(
                    """
                    INSERT INTO stores (
                        name, address, phone, email, store_type, is_active
                    )
                    VALUES (?, ?, ?, ?, 'shop', 1)
                    """,
                    (
                        "Debug Store",
                        "Debug address",
                        None,
                        None,
                    ),
                )
                store_id = int(cur.lastrowid)
            else:
                store_id = int(store["id"])

            employee = cur.execute(
                "SELECT id FROM employees WHERE user_id = ? LIMIT 1",
                (user["id"],),
            ).fetchone()
            if employee:
                cur.execute(
                    """
                    UPDATE employees
                    SET position_id = ?,
                        store_id = ?,
                        is_active = 1,
                        fired_at = NULL,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                    """,
                    (position_id, store_id, employee["id"]),
                )
            else:
                cur.execute(
                    """
                    INSERT INTO employees (
                        user_id, position_id, store_id, salary, is_active
                    )
                    VALUES (?, ?, ?, ?, 1)
                    """,
                    (user["id"], position_id, store_id, 0),
                )

            conn.commit()
            logger.info("Debug admin role granted to telegram_id=%s", telegram_id)
        finally:
            conn.close()

    @staticmethod
    def _generate_unique_code(cur: sqlite3.Cursor) -> str:
        for _ in range(20):
            code = f"{secrets.randbelow(10000):04d}"
            exists = cur.execute(
                """
                SELECT 1
                FROM auth_codes
                WHERE code = ?
                  AND used_at IS NULL
                  AND datetime(expires_at) > datetime('now')
                LIMIT 1
                """,
                (code,),
            ).fetchone()
            if not exists:
                return code
        raise ServiceError("Не удалось сгенерировать уникальный код авторизации.")


class AuthService:
    def __init__(self, repository: AuthRepository, code_ttl_minutes: int):
        self.repository = repository
        self.code_ttl_minutes = code_ttl_minutes

    @staticmethod
    def _require_telegram_user(telegram_user) -> int:
        telegram_id = getattr(telegram_user, "id", None)
        if not isinstance(telegram_id, int) or telegram_id <= 0:
            raise ValidationError("Некорректный Telegram-пользователь.")
        return telegram_id

    def issue_code_for_device(self, telegram_user, device_id: str) -> AuthCodeResult:
        telegram_id = self._require_telegram_user(telegram_user)
        normalized_device_id = normalize_device_id(device_id)
        if not normalized_device_id:
            raise ValidationError("Некорректный идентификатор устройства.")

        try:
            user = self.repository.get_or_create_user(telegram_user)
            auth_code = self.repository.upsert_auth_code(
                user_id=int(user["id"]),
                device_id=normalized_device_id,
                ttl_minutes=self.code_ttl_minutes,
                force_refresh=False,
            )
            is_employee, position_title = self.repository.get_active_role(
                telegram_id=telegram_id
            )

            return AuthCodeResult(
                auth_code_id=int(auth_code["id"]),
                code=str(auth_code["code"]),
                is_employee=is_employee,
                position_title=position_title,
            )
        except (sqlite3.Error, ServiceError):
            logger.exception("Database error while issuing auth code")
            raise ServiceError("Ошибка при работе с базой данных.")

    def refresh_code_by_record(self, telegram_user, auth_code_id: int) -> AuthCodeResult:
        telegram_id = self._require_telegram_user(telegram_user)
        if not isinstance(auth_code_id, int) or auth_code_id <= 0:
            raise ValidationError("Некорректный идентификатор кода.")

        try:
            existing = self.repository.get_auth_code_for_user(
                auth_code_id=auth_code_id,
                telegram_id=telegram_id,
            )
            if not existing:
                raise NotFoundError("Код не найден.")

            auth_code = self.repository.upsert_auth_code(
                user_id=int(existing["user_id"]),
                device_id=str(existing["device_id"] or ""),
                ttl_minutes=self.code_ttl_minutes,
                force_refresh=True,
                auth_code_id=auth_code_id,
            )
            is_employee, position_title = self.repository.get_active_role(
                telegram_id=telegram_id
            )

            return AuthCodeResult(
                auth_code_id=int(auth_code["id"]),
                code=str(auth_code["code"]),
                is_employee=is_employee,
                position_title=position_title,
            )
        except NotFoundError:
            raise
        except (sqlite3.Error, ServiceError):
            logger.exception("Database error while refreshing auth code")
            raise ServiceError("Ошибка при работе с базой данных.")

    def make_admin_debug(self, telegram_user, position_id: int = 4) -> None:
        self._require_telegram_user(telegram_user)
        try:
            self.repository.ensure_debug_admin(telegram_user, position_id=position_id)
        except sqlite3.Error:
            logger.exception("Database error while assigning debug admin role")
            raise ServiceError("Ошибка при обновлении роли.")


@dataclass(frozen=True)
class PendingTelegramNotification:
    notification_id: int
    telegram_id: int
    title: str
    body: str


class NotificationRepository:
    def fetch_pending_telegram_notifications(self, *, limit: int = 50) -> list[PendingTelegramNotification]:
        conn = get_connection()
        try:
            rows = conn.execute(
                """
                SELECT
                    n.id,
                    u.telegram_id,
                    n.title,
                    n.body
                FROM notifications n
                JOIN users u ON u.id = n.user_id
                WHERE n.status = 'pending'
                  AND n.channel = 'telegram'
                  AND u.status = 'active'
                  AND u.telegram_id IS NOT NULL
                  AND (
                        n.scheduled_at IS NULL
                        OR datetime(n.scheduled_at) <= datetime('now')
                  )
                ORDER BY COALESCE(n.scheduled_at, n.created_at) ASC, n.id ASC
                LIMIT ?
                """,
                (limit,),
            ).fetchall()
            return [
                PendingTelegramNotification(
                    notification_id=int(row["id"]),
                    telegram_id=int(row["telegram_id"]),
                    title=str(row["title"] or "Уведомление"),
                    body=str(row["body"] or ""),
                )
                for row in rows
            ]
        finally:
            conn.close()

    def fetch_pending_for_telegram_id(self, telegram_id: int, *, limit: int = 20) -> list[PendingTelegramNotification]:
        conn = get_connection()
        try:
            rows = conn.execute(
                """
                SELECT
                    n.id,
                    u.telegram_id,
                    n.title,
                    n.body
                FROM notifications n
                JOIN users u ON u.id = n.user_id
                WHERE n.status = 'pending'
                  AND n.channel = 'telegram'
                  AND u.telegram_id = ?
                  AND u.status = 'active'
                  AND (
                        n.scheduled_at IS NULL
                        OR datetime(n.scheduled_at) <= datetime('now')
                  )
                ORDER BY COALESCE(n.scheduled_at, n.created_at) ASC, n.id ASC
                LIMIT ?
                """,
                (telegram_id, limit),
            ).fetchall()
            return [
                PendingTelegramNotification(
                    notification_id=int(row["id"]),
                    telegram_id=int(row["telegram_id"]),
                    title=str(row["title"] or "Уведомление"),
                    body=str(row["body"] or ""),
                )
                for row in rows
            ]
        finally:
            conn.close()

    def mark_sent(self, notification_id: int) -> None:
        conn = get_connection()
        try:
            conn.execute(
                """
                UPDATE notifications
                SET status = 'sent',
                    sent_at = CURRENT_TIMESTAMP
                WHERE id = ?
                """,
                (notification_id,),
            )
            conn.commit()
        finally:
            conn.close()

    def mark_failed(self, notification_id: int) -> None:
        conn = get_connection()
        try:
            conn.execute(
                """
                UPDATE notifications
                SET status = 'failed'
                WHERE id = ?
                """,
                (notification_id,),
            )
            conn.commit()
        finally:
            conn.close()


class FlowerShopBot:
    def __init__(self, config: BotConfig, auth_service: AuthService, notification_repository: NotificationRepository):
        self.config = config
        self.auth_service = auth_service
        self.notification_repository = notification_repository
        self.application = Application.builder().token(config.token).build()

        self.application.add_handler(CommandHandler("start", self.start_handler))
        self.application.add_handler(CommandHandler("help", self.help_handler))
        self.application.add_handler(CommandHandler("notifications", self.notifications_handler))
        self.application.add_handler(CommandHandler("auth", self.auth_disabled_handler))
        self.application.add_handler(
            CommandHandler("debug_make_admin", self.debug_make_admin_handler)
        )
        self.application.add_handler(CallbackQueryHandler(self.button_handler))
        self.application.add_error_handler(self.application_error_handler)

    def _build_main_menu_keyboard(self) -> InlineKeyboardMarkup:
        rows = [
            [InlineKeyboardButton("🔐 Как авторизоваться", callback_data="auth_help")],
            [InlineKeyboardButton("❓ Помощь", callback_data="help")],
        ]

        if self.config.enable_debug_admin:
            rows.append(
                [
                    InlineKeyboardButton(
                        "⭐ Сделать меня админом (debug)",
                        callback_data="debug:make_admin",
                    )
                ]
            )

        return InlineKeyboardMarkup(rows)

    @staticmethod
    def _build_code_keyboard(auth_code_id: int) -> InlineKeyboardMarkup:
        return InlineKeyboardMarkup(
            [
                [
                    InlineKeyboardButton(
                        "🔄 Обновить код",
                        callback_data=f"refresh:{auth_code_id}",
                    )
                ],
                [InlineKeyboardButton("❓ Помощь", callback_data="help")],
            ]
        )

    @staticmethod
    def _build_role_text(is_employee: bool, position_title: Optional[str]) -> str:
        if not is_employee:
            return "👤 Роль: Клиент"
        if position_title:
            return f"👔 Роль: Сотрудник ({position_title})"
        return "👔 Роль: Сотрудник"

    def _build_auth_code_text(self, result: AuthCodeResult, refreshed: bool) -> str:
        title = (
            "✅ Код подтверждения обновлен"
            if refreshed
            else "✅ Код подтверждения сгенерирован"
        )
        role_text = self._build_role_text(result.is_employee, result.position_title)

        return (
            f"{title}\n\n"
            f"{role_text}\n"
            f"🔢 Код: {result.code}\n"
            f"⏰ Действует {self.config.code_ttl_minutes} минут\n\n"
            "Введите этот код в мобильном приложении для завершения авторизации."
        )

    @staticmethod
    def _build_auth_help_text() -> str:
        return (
            "🔐 Авторизация в мобильном приложении\n\n"
            "1. Откройте мобильное приложение\n"
            "2. Нажмите «Войти через Telegram»\n"
            "3. Перейдите по ссылке, которую откроет приложение\n\n"
            "После перехода бот автоматически выдаст код подтверждения."
        )

    def _build_help_text(self) -> str:
        lines = [
            "🌸 Цветочный магазин — помощь\n\n"
            "Доступные команды:\n"
            "/start — открыть меню\n"
            "/help — показать помощь\n",
            "/notifications — проверить новые уведомления\n",
        ]
        if self.config.enable_debug_admin:
            lines.append("/debug_make_admin — назначить себя админом (debug)\n")
        lines.append(
            "\nАвторизация выполняется только через кнопку "
            "«Войти через Telegram» в мобильном приложении."
        )
        return "".join(lines)

    async def _safe_answer_callback_query(
        self,
        query,
        text: Optional[str] = None,
        *,
        show_alert: bool = False,
    ) -> bool:
        try:
            if text is None:
                await query.answer()
            else:
                await query.answer(text, show_alert=show_alert)
            return True
        except TimedOut:
            logger.warning(
                "Timed out while answering callback query id=%s data=%s",
                getattr(query, "id", "unknown"),
                getattr(query, "data", None),
            )
            return False

    async def start_handler(self, update: Update, context: CallbackContext) -> None:
        message = update.effective_message
        user = update.effective_user

        if message is None:
            return
        if user is None:
            await message.reply_text("❌ Не удалось определить Telegram-пользователя.")
            return

        args = context.args or []
        if not args:
            await message.reply_text(
                f"👋 Привет, {user.first_name or 'друг'}!\n\n"
                "Я бот цветочного магазина.\n"
                "Для входа в мобильное приложение используйте кнопку "
                "«Войти через Telegram».",
                reply_markup=self._build_main_menu_keyboard(),
            )
            return

        if len(args) != 1:
            await message.reply_text(
                "❌ Некорректная ссылка авторизации.\n"
                "Запустите вход снова из мобильного приложения."
            )
            return

        device_id = normalize_device_id(args[0])
        if not device_id:
            await message.reply_text(
                "❌ Некорректная ссылка авторизации.\n"
                "Запустите вход снова из мобильного приложения."
            )
            return

        try:
            result = self.auth_service.issue_code_for_device(user, device_id)
            await message.reply_text(
                self._build_auth_code_text(result=result, refreshed=False),
                reply_markup=self._build_code_keyboard(result.auth_code_id),
            )
            await self._drain_notifications_for_telegram_id(
                telegram_id=int(user.id),
                context=context,
                silent_if_empty=True,
            )
        except ValidationError:
            await message.reply_text(
                "❌ Неверные данные авторизации.\n"
                "Запустите вход снова из мобильного приложения."
            )
        except ServiceError:
            await message.reply_text("❌ Временная ошибка сервера. Попробуйте еще раз позже.")

    async def help_handler(self, update: Update, context: CallbackContext) -> None:
        message = update.effective_message
        if message is None:
            return
        await message.reply_text(
            self._build_help_text(),
            reply_markup=self._build_main_menu_keyboard(),
        )

    async def notifications_handler(self, update: Update, context: CallbackContext) -> None:
        message = update.effective_message
        user = update.effective_user
        if message is None:
            return
        if user is None or not isinstance(user.id, int) or user.id <= 0:
            await message.reply_text("❌ Не удалось определить пользователя.")
            return

        sent_count = await self._drain_notifications_for_telegram_id(
            telegram_id=int(user.id),
            context=context,
            silent_if_empty=False,
        )
        if sent_count == 0:
            await message.reply_text("📭 Новых уведомлений пока нет.")

    async def auth_disabled_handler(self, update: Update, context: CallbackContext) -> None:
        message = update.effective_message
        if message is None:
            return
        await message.reply_text(
            "🔒 Ручной ввод кода отключен.\n"
            "Используйте кнопку «Войти через Telegram» в мобильном приложении."
        )

    async def debug_make_admin_handler(
        self,
        update: Update,
        context: CallbackContext,
    ) -> None:
        message = update.effective_message
        user = update.effective_user
        if message is None:
            return
        if user is None:
            await message.reply_text("❌ Не удалось определить пользователя.")
            return
        if not self.config.enable_debug_admin:
            await message.reply_text("🔒 Debug-режим отключен.")
            return

        try:
            self.auth_service.make_admin_debug(user)
            await message.reply_text("✅ Вы назначены администратором (debug-режим).")
        except ServiceError:
            await message.reply_text("❌ Ошибка при обновлении роли.")

    async def button_handler(self, update: Update, context: CallbackContext) -> None:
        query = update.callback_query
        user = update.effective_user

        if query is None:
            return

        callback_data = (query.data or "").strip()

        if callback_data == "auth_help":
            await self._safe_answer_callback_query(query)
            await query.edit_message_text(
                self._build_auth_help_text(),
                reply_markup=InlineKeyboardMarkup(
                    [[InlineKeyboardButton("❓ Помощь", callback_data="help")]]
                ),
            )
            return

        if callback_data == "help":
            await self._safe_answer_callback_query(query)
            await query.edit_message_text(
                self._build_help_text(),
                reply_markup=self._build_main_menu_keyboard(),
            )
            return

        if callback_data == "debug:make_admin":
            if not self.config.enable_debug_admin:
                await self._safe_answer_callback_query(
                    query,
                    "🔒 Debug-режим отключен.",
                    show_alert=True,
                )
                return
            if user is None:
                await self._safe_answer_callback_query(
                    query,
                    "❌ Не удалось определить пользователя.",
                    show_alert=True,
                )
                return

            try:
                self.auth_service.make_admin_debug(user)
                await self._safe_answer_callback_query(query)
                await query.edit_message_text(
                    "✅ Вы назначены администратором (debug-режим).",
                    reply_markup=self._build_main_menu_keyboard(),
                )
            except ServiceError:
                await self._safe_answer_callback_query(
                    query,
                    "❌ Ошибка при обновлении роли.",
                    show_alert=True,
                )
            return

        match = REFRESH_CALLBACK_PATTERN.fullmatch(callback_data)
        if not match:
            await self._safe_answer_callback_query(
                query,
                "❌ Некорректная команда.",
                show_alert=True,
            )
            return

        if user is None:
            await self._safe_answer_callback_query(
                query,
                "❌ Не удалось определить пользователя.",
                show_alert=True,
            )
            return

        auth_code_id = int(match.group(1))

        try:
            result = self.auth_service.refresh_code_by_record(user, auth_code_id)
            await self._safe_answer_callback_query(query, "Код обновлен")
            await query.edit_message_text(
                self._build_auth_code_text(result=result, refreshed=True),
                reply_markup=self._build_code_keyboard(result.auth_code_id),
            )
        except ValidationError:
            await self._safe_answer_callback_query(
                query,
                "❌ Некорректные данные запроса.",
                show_alert=True,
            )
        except NotFoundError:
            await self._safe_answer_callback_query(
                query,
                "❌ Код не найден или больше недоступен.",
                show_alert=True,
            )
        except ServiceError:
            await self._safe_answer_callback_query(
                query,
                "❌ Ошибка при обновлении кода.",
                show_alert=True,
            )

    async def application_error_handler(
        self,
        update: object,
        context: CallbackContext,
    ) -> None:
        error = context.error
        if isinstance(error, Conflict):
            logger.error(
                "Telegram 409 Conflict: обнаружен второй инстанс бота с этим же "
                "токеном. Останавливаю текущий polling."
            )
            context.application.stop_running()
            return

        if isinstance(error, TimedOut):
            logger.warning("Telegram API timeout: %s", error)
            return

        logger.exception("Unhandled telegram application error", exc_info=error)

    async def _deliver_notification(
        self,
        pending: PendingTelegramNotification,
        *,
        context: CallbackContext,
    ) -> bool:
        text = f"{pending.title}\n\n{pending.body}".strip()
        try:
            await context.bot.send_message(
                chat_id=pending.telegram_id,
                text=text,
            )
            self.notification_repository.mark_sent(pending.notification_id)
            return True
        except Exception:
            logger.exception(
                "Failed to deliver notification_id=%s to telegram_id=%s",
                pending.notification_id,
                pending.telegram_id,
            )
            self.notification_repository.mark_failed(pending.notification_id)
            return False

    async def _drain_notifications_for_telegram_id(
        self,
        *,
        telegram_id: int,
        context: CallbackContext,
        silent_if_empty: bool,
    ) -> int:
        pending = self.notification_repository.fetch_pending_for_telegram_id(
            telegram_id=telegram_id,
            limit=20,
        )
        if not pending:
            return 0

        sent_count = 0
        for item in pending:
            if await self._deliver_notification(item, context=context):
                sent_count += 1

        if not silent_if_empty and sent_count > 0:
            await context.bot.send_message(
                chat_id=telegram_id,
                text=f"✅ Отправлено уведомлений: {sent_count}",
            )
        return sent_count

    async def process_pending_notifications_job(self, context: CallbackContext) -> None:
        pending = self.notification_repository.fetch_pending_telegram_notifications(limit=50)
        if not pending:
            return
        for item in pending:
            await self._deliver_notification(item, context=context)

    def run(self) -> None:
        logger.info("Bot is starting...")
        if self.application.job_queue is not None:
            self.application.job_queue.run_repeating(
                self.process_pending_notifications_job,
                interval=self.config.notification_poll_seconds,
                first=5,
            )
            logger.info(
                "Notification polling enabled: every %s seconds",
                self.config.notification_poll_seconds,
            )
        else:
            logger.warning("Job queue is unavailable: pending notifications polling is disabled")
        self.application.run_polling(drop_pending_updates=True)


def main() -> None:
    try:
        config = BotConfig.from_env()
    except ValueError as exc:
        print(f"Ошибка конфигурации: {exc}")
        return

    try:
        ensure_database_ready()
    except Exception as exc:
        print(f"Ошибка инициализации БД: {exc}")
        return

    auth_service = AuthService(
        repository=AuthRepository(),
        code_ttl_minutes=config.code_ttl_minutes,
    )
    notification_repository = NotificationRepository()

    bot = FlowerShopBot(
        config=config,
        auth_service=auth_service,
        notification_repository=notification_repository,
    )
    bot.run()


if __name__ == "__main__":
    main()
