// Feature: graveyard-core, Property 18: Waiting one more day never makes the project look younger
// Validates: Requirements 5.12
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/dead_for.dart';

import 'support/grave_generators.dart';

final RunCounter _counter = RunCounter();

/// Orders spans by unit (today to years), then by count.
int _compare(DeadFor a, DeadFor b) {
  final int byUnit = a.unit.index.compareTo(b.unit.index);
  return byUnit != 0 ? byUnit : a.count.compareTo(b.count);
}

void main() {
  group('Property 18: Waiting one more day never makes the project look '
      'younger', () {
    Glados2(
      anyCalendarDate,
      anyIntBetween(0, 6000),
      ExploreConfig(numRuns: numRuns),
    ).test('the span from death to the next day is never smaller', (
      CalendarDate death,
      int daysAfter,
    ) {
      _counter.increment();
      final CalendarDate today = death.addDays(daysAfter);
      final DeadFor before = DeadFor.between(death, today);
      final DeadFor after = DeadFor.between(death, today.addDays(1));
      expect(
        _compare(after, before),
        greaterThanOrEqualTo(0),
        reason: '$before on $today, then $after the next day (death $death)',
      );
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });

    test('the day before a month ends still reads as weeks', () {
      final CalendarDate death = CalendarDate(2026, 1, 31);
      final DeadFor a = DeadFor.between(death, CalendarDate(2026, 2, 27));
      final DeadFor b = DeadFor.between(death, CalendarDate(2026, 2, 28));
      expect(_compare(b, a), greaterThanOrEqualTo(0));
    });
  });
}
