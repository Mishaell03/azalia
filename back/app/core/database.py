import os
import sqlite3
from pathlib import Path
from dotenv import load_dotenv
from typing import Optional

# загружаем .env из корня
BASE_DIR = Path(__file__).resolve().parents[2]
load_dotenv(BASE_DIR / ".env")

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///flower_shop.db")


def _get_db_path(url: str) -> Path:
    if url.startswith("sqlite:///"):
        return BASE_DIR / url.replace("sqlite:///", "")
    return BASE_DIR / url


DB_PATH = _get_db_path(DATABASE_URL)


def get_connection() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row

    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA synchronous = NORMAL")
    conn.execute("PRAGMA busy_timeout = 5000")

    return conn


def create_database() -> None:
    """
    Создает таблицы, индексы, представления и триггеры.
    Повторный запуск безопасен.
    """
    conn = get_connection()
    cur = conn.cursor()

    cur.executescript(
        """
        
        -- СПРАВОЧНИКИ
        
        CREATE TABLE IF NOT EXISTS stores (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            name                TEXT NOT NULL UNIQUE,
            address             TEXT NOT NULL,
            phone               TEXT,
            email               TEXT,
            store_type          TEXT NOT NULL DEFAULT 'shop'
                                CHECK(store_type IN ('shop', 'warehouse', 'pickup_point')),
            is_active           INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
            created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS positions (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            title               TEXT NOT NULL UNIQUE,
            description         TEXT,
            created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS suppliers (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            name                TEXT NOT NULL UNIQUE,
            contact_person      TEXT,
            phone               TEXT,
            email               TEXT,
            address             TEXT,
            is_active           INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
            created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS categories (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            name                TEXT NOT NULL UNIQUE,
            parent_id           INTEGER,
            created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE SET NULL
        );

        CREATE TABLE IF NOT EXISTS plant_types (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            name                TEXT NOT NULL UNIQUE,
            created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS pot_sizes (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            name                TEXT NOT NULL UNIQUE,
            diameter_cm         INTEGER CHECK(diameter_cm > 0),
            height_cm           INTEGER CHECK(height_cm > 0),
            created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS pot_materials (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            name                TEXT NOT NULL UNIQUE,
            created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS pot_colors (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            name                TEXT NOT NULL UNIQUE,
            hex_code            TEXT,
            created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS payment_methods (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            code                TEXT NOT NULL UNIQUE,
            name                TEXT NOT NULL UNIQUE,
            is_active           INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
            created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        
        -- ПОЛЬЗОВАТЕЛИ / ПРОФИЛЬ / ВХОД
        
        CREATE TABLE IF NOT EXISTS users (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            telegram_id         INTEGER NOT NULL UNIQUE,
            full_name           TEXT NOT NULL,
            phone               TEXT NOT NULL,
            avatar_url          TEXT,
            status              TEXT NOT NULL DEFAULT 'active'
                                CHECK(status IN ('active', 'blocked', 'deleted')),
            blocked_at          TEXT,
            blocked_reason      TEXT,
            deleted_at          TEXT,
            created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS user_addresses (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id             INTEGER NOT NULL,
            address             TEXT NOT NULL,
            comment             TEXT,
            is_default          INTEGER NOT NULL DEFAULT 0 CHECK(is_default IN (0, 1)),
            created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS auth_codes (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id             INTEGER NOT NULL,
            device_id           TEXT,
            code                TEXT NOT NULL,
            expires_at          TEXT NOT NULL,
            used_at             TEXT,
            created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS user_sessions (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id             INTEGER NOT NULL,
            device_id           TEXT,
            session_token       TEXT NOT NULL UNIQUE,
            refresh_token       TEXT UNIQUE,
            device_name         TEXT,
            platform            TEXT,
            ip_address          TEXT,
            user_agent          TEXT,
            is_active           INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
            expires_at          TEXT NOT NULL,
            last_seen_at        TEXT,
            revoked_at          TEXT,
            revoke_reason       TEXT,
            created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        );

        
        -- ПОДПИСКИ / КОМПАНИИ
        
        CREATE TABLE IF NOT EXISTS subscription_plans (
            id                      INTEGER PRIMARY KEY AUTOINCREMENT,
            code                    TEXT NOT NULL UNIQUE,
            name                    TEXT NOT NULL UNIQUE,
            monthly_price           REAL NOT NULL CHECK(monthly_price >= 0),
            yearly_price            REAL NOT NULL CHECK(yearly_price >= 0),
            description             TEXT,
            features_json           TEXT NOT NULL DEFAULT '[]',
            max_plants              INTEGER NOT NULL DEFAULT 1 CHECK(max_plants >= 1),
            notifications           TEXT NOT NULL DEFAULT 'basic',
            has_corporate           INTEGER NOT NULL DEFAULT 0 CHECK(has_corporate IN (0, 1)),
            has_analytics           INTEGER NOT NULL DEFAULT 0 CHECK(has_analytics IN (0, 1)),
            max_members             INTEGER NOT NULL DEFAULT 1 CHECK(max_members >= 1),
            can_create_company      INTEGER NOT NULL DEFAULT 0 CHECK(can_create_company IN (0, 1)),
            has_extended_features   INTEGER NOT NULL DEFAULT 0 CHECK(has_extended_features IN (0, 1)),
            is_active               INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
            created_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS companies (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            name                TEXT NOT NULL UNIQUE,
            owner_user_id       INTEGER NOT NULL,
            description         TEXT,
            contact_phone       TEXT,
            contact_email       TEXT,
            address             TEXT,
            status              TEXT NOT NULL DEFAULT 'active'
                                CHECK(status IN ('active', 'blocked', 'deleted')),
            created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE RESTRICT
        );

        CREATE TABLE IF NOT EXISTS company_members (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            company_id          INTEGER NOT NULL,
            user_id             INTEGER NOT NULL,
            role                TEXT NOT NULL DEFAULT 'member'
                                CHECK(role IN ('owner', 'admin', 'member')),
            is_active           INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
            created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(company_id, user_id),
            FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS company_role_history (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            company_id          INTEGER NOT NULL,
            user_id             INTEGER NOT NULL,
            old_role            TEXT,
            new_role            TEXT NOT NULL,
            changed_by_user_id  INTEGER,
            created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (changed_by_user_id) REFERENCES users(id) ON DELETE SET NULL
        );

        CREATE TABLE IF NOT EXISTS subscriptions (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            plan_id             INTEGER NOT NULL,
            user_id             INTEGER,
            company_id          INTEGER,
            billing_period      TEXT NOT NULL CHECK(billing_period IN ('monthly', 'yearly')),
            status              TEXT NOT NULL DEFAULT 'active'
                                CHECK(status IN ('active', 'past_due', 'blocked', 'cancelled', 'deleted')),
            auto_renew          INTEGER NOT NULL DEFAULT 1 CHECK(auto_renew IN (0, 1)),
            starts_at           TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            expires_at          TEXT NOT NULL,
            blocked_at          TEXT,
            delete_after_at     TEXT,
            created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            CHECK (
                (user_id IS NOT NULL AND company_id IS NULL)
                OR
                (user_id IS NULL AND company_id IS NOT NULL)
            ),
            FOREIGN KEY (plan_id) REFERENCES subscription_plans(id) ON DELETE RESTRICT,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS subscription_payment_links (
            id                      INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id                 INTEGER NOT NULL,
            plan_id                 INTEGER NOT NULL,
            billing_period          TEXT NOT NULL CHECK(billing_period IN ('monthly', 'yearly')),
            amount                  REAL NOT NULL CHECK(amount >= 0),
            status                  TEXT NOT NULL DEFAULT 'pending'
                                    CHECK(status IN ('pending', 'paid', 'failed', 'cancelled')),
            payment_url             TEXT NOT NULL,
            external_payment_id     TEXT,
            subscription_id         INTEGER,
            auto_renew_enabled      INTEGER NOT NULL DEFAULT 1 CHECK(auto_renew_enabled IN (0, 1)),
            created_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            paid_at                 TEXT,
            failed_at               TEXT,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (plan_id) REFERENCES subscription_plans(id) ON DELETE RESTRICT,
            FOREIGN KEY (subscription_id) REFERENCES subscriptions(id) ON DELETE SET NULL
        );

        
        -- КАТАЛОГ
        
        CREATE TABLE IF NOT EXISTS products (
            id                      INTEGER PRIMARY KEY AUTOINCREMENT,
            sku                     TEXT UNIQUE,
            name                    TEXT NOT NULL,
            description             TEXT,
            category_id             INTEGER NOT NULL,
            plant_type_id           INTEGER NOT NULL,
            supplier_id             INTEGER,
            base_price              REAL NOT NULL CHECK(base_price >= 0),
            cost_price              REAL NOT NULL DEFAULT 0 CHECK(cost_price >= 0),
            recommended_pot_size_id INTEGER,
            height_cm               INTEGER CHECK(height_cm >= 0),
            light_requirements      TEXT CHECK(light_requirements IN ('full_sun', 'partial_shade', 'shade')),
            watering_notes          TEXT,
            care_instructions       TEXT,
            image_url               TEXT,
            rating                  REAL NOT NULL DEFAULT 0 CHECK(rating >= 0 AND rating <= 5),
            is_active               INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
            deleted_at              TEXT,
            created_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE RESTRICT,
            FOREIGN KEY (plant_type_id) REFERENCES plant_types(id) ON DELETE RESTRICT,
            FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL,
            FOREIGN KEY (recommended_pot_size_id) REFERENCES pot_sizes(id) ON DELETE SET NULL
        );

        CREATE TABLE IF NOT EXISTS product_images (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id          INTEGER NOT NULL,
            image_url           TEXT NOT NULL,
            created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(product_id, image_url),
            FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS pot_prices (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            size_id             INTEGER NOT NULL,
            material_id         INTEGER NOT NULL,
            price               REAL NOT NULL CHECK(price >= 0),
            UNIQUE(size_id, material_id),
            FOREIGN KEY (size_id) REFERENCES pot_sizes(id) ON DELETE CASCADE,
            FOREIGN KEY (material_id) REFERENCES pot_materials(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS pot_variant_prices (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            size_id             INTEGER NOT NULL,
            material_id         INTEGER NOT NULL,
            color_id            INTEGER NOT NULL,
            price               REAL NOT NULL CHECK(price >= 0),
            is_active           INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
            UNIQUE(size_id, material_id, color_id),
            FOREIGN KEY (size_id) REFERENCES pot_sizes(id) ON DELETE CASCADE,
            FOREIGN KEY (material_id) REFERENCES pot_materials(id) ON DELETE CASCADE,
            FOREIGN KEY (color_id) REFERENCES pot_colors(id) ON DELETE CASCADE
        );

        
        -- ИЗБРАННОЕ / КОРЗИНА
        
        CREATE TABLE IF NOT EXISTS wishlist_items (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id             INTEGER NOT NULL,
            product_id          INTEGER NOT NULL,
            pot_size            TEXT,
            pot_material        TEXT,
            pot_color           TEXT,
            created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(user_id, product_id),
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS cart_items (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id             INTEGER NOT NULL,
            product_id          INTEGER NOT NULL,
            quantity            INTEGER NOT NULL CHECK(quantity > 0),
            pot_size_id         INTEGER,
            pot_material_id     INTEGER,
            pot_color_id        INTEGER,
            product_unit_price  REAL NOT NULL CHECK(product_unit_price >= 0),
            pot_unit_price      REAL NOT NULL DEFAULT 0 CHECK(pot_unit_price >= 0),
            total_price         REAL NOT NULL CHECK(total_price >= 0),
            created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(user_id, product_id, pot_size_id, pot_material_id, pot_color_id),
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
            FOREIGN KEY (pot_size_id) REFERENCES pot_sizes(id) ON DELETE SET NULL,
            FOREIGN KEY (pot_material_id) REFERENCES pot_materials(id) ON DELETE SET NULL,
            FOREIGN KEY (pot_color_id) REFERENCES pot_colors(id) ON DELETE SET NULL
        );

        CREATE TABLE IF NOT EXISTS procurement_cart_items (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id             INTEGER NOT NULL,
            store_id            INTEGER NOT NULL,
            product_id          INTEGER NOT NULL,
            quantity            INTEGER NOT NULL CHECK(quantity > 0),
            created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(user_id, store_id, product_id),
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
        );

        
        -- СОТРУДНИКИ / УПРАВЛЕНИЕ ПОЛЬЗОВАТЕЛЯМИ
        
        CREATE TABLE IF NOT EXISTS employees (
            id                      INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id                 INTEGER NOT NULL UNIQUE,
            position_id             INTEGER NOT NULL,
            store_id                INTEGER NOT NULL,
            salary                  REAL CHECK(salary >= 0),
            hired_at                TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            fired_at                TEXT,
            is_active               INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
            created_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (position_id) REFERENCES positions(id) ON DELETE RESTRICT,
            FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE RESTRICT
        );

        CREATE TABLE IF NOT EXISTS user_status_history (
            id                      INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id                 INTEGER NOT NULL,
            old_status              TEXT,
            new_status              TEXT NOT NULL,
            changed_by_employee_id  INTEGER,
            reason                  TEXT,
            created_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (changed_by_employee_id) REFERENCES employees(id) ON DELETE SET NULL
        );

        
        -- ЗАКАЗЫ / ИСТОРИЯ ПОКУПОК / ПЛАТЕЖИ / ВОЗВРАТЫ
        
        CREATE TABLE IF NOT EXISTS orders (
            id                      INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id                 INTEGER NOT NULL,
            company_id              INTEGER,
            store_id                INTEGER NOT NULL,
            order_number            TEXT NOT NULL UNIQUE,
            order_type              TEXT NOT NULL CHECK(order_type IN ('delivery', 'pickup')),
            address_id              INTEGER,
            address_snapshot        TEXT,
            comment                 TEXT,
            subtotal                REAL NOT NULL DEFAULT 0 CHECK(subtotal >= 0),
            delivery_fee            REAL NOT NULL DEFAULT 0 CHECK(delivery_fee >= 0),
            discount_amount         REAL NOT NULL DEFAULT 0 CHECK(discount_amount >= 0),
            total_price             REAL NOT NULL DEFAULT 0 CHECK(total_price >= 0),
            payment_status          TEXT NOT NULL DEFAULT 'pending'
                                    CHECK(payment_status IN ('pending', 'paid', 'failed', 'refunded', 'partially_refunded')),
            status                  TEXT NOT NULL DEFAULT 'new'
                                    CHECK(status IN (
                                        'new',
                                        'awaiting_payment',
                                        'processing',
                                        'assembled',
                                        'shipped',
                                        'ready_for_pickup',
                                        'delivered',
                                        'completed',
                                        'cancelled'
                                    )),
            assigned_employee_id    INTEGER,
            created_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
            FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE SET NULL,
            FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE RESTRICT,
            FOREIGN KEY (address_id) REFERENCES user_addresses(id) ON DELETE SET NULL,
            FOREIGN KEY (assigned_employee_id) REFERENCES employees(id) ON DELETE SET NULL
        );

        CREATE TABLE IF NOT EXISTS order_items (
            id                          INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id                    INTEGER NOT NULL,
            product_id                  INTEGER,
            product_name_snapshot       TEXT NOT NULL,
            product_description_snapshot TEXT,
            quantity                    INTEGER NOT NULL CHECK(quantity > 0),
            product_unit_price          REAL NOT NULL CHECK(product_unit_price >= 0),
            product_cost_price          REAL NOT NULL DEFAULT 0 CHECK(product_cost_price >= 0),
            pot_size_id                 INTEGER,
            pot_material_id             INTEGER,
            pot_color_id                INTEGER,
            pot_unit_price              REAL NOT NULL DEFAULT 0 CHECK(pot_unit_price >= 0),
            discount_amount             REAL NOT NULL DEFAULT 0 CHECK(discount_amount >= 0),
            total_price                 REAL NOT NULL CHECK(total_price >= 0),
            returned_quantity           INTEGER NOT NULL DEFAULT 0
                                        CHECK(returned_quantity >= 0 AND returned_quantity <= quantity),
            created_at                  TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL,
            FOREIGN KEY (pot_size_id) REFERENCES pot_sizes(id) ON DELETE SET NULL,
            FOREIGN KEY (pot_material_id) REFERENCES pot_materials(id) ON DELETE SET NULL,
            FOREIGN KEY (pot_color_id) REFERENCES pot_colors(id) ON DELETE SET NULL
        );

        CREATE TABLE IF NOT EXISTS order_status_history (
            id                      INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id                INTEGER NOT NULL,
            old_status              TEXT,
            new_status              TEXT NOT NULL,
            changed_by_employee_id  INTEGER,
            created_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
            FOREIGN KEY (changed_by_employee_id) REFERENCES employees(id) ON DELETE SET NULL
        );

        CREATE TABLE IF NOT EXISTS payments (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id            INTEGER NOT NULL,
            user_id             INTEGER NOT NULL,
            payment_method_id   INTEGER,
            amount              REAL NOT NULL CHECK(amount >= 0),
            status              TEXT NOT NULL CHECK(status IN ('pending', 'authorized', 'paid', 'failed', 'refunded')),
            external_payment_id TEXT,
            paid_at             TEXT,
            failed_at           TEXT,
            created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE SET NULL
        );

        CREATE TABLE IF NOT EXISTS refunds (
            id                          INTEGER PRIMARY KEY AUTOINCREMENT,
            payment_id                  INTEGER NOT NULL,
            amount                      REAL NOT NULL CHECK(amount >= 0),
            reason                      TEXT,
            status                      TEXT NOT NULL DEFAULT 'pending'
                                        CHECK(status IN ('pending', 'processed', 'failed')),
            processed_by_employee_id    INTEGER,
            processed_at                TEXT,
            created_at                  TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE CASCADE,
            FOREIGN KEY (processed_by_employee_id) REFERENCES employees(id) ON DELETE SET NULL
        );

        
        -- КАЛЕНДАРЬ И РАСТЕНИЯ ПОЛЬЗОВАТЕЛЯ
        
        CREATE TABLE IF NOT EXISTS calendar_events (
            id                      INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id                 INTEGER NOT NULL,
            event_date              TEXT NOT NULL,
            event_time              TEXT,
            title                   TEXT NOT NULL,
            description             TEXT,
            is_all_day              INTEGER NOT NULL DEFAULT 0 CHECK(is_all_day IN (0, 1)),
            reminder_enabled        INTEGER NOT NULL DEFAULT 1 CHECK(reminder_enabled IN (0, 1)),
            reminder_minutes_before INTEGER,
            created_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS user_plants (
            id                          INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id                     INTEGER NOT NULL,
            product_id                  INTEGER,
            custom_name                 TEXT,
            plant_name                  TEXT NOT NULL,
            photo_url                   TEXT,
            watering_requirement        TEXT,
            light_requirements          TEXT CHECK(light_requirements IN ('full_sun', 'partial_shade', 'shade')),
            watering_frequency_days     INTEGER,
            soil_change_frequency_days  INTEGER,
            pot_size_text               TEXT,
            notes                       TEXT,
            last_watered_at             TEXT,
            next_watering_at            TEXT,
            last_repot_at               TEXT,
            next_repot_at               TEXT,
            last_soil_change_at         TEXT,
            next_soil_change_at         TEXT,
            created_at                  TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at                  TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL
        );

        CREATE TABLE IF NOT EXISTS user_plant_care_logs (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            user_plant_id       INTEGER NOT NULL,
            care_type           TEXT NOT NULL CHECK(care_type IN ('watering', 'repotting', 'soil_change')),
            care_at             TEXT NOT NULL,
            notes               TEXT,
            created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_plant_id) REFERENCES user_plants(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS user_important_dates (
            id                      INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id                 INTEGER NOT NULL,
            title                   TEXT NOT NULL,
            event_date              TEXT NOT NULL,
            comment                 TEXT,
            created_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS user_holiday_preferences (
            id                      INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id                 INTEGER NOT NULL,
            holiday_code            TEXT NOT NULL
                                    CHECK(holiday_code IN ('new_year', 'march_8')),
            category_id             INTEGER,
            product_id              INTEGER,
            created_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            CHECK (
                (category_id IS NOT NULL AND product_id IS NULL)
                OR
                (category_id IS NULL AND product_id IS NOT NULL)
            ),
            UNIQUE(user_id, holiday_code, category_id, product_id),
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS user_important_date_preferences (
            id                      INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id                 INTEGER NOT NULL,
            important_date_id       INTEGER NOT NULL,
            category_id             INTEGER,
            product_id              INTEGER,
            created_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            CHECK (
                (category_id IS NOT NULL AND product_id IS NULL)
                OR
                (category_id IS NULL AND product_id IS NOT NULL)
            ),
            UNIQUE(user_id, important_date_id, category_id, product_id),
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (important_date_id) REFERENCES user_important_dates(id) ON DELETE CASCADE,
            FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS user_plant_care_dates (
            id                      INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id                 INTEGER NOT NULL,
            user_plant_id           INTEGER,
            product_id              INTEGER,
            plant_name              TEXT NOT NULL,
            plant_photo_url         TEXT,
            watering_requirement    TEXT,
            care_type               TEXT NOT NULL CHECK(care_type IN (
                                        'watering',
                                        'soil_change',
                                        'fertilizing',
                                        'repotting',
                                        'pruning'
                                    )),
            care_date               TEXT NOT NULL,
            comment                 TEXT,
            is_done                 INTEGER NOT NULL DEFAULT 0 CHECK(is_done IN (0, 1)),
            created_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (user_plant_id) REFERENCES user_plants(id) ON DELETE SET NULL,
            FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL
        );

        CREATE TABLE IF NOT EXISTS company_calendar_events (
            id                      INTEGER PRIMARY KEY AUTOINCREMENT,
            company_id              INTEGER NOT NULL,
            title                   TEXT NOT NULL,
            event_date              TEXT NOT NULL,
            comment                 TEXT,
            created_by_user_id      INTEGER NOT NULL,
            created_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
            FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS company_calendar_event_preferences (
            id                      INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id                 INTEGER NOT NULL,
            company_event_id        INTEGER NOT NULL,
            category_id             INTEGER,
            product_id              INTEGER,
            created_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            CHECK (
                (category_id IS NOT NULL AND product_id IS NULL)
                OR
                (category_id IS NULL AND product_id IS NOT NULL)
            ),
            UNIQUE(user_id, company_event_id, category_id, product_id),
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (company_event_id) REFERENCES company_calendar_events(id) ON DELETE CASCADE,
            FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
        );

        
        -- СКЛАД / СПИСАНИЯ / ДВИЖЕНИЕ
        
        CREATE TABLE IF NOT EXISTS inventory (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            store_id            INTEGER NOT NULL,
            product_id          INTEGER NOT NULL,
            quantity_on_hand    INTEGER NOT NULL DEFAULT 0 CHECK(quantity_on_hand >= 0),
            quantity_reserved   INTEGER NOT NULL DEFAULT 0 CHECK(quantity_reserved >= 0),
            quantity_available  INTEGER NOT NULL DEFAULT 0 CHECK(quantity_available >= 0),
            reorder_point       INTEGER NOT NULL DEFAULT 0 CHECK(reorder_point >= 0),
            updated_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(store_id, product_id),
            FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS inventory_movements (
            id                      INTEGER PRIMARY KEY AUTOINCREMENT,
            store_id                INTEGER NOT NULL,
            product_id              INTEGER NOT NULL,
            movement_type           TEXT NOT NULL CHECK(movement_type IN (
                                        'purchase_receipt',
                                        'sale',
                                        'sale_return',
                                        'writeoff',
                                        'adjustment',
                                        'reservation',
                                        'reservation_release',
                                        'transfer_in',
                                        'transfer_out'
                                    )),
            quantity                INTEGER NOT NULL CHECK(quantity > 0),
            unit_cost               REAL CHECK(unit_cost >= 0),
            related_order_id        INTEGER,
            created_by_employee_id  INTEGER,
            comment                 TEXT,
            created_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
            FOREIGN KEY (related_order_id) REFERENCES orders(id) ON DELETE SET NULL,
            FOREIGN KEY (created_by_employee_id) REFERENCES employees(id) ON DELETE SET NULL
        );

        
        -- ЗАКУПКИ И ПРИЕМКА
        
        CREATE TABLE IF NOT EXISTS purchase_orders (
            id                      INTEGER PRIMARY KEY AUTOINCREMENT,
            supplier_id             INTEGER NOT NULL,
            store_id                INTEGER NOT NULL,
            created_by_employee_id  INTEGER,
            purchase_number         TEXT NOT NULL UNIQUE,
            status                  TEXT NOT NULL DEFAULT 'draft'
                                    CHECK(status IN ('draft', 'sent', 'partially_received', 'received', 'cancelled')),
            expected_delivery_at    TEXT,
            ordered_at              TEXT,
            received_at             TEXT,
            comment                 TEXT,
            total_amount            REAL NOT NULL DEFAULT 0 CHECK(total_amount >= 0),
            created_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE RESTRICT,
            FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE RESTRICT,
            FOREIGN KEY (created_by_employee_id) REFERENCES employees(id) ON DELETE SET NULL
        );

        CREATE TABLE IF NOT EXISTS purchase_order_items (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            purchase_order_id   INTEGER NOT NULL,
            product_id          INTEGER NOT NULL,
            ordered_quantity    INTEGER NOT NULL CHECK(ordered_quantity > 0),
            received_quantity   INTEGER NOT NULL DEFAULT 0 CHECK(received_quantity >= 0),
            rejected_quantity   INTEGER NOT NULL DEFAULT 0 CHECK(rejected_quantity >= 0),
            unit_cost           REAL NOT NULL CHECK(unit_cost >= 0),
            line_total          REAL NOT NULL CHECK(line_total >= 0),
            FOREIGN KEY (purchase_order_id) REFERENCES purchase_orders(id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
        );

        CREATE TABLE IF NOT EXISTS purchase_receipts (
            id                      INTEGER PRIMARY KEY AUTOINCREMENT,
            purchase_order_id       INTEGER NOT NULL,
            received_by_employee_id INTEGER,
            received_at             TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            comment                 TEXT,
            FOREIGN KEY (purchase_order_id) REFERENCES purchase_orders(id) ON DELETE CASCADE,
            FOREIGN KEY (received_by_employee_id) REFERENCES employees(id) ON DELETE SET NULL
        );

        CREATE TABLE IF NOT EXISTS purchase_receipt_items (
            id                      INTEGER PRIMARY KEY AUTOINCREMENT,
            purchase_receipt_id     INTEGER NOT NULL,
            purchase_order_item_id  INTEGER NOT NULL,
            accepted_quantity       INTEGER NOT NULL DEFAULT 0 CHECK(accepted_quantity >= 0),
            rejected_quantity       INTEGER NOT NULL DEFAULT 0 CHECK(rejected_quantity >= 0),
            reject_reason           TEXT,
            FOREIGN KEY (purchase_receipt_id) REFERENCES purchase_receipts(id) ON DELETE CASCADE,
            FOREIGN KEY (purchase_order_item_id) REFERENCES purchase_order_items(id) ON DELETE CASCADE
        );

        
        -- УВЕДОМЛЕНИЯ / РАССЫЛКИ
        
        CREATE TABLE IF NOT EXISTS notification_templates (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            code                TEXT NOT NULL UNIQUE,
            title               TEXT NOT NULL,
            body                TEXT NOT NULL,
            type                TEXT NOT NULL CHECK(type IN ('order', 'marketing', 'subscription', 'plant_care', 'system')),
            is_active           INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
            created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS notifications (
            id                      INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id                 INTEGER NOT NULL,
            template_id             INTEGER,
            type                    TEXT NOT NULL CHECK(type IN ('order', 'marketing', 'subscription', 'plant_care', 'system')),
            channel                 TEXT NOT NULL DEFAULT 'telegram' CHECK(channel IN ('telegram', 'push', 'email')),
            title                   TEXT NOT NULL,
            body                    TEXT NOT NULL,
            status                  TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'sent', 'failed', 'cancelled')),
            scheduled_at            TEXT,
            sent_at                 TEXT,
            related_order_id        INTEGER,
            related_user_plant_id   INTEGER,
            created_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (template_id) REFERENCES notification_templates(id) ON DELETE SET NULL,
            FOREIGN KEY (related_order_id) REFERENCES orders(id) ON DELETE SET NULL,
            FOREIGN KEY (related_user_plant_id) REFERENCES user_plants(id) ON DELETE SET NULL
        );

        CREATE TABLE IF NOT EXISTS marketing_campaigns (
            id                      INTEGER PRIMARY KEY AUTOINCREMENT,
            name                    TEXT NOT NULL,
            message                 TEXT NOT NULL,
            status                  TEXT NOT NULL DEFAULT 'draft'
                                    CHECK(status IN ('draft', 'scheduled', 'running', 'completed', 'cancelled')),
            scheduled_at            TEXT,
            created_by_employee_id  INTEGER,
            created_at              TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (created_by_employee_id) REFERENCES employees(id) ON DELETE SET NULL
        );
        """
    )

    def _ensure_column(table: str, column: str, definition_sql: str) -> None:
        cols = cur.execute(f"PRAGMA table_info({table})").fetchall()
        existing = {row["name"] for row in cols}
        if column not in existing:
            cur.execute(f"ALTER TABLE {table} ADD COLUMN {definition_sql}")

    # Backward-compatible migration for existing DBs.
    _ensure_column("wishlist_items", "pot_size", "pot_size TEXT")
    _ensure_column("wishlist_items", "pot_material", "pot_material TEXT")
    _ensure_column("wishlist_items", "pot_color", "pot_color TEXT")
    _ensure_column("subscription_plans", "description", "description TEXT")
    _ensure_column("subscription_plans", "features_json", "features_json TEXT NOT NULL DEFAULT '[]'")
    _ensure_column("subscription_plans", "max_plants", "max_plants INTEGER NOT NULL DEFAULT 1")
    _ensure_column("subscription_plans", "notifications", "notifications TEXT NOT NULL DEFAULT 'basic'")
    _ensure_column("subscription_plans", "has_corporate", "has_corporate INTEGER NOT NULL DEFAULT 0")
    _ensure_column("subscription_plans", "has_analytics", "has_analytics INTEGER NOT NULL DEFAULT 0")
    _ensure_column("companies", "description", "description TEXT")
    _ensure_column("companies", "contact_phone", "contact_phone TEXT")
    _ensure_column("companies", "contact_email", "contact_email TEXT")
    _ensure_column("companies", "address", "address TEXT")
    _ensure_column("user_plants", "photo_url", "photo_url TEXT")
    _ensure_column("user_plants", "watering_requirement", "watering_requirement TEXT")
    _ensure_column("user_plants", "soil_change_frequency_days", "soil_change_frequency_days INTEGER")
    _ensure_column("user_plant_care_dates", "user_plant_id", "user_plant_id INTEGER")
    _ensure_column("user_plant_care_dates", "plant_photo_url", "plant_photo_url TEXT")
    _ensure_column("user_plant_care_dates", "watering_requirement", "watering_requirement TEXT")

    # Subscription plans for mobile app (Free / Standard / Premium).
    cur.executemany(
        """
        INSERT INTO subscription_plans (
            id, code, name, monthly_price, yearly_price,
            description, features_json, max_plants, notifications,
            has_corporate, has_analytics,
            max_members, can_create_company, has_extended_features, is_active
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            code = excluded.code,
            name = excluded.name,
            monthly_price = excluded.monthly_price,
            yearly_price = excluded.yearly_price,
            description = excluded.description,
            features_json = excluded.features_json,
            max_plants = excluded.max_plants,
            notifications = excluded.notifications,
            has_corporate = excluded.has_corporate,
            has_analytics = excluded.has_analytics,
            max_members = excluded.max_members,
            can_create_company = excluded.can_create_company,
            has_extended_features = excluded.has_extended_features,
            is_active = excluded.is_active
        """,
        [
            (
                1,
                "free",
                "Free",
                0.0,
                0.0,
                "Базовый уход за 1 растением и простые напоминания.",
                '["1 растение в календаре","Уведомление за 1 день","Покупка растений","Telegram-бот (базовый)"]',
                1,
                "basic",
                0,
                0,
                1,
                0,
                0,
                1,
            ),
            (
                2,
                "standard",
                "Standard",
                399.0,
                3990.0,
                "Основной тариф для регулярного ухода и покупок.",
                '["До 30 растений в календаре","Расширенные напоминания","История ухода","Рекомендации по уходу","Telegram-бот (расширенный)"]',
                30,
                "extended",
                0,
                1,
                1,
                0,
                1,
                1,
            ),
            (
                3,
                "premium",
                "Premium",
                899.0,
                8990.0,
                "Максимум возможностей: безлимит, аналитика и корпоративные функции.",
                '["Неограниченные растения","Умные уведомления","Продвинутая аналитика","Приоритетные рекомендации","Корпоративный аккаунт: организация и сотрудники","Общий календарь команды","Корпоративные события"]',
                10000,
                "smart",
                1,
                1,
                50,
                1,
                1,
                1,
            ),
        ],
    )

    # Reference data for pots.
    cur.execute("INSERT OR IGNORE INTO pot_materials(name) VALUES ('Пластик')")
    cur.execute("INSERT OR IGNORE INTO pot_materials(name) VALUES ('Керамика')")
    cur.execute("INSERT OR IGNORE INTO pot_colors(name, hex_code) VALUES ('Белый', '#FFFFFF')")
    cur.execute("INSERT OR IGNORE INTO pot_colors(name, hex_code) VALUES ('Черный', '#000000')")
    cur.execute("INSERT OR IGNORE INTO pot_colors(name, hex_code) VALUES ('Терракотовый', '#C26A3D')")

    # If sizes are absent, create a minimal set.
    sizes_count = cur.execute("SELECT COUNT(*) AS c FROM pot_sizes").fetchone()["c"]
    if int(sizes_count or 0) == 0:
        cur.execute("INSERT INTO pot_sizes(name, diameter_cm, height_cm) VALUES ('S', 10, 10)")
        cur.execute("INSERT INTO pot_sizes(name, diameter_cm, height_cm) VALUES ('M', 14, 14)")
        cur.execute("INSERT INTO pot_sizes(name, diameter_cm, height_cm) VALUES ('L', 18, 18)")

    # Ensure base size+material prices exist.
    size_ids = [int(r["id"]) for r in cur.execute("SELECT id FROM pot_sizes").fetchall()]
    material_ids = [int(r["id"]) for r in cur.execute("SELECT id FROM pot_materials").fetchall()]
    for size_id in size_ids:
        for material_id in material_ids:
            cur.execute(
                """
                INSERT OR IGNORE INTO pot_prices(size_id, material_id, price)
                VALUES (?, ?, 0)
                """,
                (size_id, material_id),
            )

    # Fill variant matrix for all colors from pot_prices.
    cur.execute(
        """
        INSERT OR IGNORE INTO pot_variant_prices(size_id, material_id, color_id, price, is_active)
        SELECT pp.size_id, pp.material_id, pc.id, pp.price, 1
        FROM pot_prices pp
        CROSS JOIN pot_colors pc
        """
    )

    # Default combo should be free: plastic + white (any size).
    plastic = cur.execute(
        "SELECT id FROM pot_materials WHERE LOWER(name) IN ('пластик', 'plastic') LIMIT 1"
    ).fetchone()
    white = cur.execute(
        "SELECT id FROM pot_colors WHERE LOWER(name) IN ('белый', 'white') LIMIT 1"
    ).fetchone()
    if plastic and white:
        cur.execute(
            """
            UPDATE pot_variant_prices
            SET price = 0
            WHERE material_id = ? AND color_id = ?
            """,
            (int(plastic["id"]), int(white["id"])),
        )

    cur.executescript(
        """
        
        -- ИНДЕКСЫ
        
        CREATE INDEX IF NOT EXISTS idx_users_telegram_id ON users(telegram_id);
        CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);

        CREATE INDEX IF NOT EXISTS idx_user_addresses_user_id ON user_addresses(user_id);

        CREATE INDEX IF NOT EXISTS idx_auth_codes_user_id ON auth_codes(user_id);
        CREATE INDEX IF NOT EXISTS idx_auth_codes_code ON auth_codes(code);
        CREATE INDEX IF NOT EXISTS idx_auth_codes_device_id ON auth_codes(device_id);

        CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
        CREATE INDEX IF NOT EXISTS idx_user_sessions_active ON user_sessions(user_id, is_active);
        CREATE INDEX IF NOT EXISTS idx_user_sessions_device_id ON user_sessions(device_id);

        CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
        CREATE INDEX IF NOT EXISTS idx_subscriptions_company_id ON subscriptions(company_id);
        CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
        CREATE INDEX IF NOT EXISTS idx_subscriptions_expires_at ON subscriptions(expires_at);
        CREATE INDEX IF NOT EXISTS idx_subscription_payment_links_user_id ON subscription_payment_links(user_id);
        CREATE INDEX IF NOT EXISTS idx_subscription_payment_links_status ON subscription_payment_links(status);

        CREATE INDEX IF NOT EXISTS idx_company_members_company_id ON company_members(company_id);
        CREATE INDEX IF NOT EXISTS idx_company_members_user_id ON company_members(user_id);
        CREATE INDEX IF NOT EXISTS idx_company_role_history_company_id ON company_role_history(company_id);

        CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);
        CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id);
        CREATE INDEX IF NOT EXISTS idx_products_active ON products(is_active);
        CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);

        CREATE INDEX IF NOT EXISTS idx_product_images_product_id ON product_images(product_id);
        CREATE INDEX IF NOT EXISTS idx_product_images_product_id_id ON product_images(product_id, id);
        CREATE INDEX IF NOT EXISTS idx_pot_variant_prices_smc ON pot_variant_prices(size_id, material_id, color_id);

        CREATE INDEX IF NOT EXISTS idx_wishlist_user_id ON wishlist_items(user_id);
        CREATE INDEX IF NOT EXISTS idx_cart_user_id ON cart_items(user_id);

        CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
        CREATE INDEX IF NOT EXISTS idx_orders_store_id ON orders(store_id);
        CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
        CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at);

        CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);

        CREATE INDEX IF NOT EXISTS idx_payments_order_id ON payments(order_id);
        CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
        CREATE INDEX IF NOT EXISTS idx_refunds_payment_id ON refunds(payment_id);

        CREATE INDEX IF NOT EXISTS idx_calendar_events_user_date ON calendar_events(user_id, event_date);
        CREATE INDEX IF NOT EXISTS idx_user_plants_user_id ON user_plants(user_id);
        CREATE INDEX IF NOT EXISTS idx_user_plants_next_watering ON user_plants(next_watering_at);
        CREATE INDEX IF NOT EXISTS idx_user_plant_logs_user_plant_id ON user_plant_care_logs(user_plant_id);
        CREATE INDEX IF NOT EXISTS idx_user_plant_logs_care_at ON user_plant_care_logs(care_at);
        CREATE INDEX IF NOT EXISTS idx_user_important_dates_user_date ON user_important_dates(user_id, event_date);
        CREATE INDEX IF NOT EXISTS idx_user_holiday_preferences_user_holiday ON user_holiday_preferences(user_id, holiday_code);
        CREATE INDEX IF NOT EXISTS idx_user_important_date_preferences_user_date ON user_important_date_preferences(user_id, important_date_id);
        CREATE INDEX IF NOT EXISTS idx_user_plant_care_dates_user_date ON user_plant_care_dates(user_id, care_date);
        CREATE INDEX IF NOT EXISTS idx_user_plant_care_dates_user_type ON user_plant_care_dates(user_id, care_type);
        CREATE INDEX IF NOT EXISTS idx_user_plant_care_dates_plant_date ON user_plant_care_dates(user_plant_id, care_type, care_date);
        CREATE INDEX IF NOT EXISTS idx_company_calendar_events_company_date ON company_calendar_events(company_id, event_date);
        CREATE INDEX IF NOT EXISTS idx_company_calendar_event_preferences_user_event ON company_calendar_event_preferences(user_id, company_event_id);

        CREATE INDEX IF NOT EXISTS idx_employees_store_id ON employees(store_id);
        CREATE INDEX IF NOT EXISTS idx_employees_active ON employees(is_active);

        CREATE INDEX IF NOT EXISTS idx_inventory_store_product ON inventory(store_id, product_id);
        CREATE INDEX IF NOT EXISTS idx_inventory_low_stock ON inventory(store_id, reorder_point, quantity_available);
        CREATE INDEX IF NOT EXISTS idx_inventory_movements_store_created ON inventory_movements(store_id, created_at);

        CREATE INDEX IF NOT EXISTS idx_purchase_orders_store_id ON purchase_orders(store_id);
        CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier_id ON purchase_orders(supplier_id);
        CREATE INDEX IF NOT EXISTS idx_procurement_cart_user_store ON procurement_cart_items(user_id, store_id);

        CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
        CREATE INDEX IF NOT EXISTS idx_notifications_status ON notifications(status);
        """
    )

    cur.executescript(
        """
        
        -- TRIGGERS: updated_at
        
        CREATE TRIGGER IF NOT EXISTS trg_users_updated_at
        AFTER UPDATE ON users
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE users SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_stores_updated_at
        AFTER UPDATE ON stores
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE stores SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_suppliers_updated_at
        AFTER UPDATE ON suppliers
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE suppliers SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_companies_updated_at
        AFTER UPDATE ON companies
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE companies SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_subscriptions_updated_at
        AFTER UPDATE ON subscriptions
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE subscriptions SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_products_updated_at
        AFTER UPDATE ON products
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE products SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_cart_items_updated_at
        AFTER UPDATE ON cart_items
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE cart_items SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_procurement_cart_items_updated_at
        AFTER UPDATE ON procurement_cart_items
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE procurement_cart_items SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_orders_updated_at
        AFTER UPDATE ON orders
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE orders SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_calendar_events_updated_at
        AFTER UPDATE ON calendar_events
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE calendar_events SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_user_plants_updated_at
        AFTER UPDATE ON user_plants
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE user_plants SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_user_important_dates_updated_at
        AFTER UPDATE ON user_important_dates
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE user_important_dates SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_user_plant_care_dates_updated_at
        AFTER UPDATE ON user_plant_care_dates
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE user_plant_care_dates SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_company_calendar_events_updated_at
        AFTER UPDATE ON company_calendar_events
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE company_calendar_events SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_employees_updated_at
        AFTER UPDATE ON employees
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE employees SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_purchase_orders_updated_at
        AFTER UPDATE ON purchase_orders
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE purchase_orders SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
        END;

        
        -- TRIGGERS: валидация заказа
        
        CREATE TRIGGER IF NOT EXISTS trg_validate_delivery_order
        BEFORE INSERT ON orders
        FOR EACH ROW
        WHEN NEW.order_type = 'delivery'
             AND NEW.address_id IS NULL
             AND (NEW.address_snapshot IS NULL OR TRIM(NEW.address_snapshot) = '')
        BEGIN
            SELECT RAISE(ABORT, 'Для доставки нужен адрес');
        END;

        CREATE TRIGGER IF NOT EXISTS trg_validate_pickup_order
        BEFORE INSERT ON orders
        FOR EACH ROW
        WHEN NEW.order_type = 'pickup'
             AND NEW.store_id IS NULL
        BEGIN
            SELECT RAISE(ABORT, 'Для самовывоза нужен магазин');
        END;

        
        -- TRIGGERS: история статусов пользователя
        
        CREATE TRIGGER IF NOT EXISTS trg_user_status_history
        AFTER UPDATE OF status ON users
        FOR EACH ROW
        WHEN OLD.status <> NEW.status
        BEGIN
            INSERT INTO user_status_history (user_id, old_status, new_status, reason)
            VALUES (NEW.id, OLD.status, NEW.status, NEW.blocked_reason);
        END;

        
        -- TRIGGERS: история статусов заказа
        
        CREATE TRIGGER IF NOT EXISTS trg_order_status_history
        AFTER UPDATE OF status ON orders
        FOR EACH ROW
        WHEN OLD.status <> NEW.status
        BEGIN
            INSERT INTO order_status_history (order_id, old_status, new_status, changed_by_employee_id)
            VALUES (NEW.id, OLD.status, NEW.status, NEW.assigned_employee_id);
        END;

        
        -- TRIGGERS: пересчет доступного остатка
        
        CREATE TRIGGER IF NOT EXISTS trg_inventory_after_insert
        AFTER INSERT ON inventory
        FOR EACH ROW
        BEGIN
            UPDATE inventory
            SET quantity_available = quantity_on_hand - quantity_reserved
            WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_inventory_after_update
        AFTER UPDATE OF quantity_on_hand, quantity_reserved ON inventory
        FOR EACH ROW
        BEGIN
            UPDATE inventory
            SET quantity_available = quantity_on_hand - quantity_reserved
            WHERE id = NEW.id;
        END;

        
        -- TRIGGERS: оплата заказа
        
        CREATE TRIGGER IF NOT EXISTS trg_payment_paid_updates_order_insert
        AFTER INSERT ON payments
        FOR EACH ROW
        WHEN NEW.status = 'paid'
        BEGIN
            UPDATE orders
            SET payment_status = 'paid'
            WHERE id = NEW.order_id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_payment_paid_updates_order_update
        AFTER UPDATE OF status ON payments
        FOR EACH ROW
        WHEN OLD.status <> 'paid' AND NEW.status = 'paid'
        BEGIN
            UPDATE orders
            SET payment_status = 'paid'
            WHERE id = NEW.order_id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_refund_processed_updates_order
        AFTER UPDATE OF status ON refunds
        FOR EACH ROW
        WHEN NEW.status = 'processed'
        BEGIN
            UPDATE orders
            SET payment_status = 'refunded'
            WHERE id = (SELECT order_id FROM payments WHERE id = NEW.payment_id);
        END;
        """
    )

    cur.executescript(
        """
        
        -- VIEW: аналитика для админа
        
        CREATE VIEW IF NOT EXISTS v_sales_analytics AS
        SELECT
            o.store_id,
            date(o.created_at) AS sales_date,
            COUNT(DISTINCT o.id) AS orders_count,
            COALESCE(SUM(o.total_price), 0) AS revenue
        FROM orders o
        WHERE o.status IN ('delivered', 'completed')
        GROUP BY o.store_id, date(o.created_at);

        CREATE VIEW IF NOT EXISTS v_product_popularity AS
        SELECT
            oi.product_id,
            oi.product_name_snapshot AS product_name,
            SUM(oi.quantity) AS total_sold,
            SUM(oi.total_price) AS total_revenue
        FROM order_items oi
        JOIN orders o ON o.id = oi.order_id
        WHERE o.status IN ('delivered', 'completed')
        GROUP BY oi.product_id, oi.product_name_snapshot;

        CREATE VIEW IF NOT EXISTS v_inventory_writeoffs AS
        SELECT
            store_id,
            product_id,
            SUM(quantity) AS writeoff_quantity
        FROM inventory_movements
        WHERE movement_type = 'writeoff'
        GROUP BY store_id, product_id;
        """
    )

    conn.commit()
    conn.close()


def recalculate_order_total(order_id: int) -> float:
    """
    Пересчитывает subtotal и total_price заказа.
    """
    conn = get_connection()
    cur = conn.cursor()

    cur.execute(
        """
        SELECT COALESCE(SUM(total_price), 0) AS subtotal
        FROM order_items
        WHERE order_id = ?
        """,
        (order_id,),
    )
    subtotal = float(cur.fetchone()["subtotal"])

    cur.execute(
        """
        SELECT delivery_fee, discount_amount
        FROM orders
        WHERE id = ?
        """,
        (order_id,),
    )
    row = cur.fetchone()
    if row is None:
        conn.close()
        raise ValueError(f"Заказ с id={order_id} не найден")

    delivery_fee = float(row["delivery_fee"] or 0)
    discount_amount = float(row["discount_amount"] or 0)
    total = round(subtotal + delivery_fee - discount_amount, 2)

    cur.execute(
        """
        UPDATE orders
        SET subtotal = ?, total_price = ?
        WHERE id = ?
        """,
        (subtotal, total, order_id),
    )

    conn.commit()
    conn.close()
    return total


def block_user(user_id: int, reason: Optional[str] = None) -> None:
    """
    Блокирует пользователя и завершает активные сессии.
    """
    conn = get_connection()
    cur = conn.cursor()

    cur.execute(
        """
        UPDATE users
        SET status = 'blocked',
            blocked_at = CURRENT_TIMESTAMP,
            blocked_reason = ?
        WHERE id = ?
        """,
        (reason, user_id),
    )

    cur.execute(
        """
        UPDATE user_sessions
        SET is_active = 0,
            revoked_at = CURRENT_TIMESTAMP,
            revoke_reason = COALESCE(?, 'user_blocked')
        WHERE user_id = ? AND is_active = 1
        """,
        (reason, user_id),
    )

    conn.commit()
    conn.close()


def is_employee(telegram_id: int) -> bool:
    """
    Проверяет, является ли пользователь активным сотрудником.
    """
    conn = get_connection()
    cur = conn.cursor()

    cur.execute(
        """
        SELECT 1
        FROM employees e
        JOIN users u ON u.id = e.user_id
        WHERE u.telegram_id = ?
          AND e.is_active = 1
        LIMIT 1
        """,
        (telegram_id,),
    )

    result = cur.fetchone() is not None
    conn.close()
    return result


def get_employee_info(telegram_id: int) -> Optional[sqlite3.Row]:
    """
    Возвращает информацию о сотруднике по telegram_id.
    """
    conn = get_connection()
    cur = conn.cursor()

    cur.execute(
        """
        SELECT
            e.id,
            e.salary,
            e.hired_at,
            e.is_active,
            p.title AS position_title,
            s.name AS store_name,
            u.full_name,
            u.phone
        FROM employees e
        JOIN users u ON u.id = e.user_id
        JOIN positions p ON p.id = e.position_id
        JOIN stores s ON s.id = e.store_id
        WHERE u.telegram_id = ?
          AND e.is_active = 1
        """,
        (telegram_id,),
    )

    row = cur.fetchone()
    conn.close()
    return row


def validate_schema() -> None:
    """
    Базовая проверка, что ключевые таблицы созданы.
    """
    required_tables = {
        "users",
        "user_sessions",
        "auth_codes",
        "user_addresses",
        "subscription_plans",
        "subscriptions",
        "subscription_payment_links",
        "companies",
        "company_members",
        "products",
        "product_images",
        "wishlist_items",
        "cart_items",
        "orders",
        "order_items",
        "payments",
        "refunds",
        "calendar_events",
        "user_plants",
        "user_plant_care_logs",
        "user_important_dates",
        "user_holiday_preferences",
        "user_important_date_preferences",
        "user_plant_care_dates",
        "company_calendar_events",
        "company_calendar_event_preferences",
        "stores",
        "employees",
        "inventory",
        "inventory_movements",
        "purchase_orders",
        "purchase_order_items",
        "purchase_receipts",
        "purchase_receipt_items",
        "notifications",
        "marketing_campaigns",
    }

    conn = get_connection()
    cur = conn.cursor()

    cur.execute(
        """
        SELECT name
        FROM sqlite_master
        WHERE type = 'table'
        """
    )
    existing_tables = {row["name"] for row in cur.fetchall()}
    conn.close()

    missing = required_tables - existing_tables
    if missing:
        raise RuntimeError(f"Не созданы таблицы: {', '.join(sorted(missing))}")


if __name__ == "__main__":
    create_database()
    validate_schema()
    print("База данных успешно создана. Схема проверена.")
