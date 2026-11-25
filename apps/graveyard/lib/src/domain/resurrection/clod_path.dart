import 'dart:math' as math;

import 'clod.dart';
import 'clod_frame.dart';

/// Pure function from a [Clod], a Stone_Area size and elapsed milliseconds
/// to a [ClodFrame].
abstract final class ClodPath {
  /// Returns where [clod] is at [elapsedMs] inside a Stone_Area of [width] by
  /// [height].
  ///
  /// The frame is not visible outside `[launchMs, launchMs + flightMs]`.
  /// Inside it, the clod follows a parabolic arc from the ground line up to
  /// its peak and back, leaning sideways by the launch angle. The whole
  /// circle stays inside the Stone_Area. Non-finite or unusable sizes and
  /// clod values give an invisible frame instead of throwing.
  static ClodFrame at({
    required Clod clod,
    required double width,
    required double height,
    required int elapsedMs,
  }) {
    const hidden = ClodFrame(x: 0, y: 0, diameter: 0, visible: false);
    final bool usable =
        width.isFinite &&
        height.isFinite &&
        width > 0 &&
        height > 0 &&
        clod.flightMs > 0 &&
        clod.launchAngleRadians.isFinite &&
        clod.peakHeightFraction.isFinite &&
        clod.sizePx.isFinite &&
        clod.sizePx > 0;
    if (!usable) return hidden;

    final int landMs = clod.launchMs + clod.flightMs;
    if (elapsedMs < clod.launchMs || elapsedMs > landMs) {
      return ClodFrame(x: 0, y: 0, diameter: clod.sizePx, visible: false);
    }

    // Shrink the clod only when the area is smaller than the clod itself.
    final double diameter = math.min(clod.sizePx, math.min(width, height));
    final double radius = diameter / 2;
    final double t = (elapsedMs - clod.launchMs) / clod.flightMs;
    final double peak = clod.peakHeightFraction.clamp(0.0, 1.0);
    final double arcHeight = peak * height;
    final double reach = math.max(0, width / 2 - radius - 1);
    final double dx = reach * math.sin(clod.launchAngleRadians) * t;
    final double dy = -4 * arcHeight * t * (1 - t);
    final double x = (width / 2 + dx).clamp(radius, width - radius);
    final double y = (height + dy).clamp(radius, height - radius);
    return ClodFrame(x: x, y: y, diameter: diameter, visible: true);
  }
}
