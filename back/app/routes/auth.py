from __future__ import annotations

import base64
import json
import random
import re
import secrets
import uuid
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional
from urllib import error as urllib_error
from urllib import request as urllib_request

from fastapi import APIRouter, Depends, File, HTTPException, Header, UploadFile
from pydantic import BaseModel, ConfigDict, Field

from app.config import get_settings
from app.config import BASE_DIR
from app.db import get_db_connection
from app.routes.utils import (
    BLOCKED_IMAGE_PATH,
    clean_text,
    get_current_user,
    is_valid_session_token,
    normalize_device_id,
    normalize_token,
)

router = APIRouter(prefix="/api/auth", tags=["auth"])

CODE_PATTERN = re.compile(r"^\d{4,8}$")
PHONE_DIGITS_PATTERN = re.compile(r"\d")
ALLOWED_AVATAR_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".gif"}
MAX_AVATAR_SIZE_BYTES = 10 * 1024 * 1024
USER_AVATAR_DIR = BASE_DIR / "img" / "users"
BLOCKED_AVATAR_DB_PATH = "img/users/blocked.png"


class VerifyCodeRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    code: str = Field(min_length=4, max_length=8)
    device_id: Optional[str] = Field(default=None, max_length=255)


class UpdateProfileRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=2, max_length=100)
    phone: str = Field(min_length=10, max_length=25)


class ValidateTokenRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    token: str = Field(min_length=8, max_length=256)


class SubscriptionCheckoutRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    plan_id: str = Field(min_length=1, max_length=64)
    billing_period: str = Field(default="monthly", max_length=16)


class SubscriptionPaymentCallbackRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    object: dict


def _serialize_employee(cur, user_id: int):
    employee = cur.execute(
        """
        SELECT
            e.id,
            e.position_id,
            e.store_id,
            e.salary,
            e.is_active,
            p.title AS position_title
        FROM employees e
        JOIN positions p ON p.id = e.position_id
        WHERE e.user_id = ?
        LIMIT 1
        """,
        (user_id,),
    ).fetchone()

    if not employee:
        return None

    return {
        "id": employee["id"],
        "position_id": employee["position_id"],
        "store_id": employee["store_id"],
        "salary": float(employee["salary"] or 0),
        "is_active": bool(employee["is_active"]),
        "position": {
            "id": employee["position_id"],
            "title": employee["position_title"],
        },
    }


def _normalize_phone(phone: str) -> str:
    digits = "".join(PHONE_DIGITS_PATTERN.findall(phone))
    if len(digits) < 10:
        raise HTTPException(status_code=400, detail="Некорректный номер телефона")
    return "+7" + digits[-10:]


def _available_user_avatars() -> list[str]:
    if not USER_AVATAR_DIR.exists():
        return []

    avatars: list[str] = []
    for path in USER_AVATAR_DIR.iterdir():
        if not path.is_file():
            continue
        if path.name.lower() == "blocked.png":
            continue
        if path.suffix.lower() not in ALLOWED_AVATAR_EXTS:
            continue
        avatars.append(f"img/users/{path.name}")
    return avatars


def _avatar_exists(rel_path: Optional[str]) -> bool:
    if not rel_path:
        return False
    return (BASE_DIR / rel_path.lstrip("/")).exists()


def _ensure_user_avatar(cur, user_id: int, avatar_url: Optional[str]) -> Optional[str]:
    current = (avatar_url or "").strip().lstrip("/")

    if current:
        if current == BLOCKED_AVATAR_DB_PATH:
            current = ""
        elif _avatar_exists(current):
            return current
        else:
            current = ""

    pool = _available_user_avatars()
    if not pool:
        return avatar_url

    chosen = random.choice(pool)
    cur.execute(
        """
        UPDATE users
        SET avatar_url = ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
        """,
        (chosen, user_id),
    )
    return chosen


def _avatar_for_response(status: Optional[str], avatar_url: Optional[str]) -> Optional[str]:
    status_text = (status or "").lower()
    if status_text in {"blocked", "deleted"}:
        return BLOCKED_IMAGE_PATH
    return avatar_url


def _extract_session_token(
    authorization: Optional[str],
) -> str:
    token = normalize_token(authorization)
    if not token:
        raise HTTPException(status_code=401, detail="Недействительная сессия")
    return token


def _yookassa_enabled(settings) -> bool:
    return bool(settings.YOOKASSA_SHOP_ID and settings.YOOKASSA_API_KEY)


def _yookassa_request(settings, method: str, path: str, payload: Optional[dict] = None) -> dict:
    credentials = f"{settings.YOOKASSA_SHOP_ID}:{settings.YOOKASSA_API_KEY}"
    headers = {
        "Authorization": f"Basic {base64.b64encode(credentials.encode('utf-8')).decode('utf-8')}",
        "Content-Type": "application/json",
    }
    if method.upper() == "POST":
        headers["Idempotence-Key"] = str(uuid.uuid4())

    request_obj = urllib_request.Request(
        url=f"https://api.yookassa.ru/v3/{path.lstrip('/')}",
        data=json.dumps(payload).encode("utf-8") if payload is not None else None,
        headers=headers,
        method=method.upper(),
    )

    try:
        with urllib_request.urlopen(request_obj, timeout=20) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib_error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="ignore")
        raise HTTPException(
            status_code=502,
            detail=f"YooKassa error: {body or exc.reason}",
        )
    except urllib_error.URLError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"YooKassa unavailable: {exc.reason}",
        )


def _create_yookassa_subscription_payment(
    settings,
    *,
    amount: float,
    description: str,
    return_url: str,
    metadata: dict[str, str],
) -> dict:
    payload = {
        "amount": {
            "value": f"{amount:.2f}",
            "currency": "RUB",
        },
        "capture": True,
        "save_payment_method": True,
        "confirmation": {
            "type": "redirect",
            "return_url": return_url,
        },
        "description": description,
        "metadata": metadata,
    }
    return _yookassa_request(settings, "POST", "/payments", payload)


def _fetch_yookassa_payment(settings, external_payment_id: str) -> dict:
    return _yookassa_request(settings, "GET", f"/payments/{external_payment_id}")


def _apply_subscription_payment_paid(cur, link_row) -> int:
    link_id = int(link_row["id"])
    if (link_row["status"] or "").lower() == "paid" and link_row["subscription_id"] is not None:
        return int(link_row["subscription_id"])

    plan_id = int(link_row["plan_id"])
    user_id = int(link_row["user_id"])
    billing_period = (link_row["billing_period"] or "monthly").lower()
    auto_renew = int(link_row["auto_renew_enabled"] or 1)

    now = datetime.utcnow()
    starts_at = now.strftime("%Y-%m-%d %H:%M:%S")
    days = 365 if billing_period == "yearly" else 30
    expires_at = (now + timedelta(days=days)).strftime("%Y-%m-%d %H:%M:%S")

    existing = cur.execute(
        """
        SELECT id
        FROM subscriptions
        WHERE user_id = ?
        ORDER BY id DESC
        LIMIT 1
        """,
        (user_id,),
    ).fetchone()

    if existing:
        subscription_id = int(existing["id"])
        cur.execute(
            """
            UPDATE subscriptions
            SET plan_id = ?,
                billing_period = ?,
                status = 'active',
                auto_renew = ?,
                starts_at = ?,
                expires_at = ?,
                blocked_at = NULL,
                delete_after_at = NULL,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """,
            (plan_id, billing_period, auto_renew, starts_at, expires_at, subscription_id),
        )
    else:
        cur.execute(
            """
            INSERT INTO subscriptions (
                plan_id, user_id, company_id, billing_period, status, auto_renew,
                starts_at, expires_at, blocked_at, delete_after_at
            )
            VALUES (?, ?, NULL, ?, 'active', ?, ?, ?, NULL, NULL)
            """,
            (plan_id, user_id, billing_period, auto_renew, starts_at, expires_at),
        )
        subscription_id = int(cur.lastrowid)

    cur.execute(
        """
        UPDATE subscription_payment_links
        SET status = 'paid',
            subscription_id = ?,
            paid_at = COALESCE(paid_at, CURRENT_TIMESTAMP)
        WHERE id = ?
        """,
        (subscription_id, link_id),
    )
    return subscription_id


def _get_active_user_subscription(cur, user_id: int):
    return cur.execute(
        """
        SELECT *
        FROM subscriptions
        WHERE user_id = ?
          AND status = 'active'
          AND datetime(expires_at) > datetime('now')
        ORDER BY id DESC
        LIMIT 1
        """,
        (user_id,),
    ).fetchone()


@router.post("/validate_token", summary="Validate Session Token")
def validate_token(payload: ValidateTokenRequest):
    """Проверяет, активен ли переданный session token."""
    is_valid = is_valid_session_token(payload.token)
    return {"success": True, "is_valid": is_valid}


def _get_user_with_session(token: str):
    conn = get_db_connection()
    try:
        row = conn.execute(
            """
            SELECT
                u.id,
                u.telegram_id,
                u.full_name,
                u.phone,
                u.avatar_url,
                u.status,
                us.session_token,
                us.device_id,
                us.expires_at
            FROM user_sessions us
            JOIN users u ON u.id = us.user_id
            WHERE us.session_token = ?
              AND us.is_active = 1
              AND datetime(us.expires_at) > datetime('now')
            LIMIT 1
            """,
            (token,),
        ).fetchone()
    finally:
        conn.close()

    return row


@router.post("/verify", summary="Verify Auth Code")
def verify_code(payload: VerifyCodeRequest):
    """Подтверждает код авторизации и создает пользовательскую сессию."""
    code = clean_text(payload.code, max_len=8)
    if not CODE_PATTERN.fullmatch(code):
        raise HTTPException(status_code=400, detail="Что-то пошло не так")

    device_id = normalize_device_id(payload.device_id)

    conn = get_db_connection()
    try:
        cur = conn.cursor()

        sql = """
            SELECT
                ac.id,
                ac.user_id,
                ac.code,
                ac.device_id,
                ac.expires_at,
                u.telegram_id,
                u.full_name,
                u.phone,
                u.avatar_url,
                u.status
            FROM auth_codes ac
            JOIN users u ON u.id = ac.user_id
            WHERE ac.code = ?
              AND ac.used_at IS NULL
              AND datetime(ac.expires_at) > datetime('now')
        """
        params: list[object] = [code]

        if device_id:
            sql += " AND ac.device_id = ?"
            params.append(device_id)

        sql += " ORDER BY ac.id DESC LIMIT 1"

        auth_code = cur.execute(sql, tuple(params)).fetchone()
        if not auth_code:
            raise HTTPException(status_code=404, detail="Что-то пошло не так")

        account_status = (auth_code["status"] or "").lower()
        if account_status in {"blocked", "deleted"}:
            raise HTTPException(
                status_code=403,
                detail={
                    "message": "Account is blocked or deleted",
                    "status": account_status,
                    "image": BLOCKED_IMAGE_PATH,
                },
            )

        ensured_avatar = _ensure_user_avatar(
            cur,
            int(auth_code["user_id"]),
            auth_code["avatar_url"],
        )

        session_token = secrets.token_urlsafe(48)
        expires_at = (datetime.utcnow() + timedelta(days=30)).strftime("%Y-%m-%d %H:%M:%S")

        cur.execute(
            "UPDATE auth_codes SET used_at = CURRENT_TIMESTAMP WHERE id = ?",
            (auth_code["id"],),
        )

        cur.execute(
            """
            INSERT INTO user_sessions (
                user_id, device_id, session_token, refresh_token,
                device_name, platform, ip_address, user_agent,
                is_active, expires_at, last_seen_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, CURRENT_TIMESTAMP)
            """,
            (
                auth_code["user_id"],
                device_id,
                session_token,
                secrets.token_urlsafe(32),
                None,
                None,
                None,
                None,
                expires_at,
            ),
        )

        employee = _serialize_employee(cur, int(auth_code["user_id"]))

        conn.commit()
    finally:
        conn.close()

    response = {
        "success": True,
        "user": {
            "id": auth_code["user_id"],
            "telegram_id": auth_code["telegram_id"],
            "name": auth_code["full_name"],
            "phone": auth_code["phone"],
            "session_token": session_token,
            "avatar_url": _avatar_for_response(auth_code["status"], ensured_avatar),
        },
        "message": "Authentication successful",
        "is_employee": bool(employee),
    }

    if employee:
        response["employee"] = employee

    return response


@router.get("/check_status/{code}", summary="Check Auth Code Status")
def check_code_status(code: str):
    """Возвращает статус кода входа: использован/истек/валиден."""
    clean_code = clean_text(code, max_len=8)
    if not CODE_PATTERN.fullmatch(clean_code):
        raise HTTPException(status_code=400, detail="Что-то пошло не так")

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        auth_code = cur.execute(
            """
            SELECT ac.*, u.telegram_id, u.full_name
            FROM auth_codes ac
            JOIN users u ON u.id = ac.user_id
            WHERE ac.code = ?
            ORDER BY ac.id DESC
            LIMIT 1
            """,
            (clean_code,),
        ).fetchone()

        if not auth_code:
            raise HTTPException(status_code=404, detail="Что-то пошло не так")

        employee = _serialize_employee(cur, int(auth_code["user_id"]))
    finally:
        conn.close()

    is_valid = auth_code["used_at"] is None and auth_code["expires_at"] > datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
    status_payload = {
        "code": auth_code["code"],
        "expires_at": auth_code["expires_at"],
        "used": auth_code["used_at"] is not None,
        "user_linked": auth_code["user_id"] is not None,
        "is_valid": bool(is_valid),
        "user": {
            "id": auth_code["user_id"],
            "telegram_id": auth_code["telegram_id"],
            "name": auth_code["full_name"],
        },
        "is_employee": bool(employee),
    }

    if employee:
        status_payload["employee"] = employee

    return {"success": True, "status": status_payload}


@router.api_route("/me", methods=["GET", "POST"], summary="Get Current User")
def me(
    authorization: Optional[str] = Header(default=None, alias="Authorization"),
):
    """Возвращает профиль текущего пользователя по токену в Authorization."""
    token = _extract_session_token(authorization)
    user = _get_user_with_session(token)

    if not user:
        raise HTTPException(status_code=401, detail="Недействительная сессия")
    account_status = (user["status"] or "").lower()
    if account_status in {"blocked", "deleted"}:
        raise HTTPException(
            status_code=403,
            detail={
                "message": "Account is blocked or deleted",
                "status": account_status,
                "image": BLOCKED_IMAGE_PATH,
            },
        )

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        ensured_avatar = _ensure_user_avatar(cur, int(user["id"]), user["avatar_url"])
        employee = _serialize_employee(cur, int(user["id"]))
        conn.commit()
    finally:
        conn.close()

    response = {
        "success": True,
        "message": "OK",
        "user": {
            "id": user["id"],
            "telegram_id": user["telegram_id"],
            "name": user["full_name"],
            "phone": user["phone"],
            "session_token": user["session_token"],
            "avatar_url": _avatar_for_response(user["status"], ensured_avatar),
        },
        "is_employee": bool(employee),
    }
    if employee:
        response["employee"] = employee
    return response


@router.post("/update_profile", summary="Update User Profile")
def update_profile(
    payload: UpdateProfileRequest,
    authorization: Optional[str] = Header(default=None, alias="Authorization"),
):
    """Обновляет имя и телефон текущего пользователя."""
    token = _extract_session_token(authorization)
    user = _get_user_with_session(token)
    if not user:
        raise HTTPException(status_code=401, detail="Пользователь не найден")

    clean_name = clean_text(payload.name, max_len=100)
    if len(clean_name) < 2:
        raise HTTPException(status_code=400, detail="Имя должно содержать минимум 2 символа")

    formatted_phone = _normalize_phone(payload.phone)

    conn = get_db_connection()
    try:
        conn.execute(
            """
            UPDATE users
            SET full_name = ?,
                phone = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """,
            (clean_name, formatted_phone, user["id"]),
        )
        conn.commit()

        updated = conn.execute(
            "SELECT id, telegram_id, full_name, phone, avatar_url FROM users WHERE id = ?",
            (user["id"],),
        ).fetchone()
    finally:
        conn.close()

    return {
        "success": True,
        "message": "Профиль успешно обновлен",
        "user": {
            "id": updated["id"],
            "telegram_id": updated["telegram_id"],
            "name": updated["full_name"],
            "phone": updated["phone"],
            "avatar_url": updated["avatar_url"],
        },
    }


@router.post("/avatar", summary="Upload User Avatar")
async def upload_avatar(
    avatar: UploadFile = File(...),
    authorization: Optional[str] = Header(default=None, alias="Authorization"),
):
    """Загружает/обновляет аватар пользователя."""
    token = _extract_session_token(authorization)
    user = _get_user_with_session(token)
    if not user:
        raise HTTPException(status_code=401, detail="Недействительная сессия")

    suffix = Path(avatar.filename or "").suffix.lower()
    if suffix not in ALLOWED_AVATAR_EXTS:
        raise HTTPException(status_code=400, detail="Неподдерживаемый формат изображения")

    content = await avatar.read()
    if not content:
        raise HTTPException(status_code=400, detail="Файл аватарки не предоставлен")
    if len(content) > MAX_AVATAR_SIZE_BYTES:
        raise HTTPException(status_code=400, detail="Размер файла превышает 10MB")

    avatar_dir = BASE_DIR / "img" / "avatars"
    avatar_dir.mkdir(parents=True, exist_ok=True)

    filename = f"{uuid.uuid4().hex}{suffix}"
    file_path = avatar_dir / filename
    file_path.write_bytes(content)

    rel_avatar_url = f"img/avatars/{filename}"

    conn = get_db_connection()
    try:
        conn.execute(
            """
            UPDATE users
            SET avatar_url = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """,
            (rel_avatar_url, user["id"]),
        )
        conn.commit()
    finally:
        conn.close()

    return {
        "success": True,
        "message": "Аватарка успешно загружена",
        "avatar_url": rel_avatar_url,
    }


@router.get("/avatar", summary="Get User Avatar")
def get_avatar(user=Depends(get_current_user)):
    """Возвращает ссылку на аватар и, при возможности, base64-представление."""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        avatar_url = _ensure_user_avatar(cur, int(user["id"]), user["avatar_url"])
        conn.commit()
    finally:
        conn.close()

    if not avatar_url:
        raise HTTPException(status_code=404, detail="Аватарка не найдена")

    avatar_url = _avatar_for_response(user["status"], avatar_url)

    payload = {"success": True, "avatar_url": avatar_url}

    file_path = BASE_DIR / avatar_url.lstrip("/")
    if file_path.exists() and file_path.is_file() and file_path.stat().st_size <= MAX_AVATAR_SIZE_BYTES:
        payload["avatar"] = base64.b64encode(file_path.read_bytes()).decode("utf-8")

    return payload


@router.get("/subscription-plans", summary="Get Subscription Plans")
def get_subscription_plans(user=Depends(get_current_user)):
    """Возвращает активные тарифы подписки для мобильного приложения."""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        active_subscription = _get_active_user_subscription(cur, int(user["id"]))
        active_plan_id = int(active_subscription["plan_id"]) if active_subscription else None

        if active_plan_id is None:
            free_row = cur.execute(
                """
                SELECT id, code
                FROM subscription_plans
                WHERE LOWER(code) = 'free' AND is_active = 1
                LIMIT 1
                """
            ).fetchone()
            if free_row:
                active_plan_id = int(free_row["id"])

        rows = conn.execute(
            """
            SELECT
                id,
                code,
                name,
                monthly_price,
                description,
                features_json,
                max_plants,
                max_members,
                notifications,
                has_corporate,
                can_create_company,
                has_analytics,
                is_active
            FROM subscription_plans
            WHERE is_active = 1
            ORDER BY monthly_price ASC, id ASC
            """
        ).fetchall()
    finally:
        conn.close()

    items = []
    active_plan_code = None
    for row in rows:
        raw_features = row["features_json"] or "[]"
        try:
            features = json.loads(raw_features)
            if not isinstance(features, list):
                features = []
        except Exception:
            features = []

        is_current = active_plan_id is not None and int(row["id"]) == int(active_plan_id)
        if is_current:
            active_plan_code = row["code"]
        items.append(
            {
                "id": str(row["code"] or row["id"]),
                "name": row["name"],
                "price": float(row["monthly_price"] or 0),
                "description": row["description"] or "",
                "features": [str(f) for f in features],
                "max_plants": int(row["max_plants"] or 1),
                "max_members": int(row["max_members"] or 1),
                "notifications": row["notifications"] or "basic",
                "has_corporate": bool(row["has_corporate"]),
                "can_create_company": bool(row["can_create_company"]),
                "has_analytics": bool(row["has_analytics"]),
                "is_current": is_current,
            }
        )

    return {
        "success": True,
        "data": {
            "items": items,
            "count": len(items),
            "current_plan_id": str(active_plan_code or "free"),
        },
    }


@router.post("/subscription-plans/checkout", summary="Create Subscription Checkout Link")
def create_subscription_checkout_link(
    payload: SubscriptionCheckoutRequest,
    user=Depends(get_current_user),
):
    settings = get_settings()
    if not _yookassa_enabled(settings):
        raise HTTPException(status_code=500, detail="YooKassa is not configured")

    plan_code = clean_text(payload.plan_id, max_len=64).lower()
    billing_period = clean_text(payload.billing_period, max_len=16).lower()
    if billing_period not in {"monthly", "yearly"}:
        raise HTTPException(status_code=400, detail="billing_period must be monthly or yearly")

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        plan = cur.execute(
            """
            SELECT id, code, name, monthly_price, yearly_price, is_active
            FROM subscription_plans
            WHERE (LOWER(code) = LOWER(?) OR CAST(id AS TEXT) = ?)
            LIMIT 1
            """,
            (plan_code, plan_code),
        ).fetchone()
        if not plan or not bool(plan["is_active"]):
            raise HTTPException(status_code=404, detail="Subscription plan not found")
        if clean_text(plan["code"], max_len=64).lower() == "free":
            raise HTTPException(status_code=400, detail="Free plan does not require payment")

        amount = float(plan["yearly_price"] if billing_period == "yearly" else plan["monthly_price"])
        if amount < 0:
            raise HTTPException(status_code=400, detail="Invalid plan price")

        return_url = f"{settings.API_BASE_URL}/auth/subscription-payment-return"
        payment = _create_yookassa_subscription_payment(
            settings,
            amount=amount,
            description=f"Подписка {plan['name']} ({billing_period})",
            return_url=return_url,
            metadata={
                "scope": "subscription",
                "user_id": str(user["id"]),
                "plan_id": str(plan["id"]),
                "billing_period": billing_period,
            },
        )

        external_payment_id = payment.get("id")
        payment_url = payment.get("confirmation", {}).get("confirmation_url") or ""
        if not payment_url:
            raise HTTPException(status_code=502, detail="YooKassa confirmation_url is missing")

        cur.execute(
            """
            INSERT INTO subscription_payment_links (
                user_id, plan_id, billing_period, amount, status, payment_url,
                external_payment_id, auto_renew_enabled
            )
            VALUES (?, ?, ?, ?, 'pending', ?, ?, 1)
            """,
            (
                int(user["id"]),
                int(plan["id"]),
                billing_period,
                amount,
                payment_url,
                clean_text(str(external_payment_id), max_len=255),
            ),
        )
        link_id = int(cur.lastrowid)
        conn.commit()
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "checkout_id": link_id,
            "payment_url": payment_url,
            "status": "pending",
            "auto_renew": True,
        },
    }


@router.get("/subscription-plans/checkout/{checkout_id}/status", summary="Get Subscription Checkout Status")
def get_subscription_checkout_status(checkout_id: int, user=Depends(get_current_user)):
    settings = get_settings()
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        link = cur.execute(
            """
            SELECT *
            FROM subscription_payment_links
            WHERE id = ? AND user_id = ?
            LIMIT 1
            """,
            (checkout_id, int(user["id"])),
        ).fetchone()
        if not link:
            raise HTTPException(status_code=404, detail="Checkout not found")

        status_code = clean_text(link["status"], max_len=32).lower()
        if status_code not in {"paid", "failed", "cancelled"} and _yookassa_enabled(settings) and link["external_payment_id"]:
            try:
                remote = _fetch_yookassa_payment(settings, str(link["external_payment_id"]))
                remote_status = clean_text(remote.get("status"), max_len=32).lower()
                remote_paid = bool(remote.get("paid"))
                if remote_paid or remote_status in {"succeeded", "paid"}:
                    _apply_subscription_payment_paid(cur, link)
                    status_code = "paid"
                elif remote_status in {"canceled", "cancelled"}:
                    cur.execute(
                        """
                        UPDATE subscription_payment_links
                        SET status = 'cancelled',
                            failed_at = COALESCE(failed_at, CURRENT_TIMESTAMP)
                        WHERE id = ?
                        """,
                        (checkout_id,),
                    )
                    status_code = "cancelled"
                conn.commit()
                link = cur.execute(
                    "SELECT * FROM subscription_payment_links WHERE id = ?",
                    (checkout_id,),
                ).fetchone()
            except HTTPException:
                pass

        status_labels = {
            "pending": "Ожидает оплату",
            "paid": "Оплачен",
            "failed": "Ошибка оплаты",
            "cancelled": "Отменен",
        }
        return {
            "success": True,
            "data": {
                "checkout_id": int(link["id"]),
                "status_code": status_code,
                "status": status_labels.get(status_code, status_code),
                "auto_renew": bool(link["auto_renew_enabled"]),
                "subscription_id": int(link["subscription_id"]) if link["subscription_id"] is not None else None,
            },
        }
    finally:
        conn.close()


@router.get("/subscription-payment-return", summary="Subscription Payment Return")
def subscription_payment_return():
    return {
        "success": True,
        "message": "Оплата обработана. Можно вернуться в приложение.",
    }


@router.post("/subscription-plans/callback", summary="Subscription Payment Callback")
def subscription_payment_callback(payload: SubscriptionPaymentCallbackRequest):
    payment_data = payload.object or {}
    external_payment_id = clean_text(payment_data.get("id"), max_len=255)
    if not external_payment_id:
        raise HTTPException(status_code=400, detail="Invalid callback payload")

    incoming_status = clean_text(payment_data.get("status"), max_len=32).lower()
    incoming_paid = bool(payment_data.get("paid"))

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        link = cur.execute(
            """
            SELECT *
            FROM subscription_payment_links
            WHERE external_payment_id = ?
            ORDER BY id DESC
            LIMIT 1
            """,
            (external_payment_id,),
        ).fetchone()
        if not link:
            return {"success": True, "message": "Payment not related to subscriptions"}

        if incoming_paid or incoming_status in {"succeeded", "paid"}:
            subscription_id = _apply_subscription_payment_paid(cur, link)
            conn.commit()
            return {
                "success": True,
                "message": "Subscription paid",
                "subscription_id": subscription_id,
            }

        if incoming_status in {"canceled", "cancelled"}:
            cur.execute(
                """
                UPDATE subscription_payment_links
                SET status = 'cancelled',
                    failed_at = COALESCE(failed_at, CURRENT_TIMESTAMP)
                WHERE id = ?
                """,
                (int(link["id"]),),
            )
            conn.commit()
            return {"success": True, "message": "Subscription payment cancelled"}

        if incoming_status in {"failed"}:
            cur.execute(
                """
                UPDATE subscription_payment_links
                SET status = 'failed',
                    failed_at = COALESCE(failed_at, CURRENT_TIMESTAMP)
                WHERE id = ?
                """,
                (int(link["id"]),),
            )
            conn.commit()
            return {"success": True, "message": "Subscription payment failed"}
    finally:
        conn.close()

    return {"success": True, "message": "Callback accepted"}


@router.post("/subscription-plans/{plan_id}/cancel", summary="Cancel Active Subscription Plan")
def cancel_subscription_plan(plan_id: str, user=Depends(get_current_user)):
    requested_plan = clean_text(plan_id, max_len=64).lower()
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        active_subscription = _get_active_user_subscription(cur, int(user["id"]))
        if not active_subscription:
            return {"success": True, "message": "No active paid subscription", "data": {"current_plan_id": "free"}}

        plan = cur.execute(
            "SELECT id, code FROM subscription_plans WHERE id = ? LIMIT 1",
            (int(active_subscription["plan_id"]),),
        ).fetchone()
        if not plan:
            raise HTTPException(status_code=404, detail="Active plan not found")

        active_plan_code = clean_text(plan["code"], max_len=64).lower()
        if active_plan_code == "free":
            return {"success": True, "message": "Free plan is always active", "data": {"current_plan_id": "free"}}

        if requested_plan and requested_plan not in {active_plan_code, str(plan["id"])}:
            raise HTTPException(status_code=400, detail="Requested plan is not active")

        cur.execute(
            """
            UPDATE subscriptions
            SET status = 'cancelled',
                auto_renew = 0,
                delete_after_at = CURRENT_TIMESTAMP,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """,
            (int(active_subscription["id"]),),
        )
        conn.commit()
    finally:
        conn.close()

    return {
        "success": True,
        "message": "Subscription cancelled. Free plan is active now.",
        "data": {"current_plan_id": "free"},
    }
