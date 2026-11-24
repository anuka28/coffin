// Feature: graveyard-scene, Property 7: Column count stays within bounds
// Validates: Requirements 4.3
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/scene_layout.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 7: Column count stays within bounds', () {
    Glados2(
      anyAvailableWidth,
      anyTextScale,
      ExploreConfig(numRuns: numRuns),
    ).test('columnsFor is 1 below 720 and 2..4 at or above', (
      int width,
      double textScale,
    ) {
      _counter.increment();
      // The column count depends on the width only, so the text scale must
      // not matter. Widths are real pixels, so the scale only drives the case.
      expect(textScale, inInclusiveRange(1.0, 2.0));
      final int columns = SceneLayout.columnsFor(width.toDouble());
      expect(columns, inInclusiveRange(1, 4));
      if (width < 720) {
        expect(columns, 1);
      } else {
        expect(columns, inInclusiveRange(2, 4));
      }
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
