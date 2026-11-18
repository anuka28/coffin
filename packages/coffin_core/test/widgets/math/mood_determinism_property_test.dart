import 'package:coffin_core/coffin_core.dart';
import 'package:coffin_core/src/widgets/math/mood_blend.dart';
import 'package:coffin_core/src/widgets/math/mood_bob.dart';
import 'package:coffin_core/src/widgets/math/mood_pose.dart';
import 'package:coffin_core/src/widgets/math/mood_reaction.dart';
import 'package:coffin_core/src/widgets/math/mood_traits.dart';
import 'package:flutter_test/flutter_test.dart' show expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;

import '../support/mood_chain.dart';
import '../support/mood_generators.dart';
import '../support/widget_generators.dart' show RunCounter, anyElapsed;

const int _numRuns = 300;
final RunCounter _counter = RunCounter();

/// Equality for doubles that treats NaN as equal to NaN.
bool _same(double a, double b) =>
    identical(a, b) || (a.isNaN && b.isNaN) || a == b;

bool _sameTraits(MoodTraits a, MoodTraits b) =>
    a.eyes == b.eyes &&
    a.mouth == b.mouth &&
    _same(a.lean, b.lean) &&
    _same(a.droop, b.droop) &&
    _same(a.opacity, b.opacity) &&
    a.bobPeriodMs == b.bobPeriodMs &&
    _same(a.bobAmplitude, b.bobAmplitude);

void main() {
  group('Mood determinism property', () {
    _counter.reset();

    // Feature: ghost-moods, Property 11: Pure mood classes are deterministic
    // Validates: Requirements 12.5, 12.6
    Glados3(
      anyChain,
      anyProgress,
      anyElapsed,
      ExploreConfig(numRuns: _numRuns),
    ).test('pure mood classes give equal results and never throw', (
      chain,
      progress,
      elapsed,
    ) {
      _counter.increment();
      final String why = 'chain=$chain progress=$progress elapsed=$elapsed';

      // The chain is built twice from the same arguments.
      final MoodPose poseA = applyChain(chain);
      final MoodPose poseB = applyChain(chain);
      expect(poseA == poseB, isTrue, reason: 'applyChain: $why');

      for (final GhostMood mood in GhostMood.values) {
        expect(
          _sameTraits(MoodTraits.of(mood), MoodTraits.of(mood)),
          isTrue,
          reason: 'traits $mood: $why',
        );

        expect(
          _same(
            MoodBob.offsetAt(mood, elapsed),
            MoodBob.offsetAt(mood, elapsed),
          ),
          isTrue,
          reason: 'offsetAt $mood: $why',
        );

        expect(
          MoodReaction.durationMs(mood),
          MoodReaction.durationMs(mood),
          reason: 'durationMs $mood: $why',
        );
        expect(
          _same(
            MoodReaction.progressAt(mood, elapsed),
            MoodReaction.progressAt(mood, elapsed),
          ),
          isTrue,
          reason: 'progressAt $mood: $why',
        );
        expect(
          _same(
            MoodReaction.scaleAt(mood, progress),
            MoodReaction.scaleAt(mood, progress),
          ),
          isTrue,
          reason: 'scaleAt $mood: $why',
        );
        expect(
          _same(
            MoodReaction.liftAt(mood, progress),
            MoodReaction.liftAt(mood, progress),
          ),
          isTrue,
          reason: 'liftAt $mood: $why',
        );
        expect(
          _same(
            MoodReaction.opacityAt(mood, progress),
            MoodReaction.opacityAt(mood, progress),
          ),
          isTrue,
          reason: 'opacityAt $mood: $why',
        );

        final MoodPose mixA = MoodBlend.mix(
          poseA,
          MoodPose.rest(mood),
          progress,
        );
        final MoodPose mixB = MoodBlend.mix(
          poseB,
          MoodPose.rest(mood),
          progress,
        );
        expect(mixA == mixB, isTrue, reason: 'mix $mood: $why');
      }

      expect(
        _same(MoodBlend.ease(progress), MoodBlend.ease(progress)),
        isTrue,
        reason: 'ease: $why',
      );
      expect(
        _same(
          MoodBlend.progressAt(elapsed, 500),
          MoodBlend.progressAt(elapsed, 500),
        ),
        isTrue,
        reason: 'blend progressAt: $why',
      );
      expect(
        _same(
          MoodBob.mixedOffsetAt(poseA, elapsed),
          MoodBob.mixedOffsetAt(poseB, elapsed),
        ),
        isTrue,
        reason: 'mixedOffsetAt: $why',
      );
    });

    test('ran every requested run', () {
      expect(_counter.runs > 0 && _counter.runs == _numRuns, isTrue);
    });
  });
}
