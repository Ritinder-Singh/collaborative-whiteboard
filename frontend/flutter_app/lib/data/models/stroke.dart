import 'dart:ui';

/// Represents a single point in a stroke with pressure and tilt data.
class StrokePoint {
  final double x;
  final double y;
  final double pressure;
  final double tilt;
  final int timestamp;

  const StrokePoint({
    required this.x,
    required this.y,
    this.pressure = 0.5,
    this.tilt = 0.0,
    int? timestamp,
  }) : timestamp = timestamp ?? 0;

  Offset get offset => Offset(x, y);

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'pressure': pressure,
        'tilt': tilt,
        'timestamp': timestamp,
      };

  factory StrokePoint.fromJson(Map<String, dynamic> json) => StrokePoint(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        pressure: (json['pressure'] as num?)?.toDouble() ?? 0.5,
        tilt: (json['tilt'] as num?)?.toDouble() ?? 0.0,
        timestamp: json['timestamp'] as int? ?? 0,
      );

  /// Create from PointerEvent for Apple Pencil/stylus support
  factory StrokePoint.fromPointer({
    required double x,
    required double y,
    double? pressure,
    double? tilt,
  }) =>
      StrokePoint(
        x: x,
        y: y,
        pressure: pressure ?? 0.5,
        tilt: tilt ?? 0.0,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
}

/// Represents a complete drawing stroke.
class Stroke {
  final String id;
  final String? userId;
  final String tool;
  final Color color;
  final double size;
  final String layerId;
  final List<StrokePoint> points;
  final bool completed;

  const Stroke({
    required this.id,
    this.userId,
    this.tool = 'pen',
    this.color = const Color(0xFF000000),
    this.size = 2.0,
    this.layerId = 'default',
    this.points = const [],
    this.completed = false,
  });

  Stroke copyWith({
    String? id,
    String? userId,
    String? tool,
    Color? color,
    double? size,
    String? layerId,
    List<StrokePoint>? points,
    bool? completed,
  }) =>
      Stroke(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        tool: tool ?? this.tool,
        color: color ?? this.color,
        size: size ?? this.size,
        layerId: layerId ?? this.layerId,
        points: points ?? this.points,
        completed: completed ?? this.completed,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'tool': tool,
        'color': '#${color.value.toRadixString(16).padLeft(8, '0')}',
        'size': size,
        'layer_id': layerId,
        'points': points.map((p) => p.toJson()).toList(),
        'completed': completed,
      };

  factory Stroke.fromJson(Map<String, dynamic> json) {
    final colorStr = json['color'] as String? ?? '#FF000000';
    final colorValue = int.parse(
      colorStr.replaceFirst('#', ''),
      radix: 16,
    );

    return Stroke(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      tool: json['tool'] as String? ?? 'pen',
      color: Color(colorValue),
      size: (json['size'] as num?)?.toDouble() ?? 2.0,
      layerId: json['layer_id'] as String? ?? 'default',
      points: (json['points'] as List<dynamic>?)
              ?.map((p) => StrokePoint.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      completed: json['completed'] as bool? ?? false,
    );
  }
}

/// Drawing tool types
enum DrawingTool {
  pen,
  pencil,
  marker,
  eraser,
  select,
  rectangle,
  circle,
  line,
  arrow,
  text,
}

/// Represents the current drawing state
class DrawingState {
  final DrawingTool tool;
  final Color color;
  final double strokeSize;
  final String activeLayerId;
  final Stroke? currentStroke;
  final List<Stroke> strokes;

  const DrawingState({
    this.tool = DrawingTool.pen,
    this.color = const Color(0xFF000000),
    this.strokeSize = 2.0,
    this.activeLayerId = 'default',
    this.currentStroke,
    this.strokes = const [],
  });

  DrawingState copyWith({
    DrawingTool? tool,
    Color? color,
    double? strokeSize,
    String? activeLayerId,
    Stroke? currentStroke,
    List<Stroke>? strokes,
    bool clearCurrentStroke = false,
  }) =>
      DrawingState(
        tool: tool ?? this.tool,
        color: color ?? this.color,
        strokeSize: strokeSize ?? this.strokeSize,
        activeLayerId: activeLayerId ?? this.activeLayerId,
        currentStroke: clearCurrentStroke ? null : (currentStroke ?? this.currentStroke),
        strokes: strokes ?? this.strokes,
      );
}
