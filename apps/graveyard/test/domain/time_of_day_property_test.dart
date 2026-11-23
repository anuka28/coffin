// Feature: graveyard-core, Property 3: Time of day does not change Today or the text
// Validates: Requirements 1.2, 1.5
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/dead_for_formatter.dart';

import '../support/fake_clock.dart';
import '../support/fixed_offset_zone.dart';
import 'support/grave_generators.dart';

final RunCounter _counter = RunCounter();

/// The clock reading, in the zone with [offsetMinutes], at [secondOfDay]
/// seconds after local midnight of [date].
DateTime _localTime(CalendarDate date, int secondOfDay, int offsetMinutes) {
  final DateTime utcMidnight = DateTime.utc(date.year, date.month, date.day);
  final DateTime instant = utcMidnight
      .subtract(Duration(minutes: offsetMinutes))
      .add(Duration(seconds: secondOfDay));
  final FakeClock clock = FakeClock(instant);
  return FixedOffsetZone(Duration(minutes: offsetMinutes))(clock.now());
}

void main() {
  group('Property 3: Time of day does not change Today or the text', () {
    // The days dead (0 to 800), the zone offset (53 steps) and the first
    // second of the day are packed into one integer below 2^32, because
    // glados offers at most three generators per test.
    Glados3(
      anyCalendarDate,
      anyIntBetween(0, 801 * 53 * 86400),
      anyIntBetween(0, 86400),
      ExploreConfig(numRuns: numRuns),
    ).test('two times on the same local date give the same Today and text', (
      CalendarDate today,
      int packed,
      int secondB,
    ) {
      final int secondA = packed % 86400;
      final int offsetMinutes = -720 + 30 * ((packed ~/ 86400) % 53);
      final CalendarDate death = today.addDays(-(packed ~/ (86400 * 53)));
      _counter.increment();
      final DateTime a = _localTime(today, secondA, offsetMinutes);
      final DateTime b = _localTime(today, secondB, offsetMinutes);

      final CalendarDate todayA = CalendarDate.fromDateTime(a);
      final CalendarDate todayB = CalendarDate.fromDateTime(b);
      expect(todayA, today);
      expect(todayB, today);
      expect(todayA, todayB);
      expect(
        DeadForFormatter.format(death, todayA),
        DeadForFormatter.format(death, todayB),
      );
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });

    test('first and last second of a day give the same date and text', () {
      final CalendarDate today = CalendarDate(2026, 3, 8);
      final CalendarDate death = CalendarDate(2026, 1, 8);
      final CalendarDate first = CalendarDate.fromDateTime(
        _localTime(today, 0, 330),
      );
      final CalendarDate last = CalendarDate.fromDateTime(
        _localTime(today, 86399, 330),
      );
      expect(first, last);
      expect(
        DeadForFormatter.format(death, first),
        DeadForFormatter.format(death, last),
      );
    });
  });
}
