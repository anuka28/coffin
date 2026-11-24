// Feature: graveyard-scene, Property 22: Thousands formatter round-trips
// Validates: Requirements 12.3
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/thousands_formatter.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 22: Thousands formatter round-trips', () {
    Glados(anyNonNegativeInt, ExploreConfig(numRuns: numRuns)).test(
      'removing the commas from format(n) gives n',
      (int n) {
        _counter.increment();
        expect(int.parse(ThousandsFormatter.format(n).replaceAll(',', '')), n);
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
