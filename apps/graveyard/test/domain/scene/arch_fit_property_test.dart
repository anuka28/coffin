// Feature: graveyard-scene, Property 17: Arch fit keeps the line inside the arch
// Validates: Requirements 9.3
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/arch_fit.dart';
import 'package:graveyard/src/domain/scene/arch_fit_result.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

/// Float tolerance on the ellipse equation.
const double _tolerance = 1e-9;

void main() {
  group('Property 17: Arch fit keeps the line inside the arch', () {
    Glados(anyArchInput, ExploreConfig(numRuns: numRuns)).test(
      'upper corners lie inside the arch ellipse and the font stays >= 12',
      (ArchInput input) {
        _counter.increment();
        // The text was measured at a font size equal to its line height.
        final double baseSize = input.lineHeight.toDouble();
        final ArchFitResult result = ArchFit.positionFor(
          archWidth: input.archWidth.toDouble(),
          archRise: input.archRise.toDouble(),
          lineHeight: input.lineHeight.toDouble(),
          textWidth: input.textWidth.toDouble(),
          fontSize: baseSize,
        );

        expect(result.fontSize, greaterThanOrEqualTo(ArchFit.minFontSize));
        expect(result.top.isFinite, isTrue);

        final double rx = input.archWidth / 2;
        final double ry = math.min(input.archRise.toDouble(), rx);
        // Truncated lines are cut to half the arch width.
        final double halfWidth = result.truncated
            ? math.max(0.0, rx / 2 - ArchFit.margin)
            : input.textWidth * (result.fontSize / baseSize) / 2;

        // Ellipse centred on the arch base: x across, y up from the centre.
        final double x = (halfWidth + ArchFit.margin) / rx;
        final double y = (result.top - ry) / ry;
        expect(
          x * x + y * y,
          lessThanOrEqualTo(1 + _tolerance),
          reason:
              'corner outside the arch for $input -> top ${result.top}, '
              'font ${result.fontSize}, truncated ${result.truncated}',
        );
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
