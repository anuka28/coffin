import 'dart:math' as math;

/// Twinkle opacity of a star over time.
abstract final class Twinkle {
  /// Opacity in `[0.25, 1.0]` for a star with [phaseMs] and [periodMs] at
  /// [elapsedMs]: `0.625 + 0.375 * sin(2 * pi * (elapsedMs + phaseMs) /
  /// periodMs)`. The result repeats every [periodMs].
  static double opacityAt({
    required int phaseMs,
    required int elapsedMs,
    required int periodMs,
  }) {
    return 0.625 +
        0.375 * math.sin(2 * math.pi * (elapsedMs + phaseMs) / periodMs);
  }
}
