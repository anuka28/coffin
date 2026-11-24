// Feature: graveyard-scene, Property 8: Tombstone rows fit the available width
// Validates: Requirements 4.4
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/scene_layout.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 8: Tombstone rows fit the available width', () {
    Glados(anyAvailableWidth, ExploreConfig(numRuns: numRuns)).test(
      'a full row fits the width left after the side padding',
      (int availableWidth) {
        _counter.increment();
        final double width = availableWidth.toDouble();
        final int columns = SceneLayout.columnsFor(width);
        final double tombstone = SceneLayout.tombstoneWidthFor(width, columns);
        final double usable = math.max(0, width - SceneLayout.sidePadding * 2);
        final double rowWidth =
            columns * tombstone + (columns - 1) * SceneLayout.gap;
        final double remaining =
            (usable - SceneLayout.gap * (columns - 1)) / columns;

        expect(tombstone, greaterThanOrEqualTo(0));
        expect(rowWidth, lessThanOrEqualTo(usable + 1e-9));
        if (remaining < SceneLayout.minTombstoneWidth) {
          expect(tombstone, closeTo(math.max(0, remaining), 1e-9));
        } else {
          expect(
            tombstone,
            greaterThanOrEqualTo(SceneLayout.minTombstoneWidth),
          );
          expect(tombstone, lessThanOrEqualTo(SceneLayout.maxTombstoneWidth));
        }
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
