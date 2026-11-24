// Feature: graveyard-scene, Property 12: New-grave diff is a set difference
// Validates: Requirements 5.12
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/new_grave_ids.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 12: New-grave diff is a set difference', () {
    Glados2(anyIdList, anyIdList, ExploreConfig(numRuns: numRuns)).test(
      'returns exactly the ids of next absent from previous, in next '
      'order, and diff of a list with itself is empty',
      (List<String> previous, List<String> next) {
        _counter.increment();
        final List<String> result = NewGraveIds.diff(
          previous: previous,
          next: next,
        );
        final List<String> expected = <String>[
          for (final String id in next)
            if (!previous.contains(id)) id,
        ];
        expect(result, expected);
        expect(NewGraveIds.diff(previous: next, next: next), isEmpty);
        expect(NewGraveIds.diff(previous: previous, next: previous), isEmpty);
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
