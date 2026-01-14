"""Socket.io event handlers for real-time collaboration."""

import socketio
import logging
from typing import Any
from datetime import datetime
import json

logger = logging.getLogger(__name__)

# Create Socket.io server with async mode
sio = socketio.AsyncServer(
    async_mode="asgi",
    cors_allowed_origins="*",
    logger=True,
    engineio_logger=True,
)


# In-memory storage for Phase 1 (will move to Redis in Phase 2)
class BoardState:
    """Manages board state and connected users."""

    def __init__(self):
        self.boards: dict[str, dict] = {}  # board_id -> {strokes, objects, layers}
        self.users: dict[str, dict] = {}  # sid -> {user_id, display_name, board_id}
        self.board_users: dict[str, set] = {}  # board_id -> set of sids

    def get_or_create_board(self, board_id: str) -> dict:
        """Get or create a board state."""
        if board_id not in self.boards:
            self.boards[board_id] = {
                "strokes": [],
                "objects": [],
                "layers": [{"id": "default", "name": "Layer 1", "visible": True, "locked": False}],
            }
            self.board_users[board_id] = set()
        return self.boards[board_id]

    def add_user(self, sid: str, user_id: str, display_name: str, board_id: str):
        """Add a user to a board."""
        self.users[sid] = {
            "user_id": user_id,
            "display_name": display_name,
            "board_id": board_id,
            "joined_at": datetime.utcnow().isoformat(),
        }
        if board_id in self.board_users:
            self.board_users[board_id].add(sid)

    def remove_user(self, sid: str) -> str | None:
        """Remove a user and return their board_id."""
        if sid in self.users:
            board_id = self.users[sid]["board_id"]
            del self.users[sid]
            if board_id in self.board_users:
                self.board_users[board_id].discard(sid)
            return board_id
        return None

    def get_board_user_count(self, board_id: str) -> int:
        """Get number of users in a board."""
        return len(self.board_users.get(board_id, set()))

    def get_board_users(self, board_id: str) -> list[dict]:
        """Get list of users in a board."""
        return [
            self.users[sid]
            for sid in self.board_users.get(board_id, set())
            if sid in self.users
        ]


# Global state instance
state = BoardState()


@sio.event
async def connect(sid: str, environ: dict, auth: dict | None = None):
    """Handle new client connection."""
    logger.info(f"Client connected: {sid}")
    await sio.emit("connected", {"sid": sid}, to=sid)


@sio.event
async def disconnect(sid: str):
    """Handle client disconnection."""
    logger.info(f"Client disconnected: {sid}")
    board_id = state.remove_user(sid)
    if board_id:
        await sio.leave_room(sid, board_id)
        await sio.emit(
            "user_left",
            {"sid": sid},
            room=board_id,
            skip_sid=sid,
        )
        await sio.emit(
            "user_count",
            {"count": state.get_board_user_count(board_id)},
            room=board_id,
        )


@sio.event
async def join_board(sid: str, data: dict):
    """Handle user joining a board."""
    board_id = data.get("board_id", "default")
    user_id = data.get("user_id", sid)
    display_name = data.get("display_name", f"User-{sid[:6]}")

    logger.info(f"User {display_name} joining board {board_id}")

    # Join the Socket.io room for this board
    await sio.enter_room(sid, board_id)

    # Add user to state
    state.add_user(sid, user_id, display_name, board_id)

    # Get or create board state
    board = state.get_or_create_board(board_id)

    # Send current board state to the new user
    await sio.emit(
        "board_state",
        {
            "board_id": board_id,
            "strokes": board["strokes"],
            "objects": board["objects"],
            "layers": board["layers"],
            "users": state.get_board_users(board_id),
        },
        to=sid,
    )

    # Notify other users
    await sio.emit(
        "user_joined",
        {
            "sid": sid,
            "user_id": user_id,
            "display_name": display_name,
        },
        room=board_id,
        skip_sid=sid,
    )

    # Update user count
    await sio.emit(
        "user_count",
        {"count": state.get_board_user_count(board_id)},
        room=board_id,
    )


@sio.event
async def leave_board(sid: str, data: dict):
    """Handle user leaving a board."""
    board_id = state.remove_user(sid)
    if board_id:
        await sio.leave_room(sid, board_id)
        await sio.emit(
            "user_left",
            {"sid": sid},
            room=board_id,
            skip_sid=sid,
        )
        await sio.emit(
            "user_count",
            {"count": state.get_board_user_count(board_id)},
            room=board_id,
        )


@sio.event
async def stroke_start(sid: str, data: dict):
    """Handle start of a new stroke."""
    user = state.users.get(sid)
    if not user:
        return

    board_id = user["board_id"]
    stroke_id = data.get("stroke_id")

    logger.debug(f"Stroke start: {stroke_id} from {sid}")

    # Initialize stroke in board state
    board = state.boards.get(board_id)
    if board:
        stroke = {
            "id": stroke_id,
            "user_id": user["user_id"],
            "tool": data.get("tool", "pen"),
            "color": data.get("color", "#000000"),
            "size": data.get("size", 2),
            "layer_id": data.get("layer_id", "default"),
            "points": [],
            "completed": False,
        }
        board["strokes"].append(stroke)

    # Broadcast to other users
    await sio.emit(
        "stroke_start",
        {
            "stroke_id": stroke_id,
            "user_id": user["user_id"],
            "tool": data.get("tool", "pen"),
            "color": data.get("color", "#000000"),
            "size": data.get("size", 2),
            "layer_id": data.get("layer_id", "default"),
        },
        room=board_id,
        skip_sid=sid,
    )


@sio.event
async def stroke_update(sid: str, data: dict):
    """Handle stroke point updates (streaming)."""
    user = state.users.get(sid)
    if not user:
        return

    board_id = user["board_id"]
    stroke_id = data.get("stroke_id")
    points = data.get("points", [])

    # Update stroke in board state
    board = state.boards.get(board_id)
    if board:
        for stroke in board["strokes"]:
            if stroke["id"] == stroke_id and not stroke["completed"]:
                stroke["points"].extend(points)
                break

    # Broadcast to other users
    await sio.emit(
        "stroke_update",
        {
            "stroke_id": stroke_id,
            "points": points,
        },
        room=board_id,
        skip_sid=sid,
    )


@sio.event
async def stroke_end(sid: str, data: dict):
    """Handle stroke completion."""
    user = state.users.get(sid)
    if not user:
        return

    board_id = user["board_id"]
    stroke_id = data.get("stroke_id")

    logger.debug(f"Stroke end: {stroke_id} from {sid}")

    # Mark stroke as completed
    board = state.boards.get(board_id)
    if board:
        for stroke in board["strokes"]:
            if stroke["id"] == stroke_id:
                stroke["completed"] = True
                break

    # Broadcast to other users
    await sio.emit(
        "stroke_end",
        {"stroke_id": stroke_id},
        room=board_id,
        skip_sid=sid,
    )


@sio.event
async def cursor_move(sid: str, data: dict):
    """Handle cursor position updates."""
    user = state.users.get(sid)
    if not user:
        return

    board_id = user["board_id"]

    # Broadcast cursor position to other users
    await sio.emit(
        "cursor_update",
        {
            "user_id": user["user_id"],
            "display_name": user["display_name"],
            "x": data.get("x", 0),
            "y": data.get("y", 0),
        },
        room=board_id,
        skip_sid=sid,
    )


@sio.event
async def clear_board(sid: str, data: dict):
    """Handle clearing the board."""
    user = state.users.get(sid)
    if not user:
        return

    board_id = user["board_id"]

    logger.info(f"Board cleared by {user['display_name']}")

    # Clear board state
    board = state.boards.get(board_id)
    if board:
        board["strokes"] = []
        board["objects"] = []

    # Broadcast to all users including sender
    await sio.emit(
        "board_cleared",
        {"cleared_by": user["user_id"]},
        room=board_id,
    )


@sio.event
async def object_add(sid: str, data: dict):
    """Handle adding a shape or object."""
    user = state.users.get(sid)
    if not user:
        return

    board_id = user["board_id"]

    # Add object to board state
    board = state.boards.get(board_id)
    if board:
        obj = {
            "id": data.get("object_id"),
            "type": data.get("type"),
            "properties": data.get("properties", {}),
            "layer_id": data.get("layer_id", "default"),
            "user_id": user["user_id"],
        }
        board["objects"].append(obj)

    # Broadcast to other users
    await sio.emit(
        "object_added",
        {
            "object_id": data.get("object_id"),
            "type": data.get("type"),
            "properties": data.get("properties", {}),
            "layer_id": data.get("layer_id", "default"),
            "user_id": user["user_id"],
        },
        room=board_id,
        skip_sid=sid,
    )


@sio.event
async def object_update(sid: str, data: dict):
    """Handle updating an object."""
    user = state.users.get(sid)
    if not user:
        return

    board_id = user["board_id"]
    object_id = data.get("object_id")
    properties = data.get("properties", {})

    # Update object in board state
    board = state.boards.get(board_id)
    if board:
        for obj in board["objects"]:
            if obj["id"] == object_id:
                obj["properties"].update(properties)
                break

    # Broadcast to other users
    await sio.emit(
        "object_updated",
        {
            "object_id": object_id,
            "properties": properties,
            "user_id": user["user_id"],
        },
        room=board_id,
        skip_sid=sid,
    )


@sio.event
async def object_delete(sid: str, data: dict):
    """Handle deleting an object."""
    user = state.users.get(sid)
    if not user:
        return

    board_id = user["board_id"]
    object_id = data.get("object_id")

    # Remove object from board state
    board = state.boards.get(board_id)
    if board:
        board["objects"] = [o for o in board["objects"] if o["id"] != object_id]

    # Broadcast to other users
    await sio.emit(
        "object_deleted",
        {
            "object_id": object_id,
            "user_id": user["user_id"],
        },
        room=board_id,
        skip_sid=sid,
    )
