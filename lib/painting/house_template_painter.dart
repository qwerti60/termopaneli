import 'package:flutter/material.dart';

/// Рисует упрощённый силуэт «дома» для экрана примерки (**§9 MVP-минимум**, без растровых assets).
class HouseTemplatePainter extends CustomPainter {
  HouseTemplatePainter({required this.variant});

  /// 0 … `HouseTemplatePainter.variantCount - 1`
  final int variant;

  static const int variantCount = 5;

  static String labelFor(int v) {
    switch (v.clamp(0, variantCount - 1)) {
      case 0:
        return 'Двускатный';
      case 1:
        return 'Широкий';
      case 2:
        return 'Узкий';
      case 3:
        return 'Плоская крыша';
      case 4:
      default:
        return 'С выступом';
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFB8D4E8), Color(0xFFE8EEF2)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.42));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.42), sky);

    final Paint ground = Paint()..color = const Color(0xFF9CB38A);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.42, size.width, size.height * 0.58),
      ground,
    );

    final Paint wall = Paint()..color = const Color(0xFF6B6B6B);
    final Paint roof = Paint()..color = const Color(0xFF4A4A4A);

    final double w = size.width;
    final double h = size.height;
    final double baseY = h * 0.72;
    final double wallH = h * 0.22;

    switch (variant.clamp(0, variantCount - 1)) {
      case 0:
        _gableHouse(canvas, w, baseY, wallH, wall, roof, bodyW: w * 0.42);
        break;
      case 1:
        _gableHouse(canvas, w, baseY, wallH, wall, roof, bodyW: w * 0.58);
        break;
      case 2:
        _gableHouse(canvas, w, baseY, wallH * 1.15, wall, roof, bodyW: w * 0.26);
        break;
      case 3:
        _flatRoof(canvas, w, baseY, wallH, wall, roof);
        break;
      case 4:
      default:
        _bumpHouse(canvas, w, baseY, wallH, wall, roof);
        break;
    }
  }

  void _gableHouse(
    Canvas canvas,
    double w,
    double baseY,
    double wallH,
    Paint wall,
    Paint roof, {
    required double bodyW,
  }) {
    final double cx = w / 2;
    final double left = cx - bodyW / 2;
    final double right = cx + bodyW / 2;
    final Path body = Path()
      ..addRect(Rect.fromLTRB(left, baseY - wallH, right, baseY));
    canvas.drawPath(body, wall);

    final Path r = Path()
      ..moveTo(left - bodyW * 0.06, baseY - wallH)
      ..lineTo(cx, baseY - wallH - bodyW * 0.32)
      ..lineTo(right + bodyW * 0.06, baseY - wallH)
      ..close();
    canvas.drawPath(r, roof);
  }

  void _flatRoof(Canvas canvas, double w, double baseY, double wallH, Paint wall, Paint roof) {
    final double bodyW = w * 0.5;
    final double cx = w / 2;
    final double left = cx - bodyW / 2;
    final double right = cx + bodyW / 2;
    canvas.drawRect(Rect.fromLTRB(left, baseY - wallH, right, baseY), wall);
    final double roofH = wallH * 0.12;
    canvas.drawRect(
      Rect.fromLTRB(left - 2, baseY - wallH - roofH, right + 2, baseY - wallH),
      roof,
    );
  }

  void _bumpHouse(Canvas canvas, double w, double baseY, double wallH, Paint wall, Paint roof) {
    final double bodyW = w * 0.38;
    final double cx = w / 2;
    final double left = cx - bodyW / 2;
    final double right = cx + bodyW / 2;
    canvas.drawRect(Rect.fromLTRB(left, baseY - wallH, right, baseY), wall);

    final double bumpW = bodyW * 0.38;
    canvas.drawRect(
      Rect.fromLTRB(right - bumpW * 0.2, baseY - wallH * 0.55, right + bumpW, baseY),
      wall,
    );

    final Path r = Path()
      ..moveTo(left - bodyW * 0.05, baseY - wallH)
      ..lineTo(cx, baseY - wallH - bodyW * 0.28)
      ..lineTo(right + bumpW * 0.4, baseY - wallH)
      ..close();
    canvas.drawPath(r, roof);
  }

  @override
  bool shouldRepaint(covariant HouseTemplatePainter oldDelegate) =>
      oldDelegate.variant != variant;
}
