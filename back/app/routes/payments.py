from __future__ import annotations

import base64
import json
import random
import uuid
from datetime import datetime
from typing import Optional
from urllib import error as urllib_error
from urllib import request as urllib_request

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.responses import HTMLResponse, RedirectResponse
from pydantic import BaseModel, ConfigDict, Field

from app.config import get_settings
from app.db import get_db_connection
from app.routes.utils import clean_text, get_current_user

router = APIRouter(prefix="/api/payments", tags=["payments"])


class GeneratePaymentLinkRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    address: Optional[str] = Field(default=None, min_length=5, max_length=500)
    payment_method: str = Field(default="card", max_length=32)
    selected_item_ids: list[int] = Field(default_factory=list, max_length=200)
    order_type: str = Field(default="delivery", max_length=16)
    store_id: Optional[int] = Field(default=None, ge=1)
    comment: Optional[str] = Field(default=None, max_length=500)


class PaymentCallbackRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    object: dict


class UpdateOrderAddressRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    address: str = Field(min_length=5, max_length=500)


def _generate_order_number(cur) -> str:
    for _ in range(20):
        # YYYYMMDD + 6 случайных цифр
        candidate = f"{datetime.utcnow().strftime('%Y%m%d')}{random.randint(0, 999999):06d}"
        exists = cur.execute(
            "SELECT id FROM orders WHERE order_number = ?",
            (candidate,),
        ).fetchone()
        if not exists:
            return candidate
    raise HTTPException(status_code=500, detail="Failed to generate order number")


def _resolve_payment_method(cur, payment_method_code: str) -> int:
    row = cur.execute(
        """
        SELECT id
        FROM payment_methods
        WHERE code = ? AND is_active = 1
        LIMIT 1
        """,
        (payment_method_code,),
    ).fetchone()
    if not row:
        raise HTTPException(status_code=400, detail="Invalid payment method")
    return int(row["id"])


def _get_cart_items_for_checkout(cur, user_id: int, selected_item_ids: list[int]):
    sql = """
        SELECT
            ci.*,
            p.name AS product_name,
            p.description AS product_description,
            p.base_price,
            p.cost_price,
            p.is_active,
            p.deleted_at,
            COALESCE(SUM(i.quantity_available), 0) AS available_qty
        FROM cart_items ci
        JOIN products p ON p.id = ci.product_id
        LEFT JOIN inventory i ON i.product_id = p.id
        WHERE ci.user_id = ?
    """
    params: list[object] = [user_id]

    if selected_item_ids:
        placeholders = ",".join(["?"] * len(selected_item_ids))
        sql += f" AND ci.id IN ({placeholders})"
        params.extend(selected_item_ids)

    sql += " GROUP BY ci.id ORDER BY ci.created_at ASC"

    rows = cur.execute(sql, tuple(params)).fetchall()
    return rows


def _validate_cart_items(cur, cart_items):
    if not cart_items:
        raise HTTPException(status_code=400, detail="Корзина пуста")

    total_price = 0.0
    validated = []

    for item in cart_items:
        if not bool(item["is_active"]) or item["deleted_at"] is not None:
            raise HTTPException(
                status_code=400,
                detail=f'Товар "{item["product_name"]}" больше не доступен',
            )

        available_qty = int(item["available_qty"])
        if int(item["quantity"]) > available_qty:
            raise HTTPException(
                status_code=400,
                detail=f'Недостаточно "{item["product_name"]}" в наличии. Доступно: {available_qty}',
            )

        current_product_price = float(item["base_price"])
        if float(item["product_unit_price"]) != current_product_price:
            raise HTTPException(
                status_code=400,
                detail=f'Цена товара "{item["product_name"]}" изменилась. Обновите корзину.',
            )

        current_pot_price = 0.0
        if item["pot_size_id"] is not None and item["pot_material_id"] is not None:
            pot = cur.execute(
                """
                SELECT price
                FROM pot_prices
                WHERE size_id = ? AND material_id = ?
                LIMIT 1
                """,
                (item["pot_size_id"], item["pot_material_id"]),
            ).fetchone()
            if not pot:
                raise HTTPException(status_code=400, detail="Выбранный горшок недоступен")
            current_pot_price = float(pot["price"])
            if float(item["pot_unit_price"]) != current_pot_price:
                raise HTTPException(status_code=400, detail="Цена горшка изменилась. Обновите корзину.")
        elif float(item["pot_unit_price"]) != 0.0:
            raise HTTPException(status_code=400, detail="Некорректные данные о горшке")

        item_total = (current_product_price + current_pot_price) * int(item["quantity"])
        total_price += item_total
        validated.append((item, round(item_total, 2)))

    return round(total_price, 2), validated


def _format_payment_row(row):
    if not row:
        return None

    created_raw = row["created_at"]
    try:
        created_at = datetime.strptime(created_raw, "%Y-%m-%d %H:%M:%S")
    except ValueError:
        created_at = datetime.fromisoformat(created_raw)
    expires_at = created_at.replace(microsecond=0)
    expires_at = expires_at.timestamp() + 24 * 3600

    return {
        "id": row["id"],
        "order_id": row["order_id"],
        "user_id": row["user_id"],
        "amount": float(row["amount"]),
        "status": row["status"],
        "payment_method_id": row["payment_method_id"],
        "external_payment_id": row["external_payment_id"],
        "created_at": row["created_at"],
        "paid_at": row["paid_at"],
        "failed_at": row["failed_at"],
        "expires_at": datetime.utcfromtimestamp(expires_at).strftime("%Y-%m-%d %H:%M:%S"),
    }


def _format_order_summary_row(row):
    return {
        "order_id": int(row["id"]),
        "order_number": row["order_number"],
        "status": row["status"],
        "payment_status": row["payment_status"],
        "order_type": row["order_type"],
        "total_price": float(row["total_price"]),
        "items_count": int(row["items_count"] or 0),
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


def _get_latest_payment_for_order(cur, order_id: int):
    return cur.execute(
        """
        SELECT
            p.*,
            pm.code AS payment_method_code,
            pm.name AS payment_method_name
        FROM payments p
        LEFT JOIN payment_methods pm ON pm.id = p.payment_method_id
        WHERE p.order_id = ?
        ORDER BY p.id DESC
        LIMIT 1
        """,
        (order_id,),
    ).fetchone()


def _get_order_refunds(cur, payment_id: int) -> list[dict]:
    refunds = cur.execute(
        """
        SELECT
            r.id,
            r.amount,
            r.reason,
            r.status,
            r.processed_at,
            r.created_at
        FROM refunds r
        WHERE r.payment_id = ?
        ORDER BY r.created_at DESC, r.id DESC
        """,
        (payment_id,),
    ).fetchall()
    return [
        {
            "id": int(refund["id"]),
            "amount": float(refund["amount"]),
            "reason": refund["reason"],
            "status": refund["status"],
            "processed_at": refund["processed_at"],
            "created_at": refund["created_at"],
        }
        for refund in refunds
    ]


def _get_order_status_history(cur, order_id: int) -> list[dict]:
    rows = cur.execute(
        """
        SELECT
            osh.id,
            osh.old_status,
            osh.new_status,
            osh.created_at,
            e.id AS employee_id,
            u.full_name AS employee_name
        FROM order_status_history osh
        LEFT JOIN employees e ON e.id = osh.changed_by_employee_id
        LEFT JOIN users u ON u.id = e.user_id
        WHERE osh.order_id = ?
        ORDER BY osh.created_at ASC, osh.id ASC
        """,
        (order_id,),
    ).fetchall()
    return [
        {
            "id": int(row["id"]),
            "old_status": row["old_status"],
            "new_status": row["new_status"],
            "changed_at": row["created_at"],
            "changed_by": {
                "employee_id": int(row["employee_id"]) if row["employee_id"] is not None else None,
                "employee_name": row["employee_name"],
            },
        }
        for row in rows
    ]


def _get_order_items_details(cur, order_id: int) -> list[dict]:
    rows = cur.execute(
        """
        SELECT
            oi.*,
            ps.name AS pot_size_name,
            pm.name AS pot_material_name,
            pc.name AS pot_color_name,
            p.image_url AS current_image_url
        FROM order_items oi
        LEFT JOIN pot_sizes ps ON ps.id = oi.pot_size_id
        LEFT JOIN pot_materials pm ON pm.id = oi.pot_material_id
        LEFT JOIN pot_colors pc ON pc.id = oi.pot_color_id
        LEFT JOIN products p ON p.id = oi.product_id
        WHERE oi.order_id = ?
        ORDER BY oi.id ASC
        """,
        (order_id,),
    ).fetchall()
    return [
        {
            "id": int(row["id"]),
            "product_id": int(row["product_id"]) if row["product_id"] is not None else None,
            "plant_id": int(row["product_id"]) if row["product_id"] is not None else None,
            "name": row["product_name_snapshot"],
            "description": row["product_description_snapshot"],
            "quantity": int(row["quantity"]),
            "returned_quantity": int(row["returned_quantity"]),
            "product_unit_price": float(row["product_unit_price"]),
            "pot_unit_price": float(row["pot_unit_price"]),
            "discount_amount": float(row["discount_amount"]),
            "total_price": float(row["total_price"]),
            "image_url": row["current_image_url"],
            "pot": {
                "size_id": int(row["pot_size_id"]) if row["pot_size_id"] is not None else None,
                "size_code": row["pot_size_name"],
                "size_name": row["pot_size_name"],
                "material_id": int(row["pot_material_id"]) if row["pot_material_id"] is not None else None,
                "material_name": row["pot_material_name"],
                "color_id": int(row["pot_color_id"]) if row["pot_color_id"] is not None else None,
                "color_name": row["pot_color_name"],
            },
            "created_at": row["created_at"],
        }
        for row in rows
    ]


def _format_order_detail(cur, order_row, payment_row):
    payment_data = None
    refunds: list[dict] = []
    if payment_row:
        payment_data = _format_payment_row(payment_row)
        payment_data["payment_method_code"] = payment_row["payment_method_code"]
        payment_data["payment_method_name"] = payment_row["payment_method_name"]
        refunds = _get_order_refunds(cur, int(payment_row["id"]))

    items = _get_order_items_details(cur, int(order_row["id"]))
    history = _get_order_status_history(cur, int(order_row["id"]))

    return {
        "order_id": int(order_row["id"]),
        "order_number": order_row["order_number"],
        "status": order_row["status"],
        "payment_status": order_row["payment_status"],
        "order_type": order_row["order_type"],
        "store_id": int(order_row["store_id"]),
        "address": order_row["address_snapshot"],
        "comment": order_row["comment"],
        "subtotal": float(order_row["subtotal"]),
        "delivery_fee": float(order_row["delivery_fee"]),
        "discount_amount": float(order_row["discount_amount"]),
        "total_price": float(order_row["total_price"]),
        "assigned_employee_id": (
            int(order_row["assigned_employee_id"])
            if order_row["assigned_employee_id"] is not None
            else None
        ),
        "created_at": order_row["created_at"],
        "updated_at": order_row["updated_at"],
        "items": items,
        "payment": payment_data,
        "refunds": refunds,
        "status_history": history,
    }


def _sync_payment_and_order(cur, payment_row, new_status: str):
    payment_id = payment_row["id"]
    order_id = payment_row["order_id"]

    if new_status == "paid":
        cur.execute(
            """
            UPDATE payments
            SET status = 'paid',
                paid_at = CURRENT_TIMESTAMP,
                failed_at = NULL
            WHERE id = ?
            """,
            (payment_id,),
        )
        cur.execute(
            """
            UPDATE orders
            SET payment_status = 'paid',
                status = CASE WHEN status = 'awaiting_payment' THEN 'processing' ELSE status END,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """,
            (order_id,),
        )

        order_items = cur.execute(
            """
            SELECT product_id, quantity, pot_size_id, pot_material_id, pot_color_id
            FROM order_items
            WHERE order_id = ?
            """,
            (order_id,),
        ).fetchall()

        user_id = payment_row["user_id"]
        for oi in order_items:
            cart_item = cur.execute(
                """
                SELECT id, quantity
                FROM cart_items
                WHERE user_id = ?
                  AND product_id = ?
                  AND IFNULL(pot_size_id, 0) = IFNULL(?, 0)
                  AND IFNULL(pot_material_id, 0) = IFNULL(?, 0)
                  AND IFNULL(pot_color_id, 0) = IFNULL(?, 0)
                ORDER BY id ASC
                LIMIT 1
                """,
                (
                    user_id,
                    oi["product_id"],
                    oi["pot_size_id"],
                    oi["pot_material_id"],
                    oi["pot_color_id"],
                ),
            ).fetchone()

            if cart_item:
                cart_qty = int(cart_item["quantity"])
                if cart_qty <= int(oi["quantity"]):
                    cur.execute("DELETE FROM cart_items WHERE id = ?", (cart_item["id"],))
                else:
                    new_qty = cart_qty - int(oi["quantity"])
                    cur.execute(
                        """
                        UPDATE cart_items
                        SET quantity = ?,
                            total_price = ROUND((product_unit_price + pot_unit_price) * ?, 2)
                        WHERE id = ?
                        """,
                        (new_qty, new_qty, cart_item["id"]),
                    )

                cur.execute(
                    """
                    UPDATE inventory
                    SET quantity_reserved = CASE
                        WHEN quantity_reserved >= ? THEN quantity_reserved - ?
                        ELSE 0
                    END,
                    quantity_available = CASE
                        WHEN quantity_available >= ? THEN quantity_available - ?
                        ELSE 0
                    END
                    WHERE product_id = ?
                    """,
                    (
                        oi["quantity"],
                        oi["quantity"],
                        oi["quantity"],
                        oi["quantity"],
                        oi["product_id"],
                    ),
                )

    elif new_status == "failed":
        cur.execute(
            """
            UPDATE payments
            SET status = 'failed',
                failed_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """,
            (payment_id,),
        )
        cur.execute(
            """
            UPDATE orders
            SET payment_status = 'failed',
                status = CASE
                    WHEN status IN ('new', 'awaiting_payment', 'processing') THEN 'cancelled'
                    ELSE status
                END,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """,
            (order_id,),
        )


def _api_origin(request: Request) -> str:
    return str(request.base_url).rstrip("/")


def _api_base_url(request: Request) -> str:
    return f"{_api_origin(request)}/api"


def _yookassa_enabled(settings) -> bool:
    return bool(settings.YOOKASSA_SHOP_ID and settings.YOOKASSA_API_KEY)


def _map_yookassa_status(remote_status: Optional[str]) -> str:
    if remote_status == "succeeded":
        return "paid"
    if remote_status == "canceled":
        return "failed"
    return "pending"


def _yookassa_request(settings, method: str, path: str, payload: Optional[dict] = None) -> dict:
    credentials = f"{settings.YOOKASSA_SHOP_ID}:{settings.YOOKASSA_API_KEY}"
    headers = {
        "Authorization": f"Basic {base64.b64encode(credentials.encode('utf-8')).decode('utf-8')}",
        "Content-Type": "application/json",
    }
    if method.upper() == "POST":
        headers["Idempotence-Key"] = str(uuid.uuid4())

    request_obj = urllib_request.Request(
        url=f"https://api.yookassa.ru/v3/{path.lstrip('/')}",
        data=json.dumps(payload).encode("utf-8") if payload is not None else None,
        headers=headers,
        method=method.upper(),
    )

    try:
        with urllib_request.urlopen(request_obj, timeout=20) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib_error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="ignore")
        raise HTTPException(
            status_code=502,
            detail=f"YooKassa error: {body or exc.reason}",
        )
    except urllib_error.URLError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"YooKassa unavailable: {exc.reason}",
        )


def _create_yookassa_payment(
    settings,
    *,
    amount: float,
    order_number: str,
    return_url: str,
    payment_method_code: str,
    metadata: dict[str, str],
) -> dict:
    payload = {
        "amount": {
            "value": f"{amount:.2f}",
            "currency": "RUB",
        },
        "capture": True,
        "confirmation": {
            "type": "redirect",
            "return_url": return_url,
        },
        "description": f"Оплата заказа {order_number}",
        "metadata": metadata,
        "payment_method_data": {
            "type": "sbp" if payment_method_code == "sbp" else "bank_card",
        },
    }

    return _yookassa_request(settings, "POST", "/payments", payload)


def _fetch_yookassa_payment(settings, external_payment_id: str) -> dict:
    return _yookassa_request(settings, "GET", f"/payments/{external_payment_id}")


def _refresh_payment_status(cur, settings, payment_row) -> str:
    external_payment_id = payment_row["external_payment_id"]
    if not _yookassa_enabled(settings) or not external_payment_id:
        return payment_row["status"]

    try:
        remote_payment = _fetch_yookassa_payment(settings, str(external_payment_id))
    except HTTPException:
        return payment_row["status"]

    mapped_status = _map_yookassa_status(remote_payment.get("status"))

    if mapped_status == "paid" and payment_row["status"] != "paid":
        _sync_payment_and_order(cur, payment_row, "paid")
    elif mapped_status == "failed" and payment_row["status"] not in {"failed", "paid"}:
        _sync_payment_and_order(cur, payment_row, "failed")

    return mapped_status


@router.post("/generate-link", status_code=status.HTTP_201_CREATED, summary="Generate Payment Link")
def generate_payment_link(
    payload: GeneratePaymentLinkRequest,
    request: Request,
    user=Depends(get_current_user),
):
    """Создает заказ и платеж, возвращает ссылку/идентификатор для оплаты."""
    settings = get_settings()

    payment_method_code = clean_text(payload.payment_method, max_len=32).lower()
    order_type = clean_text(payload.order_type, max_len=16).lower()
    if order_type not in {"delivery", "pickup"}:
        raise HTTPException(status_code=400, detail="Invalid order_type")

    address = clean_text(payload.address, max_len=500) if payload.address else None
    if order_type == "delivery" and (not address or len(address) < 5):
        raise HTTPException(status_code=400, detail="Address must be between 5 and 500 characters")

    comment = clean_text(payload.comment, max_len=500) if payload.comment else None

    selected_ids = sorted(set(payload.selected_item_ids))

    conn = get_db_connection()
    try:
        cur = conn.cursor()

        store_id = payload.store_id or 1
        store = cur.execute("SELECT id FROM stores WHERE id = ? AND is_active = 1", (store_id,)).fetchone()
        if not store:
            raise HTTPException(status_code=400, detail="Store not found or inactive")

        payment_method_id = _resolve_payment_method(cur, payment_method_code)

        cart_items = _get_cart_items_for_checkout(cur, int(user["id"]), selected_ids)
        total_price, validated_items = _validate_cart_items(cur, cart_items)

        order_number = _generate_order_number(cur)
        cur.execute(
            """
            INSERT INTO orders (
                user_id, company_id, store_id, order_number, order_type,
                address_id, address_snapshot, comment,
                subtotal, delivery_fee, discount_amount, total_price,
                payment_status, status, assigned_employee_id
            )
            VALUES (?, NULL, ?, ?, ?, NULL, ?, ?, ?, 0, 0, ?, 'pending', 'awaiting_payment', NULL)
            """,
            (
                user["id"],
                store_id,
                order_number,
                order_type,
                address,
                comment,
                total_price,
                total_price,
            ),
        )
        order_id = cur.lastrowid

        items_for_response = []
        for item, item_total in validated_items:
            cur.execute(
                """
                INSERT INTO order_items (
                    order_id, product_id,
                    product_name_snapshot, product_description_snapshot,
                    quantity, product_unit_price, product_cost_price,
                    pot_size_id, pot_material_id, pot_color_id,
                    pot_unit_price, discount_amount, total_price
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)
                """,
                (
                    order_id,
                    item["product_id"],
                    item["product_name"],
                    item["product_description"],
                    item["quantity"],
                    item["product_unit_price"],
                    item["cost_price"],
                    item["pot_size_id"],
                    item["pot_material_id"],
                    item["pot_color_id"],
                    item["pot_unit_price"],
                    item_total,
                ),
            )

            items_for_response.append(
                {
                    "cart_item_id": item["id"],
                    "product_id": item["product_id"],
                    "plant_id": item["product_id"],
                    "plant_name": item["product_name"],
                    "quantity": int(item["quantity"]),
                    "plant_price": float(item["product_unit_price"]),
                    "pot_price": float(item["pot_unit_price"]),
                    "item_total": float(item_total),
                }
            )

        external_payment_id = f"pending_{uuid.uuid4().hex}"
        cur.execute(
            """
            INSERT INTO payments (
                order_id, user_id, payment_method_id, amount, status,
                external_payment_id, paid_at, failed_at
            )
            VALUES (?, ?, ?, ?, 'pending', ?, NULL, NULL)
            """,
            (order_id, user["id"], payment_method_id, total_price, external_payment_id),
        )
        payment_id = cur.lastrowid

        if not _yookassa_enabled(settings):
            raise HTTPException(status_code=500, detail="YooKassa is not configured")

        remote_payment = _create_yookassa_payment(
            settings,
            amount=total_price,
            order_number=order_number,
            return_url=f"{_api_base_url(request)}/payments/return/{payment_id}",
            payment_method_code=payment_method_code,
            metadata={
                "payment_link_id": str(payment_id),
                "order_id": str(order_id),
                "user_id": str(user["id"]),
            },
        )
        external_payment_id = str(remote_payment["id"])
        payment_url = str(
            remote_payment.get("confirmation", {}).get("confirmation_url") or ""
        )
        if not payment_url:
            raise HTTPException(status_code=502, detail="YooKassa confirmation_url is missing")

        cur.execute(
            "UPDATE payments SET external_payment_id = ? WHERE id = ?",
            (external_payment_id, payment_id),
        )

        conn.commit()
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "payment_link_id": int(payment_id),
            "order_id": int(order_id),
            "payment_url": payment_url,
            "amount": float(total_price),
            "currency": "RUB",
            "items_count": len(items_for_response),
            "items": items_for_response,
            "address": address,
            "payment_method": payment_method_code,
            "message": "Оплатите заказ по ссылке выше. После успешной оплаты товары будут удалены из корзины.",
        },
    }


@router.get("/return/{link_id}", response_class=HTMLResponse, summary="YooKassa Return")
def payment_return(link_id: int, request: Request, payment_status: Optional[str] = None):
    settings = get_settings()
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        payment = cur.execute(
            "SELECT * FROM payments WHERE id = ? LIMIT 1",
            (link_id,),
        ).fetchone()
        if not payment:
            raise HTTPException(status_code=404, detail="Payment link not found")

        if payment_status is None:
            current_status = _refresh_payment_status(cur, settings, payment)
            conn.commit()
            return RedirectResponse(
                url=f"{_api_base_url(request)}/payments/return/{link_id}?payment_status={current_status}",
                status_code=status.HTTP_303_SEE_OTHER,
            )
    finally:
        conn.close()

    status_text = {
        "paid": "Оплата подтверждена. Можно вернуться в приложение.",
        "failed": "Платёж отменён. Можно вернуться в приложение.",
    }.get(payment_status or "pending", "Платёж ещё обрабатывается. Вернитесь в приложение и обновите статус.")

    return HTMLResponse(
        f"""
<!doctype html>
<html lang="ru">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Возврат в приложение</title>
    <style>
      body {{
        margin: 0;
        min-height: 100vh;
        display: grid;
        place-items: center;
        background: #f6f0e8;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      }}
      .card {{
        max-width: 420px;
        margin: 24px;
        padding: 24px;
        background: #fff;
        border-radius: 24px;
        box-shadow: 0 16px 40px rgba(31, 41, 55, 0.08);
        text-align: center;
        color: #1f2937;
      }}
    </style>
  </head>
  <body>
    <div class="card">
      <h1>Azalia</h1>
      <p>{status_text}</p>
    </div>
  </body>
</html>
"""
    )


@router.get("/link/{link_id}", summary="Get Payment Link")
def get_payment_link(link_id: int, user=Depends(get_current_user)):
    """Возвращает информацию о платеже по его внутреннему идентификатору."""
    settings = get_settings()
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        row = cur.execute(
            "SELECT * FROM payments WHERE id = ? LIMIT 1",
            (link_id,),
        ).fetchone()
        if row and int(row["user_id"]) == int(user["id"]):
            _refresh_payment_status(cur, settings, row)
            conn.commit()
            row = cur.execute(
                "SELECT * FROM payments WHERE id = ? LIMIT 1",
                (link_id,),
            ).fetchone()
    finally:
        conn.close()

    if not row:
        raise HTTPException(status_code=404, detail="Payment link not found")
    if int(row["user_id"]) != int(user["id"]):
        raise HTTPException(status_code=403, detail="Access denied")

    return {"success": True, "data": _format_payment_row(row)}


@router.post("/link/{link_id}/cancel", summary="Cancel Payment Link")
def cancel_payment_link(link_id: int, user=Depends(get_current_user)):
    """Отменяет ожидающий платеж и переводит заказ в отмененный/failed статус."""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        row = cur.execute(
            "SELECT * FROM payments WHERE id = ? LIMIT 1",
            (link_id,),
        ).fetchone()

        if not row:
            raise HTTPException(status_code=404, detail="Payment link not found")
        if int(row["user_id"]) != int(user["id"]):
            raise HTTPException(status_code=403, detail="Access denied")
        if row["status"] in {"paid", "refunded", "failed"}:
            raise HTTPException(status_code=400, detail=f"Cannot cancel payment link with status: {row['status']}")

        _sync_payment_and_order(cur, row, "failed")
        conn.commit()
    finally:
        conn.close()

    return {"success": True, "message": "Payment link cancelled successfully"}


@router.post("/callback", summary="Payment Callback")
def payment_callback(payload: PaymentCallbackRequest):
    """Webhook для обновления статуса платежа от внешней системы."""
    payment_data = payload.object or {}
    external_payment_id = clean_text(payment_data.get("id"), max_len=128)
    incoming_status = clean_text(payment_data.get("status"), max_len=32).lower()

    if not external_payment_id or incoming_status not in {"succeeded", "paid", "canceled", "cancelled", "failed", "expired", "pending"}:
        raise HTTPException(status_code=400, detail="Invalid callback payload")

    mapped_status = "pending"
    if incoming_status in {"succeeded", "paid"}:
        mapped_status = "paid"
    elif incoming_status in {"canceled", "cancelled", "failed", "expired"}:
        mapped_status = "failed"

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        payment = cur.execute(
            "SELECT * FROM payments WHERE external_payment_id = ? LIMIT 1",
            (external_payment_id,),
        ).fetchone()

        if not payment:
            raise HTTPException(status_code=404, detail="Payment not found")

        if mapped_status == "paid" and payment["status"] != "paid":
            _sync_payment_and_order(cur, payment, "paid")
        elif mapped_status == "failed" and payment["status"] not in {"failed", "paid"}:
            _sync_payment_and_order(cur, payment, "failed")

        conn.commit()
    finally:
        conn.close()

    return {"success": True}


@router.get("/status/{payment_id}", summary="Check Payment Status")
def check_payment_status(payment_id: str):
    """Публичная проверка статуса платежа по external_payment_id."""
    clean_payment_id = clean_text(payment_id, max_len=128)
    if not clean_payment_id:
        raise HTTPException(status_code=400, detail="Invalid payment id")

    settings = get_settings()
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        row = cur.execute(
            "SELECT * FROM payments WHERE external_payment_id = ? LIMIT 1",
            (clean_payment_id,),
        ).fetchone()
        if row:
            _refresh_payment_status(cur, settings, row)
            conn.commit()
            row = cur.execute(
                "SELECT * FROM payments WHERE external_payment_id = ? LIMIT 1",
                (clean_payment_id,),
            ).fetchone()
    finally:
        conn.close()

    if not row:
        raise HTTPException(status_code=404, detail="Payment not found")

    return {
        "success": True,
        "data": {
            "payment_id": clean_payment_id,
            "status": row["status"],
            "amount": float(row["amount"]),
            "confirmed_at": row["paid_at"],
        },
    }


@router.get("/status/link/{link_id}", summary="Check Payment Link Status")
def user_check_payment_link_status(link_id: int, user=Depends(get_current_user)):
    """Проверка статуса платежа владельцем по id записи payments."""
    settings = get_settings()
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        row = cur.execute(
            "SELECT * FROM payments WHERE id = ? LIMIT 1",
            (link_id,),
        ).fetchone()
        if row and int(row["user_id"]) == int(user["id"]):
            _refresh_payment_status(cur, settings, row)
            conn.commit()
            row = cur.execute(
                "SELECT * FROM payments WHERE id = ? LIMIT 1",
                (link_id,),
            ).fetchone()
    finally:
        conn.close()

    if not row:
        raise HTTPException(status_code=404, detail="Payment link not found")
    if int(row["user_id"]) != int(user["id"]):
        raise HTTPException(status_code=403, detail="Access denied")

    return {"success": True, "data": _format_payment_row(row)}


@router.get("/orders", summary="Get User Orders")
def get_user_orders(
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    include_payment: bool = Query(default=False),
    user=Depends(get_current_user),
):
    """Краткий список заказов текущего пользователя по session token."""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        total_row = cur.execute(
            "SELECT COUNT(*) AS total FROM orders WHERE user_id = ?",
            (int(user["id"]),),
        ).fetchone()
        total_orders = int(total_row["total"]) if total_row else 0

        if total_orders == 0:
            return {
                "success": True,
                "data": {
                    "items": [],
                    "pagination": {
                        "limit": limit,
                        "offset": offset,
                        "count": 0,
                        "total": 0,
                    },
                },
            }

        rows = cur.execute(
            """
            SELECT
                o.*,
                COUNT(oi.id) AS items_count
            FROM orders o
            LEFT JOIN order_items oi ON oi.order_id = o.id
            WHERE o.user_id = ?
            GROUP BY o.id
            ORDER BY o.created_at DESC, o.id DESC
            LIMIT ? OFFSET ?
            """,
            (int(user["id"]), limit, offset),
        ).fetchall()

        orders = []
        for row in rows:
            order_data = _format_order_summary_row(row)
            if include_payment:
                payment = _get_latest_payment_for_order(cur, int(row["id"]))
                order_data["payment"] = _format_payment_row(payment) if payment else None
            else:
                order_data["payment"] = {
                    "status": row["payment_status"],
                    "amount": float(row["total_price"]),
                }
            orders.append(order_data)
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "items": orders,
            "pagination": {
                "limit": limit,
                "offset": offset,
                "count": len(orders),
                "total": total_orders,
            },
        },
    }


@router.get("/orders/{order_id}", summary="Get User Order Details")
def get_user_order_details(order_id: int, user=Depends(get_current_user)):
    """Детальная информация по заказу текущего пользователя."""
    settings = get_settings()
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        order = cur.execute(
            """
            SELECT *
            FROM orders
            WHERE id = ? AND user_id = ?
            LIMIT 1
            """,
            (order_id, int(user["id"])),
        ).fetchone()
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")

        payment = _get_latest_payment_for_order(cur, order_id)
        if payment:
            _refresh_payment_status(cur, settings, payment)
            payment = _get_latest_payment_for_order(cur, order_id)

        payload = _format_order_detail(cur, order, payment)
        conn.commit()
    finally:
        conn.close()

    return {"success": True, "data": payload}


@router.put("/orders/{order_id}/address", summary="Update User Order Address")
def update_user_order_address(
    order_id: int,
    payload: UpdateOrderAddressRequest,
    user=Depends(get_current_user),
):
    """Обновляет адрес доставки для заказа текущего пользователя."""
    address = clean_text(payload.address, max_len=500)
    if len(address) < 5:
        raise HTTPException(status_code=400, detail="Address must be between 5 and 500 characters")

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        order = cur.execute(
            """
            SELECT *
            FROM orders
            WHERE id = ? AND user_id = ?
            LIMIT 1
            """,
            (order_id, int(user["id"])),
        ).fetchone()
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")

        if order["order_type"] != "delivery":
            raise HTTPException(status_code=400, detail="Address is available only for delivery orders")

        if order["status"] in {"cancelled", "completed", "delivered"}:
            raise HTTPException(status_code=400, detail="Order address can no longer be updated")

        cur.execute(
            """
            UPDATE orders
            SET address_snapshot = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """,
            (address, order_id),
        )
        conn.commit()
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "order_id": order_id,
            "address": address,
        },
    }


@router.get("/status/order/{order_id}", summary="Check Order Payment Status")
def user_check_order_status(order_id: int, user=Depends(get_current_user)):
    """Возвращает статус заказа и связанного с ним платежа."""
    settings = get_settings()
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        order = cur.execute(
            "SELECT * FROM orders WHERE id = ? LIMIT 1",
            (order_id,),
        ).fetchone()
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")
        if int(order["user_id"]) != int(user["id"]):
            raise HTTPException(status_code=403, detail="Access denied")

        payment = cur.execute(
            "SELECT * FROM payments WHERE order_id = ? ORDER BY id DESC LIMIT 1",
            (order_id,),
        ).fetchone()
        if payment:
            _refresh_payment_status(cur, settings, payment)
            conn.commit()
            payment = cur.execute(
                "SELECT * FROM payments WHERE order_id = ? ORDER BY id DESC LIMIT 1",
                (order_id,),
            ).fetchone()
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "order_id": order["id"],
            "order_number": order["order_number"],
            "order_status": order["status"],
            "payment_status": order["payment_status"],
            "total_price": float(order["total_price"]),
            "payment_link": _format_payment_row(payment) if payment else None,
        },
    }
