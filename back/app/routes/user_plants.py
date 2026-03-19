from __future__ import annotations

import os
import uuid
from pathlib import Path as FsPath
from typing import Optional

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from pydantic import BaseModel, ConfigDict, Field

from app.config import BASE_DIR
from app.db import get_db_connection
from app.routes.plant_care_common import (
    ALLOWED_CARE_TYPES,
    DEFAULT_PLANT_IMAGE_PATH,
    derive_soil_change_frequency_days,
    derive_watering_frequency_days,
    next_due_date,
    normalize_care_type,
    normalize_watering_requirement,
    parse_optional_iso_date,
    resolve_photo_url,
    today_iso,
)
from app.routes.utils import clean_optional_text, clean_text, get_current_user

router = APIRouter(prefix="/api/user-plants", tags=["user-plants"])

ALLOWED_IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".gif", ".webp"}
MAX_IMAGE_SIZE_BYTES = 16 * 1024 * 1024


class UserPlantCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    product_id: Optional[int] = Field(default=None, ge=1)
    plant_name: Optional[str] = Field(default=None, min_length=1, max_length=150)
    custom_name: Optional[str] = Field(default=None, max_length=150)
    photo_url: Optional[str] = Field(default=None, max_length=500)
    watering_requirement: Optional[str] = Field(default=None, max_length=64)
    watering_frequency_days: Optional[int] = Field(default=None, ge=1, le=120)
    soil_change_frequency_days: Optional[int] = Field(default=None, ge=1, le=730)
    last_watered_at: Optional[str] = Field(default=None, max_length=10)
    last_soil_change_at: Optional[str] = Field(default=None, max_length=10)
    notes: Optional[str] = Field(default=None, max_length=1000)


class UserPlantUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    product_id: Optional[int] = Field(default=None, ge=1)
    plant_name: Optional[str] = Field(default=None, min_length=1, max_length=150)
    custom_name: Optional[str] = Field(default=None, max_length=150)
    photo_url: Optional[str] = Field(default=None, max_length=500)
    watering_requirement: Optional[str] = Field(default=None, max_length=64)
    watering_frequency_days: Optional[int] = Field(default=None, ge=1, le=120)
    soil_change_frequency_days: Optional[int] = Field(default=None, ge=1, le=730)
    last_watered_at: Optional[str] = Field(default=None, max_length=10)
    last_soil_change_at: Optional[str] = Field(default=None, max_length=10)
    notes: Optional[str] = Field(default=None, max_length=1000)


class UserPlantCareMarkRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    care_type: str = Field(default="watering", min_length=1, max_length=32)
    care_date: Optional[str] = Field(default=None, max_length=10)
    notes: Optional[str] = Field(default=None, max_length=1000)


def _active_plan_max_plants(cur, user_id: int) -> int:
    row = cur.execute(
        """
        SELECT sp.max_plants
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
    if row and row["max_plants"] is not None:
        return max(1, int(row["max_plants"]))

    free_row = cur.execute(
        "SELECT max_plants FROM subscription_plans WHERE code = 'free' LIMIT 1"
    ).fetchone()
    if free_row and free_row["max_plants"] is not None:
        return max(1, int(free_row["max_plants"]))
    return 1


def _build_limits_data(cur, user_id: int) -> dict:
    max_plants = _active_plan_max_plants(cur, user_id)
    cnt = cur.execute(
        "SELECT COUNT(*) AS c FROM user_plants WHERE user_id = ?",
        (user_id,),
    ).fetchone()
    current_count = int(cnt["c"] or 0)
    can_add = current_count < max_plants
    return {
        "current_count": current_count,
        "max_plants": max_plants,
        "can_add": can_add,
        "upgrade_required": not can_add,
        "message": None
        if can_add
        else f"Лимит тарифа: максимум {max_plants} растений в личном уходе. Обновите подписку, чтобы добавить больше.",
    }


def _serialize(row) -> dict:
    raw_photo = (row["photo_url"] or "").strip() if row["photo_url"] is not None else ""
    photo = raw_photo or DEFAULT_PLANT_IMAGE_PATH
    return {
        "id": int(row["id"]),
        "user_id": int(row["user_id"]),
        "product_id": row["product_id"],
        "custom_name": row["custom_name"],
        "plant_name": row["plant_name"],
        "display_name": row["custom_name"] or row["plant_name"],
        "photo_url": photo,
        "watering_requirement": row["watering_requirement"],
        "watering_frequency_days": row["watering_frequency_days"],
        "soil_change_frequency_days": row["soil_change_frequency_days"],
        "notes": row["notes"],
        "last_watered_at": row["last_watered_at"],
        "next_watering_at": row["next_watering_at"],
        "last_soil_change_at": row["last_soil_change_at"],
        "next_soil_change_at": row["next_soil_change_at"],
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


def _fetch_user_plant(cur, user_id: int, plant_id: int):
    return cur.execute(
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
            notes,
            last_watered_at,
            next_watering_at,
            last_soil_change_at,
            next_soil_change_at,
            created_at,
            updated_at
        FROM user_plants
        WHERE id = ? AND user_id = ?
        LIMIT 1
        """,
        (plant_id, user_id),
    ).fetchone()


def _fetch_product(cur, product_id: Optional[int]):
    if product_id is None:
        return None
    row = cur.execute(
        """
        SELECT id, name, image_url, watering_notes
        FROM products
        WHERE id = ? AND deleted_at IS NULL
        LIMIT 1
        """,
        (product_id,),
    ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Product not found")
    return row


def _calculate_schedule(
    watering_requirement: Optional[str],
    watering_frequency_days: Optional[int],
    soil_change_frequency_days: Optional[int],
    last_watered_at: Optional[str],
    last_soil_change_at: Optional[str],
) -> tuple[str | None, int, int, str, str]:
    normalized_requirement = normalize_watering_requirement(watering_requirement)
    wf = derive_watering_frequency_days(normalized_requirement, watering_frequency_days)
    sf = derive_soil_change_frequency_days(wf, soil_change_frequency_days)
    next_watering_at = next_due_date(last_watered_at, wf)
    next_soil_change_at = next_due_date(last_soil_change_at, sf)
    return normalized_requirement, wf, sf, next_watering_at, next_soil_change_at


@router.get("", summary="User plants: list")
def list_user_plants(user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        rows = conn.execute(
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
                notes,
                last_watered_at,
                next_watering_at,
                last_soil_change_at,
                next_soil_change_at,
                created_at,
                updated_at
            FROM user_plants
            WHERE user_id = ?
            ORDER BY id DESC
            """,
            (int(user["id"]),),
        ).fetchall()
    finally:
        conn.close()

    items = [_serialize(row) for row in rows]
    return {"success": True, "data": {"items": items, "count": len(items)}}


@router.get("/limits", summary="User plants: limits")
def user_plants_limits(user=Depends(get_current_user)):
    user_id = int(user["id"])
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        data = _build_limits_data(cur, user_id)
    finally:
        conn.close()
    return {"success": True, "data": data}


@router.get("/{plant_id}", summary="User plants: details")
def get_user_plant(plant_id: int, user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        row = _fetch_user_plant(conn.cursor(), int(user["id"]), plant_id)
    finally:
        conn.close()
    if not row:
        raise HTTPException(status_code=404, detail="User plant not found")
    return {"success": True, "data": _serialize(row)}


@router.post("", summary="User plants: create")
def create_user_plant(payload: UserPlantCreateRequest, user=Depends(get_current_user)):
    user_id = int(user["id"])
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        limits = _build_limits_data(cur, user_id)
        if not limits["can_add"]:
            raise HTTPException(
                status_code=403,
                detail=str(limits["message"]),
            )

        product = _fetch_product(cur, payload.product_id)
        custom_name = clean_optional_text(
            payload.custom_name or payload.plant_name,
            max_len=150,
        )
        plant_name = clean_text(custom_name or payload.plant_name, max_len=150)
        if not plant_name and product:
            plant_name = clean_text(product["name"], max_len=150)
        if not plant_name:
            raise HTTPException(status_code=422, detail="Укажите имя цветка")
        if custom_name is None:
            custom_name = plant_name
        notes = clean_optional_text(payload.notes, max_len=1000)
        last_watered_at = parse_optional_iso_date(payload.last_watered_at, "last_watered_at")
        last_soil_change_at = parse_optional_iso_date(payload.last_soil_change_at, "last_soil_change_at")

        raw_requirement = payload.watering_requirement
        if raw_requirement is None and product is not None:
            raw_requirement = clean_optional_text(product["watering_notes"], max_len=64)

        (
            watering_requirement,
            watering_frequency_days,
            soil_change_frequency_days,
            next_watering_at,
            next_soil_change_at,
        ) = _calculate_schedule(
            raw_requirement,
            payload.watering_frequency_days,
            payload.soil_change_frequency_days,
            last_watered_at,
            last_soil_change_at,
        )

        product_photo = clean_optional_text(product["image_url"], max_len=500) if product else None
        photo_url = resolve_photo_url(payload.photo_url, fallback=product_photo)

        cur.execute(
            """
            INSERT INTO user_plants (
                user_id,
                product_id,
                custom_name,
                plant_name,
                photo_url,
                watering_requirement,
                watering_frequency_days,
                soil_change_frequency_days,
                notes,
                last_watered_at,
                next_watering_at,
                last_soil_change_at,
                next_soil_change_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                user_id,
                payload.product_id,
                custom_name,
                plant_name,
                photo_url,
                watering_requirement,
                watering_frequency_days,
                soil_change_frequency_days,
                notes,
                last_watered_at,
                next_watering_at,
                last_soil_change_at,
                next_soil_change_at,
            ),
        )
        plant_id = int(cur.lastrowid)
        row = _fetch_user_plant(cur, user_id, plant_id)
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    return {"success": True, "data": _serialize(row)}


@router.put("/{plant_id}", summary="User plants: update")
def update_user_plant(
    plant_id: int,
    payload: UserPlantUpdateRequest,
    user=Depends(get_current_user),
):
    user_id = int(user["id"])
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        existing = _fetch_user_plant(cur, user_id, plant_id)
        if not existing:
            raise HTTPException(status_code=404, detail="User plant not found")

        provided = payload.model_fields_set

        product_id = existing["product_id"]
        product = None
        if "product_id" in provided:
            product_id = payload.product_id
            product = _fetch_product(cur, product_id)
        elif existing["product_id"] is not None:
            product = cur.execute(
                """
                SELECT id, name, image_url, watering_notes
                FROM products
                WHERE id = ?
                LIMIT 1
                """,
                (int(existing["product_id"]),),
            ).fetchone()

        plant_name = clean_text(payload.plant_name, max_len=150) if "plant_name" in provided else existing["plant_name"]
        if not plant_name:
            raise HTTPException(status_code=422, detail="plant_name cannot be empty")

        custom_name = (
            clean_optional_text(payload.custom_name, max_len=150)
            if "custom_name" in provided
            else existing["custom_name"]
        )
        if "custom_name" in provided and "plant_name" not in provided and custom_name:
            plant_name = clean_text(custom_name, max_len=150)
        notes = (
            clean_optional_text(payload.notes, max_len=1000)
            if "notes" in provided
            else existing["notes"]
        )

        if "last_watered_at" in provided:
            last_watered_at = parse_optional_iso_date(payload.last_watered_at, "last_watered_at")
        else:
            last_watered_at = existing["last_watered_at"]

        if "last_soil_change_at" in provided:
            last_soil_change_at = parse_optional_iso_date(payload.last_soil_change_at, "last_soil_change_at")
        else:
            last_soil_change_at = existing["last_soil_change_at"]

        if "watering_requirement" in provided:
            raw_requirement = payload.watering_requirement
        else:
            raw_requirement = existing["watering_requirement"]

        if raw_requirement is None and product is not None:
            raw_requirement = clean_optional_text(product["watering_notes"], max_len=64)

        explicit_wf = (
            payload.watering_frequency_days
            if "watering_frequency_days" in provided
            else existing["watering_frequency_days"]
        )
        explicit_sf = (
            payload.soil_change_frequency_days
            if "soil_change_frequency_days" in provided
            else existing["soil_change_frequency_days"]
        )

        (
            watering_requirement,
            watering_frequency_days,
            soil_change_frequency_days,
            next_watering_at,
            next_soil_change_at,
        ) = _calculate_schedule(
            raw_requirement,
            int(explicit_wf) if explicit_wf is not None else None,
            int(explicit_sf) if explicit_sf is not None else None,
            last_watered_at,
            last_soil_change_at,
        )

        if "photo_url" in provided:
            product_photo = clean_optional_text(product["image_url"], max_len=500) if product else None
            photo_url = resolve_photo_url(payload.photo_url, fallback=product_photo)
        else:
            photo_url = resolve_photo_url(existing["photo_url"], fallback=DEFAULT_PLANT_IMAGE_PATH)

        cur.execute(
            """
            UPDATE user_plants
            SET
                product_id = ?,
                custom_name = ?,
                plant_name = ?,
                photo_url = ?,
                watering_requirement = ?,
                watering_frequency_days = ?,
                soil_change_frequency_days = ?,
                notes = ?,
                last_watered_at = ?,
                next_watering_at = ?,
                last_soil_change_at = ?,
                next_soil_change_at = ?
            WHERE id = ? AND user_id = ?
            """,
            (
                product_id,
                custom_name,
                plant_name,
                photo_url,
                watering_requirement,
                watering_frequency_days,
                soil_change_frequency_days,
                notes,
                last_watered_at,
                next_watering_at,
                last_soil_change_at,
                next_soil_change_at,
                plant_id,
                user_id,
            ),
        )
        row = _fetch_user_plant(cur, user_id, plant_id)
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    return {"success": True, "data": _serialize(row)}


@router.delete("/{plant_id}", summary="User plants: delete")
def delete_user_plant(plant_id: int, user=Depends(get_current_user)):
    user_id = int(user["id"])
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        exists = _fetch_user_plant(cur, user_id, plant_id)
        if not exists:
            raise HTTPException(status_code=404, detail="User plant not found")

        cur.execute(
            "DELETE FROM user_plant_care_dates WHERE user_id = ? AND user_plant_id = ?",
            (user_id, plant_id),
        )
        cur.execute(
            "DELETE FROM user_plant_care_logs WHERE user_plant_id = ?",
            (plant_id,),
        )
        cur.execute(
            "DELETE FROM user_plants WHERE id = ? AND user_id = ?",
            (plant_id, user_id),
        )
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    return {"success": True, "data": {"deleted": True, "id": plant_id}}


@router.post("/{plant_id}/care", summary="User plants: mark care action")
def mark_user_plant_care(
    plant_id: int,
    payload: UserPlantCareMarkRequest,
    user=Depends(get_current_user),
):
    user_id = int(user["id"])
    care_type = normalize_care_type(payload.care_type)
    care_date = parse_optional_iso_date(payload.care_date, "care_date") or today_iso()
    notes = clean_optional_text(payload.notes, max_len=1000)

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        plant = _fetch_user_plant(cur, user_id, plant_id)
        if not plant:
            raise HTTPException(status_code=404, detail="User plant not found")

        existing_task = cur.execute(
            """
            SELECT id
            FROM user_plant_care_dates
            WHERE user_id = ?
              AND user_plant_id = ?
              AND care_type = ?
              AND care_date = ?
            LIMIT 1
            """,
            (user_id, plant_id, care_type, care_date),
        ).fetchone()

        display_name = clean_text(plant["custom_name"] or plant["plant_name"], max_len=150)
        photo_url = resolve_photo_url(plant["photo_url"], fallback=DEFAULT_PLANT_IMAGE_PATH)

        if existing_task:
            cur.execute(
                """
                UPDATE user_plant_care_dates
                SET
                    is_done = 1,
                    comment = COALESCE(?, comment),
                    plant_name = ?,
                    plant_photo_url = ?,
                    watering_requirement = ?
                WHERE id = ? AND user_id = ?
                """,
                (
                    notes,
                    display_name,
                    photo_url,
                    plant["watering_requirement"],
                    int(existing_task["id"]),
                    user_id,
                ),
            )
            task_id = int(existing_task["id"])
        else:
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
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
                """,
                (
                    user_id,
                    plant_id,
                    plant["product_id"],
                    display_name,
                    photo_url,
                    plant["watering_requirement"],
                    care_type,
                    care_date,
                    notes,
                ),
            )
            task_id = int(cur.lastrowid)

        if care_type in {"watering", "repotting", "soil_change"}:
            log_exists = cur.execute(
                """
                SELECT id
                FROM user_plant_care_logs
                WHERE user_plant_id = ? AND care_type = ? AND care_at = ?
                LIMIT 1
                """,
                (plant_id, care_type, care_date),
            ).fetchone()
            if not log_exists:
                cur.execute(
                    """
                    INSERT INTO user_plant_care_logs (user_plant_id, care_type, care_at, notes)
                    VALUES (?, ?, ?, ?)
                    """,
                    (plant_id, care_type, care_date, notes),
                )

        if care_type == "watering":
            wf = int(plant["watering_frequency_days"] or 7)
            cur.execute(
                """
                UPDATE user_plants
                SET
                    last_watered_at = ?,
                    next_watering_at = ?
                WHERE id = ? AND user_id = ?
                """,
                (care_date, next_due_date(care_date, wf), plant_id, user_id),
            )
        elif care_type == "soil_change":
            sf = int(plant["soil_change_frequency_days"] or 180)
            cur.execute(
                """
                UPDATE user_plants
                SET
                    last_soil_change_at = ?,
                    next_soil_change_at = ?
                WHERE id = ? AND user_id = ?
                """,
                (care_date, next_due_date(care_date, sf), plant_id, user_id),
            )

        refreshed = _fetch_user_plant(cur, user_id, plant_id)
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "task_id": task_id,
            "care_type": care_type,
            "care_date": care_date,
            "plant": _serialize(refreshed),
        },
    }


@router.post("/{plant_id}/photo", summary="User plants: upload photo")
async def upload_user_plant_photo(
    plant_id: int,
    file: UploadFile = File(...),
    user=Depends(get_current_user),
):
    filename = (file.filename or "").strip()
    ext = os.path.splitext(filename)[1].lower()
    if ext not in ALLOWED_IMAGE_EXTS:
        raise HTTPException(status_code=400, detail="Unsupported image format")

    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Empty file")
    if len(content) > MAX_IMAGE_SIZE_BYTES:
        raise HTTPException(status_code=413, detail="File is too large")

    user_id = int(user["id"])
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        exists = _fetch_user_plant(cur, user_id, plant_id)
        if not exists:
            raise HTTPException(status_code=404, detail="User plant not found")

        storage_dir = BASE_DIR / "img" / "user_plants"
        storage_dir.mkdir(parents=True, exist_ok=True)
        safe_name = f"{user_id}_{plant_id}_{uuid.uuid4().hex[:12]}{ext}"
        target = storage_dir / safe_name
        target.write_bytes(content)

        rel_path = FsPath("img") / "user_plants" / safe_name
        rel_str = rel_path.as_posix()

        cur.execute(
            "UPDATE user_plants SET photo_url = ? WHERE id = ? AND user_id = ?",
            (rel_str, plant_id, user_id),
        )
        row = _fetch_user_plant(cur, user_id, plant_id)
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    return {"success": True, "data": _serialize(row)}


@router.get("/care/types", summary="User plants: available care types")
def user_plant_care_types(_user=Depends(get_current_user)):
    return {
        "success": True,
        "data": {"items": sorted(ALLOWED_CARE_TYPES)},
    }
