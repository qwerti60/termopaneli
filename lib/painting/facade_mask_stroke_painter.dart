import 'package:flutter/material.dart';

/// Контуры: завершённые полигоны + текущая линия обводки.
class FacadeMaskStrokePainter extends CustomPainter {
  FacadeMaskStrokePainter({
    required this.polygons,
    this.currentStroke = const <Offset>[],
    this.currentClosed = false,
    this.polygonColor = const Color(0xFFFFA000),
    this.currentColor = const Color(0xFFE65100),
    this.strokeWidth = 3,
  });

  final List<List<Offset>> polygons;
  final List<Offset> currentStroke;
  final bool currentClosed;
  final Color polygonColor;
  final Color currentColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint polyPaint = Paint()
      ..color = polygonColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final List<Offset> normPoints in polygons) {
      if (normPoints.length < 2) {
        continue;
      }
      final Path path = _openPath(normPoints, size);
      if (normPoints.length >= 3) {
        path.close();
      }
      canvas.drawPath(path, polyPaint);
    }

    if (currentStroke.length >= 2) {
      final Path path = _openPath(currentStroke, size);
      if (currentClosed && currentStroke.length >= 3) {
        path.close();
      }
      final Paint p = Paint()
        ..color = currentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 0.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, p);
    }
  }

  Path _openPath(List<Offset> normPoints, Size size) {
    final Path path = Path();
    final Offset p0 = _px(normPoints.first, size);
    path.moveTo(p0.dx, p0.dy);
    for (int i = 1; i < normPoints.length; i++) {
      final Offset p = _px(normPoints[i], size);
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  Offset _px(Offset n, Size size) {
    return Offset(n.dx.clamp(0.0, 1.0) * size.width, n.dy.clamp(0.0, 1.0) * size.height);
  }

  @override
  bool shouldRepaint(covariant FacadeMaskStrokePainter oldDelegate) {
    if (oldDelegate.currentClosed != currentClosed ||
        oldDelegate.polygonColor != polygonColor ||
        oldDelegate.currentColor != currentColor ||
        oldDelegate.strokeWidth != strokeWidth) {
      return true;
    }
    if (!_samePolygons(oldDelegate.polygons, polygons)) {
      return true;
    }
    if (oldDelegate.currentStroke.length != currentStroke.length) {
      return true;
    }
    for (int i = 0; i < currentStroke.length; i++) {
      if (oldDelegate.currentStroke[i] != currentStroke[i]) {
        return true;
      }
    }
    return false;
  }

  bool _samePolygons(List<List<Offset>> a, List<List<Offset>> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int pi = 0; pi < a.length; pi++) {
      if (a[pi].length != b[pi].length) {
        return false;
      }
      for (int i = 0; i < a[pi].length; i++) {
        if (a[pi][i] != b[pi][i]) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  bool shouldRebuildSemantics(covariant FacadeMaskStrokePainter oldDelegate) => false;
}
