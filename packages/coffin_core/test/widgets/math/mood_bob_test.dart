import 'package:coffin_core/src/widgets/ghost_mood.dart';
import 'package:coffin_core/src/widgets/math/ghost_bob.dart';
import 'package:coffin_core/src/widgets/math/mood_blend.dart';
import 'package:coffin_core/src/widgets/math/mood_bob.dart';
import 'package:coffin_core/src/widgets/math/mood_pose.dart';
import 'package:coffin_core/src/widgets/math/mood_traits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final List<GhostMood> bobbing = <GhostMood>[
    for (final GhostMood m in GhostMood.values)
      if (m != GhostMood.dead) m,
  ];

  group('MoodBob.offsetAt', () {
    test('dead is 0 at zero, negative and 2^40', () {
      expect(MoodBob.offsetAt(GhostMood.dead, 0), 0);
      expect(MoodBob.offsetAt(GhostMood.dead, -12345), 0);
      expect(MoodBob.offsetAt(GhostMood.dead, 1099511627776), 0);
    });

    test('bobbing moods equal a GhostBob built from the table', () {
      for (final GhostMood mood in bobbing) {
        final MoodTraits t = MoodTraits.of(mood);
        final GhostBob bob = GhostBob(
          periodMs: t.bobPeriodMs,
          amplitude: t.bobAmplitude,
        );
        final int p = t.bobPeriodMs;
        for (final int time in <int>[0, p ~/ 4, p ~/ 2, p, -777]) {
          expect(MoodBob.offsetAt(mood, time), bob.offsetAt(time));
        }
      }
    });

    test('offset at t equals offset at t plus one period', () {
      for (final GhostMood mood in GhostMood.values) {
        final int p = MoodTraits.of(mood).bobPeriodMs;
        for (final int time in <int>[0, 123, -999, 1099511627776 ~/ 2]) {
          expect(
            MoodBob.offsetAt(mood, time),
            MoodBob.offsetAt(mood, time + p),
          );
        }
      }
    });
  });

  group('MoodBob.mixedOffsetAt', () {
    test('a rest pose equals offsetAt of its mood', () {
      for (final GhostMood mood in GhostMood.values) {
        for (final int time in <int>[0, 700, 2999, -450]) {
          expect(
            MoodBob.mixedOffsetAt(MoodPose.rest(mood), time),
            MoodBob.offsetAt(mood, time),
          );
        }
      }
    });

    test('a half-half mix of thriving and dead gives half the offset', () {
      final MoodPose mixed = MoodBlend.mix(
        MoodPose.rest(GhostMood.thriving),
        MoodPose.rest(GhostMood.dead),
        0.5,
      );
      for (final int time in <int>[0, 500, 1500, 2200, -800]) {
        expect(
          MoodBob.mixedOffsetAt(mixed, time),
          closeTo(MoodBob.offsetAt(GhostMood.thriving, time) / 2, 1e-12),
        );
      }
    });
  });
}
