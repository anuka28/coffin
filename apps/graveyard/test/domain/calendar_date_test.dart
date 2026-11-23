import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';

void main() {
  group('leap years and month ends', () {
    test('February has 29 days in leap years', () {
      expect(CalendarDate(2024, 2, 1).daysInMonth, 29);
      expect(CalendarDate(2000, 2, 1).daysInMonth, 29);
    });

    test('February has 28 days in non-leap years', () {
      expect(CalendarDate(2025, 2, 1).daysInMonth, 28);
      expect(CalendarDate(1900, 2, 1).daysInMonth, 28);
    });

    test('other months have their usual length', () {
      expect(CalendarDate(2025, 1, 1).daysInMonth, 31);
      expect(CalendarDate(2025, 4, 1).daysInMonth, 30);
    });

    test('isLastDayOfMonth', () {
      expect(CalendarDate(2024, 2, 29).isLastDayOfMonth, isTrue);
      expect(CalendarDate(2025, 2, 28).isLastDayOfMonth, isTrue);
      expect(CalendarDate(2025, 2, 27).isLastDayOfMonth, isFalse);
      expect(CalendarDate(2025, 12, 31).isLastDayOfMonth, isTrue);
    });
  });

  group('construction', () {
    test('rejects unreal dates', () {
      expect(() => CalendarDate(2025, 2, 29), throwsArgumentError);
      expect(() => CalendarDate(2025, 13, 1), throwsArgumentError);
      expect(() => CalendarDate(2025, 0, 1), throwsArgumentError);
      expect(() => CalendarDate(2025, 1, 0), throwsArgumentError);
    });

    test('tryCreate returns null for unreal dates', () {
      expect(CalendarDate.tryCreate(2025, 4, 31), isNull);
      expect(CalendarDate.tryCreate(2024, 2, 29), isNotNull);
    });

    test('year bounds are 1 to 9999', () {
      expect(CalendarDate.tryCreate(0, 1, 1), isNull);
      expect(CalendarDate.tryCreate(10000, 1, 1), isNull);
      expect(CalendarDate.tryCreate(1, 1, 1), isNotNull);
      expect(CalendarDate.tryCreate(9999, 12, 31), isNotNull);
    });

    test('fromDateTime reads only year, month and day', () {
      final date = CalendarDate.fromDateTime(DateTime(2025, 3, 9, 23, 59));
      expect(date, CalendarDate(2025, 3, 9));
    });
  });

  group('tryParse', () {
    test('parses a valid date', () {
      expect(CalendarDate.tryParse('2024-02-29'), CalendarDate(2024, 2, 29));
    });

    test('rejects the wrong shape', () {
      for (final bad in [
        '',
        '2025-1-01',
        '2025-01-1',
        '25-01-01',
        '2025/01/01',
        '20250101',
        ' 2025-01-01',
        '2025-01-01 ',
        '2025-01-01\n',
        '2025-01-01T00:00:00',
        'abcd-ef-gh',
      ]) {
        expect(CalendarDate.tryParse(bad), isNull, reason: bad);
      }
    });

    test('rejects month 13 and day 00', () {
      expect(CalendarDate.tryParse('2025-13-01'), isNull);
      expect(CalendarDate.tryParse('2025-00-10'), isNull);
      expect(CalendarDate.tryParse('2025-01-00'), isNull);
    });

    test('rejects dates that do not exist', () {
      expect(CalendarDate.tryParse('2025-02-30'), isNull);
      expect(CalendarDate.tryParse('2025-02-29'), isNull);
      expect(CalendarDate.tryParse('2025-04-31'), isNull);
    });

    test('rejects year 0000', () {
      expect(CalendarDate.tryParse('0000-01-01'), isNull);
    });

    test('accepts year bounds', () {
      expect(CalendarDate.tryParse('0001-01-01'), CalendarDate(1, 1, 1));
      expect(CalendarDate.tryParse('9999-12-31'), CalendarDate(9999, 12, 31));
    });

    test('toIso round-trips and pads', () {
      expect(CalendarDate(5, 3, 9).toIso(), '0005-03-09');
      expect(CalendarDate.tryParse('0005-03-09')!.toIso(), '0005-03-09');
    });
  });

  group('epoch days', () {
    test('1970-01-01 is epoch day 0', () {
      expect(CalendarDate(1970, 1, 1).epochDay, 0);
      expect(CalendarDate.earliest, CalendarDate(1970, 1, 1));
    });

    test('known epoch days', () {
      expect(CalendarDate(1969, 12, 31).epochDay, -1);
      expect(CalendarDate(2000, 3, 1).epochDay, 11017);
    });

    test('fromEpochDay inverts epochDay', () {
      for (final d in [
        CalendarDate(1, 1, 1),
        CalendarDate(1969, 12, 31),
        CalendarDate(2024, 2, 29),
        CalendarDate(9999, 12, 31),
      ]) {
        expect(CalendarDate.fromEpochDay(d.epochDay), d);
      }
    });
  });

  group('addDays', () {
    test('crosses month and leap-day boundaries', () {
      expect(CalendarDate(2024, 2, 28).addDays(1), CalendarDate(2024, 2, 29));
      expect(CalendarDate(2025, 2, 28).addDays(1), CalendarDate(2025, 3, 1));
      expect(CalendarDate(2025, 12, 31).addDays(1), CalendarDate(2026, 1, 1));
    });

    test('handles negative n', () {
      expect(CalendarDate(2024, 3, 1).addDays(-1), CalendarDate(2024, 2, 29));
      expect(CalendarDate(2025, 1, 1).addDays(-1), CalendarDate(2024, 12, 31));
      expect(CalendarDate(2025, 3, 1).addDays(-365), CalendarDate(2024, 3, 1));
    });

    test('zero is identity', () {
      expect(CalendarDate(2025, 6, 15).addDays(0), CalendarDate(2025, 6, 15));
    });

    test('throws outside the year bounds', () {
      expect(() => CalendarDate(9999, 12, 31).addDays(1), throwsArgumentError);
      expect(() => CalendarDate(1, 1, 1).addDays(-1), throwsArgumentError);
    });
  });

  group('addMonthsClamped', () {
    test('clamps to the end of a shorter month', () {
      expect(
        CalendarDate(2025, 1, 31).addMonthsClamped(1),
        CalendarDate(2025, 2, 28),
      );
      expect(
        CalendarDate(2024, 1, 31).addMonthsClamped(1),
        CalendarDate(2024, 2, 29),
      );
    });

    test('handles negative n and year rollover', () {
      expect(
        CalendarDate(2025, 1, 15).addMonthsClamped(-1),
        CalendarDate(2024, 12, 15),
      );
      expect(
        CalendarDate(2025, 3, 31).addMonthsClamped(-1),
        CalendarDate(2025, 2, 28),
      );
    });
  });

  group('daysUntil', () {
    test('is signed', () {
      final a = CalendarDate(2025, 1, 1);
      final b = CalendarDate(2025, 1, 31);
      expect(a.daysUntil(b), 30);
      expect(b.daysUntil(a), -30);
      expect(a.daysUntil(a), 0);
    });
  });

  group('wholeMonthsUntil', () {
    test('counts a month once the day of month is reached', () {
      final start = CalendarDate(2025, 1, 15);
      expect(start.wholeMonthsUntil(CalendarDate(2025, 2, 14)), 0);
      expect(start.wholeMonthsUntil(CalendarDate(2025, 2, 15)), 1);
      expect(start.wholeMonthsUntil(CalendarDate(2026, 1, 15)), 12);
    });

    test('Jan 31 reaches a whole month on the last day of February', () {
      final start = CalendarDate(2025, 1, 31);
      expect(start.wholeMonthsUntil(CalendarDate(2025, 2, 27)), 0);
      expect(start.wholeMonthsUntil(CalendarDate(2025, 2, 28)), 1);
    });

    test('leap February clamp', () {
      final start = CalendarDate(2024, 1, 31);
      expect(start.wholeMonthsUntil(CalendarDate(2024, 2, 28)), 0);
      expect(start.wholeMonthsUntil(CalendarDate(2024, 2, 29)), 1);
    });

    test('Jan 30 and 29 clamp in a non-leap February', () {
      expect(
        CalendarDate(2025, 1, 30).wholeMonthsUntil(CalendarDate(2025, 2, 28)),
        1,
      );
      expect(
        CalendarDate(2025, 1, 29).wholeMonthsUntil(CalendarDate(2025, 2, 28)),
        1,
      );
    });

    test('does not clamp when the later month is longer than the day', () {
      final start = CalendarDate(2025, 1, 31);
      expect(start.wholeMonthsUntil(CalendarDate(2025, 3, 30)), 1);
      expect(start.wholeMonthsUntil(CalendarDate(2025, 3, 31)), 2);
    });

    test('31st into a 30-day month', () {
      final start = CalendarDate(2025, 3, 31);
      expect(start.wholeMonthsUntil(CalendarDate(2025, 4, 29)), 0);
      expect(start.wholeMonthsUntil(CalendarDate(2025, 4, 30)), 1);
    });

    test('is 0 when later is the same or earlier', () {
      final a = CalendarDate(2025, 5, 10);
      expect(a.wholeMonthsUntil(a), 0);
      expect(a.wholeMonthsUntil(CalendarDate(2025, 4, 10)), 0);
      expect(a.wholeMonthsUntil(CalendarDate(2020, 1, 1)), 0);
    });
  });

  group('ordering', () {
    test('compareTo and equality', () {
      final a = CalendarDate(2025, 1, 31);
      final b = CalendarDate(2025, 2, 1);
      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(a), greaterThan(0));
      expect(a.compareTo(CalendarDate(2025, 1, 31)), 0);
      expect(a, CalendarDate(2025, 1, 31));
      expect(a.hashCode, CalendarDate(2025, 1, 31).hashCode);
    });
  });
}
