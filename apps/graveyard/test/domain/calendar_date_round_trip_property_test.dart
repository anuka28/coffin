// Feature: graveyard-core, Property 1: Calendar date round trip
// Validates: Requirements 1.6
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/calendar_date.dart';

import 'support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 1: Calendar date round trip', () {
    Glados(anyCalendarDate, ExploreConfig(numRuns: numRuns)).test(
      'tryParse(toIso()) and fromEpochDay(epochDay) return the same date',
      (CalendarDate date) {
        _counter.increment();
        expect(CalendarDate.tryParse(date.toIso()), date);
        expect(CalendarDate.fromEpochDay(date.epochDay), date);
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
