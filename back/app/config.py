from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


BASE_DIR = Path(__file__).resolve().parents[1]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=BASE_DIR / ".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    SECRET_KEY: str = ""
    DATABASE_URL: str = "sqlite:///flower_shop.db"
    DEBUG: bool = False
    PORT: int = 5000

    BOT_TOKEN: str = ""
    API_BASE_URL: str = "https://www.nebinance.ru/api"

    YOOKASSA_SHOP_ID: str = ""
    YOOKASSA_SDK: str = ""
    YOOKASSA_API_KEY: str = ""


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
