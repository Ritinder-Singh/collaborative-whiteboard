import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:collaborative_whiteboard/data/models/canvas_action.dart';

/// Custom painter for rendering shapes (rectangles, circles, lines, arrows, text)
class ShapePainter extends CustomPainter {
  final List<CanvasObject> objects;
  final CanvasObject? currentObject;
  final CanvasObject? selectedObject;
  final Offset canvasOffset;
  final double canvasScale;
  final Map<String, double> layerOpacities;

  ShapePainter({
    required this.objects,
    this.currentObject,
    this.selectedObject,
    this.canvasOffset = Offset.zero,
    this.canvasScale = 1.0,
    this.layerOpacities = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(canvasOffset.dx, canvasOffset.dy);
    canvas.scale(canvasScale);

    // Draw all completed objects
    for (final obj in objects) {
      _drawObject(canvas, obj, isSelected: obj.id == selectedObject?.id);
    }

    // Draw current object being created
    if (currentObject != null) {
      _drawObject(canvas, currentObject!, isPreview: true);
    }

    canvas.restore();
  }

  void _drawObject(Canvas canvas, CanvasObject obj,
      {bool isSelected = false, bool isPreview = false}) {
    // Apply layer opacity
    final layerOpacity = layerOpacities[obj.layerId] ?? 1.0;
    final objColor = Color(obj.color);
    final colorWithLayerOpacity = objColor.withOpacity(objColor.opacity * layerOpacity);

    final paint = Paint()
      ..color = colorWithLayerOpacity
      ..strokeWidth = obj.strokeWidth
      ..style = obj.filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (isPreview) {
      paint.color = paint.color.withOpacity(paint.color.opacity * 0.7);
    }

    switch (obj.type) {
      case 'rectangle':
        _drawRectangle(canvas, obj, paint);
        break;
      case 'circle':
        _drawCircle(canvas, obj, paint);
        break;
      case 'ellipse':
        _drawEllipse(canvas, obj, paint);
        break;
      case 'line':
        _drawLine(canvas, obj, paint);
        break;
      case 'arrow':
        _drawArrow(canvas, obj, paint);
        break;
      case 'text':
        _drawText(canvas, obj);
        break;
    }

    // Draw selection handles
    if (isSelected) {
      _drawSelectionHandles(canvas, obj);
    }
  }

  void _drawRectangle(Canvas canvas, CanvasObject obj, Paint paint) {
    final rect = Rect.fromLTWH(obj.x, obj.y, obj.width, obj.height);

    canvas.save();
    if (obj.rotation != 0) {
      canvas.translate(obj.x + obj.width / 2, obj.y + obj.height / 2);
      canvas.rotate(obj.rotation);
      canvas.translate(-(obj.x + obj.width / 2), -(obj.y + obj.height / 2));
    }

    canvas.drawRect(rect, paint);

    // Draw fill if filled
    if (obj.filled && obj.fillColor != null) {
      final fillPaint = Paint()
        ..color = Color(obj.fillColor!)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, paint); // Draw stroke on top
    }

    canvas.restore();
  }

  void _drawCircle(Canvas canvas, CanvasObject obj, Paint paint) {
    final center = Offset(obj.x + obj.width / 2, obj.y + obj.height / 2);
    final radius = math.min(obj.width, obj.height) / 2;

    if (obj.filled && obj.fillColor != null) {
      final fillPaint = Paint()
        ..color = Color(obj.fillColor!)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, fillPaint);
    }
    canvas.drawCircle(center, radius, paint);
  }

  void _drawEllipse(Canvas canvas, CanvasObject obj, Paint paint) {
    final rect = Rect.fromLTWH(obj.x, obj.y, obj.width, obj.height);

    canvas.save();
    if (obj.rotation != 0) {
      canvas.translate(obj.x + obj.width / 2, obj.y + obj.height / 2);
      canvas.rotate(obj.rotation);
      canvas.translate(-(obj.x + obj.width / 2), -(obj.y + obj.height / 2));
    }

    if (obj.filled && obj.fillColor != null) {
      final fillPaint = Paint()
        ..color = Color(obj.fillColor!)
        ..style = PaintingStyle.fill;
      canvas.drawOval(rect, fillPaint);
    }
    canvas.drawOval(rect, paint);

    canvas.restore();
  }

  void _drawLine(Canvas canvas, CanvasObject obj, Paint paint) {
    final start = Offset(obj.x, obj.y);
    final end = Offset(obj.x2 ?? obj.x + obj.width, obj.y2 ?? obj.y + obj.height);
    canvas.drawLine(start, end, paint);
  }

  void _drawArrow(Canvas canvas, CanvasObject obj, Paint paint) {
    final start = Offset(obj.x, obj.y);
    final end = Offset(obj.x2 ?? obj.x + obj.width, obj.y2 ?? obj.y + obj.height);

    // Draw the main line
    canvas.drawLine(start, end, paint);

    // Calculate arrow head
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    const arrowLength = 15.0;
    const arrowAngle = math.pi / 6; // 30 degrees

    final arrowPoint1 = Offset(
      end.dx - arrowLength * math.cos(angle - arrowAngle),
      end.dy - arrowLength * math.sin(angle - arrowAngle),
    );
    final arrowPoint2 = Offset(
      end.dx - arrowLength * math.cos(angle + arrowAngle),
      end.dy - arrowLength * math.sin(angle + arrowAngle),
    );

    // Draw arrow head
    final arrowPath = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(arrowPoint1.dx, arrowPoint1.dy)
      ..moveTo(end.dx, end.dy)
      ..lineTo(arrowPoint2.dx, arrowPoint2.dy);

    canvas.drawPath(arrowPath, paint);
  }

  void _drawText(Canvas canvas, CanvasObject obj) {
    if (obj.text == null || obj.text!.isEmpty) return;

    final textPainter = TextPainter(
      text: TextSpan(
        text: obj.text,
        style: TextStyle(
          color: Color(obj.color),
          fontSize: obj.fontSize ?? 16,
          fontFamily: obj.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    canvas.save();
    if (obj.rotation != 0) {
      canvas.translate(obj.x, obj.y);
      canvas.rotate(obj.rotation);
      canvas.translate(-obj.x, -obj.y);
    }

    textPainter.paint(canvas, Offset(obj.x, obj.y));
    canvas.restore();
  }

  void _drawSelectionHandles(Canvas canvas, CanvasObject obj) {
    final handlePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const handleSize = 8.0;

    // Get bounding box
    final rect = _getBoundingBox(obj);

    // Draw selection border
    canvas.drawRect(rect, borderPaint);

    // Draw corner handles
    final handles = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
      Offset(rect.center.dx, rect.top), // Top center
      Offset(rect.center.dx, rect.bottom), // Bottom center
      Offset(rect.left, rect.center.dy), // Left center
      Offset(rect.right, rect.center.dy), // Right center
    ];

    for (final handle in handles) {
      canvas.drawRect(
        Rect.fromCenter(
          center: handle,
          width: handleSize,
          height: handleSize,
        ),
        handlePaint,
      );
    }
  }

  Rect _getBoundingBox(CanvasObject obj) {
    switch (obj.type) {
      case 'line':
      case 'arrow':
        final x1 = obj.x;
        final y1 = obj.y;
        final x2 = obj.x2 ?? obj.x + obj.width;
        final y2 = obj.y2 ?? obj.y + obj.height;
        return Rect.fromPoints(Offset(x1, y1), Offset(x2, y2));
      default:
        return Rect.fromLTWH(obj.x, obj.y, obj.width, obj.height);
    }
  }

  @override
  bool shouldRepaint(covariant ShapePainter oldDelegate) {
    return objects != oldDelegate.objects ||
        currentObject != oldDelegate.currentObject ||
        selectedObject != oldDelegate.selectedObject ||
        canvasOffset != oldDelegate.canvasOffset ||
        canvasScale != oldDelegate.canvasScale ||
        layerOpacities != oldDelegate.layerOpacities;
  }
}
