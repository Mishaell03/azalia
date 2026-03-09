from __future__ import annotations

import uvicorn

from app import create_app
from app.config import get_settings


app = create_app()


if __name__ == "__main__":
    settings = get_settings()
    uvicorn.run("main:app", host="0.0.0.0", port=int(settings.PORT), reload=settings.DEBUG)
