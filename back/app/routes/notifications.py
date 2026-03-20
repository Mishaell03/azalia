from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.db import get_db_connection
from app.routes.utils import clean_text, get_current_user

router = APIRouter(prefix="/api/notifications", tags=["notifications"])


@router.get("/items", summary="Get User Notifications")
def get_user_notifications(
    status: Optional[str] = Query(default="pending", max_length=32),
    notification_type: Optional[str] = Query(default=None, alias="type", max_length=32),
    channel: Optional[str] = Query(default=None, max_length=32),
    limit: int = Query(default=50, ge=1, le=200),
    user=Depends(get_current_user),
):
    resolved_status = clean_text(status, max_len=32).lower()
    resolved_type = clean_text(notification_type, max_len=32).lower() if notification_type is not None else ""
    resolved_channel = clean_text(channel, max_len=32).lower() if channel is not None else ""

    where_parts = ["n.user_id = ?"]
    params: list[object] = [int(user["id"])]

    if resolved_status:
        where_parts.append("n.status = ?")
        params.append(resolved_status)
    if resolved_type:
        where_parts.append("n.type = ?")
        params.append(resolved_type)
    if resolved_channel:
        where_parts.append("n.channel = ?")
        params.append(resolved_channel)

    where_sql = " AND ".join(where_parts)

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        rows = cur.execute(
            f"""
            SELECT
                n.id,
                n.user_id,
                n.template_id,
                n.type,
                n.channel,
                n.title,
                n.body,
                n.status,
                n.scheduled_at,
                n.sent_at,
                n.related_order_id,
                n.related_user_plant_id,
                n.created_at
            FROM notifications n
            WHERE {where_sql}
            ORDER BY n.created_at DESC, n.id DESC
            LIMIT ?
            """,
            tuple(params + [limit]),
        ).fetchall()
    finally:
        conn.close()

    items = [
        {
            "id": int(row["id"]),
            "user_id": int(row["user_id"]),
            "template_id": int(row["template_id"]) if row["template_id"] is not None else None,
            "type": row["type"],
            "channel": row["channel"],
            "title": row["title"],
            "body": row["body"],
            "status": row["status"],
            "scheduled_at": row["scheduled_at"],
            "sent_at": row["sent_at"],
            "related_order_id": int(row["related_order_id"]) if row["related_order_id"] is not None else None,
            "related_user_plant_id": int(row["related_user_plant_id"]) if row["related_user_plant_id"] is not None else None,
            "created_at": row["created_at"],
        }
        for row in rows
    ]

    return {
        "success": True,
        "data": {
            "items": items,
            "count": len(items),
            "filters": {
                "status": resolved_status or None,
                "type": resolved_type or None,
                "channel": resolved_channel or None,
            },
        },
    }

