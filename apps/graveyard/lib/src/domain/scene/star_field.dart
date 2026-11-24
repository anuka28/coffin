import 'dart:math' as math;

import 'star.dart';

/// Deterministic star layout for the night sky.
abstract final class StarField {
  /// Fraction of the height above which stars may appear (the ground line).
  static const double skyFraction = 0.66;

  /// Clearance between a star and the moon circle, in logical pixels.
  static const double moonMargin = 4;

  /// Maximum rejection-sampling attempts per star.
  static const int maxAttempts = 200;

  /// Generates the stars for a sky of [width] by [height].
  ///
  /// The same arguments always give the same list. Every star lies inside the
  /// width, at or above [skyFraction] of the height, and outside the moon
  /// circle ([moonCx], [moonCy], [moonRadius]) plus a 4 px margin. The count
  /// grows with the area, from 12 to 60. A size of 0 or less gives an empty
  /// list.
  static List<Star> generate({
    required int seed,
    required double width,
    required double height,
    required double moonCx,
    required double moonCy,
    required double moonRadius,
  }) {
    if (!(width > 0) || !(height > 0)) return const <Star>[];
    final random = math.Random(seed);
    final count = (12 + (width * height / 1400).round()).clamp(12, 60);
    final maxY = height * skyFraction;
    final clearance = moonRadius + moonMargin;

    double distance(double x, double y) =>
        math.sqrt((x - moonCx) * (x - moonCx) + (y - moonCy) * (y - moonCy));

    final stars = <Star>[];
    for (var i = 0; i < count; i++) {
      double? x;
      double? y;
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        final cx = random.nextDouble() * width;
        final cy = random.nextDouble() * maxY;
        if (distance(cx, cy) >= clearance) {
          x = cx;
          y = cy;
          break;
        }
      }
      if (x == null || y == null) {
        // Deterministic fallback: scan a low-discrepancy sequence and keep the
        // first point outside the moon, or the farthest one when none is.
        var bestX = 0.0;
        var bestY = 0.0;
        var bestDistance = -1.0;
        for (var j = 0; j < maxAttempts; j++) {
          final fx =
              (((i + 1) * 0.61803398875 + j * 0.41421356237) % 1) * width;
          final fy = (((i + 1) * 0.32471795724 + j * 0.75487766625) % 1) * maxY;
          final d = distance(fx, fy);
          if (d > bestDistance) {
            bestDistance = d;
            bestX = fx;
            bestY = fy;
          }
          if (d >= clearance) break;
        }
        x = bestX;
        y = bestY;
      }
      final radius = 1 + random.nextDouble() * 1.5;
      final periodMs = 3000 + random.nextInt(5000);
      final phaseMs = random.nextInt(periodMs);
      stars.add(
        Star(
          dx: x,
          dy: y,
          radius: radius,
          phaseMs: phaseMs,
          periodMs: periodMs,
        ),
      );
    }
    return List<Star>.unmodifiable(stars);
  }
}
