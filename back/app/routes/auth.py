from __future__ import annotations

import base64
import re
import secrets
import uuid
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, Depends, File, HTTPException, Header, UploadFile
from pydantic import BaseModel, ConfigDict, Field

from app.config import BASE_DIR
from app.db import get_db_connection
from app.routes.utils import (
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


def _extract_session_token(
    authorization: Optional[str],
) -> str:
    token = normalize_token(authorization)
    if not token:
        raise HTTPException(status_code=401, detail="Недействительная сессия")
    return token


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
              AND u.status = 'active'
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
                u.avatar_url
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
            "avatar_url": auth_code["avatar_url"],
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

    conn = get_db_connection()
    try:
        employee = _serialize_employee(conn.cursor(), int(user["id"]))
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
            "avatar_url": user["avatar_url"],
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
    avatar_url = user["avatar_url"]
    if not avatar_url:
        raise HTTPException(status_code=404, detail="Аватарка не найдена")

    payload = {"success": True, "avatar_url": avatar_url}

    file_path = BASE_DIR / avatar_url
    if file_path.exists() and file_path.is_file() and file_path.stat().st_size <= MAX_AVATAR_SIZE_BYTES:
        payload["avatar"] = base64.b64encode(file_path.read_bytes()).decode("utf-8")

    return payload
