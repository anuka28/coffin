import 'dart:math' as math;

/// Progress curve of a new tombstone rising from the ground.
abstract final class RiseProgress {
  /// Length of the rise, in milliseconds.
  static const int durationMs = 600;

  /// Returns the eased progress from 0 to 1 after [elapsedMs] milliseconds.
  ///
  /// Uses an ease-in-out cubic curve. Values outside `[0, durationMs]` are
  /// clamped.
  static double at(int elapsedMs) {
    final t = (elapsedMs / durationMs).clamp(0.0, 1.0).toDouble();
    return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
  }
}
