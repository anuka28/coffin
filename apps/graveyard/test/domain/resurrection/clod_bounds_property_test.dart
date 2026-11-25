// Feature: graveyard-resurrection, Property 12: Clods stay inside their bounds
// Validates: Requirements 8.4
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/resurrection/clod.dart';
import 'package:graveyard/src/domain/resurrection/clod_path_generator.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 12: Clods stay inside their bounds', () {
    Glados(anyGraveId, ExploreConfig(numRuns: numRuns)).test(
      'count is 4 to 7, flight is positive, size is 2 to 8',
      (String id) {
        _counter.increment();
        final List<Clod> clods = ClodPathGenerator.generate(id);
        expect(clods.length, inInclusiveRange(4, 7));
        for (final Clod clod in clods) {
          expect(clod.flightMs, greaterThan(0));
          expect(clod.sizePx, inInclusiveRange(2, 8));
        }
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
