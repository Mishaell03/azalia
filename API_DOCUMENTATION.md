# API Documentation - Azalia Backend

## 1) Общая информация

- Приложение: `FastAPI`
- Base URL (локально): `http://localhost:5000`
- API Prefix: `/api`
- Swagger UI: `/docs`
- ReDoc: `/redoc`
- OpenAPI JSON: `/openapi.json`

## 2) Аутентификация и доступ

### Session token

Для защищенных методов передавайте **сырое значение session_token** в заголовке:

```http
Authorization: <session_token>
```

Важно:
- формат `Bearer <token>` не поддерживается;
- токен проверяется по активной сессии и сроку действия;
- у заблокированных/удаленных пользователей доступ к защищенным методам закрывается.

### Уровни доступа

- `Public` - без токена
- `User` - любой авторизованный пользователь
- `Admin` - только администратор
- `Employee/Admin` - сотрудник или администратор (в зависимости от endpoint)

## 3) Формат ответов

В проекте нет одного обязательного envelope для всех ручек, но чаще всего используются:

```json
{"success": true, "data": {...}}
```

или

```json
{"success": false, "detail": "..."}
```

Типовые коды:
- `200 OK`
- `201 Created`
- `400 Bad Request`
- `401 Unauthorized`
- `403 Forbidden`
- `404 Not Found`
- `413 Payload Too Large`
- `500 Internal Server Error`

## 4) Изображения и WebP

### Что изменено на бэке

- Загрузка изображений (`avatar`, `plant image`, `user plant photo`) теперь сохраняет файлы в `webp`.
- Endpoint `GET /img/{file_path:path}` теперь отдает изображения клиенту в формате `image/webp` (включая старые `png/jpg` через серверную конвертацию).

Это сделано без изменений фронтенда.

### Статический endpoint

- `GET /img/{file_path:path}` - отдать файл из каталога `img`.
- Если файл не найден, возвращается дефолтное изображение.

## 5) Полный список endpoint'ов

Ниже перечислены все актуальные ручки из `back/app/routes/*`.

## 5.1 Auth (`/api/auth`)

| Method | Path | Access | Назначение |
|---|---|---|---|
| POST | `/api/auth/validate_token` | Public | Validate session token |
| POST | `/api/auth/verify` | Public | Verify auth code |
| GET | `/api/auth/check_status/{code}` | Public | Check auth code status |
| GET, POST | `/api/auth/me` | User | Current user profile |
| POST | `/api/auth/update_profile` | User | Update name/phone |
| POST | `/api/auth/avatar` | User | Upload avatar (multipart) |
| GET | `/api/auth/avatar` | User | Get current avatar |
| GET | `/api/auth/subscription-plans` | User | Subscription plans |
| POST | `/api/auth/subscription-plans/checkout` | User | Create subscription checkout |
| GET | `/api/auth/subscription-plans/checkout/{checkout_id}/status` | User | Checkout status |
| GET | `/api/auth/subscription-payment-return` | Public | Return URL after payment |
| POST | `/api/auth/subscription-plans/callback` | Public | Subscription payment callback |
| POST | `/api/auth/subscription-plans/{plan_id}/cancel` | User | Cancel active subscription |

## 5.2 Plants (`/api/plants`)

| Method | Path | Access | Назначение |
|---|---|---|---|
| GET | `/api/plants/` | Public | List plants |
| GET | `/api/plants/categories` | Public | Plant categories |
| GET | `/api/plants/filters` | Public | Filter dictionaries |
| GET | `/api/plants/{plant_id}` | Public | Plant details |
| POST | `/api/plants/` | Admin | Create plant |
| POST | `/api/plants/admin/create` | Admin | Admin create plant |
| PUT | `/api/plants/{plant_id}` | Admin | Update plant |
| DELETE | `/api/plants/{plant_id}` | Admin | Archive plant |
| POST | `/api/plants/{plant_id}/image` | Admin | Upload preview image |
| POST | `/api/plants/{plant_id}/images` | Admin | Upload detail image |
| GET | `/api/plants/{plant_id}/images` | Admin | List plant images |
| DELETE | `/api/plants/{plant_id}/images/{image_id}` | Admin | Delete one image |
| DELETE | `/api/plants/{plant_id}/image` | Admin | Delete preview endpoint-stub |

## 5.3 Categories (`/api/categories`)

| Method | Path | Access | Назначение |
|---|---|---|---|
| GET | `/api/categories/` | Public | List categories |
| GET | `/api/categories/stats` | Admin | Categories statistics |
| GET | `/api/categories/{category_id}` | Public | Category details |
| POST | `/api/categories/` | Admin | Create category |
| POST | `/api/categories/admin/create` | Admin | Admin create category |
| PUT | `/api/categories/{category_id}` | Admin | Update category |
| DELETE | `/api/categories/{category_id}` | Admin | Delete category |
| GET | `/api/categories/admin/{category_id}/deletion-check` | Admin | Deletion validation |
| DELETE | `/api/categories/admin/{category_id}/delete` | Admin | Force admin delete |
| GET | `/api/categories/{category_id}/plants` | Public | Plants by category |

## 5.4 Cart & Wishlist (`/api/cart`)

| Method | Path | Access | Назначение |
|---|---|---|---|
| GET | `/api/cart/items` | User | Get cart items |
| POST | `/api/cart/items` | User | Add item to cart |
| PUT | `/api/cart/items/{item_id}` | User | Update cart item |
| DELETE | `/api/cart/items/{item_id}` | User | Delete cart item |
| DELETE | `/api/cart/clear` | User | Clear cart |
| GET | `/api/cart/wishlist` | User | Get wishlist |
| POST | `/api/cart/wishlist` | User | Add to wishlist |
| DELETE | `/api/cart/wishlist/{plant_id}` | User | Remove from wishlist |
| GET | `/api/cart/wishlist/check/{plant_id}` | User | Check in wishlist |
| GET | `/api/cart/pot/price` | User | Calculate pot price |

## 5.5 Pot Dictionaries (`/api/pot`)

| Method | Path | Access | Назначение |
|---|---|---|---|
| GET | `/api/pot/sizes` | Public | Pot sizes |
| GET | `/api/pot/materials` | Public | Pot materials |
| GET | `/api/pot/colors` | Public | Pot colors |
| GET | `/api/pot/variants` | Public | Pot variants |
| GET | `/api/pot/options` | Public | Options availability |
| GET | `/api/pot/prices` | Public | Pot prices |
| GET | `/api/pot/price` | Public | Single pot price |

## 5.6 Payments (`/api/payments`)

| Method | Path | Access | Назначение |
|---|---|---|---|
| GET | `/api/payments/stores` | User | Active stores for delivery/pickup |
| POST | `/api/payments/availability` | User | Check order availability |
| POST | `/api/payments/generate-link` | User | Generate payment link |
| GET | `/api/payments/return/{link_id}` | Public | YooKassa return page |
| GET | `/api/payments/link/{link_id}` | User | Payment link details |
| POST | `/api/payments/link/{link_id}/cancel` | User | Cancel payment link |
| POST | `/api/payments/callback` | Public | YooKassa callback |
| GET | `/api/payments/status/{payment_id}` | User | Payment status |
| GET | `/api/payments/status/link/{link_id}` | User | Payment link status |
| GET | `/api/payments/orders` | User | User order list |
| GET | `/api/payments/orders/{order_id}` | User | User order details |
| POST | `/api/payments/orders/{order_id}/cancel` | User | Cancel user order |
| PUT | `/api/payments/orders/{order_id}/address` | User | Update order address |
| GET | `/api/payments/admin/orders` | Admin | Admin order list |
| GET | `/api/payments/admin/orders/{order_id}` | Admin | Admin order details |
| POST | `/api/payments/admin/orders/{order_id}/accept` | Admin | Accept order |
| PATCH | `/api/payments/admin/orders/{order_id}/status` | Admin | Update order status |
| POST | `/api/payments/admin/orders/{order_id}/close` | Admin | Close order |
| POST | `/api/payments/admin/orders/{order_id}/mark-paid` | Admin | Mark paid |
| POST | `/api/payments/admin/orders/{order_id}/refund` | Admin | Refund payment |
| GET | `/api/payments/status/order/{order_id}` | User | Order payment status |

## 5.7 Employees & Procurement (`/api`)

| Method | Path | Access | Назначение |
|---|---|---|---|
| GET | `/api/users/{user_id}` | Admin | User details |
| GET | `/api/admins/{user_id}` | Admin | Admin details |
| PATCH | `/api/users/{user_id}` | Admin | Update user |
| PATCH | `/api/admins/{user_id}` | Admin | Update admin |
| GET | `/api/users` | Admin | User list |
| GET | `/api/admin/companies` | Admin | Companies with members |
| GET | `/api/debug/whoami` | User | Debug current user |
| GET | `/api/employees` | Admin | Employee list |
| GET | `/api/employees/{employee_id}` | Admin | Employee details |
| GET | `/api/warehouse/products` | Employee/Admin | Warehouse products |
| PATCH | `/api/warehouse/products/{product_id}/adjust` | Employee/Admin | Adjust stock |
| GET | `/api/procurement/stores` | Employee/Admin | Stores for procurement |
| GET | `/api/procurement/missing-products` | Employee/Admin | Missing products |
| GET | `/api/procurement/catalog-products` | Employee/Admin | Catalog for procurement |
| GET | `/api/procurement/cart` | Employee/Admin | Procurement cart |
| POST | `/api/procurement/cart/items` | Employee/Admin | Add/update cart item |
| DELETE | `/api/procurement/cart/items/{cart_item_id}` | Employee/Admin | Remove cart item |
| POST | `/api/procurement/cart/checkout` | Employee/Admin | Checkout procurement cart |
| GET | `/api/procurement/history` | Employee/Admin | Procurement history |
| GET | `/api/procurement/receipts` | Employee/Admin | Supplies for unloading |
| POST | `/api/procurement/receipts` | Employee/Admin | Accept unloading |
| GET | `/api/admin/analytics` | Admin | Sales analytics |
| GET | `/api/admin/subscription-plans` | Admin | Subscription plans (admin) |
| POST | `/api/employees/assign` | Admin | Assign employee |
| POST | `/api/employees/deactivate` | Admin | Deactivate/update employee |

## 5.8 Notifications (`/api/notifications`)

| Method | Path | Access | Назначение |
|---|---|---|---|
| GET | `/api/notifications/items` | User | User notifications |

## 5.9 Important Dates (`/api/important-dates`)

| Method | Path | Access | Назначение |
|---|---|---|---|
| GET | `/api/important-dates` | User | List dates |
| GET | `/api/important-dates/holiday-preferences` | User | List holiday prefs |
| POST | `/api/important-dates/holiday-preferences` | User | Add holiday pref |
| GET | `/api/important-dates/holiday-preferences/options` | User | Holiday pref options |
| GET | `/api/important-dates/preferences/options` | User | Date pref options |
| GET | `/api/important-dates/{important_date_id}/preferences` | User | Date prefs list |
| POST | `/api/important-dates/{important_date_id}/preferences` | User | Add date pref |
| DELETE | `/api/important-dates/preferences/{preference_id}` | User | Delete date pref |
| DELETE | `/api/important-dates/holiday-preferences/{preference_id}` | User | Delete holiday pref |
| GET | `/api/important-dates/{important_date_id}` | User | Date details |
| POST | `/api/important-dates` | User | Create date |
| PUT | `/api/important-dates/{important_date_id}` | User | Update date |
| DELETE | `/api/important-dates/{important_date_id}` | User | Delete date |

## 5.10 Plant Care Dates (`/api/plant-care-dates`)

| Method | Path | Access | Назначение |
|---|---|---|---|
| GET | `/api/plant-care-dates` | User | List care dates |
| GET | `/api/plant-care-dates/{care_date_id}` | User | Care date details |
| POST | `/api/plant-care-dates` | User | Create care date |
| PUT | `/api/plant-care-dates/{care_date_id}` | User | Update care date |
| DELETE | `/api/plant-care-dates/{care_date_id}` | User | Delete care date |

## 5.11 User Plants (`/api/user-plants`)

| Method | Path | Access | Назначение |
|---|---|---|---|
| GET | `/api/user-plants` | User | My plants list |
| GET | `/api/user-plants/limits` | User | Plan limits |
| GET | `/api/user-plants/{plant_id}` | User | Plant details |
| POST | `/api/user-plants` | User | Create user plant |
| PUT | `/api/user-plants/{plant_id}` | User | Update user plant |
| DELETE | `/api/user-plants/{plant_id}` | User | Delete user plant |
| POST | `/api/user-plants/{plant_id}/care` | User | Mark care action |
| POST | `/api/user-plants/{plant_id}/photo` | User | Upload plant photo |
| GET | `/api/user-plants/care/types` | User | Care type dictionary |

## 5.12 Company Calendar (`/api/company-calendar-events`)

| Method | Path | Access | Назначение |
|---|---|---|---|
| GET | `/api/company-calendar-events/organizations` | User | My organizations |
| GET | `/api/company-calendar-events` | User | Event list |
| POST | `/api/company-calendar-events` | User | Create event |
| PUT | `/api/company-calendar-events/{event_id}` | User | Update event |
| DELETE | `/api/company-calendar-events/{event_id}` | User | Delete event |
| GET | `/api/company-calendar-events/preferences/options` | User | Preference options |
| GET | `/api/company-calendar-events/{event_id}/preferences` | User | Event preferences |
| POST | `/api/company-calendar-events/{event_id}/preferences` | User | Add event preference |
| DELETE | `/api/company-calendar-events/preferences/{preference_id}` | User | Delete event preference |

## 5.13 Corporate Subscription (`/api/corporate-subscription`)

| Method | Path | Access | Назначение |
|---|---|---|---|
| GET | `/api/corporate-subscription/company` | User | Current company |
| POST | `/api/corporate-subscription/company` | User | Create company |
| GET | `/api/corporate-subscription/company/members` | User | Company members |
| POST | `/api/corporate-subscription/company/members` | User | Add member |
| DELETE | `/api/corporate-subscription/company/members/{member_user_id}` | User | Remove member |

## 5.14 Service endpoints

| Method | Path | Access | Назначение |
|---|---|---|---|
| GET | `/` | Public | Health check |
| GET | `/img/{file_path:path}` | Public | Static image отдача (в `webp`) |

## 6) Загрузка файлов (multipart)

Используются endpoint'ы:
- `POST /api/auth/avatar` (field: `avatar`)
- `POST /api/plants/{plant_id}/image` (field: `image`)
- `POST /api/plants/{plant_id}/images` (field: `image`)
- `POST /api/user-plants/{plant_id}/photo` (field: `file`)

Поддерживаемые входные расширения:
- `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`

После загрузки сервер сохраняет результат в `.webp`.

## 7) Пример запроса

```bash
curl -X GET 'http://localhost:5000/api/plants/'
```

```bash
curl -X POST 'http://localhost:5000/api/auth/me' \
  -H 'Authorization: <session_token>'
```

```bash
curl -X POST 'http://localhost:5000/api/auth/avatar' \
  -H 'Authorization: <session_token>' \
  -F 'avatar=@/path/to/avatar.png'
```
