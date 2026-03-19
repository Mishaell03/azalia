from __future__ import annotations

from datetime import date, datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, ConfigDict, Field

from app.db import get_db_connection
from app.routes.plant_care_common import (
    DEFAULT_PLANT_IMAGE_PATH,
    derive_soil_change_frequency_days,
    derive_watering_frequency_days,
    next_due_date,
    normalize_care_type,
    normalize_watering_requirement,
    parse_iso_date,
    resolve_photo_url,
)
from app.routes.utils import clean_optional_text, clean_text, get_current_user

router = APIRouter(prefix="/api/plant-care-dates", tags=["plant-care-dates"])


class PlantCareDateCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    user_plant_id: Optional[int] = Field(default=None, ge=1)
    product_id: Optional[int] = Field(default=None, ge=1)
    plant_name: Optional[str] = Field(default=None, min_length=1, max_length=150)
    plant_photo_url: Optional[str] = Field(default=None, max_length=500)
    watering_requirement: Optional[str] = Field(default=None, max_length=64)
    care_type: str = Field(min_length=1, max_length=32)
    care_date: str = Field(min_length=10, max_length=10)
    comment: Optional[str] = Field(default=None, max_length=1000)
    is_done: bool = False


class PlantCareDateUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    user_plant_id: Optional[int] = Field(default=None, ge=1)
    product_id: Optional[int] = Field(default=None, ge=1)
    plant_name: Optional[str] = Field(default=None, min_length=1, max_length=150)
    plant_photo_url: Optional[str] = Field(default=None, max_length=500)
    watering_requirement: Optional[str] = Field(default=None, max_length=64)
    care_type: Optional[str] = Field(default=None, min_length=1, max_length=32)
    care_date: Optional[str] = Field(default=None, min_length=10, max_length=10)
    comment: Optional[str] = Field(default=None, max_length=1000)
    is_done: Optional[bool] = None


def _validate_product(cur, product_id: Optional[int]):
    if product_id is None:
        return None
    row = cur.execute(
        """
        SELECT id, image_url
        FROM products
        WHERE id = ? AND deleted_at IS NULL
        LIMIT 1
        """,
        (product_id,),
    ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Product not found")
    return row


def _fetch_user_plant(cur, user_id: int, user_plant_id: Optional[int]):
    if user_plant_id is None:
        return None
    row = cur.execute(
        """
        SELECT
            id,
            user_id,
            product_id,
            custom_name,
            plant_name,
            photo_url,
            watering_requirement,
            watering_frequency_days,
            soil_change_frequency_days,
            last_watered_at,
            next_watering_at,
            last_soil_change_at,
            next_soil_change_at
        FROM user_plants
        WHERE id = ? AND user_id = ?
        LIMIT 1
        """,
        (user_plant_id, user_id),
    ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="User plant not found")
    return row


def _serialize(row) -> dict:
    raw_photo = (row["plant_photo_url"] or "").strip() if row["plant_photo_url"] is not None else ""
    return {
        "id": int(row["id"]),
        "user_plant_id": row["user_plant_id"],
        "product_id": row["product_id"],
        "plant_name": row["plant_name"],
        "plant_photo_url": raw_photo or DEFAULT_PLANT_IMAGE_PATH,
        "watering_requirement": row["watering_requirement"],
        "care_type": row["care_type"],
        "care_date": row["care_date"],
        "comment": row["comment"],
        "is_done": bool(row["is_done"]),
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


def _parse_date_obj(value: str) -> date:
    return datetime.strptime(value, "%Y-%m-%d").date()


def _iter_due_dates(next_due: Optional[str], frequency_days: Optional[int], window_start: date, window_end: date):
    if not next_due or frequency_days is None:
        return
    freq = int(frequency_days)
    if freq <= 0:
        return
    try:
        current = _parse_date_obj(next_due)
    except ValueError:
        return

    guard = 0
    while current <= window_end and guard < 400:
        if current >= window_start:
            yield current.strftime("%Y-%m-%d")
        current = current + timedelta(days=freq)
        guard += 1


def _iter_pruning_dates(window_start: date, window_end: date):
    # Twice a year: spring and autumn.
    season_days = ((3, 15), (9, 15))
    for year in range(window_start.year, window_end.year + 1):
        for month, day in season_days:
            dt = date(year, month, day)
            if window_start <= dt <= window_end:
                yield dt.strftime("%Y-%m-%d")


def _clear_future_auto_tasks(
    cur,
    *,
    user_id: int,
    user_plant_id: int,
    care_type: str,
    from_date: str,
) -> None:
    cur.execute(
        """
        DELETE FROM user_plant_care_dates
        WHERE user_id = ?
          AND user_plant_id = ?
          AND care_type = ?
          AND is_done = 0
          AND care_date >= ?
          AND comment LIKE 'Авто:%'
        """,
        (user_id, user_plant_id, care_type, from_date),
    )


def _sync_auto_tasks(cur, user_id: int, window_start: str, window_end: str) -> None:
    start = _parse_date_obj(window_start)
    end = _parse_date_obj(window_end)

    rows = cur.execute(
        """
        SELECT
            id,
            product_id,
            custom_name,
            plant_name,
            photo_url,
            watering_requirement,
            watering_frequency_days,
            soil_change_frequency_days,
            next_watering_at,
            next_soil_change_at
        FROM user_plants
        WHERE user_id = ?
        """,
        (user_id,),
    ).fetchall()

    existing_rows = cur.execute(
        """
        SELECT user_plant_id, care_type, care_date
        FROM user_plant_care_dates
        WHERE user_id = ?
          AND user_plant_id IS NOT NULL
          AND care_date >= ?
          AND care_date <= ?
        """,
        (user_id, window_start, window_end),
    ).fetchall()

    existing = {
        (int(row["user_plant_id"]), str(row["care_type"]), str(row["care_date"]))
        for row in existing_rows
        if row["user_plant_id"] is not None
    }

    for row in rows:
        user_plant_id = int(row["id"])
        plant_name = clean_text(row["custom_name"] or row["plant_name"], max_len=150)
        photo = resolve_photo_url(row["photo_url"], fallback=DEFAULT_PLANT_IMAGE_PATH)
        req = normalize_watering_requirement(row["watering_requirement"])

        for due in _iter_due_dates(row["next_watering_at"], row["watering_frequency_days"], start, end):
            key = (user_plant_id, "watering", due)
            if key in existing:
                continue
            cur.execute(
                """
                INSERT INTO user_plant_care_dates (
                    user_id,
                    user_plant_id,
                    product_id,
                    plant_name,
                    plant_photo_url,
                    watering_requirement,
                    care_type,
                    care_date,
                    comment,
                    is_done
                )
                VALUES (?, ?, ?, ?, ?, ?, 'watering', ?, ?, 0)
                """,
                (
                    user_id,
                    user_plant_id,
                    row["product_id"],
                    plant_name,
                    photo,
                    req,
                    due,
                    "Авто: полив по графику",
                ),
            )
            existing.add(key)

        for due in _iter_due_dates(row["next_soil_change_at"], row["soil_change_frequency_days"], start, end):
            key = (user_plant_id, "soil_change", due)
            if key in existing:
                continue
            cur.execute(
                """
                INSERT INTO user_plant_care_dates (
                    user_id,
                    user_plant_id,
                    product_id,
                    plant_name,
                    plant_photo_url,
                    watering_requirement,
                    care_type,
                    care_date,
                    comment,
                    is_done
                )
                VALUES (?, ?, ?, ?, ?, ?, 'soil_change', ?, ?, 0)
                """,
                (
                    user_id,
                    user_plant_id,
                    row["product_id"],
                    plant_name,
                    photo,
                    req,
                    due,
                    "Авто: смена грунта по графику",
                ),
            )
            existing.add(key)

        for due in _iter_pruning_dates(start, end):
            key = (user_plant_id, "pruning", due)
            if key in existing:
                continue
            cur.execute(
                """
                INSERT INTO user_plant_care_dates (
                    user_id,
                    user_plant_id,
                    product_id,
                    plant_name,
                    plant_photo_url,
                    watering_requirement,
                    care_type,
                    care_date,
                    comment,
                    is_done
                )
                VALUES (?, ?, ?, ?, ?, ?, 'pruning', ?, ?, 0)
                """,
                (
                    user_id,
                    user_plant_id,
                    row["product_id"],
                    plant_name,
                    photo,
                    req,
                    due,
                    "Авто: сезонная подрезка (весна/осень)",
                ),
            )
            existing.add(key)


def _touch_user_plant_after_done(cur, user_id: int, task_row) -> None:
    user_plant_id = task_row["user_plant_id"]
    if user_plant_id is None:
        return

    plant = _fetch_user_plant(cur, user_id, int(user_plant_id))
    care_type = str(task_row["care_type"])
    care_date = str(task_row["care_date"])

    if care_type == "watering":
        watering_requirement = normalize_watering_requirement(plant["watering_requirement"])
        wf = derive_watering_frequency_days(watering_requirement, plant["watering_frequency_days"])
        next_watering_at = next_due_date(care_date, wf)
        _clear_future_auto_tasks(
            cur,
            user_id=user_id,
            user_plant_id=int(user_plant_id),
            care_type="watering",
            from_date=care_date,
        )
        cur.execute(
            """
            UPDATE user_plants
            SET
                watering_requirement = ?,
                watering_frequency_days = ?,
                last_watered_at = ?,
                next_watering_at = ?
            WHERE id = ? AND user_id = ?
            """,
            (watering_requirement, wf, care_date, next_watering_at, int(user_plant_id), user_id),
        )

    if care_type == "soil_change":
        watering_requirement = normalize_watering_requirement(plant["watering_requirement"])
        wf = derive_watering_frequency_days(watering_requirement, plant["watering_frequency_days"])
        sf = derive_soil_change_frequency_days(wf, plant["soil_change_frequency_days"])
        next_soil_change_at = next_due_date(care_date, sf)
        _clear_future_auto_tasks(
            cur,
            user_id=user_id,
            user_plant_id=int(user_plant_id),
            care_type="soil_change",
            from_date=care_date,
        )
        cur.execute(
            """
            UPDATE user_plants
            SET
                watering_requirement = ?,
                watering_frequency_days = ?,
                soil_change_frequency_days = ?,
                last_soil_change_at = ?,
                next_soil_change_at = ?
            WHERE id = ? AND user_id = ?
            """,
            (watering_requirement, wf, sf, care_date, next_soil_change_at, int(user_plant_id), user_id),
        )

    if care_type in {"watering", "repotting", "soil_change"}:
        exists = cur.execute(
            """
            SELECT id
            FROM user_plant_care_logs
            WHERE user_plant_id = ?
              AND care_type = ?
              AND care_at = ?
            LIMIT 1
            """,
            (int(user_plant_id), care_type, care_date),
        ).fetchone()
        if not exists:
            cur.execute(
                """
                INSERT INTO user_plant_care_logs (user_plant_id, care_type, care_at, notes)
                VALUES (?, ?, ?, ?)
                """,
                (int(user_plant_id), care_type, care_date, task_row["comment"]),
            )


def _auto_window(date_from: Optional[str], date_to: Optional[str]) -> tuple[str, str]:
    if date_from and date_to:
        return date_from, date_to

    today = date.today()
    month_start = date(today.year, today.month, 1)
    if today.month == 12:
        month_end = date(today.year + 1, 1, 1) - timedelta(days=1)
    else:
        month_end = date(today.year, today.month + 1, 1) - timedelta(days=1)
    return month_start.strftime("%Y-%m-%d"), (month_end + timedelta(days=31)).strftime("%Y-%m-%d")


@router.get("", summary="Plant Care Dates: List")
def list_plant_care_dates(
    care_type: Optional[str] = Query(default=None),
    date_from: Optional[str] = Query(default=None, min_length=10, max_length=10),
    date_to: Optional[str] = Query(default=None, min_length=10, max_length=10),
    is_done: Optional[bool] = Query(default=None),
    user=Depends(get_current_user),
):
    normalized_care_type: Optional[str] = None
    if care_type is not None:
        normalized_care_type = normalize_care_type(care_type, "care_type")
    if date_from is not None:
        date_from = parse_iso_date(date_from, "date_from")
    if date_to is not None:
        date_to = parse_iso_date(date_to, "date_to")
    if date_from and date_to and date_from > date_to:
        raise HTTPException(status_code=400, detail="date_from cannot exceed date_to")

    user_id = int(user["id"])
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        sync_from, sync_to = _auto_window(date_from, date_to)
        _sync_auto_tasks(cur, user_id, sync_from, sync_to)

        sql = """
            SELECT
                id,
                user_plant_id,
                product_id,
                plant_name,
                plant_photo_url,
                watering_requirement,
                care_type,
                care_date,
                comment,
                is_done,
                created_at,
                updated_at
            FROM user_plant_care_dates
            WHERE user_id = ?
        """
        params: list[object] = [user_id]
        if normalized_care_type is not None:
            sql += " AND care_type = ?"
            params.append(normalized_care_type)
        if date_from is not None:
            sql += " AND care_date >= ?"
            params.append(date_from)
        if date_to is not None:
            sql += " AND care_date <= ?"
            params.append(date_to)
        if is_done is not None:
            sql += " AND is_done = ?"
            params.append(1 if is_done else 0)
        sql += " ORDER BY care_date ASC, id ASC"

        rows = cur.execute(sql, tuple(params)).fetchall()
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    items = [_serialize(row) for row in rows]
    return {"success": True, "data": {"items": items, "count": len(items)}}


@router.get("/{care_date_id}", summary="Plant Care Dates: Details")
def get_plant_care_date(care_date_id: int, user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        row = conn.execute(
            """
            SELECT
                id,
                user_plant_id,
                product_id,
                plant_name,
                plant_photo_url,
                watering_requirement,
                care_type,
                care_date,
                comment,
                is_done,
                created_at,
                updated_at
            FROM user_plant_care_dates
            WHERE id = ? AND user_id = ?
            LIMIT 1
            """,
            (care_date_id, int(user["id"])),
        ).fetchone()
    finally:
        conn.close()

    if not row:
        raise HTTPException(status_code=404, detail="Plant care date not found")
    return {"success": True, "data": _serialize(row)}


@router.post("", summary="Plant Care Dates: Create")
def create_plant_care_date(payload: PlantCareDateCreateRequest, user=Depends(get_current_user)):
    user_id = int(user["id"])
    care_type = normalize_care_type(payload.care_type, "care_type")
    care_date = parse_iso_date(payload.care_date, "care_date")
    comment = clean_optional_text(payload.comment, max_len=1000)

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        plan_code = _active_plan_code(cur, user_id)
        if plan_code == "free":
            cnt = cur.execute(
                "SELECT COUNT(*) AS c FROM user_plant_care_dates WHERE user_id = ?",
                (user_id,),
            ).fetchone()
            if int(cnt["c"] or 0) >= 200:
                raise HTTPException(
                    status_code=403,
                    detail=(
                        "Лимит бесплатного тарифа: не более 200 задач по уходу. "
                        "Перейдите на расширенную подписку."
                    ),
                )

        selected_plant = _fetch_user_plant(cur, user_id, payload.user_plant_id)
        product = _validate_product(cur, payload.product_id)

        product_id = payload.product_id
        if selected_plant is not None and product_id is None:
            product_id = selected_plant["product_id"]

        resolved_name = payload.plant_name
        if selected_plant is not None and (resolved_name is None or not resolved_name.strip()):
            resolved_name = selected_plant["custom_name"] or selected_plant["plant_name"]
        plant_name = clean_text(resolved_name, max_len=150)
        if not plant_name:
            raise HTTPException(status_code=422, detail="plant_name is required")

        selected_photo = selected_plant["photo_url"] if selected_plant is not None else None
        product_photo = product["image_url"] if product is not None else None
        photo_url = resolve_photo_url(payload.plant_photo_url, fallback=selected_photo or product_photo)

        raw_requirement = payload.watering_requirement
        if raw_requirement is None and selected_plant is not None:
            raw_requirement = selected_plant["watering_requirement"]
        watering_requirement = normalize_watering_requirement(raw_requirement)

        cur.execute(
            """
            INSERT INTO user_plant_care_dates (
                user_id,
                user_plant_id,
                product_id,
                plant_name,
                plant_photo_url,
                watering_requirement,
                care_type,
                care_date,
                comment,
                is_done
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                user_id,
                payload.user_plant_id,
                product_id,
                plant_name,
                photo_url,
                watering_requirement,
                care_type,
                care_date,
                comment,
                1 if payload.is_done else 0,
            ),
        )
        item_id = int(cur.lastrowid)
        row = cur.execute(
            """
            SELECT
                id,
                user_plant_id,
                product_id,
                plant_name,
                plant_photo_url,
                watering_requirement,
                care_type,
                care_date,
                comment,
                is_done,
                created_at,
                updated_at
            FROM user_plant_care_dates
            WHERE id = ?
            LIMIT 1
            """,
            (item_id,),
        ).fetchone()

        if bool(row["is_done"]):
            _touch_user_plant_after_done(cur, user_id, row)

        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    return {"success": True, "data": _serialize(row)}


@router.put("/{care_date_id}", summary="Plant Care Dates: Update")
def update_plant_care_date(
    care_date_id: int,
    payload: PlantCareDateUpdateRequest,
    user=Depends(get_current_user),
):
    user_id = int(user["id"])
    provided = payload.model_fields_set
    updates: list[str] = []
    params: list[object] = []

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        existing = cur.execute(
            """
            SELECT
                id,
                user_plant_id,
                product_id,
                plant_name,
                plant_photo_url,
                watering_requirement,
                care_type,
                care_date,
                comment,
                is_done,
                created_at,
                updated_at
            FROM user_plant_care_dates
            WHERE id = ? AND user_id = ?
            LIMIT 1
            """,
            (care_date_id, user_id),
        ).fetchone()
        if not existing:
            raise HTTPException(status_code=404, detail="Plant care date not found")

        selected_plant = None
        if "user_plant_id" in provided:
            selected_plant = _fetch_user_plant(cur, user_id, payload.user_plant_id)
            updates.append("user_plant_id = ?")
            params.append(payload.user_plant_id)

        if "product_id" in provided:
            product = _validate_product(cur, payload.product_id)
            updates.append("product_id = ?")
            params.append(payload.product_id)
        else:
            product = _validate_product(cur, existing["product_id"])

        if "plant_name" in provided:
            plant_name = clean_text(payload.plant_name, max_len=150)
            if not plant_name:
                raise HTTPException(status_code=422, detail="plant_name cannot be empty")
            updates.append("plant_name = ?")
            params.append(plant_name)
        elif selected_plant is not None:
            hydrated_name = clean_text(selected_plant["custom_name"] or selected_plant["plant_name"], max_len=150)
            if hydrated_name:
                updates.append("plant_name = ?")
                params.append(hydrated_name)

        if "care_type" in provided:
            updates.append("care_type = ?")
            params.append(normalize_care_type(payload.care_type or "", "care_type"))

        if "care_date" in provided:
            updates.append("care_date = ?")
            params.append(parse_iso_date(payload.care_date or "", "care_date"))

        if "comment" in provided:
            updates.append("comment = ?")
            params.append(clean_optional_text(payload.comment, max_len=1000))

        if "is_done" in provided:
            updates.append("is_done = ?")
            params.append(1 if payload.is_done else 0)

        if "plant_photo_url" in provided:
            selected_photo = selected_plant["photo_url"] if selected_plant is not None else None
            product_photo = product["image_url"] if product is not None else None
            updates.append("plant_photo_url = ?")
            params.append(resolve_photo_url(payload.plant_photo_url, fallback=selected_photo or product_photo))
        elif selected_plant is not None:
            updates.append("plant_photo_url = ?")
            params.append(resolve_photo_url(selected_plant["photo_url"], fallback=DEFAULT_PLANT_IMAGE_PATH))

        if "watering_requirement" in provided:
            updates.append("watering_requirement = ?")
            params.append(normalize_watering_requirement(payload.watering_requirement))
        elif selected_plant is not None:
            updates.append("watering_requirement = ?")
            params.append(normalize_watering_requirement(selected_plant["watering_requirement"]))

        if not updates:
            raise HTTPException(status_code=400, detail="No fields to update")

        cur.execute(
            f"UPDATE user_plant_care_dates SET {', '.join(updates)} WHERE id = ? AND user_id = ?",
            (*params, care_date_id, user_id),
        )
        row = cur.execute(
            """
            SELECT
                id,
                user_plant_id,
                product_id,
                plant_name,
                plant_photo_url,
                watering_requirement,
                care_type,
                care_date,
                comment,
                is_done,
                created_at,
                updated_at
            FROM user_plant_care_dates
            WHERE id = ? AND user_id = ?
            LIMIT 1
            """,
            (care_date_id, user_id),
        ).fetchone()

        if bool(row["is_done"]):
            _touch_user_plant_after_done(cur, user_id, row)

        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    return {"success": True, "data": _serialize(row)}


@router.delete("/{care_date_id}", summary="Plant Care Dates: Delete")
def delete_plant_care_date(care_date_id: int, user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        exists = cur.execute(
            "SELECT id FROM user_plant_care_dates WHERE id = ? AND user_id = ? LIMIT 1",
            (care_date_id, int(user["id"])),
        ).fetchone()
        if not exists:
            raise HTTPException(status_code=404, detail="Plant care date not found")

        cur.execute(
            "DELETE FROM user_plant_care_dates WHERE id = ? AND user_id = ?",
            (care_date_id, int(user["id"])),
        )
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    return {"success": True, "data": {"deleted": True, "id": care_date_id}}
