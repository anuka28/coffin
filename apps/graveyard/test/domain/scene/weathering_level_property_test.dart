// Feature: graveyard-scene, Property 13: Weathering level stays in range and is monotonic
// Validates: Requirements 7.3, 7.4
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/weathering.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 13: Weathering level stays in range and is monotonic', () {
    Glados3(
      anyDayCount,
      anyDayCount,
      anyMixedGraveId,
      ExploreConfig(numRuns: numRuns),
    ).test('level is in [0, 1] and non-decreasing in the day count', (
      int a,
      int b,
      String id,
    ) {
      _counter.increment();
      final int low = a <= b ? a : b;
      final int high = a <= b ? b : a;
      final double atLow = Weathering.of(dayCount: low, graveId: id).level;
      final double atHigh = Weathering.of(dayCount: high, graveId: id).level;

      for (final double value in <double>[atLow, atHigh]) {
        expect(value.isFinite, isTrue);
        expect(value, greaterThanOrEqualTo(0.0));
        expect(value, lessThanOrEqualTo(1.0));
      }
      expect(atLow, lessThanOrEqualTo(atHigh));
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
