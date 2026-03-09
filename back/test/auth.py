from __future__ import annotations

import re
import sqlite3
from datetime import datetime, timedelta
from pathlib import Path


USER_ID = 5
DEVICE_ID = "1112EC7E-E1C4-4320-A0B3-C740F0E7427C"
CODE = "0000"

BASE_DIR = Path(__file__).resolve().parents[1]
DB_PATH = BASE_DIR / "flower_shop.db"


def main() -> None:
    if not isinstance(USER_ID, int) or USER_ID <= 0:
        raise RuntimeError("USER_ID должен быть положительным числом")

    if not isinstance(DEVICE_ID, str) or not DEVICE_ID.strip():
        raise RuntimeError("DEVICE_ID должен быть непустой строкой")

    if not isinstance(CODE, str) or not re.fullmatch(r"\d{4}", CODE):
        raise RuntimeError("CODE должен быть строкой из 4 цифр")

    expires_at = (datetime.utcnow() + timedelta(minutes=10)).strftime("%Y-%m-%d %H:%M:%S")

    conn = sqlite3.connect(DB_PATH)
    try:
        cur = conn.cursor()

        user = cur.execute("SELECT id FROM users WHERE id = ?", (USER_ID,)).fetchone()
        if not user:
            raise RuntimeError(f"Пользователь с id={USER_ID} не найден")

        cur.execute(
            """
            INSERT INTO auth_codes (user_id, device_id, code, expires_at, used_at)
            VALUES (?, ?, ?, ?, NULL)
            """,
            (USER_ID, DEVICE_ID.strip(), CODE, expires_at),
        )
        conn.commit()

        print("✅ Запись в auth_codes создана")
        print(f"user_id={USER_ID}")
        print(f"device_id={DEVICE_ID.strip()}")
        print(f"code={CODE}")
        print(f"expires_at_utc={expires_at}")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
