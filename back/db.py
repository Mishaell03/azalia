import os
import sqlite3
from datetime import datetime, timedelta

def create_database():
    conn = sqlite3.connect('flower_shop.db')
    cursor = conn.cursor()
    base_dir = os.path.abspath(os.path.dirname(__file__))
    db_path = os.path.join(base_dir, 'flower_shop.db')

    cursor.execute('PRAGMA foreign_keys = ON')

    # должности
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS positions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL UNIQUE,
            responsibilities TEXT,
            requirements TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')

    # поставщики
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS suppliers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            address TEXT NOT NULL,
            contact_person TEXT NOT NULL,
            staff_info TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')

    # категории растений
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            description TEXT,
            parent_id INTEGER,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (parent_id) REFERENCES categories (id) ON DELETE SET NULL
        )
    ''')

    # материалы горшков
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS pot_materials (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            description TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')

    # размеры горшков
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS pot_sizes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            diameter_cm INTEGER,
            height_cm INTEGER,
            volume_liters DECIMAL(5,2),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')

    # цвета горшков
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS pot_colors (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            hex_code TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')

    # стоимость горшков
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS pot_prices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            material_id INTEGER NOT NULL,
            size_id INTEGER NOT NULL,
            price DECIMAL(10,2) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (material_id) REFERENCES pot_materials (id) ON DELETE CASCADE,
            FOREIGN KEY (size_id) REFERENCES pot_sizes (id) ON DELETE CASCADE,
            UNIQUE(material_id, size_id)
        )
    ''')

    # горшечные растения
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS pot_plants (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            description TEXT,
            base_price DECIMAL(10,2) NOT NULL,
            supplier_id INTEGER,
            category_id INTEGER NOT NULL,
            plant_type INTEGER NOT NULL,
            recommended_pot_size TEXT CHECK(recommended_pot_size IN ('S', 'M', 'L', 'XL')),
            height_cm INTEGER,
            care_instructions TEXT,
            light_requirements TEXT CHECK(light_requirements IN ('full_sun', 'partial_shade', 'shade')),
            watering_frequency TEXT,
            in_stock BOOLEAN DEFAULT TRUE,
            rating DECIMAL(3,2) CHECK(rating >= 0 AND rating <= 5),
            image_url TEXT,
            stock_quantity INTEGER NOT NULL DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE SET NULL,
            FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE RESTRICT,
            FOREIGN KEY (plant_type) REFERENCES categories (id) ON DELETE RESTRICT
        )
    ''')

    # пользователи (основная таблица для всех)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            telegram_id INTEGER UNIQUE NOT NULL,
            name TEXT NOT NULL,
            phone TEXT NOT NULL,
            session_token TEXT UNIQUE,
            token_expires_at TIMESTAMP,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')

    # сотрудники (дополнительная информация для работников)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS employees (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            telegram_id INTEGER UNIQUE NOT NULL,
            position_id INTEGER NOT NULL,
            salary DECIMAL(10,2),
            hire_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (telegram_id) REFERENCES users(telegram_id) ON DELETE CASCADE,
            FOREIGN KEY (position_id) REFERENCES positions (id) ON DELETE RESTRICT
        )
    ''')

    # заказы
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            delivery_date TIMESTAMP CHECK(delivery_date >= order_date),
            user_id INTEGER NOT NULL,
            address TEXT NOT NULL,
            total_price DECIMAL(10,2) NOT NULL,
            payment_method TEXT CHECK(payment_method IN ('cash', 'card')),
            is_paid BOOLEAN DEFAULT FALSE,
            assigned_employee_id INTEGER,
            status TEXT DEFAULT 'new' CHECK(status IN ('new', 'processing', 'delivered', 'cancelled')),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
            FOREIGN KEY (assigned_employee_id) REFERENCES employees (id) ON DELETE SET NULL
        )
    ''')

    # позиции заказа с характеристиками горшка
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS order_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER NOT NULL,
            plant_id INTEGER NOT NULL,
            quantity INTEGER NOT NULL DEFAULT 1,
            plant_unit_price DECIMAL(10,2) NOT NULL,
            pot_color TEXT CHECK(pot_color IN ('white', 'black', 'terracotta', 'green', 'blue', 'multicolor')),
            pot_size TEXT CHECK(pot_size IN ('S', 'M', 'L', 'XL')),
            pot_material TEXT CHECK(pot_material IN ('ceramic', 'plastic', 'clay', 'glass', 'metal', 'wood')),
            pot_unit_price DECIMAL(10,2) DEFAULT 0,
            total_price DECIMAL(10,2) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
            FOREIGN KEY (plant_id) REFERENCES pot_plants (id) ON DELETE RESTRICT
        )
    ''')

    # ссылки на оплату
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS payment_links (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            order_id INTEGER,
            amount DECIMAL(10,2) NOT NULL,
            payment_url TEXT UNIQUE,
            status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'paid', 'expired', 'cancelled')),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            expires_at TIMESTAMP,
            payment_system_id TEXT,
            payment_confirmed_at TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
            FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE SET NULL
        )
    ''')

    # статус заказа
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS order_status_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER NOT NULL,
            old_status TEXT,
            new_status TEXT NOT NULL,
            changed_by INTEGER,
            change_reason TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
            FOREIGN KEY (changed_by) REFERENCES employees (id) ON DELETE SET NULL
        )
    ''')

    # отзывы
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS reviews (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            order_id INTEGER NOT NULL,
            rating INTEGER NOT NULL CHECK(rating >= 1 AND rating <= 5),
            comment TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
            FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
        )
    ''')
    
    # OAuth коды для авторизации по device_id
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS oauth_codes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            telegram_id INTEGER NOT NULL,
            device_id TEXT NOT NULL CHECK(length(device_id) <= 255),
            code TEXT NOT NULL UNIQUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            expires_at TIMESTAMP NOT NULL,
            used BOOLEAN DEFAULT FALSE,
            used_at TIMESTAMP,
            FOREIGN KEY (telegram_id) REFERENCES users(telegram_id) ON DELETE CASCADE
        )
    ''')

    # корзина пользователя
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS cart_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            plant_id INTEGER NOT NULL,
            quantity INTEGER NOT NULL DEFAULT 1,
            pot_color_id INTEGER,
            pot_size_id INTEGER,
            pot_material_id INTEGER,
            plant_unit_price DECIMAL(10,2) NOT NULL,
            pot_unit_price DECIMAL(10,2) DEFAULT 0,
            total_price DECIMAL(10,2) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
            FOREIGN KEY (plant_id) REFERENCES pot_plants (id) ON DELETE CASCADE,
            FOREIGN KEY (pot_color_id) REFERENCES pot_colors (id) ON DELETE SET NULL,
            FOREIGN KEY (pot_size_id) REFERENCES pot_sizes (id) ON DELETE SET NULL,
            FOREIGN KEY (pot_material_id) REFERENCES pot_materials (id) ON DELETE SET NULL
        )
    ''')

    # избранное пользователя
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS wishlist_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            plant_id INTEGER NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
            FOREIGN KEY (plant_id) REFERENCES pot_plants (id) ON DELETE CASCADE,
            UNIQUE(user_id, plant_id)
        )
    ''')

    cursor.execute('CREATE INDEX IF NOT EXISTS idx_users_telegram_id ON users(telegram_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_employees_telegram_id ON employees(telegram_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_employees_is_active ON employees(is_active)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_orders_user_status ON orders(user_id, status)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_pot_plants_category_stock ON pot_plants(category_id, in_stock)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_payment_links_user_status ON payment_links(user_id, status)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_categories_parent_id ON categories(parent_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_pot_plants_category_id ON pot_plants(category_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_pot_plants_in_stock ON pot_plants(in_stock)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_oauth_codes_device_id ON oauth_codes(device_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_oauth_codes_code ON oauth_codes(code)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_oauth_codes_telegram_id ON oauth_codes(telegram_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_oauth_codes_telegram_device ON oauth_codes(telegram_id, device_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_cart_items_user_id ON cart_items(user_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_cart_items_plant_id ON cart_items(plant_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_wishlist_items_user_id ON wishlist_items(user_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_wishlist_items_plant_id ON wishlist_items(plant_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_pot_prices_material_size ON pot_prices(material_id, size_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_cart_items_composite ON cart_items(user_id, plant_id, pot_color_id, pot_size_id, pot_material_id)')

    conn.commit()
    conn.close()

def add_sample_data():
    conn = sqlite3.connect('flower_shop.db')
    cursor = conn.cursor()
    
    # тестовые должности
    cursor.executemany('''
        INSERT OR IGNORE INTO positions (title, responsibilities, requirements)
        VALUES (?, ?, ?)
    ''', [
    ('Флорист', 'Консультация клиентов, уход за растениями', 'Опыт работы с растениями, знание флористики'),
    ('Курьер', 'Доставка заказов', 'Водительские права, аккуратное обращение с растениями'),
    ('Менеджер', 'Прием заказов, работа с клиентами', 'Коммуникабельность, знание ассортимента'),
    ('Администратор', 'Управление персоналом, контроль работы магазина, отчетность', 'Опыт управления, организаторские способности'),
    ('Аналитик', 'Анализ продаж, прогнозирование спроса, формирование отчетов', 'Аналитическое мышление, знание Excel/SQL, опыт работы с данными')     
    ])
    
    # тестовые поставщики
    cursor.executemany('''
        INSERT OR IGNORE INTO suppliers (name, address, contact_person, staff_info)
        VALUES (?, ?, ?, ?)
    ''', [
        ('Оранжерея "Райский сад"', 'ул. Цветочная, 15', 'Иванов Петр', '12 сотрудников'),
        ('Теплицы "Экзотик"', 'ул. Парковая, 28', 'Сидорова Мария', '8 сотрудников'),
        ('Питомник "Декоративные растения"', 'ул. Садовая, 5', 'Кузнецов Алексей', '10 сотрудников')
    ])
    
    # тестовые категории растений
    cursor.executemany('''
        INSERT OR IGNORE INTO categories (name, description, parent_id)
        VALUES (?, ?, ?)
    ''', [
        ('Цветущие', 'Растения с красивыми цветами', None),
        ('Кактусы', 'Засухоустойчивые растения', None),
        ('Хвоя', 'Сосен и елочек', None),
        ('Фикусы', 'Разновидности фикусов', None)
    ])
    
    cursor.executemany('''
        INSERT OR IGNORE INTO pot_materials (name, description)
        VALUES (?, ?)
    ''', [
        ('Пластик', 'Легкий и прочный пластик, подходит для большинства растений'),
        ('Керамика', 'Эстетичная глазурованная керамика с дренажными отверстиями'),
        ('Глина', 'Натуральная терракотовая глина, обеспечивает хороший воздухообмен'),
        ('Стекло', 'Прозрачное стекло для декоративных композиций'),
        ('Металл', 'Стильные металлические кашпо для современного интерьера'),
        ('Дерево', 'Экологичные деревянные кашпо ручной работы')
    ])
    
    # Размеры горшков
    cursor.executemany('''
        INSERT OR IGNORE INTO pot_sizes (code, name, diameter_cm, height_cm, volume_liters)
        VALUES (?, ?, ?, ?, ?)
    ''', [
        ('S', 'Маленький', 12, 10, 0.8),
        ('M', 'Средний', 16, 13, 1.5),
        ('L', 'Большой', 20, 16, 2.5),
        ('XL', 'Очень большой', 25, 20, 4.0)
    ])
    
    # Цвета горшков
    cursor.executemany('''
        INSERT OR IGNORE INTO pot_colors (name, hex_code)
        VALUES (?, ?)
    ''', [
        ('Белый', '#FFFFFF'),
        ('Черный', '#000000'),
        ('Терракотовый', '#E2725B'),
        ('Зеленый', '#228B22'),
        ('Синий', '#1E90FF'),
        ('Разноцветный', '#FFD700')
    ])
    
    # Цены на горшки (материал + размер)
    cursor.executemany('''
        INSERT OR IGNORE INTO pot_prices (material_id, size_id, price)
        VALUES (?, ?, ?)
    ''', [
        # Пластик (id=1)
        (1, 1, 150.00), (1, 2, 200.00), (1, 3, 250.00), (1, 4, 300.00),
        # Керамика (id=2)
        (2, 1, 300.00), (2, 2, 400.00), (2, 3, 500.00), (2, 4, 600.00),
        # Глина (id=3)
        (3, 1, 250.00), (3, 2, 350.00), (3, 3, 450.00), (3, 4, 550.00),
        # Стекло (id=4)
        (4, 1, 400.00), (4, 2, 550.00), (4, 3, 700.00), (4, 4, 850.00),
        # Металл (id=5)
        (5, 1, 350.00), (5, 2, 450.00), (5, 3, 550.00), (5, 4, 650.00),
        # Дерево (id=6)
        (6, 1, 280.00), (6, 2, 380.00), (6, 3, 480.00), (6, 4, 580.00)
    ])
    
    # тестовые горшечные растения
    cursor.executemany('''
        INSERT OR IGNORE INTO pot_plants (name, description, base_price, supplier_id, category_id, plant_type, recommended_pot_size, height_cm, care_instructions, light_requirements, watering_frequency, rating, in_stock, image_url, stock_quantity)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [ 
        # Кактусы и суккуленты (category_id=2, plant_type=2)
        ('Эчеверия', 'Красивый суккулент с розеткой мясистых листьев', 650.00, 3, 2, 2, 'S', 15, 'Минимальный полив, много света', 'full_sun', '1 раз в 2 недели', 4.8, True, 'img/1.png',4),
        ('Колючая ', 'Кактус с плоскими стеблями и колючками', 750.00, 3, 2, 2, 'M', 25, 'Редкий полив, прямые солнечные лучи', 'full_sun', '1 раз в 3 недели', 4.3, True, 'img/2.png',5),
        ('Сансевиерия', 'Неприхотливый суккулент с длинными вертикальными листьями', 500.00, 3, 2, 2, 'S', 30, 'Умеренный полив, переносит тень', 'shade', '1 раз в 2 недели', 4.9, True, 'img/3.png',10),
        # Фикусы (category_id=4, plant_type=4)
        ('Кудрявый фикус Барок', 'Кудрявый невысокий фикус с красивыми листьями', 1200.00, 1, 4, 4, 'M', 35, 'Регулярный полив, опрыскивание', 'partial_shade', '1 раз в неделю', 4.7, True, 'img/4.png',5),
        ('Фикус Бенджамина Вариегата', 'Фикус с белым обрамлением листочков', 1500.00, 1, 4, 4, 'M', 45, 'Регулярный полив, избегать сквозняков', 'partial_shade', '1 раз в неделю', 4.9, True, 'img/5.png',9),
        ('Фикус Natasja', 'Засухоустойчивый фикус', 1100.00, 1, 4, 4, 'S', 25, 'Умеренный полив', 'partial_shade', '1 раз в 10 дней', 4.5, True, 'img/6.png',1),
        
        # Цветущие растения (category_id=1, plant_type=1)
        ('Фиалка Коршунова', 'Комнатное травенистое растение', 550.00, 1, 1, 1, 'S', 12, 'Полив в поддон, избегать попадания воды на листья', 'partial_shade', '2-3 раза в неделю', 4.8, True, 'img/7.png',3),
        ('Азалия Вервениана', 'Сильно ветвистое цветущее растение', 1800.00, 2, 1, 1, 'M', 40, 'Регулярный полив, подкормка во время цветения', 'partial_shade', '2 раза в неделю', 4.6, True, 'img/8.png',15),
        ('Бегония Элатиор Кармен', 'Многолетнее растение с большим количеством листьев', 850.00, 1, 1, 1, 'S', 18, 'Регулярный полив, опрыскивание', 'shade', '2 раза в неделю', 4.4, True, 'img/9.png',5),
        
        # Хвойные растения (category_id=3, plant_type=3)
        ('Сосна горная', 'Пышная сосна с колючими веточками', 2200.00, 3, 3, 3, 'L', 60, 'Редкий полив, много свежего воздуха', 'full_sun', '1 раз в 2 недели', 4.9, True, 'img/10.png',6),
        ('Китайская ель Коника', 'Высокая ель с конусовидной формой, выведенная искусственно', 2800.00, 3, 3, 3, 'L', 70, 'Умеренный полив, защита от прямого солнца', 'partial_shade', '1 раз в неделю', 4.7, True, 'img/11.png',4),
        ('Туя', 'Медленнорастущая с компактной кроной ель с мягкими колючками', 1900.00, 3, 3, 3, 'M', 50, 'Регулярный полив, опрыскивание', 'full_sun', '1 раз в неделю', 4.5, True, 'img/12.png',4)
    ])
    
    # тестовые пользователи (все пользователи, включая работников)
    cursor.executemany('''
        INSERT OR IGNORE INTO users (telegram_id, name, phone)
        VALUES (?, ?, ?)
    ''', [
        (123456789, 'Анна Петрова', '+79161234567'),
        (987654321, 'Иван Сидоров', '+79167654321'),
        (555555555, 'Мария Иванова', '+79165554433'),
        # Работники тоже являются пользователями
        (111111111, 'Ольга Цветкова', '+79161112233'),
        (222222222, 'Дмитрий Доставкин', '+79162223344'),
        (333333333, 'Екатерина Менеджерова', '+79163334455')
    ])
    
    # тестовые сотрудники (только те, кто является работниками)
    cursor.executemany('''
        INSERT OR IGNORE INTO employees (telegram_id, position_id, salary)
        VALUES (?, ?, ?)
    ''', [
        (111111111, 1, 45000.00),  # Ольга - флорист
        (222222222, 2, 40000.00),  # Дмитрий - курьер
        (333333333, 3, 50000.00)   # Екатерина - менеджер
    ])
    
    conn.commit()
    conn.close()

def create_triggers():
    conn = sqlite3.connect('flower_shop.db')
    cursor = conn.cursor()
    
    # триггер обновления updated_at в таблице users
    cursor.execute('''
        CREATE TRIGGER IF NOT EXISTS update_users_timestamp 
        AFTER UPDATE ON users
        FOR EACH ROW
        BEGIN
            UPDATE users SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
        END
    ''')
    
    # триггер обновления updated_at в таблице employees
    cursor.execute('''
        CREATE TRIGGER IF NOT EXISTS update_employees_timestamp 
        AFTER UPDATE ON employees
        FOR EACH ROW
        BEGIN
            UPDATE employees SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
        END
    ''')
    
    # триггер обновления updated_at в таблице orders
    cursor.execute('''
        CREATE TRIGGER IF NOT EXISTS update_orders_timestamp 
        AFTER UPDATE ON orders
        FOR EACH ROW
        BEGIN
            UPDATE orders SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
        END
    ''')
    
    # триггер вставки в историю статусов
    cursor.execute('''
        CREATE TRIGGER IF NOT EXISTS track_order_status_changes 
        AFTER UPDATE OF status ON orders
        FOR EACH ROW
        WHEN OLD.status != NEW.status
        BEGIN
            INSERT INTO order_status_history (order_id, old_status, new_status, changed_by)
            VALUES (NEW.id, OLD.status, NEW.status, NEW.assigned_employee_id);
        END
    ''')
    
    # триггер расчета total_price в order_items
    cursor.execute('''
        CREATE TRIGGER IF NOT EXISTS calculate_order_item_total 
        BEFORE INSERT ON order_items
        FOR EACH ROW
        BEGIN
            UPDATE order_items 
            SET total_price = (NEW.plant_unit_price + NEW.pot_unit_price) * NEW.quantity 
            WHERE id = NEW.id;
        END
    ''')

    # триггер для обновления updated_at в cart_items
    cursor.execute('''
        CREATE TRIGGER IF NOT EXISTS calculate_cart_item_total 
        BEFORE INSERT ON cart_items
        FOR EACH ROW
        BEGIN
            UPDATE cart_items 
            SET total_price = (NEW.plant_unit_price + NEW.pot_unit_price) * NEW.quantity 
            WHERE id = NEW.id;
        END
    ''')

    # триггер для расчета total_price в cart_items
    cursor.execute('''
        CREATE TRIGGER IF NOT EXISTS update_cart_items_timestamp 
        AFTER UPDATE ON cart_items
        FOR EACH ROW
        BEGIN
            UPDATE cart_items SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
        END
    ''')

    # триггер для авто обновления in_stock на основе stock_quantity
    cursor.execute('''
        CREATE TRIGGER IF NOT EXISTS update_plant_stock_status 
        AFTER UPDATE OF stock_quantity ON pot_plants
        FOR EACH ROW
        BEGIN
            UPDATE pot_plants 
            SET in_stock = (NEW.stock_quantity > 0)
            WHERE id = NEW.id;
        END
    ''')
    
    conn.commit()
    conn.close()

def calculate_order_total(order_id):
    conn = sqlite3.connect('flower_shop.db')
    cursor = conn.cursor()
    
    cursor.execute('SELECT SUM(total_price) FROM order_items WHERE order_id = ?', (order_id,))
    
    total = cursor.fetchone()[0] or 0
    
    cursor.execute('UPDATE orders SET total_price = ? WHERE id = ?', (total, order_id))
    
    conn.commit()
    conn.close()
    return total

def is_employee(telegram_id):
    """является ли user воркером"""
    conn = sqlite3.connect('flower_shop.db')
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT COUNT(*) FROM employees 
        WHERE telegram_id = ? AND is_active = TRUE
    ''', (telegram_id,))
    
    result = cursor.fetchone()[0] > 0
    conn.close()
    return result

def get_employee_info(telegram_id):
    """инфа о работнике"""
    conn = sqlite3.connect('flower_shop.db')
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT e.*, p.title as position_title, u.name, u.phone
        FROM employees e
        JOIN positions p ON e.position_id = p.id
        JOIN users u ON e.telegram_id = u.telegram_id
        WHERE e.telegram_id = ? AND e.is_active = TRUE
    ''', (telegram_id,))
    
    employee = cursor.fetchone()
    conn.close()
    return employee

if __name__ == "__main__":
    create_database()
    add_sample_data()
    create_triggers()