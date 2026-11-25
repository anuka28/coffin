// Feature: graveyard-resurrection, Property 11: The same Grave id always gets the same Clods
// Validates: Requirements 8.2, 8.3
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/resurrection/clod.dart';
import 'package:graveyard/src/domain/resurrection/clod_path_generator.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 11: The same Grave id always gets the same Clods', () {
    Glados(anyGraveId, ExploreConfig(numRuns: numRuns)).test(
      'generate called twice returns equal lists',
      (String id) {
        _counter.increment();
        final List<Clod> first = ClodPathGenerator.generate(id);
        final List<Clod> second = ClodPathGenerator.generate(id);
        expect(second.length, first.length);
        for (int i = 0; i < first.length; i++) {
          expect(second[i], equals(first[i]));
        }
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
