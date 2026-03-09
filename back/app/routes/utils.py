from __future__ import annotations

import os
import re
from datetime import datetime
from typing import Optional

from fastapi import Header, HTTPException, Request, status

from app.db import get_db_connection

TOKEN_PATTERN = re.compile(r"^[A-Za-z0-9_\-]{8,256}$")
DEVICE_ID_PATTERN = re.compile(r"^[A-Za-z0-9_.:-]{1,255}$")
SAFE_TEXT_PATTERN = re.compile(r"[\x00-\x1F\x7F]")


def utc_now_str() -> str:
    return datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")


def clean_text(value: Optional[str], max_len: int = 255) -> str:
    if value is None:
        return ""
    text = SAFE_TEXT_PATTERN.sub("", str(value)).strip()
    return text[:max_len]


def clean_optional_text(value: Optional[str], max_len: int = 255) -> Optional[str]:
    text = clean_text(value, max_len=max_len)
    return text if text else None


def normalize_token(raw_token: Optional[str]) -> Optional[str]:
    if not raw_token or not isinstance(raw_token, str):
        return None
    token = raw_token.strip().strip('"\'')
    if token.lower().startswith("bearer "):
        return None
    if not TOKEN_PATTERN.fullmatch(token):
        return None
    return token


def normalize_device_id(raw_device_id: Optional[str]) -> Optional[str]:
    if raw_device_id is None:
        return None
    device_id = clean_text(raw_device_id, max_len=255)
    if not device_id:
        return None
    if not DEVICE_ID_PATTERN.fullmatch(device_id):
        return None
    return device_id


def get_auth_token_from_headers(
    authorization: Optional[str] = Header(default=None, alias="Authorization"),
) -> str:
    token = normalize_token(authorization)
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session token required",
        )
    return token


def get_current_user(
    token: Optional[str] = Header(default=None, alias="Authorization"),
):
    resolved = normalize_token(token)
    if not resolved:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid session token",
        )

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
                us.expires_at,
                us.is_active
            FROM user_sessions us
            JOIN users u ON u.id = us.user_id
            WHERE us.session_token = ?
              AND us.is_active = 1
              AND datetime(us.expires_at) > datetime('now')
              AND u.status = 'active'
            LIMIT 1
            """,
            (resolved,),
        ).fetchone()
    finally:
        conn.close()

    if not row:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired session token",
        )

    return row


def is_valid_session_token(token: str) -> bool:
    normalized = normalize_token(token)
    if not normalized:
        return False

    conn = get_db_connection()
    try:
        row = conn.execute(
            """
            SELECT 1
            FROM user_sessions us
            JOIN users u ON u.id = us.user_id
            WHERE us.session_token = ?
              AND us.is_active = 1
              AND datetime(us.expires_at) > datetime('now')
              AND u.status = 'active'
            LIMIT 1
            """,
            (normalized,),
        ).fetchone()
    finally:
        conn.close()

    return row is not None


def is_admin_user(user_row) -> bool:
    if user_row is None:
        return False

    admin_ids_raw = os.getenv("ADMIN_IDS", "")
    allowed_ids: set[int] = set()
    if admin_ids_raw:
        for chunk in re.split(r"[,;\s]+", admin_ids_raw):
            if chunk:
                try:
                    allowed_ids.add(int(chunk))
                except ValueError:
                    pass

    user_id = int(user_row["id"])
    telegram_id = int(user_row["telegram_id"])

    if user_id in allowed_ids or telegram_id in allowed_ids:
        return True

    conn = get_db_connection()
    try:
        emp = conn.execute(
            """
            SELECT e.id, e.position_id, p.title
            FROM employees e
            JOIN positions p ON p.id = e.position_id
            WHERE e.user_id = ?
              AND e.is_active = 1
            LIMIT 1
            """,
            (user_id,),
        ).fetchone()
    finally:
        conn.close()

    if not emp:
        return False

    title = (emp["title"] or "").lower()
    return emp["position_id"] == 4 or "админ" in title or "admin" in title


def require_admin(user_row) -> None:
    if not is_admin_user(user_row):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin privileges required",
        )


def request_ip(request: Request) -> Optional[str]:
    if request.client and request.client.host:
        return clean_text(request.client.host, max_len=64)
    return None
