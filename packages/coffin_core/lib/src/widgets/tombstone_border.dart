import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../theme/coffin_metrics.dart';

/// A tombstone outline: a half-ellipse arch on top, straight sides and two
/// rounded bottom corners.
///
/// Used as the `shape` of a `ShapeDecoration` so the fill and the glow follow
/// the tombstone outline. Internal to `coffin_core`.
final class TombstoneBorder extends OutlinedBorder {
  /// Creates a tombstone border.
  ///
  /// [archRise] is the vertical radius of the arch and [bottomRadius] is the
  /// radius of the two bottom corners. Both are clamped to the rect when the
  /// path is built, so the arcs never invert.
  const TombstoneBorder({
    super.side = BorderSide.none,
    this.archRise = 140,
    this.bottomRadius = CoffinMetrics.cornerRadius,
  });

  /// Vertical radius of the arch, in logical pixels.
  final double archRise;

  /// Radius of the two bottom corners, in logical pixels.
  final double bottomRadius;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _buildPath(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _buildPath(rect.deflate(side.width));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) {
      return;
    }
    canvas.drawPath(_buildPath(rect.deflate(side.width / 2)), side.toPaint());
  }

  @override
  ShapeBorder scale(double t) => TombstoneBorder(
    side: side.scale(t),
    archRise: archRise * t,
    bottomRadius: bottomRadius * t,
  );

  @override
  TombstoneBorder copyWith({
    BorderSide? side,
    double? archRise,
    double? bottomRadius,
  }) => TombstoneBorder(
    side: side ?? this.side,
    archRise: archRise ?? this.archRise,
    bottomRadius: bottomRadius ?? this.bottomRadius,
  );

  Path _buildPath(Rect rect) {
    final path = Path();
    final w = rect.width;
    final h = rect.height;
    if (!(w > 0) || !(h > 0)) {
      return path;
    }
    final rx = w / 2;
    final br = math.min(bottomRadius, math.min(w / 2, h / 2));
    final ry = math.min(archRise, math.min(rx, h - br));
    path
      ..moveTo(rect.left, rect.top + ry)
      ..arcToPoint(
        Offset(rect.right, rect.top + ry),
        radius: Radius.elliptical(rx, ry),
      )
      ..lineTo(rect.right, rect.bottom - br)
      ..arcToPoint(
        Offset(rect.right - br, rect.bottom),
        radius: Radius.circular(br),
      )
      ..lineTo(rect.left + br, rect.bottom)
      ..arcToPoint(
        Offset(rect.left, rect.bottom - br),
        radius: Radius.circular(br),
      )
      ..close();
    return path;
  }

  @override
  bool operator ==(Object other) =>
      other is TombstoneBorder &&
      other.side == side &&
      other.archRise == archRise &&
      other.bottomRadius == bottomRadius;

  @override
  int get hashCode => Object.hash(side, archRise, bottomRadius);

  @override
  String toString() =>
      'TombstoneBorder($side, archRise: $archRise, '
      'bottomRadius: $bottomRadius)';
}
