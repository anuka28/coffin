// Feature: graveyard-polish, Property 1: Ground fills at least to the viewport bottom
// Validates: Requirements 2.2, 2.4
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/ground_height.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();
final RunCounter _contentCounter = RunCounter();

/// Float tolerance for the sum of the top and the height.
const double _epsilon = 1e-9;

void main() {
  group('Property 1: Ground fills at least to the viewport bottom', () {
    Glados3(
      anyDoubleBetween(0, 4000),
      anyDoubleBetween(0, 1),
      anyDoubleBetween(0, 4000),
      ExploreConfig(numRuns: numRuns),
    ).test('groundTop + height reaches the viewport bottom', (
      double viewportHeight,
      double fraction,
      double extra,
    ) {
      _counter.increment();
      final double groundTop = viewportHeight * fraction;
      final double contentBottom = groundTop + extra;
      final double height = GroundHeight.of(
        groundTop: groundTop,
        contentBottom: contentBottom,
        viewportHeight: viewportHeight,
      );
      expect(
        groundTop + height,
        greaterThanOrEqualTo(viewportHeight - _epsilon),
      );
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });

  // Feature: graveyard-polish, Property 3: Ground height never shrinks the content area
  // Validates: Requirements 2.3, 3.1
  group('Property 3: Ground height never shrinks the content area', () {
    Glados3(
      anyDoubleBetween(0, 4000),
      anyDoubleBetween(0, 4000),
      anyDoubleBetween(0, 4000),
      ExploreConfig(numRuns: numRuns),
    ).test('height covers the content below the ground top', (
      double groundTop,
      double extra,
      double viewportHeight,
    ) {
      _contentCounter.increment();
      final double contentBottom = groundTop + extra;
      final double height = GroundHeight.of(
        groundTop: groundTop,
        contentBottom: contentBottom,
        viewportHeight: viewportHeight,
      );
      expect(
        height,
        greaterThanOrEqualTo(contentBottom - groundTop - _epsilon),
      );
      expect(height, greaterThanOrEqualTo(0));
    });

    test('ran the configured number of times', () {
      _contentCounter.expectRuns(numRuns);
    });
  });
}
