import 'package:flutter/widgets.dart';

/// Обрезка по одной или нескольким замкнутым областям (нормализованные координаты 0…1).
class FacadeMaskClipper extends CustomClipper<Path> {
  FacadeMaskClipper(this.polygons);

  final List<List<Offset>> polygons;

  @override
  Path getClip(Size size) {
    final Path out = Path();
    bool any = false;
    for (final List<Offset> normPoints in polygons) {
      if (normPoints.length < 3) {
        continue;
      }
      any = true;
      final Offset o0 = _toPx(normPoints.first, size);
      out.moveTo(o0.dx, o0.dy);
      for (int i = 1; i < normPoints.length; i++) {
        final Offset o = _toPx(normPoints[i], size);
        out.lineTo(o.dx, o.dy);
      }
      out.close();
    }
    if (!any) {
      return Path()..addRect(Offset.zero & size);
    }
    return out;
  }

  static Offset _toPx(Offset n, Size size) {
    return Offset(n.dx.clamp(0.0, 1.0) * size.width, n.dy.clamp(0.0, 1.0) * size.height);
  }

  @override
  bool shouldReclip(covariant FacadeMaskClipper oldClipper) {
    if (oldClipper.polygons.length != polygons.length) {
      return true;
    }
    for (int pi = 0; pi < polygons.length; pi++) {
      final List<Offset> a = oldClipper.polygons[pi];
      final List<Offset> b = polygons[pi];
      if (a.length != b.length) {
        return true;
      }
      for (int i = 0; i < a.length; i++) {
        if (a[i] != b[i]) {
          return true;
        }
      }
    }
    return false;
  }
}
