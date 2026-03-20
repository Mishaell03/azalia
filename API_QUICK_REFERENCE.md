# API Quick Reference - Azalia

## Base

- Base URL: `http://localhost:5000`
- API prefix: `/api`
- Docs: `/docs`, `/redoc`, `/openapi.json`
- Auth header for protected methods: `Authorization: <session_token>` (не `Bearer`)

## Images (WebP)

- `GET /img/{file_path:path}` - сервер отдает изображения как `image/webp`
- Upload ручки сохраняют изображения в `.webp`:
  - `POST /api/auth/avatar`
  - `POST /api/plants/{plant_id}/image`
  - `POST /api/plants/{plant_id}/images`
  - `POST /api/user-plants/{plant_id}/photo`

## Auth `/api/auth`

- `POST /validate_token`
- `POST /verify`
- `GET /check_status/{code}`
- `GET|POST /me`
- `POST /update_profile`
- `POST /avatar`
- `GET /avatar`
- `GET /subscription-plans`
- `POST /subscription-plans/checkout`
- `GET /subscription-plans/checkout/{checkout_id}/status`
- `GET /subscription-payment-return`
- `POST /subscription-plans/callback`
- `POST /subscription-plans/{plan_id}/cancel`

## Plants `/api/plants`

- `GET /`
- `GET /categories`
- `GET /filters`
- `GET /{plant_id}`
- `POST /`
- `POST /admin/create`
- `PUT /{plant_id}`
- `DELETE /{plant_id}`
- `POST /{plant_id}/image`
- `POST /{plant_id}/images`
- `GET /{plant_id}/images`
- `DELETE /{plant_id}/images/{image_id}`
- `DELETE /{plant_id}/image`

## Categories `/api/categories`

- `GET /`
- `GET /stats`
- `GET /{category_id}`
- `POST /`
- `POST /admin/create`
- `PUT /{category_id}`
- `DELETE /{category_id}`
- `GET /admin/{category_id}/deletion-check`
- `DELETE /admin/{category_id}/delete`
- `GET /{category_id}/plants`

## Cart `/api/cart`

- `GET /items`
- `POST /items`
- `PUT /items/{item_id}`
- `DELETE /items/{item_id}`
- `DELETE /clear`
- `GET /wishlist`
- `POST /wishlist`
- `DELETE /wishlist/{plant_id}`
- `GET /wishlist/check/{plant_id}`
- `GET /pot/price`

## Pot `/api/pot`

- `GET /sizes`
- `GET /materials`
- `GET /colors`
- `GET /variants`
- `GET /options`
- `GET /prices`
- `GET /price`

## Payments `/api/payments`

- `GET /stores`
- `POST /availability`
- `POST /generate-link`
- `GET /return/{link_id}`
- `GET /link/{link_id}`
- `POST /link/{link_id}/cancel`
- `POST /callback`
- `GET /status/{payment_id}`
- `GET /status/link/{link_id}`
- `GET /orders`
- `GET /orders/{order_id}`
- `POST /orders/{order_id}/cancel`
- `PUT /orders/{order_id}/address`
- `GET /admin/orders`
- `GET /admin/orders/{order_id}`
- `POST /admin/orders/{order_id}/accept`
- `PATCH /admin/orders/{order_id}/status`
- `POST /admin/orders/{order_id}/close`
- `POST /admin/orders/{order_id}/mark-paid`
- `POST /admin/orders/{order_id}/refund`
- `GET /status/order/{order_id}`

## Employees & Procurement `/api`

- `GET /users/{user_id}`
- `GET /admins/{user_id}`
- `PATCH /users/{user_id}`
- `PATCH /admins/{user_id}`
- `GET /users`
- `GET /admin/companies`
- `GET /debug/whoami`
- `GET /employees`
- `GET /employees/{employee_id}`
- `GET /warehouse/products`
- `PATCH /warehouse/products/{product_id}/adjust`
- `GET /procurement/stores`
- `GET /procurement/missing-products`
- `GET /procurement/catalog-products`
- `GET /procurement/cart`
- `POST /procurement/cart/items`
- `DELETE /procurement/cart/items/{cart_item_id}`
- `POST /procurement/cart/checkout`
- `GET /procurement/history`
- `GET /procurement/receipts`
- `POST /procurement/receipts`
- `GET /admin/analytics`
- `GET /admin/subscription-plans`
- `POST /employees/assign`
- `POST /employees/deactivate`

## Other modules

### Notifications `/api/notifications`
- `GET /items`

### Important Dates `/api/important-dates`
- `GET /`
- `GET /holiday-preferences`
- `POST /holiday-preferences`
- `GET /holiday-preferences/options`
- `GET /preferences/options`
- `GET /{important_date_id}/preferences`
- `POST /{important_date_id}/preferences`
- `DELETE /preferences/{preference_id}`
- `DELETE /holiday-preferences/{preference_id}`
- `GET /{important_date_id}`
- `POST /`
- `PUT /{important_date_id}`
- `DELETE /{important_date_id}`

### Plant Care Dates `/api/plant-care-dates`
- `GET /`
- `GET /{care_date_id}`
- `POST /`
- `PUT /{care_date_id}`
- `DELETE /{care_date_id}`

### User Plants `/api/user-plants`
- `GET /`
- `GET /limits`
- `GET /{plant_id}`
- `POST /`
- `PUT /{plant_id}`
- `DELETE /{plant_id}`
- `POST /{plant_id}/care`
- `POST /{plant_id}/photo`
- `GET /care/types`

### Company Calendar `/api/company-calendar-events`
- `GET /organizations`
- `GET /`
- `POST /`
- `PUT /{event_id}`
- `DELETE /{event_id}`
- `GET /preferences/options`
- `GET /{event_id}/preferences`
- `POST /{event_id}/preferences`
- `DELETE /preferences/{preference_id}`

### Corporate Subscription `/api/corporate-subscription`
- `GET /company`
- `POST /company`
- `GET /company/members`
- `POST /company/members`
- `DELETE /company/members/{member_user_id}`
