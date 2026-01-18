"""Board models."""

from datetime import datetime
from typing import Optional, Any
from uuid import UUID, uuid4

from sqlalchemy import String, Boolean, DateTime, Integer, ForeignKey, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID as PG_UUID, JSONB

from app.database import Base


class Board(Base):
    """Board model for whiteboard canvases."""

    __tablename__ = "boards"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        default="Untitled Board",
    )
    owner_id: Mapped[Optional[UUID]] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    is_locked: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
    )
    is_public: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
    )
    thumbnail_url: Mapped[Optional[str]] = mapped_column(
        String(500),
        nullable=True,
    )
    canvas_data: Mapped[dict[str, Any]] = mapped_column(
        JSONB,
        default=dict,
        nullable=False,
    )
    settings: Mapped[dict[str, Any]] = mapped_column(
        JSONB,
        default=dict,
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )

    # Relationships
    owner = relationship(
        "User",
        back_populates="owned_boards",
        foreign_keys=[owner_id],
    )
    members = relationship(
        "BoardMember",
        back_populates="board",
        cascade="all, delete-orphan",
    )
    versions = relationship(
        "BoardVersion",
        back_populates="board",
        cascade="all, delete-orphan",
        order_by="BoardVersion.version_number.desc()",
    )

    def __repr__(self) -> str:
        return f"<Board {self.name} ({self.id})>"


class BoardMember(Base):
    """Board membership for collaboration permissions."""

    __tablename__ = "board_members"

    board_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("boards.id", ondelete="CASCADE"),
        primary_key=True,
    )
    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
        index=True,
    )
    role: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="editor",
    )
    joined_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )

    # Relationships
    board = relationship("Board", back_populates="members")
    user = relationship("User", back_populates="board_memberships")

    def __repr__(self) -> str:
        return f"<BoardMember {self.user_id} - {self.role}>"


class BoardVersion(Base):
    """Board version history for restore functionality."""

    __tablename__ = "board_versions"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    board_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("boards.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    version_number: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )
    canvas_data: Mapped[dict[str, Any]] = mapped_column(
        JSONB,
        nullable=False,
    )
    created_by: Mapped[Optional[UUID]] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )

    # Relationships
    board = relationship("Board", back_populates="versions")

    def __repr__(self) -> str:
        return f"<BoardVersion {self.board_id} v{self.version_number}>"
