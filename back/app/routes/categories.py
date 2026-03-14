from __future__ import annotations

import re
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict, Field

from app.db import get_db_connection
from app.routes.utils import get_current_user, require_admin

router = APIRouter(prefix="/api/categories", tags=["categories"])
SAFE_TEXT_RE = re.compile(r"[\x00-\x1F\x7F]")
DEFAULT_PRODUCT_IMAGE_PATH = "img/none.png"


class CategoryCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=100)
    description: Optional[str] = Field(default=None, max_length=500)
    parent_id: Optional[int] = Field(default=None, ge=1)


class CategoryUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: Optional[str] = Field(default=None, min_length=1, max_length=100)
    parent_id: Optional[int] = Field(default=None, ge=1)


def _clean_text(value: Optional[str], max_len: int) -> Optional[str]:
    if value is None:
        return None
    text = SAFE_TEXT_RE.sub("", str(value)).strip()
    if not text:
        return None
    return text[:max_len]


def _build_tree(rows, parent_id=None):
    result = []
    for row in rows:
        if row["parent_id"] == parent_id:
            node = {
                "id": row["id"],
                "name": row["name"],
                "parent_id": row["parent_id"],
                "created_at": row["created_at"],
                "subcategories": _build_tree(rows, row["id"]),
            }
            result.append(node)
    return result


@router.get("/", summary="Get Categories")
def get_categories(only_parents: bool = Query(default=False)):
    """Возвращает дерево категорий или только корневые категории."""
    conn = get_db_connection()
    try:
        rows = conn.execute(
            "SELECT id, name, parent_id, created_at FROM categories ORDER BY name ASC"
        ).fetchall()
    finally:
        conn.close()

    if only_parents:
        filtered = [row for row in rows if row["parent_id"] is None]
        data = [
            {
                "id": row["id"],
                "name": row["name"],
                "parent_id": row["parent_id"],
                "created_at": row["created_at"],
                "subcategories": [],
            }
            for row in filtered
        ]
    else:
        data = _build_tree(rows)

    return {"success": True, "data": data, "count": len(rows)}


@router.get("/stats", summary="Get Categories Stats")
def get_categories_stats(user=Depends(get_current_user)):
    """Статистика по категориям: количество товаров в каждой категории."""
    require_admin(user)
    conn = get_db_connection()
    try:
        stats = conn.execute(
            """
            SELECT
                c.id AS category_id,
                c.name AS category_name,
                COUNT(p.id) AS products_count
            FROM categories c
            LEFT JOIN products p ON p.category_id = c.id
                AND p.deleted_at IS NULL
            GROUP BY c.id, c.name
            ORDER BY c.name ASC
            """
        ).fetchall()
    finally:
        conn.close()

    return {
        "success": True,
        "data": [
            {
                "category_id": row["category_id"],
                "category_name": row["category_name"],
                "products_count": int(row["products_count"]),
            }
            for row in stats
        ],
    }


@router.get("/{category_id}", summary="Get Category By Id")
def get_category(category_id: int):
    """Детальная информация по категории, включая подкатегории и число товаров."""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        category = cur.execute(
            "SELECT id, name, parent_id, created_at FROM categories WHERE id = ?",
            (category_id,),
        ).fetchone()
        if not category:
            raise HTTPException(status_code=404, detail="Category not found")

        subcategories = cur.execute(
            "SELECT id, name, parent_id, created_at FROM categories WHERE parent_id = ? ORDER BY name ASC",
            (category_id,),
        ).fetchall()
        products_count = cur.execute(
            "SELECT COUNT(*) AS cnt FROM products WHERE category_id = ? AND deleted_at IS NULL",
            (category_id,),
        ).fetchone()["cnt"]

        parent = None
        if category["parent_id"] is not None:
            parent = cur.execute(
                "SELECT id, name, parent_id, created_at FROM categories WHERE id = ?",
                (category["parent_id"],),
            ).fetchone()
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "id": category["id"],
            "name": category["name"],
            "parent_id": category["parent_id"],
            "created_at": category["created_at"],
            "plants_count": int(products_count),
            "parent_category": (
                {
                    "id": parent["id"],
                    "name": parent["name"],
                    "parent_id": parent["parent_id"],
                    "created_at": parent["created_at"],
                }
                if parent
                else None
            ),
            "subcategories": [
                {
                    "id": row["id"],
                    "name": row["name"],
                    "parent_id": row["parent_id"],
                    "created_at": row["created_at"],
                }
                for row in subcategories
            ],
        },
    }


@router.post("/", status_code=status.HTTP_201_CREATED, summary="Create Category")
def create_category(payload: CategoryCreateRequest, user=Depends(get_current_user)):
    """Создает новую категорию."""
    require_admin(user)
    name = _clean_text(payload.name, 100)
    if not name:
        raise HTTPException(status_code=400, detail="Invalid category name")

    conn = get_db_connection()
    try:
        cur = conn.cursor()

        existing = cur.execute(
            "SELECT id FROM categories WHERE lower(name) = lower(?)",
            (name,),
        ).fetchone()
        if existing:
            raise HTTPException(status_code=400, detail="Category with this name already exists")

        if payload.parent_id is not None:
            parent = cur.execute(
                "SELECT id FROM categories WHERE id = ?",
                (payload.parent_id,),
            ).fetchone()
            if not parent:
                raise HTTPException(status_code=400, detail="Parent category not found")

        cur.execute(
            "INSERT INTO categories (name, parent_id) VALUES (?, ?)",
            (name, payload.parent_id),
        )
        category_id = cur.lastrowid
        conn.commit()
    finally:
        conn.close()

    return {
        "success": True,
        "message": "Category created successfully",
        "data": {"id": category_id, "name": name, "parent_id": payload.parent_id},
    }


@router.put("/{category_id}", summary="Update Category")
def update_category(category_id: int, payload: CategoryUpdateRequest, user=Depends(get_current_user)):
    """Обновляет существующую категорию."""
    require_admin(user)
    updates = payload.model_dump(exclude_unset=True)
    if not updates:
        raise HTTPException(status_code=400, detail="No data provided")

    conn = get_db_connection()
    try:
        cur = conn.cursor()

        category = cur.execute("SELECT id FROM categories WHERE id = ?", (category_id,)).fetchone()
        if not category:
            raise HTTPException(status_code=404, detail="Category not found")

        if "parent_id" in updates and updates["parent_id"] == category_id:
            raise HTTPException(status_code=400, detail="Category cannot be parent of itself")

        if "parent_id" in updates and updates["parent_id"] is not None:
            parent = cur.execute(
                "SELECT id FROM categories WHERE id = ?",
                (updates["parent_id"],),
            ).fetchone()
            if not parent:
                raise HTTPException(status_code=400, detail="Parent category not found")

        if "name" in updates:
            clean_name = _clean_text(updates["name"], 100)
            if not clean_name:
                raise HTTPException(status_code=400, detail="Invalid category name")
            dup = cur.execute(
                "SELECT id FROM categories WHERE lower(name) = lower(?) AND id <> ?",
                (clean_name, category_id),
            ).fetchone()
            if dup:
                raise HTTPException(status_code=400, detail="Category with this name already exists")
            updates["name"] = clean_name

        set_parts = [f"{field} = ?" for field in updates.keys()]
        params = list(updates.values())
        params.append(category_id)

        cur.execute(
            f"UPDATE categories SET {', '.join(set_parts)} WHERE id = ?",
            tuple(params),
        )
        conn.commit()
    finally:
        conn.close()

    return {"success": True, "message": "Category updated successfully"}


@router.delete("/{category_id}", summary="Delete Category")
def delete_category(category_id: int, user=Depends(get_current_user)):
    """Удаляет категорию, если в ней нет товаров и подкатегорий."""
    require_admin(user)
    conn = get_db_connection()
    try:
        cur = conn.cursor()

        category = cur.execute("SELECT id FROM categories WHERE id = ?", (category_id,)).fetchone()
        if not category:
            raise HTTPException(status_code=404, detail="Category not found")

        products_count = cur.execute(
            "SELECT COUNT(*) AS cnt FROM products WHERE category_id = ? AND deleted_at IS NULL",
            (category_id,),
        ).fetchone()["cnt"]
        if products_count > 0:
            raise HTTPException(
                status_code=400,
                detail=f"Cannot delete category with {products_count} products",
            )

        subcategories_count = cur.execute(
            "SELECT COUNT(*) AS cnt FROM categories WHERE parent_id = ?",
            (category_id,),
        ).fetchone()["cnt"]
        if subcategories_count > 0:
            raise HTTPException(
                status_code=400,
                detail=f"Cannot delete category with {subcategories_count} subcategories",
            )

        cur.execute("DELETE FROM categories WHERE id = ?", (category_id,))
        conn.commit()
    finally:
        conn.close()

    return {"success": True, "message": "Category deleted successfully"}


@router.get("/{category_id}/plants", summary="Get Category Plants")
def get_category_plants(
    category_id: int,
    in_stock: Optional[bool] = Query(default=None),
    plant_type_id: Optional[int] = Query(default=None, ge=1),
):
    """Возвращает список товаров выбранной категории."""
    conn = get_db_connection()
    try:
        cur = conn.cursor()

        category = cur.execute(
            "SELECT id, name, parent_id, created_at FROM categories WHERE id = ?",
            (category_id,),
        ).fetchone()
        if not category:
            raise HTTPException(status_code=404, detail="Category not found")

        sql = """
            SELECT
                p.id,
                p.name,
                p.description,
                p.base_price,
                p.rating,
                p.image_url,
                p.is_active,
                COALESCE(SUM(i.quantity_available), 0) AS inventory_available
            FROM products p
            LEFT JOIN inventory i ON i.product_id = p.id
            WHERE p.category_id = ?
              AND p.deleted_at IS NULL
        """
        params: list[object] = [category_id]

        if plant_type_id is not None:
            sql += " AND p.plant_type_id = ?"
            params.append(plant_type_id)

        sql += " GROUP BY p.id"

        if in_stock is True:
            sql += " HAVING COALESCE(SUM(i.quantity_available), 0) > 0"
        elif in_stock is False:
            sql += " HAVING COALESCE(SUM(i.quantity_available), 0) <= 0"

        sql += " ORDER BY p.name ASC"

        products = cur.execute(sql, tuple(params)).fetchall()
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "category": {
                "id": category["id"],
                "name": category["name"],
                "parent_id": category["parent_id"],
                "created_at": category["created_at"],
            },
            "plants": [
                {
                    "id": row["id"],
                    "name": row["name"],
                    "description": row["description"],
                    "base_price": float(row["base_price"]),
                    "rating": float(row["rating"]),
                    "image_url": (
                        (row["image_url"] or "").strip() if row["image_url"] else DEFAULT_PRODUCT_IMAGE_PATH
                    ),
                    "is_active": bool(row["is_active"]),
                    "inventory_available": int(row["inventory_available"]),
                }
                for row in products
            ],
            "count": len(products),
        },
    }
