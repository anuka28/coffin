// Feature: graveyard-resurrection, Property 3: Lay_To_Rest is idempotent
// Validates: Requirements 2.9
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/raise_rules.dart';

import 'support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 3: Lay_To_Rest is idempotent', () {
    Glados(anyGraveWithRisen, ExploreConfig(numRuns: numRuns)).test(
      'laying to rest twice equals laying to rest once',
      (Grave grave) {
        _counter.increment();
        final Grave once = RaiseRules.layToRest(grave);
        final Grave twice = RaiseRules.layToRest(once);
        expect(twice, once);
        expect(twice.hashCode, once.hashCode);
        expect(once.risenOn, isNull);
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
