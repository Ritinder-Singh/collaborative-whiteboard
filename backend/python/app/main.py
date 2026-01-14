"""Main FastAPI application entry point."""

import logging
from contextlib import asynccontextmanager

import socketio
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.socket_handlers import sio

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler."""
    logger.info("Starting Collaborative Whiteboard server...")
    logger.info(f"Server running on {settings.host}:{settings.port}")
    yield
    logger.info("Shutting down server...")


# Create FastAPI app
app = FastAPI(
    title="Collaborative Whiteboard API",
    description="Real-time collaborative whiteboard backend",
    version="1.0.0",
    lifespan=lifespan,
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint for load balancers."""
    return {"status": "healthy", "service": "whiteboard-backend"}


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "message": "Collaborative Whiteboard API",
        "version": "1.0.0",
        "docs": "/docs",
    }


# Create Socket.io ASGI app
socket_app = socketio.ASGIApp(
    sio,
    other_asgi_app=app,
    socketio_path="socket.io",
)

# Export the combined app for uvicorn
app = socket_app


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
    )
