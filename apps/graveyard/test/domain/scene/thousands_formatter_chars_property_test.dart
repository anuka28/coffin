// Feature: graveyard-scene, Property 24: Thousands formatter output is digits and commas only
// Validates: Requirements 12.5
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/thousands_formatter.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group(
    'Property 24: Thousands formatter output is digits and commas only',
    () {
      Glados(anyNonNegativeInt, ExploreConfig(numRuns: numRuns)).test(
        'format(n) has only digits and commas, with no edge comma',
        (int n) {
          _counter.increment();
          final String text = ThousandsFormatter.format(n);
          expect(text, matches(RegExp(r'^[0-9,]+$')));
          expect(text.startsWith(','), isFalse);
          expect(text.endsWith(','), isFalse);
        },
      );

      test('ran the configured number of times', () {
        _counter.expectRuns(numRuns);
      });
    },
  );
}
