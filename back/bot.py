import os
import sqlite3
import logging
import re
from datetime import datetime, timedelta
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackContext, CallbackQueryHandler
import random
from dotenv import load_dotenv

def main():
    load_dotenv()
    
    BOT_TOKEN = os.getenv('BOT_TOKEN')
    if not BOT_TOKEN:
        print("Ошибка: BOT_TOKEN не установлен в переменных окружения")
        print("Проверьте файл .env и наличие BOT_TOKEN")
        return

    DB_PATH = os.getenv('DATABASE_URL')
    if DB_PATH and DB_PATH.startswith('sqlite:///'):
        DB_PATH = DB_PATH.replace('sqlite:///', '')
    
    bot = FlowerShopBot(BOT_TOKEN, DB_PATH)
    bot.run()

logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

class FlowerShopBot:
    def __init__(self, token: str, db_path: str):
        self.token = token
        self.db_path = db_path
        self.application = Application.builder().token(token).build()
        
        self.application.add_handler(CommandHandler("start", self.start_handler))
        self.application.add_handler(CommandHandler("help", self.help_handler))
        self.application.add_handler(CommandHandler("auth", self.auth_handler))
        self.application.add_handler(CallbackQueryHandler(self.button_handler))
        
    def get_db_connection(self):
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def generate_auth_code(self):
        while True:
            code = str(random.randint(1000, 9999))
            conn = self.get_db_connection()
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(*) FROM oauth_codes WHERE code = ? AND used = 0", (code,))
            count = cursor.fetchone()[0]
            conn.close()
            if count == 0:
                return code

    def validate_device_id(self, device_id: str) -> bool:
        """валидация device_id"""
        if not device_id or len(device_id) > 255:
            return False
        # только буквы, цифры + безопасные символы
        if not re.match(r'^[a-zA-Z0-9_\-.:]+$', device_id):
            return False
        return True

    def escape_markdown(self, text: str) -> str:
        """экранируе спецсимволы MarkdownV2"""
        escape_chars = r'_*[]()~`>#+-=|{}.!'
        return ''.join(f'\\{char}' if char in escape_chars else char for char in text)

    async def start_handler(self, update: Update, context: CallbackContext):
        user = update.effective_user
        args = context.args
        
        if args:
            device_id = args[0]
            
            # валидация device_id
            if not self.validate_device_id(device_id):
                await update.message.reply_text(
                    "❌ Неверный формат идентификатора устройства.\n"
                    "Используйте ссылку из мобильного приложения."
                )
                return
                
            await self.process_device_auth(update, context, device_id, user)
        else:
            keyboard = [
                [InlineKeyboardButton("🔐 Авторизация", callback_data="auth_help")],
                [InlineKeyboardButton("❓ Помощь", callback_data="help")]
            ]
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            await update.message.reply_text(
                f"👋 Привет, {user.first_name}!\n\n"
                "Я бот цветочного магазина 🌸\n"
                "Для авторизации в мобильном приложении используйте функцию авторизации.",
                reply_markup=reply_markup
            )

    async def process_device_auth(self, update: Update, context: CallbackContext, device_id: str, user):
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            # проверяем/создаем пользователя
            cursor.execute("SELECT * FROM users WHERE telegram_id = ?", (user.id,))
            existing_user = cursor.fetchone()
            
            if not existing_user:
                user_name = f"{user.first_name or ''} {user.last_name or ''}".strip() or user.username or "Пользователь"
                cursor.execute(
                    "INSERT INTO users (telegram_id, name, phone) VALUES (?, ?, ?)",
                    (user.id, user_name, "")
                )
                user_id = cursor.lastrowid
            else:
                user_id = existing_user['id']
            
            # проверяем активный код/сессию устройства и пользователя
            cursor.execute(
                """SELECT * FROM oauth_codes 
                WHERE telegram_id = ? AND device_id = ? AND used = 0 AND expires_at > datetime('now')""",
                (user.id, device_id)
            )
            existing_code = cursor.fetchone()
            
            if existing_code:
                auth_code = existing_code['code']
                logger.info(f"Using existing code {auth_code} for user {user.id} and device {device_id}")
            else:
                auth_code = self.generate_auth_code()
                
                # удаляем старые записи устройства и пользователя
                cursor.execute(
                    "DELETE FROM oauth_codes WHERE telegram_id = ? AND device_id = ? AND used = 0",
                    (user.id, device_id)
                )
                
                # сохраняем код в бд
                cursor.execute(
                    """INSERT INTO oauth_codes 
                    (telegram_id, device_id, code, expires_at, used) 
                    VALUES (?, ?, ?, datetime('now', '+10 minutes'), 0)""",
                    (user.id, device_id, auth_code)
                )
                logger.info(f"Generated new code {auth_code} for user {user.id} and device {device_id}")
            
            conn.commit()
            conn.close()
            
            role_text = await self.get_user_role_text(user.id)
            
            keyboard = [
                [InlineKeyboardButton("🔄 Обновить код", callback_data=f"refresh_{device_id}")],
                [InlineKeyboardButton("❓ Помощь", callback_data="help")]
            ]
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            await update.message.reply_text(
                f"✅ *Код подтверждения сгенерирован\\!*\n\n"
                f"{role_text}\n"
                f"📱 Device ID: `{self.escape_markdown(device_id)}`\n"
                f"🔢 Код подтверждения: `{auth_code}`\n"
                f"⏰ Действует 10 минут\n\n"
                f"Введите этот код в мобильном приложении для завершения авторизации\\.",
                parse_mode='MarkdownV2',
                reply_markup=reply_markup
            )
            
        except Exception as e:
            logger.error(f"Error processing device auth: {e}")
            await update.message.reply_text(
                "❌ Произошла ошибка при генерации кода. Попробуйте еще раз."
            )

    async def refresh_auth_code(self, update: Update, context: CallbackContext, device_id: str, user):
        """Обновляет код подтверждения для существующей пары пользователь-устройство"""
        try:
            query = update.callback_query
            await query.answer()
            
            # валидация device_id из callback
            if not self.validate_device_id(device_id):
                await query.answer("❌ Неверный идентификатор устройства", show_alert=True)
                return
            
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            new_auth_code = self.generate_auth_code()
            
            # обновляем запись
            cursor.execute(
                """UPDATE oauth_codes 
                SET code = ?, expires_at = datetime('now', '+10 minutes'), used = 0
                WHERE telegram_id = ? AND device_id = ?""",
                (new_auth_code, user.id, device_id)
            )
            
            if cursor.rowcount == 0:
                # записи не было - создаем новую
                cursor.execute(
                    """INSERT INTO oauth_codes 
                    (telegram_id, device_id, code, expires_at, used) 
                    VALUES (?, ?, ?, datetime('now', '+10 minutes'), 0)""",
                    (user.id, device_id, new_auth_code)
                )
            
            conn.commit()
            conn.close()
            
            role_text = await self.get_user_role_text(user.id)
            
            keyboard = [
                [InlineKeyboardButton("🔄 Обновить код", callback_data=f"refresh_{device_id}")],
                [InlineKeyboardButton("❓ Помощь", callback_data="help")]
            ]
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            await query.edit_message_text(
                f"✅ *Код подтверждения обновлен\\!*\n\n"
                f"{role_text}\n"
                f"📱 Device ID: `{self.escape_markdown(device_id)}`\n"
                f"🔢 Новый код: `{new_auth_code}`\n"
                f"⏰ Действует 10 минут\n\n"
                f"Введите этот код в мобильном приложении для завершения авторизации\\.",
                parse_mode='MarkdownV2',
                reply_markup=reply_markup
            )
            
            logger.info(f"Refreshed code to {new_auth_code} for user {user.id} and device {device_id}")
            
        except Exception as e:
            logger.error(f"Error refreshing auth code: {e}")
            await update.callback_query.answer(
                "❌ Ошибка при обновлении кода. Попробуйте еще раз.",
                show_alert=True
            )

    async def get_user_role_text(self, telegram_id):
        """текстовое представление роли пользователя"""
        conn = self.get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute(
            """SELECT e.*, p.title as position_title 
            FROM employees e 
            LEFT JOIN positions p ON e.position_id = p.id 
            WHERE e.telegram_id = ? AND e.is_active = 1""",
            (telegram_id,)
        )
        employee_info = cursor.fetchone()
        conn.close()
        
        if employee_info:
            return f"👔 *Сотрудник* \\({self.escape_markdown(employee_info['position_title'])}\\)"
        else:
            return "👤 *Клиент*"

    async def auth_handler(self, update: Update, context: CallbackContext):
        args = context.args
        user = update.effective_user
        
        if args:
            if len(args) >= 2:
                code = args[0]
                device_id = args[1]
                
                # Валидация входных данных
                if not self.validate_device_id(device_id):
                    await update.message.reply_text("❌ Неверный формат идентификатора устройства.")
                    return
                    
                if not re.match(r'^\d{4}$', code):
                    await update.message.reply_text("❌ Код должен состоять из 4 цифр.")
                    return
                    
                await self.process_manual_auth(update, context, code, device_id, user)
            else:
                await update.message.reply_text(
                    "❌ Неверный формат. Используйте:\n"
                    "`/auth КОД DEVICE_ID`",
                    parse_mode='Markdown'
                )
        else:
            await update.message.reply_text(
                "🔐 *Авторизация в мобильном приложении*\n\n"
                "Чтобы авторизоваться:\n"
                "1\\. Откройте мобильное приложение\n"
                "2\\. Нажмите 'Войти через Telegram'\n"
                "3\\. Используйте полученную ссылку\n\n"
                "Или введите команду:\n"
                "`/auth КОД DEVICE_ID`\n\n"
                "🔗 *Формат ссылки:*\n"
                "`https://t\\.me/for_the_future_bot?start=DEVICE_ID`",
                parse_mode='MarkdownV2'
            )

    async def process_manual_auth(self, update: Update, context: CallbackContext, code: str, device_id: str, user):
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute("SELECT * FROM users WHERE telegram_id = ?", (user.id,))
            existing_user = cursor.fetchone()
            
            if not existing_user:
                user_name = f"{user.first_name or ''} {user.last_name or ''}".strip() or user.username or "Пользователь"
                cursor.execute(
                    "INSERT INTO users (telegram_id, name, phone) VALUES (?, ?, ?)",
                    (user.id, user_name, "")
                )
                user_id = cursor.lastrowid
            
            # проверяем код
            cursor.execute(
                "SELECT * FROM oauth_codes WHERE code = ? AND device_id = ?",
                (code, device_id)
            )
            existing_code = cursor.fetchone()
            
            if existing_code:
                if existing_code['telegram_id'] is not None and existing_code['telegram_id'] != user.id:
                    await update.message.reply_text(
                        "❌ Этот код уже был использован другим пользователем."
                    )
                    conn.close()
                    return
                
                cursor.execute(
                    """UPDATE oauth_codes 
                    SET telegram_id = ?, expires_at = datetime('now', '+10 minutes')
                    WHERE code = ? AND device_id = ?""",
                    (user.id, code, device_id)
                )
            else:
                cursor.execute(
                    """INSERT INTO oauth_codes 
                    (telegram_id, device_id, code, expires_at, used) 
                    VALUES (?, ?, ?, datetime('now', '+10 minutes'), 0)""",
                    (user.id, device_id, code)
                )
            
            conn.commit()
            conn.close()
            
            role_text = await self.get_user_role_text(user.id)
            
            await update.message.reply_text(
                f"✅ *Авторизация успешна\\!*\n\n"
                f"{role_text}\n"
                f"📱 Код: `{code}`\n"
                f"⏰ Действует 10 минут\n\n"
                f"Вернитесь в мобильное приложение для завершения входа\\.",
                parse_mode='MarkdownV2'
            )
            
            logger.info(f"User {user.id} successfully linked code {code} for device {device_id}")
            
        except Exception as e:
            logger.error(f"Error processing manual auth: {e}")
            await update.message.reply_text(
                "❌ Произошла ошибка при обработке кода. Попробуйте еще раз."
            )

    async def help_handler(self, update: Update, context: CallbackContext):
        help_text = (
            "🌸 *Цветочный магазин \\- Помощь*\n\n"
            "🔐 *Авторизация в приложении:*\n"
            "1\\. Откройте мобильное приложение\n"
            "2\\. Нажмите 'Войти через Telegram'\n"
            "3\\. Используйте полученную ссылку\n\n"
            "📱 *Доступные команды:*\n"
            "/start \\- Начать работу с ботом\n"
            "/auth КОД DEVICE_ID \\- Ручная авторизация\n"
            "/help \\- Показать эту справку\n\n"
            "🔗 *Формат ссылки:*\n"
            "`https://t\\.me/for_the_future_bot?start=DEVICE_ID`\n\n"
            "❓ *Проблемы с авторизацией\\?*\n"
            "Убедитесь, что:\n"
            "• Используете актуальную ссылку из приложения\n"
            "• Код состоит из 4 цифр\n"
            "• Ссылка не была использована ранее\n"
            "• Если код устарел, нажмите 'Обновить код'"
        )
        
        await update.message.reply_text(help_text, parse_mode='MarkdownV2')

    async def button_handler(self, update: Update, context: CallbackContext):
        query = update.callback_query
        await query.answer()
        
        user = update.effective_user
        
        if query.data == "auth_help":
            await query.edit_message_text(
                "🔐 *Авторизация в мобильном приложении*\n\n"
                "Чтобы авторизоваться:\n"
                "1\\. Откройте мобильное приложение\n"
                "2\\. Нажмите 'Войти через Telegram'\n"
                "3\\. Используйте полученную ссылку\n\n"
                "Или введите команду:\n"
                "`/auth КОД DEVICE_ID`\n\n"
                "🔗 *Формат ссылки:*\n"
                "`https://t\\.me/for_the_future_bot?start=DEVICE_ID`",
                parse_mode='MarkdownV2'
            )
        elif query.data == "help":
            await self.help_handler(update, context)
        elif query.data.startswith("refresh_"):
            device_id = query.data[8:]
            
            # валидация device_id из callback_data
            if not self.validate_device_id(device_id):
                await query.answer("❌ Неверный идентификатор устройства", show_alert=True)
                return
                
            await self.refresh_auth_code(update, context, device_id, user)

    def run(self):
        logger.info("Bot is starting...")
        self.application.run_polling()

if __name__ == '__main__':
    main()