import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:collaborative_whiteboard/core/utils/name_generator.dart';
import 'package:collaborative_whiteboard/data/models/stroke.dart';
import 'package:collaborative_whiteboard/data/models/canvas_action.dart';
import 'package:collaborative_whiteboard/data/models/layer.dart';
import 'package:collaborative_whiteboard/data/services/socket_service.dart';
import 'package:collaborative_whiteboard/features/canvas/painters/stroke_painter.dart';
import 'package:collaborative_whiteboard/features/canvas/painters/shape_painter.dart';
import 'package:collaborative_whiteboard/features/canvas/widgets/toolbar.dart';
import 'package:collaborative_whiteboard/features/canvas/widgets/layer_panel.dart';

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
  Color _selectedColor = Colors.white;
  double _strokeSize = 4.0;

  // Canvas state
  List<Stroke> _strokes = [];
  Stroke? _currentStroke;
  Map<String, Stroke> _remoteStrokes = {};
  Map<String, CursorInfo> _remoteCursors = {};

  // Objects state (shapes, text)
  List<CanvasObject> _objects = [];
  CanvasObject? _currentObject;
  CanvasObject? _selectedObject;
  Offset? _objectStartPos;

  // Layers state
  List<CanvasLayer> _layers = [CanvasLayer.defaultLayer()];
  String _activeLayerId = 'default';
  bool _showLayerPanel = false;

  // Undo/Redo
  final ActionHistory _history = ActionHistory();

  // Canvas transformation
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

  // Focus node for keyboard shortcuts
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _socketService = ref.read(socketServiceProvider);
    _connectToServer();
  }

  Future<void> _connectToServer() async {
    const serverUrl = 'http://localhost:8000';

    await _socketService.connect(
      serverUrl: serverUrl,
      userId: _uuid.v4(),
      displayName: NameGenerator.generate(),
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
        final strokesData = data['strokes'] as List<dynamic>? ?? [];
        final loadedStrokes = <Stroke>[];
        for (final s in strokesData) {
          final stroke = Stroke.fromJson(Map<String, dynamic>.from(s));
          if (stroke.completed) {
            loadedStrokes.add(stroke);
          }
        }
        setState(() {
          _strokes = loadedStrokes;
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
        final colorStr = data['color'] as String? ?? '#FFFFFFFF';
        final colorValue = int.parse(
          colorStr.replaceFirst('#', ''),
          radix: 16,
        );

        setState(() {
          _remoteStrokes = Map.from(_remoteStrokes);
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
            _remoteStrokes = Map.from(_remoteStrokes);
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
          _remoteStrokes = Map.from(_remoteStrokes);
          final stroke = _remoteStrokes.remove(strokeId);
          if (stroke != null) {
            _strokes = List.from(_strokes);
            _strokes.add(stroke.copyWith(completed: true));
          }
        });
      }),
    );

    // Remote cursor updates
    _subscriptions.add(
      _socketService.onCursorUpdate.listen((data) {
        final oderId = data['user_id'] as String;
        final displayName = data['display_name'] as String? ?? 'User';
        final x = (data['x'] as num).toDouble();
        final y = (data['y'] as num).toDouble();

        setState(() {
          _remoteCursors = Map.from(_remoteCursors);
          _remoteCursors[oderId] = CursorInfo(
            userId: oderId,
            displayName: displayName,
            x: x,
            y: y,
            color: _getUserColor(oderId),
          );
        });

        Future.delayed(const Duration(seconds: 5), () {
          final cursor = _remoteCursors[oderId];
          if (cursor != null &&
              DateTime.now().difference(cursor.lastUpdate).inSeconds > 5) {
            setState(() {
              _remoteCursors = Map.from(_remoteCursors);
              _remoteCursors.remove(oderId);
            });
          }
        });
      }),
    );

    // Board cleared
    _subscriptions.add(
      _socketService.onBoardCleared.listen((_) {
        setState(() {
          _strokes = [];
          _remoteStrokes = {};
          _objects = [];
          _history.clear();
        });
      }),
    );
  }

  Color _getUserColor(String oderId) {
    final hash = oderId.hashCode;
    return HSLColor.fromAHSL(1.0, (hash % 360).toDouble(), 0.7, 0.5).toColor();
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _focusNode.dispose();
    super.dispose();
  }

  // Undo action
  void _undo() {
    final action = _history.undo();
    if (action == null) return;

    setState(() {
      switch (action.type) {
        case ActionType.addStroke:
          _strokes = _strokes.where((s) => s.id != action.stroke!.id).toList();
          break;
        case ActionType.deleteStroke:
          _strokes = [..._strokes, action.stroke!];
          break;
        case ActionType.addObject:
          _objects = _objects.where((o) => o.id != action.object!.id).toList();
          break;
        case ActionType.updateObject:
          final index = _objects.indexWhere((o) => o.id == action.object!.id);
          if (index >= 0) {
            _objects = List.from(_objects);
            _objects[index] = action.previousState!;
          }
          break;
        case ActionType.deleteObject:
          _objects = [..._objects, action.object!];
          break;
        case ActionType.clearCanvas:
          _strokes = action.clearedStrokes ?? [];
          _objects = action.clearedObjects ?? [];
          break;
      }
    });
  }

  // Redo action
  void _redo() {
    final action = _history.redo();
    if (action == null) return;

    setState(() {
      switch (action.type) {
        case ActionType.addStroke:
          _strokes = [..._strokes, action.stroke!];
          break;
        case ActionType.deleteStroke:
          _strokes = _strokes.where((s) => s.id != action.stroke!.id).toList();
          break;
        case ActionType.addObject:
          _objects = [..._objects, action.object!];
          break;
        case ActionType.updateObject:
          final index = _objects.indexWhere((o) => o.id == action.object!.id);
          if (index >= 0) {
            _objects = List.from(_objects);
            _objects[index] = action.object!;
          }
          break;
        case ActionType.deleteObject:
          _objects = _objects.where((o) => o.id != action.object!.id).toList();
          break;
        case ActionType.clearCanvas:
          _strokes = [];
          _objects = [];
          break;
      }
    });
  }

  // Keyboard shortcuts handler
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final isCtrl = HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;

      if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyZ) {
        if (HardwareKeyboard.instance.isShiftPressed) {
          _redo();
        } else {
          _undo();
        }
        return KeyEventResult.handled;
      }

      if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyY) {
        _redo();
        return KeyEventResult.handled;
      }

      // Delete selected object
      if (event.logicalKey == LogicalKeyboardKey.delete ||
          event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_selectedObject != null) {
          _deleteSelectedObject();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  void _deleteSelectedObject() {
    if (_selectedObject == null) return;

    _history.push(CanvasAction.deleteObject(_selectedObject!));
    setState(() {
      _objects = _objects.where((o) => o.id != _selectedObject!.id).toList();
      _selectedObject = null;
    });
  }

  // Layer management methods
  void _addLayer() {
    final newIndex = _layers.isEmpty ? 0 : _layers.map((l) => l.index).reduce((a, b) => a > b ? a : b) + 1;
    final layerId = _uuid.v4();
    final newLayer = CanvasLayer(
      id: layerId,
      name: 'Layer ${_layers.length + 1}',
      index: newIndex,
    );
    setState(() {
      _layers = [..._layers, newLayer];
      _activeLayerId = layerId;
    });
  }

  void _deleteLayer(String layerId) {
    if (_layers.length <= 1) return; // Keep at least one layer

    setState(() {
      _layers = _layers.where((l) => l.id != layerId).toList();
      // Also remove strokes and objects on this layer
      _strokes = _strokes.where((s) => s.layerId != layerId).toList();
      _objects = _objects.where((o) => o.layerId != layerId).toList();
      // Switch to another layer if active was deleted
      if (_activeLayerId == layerId) {
        _activeLayerId = _layers.first.id;
      }
    });
  }

  void _toggleLayerVisibility(String layerId) {
    setState(() {
      _layers = _layers.map((l) {
        if (l.id == layerId) {
          return l.copyWith(isVisible: !l.isVisible);
        }
        return l;
      }).toList();
    });
  }

  void _toggleLayerLock(String layerId) {
    setState(() {
      _layers = _layers.map((l) {
        if (l.id == layerId) {
          return l.copyWith(isLocked: !l.isLocked);
        }
        return l;
      }).toList();
    });
  }

  void _reorderLayers(int oldIndex, int newIndex) {
    setState(() {
      final sortedLayers = List<CanvasLayer>.from(_layers)
        ..sort((a, b) => b.index.compareTo(a.index));

      final layer = sortedLayers.removeAt(oldIndex);
      sortedLayers.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, layer);

      // Update indices
      _layers = sortedLayers.asMap().entries.map((e) {
        return e.value.copyWith(index: sortedLayers.length - 1 - e.key);
      }).toList();
    });
  }

  void _setLayerOpacity(String layerId, double opacity) {
    setState(() {
      _layers = _layers.map((l) {
        if (l.id == layerId) {
          return l.copyWith(opacity: opacity);
        }
        return l;
      }).toList();
    });
  }

  void _renameLayer(String layerId, String newName) {
    setState(() {
      _layers = _layers.map((l) {
        if (l.id == layerId) {
          return l.copyWith(name: newName);
        }
        return l;
      }).toList();
    });
  }

  bool _isActiveLayerLocked() {
    final activeLayer = _layers.firstWhere(
      (l) => l.id == _activeLayerId,
      orElse: () => CanvasLayer.defaultLayer(),
    );
    return activeLayer.isLocked;
  }

  @override
  Widget build(BuildContext context) {
    // Filter strokes and objects by visible layers
    final visibleLayerIds = _layers
        .where((l) => l.isVisible)
        .map((l) => l.id)
        .toSet();

    final visibleStrokes = _strokes
        .where((s) => visibleLayerIds.contains(s.layerId))
        .toList();

    final visibleObjects = _objects
        .where((o) => visibleLayerIds.contains(o.layerId))
        .toList();

    // Get layer opacities for rendering
    final layerOpacities = Map<String, double>.fromEntries(
      _layers.map((l) => MapEntry(l.id, l.opacity)),
    );

    return Scaffold(
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Column(
          children: [
            // Toolbar
            Row(
              children: [
                Expanded(
                  child: CanvasToolbar(
                    selectedTool: _selectedTool,
                    selectedColor: _selectedColor,
                    strokeSize: _strokeSize,
                    onToolChanged: (tool) {
                      if (_isActiveLayerLocked() && tool != DrawingTool.select) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Active layer is locked'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                        return;
                      }
                      setState(() {
                        _selectedTool = tool;
                        _selectedObject = null;
                      });
                    },
                    onColorChanged: (color) => setState(() => _selectedColor = color),
                    onStrokeSizeChanged: (size) => setState(() => _strokeSize = size),
                    onClearCanvas: _clearCanvas,
                    onUndo: _history.canUndo ? _undo : null,
                    onRedo: _history.canRedo ? _redo : null,
                    canUndo: _history.canUndo,
                    canRedo: _history.canRedo,
                  ),
                ),
                // Layer panel toggle
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.layers,
                      color: _showLayerPanel
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    onPressed: () => setState(() => _showLayerPanel = !_showLayerPanel),
                    tooltip: 'Toggle Layers Panel',
                  ),
                ),
              ],
            ),

            // Canvas and layer panel
            Expanded(
              child: Row(
                children: [
                  // Main canvas
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
                          child: Stack(
                            children: [
                              // Strokes layer
                              CustomPaint(
                                painter: StrokePainter(
                                  strokes: visibleStrokes,
                                  currentStroke: _currentStroke,
                                  remoteStrokes: _remoteStrokes,
                                  canvasOffset: _canvasOffset,
                                  canvasScale: _canvasScale,
                                  layerOpacities: layerOpacities,
                                ),
                                size: Size.infinite,
                              ),
                              // Shapes layer
                              CustomPaint(
                                painter: ShapePainter(
                                  objects: visibleObjects,
                                  currentObject: _currentObject,
                                  selectedObject: _selectedObject,
                                  canvasOffset: _canvasOffset,
                                  canvasScale: _canvasScale,
                                  layerOpacities: layerOpacities,
                                ),
                                size: Size.infinite,
                              ),
                              // Cursors layer
                              CustomPaint(
                                painter: CursorPainter(
                                  cursors: _remoteCursors,
                                  canvasOffset: _canvasOffset,
                                  canvasScale: _canvasScale,
                                ),
                                size: Size.infinite,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Layer panel (conditional)
                  if (_showLayerPanel)
                    LayerPanel(
                      layers: _layers,
                      activeLayerId: _activeLayerId,
                      onLayerSelected: (id) => setState(() => _activeLayerId = id),
                      onLayerVisibilityToggled: _toggleLayerVisibility,
                      onLayerLockToggled: _toggleLayerLock,
                      onLayerDeleted: _deleteLayer,
                      onLayerAdded: _addLayer,
                      onLayerReordered: _reorderLayers,
                      onLayerOpacityChanged: _setLayerOpacity,
                      onLayerRenamed: _renameLayer,
                    ),
                ],
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
      ),
    );
  }

  Offset _screenToCanvas(Offset screenPos) {
    return (screenPos - _canvasOffset) / _canvasScale;
  }

  void _onPointerDown(PointerDownEvent event) {
    final canvasPos = _screenToCanvas(event.localPosition);

    // Check if active layer is locked (allow select tool)
    if (_isActiveLayerLocked() && _selectedTool != DrawingTool.select) {
      return;
    }

    switch (_selectedTool) {
      case DrawingTool.pen:
      case DrawingTool.pencil:
      case DrawingTool.marker:
        _startStroke(event, canvasPos, 'pen');
        break;
      case DrawingTool.eraser:
        _startStroke(event, canvasPos, 'eraser');
        break;
      case DrawingTool.select:
        _handleSelect(canvasPos);
        break;
      case DrawingTool.rectangle:
      case DrawingTool.circle:
      case DrawingTool.line:
      case DrawingTool.arrow:
        _startShape(canvasPos);
        break;
      case DrawingTool.text:
        _addText(canvasPos);
        break;
    }
  }

  void _startStroke(PointerDownEvent event, Offset canvasPos, String tool) {
    // For eraser, check if we hit any strokes immediately
    if (tool == 'eraser') {
      _eraseAtPoint(canvasPos);
      return;
    }

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
        tool: tool,
        color: _selectedColor,
        size: _strokeSize,
        layerId: _activeLayerId,
        points: [point],
      );
    });

    _socketService.emitStrokeStart(
      strokeId: strokeId,
      tool: tool,
      color: '#${_selectedColor.value.toRadixString(16).padLeft(8, '0')}',
      size: _strokeSize,
    );
  }

  // Eraser: remove strokes that are near the eraser point
  void _eraseAtPoint(Offset canvasPos) {
    final eraserRadius = _strokeSize * 2;
    final strokesToRemove = <Stroke>[];

    for (final stroke in _strokes) {
      if (_isStrokeNearPoint(stroke, canvasPos, eraserRadius)) {
        strokesToRemove.add(stroke);
      }
    }

    if (strokesToRemove.isNotEmpty) {
      setState(() {
        for (final stroke in strokesToRemove) {
          _history.push(CanvasAction.deleteStroke(stroke));
          _strokes = _strokes.where((s) => s.id != stroke.id).toList();
        }
      });
    }
  }

  bool _isStrokeNearPoint(Stroke stroke, Offset point, double radius) {
    for (final strokePoint in stroke.points) {
      final distance = (Offset(strokePoint.x, strokePoint.y) - point).distance;
      if (distance < radius + stroke.size / 2) {
        return true;
      }
    }
    return false;
  }

  void _startShape(Offset canvasPos) {
    _objectStartPos = canvasPos;

    String type;
    switch (_selectedTool) {
      case DrawingTool.rectangle:
        type = 'rectangle';
        break;
      case DrawingTool.circle:
        type = 'circle';
        break;
      case DrawingTool.line:
        type = 'line';
        break;
      case DrawingTool.arrow:
        type = 'arrow';
        break;
      default:
        return;
    }

    setState(() {
      _currentObject = CanvasObject(
        id: _uuid.v4(),
        type: type,
        layerId: _activeLayerId,
        x: canvasPos.dx,
        y: canvasPos.dy,
        width: 0,
        height: 0,
        color: _selectedColor.value,
        strokeWidth: _strokeSize,
        x2: canvasPos.dx,
        y2: canvasPos.dy,
      );
    });
  }

  void _handleSelect(Offset canvasPos) {
    // Find object at position
    CanvasObject? hitObject;
    for (final obj in _objects.reversed) {
      if (_isPointInObject(canvasPos, obj)) {
        hitObject = obj;
        break;
      }
    }

    setState(() {
      _selectedObject = hitObject;
      if (hitObject != null) {
        _objectStartPos = canvasPos;
      }
    });
  }

  bool _isPointInObject(Offset point, CanvasObject obj) {
    switch (obj.type) {
      case 'rectangle':
      case 'circle':
        final rect = Rect.fromLTWH(obj.x, obj.y, obj.width, obj.height);
        return rect.inflate(10).contains(point);
      case 'line':
      case 'arrow':
        final start = Offset(obj.x, obj.y);
        final end = Offset(obj.x2 ?? obj.x, obj.y2 ?? obj.y);
        final distance = _pointToLineDistance(point, start, end);
        return distance < 15;
      case 'text':
        final rect = Rect.fromLTWH(obj.x, obj.y, 100, 30);
        return rect.inflate(10).contains(point);
      default:
        return false;
    }
  }

  double _pointToLineDistance(Offset point, Offset lineStart, Offset lineEnd) {
    final dx = lineEnd.dx - lineStart.dx;
    final dy = lineEnd.dy - lineStart.dy;
    final length = (dx * dx + dy * dy);
    if (length == 0) return (point - lineStart).distance;

    var t = ((point.dx - lineStart.dx) * dx + (point.dy - lineStart.dy) * dy) / length;
    t = t.clamp(0.0, 1.0);

    final projection = Offset(lineStart.dx + t * dx, lineStart.dy + t * dy);
    return (point - projection).distance;
  }

  void _addText(Offset canvasPos) {
    showDialog(
      context: context,
      builder: (context) {
        String text = '';
        return AlertDialog(
          title: const Text('Add Text'),
          content: TextField(
            autofocus: true,
            onChanged: (value) => text = value,
            decoration: const InputDecoration(hintText: 'Enter text...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (text.isNotEmpty) {
                  final obj = CanvasObject(
                    id: _uuid.v4(),
                    type: 'text',
                    layerId: _activeLayerId,
                    x: canvasPos.dx,
                    y: canvasPos.dy,
                    color: _selectedColor.value,
                    text: text,
                    fontSize: _strokeSize * 4,
                  );
                  _history.push(CanvasAction.addObject(obj));
                  setState(() {
                    _objects = [..._objects, obj];
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    final canvasPos = _screenToCanvas(event.localPosition);

    // Update cursor position for other users
    _socketService.emitCursorMove(x: canvasPos.dx, y: canvasPos.dy);

    // Handle eraser while dragging
    if (_selectedTool == DrawingTool.eraser) {
      _eraseAtPoint(canvasPos);
      return;
    }

    // Handle stroke drawing
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

      _socketService.emitStrokeUpdate(
        strokeId: _currentStroke!.id,
        points: [point],
      );
    }

    // Handle shape drawing
    if (_currentObject != null && _objectStartPos != null) {
      setState(() {
        if (_currentObject!.type == 'line' || _currentObject!.type == 'arrow') {
          _currentObject = _currentObject!.copyWith(
            x2: canvasPos.dx,
            y2: canvasPos.dy,
          );
        } else {
          final width = canvasPos.dx - _objectStartPos!.dx;
          final height = canvasPos.dy - _objectStartPos!.dy;

          _currentObject = _currentObject!.copyWith(
            x: width >= 0 ? _objectStartPos!.dx : canvasPos.dx,
            y: height >= 0 ? _objectStartPos!.dy : canvasPos.dy,
            width: width.abs(),
            height: height.abs(),
          );
        }
      });
    }

    // Handle object moving
    if (_selectedTool == DrawingTool.select &&
        _selectedObject != null &&
        _objectStartPos != null) {
      final delta = canvasPos - _objectStartPos!;
      _objectStartPos = canvasPos;

      setState(() {
        final index = _objects.indexWhere((o) => o.id == _selectedObject!.id);
        if (index >= 0) {
          _objects = List.from(_objects);
          _objects[index] = _selectedObject!.copyWith(
            x: _selectedObject!.x + delta.dx,
            y: _selectedObject!.y + delta.dy,
            x2: _selectedObject!.x2 != null ? _selectedObject!.x2! + delta.dx : null,
            y2: _selectedObject!.y2 != null ? _selectedObject!.y2! + delta.dy : null,
          );
          _selectedObject = _objects[index];
        }
      });
    }
  }

  void _onPointerUp(PointerEvent event) {
    // Complete stroke
    if (_currentStroke != null) {
      _socketService.emitStrokeEnd(strokeId: _currentStroke!.id);

      final completedStroke = _currentStroke!.copyWith(completed: true);
      _history.push(CanvasAction.addStroke(completedStroke));

      setState(() {
        _strokes = [..._strokes, completedStroke];
        _currentStroke = null;
      });
    }

    // Complete shape
    if (_currentObject != null) {
      // Only add if shape has some size
      if (_currentObject!.width > 5 || _currentObject!.height > 5 ||
          (_currentObject!.type == 'line' || _currentObject!.type == 'arrow')) {
        _history.push(CanvasAction.addObject(_currentObject!));
        setState(() {
          _objects = [..._objects, _currentObject!];
        });
      }
      setState(() {
        _currentObject = null;
        _objectStartPos = null;
      });
    }

    _objectStartPos = null;
  }

  void _onScaleStart(ScaleStartDetails details) {
    _lastPanPosition = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      if (_lastPanPosition != null && details.pointerCount == 2) {
        final delta = details.focalPoint - _lastPanPosition!;
        _canvasOffset += delta;
        _lastPanPosition = details.focalPoint;
      }

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
    _history.push(CanvasAction.clearCanvas(
      strokes: _strokes,
      objects: _objects,
    ));
    setState(() {
      _strokes = [];
      _objects = [];
      _remoteStrokes = {};
      _selectedObject = null;
    });
    _socketService.emitClearBoard();
  }
}
