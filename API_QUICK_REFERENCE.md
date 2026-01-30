# API Краткая справка - Азалия

## Быстрый навигатор по всем эндпоинтам

### 🔐 Аутентификация `/api/auth`
- `POST /verify` - Проверить код и получить session_token
- `GET /check_status/<code>` - Статус кода
- `GET/POST /me` - Получить инфо о текущем пользователе
- `POST /update_profile` - Обновить имя/телефон
- `POST /avatar` - Загрузить аватарку
- `GET /avatar` - Получить аватарку

### 🛍️ Корзина и Избранное `/api/cart`
- `GET /items` - Товары в корзине
- `POST /items` - Добавить в корзину
- `PUT /items/<id>` - Изменить кол-во
- `DELETE /items/<id>` - Удалить из корзины
- `DELETE /clear` - Очистить корзину
- `GET /wishlist` - Избранное
- `POST /wishlist` - Добавить в избранное
- `DELETE /wishlist/<id>` - Удалить из избранного
- `GET /wishlist/check/<id>` - Проверить в избранном
- `GET /pot/price` - Цена горшка

### 🌿 Растения `/api/plants`
- `GET /` - Список растений (с фильтрами)
- `GET /<id>` - Информация о растении
- `POST /` - Создать растение (админ)
- `PUT /<id>` - Обновить растение (админ)
- `DELETE /<id>` - Удалить растение (админ)
- `POST /<id>/image` - Загрузить изображение (админ)
- `DELETE /<id>/image` - Удалить изображение (админ)
- `PATCH /<id>/stock` - Обновить наличие (админ)
- `GET /with-images` - Растения с картинками
- `GET /top-rated` - Top растения по рейтингу

### 📂 Категории `/api/categories`
- `GET /` - Все категории
- `GET /<id>` - Категория
- `POST /` - Создать категорию (админ)
- `PUT /<id>` - Обновить категорию (админ)
- `DELETE /<id>` - Удалить категорию (админ)
- `GET /<id>/plants` - Растения в категории
- `GET /stats` - Статистика (админ)

### 👥 Сотрудники `/api`
- `GET /users` - Список пользователей (админ)
- `GET /debug/whoami` - Инфо о себе
- `GET /employees` - Список сотрудников (админ)
- `GET /employees/<id>` - Сотрудник (админ)
- `POST /employees/assign` - Назначить сотрудника (админ)
- `POST /employees/deactivate` - Деактивировать (админ)

### 💳 Платежи `/api/payments`
- `POST /create` - Создать платежную ссылку
- `GET /status/<id>` - Статус платежа
- `POST /callback` - Webhook от Yookassa (автоматический)

### 🖼️ Статические файлы `/api`
- `GET /img/<filename>` - Получить изображение

---

## Основные параметры запросов

### Аутентификация
```
Заголовок: Authorization: session_token
или в теле: {"session_token": "..."}
```

### Фильтры в GET /plants
```
?category_id=1
&in_stock=true
&plant_type=декоративное
&search=фикус
&min_price=1000&max_price=5000
&min_rating=4&max_rating=5
```

### Создание платежа
```json
{
  "items": [{"plant_id": 1, "quantity": 2, "plant_price": 1500}],
  "amount": 3000,
  "delivery_address": "адрес"
}
```

### Добавление в корзину
```json
{
  "plant_id": 1,
  "quantity": 2,
  "pot_color": "white",
  "pot_size": "M",
  "pot_material": "ceramic"
}
```

---

## Коды ответов

| Код | Значение |
|-----|----------|
| 200 | OK ✓ |
| 201 | Created ✓ |
| 400 | Bad Request ✗ |
| 401 | Unauthorized ✗ |
| 403 | Forbidden ✗ |
| 404 | Not Found ✗ |
| 500 | Server Error ✗ |

---

## Форматы значений в БД

### Статусы
- **Заказ**: `new`, `payment_pending`, `processing`, `delivered`, `cancelled`
- **Платеж**: `pending`, `completed`, `failed`
- **Сотрудник**: `is_active` (true/false)

### Освещение
- `full_sun`, `partial_shade`, `shade`

### Цвета горшков
- `white`, `black`, `terracotta`, `green`, `blue`, `multicolor`

### Размеры горшков
- `S`, `M`, `L`, `XL`

### Материалы горшков
- `ceramic`, `plastic`, `clay`, `glass`, `metal`, `wood`

### Методы оплаты
- `cash`, `card`

---

## Обязательные переменные окружения

```dotenv
SECRET_KEY=...          # 64 символа
DATABASE_URL=...        # Путь к БД
BOT_TOKEN=...          # Token Telegram бота
YOOKASSA_SHOP_ID=...   # ID магазина Yookassa
YOOKASSA_API_KEY=...   # API ключ Yookassa
```

---

## Примеры использования

### Вход в систему
```bash
1. POST /api/auth/verify {code: "1234"}
2. Получить session_token из ответа
3. Использовать в заголовке Authorization
```

### Добавить товар и оплатить
```bash
1. POST /api/cart/items {plant_id: 1, quantity: 2, ...}
2. GET /api/cart/items (проверить)
3. POST /api/payments/create {items: [...], amount: 3000, ...}
4. Перенаправить на payment_url
5. Yookassa отправит callback (платеж готов)
```

### Как администратор
```bash
1. Получить session_token (должен быть ID=4 или в ADMIN_IDS)
2. POST /api/plants/ {name: "...", base_price: 1500, ...}
3. POST /api/plants/<id>/image (форма с файлом)
4. PATCH /api/plants/<id>/stock {stock_quantity: 10}
5. POST /api/employees/assign {user_id: 1, position_id: 1}
```

---

**Полная документация:** [API_DOCUMENTATION.md](API_DOCUMENTATION.md)