from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, HTTPException, Query

from app.db import get_db_connection

router = APIRouter(prefix="/api/pot", tags=["pot"])

DEFAULT_FREE_POT_SIZE_NAMES = ["S", "Small", "Маленький", "Малый"]
DEFAULT_FREE_POT_MATERIAL_NAMES = ["Пластик", "Plastic"]
DEFAULT_FREE_POT_COLOR_NAMES = ["Белый", "White"]


def _resolve_option_id(cur, table: str, option_id: Optional[int], option_name: Optional[str]) -> Optional[int]:
    if option_id is not None:
        row = cur.execute(f"SELECT id FROM {table} WHERE id = ?", (option_id,)).fetchone()
        return int(row["id"]) if row else None

    if option_name is not None:
        name = option_name.strip()
        if name:
            row = cur.execute(
                f"SELECT id FROM {table} WHERE LOWER(name) = LOWER(?)",
                (name,),
            ).fetchone()
            return int(row["id"]) if row else None
    return None


def _variant_rows(cur):
    rows = cur.execute(
        """
        SELECT
            vp.id,
            vp.size_id,
            vp.material_id,
            vp.color_id,
            vp.price,
            vp.is_active,
            ps.name AS size_name,
            pm.name AS material_name,
            pc.name AS color_name
        FROM pot_variant_prices vp
        JOIN pot_sizes ps ON ps.id = vp.size_id
        JOIN pot_materials pm ON pm.id = vp.material_id
        JOIN pot_colors pc ON pc.id = vp.color_id
        """
    ).fetchall()
    return [row for row in rows if int(row["is_active"] or 0) == 1]


def _default_option_id(cur, table: str, names: list[str]) -> Optional[int]:
    for name in names:
        resolved = _resolve_option_id(cur, table, None, name)
        if resolved is not None:
            return int(resolved)
    return None


def _first_option_id(cur, table: str) -> Optional[int]:
    row = cur.execute(f"SELECT id FROM {table} ORDER BY id LIMIT 1").fetchone()
    return int(row["id"]) if row else None


def _resolve_default_free_pot_ids(cur) -> tuple[Optional[int], Optional[int], Optional[int]]:
    size_id = _default_option_id(cur, "pot_sizes", DEFAULT_FREE_POT_SIZE_NAMES) or _first_option_id(cur, "pot_sizes")
    material_id = _default_option_id(cur, "pot_materials", DEFAULT_FREE_POT_MATERIAL_NAMES) or _first_option_id(cur, "pot_materials")
    color_id = _default_option_id(cur, "pot_colors", DEFAULT_FREE_POT_COLOR_NAMES) or _first_option_id(cur, "pot_colors")
    return size_id, material_id, color_id


def _is_default_free_pot(
    *,
    size_id: Optional[int],
    material_id: Optional[int],
    color_id: Optional[int],
    default_size_id: Optional[int],
    default_material_id: Optional[int],
    default_color_id: Optional[int],
) -> bool:
    if size_id is None or material_id is None:
        return False
    if default_size_id is None or default_material_id is None:
        return False
    if size_id != default_size_id or material_id != default_material_id:
        return False
    if default_color_id is None:
        return True
    return color_id is None or color_id == default_color_id


def _apply_default_pot_selection(
    *,
    size_id: Optional[int],
    material_id: Optional[int],
    color_id: Optional[int],
    default_size_id: Optional[int],
    default_material_id: Optional[int],
    default_color_id: Optional[int],
) -> tuple[int, int, Optional[int]]:
    if default_size_id is None or default_material_id is None:
        raise HTTPException(
            status_code=500,
            detail="Default free pot configuration is missing (S + Plastic + White)",
        )
    resolved_size_id = size_id if size_id is not None else default_size_id
    resolved_material_id = material_id if material_id is not None else default_material_id
    resolved_color_id = color_id if color_id is not None else default_color_id
    return int(resolved_size_id), int(resolved_material_id), resolved_color_id


@router.get("/sizes", summary="Get Pot Sizes")
def get_pot_sizes():
    conn = get_db_connection()
    try:
        rows = conn.execute(
            """
            SELECT id, name, diameter_cm, height_cm
            FROM pot_sizes
            ORDER BY name COLLATE NOCASE
            """
        ).fetchall()
    finally:
        conn.close()

    return {
        "success": True,
        "data": [
            {
                "id": int(row["id"]),
                "code": row["name"],
                "name": row["name"],
                "diameter_cm": row["diameter_cm"],
                "height_cm": row["height_cm"],
                "volume_liters": None,
            }
            for row in rows
        ],
    }


@router.get("/materials", summary="Get Pot Materials")
def get_pot_materials():
    conn = get_db_connection()
    try:
        rows = conn.execute(
            """
            SELECT id, name
            FROM pot_materials
            ORDER BY name COLLATE NOCASE
            """
        ).fetchall()
    finally:
        conn.close()

    return {
        "success": True,
        "data": [
            {
                "id": int(row["id"]),
                "name": row["name"],
                "description": None,
            }
            for row in rows
        ],
    }


@router.get("/colors", summary="Get Pot Colors")
def get_pot_colors():
    conn = get_db_connection()
    try:
        rows = conn.execute(
            """
            SELECT id, name, hex_code
            FROM pot_colors
            ORDER BY name COLLATE NOCASE
            """
        ).fetchall()
    finally:
        conn.close()

    return {
        "success": True,
        "data": [
            {
                "id": int(row["id"]),
                "name": row["name"],
                "hex_code": row["hex_code"],
            }
            for row in rows
        ],
    }


@router.get("/variants", summary="Get Pot Variants")
def get_pot_variants():
    conn = get_db_connection()
    try:
        variants = _variant_rows(conn.cursor())
    finally:
        conn.close()

    return {
        "success": True,
        "data": [
            {
                "id": int(row["id"]),
                "size_id": int(row["size_id"]),
                "size": row["size_name"],
                "material_id": int(row["material_id"]),
                "material": row["material_name"],
                "color_id": int(row["color_id"]),
                "color": row["color_name"],
                "price": float(row["price"]),
                "is_active": True,
            }
            for row in variants
        ],
    }


@router.get("/options", summary="Get Pot Options Availability")
def get_pot_options(
    material: Optional[str] = Query(default=None, max_length=50),
    size: Optional[str] = Query(default=None, max_length=50),
    color: Optional[str] = Query(default=None, max_length=50),
    material_id: Optional[int] = Query(default=None, ge=1),
    size_id: Optional[int] = Query(default=None, ge=1),
    color_id: Optional[int] = Query(default=None, ge=1),
):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        selected_size_id = _resolve_option_id(cur, "pot_sizes", size_id, size)
        selected_material_id = _resolve_option_id(cur, "pot_materials", material_id, material)
        selected_color_id = _resolve_option_id(cur, "pot_colors", color_id, color)

        sizes = cur.execute("SELECT id, name, diameter_cm, height_cm FROM pot_sizes ORDER BY name COLLATE NOCASE").fetchall()
        materials = cur.execute("SELECT id, name FROM pot_materials ORDER BY name COLLATE NOCASE").fetchall()
        colors = cur.execute("SELECT id, name, hex_code FROM pot_colors ORDER BY name COLLATE NOCASE").fetchall()
        variants = _variant_rows(cur)

        def _size_available(size_id_: int) -> bool:
            return any(
                int(v["size_id"]) == size_id_
                and (selected_material_id is None or int(v["material_id"]) == selected_material_id)
                and (selected_color_id is None or int(v["color_id"]) == selected_color_id)
                for v in variants
            )

        def _material_available(material_id_: int) -> bool:
            return any(
                int(v["material_id"]) == material_id_
                and (selected_size_id is None or int(v["size_id"]) == selected_size_id)
                and (selected_color_id is None or int(v["color_id"]) == selected_color_id)
                for v in variants
            )

        def _color_available(color_id_: int) -> bool:
            return any(
                int(v["color_id"]) == color_id_
                and (selected_size_id is None or int(v["size_id"]) == selected_size_id)
                and (selected_material_id is None or int(v["material_id"]) == selected_material_id)
                for v in variants
            )
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "selected": {
                "size_id": selected_size_id,
                "material_id": selected_material_id,
                "color_id": selected_color_id,
            },
            "sizes": [
                {
                    "id": int(s["id"]),
                    "code": s["name"],
                    "name": s["name"],
                    "diameter_cm": s["diameter_cm"],
                    "height_cm": s["height_cm"],
                    "volume_liters": None,
                    "is_available": _size_available(int(s["id"])),
                }
                for s in sizes
            ],
            "materials": [
                {
                    "id": int(m["id"]),
                    "name": m["name"],
                    "description": None,
                    "is_available": _material_available(int(m["id"])),
                }
                for m in materials
            ],
            "colors": [
                {
                    "id": int(c["id"]),
                    "name": c["name"],
                    "hex_code": c["hex_code"],
                    "is_available": _color_available(int(c["id"])),
                }
                for c in colors
            ],
        },
    }


@router.get("/prices", summary="Get Pot Prices")
def get_pot_prices():
    conn = get_db_connection()
    try:
        rows = conn.execute(
            """
            SELECT
                vp.id,
                vp.material_id,
                vp.size_id,
                vp.color_id,
                vp.price,
                vp.is_active,
                pm.name AS material_name,
                ps.name AS size_name,
                pc.name AS color_name
            FROM pot_variant_prices vp
            JOIN pot_materials pm ON pm.id = vp.material_id
            JOIN pot_sizes ps ON ps.id = vp.size_id
            JOIN pot_colors pc ON pc.id = vp.color_id
            ORDER BY pm.name COLLATE NOCASE, ps.name COLLATE NOCASE, pc.name COLLATE NOCASE
            """
        ).fetchall()
    finally:
        conn.close()

    return {
        "success": True,
        "data": [
            {
                "id": int(row["id"]),
                "material_id": int(row["material_id"]),
                "size_id": int(row["size_id"]),
                "color_id": int(row["color_id"]),
                "price": float(row["price"]),
                "is_active": bool(row["is_active"]),
                "material": row["material_name"],
                "size": row["size_name"],
                "color": row["color_name"],
            }
            for row in rows
        ],
    }


@router.get("/price", summary="Get Pot Price")
def get_pot_price(
    material: Optional[str] = Query(default=None, max_length=50),
    size: Optional[str] = Query(default=None, max_length=50),
    color: Optional[str] = Query(default=None, max_length=50),
    material_id: Optional[int] = Query(default=None, ge=1),
    size_id: Optional[int] = Query(default=None, ge=1),
    color_id: Optional[int] = Query(default=None, ge=1),
):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        resolved_size_id = _resolve_option_id(cur, "pot_sizes", size_id, size)
        resolved_material_id = _resolve_option_id(cur, "pot_materials", material_id, material)
        resolved_color_id = _resolve_option_id(cur, "pot_colors", color_id, color)
        default_size_id, default_material_id, default_color_id = _resolve_default_free_pot_ids(cur)

        resolved_size_id, resolved_material_id, resolved_color_id = _apply_default_pot_selection(
            size_id=resolved_size_id,
            material_id=resolved_material_id,
            color_id=resolved_color_id,
            default_size_id=default_size_id,
            default_material_id=default_material_id,
            default_color_id=default_color_id,
        )

        size_row = cur.execute(
            "SELECT id, name FROM pot_sizes WHERE id = ?",
            (resolved_size_id,),
        ).fetchone()
        material_row = cur.execute(
            "SELECT id, name FROM pot_materials WHERE id = ?",
            (resolved_material_id,),
        ).fetchone()
        color_row = None
        if resolved_color_id is not None:
            color_row = cur.execute(
                "SELECT id, name FROM pot_colors WHERE id = ?",
                (resolved_color_id,),
            ).fetchone()

        if _is_default_free_pot(
            size_id=resolved_size_id,
            material_id=resolved_material_id,
            color_id=resolved_color_id,
            default_size_id=default_size_id,
            default_material_id=default_material_id,
            default_color_id=default_color_id,
        ):
            price = 0.0
        else:
            row = cur.execute(
                """
                SELECT
                    pp.price
                FROM pot_prices pp
                WHERE pp.size_id = ? AND pp.material_id = ?
                LIMIT 1
                """,
                (resolved_size_id, resolved_material_id),
            ).fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Price not found")
            price = float(row["price"])
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "price": price,
            "material_id": int(material_row["id"]) if material_row else None,
            "material": material_row["name"] if material_row else None,
            "size_id": int(size_row["id"]) if size_row else None,
            "size": size_row["name"] if size_row else None,
            "color_id": int(color_row["id"]) if color_row else None,
            "color": color_row["name"] if color_row else None,
        },
    }
