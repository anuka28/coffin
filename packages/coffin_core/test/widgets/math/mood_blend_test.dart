import 'package:coffin_core/src/widgets/ghost_mood.dart';
import 'package:coffin_core/src/widgets/math/mood_blend.dart';
import 'package:coffin_core/src/widgets/math/mood_pose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoodBlend constants', () {
    test('durations', () {
      expect(MoodBlend.transitionMs, 500);
      expect(MoodBlend.restartMs, 200);
    });
  });

  group('MoodBlend.ease', () {
    // u * u * (3 - 2u): 0.25 -> 0.0625 * 2.5 = 0.15625,
    // 0.5 -> 0.25 * 2 = 0.5, 0.75 -> 0.5625 * 1.5 = 0.84375.
    final Map<double, double> cases = <double, double>{
      0: 0,
      0.25: 0.15625,
      0.5: 0.5,
      0.75: 0.84375,
      1: 1,
      -1: 0,
      2: 1,
      double.nan: 1,
      double.infinity: 1,
      double.negativeInfinity: 0,
    };
    cases.forEach((double u, double expected) {
      test('ease($u) is $expected', () {
        expect(MoodBlend.ease(u), expected);
      });
    });
  });

  group('MoodBlend.progressAt', () {
    test('negative time gives 0', () {
      expect(MoodBlend.progressAt(-10, 500), 0);
    });
    test('zero time gives 0', () {
      expect(MoodBlend.progressAt(0, 500), 0);
    });
    test('half time gives 0.5', () {
      expect(MoodBlend.progressAt(250, 500), 0.5);
    });
    test('full time gives 1', () {
      expect(MoodBlend.progressAt(500, 500), 1);
    });
    test('beyond the duration gives 1', () {
      expect(MoodBlend.progressAt(900, 500), 1);
    });
    test('duration 0 or less gives 1', () {
      expect(MoodBlend.progressAt(0, 0), 1);
      expect(MoodBlend.progressAt(-5, 0), 1);
      expect(MoodBlend.progressAt(100, -1), 1);
    });
  });

  group('MoodBlend.mix thriving to dead', () {
    final MoodPose from = MoodPose.rest(GhostMood.thriving);
    final MoodPose to = MoodPose.rest(GhostMood.dead);

    test('progress 0 and below give exactly from', () {
      expect(MoodBlend.mix(from, to, 0), from);
      expect(MoodBlend.mix(from, to, -1), from);
    });

    test('progress 1, above and NaN give exactly to', () {
      expect(MoodBlend.mix(from, to, 1), to);
      expect(MoodBlend.mix(from, to, 2), to);
      expect(MoodBlend.mix(from, to, double.nan), to);
    });

    test('progress 0.5 is the midpoint', () {
      // Opacity 1.0 -> 0.72 gives 0.86. Lean 0 -> 0.15 gives 0.075.
      // Droop 0 -> 0.10 gives 0.05. Bob amplitude 8 -> 0 gives 4.
      final MoodPose m = MoodBlend.mix(from, to, 0.5);
      expect(m.opacity, closeTo(0.86, 1e-12));
      expect(m.lean, closeTo(0.075, 1e-12));
      expect(m.droop, closeTo(0.05, 1e-12));
      expect(m.scale, 1);
      expect(m.lift, 0);
      expect(m.bobAmplitude, closeTo(4, 1e-12));
      for (int i = 0; i < 7; i++) {
        final double expected =
            (i == GhostMood.thriving.index || i == GhostMood.dead.index)
            ? 0.5
            : 0;
        expect(m.weights[i], expected);
      }
    });

    test('weights sum to 1 across progress values', () {
      for (final double p in <double>[0, 0.1, 0.3, 0.5, 0.77, 0.9, 1]) {
        final double sum = MoodBlend.mix(
          from,
          to,
          p,
        ).weights.fold<double>(0, (double a, double b) => a + b);
        expect(sum, closeTo(1, 1e-9));
      }
    });
  });

  group('MoodBlend.mix identity', () {
    test('a pose mixed with itself is equal', () {
      for (final GhostMood mood in GhostMood.values) {
        final MoodPose p = MoodPose.rest(mood);
        for (final double progress in <double>[0, 0.3, 0.5, 1, -1, 2]) {
          expect(MoodBlend.mix(p, p, progress), p);
        }
      }
    });
  });
}
