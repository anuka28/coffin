// Feature: graveyard-core, Property 2: Day counts are calendar days, also across daylight saving
// Validates: Requirements 1.3, 1.4
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/calendar_date.dart';

import 'support/grave_generators.dart';

final RunCounter _counter = RunCounter();

final List<CalendarDate> _daylightSavingDates = <CalendarDate>[
  CalendarDate(2026, 3, 8),
  CalendarDate(2026, 3, 29),
  CalendarDate(2026, 10, 25),
  CalendarDate(2026, 11, 1),
];

/// Checks every part of the property for one [date] and one [n].
void _expectCalendarArithmetic(CalendarDate date, int n) {
  final CalendarDate moved = date.addDays(n);

  expect(date.daysUntil(moved), n);
  expect(moved.epochDay - date.epochDay, n);
  expect(moved.addDays(-n), date);
  expect(moved.daysUntil(date), -n);

  CalendarDate stepped = date;
  for (int i = 0; i < n; i++) {
    stepped = stepped.addDays(1);
  }
  expect(stepped, moved);

  // Model: UTC year/month/day overflow, read back as a calendar date. It
  // uses neither Duration nor the machine time zone.
  final DateTime model = DateTime.utc(date.year, date.month, date.day + n);
  expect(moved, CalendarDate(model.year, model.month, model.day));
}

void main() {
  group('Property 2: Day counts are calendar days, also across daylight '
      'saving', () {
    Glados2(
      anyCalendarDate,
      anyIntBetween(0, 801),
      ExploreConfig(numRuns: numRuns),
    ).test('addDays, daysUntil and epochDay agree for n from 0 to 800', (
      CalendarDate date,
      int n,
    ) {
      _counter.increment();
      _expectCalendarArithmetic(date, n);
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });

    test('the four daylight saving dates count whole days for n 0 to 800', () {
      for (final CalendarDate date in _daylightSavingDates) {
        for (int n = 0; n <= 800; n++) {
          expect(date.daysUntil(date.addDays(n)), n, reason: '$date + $n');
          expect(date.addDays(n).addDays(-n), date, reason: '$date + $n');
        }
        for (final int n in <int>[0, 1, 2, 7, 30, 800]) {
          _expectCalendarArithmetic(date, n);
        }
      }
    });

    test('one day before and after a daylight saving date is one day', () {
      for (final CalendarDate date in _daylightSavingDates) {
        expect(date.addDays(-1).daysUntil(date), 1);
        expect(date.daysUntil(date.addDays(1)), 1);
        expect(date.addDays(-1).daysUntil(date.addDays(1)), 2);
      }
    });
  });
}
