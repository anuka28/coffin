import '../ghost_mood.dart';
import 'mood_blend.dart';
import 'mood_traits.dart';

/// Pure curves of the two reaction moods, `fed` and `rising`.
///
/// A reaction is a short run driven by elapsed time. Progress goes from 0 to 1
/// and the curves return the scale, lift and opacity at that progress. Steady
/// moods have no reaction: scale 1, lift 0, their own opacity and duration 0.
abstract final class MoodReaction {
  /// Duration in milliseconds of the `fed` reaction.
  static const int fedDurationMs = 900;

  /// Duration in milliseconds of the `rising` reaction.
  static const int risingDurationMs = 2200;

  /// Whether [mood] is a reaction mood (`fed` or `rising`).
  static bool isReaction(GhostMood mood) {
    return mood == GhostMood.fed || mood == GhostMood.rising;
  }

  /// Duration in milliseconds of the reaction of [mood].
  ///
  /// `fed` is 900, `rising` is 2200 and every steady mood is 0.
  static int durationMs(GhostMood mood) {
    switch (mood) {
      case GhostMood.fed:
        return fedDurationMs;
      case GhostMood.rising:
        return risingDurationMs;
      case GhostMood.thriving:
      case GhostMood.content:
      case GhostMood.hungry:
      case GhostMood.fading:
      case GhostMood.dead:
        return 0;
    }
  }

  /// Linear progress from 0 to 1 of a reaction of [mood] that started
  /// [elapsedMs] ago.
  ///
  /// A negative time gives 0. A time at or above the duration gives 1. A
  /// mood with duration 0 gives 1.
  static double progressAt(GhostMood mood, int elapsedMs) {
    final int duration = durationMs(mood);
    if (duration <= 0) {
      return 1;
    }
    if (elapsedMs < 0) {
      return 0;
    }
    if (elapsedMs >= duration) {
      return 1;
    }
    return elapsedMs / duration;
  }

  /// Scale of [mood] at progress [p].
  ///
  /// `fed` goes from 1.0 up to 1.10 and back. Every other mood is 1.
  static double scaleAt(GhostMood mood, double p) {
    if (mood != GhostMood.fed) {
      return 1;
    }
    return 1 + (MoodTraits.fedMaxScale - 1) * _bump(p);
  }

  /// Upward lift in logical pixels of [mood] at progress [p].
  ///
  /// `fed` goes from 0 up to 6 and back, `rising` from 0 up to 10 and back.
  /// Every other mood is 0.
  static double liftAt(GhostMood mood, double p) {
    switch (mood) {
      case GhostMood.fed:
        return MoodTraits.fedMaxLift * _bump(p);
      case GhostMood.rising:
        return MoodTraits.risingMaxLift * _bump(p);
      case GhostMood.thriving:
      case GhostMood.content:
      case GhostMood.hungry:
      case GhostMood.fading:
      case GhostMood.dead:
        return 0;
    }
  }

  /// Body opacity of [mood] at progress [p].
  ///
  /// `fed` is 1.0. `rising` eases from the opacity of `dead` to the opacity of
  /// `thriving`. A steady mood returns its own table opacity.
  static double opacityAt(GhostMood mood, double p) {
    if (mood == GhostMood.rising) {
      final double from = MoodTraits.of(GhostMood.dead).opacity;
      final double to = MoodTraits.of(GhostMood.thriving).opacity;
      return from + (to - from) * MoodBlend.ease(p);
    }
    return MoodTraits.of(mood).opacity;
  }

  /// Envelope that rises from 0 to 1 at the middle and returns to 0.
  static double _bump(double p) {
    final double c = p.isNaN ? 1 : (p < 0 ? 0 : (p > 1 ? 1 : p));
    return c <= 0.5 ? MoodBlend.ease(2 * c) : MoodBlend.ease(2 - 2 * c);
  }
}
