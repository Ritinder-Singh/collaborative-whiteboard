"""Board API routes."""

from datetime import datetime
from typing import Any, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel, Field
from sqlalchemy import select, or_, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.user import User
from app.models.board import Board, BoardMember, BoardVersion
from app.utils.auth import get_current_user, get_current_user_required

router = APIRouter()


# Pydantic schemas
class BoardCreate(BaseModel):
    """Board creation request."""
    name: str = Field(default="Untitled Board", max_length=255)
    is_public: bool = True


class BoardUpdate(BaseModel):
    """Board update request."""
    name: Optional[str] = Field(None, max_length=255)
    is_public: Optional[bool] = None
    is_locked: Optional[bool] = None
    settings: Optional[dict[str, Any]] = None


class BoardCanvasUpdate(BaseModel):
    """Board canvas data update request."""
    canvas_data: dict[str, Any]
    create_version: bool = False


class BoardResponse(BaseModel):
    """Board response."""
    id: UUID
    name: str
    owner_id: Optional[UUID]
    is_locked: bool
    is_public: bool
    thumbnail_url: Optional[str]
    settings: dict[str, Any]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class BoardDetailResponse(BoardResponse):
    """Board detail response with canvas data."""
    canvas_data: dict[str, Any]
    role: Optional[str] = None  # Current user's role


class BoardListResponse(BaseModel):
    """Board list response."""
    boards: list[BoardResponse]
    total: int
    page: int
    page_size: int


class BoardMemberResponse(BaseModel):
    """Board member response."""
    user_id: UUID
    display_name: str
    role: str
    joined_at: datetime


class BoardMemberAdd(BaseModel):
    """Add board member request."""
    user_id: UUID
    role: str = Field(default="editor", pattern="^(editor|viewer)$")


class BoardVersionResponse(BaseModel):
    """Board version response."""
    id: UUID
    version_number: int
    created_by: Optional[UUID]
    created_at: datetime


@router.get("", response_model=BoardListResponse)
async def list_boards(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user: Optional[User] = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> BoardListResponse:
    """List boards accessible to the current user."""
    offset = (page - 1) * page_size

    # Build query based on user authentication
    if user:
        # Authenticated: own boards + member boards + public boards
        query = (
            select(Board)
            .outerjoin(BoardMember, Board.id == BoardMember.board_id)
            .where(
                or_(
                    Board.owner_id == user.id,
                    BoardMember.user_id == user.id,
                    Board.is_public == True,
                )
            )
            .distinct()
            .order_by(Board.updated_at.desc())
            .offset(offset)
            .limit(page_size)
        )
        count_query = (
            select(func.count(Board.id.distinct()))
            .outerjoin(BoardMember, Board.id == BoardMember.board_id)
            .where(
                or_(
                    Board.owner_id == user.id,
                    BoardMember.user_id == user.id,
                    Board.is_public == True,
                )
            )
        )
    else:
        # Unauthenticated: only public boards
        query = (
            select(Board)
            .where(Board.is_public == True)
            .order_by(Board.updated_at.desc())
            .offset(offset)
            .limit(page_size)
        )
        count_query = select(func.count()).where(Board.is_public == True)

    result = await db.execute(query)
    boards = result.scalars().all()

    count_result = await db.execute(count_query)
    total = count_result.scalar() or 0

    return BoardListResponse(
        boards=[BoardResponse.model_validate(b) for b in boards],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/my", response_model=BoardListResponse)
async def list_my_boards(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user: User = Depends(get_current_user_required),
    db: AsyncSession = Depends(get_db),
) -> BoardListResponse:
    """List boards owned by the current user."""
    offset = (page - 1) * page_size

    query = (
        select(Board)
        .where(Board.owner_id == user.id)
        .order_by(Board.updated_at.desc())
        .offset(offset)
        .limit(page_size)
    )

    count_query = (
        select(func.count())
        .select_from(Board)
        .where(Board.owner_id == user.id)
    )

    result = await db.execute(query)
    boards = result.scalars().all()

    count_result = await db.execute(count_query)
    total = count_result.scalar() or 0

    return BoardListResponse(
        boards=[BoardResponse.model_validate(b) for b in boards],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.post("", response_model=BoardDetailResponse, status_code=status.HTTP_201_CREATED)
async def create_board(
    data: BoardCreate,
    user: Optional[User] = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> BoardDetailResponse:
    """Create a new board."""
    board = Board(
        name=data.name,
        owner_id=user.id if user else None,
        is_public=data.is_public,
        canvas_data={"strokes": [], "objects": [], "layers": []},
    )
    db.add(board)

    # Add owner as member with owner role
    if user:
        member = BoardMember(
            board_id=board.id,
            user_id=user.id,
            role="owner",
        )
        db.add(member)

    await db.flush()
    await db.refresh(board)

    response = BoardDetailResponse.model_validate(board)
    response.role = "owner" if user else None
    return response


@router.get("/{board_id}", response_model=BoardDetailResponse)
async def get_board(
    board_id: UUID,
    user: Optional[User] = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> BoardDetailResponse:
    """Get a board by ID."""
    result = await db.execute(
        select(Board)
        .options(selectinload(Board.members))
        .where(Board.id == board_id)
    )
    board = result.scalar_one_or_none()

    if not board:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Board not found",
        )

    # Check access
    if not board.is_public:
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication required for private boards",
            )
        # Check if user is owner or member
        is_owner = board.owner_id == user.id
        is_member = any(m.user_id == user.id for m in board.members)
        if not is_owner and not is_member:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied",
            )

    # Determine user's role
    role = None
    if user:
        if board.owner_id == user.id:
            role = "owner"
        else:
            for m in board.members:
                if m.user_id == user.id:
                    role = m.role
                    break

    response = BoardDetailResponse.model_validate(board)
    response.role = role
    return response


@router.patch("/{board_id}", response_model=BoardDetailResponse)
async def update_board(
    board_id: UUID,
    data: BoardUpdate,
    user: User = Depends(get_current_user_required),
    db: AsyncSession = Depends(get_db),
) -> BoardDetailResponse:
    """Update board settings (owner only)."""
    result = await db.execute(select(Board).where(Board.id == board_id))
    board = result.scalar_one_or_none()

    if not board:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Board not found",
        )

    # Check ownership
    if board.owner_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the owner can update board settings",
        )

    # Update fields
    if data.name is not None:
        board.name = data.name
    if data.is_public is not None:
        board.is_public = data.is_public
    if data.is_locked is not None:
        board.is_locked = data.is_locked
    if data.settings is not None:
        board.settings = data.settings

    await db.flush()
    await db.refresh(board)

    response = BoardDetailResponse.model_validate(board)
    response.role = "owner"
    return response


@router.put("/{board_id}/canvas", response_model=BoardDetailResponse)
async def update_canvas(
    board_id: UUID,
    data: BoardCanvasUpdate,
    user: Optional[User] = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> BoardDetailResponse:
    """Update board canvas data (auto-save endpoint)."""
    result = await db.execute(
        select(Board)
        .options(selectinload(Board.members))
        .where(Board.id == board_id)
    )
    board = result.scalar_one_or_none()

    if not board:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Board not found",
        )

    # Check edit permissions
    can_edit = False
    role = None

    if board.is_public and not board.is_locked:
        can_edit = True
    elif user:
        if board.owner_id == user.id:
            can_edit = True
            role = "owner"
        else:
            for m in board.members:
                if m.user_id == user.id:
                    role = m.role
                    if role in ("owner", "editor"):
                        can_edit = True
                    break

    if not can_edit:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have permission to edit this board",
        )

    # Create version if requested
    if data.create_version:
        # Get current max version number
        version_result = await db.execute(
            select(func.max(BoardVersion.version_number))
            .where(BoardVersion.board_id == board_id)
        )
        max_version = version_result.scalar() or 0

        version = BoardVersion(
            board_id=board_id,
            version_number=max_version + 1,
            canvas_data=board.canvas_data,  # Save current state before update
            created_by=user.id if user else None,
        )
        db.add(version)

    # Update canvas data
    board.canvas_data = data.canvas_data

    await db.flush()
    await db.refresh(board)

    response = BoardDetailResponse.model_validate(board)
    response.role = role
    return response


@router.delete("/{board_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_board(
    board_id: UUID,
    user: User = Depends(get_current_user_required),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Delete a board (owner only)."""
    result = await db.execute(select(Board).where(Board.id == board_id))
    board = result.scalar_one_or_none()

    if not board:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Board not found",
        )

    if board.owner_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the owner can delete this board",
        )

    await db.delete(board)


@router.get("/{board_id}/members", response_model=list[BoardMemberResponse])
async def list_board_members(
    board_id: UUID,
    user: User = Depends(get_current_user_required),
    db: AsyncSession = Depends(get_db),
) -> list[BoardMemberResponse]:
    """List board members."""
    result = await db.execute(
        select(Board)
        .options(selectinload(Board.members).selectinload(BoardMember.user))
        .where(Board.id == board_id)
    )
    board = result.scalar_one_or_none()

    if not board:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Board not found",
        )

    return [
        BoardMemberResponse(
            user_id=m.user_id,
            display_name=m.user.display_name,
            role=m.role,
            joined_at=m.joined_at,
        )
        for m in board.members
    ]


@router.post("/{board_id}/members", response_model=BoardMemberResponse, status_code=status.HTTP_201_CREATED)
async def add_board_member(
    board_id: UUID,
    data: BoardMemberAdd,
    user: User = Depends(get_current_user_required),
    db: AsyncSession = Depends(get_db),
) -> BoardMemberResponse:
    """Add a member to a board (owner only)."""
    result = await db.execute(select(Board).where(Board.id == board_id))
    board = result.scalar_one_or_none()

    if not board:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Board not found",
        )

    if board.owner_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the owner can add members",
        )

    # Check if user exists
    user_result = await db.execute(select(User).where(User.id == data.user_id))
    target_user = user_result.scalar_one_or_none()

    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    # Check if already a member
    member_result = await db.execute(
        select(BoardMember).where(
            BoardMember.board_id == board_id,
            BoardMember.user_id == data.user_id,
        )
    )
    existing = member_result.scalar_one_or_none()

    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User is already a member",
        )

    member = BoardMember(
        board_id=board_id,
        user_id=data.user_id,
        role=data.role,
    )
    db.add(member)
    await db.flush()
    await db.refresh(member)

    return BoardMemberResponse(
        user_id=member.user_id,
        display_name=target_user.display_name,
        role=member.role,
        joined_at=member.joined_at,
    )


@router.delete("/{board_id}/members/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_board_member(
    board_id: UUID,
    user_id: UUID,
    user: User = Depends(get_current_user_required),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Remove a member from a board (owner only)."""
    result = await db.execute(select(Board).where(Board.id == board_id))
    board = result.scalar_one_or_none()

    if not board:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Board not found",
        )

    if board.owner_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the owner can remove members",
        )

    if user_id == user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot remove yourself from the board",
        )

    member_result = await db.execute(
        select(BoardMember).where(
            BoardMember.board_id == board_id,
            BoardMember.user_id == user_id,
        )
    )
    member = member_result.scalar_one_or_none()

    if not member:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Member not found",
        )

    await db.delete(member)


@router.get("/{board_id}/versions", response_model=list[BoardVersionResponse])
async def list_board_versions(
    board_id: UUID,
    user: User = Depends(get_current_user_required),
    db: AsyncSession = Depends(get_db),
) -> list[BoardVersionResponse]:
    """List board versions (history)."""
    result = await db.execute(
        select(BoardVersion)
        .where(BoardVersion.board_id == board_id)
        .order_by(BoardVersion.version_number.desc())
        .limit(50)
    )
    versions = result.scalars().all()

    return [
        BoardVersionResponse(
            id=v.id,
            version_number=v.version_number,
            created_by=v.created_by,
            created_at=v.created_at,
        )
        for v in versions
    ]


@router.post("/{board_id}/versions/{version_id}/restore", response_model=BoardDetailResponse)
async def restore_board_version(
    board_id: UUID,
    version_id: UUID,
    user: User = Depends(get_current_user_required),
    db: AsyncSession = Depends(get_db),
) -> BoardDetailResponse:
    """Restore a board to a specific version (owner/editor only)."""
    result = await db.execute(
        select(Board)
        .options(selectinload(Board.members))
        .where(Board.id == board_id)
    )
    board = result.scalar_one_or_none()

    if not board:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Board not found",
        )

    # Check edit permissions
    can_edit = board.owner_id == user.id
    role = "owner" if can_edit else None

    if not can_edit:
        for m in board.members:
            if m.user_id == user.id and m.role in ("owner", "editor"):
                can_edit = True
                role = m.role
                break

    if not can_edit:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have permission to restore this board",
        )

    # Get the version
    version_result = await db.execute(
        select(BoardVersion).where(
            BoardVersion.id == version_id,
            BoardVersion.board_id == board_id,
        )
    )
    version = version_result.scalar_one_or_none()

    if not version:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Version not found",
        )

    # Save current state as new version
    max_version_result = await db.execute(
        select(func.max(BoardVersion.version_number))
        .where(BoardVersion.board_id == board_id)
    )
    max_version = max_version_result.scalar() or 0

    backup_version = BoardVersion(
        board_id=board_id,
        version_number=max_version + 1,
        canvas_data=board.canvas_data,
        created_by=user.id,
    )
    db.add(backup_version)

    # Restore the canvas data
    board.canvas_data = version.canvas_data

    await db.flush()
    await db.refresh(board)

    response = BoardDetailResponse.model_validate(board)
    response.role = role
    return response
