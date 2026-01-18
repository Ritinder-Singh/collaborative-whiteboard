"""API routes."""

from fastapi import APIRouter

from app.api.auth import router as auth_router
from app.api.boards import router as boards_router
from app.api.users import router as users_router

api_router = APIRouter()

api_router.include_router(auth_router, prefix="/auth", tags=["auth"])
api_router.include_router(boards_router, prefix="/boards", tags=["boards"])
api_router.include_router(users_router, prefix="/users", tags=["users"])
