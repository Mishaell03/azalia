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
from app.routes.utils import clean_text, get_current_user, require_admin

router = APIRouter(prefix="/api/payments", tags=["payments"])


class GeneratePaymentLinkRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    address: Optional[str] = Field(default=None, max_length=500)
    payment_method: str = Field(default="card", max_length=32)
    payment_timing: str = Field(default="online", max_length=24)
    on_delivery_method: Optional[str] = Field(default=None, max_length=32)
    selected_item_ids: list[int] = Field(default_factory=list, max_length=200)
    accept_quantity_changes: bool = False
    order_type: str = Field(default="delivery", max_length=16)
    store_id: Optional[int] = Field(default=None, ge=1)
    comment: Optional[str] = Field(default=None, max_length=500)


class PaymentCallbackRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    object: dict


class UpdateOrderAddressRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    address: str = Field(min_length=5, max_length=500)


class CheckOrderAvailabilityRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    selected_item_ids: list[int] = Field(default_factory=list, max_length=200)
    order_type: str = Field(default="delivery", max_length=16)
    store_id: Optional[int] = Field(default=None, ge=1)


class AdminUpdateOrderStatusRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    status: str = Field(min_length=2, max_length=32)


class AdminOrderRefundRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    reason: Optional[str] = Field(default=None, max_length=500)


ADMIN_ORDER_STATUSES: set[str] = {
    "new",
    "awaiting_payment",
    "processing",
    "assembled",
    "shipped",
    "ready_for_pickup",
    "delivered",
    "completed",
    "cancelled",
}

ORDER_STATUS_RU: dict[str, str] = {
    "new": "Новый",
    "awaiting_payment": "Ожидает оплату",
    "processing": "В обработке",
    "assembled": "Собирается",
    "shipped": "В доставке",
    "ready_for_pickup": "Готов к выдаче",
    "delivered": "Доставлен",
    "completed": "Закрыт",
    "cancelled": "Отменен",
}

ORDER_STATUS_INPUT_ALIASES: dict[str, str] = {
    # Русские названия из UI
    "новый": "new",
    "ожидает оплату": "awaiting_payment",
    "в обработке": "processing",
    "Собирается": "assembled",
    "в доставке": "shipped",
    "готов к выдаче": "ready_for_pickup",
    "доставлен": "delivered",
    "закрыт": "completed",
    "отменен": "cancelled",
    "отменён": "cancelled",
}

PAYMENT_STATUS_RU: dict[str, str] = {
    "pending": "Ожидает оплату",
    "authorized": "Авторизован",
    "paid": "Оплачен",
    "failed": "Ошибка оплаты",
    "refunded": "Средства возвращены",
    "partially_refunded": "Частичный возврат",
}

MAX_ORDER_STATUS_REFRESH_PER_REQUEST = 3

ORDER_TYPE_LABELS: dict[str, str] = {
    "delivery": "С доставкой",
    "pickup": "Без доставки",
}


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


def _resolve_active_store(cur, store_id: int):
    row = cur.execute(
        """
        SELECT id, name, address, store_type
        FROM stores
        WHERE id = ? AND is_active = 1
        LIMIT 1
        """,
        (store_id,),
    ).fetchone()
    if not row:
        raise HTTPException(status_code=400, detail="Store not found or inactive")
    return row


def _resolve_default_delivery_store(cur):
    row = cur.execute(
        """
        SELECT id, name, address, store_type
        FROM stores
        WHERE is_active = 1
        ORDER BY id ASC
        LIMIT 1
        """
    ).fetchone()
    if not row:
        raise HTTPException(status_code=400, detail="No active stores available")
    return row


def _order_status_to_ru(status_value: Optional[str]) -> str:
    code = clean_text(status_value, max_len=32).lower()
    return ORDER_STATUS_RU.get(code, code or "-")


def _payment_status_to_ru(status_value: Optional[str]) -> str:
    code = clean_text(status_value, max_len=32).lower()
    return PAYMENT_STATUS_RU.get(code, code or "-")


def _order_type_to_label(order_type: Optional[str]) -> str:
    code = clean_text(order_type, max_len=16).lower()
    return ORDER_TYPE_LABELS.get(code, code or "-")


def _allowed_admin_statuses_for_order_type(order_type: Optional[str]) -> tuple[str, ...]:
    code = clean_text(order_type, max_len=16).lower()
    if code == "pickup":
        return ("assembled", "ready_for_pickup", "completed", "cancelled")
    return ("assembled", "shipped", "delivered", "completed", "cancelled")


def _enqueue_order_status_notification(
    cur,
    *,
    order_id: int,
    old_status: Optional[str],
    new_status: str,
) -> None:
    old_code = clean_text(old_status, max_len=32).lower()
    new_code = clean_text(new_status, max_len=32).lower()
    if not new_code or old_code == new_code:
        return

    order_row = cur.execute(
        """
        SELECT id, user_id, order_number
        FROM orders
        WHERE id = ?
        LIMIT 1
        """,
        (order_id,),
    ).fetchone()
    if not order_row:
        return

    title = "Статус заказа обновлен"
    body = (
        f"Заказ №{order_row['order_number']}: "
        f"{_order_status_to_ru(old_code) if old_code else 'Создан'} -> {_order_status_to_ru(new_code)}"
    )
    cur.execute(
        """
        INSERT INTO notifications (
            user_id,
            template_id,
            title,
            body,
            status,
            related_order_id
        )
        VALUES (?, NULL, ?, ?, 'pending', ?)
        """,
        (
            int(order_row["user_id"]),
            title,
            body,
            int(order_id),
        ),
    )


def _admin_status_options_for_order_type(order_type: Optional[str]) -> list[dict[str, str]]:
    return [
        {"code": status_code, "label": _order_status_to_ru(status_code)}
        for status_code in _allowed_admin_statuses_for_order_type(order_type)
    ]


def _payment_mode_from_external_id(external_payment_id: Optional[str]) -> str:
    resolved = clean_text(external_payment_id, max_len=128).lower()
    if resolved.startswith("on_delivery_"):
        return "on_delivery"
    return "online"


def _should_refresh_payment_detail(order_row, payment_row) -> bool:
    if not payment_row:
        return False
    if _payment_mode_from_external_id(payment_row["external_payment_id"]) != "online":
        return False
    order_status = clean_text(order_row["status"], max_len=32).lower()
    payment_status = clean_text(payment_row["status"], max_len=32).lower()
    if order_status in {"completed", "cancelled"}:
        return False
    return payment_status in {"pending", "authorized"}


def _reserve_inventory_for_order(
    cur,
    *,
    order_id: int,
    order_type: str,
    store_id: int,
    items: list[dict],
) -> None:
    for validated in items:
        item = validated["item"]
        qty_left = int(validated["checkout_quantity"])
        if qty_left <= 0:
            continue
        product_id = int(item["product_id"])

        if order_type == "pickup":
            row = cur.execute(
                """
                SELECT id, quantity_available
                FROM inventory
                WHERE store_id = ? AND product_id = ?
                LIMIT 1
                """,
                (store_id, product_id),
            ).fetchone()
            available = int(row["quantity_available"] or 0) if row else 0
            if not row or available < qty_left:
                raise HTTPException(
                    status_code=409,
                    detail=f'Недостаточно "{item["product_name"]}" для самовывоза. Доступно: {available}',
                )

            cur.execute(
                "UPDATE inventory SET quantity_reserved = quantity_reserved + ? WHERE id = ?",
                (qty_left, int(row["id"])),
            )
            cur.execute(
                """
                INSERT INTO inventory_movements (
                    store_id, product_id, movement_type, quantity, related_order_id, comment
                )
                VALUES (?, ?, 'reservation', ?, ?, ?)
                """,
                (store_id, product_id, qty_left, order_id, "Order placed, awaiting payment"),
            )
            continue

        rows = cur.execute(
            """
            SELECT id, store_id, quantity_available
            FROM inventory
            WHERE product_id = ? AND quantity_available > 0
            ORDER BY quantity_available DESC, id ASC
            """,
            (product_id,),
        ).fetchall()

        for row in rows:
            available = int(row["quantity_available"] or 0)
            if available <= 0:
                continue
            allocated = min(qty_left, available)
            if allocated <= 0:
                continue

            cur.execute(
                "UPDATE inventory SET quantity_reserved = quantity_reserved + ? WHERE id = ?",
                (allocated, int(row["id"])),
            )
            cur.execute(
                """
                INSERT INTO inventory_movements (
                    store_id, product_id, movement_type, quantity, related_order_id, comment
                )
                VALUES (?, ?, 'reservation', ?, ?, ?)
                """,
                (int(row["store_id"]), product_id, allocated, order_id, "Order placed, awaiting payment"),
            )
            qty_left -= allocated
            if qty_left <= 0:
                break

        if qty_left > 0:
            raise HTTPException(
                status_code=409,
                detail=f'Недостаточно "{item["product_name"]}" в наличии для оформления заказа',
            )


def _get_order_reservation_balances(cur, order_id: int):
    rows = cur.execute(
        """
        SELECT
            store_id,
            product_id,
            SUM(CASE WHEN movement_type = 'reservation' THEN quantity ELSE 0 END) AS reserved_qty,
            SUM(CASE WHEN movement_type = 'reservation_release' THEN quantity ELSE 0 END) AS released_qty,
            SUM(CASE WHEN movement_type = 'sale' THEN quantity ELSE 0 END) AS sold_qty
        FROM inventory_movements
        WHERE related_order_id = ?
          AND movement_type IN ('reservation', 'reservation_release', 'sale')
        GROUP BY store_id, product_id
        """,
        (order_id,),
    ).fetchall()
    return rows


def _release_reserved_inventory_for_order(cur, order_id: int, *, reason: str) -> None:
    balances = _get_order_reservation_balances(cur, order_id)
    for row in balances:
        reserved_qty = int(row["reserved_qty"] or 0)
        released_qty = int(row["released_qty"] or 0)
        sold_qty = int(row["sold_qty"] or 0)
        qty_to_release = reserved_qty - released_qty - sold_qty
        if qty_to_release <= 0:
            continue

        cur.execute(
            """
            UPDATE inventory
            SET quantity_reserved = CASE
                WHEN quantity_reserved >= ? THEN quantity_reserved - ?
                ELSE 0
            END
            WHERE store_id = ? AND product_id = ?
            """,
            (qty_to_release, qty_to_release, int(row["store_id"]), int(row["product_id"])),
        )
        cur.execute(
            """
            INSERT INTO inventory_movements (
                store_id, product_id, movement_type, quantity, related_order_id, comment
            )
            VALUES (?, ?, 'reservation_release', ?, ?, ?)
            """,
            (int(row["store_id"]), int(row["product_id"]), qty_to_release, order_id, reason),
        )


def _consume_reserved_inventory_for_order(cur, order_id: int, *, reason: str) -> None:
    balances = _get_order_reservation_balances(cur, order_id)
    for row in balances:
        reserved_qty = int(row["reserved_qty"] or 0)
        released_qty = int(row["released_qty"] or 0)
        sold_qty = int(row["sold_qty"] or 0)
        qty_to_sell = reserved_qty - released_qty - sold_qty
        if qty_to_sell <= 0:
            continue

        cur.execute(
            """
            UPDATE inventory
            SET quantity_on_hand = CASE
                    WHEN quantity_on_hand >= ? THEN quantity_on_hand - ?
                    ELSE 0
                END,
                quantity_reserved = CASE
                    WHEN quantity_reserved >= ? THEN quantity_reserved - ?
                    ELSE 0
                END
            WHERE store_id = ? AND product_id = ?
            """,
            (
                qty_to_sell,
                qty_to_sell,
                qty_to_sell,
                qty_to_sell,
                int(row["store_id"]),
                int(row["product_id"]),
            ),
        )
        cur.execute(
            """
            INSERT INTO inventory_movements (
                store_id, product_id, movement_type, quantity, related_order_id, comment
            )
            VALUES (?, ?, 'sale', ?, ?, ?)
            """,
            (int(row["store_id"]), int(row["product_id"]), qty_to_sell, order_id, reason),
        )


def _should_refresh_payment_in_orders_list(order_row, payment_row) -> bool:
    if not payment_row:
        return False

    order_status = clean_text(order_row["status"], max_len=32).lower()
    payment_status = clean_text(payment_row["status"], max_len=32).lower()
    payment_mode = _payment_mode_from_external_id(payment_row["external_payment_id"])

    if payment_mode != "online":
        return False
    if order_status in {"completed", "cancelled"}:
        return False
    return payment_status in {"pending", "authorized"}


def _get_cart_items_for_checkout(
    cur,
    user_id: int,
    selected_item_ids: list[int],
    *,
    store_id: Optional[int] = None,
    limit_to_store: bool = False,
):
    inventory_join = "LEFT JOIN inventory i ON i.product_id = p.id"
    params: list[object] = []
    if limit_to_store:
        if store_id is None:
            raise HTTPException(status_code=400, detail="store_id is required for pickup availability check")
        inventory_join = "LEFT JOIN inventory i ON i.product_id = p.id AND i.store_id = ?"
        params.append(store_id)
    params.append(user_id)

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
    """
    sql += f"\n        {inventory_join}\n"
    sql += """
        WHERE ci.user_id = ?
    """

    if selected_item_ids:
        placeholders = ",".join(["?"] * len(selected_item_ids))
        sql += f" AND ci.id IN ({placeholders})"
        params.extend(selected_item_ids)

    sql += " GROUP BY ci.id ORDER BY ci.created_at ASC"

    rows = cur.execute(sql, tuple(params)).fetchall()
    return rows


def _validate_cart_items(cur, cart_items, *, clamp_to_available: bool = False):
    if not cart_items:
        raise HTTPException(status_code=400, detail="Корзина пуста")

    total_price = 0.0
    validated: list[dict] = []

    for item in cart_items:
        if not bool(item["is_active"]) or item["deleted_at"] is not None:
            raise HTTPException(
                status_code=400,
                detail=f'Товар "{item["product_name"]}" больше не доступен',
            )

        available_qty = int(item["available_qty"])
        requested_qty = int(item["quantity"])
        checkout_qty = requested_qty
        if requested_qty > available_qty:
            if clamp_to_available:
                if available_qty <= 0:
                    raise HTTPException(
                        status_code=400,
                        detail=f'Товар "{item["product_name"]}" отсутствует на выбранной точке',
                    )
                checkout_qty = available_qty
            else:
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

        item_total = (current_product_price + current_pot_price) * checkout_qty
        total_price += item_total
        validated.append(
            {
                "item": item,
                "requested_quantity": requested_qty,
                "checkout_quantity": checkout_qty,
                "item_total": round(item_total, 2),
            }
        )

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
        "status": _payment_status_to_ru(row["status"]),
        "status_code": row["status"],
        "payment_mode": _payment_mode_from_external_id(row["external_payment_id"]),
        "payment_method_id": row["payment_method_id"],
        "external_payment_id": row["external_payment_id"],
        "created_at": row["created_at"],
        "paid_at": row["paid_at"],
        "failed_at": row["failed_at"],
        "expires_at": datetime.utcfromtimestamp(expires_at).strftime("%Y-%m-%d %H:%M:%S"),
    }


def _format_order_summary_row(row):
    resolved_address = _resolve_order_address(row)
    order_type = row["order_type"]
    return {
        "order_id": int(row["id"]),
        "order_number": row["order_number"],
        "status": _order_status_to_ru(row["status"]),
        "status_code": row["status"],
        "payment_status": _payment_status_to_ru(row["payment_status"]),
        "payment_status_code": row["payment_status"],
        "order_type": order_type,
        "order_type_label": _order_type_to_label(order_type),
        "available_statuses": _admin_status_options_for_order_type(order_type),
        "address": resolved_address,
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
            "old_status": _order_status_to_ru(row["old_status"]),
            "old_status_code": row["old_status"],
            "new_status": _order_status_to_ru(row["new_status"]),
            "new_status_code": row["new_status"],
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
        if payment_data["payment_mode"] == "on_delivery":
            method_code = clean_text(payment_row["payment_method_code"], max_len=32).lower()
            payment_data["on_delivery_method"] = method_code if method_code in {"cash", "card"} else None
        refunds = _get_order_refunds(cur, int(payment_row["id"]))

    items = _get_order_items_details(cur, int(order_row["id"]))
    history = _get_order_status_history(cur, int(order_row["id"]))
    resolved_address = _resolve_order_address(order_row)

    return {
        "order_id": int(order_row["id"]),
        "order_number": order_row["order_number"],
        "status": _order_status_to_ru(order_row["status"]),
        "status_code": order_row["status"],
        "payment_status": _payment_status_to_ru(order_row["payment_status"]),
        "payment_status_code": order_row["payment_status"],
        "order_type": order_row["order_type"],
        "order_type_label": _order_type_to_label(order_row["order_type"]),
        "available_statuses": _admin_status_options_for_order_type(order_row["order_type"]),
        "store_id": int(order_row["store_id"]),
        "address": resolved_address,
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


def _resolve_order_address(order_row) -> Optional[str]:
    keys = set(order_row.keys())
    order_type = clean_text(order_row["order_type"], max_len=16).lower() if "order_type" in keys else ""
    snapshot = clean_text(order_row["address_snapshot"], max_len=500) if "address_snapshot" in keys else ""
    store_address = clean_text(order_row["store_address"], max_len=500) if "store_address" in keys else ""

    if order_type == "pickup":
        return store_address or snapshot or None
    return snapshot or None


def _resolve_active_employee_id(cur, user_id: int) -> int:
    row = cur.execute(
        """
        SELECT id
        FROM employees
        WHERE user_id = ?
          AND is_active = 1
        LIMIT 1
        """,
        (user_id,),
    ).fetchone()
    if not row:
        raise HTTPException(status_code=403, detail="Active employee access required")
    return int(row["id"])


def _require_admin_employee(cur, user) -> int:
    require_admin(user)
    return _resolve_active_employee_id(cur, int(user["id"]))


def _validate_admin_order_status(status_value: str) -> str:
    raw = clean_text(status_value, max_len=64).lower()
    normalized = raw.replace("-", "_")
    compact = normalized.replace("  ", " ").strip()

    # 1) Предпочитаем чистые кодовые значения API.
    if normalized in ADMIN_ORDER_STATUSES:
        return normalized

    # 2) Принимаем русские метки статусов из интерфейса.
    if compact in ORDER_STATUS_INPUT_ALIASES:
        return ORDER_STATUS_INPUT_ALIASES[compact]

    # 3) Поддержка вариантов с пробелами вместо "_" (ready for pickup).
    code_like = compact.replace(" ", "_")
    if code_like in ADMIN_ORDER_STATUSES:
        return code_like

    raise HTTPException(
        status_code=400,
        detail=(
            "Invalid order status. Use status_code (new, awaiting_payment, processing, assembled, "
            "shipped, ready_for_pickup, delivered, completed, cancelled). Allowed: "
            + ", ".join(sorted(ADMIN_ORDER_STATUSES))
        ),
    )


def _update_order_status(
    cur,
    *,
    order_id: int,
    new_status: str,
    employee_id: int,
):
    order = cur.execute(
        """
        SELECT id, status, payment_status
        FROM orders
        WHERE id = ?
        LIMIT 1
        """,
        (order_id,),
    ).fetchone()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    current_status = clean_text(order["status"], max_len=32).lower()
    resolved_new = _validate_admin_order_status(new_status)

    if current_status in {"completed", "cancelled"} and resolved_new != current_status:
        raise HTTPException(
            status_code=400,
            detail=f"Order is already {current_status} and cannot be changed",
        )

    payment_status = clean_text(order["payment_status"], max_len=32).lower()
    if resolved_new == "completed" and payment_status != "paid":
        raise HTTPException(
            status_code=400,
            detail="Cannot complete order before payment is completed",
        )

    if resolved_new != current_status:
        cur.execute(
            """
            UPDATE orders
            SET status = ?,
                assigned_employee_id = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """,
            (resolved_new, employee_id, order_id),
        )
        _enqueue_order_status_notification(
            cur,
            order_id=int(order_id),
            old_status=current_status,
            new_status=resolved_new,
        )
    else:
        cur.execute(
            """
            UPDATE orders
            SET assigned_employee_id = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """,
            (employee_id, order_id),
        )

    if resolved_new == "cancelled" and payment_status != "paid":
        _release_reserved_inventory_for_order(
            cur,
            int(order_id),
            reason="Order cancelled by admin, reservation released",
        )


def _sync_payment_and_order(cur, payment_row, new_status: str):
    payment_id = payment_row["id"]
    order_id = payment_row["order_id"]
    before_row = cur.execute(
        """
        SELECT status
        FROM orders
        WHERE id = ?
        LIMIT 1
        """,
        (order_id,),
    ).fetchone()
    old_order_status = clean_text(
        before_row["status"] if before_row else None,
        max_len=32,
    ).lower()

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
        after_row = cur.execute(
            """
            SELECT status
            FROM orders
            WHERE id = ?
            LIMIT 1
            """,
            (order_id,),
        ).fetchone()
        new_order_status = clean_text(
            after_row["status"] if after_row else None,
            max_len=32,
        ).lower()
        _enqueue_order_status_notification(
            cur,
            order_id=int(order_id),
            old_status=old_order_status,
            new_status=new_order_status,
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

        _consume_reserved_inventory_for_order(
            cur,
            int(order_id),
            reason="Order paid, inventory sold",
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
        after_row = cur.execute(
            """
            SELECT status
            FROM orders
            WHERE id = ?
            LIMIT 1
            """,
            (order_id,),
        ).fetchone()
        new_order_status = clean_text(
            after_row["status"] if after_row else None,
            max_len=32,
        ).lower()
        _enqueue_order_status_notification(
            cur,
            order_id=int(order_id),
            old_status=old_order_status,
            new_status=new_order_status,
        )
        _release_reserved_inventory_for_order(
            cur,
            int(order_id),
            reason="Payment failed/cancelled, reservation released",
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
    if remote_status == "paid":
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
        "save_payment_method": False,
        "confirmation": {
            "type": "redirect",
            "return_url": return_url,
        },
        "description": f"Оплата заказа {order_number}",
        "metadata": metadata,
    }

    # Не форсим bank_card: тогда YooKassa открывает универсальную страницу оплаты.
    # Для СБП оставляем явный тип, чтобы сразу вести в СБП-сценарий.
    if payment_method_code == "sbp":
        payload["payment_method_data"] = {"type": "sbp"}

    return _yookassa_request(settings, "POST", "/payments", payload)


def _fetch_yookassa_payment(settings, external_payment_id: str) -> dict:
    return _yookassa_request(settings, "GET", f"/payments/{external_payment_id}")


def _create_yookassa_refund(
    settings,
    *,
    external_payment_id: str,
    amount: float,
    reason: Optional[str] = None,
    metadata: Optional[dict[str, str]] = None,
) -> dict:
    payload: dict[str, object] = {
        "payment_id": external_payment_id,
        "amount": {
            "value": f"{amount:.2f}",
            "currency": "RUB",
        },
    }
    clean_reason = clean_text(reason, max_len=255)
    if clean_reason:
        payload["description"] = clean_reason
    if metadata:
        payload["metadata"] = metadata
    return _yookassa_request(settings, "POST", "/refunds", payload)


def _create_refund_record_and_apply(
    cur,
    *,
    payment_id: int,
    amount: float,
    reason: str,
    employee_id: Optional[int],
    processed: bool,
):
    refund_status = "processed" if processed else "pending"
    cur.execute(
        """
        INSERT INTO refunds (
            payment_id, amount, reason, status, processed_by_employee_id, processed_at
        )
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        (
            payment_id,
            amount,
            clean_text(reason, max_len=500),
            refund_status,
            employee_id,
            datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S") if processed else None,
        ),
    )
    refund_id = int(cur.lastrowid)
    if processed:
        cur.execute(
            """
            UPDATE payments
            SET status = 'refunded',
                failed_at = NULL
            WHERE id = ?
            """,
            (payment_id,),
        )
        cur.execute(
            """
            UPDATE orders
            SET payment_status = 'refunded',
                updated_at = CURRENT_TIMESTAMP
            WHERE id = (
                SELECT order_id
                FROM payments
                WHERE id = ?
                LIMIT 1
            )
            """,
            (payment_id,),
        )
    return refund_id, refund_status


def _refund_payment(
    cur,
    settings,
    *,
    order_id: int,
    payment_row,
    employee_id: Optional[int],
    reason: str,
):
    existing_refund = cur.execute(
        """
        SELECT id, status
        FROM refunds
        WHERE payment_id = ?
          AND status IN ('pending', 'processed')
        ORDER BY id DESC
        LIMIT 1
        """,
        (int(payment_row["id"]),),
    ).fetchone()
    if existing_refund:
        raise HTTPException(status_code=400, detail="Refund can be performed only once for this payment")

    payment_status = clean_text(payment_row["status"], max_len=32).lower()
    if payment_status == "refunded":
        return {"already_refunded": True}
    if payment_status != "paid":
        raise HTTPException(status_code=400, detail="Only paid orders can be refunded")

    amount = float(payment_row["amount"])
    payment_mode = _payment_mode_from_external_id(payment_row["external_payment_id"])
    if payment_mode == "online":
        if not _yookassa_enabled(settings):
            raise HTTPException(status_code=500, detail="YooKassa is not configured")
        refund = _create_yookassa_refund(
            settings,
            external_payment_id=str(payment_row["external_payment_id"]),
            amount=amount,
            reason=reason,
            metadata={
                "order_id": str(order_id),
                "payment_id": str(payment_row["id"]),
            },
        )
        remote_status = clean_text(refund.get("status"), max_len=32).lower()
        # В YooKassa refund может вернуться "pending", но запрос уже принят.
        # Фиксируем его как выполненный в нашей системе, чтобы статус средств был отражен сразу.
        if remote_status in {"canceled", "cancelled", "failed"}:
            raise HTTPException(status_code=502, detail="Refund request was rejected by payment provider")
        processed = remote_status in {"succeeded", "pending"}
        refund_id, refund_status = _create_refund_record_and_apply(
            cur,
            payment_id=int(payment_row["id"]),
            amount=amount,
            reason=reason,
            employee_id=employee_id,
            processed=processed,
        )
        return {
            "already_refunded": False,
            "refund_id": refund_id,
            "refund_status": refund_status,
            "external_refund_id": refund.get("id"),
        }

    refund_id, refund_status = _create_refund_record_and_apply(
        cur,
        payment_id=int(payment_row["id"]),
        amount=amount,
        reason=reason,
        employee_id=employee_id,
        processed=True,
    )
    return {
        "already_refunded": False,
        "refund_id": refund_id,
        "refund_status": refund_status,
        "external_refund_id": None,
    }


def _refresh_payment_status(cur, settings, payment_row) -> str:
    local_status = clean_text(payment_row["status"], max_len=64).lower()
    # Уже возвращенный платеж не должен синхронизироваться обратно в paid.
    if local_status in {"refunded", "partially_refunded"}:
        return local_status

    external_payment_id = payment_row["external_payment_id"]
    if not _yookassa_enabled(settings) or not external_payment_id:
        return payment_row["status"]

    try:
        remote_payment = _fetch_yookassa_payment(settings, str(external_payment_id))
    except HTTPException:
        return payment_row["status"]

    remote_status = clean_text(remote_payment.get("status"), max_len=64).lower()
    remote_paid = bool(remote_payment.get("paid"))

    if remote_paid or remote_status in {"succeeded", "paid"}:
        mapped_status = "paid"
    elif remote_status in {"canceled", "cancelled"}:
        mapped_status = "failed"
    else:
        mapped_status = _map_yookassa_status(remote_status)

    if mapped_status == "paid" and payment_row["status"] != "paid":
        _sync_payment_and_order(cur, payment_row, "paid")
    elif mapped_status == "failed" and payment_row["status"] not in {"failed", "paid"}:
        _sync_payment_and_order(cur, payment_row, "failed")

    return mapped_status


@router.get("/stores", summary="Get Active Stores for Delivery/Pickup")
def get_active_stores(user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        rows = cur.execute(
            """
            SELECT id, name, address, store_type
            FROM stores
            WHERE is_active = 1
            ORDER BY name ASC, id ASC
            """
        ).fetchall()
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "items": [
                {
                    "id": int(row["id"]),
                    "name": row["name"],
                    "address": row["address"],
                    "store_type": row["store_type"],
                }
                for row in rows
            ]
        },
    }


@router.post("/availability", summary="Check Cart Availability for Delivery/Pickup")
def check_order_availability(
    payload: CheckOrderAvailabilityRequest,
    user=Depends(get_current_user),
):
    order_type = clean_text(payload.order_type, max_len=16).lower()
    if order_type not in {"delivery", "pickup"}:
        raise HTTPException(status_code=400, detail="Invalid order_type")

    selected_ids = sorted(set(payload.selected_item_ids))

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        store_id: Optional[int] = None
        limit_to_store = False
        if order_type == "pickup":
            if payload.store_id is None:
                raise HTTPException(status_code=400, detail="store_id is required for pickup")
            store = _resolve_active_store(cur, int(payload.store_id))
            store_id = int(store["id"])
            limit_to_store = True

        cart_items = _get_cart_items_for_checkout(
            cur,
            int(user["id"]),
            selected_ids,
            store_id=store_id,
            limit_to_store=limit_to_store,
        )
    finally:
        conn.close()

    if not cart_items:
        return {
            "success": True,
            "data": {
                "all_available": False,
                "can_proceed": False,
                "available_item_ids": [],
                "missing_items": [],
            },
        }

    missing_items: list[dict] = []
    available_item_ids: list[int] = []
    items: list[dict] = []
    quantity_changes: list[dict] = []
    for item in cart_items:
        requested = int(item["quantity"])
        available = int(item["available_qty"] or 0)
        missing = max(0, requested - available)
        cart_item_id = int(item["id"])

        if available > 0:
            available_item_ids.append(cart_item_id)

        items.append(
            {
                "cart_item_id": cart_item_id,
                "product_id": int(item["product_id"]),
                "name": item["product_name"],
                "requested_quantity": requested,
                "available_quantity": available,
                "missing_quantity": missing,
                "will_reduce_quantity": missing > 0 and available > 0,
                "can_order": available > 0,
            }
        )

        if missing > 0:
            missing_items.append(
                {
                    "cart_item_id": cart_item_id,
                    "product_id": int(item["product_id"]),
                    "name": item["product_name"],
                    "requested_quantity": requested,
                    "available_quantity": available,
                    "missing_quantity": missing,
                }
            )
            quantity_changes.append(
                {
                    "cart_item_id": cart_item_id,
                    "product_id": int(item["product_id"]),
                    "name": item["product_name"],
                    "requested_quantity": requested,
                    "final_quantity": max(0, available),
                    "available_quantity": available,
                    "missing_quantity": missing,
                    "removed_from_order": available <= 0,
                }
            )

    return {
        "success": True,
        "data": {
            "order_type": order_type,
            "store_id": store_id,
            "all_available": len(missing_items) == 0,
            "can_proceed": len(available_item_ids) > 0,
            "available_item_ids": available_item_ids,
            "missing_items": missing_items,
            "quantity_changes": quantity_changes,
            "items": items,
        },
    }


@router.post("/generate-link", status_code=status.HTTP_201_CREATED, summary="Generate Payment Link")
def generate_payment_link(
    payload: GeneratePaymentLinkRequest,
    request: Request,
    user=Depends(get_current_user),
):
    """Создает заказ и платеж, возвращает ссылку/идентификатор для оплаты."""
    settings = get_settings()

    payment_timing = clean_text(payload.payment_timing, max_len=24).lower()
    if payment_timing not in {"online", "on_delivery"}:
        raise HTTPException(status_code=400, detail="Invalid payment_timing")

    payment_method_code = clean_text(payload.payment_method, max_len=32).lower()
    on_delivery_method = clean_text(payload.on_delivery_method, max_len=32).lower()
    if payment_timing == "on_delivery":
        method = on_delivery_method or payment_method_code
        if method not in {"cash", "card"}:
            raise HTTPException(status_code=400, detail="on_delivery_method must be cash or card")
        payment_method_code = method
    elif payment_method_code not in {"card", "sbp", "online"}:
        raise HTTPException(status_code=400, detail="payment_method must be card, sbp or online")
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

        if order_type == "pickup":
            if payload.store_id is None:
                raise HTTPException(status_code=400, detail="store_id is required for pickup")
            store = _resolve_active_store(cur, int(payload.store_id))
        else:
            # Для доставки не привязываем заказ к store_id из запроса:
            # наличие и резерв проверяются по всем магазинам.
            store = _resolve_default_delivery_store(cur)
        store_id = int(store["id"])

        payment_method_id = _resolve_payment_method(cur, payment_method_code)

        cart_items = _get_cart_items_for_checkout(
            cur,
            int(user["id"]),
            selected_ids,
            store_id=store_id,
            limit_to_store=(order_type == "pickup"),
        )
        total_price, validated_items = _validate_cart_items(
            cur,
            cart_items,
            clamp_to_available=(order_type == "pickup" or bool(payload.accept_quantity_changes)),
        )

        order_address_snapshot = address
        if order_type == "pickup":
            order_address_snapshot = clean_text(store["address"], max_len=500) or None

        order_number = _generate_order_number(cur)
        cur.execute(
            """
            INSERT INTO orders (
                user_id, company_id, store_id, order_number, order_type,
                address_id, address_snapshot, comment,
                subtotal, delivery_fee, discount_amount, total_price,
                payment_status, status, assigned_employee_id
            )
            VALUES (?, NULL, ?, ?, ?, NULL, ?, ?, ?, 0, 0, ?, 'pending', ?, NULL)
            """,
            (
                user["id"],
                store_id,
                order_number,
                order_type,
                order_address_snapshot,
                comment,
                total_price,
                total_price,
                "new" if payment_timing == "on_delivery" else "awaiting_payment",
            ),
        )
        order_id = cur.lastrowid

        items_for_response = []
        quantity_changes = []
        for validated in validated_items:
            item = validated["item"]
            item_total = float(validated["item_total"])
            checkout_quantity = int(validated["checkout_quantity"])
            requested_quantity = int(validated["requested_quantity"])
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
                    checkout_quantity,
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
                    "quantity": checkout_quantity,
                    "requested_quantity": requested_quantity,
                    "plant_price": float(item["product_unit_price"]),
                    "pot_price": float(item["pot_unit_price"]),
                    "item_total": float(item_total),
                    "quantity_reduced": checkout_quantity < requested_quantity,
                }
            )
            if checkout_quantity < requested_quantity:
                quantity_changes.append(
                    {
                        "cart_item_id": int(item["id"]),
                        "product_id": int(item["product_id"]),
                        "name": item["product_name"],
                        "requested_quantity": requested_quantity,
                        "final_quantity": checkout_quantity,
                        "removed_from_order": checkout_quantity <= 0,
                    }
                )

        _reserve_inventory_for_order(
            cur,
            order_id=int(order_id),
            order_type=order_type,
            store_id=int(store_id),
            items=validated_items,
        )

        external_payment_id = (
            f"on_delivery_{payment_method_code}_{uuid.uuid4().hex}"
            if payment_timing == "on_delivery"
            else f"pending_{uuid.uuid4().hex}"
        )
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

        payment_url = ""
        if payment_timing == "online":
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
            "quantity_changes": quantity_changes,
            "address": order_address_snapshot,
            "payment_method": payment_method_code,
            "payment_timing": payment_timing,
            "on_delivery_method": payment_method_code if payment_timing == "on_delivery" else None,
            "message": (
                "Заказ оформлен. Оплата будет при получении."
                if payment_timing == "on_delivery"
                else "Оплатите заказ по ссылке выше. После успешной оплаты товары будут удалены из корзины."
            ),
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
    incoming_paid = bool(payment_data.get("paid"))

    if not external_payment_id or incoming_status not in {
        "succeeded",
        "paid",
        "waiting_for_capture",
        "canceled",
        "cancelled",
        "failed",
        "expired",
        "pending",
    }:
        raise HTTPException(status_code=400, detail="Invalid callback payload")

    mapped_status = "pending"
    if incoming_paid or incoming_status in {"succeeded", "paid"}:
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
def check_payment_status(payment_id: str, user=Depends(get_current_user)):
    """Проверка статуса платежа владельцем токена по external_payment_id."""
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
        if row and int(row["user_id"]) != int(user["id"]):
            raise HTTPException(status_code=403, detail="Access denied")
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
    settings = get_settings()
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
                s.address AS store_address,
                COUNT(oi.id) AS items_count
            FROM orders o
            LEFT JOIN order_items oi ON oi.order_id = o.id
            LEFT JOIN stores s ON s.id = o.store_id
            WHERE o.user_id = ?
            GROUP BY o.id
            ORDER BY o.created_at DESC, o.id DESC
            LIMIT ? OFFSET ?
            """,
            (int(user["id"]), limit, offset),
        ).fetchall()

        # Не блокируем историю массовыми внешними запросами.
        # Синхронизируем только несколько самых свежих "живых" online-платежей на первой странице.
        if offset == 0:
            refresh_count = 0
            for row in rows:
                if refresh_count >= MAX_ORDER_STATUS_REFRESH_PER_REQUEST:
                    break
                payment = _get_latest_payment_for_order(cur, int(row["id"]))
                if _should_refresh_payment_in_orders_list(row, payment):
                    _refresh_payment_status(cur, settings, payment)
                    refresh_count += 1

            if refresh_count > 0:
                conn.commit()
                # Перечитываем строки, чтобы отдать обновленные статусы.
                rows = cur.execute(
                    """
                    SELECT
                        o.*,
                        s.address AS store_address,
                        COUNT(oi.id) AS items_count
                    FROM orders o
                    LEFT JOIN order_items oi ON oi.order_id = o.id
                    LEFT JOIN stores s ON s.id = o.store_id
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
                    "status": _payment_status_to_ru(row["payment_status"]),
                    "status_code": row["payment_status"],
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
            SELECT
                o.*,
                s.address AS store_address
            FROM orders o
            LEFT JOIN stores s ON s.id = o.store_id
            WHERE o.id = ? AND o.user_id = ?
            LIMIT 1
            """,
            (order_id, int(user["id"])),
        ).fetchone()
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")

        payment = _get_latest_payment_for_order(cur, order_id)
        if _should_refresh_payment_detail(order, payment):
            _refresh_payment_status(cur, settings, payment)
            payment = _get_latest_payment_for_order(cur, order_id)

        payload = _format_order_detail(cur, order, payment)
        conn.commit()
    finally:
        conn.close()

    return {"success": True, "data": payload}


@router.post("/orders/{order_id}/cancel", summary="Cancel User Order")
def cancel_user_order(order_id: int, user=Depends(get_current_user)):
    """Отмена заказа пользователем из личного кабинета."""
    settings = get_settings()
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        order = cur.execute(
            """
            SELECT id, user_id, status, payment_status
            FROM orders
            WHERE id = ? AND user_id = ?
            LIMIT 1
            """,
            (order_id, int(user["id"])),
        ).fetchone()
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")

        current_status = clean_text(order["status"], max_len=32).lower()
        if current_status == "completed":
            raise HTTPException(status_code=400, detail=f"Order cannot be cancelled in status: {current_status}")
        if current_status == "cancelled":
            return {
                "success": True,
                "data": {
                    "order_id": order_id,
                    "status": _order_status_to_ru("cancelled"),
                    "status_code": "cancelled",
                },
            }

        payment = cur.execute(
            """
            SELECT *
            FROM payments
            WHERE order_id = ?
            ORDER BY id DESC
            LIMIT 1
            """,
            (order_id,),
        ).fetchone()

        if payment and clean_text(payment["status"], max_len=32).lower() not in {"failed", "refunded", "paid"}:
            _sync_payment_and_order(cur, payment, "failed")
        else:
            old_status = current_status
            cur.execute(
                """
                UPDATE orders
                SET status = 'cancelled',
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
                """,
                (order_id,),
            )
            _enqueue_order_status_notification(
                cur,
                order_id=int(order_id),
                old_status=old_status,
                new_status="cancelled",
            )
            _release_reserved_inventory_for_order(
                cur,
                int(order_id),
                reason="Order cancelled by user, reservation released",
            )
            if payment and clean_text(payment["status"], max_len=32).lower() == "paid":
                if _payment_mode_from_external_id(payment["external_payment_id"]) == "online":
                    _refund_payment(
                        cur,
                        settings,
                        order_id=order_id,
                        payment_row=payment,
                        employee_id=None,
                        reason="Order cancelled by user",
                    )

        conn.commit()
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "order_id": order_id,
            "status": _order_status_to_ru("cancelled"),
            "status_code": "cancelled",
        },
    }


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


@router.get("/admin/orders", summary="Admin: Get Orders")
def admin_get_orders(
    limit: int = Query(default=30, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    status_filter: Optional[str] = Query(default=None, alias="status"),
    store_id: Optional[int] = Query(default=None, ge=1),
    sort_by: str = Query(default="created_at_desc"),
    include_closed: bool = Query(default=True),
    user=Depends(get_current_user),
):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        _require_admin_employee(cur, user)

        where_parts = ["1=1"]
        params: list[object] = []

        if status_filter:
            resolved_status = _validate_admin_order_status(status_filter)
            where_parts.append("o.status = ?")
            params.append(resolved_status)
        elif not include_closed:
            where_parts.append("o.status NOT IN ('completed', 'cancelled')")

        if store_id is not None:
            where_parts.append("o.store_id = ?")
            params.append(store_id)

        resolved_sort = clean_text(sort_by, max_len=32).lower() or "created_at_desc"
        if resolved_sort not in {"created_at_desc", "address_asc"}:
            raise HTTPException(status_code=400, detail="Invalid sort_by")

        order_by_sql = "datetime(o.created_at) DESC, o.id DESC"
        if resolved_sort == "address_asc":
            # Для самовывоза сортируем по адресу точки выдачи (s.address),
            # для доставки — по адресу заказа (o.address_snapshot).
            order_by_sql = (
                "lower(CASE WHEN o.order_type = 'pickup' "
                "THEN COALESCE(s.address, '') ELSE COALESCE(o.address_snapshot, '') END) ASC, "
                "datetime(o.created_at) DESC, o.id DESC"
            )

        where_sql = " AND ".join(where_parts)

        total_row = cur.execute(
            f"""
            SELECT COUNT(*) AS total
            FROM orders o
            WHERE {where_sql}
            """,
            tuple(params),
        ).fetchone()
        total = int(total_row["total"] or 0) if total_row else 0

        rows = cur.execute(
            f"""
            SELECT
                o.*,
                COUNT(oi.id) AS items_count,
                u.full_name AS customer_name,
                u.phone AS customer_phone,
                s.name AS store_name,
                s.address AS store_address
            FROM orders o
            LEFT JOIN order_items oi ON oi.order_id = o.id
            LEFT JOIN users u ON u.id = o.user_id
            LEFT JOIN stores s ON s.id = o.store_id
            WHERE {where_sql}
            GROUP BY o.id
            ORDER BY {order_by_sql}
            LIMIT ? OFFSET ?
            """,
            tuple(params + [limit, offset]),
        ).fetchall()

        items = []
        for row in rows:
            item = _format_order_summary_row(row)
            item["customer"] = {
                "name": row["customer_name"],
                "phone": row["customer_phone"],
            }
            item["store"] = {
                "id": int(row["store_id"]),
                "name": row["store_name"],
                "address": row["store_address"],
            }
            items.append(item)
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "items": items,
            "pagination": {
                "limit": limit,
                "offset": offset,
                "count": len(items),
                "total": total,
            },
        },
    }


@router.get("/admin/orders/{order_id}", summary="Admin: Get Order Details")
def admin_get_order_details(order_id: int, user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        _require_admin_employee(cur, user)

        order = cur.execute(
            """
            SELECT
                o.*,
                u.full_name AS customer_name,
                u.phone AS customer_phone,
                s.name AS store_name,
                s.address AS store_address
            FROM orders o
            LEFT JOIN users u ON u.id = o.user_id
            LEFT JOIN stores s ON s.id = o.store_id
            WHERE o.id = ?
            LIMIT 1
            """,
            (order_id,),
        ).fetchone()
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")

        payment = _get_latest_payment_for_order(cur, order_id)
        data = _format_order_detail(cur, order, payment)
        data["customer"] = {
            "id": int(order["user_id"]),
            "name": order["customer_name"],
            "phone": order["customer_phone"],
        }
        data["store"] = {
            "id": int(order["store_id"]),
            "name": order["store_name"],
            "address": order["store_address"],
        }

    finally:
        conn.close()

    return {"success": True, "data": data}


@router.post("/admin/orders/{order_id}/accept", summary="Admin: Accept Order")
def admin_accept_order(order_id: int, user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        employee_id = _require_admin_employee(cur, user)

        row = cur.execute(
            """
            SELECT id, status, payment_status
            FROM orders
            WHERE id = ?
            LIMIT 1
            """,
            (order_id,),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Order not found")

        current_status = clean_text(row["status"], max_len=32).lower()
        payment_status = clean_text(row["payment_status"], max_len=32).lower()

        if current_status in {"completed", "cancelled"}:
            raise HTTPException(status_code=400, detail=f"Cannot accept order in status: {current_status}")
        if payment_status != "paid":
            raise HTTPException(status_code=400, detail="Cannot accept order before payment is completed")

        next_status = "processing" if current_status in {"new", "awaiting_payment"} else current_status
        _update_order_status(
            cur,
            order_id=order_id,
            new_status=next_status,
            employee_id=employee_id,
        )
        conn.commit()
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "order_id": order_id,
            "status": _order_status_to_ru(next_status),
            "status_code": next_status,
        },
    }


@router.patch("/admin/orders/{order_id}/status", summary="Admin: Update Order Status")
def admin_update_order_status(
    order_id: int,
    payload: AdminUpdateOrderStatusRequest,
    user=Depends(get_current_user),
):
    settings = get_settings()
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        employee_id = _require_admin_employee(cur, user)
        resolved_status = _validate_admin_order_status(payload.status)
        order = cur.execute(
            """
            SELECT id, order_type
            FROM orders
            WHERE id = ?
            LIMIT 1
            """,
            (order_id,),
        ).fetchone()
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")

        allowed_statuses = set(_allowed_admin_statuses_for_order_type(order["order_type"]))
        if resolved_status not in allowed_statuses:
            allowed_text = ", ".join(_allowed_admin_statuses_for_order_type(order["order_type"]))
            raise HTTPException(
                status_code=400,
                detail=f"Status '{resolved_status}' is not allowed for this order type. Allowed: {allowed_text}",
            )

        _update_order_status(
            cur,
            order_id=order_id,
            new_status=resolved_status,
            employee_id=employee_id,
        )
        if resolved_status == "cancelled":
            payment = _get_latest_payment_for_order(cur, order_id)
            if payment and clean_text(payment["status"], max_len=32).lower() == "paid":
                if _payment_mode_from_external_id(payment["external_payment_id"]) == "online":
                    _refund_payment(
                        cur,
                        settings,
                        order_id=order_id,
                        payment_row=payment,
                        employee_id=employee_id,
                        reason="Order cancelled by admin",
                    )
        conn.commit()
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "order_id": order_id,
            "status": _order_status_to_ru(resolved_status),
            "status_code": resolved_status,
        },
    }


@router.post("/admin/orders/{order_id}/close", summary="Admin: Close Order")
def admin_close_order(order_id: int, user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        employee_id = _require_admin_employee(cur, user)

        row = cur.execute(
            """
            SELECT id, payment_status
            FROM orders
            WHERE id = ?
            LIMIT 1
            """,
            (order_id,),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Order not found")
        if clean_text(row["payment_status"], max_len=32).lower() != "paid":
            raise HTTPException(status_code=400, detail="Cannot close unpaid order")

        _update_order_status(
            cur,
            order_id=order_id,
            new_status="completed",
            employee_id=employee_id,
        )
        conn.commit()
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "order_id": order_id,
            "status": _order_status_to_ru("completed"),
            "status_code": "completed",
        },
    }


@router.post("/admin/orders/{order_id}/mark-paid", summary="Admin: Mark Order Paid")
def admin_mark_order_paid(order_id: int, user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        employee_id = _require_admin_employee(cur, user)

        order = cur.execute(
            """
            SELECT id, payment_status
            FROM orders
            WHERE id = ?
            LIMIT 1
            """,
            (order_id,),
        ).fetchone()
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")

        payment = cur.execute(
            """
            SELECT p.*
            FROM payments p
            WHERE p.order_id = ?
            ORDER BY p.id DESC
            LIMIT 1
            """,
            (order_id,),
        ).fetchone()
        if not payment:
            raise HTTPException(status_code=404, detail="Payment not found")

        payment_status = clean_text(payment["status"], max_len=32).lower()
        if payment_status == "paid":
            return {
                "success": True,
                "data": {
                    "order_id": order_id,
                    "payment_status": _payment_status_to_ru("paid"),
                    "payment_status_code": "paid",
                },
            }

        _sync_payment_and_order(cur, payment, "paid")
        cur.execute(
            """
            UPDATE orders
            SET assigned_employee_id = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """,
            (employee_id, order_id),
        )
        conn.commit()
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "order_id": order_id,
            "payment_status": _payment_status_to_ru("paid"),
            "payment_status_code": "paid",
        },
    }


@router.post("/admin/orders/{order_id}/refund", summary="Admin: Refund Order Payment")
def admin_refund_order(
    order_id: int,
    payload: AdminOrderRefundRequest,
    user=Depends(get_current_user),
):
    settings = get_settings()
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        employee_id = _require_admin_employee(cur, user)

        order = cur.execute(
            """
            SELECT id
            FROM orders
            WHERE id = ?
            LIMIT 1
            """,
            (order_id,),
        ).fetchone()
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")

        payment = cur.execute(
            """
            SELECT p.*
            FROM payments p
            WHERE p.order_id = ?
            ORDER BY p.id DESC
            LIMIT 1
            """,
            (order_id,),
        ).fetchone()
        if not payment:
            raise HTTPException(status_code=404, detail="Payment not found")

        result = _refund_payment(
            cur,
            settings,
            order_id=order_id,
            payment_row=payment,
            employee_id=employee_id,
            reason=payload.reason or "Refund by admin",
        )
        conn.commit()
    finally:
        conn.close()

    if result.get("already_refunded"):
        return {
            "success": True,
            "data": {
                "order_id": order_id,
                "payment_status": _payment_status_to_ru("refunded"),
                "payment_status_code": "refunded",
                "already_refunded": True,
            },
        }

    return {
        "success": True,
        "data": {
            "order_id": order_id,
            "payment_status": _payment_status_to_ru("refunded"),
            "payment_status_code": "refunded",
            "refund_id": result.get("refund_id"),
            "refund_status": result.get("refund_status"),
            "external_refund_id": result.get("external_refund_id"),
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
            "order_status": _order_status_to_ru(order["status"]),
            "order_status_code": order["status"],
            "payment_status": _payment_status_to_ru(order["payment_status"]),
            "payment_status_code": order["payment_status"],
            "total_price": float(order["total_price"]),
            "payment_link": _format_payment_row(payment) if payment else None,
        },
    }
