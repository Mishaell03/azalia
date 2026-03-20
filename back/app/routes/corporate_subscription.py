from __future__ import annotations

import re
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, ConfigDict, Field

from app.db import get_db_connection
from app.routes.utils import clean_optional_text, clean_text, get_current_user

router = APIRouter(prefix="/api/corporate-subscription", tags=["corporate-subscription"])

PHONE_DIGITS_PATTERN = re.compile(r"\d")


class CompanyCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=2, max_length=150)
    description: Optional[str] = Field(default=None, max_length=1000)
    contact_phone: Optional[str] = Field(default=None, max_length=25)
    contact_email: Optional[str] = Field(default=None, max_length=120)
    address: Optional[str] = Field(default=None, max_length=255)


class CompanyAddMemberRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    company_id: Optional[int] = Field(default=None, ge=1)
    telegram_id: Optional[int] = Field(default=None, ge=1)
    user_phone: Optional[str] = Field(default=None, max_length=25)
    role: str = Field(default="member", max_length=16)


def _normalize_phone(phone: Optional[str]) -> Optional[str]:
    if phone is None:
        return None
    digits = "".join(PHONE_DIGITS_PATTERN.findall(phone))
    if len(digits) < 10:
        raise HTTPException(status_code=422, detail="Некорректный номер телефона")
    return "+7" + digits[-10:]


def _active_plan(cur, user_id: int) -> dict:
    row = cur.execute(
        """
        SELECT
            sp.id,
            sp.code,
            sp.name,
            sp.has_corporate,
            sp.can_create_company,
            sp.max_members
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

    if row:
        return {
            "id": int(row["id"]),
            "code": row["code"],
            "name": row["name"],
            "has_corporate": bool(row["has_corporate"]),
            "can_create_company": bool(row["can_create_company"]),
            "max_members": max(1, int(row["max_members"] or 1)),
        }

    free_row = cur.execute(
        """
        SELECT id, code, name, has_corporate, can_create_company, max_members
        FROM subscription_plans
        WHERE LOWER(code) = 'free'
        LIMIT 1
        """
    ).fetchone()
    if free_row:
        return {
            "id": int(free_row["id"]),
            "code": free_row["code"],
            "name": free_row["name"],
            "has_corporate": bool(free_row["has_corporate"]),
            "can_create_company": bool(free_row["can_create_company"]),
            "max_members": max(1, int(free_row["max_members"] or 1)),
        }

    return {
        "id": 0,
        "code": "free",
        "name": "Free",
        "has_corporate": False,
        "can_create_company": False,
        "max_members": 1,
    }


def _require_corporate_access(plan: dict) -> None:
    if plan["has_corporate"] or plan["can_create_company"]:
        return
    raise HTTPException(
        status_code=403,
        detail="Корпоративные возможности доступны только в расширенной подписке",
    )


def _serialize_company(row, *, my_role: Optional[str], is_organizer: bool) -> dict:
    return {
        "id": int(row["id"]),
        "name": row["name"],
        "description": row["description"],
        "contact_phone": row["contact_phone"],
        "contact_email": row["contact_email"],
        "address": row["address"],
        "status": row["status"],
        "owner_user_id": int(row["owner_user_id"]),
        "my_role": my_role,
        "is_organizer": is_organizer,
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


def _company_for_user(cur, user_id: int):
    return cur.execute(
        """
        SELECT
            c.id,
            c.name,
            c.description,
            c.contact_phone,
            c.contact_email,
            c.address,
            c.status,
            c.owner_user_id,
            c.created_at,
            c.updated_at,
            cm.role AS my_role,
            cm.is_active AS my_membership_active
        FROM company_members cm
        JOIN companies c ON c.id = cm.company_id
        WHERE cm.user_id = ?
          AND cm.is_active = 1
          AND c.status = 'active'
        ORDER BY CASE cm.role WHEN 'owner' THEN 0 WHEN 'admin' THEN 1 ELSE 2 END, cm.id ASC
        LIMIT 1
        """,
        (user_id,),
    ).fetchone()


def _members_for_company(cur, company_id: int) -> list[dict]:
    rows = cur.execute(
        """
        SELECT
            cm.user_id,
            cm.role,
            cm.is_active,
            cm.created_at,
            u.full_name,
            u.phone,
            u.avatar_url,
            u.status
        FROM company_members cm
        JOIN users u ON u.id = cm.user_id
        WHERE cm.company_id = ?
          AND cm.is_active = 1
        ORDER BY CASE cm.role WHEN 'owner' THEN 0 WHEN 'admin' THEN 1 ELSE 2 END, u.full_name ASC
        """,
        (company_id,),
    ).fetchall()

    return [
        {
            "user_id": int(row["user_id"]),
            "full_name": row["full_name"],
            "phone": row["phone"],
            "avatar_url": row["avatar_url"],
            "user_status": row["status"],
            "role": row["role"],
            "is_active": bool(row["is_active"]),
            "created_at": row["created_at"],
        }
        for row in rows
    ]


def _assert_organizer(cur, company_id: int, user_id: int) -> str:
    row = cur.execute(
        """
        SELECT role
        FROM company_members
        WHERE company_id = ?
          AND user_id = ?
          AND is_active = 1
        LIMIT 1
        """,
        (company_id, user_id),
    ).fetchone()
    if not row:
        raise HTTPException(status_code=403, detail="Вы не состоите в этой компании")
    role = (row["role"] or "member").lower()
    if role not in {"owner", "admin"}:
        raise HTTPException(status_code=403, detail="Только организатор может управлять участниками")
    return role


@router.get("/company", summary="Corporate: my company")
def get_my_company(user=Depends(get_current_user)):
    user_id = int(user["id"])
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        plan = _active_plan(cur, user_id)
        company_row = _company_for_user(cur, user_id)

        company = None
        members: list[dict] = []
        if company_row:
            my_role = (company_row["my_role"] or "member").lower()
            company = _serialize_company(
                company_row,
                my_role=my_role,
                is_organizer=my_role in {"owner", "admin"},
            )
            members = _members_for_company(cur, int(company_row["id"]))

        can_use_corporate = bool(plan["has_corporate"] or plan["can_create_company"])
        current_members = len(members)
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "plan": plan,
            "can_use_corporate": can_use_corporate,
            "company": company,
            "members": members,
            "limits": {
                "max_members": int(plan["max_members"]),
                "current_members": current_members,
                "can_add_more": current_members < int(plan["max_members"]),
            },
        },
    }


@router.post("/company", summary="Corporate: create company")
def create_company(payload: CompanyCreateRequest, user=Depends(get_current_user)):
    user_id = int(user["id"])

    name = clean_text(payload.name, max_len=150)
    if not name:
        raise HTTPException(status_code=422, detail="Название компании обязательно")

    description = clean_optional_text(payload.description, max_len=1000)
    contact_phone = _normalize_phone(payload.contact_phone)
    contact_email = clean_optional_text(payload.contact_email, max_len=120)
    address = clean_optional_text(payload.address, max_len=255)

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        plan = _active_plan(cur, user_id)
        _require_corporate_access(plan)

        existing_owned = cur.execute(
            """
            SELECT id
            FROM companies
            WHERE owner_user_id = ?
              AND status = 'active'
            LIMIT 1
            """,
            (user_id,),
        ).fetchone()
        if existing_owned:
            raise HTTPException(status_code=400, detail="У вас уже есть активная компания")

        cur.execute(
            """
            INSERT INTO companies (
                name,
                owner_user_id,
                status,
                description,
                contact_phone,
                contact_email,
                address
            )
            VALUES (?, ?, 'active', ?, ?, ?, ?)
            """,
            (name, user_id, description, contact_phone, contact_email, address),
        )
        company_id = int(cur.lastrowid)

        cur.execute(
            """
            INSERT INTO company_members (company_id, user_id, role, is_active)
            VALUES (?, ?, 'owner', 1)
            """,
            (company_id, user_id),
        )

        cur.execute(
            """
            INSERT INTO company_role_history (
                company_id,
                user_id,
                old_role,
                new_role,
                changed_by_user_id
            )
            VALUES (?, ?, NULL, 'owner', ?)
            """,
            (company_id, user_id, user_id),
        )

        row = cur.execute(
            """
            SELECT id, name, description, contact_phone, contact_email, address,
                   status, owner_user_id, created_at, updated_at
            FROM companies
            WHERE id = ?
            LIMIT 1
            """,
            (company_id,),
        ).fetchone()

        members = _members_for_company(cur, company_id)
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "company": _serialize_company(row, my_role="owner", is_organizer=True),
            "members": members,
            "limits": {
                "max_members": int(plan["max_members"]),
                "current_members": len(members),
                "can_add_more": len(members) < int(plan["max_members"]),
            },
        },
    }


@router.get("/company/members", summary="Corporate: list members")
def get_company_members(
    company_id: Optional[int] = Query(default=None, ge=1),
    user=Depends(get_current_user),
):
    user_id = int(user["id"])
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        plan = _active_plan(cur, user_id)
        _require_corporate_access(plan)

        if company_id is None:
            company_row = _company_for_user(cur, user_id)
            if not company_row:
                raise HTTPException(status_code=404, detail="Компания не найдена")
            company_id = int(company_row["id"])
        _assert_organizer(cur, company_id, user_id)

        company = cur.execute(
            """
            SELECT id, name, description, contact_phone, contact_email, address,
                   status, owner_user_id, created_at, updated_at
            FROM companies
            WHERE id = ?
              AND status = 'active'
            LIMIT 1
            """,
            (company_id,),
        ).fetchone()
        if not company:
            raise HTTPException(status_code=404, detail="Компания не найдена")

        members = _members_for_company(cur, company_id)
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "company": _serialize_company(company, my_role="owner", is_organizer=True),
            "members": members,
            "limits": {
                "max_members": int(plan["max_members"]),
                "current_members": len(members),
                "can_add_more": len(members) < int(plan["max_members"]),
            },
        },
    }


@router.post("/company/members", summary="Corporate: add member")
def add_company_member(payload: CompanyAddMemberRequest, user=Depends(get_current_user)):
    user_id = int(user["id"])

    role = clean_text(payload.role, max_len=16).lower() or "member"
    if role not in {"member", "admin"}:
        raise HTTPException(status_code=422, detail="role must be member or admin")

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        plan = _active_plan(cur, user_id)
        _require_corporate_access(plan)

        company_id = payload.company_id
        if company_id is None:
            company_row = _company_for_user(cur, user_id)
            if not company_row:
                raise HTTPException(status_code=404, detail="Компания не найдена")
            company_id = int(company_row["id"])

        _assert_organizer(cur, int(company_id), user_id)

        members = _members_for_company(cur, int(company_id))
        if len(members) >= int(plan["max_members"]):
            raise HTTPException(
                status_code=403,
                detail=(
                    f"Достигнут лимит участников корпоративной подписки ({plan['max_members']}). "
                    "Расширьте тариф."
                ),
            )

        target = None
        if payload.telegram_id is not None:
            target = cur.execute(
                """
                SELECT id, telegram_id, full_name, phone, avatar_url, status
                FROM users
                WHERE telegram_id = ?
                LIMIT 1
                """,
                (int(payload.telegram_id),),
            ).fetchone()
        elif payload.user_phone is not None:
            normalized_phone = _normalize_phone(payload.user_phone)
            target = cur.execute(
                """
                SELECT id, telegram_id, full_name, phone, avatar_url, status
                FROM users
                WHERE phone = ?
                LIMIT 1
                """,
                (normalized_phone,),
            ).fetchone()
        else:
            raise HTTPException(status_code=422, detail="Укажите telegram_id или user_phone")

        if not target:
            raise HTTPException(status_code=404, detail="Пользователь не найден")
        if (target["status"] or "active").lower() != "active":
            raise HTTPException(status_code=400, detail="Пользователь не активен")

        existing = cur.execute(
            """
            SELECT id, is_active
            FROM company_members
            WHERE company_id = ?
              AND user_id = ?
            LIMIT 1
            """,
            (int(company_id), int(target["id"])),
        ).fetchone()

        if existing and bool(existing["is_active"]):
            raise HTTPException(status_code=409, detail="Пользователь уже добавлен")

        if existing:
            cur.execute(
                """
                UPDATE company_members
                SET role = ?, is_active = 1
                WHERE id = ?
                """,
                (role, int(existing["id"])),
            )
        else:
            cur.execute(
                """
                INSERT INTO company_members (company_id, user_id, role, is_active)
                VALUES (?, ?, ?, 1)
                """,
                (int(company_id), int(target["id"]), role),
            )

        cur.execute(
            """
            INSERT INTO company_role_history (
                company_id,
                user_id,
                old_role,
                new_role,
                changed_by_user_id
            )
            VALUES (?, ?, NULL, ?, ?)
            """,
            (int(company_id), int(target["id"]), role, user_id),
        )

        member = cur.execute(
            """
            SELECT
                cm.user_id,
                cm.role,
                cm.is_active,
                cm.created_at,
                u.full_name,
                u.phone,
                u.avatar_url,
                u.status
            FROM company_members cm
            JOIN users u ON u.id = cm.user_id
            WHERE cm.company_id = ?
              AND cm.user_id = ?
              AND cm.is_active = 1
            LIMIT 1
            """,
            (int(company_id), int(target["id"])),
        ).fetchone()

        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "member": {
                "user_id": int(member["user_id"]),
                "telegram_id": int(target["telegram_id"]),
                "full_name": member["full_name"],
                "phone": member["phone"],
                "avatar_url": member["avatar_url"],
                "user_status": member["status"],
                "role": member["role"],
                "is_active": bool(member["is_active"]),
                "created_at": member["created_at"],
            }
        },
    }


@router.delete("/company/members/{member_user_id}", summary="Corporate: remove member")
def remove_company_member(
    member_user_id: int,
    company_id: Optional[int] = Query(default=None, ge=1),
    user=Depends(get_current_user),
):
    user_id = int(user["id"])

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        plan = _active_plan(cur, user_id)
        _require_corporate_access(plan)

        if company_id is None:
            company_row = _company_for_user(cur, user_id)
            if not company_row:
                raise HTTPException(status_code=404, detail="Компания не найдена")
            company_id = int(company_row["id"])

        organizer_role = _assert_organizer(cur, int(company_id), user_id)

        target = cur.execute(
            """
            SELECT user_id, role, is_active
            FROM company_members
            WHERE company_id = ?
              AND user_id = ?
            LIMIT 1
            """,
            (int(company_id), int(member_user_id)),
        ).fetchone()
        if not target or not bool(target["is_active"]):
            raise HTTPException(status_code=404, detail="Участник не найден")

        target_role = (target["role"] or "member").lower()
        if target_role == "owner":
            raise HTTPException(status_code=400, detail="Нельзя удалить владельца компании")

        if organizer_role != "owner" and target_role == "admin":
            raise HTTPException(status_code=403, detail="Только владелец может удалить администратора")

        cur.execute(
            """
            UPDATE company_members
            SET is_active = 0
            WHERE company_id = ?
              AND user_id = ?
            """,
            (int(company_id), int(member_user_id)),
        )
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    return {
        "success": True,
        "data": {
            "removed": True,
            "company_id": int(company_id),
            "user_id": int(member_user_id),
        },
    }
