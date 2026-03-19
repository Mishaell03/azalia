from __future__ import annotations

from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, ConfigDict, Field

from app.db import get_db_connection
from app.routes.utils import clean_optional_text, clean_text, get_current_user

router = APIRouter(prefix="/api/company-calendar-events", tags=["company-calendar-events"])


class CompanyCalendarEventCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    company_id: int = Field(ge=1)
    title: str = Field(min_length=1, max_length=150)
    event_date: str = Field(min_length=10, max_length=10)
    comment: Optional[str] = Field(default=None, max_length=1000)


class CompanyCalendarEventUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: Optional[str] = Field(default=None, min_length=1, max_length=150)
    event_date: Optional[str] = Field(default=None, min_length=10, max_length=10)
    comment: Optional[str] = Field(default=None, max_length=1000)


class CompanyCalendarPreferenceCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    category_id: Optional[int] = Field(default=None, ge=1)
    product_id: Optional[int] = Field(default=None, ge=1)


def _parse_iso_date(value: str, field_name: str) -> str:
    text = clean_text(value, max_len=16)
    try:
        return datetime.strptime(text, "%Y-%m-%d").strftime("%Y-%m-%d")
    except ValueError:
        raise HTTPException(status_code=422, detail=f"{field_name} must be YYYY-MM-DD")


def _user_has_corporate_plan(cur, user_id: int) -> bool:
    row = cur.execute(
        """
        SELECT sp.has_corporate
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
    return bool(row and row["has_corporate"])


def _company_memberships(cur, user_id: int) -> list[dict]:
    rows = cur.execute(
        """
        SELECT
            cm.company_id,
            c.name AS company_name,
            cm.role
        FROM company_members cm
        JOIN companies c ON c.id = cm.company_id
        WHERE cm.user_id = ?
          AND cm.is_active = 1
          AND c.status = 'active'
        ORDER BY c.name ASC, cm.company_id ASC
        """,
        (user_id,),
    ).fetchall()
    return [
        {
            "company_id": int(row["company_id"]),
            "company_name": row["company_name"],
            "role": row["role"],
        }
        for row in rows
    ]


def _require_company_member(cur, *, company_id: int, user_id: int) -> None:
    row = cur.execute(
        """
        SELECT 1
        FROM company_members cm
        JOIN companies c ON c.id = cm.company_id
        WHERE cm.company_id = ?
          AND cm.user_id = ?
          AND cm.is_active = 1
          AND c.status = 'active'
        LIMIT 1
        """,
        (company_id, user_id),
    ).fetchone()
    if not row:
        raise HTTPException(status_code=403, detail="Нет доступа к календарю организации")


def _serialize(row) -> dict:
    return {
        "id": int(row["id"]),
        "company_id": int(row["company_id"]),
        "company_name": row["company_name"],
        "title": row["title"],
        "event_date": row["event_date"],
        "comment": row["comment"],
        "created_by_user_id": int(row["created_by_user_id"]),
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


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


def _ensure_event_access(cur, event_id: int, user_id: int):
    row = cur.execute(
        """
        SELECT e.id, e.company_id, e.title
        FROM company_calendar_events e
        JOIN companies c ON c.id = e.company_id
        JOIN company_members cm ON cm.company_id = e.company_id
        WHERE e.id = ?
          AND cm.user_id = ?
          AND cm.is_active = 1
          AND c.status = 'active'
        LIMIT 1
        """,
        (event_id, user_id),
    ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Company event not found")
    return row


@router.get("/organizations", summary="Company Calendar: My Organizations")
def get_my_organizations(user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        memberships = _company_memberships(cur, int(user["id"]))
        can_use_corporate = _user_has_corporate_plan(cur, int(user["id"]))
    finally:
        conn.close()
    return {
        "success": True,
        "data": {
            "can_use_corporate": can_use_corporate,
            "items": memberships,
            "count": len(memberships),
        },
    }


@router.get("", summary="Company Calendar: List")
def list_company_events(
    company_id: int = Query(ge=1),
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

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        _require_company_member(cur, company_id=company_id, user_id=int(user["id"]))

        sql = """
            SELECT
                e.id,
                e.company_id,
                c.name AS company_name,
                e.title,
                e.event_date,
                e.comment,
                e.created_by_user_id,
                e.created_at,
                e.updated_at
            FROM company_calendar_events e
            JOIN companies c ON c.id = e.company_id
            WHERE e.company_id = ?
        """
        params: list[object] = [company_id]
        if date_from is not None:
            sql += " AND e.event_date >= ?"
            params.append(date_from)
        if date_to is not None:
            sql += " AND e.event_date <= ?"
            params.append(date_to)
        sql += " ORDER BY e.event_date ASC, e.id ASC"
        rows = cur.execute(sql, tuple(params)).fetchall()
    finally:
        conn.close()

    items = [_serialize(row) for row in rows]
    return {"success": True, "data": {"items": items, "count": len(items)}}


@router.post("", summary="Company Calendar: Create")
def create_company_event(payload: CompanyCalendarEventCreateRequest, user=Depends(get_current_user)):
    title = clean_text(payload.title, max_len=150)
    if not title:
        raise HTTPException(status_code=422, detail="title is required")
    event_date = _parse_iso_date(payload.event_date, "event_date")
    comment = clean_optional_text(payload.comment, max_len=1000)

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        _require_company_member(cur, company_id=int(payload.company_id), user_id=int(user["id"]))
        if not _user_has_corporate_plan(cur, int(user["id"])):
            raise HTTPException(
                status_code=403,
                detail="Корпоративный календарь доступен только на расширенной подписке.",
            )

        cur.execute(
            """
            INSERT INTO company_calendar_events (
                company_id, title, event_date, comment, created_by_user_id
            )
            VALUES (?, ?, ?, ?, ?)
            """,
            (int(payload.company_id), title, event_date, comment, int(user["id"])),
        )
        item_id = int(cur.lastrowid)
        row = cur.execute(
            """
            SELECT
                e.id,
                e.company_id,
                c.name AS company_name,
                e.title,
                e.event_date,
                e.comment,
                e.created_by_user_id,
                e.created_at,
                e.updated_at
            FROM company_calendar_events e
            JOIN companies c ON c.id = e.company_id
            WHERE e.id = ?
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


@router.put("/{event_id}", summary="Company Calendar: Update")
def update_company_event(
    event_id: int,
    payload: CompanyCalendarEventUpdateRequest,
    user=Depends(get_current_user),
):
    updates: list[str] = []
    params: list[object] = []

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        row = cur.execute(
            "SELECT id, company_id FROM company_calendar_events WHERE id = ? LIMIT 1",
            (event_id,),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Company event not found")
        company_id = int(row["company_id"])
        _require_company_member(cur, company_id=company_id, user_id=int(user["id"]))
        if not _user_has_corporate_plan(cur, int(user["id"])):
            raise HTTPException(
                status_code=403,
                detail="Корпоративный календарь доступен только на расширенной подписке.",
            )

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

        cur.execute(
            f"UPDATE company_calendar_events SET {', '.join(updates)} WHERE id = ?",
            (*params, event_id),
        )
        updated = cur.execute(
            """
            SELECT
                e.id,
                e.company_id,
                c.name AS company_name,
                e.title,
                e.event_date,
                e.comment,
                e.created_by_user_id,
                e.created_at,
                e.updated_at
            FROM company_calendar_events e
            JOIN companies c ON c.id = e.company_id
            WHERE e.id = ?
            LIMIT 1
            """,
            (event_id,),
        ).fetchone()
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    return {"success": True, "data": _serialize(updated)}


@router.delete("/{event_id}", summary="Company Calendar: Delete")
def delete_company_event(event_id: int, user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        row = cur.execute(
            "SELECT id, company_id FROM company_calendar_events WHERE id = ? LIMIT 1",
            (event_id,),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Company event not found")
        _require_company_member(cur, company_id=int(row["company_id"]), user_id=int(user["id"]))

        cur.execute("DELETE FROM company_calendar_events WHERE id = ?", (event_id,))
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    return {"success": True, "data": {"deleted": True, "id": event_id}}


@router.get("/preferences/options", summary="Company Calendar: Preference Options")
def company_event_preference_options(user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        memberships = _company_memberships(cur, int(user["id"]))
        if not memberships:
            return {
                "success": True,
                "data": {"categories": [], "products": []},
            }

        categories = cur.execute(
            """
            SELECT id, name
            FROM categories
            ORDER BY name ASC
            LIMIT 200
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


@router.get("/{event_id}/preferences", summary="Company Calendar: List Event Preferences")
def list_company_event_preferences(event_id: int, user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        event_row = _ensure_event_access(cur, event_id, int(user["id"]))
        rows = cur.execute(
            """
            SELECT
                p.id,
                p.company_event_id,
                p.category_id,
                c.name AS category_name,
                p.product_id,
                pr.name AS product_name,
                p.created_at
            FROM company_calendar_event_preferences p
            LEFT JOIN categories c ON c.id = p.category_id
            LEFT JOIN products pr ON pr.id = p.product_id
            WHERE p.user_id = ? AND p.company_event_id = ?
            ORDER BY p.id DESC
            """,
            (int(user["id"]), event_id),
        ).fetchall()
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "event": {
                "id": int(event_row["id"]),
                "company_id": int(event_row["company_id"]),
                "title": event_row["title"],
            },
            "items": [
                {
                    "id": int(r["id"]),
                    "company_event_id": int(r["company_event_id"]),
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


@router.post("/{event_id}/preferences", summary="Company Calendar: Add Event Preference")
def add_company_event_preference(
    event_id: int,
    payload: CompanyCalendarPreferenceCreateRequest,
    user=Depends(get_current_user),
):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        event_row = _ensure_event_access(cur, event_id, int(user["id"]))
        if not _user_has_corporate_plan(cur, int(user["id"])):
            raise HTTPException(
                status_code=403,
                detail="Предпочтения доступны только на расширенной подписке.",
            )

        _validate_preference_refs(
            cur,
            category_id=payload.category_id,
            product_id=payload.product_id,
        )
        cur.execute(
            """
            INSERT INTO company_calendar_event_preferences (
                user_id, company_event_id, category_id, product_id
            )
            VALUES (?, ?, ?, ?)
            """,
            (int(user["id"]), event_id, payload.category_id, payload.product_id),
        )
        pref_id = int(cur.lastrowid)
        row = cur.execute(
            """
            SELECT
                p.id,
                p.company_event_id,
                p.category_id,
                c.name AS category_name,
                p.product_id,
                pr.name AS product_name,
                p.created_at
            FROM company_calendar_event_preferences p
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
            "event": {
                "id": int(event_row["id"]),
                "company_id": int(event_row["company_id"]),
                "title": event_row["title"],
            },
            "preference": {
                "id": int(row["id"]),
                "company_event_id": int(row["company_event_id"]),
                "category_id": row["category_id"],
                "category_name": row["category_name"],
                "product_id": row["product_id"],
                "product_name": row["product_name"],
                "created_at": row["created_at"],
            },
        },
    }


@router.delete("/preferences/{preference_id}", summary="Company Calendar: Delete Event Preference")
def delete_company_event_preference(preference_id: int, user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        exists = cur.execute(
            """
            SELECT p.id
            FROM company_calendar_event_preferences p
            JOIN company_calendar_events e ON e.id = p.company_event_id
            JOIN company_members cm ON cm.company_id = e.company_id
            JOIN companies c ON c.id = e.company_id
            WHERE p.id = ?
              AND p.user_id = ?
              AND cm.user_id = ?
              AND cm.is_active = 1
              AND c.status = 'active'
            LIMIT 1
            """,
            (preference_id, int(user["id"]), int(user["id"])),
        ).fetchone()
        if not exists:
            raise HTTPException(status_code=404, detail="Event preference not found")
        cur.execute(
            "DELETE FROM company_calendar_event_preferences WHERE id = ? AND user_id = ?",
            (preference_id, int(user["id"])),
        )
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    return {"success": True, "data": {"deleted": True, "id": preference_id}}
