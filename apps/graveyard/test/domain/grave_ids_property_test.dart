// Feature: graveyard-core, Property 6: Generated grave ids are unique
// Validates: Requirements 2.1
import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/grave_ids.dart';

import 'support/grave_generators.dart';

final RunCounter _counter = RunCounter();

/// Ids that are not of the `gN` shape, mixed into the existing sets.
const List<String> _otherIds = <String>['x', 'g0', 'g01', 'G1', 'g', 'abc'];

/// Maps a number to an existing id: 1 to 30 give `gN`, the rest pick an
/// unrelated id.
String _idFor(int n) =>
    n <= 30 ? 'g$n' : _otherIds[(n - 31) % _otherIds.length];

void main() {
  group('Property 6: Generated grave ids are unique', () {
    Glados(
      anyListBetween<int>(0, 40, anyIntBetween(1, 37)),
      ExploreConfig(numRuns: numRuns),
    ).test('next is new, a valid key, and a second next differs', (
      List<int> numbers,
    ) {
      _counter.increment();
      final Set<String> existing = numbers.map(_idFor).toSet();

      final String first = GraveIds.next(existing);
      expect(existing.contains(first), isFalse);
      expect(KeyValidator.isValid(first), isTrue);

      final Set<String> grown = <String>{...existing, first};
      final String second = GraveIds.next(grown);
      expect(second, isNot(first));
      expect(grown.contains(second), isFalse);
      expect(KeyValidator.isValid(second), isTrue);
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
