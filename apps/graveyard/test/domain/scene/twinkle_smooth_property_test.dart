// Feature: graveyard-scene, Property 6: Twinkle has no hard flicker
// Validates: Requirements 2.4
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/twinkle.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

/// Largest allowed opacity change over 100 ms, plus float tolerance.
const double _maxStep = 0.15;
const double _tolerance = 1e-9;

void main() {
  group('Property 6: Twinkle has no hard flicker', () {
    Glados(
      anyTwinkleInput,
      ExploreConfig(numRuns: numRuns),
    ).test('opacity changes by at most 0.15 over 100 ms', (TwinkleInput input) {
      _counter.increment();
      final double before = Twinkle.opacityAt(
        phaseMs: input.phaseMs,
        elapsedMs: input.elapsedMs,
        periodMs: input.periodMs,
      );
      final double after = Twinkle.opacityAt(
        phaseMs: input.phaseMs,
        elapsedMs: input.elapsedMs + 100,
        periodMs: input.periodMs,
      );
      expect((after - before).abs(), lessThanOrEqualTo(_maxStep + _tolerance));
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
