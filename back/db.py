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

    # стоимость горшков по размеру и материалу
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS pot_prices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            size TEXT NOT NULL CHECK(size IN ('S', 'M', 'L', 'XL')),
            material TEXT NOT NULL CHECK(material IN ('ceramic', 'plastic', 'clay', 'glass', 'metal', 'wood')),
            price DECIMAL(10,2) NOT NULL,
            UNIQUE(size, material)
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
            plant_type TEXT CHECK(plant_type IN ('flowering', 'foliage', 'succulent', 'cactus', 'orchid')),
            recommended_pot_size TEXT CHECK(recommended_pot_size IN ('S', 'M', 'L', 'XL')),
            height_cm INTEGER,
            care_instructions TEXT,
            light_requirements TEXT CHECK(light_requirements IN ('full_sun', 'partial_shade', 'shade')),
            watering_frequency TEXT,
            in_stock BOOLEAN DEFAULT TRUE,
            rating DECIMAL(3,2) CHECK(rating >= 0 AND rating <= 5),
            image_url TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE SET NULL,
            FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE RESTRICT
        )
    ''')

    # пользователи
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            telegram_id INTEGER UNIQUE,
            name TEXT NOT NULL,
            phone TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')

    # сотрудники
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS employees (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            telegram_id INTEGER UNIQUE,
            full_name TEXT NOT NULL,
            phone TEXT NOT NULL,
            age INTEGER CHECK(age >= 0),
            address TEXT,
            passport_data TEXT,
            position_id INTEGER NOT NULL,
            salary DECIMAL(10,2),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
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

    # ссыли на оплату
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

    # статус заказв
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

    cursor.execute('CREATE INDEX IF NOT EXISTS idx_payment_links_user_id ON payment_links(user_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_payment_links_status ON payment_links(status)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_order_items_plant_id ON order_items(plant_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_employees_position_id ON employees(position_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_pot_plants_supplier_id ON pot_plants(supplier_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_pot_plants_category_id ON pot_plants(category_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_pot_plants_in_stock ON pot_plants(in_stock)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_pot_prices_size_material ON pot_prices(size, material)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_categories_parent_id ON categories(parent_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_order_status_history_order_id ON order_status_history(order_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_reviews_user_id ON reviews(user_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_reviews_order_id ON reviews(order_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_orders_delivery_date ON orders(delivery_date)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_payment_links_expires_at ON payment_links(expires_at)')

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
    
    # цены на горшки по размерам и материалам
    cursor.executemany('''
        INSERT OR IGNORE INTO pot_prices (size, material, price)
        VALUES (?, ?, ?)
    ''', [
        ('S', 'plastic', 150.00),
        ('S', 'ceramic', 300.00),
        ('S', 'clay', 250.00),
        ('S', 'glass', 400.00),
        ('S', 'metal', 350.00),
        ('S', 'wood', 280.00),
        
        ('M', 'plastic', 200.00),
        ('M', 'ceramic', 400.00),
        ('M', 'clay', 350.00),
        ('M', 'glass', 550.00),
        ('M', 'metal', 450.00),
        ('M', 'wood', 380.00),
        
        ('L', 'plastic', 250.00),
        ('L', 'ceramic', 500.00),
        ('L', 'clay', 450.00),
        ('L', 'glass', 700.00),
        ('L', 'metal', 550.00),
        ('L', 'wood', 480.00),
        
        ('XL', 'plastic', 300.00),
        ('XL', 'ceramic', 600.00),
        ('XL', 'clay', 550.00),
        ('XL', 'glass', 850.00),
        ('XL', 'metal', 650.00),
        ('XL', 'wood', 580.00)
    ])
    
    # тестовые горшечные растения
    cursor.executemany('''
        INSERT OR IGNORE INTO pot_plants (name, description, base_price, supplier_id, category_id, plant_type, recommended_pot_size, height_cm, care_instructions, light_requirements, watering_frequency, rating, in_stock, image_url)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [ 
        # Кактусы и суккуленты (category_id=2)
        ('Эчеверия', 'Красивый суккулент с розеткой мясистых листьев', 650.00, 3, 2, 'succulent', 'S', 15, 'Минимальный полив, много света', 'full_sun', '1 раз в 2 недели', 4.8, True, 'img/1.png'),
        ('Колючая ', 'Кактус с плоскими стеблями и колючками', 750.00, 3, 2, 'cactus', 'M', 25, 'Редкий полив, прямые солнечные лучи', 'full_sun', '1 раз в 3 недели', 4.3, True, 'img/2.png'),
        ('Сансевиерия', 'Неприхотливый суккулент с длинными вертикальными листьями', 500.00, 3, 2, 'succulent', 'S', 30, 'Умеренный полив, переносит тень', 'shade', '1 раз в 2 недели', 4.9, True, 'img/3.png'),
        # Фикусы (category_id=4)
        ('Кудрявый фикус Барок', 'Кудрявый невысокий фикус с красивыми листьями', 1200.00, 1, 4, 'foliage', 'M', 35, 'Регулярный полив, опрыскивание', 'partial_shade', '1 раз в неделю', 4.7, True, 'img/4.png'),
        ('Фикус Бенджамина Вариегата', 'Фикус с белым обрамлением листочков', 1500.00, 1, 4, 'foliage', 'M', 45, 'Регулярный полив, избегать сквозняков', 'partial_shade', '1 раз в неделю', 4.9, True, 'img/5.png'),
        ('Фикус Natasja', 'Засухоустойчивый фикус', 1100.00, 1, 4, 'foliage', 'S', 25, 'Умеренный полив', 'partial_shade', '1 раз в 10 дней', 4.5, True, 'img/6.png'),
        
        # Цветущие растения (category_id=1)
        ('Фиалка Коршунова', 'Комнатное травенистое растение', 550.00, 1, 1, 'flowering', 'S', 12, 'Полив в поддон, избегать попадания воды на листья', 'partial_shade', '2-3 раза в неделю', 4.8, True, 'img/7.png'),
        ('Азалия Вервениана', 'Сильно ветвистое цветущее растение', 1800.00, 2, 1, 'flowering', 'M', 40, 'Регулярный полив, подкормка во время цветения', 'partial_shade', '2 раза в неделю', 4.6, True, 'img/8.png'),
        ('Бегония Элатиор Кармен', 'Многолетнее растение с большим количеством листьев', 850.00, 1, 1, 'flowering', 'S', 18, 'Регулярный полив, опрыскивание', 'shade', '2 раза в неделю', 4.4, True, 'img/9.png'),
        
        # Хвойные растения (category_id=3)
        ('Сосна горная', 'Пышная сосна с колючими веточками', 2200.00, 3, 3, 'foliage', 'L', 60, 'Редкий полив, много свежего воздуха', 'full_sun', '1 раз в 2 недели', 4.9, True, 'img/10.png'),
        ('Китайская ель Коника', 'Высокая ель с конусовидной формой, выведенная искусственно', 2800.00, 3, 3, 'foliage', 'L', 70, 'Умеренный полив, защита от прямого солнца', 'partial_shade', '1 раз в неделю', 4.7, True, 'img/11.png'),
        ('Туя', 'Медленнорастущая с компактной кроной ель с мягкими колючками', 1900.00, 3, 3, 'foliage', 'M', 50, 'Регулярный полив, опрыскивание', 'full_sun', '1 раз в неделю', 4.5, True, 'img/12.png')
        
       
    ])
    
    # тестовые пользователи
    cursor.executemany('''
        INSERT OR IGNORE INTO users (telegram_id, name, phone)
        VALUES (?, ?, ?)
    ''', [
        (123456789, 'Анна Петрова', '+79161234567'),
        (987654321, 'Иван Сидоров', '+79167654321'),
        (555555555, 'Мария Иванова', '+79165554433')
    ])
    
    # тестовые сотрудники
    cursor.executemany('''
        INSERT OR IGNORE INTO employees (telegram_id, full_name, phone, age, address, position_id, salary)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', [
        (111111111, 'Ольга Цветкова', '+79161112233', 28, 'ул. Флористическая, 10', 1, 45000.00),
        (222222222, 'Дмитрий Доставкин', '+79162223344', 32, 'ул. Транспортная, 25', 2, 40000.00),
        (333333333, 'Екатерина Менеджерова', '+79163334455', 26, 'ул. Офисная, 7', 3, 50000.00)
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

if __name__ == "__main__":
    create_database()
    add_sample_data()
    create_triggers()