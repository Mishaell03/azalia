import os
import sqlite3
from datetime import datetime, timedelta, UTC

DB_NAME = "flower_shop.db"


def get_connection(db_name: str = DB_NAME) -> sqlite3.Connection:
    """
    Создает подключение к SQLite и включает базовые настройки производительности.
    """
    base_dir = os.path.abspath(os.path.dirname(__file__)) if "__file__" in globals() else os.getcwd()
    db_path = os.path.join(base_dir, db_name)

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row

    # Базовые настройки SQLite
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA synchronous = NORMAL")
    conn.execute("PRAGMA temp_store = MEMORY")
    conn.execute("PRAGMA cache_size = -64000")   # около 64 МБ кэша
    conn.execute("PRAGMA busy_timeout = 5000")

    return conn


def create_database() -> None:
    """
    Создает все таблицы базы данных.
    """
    conn = get_connection()
    cursor = conn.cursor()

    cursor.executescript(
        """
        ------------------------------------------------------------------------
        -- СПРАВОЧНИКИ
        ------------------------------------------------------------------------

        -- Должности сотрудников
        CREATE TABLE IF NOT EXISTS positions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL UNIQUE,
            responsibilities TEXT,
            requirements TEXT,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        -- Поставщики растений
        CREATE TABLE IF NOT EXISTS suppliers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            address TEXT NOT NULL,
            contact_person TEXT NOT NULL,
            phone TEXT,
            email TEXT,
            staff_info TEXT,
            is_active BOOLEAN NOT NULL DEFAULT 1,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        -- Магазины / склады / пункты самовывоза
        CREATE TABLE IF NOT EXISTS stores (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            address TEXT NOT NULL,
            phone TEXT,
            email TEXT,
            store_type TEXT NOT NULL DEFAULT 'shop'
                CHECK(store_type IN ('shop', 'warehouse', 'pickup_point')),
            is_active BOOLEAN NOT NULL DEFAULT 1,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        -- Категории растений
        CREATE TABLE IF NOT EXISTS categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            description TEXT,
            parent_id INTEGER,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE SET NULL
        );

        -- Типы растений
        CREATE TABLE IF NOT EXISTS plant_types (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL UNIQUE,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        -- Материалы горшков
        CREATE TABLE IF NOT EXISTS pot_materials (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            description TEXT,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        -- Размеры горшков
        CREATE TABLE IF NOT EXISTS pot_sizes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            diameter_cm INTEGER,
            height_cm INTEGER,
            volume_liters REAL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        -- Цвета горшков
        CREATE TABLE IF NOT EXISTS pot_colors (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            hex_code TEXT,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        -- Способы оплаты
        CREATE TABLE IF NOT EXISTS payment_methods (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL UNIQUE,
            is_active BOOLEAN NOT NULL DEFAULT 1,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        ------------------------------------------------------------------------
        -- ЦЕНЫ НА ГОРШКИ
        ------------------------------------------------------------------------

        -- Стоимость горшка зависит от материала и размера
        CREATE TABLE IF NOT EXISTS pot_prices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            material_id INTEGER NOT NULL,
            size_id INTEGER NOT NULL,
            price REAL NOT NULL CHECK(price >= 0),
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (material_id) REFERENCES pot_materials(id) ON DELETE CASCADE,
            FOREIGN KEY (size_id) REFERENCES pot_sizes(id) ON DELETE CASCADE,
            UNIQUE(material_id, size_id)
        );

        ------------------------------------------------------------------------
        -- ТОВАРЫ
        ------------------------------------------------------------------------

        -- Основная таблица товаров
        CREATE TABLE IF NOT EXISTS pot_plants (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sku TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL UNIQUE,
            description TEXT,
            supplier_id INTEGER,
            category_id INTEGER NOT NULL,
            plant_type_id INTEGER NOT NULL,
            base_price REAL NOT NULL CHECK(base_price >= 0),
            cost_price REAL NOT NULL DEFAULT 0 CHECK(cost_price >= 0),
            recommended_pot_size_id INTEGER,
            height_cm INTEGER CHECK(height_cm >= 0),
            care_instructions TEXT,
            light_requirements TEXT
                CHECK(light_requirements IN ('full_sun', 'partial_shade', 'shade')),
            watering_frequency TEXT,
            rating REAL DEFAULT 0 CHECK(rating >= 0 AND rating <= 5),
            main_image_url TEXT,
            is_active BOOLEAN NOT NULL DEFAULT 1,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL,
            FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE RESTRICT,
            FOREIGN KEY (plant_type_id) REFERENCES plant_types(id) ON DELETE RESTRICT,
            FOREIGN KEY (recommended_pot_size_id) REFERENCES pot_sizes(id) ON DELETE SET NULL
        );

        -- Дополнительные фотографии товаров
        CREATE TABLE IF NOT EXISTS plant_images (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            plant_id INTEGER NOT NULL,
            image_url TEXT NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0,
            is_main BOOLEAN NOT NULL DEFAULT 0,
            alt_text TEXT,
            is_active BOOLEAN NOT NULL DEFAULT 1,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (plant_id) REFERENCES pot_plants(id) ON DELETE CASCADE
        );

        ------------------------------------------------------------------------
        -- ПОЛЬЗОВАТЕЛИ И СОТРУДНИКИ
        ------------------------------------------------------------------------

        -- Все пользователи системы
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            telegram_id INTEGER UNIQUE,
            name TEXT NOT NULL,
            phone TEXT NOT NULL,
            email TEXT,
            password_hash TEXT,
            status TEXT NOT NULL DEFAULT 'active'
                CHECK(status IN ('active', 'blocked', 'deleted')),
            blocked_at TIMESTAMP,
            blocked_reason TEXT,
            avatar BLOB,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        -- История изменения статусов пользователей
        CREATE TABLE IF NOT EXISTS user_status_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            old_status TEXT,
            new_status TEXT NOT NULL
                CHECK(new_status IN ('active', 'blocked', 'deleted')),
            changed_by_employee_id INTEGER,
            reason TEXT,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        );

        -- Сотрудники
        CREATE TABLE IF NOT EXISTS employees (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL UNIQUE,
            position_id INTEGER NOT NULL,
            store_id INTEGER,
            salary REAL CHECK(salary >= 0),
            hire_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            is_active BOOLEAN NOT NULL DEFAULT 1,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (position_id) REFERENCES positions(id) ON DELETE RESTRICT,
            FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE SET NULL
        );

        -- Активные сессии пользователей для нескольких устройств
        CREATE TABLE IF NOT EXISTS user_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            device_id TEXT NOT NULL,
            session_token TEXT NOT NULL UNIQUE,
            refresh_token TEXT UNIQUE,
            device_name TEXT,
            platform TEXT,
            ip_address TEXT,
            user_agent TEXT,
            is_active BOOLEAN NOT NULL DEFAULT 1,
            last_seen_at TIMESTAMP,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            expires_at TIMESTAMP,
            revoked_at TIMESTAMP,
            revoke_reason TEXT,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        );

        -- Временные коды авторизации
        CREATE TABLE IF NOT EXISTS oauth_codes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            device_id TEXT NOT NULL CHECK(length(device_id) <= 255),
            code TEXT NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            expires_at TIMESTAMP NOT NULL,
            used BOOLEAN NOT NULL DEFAULT 0,
            used_at TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        );

        ------------------------------------------------------------------------
        -- СКЛАД ПО ТОЧКАМ
        ------------------------------------------------------------------------

        -- Остатки товара по каждой точке
        CREATE TABLE IF NOT EXISTS store_inventory (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            store_id INTEGER NOT NULL,
            plant_id INTEGER NOT NULL,
            quantity_on_hand INTEGER NOT NULL DEFAULT 0 CHECK(quantity_on_hand >= 0),
            quantity_reserved INTEGER NOT NULL DEFAULT 0 CHECK(quantity_reserved >= 0),
            quantity_available INTEGER NOT NULL DEFAULT 0 CHECK(quantity_available >= 0),
            reorder_point INTEGER NOT NULL DEFAULT 0 CHECK(reorder_point >= 0),
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE,
            FOREIGN KEY (plant_id) REFERENCES pot_plants(id) ON DELETE CASCADE,
            UNIQUE(store_id, plant_id)
        );

        -- История движения товара по складу
        CREATE TABLE IF NOT EXISTS inventory_movements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            store_id INTEGER NOT NULL,
            plant_id INTEGER NOT NULL,
            movement_type TEXT NOT NULL CHECK(
                movement_type IN (
                    'purchase_receipt',
                    'sale',
                    'sale_cancel_return',
                    'writeoff',
                    'transfer_in',
                    'transfer_out',
                    'adjustment',
                    'reservation',
                    'reservation_release'
                )
            ),
            quantity INTEGER NOT NULL CHECK(quantity > 0),
            unit_cost REAL CHECK(unit_cost >= 0),
            related_order_id INTEGER,
            related_purchase_order_id INTEGER,
            comment TEXT,
            created_by_employee_id INTEGER,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE,
            FOREIGN KEY (plant_id) REFERENCES pot_plants(id) ON DELETE CASCADE,
            FOREIGN KEY (created_by_employee_id) REFERENCES employees(id) ON DELETE SET NULL
        );

        ------------------------------------------------------------------------
        -- КОРЗИНА И ИЗБРАННОЕ
        ------------------------------------------------------------------------

        -- Корзина пользователя
        CREATE TABLE IF NOT EXISTS cart_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            plant_id INTEGER NOT NULL,
            quantity INTEGER NOT NULL DEFAULT 1 CHECK(quantity > 0),
            pot_color_id INTEGER,
            pot_size_id INTEGER,
            pot_material_id INTEGER,
            plant_unit_price REAL NOT NULL CHECK(plant_unit_price >= 0),
            pot_unit_price REAL NOT NULL DEFAULT 0 CHECK(pot_unit_price >= 0),
            total_price REAL NOT NULL CHECK(total_price >= 0),
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (plant_id) REFERENCES pot_plants(id) ON DELETE CASCADE,
            FOREIGN KEY (pot_color_id) REFERENCES pot_colors(id) ON DELETE SET NULL,
            FOREIGN KEY (pot_size_id) REFERENCES pot_sizes(id) ON DELETE SET NULL,
            FOREIGN KEY (pot_material_id) REFERENCES pot_materials(id) ON DELETE SET NULL
        );

        -- Избранные товары пользователя
        CREATE TABLE IF NOT EXISTS wishlist_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            plant_id INTEGER NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (plant_id) REFERENCES pot_plants(id) ON DELETE CASCADE,
            UNIQUE(user_id, plant_id)
        );

        ------------------------------------------------------------------------
        -- ЗАКАЗЫ КЛИЕНТОВ
        ------------------------------------------------------------------------

        -- Заказы клиентов
        CREATE TABLE IF NOT EXISTS orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_number TEXT NOT NULL UNIQUE,
            order_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            delivery_date TIMESTAMP,
            user_id INTEGER NOT NULL,
            order_type TEXT NOT NULL DEFAULT 'delivery'
                CHECK(order_type IN ('delivery', 'pickup')),
            store_id INTEGER,
            address TEXT,
            customer_comment TEXT,
            subtotal REAL NOT NULL DEFAULT 0 CHECK(subtotal >= 0),
            delivery_fee REAL NOT NULL DEFAULT 0 CHECK(delivery_fee >= 0),
            discount_amount REAL NOT NULL DEFAULT 0 CHECK(discount_amount >= 0),
            total_price REAL NOT NULL DEFAULT 0 CHECK(total_price >= 0),
            payment_method_id INTEGER,
            payment_status TEXT NOT NULL DEFAULT 'pending'
                CHECK(payment_status IN ('pending', 'paid', 'failed', 'refunded', 'partially_refunded')),
            is_paid BOOLEAN NOT NULL DEFAULT 0,
            assigned_employee_id INTEGER,
            status TEXT NOT NULL DEFAULT 'new'
                CHECK(status IN (
                    'new',
                    'awaiting_payment',
                    'processing',
                    'assembled',
                    'shipped',
                    'ready_for_pickup',
                    'delivered',
                    'completed',
                    'cancelled',
                    'returned'
                )),
            source_channel TEXT NOT NULL DEFAULT 'telegram'
                CHECK(source_channel IN ('telegram', 'site', 'mobile_app', 'admin_panel')),
            cancellation_reason TEXT,
            cancelled_by TEXT
                CHECK(cancelled_by IN ('user', 'employee', 'system')),
            cancelled_at TIMESTAMP,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
            FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE SET NULL,
            FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE SET NULL,
            FOREIGN KEY (assigned_employee_id) REFERENCES employees(id) ON DELETE SET NULL
        );

        -- Позиции заказа
        CREATE TABLE IF NOT EXISTS order_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER NOT NULL,
            plant_id INTEGER NOT NULL,
            plant_name_snapshot TEXT NOT NULL,
            plant_description_snapshot TEXT,
            quantity INTEGER NOT NULL CHECK(quantity > 0),
            plant_unit_price REAL NOT NULL CHECK(plant_unit_price >= 0),
            unit_cost REAL NOT NULL DEFAULT 0 CHECK(unit_cost >= 0),
            pot_color_id INTEGER,
            pot_size_id INTEGER,
            pot_material_id INTEGER,
            pot_unit_price REAL NOT NULL DEFAULT 0 CHECK(pot_unit_price >= 0),
            discount_amount REAL NOT NULL DEFAULT 0 CHECK(discount_amount >= 0),
            total_price REAL NOT NULL CHECK(total_price >= 0),
            store_id INTEGER,
            fulfilled_quantity INTEGER NOT NULL DEFAULT 0 CHECK(fulfilled_quantity >= 0),
            returned_quantity INTEGER NOT NULL DEFAULT 0 CHECK(returned_quantity >= 0),
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
            FOREIGN KEY (plant_id) REFERENCES pot_plants(id) ON DELETE RESTRICT,
            FOREIGN KEY (pot_color_id) REFERENCES pot_colors(id) ON DELETE SET NULL,
            FOREIGN KEY (pot_size_id) REFERENCES pot_sizes(id) ON DELETE SET NULL,
            FOREIGN KEY (pot_material_id) REFERENCES pot_materials(id) ON DELETE SET NULL,
            FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE SET NULL
        );

        -- История изменения статусов заказа
        CREATE TABLE IF NOT EXISTS order_status_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER NOT NULL,
            old_status TEXT,
            new_status TEXT NOT NULL,
            changed_by INTEGER,
            change_reason TEXT,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
            FOREIGN KEY (changed_by) REFERENCES employees(id) ON DELETE SET NULL
        );

        -- Лог событий по заказу
        CREATE TABLE IF NOT EXISTS order_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER NOT NULL,
            event_type TEXT NOT NULL CHECK(
                event_type IN (
                    'created',
                    'paid',
                    'payment_failed',
                    'assigned',
                    'assembled',
                    'shipped',
                    'ready_for_pickup',
                    'delivered',
                    'completed',
                    'cancelled',
                    'returned',
                    'status_changed'
                )
            ),
            event_data TEXT,
            created_by_employee_id INTEGER,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
            FOREIGN KEY (created_by_employee_id) REFERENCES employees(id) ON DELETE SET NULL
        );

        -- Детализация отмен заказа
        CREATE TABLE IF NOT EXISTS order_cancellations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER NOT NULL UNIQUE,
            cancelled_by_type TEXT NOT NULL CHECK(cancelled_by_type IN ('user', 'employee', 'system')),
            cancelled_by_employee_id INTEGER,
            reason_code TEXT,
            reason_text TEXT,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
            FOREIGN KEY (cancelled_by_employee_id) REFERENCES employees(id) ON DELETE SET NULL
        );

        ------------------------------------------------------------------------
        -- ПЛАТЕЖИ
        ------------------------------------------------------------------------

        -- Платежные ссылки
        CREATE TABLE IF NOT EXISTS payment_links (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            order_id INTEGER,
            amount REAL NOT NULL CHECK(amount >= 0),
            payment_url TEXT UNIQUE,
            status TEXT NOT NULL DEFAULT 'pending'
                CHECK(status IN ('pending', 'paid', 'expired', 'cancelled')),
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            expires_at TIMESTAMP,
            payment_system_id TEXT,
            payment_confirmed_at TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL
        );

        -- Платежи
        CREATE TABLE IF NOT EXISTS payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            amount REAL NOT NULL CHECK(amount >= 0),
            payment_method_id INTEGER,
            status TEXT NOT NULL
                CHECK(status IN ('pending', 'authorized', 'paid', 'failed', 'refunded', 'cancelled')),
            external_payment_id TEXT,
            paid_at TIMESTAMP,
            failed_at TIMESTAMP,
            refund_amount REAL NOT NULL DEFAULT 0 CHECK(refund_amount >= 0),
            refunded_at TIMESTAMP,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE SET NULL
        );

        ------------------------------------------------------------------------
        -- ОТЗЫВЫ
        ------------------------------------------------------------------------

        -- Отзывы по заказам
        CREATE TABLE IF NOT EXISTS reviews (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            order_id INTEGER NOT NULL,
            rating INTEGER NOT NULL CHECK(rating >= 1 AND rating <= 5),
            comment TEXT,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
            UNIQUE(user_id, order_id)
        );

        ------------------------------------------------------------------------
        -- ЗАКУПКИ У ПОСТАВЩИКОВ
        ------------------------------------------------------------------------

        -- Заказы поставщикам
        CREATE TABLE IF NOT EXISTS purchase_orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            purchase_number TEXT NOT NULL UNIQUE,
            supplier_id INTEGER NOT NULL,
            store_id INTEGER NOT NULL,
            created_by_employee_id INTEGER,
            status TEXT NOT NULL DEFAULT 'draft'
                CHECK(status IN ('draft', 'sent', 'partially_received', 'received', 'cancelled')),
            expected_delivery_date TIMESTAMP,
            ordered_at TIMESTAMP,
            received_at TIMESTAMP,
            comment TEXT,
            total_amount REAL NOT NULL DEFAULT 0 CHECK(total_amount >= 0),
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE RESTRICT,
            FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE RESTRICT,
            FOREIGN KEY (created_by_employee_id) REFERENCES employees(id) ON DELETE SET NULL
        );

        -- Позиции заказа поставщику
        CREATE TABLE IF NOT EXISTS purchase_order_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            purchase_order_id INTEGER NOT NULL,
            plant_id INTEGER NOT NULL,
            ordered_quantity INTEGER NOT NULL CHECK(ordered_quantity > 0),
            received_quantity INTEGER NOT NULL DEFAULT 0 CHECK(received_quantity >= 0),
            rejected_quantity INTEGER NOT NULL DEFAULT 0 CHECK(rejected_quantity >= 0),
            unit_cost REAL NOT NULL CHECK(unit_cost >= 0),
            line_total REAL NOT NULL CHECK(line_total >= 0),
            comment TEXT,
            FOREIGN KEY (purchase_order_id) REFERENCES purchase_orders(id) ON DELETE CASCADE,
            FOREIGN KEY (plant_id) REFERENCES pot_plants(id) ON DELETE RESTRICT
        );

        -- Документы приемки поставок
        CREATE TABLE IF NOT EXISTS purchase_receipts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            purchase_order_id INTEGER NOT NULL,
            received_by_employee_id INTEGER,
            received_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            comment TEXT,
            FOREIGN KEY (purchase_order_id) REFERENCES purchase_orders(id) ON DELETE CASCADE,
            FOREIGN KEY (received_by_employee_id) REFERENCES employees(id) ON DELETE SET NULL
        );

        -- Позиции приемки поставок
        CREATE TABLE IF NOT EXISTS purchase_receipt_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            purchase_receipt_id INTEGER NOT NULL,
            purchase_order_item_id INTEGER NOT NULL,
            accepted_quantity INTEGER NOT NULL DEFAULT 0 CHECK(accepted_quantity >= 0),
            rejected_quantity INTEGER NOT NULL DEFAULT 0 CHECK(rejected_quantity >= 0),
            reject_reason TEXT,
            FOREIGN KEY (purchase_receipt_id) REFERENCES purchase_receipts(id) ON DELETE CASCADE,
            FOREIGN KEY (purchase_order_item_id) REFERENCES purchase_order_items(id) ON DELETE CASCADE
        );
        """
    )

    conn.commit()
    conn.close()


def create_indexes() -> None:
    """
    Создает индексы для ускорения выборок.
    """
    conn = get_connection()
    cursor = conn.cursor()

    cursor.executescript(
        """
        ------------------------------------------------------------------------
        -- ИНДЕКСЫ: ПОЛЬЗОВАТЕЛИ / СОТРУДНИКИ / СЕССИИ
        ------------------------------------------------------------------------

        CREATE INDEX IF NOT EXISTS idx_users_telegram_id ON users(telegram_id);
        CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
        CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);

        CREATE INDEX IF NOT EXISTS idx_employees_user_id ON employees(user_id);
        CREATE INDEX IF NOT EXISTS idx_employees_position_id ON employees(position_id);
        CREATE INDEX IF NOT EXISTS idx_employees_store_id ON employees(store_id);
        CREATE INDEX IF NOT EXISTS idx_employees_is_active ON employees(is_active);

        CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
        CREATE INDEX IF NOT EXISTS idx_user_sessions_device_id ON user_sessions(device_id);
        CREATE INDEX IF NOT EXISTS idx_user_sessions_is_active ON user_sessions(is_active);
        CREATE INDEX IF NOT EXISTS idx_user_sessions_user_active ON user_sessions(user_id, is_active);

        CREATE INDEX IF NOT EXISTS idx_oauth_codes_user_id ON oauth_codes(user_id);
        CREATE INDEX IF NOT EXISTS idx_oauth_codes_device_id ON oauth_codes(device_id);
        CREATE INDEX IF NOT EXISTS idx_oauth_codes_code ON oauth_codes(code);
        CREATE INDEX IF NOT EXISTS idx_oauth_codes_user_device ON oauth_codes(user_id, device_id);

        CREATE INDEX IF NOT EXISTS idx_user_status_history_user_id ON user_status_history(user_id);
        CREATE INDEX IF NOT EXISTS idx_user_status_history_created_at ON user_status_history(created_at);

        ------------------------------------------------------------------------
        -- ИНДЕКСЫ: ТОВАРЫ / КАТАЛОГ
        ------------------------------------------------------------------------

        CREATE INDEX IF NOT EXISTS idx_pot_plants_supplier_id ON pot_plants(supplier_id);
        CREATE INDEX IF NOT EXISTS idx_pot_plants_category_id ON pot_plants(category_id);
        CREATE INDEX IF NOT EXISTS idx_pot_plants_plant_type_id ON pot_plants(plant_type_id);
        CREATE INDEX IF NOT EXISTS idx_pot_plants_is_active ON pot_plants(is_active);
        CREATE INDEX IF NOT EXISTS idx_pot_plants_name ON pot_plants(name);
        CREATE INDEX IF NOT EXISTS idx_pot_plants_category_active ON pot_plants(category_id, is_active);

        CREATE INDEX IF NOT EXISTS idx_categories_parent_id ON categories(parent_id);
        CREATE INDEX IF NOT EXISTS idx_pot_prices_material_size ON pot_prices(material_id, size_id);

        CREATE INDEX IF NOT EXISTS idx_plant_images_plant_id ON plant_images(plant_id);
        CREATE INDEX IF NOT EXISTS idx_plant_images_plant_sort ON plant_images(plant_id, sort_order);
        CREATE INDEX IF NOT EXISTS idx_plant_images_is_main ON plant_images(plant_id, is_main);

        ------------------------------------------------------------------------
        -- ИНДЕКСЫ: СКЛАД
        ------------------------------------------------------------------------

        CREATE INDEX IF NOT EXISTS idx_store_inventory_store_id ON store_inventory(store_id);
        CREATE INDEX IF NOT EXISTS idx_store_inventory_plant_id ON store_inventory(plant_id);
        CREATE INDEX IF NOT EXISTS idx_store_inventory_available ON store_inventory(quantity_available);
        CREATE INDEX IF NOT EXISTS idx_store_inventory_store_plant ON store_inventory(store_id, plant_id);

        CREATE INDEX IF NOT EXISTS idx_inventory_movements_store_id ON inventory_movements(store_id);
        CREATE INDEX IF NOT EXISTS idx_inventory_movements_plant_id ON inventory_movements(plant_id);
        CREATE INDEX IF NOT EXISTS idx_inventory_movements_type ON inventory_movements(movement_type);
        CREATE INDEX IF NOT EXISTS idx_inventory_movements_created_at ON inventory_movements(created_at);
        CREATE INDEX IF NOT EXISTS idx_inventory_movements_store_plant ON inventory_movements(store_id, plant_id);

        ------------------------------------------------------------------------
        -- ИНДЕКСЫ: КОРЗИНА / ИЗБРАННОЕ
        ------------------------------------------------------------------------

        CREATE INDEX IF NOT EXISTS idx_cart_items_user_id ON cart_items(user_id);
        CREATE INDEX IF NOT EXISTS idx_cart_items_plant_id ON cart_items(plant_id);
        CREATE UNIQUE INDEX IF NOT EXISTS idx_cart_items_unique_config
            ON cart_items(user_id, plant_id, pot_color_id, pot_size_id, pot_material_id);

        CREATE INDEX IF NOT EXISTS idx_wishlist_items_user_id ON wishlist_items(user_id);
        CREATE INDEX IF NOT EXISTS idx_wishlist_items_plant_id ON wishlist_items(plant_id);

        ------------------------------------------------------------------------
        -- ИНДЕКСЫ: ЗАКАЗЫ
        ------------------------------------------------------------------------

        CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
        CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
        CREATE INDEX IF NOT EXISTS idx_orders_payment_status ON orders(payment_status);
        CREATE INDEX IF NOT EXISTS idx_orders_store_id ON orders(store_id);
        CREATE INDEX IF NOT EXISTS idx_orders_assigned_employee_id ON orders(assigned_employee_id);
        CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at);
        CREATE INDEX IF NOT EXISTS idx_orders_order_date ON orders(order_date);
        CREATE INDEX IF NOT EXISTS idx_orders_user_status ON orders(user_id, status);
        CREATE INDEX IF NOT EXISTS idx_orders_store_status ON orders(store_id, status);

        CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
        CREATE INDEX IF NOT EXISTS idx_order_items_plant_id ON order_items(plant_id);
        CREATE INDEX IF NOT EXISTS idx_order_items_store_id ON order_items(store_id);
        CREATE INDEX IF NOT EXISTS idx_order_items_order_plant ON order_items(order_id, plant_id);

        CREATE INDEX IF NOT EXISTS idx_order_status_history_order_id ON order_status_history(order_id);
        CREATE INDEX IF NOT EXISTS idx_order_status_history_created_at ON order_status_history(created_at);

        CREATE INDEX IF NOT EXISTS idx_order_events_order_id ON order_events(order_id);
        CREATE INDEX IF NOT EXISTS idx_order_events_event_type ON order_events(event_type);
        CREATE INDEX IF NOT EXISTS idx_order_events_created_at ON order_events(created_at);

        CREATE INDEX IF NOT EXISTS idx_order_cancellations_order_id ON order_cancellations(order_id);

        ------------------------------------------------------------------------
        -- ИНДЕКСЫ: ПЛАТЕЖИ
        ------------------------------------------------------------------------

        CREATE INDEX IF NOT EXISTS idx_payment_links_user_id ON payment_links(user_id);
        CREATE INDEX IF NOT EXISTS idx_payment_links_order_id ON payment_links(order_id);
        CREATE INDEX IF NOT EXISTS idx_payment_links_status ON payment_links(status);

        CREATE INDEX IF NOT EXISTS idx_payments_order_id ON payments(order_id);
        CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments(user_id);
        CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
        CREATE INDEX IF NOT EXISTS idx_payments_paid_at ON payments(paid_at);

        ------------------------------------------------------------------------
        -- ИНДЕКСЫ: ОТЗЫВЫ
        ------------------------------------------------------------------------

        CREATE INDEX IF NOT EXISTS idx_reviews_user_id ON reviews(user_id);
        CREATE INDEX IF NOT EXISTS idx_reviews_order_id ON reviews(order_id);

        ------------------------------------------------------------------------
        -- ИНДЕКСЫ: ЗАКУПКИ
        ------------------------------------------------------------------------

        CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier_id ON purchase_orders(supplier_id);
        CREATE INDEX IF NOT EXISTS idx_purchase_orders_store_id ON purchase_orders(store_id);
        CREATE INDEX IF NOT EXISTS idx_purchase_orders_status ON purchase_orders(status);
        CREATE INDEX IF NOT EXISTS idx_purchase_orders_created_at ON purchase_orders(created_at);

        CREATE INDEX IF NOT EXISTS idx_purchase_order_items_po_id ON purchase_order_items(purchase_order_id);
        CREATE INDEX IF NOT EXISTS idx_purchase_order_items_plant_id ON purchase_order_items(plant_id);

        CREATE INDEX IF NOT EXISTS idx_purchase_receipts_po_id ON purchase_receipts(purchase_order_id);
        CREATE INDEX IF NOT EXISTS idx_purchase_receipts_received_at ON purchase_receipts(received_at);

        CREATE INDEX IF NOT EXISTS idx_purchase_receipt_items_receipt_id ON purchase_receipt_items(purchase_receipt_id);
        CREATE INDEX IF NOT EXISTS idx_purchase_receipt_items_po_item_id ON purchase_receipt_items(purchase_order_item_id);
        """
    )

    conn.commit()
    conn.close()


def create_triggers() -> None:
    """
    Создает базовые триггеры для поддержки целостности данных.
    """
    conn = get_connection()
    cursor = conn.cursor()

    cursor.executescript(
        """
        ------------------------------------------------------------------------
        -- ОБНОВЛЕНИЕ ПОЛЕЙ updated_at
        ------------------------------------------------------------------------

        CREATE TRIGGER IF NOT EXISTS trg_users_updated_at
        AFTER UPDATE ON users
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE users
            SET updated_at = CURRENT_TIMESTAMP
            WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_employees_updated_at
        AFTER UPDATE ON employees
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE employees
            SET updated_at = CURRENT_TIMESTAMP
            WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_suppliers_updated_at
        AFTER UPDATE ON suppliers
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE suppliers
            SET updated_at = CURRENT_TIMESTAMP
            WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_stores_updated_at
        AFTER UPDATE ON stores
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE stores
            SET updated_at = CURRENT_TIMESTAMP
            WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_pot_plants_updated_at
        AFTER UPDATE ON pot_plants
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE pot_plants
            SET updated_at = CURRENT_TIMESTAMP
            WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_orders_updated_at
        AFTER UPDATE ON orders
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE orders
            SET updated_at = CURRENT_TIMESTAMP
            WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_purchase_orders_updated_at
        AFTER UPDATE ON purchase_orders
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE purchase_orders
            SET updated_at = CURRENT_TIMESTAMP
            WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_cart_items_updated_at
        AFTER UPDATE ON cart_items
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE cart_items
            SET updated_at = CURRENT_TIMESTAMP
            WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_store_inventory_updated_at
        AFTER UPDATE ON store_inventory
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
            UPDATE store_inventory
            SET updated_at = CURRENT_TIMESTAMP
            WHERE id = NEW.id;
        END;

        ------------------------------------------------------------------------
        -- ИСТОРИЯ СТАТУСОВ ПОЛЬЗОВАТЕЛЕЙ
        ------------------------------------------------------------------------

        CREATE TRIGGER IF NOT EXISTS trg_user_status_history
        AFTER UPDATE OF status ON users
        FOR EACH ROW
        WHEN OLD.status != NEW.status
        BEGIN
            INSERT INTO user_status_history (user_id, old_status, new_status, reason)
            VALUES (NEW.id, OLD.status, NEW.status, NEW.blocked_reason);
        END;

        ------------------------------------------------------------------------
        -- ПРОВЕРКА ТИПА ЗАКАЗА
        ------------------------------------------------------------------------

        CREATE TRIGGER IF NOT EXISTS trg_validate_delivery_order
        BEFORE INSERT ON orders
        FOR EACH ROW
        WHEN NEW.order_type = 'delivery' AND (NEW.address IS NULL OR TRIM(NEW.address) = '')
        BEGIN
            SELECT RAISE(ABORT, 'Для заказа с доставкой необходимо указать адрес');
        END;

        CREATE TRIGGER IF NOT EXISTS trg_validate_pickup_order
        BEFORE INSERT ON orders
        FOR EACH ROW
        WHEN NEW.order_type = 'pickup' AND NEW.store_id IS NULL
        BEGIN
            SELECT RAISE(ABORT, 'Для самовывоза необходимо указать точку выдачи');
        END;

        ------------------------------------------------------------------------
        -- ИСТОРИЯ ИЗМЕНЕНИЯ СТАТУСА ЗАКАЗА
        ------------------------------------------------------------------------

        CREATE TRIGGER IF NOT EXISTS trg_track_order_status_changes
        AFTER UPDATE OF status ON orders
        FOR EACH ROW
        WHEN OLD.status != NEW.status
        BEGIN
            INSERT INTO order_status_history (order_id, old_status, new_status, changed_by)
            VALUES (NEW.id, OLD.status, NEW.status, NEW.assigned_employee_id);

            INSERT INTO order_events (order_id, event_type, event_data, created_by_employee_id)
            VALUES (
                NEW.id,
                'status_changed',
                'Статус изменен с "' || OLD.status || '" на "' || NEW.status || '"',
                NEW.assigned_employee_id
            );
        END;

        ------------------------------------------------------------------------
        -- СОБЫТИЕ СОЗДАНИЯ ЗАКАЗА
        ------------------------------------------------------------------------

        CREATE TRIGGER IF NOT EXISTS trg_order_created_event
        AFTER INSERT ON orders
        FOR EACH ROW
        BEGIN
            INSERT INTO order_events (order_id, event_type, event_data)
            VALUES (NEW.id, 'created', 'Заказ создан');
        END;

        ------------------------------------------------------------------------
        -- ОБНОВЛЕНИЕ СТАТУСА ЗАКАЗА ПРИ УСПЕШНОЙ ОПЛАТЕ
        ------------------------------------------------------------------------

        CREATE TRIGGER IF NOT EXISTS trg_payment_paid_updates_order
        AFTER INSERT ON payments
        FOR EACH ROW
        WHEN NEW.status = 'paid'
        BEGIN
            UPDATE orders
            SET payment_status = 'paid',
                is_paid = 1
            WHERE id = NEW.order_id;

            INSERT INTO order_events (order_id, event_type, event_data)
            VALUES (NEW.order_id, 'paid', 'Оплата успешно получена');
        END;

        ------------------------------------------------------------------------
        -- АВТОМАТИЧЕСКИЙ ПЕРЕСЧЕТ ДОСТУПНОГО ОСТАТКА
        ------------------------------------------------------------------------

        CREATE TRIGGER IF NOT EXISTS trg_inventory_available_insert
        AFTER INSERT ON store_inventory
        FOR EACH ROW
        BEGIN
            UPDATE store_inventory
            SET quantity_available = quantity_on_hand - quantity_reserved
            WHERE id = NEW.id;
        END;

        CREATE TRIGGER IF NOT EXISTS trg_inventory_available_update
        AFTER UPDATE OF quantity_on_hand, quantity_reserved ON store_inventory
        FOR EACH ROW
        BEGIN
            UPDATE store_inventory
            SET quantity_available = quantity_on_hand - quantity_reserved
            WHERE id = NEW.id;
        END;
        """
    )

    conn.commit()
    conn.close()


def add_sample_data() -> None:
    """
    Заполняет базу тестовыми данными.
    """
    conn = get_connection()
    cursor = conn.cursor()

    # Должности
    cursor.executemany(
        """
        INSERT OR IGNORE INTO positions (title, responsibilities, requirements)
        VALUES (?, ?, ?)
        """,
        [
            ("Флорист", "Консультация клиентов, сборка заказов, уход за растениями", "Опыт работы с растениями"),
            ("Курьер", "Доставка заказов клиентам", "Водительские права, аккуратность"),
            ("Менеджер", "Работа с заказами и клиентами", "Коммуникабельность, стрессоустойчивость"),
            ("Администратор", "Управление магазином и персоналом", "Опыт управления"),
            ("Аналитик", "Анализ продаж, складских остатков и спроса", "SQL, Excel, аналитическое мышление"),
            ("Закупщик", "Работа с поставщиками и закупками", "Навыки переговоров, учет поставок"),
        ],
    )

    # Точки
    cursor.executemany(
        """
        INSERT OR IGNORE INTO stores (name, address, phone, email, store_type)
        VALUES (?, ?, ?, ?, ?)
        """,
        [
            ("Центральный магазин", "ул. Цветочная, 10", "+74950000001", "central@flowers.local", "shop"),
            ("Склад Север", "ул. Складская, 3", "+74950000002", "warehouse@flowers.local", "warehouse"),
            ("Пункт самовывоза Юг", "пр. Южный, 15", "+74950000003", "pickup@flowers.local", "pickup_point"),
        ],
    )

    # Поставщики
    cursor.executemany(
        """
        INSERT OR IGNORE INTO suppliers (name, address, contact_person, phone, email, staff_info)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        [
            ('Оранжерея "Райский сад"', "ул. Цветочная, 15", "Иванов Петр", "+74951111111", "supplier1@flowers.local", "12 сотрудников"),
            ('Теплицы "Экзотик"', "ул. Парковая, 28", "Сидорова Мария", "+74952222222", "supplier2@flowers.local", "8 сотрудников"),
            ('Питомник "Декоративные растения"', "ул. Садовая, 5", "Кузнецов Алексей", "+74953333333", "supplier3@flowers.local", "10 сотрудников"),
        ],
    )

    # Категории
    cursor.executemany(
        """
        INSERT OR IGNORE INTO categories (name, description, parent_id)
        VALUES (?, ?, ?)
        """,
        [
            ("Цветущие", "Комнатные цветущие растения", None),
            ("Суккуленты и кактусы", "Засухоустойчивые растения", None),
            ("Хвойные", "Мини-хвойные для дома и террасы", None),
            ("Фикусы", "Разновидности фикусов", None),
            ("Декоративно-лиственные", "Растения с красивой листвой", None),
        ],
    )

    # Типы растений
    cursor.executemany(
        """
        INSERT OR IGNORE INTO plant_types (code, name)
        VALUES (?, ?)
        """,
        [
            ("succulent", "Суккулент"),
            ("cactus", "Кактус"),
            ("flowering", "Цветущее"),
            ("foliage", "Декоративно-лиственное"),
            ("conifer", "Хвойное"),
        ],
    )

    # Материалы горшков
    cursor.executemany(
        """
        INSERT OR IGNORE INTO pot_materials (name, description)
        VALUES (?, ?)
        """,
        [
            ("Пластик", "Легкий и практичный"),
            ("Керамика", "Эстетичная глазурованная керамика"),
            ("Глина", "Натуральная терракота"),
            ("Стекло", "Декоративные прозрачные варианты"),
            ("Металл", "Современный стиль"),
            ("Дерево", "Экологичный материал"),
        ],
    )

    # Размеры горшков
    cursor.executemany(
        """
        INSERT OR IGNORE INTO pot_sizes (code, name, diameter_cm, height_cm, volume_liters)
        VALUES (?, ?, ?, ?, ?)
        """,
        [
            ("S", "Маленький", 12, 10, 0.8),
            ("M", "Средний", 16, 13, 1.5),
            ("L", "Большой", 20, 16, 2.5),
            ("XL", "Очень большой", 25, 20, 4.0),
        ],
    )

    # Цвета горшков
    cursor.executemany(
        """
        INSERT OR IGNORE INTO pot_colors (name, hex_code)
        VALUES (?, ?)
        """,
        [
            ("Белый", "#FFFFFF"),
            ("Черный", "#000000"),
            ("Терракотовый", "#E2725B"),
            ("Зеленый", "#228B22"),
            ("Синий", "#1E90FF"),
            ("Разноцветный", "#FFD700"),
        ],
    )

    # Способы оплаты
    cursor.executemany(
        """
        INSERT OR IGNORE INTO payment_methods (code, name)
        VALUES (?, ?)
        """,
        [
            ("cash", "Наличные"),
            ("card", "Карта"),
            ("sbp", "СБП"),
            ("online", "Онлайн"),
        ],
    )

    # Цены на горшки
    cursor.executemany(
        """
        INSERT OR IGNORE INTO pot_prices (material_id, size_id, price)
        VALUES (?, ?, ?)
        """,
        [
            (1, 1, 150.00), (1, 2, 200.00), (1, 3, 250.00), (1, 4, 300.00),
            (2, 1, 300.00), (2, 2, 400.00), (2, 3, 500.00), (2, 4, 600.00),
            (3, 1, 250.00), (3, 2, 350.00), (3, 3, 450.00), (3, 4, 550.00),
            (4, 1, 400.00), (4, 2, 550.00), (4, 3, 700.00), (4, 4, 850.00),
            (5, 1, 350.00), (5, 2, 450.00), (5, 3, 550.00), (5, 4, 650.00),
            (6, 1, 280.00), (6, 2, 380.00), (6, 3, 480.00), (6, 4, 580.00),
        ],
    )

    # Товары
    cursor.executemany(
        """
        INSERT OR IGNORE INTO pot_plants (
            sku, name, description, supplier_id, category_id, plant_type_id,
            base_price, cost_price, recommended_pot_size_id, height_cm,
            care_instructions, light_requirements, watering_frequency,
            rating, main_image_url, is_active
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            ("PL-001", "Эчеверия", "Красивый суккулент с розеткой мясистых листьев", 3, 2, 1, 650.00, 350.00, 1, 15, "Минимальный полив, много света", "full_sun", "1 раз в 2 недели", 4.8, "img/1.png", 1),
            ("PL-002", "Опунция", "Кактус с плоскими стеблями и колючками", 3, 2, 2, 750.00, 420.00, 2, 25, "Редкий полив, прямые солнечные лучи", "full_sun", "1 раз в 3 недели", 4.3, "img/2.png", 1),
            ("PL-003", "Сансевиерия", "Неприхотливое растение с длинными вертикальными листьями", 3, 5, 4, 500.00, 280.00, 1, 30, "Умеренный полив, переносит тень", "shade", "1 раз в 2 недели", 4.9, "img/3.png", 1),
            ("PL-004", "Кудрявый фикус Барок", "Кудрявый невысокий фикус с красивыми листьями", 1, 4, 4, 1200.00, 700.00, 2, 35, "Регулярный полив, опрыскивание", "partial_shade", "1 раз в неделю", 4.7, "img/4.png", 1),
            ("PL-005", "Фикус Бенджамина Вариегата", "Фикус с белым обрамлением листьев", 1, 4, 4, 1500.00, 900.00, 2, 45, "Регулярный полив, избегать сквозняков", "partial_shade", "1 раз в неделю", 4.9, "img/5.png", 1),
            ("PL-006", "Фикус Natasja", "Компактный фикус для дома и офиса", 1, 4, 4, 1100.00, 650.00, 1, 25, "Умеренный полив", "partial_shade", "1 раз в 10 дней", 4.5, "img/6.png", 1),
            ("PL-007", "Фиалка Коршунова", "Комнатное цветущее растение", 1, 1, 3, 550.00, 300.00, 1, 12, "Полив в поддон", "partial_shade", "2-3 раза в неделю", 4.8, "img/7.png", 1),
            ("PL-008", "Азалия Вервениана", "Сильно ветвистое цветущее растение", 2, 1, 3, 1800.00, 1100.00, 2, 40, "Регулярный полив, подкормка во время цветения", "partial_shade", "2 раза в неделю", 4.6, "img/8.png", 1),
            ("PL-009", "Бегония Элатиор Кармен", "Многолетнее растение с ярким цветением", 1, 1, 3, 850.00, 500.00, 1, 18, "Регулярный полив, опрыскивание", "shade", "2 раза в неделю", 4.4, "img/9.png", 1),
            ("PL-010", "Сосна горная", "Пышная сосна с колючими веточками", 3, 3, 5, 2200.00, 1400.00, 3, 60, "Редкий полив, свежий воздух", "full_sun", "1 раз в 2 недели", 4.9, "img/10.png", 1),
            ("PL-011", "Ель Коника", "Высокая ель с конусовидной формой", 3, 3, 5, 2800.00, 1750.00, 3, 70, "Умеренный полив, защита от прямого солнца", "partial_shade", "1 раз в неделю", 4.7, "img/11.png", 1),
            ("PL-012", "Туя", "Компактное хвойное растение", 3, 3, 5, 1900.00, 1150.00, 2, 50, "Регулярный полив, опрыскивание", "full_sun", "1 раз в неделю", 4.5, "img/12.png", 1),
        ],
    )

    # Дополнительные фотографии товаров
    cursor.executemany(
        """
        INSERT OR IGNORE INTO plant_images (plant_id, image_url, sort_order, is_main, alt_text, is_active)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        [
            (1, "img/1.png", 0, 1, "Эчеверия - главное фото", 1),
            (1, "img/1_2.png", 1, 0, "Эчеверия - вид сбоку", 1),
            (1, "img/1_3.png", 2, 0, "Эчеверия в интерьере", 1),

            (2, "img/2.png", 0, 1, "Опунция - главное фото", 1),
            (2, "img/2_2.png", 1, 0, "Опунция крупный план", 1),

            (5, "img/5.png", 0, 1, "Фикус Бенджамина - главное фото", 1),
            (5, "img/5_2.png", 1, 0, "Фикус Бенджамина в кашпо", 1),

            (8, "img/8.png", 0, 1, "Азалия - главное фото", 1),
            (8, "img/8_2.png", 1, 0, "Азалия в магазине", 1),

            (10, "img/10.png", 0, 1, "Сосна горная - главное фото", 1),
            (10, "img/10_2.png", 1, 0, "Сосна горная крупный план", 1),
        ],
    )

    # Пользователи
    cursor.executemany(
        """
        INSERT OR IGNORE INTO users (telegram_id, name, phone, email, status)
        VALUES (?, ?, ?, ?, ?)
        """,
        [
            (123456789, "Анна", "+79161234567", "anna@test.local", "active"),
            (987654321, "Иван", "+79167654321", "ivan@test.local", "active"),
            (555555555, "Мария", "+79165554433", "maria@test.local", "active"),
            (111111111, "Ольга", "+79161112233", "olga@test.local", "active"),
            (5287879603, "Михаил", "+79507045044", "mihail@test.local", "active"),
            (222222222, "Дмитрий", "+79162223344", "dmitry@test.local", "active"),
            (333333333, "Екатерина", "+79163334455", "ekaterina@test.local", "active"),
            (444444444, "Заблокированный клиент", "+79164445566", "blocked@test.local", "blocked"),
        ],
    )

    # Сотрудники
    cursor.executemany(
        """
        INSERT OR IGNORE INTO employees (user_id, position_id, store_id, salary, is_active)
        VALUES (?, ?, ?, ?, ?)
        """,
        [
            (4, 1, 1, 45000.00, 1),   # Ольга
            (5, 4, 1, 200000.00, 1),  # Михаил
            (6, 2, 1, 40000.00, 1),   # Дмитрий
            (7, 3, 1, 50000.00, 1),   # Екатерина
        ],
    )

    # Сессии пользователей
    now = datetime.now(UTC)
    future = now + timedelta(days=30)

    cursor.executemany(
        """
        INSERT OR IGNORE INTO user_sessions (
            user_id, device_id, session_token, refresh_token,
            device_name, platform, ip_address, user_agent,
            is_active, last_seen_at, expires_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (1, "iphone_anna_1", "sess_anna_1", "ref_anna_1", "iPhone 14", "iOS", "10.0.0.1", "Telegram iOS", 1, now.isoformat(), future.isoformat()),
            (1, "ipad_anna_2", "sess_anna_2", "ref_anna_2", "iPad", "iOS", "10.0.0.2", "Telegram iPad", 1, now.isoformat(), future.isoformat()),
            (2, "android_ivan_1", "sess_ivan_1", "ref_ivan_1", "Samsung S24", "Android", "10.0.0.3", "Telegram Android", 1, now.isoformat(), future.isoformat()),
        ],
    )

    # OAuth-коды
    oauth_exp = now + timedelta(minutes=10)
    cursor.executemany(
        """
        INSERT OR IGNORE INTO oauth_codes (user_id, device_id, code, expires_at, used)
        VALUES (?, ?, ?, ?, ?)
        """,
        [
            (1, "iphone_anna_1", "111222", oauth_exp.isoformat(), 0),
            (2, "android_ivan_1", "333444", oauth_exp.isoformat(), 0),
        ],
    )

    # Остатки по складам
    cursor.executemany(
        """
        INSERT OR IGNORE INTO store_inventory (
            store_id, plant_id, quantity_on_hand, quantity_reserved, quantity_available, reorder_point
        )
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        [
            (1, 1, 10, 1, 9, 3),
            (1, 2, 8, 0, 8, 2),
            (1, 3, 20, 2, 18, 5),
            (1, 4, 7, 1, 6, 2),
            (1, 5, 12, 2, 10, 3),
            (1, 6, 5, 0, 5, 2),
            (1, 7, 6, 0, 6, 2),
            (1, 8, 15, 3, 12, 4),
            (1, 9, 10, 0, 10, 3),
            (1, 10, 5, 0, 5, 2),
            (1, 11, 4, 0, 4, 2),
            (1, 12, 6, 0, 6, 2),

            (2, 1, 20, 0, 20, 5),
            (2, 2, 15, 0, 15, 5),
            (2, 3, 30, 0, 30, 10),
            (2, 4, 10, 0, 10, 3),
            (2, 5, 14, 0, 14, 4),
            (2, 10, 8, 0, 8, 2),
            (2, 11, 7, 0, 7, 2),
            (2, 12, 9, 0, 9, 3),

            (3, 7, 5, 0, 5, 2),
            (3, 8, 6, 1, 5, 2),
            (3, 9, 4, 0, 4, 2),
        ],
    )

    # Движения товаров
    cursor.executemany(
        """
        INSERT OR IGNORE INTO inventory_movements (
            store_id, plant_id, movement_type, quantity, unit_cost, comment, created_by_employee_id
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (1, 1, "adjustment", 10, 350.00, "Стартовый остаток", 2),
            (1, 3, "adjustment", 20, 280.00, "Стартовый остаток", 2),
            (2, 5, "adjustment", 14, 900.00, "Стартовый остаток", 2),
            (3, 8, "adjustment", 6, 1100.00, "Стартовый остаток", 2),
        ],
    )

    # Корзина
    cursor.executemany(
        """
        INSERT OR IGNORE INTO cart_items (
            user_id, plant_id, quantity, pot_color_id, pot_size_id, pot_material_id,
            plant_unit_price, pot_unit_price, total_price
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (1, 1, 2, 1, 1, 2, 650.00, 300.00, 1900.00),
            (1, 5, 1, 2, 2, 3, 1500.00, 350.00, 1850.00),
            (2, 8, 1, 3, 2, 2, 1800.00, 400.00, 2200.00),
        ],
    )

    # Избранное
    cursor.executemany(
        """
        INSERT OR IGNORE INTO wishlist_items (user_id, plant_id)
        VALUES (?, ?)
        """,
        [
            (1, 8),
            (1, 10),
            (2, 5),
            (3, 11),
        ],
    )

    # Заказы
    cursor.executemany(
        """
        INSERT OR IGNORE INTO orders (
            order_number, order_date, delivery_date, user_id, order_type, store_id, address,
            customer_comment, subtotal, delivery_fee, discount_amount, total_price,
            payment_method_id, payment_status, is_paid, assigned_employee_id, status, source_channel
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (
                "ORD-20260001",
                "2026-03-01 10:15:00",
                "2026-03-02 14:00:00",
                1,
                "delivery",
                1,
                "Москва, ул. Лесная, 12",
                "Позвонить за 30 минут",
                2550.00,
                300.00,
                100.00,
                2750.00,
                2,
                "paid",
                1,
                4,
                "completed",
                "telegram"
            ),
            (
                "ORD-20260002",
                "2026-03-03 12:00:00",
                None,
                2,
                "pickup",
                3,
                None,
                "Самовывоз вечером",
                2200.00,
                0.00,
                0.00,
                2200.00,
                4,
                "pending",
                0,
                4,
                "ready_for_pickup",
                "telegram"
            ),
            (
                "ORD-20260003",
                "2026-03-05 09:30:00",
                "2026-03-05 18:00:00",
                3,
                "delivery",
                1,
                "Москва, ул. Солнечная, 7",
                None,
                1450.00,
                250.00,
                0.00,
                1700.00,
                3,
                "failed",
                0,
                4,
                "cancelled",
                "site"
            ),
        ],
    )

    # Позиции заказов
    cursor.executemany(
        """
        INSERT OR IGNORE INTO order_items (
            order_id, plant_id, plant_name_snapshot, plant_description_snapshot,
            quantity, plant_unit_price, unit_cost,
            pot_color_id, pot_size_id, pot_material_id, pot_unit_price,
            discount_amount, total_price, store_id, fulfilled_quantity, returned_quantity
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (1, 1, "Эчеверия", "Красивый суккулент с розеткой мясистых листьев", 2, 650.00, 350.00, 1, 1, 2, 300.00, 50.00, 1850.00, 1, 2, 0),
            (1, 7, "Фиалка Коршунова", "Комнатное цветущее растение", 1, 550.00, 300.00, 3, 1, 1, 150.00, 50.00, 650.00, 1, 1, 0),

            (2, 8, "Азалия Вервениана", "Сильно ветвистое цветущее растение", 1, 1800.00, 1100.00, 1, 2, 2, 400.00, 0.00, 2200.00, 3, 0, 0),

            (3, 4, "Кудрявый фикус Барок", "Кудрявый невысокий фикус с красивыми листьями", 1, 1200.00, 700.00, 2, 2, 3, 250.00, 0.00, 1450.00, 1, 0, 0),
        ],
    )

    # Отмены заказов
    cursor.executemany(
        """
        INSERT OR IGNORE INTO order_cancellations (
            order_id, cancelled_by_type, cancelled_by_employee_id, reason_code, reason_text
        )
        VALUES (?, ?, ?, ?, ?)
        """,
        [
            (3, "system", None, "payment_timeout", "Платеж не был подтвержден вовремя"),
        ],
    )

    # История статусов заказов
    cursor.executemany(
        """
        INSERT OR IGNORE INTO order_status_history (
            order_id, old_status, new_status, changed_by, change_reason, created_at
        )
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        [
            (1, "new", "processing", 4, "Заказ принят в работу", "2026-03-01 10:20:00"),
            (1, "processing", "assembled", 1, "Заказ собран флористом", "2026-03-01 12:00:00"),
            (1, "assembled", "shipped", 3, "Передан курьеру", "2026-03-02 12:30:00"),
            (1, "shipped", "delivered", 3, "Доставлен клиенту", "2026-03-02 14:10:00"),
            (1, "delivered", "completed", 4, "Заказ закрыт", "2026-03-02 18:00:00"),

            (2, "new", "processing", 4, "Заказ принят", "2026-03-03 12:15:00"),
            (2, "processing", "assembled", 1, "Заказ собран", "2026-03-03 14:00:00"),
            (2, "assembled", "ready_for_pickup", 4, "Готов к самовывозу", "2026-03-03 15:00:00"),

            (3, "new", "cancelled", 4, "Отмена из-за неуспешной оплаты", "2026-03-05 11:00:00"),
        ],
    )

    # События заказов
    cursor.executemany(
        """
        INSERT OR IGNORE INTO order_events (
            order_id, event_type, event_data, created_by_employee_id, created_at
        )
        VALUES (?, ?, ?, ?, ?)
        """,
        [
            (1, "created", "Заказ создан", None, "2026-03-01 10:15:00"),
            (1, "paid", "Оплата получена", None, "2026-03-01 10:16:00"),
            (1, "assembled", "Заказ собран", 1, "2026-03-01 12:00:00"),
            (1, "shipped", "Заказ передан в доставку", 3, "2026-03-02 12:30:00"),
            (1, "delivered", "Заказ доставлен", 3, "2026-03-02 14:10:00"),
            (1, "completed", "Заказ завершен", 4, "2026-03-02 18:00:00"),

            (2, "created", "Заказ создан", None, "2026-03-03 12:00:00"),
            (2, "ready_for_pickup", "Готов к самовывозу", 4, "2026-03-03 15:00:00"),

            (3, "created", "Заказ создан", None, "2026-03-05 09:30:00"),
            (3, "payment_failed", "Оплата не прошла", None, "2026-03-05 10:30:00"),
            (3, "cancelled", "Заказ отменен", 4, "2026-03-05 11:00:00"),
        ],
    )

    # Платежные ссылки
    cursor.executemany(
        """
        INSERT OR IGNORE INTO payment_links (
            user_id, order_id, amount, payment_url, status, expires_at, payment_system_id, payment_confirmed_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (1, 1, 2750.00, "https://pay.local/order1", "paid", "2026-03-01 11:15:00", "ps_001", "2026-03-01 10:16:00"),
            (2, 2, 2200.00, "https://pay.local/order2", "pending", "2026-03-03 14:00:00", "ps_002", None),
            (3, 3, 1700.00, "https://pay.local/order3", "expired", "2026-03-05 10:30:00", "ps_003", None),
        ],
    )

    # Платежи
    cursor.executemany(
        """
        INSERT OR IGNORE INTO payments (
            order_id, user_id, amount, payment_method_id, status,
            external_payment_id, paid_at, failed_at, refund_amount, refunded_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (1, 1, 2750.00, 2, "paid", "ext_pay_001", "2026-03-01 10:16:00", None, 0.00, None),
            (2, 2, 2200.00, 4, "pending", "ext_pay_002", None, None, 0.00, None),
            (3, 3, 1700.00, 3, "failed", "ext_pay_003", None, "2026-03-05 10:30:00", 0.00, None),
        ],
    )

    # Отзывы
    cursor.executemany(
        """
        INSERT OR IGNORE INTO reviews (user_id, order_id, rating, comment)
        VALUES (?, ?, ?, ?)
        """,
        [
            (1, 1, 5, "Отличные растения и быстрая доставка"),
        ],
    )

    # Заказы поставщикам
    cursor.executemany(
        """
        INSERT OR IGNORE INTO purchase_orders (
            purchase_number, supplier_id, store_id, created_by_employee_id,
            status, expected_delivery_date, ordered_at, received_at, comment, total_amount
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            ("PO-20260001", 3, 2, 2, "received", "2026-02-25 12:00:00", "2026-02-20 10:00:00", "2026-02-25 11:30:00", "Поставка суккулентов и хвойных", 19600.00),
            ("PO-20260002", 1, 1, 2, "partially_received", "2026-03-07 15:00:00", "2026-03-04 09:00:00", None, "Поставка фикусов", 11100.00),
        ],
    )

    # Позиции заказов поставщикам
    cursor.executemany(
        """
        INSERT OR IGNORE INTO purchase_order_items (
            purchase_order_id, plant_id, ordered_quantity, received_quantity,
            rejected_quantity, unit_cost, line_total, comment
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (1, 1, 20, 20, 0, 350.00, 7000.00, "Эчеверия"),
            (1, 10, 6, 6, 0, 1400.00, 8400.00, "Сосна горная"),
            (1, 11, 2, 2, 0, 2100.00, 4200.00, "Ель Коника"),

            (2, 4, 6, 4, 1, 700.00, 4200.00, "Фикус Барок"),
            (2, 5, 6, 5, 0, 900.00, 5400.00, "Фикус Бенджамина Вариегата"),
            (2, 6, 2, 0, 0, 750.00, 1500.00, "Фикус Natasja"),
        ],
    )

    # Приемки поставок
    cursor.executemany(
        """
        INSERT OR IGNORE INTO purchase_receipts (
            purchase_order_id, received_by_employee_id, received_at, comment
        )
        VALUES (?, ?, ?, ?)
        """,
        [
            (1, 2, "2026-02-25 11:30:00", "Поставка принята полностью"),
            (2, 2, "2026-03-07 16:10:00", "Частичная приемка, есть брак"),
        ],
    )

    # Позиции приемки
    cursor.executemany(
        """
        INSERT OR IGNORE INTO purchase_receipt_items (
            purchase_receipt_id, purchase_order_item_id, accepted_quantity, rejected_quantity, reject_reason
        )
        VALUES (?, ?, ?, ?, ?)
        """,
        [
            (1, 1, 20, 0, None),
            (1, 2, 6, 0, None),
            (1, 3, 2, 0, None),

            (2, 4, 4, 1, "Повреждение листьев"),
            (2, 5, 5, 0, None),
            (2, 6, 0, 0, None),
        ],
    )

    conn.commit()
    conn.close()


def is_employee(telegram_id: int) -> bool:
    """
    Проверяет, является ли пользователь сотрудником.
    """
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        """
        SELECT COUNT(*)
        FROM employees e
        JOIN users u ON u.id = e.user_id
        WHERE u.telegram_id = ? AND e.is_active = 1
        """,
        (telegram_id,),
    )

    result = cursor.fetchone()[0] > 0
    conn.close()
    return result


def get_employee_info(telegram_id: int):
    """
    Возвращает информацию о сотруднике по telegram_id.
    """
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        """
        SELECT
            e.id,
            e.salary,
            e.hire_date,
            e.is_active,
            p.title AS position_title,
            u.name,
            u.phone,
            s.name AS store_name
        FROM employees e
        JOIN users u ON u.id = e.user_id
        JOIN positions p ON e.position_id = p.id
        LEFT JOIN stores s ON e.store_id = s.id
        WHERE u.telegram_id = ? AND e.is_active = 1
        """,
        (telegram_id,),
    )

    employee = cursor.fetchone()
    conn.close()
    return employee


def block_user(user_id: int, reason: str) -> None:
    """
    Блокирует пользователя и деактивирует все его сессии.
    """
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        """
        UPDATE users
        SET status = 'blocked',
            blocked_at = CURRENT_TIMESTAMP,
            blocked_reason = ?
        WHERE id = ?
        """,
        (reason, user_id),
    )

    cursor.execute(
        """
        UPDATE user_sessions
        SET is_active = 0,
            revoked_at = CURRENT_TIMESTAMP,
            revoke_reason = 'user_blocked'
        WHERE user_id = ? AND is_active = 1
        """,
        (user_id,),
    )

    conn.commit()
    conn.close()


def recalculate_order_total(order_id: int) -> float:
    """
    Пересчитывает итоговую сумму заказа на Python-стороне.
    """
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        """
        SELECT COALESCE(SUM(total_price), 0)
        FROM order_items
        WHERE order_id = ?
        """,
        (order_id,),
    )
    subtotal = cursor.fetchone()[0] or 0

    cursor.execute(
        """
        SELECT delivery_fee, discount_amount
        FROM orders
        WHERE id = ?
        """,
        (order_id,),
    )
    row = cursor.fetchone()

    if not row:
        conn.close()
        raise ValueError(f"Заказ с id={order_id} не найден")

    delivery_fee = row["delivery_fee"] or 0
    discount_amount = row["discount_amount"] or 0
    total = round(subtotal + delivery_fee - discount_amount, 2)

    cursor.execute(
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


def reset_database() -> None:
    """
    Полностью удаляет все таблицы и триггеры.
    Использовать только в разработке.
    """
    conn = get_connection()
    cursor = conn.cursor()

    cursor.executescript(
        """
        DROP TRIGGER IF EXISTS trg_users_updated_at;
        DROP TRIGGER IF EXISTS trg_employees_updated_at;
        DROP TRIGGER IF EXISTS trg_suppliers_updated_at;
        DROP TRIGGER IF EXISTS trg_stores_updated_at;
        DROP TRIGGER IF EXISTS trg_pot_plants_updated_at;
        DROP TRIGGER IF EXISTS trg_orders_updated_at;
        DROP TRIGGER IF EXISTS trg_purchase_orders_updated_at;
        DROP TRIGGER IF EXISTS trg_cart_items_updated_at;
        DROP TRIGGER IF EXISTS trg_store_inventory_updated_at;
        DROP TRIGGER IF EXISTS trg_user_status_history;
        DROP TRIGGER IF EXISTS trg_validate_delivery_order;
        DROP TRIGGER IF EXISTS trg_validate_pickup_order;
        DROP TRIGGER IF EXISTS trg_track_order_status_changes;
        DROP TRIGGER IF EXISTS trg_order_created_event;
        DROP TRIGGER IF EXISTS trg_payment_paid_updates_order;
        DROP TRIGGER IF EXISTS trg_inventory_available_insert;
        DROP TRIGGER IF EXISTS trg_inventory_available_update;
        """
    )

    tables = [
        "purchase_receipt_items",
        "purchase_receipts",
        "purchase_order_items",
        "purchase_orders",
        "reviews",
        "payments",
        "payment_links",
        "order_cancellations",
        "order_events",
        "order_status_history",
        "order_items",
        "orders",
        "wishlist_items",
        "cart_items",
        "inventory_movements",
        "store_inventory",
        "oauth_codes",
        "user_sessions",
        "employees",
        "user_status_history",
        "users",
        "plant_images",
        "pot_plants",
        "pot_prices",
        "payment_methods",
        "pot_colors",
        "pot_sizes",
        "pot_materials",
        "plant_types",
        "categories",
        "stores",
        "suppliers",
        "positions",
    ]

    for table in tables:
        cursor.execute(f"DROP TABLE IF EXISTS {table}")

    conn.commit()
    conn.close()


if __name__ == "__main__":
    create_database()
    create_indexes()
    create_triggers()
    add_sample_data()
    print("База данных успешно создана и заполнена тестовыми данными.")