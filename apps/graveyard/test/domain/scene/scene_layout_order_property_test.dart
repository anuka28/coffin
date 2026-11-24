// Feature: graveyard-scene, Property 9: Layout preserves list order
// Validates: Requirements 4.5
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/scene_cell.dart';
import 'package:graveyard/src/domain/scene/scene_layout.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 9: Layout preserves list order', () {
    Glados2(
      anyAvailableWidth,
      anyGraveCount,
      ExploreConfig(numRuns: numRuns),
    ).test('index i sits at row i ~/ columns and column i % columns, '
        'reading left to right then top to bottom', (int width, int count) {
      _counter.increment();
      final double available = width.toDouble();
      final int columns = SceneLayout.columnsFor(available);
      SceneCell? previous;
      for (int i = 0; i < count; i++) {
        final SceneCell cell = SceneLayout.cellFor(
          index: i,
          graveCount: count,
          availableWidth: available,
        );
        expect(cell.row, i ~/ columns);
        expect(cell.column, i % columns);
        if (previous != null) {
          final bool nonDecreasing =
              cell.row > previous.row ||
              (cell.row == previous.row && cell.column > previous.column);
          expect(nonDecreasing, isTrue);
        }
        previous = cell;
      }
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
