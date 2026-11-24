// Feature: graveyard-scene, Property 10: Layout is injective
// Validates: Requirements 4.6
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/scene_cell.dart';
import 'package:graveyard/src/domain/scene/scene_layout.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 10: Layout is injective', () {
    Glados2(
      anyAvailableWidth,
      anyGraveCount,
      ExploreConfig(numRuns: numRuns),
    ).test('every grave gets exactly one cell and no two share a '
        '(row, column)', (int width, int count) {
      _counter.increment();
      final Set<String> seen = <String>{};
      for (int i = 0; i < count; i++) {
        final SceneCell cell = SceneLayout.cellFor(
          index: i,
          graveCount: count,
          availableWidth: width.toDouble(),
        );
        expect(seen.add('${cell.row},${cell.column}'), isTrue);
      }
      expect(seen.length, count);
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
