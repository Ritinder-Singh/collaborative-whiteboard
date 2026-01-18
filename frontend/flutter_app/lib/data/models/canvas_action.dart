import 'package:collaborative_whiteboard/data/models/stroke.dart';

/// Types of actions that can be undone/redone
enum ActionType {
  addStroke,
  deleteStroke,
  addObject,
  updateObject,
  deleteObject,
  clearCanvas,
}

/// Represents a single undoable action on the canvas
class CanvasAction {
  final String id;
  final ActionType type;
  final DateTime timestamp;

  // For stroke actions
  final Stroke? stroke;

  // For object actions
  final CanvasObject? object;
  final CanvasObject? previousState; // For update actions

  // For clear canvas
  final List<Stroke>? clearedStrokes;
  final List<CanvasObject>? clearedObjects;

  CanvasAction({
    required this.id,
    required this.type,
    DateTime? timestamp,
    this.stroke,
    this.object,
    this.previousState,
    this.clearedStrokes,
    this.clearedObjects,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create an action for adding a stroke
  factory CanvasAction.addStroke(Stroke stroke) => CanvasAction(
        id: stroke.id,
        type: ActionType.addStroke,
        stroke: stroke,
      );

  /// Create an action for deleting a stroke
  factory CanvasAction.deleteStroke(Stroke stroke) => CanvasAction(
        id: stroke.id,
        type: ActionType.deleteStroke,
        stroke: stroke,
      );

  /// Create an action for adding an object
  factory CanvasAction.addObject(CanvasObject object) => CanvasAction(
        id: object.id,
        type: ActionType.addObject,
        object: object,
      );

  /// Create an action for updating an object
  factory CanvasAction.updateObject(
    CanvasObject newState,
    CanvasObject previousState,
  ) =>
      CanvasAction(
        id: newState.id,
        type: ActionType.updateObject,
        object: newState,
        previousState: previousState,
      );

  /// Create an action for deleting an object
  factory CanvasAction.deleteObject(CanvasObject object) => CanvasAction(
        id: object.id,
        type: ActionType.deleteObject,
        object: object,
      );

  /// Create an action for clearing the canvas
  factory CanvasAction.clearCanvas({
    required List<Stroke> strokes,
    required List<CanvasObject> objects,
  }) =>
      CanvasAction(
        id: 'clear-${DateTime.now().millisecondsSinceEpoch}',
        type: ActionType.clearCanvas,
        clearedStrokes: List.from(strokes),
        clearedObjects: List.from(objects),
      );
}

/// Represents a canvas object (shape, text, image, etc.)
class CanvasObject {
  final String id;
  final String type; // 'rectangle', 'circle', 'line', 'arrow', 'text'
  final String layerId;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final int color;
  final double strokeWidth;
  final bool filled;
  final int? fillColor;
  final String? text;
  final double? fontSize;
  final String? fontFamily;

  // For lines and arrows
  final double? x2;
  final double? y2;

  const CanvasObject({
    required this.id,
    required this.type,
    this.layerId = 'default',
    required this.x,
    required this.y,
    this.width = 0,
    this.height = 0,
    this.rotation = 0,
    this.color = 0xFFFFFFFF,
    this.strokeWidth = 2,
    this.filled = false,
    this.fillColor,
    this.text,
    this.fontSize,
    this.fontFamily,
    this.x2,
    this.y2,
  });

  CanvasObject copyWith({
    String? id,
    String? type,
    String? layerId,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    int? color,
    double? strokeWidth,
    bool? filled,
    int? fillColor,
    String? text,
    double? fontSize,
    String? fontFamily,
    double? x2,
    double? y2,
  }) =>
      CanvasObject(
        id: id ?? this.id,
        type: type ?? this.type,
        layerId: layerId ?? this.layerId,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        rotation: rotation ?? this.rotation,
        color: color ?? this.color,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        filled: filled ?? this.filled,
        fillColor: fillColor ?? this.fillColor,
        text: text ?? this.text,
        fontSize: fontSize ?? this.fontSize,
        fontFamily: fontFamily ?? this.fontFamily,
        x2: x2 ?? this.x2,
        y2: y2 ?? this.y2,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'layer_id': layerId,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'rotation': rotation,
        'color': '#${color.toRadixString(16).padLeft(8, '0')}',
        'stroke_width': strokeWidth,
        'filled': filled,
        'fill_color': fillColor != null
            ? '#${fillColor!.toRadixString(16).padLeft(8, '0')}'
            : null,
        'text': text,
        'font_size': fontSize,
        'font_family': fontFamily,
        'x2': x2,
        'y2': y2,
      };

  factory CanvasObject.fromJson(Map<String, dynamic> json) {
    final colorStr = json['color'] as String? ?? '#FFFFFFFF';
    final colorValue = int.parse(colorStr.replaceFirst('#', ''), radix: 16);

    final fillColorStr = json['fill_color'] as String?;
    final fillColorValue = fillColorStr != null
        ? int.parse(fillColorStr.replaceFirst('#', ''), radix: 16)
        : null;

    return CanvasObject(
      id: json['id'] as String,
      type: json['type'] as String,
      layerId: json['layer_id'] as String? ?? 'default',
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num?)?.toDouble() ?? 0,
      height: (json['height'] as num?)?.toDouble() ?? 0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      color: colorValue,
      strokeWidth: (json['stroke_width'] as num?)?.toDouble() ?? 2,
      filled: json['filled'] as bool? ?? false,
      fillColor: fillColorValue,
      text: json['text'] as String?,
      fontSize: (json['font_size'] as num?)?.toDouble(),
      fontFamily: json['font_family'] as String?,
      x2: (json['x2'] as num?)?.toDouble(),
      y2: (json['y2'] as num?)?.toDouble(),
    );
  }
}

/// Manages undo/redo history
class ActionHistory {
  final List<CanvasAction> _undoStack = [];
  final List<CanvasAction> _redoStack = [];
  final int maxHistorySize;

  ActionHistory({this.maxHistorySize = 100});

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  int get undoCount => _undoStack.length;
  int get redoCount => _redoStack.length;

  /// Add a new action to history
  void push(CanvasAction action) {
    _undoStack.add(action);
    _redoStack.clear(); // Clear redo stack on new action

    // Limit history size
    while (_undoStack.length > maxHistorySize) {
      _undoStack.removeAt(0);
    }
  }

  /// Pop the last action for undo
  CanvasAction? undo() {
    if (_undoStack.isEmpty) return null;
    final action = _undoStack.removeLast();
    _redoStack.add(action);
    return action;
  }

  /// Pop from redo stack
  CanvasAction? redo() {
    if (_redoStack.isEmpty) return null;
    final action = _redoStack.removeLast();
    _undoStack.add(action);
    return action;
  }

  /// Clear all history
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
