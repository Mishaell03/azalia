from __future__ import annotations

import os
import re
import uuid
from pathlib import Path as FsPath
from typing import Any, Optional

from fastapi import APIRouter, Depends, File, Header, HTTPException, Path as FastApiPath, Query, UploadFile, status
from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.config import BASE_DIR
from app.db import get_db_connection
from app.routes.utils import get_current_user, require_admin

router = APIRouter(prefix="/api/plants", tags=["plants"])

ALLOWED_IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".gif", ".webp"}
MAX_IMAGE_SIZE_BYTES = 16 * 1024 * 1024
SAFE_TEXT_RE = re.compile(r"[\x00-\x1F\x7F]")
DEFAULT_PRODUCT_IMAGE_PATH = "img/none.png"


class ProductCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=150)
    description: Optional[str] = Field(default=None, max_length=2000)
    category_id: int = Field(ge=1)
    plant_type_id: int = Field(ge=1)
    supplier_id: Optional[int] = Field(default=None, ge=1)
    base_price: float = Field(ge=0, le=1_000_000)
    cost_price: float = Field(default=0, ge=0, le=1_000_000)
    recommended_pot_size_id: Optional[int] = Field(default=None, ge=1)
    height_cm: Optional[int] = Field(default=None, ge=0, le=10_000)
    light_requirements: Optional[str] = Field(default=None)
    watering_notes: Optional[str] = Field(default=None, max_length=500)
    care_instructions: Optional[str] = Field(default=None, max_length=3000)
    image_url: Optional[str] = Field(default=None, max_length=500)
    rating: float = Field(default=0, ge=0, le=5)
    is_active: bool = True

    @field_validator("name", mode="before")
    @classmethod
    def clean_name(cls, value: str) -> str:
        text = SAFE_TEXT_RE.sub("", str(value)).strip()
        if not text:
            raise ValueError("Invalid name")
        return text


class ProductUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: Optional[str] = Field(default=None, min_length=1, max_length=150)
    description: Optional[str] = Field(default=None, max_length=2000)
    category_id: Optional[int] = Field(default=None, ge=1)
    plant_type_id: Optional[int] = Field(default=None, ge=1)
    supplier_id: Optional[int] = Field(default=None, ge=1)
    base_price: Optional[float] = Field(default=None, ge=0, le=1_000_000)
    cost_price: Optional[float] = Field(default=None, ge=0, le=1_000_000)
    recommended_pot_size_id: Optional[int] = Field(default=None, ge=1)
    height_cm: Optional[int] = Field(default=None, ge=0, le=10_000)
    light_requirements: Optional[str] = Field(default=None)
    watering_notes: Optional[str] = Field(default=None, max_length=500)
    care_instructions: Optional[str] = Field(default=None, max_length=3000)
    image_url: Optional[str] = Field(default=None, max_length=500)
    rating: Optional[float] = Field(default=None, ge=0, le=5)
    is_active: Optional[bool] = None


def _clean_text(value: Optional[str], max_len: int = 255) -> Optional[str]:
    if value is None:
        return None
    text = SAFE_TEXT_RE.sub("", str(value)).strip()
    if not text:
        return None
    return text[:max_len]


def _product_to_dict(row, images: list[dict[str, Any]]) -> dict[str, Any]:
    is_active = bool(row["is_active"])
    is_removed = (not is_active) or (row["deleted_at"] is not None)
    raw_image = (row["image_url"] or "").strip() if row["image_url"] is not None else ""
    resolved_image = raw_image or (
        images[0]["image_url"]
        if images and isinstance(images[0], dict) and images[0].get("image_url")
        else DEFAULT_PRODUCT_IMAGE_PATH
    )
    return {
        "id": row["id"],
        "sku": row["sku"],
        "name": row["name"],
        "description": row["description"],
        "category_id": row["category_id"],
        "category_name": row["category_name"],
        "plant_type_id": row["plant_type_id"],
        "plant_type_name": row["plant_type_name"],
        "supplier_id": row["supplier_id"],
        "supplier_name": row["supplier_name"],
        "base_price": float(row["base_price"]),
        "cost_price": float(row["cost_price"]),
        "recommended_pot_size_id": row["recommended_pot_size_id"],
        "recommended_pot_size_name": row["recommended_pot_size_name"],
        "height_cm": row["height_cm"],
        "light_requirements": row["light_requirements"],
        "watering_notes": row["watering_notes"],
        "care_instructions": row["care_instructions"],
        "image_url": resolved_image,
        "rating": float(row["rating"]),
        "is_active": is_active,
        "deleted_at": row["deleted_at"],
        "sale_status": "removed" if is_removed else "active",
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
        "inventory_available": int(row["inventory_available"] or 0),
        "images": images,
    }


def _fetch_images(cur, product_id: int) -> list[dict[str, Any]]:
    rows = cur.execute(
        """
        SELECT id, image_url, sort_order, is_main, is_active, alt_text, created_at
        FROM product_images
        WHERE product_id = ? AND is_active = 1
        ORDER BY is_main DESC, sort_order ASC, id ASC
        """,
        (product_id,),
    ).fetchall()
    return [
        {
            "id": row["id"],
            "image_url": row["image_url"],
            "sort_order": row["sort_order"],
            "is_main": bool(row["is_main"]),
            "alt_text": row["alt_text"],
            "created_at": row["created_at"],
        }
        for row in rows
    ]


def _base_product_sql() -> str:
    return """
        SELECT
            p.*,
            c.name AS category_name,
            pt.name AS plant_type_name,
            s.name AS supplier_name,
            ps.name AS recommended_pot_size_name,
            COALESCE(SUM(i.quantity_available), 0) AS inventory_available
        FROM products p
        JOIN categories c ON c.id = p.category_id
        JOIN plant_types pt ON pt.id = p.plant_type_id
        LEFT JOIN suppliers s ON s.id = p.supplier_id
        LEFT JOIN pot_sizes ps ON ps.id = p.recommended_pot_size_id
        LEFT JOIN inventory i ON i.product_id = p.id
    """


def _validate_refs(cur, payload: ProductCreateRequest | ProductUpdateRequest) -> None:
    checks: list[tuple[str, str, Optional[int]]] = [
        ("Category", "categories", getattr(payload, "category_id", None)),
        ("Plant type", "plant_types", getattr(payload, "plant_type_id", None)),
        ("Supplier", "suppliers", getattr(payload, "supplier_id", None)),
        (
            "Pot size",
            "pot_sizes",
            getattr(payload, "recommended_pot_size_id", None),
        ),
    ]

    for label, table, value in checks:
        if value is None:
            continue
        row = cur.execute(f"SELECT id FROM {table} WHERE id = ?", (value,)).fetchone()
        if not row:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"{label} not found",
            )


def _create_product(cur, payload: ProductCreateRequest) -> int:
    _validate_refs(cur, payload)

    exists = cur.execute(
        "SELECT id FROM products WHERE lower(name) = lower(?) AND deleted_at IS NULL",
        (payload.name,),
    ).fetchone()
    if exists:
        raise HTTPException(status_code=400, detail="Plant with this name already exists")

    cur.execute(
        """
        INSERT INTO products (
            sku, name, description, category_id, plant_type_id, supplier_id,
            base_price, cost_price, recommended_pot_size_id, height_cm,
            light_requirements, watering_notes, care_instructions, image_url,
            rating, is_active
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            None,
            payload.name,
            _clean_text(payload.description, 2000),
            payload.category_id,
            payload.plant_type_id,
            payload.supplier_id,
            payload.base_price,
            payload.cost_price,
            payload.recommended_pot_size_id,
            payload.height_cm,
            _clean_text(payload.light_requirements, 32),
            _clean_text(payload.watering_notes, 500),
            _clean_text(payload.care_instructions, 3000),
            _clean_text(payload.image_url, 500),
            payload.rating,
            int(payload.is_active),
        ),
    )
    return int(cur.lastrowid)


@router.get("/", summary="Get Plants")
def get_plants(
    category_id: Optional[int] = Query(default=None, ge=1),
    plant_type_id: Optional[int] = Query(default=None, ge=1),
    supplier_id: Optional[int] = Query(default=None, ge=1),
    in_stock: Optional[bool] = Query(default=None),
    search: Optional[str] = Query(default=None, max_length=100),
    min_price: Optional[float] = Query(default=None, ge=0),
    max_price: Optional[float] = Query(default=None, ge=0),
    min_rating: Optional[float] = Query(default=None, ge=0, le=5),
    max_rating: Optional[float] = Query(default=None, ge=0, le=5),
    sort_by: str = Query(default="name"),
    page: int = Query(default=1, ge=1),
    per_page: int = Query(default=5, ge=1, le=100),
    limit: Optional[int] = Query(default=None, ge=1, le=500),
    offset: Optional[int] = Query(default=None, ge=0),
    include_inactive: bool = Query(default=False),
    token: Optional[str] = Header(default=None, alias="Authorization"),
):
    """Возвращает список растений с фильтрами, сортировкой и пагинацией."""
    if min_price is not None and max_price is not None and min_price > max_price:
        raise HTTPException(status_code=400, detail="min_price cannot exceed max_price")
    if min_rating is not None and max_rating is not None and min_rating > max_rating:
        raise HTTPException(status_code=400, detail="min_rating cannot exceed max_rating")

    sort_mapping = {
        "name": "p.name ASC",
        "price_asc": "p.base_price ASC",
        "price_desc": "p.base_price DESC",
        "rating_desc": "p.rating DESC, p.name ASC",
        "created_desc": "p.created_at DESC",
    }
    sort_sql = sort_mapping.get(sort_by)
    if sort_sql is None:
        raise HTTPException(status_code=400, detail="Invalid sort_by value")

    effective_limit = limit if limit is not None else per_page
    effective_offset = offset if offset is not None else (page - 1) * effective_limit
    effective_page = (
        (effective_offset // effective_limit) + 1 if effective_limit > 0 else 1
    )

    sql = _base_product_sql() + " WHERE 1=1 "
    params: list[Any] = []

    if include_inactive:
        user = get_current_user(token)
        require_admin(user)
    else:
        sql += " AND p.is_active = 1 AND p.deleted_at IS NULL"

    if category_id is not None:
        sql += " AND p.category_id = ?"
        params.append(category_id)

    if plant_type_id is not None:
        sql += " AND p.plant_type_id = ?"
        params.append(plant_type_id)

    if supplier_id is not None:
        sql += " AND p.supplier_id = ?"
        params.append(supplier_id)

    if search:
        q = f"%{_clean_text(search, 100) or ''}%"
        sql += " AND (p.name LIKE ? ESCAPE '\\' OR p.description LIKE ? ESCAPE '\\' OR p.sku LIKE ? ESCAPE '\\')"
        params.extend([q, q, q])

    if min_price is not None:
        sql += " AND p.base_price >= ?"
        params.append(min_price)

    if max_price is not None:
        sql += " AND p.base_price <= ?"
        params.append(max_price)

    if min_rating is not None:
        sql += " AND p.rating >= ?"
        params.append(min_rating)

    if max_rating is not None:
        sql += " AND p.rating <= ?"
        params.append(max_rating)

    sql += " GROUP BY p.id"

    # Для публичной витрины API должен возвращать все товары в продаже,
    # кроме снятых с продажи. Поэтому in_stock=True в публичном запросе
    # не сужает выборку по остаткам.
    if in_stock is False:
        sql += " HAVING COALESCE(SUM(i.quantity_available), 0) <= 0"
    elif in_stock is True and include_inactive:
        sql += " HAVING COALESCE(SUM(i.quantity_available), 0) > 0"

    count_sql = f"SELECT COUNT(*) AS total FROM ({sql}) AS filtered_products"
    count_params = params.copy()

    sql += f" ORDER BY {sort_sql} LIMIT ? OFFSET ?"
    params.extend([effective_limit, effective_offset])

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        total = int(cur.execute(count_sql, count_params).fetchone()["total"])
        rows = cur.execute(sql, params).fetchall()
        data = [_product_to_dict(row, _fetch_images(cur, row["id"])) for row in rows]
    finally:
        conn.close()

    pages = (total + effective_limit - 1) // effective_limit if effective_limit else 0
    return {
        "success": True,
        "data": data,
        "count": len(data),
        "pagination": {
            "page": effective_page,
            "per_page": effective_limit,
            "total": total,
            "pages": pages,
        },
    }


@router.get("/categories", summary="Get Plant Categories")
def get_categories_for_products():
    """Возвращает категории для раздела каталога растений."""
    conn = get_db_connection()
    try:
        rows = conn.execute(
            "SELECT id, name, parent_id, created_at FROM categories ORDER BY name ASC"
        ).fetchall()
    finally:
        conn.close()

    return {
        "success": True,
        "data": [
            {
                "id": row["id"],
                "name": row["name"],
                "parent_id": row["parent_id"],
                "created_at": row["created_at"],
            }
            for row in rows
        ],
    }


@router.get("/filters", summary="Get Plant Filters")
def get_filters():
    """Возвращает справочники и диапазоны фильтров для каталога."""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        plant_types = cur.execute(
            "SELECT id, name FROM plant_types ORDER BY name ASC"
        ).fetchall()
        categories = cur.execute(
            "SELECT id, name, parent_id FROM categories ORDER BY name ASC"
        ).fetchall()
        price_range = cur.execute(
            "SELECT COALESCE(MIN(base_price), 0) AS min_v, COALESCE(MAX(base_price), 0) AS max_v FROM products WHERE deleted_at IS NULL"
        ).fetchone()
        rating_range = cur.execute(
            "SELECT COALESCE(MIN(rating), 0) AS min_v, COALESCE(MAX(rating), 5) AS max_v FROM products WHERE deleted_at IS NULL"
        ).fetchone()
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "plant_types": [{"id": row["id"], "name": row["name"]} for row in plant_types],
            "categories": [
                {"id": row["id"], "name": row["name"], "parent_id": row["parent_id"]}
                for row in categories
            ],
            "price_range": {
                "min": float(price_range["min_v"]),
                "max": float(price_range["max_v"]),
            },
            "rating_range": {
                "min": float(rating_range["min_v"]),
                "max": float(rating_range["max_v"]),
            },
        },
    }


@router.get("/{plant_id}", summary="Get Plant By Id")
def get_plant(plant_id: int = FastApiPath(..., ge=1)):
    """Возвращает детальную информацию по одному растению."""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        row = cur.execute(
            _base_product_sql()
            + """
            WHERE p.id = ?
            GROUP BY p.id
            """,
            (plant_id,),
        ).fetchone()

        if not row:
            raise HTTPException(status_code=404, detail="Plant not found")

        data = _product_to_dict(row, _fetch_images(cur, plant_id))
    finally:
        conn.close()

    return {"success": True, "data": data}


@router.post("/", status_code=status.HTTP_201_CREATED, summary="Create Plant")
def create_plant(payload: ProductCreateRequest, user=Depends(get_current_user)):
    """Создает новое растение в каталоге."""
    require_admin(user)
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        product_id = _create_product(cur, payload)
        conn.commit()
    finally:
        conn.close()

    return {"success": True, "message": "Plant created successfully", "id": product_id}


@router.post("/admin/create", status_code=status.HTTP_201_CREATED, summary="Admin Create Plant")
def admin_create_plant(payload: ProductCreateRequest, user=Depends(get_current_user)):
    """Создает новое растение через админ-редактор."""
    require_admin(user)
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        product_id = _create_product(cur, payload)
        conn.commit()
    finally:
        conn.close()

    return {
        "success": True,
        "message": "Plant created successfully",
        "data": {
            "id": product_id,
        },
    }


@router.put("/{plant_id}", summary="Update Plant")
def update_plant(plant_id: int, payload: ProductUpdateRequest, user=Depends(get_current_user)):
    """Обновляет поля растения."""
    require_admin(user)
    updates = payload.model_dump(exclude_unset=True)
    if not updates:
        raise HTTPException(status_code=400, detail="No data provided")

    conn = get_db_connection()
    try:
        cur = conn.cursor()

        row = cur.execute("SELECT id, name FROM products WHERE id = ?", (plant_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Plant not found")

        _validate_refs(cur, payload)

        if "name" in updates:
            new_name = _clean_text(updates["name"], 150)
            if not new_name:
                raise HTTPException(status_code=400, detail="Invalid plant name")
            dup = cur.execute(
                """
                SELECT id
                FROM products
                WHERE lower(name) = lower(?)
                  AND id <> ?
                  AND deleted_at IS NULL
                """,
                (new_name, plant_id),
            ).fetchone()
            if dup:
                raise HTTPException(status_code=400, detail="Plant with this name already exists")
            updates["name"] = new_name

        text_fields = {
            "description": 2000,
            "light_requirements": 32,
            "watering_notes": 500,
            "care_instructions": 3000,
            "image_url": 500,
        }
        for field_name, max_len in text_fields.items():
            if field_name in updates:
                updates[field_name] = _clean_text(updates[field_name], max_len)

        if "is_active" in updates:
            updates["is_active"] = int(bool(updates["is_active"]))

        set_parts = [f"{k} = ?" for k in updates.keys()]
        params = list(updates.values())
        params.append(plant_id)

        cur.execute(
            f"UPDATE products SET {', '.join(set_parts)} WHERE id = ?",
            tuple(params),
        )
        conn.commit()
    finally:
        conn.close()

    return {"success": True, "message": "Plant updated successfully"}


@router.delete("/{plant_id}", summary="Archive Plant")
def delete_plant(plant_id: int, user=Depends(get_current_user)):
    """Архивирует растение (мягкое удаление)."""
    require_admin(user)
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        exists = cur.execute("SELECT id FROM products WHERE id = ?", (plant_id,)).fetchone()
        if not exists:
            raise HTTPException(status_code=404, detail="Plant not found")

        # Безопаснее для истории заказов: мягкое удаление.
        cur.execute(
            """
            UPDATE products
            SET is_active = 0,
                deleted_at = COALESCE(deleted_at, CURRENT_TIMESTAMP)
            WHERE id = ?
            """,
            (plant_id,),
        )
        conn.commit()
    finally:
        conn.close()

    return {"success": True, "message": "Plant archived successfully"}


@router.post("/{plant_id}/image", summary="Upload Plant Image")
async def upload_plant_image(
    plant_id: int,
    image: UploadFile = File(...),
    user=Depends(get_current_user),
):
    """Загружает изображение растения и добавляет запись в product_images."""
    require_admin(user)
    filename = image.filename or ""
    suffix = FsPath(filename).suffix.lower()
    if suffix not in ALLOWED_IMAGE_EXTS:
        raise HTTPException(status_code=400, detail="Unsupported file type")

    content = await image.read()
    if not content:
        raise HTTPException(status_code=400, detail="Empty file")
    if len(content) > MAX_IMAGE_SIZE_BYTES:
        raise HTTPException(status_code=400, detail="File too large")

    img_dir = BASE_DIR / "img" / "preview"
    img_dir.mkdir(parents=True, exist_ok=True)

    safe_name = f"{uuid.uuid4().hex}{suffix}"
    full_path = img_dir / safe_name
    full_path.write_bytes(content)

    rel_path = f"img/preview/{safe_name}"

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        exists = cur.execute("SELECT id FROM products WHERE id = ?", (plant_id,)).fetchone()
        if not exists:
            full_path.unlink(missing_ok=True)
            raise HTTPException(status_code=404, detail="Plant not found")

        cur.execute("UPDATE products SET image_url = ? WHERE id = ?", (rel_path, plant_id))
        cur.execute(
            """
            INSERT INTO product_images (product_id, image_url, sort_order, is_main, is_active)
            VALUES (?, ?, 0, 1, 1)
            """,
            (plant_id, rel_path),
        )
        conn.commit()
    finally:
        conn.close()

    return {"success": True, "message": "Image uploaded", "image_url": rel_path}


@router.delete("/{plant_id}/image", summary="Delete Plant Image")
def delete_plant_image(plant_id: int, user=Depends(get_current_user)):
    """Удаляет основное изображение растения и деактивирует связанные фото."""
    require_admin(user)
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        row = cur.execute("SELECT image_url FROM products WHERE id = ?", (plant_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Plant not found")

        image_url = row["image_url"]
        cur.execute("UPDATE products SET image_url = NULL WHERE id = ?", (plant_id,))
        cur.execute(
            "UPDATE product_images SET is_active = 0 WHERE product_id = ?",
            (plant_id,),
        )
        conn.commit()
    finally:
        conn.close()

    if image_url:
        normalized = FsPath(image_url)
        if not normalized.is_absolute() and normalized.parts and normalized.parts[0] == "img":
            (BASE_DIR / normalized).unlink(missing_ok=True)

    return {"success": True, "message": "Image deleted"}
