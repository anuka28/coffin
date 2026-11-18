import 'package:coffin_core/coffin_core.dart';
import 'package:coffin_core/src/widgets/math/mood_reaction.dart';
import 'package:coffin_core/src/widgets/math/mood_traits.dart';
import 'package:flutter_test/flutter_test.dart' show expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;

import '../support/mood_generators.dart';
import '../support/widget_generators.dart'
    show RunCounter, anyElapsed, anyIntBetween;

const int _numRuns = 300;
final RunCounter _rangeCounter = RunCounter();
final RunCounter _speedCounter = RunCounter();

/// Any of the two reaction moods.
final Generator<GhostMood> _anyReaction = any.simple<GhostMood>(
  generate: (random, size) =>
      random.nextBool() ? GhostMood.fed : GhostMood.rising,
  shrink: (GhostMood mood) sync* {
    if (mood == GhostMood.rising) {
      yield GhostMood.fed;
    }
  },
);

void main() {
  group('MoodReaction ranges property', () {
    _rangeCounter.reset();

    // Feature: ghost-moods, Property 8: Reaction values stay in range and start and end without a jump
    // Validates: Requirements 8.3, 8.4, 8.5, 8.6, 21.7
    Glados3(
      _anyReaction,
      anyElapsed,
      anyProgress,
      ExploreConfig(numRuns: _numRuns),
    ).test('reaction values stay in range and start and end without a jump', (
      mood,
      elapsed,
      progress,
    ) {
      _rangeCounter.increment();
      final String why = 'mood=$mood elapsed=$elapsed progress=$progress';

      // Progress from elapsed time.
      final int duration = MoodReaction.durationMs(mood);
      final double t = MoodReaction.progressAt(mood, elapsed);
      expect(t, inInclusiveRange(0, 1), reason: 'progress range: $why');
      if (elapsed <= 0) {
        expect(t, 0, reason: 'progress at or below 0: $why');
      }
      if (elapsed >= duration) {
        expect(t, 1, reason: 'progress at or above duration: $why');
      }

      // Curves at any progress, NaN included.
      final double scale = MoodReaction.scaleAt(mood, progress);
      final double lift = MoodReaction.liftAt(mood, progress);
      final double opacity = MoodReaction.opacityAt(mood, progress);
      expect(scale.isFinite, isTrue, reason: 'scale finite: $why');
      expect(lift.isFinite, isTrue, reason: 'lift finite: $why');
      expect(opacity.isFinite, isTrue, reason: 'opacity finite: $why');

      final double dead = MoodTraits.of(GhostMood.dead).opacity;
      final double thriving = MoodTraits.of(GhostMood.thriving).opacity;
      if (mood == GhostMood.fed) {
        expect(scale, inInclusiveRange(1.0, 1.10), reason: 'scale: $why');
        expect(lift, inInclusiveRange(0, 6), reason: 'fed lift: $why');
      } else {
        expect(lift, inInclusiveRange(0, 10), reason: 'rising lift: $why');
        expect(opacity, inInclusiveRange(dead, thriving), reason: 'op: $why');
      }

      // Start and end values, and NaN behaving as progress 1.
      expect(MoodReaction.scaleAt(mood, double.nan), 1.0, reason: why);
      expect(MoodReaction.liftAt(mood, double.nan), 0, reason: why);
      expect(MoodReaction.scaleAt(mood, 0), 1.0, reason: why);
      expect(MoodReaction.scaleAt(mood, 1), 1.0, reason: why);
      expect(MoodReaction.liftAt(mood, 0), 0, reason: why);
      expect(MoodReaction.liftAt(mood, 1), 0, reason: why);
      if (mood == GhostMood.fed) {
        expect(MoodReaction.opacityAt(mood, 0), 1.0, reason: why);
        expect(MoodReaction.opacityAt(mood, 1), 1.0, reason: why);
        expect(MoodReaction.opacityAt(mood, double.nan), 1.0, reason: why);
      } else {
        expect(MoodReaction.opacityAt(mood, 0), dead, reason: why);
        expect(MoodReaction.opacityAt(mood, 1), thriving, reason: why);
        expect(MoodReaction.opacityAt(mood, double.nan), thriving, reason: why);
      }
      if (progress.isNaN) {
        expect(scale, MoodReaction.scaleAt(mood, 1), reason: 'NaN: $why');
        expect(lift, MoodReaction.liftAt(mood, 1), reason: 'NaN: $why');
        expect(opacity, MoodReaction.opacityAt(mood, 1), reason: 'NaN: $why');
      }
    });

    test('ran every requested run', () {
      expect(_rangeCounter.runs > 0 && _rangeCounter.runs == _numRuns, isTrue);
    });
  });

  group('MoodReaction speed property', () {
    _speedCounter.reset();

    // Feature: ghost-moods, Property 9: Reactions move no faster than 1.5 times their average speed
    // Validates: Requirements 8.9
    Glados2(
      _anyReaction,
      anyIntBetween(0, 1000),
      ExploreConfig(numRuns: _numRuns),
    ).test('reactions move no faster than 1.5 times their average speed', (
      mood,
      thousandths,
    ) {
      _speedCounter.increment();
      final int duration = MoodReaction.durationMs(mood);
      final double step = 16 / duration;
      final double p = thousandths / 1000 * (1 - step);
      final double q = p + step;
      final String why = 'mood=$mood p=$p q=$q';

      final bool fed = mood == GhostMood.fed;
      // Total travel over the run of each value.
      final double scaleTravel = fed ? 0.20 : 0;
      final double liftTravel = fed ? 12 : 20;
      final double opacityTravel = fed ? 0 : 0.28;

      double limit(double travel) => 1.5 * travel / duration * 16 + 1e-9;

      final double dScale =
          (MoodReaction.scaleAt(mood, q) - MoodReaction.scaleAt(mood, p)).abs();
      final double dLift =
          (MoodReaction.liftAt(mood, q) - MoodReaction.liftAt(mood, p)).abs();
      final double dOpacity =
          (MoodReaction.opacityAt(mood, q) - MoodReaction.opacityAt(mood, p))
              .abs();
      expect(
        dScale,
        lessThanOrEqualTo(limit(scaleTravel)),
        reason: 'scale: $why',
      );
      expect(dLift, lessThanOrEqualTo(limit(liftTravel)), reason: 'lift: $why');
      expect(
        dOpacity,
        lessThanOrEqualTo(limit(opacityTravel)),
        reason: 'opacity: $why',
      );
    });

    test('ran every requested run', () {
      expect(_speedCounter.runs > 0 && _speedCounter.runs == _numRuns, isTrue);
    });
  });
}
