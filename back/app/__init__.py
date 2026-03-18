from __future__ import annotations

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse

from app.config import BASE_DIR, get_settings
from app.core.database import create_database, validate_schema
from app.routes.auth import router as auth_router
from app.routes.cart import router as cart_router
from app.routes.categories import router as categories_router
from app.routes.employees import router as employees_router
from app.routes.payments import router as payments_router
from app.routes.plants import router as plants_router
from app.routes.pot import router as pot_router


def create_app() -> FastAPI:
    settings = get_settings()

    app = FastAPI(
        title="Flower Shop API",
        description=(
            "API для магазина растений: авторизация, каталог, корзина, "
            "сотрудники и платежи."
        ),
        version="1.0.0",
        debug=settings.DEBUG,
        openapi_tags=[
            {"name": "auth", "description": "Авторизация и профиль пользователя"},
            {"name": "plants", "description": "Каталог растений и изображения"},
            {"name": "categories", "description": "Категории каталога"},
            {"name": "cart", "description": "Корзина и избранное"},
            {"name": "employees", "description": "Пользователи и сотрудники"},
            {"name": "payments", "description": "Оплата и статусы заказов"},
            {"name": "pot", "description": "Справочники горшков и цены"},
        ],
    )

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
        path = request.url.path
        if path.startswith("/docs") or path.startswith("/redoc") or path.startswith("/openapi.json"):
            response.headers["Content-Security-Policy"] = (
                "default-src 'self' https://cdn.jsdelivr.net https://fastapi.tiangolo.com; "
                "script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; "
                "style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; "
                "img-src 'self' data: https://fastapi.tiangolo.com;"
            )
        else:
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
    default_img_path = (img_dir / "none.png").resolve()
    default_user_img_path = (img_dir / "users" / "user2.png").resolve()

    @app.get("/img/{file_path:path}", include_in_schema=False)
    async def get_image(file_path: str):
        # Разрешаем отдавать только файлы внутри каталога img.
        requested = (img_dir / file_path).resolve()
        is_inside_img = str(requested).startswith(str(img_dir.resolve()))
        if is_inside_img and requested.is_file():
            target = requested
        elif file_path.startswith("users/") and default_user_img_path.is_file():
            target = default_user_img_path
        else:
            target = default_img_path
        return FileResponse(target)

    app.include_router(plants_router)
    app.include_router(categories_router)
    app.include_router(employees_router)
    app.include_router(auth_router)
    app.include_router(cart_router)
    app.include_router(payments_router)
    app.include_router(pot_router)

    @app.get("/")
    async def root():
        """Проверка, что API запущено."""
        return {"message": "Flower Shop API running"}

    return app
