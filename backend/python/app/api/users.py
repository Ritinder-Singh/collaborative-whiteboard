"""User API routes."""

from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel
from sqlalchemy import select, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.user import User
from app.utils.auth import get_current_user_required

router = APIRouter()


class UserResponse(BaseModel):
    """User response."""
    id: UUID
    email: Optional[str] = None
    display_name: str
    avatar_url: Optional[str] = None
    is_anonymous: bool

    class Config:
        from_attributes = True


class UserSearchResponse(BaseModel):
    """User search response."""
    users: list[UserResponse]
    total: int


@router.get("/search", response_model=UserSearchResponse)
async def search_users(
    q: str = Query(..., min_length=1, max_length=100),
    limit: int = Query(10, ge=1, le=50),
    user: User = Depends(get_current_user_required),
    db: AsyncSession = Depends(get_db),
) -> UserSearchResponse:
    """Search for users by email or display name."""
    search_pattern = f"%{q}%"

    result = await db.execute(
        select(User)
        .where(
            User.is_anonymous == False,
            or_(
                User.email.ilike(search_pattern),
                User.display_name.ilike(search_pattern),
            ),
        )
        .limit(limit)
    )
    users = result.scalars().all()

    return UserSearchResponse(
        users=[UserResponse.model_validate(u) for u in users],
        total=len(users),
    )


@router.get("/{user_id}", response_model=UserResponse)
async def get_user(
    user_id: UUID,
    user: User = Depends(get_current_user_required),
    db: AsyncSession = Depends(get_db),
) -> UserResponse:
    """Get a user by ID."""
    result = await db.execute(select(User).where(User.id == user_id))
    target_user = result.scalar_one_or_none()

    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    return UserResponse.model_validate(target_user)
