// Feature: graveyard-seance, Property 8: Revival_Band is total and monotonic
// Validates: Requirements 3.2, 3.3, 14.9
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/seance/revival_band.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 8: Revival_Band is total and monotonic', () {
    Glados2(anyScore, anyScore, ExploreConfig(numRuns: numRuns)).test(
      'a higher score never gives a lower band, and the band matches the edges',
      (int a, int b) {
        _counter.increment();
        final int low = a < b ? a : b;
        final int high = a < b ? b : a;

        final RevivalBand lowBand = RevivalBand.forScore(low);
        final RevivalBand highBand = RevivalBand.forScore(high);

        expect(highBand.index, greaterThanOrEqualTo(lowBand.index));
        for (final int s in <int>[low, high]) {
          final RevivalBand expected = s <= 39
              ? RevivalBand.restless
              : (s <= 69 ? RevivalBand.stirring : RevivalBand.readyToRise);
          expect(RevivalBand.forScore(s), expected);
        }
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
