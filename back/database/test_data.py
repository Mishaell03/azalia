from datetime import datetime, timedelta
from init import get_connection


def seed_reference_data(cur) -> None:
    """
    Заполняет справочники.
    """
    cur.executemany(
        """
        INSERT OR IGNORE INTO stores (name, address, phone, email, store_type, is_active)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        [
            ("Центральный магазин", "Москва, ул. Цветочная, 10", "+74950000001", "central@flowers.local", "shop", 1),
            ("Склад Север", "Москва, ул. Складская, 3", "+74950000002", "warehouse@flowers.local", "warehouse", 1),
            ("Пункт самовывоза Юг", "Москва, пр. Южный, 15", "+74950000003", "pickup@flowers.local", "pickup_point", 1),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO positions (title, description)
        VALUES (?, ?)
        """,
        [
            ("Флорист", "Сборка заказов, консультации, уход за растениями"),
            ("Курьер", "Доставка заказов"),
            ("Менеджер", "Работа с клиентами и заказами"),
            ("Администратор", "Управление магазином и сотрудниками"),
            ("Закупщик", "Закупки и поставщики"),
            ("Аналитик", "Отчеты, выручка, популярность товаров"),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO suppliers (name, contact_person, phone, email, address, is_active)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        [
            ('Оранжерея "Райский сад"', "Иванов Петр", "+74951111111", "supplier1@flowers.local", "Москва, ул. Тепличная, 5", 1),
            ('Теплицы "Экзотик"', "Сидорова Мария", "+74952222222", "supplier2@flowers.local", "Москва, ул. Парковая, 28", 1),
            ('Питомник "Декоративные растения"', "Кузнецов Алексей", "+74953333333", "supplier3@flowers.local", "Москва, ул. Садовая, 17", 1),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO categories (id, name, parent_id)
        VALUES (?, ?, ?)
        """,
        [
            (1, "Цветущие", None),
            (2, "Суккуленты и кактусы", None),
            (3, "Хвойные", None),
            (4, "Фикусы", None),
            (5, "Декоративно-лиственные", None),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO plant_types (id, name)
        VALUES (?, ?)
        """,
        [
            (1, "Суккулент"),
            (2, "Кактус"),
            (3, "Цветущее"),
            (4, "Декоративно-лиственное"),
            (5, "Хвойное"),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO pot_sizes (id, name, diameter_cm, height_cm)
        VALUES (?, ?, ?, ?)
        """,
        [
            (1, "S", 12, 10),
            (2, "M", 16, 13),
            (3, "L", 20, 16),
            (4, "XL", 25, 20),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO pot_materials (id, name)
        VALUES (?, ?)
        """,
        [
            (1, "Пластик"),
            (2, "Керамика"),
            (3, "Глина"),
            (4, "Стекло"),
            (5, "Металл"),
            (6, "Дерево"),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO pot_colors (id, name, hex_code)
        VALUES (?, ?, ?)
        """,
        [
            (1, "Белый", "#FFFFFF"),
            (2, "Черный", "#000000"),
            (3, "Терракотовый", "#E2725B"),
            (4, "Зеленый", "#228B22"),
            (5, "Синий", "#1E90FF"),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO payment_methods (id, code, name, is_active)
        VALUES (?, ?, ?, ?)
        """,
        [
            (1, "cash", "Наличные", 1),
            (2, "card", "Карта", 1),
            (3, "sbp", "СБП", 1),
            (4, "online", "Онлайн", 1),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO subscription_plans
        (id, code, name, monthly_price, yearly_price, max_members, can_create_company, has_extended_features, is_active)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (1, "basic", "Обычная", 299.0, 2990.0, 1, 0, 0, 1),
            (2, "standard", "Обычная+", 499.0, 4990.0, 1, 0, 1, 1),
            (3, "corporate", "Корпоративная", 1990.0, 19990.0, 20, 1, 1, 1),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO notification_templates (id, code, title, body, type, is_active)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        [
            (1, "order_created", "Заказ создан", "Ваш заказ успешно создан.", "order", 1),
            (2, "order_status", "Статус заказа", "Статус заказа был обновлен.", "order", 1),
            (3, "plant_watering", "Пора полить растение", "Напоминаем о поливе растения.", "plant_care", 1),
            (4, "subscription_due", "Подписка требует оплаты", "Необходимо оплатить подписку.", "subscription", 1),
            (5, "marketing_sale", "Акция", "У нас новые скидки на растения.", "marketing", 1),
        ],
    )


def seed_users(cur) -> None:
    """
    Пользователи, адреса, коды входа, сессии.
    """
    cur.executemany(
        """
        INSERT OR IGNORE INTO users (id, telegram_id, full_name, phone, avatar_url, status, blocked_reason)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (1, 123456789, "Анна Смирнова", "+79161234567", "img/users/anna.png", "active", None),
            (2, 987654321, "Иван Петров", "+79167654321", "img/users/ivan.png", "active", None),
            (3, 555555555, "Мария Волкова", "+79165554433", "img/users/maria.png", "active", None),
            (4, 111111111, "Ольга Романова", "+79161112233", "img/users/olga.png", "active", None),
            (5, 222222222, "Дмитрий Соколов", "+79162223344", "img/users/dmitry.png", "active", None),
            (6, 333333333, "Екатерина Белова", "+79163334455", "img/users/ekaterina.png", "active", None),
            (7, 444444444, "Заблокированный клиент", "+79164445566", "img/users/blocked.png", "blocked", "Неуплата подписки"),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO user_addresses (user_id, address, comment, is_default)
        VALUES (?, ?, ?, ?)
        """,
        [
            (1, "Москва, ул. Лесная, 12, кв. 45", "Домофон 45", 1),
            (2, "Москва, ул. Парковая, 7", None, 1),
            (3, "Москва, ул. Солнечная, 7, офис 22", "Рабочий адрес", 1),
        ],
    )

    now = datetime.now()
    auth_expires = (now + timedelta(minutes=10)).strftime("%Y-%m-%d %H:%M:%S")
    session_expires = (now + timedelta(days=30)).strftime("%Y-%m-%d %H:%M:%S")
    now_str = now.strftime("%Y-%m-%d %H:%M:%S")

    cur.executemany(
        """
        INSERT OR IGNORE INTO auth_codes (user_id, device_id, code, expires_at, used_at)
        VALUES (?, ?, ?, ?, ?)
        """,
        [
            (1, "iphone_anna_1", "111222", auth_expires, None),
            (2, "android_ivan_1", "333444", auth_expires, None),
            (3, "iphone_maria_1", "555666", auth_expires, None),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO user_sessions
        (user_id, device_id, session_token, refresh_token, device_name, platform, ip_address, user_agent, is_active, expires_at, last_seen_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (1, "iphone_anna_1", "sess_anna_1", "ref_anna_1", "iPhone 14", "iOS", "10.0.0.1", "Telegram iOS", 1, session_expires, now_str),
            (1, "ipad_anna_2", "sess_anna_2", "ref_anna_2", "iPad Air", "iOS", "10.0.0.2", "Telegram iPad", 1, session_expires, now_str),
            (2, "android_ivan_1", "sess_ivan_1", "ref_ivan_1", "Samsung S24", "Android", "10.0.0.3", "Telegram Android", 1, session_expires, now_str),
        ],
    )


def seed_companies_and_subscriptions(cur) -> None:
    """
    Компании, участники, подписки.
    """
    now = datetime.now()
    month_later = (now + timedelta(days=30)).strftime("%Y-%m-%d %H:%M:%S")
    year_later = (now + timedelta(days=365)).strftime("%Y-%m-%d %H:%M:%S")
    week_later = (now + timedelta(days=7)).strftime("%Y-%m-%d %H:%M:%S")
    now_str = now.strftime("%Y-%m-%d %H:%M:%S")

    cur.execute(
        """
        INSERT OR IGNORE INTO companies (id, name, owner_user_id, status)
        VALUES (?, ?, ?, ?)
        """,
        (1, "Green Office", 2, "active"),
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO company_members (company_id, user_id, role, is_active)
        VALUES (?, ?, ?, ?)
        """,
        [
            (1, 2, "owner", 1),
            (1, 3, "admin", 1),
            (1, 1, "member", 1),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO company_role_history (company_id, user_id, old_role, new_role, changed_by_user_id)
        VALUES (?, ?, ?, ?, ?)
        """,
        [
            (1, 2, None, "owner", 2),
            (1, 3, None, "admin", 2),
            (1, 1, None, "member", 2),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO subscriptions
        (plan_id, user_id, company_id, billing_period, status, auto_renew, starts_at, expires_at, blocked_at, delete_after_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (1, 1, None, "monthly", "active", 1, now_str, month_later, None, None),
            (2, 3, None, "yearly", "active", 1, now_str, year_later, None, None),
            (3, None, 1, "monthly", "active", 1, now_str, month_later, None, None),
            (1, 7, None, "monthly", "blocked", 0, now_str, month_later, now_str, week_later),
        ],
    )


def seed_products(cur) -> None:
    """
    Каталог товаров, фото и цены горшков.
    """

    cur.executemany(
        """
        INSERT OR IGNORE INTO products
        (
            id,
            sku,
            name,
            description,
            category_id,
            plant_type_id,
            supplier_id,
            base_price,
            cost_price,
            recommended_pot_size_id,
            height_cm,
            light_requirements,
            watering_notes,
            care_instructions,
            image_url,
            rating,
            is_active,
            deleted_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (
                1,
                "PL-001",
                "Эчеверия",
                "Красивый суккулент с розеткой мясистых листьев",
                2,
                1,
                3,
                650.00,
                350.00,
                1,
                15,
                "full_sun",
                "1 раз в 2 недели",
                "Минимальный полив, много света",
                "img/1.png",
                4.8,
                1,
                None,
            ),
            (
                2,
                "PL-002",
                "Колючая",
                "Кактус с плоскими стеблями и колючками",
                2,
                2,
                3,
                750.00,
                420.00,
                2,
                25,
                "full_sun",
                "1 раз в 3 недели",
                "Редкий полив, прямые солнечные лучи",
                "img/2.png",
                4.3,
                1,
                None,
            ),
            (
                3,
                "PL-003",
                "Сансевиерия",
                "Неприхотливый суккулент с длинными вертикальными листьями",
                2,
                1,
                3,
                500.00,
                280.00,
                1,
                30,
                "shade",
                "1 раз в 2 недели",
                "Умеренный полив, переносит тень",
                "img/3.png",
                4.9,
                1,
                None,
            ),
            (
                4,
                "PL-004",
                "Кудрявый фикус Барок",
                "Кудрявый невысокий фикус с красивыми листьями",
                4,
                4,
                1,
                1200.00,
                700.00,
                2,
                35,
                "partial_shade",
                "1 раз в неделю",
                "Регулярный полив, опрыскивание",
                "img/4.png",
                4.7,
                1,
                None,
            ),
            (
                5,
                "PL-005",
                "Фикус Бенджамина Вариегата",
                "Фикус с белым обрамлением листочков",
                4,
                4,
                1,
                1500.00,
                900.00,
                2,
                45,
                "partial_shade",
                "1 раз в неделю",
                "Регулярный полив, избегать сквозняков",
                "img/5.png",
                4.9,
                1,
                None,
            ),
            (
                6,
                "PL-006",
                "Фикус Natasja",
                "Засухоустойчивый фикус",
                4,
                4,
                1,
                1100.00,
                650.00,
                1,
                25,
                "partial_shade",
                "1 раз в 10 дней",
                "Умеренный полив",
                "img/6.png",
                4.5,
                1,
                None,
            ),
            (
                7,
                "PL-007",
                "Фиалка Коршунова",
                "Комнатное травенистое растение",
                1,
                3,
                1,
                550.00,
                300.00,
                1,
                12,
                "partial_shade",
                "2-3 раза в неделю",
                "Полив в поддон, избегать попадания воды на листья",
                "img/7.png",
                4.8,
                1,
                None,
            ),
            (
                8,
                "PL-008",
                "Азалия Вервениана",
                "Сильно ветвистое цветущее растение",
                1,
                3,
                2,
                1800.00,
                1100.00,
                2,
                40,
                "partial_shade",
                "2 раза в неделю",
                "Регулярный полив, подкормка во время цветения",
                "img/8.png",
                4.6,
                1,
                None,
            ),
            (
                9,
                "PL-009",
                "Бегония Элатиор Кармен",
                "Многолетнее растение с большим количеством листьев",
                1,
                3,
                1,
                850.00,
                500.00,
                1,
                18,
                "shade",
                "2 раза в неделю",
                "Регулярный полив, опрыскивание",
                "img/9.png",
                4.4,
                1,
                None,
            ),
            (
                10,
                "PL-010",
                "Сосна горная",
                "Пышная сосна с колючими веточками",
                3,
                5,
                3,
                2200.00,
                1400.00,
                3,
                60,
                "full_sun",
                "1 раз в 2 недели",
                "Редкий полив, много свежего воздуха",
                "img/10.png",
                4.9,
                1,
                None,
            ),
            (
                11,
                "PL-011",
                "Китайская ель Коника",
                "Высокая ель с конусовидной формой, выведенная искусственно",
                3,
                5,
                3,
                2800.00,
                1750.00,
                3,
                70,
                "partial_shade",
                "1 раз в неделю",
                "Умеренный полив, защита от прямого солнца",
                "img/11.png",
                4.7,
                1,
                None,
            ),
            (
                12,
                "PL-012",
                "Туя",
                "Медленнорастущая с компактной кроной ель с мягкими колючками",
                3,
                5,
                3,
                1900.00,
                1150.00,
                2,
                50,
                "full_sun",
                "1 раз в неделю",
                "Регулярный полив, опрыскивание",
                "img/12.png",
                4.5,
                1,
                None,
            ),
            (
                13,
                "PL-013",
                "Снятый с продажи товар",
                "Товар больше не продается, но виден в истории заказов",
                1,
                3,
                1,
                1200.00,
                700.00,
                2,
                20,
                "partial_shade",
                "1 раз в неделю",
                "Архивный товар",
                "img/13.png",
                3.5,
                0,
                "2026-03-01 00:00:00",
            ),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO product_images (product_id, image_url, sort_order, is_main, is_active, alt_text)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        [
            (1, "img/1.png", 0, 1, 1, "Эчеверия"),
            (2, "img/2.png", 0, 1, 1, "Колючая"),
            (3, "img/3.png", 0, 1, 1, "Сансевиерия"),
            (4, "img/4.png", 0, 1, 1, "Кудрявый фикус Барок"),
            (5, "img/5.png", 0, 1, 1, "Фикус Бенджамина Вариегата"),
            (6, "img/6.png", 0, 1, 1, "Фикус Natasja"),
            (7, "img/7.png", 0, 1, 1, "Фиалка Коршунова"),
            (8, "img/8.png", 0, 1, 1, "Азалия Вервениана"),
            (9, "img/9.png", 0, 1, 1, "Бегония Элатиор Кармен"),
            (10, "img/10.png", 0, 1, 1, "Сосна горная"),
            (11, "img/11.png", 0, 1, 1, "Китайская ель Коника"),
            (12, "img/12.png", 0, 1, 1, "Туя"),
            (13, "img/13.png", 0, 1, 1, "Снятый с продажи товар"),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO pot_prices (size_id, material_id, price)
        VALUES (?, ?, ?)
        """,
        [
            (1, 1, 150.00), (2, 1, 200.00), (3, 1, 250.00), (4, 1, 300.00),
            (1, 2, 300.00), (2, 2, 400.00), (3, 2, 500.00), (4, 2, 600.00),
            (1, 3, 250.00), (2, 3, 350.00), (3, 3, 450.00), (4, 3, 550.00),
        ],
    )


def seed_user_content(cur) -> None:
    """
    Избранное, корзина, календарь, свои растения и уход.
    """
    cur.executemany(
        """
        INSERT OR IGNORE INTO wishlist_items (user_id, product_id)
        VALUES (?, ?)
        """,
        [
            (1, 6),
            (1, 7),
            (2, 5),
            (3, 8),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO cart_items
        (user_id, product_id, quantity, pot_size_id, pot_material_id, pot_color_id, product_unit_price, pot_unit_price, total_price)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (1, 1, 2, 1, 2, 1, 650.0, 300.0, 1900.0),
            (1, 5, 1, 2, 3, 2, 1500.0, 350.0, 1850.0),
            (2, 8, 1, 2, 2, 3, 1800.0, 400.0, 2200.0),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO calendar_events
        (user_id, event_date, event_time, title, description, is_all_day, reminder_enabled, reminder_minutes_before)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (1, "2026-06-12", "09:00:00", "День рождения мамы", "Не забыть поздравить", 0, 1, 60),
            (1, "2026-03-16", "10:00:00", "Полить фикус", "Домашнее напоминание", 0, 1, 30),
            (2, "2026-03-20", "11:00:00", "Проверка растений в офисе", "Осмотр корпоративных растений", 0, 1, 60),
            (3, "2026-12-01", "12:00:00", "Продление подписки", "Проверить оплату", 0, 1, 1440),
        ],
    )

    now = datetime.now()
    cur.executemany(
        """
        INSERT OR IGNORE INTO user_plants
        (
            id, user_id, product_id, custom_name, plant_name, photo_url,
            light_requirements, watering_frequency_days, pot_size_text, notes,
            last_watered_at, next_watering_at,
            last_repot_at, next_repot_at,
            last_soil_change_at, next_soil_change_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (
                1,
                1,
                5,
                "Фикус в гостиной",
                "Фикус Бенджамина Вариегата",
                "img/user_plants/anna_ficus.png",
                "partial_shade",
                7,
                "M",
                "Поливать осторожно",
                (now - timedelta(days=1)).strftime("%Y-%m-%d %H:%M:%S"),
                (now + timedelta(days=6)).strftime("%Y-%m-%d %H:%M:%S"),
                (now - timedelta(days=120)).strftime("%Y-%m-%d %H:%M:%S"),
                (now + timedelta(days=245)).strftime("%Y-%m-%d %H:%M:%S"),
                (now - timedelta(days=90)).strftime("%Y-%m-%d %H:%M:%S"),
                (now + timedelta(days=275)).strftime("%Y-%m-%d %H:%M:%S"),
            ),
            (
                2,
                1,
                None,
                "Кактус на окне",
                "Мой домашний кактус",
                "img/user_plants/anna_cactus.png",
                "full_sun",
                14,
                "S",
                "Куплен не в магазине",
                now.strftime("%Y-%m-%d %H:%M:%S"),
                (now + timedelta(days=14)).strftime("%Y-%m-%d %H:%M:%S"),
                None,
                None,
                None,
                None,
            ),
            (
                3,
                2,
                8,
                "Азалия в офисе",
                "Азалия Вервениана",
                "img/user_plants/office_azalia.png",
                "partial_shade",
                4,
                "M",
                "Следить за влажностью",
                now.strftime("%Y-%m-%d %H:%M:%S"),
                (now + timedelta(days=4)).strftime("%Y-%m-%d %H:%M:%S"),
                None,
                None,
                None,
                None,
            ),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO user_plant_care_logs (user_plant_id, care_type, care_at, notes)
        VALUES (?, ?, ?, ?)
        """,
        [
            (1, "watering", (now - timedelta(days=1)).strftime("%Y-%m-%d %H:%M:%S"), "Полив после просушки грунта"),
            (1, "soil_change", (now - timedelta(days=90)).strftime("%Y-%m-%d %H:%M:%S"), "Полная смена почвы"),
            (1, "repotting", (now - timedelta(days=120)).strftime("%Y-%m-%d %H:%M:%S"), "Пересадка в больший горшок"),
            (2, "watering", now.strftime("%Y-%m-%d %H:%M:%S"), "Минимальный полив"),
            (3, "watering", now.strftime("%Y-%m-%d %H:%M:%S"), "Полив офисной азалии"),
        ],
    )


def seed_employees_inventory_and_purchases(cur) -> None:
    """
    Сотрудники, склад, движения, закупки, приемка.
    """
    cur.executemany(
        """
        INSERT OR IGNORE INTO employees (id, user_id, position_id, store_id, salary, is_active)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        [
            (1, 4, 1, 1, 45000.0, 1),   # флорист
            (2, 5, 4, 1, 120000.0, 1),  # администратор
            (3, 6, 2, 1, 40000.0, 1),   # курьер
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO inventory
        (store_id, product_id, quantity_on_hand, quantity_reserved, quantity_available, reorder_point)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        [
            (1, 1, 10, 1, 9, 3),
            (1, 2, 8, 0, 8, 2),
            (1, 3, 20, 2, 18, 5),
            (1, 4, 7, 1, 6, 2),
            (1, 5, 12, 2, 10, 3),
            (1, 6, 15, 3, 12, 4),
            (1, 7, 5, 0, 5, 2),
            (1, 8, 4, 0, 4, 2),
            (2, 1, 20, 0, 20, 5),
            (2, 5, 14, 0, 14, 4),
            (2, 7, 8, 0, 8, 2),
            (2, 8, 7, 0, 7, 2),
            (3, 6, 6, 1, 5, 2),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO inventory_movements
        (store_id, product_id, movement_type, quantity, unit_cost, related_order_id, created_by_employee_id, comment)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (1, 1, "adjustment", 10, 350.0, None, 2, "Стартовый остаток"),
            (1, 3, "adjustment", 20, 280.0, None, 2, "Стартовый остаток"),
            (2, 5, "adjustment", 14, 900.0, None, 2, "Стартовый остаток"),
            (1, 4, "writeoff", 1, 700.0, None, 2, "Повреждение растения"),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO purchase_orders
        (id, supplier_id, store_id, created_by_employee_id, purchase_number, status, expected_delivery_at, ordered_at, received_at, comment, total_amount)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (
                1, 3, 2, 2, "PO-20260001", "received",
                "2026-02-25 12:00:00", "2026-02-20 10:00:00", "2026-02-25 11:30:00",
                "Поставка суккулентов и хвойных", 19600.0
            ),
            (
                2, 1, 1, 2, "PO-20260002", "partially_received",
                "2026-03-07 15:00:00", "2026-03-04 09:00:00", None,
                "Поставка фикусов", 11100.0
            ),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO purchase_order_items
        (id, purchase_order_id, product_id, ordered_quantity, received_quantity, rejected_quantity, unit_cost, line_total)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (1, 1, 1, 20, 20, 0, 350.0, 7000.0),
            (2, 1, 10, 6, 6, 0, 1400.0, 8400.0),
            (3, 1, 11, 2, 2, 0, 2100.0, 4200.0),
            (4, 2, 4, 6, 4, 1, 700.0, 4200.0),
            (5, 2, 5, 6, 5, 0, 900.0, 5400.0),
            (6, 2, 6, 2, 0, 0, 750.0, 1500.0),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO purchase_receipts
        (id, purchase_order_id, received_by_employee_id, received_at, comment)
        VALUES (?, ?, ?, ?, ?)
        """,
        [
            (1, 1, 2, "2026-02-25 11:30:00", "Поставка принята полностью"),
            (2, 2, 2, "2026-03-07 16:10:00", "Частичная приемка, есть брак"),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO purchase_receipt_items
        (purchase_receipt_id, purchase_order_item_id, accepted_quantity, rejected_quantity, reject_reason)
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


def seed_orders_and_payments(cur) -> None:
    """
    Заказы, позиции, история покупок, платежи, возвраты, уведомления.
    """
    cur.executemany(
        """
        INSERT OR IGNORE INTO orders
        (
            id, user_id, company_id, store_id, order_number, order_type,
            address_id, address_snapshot, comment, subtotal, delivery_fee,
            discount_amount, total_price, payment_status, status, assigned_employee_id,
            created_at, updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (
                1, 1, None, 1, "ORD-20260001", "delivery",
                1, "Москва, ул. Лесная, 12, кв. 45", "Позвонить за 30 минут",
                2550.0, 300.0, 100.0, 2750.0, "paid", "completed", 1,
                "2026-03-01 10:15:00", "2026-03-02 18:00:00"
            ),
            (
                2, 2, 1, 3, "ORD-20260002", "pickup",
                None, None, "Самовывоз вечером",
                2200.0, 0.0, 0.0, 2200.0, "pending", "ready_for_pickup", 1,
                "2026-03-03 12:00:00", "2026-03-03 15:00:00"
            ),
            (
                3, 3, None, 1, "ORD-20260003", "delivery",
                3, "Москва, ул. Солнечная, 7, офис 22", None,
                1450.0, 250.0, 0.0, 1700.0, "failed", "cancelled", 1,
                "2026-03-05 09:30:00", "2026-03-05 11:00:00"
            ),
            (
                4, 1, None, 1, "ORD-20260004", "delivery",
                1, "Москва, ул. Лесная, 12, кв. 45", "История должна хранить удаленный товар",
                1450.0, 300.0, 0.0, 1750.0, "refunded", "completed", 1,
                "2026-03-06 12:00:00", "2026-03-07 10:00:00"
            ),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO order_items
        (
            order_id, product_id, product_name_snapshot, product_description_snapshot,
            quantity, product_unit_price, product_cost_price,
            pot_size_id, pot_material_id, pot_color_id,
            pot_unit_price, discount_amount, total_price, returned_quantity
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (1, 1, "Эчеверия", "Красивый суккулент с розеткой мясистых листьев", 2, 650.0, 350.0, 1, 2, 1, 300.0, 50.0, 1850.0, 0),
            (1, 7, "Фиалка Коршунова", "Комнатное травенистое растение", 1, 550.0, 300.0, 1, 1, 3, 150.0, 50.0, 700.0, 0),
            (2, 8, "Азалия Вервениана", "Сильно ветвистое цветущее растение", 1, 1800.0, 1100.0, 2, 2, 1, 400.0, 0.0, 2200.0, 0),
            (3, 3, "Сансевиерия", "Неприхотливый суккулент с длинными вертикальными листьями", 1, 1450.0, 700.0, 2, 3, 2, 0.0, 0.0, 1450.0, 0),
            (4, 13, "Снятый с продажи товар", "Товар больше не продается, но виден в истории заказов", 1, 1200.0, 700.0, 2, 3, 2, 250.0, 0.0, 1450.0, 0),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO order_status_history (order_id, old_status, new_status, changed_by_employee_id, created_at)
        VALUES (?, ?, ?, ?, ?)
        """,
        [
            (1, "new", "processing", 1, "2026-03-01 10:20:00"),
            (1, "processing", "assembled", 1, "2026-03-01 12:00:00"),
            (1, "assembled", "shipped", 3, "2026-03-02 12:30:00"),
            (1, "shipped", "delivered", 3, "2026-03-02 14:10:00"),
            (1, "delivered", "completed", 1, "2026-03-02 18:00:00"),
            (2, "new", "processing", 1, "2026-03-03 12:15:00"),
            (2, "processing", "assembled", 1, "2026-03-03 14:00:00"),
            (2, "assembled", "ready_for_pickup", 1, "2026-03-03 15:00:00"),
            (3, "new", "cancelled", 1, "2026-03-05 11:00:00"),
            (4, "new", "processing", 1, "2026-03-06 12:10:00"),
            (4, "processing", "completed", 1, "2026-03-06 18:00:00"),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO payments
        (id, order_id, user_id, payment_method_id, amount, status, external_payment_id, paid_at, failed_at, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (1, 1, 1, 2, 2750.0, "paid", "ext_pay_001", "2026-03-01 10:16:00", None, "2026-03-01 10:15:30"),
            (2, 2, 2, 4, 2200.0, "pending", "ext_pay_002", None, None, "2026-03-03 12:01:00"),
            (3, 3, 3, 3, 1700.0, "failed", "ext_pay_003", None, "2026-03-05 10:30:00", "2026-03-05 09:31:00"),
            (4, 4, 1, 2, 1750.0, "refunded", "ext_pay_004", "2026-03-06 12:05:00", None, "2026-03-06 12:01:00"),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO refunds
        (payment_id, amount, reason, status, processed_by_employee_id, processed_at, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (4, 1750.0, "Возврат по запросу клиента", "processed", 1, "2026-03-07 10:00:00", "2026-03-07 09:30:00"),
        ],
    )

    cur.executemany(
        """
        INSERT OR IGNORE INTO notifications
        (user_id, template_id, type, channel, title, body, status, scheduled_at, sent_at, related_order_id, related_user_plant_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (1, 1, "order", "telegram", "Заказ создан", "Ваш заказ #ORD-20260001 создан", "sent", "2026-03-01 10:15:00", "2026-03-01 10:15:05", 1, None),
            (1, 3, "plant_care", "telegram", "Пора полить растение", "Не забудьте полить фикус в гостиной", "pending", "2026-03-16 09:30:00", None, None, 1),
            (3, 4, "subscription", "telegram", "Подписка требует оплаты", "Не забудьте оплатить подписку", "pending", "2026-11-30 12:00:00", None, None, None),
        ],
    )

    cur.execute(
        """
        INSERT OR IGNORE INTO marketing_campaigns
        (name, message, status, scheduled_at, created_by_employee_id)
        VALUES (?, ?, ?, ?, ?)
        """,
        (
            "Весенняя распродажа",
            "Скидки на цветущие растения до конца недели",
            "scheduled",
            "2026-04-01 10:00:00",
            2,
        ),
    )


def validate_seed(cur) -> None:
    """
    Быстрая проверка, что сиды действительно записались.
    """
    checks = {
        "users": 3,
        "products": 10,
        "orders": 4,
        "order_items": 5,
        "inventory": 5,
        "subscriptions": 3,
    }

    for table, min_count in checks.items():
        cur.execute(f"SELECT COUNT(*) AS cnt FROM {table}")
        count = cur.fetchone()["cnt"]
        if count < min_count:
            raise RuntimeError(
                f"Недостаточно данных в таблице {table}: ожидается минимум {min_count}, получено {count}"
            )


def seed_database() -> None:
    conn = get_connection()
    cur = conn.cursor()

    seed_reference_data(cur)
    seed_users(cur)
    seed_companies_and_subscriptions(cur)
    seed_products(cur)
    seed_user_content(cur)
    seed_employees_inventory_and_purchases(cur)
    seed_orders_and_payments(cur)

    validate_seed(cur)

    conn.commit()
    conn.close()


if __name__ == "__main__":
    seed_database()
    print("👍🏻 Тестовые данные успешно добавлены")