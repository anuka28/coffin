import '../ghost_mood.dart';
import 'ghost_bob.dart';
import 'mood_pose.dart';
import 'mood_traits.dart';

/// Pure vertical bob offsets of the ghost for a mood or a blended pose.
abstract final class MoodBob {
  /// One bob per mood, built once from the table. `dead` has none.
  static final List<GhostBob?> _bobs = List<GhostBob?>.unmodifiable(<GhostBob?>[
    for (final GhostMood mood in GhostMood.values)
      mood == GhostMood.dead
          ? null
          : GhostBob(
              periodMs: MoodTraits.of(mood).bobPeriodMs,
              amplitude: MoodTraits.of(mood).bobAmplitude,
            ),
  ]);

  /// Vertical offset in logical pixels of [mood] at [elapsedMs].
  ///
  /// Positive is down. `dead` is always 0. Every other mood returns the
  /// offset of a `GhostBob` with the period and amplitude of its table row.
  static double offsetAt(GhostMood mood, int elapsedMs) {
    final GhostBob? bob = _bobs[mood.index];
    return bob == null ? 0 : bob.offsetAt(elapsedMs);
  }

  /// Vertical offset in logical pixels of a blended [pose] at [elapsedMs].
  ///
  /// The sum over moods of weight times [offsetAt]. Moods with a zero weight
  /// are skipped. The result never exceeds `pose.bobAmplitude`.
  static double mixedOffsetAt(MoodPose pose, int elapsedMs) {
    double sum = 0;
    for (final GhostMood mood in GhostMood.values) {
      final double w = pose.weights[mood.index];
      if (w == 0) {
        continue;
      }
      sum += w * offsetAt(mood, elapsedMs);
    }
    return sum;
  }
}
