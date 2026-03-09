from __future__ import annotations

import uuid
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
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


def _generate_order_number(cur) -> str:
    for _ in range(10):
        candidate = f"ORD-{datetime.utcnow().strftime('%Y%m%d')}-{uuid.uuid4().hex[:6].upper()}"
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

        # Удаляем оплаченные товары из корзины и резервируем остатки.
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


@router.post("/generate-link", status_code=status.HTTP_201_CREATED, summary="Generate Payment Link")
def generate_payment_link(payload: GeneratePaymentLinkRequest, user=Depends(get_current_user)):
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

        external_payment_id = f"pay_{uuid.uuid4().hex}"
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

        conn.commit()
    finally:
        conn.close()

    payment_url = f"{settings.API_BASE_URL}/payments/status/{external_payment_id}"

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


@router.get("/link/{link_id}", summary="Get Payment Link")
def get_payment_link(link_id: int, user=Depends(get_current_user)):
    """Возвращает информацию о платеже по его внутреннему идентификатору."""
    conn = get_db_connection()
    try:
        row = conn.execute(
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

    conn = get_db_connection()
    try:
        row = conn.execute(
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
    conn = get_db_connection()
    try:
        row = conn.execute(
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


@router.get("/status/order/{order_id}", summary="Check Order Payment Status")
def user_check_order_status(order_id: int, user=Depends(get_current_user)):
    """Возвращает статус заказа и связанного с ним платежа."""
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
