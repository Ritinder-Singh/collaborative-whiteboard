# Collaborative Whiteboard

A cross-platform collaborative whiteboard application with real-time synchronization, offline support, and native stylus/Apple Pencil support.

## Features

- **Real-time Collaboration**: Multiple users can draw simultaneously with live updates
- **Pressure Sensitivity**: Full Apple Pencil and stylus support with pressure/tilt
- **Infinite Canvas**: Pan and zoom on an unlimited canvas
- **Drawing Tools**: Pen, eraser, shapes, text, layers
- **User Presence**: See other users' cursors and names
- **Offline Support**: Draw offline, auto-sync when connected
- **Cross-Platform**: iOS, Android, and Web from a single codebase

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter (Dart) |
| Backend | Python (FastAPI) / Go |
| Real-time | Socket.io |
| Cache | Redis |
| Database | PostgreSQL |
| Load Balancer | Nginx |

## Project Structure

```
collaborative-whiteboard/
├── backend/
│   ├── python/          # Python FastAPI backend
│   └── go/              # Go backend (alternative)
├── frontend/
│   └── flutter_app/     # Flutter cross-platform app
├── infrastructure/
│   ├── docker/          # Docker Compose files
│   ├── nginx/           # Nginx configuration
│   └── sql/             # Database schema
└── docs/                # Documentation
```

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Flutter SDK (3.2.0+)
- Python 3.11+ (for local development)

### Running with Docker (Recommended)

1. Start the backend services:

```bash
cd infrastructure/docker
docker-compose -f docker-compose.dev.yml up -d
```

This starts:
- Python backend on `http://localhost:8000`
- Redis on `localhost:6379`
- PostgreSQL on `localhost:5432`

2. Run the Flutter app:

```bash
cd frontend/flutter_app
flutter pub get
flutter run -d chrome  # For web
flutter run            # For connected device
```

### Running Locally (Without Docker)

1. Install Python dependencies:

```bash
cd backend/python
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

2. Start Redis (required):

```bash
# macOS
brew install redis && brew services start redis

# Ubuntu/Debian
sudo apt install redis-server && sudo systemctl start redis
```

3. Run the Python backend:

```bash
cd backend/python
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

4. Run the Flutter app:

```bash
cd frontend/flutter_app
flutter pub get
flutter run
```

## Development

### Backend API

- Health check: `GET /health`
- API docs: `GET /docs` (Swagger UI)

### Socket.io Events

| Event | Direction | Description |
|-------|-----------|-------------|
| `join_board` | Client → Server | Join a whiteboard |
| `stroke_start` | Client → Server | Begin drawing |
| `stroke_update` | Client → Server | Stream stroke points |
| `stroke_end` | Client → Server | Complete stroke |
| `cursor_move` | Client → Server | Update cursor position |
| `board_state` | Server → Client | Full board sync |
| `stroke_received` | Server → Client | Remote stroke update |
| `cursor_update` | Server → Client | Remote cursor position |

### Flutter App

The Flutter app uses:
- **Riverpod** for state management
- **perfect_freehand** for smooth stroke rendering
- **socket_io_client** for real-time communication

## Configuration

### Backend Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HOST` | Server host | `0.0.0.0` |
| `PORT` | Server port | `8000` |
| `DEBUG` | Debug mode | `true` |
| `REDIS_HOST` | Redis host | `localhost` |
| `REDIS_PORT` | Redis port | `6379` |
| `DATABASE_URL` | PostgreSQL URL | See `.env.example` |

### Flutter Configuration

Update the server URL in `lib/features/canvas/screens/canvas_screen.dart`:

```dart
const serverUrl = 'http://your-server-ip:8000';
```

## Testing

### Backend Tests

```bash
cd backend/python
pytest
```

### Flutter Tests

```bash
cd frontend/flutter_app
flutter test
```

## Deployment

### Docker Production

```bash
cd infrastructure/docker
docker-compose up -d
```

This runs:
- Nginx load balancer on port 80
- Two Python backend instances
- Redis and PostgreSQL

### Kubernetes

Kubernetes manifests are in `infrastructure/kubernetes/`.

## License

MIT
