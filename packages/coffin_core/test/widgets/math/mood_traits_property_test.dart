import 'package:coffin_core/coffin_core.dart';
import 'package:coffin_core/src/widgets/math/mood_traits.dart';
import 'package:flutter_test/flutter_test.dart' show expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;

import '../support/mood_generators.dart';
import '../support/widget_generators.dart' show RunCounter;

const int _numRuns = 300;
final RunCounter _tableCounter = RunCounter();

/// The steady moods in table order, from most alive to dead.
const List<GhostMood> _steady = <GhostMood>[
  GhostMood.thriving,
  GhostMood.content,
  GhostMood.hungry,
  GhostMood.fading,
  GhostMood.dead,
];

void main() {
  group('MoodTraits property', () {
    _tableCounter.reset();

    // Feature: ghost-moods, Property 1: The mood table is ordered, in range and distinct
    // Validates: Requirements 3.2, 4.1, 4.2, 4.5, 5.1, 5.2, 5.6, 21.8
    Glados2(anyMood, anyMood, ExploreConfig(numRuns: _numRuns)).test(
      'table is ordered, in range and distinct',
      (a, b) {
        _tableCounter.increment();
        final String why = 'a=$a b=$b';
        final MoodTraits ra = MoodTraits.of(a);
        final MoodTraits rb = MoodTraits.of(b);

        // Distinct: two different moods differ in a face or pose number.
        if (a != b) {
          final bool differs =
              ra.eyes != rb.eyes ||
              ra.mouth != rb.mouth ||
              ra.lean != rb.lean ||
              ra.droop != rb.droop;
          expect(differs, isTrue, reason: 'rows are not distinct: $why');
        }

        // Ordered: earlier steady moods are brighter, and (while bobbing)
        // faster and wider.
        final int ia = _steady.indexOf(a);
        final int ib = _steady.indexOf(b);
        if (ia >= 0 && ib >= 0 && ia < ib) {
          expect(ra.opacity > rb.opacity, isTrue, reason: 'opacity: $why');
          if (ib <= _steady.indexOf(GhostMood.fading)) {
            expect(
              ra.bobPeriodMs < rb.bobPeriodMs,
              isTrue,
              reason: 'period: $why',
            );
            expect(
              ra.bobAmplitude > rb.bobAmplitude,
              isTrue,
              reason: 'amplitude: $why',
            );
          }
        }

        // In range, for both moods.
        for (final GhostMood mood in <GhostMood>[a, b]) {
          final MoodTraits row = MoodTraits.of(mood);
          expect(
            row.opacity,
            inInclusiveRange(0.72, 1.00),
            reason: 'opacity range: $mood',
          );
          if (mood != GhostMood.dead) {
            expect(
              row.bobPeriodMs,
              inInclusiveRange(2500, 5000),
              reason: 'period range: $mood',
            );
            expect(
              row.bobAmplitude,
              inInclusiveRange(2, 10),
              reason: 'amplitude range: $mood',
            );
          }
        }
        expect(MoodTraits.of(GhostMood.fed).opacity, 1.00, reason: why);
        expect(
          MoodTraits.of(GhostMood.rising).opacity,
          MoodTraits.of(GhostMood.thriving).opacity,
          reason: why,
        );
      },
    );

    test('ran every requested run', () {
      expect(_tableCounter.runs > 0 && _tableCounter.runs == _numRuns, isTrue);
    });
  });
}
