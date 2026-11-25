// Feature: graveyard-resurrection, Property 2: Raising twice equals raising once
// Validates: Requirements 2.8
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/raise_rules.dart';

import 'support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 2: Raising twice equals raising once', () {
    Glados3(
      anyGraveWithRisen,
      anyCalendarDate,
      anyCalendarDate,
      ExploreConfig(numRuns: numRuns),
    ).test('a second raise on another day changes nothing', (
      Grave grave,
      CalendarDate first,
      CalendarDate drawn,
    ) {
      _counter.increment();
      // The second Today always differs from the first.
      final CalendarDate second = drawn == first
          ? CalendarDate.fromEpochDay(first.epochDay + 1)
          : drawn;
      expect(second, isNot(first));

      final Grave once = RaiseRules.raise(grave, first);
      final Grave twice = RaiseRules.raise(once, second);
      expect(twice, once);
      expect(twice.hashCode, once.hashCode);
      expect(twice.risenOn, once.risenOn);

      // An already-Risen Grave keeps the date it already had.
      if (grave.risenOn != null) {
        expect(once.risenOn, grave.risenOn);
        expect(RaiseRules.raise(grave, second).risenOn, grave.risenOn);
      }
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
