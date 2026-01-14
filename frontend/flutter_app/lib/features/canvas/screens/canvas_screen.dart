import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:collaborative_whiteboard/data/models/stroke.dart';
import 'package:collaborative_whiteboard/data/services/socket_service.dart';
import 'package:collaborative_whiteboard/features/canvas/painters/stroke_painter.dart';
import 'package:collaborative_whiteboard/features/canvas/widgets/toolbar.dart';

const _uuid = Uuid();

/// Provider for the socket service
final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for connection status
final connectionStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  final service = ref.watch(socketServiceProvider);
  return service.connectionStatus;
});

/// Main canvas screen for the whiteboard.
class CanvasScreen extends ConsumerStatefulWidget {
  const CanvasScreen({super.key});

  @override
  ConsumerState<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends ConsumerState<CanvasScreen> {
  // Drawing state
  DrawingTool _selectedTool = DrawingTool.pen;
  Color _selectedColor = Colors.black;
  double _strokeSize = 4.0;

  // Canvas state
  final List<Stroke> _strokes = [];
  Stroke? _currentStroke;
  final Map<String, Stroke> _remoteStrokes = {};
  final Map<String, CursorInfo> _remoteCursors = {};

  // Canvas transformation (for infinite canvas)
  Offset _canvasOffset = Offset.zero;
  double _canvasScale = 1.0;
  Offset? _lastPanPosition;

  // User info
  int _userCount = 1;
  bool _isConnected = false;
  String _boardId = 'default';

  // Subscriptions
  final List<StreamSubscription> _subscriptions = [];

  // Socket service
  late final SocketService _socketService;

  @override
  void initState() {
    super.initState();
    _socketService = ref.read(socketServiceProvider);
    _connectToServer();
  }

  Future<void> _connectToServer() async {
    // Connect to the Python backend
    // For local development, use your machine's IP or localhost
    const serverUrl = 'http://localhost:8000';

    await _socketService.connect(
      serverUrl: serverUrl,
      userId: _uuid.v4(),
      displayName: 'User-${_uuid.v4().substring(0, 6)}',
    );

    _setupSocketListeners();
    _socketService.joinBoard(_boardId);
  }

  void _setupSocketListeners() {
    // Connection status
    _subscriptions.add(
      _socketService.connectionStatus.listen((status) {
        setState(() {
          _isConnected = status == ConnectionStatus.connected;
        });
      }),
    );

    // Board state (initial sync)
    _subscriptions.add(
      _socketService.onBoardState.listen((data) {
        setState(() {
          _strokes.clear();
          final strokesData = data['strokes'] as List<dynamic>? ?? [];
          for (final s in strokesData) {
            final stroke = Stroke.fromJson(Map<String, dynamic>.from(s));
            if (stroke.completed) {
              _strokes.add(stroke);
            }
          }
        });
      }),
    );

    // User count
    _subscriptions.add(
      _socketService.onUserCount.listen((count) {
        setState(() => _userCount = count);
      }),
    );

    // Remote stroke start
    _subscriptions.add(
      _socketService.onStrokeStart.listen((data) {
        final strokeId = data['stroke_id'] as String;
        final colorStr = data['color'] as String? ?? '#FF000000';
        final colorValue = int.parse(
          colorStr.replaceFirst('#', ''),
          radix: 16,
        );

        setState(() {
          _remoteStrokes[strokeId] = Stroke(
            id: strokeId,
            userId: data['user_id'] as String?,
            tool: data['tool'] as String? ?? 'pen',
            color: Color(colorValue),
            size: (data['size'] as num?)?.toDouble() ?? 2.0,
            layerId: data['layer_id'] as String? ?? 'default',
            points: [],
          );
        });
      }),
    );

    // Remote stroke update
    _subscriptions.add(
      _socketService.onStrokeUpdate.listen((data) {
        final strokeId = data['stroke_id'] as String;
        final points = (data['points'] as List<dynamic>? ?? [])
            .map((p) => StrokePoint.fromJson(Map<String, dynamic>.from(p)))
            .toList();

        setState(() {
          final stroke = _remoteStrokes[strokeId];
          if (stroke != null) {
            _remoteStrokes[strokeId] = stroke.copyWith(
              points: [...stroke.points, ...points],
            );
          }
        });
      }),
    );

    // Remote stroke end
    _subscriptions.add(
      _socketService.onStrokeEnd.listen((data) {
        final strokeId = data['stroke_id'] as String;

        setState(() {
          final stroke = _remoteStrokes.remove(strokeId);
          if (stroke != null) {
            _strokes.add(stroke.copyWith(completed: true));
          }
        });
      }),
    );

    // Remote cursor updates
    _subscriptions.add(
      _socketService.onCursorUpdate.listen((data) {
        final userId = data['user_id'] as String;
        final displayName = data['display_name'] as String? ?? 'User';
        final x = (data['x'] as num).toDouble();
        final y = (data['y'] as num).toDouble();

        setState(() {
          _remoteCursors[userId] = CursorInfo(
            userId: userId,
            displayName: displayName,
            x: x,
            y: y,
            color: _getUserColor(userId),
          );
        });

        // Remove stale cursors after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          final cursor = _remoteCursors[userId];
          if (cursor != null &&
              DateTime.now().difference(cursor.lastUpdate).inSeconds > 5) {
            setState(() => _remoteCursors.remove(userId));
          }
        });
      }),
    );

    // Board cleared
    _subscriptions.add(
      _socketService.onBoardCleared.listen((_) {
        setState(() {
          _strokes.clear();
          _remoteStrokes.clear();
        });
      }),
    );
  }

  Color _getUserColor(String oderId) {
    // Generate a consistent color for each user
    final hash = oderId.hashCode;
    return HSLColor.fromAHSL(
      1.0,
      (hash % 360).toDouble(),
      0.7,
      0.5,
    ).toColor();
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Toolbar
          CanvasToolbar(
            selectedTool: _selectedTool,
            selectedColor: _selectedColor,
            strokeSize: _strokeSize,
            onToolChanged: (tool) => setState(() => _selectedTool = tool),
            onColorChanged: (color) => setState(() => _selectedColor = color),
            onStrokeSizeChanged: (size) => setState(() => _strokeSize = size),
            onClearCanvas: _clearCanvas,
          ),

          // Canvas
          Expanded(
            child: GestureDetector(
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: _onScaleEnd,
              child: Listener(
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerUp,
                behavior: HitTestBehavior.opaque,
                child: ClipRect(
                  child: CustomPaint(
                    painter: StrokePainter(
                      strokes: _strokes,
                      currentStroke: _currentStroke,
                      remoteStrokes: _remoteStrokes,
                      canvasOffset: _canvasOffset,
                      canvasScale: _canvasScale,
                    ),
                    foregroundPainter: CursorPainter(
                      cursors: _remoteCursors,
                      canvasOffset: _canvasOffset,
                      canvasScale: _canvasScale,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),

          // Status bar
          ConnectionStatusBar(
            isConnected: _isConnected,
            userCount: _userCount,
            boardId: _boardId,
          ),
        ],
      ),
    );
  }

  // Convert screen position to canvas position
  Offset _screenToCanvas(Offset screenPos) {
    return (screenPos - _canvasOffset) / _canvasScale;
  }

  void _onPointerDown(PointerDownEvent event) {
    // Only handle drawing for pen/touch, not for panning
    if (_selectedTool == DrawingTool.pen || _selectedTool == DrawingTool.eraser) {
      final canvasPos = _screenToCanvas(event.localPosition);

      final strokeId = _uuid.v4();
      final point = StrokePoint.fromPointer(
        x: canvasPos.dx,
        y: canvasPos.dy,
        pressure: event.pressure,
        tilt: event.tilt,
      );

      setState(() {
        _currentStroke = Stroke(
          id: strokeId,
          tool: _selectedTool == DrawingTool.eraser ? 'eraser' : 'pen',
          color: _selectedColor,
          size: _strokeSize,
          points: [point],
        );
      });

      // Emit stroke start to server
      _socketService.emitStrokeStart(
        strokeId: strokeId,
        tool: _selectedTool == DrawingTool.eraser ? 'eraser' : 'pen',
        color: '#${_selectedColor.value.toRadixString(16).padLeft(8, '0')}',
        size: _strokeSize,
      );
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final canvasPos = _screenToCanvas(event.localPosition);

    // Update cursor position for other users
    _socketService.emitCursorMove(x: canvasPos.dx, y: canvasPos.dy);

    if (_currentStroke != null) {
      final point = StrokePoint.fromPointer(
        x: canvasPos.dx,
        y: canvasPos.dy,
        pressure: event.pressure,
        tilt: event.tilt,
      );

      setState(() {
        _currentStroke = _currentStroke!.copyWith(
          points: [..._currentStroke!.points, point],
        );
      });

      // Emit stroke update to server (batch points for efficiency)
      _socketService.emitStrokeUpdate(
        strokeId: _currentStroke!.id,
        points: [point],
      );
    }
  }

  void _onPointerUp(PointerEvent event) {
    if (_currentStroke != null) {
      // Emit stroke end to server
      _socketService.emitStrokeEnd(strokeId: _currentStroke!.id);

      setState(() {
        _strokes.add(_currentStroke!.copyWith(completed: true));
        _currentStroke = null;
      });
    }
  }

  // Pan and zoom gestures
  void _onScaleStart(ScaleStartDetails details) {
    _lastPanPosition = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      // Handle panning
      if (_lastPanPosition != null && details.pointerCount == 2) {
        final delta = details.focalPoint - _lastPanPosition!;
        _canvasOffset += delta;
        _lastPanPosition = details.focalPoint;
      }

      // Handle zooming
      if (details.scale != 1.0) {
        final newScale = (_canvasScale * details.scale).clamp(0.1, 5.0);
        _canvasScale = newScale;
      }
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _lastPanPosition = null;
  }

  void _clearCanvas() {
    setState(() {
      _strokes.clear();
      _remoteStrokes.clear();
    });
    _socketService.emitClearBoard();
  }
}
