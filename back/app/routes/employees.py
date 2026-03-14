from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict, Field

from app.db import get_db_connection
from app.routes.utils import BLOCKED_IMAGE_PATH, clean_optional_text, get_current_user, is_admin_user, require_admin

router = APIRouter(prefix="/api", tags=["employees"])


class AssignEmployeeRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    user_id: Optional[int] = Field(default=None, ge=1)
    telegram_id: Optional[int] = Field(default=None, ge=1)
    position_id: Optional[int] = Field(default=None, ge=1)
    store_id: Optional[int] = Field(default=None, ge=1)
    salary: Optional[float] = Field(default=None, ge=0)
    is_active: Optional[bool] = None


class DeactivateEmployeeRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    user_id: Optional[int] = Field(default=None, ge=1)
    telegram_id: Optional[int] = Field(default=None, ge=1)
    position_id: Optional[int] = Field(default=None, ge=1)
    store_id: Optional[int] = Field(default=None, ge=1)
    salary: Optional[float] = Field(default=None, ge=0)
    is_active: Optional[bool] = None


class UpdateUserRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    status: Optional[str] = Field(default=None, max_length=20)
    blocked_reason: Optional[str] = Field(default=None, max_length=255)

    # backward-compatible admin toggles
    make_admin: Optional[bool] = None
    admin_store_id: Optional[int] = Field(default=None, ge=1)
    admin_salary: Optional[float] = Field(default=None, ge=0)
    admin_is_active: Optional[bool] = None

    # generic employee assignment (supports all professions from positions table)
    position_id: Optional[int] = Field(default=None, ge=1)
    store_id: Optional[int] = Field(default=None, ge=1)
    salary: Optional[float] = Field(default=None, ge=0)
    is_active: Optional[bool] = None
    remove_employee: Optional[bool] = None


class UpdateEmployeeRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    position_id: Optional[int] = Field(default=None, ge=1)
    store_id: Optional[int] = Field(default=None, ge=1)
    salary: Optional[float] = Field(default=None, ge=0)
    is_active: Optional[bool] = None


class UpdateAdminRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    position_id: Optional[int] = Field(default=None, ge=1)
    salary: Optional[float] = Field(default=None, ge=0)
    store_id: Optional[int] = Field(default=None, ge=1)
    store_address: Optional[str] = Field(default=None, max_length=255)
    is_active: Optional[bool] = None
    fire: Optional[bool] = None


def _resolve_user(cur, user_id: Optional[int], telegram_id: Optional[int]):
    user = None
    if user_id is not None:
        user = cur.execute(
            "SELECT id, telegram_id, full_name, phone, avatar_url, status FROM users WHERE id = ?",
            (user_id,),
        ).fetchone()

    if user is None and telegram_id is not None:
        user = cur.execute(
            "SELECT id, telegram_id, full_name, phone, avatar_url, status FROM users WHERE telegram_id = ?",
            (telegram_id,),
        ).fetchone()

    return user


def _resolve_user_by_id(cur, user_id: int):
    return cur.execute(
        """
        SELECT id, telegram_id, full_name, phone, avatar_url, status, blocked_at, blocked_reason, deleted_at,
               created_at, updated_at
        FROM users
        WHERE id = ?
        LIMIT 1
        """,
        (user_id,),
    ).fetchone()


def _resolve_admin_position_id(cur) -> int:
    admin_position = cur.execute(
        """
        SELECT id
        FROM positions
        WHERE id = 4 OR lower(title) LIKE '%admin%' OR lower(title) LIKE '%админ%'
        ORDER BY CASE WHEN id = 4 THEN 0 ELSE 1 END, id ASC
        LIMIT 1
        """
    ).fetchone()
    if not admin_position:
        raise HTTPException(status_code=404, detail="Admin position not found")
    return int(admin_position["id"])


def _is_admin_role(position_id: int, position_title: Optional[str]) -> bool:
    title = (position_title or "").lower()
    return int(position_id) == 4 or "админ" in title or "admin" in title


def _avatar_for_status(status: Optional[str], avatar_url: Optional[str]) -> Optional[str]:
    if (status or "").lower() in {"blocked", "deleted"}:
        return BLOCKED_IMAGE_PATH
    return avatar_url


def _resolve_employee_by_user_id(cur, user_id: int):
    return cur.execute(
        """
        SELECT
            e.id,
            e.user_id,
            e.position_id,
            e.store_id,
            e.salary,
            e.hired_at,
            e.fired_at,
            e.is_active,
            p.title AS position_title
        FROM employees e
        JOIN positions p ON p.id = e.position_id
        WHERE e.user_id = ?
        LIMIT 1
        """,
        (user_id,),
    ).fetchone()


def _get_positions(cur):
    rows = cur.execute(
        """
        SELECT id, title, description, created_at
        FROM positions
        ORDER BY id ASC
        """
    ).fetchall()
    return [
        {
            "id": row["id"],
            "title": row["title"],
            "description": row["description"],
            "created_at": row["created_at"],
        }
        for row in rows
    ]


def _get_stores(cur):
    rows = cur.execute(
        """
        SELECT id, name, address, phone, email, store_type, is_active, created_at, updated_at
        FROM stores
        ORDER BY id ASC
        """
    ).fetchall()
    return [
        {
            "id": row["id"],
            "name": row["name"],
            "address": row["address"],
            "phone": row["phone"],
            "email": row["email"],
            "store_type": row["store_type"],
            "is_active": bool(row["is_active"]),
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
        }
        for row in rows
    ]


def _get_user_orders(cur, user_id: int, limit: int = 100):
    rows = cur.execute(
        """
        SELECT
            o.id,
            o.order_number,
            o.order_type,
            o.store_id,
            s.name AS store_name,
            o.subtotal,
            o.delivery_fee,
            o.discount_amount,
            o.total_price,
            o.payment_status,
            o.status,
            o.created_at,
            o.updated_at
        FROM orders o
        JOIN stores s ON s.id = o.store_id
        WHERE o.user_id = ?
        ORDER BY datetime(o.created_at) DESC, o.id DESC
        LIMIT ?
        """,
        (user_id, limit),
    ).fetchall()

    return [
        {
            "id": row["id"],
            "order_number": row["order_number"],
            "order_type": row["order_type"],
            "store_id": row["store_id"],
            "store_name": row["store_name"],
            "subtotal": float(row["subtotal"] or 0),
            "delivery_fee": float(row["delivery_fee"] or 0),
            "discount_amount": float(row["discount_amount"] or 0),
            "total_price": float(row["total_price"] or 0),
            "payment_status": row["payment_status"],
            "status": row["status"],
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
        }
        for row in rows
    ]


def _get_user_status_history(cur, user_id: int, limit: int = 50):
    rows = cur.execute(
        """
        SELECT id, old_status, new_status, changed_by_employee_id, reason, created_at
        FROM user_status_history
        WHERE user_id = ?
        ORDER BY id DESC
        LIMIT ?
        """,
        (user_id, limit),
    ).fetchall()

    return [
        {
            "id": row["id"],
            "old_status": row["old_status"],
            "new_status": row["new_status"],
            "changed_by_employee_id": row["changed_by_employee_id"],
            "reason": row["reason"],
            "created_at": row["created_at"],
        }
        for row in rows
    ]


def _get_order_status_history(cur, user_id: int, limit: int = 100):
    rows = cur.execute(
        """
        SELECT
            osh.id,
            osh.order_id,
            o.order_number,
            osh.old_status,
            osh.new_status,
            osh.changed_by_employee_id,
            osh.created_at
        FROM order_status_history osh
        JOIN orders o ON o.id = osh.order_id
        WHERE o.user_id = ?
        ORDER BY osh.id DESC
        LIMIT ?
        """,
        (user_id, limit),
    ).fetchall()

    return [
        {
            "id": row["id"],
            "order_id": row["order_id"],
            "order_number": row["order_number"],
            "old_status": row["old_status"],
            "new_status": row["new_status"],
            "changed_by_employee_id": row["changed_by_employee_id"],
            "created_at": row["created_at"],
        }
        for row in rows
    ]


def _serialize_user_detail(cur, user_id: int):
    profile = _serialize_user(cur, user_id)
    if profile is None:
        return None

    orders = _get_user_orders(cur, user_id=user_id, limit=100)
    user_status_history = _get_user_status_history(cur, user_id=user_id, limit=50)
    order_status_history = _get_order_status_history(cur, user_id=user_id, limit=100)

    profile["orders"] = orders
    profile["history"] = {
        "user_status": user_status_history,
        "order_status": order_status_history,
    }
    profile["orders_summary"] = {
        "orders_count": len(orders),
        "orders_total_amount": round(sum(float(o["total_price"]) for o in orders), 2),
    }

    return profile


def _serialize_user(cur, user_id: int):
    user = _resolve_user_by_id(cur, user_id)
    if not user:
        return None

    employee = cur.execute(
        """
        SELECT
            e.id,
            e.position_id,
            e.store_id,
            e.salary,
            e.hired_at,
            e.fired_at,
            e.is_active,
            p.title AS position_title,
            s.name AS store_name,
            s.address AS store_address
        FROM employees e
        JOIN positions p ON p.id = e.position_id
        JOIN stores s ON s.id = e.store_id
        WHERE e.user_id = ?
        LIMIT 1
        """,
        (user_id,),
    ).fetchone()

    response = {
        "id": user["id"],
        "telegram_id": user["telegram_id"],
        "name": user["full_name"],
        "phone": user["phone"],
        "avatar_url": _avatar_for_status(user["status"], user["avatar_url"]),
        "status": user["status"],
        "blocked_at": user["blocked_at"],
        "blocked_reason": user["blocked_reason"],
        "deleted_at": user["deleted_at"],
        "created_at": user["created_at"],
        "updated_at": user["updated_at"],
        "is_admin": False,
    }

    if employee:
        is_admin = _is_admin_role(employee["position_id"], employee["position_title"])
        response["employee"] = {
            "id": employee["id"],
            "position_id": employee["position_id"],
            "position_title": employee["position_title"],
            "store_id": employee["store_id"],
            "store_name": employee["store_name"],
            "store_address": employee["store_address"],
            "salary": float(employee["salary"] or 0),
            "hired_at": employee["hired_at"],
            "fired_at": employee["fired_at"],
            "is_active": bool(employee["is_active"]),
        }
        response["is_admin"] = is_admin

    return response


def _employee_with_details(cur, employee_id: int):
    return cur.execute(
        """
        SELECT
            e.id,
            e.user_id,
            e.position_id,
            e.store_id,
            e.salary,
            e.hired_at,
            e.fired_at,
            e.is_active,
            e.created_at,
            e.updated_at,
            u.telegram_id,
            u.full_name,
            u.phone,
            u.avatar_url,
            u.status,
            p.title AS position_title,
            s.name AS store_name,
            s.address AS store_address
        FROM employees e
        JOIN users u ON u.id = e.user_id
        JOIN positions p ON p.id = e.position_id
        JOIN stores s ON s.id = e.store_id
        WHERE e.id = ?
        LIMIT 1
        """,
        (employee_id,),
    ).fetchone()


def _employee_to_dict(row):
    is_active = bool(row["is_active"])
    avatar_url = _avatar_for_status(row["status"], row["avatar_url"])
    if not is_active:
        avatar_url = BLOCKED_IMAGE_PATH

    return {
        "id": row["id"],
        "user_id": row["user_id"],
        "telegram_id": row["telegram_id"],
        "full_name": row["full_name"],
        "phone": row["phone"],
        "avatar_url": avatar_url,
        "status": row["status"],
        "position_id": row["position_id"],
        "position_title": row["position_title"],
        "store_id": row["store_id"],
        "store_name": row["store_name"],
        "store_address": row["store_address"],
        "salary": float(row["salary"] or 0),
        "hired_at": row["hired_at"],
        "fired_at": row["fired_at"],
        "is_active": is_active,
        "is_fired": not is_active,
        "employment_status": "active" if is_active else "fired",
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


def _validate_employee_links(cur, position_id: Optional[int], store_id: Optional[int]) -> None:
    if position_id is not None:
        pos = cur.execute("SELECT id FROM positions WHERE id = ?", (position_id,)).fetchone()
        if not pos:
            raise HTTPException(status_code=404, detail="Position not found")

    if store_id is not None:
        store = cur.execute("SELECT id FROM stores WHERE id = ?", (store_id,)).fetchone()
        if not store:
            raise HTTPException(status_code=404, detail="Store not found")


def _update_employee_record(cur, employee_id: int, payload: UpdateEmployeeRequest):
    _validate_employee_links(cur, payload.position_id, payload.store_id)

    updates = {}
    if payload.position_id is not None:
        updates["position_id"] = payload.position_id
    if payload.store_id is not None:
        updates["store_id"] = payload.store_id
    if payload.salary is not None:
        updates["salary"] = payload.salary
    if payload.is_active is not None:
        updates["is_active"] = int(payload.is_active)
        updates["fired_at"] = None if payload.is_active else "CURRENT_TIMESTAMP"

    if not updates:
        raise HTTPException(status_code=400, detail="No update fields provided")

    set_parts = []
    params: list[object] = []
    for key, value in updates.items():
        if value == "CURRENT_TIMESTAMP":
            set_parts.append(f"{key} = CURRENT_TIMESTAMP")
        else:
            set_parts.append(f"{key} = ?")
            params.append(value)

    params.append(employee_id)
    cur.execute(
        f"UPDATE employees SET {', '.join(set_parts)} WHERE id = ?",
        tuple(params),
    )


@router.get("/users/{user_id}", summary="Get User Details (Admin only)")
def get_user_details(user_id: int, user=Depends(get_current_user)):
    """Детали пользователя: профиль, сотрудник, заказы и история."""
    require_admin(user)

    response_data = None
    positions = []
    stores = []
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        details = _serialize_user_detail(cur, user_id)
        if not details:
            raise HTTPException(status_code=404, detail="User not found")
        positions = _get_positions(cur)
        stores = _get_stores(cur)
        response_data = details
    finally:
        conn.close()

    return {
        "success": True,
        "data": response_data,
        "options": {
            "positions": positions,
            "stores": stores,
        },
    }


@router.get("/admins/{user_id}", summary="Get Admin Details (Admin only)")
def get_admin_details(user_id: int, user=Depends(get_current_user)):
    """Детали администратора + доступные профессии/магазины для переназначения."""
    require_admin(user)

    response_data = None
    positions = []
    stores = []
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        details = _serialize_user_detail(cur, user_id)
        if not details:
            raise HTTPException(status_code=404, detail="User not found")

        employee = _resolve_employee_by_user_id(cur, user_id)
        if not employee or not _is_admin_role(employee["position_id"], employee["position_title"]):
            raise HTTPException(status_code=400, detail="Target user is not admin")
        positions = _get_positions(cur)
        stores = _get_stores(cur)
        response_data = details
    finally:
        conn.close()

    return {
        "success": True,
        "data": response_data,
        "options": {
            "positions": positions,
            "stores": stores,
        },
    }


@router.patch("/users/{user_id}", summary="Update User (Admin only)")
def update_user(user_id: int, payload: UpdateUserRequest, user=Depends(get_current_user)):
    """Редактирование пользователя (бан/разбан/назначение админом)."""
    require_admin(user)

    normalized_status = clean_optional_text(payload.status, max_len=20)
    if normalized_status is not None and normalized_status not in {"active", "blocked", "deleted"}:
        raise HTTPException(
            status_code=400,
            detail="status must be one of: active, blocked, deleted",
        )
    blocked_reason = clean_optional_text(payload.blocked_reason, max_len=255)
    current_user_id = int(user["id"])

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        target_user = _resolve_user_by_id(cur, user_id)
        if not target_user:
            raise HTTPException(status_code=404, detail="User not found")

        requested_store_id = payload.store_id if payload.store_id is not None else payload.admin_store_id
        requested_salary = payload.salary if payload.salary is not None else payload.admin_salary
        requested_is_active = (
            payload.is_active if payload.is_active is not None else payload.admin_is_active
        )

        is_self = user_id == current_user_id
        is_self_block_or_delete = normalized_status in {"blocked", "deleted"}
        is_self_fire = (
            payload.remove_employee is True
            or requested_is_active is False
            or (
                payload.make_admin is False
                and payload.position_id is None
                and requested_store_id is None
                and requested_salary is None
                and requested_is_active is None
                and payload.remove_employee is None
            )
        )
        if is_self and (is_self_block_or_delete or is_self_fire):
            raise HTTPException(
                status_code=400,
                detail="You cannot block/delete or fire your own account",
            )

        changes_made = False

        user_set_parts: list[str] = []
        user_params: list[object] = []

        if normalized_status is not None:
            user_set_parts.append("status = ?")
            user_params.append(normalized_status)
            changes_made = True

            if normalized_status == "blocked":
                user_set_parts.append("blocked_at = CURRENT_TIMESTAMP")
                user_set_parts.append("blocked_reason = ?")
                user_params.append(blocked_reason)
            elif normalized_status == "active":
                user_set_parts.append("blocked_at = NULL")
                user_set_parts.append("blocked_reason = NULL")
                user_set_parts.append("deleted_at = NULL")
            elif normalized_status == "deleted":
                user_set_parts.append("deleted_at = CURRENT_TIMESTAMP")

        elif blocked_reason is not None:
            user_set_parts.append("blocked_reason = ?")
            user_params.append(blocked_reason)
            changes_made = True

        if user_set_parts:
            user_params.append(user_id)
            cur.execute(
                f"UPDATE users SET {', '.join(user_set_parts)} WHERE id = ?",
                tuple(user_params),
            )

        if normalized_status == "blocked":
            revoke_reason = blocked_reason or "user_blocked_by_admin"
            cur.execute(
                """
                UPDATE user_sessions
                SET is_active = 0,
                    revoked_at = CURRENT_TIMESTAMP,
                    revoke_reason = ?
                WHERE user_id = ?
                  AND is_active = 1
                """,
                (revoke_reason, user_id),
            )

        employee_change_requested = (
            payload.make_admin is not None
            or payload.position_id is not None
            or payload.store_id is not None
            or payload.salary is not None
            or payload.is_active is not None
            or payload.remove_employee is not None
            or payload.admin_store_id is not None
            or payload.admin_salary is not None
            or payload.admin_is_active is not None
        )

        if employee_change_requested:
            employee = _resolve_employee_by_user_id(cur, user_id)
            admin_position_id = _resolve_admin_position_id(cur)

            # backward-compatible aliases
            if payload.remove_employee is True:
                if not employee:
                    raise HTTPException(status_code=404, detail="Employee record not found")
                cur.execute(
                    """
                    UPDATE employees
                    SET is_active = 0,
                        fired_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                    """,
                    (employee["id"],),
                )
                changes_made = True
            else:
                # Legacy behavior: make_admin=false without explicit profession means deactivate admin role.
                if (
                    payload.make_admin is False
                    and payload.position_id is None
                    and requested_store_id is None
                    and requested_salary is None
                    and requested_is_active is None
                    and payload.remove_employee is None
                ):
                    if not employee:
                        raise HTTPException(status_code=404, detail="Admin employee record not found")
                    if not _is_admin_role(employee["position_id"], employee["position_title"]):
                        raise HTTPException(status_code=400, detail="User is not admin")

                    cur.execute(
                        """
                        UPDATE employees
                        SET is_active = 0,
                            fired_at = CURRENT_TIMESTAMP
                        WHERE id = ?
                        """,
                        (employee["id"],),
                    )
                    changes_made = True
                else:
                    target_position_id = payload.position_id
                    if payload.make_admin is True:
                        target_position_id = admin_position_id

                    if target_position_id is None and employee:
                        target_position_id = int(employee["position_id"])

                    if target_position_id is None:
                        raise HTTPException(
                            status_code=400,
                            detail="position_id is required to assign profession",
                        )

                    target_store_id = requested_store_id
                    if target_store_id is None and employee:
                        target_store_id = int(employee["store_id"])
                    if target_store_id is None:
                        target_store_id = 1

                    _validate_employee_links(cur, target_position_id, target_store_id)

                    target_salary = requested_salary
                    if target_salary is None and employee:
                        target_salary = employee["salary"]

                    target_is_active = requested_is_active
                    if target_is_active is None and employee:
                        target_is_active = bool(employee["is_active"])
                    if target_is_active is None:
                        target_is_active = True

                    if employee:
                        cur.execute(
                            """
                            UPDATE employees
                            SET position_id = ?,
                                store_id = ?,
                                salary = ?,
                                is_active = ?,
                                fired_at = CASE WHEN ? = 1 THEN NULL ELSE CURRENT_TIMESTAMP END
                            WHERE id = ?
                            """,
                            (
                                target_position_id,
                                target_store_id,
                                target_salary,
                                int(target_is_active),
                                int(target_is_active),
                                employee["id"],
                            ),
                        )
                    else:
                        cur.execute(
                            """
                            INSERT INTO employees (user_id, position_id, store_id, salary, is_active, fired_at)
                            VALUES (?, ?, ?, ?, ?, CASE WHEN ? = 1 THEN NULL ELSE CURRENT_TIMESTAMP END)
                            """,
                            (
                                user_id,
                                target_position_id,
                                target_store_id,
                                target_salary,
                                int(target_is_active),
                                int(target_is_active),
                            ),
                        )
                    changes_made = True

        if not changes_made:
            raise HTTPException(status_code=400, detail="No update fields provided")

        conn.commit()
        response = _serialize_user_detail(cur, user_id)
        positions = _get_positions(cur)
        stores = _get_stores(cur)
    finally:
        conn.close()

    return {
        "success": True,
        "message": "User updated",
        "data": response,
        "options": {
            "positions": positions,
            "stores": stores,
        },
    }


@router.patch("/admins/{user_id}", summary="Update Admin (Admin only)")
def update_admin(user_id: int, payload: UpdateAdminRequest, user=Depends(get_current_user)):
    """Редактирование администратора: ЗП, место/адрес работы, увольнение."""
    require_admin(user)

    store_address = clean_optional_text(payload.store_address, max_len=255)
    if (
        payload.position_id is None
        and payload.salary is None
        and payload.store_id is None
        and payload.is_active is None
        and payload.fire is None
        and store_address is None
    ):
        raise HTTPException(status_code=400, detail="No update fields provided")

    current_user_id = int(user["id"])
    is_self = user_id == current_user_id
    requested_is_active = payload.is_active
    if payload.fire is True:
        requested_is_active = False
    elif payload.fire is False and payload.is_active is None:
        requested_is_active = True

    if is_self and requested_is_active is False:
        raise HTTPException(
            status_code=400,
            detail="You cannot fire your own admin account",
        )

    conn = get_db_connection()
    try:
        cur = conn.cursor()

        target_user = _resolve_user_by_id(cur, user_id)
        if not target_user:
            raise HTTPException(status_code=404, detail="User not found")

        employee = _resolve_employee_by_user_id(cur, user_id)
        if not employee:
            raise HTTPException(status_code=404, detail="Admin employee record not found")
        if not _is_admin_role(employee["position_id"], employee["position_title"]):
            raise HTTPException(status_code=400, detail="Target employee is not admin")

        if payload.position_id is not None or payload.store_id is not None:
            _validate_employee_links(cur, payload.position_id, payload.store_id)

        set_parts: list[str] = []
        params: list[object] = []

        if payload.position_id is not None:
            set_parts.append("position_id = ?")
            params.append(payload.position_id)
        if payload.salary is not None:
            set_parts.append("salary = ?")
            params.append(payload.salary)
        if payload.store_id is not None:
            set_parts.append("store_id = ?")
            params.append(payload.store_id)

        is_active_value: Optional[bool] = payload.is_active
        if payload.fire is True:
            is_active_value = False
        elif payload.fire is False and payload.is_active is None:
            is_active_value = True

        if is_active_value is not None:
            set_parts.append("is_active = ?")
            params.append(int(is_active_value))
            if is_active_value:
                set_parts.append("fired_at = NULL")
            else:
                set_parts.append("fired_at = CURRENT_TIMESTAMP")

        if set_parts:
            params.append(employee["id"])
            cur.execute(
                f"UPDATE employees SET {', '.join(set_parts)} WHERE id = ?",
                tuple(params),
            )

        if store_address is not None:
            target_store_id = payload.store_id or int(employee["store_id"])
            cur.execute(
                "UPDATE stores SET address = ? WHERE id = ?",
                (store_address, target_store_id),
            )

        conn.commit()
        response = _serialize_user_detail(cur, user_id)
        positions = _get_positions(cur)
        stores = _get_stores(cur)
    finally:
        conn.close()

    return {
        "success": True,
        "message": "Admin updated",
        "data": response,
        "options": {
            "positions": positions,
            "stores": stores,
        },
    }


@router.get("/users", summary="Get Users (Non-employees)")
def list_users(
    page: int = Query(default=1, ge=1),
    per_page: int = Query(default=20, ge=1, le=100),
    user=Depends(get_current_user),
):
    """Возвращает обычных пользователей + уволенных сотрудников."""
    require_admin(user)
    offset = (page - 1) * per_page

    conn = get_db_connection()
    try:
        total = int(
            conn.execute(
                """
                SELECT COUNT(*) AS total
                FROM users u
                LEFT JOIN employees e ON e.user_id = u.id
                WHERE e.id IS NULL OR e.is_active = 0
                """
            ).fetchone()["total"]
        )
        rows = conn.execute(
            """
            SELECT
                u.id,
                u.telegram_id,
                u.full_name,
                u.phone,
                u.avatar_url,
                u.status,
                e.id AS employee_id,
                e.is_active AS employee_is_active,
                u.created_at,
                u.updated_at
            FROM users u
            LEFT JOIN employees e ON e.user_id = u.id
            WHERE e.id IS NULL OR e.is_active = 0
            ORDER BY u.id ASC
            LIMIT ? OFFSET ?
            """
            ,
            (per_page, offset),
        ).fetchall()
    finally:
        conn.close()

    pages = (total + per_page - 1) // per_page
    return {
        "success": True,
        "data": [
            {
                "id": row["id"],
                "telegram_id": row["telegram_id"],
                "name": row["full_name"],
                "phone": row["phone"],
                "avatar_url": _avatar_for_status(row["status"], row["avatar_url"]),
                "status": row["status"],
                "is_employee": row["employee_id"] is not None,
                "is_fired_employee": row["employee_id"] is not None and not bool(row["employee_is_active"]),
                "employment_status": (
                    "fired"
                    if row["employee_id"] is not None and not bool(row["employee_is_active"])
                    else "none"
                ),
                "created_at": row["created_at"],
                "updated_at": row["updated_at"],
            }
            for row in rows
        ],
        "pagination": {
            "page": page,
            "per_page": per_page,
            "total": total,
            "pages": pages,
        },
    }


@router.get("/debug/whoami", summary="Debug Current User")
def debug_whoami(user=Depends(get_current_user)):
    """Отладочный endpoint: показывает текущего пользователя и его роль."""
    return {
        "success": True,
        "user": {
            "id": user["id"],
            "telegram_id": user["telegram_id"],
            "name": user["full_name"],
            "phone": user["phone"],
            "avatar_url": user["avatar_url"],
            "status": user["status"],
            "session_token": user["session_token"],
            "session_expires_at": user["expires_at"],
        },
        "is_admin": is_admin_user(user),
    }


@router.get("/employees", summary="Get Employees")
def get_employees(user=Depends(get_current_user)):
    """Возвращает список сотрудников с подробной информацией."""
    require_admin(user)

    conn = get_db_connection()
    try:
        rows = conn.execute(
            """
            SELECT
                e.id,
                e.user_id,
                e.position_id,
                e.store_id,
                e.salary,
                e.hired_at,
                e.fired_at,
                e.is_active,
                e.created_at,
                e.updated_at,
                u.telegram_id,
                u.full_name,
                u.phone,
                u.avatar_url,
                u.status,
                p.title AS position_title,
                s.name AS store_name,
                s.address AS store_address
            FROM employees e
            JOIN users u ON u.id = e.user_id
            JOIN positions p ON p.id = e.position_id
            JOIN stores s ON s.id = e.store_id
            ORDER BY e.id ASC
            """
        ).fetchall()
    finally:
        conn.close()

    return {"success": True, "data": [_employee_to_dict(row) for row in rows]}


@router.get("/employees/{employee_id}", summary="Get Employee By Id")
def get_employee(employee_id: int, user=Depends(get_current_user)):
    """Возвращает карточку конкретного сотрудника."""
    require_admin(user)

    conn = get_db_connection()
    try:
        row = _employee_with_details(conn.cursor(), employee_id)
    finally:
        conn.close()

    if not row:
        raise HTTPException(status_code=404, detail="Employee not found")

    return {"success": True, "data": _employee_to_dict(row)}


@router.post("/employees/assign", status_code=status.HTTP_201_CREATED, summary="Assign Employee")
def assign_employee(payload: AssignEmployeeRequest, user=Depends(get_current_user)):
    """Назначает пользователя сотрудником или обновляет существующего сотрудника."""
    require_admin(user)

    if payload.user_id is None and payload.telegram_id is None:
        raise HTTPException(status_code=400, detail="user_id or telegram_id is required")

    conn = get_db_connection()
    try:
        cur = conn.cursor()

        target_user = _resolve_user(cur, payload.user_id, payload.telegram_id)
        if not target_user:
            raise HTTPException(status_code=404, detail="User not found")

        if int(target_user["id"]) == int(user["id"]) and payload.is_active is False:
            raise HTTPException(
                status_code=400,
                detail="You cannot fire your own account",
            )

        existing = cur.execute(
            "SELECT id FROM employees WHERE user_id = ?",
            (target_user["id"],),
        ).fetchone()

        if payload.position_id is not None:
            pos = cur.execute("SELECT id FROM positions WHERE id = ?", (payload.position_id,)).fetchone()
            if not pos:
                raise HTTPException(status_code=404, detail="Position not found")

        if payload.store_id is not None:
            store = cur.execute("SELECT id FROM stores WHERE id = ?", (payload.store_id,)).fetchone()
            if not store:
                raise HTTPException(status_code=404, detail="Store not found")

        if existing:
            updates = {}
            if payload.position_id is not None:
                updates["position_id"] = payload.position_id
            if payload.store_id is not None:
                updates["store_id"] = payload.store_id
            if payload.salary is not None:
                updates["salary"] = payload.salary
            if payload.is_active is not None:
                updates["is_active"] = int(payload.is_active)
                updates["fired_at"] = None if payload.is_active else "CURRENT_TIMESTAMP"

            if not updates:
                raise HTTPException(status_code=400, detail="No update fields provided")

            set_parts = []
            params: list[object] = []
            for key, value in updates.items():
                if value == "CURRENT_TIMESTAMP":
                    set_parts.append(f"{key} = CURRENT_TIMESTAMP")
                else:
                    set_parts.append(f"{key} = ?")
                    params.append(value)
            params.append(existing["id"])

            cur.execute(
                f"UPDATE employees SET {', '.join(set_parts)} WHERE id = ?",
                tuple(params),
            )
            conn.commit()

            updated = _employee_with_details(cur, existing["id"])
            return {
                "success": True,
                "message": "Employee updated",
                "data": _employee_to_dict(updated),
            }

        if payload.position_id is None:
            raise HTTPException(status_code=400, detail="position_id is required")

        store_id = payload.store_id or 1
        store = cur.execute("SELECT id FROM stores WHERE id = ?", (store_id,)).fetchone()
        if not store:
            raise HTTPException(status_code=404, detail="Store not found")

        cur.execute(
            """
            INSERT INTO employees (user_id, position_id, store_id, salary, is_active)
            VALUES (?, ?, ?, ?, ?)
            """,
            (
                target_user["id"],
                payload.position_id,
                store_id,
                payload.salary,
                1 if payload.is_active is None else int(payload.is_active),
            ),
        )
        employee_id = cur.lastrowid
        conn.commit()

        created = _employee_with_details(cur, employee_id)
    finally:
        conn.close()

    return {
        "success": True,
        "message": "User assigned as employee",
        "data": _employee_to_dict(created),
    }


@router.post("/employees/deactivate", summary="Deactivate Or Update Employee")
def deactivate_employee(payload: DeactivateEmployeeRequest, user=Depends(get_current_user)):
    """Деактивирует сотрудника или обновляет его параметры."""
    require_admin(user)

    if payload.user_id is None and payload.telegram_id is None:
        raise HTTPException(status_code=400, detail="user_id or telegram_id is required")

    conn = get_db_connection()
    try:
        cur = conn.cursor()

        target_user = _resolve_user(cur, payload.user_id, payload.telegram_id)
        if not target_user:
            raise HTTPException(status_code=404, detail="User not found")

        employee = cur.execute(
            "SELECT id FROM employees WHERE user_id = ?",
            (target_user["id"],),
        ).fetchone()
        if not employee:
            raise HTTPException(status_code=404, detail="Employee record not found")

        if payload.position_id is not None:
            pos = cur.execute("SELECT id FROM positions WHERE id = ?", (payload.position_id,)).fetchone()
            if not pos:
                raise HTTPException(status_code=404, detail="Position not found")

        if payload.store_id is not None:
            store = cur.execute("SELECT id FROM stores WHERE id = ?", (payload.store_id,)).fetchone()
            if not store:
                raise HTTPException(status_code=404, detail="Store not found")

        updates = {}
        if payload.position_id is not None:
            updates["position_id"] = payload.position_id
        if payload.store_id is not None:
            updates["store_id"] = payload.store_id
        if payload.salary is not None:
            updates["salary"] = payload.salary

        is_active = False if payload.is_active is None else payload.is_active
        if int(target_user["id"]) == int(user["id"]) and not is_active:
            raise HTTPException(
                status_code=400,
                detail="You cannot fire your own account",
            )
        updates["is_active"] = int(is_active)

        set_parts = []
        params: list[object] = []
        for key, value in updates.items():
            set_parts.append(f"{key} = ?")
            params.append(value)

        if is_active:
            set_parts.append("fired_at = NULL")
        else:
            set_parts.append("fired_at = CURRENT_TIMESTAMP")

        params.append(employee["id"])
        cur.execute(
            f"UPDATE employees SET {', '.join(set_parts)} WHERE id = ?",
            tuple(params),
        )
        conn.commit()

        updated = _employee_with_details(cur, employee["id"])
    finally:
        conn.close()

    return {
        "success": True,
        "message": "Employee deactivated/updated",
        "data": _employee_to_dict(updated),
    }
