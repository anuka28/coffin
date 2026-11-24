import 'package:flutter/rendering.dart';

import '../domain/scene/crack.dart';

/// Draws the cracks of one tombstone as thin stroked polylines.
///
/// Holds no controller, ticker or listenable, so it looks the same with and
/// without reduced motion. The caller passes the [color] (the background
/// color at 70% alpha); the painter has no color of its own.
final class CrackPainter extends CustomPainter {
  /// Creates a painter for [cracks] in [color] with a line of [strokeWidth].
  const CrackPainter({
    required this.cracks,
    required this.color,
    this.strokeWidth = 1.5,
  });

  /// The cracks to draw, in stone coordinates.
  final List<Crack> cracks;

  /// The stroke color.
  final Color color;

  /// The stroke width in logical pixels.
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (cracks.isEmpty) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..color = color;
    for (final crack in cracks) {
      final points = crack.points;
      if (points.length < 2) continue;
      final path = Path()
        ..moveTo(points.first.x.toDouble(), points.first.y.toDouble());
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].x.toDouble(), points[i].y.toDouble());
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(CrackPainter oldDelegate) {
    if (oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.cracks.length != cracks.length) {
      return true;
    }
    for (var i = 0; i < cracks.length; i++) {
      if (oldDelegate.cracks[i] != cracks[i]) return true;
    }
    return false;
  }
}
