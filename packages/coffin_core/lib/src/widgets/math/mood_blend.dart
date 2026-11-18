import 'mood_pose.dart';

/// Pure blending of ghost poses: easing, progress and the pose mix.
///
/// Every mood transition, reaction and interruption is a [mix] between two
/// poses, so a blend that starts from the currently shown pose never jumps.
abstract final class MoodBlend {
  /// Duration in milliseconds of a blend between two moods.
  static const int transitionMs = 500;

  /// Duration in milliseconds of a blend that restarts a reaction.
  static const int restartMs = 200;

  /// Smoothstep easing of [u].
  ///
  /// [u] is clamped into 0 to 1 (below 0 gives 0, above 1 gives 1, NaN gives
  /// 1), then mapped through `u * u * (3 - 2 * u)`. The curve is monotonic,
  /// maps 0 to 0 and 1 to 1, and has a peak slope of 1.5.
  static double ease(double u) {
    final double c = u.isNaN ? 1 : (u < 0 ? 0 : (u > 1 ? 1 : u));
    return c * c * (3 - 2 * c);
  }

  /// Linear progress from 0 to 1 of a blend that started [sinceStartMs] ago
  /// and lasts [durationMs].
  ///
  /// A negative time gives 0. A [durationMs] of 0 or less gives 1.
  static double progressAt(int sinceStartMs, int durationMs) {
    if (durationMs <= 0) {
      return 1;
    }
    if (sinceStartMs <= 0) {
      return 0;
    }
    final double p = sinceStartMs / durationMs;
    return p > 1 ? 1 : p;
  }

  /// Mixes [from] into [to] at [progress].
  ///
  /// With `e = ease(progress)`, each number and each weight is
  /// `from + (to - from) * e`. The result is exactly [from] when `e` is 0 and
  /// exactly [to] when `e` is 1, and every value stays between its two
  /// endpoint values.
  static MoodPose mix(MoodPose from, MoodPose to, double progress) {
    final double e = ease(progress);
    final int count = from.weights.length;
    return MoodPose(
      weights: List<double>.unmodifiable(<double>[
        for (int i = 0; i < count; i++)
          _lerp(from.weights[i], to.weights[i], e),
      ]),
      opacity: _lerp(from.opacity, to.opacity, e),
      lean: _lerp(from.lean, to.lean, e),
      droop: _lerp(from.droop, to.droop, e),
      scale: _lerp(from.scale, to.scale, e),
      lift: _lerp(from.lift, to.lift, e),
      bobAmplitude: _lerp(from.bobAmplitude, to.bobAmplitude, e),
    );
  }

  static double _lerp(double a, double b, double e) {
    if (e == 0) {
      return a;
    }
    if (e == 1) {
      return b;
    }
    final double v = a + (b - a) * e;
    final double lo = a < b ? a : b;
    final double hi = a < b ? b : a;
    return v < lo ? lo : (v > hi ? hi : v);
  }
}
