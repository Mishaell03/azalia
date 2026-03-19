from __future__ import annotations

from datetime import date, datetime, timedelta
from typing import Optional

from fastapi import HTTPException

from app.routes.utils import clean_optional_text, clean_text

DEFAULT_PLANT_IMAGE_PATH = "img/none.png"
ALLOWED_CARE_TYPES = {"watering", "soil_change", "fertilizing", "repotting", "pruning"}


def parse_iso_date(value: str, field_name: str) -> str:
    text = clean_text(value, max_len=16)
    try:
        return datetime.strptime(text, "%Y-%m-%d").strftime("%Y-%m-%d")
    except ValueError:
        raise HTTPException(status_code=422, detail=f"{field_name} must be YYYY-MM-DD")


def parse_optional_iso_date(value: Optional[str], field_name: str) -> Optional[str]:
    if value is None:
        return None
    text = clean_optional_text(value, max_len=16)
    if text is None:
        return None
    return parse_iso_date(text, field_name)


def parse_iso_date_to_obj(value: str, field_name: str) -> date:
    normalized = parse_iso_date(value, field_name)
    return datetime.strptime(normalized, "%Y-%m-%d").date()


def today_iso() -> str:
    return date.today().strftime("%Y-%m-%d")


def normalize_care_type(value: str, field_name: str = "care_type") -> str:
    normalized = clean_text(value, max_len=32).lower()
    if normalized not in ALLOWED_CARE_TYPES:
        supported = ", ".join(sorted(ALLOWED_CARE_TYPES))
        raise HTTPException(status_code=422, detail=f"{field_name} must be one of: {supported}")
    return normalized


def normalize_watering_requirement(value: Optional[str]) -> Optional[str]:
    text = clean_optional_text(value, max_len=64)
    if text is None:
        return None
    return text.lower()


def derive_watering_frequency_days(
    watering_requirement: Optional[str],
    explicit_days: Optional[int],
) -> int:
    if explicit_days is not None and explicit_days > 0:
        return int(explicit_days)

    req = (watering_requirement or "").strip().lower()
    if req:
        if req.isdigit():
            return max(1, min(int(req), 90))
        for token in req.replace("/", " ").replace(",", " ").split():
            if token.isdigit():
                return max(1, min(int(token), 90))

    mapping = {
        "very_low": 14,
        "low": 10,
        "medium": 7,
        "regular": 7,
        "high": 4,
        "very_high": 2,
        "daily": 1,
        "не знаю": 7,
        "unknown": 7,
    }
    return mapping.get(req, 7)


def derive_soil_change_frequency_days(
    watering_frequency_days: int,
    explicit_days: Optional[int],
) -> int:
    # Product requirement: soil replacement is always once per half-year.
    return 180


def next_due_date(last_action_date: Optional[str], frequency_days: int) -> str:
    base = date.today()
    if last_action_date:
        try:
            base = datetime.strptime(last_action_date, "%Y-%m-%d").date()
        except ValueError:
            pass
    return (base + timedelta(days=max(1, int(frequency_days)))).strftime("%Y-%m-%d")


def resolve_photo_url(
    photo_url: Optional[str],
    *,
    fallback: Optional[str] = None,
) -> str:
    photo = clean_optional_text(photo_url, max_len=500)
    if photo:
        return photo
    if fallback:
        return clean_text(fallback, max_len=500)
    return DEFAULT_PLANT_IMAGE_PATH


def parse_month_window(month_value: Optional[str]) -> tuple[str, str]:
    if month_value is None:
        today = date.today()
        start = date(today.year, today.month, 1)
    else:
        raw = clean_text(month_value, max_len=7)
        try:
            year = int(raw[:4])
            month = int(raw[5:7])
            start = date(year, month, 1)
        except Exception:
            raise HTTPException(status_code=422, detail="month must be YYYY-MM")

    if start.month == 12:
        end = date(start.year + 1, 1, 1) - timedelta(days=1)
    else:
        end = date(start.year, start.month + 1, 1) - timedelta(days=1)
    return start.strftime("%Y-%m-%d"), end.strftime("%Y-%m-%d")
