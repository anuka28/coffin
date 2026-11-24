// Feature: graveyard-scene, Property 4: Twinkle opacity stays in range
// Validates: Requirements 2.2
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/twinkle.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

/// Float tolerance around the exact bounds.
const double _tolerance = 1e-12;

void main() {
  group('Property 4: Twinkle opacity stays in range', () {
    Glados(anyTwinkleInput, ExploreConfig(numRuns: numRuns)).test(
      'opacityAt is within [0.25, 1.0]',
      (TwinkleInput input) {
        _counter.increment();
        final double opacity = Twinkle.opacityAt(
          phaseMs: input.phaseMs,
          elapsedMs: input.elapsedMs,
          periodMs: input.periodMs,
        );
        expect(opacity.isFinite, isTrue);
        expect(opacity, greaterThanOrEqualTo(0.25 - _tolerance));
        expect(opacity, lessThanOrEqualTo(1.0 + _tolerance));
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
