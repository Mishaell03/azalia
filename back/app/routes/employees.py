from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict, Field

from app.db import get_db_connection
from app.routes.utils import get_current_user, is_admin_user, require_admin

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
    return {
        "id": row["id"],
        "user_id": row["user_id"],
        "telegram_id": row["telegram_id"],
        "full_name": row["full_name"],
        "phone": row["phone"],
        "avatar_url": row["avatar_url"],
        "position_id": row["position_id"],
        "position_title": row["position_title"],
        "store_id": row["store_id"],
        "store_name": row["store_name"],
        "store_address": row["store_address"],
        "salary": float(row["salary"] or 0),
        "hired_at": row["hired_at"],
        "fired_at": row["fired_at"],
        "is_active": bool(row["is_active"]),
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


@router.get("/users", summary="Get Users (Non-employees)")
def list_users(
    page: int = Query(default=1, ge=1),
    per_page: int = Query(default=20, ge=1, le=100),
    user=Depends(get_current_user),
):
    """Возвращает список пользователей, которые не назначены сотрудниками."""
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
                WHERE e.id IS NULL
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
                u.created_at,
                u.updated_at
            FROM users u
            LEFT JOIN employees e ON e.user_id = u.id
            WHERE e.id IS NULL
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
                "avatar_url": row["avatar_url"],
                "status": row["status"],
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
