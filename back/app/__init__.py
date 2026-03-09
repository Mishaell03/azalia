from __future__ import annotations

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from app.config import BASE_DIR, get_settings
from app.core.database import create_database, validate_schema
from app.routes.auth import router as auth_router
from app.routes.cart import router as cart_router
from app.routes.categories import router as categories_router
from app.routes.employees import router as employees_router
from app.routes.payments import router as payments_router
from app.routes.plants import router as plants_router


def create_app() -> FastAPI:
    settings = get_settings()

    app = FastAPI(title="Flower Shop API", debug=settings.DEBUG)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.middleware("http")
    async def security_headers(request: Request, call_next):
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Content-Security-Policy"] = "default-src 'self'; img-src 'self' data:;"
        return response

    @app.on_event("startup")
    async def startup_init() -> None:
        create_database()
        validate_schema()

    @app.exception_handler(Exception)
    async def internal_error_handler(_: Request, exc: Exception):
        if settings.DEBUG:
            return JSONResponse(status_code=500, content={"success": False, "error": str(exc)})
        return JSONResponse(status_code=500, content={"success": False, "error": "Internal server error"})

    img_dir = BASE_DIR / "img"
    img_dir.mkdir(parents=True, exist_ok=True)
    app.mount("/img", StaticFiles(directory=img_dir), name="img")

    app.include_router(plants_router)
    app.include_router(categories_router)
    app.include_router(employees_router)
    app.include_router(auth_router)
    app.include_router(cart_router)
    app.include_router(payments_router)

    @app.get("/")
    async def root():
        return {"message": "Flower Shop API running"}

    return app
