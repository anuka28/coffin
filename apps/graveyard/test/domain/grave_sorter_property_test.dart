// Feature: graveyard-core, Property 19: Sorting orders, keeps, and does not mutate
// Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.5, 6.7
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/grave_sorter.dart';

import 'support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 19: Sorting orders, keeps, and does not mutate', () {
    Glados(anyGraveList, ExploreConfig(numRuns: numRuns)).test(
      'sort is a new ordered permutation, leaves the input alone, is idempotent',
      (List<Grave> input) {
        _counter.increment();
        final List<Grave> copy = List<Grave>.of(input);

        final List<Grave> sorted = GraveSorter.sort(input);

        // Does not mutate, and returns a new list.
        expect(input, equals(copy));
        expect(identical(sorted, input), isFalse);

        // Permutation: same length and same elements (ids are distinct).
        expect(sorted.length, input.length);
        final Map<String, Grave> byId = <String, Grave>{
          for (final Grave g in input) g.id: g,
        };
        expect(sorted.map((Grave g) => g.id).toSet(), byId.keys.toSet());
        for (final Grave g in sorted) {
          expect(g, equals(byId[g.id]));
        }

        // Order: date non-increasing, then lower-cased name, then id.
        for (int i = 0; i + 1 < sorted.length; i++) {
          final Grave a = sorted[i];
          final Grave b = sorted[i + 1];
          final int byDate = a.dateOfDeath.compareTo(b.dateOfDeath);
          expect(byDate, greaterThanOrEqualTo(0));
          if (byDate == 0) {
            final int byName = a.name.toLowerCase().compareTo(
              b.name.toLowerCase(),
            );
            expect(byName, lessThanOrEqualTo(0));
            if (byName == 0) {
              expect(a.id.compareTo(b.id), lessThan(0));
            }
          }
        }

        // Idempotent.
        expect(GraveSorter.sort(sorted), equals(sorted));
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
