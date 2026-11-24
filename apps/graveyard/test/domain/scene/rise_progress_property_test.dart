// Feature: graveyard-scene, Property 11: Rise progress stays in range and is monotonic
// Validates: Requirements 5.3
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/rise_progress.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 11: Rise progress stays in range and is monotonic', () {
    Glados2(
      anyIntBetween(-2000, 3000),
      anyIntBetween(-2000, 3000),
      ExploreConfig(numRuns: numRuns),
    ).test('at is in [0, 1], clamped at both ends, and non-decreasing', (
      int a,
      int b,
    ) {
      _counter.increment();
      final int low = a <= b ? a : b;
      final int high = a <= b ? b : a;
      final double atLow = RiseProgress.at(low);
      final double atHigh = RiseProgress.at(high);

      for (final double value in <double>[atLow, atHigh]) {
        expect(value.isFinite, isTrue);
        expect(value, greaterThanOrEqualTo(0.0));
        expect(value, lessThanOrEqualTo(1.0));
      }
      if (low <= 0) {
        expect(atLow, 0.0);
      }
      if (low >= RiseProgress.durationMs) {
        expect(atLow, 1.0);
      }
      if (high >= RiseProgress.durationMs) {
        expect(atHigh, 1.0);
      }
      expect(atLow, lessThanOrEqualTo(atHigh));
    });

    test('at(0) is 0', () {
      expect(RiseProgress.at(0), 0.0);
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
