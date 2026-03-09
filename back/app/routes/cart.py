from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.db import get_db_connection
from app.routes.utils import clean_text, get_current_user

router = APIRouter(prefix="/api/cart", tags=["cart"])


class CartAddRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    product_id: Optional[int] = Field(default=None, ge=1)
    plant_id: Optional[int] = Field(default=None, ge=1)
    quantity: int = Field(default=1, ge=1, le=100)

    pot_size_id: Optional[int] = Field(default=None, ge=1)
    pot_material_id: Optional[int] = Field(default=None, ge=1)
    pot_color_id: Optional[int] = Field(default=None, ge=1)

    pot_size: Optional[str] = Field(default=None, max_length=50)
    pot_material: Optional[str] = Field(default=None, max_length=50)
    pot_color: Optional[str] = Field(default=None, max_length=50)

    @model_validator(mode="after")
    def validate_product(self):
        if self.product_id is None and self.plant_id is None:
            raise ValueError("product_id or plant_id is required")
        if self.product_id is not None and self.plant_id is not None and self.product_id != self.plant_id:
            raise ValueError("product_id and plant_id mismatch")
        return self


class CartUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    quantity: int = Field(ge=0, le=100)


class WishlistRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    product_id: Optional[int] = Field(default=None, ge=1)
    plant_id: Optional[int] = Field(default=None, ge=1)

    @model_validator(mode="after")
    def validate_product(self):
        if self.product_id is None and self.plant_id is None:
            raise ValueError("product_id or plant_id is required")
        if self.product_id is not None and self.plant_id is not None and self.product_id != self.plant_id:
            raise ValueError("product_id and plant_id mismatch")
        return self


def _resolve_option_id(cur, table: str, id_value: Optional[int], name_value: Optional[str]) -> Optional[int]:
    if id_value is not None:
        row = cur.execute(f"SELECT id FROM {table} WHERE id = ?", (id_value,)).fetchone()
        if not row:
            raise HTTPException(status_code=400, detail=f"{table} entry not found")
        return id_value

    if name_value:
        cleaned = clean_text(name_value, max_len=50)
        if not cleaned:
            return None
        row = cur.execute(
            f"SELECT id FROM {table} WHERE lower(name) = lower(?)",
            (cleaned,),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=400, detail=f"{table} entry not found")
        return int(row["id"])

    return None


def _resolve_product(cur, product_id: int):
    row = cur.execute(
        """
        SELECT p.id, p.name, p.base_price, p.is_active, p.deleted_at,
               COALESCE(SUM(i.quantity_available), 0) AS available_qty
        FROM products p
        LEFT JOIN inventory i ON i.product_id = p.id
        WHERE p.id = ?
        GROUP BY p.id
        """,
        (product_id,),
    ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Product not found")
    if not bool(row["is_active"]) or row["deleted_at"] is not None:
        raise HTTPException(status_code=400, detail="Product is not available")
    return row


def _resolve_pot_unit_price(
    cur,
    pot_size_id: Optional[int],
    pot_material_id: Optional[int],
) -> float:
    if pot_size_id is None and pot_material_id is None:
        return 0.0
    if pot_size_id is None or pot_material_id is None:
        raise HTTPException(status_code=400, detail="pot_size and pot_material must be provided together")

    row = cur.execute(
        "SELECT price FROM pot_prices WHERE size_id = ? AND material_id = ? LIMIT 1",
        (pot_size_id, pot_material_id),
    ).fetchone()
    if not row:
        raise HTTPException(status_code=400, detail="Selected pot combination not available")
    return float(row["price"])


def _cart_item_to_dict(cur, row):
    product = cur.execute(
        "SELECT id, name, image_url FROM products WHERE id = ?",
        (row["product_id"],),
    ).fetchone()

    size_name = None
    if row["pot_size_id"]:
        psize = cur.execute("SELECT name FROM pot_sizes WHERE id = ?", (row["pot_size_id"],)).fetchone()
        size_name = psize["name"] if psize else None

    material_name = None
    if row["pot_material_id"]:
        mat = cur.execute("SELECT name FROM pot_materials WHERE id = ?", (row["pot_material_id"],)).fetchone()
        material_name = mat["name"] if mat else None

    color_name = None
    if row["pot_color_id"]:
        clr = cur.execute("SELECT name FROM pot_colors WHERE id = ?", (row["pot_color_id"],)).fetchone()
        color_name = clr["name"] if clr else None

    return {
        "id": row["id"],
        "user_id": row["user_id"],
        "product_id": row["product_id"],
        "plant_id": row["product_id"],
        "product_name": product["name"] if product else None,
        "image_url": product["image_url"] if product else None,
        "quantity": int(row["quantity"]),
        "pot_size_id": row["pot_size_id"],
        "pot_size": size_name,
        "pot_material_id": row["pot_material_id"],
        "pot_material": material_name,
        "pot_color_id": row["pot_color_id"],
        "pot_color": color_name,
        "product_unit_price": float(row["product_unit_price"]),
        "pot_unit_price": float(row["pot_unit_price"]),
        "total_price": float(row["total_price"]),
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


@router.get("/items")
def get_cart_items(user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        rows = cur.execute(
            """
            SELECT *
            FROM cart_items
            WHERE user_id = ?
            ORDER BY created_at DESC
            """,
            (user["id"],),
        ).fetchall()

        items = [_cart_item_to_dict(cur, row) for row in rows]
    finally:
        conn.close()

    total_items = sum(item["quantity"] for item in items)
    total_price = sum(item["total_price"] for item in items)

    return {
        "success": True,
        "data": {
            "items": items,
            "summary": {
                "total_items": total_items,
                "total_price": round(float(total_price), 2),
                "items_count": len(items),
            },
        },
    }


@router.post("/items", status_code=status.HTTP_201_CREATED)
def add_to_cart(payload: CartAddRequest, response: Response, user=Depends(get_current_user)):
    product_id = payload.product_id or payload.plant_id

    conn = get_db_connection()
    try:
        cur = conn.cursor()

        product = _resolve_product(cur, product_id)

        pot_size_id = _resolve_option_id(cur, "pot_sizes", payload.pot_size_id, payload.pot_size)
        pot_material_id = _resolve_option_id(cur, "pot_materials", payload.pot_material_id, payload.pot_material)
        pot_color_id = _resolve_option_id(cur, "pot_colors", payload.pot_color_id, payload.pot_color)

        pot_unit_price = _resolve_pot_unit_price(cur, pot_size_id, pot_material_id)

        existing = cur.execute(
            """
            SELECT *
            FROM cart_items
            WHERE user_id = ?
              AND product_id = ?
              AND IFNULL(pot_size_id, 0) = IFNULL(?, 0)
              AND IFNULL(pot_material_id, 0) = IFNULL(?, 0)
              AND IFNULL(pot_color_id, 0) = IFNULL(?, 0)
            LIMIT 1
            """,
            (user["id"], product_id, pot_size_id, pot_material_id, pot_color_id),
        ).fetchone()

        current_quantity = int(existing["quantity"]) if existing else 0
        requested_quantity = current_quantity + payload.quantity

        if requested_quantity > int(product["available_qty"]):
            raise HTTPException(
                status_code=400,
                detail=f"Not enough product in stock. Available: {int(product['available_qty'])}",
            )

        product_unit_price = float(product["base_price"])
        total_price = round((product_unit_price + pot_unit_price) * requested_quantity, 2)

        if existing:
            cur.execute(
                """
                UPDATE cart_items
                SET quantity = ?,
                    product_unit_price = ?,
                    pot_unit_price = ?,
                    total_price = ?
                WHERE id = ?
                """,
                (requested_quantity, product_unit_price, pot_unit_price, total_price, existing["id"]),
            )
            item_id = existing["id"]
            message = "Cart item updated"
            response.status_code = status.HTTP_200_OK
        else:
            cur.execute(
                """
                INSERT INTO cart_items (
                    user_id,
                    product_id,
                    quantity,
                    pot_size_id,
                    pot_material_id,
                    pot_color_id,
                    product_unit_price,
                    pot_unit_price,
                    total_price
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    user["id"],
                    product_id,
                    payload.quantity,
                    pot_size_id,
                    pot_material_id,
                    pot_color_id,
                    product_unit_price,
                    pot_unit_price,
                    round((product_unit_price + pot_unit_price) * payload.quantity, 2),
                ),
            )
            item_id = cur.lastrowid
            message = "Item added to cart"

        conn.commit()

        item_row = cur.execute("SELECT * FROM cart_items WHERE id = ?", (item_id,)).fetchone()
        item_data = _cart_item_to_dict(cur, item_row)
    finally:
        conn.close()

    return {
        "success": True,
        "message": message,
        "data": item_data,
    }


@router.put("/items/{item_id}")
def update_cart_item(item_id: int, payload: CartUpdateRequest, user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        item = cur.execute(
            "SELECT * FROM cart_items WHERE id = ? AND user_id = ?",
            (item_id, user["id"]),
        ).fetchone()
        if not item:
            raise HTTPException(status_code=404, detail="Cart item not found")

        if payload.quantity == 0:
            cur.execute("DELETE FROM cart_items WHERE id = ?", (item_id,))
            conn.commit()
            return {"success": True, "message": "Item removed from cart", "data": None}

        product = _resolve_product(cur, int(item["product_id"]))
        if payload.quantity > int(product["available_qty"]):
            raise HTTPException(
                status_code=400,
                detail=f"Not enough product in stock. Available: {int(product['available_qty'])}",
            )

        total_price = round((float(item["product_unit_price"]) + float(item["pot_unit_price"])) * payload.quantity, 2)
        cur.execute(
            "UPDATE cart_items SET quantity = ?, total_price = ? WHERE id = ?",
            (payload.quantity, total_price, item_id),
        )
        conn.commit()

        updated = cur.execute("SELECT * FROM cart_items WHERE id = ?", (item_id,)).fetchone()
        item_data = _cart_item_to_dict(cur, updated)
    finally:
        conn.close()

    return {"success": True, "message": "Cart updated", "data": item_data}


@router.delete("/items/{item_id}")
def remove_from_cart(item_id: int, user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        item = cur.execute(
            "SELECT id FROM cart_items WHERE id = ? AND user_id = ?",
            (item_id, user["id"]),
        ).fetchone()
        if not item:
            raise HTTPException(status_code=404, detail="Cart item not found")

        cur.execute("DELETE FROM cart_items WHERE id = ?", (item_id,))
        conn.commit()
    finally:
        conn.close()

    return {"success": True, "message": "Item removed from cart"}


@router.delete("/clear")
def clear_cart(user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        conn.execute("DELETE FROM cart_items WHERE user_id = ?", (user["id"],))
        conn.commit()
    finally:
        conn.close()
    return {"success": True, "message": "Cart cleared"}


@router.get("/wishlist")
def get_wishlist(user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        rows = conn.execute(
            """
            SELECT wi.id, wi.user_id, wi.product_id, wi.created_at,
                   p.name AS product_name, p.image_url
            FROM wishlist_items wi
            JOIN products p ON p.id = wi.product_id
            WHERE wi.user_id = ?
            ORDER BY wi.created_at DESC
            """,
            (user["id"],),
        ).fetchall()
    finally:
        conn.close()

    items = [
        {
            "id": row["id"],
            "user_id": row["user_id"],
            "product_id": row["product_id"],
            "plant_id": row["product_id"],
            "product_name": row["product_name"],
            "image_url": row["image_url"],
            "created_at": row["created_at"],
        }
        for row in rows
    ]
    return {"success": True, "data": {"items": items, "count": len(items)}}


@router.post("/wishlist", status_code=status.HTTP_201_CREATED)
def add_to_wishlist(payload: WishlistRequest, user=Depends(get_current_user)):
    product_id = payload.product_id or payload.plant_id

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        _resolve_product(cur, product_id)

        existing = cur.execute(
            "SELECT id FROM wishlist_items WHERE user_id = ? AND product_id = ?",
            (user["id"], product_id),
        ).fetchone()
        if existing:
            raise HTTPException(status_code=400, detail="Item already in wishlist")

        cur.execute(
            "INSERT INTO wishlist_items (user_id, product_id) VALUES (?, ?)",
            (user["id"], product_id),
        )
        item_id = cur.lastrowid
        conn.commit()
    finally:
        conn.close()

    return {
        "success": True,
        "message": "Item added to wishlist",
        "data": {"id": item_id, "user_id": int(user["id"]), "product_id": int(product_id), "plant_id": int(product_id)},
    }


@router.delete("/wishlist/{plant_id}")
def remove_from_wishlist(plant_id: int, user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        row = cur.execute(
            "SELECT id FROM wishlist_items WHERE user_id = ? AND product_id = ?",
            (user["id"], plant_id),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Wishlist item not found")

        cur.execute("DELETE FROM wishlist_items WHERE id = ?", (row["id"],))
        conn.commit()
    finally:
        conn.close()

    return {"success": True, "message": "Item removed from wishlist"}


@router.get("/wishlist/check/{plant_id}")
def check_wishlist(plant_id: int, user=Depends(get_current_user)):
    conn = get_db_connection()
    try:
        exists = conn.execute(
            "SELECT 1 FROM wishlist_items WHERE user_id = ? AND product_id = ? LIMIT 1",
            (user["id"], plant_id),
        ).fetchone()
    finally:
        conn.close()

    return {"success": True, "data": {"in_wishlist": exists is not None}}


@router.get("/pot/price")
def get_pot_price(
    material: Optional[str] = Query(default=None, max_length=50),
    size: Optional[str] = Query(default=None, max_length=50),
    material_id: Optional[int] = Query(default=None, ge=1),
    size_id: Optional[int] = Query(default=None, ge=1),
):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        resolved_size_id = _resolve_option_id(cur, "pot_sizes", size_id, size)
        resolved_material_id = _resolve_option_id(cur, "pot_materials", material_id, material)

        if resolved_size_id is None or resolved_material_id is None:
            raise HTTPException(status_code=400, detail="Material and size are required")

        row = cur.execute(
            """
            SELECT
                pp.price,
                ps.id AS size_id,
                ps.name AS size_name,
                pm.id AS material_id,
                pm.name AS material_name
            FROM pot_prices pp
            JOIN pot_sizes ps ON ps.id = pp.size_id
            JOIN pot_materials pm ON pm.id = pp.material_id
            WHERE pp.size_id = ? AND pp.material_id = ?
            LIMIT 1
            """,
            (resolved_size_id, resolved_material_id),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Price not found")
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "price": float(row["price"]),
            "material_id": row["material_id"],
            "material": row["material_name"],
            "size_id": row["size_id"],
            "size": row["size_name"],
        },
    }
