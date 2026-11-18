import 'package:coffin_core/coffin_core.dart';
import 'package:coffin_core/src/widgets/math/ghost_bob.dart';
import 'package:coffin_core/src/widgets/math/mood_bob.dart';
import 'package:coffin_core/src/widgets/math/mood_pose.dart';
import 'package:coffin_core/src/widgets/math/mood_traits.dart';
import 'package:flutter_test/flutter_test.dart' show expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;

import '../support/mood_chain.dart';
import '../support/mood_generators.dart';
import '../support/widget_generators.dart' show RunCounter, anyElapsed;

const int _numRuns = 300;
final RunCounter _bobCounter = RunCounter();
final RunCounter _mixedCounter = RunCounter();

void main() {
  group('MoodBob property', () {
    _bobCounter.reset();
    _mixedCounter.reset();

    // Feature: ghost-moods, Property 2: Mood bob is bounded, periodic and equals GhostBob
    // Validates: Requirements 5.3, 5.4, 5.5, 5.7, 21.4
    Glados2(anyMood, anyElapsed, ExploreConfig(numRuns: _numRuns)).test(
      'offset is bounded, periodic and equals GhostBob',
      (mood, elapsed) {
        _bobCounter.increment();
        final String why = 'mood=$mood elapsed=$elapsed';
        final MoodTraits row = MoodTraits.of(mood);
        final double v = MoodBob.offsetAt(mood, elapsed);

        expect(v.isFinite, isTrue, reason: why);
        expect(
          v,
          inInclusiveRange(-row.bobAmplitude, row.bobAmplitude),
          reason: 'range: $why',
        );

        if (mood == GhostMood.dead) {
          expect(v, 0, reason: 'dead: $why');
        } else {
          final GhostBob bob = GhostBob(
            periodMs: row.bobPeriodMs,
            amplitude: row.bobAmplitude,
          );
          expect(v, bob.offsetAt(elapsed), reason: 'GhostBob: $why');
        }

        expect(
          v,
          MoodBob.offsetAt(mood, elapsed + row.bobPeriodMs),
          reason: 'period: $why',
        );
      },
    );

    test('ran every requested run', () {
      expect(_bobCounter.runs > 0 && _bobCounter.runs == _numRuns, isTrue);
    });

    // Feature: ghost-moods, Property 7: The mixed bob never exceeds the blended amplitude
    // Validates: Requirements 5.4, 7.2, 7.6
    Glados2(anyChain, anyElapsed, ExploreConfig(numRuns: _numRuns)).test(
      'mixed bob never exceeds the blended amplitude',
      (chain, elapsed) {
        _mixedCounter.increment();
        final String why = 'chain=$chain elapsed=$elapsed';
        final MoodPose pose = applyChain(chain);
        final double v = MoodBob.mixedOffsetAt(pose, elapsed);

        expect(v.isFinite, isTrue, reason: why);
        expect(
          v.abs(),
          lessThanOrEqualTo(pose.bobAmplitude + 1e-9),
          reason: 'bound: $why',
        );

        for (final GhostMood mood in GhostMood.values) {
          expect(
            MoodBob.mixedOffsetAt(MoodPose.rest(mood), elapsed),
            MoodBob.offsetAt(mood, elapsed),
            reason: 'rest $mood: $why',
          );
        }
      },
    );

    test('ran every requested run for the mixed bob', () {
      expect(_mixedCounter.runs > 0 && _mixedCounter.runs == _numRuns, isTrue);
    });
  });
}
