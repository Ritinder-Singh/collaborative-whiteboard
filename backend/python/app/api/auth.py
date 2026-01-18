"""Authentication API routes."""

from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.user import User
from app.utils.auth import (
    get_password_hash,
    verify_password,
    create_access_token,
    get_current_user,
    get_current_user_required,
)

router = APIRouter()


# Pydantic schemas
class UserRegister(BaseModel):
    """User registration request."""
    email: EmailStr
    password: str = Field(..., min_length=6)
    display_name: str = Field(..., min_length=1, max_length=100)


class UserLogin(BaseModel):
    """User login request."""
    email: EmailStr
    password: str


class AnonymousJoin(BaseModel):
    """Anonymous user quick join request."""
    display_name: str = Field(..., min_length=1, max_length=100)


class TokenResponse(BaseModel):
    """Token response."""
    access_token: str
    token_type: str = "bearer"
    user: "UserResponse"


class UserResponse(BaseModel):
    """User response."""
    id: UUID
    email: Optional[str] = None
    display_name: str
    avatar_url: Optional[str] = None
    is_anonymous: bool

    class Config:
        from_attributes = True


class UserUpdate(BaseModel):
    """User update request."""
    display_name: Optional[str] = Field(None, min_length=1, max_length=100)
    avatar_url: Optional[str] = None


@router.post("/register", response_model=TokenResponse)
async def register(
    data: UserRegister,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    """Register a new user with email and password."""
    # Check if email already exists
    result = await db.execute(select(User).where(User.email == data.email))
    existing_user = result.scalar_one_or_none()

    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    # Create new user
    user = User(
        email=data.email,
        password_hash=get_password_hash(data.password),
        display_name=data.display_name,
        is_anonymous=False,
    )
    db.add(user)
    await db.flush()
    await db.refresh(user)

    # Create access token
    access_token = create_access_token(data={"sub": str(user.id)})

    return TokenResponse(
        access_token=access_token,
        user=UserResponse.model_validate(user),
    )


@router.post("/login", response_model=TokenResponse)
async def login(
    data: UserLogin,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    """Login with email and password."""
    result = await db.execute(select(User).where(User.email == data.email))
    user = result.scalar_one_or_none()

    if not user or not user.password_hash:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    if not verify_password(data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    # Create access token
    access_token = create_access_token(data={"sub": str(user.id)})

    return TokenResponse(
        access_token=access_token,
        user=UserResponse.model_validate(user),
    )


@router.post("/anonymous", response_model=TokenResponse)
async def anonymous_join(
    data: AnonymousJoin,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    """Create an anonymous user for quick join."""
    user = User(
        display_name=data.display_name,
        is_anonymous=True,
    )
    db.add(user)
    await db.flush()
    await db.refresh(user)

    # Create access token
    access_token = create_access_token(data={"sub": str(user.id)})

    return TokenResponse(
        access_token=access_token,
        user=UserResponse.model_validate(user),
    )


@router.get("/me", response_model=UserResponse)
async def get_me(
    user: User = Depends(get_current_user_required),
) -> UserResponse:
    """Get current authenticated user."""
    return UserResponse.model_validate(user)


@router.patch("/me", response_model=UserResponse)
async def update_me(
    data: UserUpdate,
    user: User = Depends(get_current_user_required),
    db: AsyncSession = Depends(get_db),
) -> UserResponse:
    """Update current user profile."""
    if data.display_name is not None:
        user.display_name = data.display_name
    if data.avatar_url is not None:
        user.avatar_url = data.avatar_url

    await db.flush()
    await db.refresh(user)

    return UserResponse.model_validate(user)


@router.post("/convert", response_model=TokenResponse)
async def convert_anonymous(
    data: UserRegister,
    user: User = Depends(get_current_user_required),
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    """Convert an anonymous user to a registered user."""
    if not user.is_anonymous:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User is already registered",
        )

    # Check if email already exists
    result = await db.execute(select(User).where(User.email == data.email))
    existing_user = result.scalar_one_or_none()

    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    # Update user to registered
    user.email = data.email
    user.password_hash = get_password_hash(data.password)
    user.display_name = data.display_name
    user.is_anonymous = False

    await db.flush()
    await db.refresh(user)

    # Create new access token
    access_token = create_access_token(data={"sub": str(user.id)})

    return TokenResponse(
        access_token=access_token,
        user=UserResponse.model_validate(user),
    )
