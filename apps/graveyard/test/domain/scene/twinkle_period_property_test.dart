// Feature: graveyard-scene, Property 5: Twinkle is periodic
// Validates: Requirements 2.3
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/twinkle.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

/// Allowed difference between one period apart.
const double _tolerance = 1e-9;

void main() {
  group('Property 5: Twinkle is periodic', () {
    Glados(anyTwinkleInput, ExploreConfig(numRuns: numRuns)).test(
      'opacityAt(t) equals opacityAt(t + period)',
      (TwinkleInput input) {
        _counter.increment();
        final double now = Twinkle.opacityAt(
          phaseMs: input.phaseMs,
          elapsedMs: input.elapsedMs,
          periodMs: input.periodMs,
        );
        final double later = Twinkle.opacityAt(
          phaseMs: input.phaseMs,
          elapsedMs: input.elapsedMs + input.periodMs,
          periodMs: input.periodMs,
        );
        expect((now - later).abs(), lessThanOrEqualTo(_tolerance));
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
