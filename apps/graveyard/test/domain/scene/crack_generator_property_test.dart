// Feature: graveyard-scene, Property 25: Cracks stay inside the stone, outside the text, and depend on the id only
// Validates: Requirements 7.15, 7.16, 7.17, 7.18, 7.19, 7.20, 7.22, 8.9, 8.10
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/crack.dart';
import 'package:graveyard/src/domain/scene/crack_generator.dart';
import 'package:graveyard/src/domain/scene/crack_point.dart';
import 'package:graveyard/src/domain/scene/keep_out_rect.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

/// Half of the crack stroke width.
const double _halfStroke = 0.75;

/// Samples per segment, excluding the start point.
const int _samples = 8;

List<Crack> _generate(CrackInput input, int dayCount) =>
    CrackGenerator.generate(
      dayCount: dayCount,
      graveId: input.graveId,
      stoneWidth: input.stoneWidth.toDouble(),
      stoneHeight: input.stoneHeight.toDouble(),
      keepOut: input.keepOut,
    );

bool _sameCracks(List<Crack> a, List<Crack> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void main() {
  group('Property 25: Cracks stay inside the stone, outside the text, and '
      'depend on the id only', () {
    Glados(anyCrackInput, ExploreConfig(numRuns: numRuns)).test(
      'no cracks up to 1825 days, 1 to 3 cracks of 3 to 5 points above, '
      'inside the stone and outside the text, same for any older day count',
      (CrackInput input) {
        _counter.increment();
        final double w = input.stoneWidth.toDouble();
        final double h = input.stoneHeight.toDouble();
        final List<Crack> cracks = _generate(input, input.dayCount);

        // Clause 1: age threshold and shape.
        if (input.dayCount <= CrackGenerator.ageThresholdDays) {
          expect(cracks, isEmpty);
        } else {
          expect(cracks.length, inInclusiveRange(1, 3));
          for (final Crack crack in cracks) {
            expect(crack.points.length, inInclusiveRange(3, 5));
          }
        }

        // Clause 2: geometry of every sample on every segment, ends included.
        for (final Crack crack in _generate(input, 1826)) {
          for (int s = 0; s + 1 < crack.points.length; s++) {
            final CrackPoint a = crack.points[s];
            final CrackPoint b = crack.points[s + 1];
            for (int i = 0; i <= _samples; i++) {
              final double t = i / _samples;
              final double x = a.x + (b.x - a.x) * t;
              final double y = a.y + (b.y - a.y) * t;
              expect(x, greaterThanOrEqualTo(CrackGenerator.sideInset));
              expect(x, lessThanOrEqualTo(w - CrackGenerator.sideInset));
              expect(y, lessThanOrEqualTo(h - CrackGenerator.baseInset));
              for (final KeepOutRect r in input.keepOut) {
                final bool inside =
                    x >= r.left - _halfStroke &&
                    x <= r.right + _halfStroke &&
                    y >= r.top - _halfStroke &&
                    y <= r.bottom + _halfStroke;
                expect(inside, isFalse, reason: '($x, $y) touches $r');
              }
              expect(x - _halfStroke, greaterThanOrEqualTo(0));
              expect(x + _halfStroke, lessThanOrEqualTo(w));
              expect(y - _halfStroke, greaterThanOrEqualTo(0));
              expect(y + _halfStroke, lessThanOrEqualTo(h));
            }
          }
        }

        // Clause 3: same arguments, same cracks; day count above the
        // threshold does not matter.
        expect(_sameCracks(_generate(input, input.dayCount), cracks), isTrue);
        final List<Crack> older = _generate(input, 1826);
        expect(_sameCracks(_generate(input, 1826), older), isTrue);
        expect(_sameCracks(_generate(input, 4000), older), isTrue);
        expect(_sameCracks(_generate(input, 1826 + 1000000), older), isTrue);
        if (input.dayCount > CrackGenerator.ageThresholdDays) {
          expect(_sameCracks(cracks, older), isTrue);
        }
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
