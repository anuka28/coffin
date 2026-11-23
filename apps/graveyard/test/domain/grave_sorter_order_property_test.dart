// Feature: graveyard-core, Property 20: Sorting does not depend on the input order
// Validates: Requirements 6.6
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/grave_sorter.dart';

import 'support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 20: Sorting does not depend on the input order', () {
    Glados2(
      anyGraveList,
      anyIntBetween(0, 0x40000000),
      ExploreConfig(numRuns: numRuns),
    ).test('any shuffle of distinct-id graves sorts to equal results', (
      List<Grave> graves,
      int seed,
    ) {
      _counter.increment();
      final List<Grave> shuffled = List<Grave>.of(graves)
        ..shuffle(math.Random(seed));

      final List<Grave> a = GraveSorter.sort(graves);
      final List<Grave> b = GraveSorter.sort(shuffled);

      expect(b, equals(a));
      expect(
        b.map((Grave g) => g.id).toList(),
        equals(a.map((Grave g) => g.id).toList()),
      );
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
