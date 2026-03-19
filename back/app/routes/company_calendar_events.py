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
