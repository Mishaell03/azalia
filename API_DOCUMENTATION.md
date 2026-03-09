# API Документация - Цветочный магазин "Азалия"

## Базовая информация

**Base URL:** `http://localhost:5000/api`

**Аутентификация:** Большинство эндпоинтов требуют `session_token` в заголовке `Authorization` или в теле запроса.

---

## 📱 Аутентификация (Auth)

### 1. POST `/auth/verify`
**Проверка кода авторизации и получение session_token**

#### Параметры запроса (JSON):
```json
{
  "code": "4321",
  "device_id": "abc123def456"
}
```

#### Успешный ответ (200):
```json
{
  "success": true,
  "user": {
    "id": 1,
    "telegram_id": 123456789,
    "name": "Иван Петров",
    "phone": "+7 999 999 99 99",
    "session_token": "93719ff544e283126f31c8ec97d56de2a7b3c1af767a30b06b7261803782349b",
    "avatar": "base64_encoded_image_or_null"
  },
  "role": "customer",
  "message": "Authentication successful"
}
```

#### Ошибки:
- 400: Неверный код или формат
- 401: Код истек или уже использован

---

### 2. GET `/auth/check_status/<code>`
**Проверка статуса кода авторизации**

#### Параметры пути:
- `code` (string): 4-значный код

#### Успешный ответ (200):
```json
{
  "code": "4321",
  "expires_at": "2026-01-26T15:30:00",
  "used": false,
  "user_linked": false,
  "is_valid": true,
  "user_info": {
    "name": "Иван Петров",
    "telegram_id": 123456789
  }
}
```

---

### 3. GET/POST `/auth/me`
**Получить информацию о текущем пользователе**

#### Заголовки:
- `Authorization: session_token`

#### Успешный ответ (200):
```json
{
  "success": true,
  "user": {
    "id": 1,
    "telegram_id": 123456789,
    "name": "Иван Петров",
    "phone": "+7 999 999 99 99",
    "avatar": "base64_encoded_image_or_null"
  },
  "role": "customer"
}
```

#### Ошибки:
- 401: Сессия истекла или невалидна

---

### 4. POST `/auth/update_profile`
**Обновить профиль пользователя**

#### Заголовки:
- `Authorization: session_token`

#### Параметры запроса (JSON):
```json
{
  "name": "Новое имя",
  "phone": "+7 999 888 77 66"
}
```

#### Успешный ответ (200):
```json
{
  "success": true,
  "user": {
    "id": 1,
    "name": "Новое имя",
    "phone": "+7 999 888 77 66"
  }
}
```

---

### 5. POST `/auth/avatar`
**Загрузить или изменить аватарку пользователя**

#### Заголовки:
- `Authorization: session_token`
- `Content-Type: multipart/form-data`

#### Параметры (form-data):
- `avatar` (file): Изображение (PNG, JPG, GIF, WebP, max 5MB)

#### Успешный ответ (200):
```json
{
  "success": true,
  "message": "Avatar uploaded successfully"
}
```

#### Ошибки:
- 400: Неверный формат файла или размер
- 401: Требуется аутентификация

---

### 6. GET `/auth/avatar`
**Получить аватарку пользователя**

#### Заголовки:
- `Authorization: session_token`

#### Успешный ответ (200):
```json
{
  "success": true,
  "avatar": "base64_encoded_image"
}
```

---

## 🛍️ Корзина и Избранное (Cart)

### 1. GET `/cart/items`
**Получить все товары в корзине**

#### Заголовки:
- `Authorization: session_token`

#### Успешный ответ (200):
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": 1,
        "plant_id": 1,
        "quantity": 2,
        "plant_unit_price": 1500.00,
        "pot_color": "white",
        "pot_size": "M",
        "pot_material": "ceramic",
        "pot_unit_price": 500.00,
        "total_price": 4000.00
      }
    ],
    "summary": {
      "total_items": 2,
      "total_price": 4000.00,
      "items_count": 1
    }
  }
}
```

---

### 2. POST `/cart/items`
**Добавить товар в корзину**

#### Заголовки:
- `Authorization: session_token`

#### Параметры запроса (JSON):
```json
{
  "plant_id": 1,
  "quantity": 2,
  "pot_color": "white",
  "pot_size": "M",
  "pot_material": "ceramic"
}
```

#### Успешный ответ (200):
```json
{
  "success": true,
  "data": {
    "id": 1,
    "plant_id": 1,
    "quantity": 2,
    "total_price": 4000.00
  }
}
```

#### Ошибки:
- 400: Товар не найден или недостаточно в наличии
- 401: Требуется аутентификация

---

### 3. PUT `/cart/items/<item_id>`
**Обновить количество товара в корзине**

#### Заголовки:
- `Authorization: session_token`

#### Параметры пути:
- `item_id` (int): ID товара в корзине

#### Параметры запроса (JSON):
```json
{
  "quantity": 3
}
```

#### Успешный ответ (200):
```json
{
  "success": true,
  "message": "Корзина обновлена",
  "data": {
    "id": 1,
    "quantity": 3,
    "total_price": 6000.00
  }
}
```

---

### 4. DELETE `/cart/items/<item_id>`
**Удалить товар из корзины**

#### Заголовки:
- `Authorization: session_token`

#### Параметры пути:
- `item_id` (int): ID товара в корзине

#### Успешный ответ (200):
```json
{
  "success": true,
  "message": "Товар удален из корзины"
}
```

---

### 5. DELETE `/cart/clear`
**Очистить всю корзину**

#### Заголовки:
- `Authorization: session_token`

#### Успешный ответ (200):
```json
{
  "success": true,
  "message": "Корзина очищена"
}
```

---

### 6. GET `/cart/wishlist`
**Получить избранные товары**

#### Заголовки:
- `Authorization: session_token`

#### Успешный ответ (200):
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "plant_id": 1,
      "plant_name": "Фикус",
      "plant_image": "image_url"
    }
  ]
}
```

---

### 7. POST `/cart/wishlist`
**Добавить товар в избранное**

#### Заголовки:
- `Authorization: session_token`

#### Параметры запроса (JSON):
```json
{
  "plant_id": 1
}
```

#### Успешный ответ (200):
```json
{
  "success": true,
  "message": "Товар добавлен в избранное"
}
```

---

### 8. DELETE `/cart/wishlist/<plant_id>`
**Удалить товар из избранного**

#### Заголовки:
- `Authorization: session_token`

#### Параметры пути:
- `plant_id` (int): ID растения

#### Успешный ответ (200):
```json
{
  "success": true,
  "message": "Товар удален из избранного"
}
```

---

### 9. GET `/cart/wishlist/check/<plant_id>`
**Проверить, есть ли товар в избранном**

#### Заголовки:
- `Authorization: session_token`

#### Параметры пути:
- `plant_id` (int): ID растения

#### Успешный ответ (200):
```json
{
  "success": true,
  "in_wishlist": true
}
```

---

### 10. GET `/cart/pot/price`
**Получить цену горшка**

#### Query параметры:
- `material_id` (int): ID материала горшка
- `size_id` (int): ID размера горшка

#### Успешный ответ (200):
```json
{
  "success": true,
  "price": 500.00
}
```

---

## 🌿 Растения (Plants)

### 1. GET `/plants/`
**Получить список растений с фильтрами**

#### Query параметры:
- `category_id` (int, опционально): Фильтр по категории
- `in_stock` (bool, опционально): Только в наличии (true/false)
- `plant_type` (string, опционально): Тип растения
- `search` (string, опционально): Поиск по названию или описанию
- `min_price` (float, опционально): Минимальная цена
- `max_price` (float, опционально): Максимальная цена
- `min_rating` (float, опционально): Минимальный рейтинг (0-5)
- `max_rating` (float, опционально): Максимальный рейтинг (0-5)

#### Успешный ответ (200):
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "Фикус",
      "description": "Красивое растение",
      "base_price": 1500.00,
      "category_id": 1,
      "plant_type": "Декоративное",
      "height_cm": 50,
      "in_stock": true,
      "stock_quantity": 10,
      "rating": 4.5,
      "image_url": "image_url"
    }
  ],
  "count": 1
}
```

---

### 2. GET `/plants/<plant_id>`
**Получить информацию о конкретном растении**

#### Параметры пути:
- `plant_id` (int): ID растения

#### Успешный ответ (200):
```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "Фикус",
    "description": "Красивое растение",
    "base_price": 1500.00,
    "category": {
      "id": 1,
      "name": "Декоративные"
    },
    "supplier": {
      "id": 1,
      "name": "Поставщик 1"
    },
    "height_cm": 50,
    "care_instructions": "Поливать 2 раза в неделю",
    "light_requirements": "partial_shade",
    "watering_frequency": "2 times a week",
    "in_stock": true,
    "stock_quantity": 10,
    "rating": 4.5,
    "image_url": "image_url"
  }
}
```

---

### 3. POST `/plants/`
**Создать новое растение (только администратор)**

#### Заголовки:
- `Authorization: session_token` (Admin)

#### Параметры запроса (JSON):
```json
{
  "name": "Новое растение",
  "description": "Описание",
  "base_price": 2000.00,
  "category_id": 1,
  "plant_type": 1,
  "height_cm": 60,
  "care_instructions": "Инструкции",
  "light_requirements": "partial_shade",
  "watering_frequency": "2 times a week",
  "supplier_id": 1,
  "stock_quantity": 5
}
```

#### Успешный ответ (201):
```json
{
  "success": true,
  "data": {
    "id": 2,
    "name": "Новое растение"
  }
}
```

---

### 4. PUT `/plants/<plant_id>`
**Обновить информацию о растении (только администратор)**

#### Заголовки:
- `Authorization: session_token` (Admin)

#### Параметры пути:
- `plant_id` (int): ID растения

#### Параметры запроса (JSON):
```json
{
  "name": "Обновленное название",
  "base_price": 2500.00,
  "stock_quantity": 20
}
```

#### Успешный ответ (200):
```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "Обновленное название"
  }
}
```

---

### 5. DELETE `/plants/<plant_id>`
**Удалить растение (только администратор)**

#### Заголовки:
- `Authorization: session_token` (Admin)

#### Параметры пути:
- `plant_id` (int): ID растения

#### Успешный ответ (200):
```json
{
  "success": true,
  "message": "Plant deleted successfully"
}
```

---

### 6. POST `/plants/<plant_id>/image`
**Загрузить изображение растения (только администратор)**

#### Заголовки:
- `Authorization: session_token` (Admin)
- `Content-Type: multipart/form-data`

#### Параметры (form-data):
- `image` (file): Изображение (PNG, JPG, GIF, WebP, max 16MB)

#### Успешный ответ (200):
```json
{
  "success": true,
  "image_url": "image_filename.jpg"
}
```

---

### 7. DELETE `/plants/<plant_id>/image`
**Удалить изображение растения (только администратор)**

#### Заголовки:
- `Authorization: session_token` (Admin)

#### Параметры пути:
- `plant_id` (int): ID растения

#### Успешный ответ (200):
```json
{
  "success": true,
  "message": "Image deleted successfully"
}
```

---

### 8. PATCH `/plants/<plant_id>/stock`
**Обновить наличие и количество товара (только администратор)**

#### Заголовки:
- `Authorization: session_token` (Admin)

#### Параметры пути:
- `plant_id` (int): ID растения

#### Параметры запроса (JSON):
```json
{
  "stock_quantity": 15,
  "in_stock": true
}
```

#### Успешный ответ (200):
```json
{
  "success": true,
  "data": {
    "id": 1,
    "stock_quantity": 15,
    "in_stock": true
  }
}
```

---

### 9. GET `/plants/with-images`
**Получить растения с изображениями**

#### Успешный ответ (200):
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "Фикус",
      "image_url": "image_url"
    }
  ]
}
```

---

### 10. GET `/plants/top-rated`
**Получить растения с высоким рейтингом**

#### Query параметры:
- `limit` (int, опционально): Количество растений (default: 10)

#### Успешный ответ (200):
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "Фикус",
      "rating": 4.8
    }
  ]
}
```

---

## 📂 Категории (Categories)

### 1. GET `/categories/`
**Получить все категории**

#### Query параметры:
- `only_parents` (bool, опционально): Только корневые категории (true/false)

#### Успешный ответ (200):
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "Декоративные",
      "description": "Описание",
      "parent_id": null,
      "subcategories": [
        {
          "id": 2,
          "name": "Фикусы"
        }
      ]
    }
  ],
  "count": 1
}
```

---

### 2. GET `/categories/<category_id>`
**Получить информацию о категории**

#### Параметры пути:
- `category_id` (int): ID категории

#### Успешный ответ (200):
```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "Декоративные",
    "description": "Описание",
    "parent_id": null,
    "parent": null,
    "subcategories": [],
    "plants_count": 5
  }
}
```

---

### 3. POST `/categories/`
**Создать новую категорию (только администратор)**

#### Заголовки:
- `Authorization: session_token` (Admin)

#### Параметры запроса (JSON):
```json
{
  "name": "Новая категория",
  "description": "Описание",
  "parent_id": null
}
```

#### Успешный ответ (201):
```json
{
  "success": true,
  "data": {
    "id": 3,
    "name": "Новая категория"
  }
}
```

---

### 4. PUT `/categories/<category_id>`
**Обновить категорию (только администратор)**

#### Заголовки:
- `Authorization: session_token` (Admin)

#### Параметры пути:
- `category_id` (int): ID категории

#### Параметры запроса (JSON):
```json
{
  "name": "Обновленная категория",
  "description": "Новое описание"
}
```

#### Успешный ответ (200):
```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "Обновленная категория"
  }
}
```

---

### 5. DELETE `/categories/<category_id>`
**Удалить категорию (только администратор)**

#### Заголовки:
- `Authorization: session_token` (Admin)

#### Параметры пути:
- `category_id` (int): ID категории

#### Успешный ответ (200):
```json
{
  "success": true,
  "message": "Category deleted successfully"
}
```

#### Ошибки:
- 400: Категория содержит товары или подкатегории

---

### 6. GET `/categories/<category_id>/plants`
**Получить растения в категории**

#### Параметры пути:
- `category_id` (int): ID категории

#### Query параметры:
- `in_stock` (bool, опционально): Только в наличии
- `plant_type` (string, опционально): Тип растения

#### Успешный ответ (200):
```json
{
  "success": true,
  "data": {
    "category": {
      "id": 1,
      "name": "Декоративные"
    },
    "plants": [
      {
        "id": 1,
        "name": "Фикус"
      }
    ],
    "count": 1
  }
}
```

---

### 7. GET `/categories/stats`
**Получить статистику по категориям (только администратор)**

#### Заголовки:
- `Authorization: session_token` (Admin)

#### Успешный ответ (200):
```json
{
  "success": true,
  "data": [
    {
      "category_id": 1,
      "category_name": "Декоративные",
      "plants_count": 5,
      "total_stock": 50
    }
  ]
}
```

---

## 👥 Сотрудники (Employees)

### 1. GET `/users`
**Получить список пользователей (исключая сотрудников, только администратор)**

#### Заголовки:
- `Authorization: session_token` (Admin)

#### Успешный ответ (200):
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "telegram_id": 123456789,
      "name": "Иван Петров",
      "phone": "+7 999 999 99 99"
    }
  ]
}
```

---

### 2. GET `/debug/whoami`
**Получить информацию о текущем пользователе (отладка)**

#### Заголовки:
- `Authorization: session_token`

#### Успешный ответ (200):
```json
{
  "success": true,
  "user": {
    "id": 1,
    "telegram_id": 123456789,
    "name": "Иван Петров"
  },
  "is_admin": true
}
```

---

### 3. GET `/employees`
**Получить список всех сотрудников (только администратор)**

#### Заголовки:
- `Authorization: session_token` (Admin)

#### Успешный ответ (200):
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "telegram_id": 123456789,
      "position_id": 1,
      "position_title": "Менеджер",
      "salary": 50000.00,
      "hire_date": "2025-01-01T00:00:00",
      "is_active": true,
      "user_info": {
        "name": "Иван Петров",
        "phone": "+7 999 999 99 99"
      }
    }
  ]
}
```

---

### 4. GET `/employees/<employee_id>`
**Получить информацию о сотруднике (только администратор)**

#### Заголовки:
- `Authorization: session_token` (Admin)

#### Параметры пути:
- `employee_id` (int): ID сотрудника

#### Успешный ответ (200):
```json
{
  "success": true,
  "data": {
    "id": 1,
    "telegram_id": 123456789,
    "position_title": "Менеджер",
    "salary": 50000.00,
    "is_active": true,
    "user_info": {
      "name": "Иван Петров",
      "phone": "+7 999 999 99 99"
    }
  }
}
```

---

### 5. POST `/employees/assign`
**Назначить пользователя сотрудником (только администратор)**

#### Заголовки:
- `Authorization: session_token` (Admin)

#### Параметры запроса (JSON):
```json
{
  "user_id": 1,
  "telegram_id": 123456789,
  "position_id": 1,
  "salary": 50000.00
}
```

#### Успешный ответ (200):
```json
{
  "success": true,
  "message": "Employee assigned successfully"
}
```

#### Ошибки:
- 400: Пользователь не найден, позиция не существует
- 403: Требуется права администратора

---

### 6. POST `/employees/deactivate`
**Деактивировать сотрудника или обновить его данные (только администратор)**

#### Заголовки:
- `Authorization: session_token` (Admin)

#### Параметры запроса (JSON):
```json
{
  "user_id": 1,
  "telegram_id": 123456789,
  "is_active": false,
  "position_id": 2,
  "salary": 55000.00
}
```

#### Успешный ответ (200):
```json
{
  "success": true,
  "message": "Employee updated successfully"
}
```

---

## 💳 Платежи (Payments)

### 1. POST `/payments/create`
**Создать платежную ссылку через Yookassa**

#### Заголовки:
- `Authorization: session_token`
- `Content-Type: application/json`

#### Параметры запроса (JSON):
```json
{
  "items": [
    {
      "plant_id": 1,
      "quantity": 2,
      "plant_price": 1500.00
    },
    {
      "plant_id": 2,
      "quantity": 1,
      "plant_price": 2500.00
    }
  ],
  "amount": 5500.00,
  "delivery_address": "Москва, ул. Тверская, 1"
}
```

#### Успешный ответ (200):
```json
{
  "success": true,
  "data": {
    "payment_url": "https://yookassa.ru/payments/confirmation_url",
    "payment_link_id": 42,
    "order_id": 10,
    "amount": 5500.00,
    "expires_at": "2026-01-27T12:34:56"
  }
}
```

#### Ошибки:
- 400: Товар не найден, недостаточно в наличии, неверная сумма, отсутствует адрес
- 401: Требуется аутентификация
- 500: Ошибка платежной системы

#### Проверки безопасности:
- ✓ Проверка сессии токена
- ✓ Проверка наличия товаров в БД
- ✓ Проверка доступности товаров (in_stock=true)
- ✓ Проверка достаточного количества на складе
- ✓ Проверка совпадения цены товара с БД
- ✓ Проверка совпадения суммы
- ✓ Обязательный адрес доставки

---

### 2. GET `/payments/status/<payment_link_id>`
**Получить статус платежа**

#### Заголовки:
- `Authorization: session_token`

#### Параметры пути:
- `payment_link_id` (int): ID ссылки платежа

#### Успешный ответ (200):
```json
{
  "success": true,
  "data": {
    "id": 42,
    "user_id": 1,
    "order_id": 10,
    "amount": 5500.00,
    "payment_url": "https://yookassa.ru/payments/confirmation_url",
    "status": "pending",
    "created_at": "2026-01-26T12:34:56",
    "expires_at": "2026-01-27T12:34:56",
    "payment_system_id": "2aae8a61-00fa-40e5-9c95-d8d7e5bd37c0",
    "payment_confirmed_at": null
  }
}
```

#### Ошибки:
- 401: Требуется аутентификация
- 403: Доступ запрещен (чужой платеж)
- 404: Платеж не найден

---

### 3. POST `/payments/callback`
**Webhook от Yookassa для уведомления об оплате (автоматический)**

#### Параметры запроса (JSON от Yookassa):
```json
{
  "event": "payment.succeeded",
  "object": {
    "id": "2aae8a61-00fa-40e5-9c95-d8d7e5bd37c0",
    "status": "succeeded",
    "amount": {
      "value": "5500.00",
      "currency": "RUB"
    }
  }
}
```

#### Ответ (200):
```json
{
  "success": true
}
```

#### Автоматические действия:
- Обновляет `payment_link.status = "completed"`
- Обновляет `order.status = "processing"`
- Обновляет `order.is_paid = true`

---

## 🖼️ Статические файлы

### GET `/api/img/<filename>`
**Получить изображение растения**

#### Параметры пути:
- `filename` (string): Имя файла изображения

#### Ответ:
Возвращает изображение с соответствующим MIME типом (image/jpeg, image/png и т.д.)

#### Пример:
```
GET /api/img/abc123def456_flower.jpg
```


## 📋 Типы ролей

| Роль | Описание |
|------|----------|
| `customer` | Обычный пользователь/покупатель |
| `employee` | Сотрудник магазина |
| `admin` | Администратор (ID=4) |

---

## 🔧 Конфигурация окружения (.env)

```dotenv
SECRET_KEY="your_secret_key"
DATABASE_URL="sqlite:///flower_shop.db"
DEBUG=True
PORT=5000

BOT_TOKEN="your_bot_token"
API_BASE_URL="http://localhost:5000/api"

YOOKASSA_SHOP_ID="your_shop_id"
YOOKASSA_API_KEY="your_api_key"
YOOKASSA_RETURN_URL="http://localhost:5000/api/payments/callback"
```

---

## 📝 Примечания

1. **Аутентификация**: Используйте session_token, полученный из `/auth/verify`
2. **Валидация**: Все входные данные валидируются на сервере
3. **Логирование**: Все операции логируются для отладки
4. **Транзакции**: Все операции БД используют транзакции для целостности данных
5. **Безопасность**: Реализована защита от SQL injection, XSS и других уязвимостей
6. **Изображения**: Все изображения сжимаются и оптимизируются на сервере
7. **Платежи**: Поддерживается интеграция с Yookassa для безопасных платежей

---
