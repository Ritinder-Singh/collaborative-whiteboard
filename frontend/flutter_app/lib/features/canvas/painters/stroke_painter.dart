import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:collaborative_whiteboard/data/models/stroke.dart';

/// Custom painter for rendering strokes with pressure sensitivity.
class StrokePainter extends CustomPainter {
  final List<Stroke> strokes;
  final Stroke? currentStroke;
  final Map<String, Stroke> remoteStrokes;
  final Offset canvasOffset;
  final double canvasScale;
  final Map<String, double> layerOpacities;

  StrokePainter({
    required this.strokes,
    this.currentStroke,
    this.remoteStrokes = const {},
    this.canvasOffset = Offset.zero,
    this.canvasScale = 1.0,
    this.layerOpacities = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    // Apply canvas transformation for pan/zoom
    canvas.translate(canvasOffset.dx, canvasOffset.dy);
    canvas.scale(canvasScale);

    // Draw completed strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    // Draw remote strokes (from other users)
    for (final stroke in remoteStrokes.values) {
      _drawStroke(canvas, stroke);
    }

    // Draw current stroke being drawn
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!);
    }

    canvas.restore();
  }

  void _drawStroke(Canvas canvas, Stroke stroke) {
    if (stroke.points.isEmpty) return;

    // Apply layer opacity
    final layerOpacity = layerOpacities[stroke.layerId] ?? 1.0;
    final strokeColor = stroke.color.withOpacity(stroke.color.opacity * layerOpacity);

    final paint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Handle eraser
    if (stroke.tool == 'eraser') {
      paint.blendMode = BlendMode.clear;
    }

    // Convert points to perfect_freehand format
    final inputPoints = stroke.points
        .map((p) => PointVector(p.x, p.y, p.pressure))
        .toList();

    if (inputPoints.isEmpty) return;

    // Generate smooth stroke outline using perfect_freehand
    final outlinePoints = getStroke(
      inputPoints,
      options: StrokeOptions(
        size: stroke.size,
        thinning: 0.5,
        smoothing: 0.5,
        streamline: 0.5,
        start: StrokeEndOptions.start(
          taperEnabled: true,
          cap: true,
        ),
        end: StrokeEndOptions.end(
          taperEnabled: true,
          cap: true,
        ),
        simulatePressure: stroke.points.every((p) => p.pressure == 0.5),
      ),
    );

    if (outlinePoints.isEmpty) return;

    // Draw the stroke as a filled path
    final path = Path();

    path.moveTo(outlinePoints.first.dx, outlinePoints.first.dy);

    for (int i = 1; i < outlinePoints.length; i++) {
      path.lineTo(outlinePoints[i].dx, outlinePoints[i].dy);
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant StrokePainter oldDelegate) {
    return strokes != oldDelegate.strokes ||
        currentStroke != oldDelegate.currentStroke ||
        remoteStrokes != oldDelegate.remoteStrokes ||
        canvasOffset != oldDelegate.canvasOffset ||
        canvasScale != oldDelegate.canvasScale ||
        layerOpacities != oldDelegate.layerOpacities;
  }
}

/// Painter for rendering user cursors.
class CursorPainter extends CustomPainter {
  final Map<String, CursorInfo> cursors;
  final Offset canvasOffset;
  final double canvasScale;

  CursorPainter({
    required this.cursors,
    this.canvasOffset = Offset.zero,
    this.canvasScale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(canvasOffset.dx, canvasOffset.dy);
    canvas.scale(canvasScale);

    for (final entry in cursors.entries) {
      final cursor = entry.value;
      _drawCursor(canvas, cursor);
    }

    canvas.restore();
  }

  void _drawCursor(Canvas canvas, CursorInfo cursor) {
    final paint = Paint()
      ..color = cursor.color
      ..style = PaintingStyle.fill;

    // Draw cursor dot
    canvas.drawCircle(
      Offset(cursor.x, cursor.y),
      6,
      paint,
    );

    // Draw user name label
    final textPainter = TextPainter(
      text: TextSpan(
        text: cursor.displayName,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Background for label
    final labelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        cursor.x + 10,
        cursor.y - 8,
        textPainter.width + 12,
        textPainter.height + 6,
      ),
      const Radius.circular(4),
    );

    canvas.drawRRect(labelRect, paint);

    // Draw text
    textPainter.paint(
      canvas,
      Offset(cursor.x + 16, cursor.y - 5),
    );
  }

  @override
  bool shouldRepaint(covariant CursorPainter oldDelegate) {
    return cursors != oldDelegate.cursors ||
        canvasOffset != oldDelegate.canvasOffset ||
        canvasScale != oldDelegate.canvasScale;
  }
}

/// Information about a remote user's cursor.
class CursorInfo {
  final String userId;
  final String displayName;
  final double x;
  final double y;
  final Color color;
  final DateTime lastUpdate;

  CursorInfo({
    required this.userId,
    required this.displayName,
    required this.x,
    required this.y,
    required this.color,
    DateTime? lastUpdate,
  }) : lastUpdate = lastUpdate ?? DateTime.now();

  CursorInfo copyWith({
    double? x,
    double? y,
  }) =>
      CursorInfo(
        userId: userId,
        displayName: displayName,
        x: x ?? this.x,
        y: y ?? this.y,
        color: color,
        lastUpdate: DateTime.now(),
      );
}
