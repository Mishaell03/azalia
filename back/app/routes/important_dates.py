from __future__ import annotations

from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, ConfigDict, Field

from app.db import get_db_connection
from app.routes.utils import clean_optional_text, clean_text, get_current_user

router = APIRouter(prefix="/api/important-dates", tags=["important-dates"])


class ImportantDateCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str = Field(min_length=1, max_length=150)
    event_date: str = Field(min_length=10, max_length=10)
    comment: Optional[str] = Field(default=None, max_length=1000)


class ImportantDateUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: Optional[str] = Field(default=None, min_length=1, max_length=150)
    event_date: Optional[str] = Field(default=None, min_length=10, max_length=10)
    comment: Optional[str] = Field(default=None, max_length=1000)


class HolidayPreferenceCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    holiday_code: str = Field(min_length=1, max_length=32)
    category_id: Optional[int] = Field(default=None, ge=1)
    product_id: Optional[int] = Field(default=None, ge=1)


class ImportantDatePreferenceCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    category_id: Optional[int] = Field(default=None, ge=1)
    product_id: Optional[int] = Field(default=None, ge=1)


def _parse_iso_date(value: str, field_name: str) -> str:
    text = clean_text(value, max_len=16)
    try:
        return datetime.strptime(text, "%Y-%m-%d").strftime("%Y-%m-%d")
    except ValueError:
        raise HTTPException(status_code=422, detail=f"{field_name} must be YYYY-MM-DD")


def _serialize(row) -> dict:
    return {
        "id": int(row["id"]),
        "title": row["title"],
        "event_date": row["event_date"],
        "comment": row["comment"],
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


def _active_plan_code(cur, user_id: int) -> str:
    row = cur.execute(
        """
        SELECT sp.code
        FROM subscriptions s
        JOIN subscription_plans sp ON sp.id = s.plan_id
        WHERE s.user_id = ?
          AND s.status = 'active'
          AND datetime(s.expires_at) > datetime('now')
        ORDER BY s.id DESC
        LIMIT 1
        """,
        (user_id,),
    ).fetchone()
    if not row:
        return "free"
    return (row["code"] or "free").strip().lower()


def _normalize_holiday_code(value: str) -> str:
    code = clean_text(value, max_len=32).strip().lower()
    if code not in {"new_year", "march_8"}:
        raise HTTPException(status_code=422, detail="holiday_code must be new_year or march_8")
    return code


def _holiday_title(code: str) -> str:
    if code == "new_year":
        return "Новый год"
    if code == "march_8":
        return "8 марта"
    return code


def _validate_preference_refs(cur, *, category_id: Optional[int], product_id: Optional[int]) -> None:
    if (category_id is None and product_id is None) or (category_id is not None and product_id is not None):
        raise HTTPException(status_code=422, detail="Set either category_id or product_id")

    if category_id is not None:
        cat = cur.execute(
            "SELECT id FROM categories WHERE id = ? LIMIT 1",
            (category_id,),
        ).fetchone()
        if not cat:
            raise HTTPException(status_code=404, detail="Category not found")

    if product_id is not None:
        prod = cur.execute(
            """
            SELECT id
            FROM products
            WHERE id = ? AND deleted_at IS NULL
            LIMIT 1
            """,
            (product_id,),
        ).fetchone()
        if not prod:
            raise HTTPException(status_code=404, detail="Product not found")


def _ensure_important_date_access(cur, important_date_id: int, user_id: int):
    row = cur.execute(
        """
        SELECT id, title
        FROM user_important_dates
        WHERE id = ? AND user_id = ?
        LIMIT 1
        """,
        (important_date_id, user_id),
    ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Important date not found")
    return row


@router.get("", summary="Important Dates: List")
def list_important_dates(
    date_from: Optional[str] = Query(default=None, min_length=10, max_length=10),
    date_to: Optional[str] = Query(default=None, min_length=10, max_length=10),
    user=Depends(get_current_user),
):
    if date_from is not None:
        date_from = _parse_iso_date(date_from, "date_from")
    if date_to is not None:
        date_to = _parse_iso_date(date_to, "date_to")
    if date_from and date_to and date_from > date_to:
        raise HTTPException(status_code=400, detail="date_from cannot exceed date_to")

    sql = """
        SELECT id, title, event_date, comment, created_at, updated_at
        FROM user_important_dates
        WHERE user_id = ?
    """
    params: list[object] = [int(user["id"])]
    if date_from is not None:
        sql += " AND event_date >= ?"
        params.append(date_from)
    if date_to is not None:
        sql += " AND event_date <= ?"
        params.append(date_to)
    sql += " ORDER BY event_date ASC, id ASC"

    conn = get_db_connection()
    try:
        rows = conn.execute(sql, tuple(params)).fetchall()
    finally:
        conn.close()

    items = [_serialize(row) for row in rows]
    return {"success": True, "data": {"items": items, "count": len(items)}}


@router.get("/holiday-preferences", summary="Important Dates: Holiday Preferences")
def list_holiday_preferences(
    holiday_code: Optional[str] = Query(default=None, max_length=32),
    user=Depends(get_current_user),
):
    normalized_code = None
    if holiday_code is not None and holiday_code.strip():
        normalized_code = _normalize_holiday_code(holiday_code)

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        sql = """
            SELECT
                hp.id,
                hp.holiday_code,
                hp.category_id,
                c.name AS category_name,
                hp.product_id,
                p.name AS product_name,
                hp.created_at
            FROM user_holiday_preferences hp
            LEFT JOIN categories c ON c.id = hp.category_id
            LEFT JOIN products p ON p.id = hp.product_id
            WHERE hp.user_id = ?
        """
        params: list[object] = [int(user["id"])]
        if normalized_code is not None:
            sql += " AND hp.holiday_code = ?"
            params.append(normalized_code)
        sql += " ORDER BY hp.holiday_code ASC, hp.id DESC"
        rows = cur.execute(sql, tuple(params)).fetchall()
    finally:
        conn.close()

    items = [
        {
            "id": int(row["id"]),
            "holiday_code": row["holiday_code"],
            "holiday_title": _holiday_title(row["holiday_code"]),
            "category_id": row["category_id"],
            "category_name": row["category_name"],
            "product_id": row["product_id"],
            "product_name": row["product_name"],
            "created_at": row["created_at"],
        }
        for row in rows
    ]
    return {"success": True, "data": {"items": items, "count": len(items)}}


@router.post("/holiday-preferences", summary="Important Dates: Add Holiday Preference")
def add_holiday_preference(payload: HolidayPreferenceCreateRequest, user=Depends(get_current_user)):
    code = _normalize_holiday_code(payload.holiday_code)

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        _validate_preference_refs(
            cur,
            category_id=payload.category_id,
            product_id=payload.product_id,
        )
        cur.execute(
            """
            INSERT INTO user_holiday_preferences (user_id, holiday_code, category_id, product_id)
            VALUES (?, ?, ?, ?)
            """,
            (int(user["id"]), code, payload.category_id, payload.product_id),
        )
        pref_id = int(cur.lastrowid)
        row = cur.execute(
            """
            SELECT
                hp.id,
                hp.holiday_code,
                hp.category_id,
                c.name AS category_name,
                hp.product_id,
                p.name AS product_name,
                hp.created_at
            FROM user_holiday_preferences hp
            LEFT JOIN categories c ON c.id = hp.category_id
            LEFT JOIN products p ON p.id = hp.product_id
            WHERE hp.id = ?
            LIMIT 1
            """,
            (pref_id,),
        ).fetchone()
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "id": int(row["id"]),
            "holiday_code": row["holiday_code"],
            "holiday_title": _holiday_title(row["holiday_code"]),
            "category_id": row["category_id"],
            "category_name": row["category_name"],
            "product_id": row["product_id"],
            "product_name": row["product_name"],
            "created_at": row["created_at"],
        },
    }


@router.get("/holiday-preferences/options", summary="Important Dates: Holiday Preference Options")
def holiday_preference_options(user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        categories = cur.execute(
            """
            SELECT id, name
            FROM categories
            ORDER BY name ASC
            """
        ).fetchall()
        products = cur.execute(
            """
            SELECT id, name
            FROM products
            WHERE deleted_at IS NULL
              AND is_active = 1
            ORDER BY name ASC
            LIMIT 500
            """
        ).fetchall()
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "categories": [{"id": int(row["id"]), "name": row["name"]} for row in categories],
            "products": [{"id": int(row["id"]), "name": row["name"]} for row in products],
        },
    }


@router.get("/preferences/options", summary="Important Dates: Date Preference Options")
def important_date_preference_options(user=Depends(get_current_user)):
    return holiday_preference_options(user=user)


@router.get("/{important_date_id}/preferences", summary="Important Dates: List Date Preferences")
def list_important_date_preferences(important_date_id: int, user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        date_row = _ensure_important_date_access(cur, important_date_id, int(user["id"]))
        rows = cur.execute(
            """
            SELECT
                p.id,
                p.important_date_id,
                p.category_id,
                c.name AS category_name,
                p.product_id,
                pr.name AS product_name,
                p.created_at
            FROM user_important_date_preferences p
            LEFT JOIN categories c ON c.id = p.category_id
            LEFT JOIN products pr ON pr.id = p.product_id
            WHERE p.user_id = ? AND p.important_date_id = ?
            ORDER BY p.id DESC
            """,
            (int(user["id"]), important_date_id),
        ).fetchall()
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "important_date": {"id": int(date_row["id"]), "title": date_row["title"]},
            "items": [
                {
                    "id": int(r["id"]),
                    "important_date_id": int(r["important_date_id"]),
                    "category_id": r["category_id"],
                    "category_name": r["category_name"],
                    "product_id": r["product_id"],
                    "product_name": r["product_name"],
                    "created_at": r["created_at"],
                }
                for r in rows
            ],
            "count": len(rows),
        },
    }


@router.post("/{important_date_id}/preferences", summary="Important Dates: Add Date Preference")
def add_important_date_preference(
    important_date_id: int,
    payload: ImportantDatePreferenceCreateRequest,
    user=Depends(get_current_user),
):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        date_row = _ensure_important_date_access(cur, important_date_id, int(user["id"]))
        _validate_preference_refs(cur, category_id=payload.category_id, product_id=payload.product_id)
        cur.execute(
            """
            INSERT INTO user_important_date_preferences (
                user_id, important_date_id, category_id, product_id
            )
            VALUES (?, ?, ?, ?)
            """,
            (int(user["id"]), important_date_id, payload.category_id, payload.product_id),
        )
        pref_id = int(cur.lastrowid)
        row = cur.execute(
            """
            SELECT
                p.id,
                p.important_date_id,
                p.category_id,
                c.name AS category_name,
                p.product_id,
                pr.name AS product_name,
                p.created_at
            FROM user_important_date_preferences p
            LEFT JOIN categories c ON c.id = p.category_id
            LEFT JOIN products pr ON pr.id = p.product_id
            WHERE p.id = ?
            LIMIT 1
            """,
            (pref_id,),
        ).fetchone()
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "important_date": {"id": int(date_row["id"]), "title": date_row["title"]},
            "preference": {
                "id": int(row["id"]),
                "important_date_id": int(row["important_date_id"]),
                "category_id": row["category_id"],
                "category_name": row["category_name"],
                "product_id": row["product_id"],
                "product_name": row["product_name"],
                "created_at": row["created_at"],
            },
        },
    }


@router.delete("/preferences/{preference_id}", summary="Important Dates: Delete Date Preference")
def delete_important_date_preference(preference_id: int, user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        exists = cur.execute(
            """
            SELECT id
            FROM user_important_date_preferences
            WHERE id = ? AND user_id = ?
            LIMIT 1
            """,
            (preference_id, int(user["id"])),
        ).fetchone()
        if not exists:
            raise HTTPException(status_code=404, detail="Date preference not found")
        cur.execute(
            "DELETE FROM user_important_date_preferences WHERE id = ? AND user_id = ?",
            (preference_id, int(user["id"])),
        )
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    return {"success": True, "data": {"deleted": True, "id": preference_id}}


@router.delete("/holiday-preferences/{preference_id}", summary="Important Dates: Delete Holiday Preference")
def delete_holiday_preference(preference_id: int, user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        exists = cur.execute(
            """
            SELECT id
            FROM user_holiday_preferences
            WHERE id = ? AND user_id = ?
            LIMIT 1
            """,
            (preference_id, int(user["id"])),
        ).fetchone()
        if not exists:
            raise HTTPException(status_code=404, detail="Holiday preference not found")
        cur.execute(
            "DELETE FROM user_holiday_preferences WHERE id = ? AND user_id = ?",
            (preference_id, int(user["id"])),
        )
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    return {"success": True, "data": {"deleted": True, "id": preference_id}}


@router.get("/{important_date_id}", summary="Important Dates: Details")
def get_important_date(important_date_id: int, user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        row = conn.execute(
            """
            SELECT id, title, event_date, comment, created_at, updated_at
            FROM user_important_dates
            WHERE id = ? AND user_id = ?
            LIMIT 1
            """,
            (important_date_id, int(user["id"])),
        ).fetchone()
    finally:
        conn.close()

    if not row:
        raise HTTPException(status_code=404, detail="Important date not found")
    return {"success": True, "data": _serialize(row)}


@router.post("", summary="Important Dates: Create")
def create_important_date(payload: ImportantDateCreateRequest, user=Depends(get_current_user)):
    title = clean_text(payload.title, max_len=150)
    if not title:
        raise HTTPException(status_code=422, detail="title is required")
    event_date = _parse_iso_date(payload.event_date, "event_date")
    comment = clean_optional_text(payload.comment, max_len=1000)

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        plan_code = _active_plan_code(cur, int(user["id"]))
        if plan_code == "free":
            cnt = cur.execute(
                "SELECT COUNT(*) AS c FROM user_important_dates WHERE user_id = ?",
                (int(user["id"]),),
            ).fetchone()
            if int(cnt["c"] or 0) >= 5:
                raise HTTPException(
                    status_code=403,
                    detail="Лимит бесплатного тарифа: не более 5 памятных дат. Перейдите на расширенную подписку.",
                )
        cur.execute(
            """
            INSERT INTO user_important_dates (user_id, title, event_date, comment)
            VALUES (?, ?, ?, ?)
            """,
            (int(user["id"]), title, event_date, comment),
        )
        item_id = int(cur.lastrowid)
        row = cur.execute(
            """
            SELECT id, title, event_date, comment, created_at, updated_at
            FROM user_important_dates
            WHERE id = ?
            LIMIT 1
            """,
            (item_id,),
        ).fetchone()
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    return {"success": True, "data": _serialize(row)}


@router.put("/{important_date_id}", summary="Important Dates: Update")
def update_important_date(
    important_date_id: int,
    payload: ImportantDateUpdateRequest,
    user=Depends(get_current_user),
):
    updates: list[str] = []
    params: list[object] = []

    if payload.title is not None:
        title = clean_text(payload.title, max_len=150)
        if not title:
            raise HTTPException(status_code=422, detail="title cannot be empty")
        updates.append("title = ?")
        params.append(title)

    if payload.event_date is not None:
        updates.append("event_date = ?")
        params.append(_parse_iso_date(payload.event_date, "event_date"))

    if payload.comment is not None:
        updates.append("comment = ?")
        params.append(clean_optional_text(payload.comment, max_len=1000))

    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        exists = cur.execute(
            "SELECT id FROM user_important_dates WHERE id = ? AND user_id = ? LIMIT 1",
            (important_date_id, int(user["id"])),
        ).fetchone()
        if not exists:
            raise HTTPException(status_code=404, detail="Important date not found")

        cur.execute(
            f"UPDATE user_important_dates SET {', '.join(updates)} WHERE id = ? AND user_id = ?",
            (*params, important_date_id, int(user["id"])),
        )
        row = cur.execute(
            """
            SELECT id, title, event_date, comment, created_at, updated_at
            FROM user_important_dates
            WHERE id = ? AND user_id = ?
            LIMIT 1
            """,
            (important_date_id, int(user["id"])),
        ).fetchone()
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    return {"success": True, "data": _serialize(row)}


@router.delete("/{important_date_id}", summary="Important Dates: Delete")
def delete_important_date(important_date_id: int, user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        exists = cur.execute(
            "SELECT id FROM user_important_dates WHERE id = ? AND user_id = ? LIMIT 1",
            (important_date_id, int(user["id"])),
        ).fetchone()
        if not exists:
            raise HTTPException(status_code=404, detail="Important date not found")

        cur.execute(
            "DELETE FROM user_important_dates WHERE id = ? AND user_id = ?",
            (important_date_id, int(user["id"])),
        )
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    return {"success": True, "data": {"deleted": True, "id": important_date_id}}
