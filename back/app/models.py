from __future__ import annotations

import os
import sqlite3
from pathlib import Path
from typing import Optional, Any, Iterable
from dataclasses import dataclass, field

from dotenv import load_dotenv


# корень проекта
BASE_DIR = Path(__file__).resolve().parents[1]

# загружаем .env
load_dotenv(BASE_DIR / ".env")

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///flower_shop.db")


def _extract_sqlite_path(url: str) -> str:
    if url.startswith("sqlite:///"):
        return url.replace("sqlite:///", "", 1)
    return url


DB_PATH = BASE_DIR / _extract_sqlite_path(DATABASE_URL)


def get_connection() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn

# DATACLASS-МОДЕЛИ

@dataclass(slots=True)
class Store:
    id: int
    name: str
    address: str
    phone: Optional[str]
    email: Optional[str]
    store_type: str
    is_active: bool
    created_at: str
    updated_at: str


@dataclass(slots=True)
class User:
    id: int
    telegram_id: int
    full_name: str
    phone: str
    avatar_url: Optional[str]
    status: str
    blocked_at: Optional[str]
    blocked_reason: Optional[str]
    deleted_at: Optional[str]
    created_at: str
    updated_at: str


@dataclass(slots=True)
class UserAddress:
    id: int
    user_id: int
    address: str
    comment: Optional[str]
    is_default: bool
    created_at: str


@dataclass(slots=True)
class UserSession:
    id: int
    user_id: int
    device_id: Optional[str]
    session_token: str
    refresh_token: Optional[str]
    device_name: Optional[str]
    platform: Optional[str]
    ip_address: Optional[str]
    user_agent: Optional[str]
    is_active: bool
    expires_at: str
    last_seen_at: Optional[str]
    revoked_at: Optional[str]
    revoke_reason: Optional[str]
    created_at: str


@dataclass(slots=True)
class Company:
    id: int
    name: str
    owner_user_id: int
    status: str
    created_at: str
    updated_at: str


@dataclass(slots=True)
class CompanyMember:
    id: int
    company_id: int
    user_id: int
    role: str
    is_active: bool
    created_at: str


@dataclass(slots=True)
class SubscriptionPlan:
    id: int
    code: str
    name: str
    monthly_price: float
    yearly_price: float
    max_members: int
    can_create_company: bool
    has_extended_features: bool
    is_active: bool
    created_at: str


@dataclass(slots=True)
class Subscription:
    id: int
    plan_id: int
    user_id: Optional[int]
    company_id: Optional[int]
    billing_period: str
    status: str
    auto_renew: bool
    starts_at: str
    expires_at: str
    blocked_at: Optional[str]
    delete_after_at: Optional[str]
    created_at: str
    updated_at: str


@dataclass(slots=True)
class ProductImage:
    id: int
    product_id: int
    image_url: str
    created_at: str


@dataclass(slots=True)
class Product:
    id: int
    sku: Optional[str]
    name: str
    description: Optional[str]
    category_id: int
    plant_type_id: int
    supplier_id: Optional[int]
    base_price: float
    cost_price: float
    recommended_pot_size_id: Optional[int]
    height_cm: Optional[int]
    light_requirements: Optional[str]
    watering_notes: Optional[str]
    care_instructions: Optional[str]
    image_url: Optional[str]
    rating: float
    is_active: bool
    deleted_at: Optional[str]
    created_at: str
    updated_at: str
    images: list[ProductImage] = field(default_factory=list)


@dataclass(slots=True)
class CartItem:
    id: int
    user_id: int
    product_id: int
    quantity: int
    pot_size_id: Optional[int]
    pot_material_id: Optional[int]
    pot_color_id: Optional[int]
    product_unit_price: float
    pot_unit_price: float
    total_price: float
    created_at: str
    updated_at: str


@dataclass(slots=True)
class WishlistItem:
    id: int
    user_id: int
    product_id: int
    created_at: str


@dataclass(slots=True)
class Order:
    id: int
    user_id: int
    company_id: Optional[int]
    store_id: int
    order_number: str
    order_type: str
    address_id: Optional[int]
    address_snapshot: Optional[str]
    comment: Optional[str]
    subtotal: float
    delivery_fee: float
    discount_amount: float
    total_price: float
    payment_status: str
    status: str
    assigned_employee_id: Optional[int]
    created_at: str
    updated_at: str


@dataclass(slots=True)
class OrderItem:
    id: int
    order_id: int
    product_id: Optional[int]
    product_name_snapshot: str
    product_description_snapshot: Optional[str]
    quantity: int
    product_unit_price: float
    product_cost_price: float
    pot_size_id: Optional[int]
    pot_material_id: Optional[int]
    pot_color_id: Optional[int]
    pot_unit_price: float
    discount_amount: float
    total_price: float
    returned_quantity: int
    created_at: str


@dataclass(slots=True)
class CalendarEvent:
    id: int
    user_id: int
    event_date: str
    event_time: Optional[str]
    title: str
    description: Optional[str]
    is_all_day: bool
    reminder_enabled: bool
    reminder_minutes_before: Optional[int]
    created_at: str
    updated_at: str


@dataclass(slots=True)
class UserPlant:
    id: int
    user_id: int
    product_id: Optional[int]
    custom_name: Optional[str]
    plant_name: str
    photo_url: Optional[str]
    light_requirements: Optional[str]
    watering_frequency_days: Optional[int]
    soil_change_frequency_days: Optional[int]
    pot_size_text: Optional[str]
    notes: Optional[str]
    last_watered_at: Optional[str]
    next_watering_at: Optional[str]
    last_repot_at: Optional[str]
    next_repot_at: Optional[str]
    last_soil_change_at: Optional[str]
    next_soil_change_at: Optional[str]
    created_at: str
    updated_at: str


@dataclass(slots=True)
class UserPlantCareLog:
    id: int
    user_plant_id: int
    care_type: str
    care_at: str
    notes: Optional[str]
    created_at: str


@dataclass(slots=True)
class InventoryItem:
    id: int
    store_id: int
    product_id: int
    quantity_on_hand: int
    quantity_reserved: int
    quantity_available: int
    reorder_point: int
    updated_at: str



# ФИЛЬТРЫ


@dataclass(slots=True)
class ProductFilter:
    query: Optional[str] = None
    category_id: Optional[int] = None
    plant_type_id: Optional[int] = None
    supplier_id: Optional[int] = None
    is_active: Optional[bool] = True
    min_price: Optional[float] = None
    max_price: Optional[float] = None
    min_rating: Optional[float] = None
    light_requirements: Optional[str] = None
    sort_by: str = "name"
    limit: int = 100
    offset: int = 0


@dataclass(slots=True)
class OrderFilter:
    user_id: Optional[int] = None
    company_id: Optional[int] = None
    store_id: Optional[int] = None
    status: Optional[str] = None
    payment_status: Optional[str] = None
    order_type: Optional[str] = None
    sort_by: str = "created_desc"
    limit: int = 100
    offset: int = 0



# БАЗОВЫЙ DB HELPER


class DatabaseManager:
    def fetch_one(self, query: str, params: Iterable[Any] = ()) -> Optional[sqlite3.Row]:
        with get_connection() as conn:
            cur = conn.execute(query, tuple(params))
            return cur.fetchone()

    def fetch_all(self, query: str, params: Iterable[Any] = ()) -> list[sqlite3.Row]:
        with get_connection() as conn:
            cur = conn.execute(query, tuple(params))
            return cur.fetchall()

    def execute(self, query: str, params: Iterable[Any] = ()) -> int:
        with get_connection() as conn:
            cur = conn.execute(query, tuple(params))
            conn.commit()
            return cur.lastrowid

    def executemany(self, query: str, params_seq: Iterable[Iterable[Any]]) -> None:
        with get_connection() as conn:
            conn.executemany(query, params_seq)
            conn.commit()


db = DatabaseManager()



# MAPPERS


def _to_store(row: sqlite3.Row) -> Store:
    return Store(
        id=row["id"],
        name=row["name"],
        address=row["address"],
        phone=row["phone"],
        email=row["email"],
        store_type=row["store_type"],
        is_active=bool(row["is_active"]),
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


def _to_user(row: sqlite3.Row) -> User:
    return User(
        id=row["id"],
        telegram_id=row["telegram_id"],
        full_name=row["full_name"],
        phone=row["phone"],
        avatar_url=row["avatar_url"],
        status=row["status"],
        blocked_at=row["blocked_at"],
        blocked_reason=row["blocked_reason"],
        deleted_at=row["deleted_at"],
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


def _to_user_address(row: sqlite3.Row) -> UserAddress:
    return UserAddress(
        id=row["id"],
        user_id=row["user_id"],
        address=row["address"],
        comment=row["comment"],
        is_default=bool(row["is_default"]),
        created_at=row["created_at"],
    )


def _to_user_session(row: sqlite3.Row) -> UserSession:
    return UserSession(
        id=row["id"],
        user_id=row["user_id"],
        device_id=row["device_id"],
        session_token=row["session_token"],
        refresh_token=row["refresh_token"],
        device_name=row["device_name"],
        platform=row["platform"],
        ip_address=row["ip_address"],
        user_agent=row["user_agent"],
        is_active=bool(row["is_active"]),
        expires_at=row["expires_at"],
        last_seen_at=row["last_seen_at"],
        revoked_at=row["revoked_at"],
        revoke_reason=row["revoke_reason"],
        created_at=row["created_at"],
    )


def _to_company(row: sqlite3.Row) -> Company:
    return Company(
        id=row["id"],
        name=row["name"],
        owner_user_id=row["owner_user_id"],
        status=row["status"],
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


def _to_company_member(row: sqlite3.Row) -> CompanyMember:
    return CompanyMember(
        id=row["id"],
        company_id=row["company_id"],
        user_id=row["user_id"],
        role=row["role"],
        is_active=bool(row["is_active"]),
        created_at=row["created_at"],
    )


def _to_subscription_plan(row: sqlite3.Row) -> SubscriptionPlan:
    return SubscriptionPlan(
        id=row["id"],
        code=row["code"],
        name=row["name"],
        monthly_price=float(row["monthly_price"]),
        yearly_price=float(row["yearly_price"]),
        max_members=row["max_members"],
        can_create_company=bool(row["can_create_company"]),
        has_extended_features=bool(row["has_extended_features"]),
        is_active=bool(row["is_active"]),
        created_at=row["created_at"],
    )


def _to_subscription(row: sqlite3.Row) -> Subscription:
    return Subscription(
        id=row["id"],
        plan_id=row["plan_id"],
        user_id=row["user_id"],
        company_id=row["company_id"],
        billing_period=row["billing_period"],
        status=row["status"],
        auto_renew=bool(row["auto_renew"]),
        starts_at=row["starts_at"],
        expires_at=row["expires_at"],
        blocked_at=row["blocked_at"],
        delete_after_at=row["delete_after_at"],
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


def _to_product_image(row: sqlite3.Row) -> ProductImage:
    return ProductImage(
        id=row["id"],
        product_id=row["product_id"],
        image_url=row["image_url"],
        created_at=row["created_at"],
    )


def _to_product(row: sqlite3.Row) -> Product:
    return Product(
        id=row["id"],
        sku=row["sku"],
        name=row["name"],
        description=row["description"],
        category_id=row["category_id"],
        plant_type_id=row["plant_type_id"],
        supplier_id=row["supplier_id"],
        base_price=float(row["base_price"]),
        cost_price=float(row["cost_price"]),
        recommended_pot_size_id=row["recommended_pot_size_id"],
        height_cm=row["height_cm"],
        light_requirements=row["light_requirements"],
        watering_notes=row["watering_notes"],
        care_instructions=row["care_instructions"],
        image_url=row["image_url"],
        rating=float(row["rating"]),
        is_active=bool(row["is_active"]),
        deleted_at=row["deleted_at"],
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


def _to_cart_item(row: sqlite3.Row) -> CartItem:
    return CartItem(
        id=row["id"],
        user_id=row["user_id"],
        product_id=row["product_id"],
        quantity=row["quantity"],
        pot_size_id=row["pot_size_id"],
        pot_material_id=row["pot_material_id"],
        pot_color_id=row["pot_color_id"],
        product_unit_price=float(row["product_unit_price"]),
        pot_unit_price=float(row["pot_unit_price"]),
        total_price=float(row["total_price"]),
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


def _to_wishlist_item(row: sqlite3.Row) -> WishlistItem:
    return WishlistItem(
        id=row["id"],
        user_id=row["user_id"],
        product_id=row["product_id"],
        created_at=row["created_at"],
    )


def _to_order(row: sqlite3.Row) -> Order:
    return Order(
        id=row["id"],
        user_id=row["user_id"],
        company_id=row["company_id"],
        store_id=row["store_id"],
        order_number=row["order_number"],
        order_type=row["order_type"],
        address_id=row["address_id"],
        address_snapshot=row["address_snapshot"],
        comment=row["comment"],
        subtotal=float(row["subtotal"]),
        delivery_fee=float(row["delivery_fee"]),
        discount_amount=float(row["discount_amount"]),
        total_price=float(row["total_price"]),
        payment_status=row["payment_status"],
        status=row["status"],
        assigned_employee_id=row["assigned_employee_id"],
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


def _to_order_item(row: sqlite3.Row) -> OrderItem:
    return OrderItem(
        id=row["id"],
        order_id=row["order_id"],
        product_id=row["product_id"],
        product_name_snapshot=row["product_name_snapshot"],
        product_description_snapshot=row["product_description_snapshot"],
        quantity=row["quantity"],
        product_unit_price=float(row["product_unit_price"]),
        product_cost_price=float(row["product_cost_price"]),
        pot_size_id=row["pot_size_id"],
        pot_material_id=row["pot_material_id"],
        pot_color_id=row["pot_color_id"],
        pot_unit_price=float(row["pot_unit_price"]),
        discount_amount=float(row["discount_amount"]),
        total_price=float(row["total_price"]),
        returned_quantity=row["returned_quantity"],
        created_at=row["created_at"],
    )


def _to_calendar_event(row: sqlite3.Row) -> CalendarEvent:
    return CalendarEvent(
        id=row["id"],
        user_id=row["user_id"],
        event_date=row["event_date"],
        event_time=row["event_time"],
        title=row["title"],
        description=row["description"],
        is_all_day=bool(row["is_all_day"]),
        reminder_enabled=bool(row["reminder_enabled"]),
        reminder_minutes_before=row["reminder_minutes_before"],
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


def _to_user_plant(row: sqlite3.Row) -> UserPlant:
    return UserPlant(
        id=row["id"],
        user_id=row["user_id"],
        product_id=row["product_id"],
        custom_name=row["custom_name"],
        plant_name=row["plant_name"],
        photo_url=row["photo_url"],
        light_requirements=row["light_requirements"],
        watering_frequency_days=row["watering_frequency_days"],
        pot_size_text=row["pot_size_text"],
        notes=row["notes"],
        last_watered_at=row["last_watered_at"],
        next_watering_at=row["next_watering_at"],
        last_repot_at=row["last_repot_at"],
        next_repot_at=row["next_repot_at"],
        last_soil_change_at=row["last_soil_change_at"],
        next_soil_change_at=row["next_soil_change_at"],
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


def _to_user_plant_care_log(row: sqlite3.Row) -> UserPlantCareLog:
    return UserPlantCareLog(
        id=row["id"],
        user_plant_id=row["user_plant_id"],
        care_type=row["care_type"],
        care_at=row["care_at"],
        notes=row["notes"],
        created_at=row["created_at"],
    )


def _to_inventory_item(row: sqlite3.Row) -> InventoryItem:
    return InventoryItem(
        id=row["id"],
        store_id=row["store_id"],
        product_id=row["product_id"],
        quantity_on_hand=row["quantity_on_hand"],
        quantity_reserved=row["quantity_reserved"],
        quantity_available=row["quantity_available"],
        reorder_point=row["reorder_point"],
        updated_at=row["updated_at"],
    )



# REPOSITORIES


class ProductRepository:
    @staticmethod
    def _build_sort(sort_by: str) -> str:
        mapping = {
            "name": "p.name ASC",
            "price_asc": "p.base_price ASC",
            "price_desc": "p.base_price DESC",
            "rating_desc": "p.rating DESC, p.name ASC",
            "created_desc": "p.created_at DESC",
        }
        return mapping.get(sort_by, "p.name ASC")

    def get_by_id(self, product_id: int, with_images: bool = True) -> Optional[Product]:
        row = db.fetch_one("SELECT * FROM products WHERE id = ?", (product_id,))
        if not row:
            return None

        product = _to_product(row)
        if with_images:
            product.images = self.get_images(product.id)
        return product

    def get_images(self, product_id: int, active_only: bool = True) -> list[ProductImage]:
        sql = "SELECT * FROM product_images WHERE product_id = ?"
        params: list[Any] = [product_id]

        # Kept for backward compatibility; product_images no longer has is_active.
        _ = active_only
        sql += " ORDER BY id ASC"
        rows = db.fetch_all(sql, params)
        return [_to_product_image(row) for row in rows]

    def search(self, filt: ProductFilter) -> list[Product]:
        sql = """
            SELECT p.*
            FROM products p
            WHERE 1=1
        """
        params: list[Any] = []

        if filt.is_active is not None:
            sql += " AND p.is_active = ?"
            params.append(int(filt.is_active))

        if filt.query:
            q = f"%{filt.query.strip()}%"
            sql += """
                AND (
                    p.name LIKE ?
                    OR p.description LIKE ?
                    OR p.sku LIKE ?
                )
            """
            params.extend([q, q, q])

        if filt.category_id is not None:
            sql += " AND p.category_id = ?"
            params.append(filt.category_id)

        if filt.plant_type_id is not None:
            sql += " AND p.plant_type_id = ?"
            params.append(filt.plant_type_id)

        if filt.supplier_id is not None:
            sql += " AND p.supplier_id = ?"
            params.append(filt.supplier_id)

        if filt.min_price is not None:
            sql += " AND p.base_price >= ?"
            params.append(filt.min_price)

        if filt.max_price is not None:
            sql += " AND p.base_price <= ?"
            params.append(filt.max_price)

        if filt.min_rating is not None:
            sql += " AND p.rating >= ?"
            params.append(filt.min_rating)

        if filt.light_requirements:
            sql += " AND p.light_requirements = ?"
            params.append(filt.light_requirements)

        sql += f" ORDER BY {self._build_sort(filt.sort_by)} LIMIT ? OFFSET ?"
        params.extend([filt.limit, filt.offset])

        rows = db.fetch_all(sql, params)
        products = [_to_product(row) for row in rows]

        for product in products:
            product.images = self.get_images(product.id)

        return products

    def get_deleted_or_inactive(self, limit: int = 100) -> list[Product]:
        rows = db.fetch_all(
            """
            SELECT *
            FROM products
            WHERE is_active = 0 OR deleted_at IS NOT NULL
            ORDER BY updated_at DESC
            LIMIT ?
            """,
            (limit,),
        )
        return [_to_product(row) for row in rows]


class UserRepository:
    def get_by_id(self, user_id: int) -> Optional[User]:
        row = db.fetch_one("SELECT * FROM users WHERE id = ?", (user_id,))
        return _to_user(row) if row else None

    def get_by_telegram_id(self, telegram_id: int) -> Optional[User]:
        row = db.fetch_one("SELECT * FROM users WHERE telegram_id = ?", (telegram_id,))
        return _to_user(row) if row else None

    def search(self, query: str, limit: int = 50, offset: int = 0) -> list[User]:
        q = f"%{query.strip()}%"
        rows = db.fetch_all(
            """
            SELECT *
            FROM users
            WHERE full_name LIKE ?
               OR phone LIKE ?
            ORDER BY full_name ASC
            LIMIT ? OFFSET ?
            """,
            (q, q, limit, offset),
        )
        return [_to_user(row) for row in rows]

    def get_addresses(self, user_id: int) -> list[UserAddress]:
        rows = db.fetch_all(
            """
            SELECT *
            FROM user_addresses
            WHERE user_id = ?
            ORDER BY is_default DESC, id ASC
            """,
            (user_id,),
        )
        return [_to_user_address(row) for row in rows]

    def get_sessions(self, user_id: int, active_only: bool = False) -> list[UserSession]:
        sql = "SELECT * FROM user_sessions WHERE user_id = ?"
        params: list[Any] = [user_id]

        if active_only:
            sql += " AND is_active = 1"

        sql += " ORDER BY created_at DESC"
        rows = db.fetch_all(sql, params)
        return [_to_user_session(row) for row in rows]


class CompanyRepository:
    def get_by_id(self, company_id: int) -> Optional[Company]:
        row = db.fetch_one("SELECT * FROM companies WHERE id = ?", (company_id,))
        return _to_company(row) if row else None

    def get_by_owner(self, owner_user_id: int) -> list[Company]:
        rows = db.fetch_all(
            "SELECT * FROM companies WHERE owner_user_id = ? ORDER BY created_at DESC",
            (owner_user_id,),
        )
        return [_to_company(row) for row in rows]

    def get_members(self, company_id: int, active_only: bool = True) -> list[CompanyMember]:
        sql = "SELECT * FROM company_members WHERE company_id = ?"
        params: list[Any] = [company_id]

        if active_only:
            sql += " AND is_active = 1"

        sql += " ORDER BY role DESC, id ASC"
        rows = db.fetch_all(sql, params)
        return [_to_company_member(row) for row in rows]


class SubscriptionRepository:
    def get_plan_by_code(self, code: str) -> Optional[SubscriptionPlan]:
        row = db.fetch_one("SELECT * FROM subscription_plans WHERE code = ?", (code,))
        return _to_subscription_plan(row) if row else None

    def get_user_subscription(self, user_id: int) -> Optional[Subscription]:
        row = db.fetch_one(
            """
            SELECT *
            FROM subscriptions
            WHERE user_id = ?
            ORDER BY created_at DESC
            LIMIT 1
            """,
            (user_id,),
        )
        return _to_subscription(row) if row else None

    def get_company_subscription(self, company_id: int) -> Optional[Subscription]:
        row = db.fetch_one(
            """
            SELECT *
            FROM subscriptions
            WHERE company_id = ?
            ORDER BY created_at DESC
            LIMIT 1
            """,
            (company_id,),
        )
        return _to_subscription(row) if row else None


class WishlistRepository:
    def get_user_wishlist(self, user_id: int) -> list[WishlistItem]:
        rows = db.fetch_all(
            """
            SELECT *
            FROM wishlist_items
            WHERE user_id = ?
            ORDER BY created_at DESC
            """,
            (user_id,),
        )
        return [_to_wishlist_item(row) for row in rows]


class CartRepository:
    def get_user_cart(self, user_id: int) -> list[CartItem]:
        rows = db.fetch_all(
            """
            SELECT *
            FROM cart_items
            WHERE user_id = ?
            ORDER BY created_at DESC
            """,
            (user_id,),
        )
        return [_to_cart_item(row) for row in rows]


class OrderRepository:
    @staticmethod
    def _build_sort(sort_by: str) -> str:
        mapping = {
            "created_desc": "o.created_at DESC",
            "created_asc": "o.created_at ASC",
            "price_desc": "o.total_price DESC",
            "price_asc": "o.total_price ASC",
        }
        return mapping.get(sort_by, "o.created_at DESC")

    def get_by_id(self, order_id: int) -> Optional[Order]:
        row = db.fetch_one("SELECT * FROM orders o WHERE o.id = ?", (order_id,))
        return _to_order(row) if row else None

    def get_by_number(self, order_number: str) -> Optional[Order]:
        row = db.fetch_one("SELECT * FROM orders WHERE order_number = ?", (order_number,))
        return _to_order(row) if row else None

    def search(self, filt: OrderFilter) -> list[Order]:
        sql = """
            SELECT o.*
            FROM orders o
            WHERE 1=1
        """
        params: list[Any] = []

        if filt.user_id is not None:
            sql += " AND o.user_id = ?"
            params.append(filt.user_id)

        if filt.company_id is not None:
            sql += " AND o.company_id = ?"
            params.append(filt.company_id)

        if filt.store_id is not None:
            sql += " AND o.store_id = ?"
            params.append(filt.store_id)

        if filt.status is not None:
            sql += " AND o.status = ?"
            params.append(filt.status)

        if filt.payment_status is not None:
            sql += " AND o.payment_status = ?"
            params.append(filt.payment_status)

        if filt.order_type is not None:
            sql += " AND o.order_type = ?"
            params.append(filt.order_type)

        sql += f" ORDER BY {self._build_sort(filt.sort_by)} LIMIT ? OFFSET ?"
        params.extend([filt.limit, filt.offset])

        rows = db.fetch_all(sql, params)
        return [_to_order(row) for row in rows]

    def get_order_items(self, order_id: int) -> list[OrderItem]:
        rows = db.fetch_all(
            """
            SELECT *
            FROM order_items
            WHERE order_id = ?
            ORDER BY id ASC
            """,
            (order_id,),
        )
        return [_to_order_item(row) for row in rows]

    def get_user_history(self, user_id: int, limit: int = 100, offset: int = 0) -> list[Order]:
        rows = db.fetch_all(
            """
            SELECT *
            FROM orders
            WHERE user_id = ?
            ORDER BY created_at DESC
            LIMIT ? OFFSET ?
            """,
            (user_id, limit, offset),
        )
        return [_to_order(row) for row in rows]


class CalendarRepository:
    def get_user_events(self, user_id: int) -> list[CalendarEvent]:
        rows = db.fetch_all(
            """
            SELECT *
            FROM calendar_events
            WHERE user_id = ?
            ORDER BY event_date ASC, event_time ASC
            """,
            (user_id,),
        )
        return [_to_calendar_event(row) for row in rows]

    def get_user_events_for_day(self, user_id: int, event_date: str) -> list[CalendarEvent]:
        rows = db.fetch_all(
            """
            SELECT *
            FROM calendar_events
            WHERE user_id = ? AND event_date = ?
            ORDER BY event_time ASC
            """,
            (user_id, event_date),
        )
        return [_to_calendar_event(row) for row in rows]


class UserPlantRepository:
    def get_user_plants(self, user_id: int) -> list[UserPlant]:
        rows = db.fetch_all(
            """
            SELECT *
            FROM user_plants
            WHERE user_id = ?
            ORDER BY created_at DESC
            """,
            (user_id,),
        )
        return [_to_user_plant(row) for row in rows]

    def get_by_id(self, user_plant_id: int) -> Optional[UserPlant]:
        row = db.fetch_one(
            "SELECT * FROM user_plants WHERE id = ?",
            (user_plant_id,),
        )
        return _to_user_plant(row) if row else None

    def get_care_logs(self, user_plant_id: int) -> list[UserPlantCareLog]:
        rows = db.fetch_all(
            """
            SELECT *
            FROM user_plant_care_logs
            WHERE user_plant_id = ?
            ORDER BY care_at DESC
            """,
            (user_plant_id,),
        )
        return [_to_user_plant_care_log(row) for row in rows]

    def get_watering_due(self) -> list[UserPlant]:
        rows = db.fetch_all(
            """
            SELECT *
            FROM user_plants
            WHERE next_watering_at IS NOT NULL
            ORDER BY next_watering_at ASC
            """
        )
        return [_to_user_plant(row) for row in rows]


class InventoryRepository:
    def get_store_inventory(self, store_id: int) -> list[InventoryItem]:
        rows = db.fetch_all(
            """
            SELECT *
            FROM inventory
            WHERE store_id = ?
            ORDER BY product_id ASC
            """,
            (store_id,),
        )
        return [_to_inventory_item(row) for row in rows]

    def get_low_stock(self, store_id: Optional[int] = None) -> list[InventoryItem]:
        sql = """
            SELECT *
            FROM inventory
            WHERE quantity_available <= reorder_point
        """
        params: list[Any] = []

        if store_id is not None:
            sql += " AND store_id = ?"
            params.append(store_id)

        sql += " ORDER BY quantity_available ASC, reorder_point DESC"
        rows = db.fetch_all(sql, params)
        return [_to_inventory_item(row) for row in rows]


class StoreRepository:
    def get_all_active(self) -> list[Store]:
        rows = db.fetch_all(
            "SELECT * FROM stores WHERE is_active = 1 ORDER BY name ASC"
        )
        return [_to_store(row) for row in rows]

    def get_by_id(self, store_id: int) -> Optional[Store]:
        row = db.fetch_one("SELECT * FROM stores WHERE id = ?", (store_id,))
        return _to_store(row) if row else None



# ЕДИНАЯ ТОЧКА ВХОДА


class DataService:
    def __init__(self) -> None:
        self.products = ProductRepository()
        self.users = UserRepository()
        self.companies = CompanyRepository()
        self.subscriptions = SubscriptionRepository()
        self.wishlist = WishlistRepository()
        self.cart = CartRepository()
        self.orders = OrderRepository()
        self.calendar = CalendarRepository()
        self.user_plants = UserPlantRepository()
        self.inventory = InventoryRepository()
        self.stores = StoreRepository()


if __name__ == "__main__":
    service = DataService()


    # ТЕСТЫ ЗАПРОСОВ

    # print("=== Товары ===")
    # products = service.products.search(
    #     ProductFilter(query="фикус", sort_by="rating_desc", limit=20)
    # )
    # for product in products:
    #     print(product.id, product.name, product.base_price, product.rating)

    # print("\n=== История заказов пользователя ===")
    # orders = service.orders.get_user_history(user_id=1)
    # for order in orders:
    #     print(order.order_number, order.status, order.total_price)

    # print("\n=== Свои растения пользователя ===")
    # user_plants = service.user_plants.get_user_plants(user_id=1)
    # for plant in user_plants:
    #     print(plant.id, plant.custom_name, plant.next_watering_at)

    # print("\n=== Остатки магазина ===")
    # inventory_items = service.inventory.get_store_inventory(store_id=1)
    # for item in inventory_items[:5]:
    #     print(item.product_id, item.quantity_available, item.reorder_point)
