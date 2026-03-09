from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator

from app.config import BASE_DIR, get_settings


def _db_path_from_url(database_url: str) -> Path:
    url = (database_url or "").strip()
    if not url:
        return BASE_DIR / "flower_shop.db"

    if url.startswith("sqlite:///"):
        raw = url.replace("sqlite:///", "", 1)
    elif "://" not in url:
        raw = url
    else:
        raise ValueError("Only sqlite DATABASE_URL is supported")

    path = Path(raw)
    if not path.is_absolute():
        path = BASE_DIR / path
    return path


def get_db_connection() -> sqlite3.Connection:
    settings = get_settings()
    db_path = _db_path_from_url(settings.DATABASE_URL)
    conn = sqlite3.connect(db_path, timeout=15)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA synchronous = NORMAL")
    conn.execute("PRAGMA busy_timeout = 5000")
    return conn


@contextmanager
def db_cursor(commit: bool = False) -> Iterator[sqlite3.Cursor]:
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        yield cur
        if commit:
            conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
