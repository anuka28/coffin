import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// Paints one ghost: a round head, straight sides and a three-scallop hem,
/// with two eyes.
///
/// The painter takes plain colors and picks nothing itself. It has no mood,
/// expression or state parameter, and it reads no theme or controller.
///
/// The ghost is `0.8` as wide as it is tall (capped by the available width)
/// and centered horizontally. The vertical space `headroom` stays free above
/// and below it, so a [bobOffset] within `[-headroom, headroom]` never moves
/// the ghost out of the box.
class GhostPainter extends CustomPainter {
  /// Creates a ghost painter.
  ///
  /// [bodyColor] fills the body and [eyeColor] fills the eyes. Each shadow in
  /// [glow] is drawn along the ghost outline before the body. [bobOffset]
  /// moves the ghost down (positive) or up, clamped into
  /// `[-headroom, headroom]`, with NaN treated as 0. [repaint] is passed to
  /// [CustomPainter].
  const GhostPainter({
    required this.bodyColor,
    required this.eyeColor,
    this.glow = const <BoxShadow>[],
    this.bobOffset = 0,
    this.headroom = 0,
    super.repaint,
  });

  /// Fill color of the ghost body.
  final Color bodyColor;

  /// Fill color of the two eyes.
  final Color eyeColor;

  /// Shadows drawn along the ghost outline, behind the body.
  final List<BoxShadow> glow;

  /// Vertical offset in logical pixels. Positive is down.
  final double bobOffset;

  /// Vertical space kept free above and below the ghost, in logical pixels.
  final double headroom;

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    if (!width.isFinite || !height.isFinite || !headroom.isFinite) {
      return;
    }
    if (width <= 0 || height <= 0) {
      return;
    }
    final double room = headroom < 0 ? 0 : headroom;
    final double h = height - 2 * room;
    final double w = math.min(width, 0.8 * h);
    if (!h.isFinite || !w.isFinite || h <= 0 || w <= 0) {
      return;
    }
    final double dy = bobOffset.isNaN ? 0 : bobOffset.clamp(-room, room);

    final double cx = width / 2;
    final double left = cx - w / 2;
    final double right = cx + w / 2;
    final double top = room + dy;
    final double bottom = top + h;
    final double scallop = w / 6;

    final Path path = Path()
      ..moveTo(left, top + w / 2)
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, top + w / 2), radius: w / 2),
        math.pi,
        math.pi,
        false,
      )
      ..lineTo(right, bottom - scallop);
    for (int i = 0; i < 3; i++) {
      path.arcTo(
        Rect.fromCircle(
          center: Offset(right - scallop * (2 * i + 1), bottom - scallop),
          radius: scallop,
        ),
        0,
        math.pi,
        false,
      );
    }
    path.close();

    for (final BoxShadow shadow in glow) {
      canvas.drawPath(path.shift(shadow.offset), shadow.toPaint());
    }
    canvas.drawPath(path, Paint()..color = bodyColor);

    final Paint eyePaint = Paint()..color = eyeColor;
    final double eyeRadius = 0.07 * w;
    final double eyeY = top + 0.40 * w;
    canvas.drawCircle(Offset(cx - 0.18 * w, eyeY), eyeRadius, eyePaint);
    canvas.drawCircle(Offset(cx + 0.18 * w, eyeY), eyeRadius, eyePaint);
  }

  @override
  bool shouldRepaint(GhostPainter oldDelegate) {
    return oldDelegate.bodyColor != bodyColor ||
        oldDelegate.eyeColor != eyeColor ||
        oldDelegate.bobOffset != bobOffset ||
        oldDelegate.headroom != headroom ||
        !listEquals(oldDelegate.glow, glow);
  }
}
