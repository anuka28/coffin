import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/dead_for.dart';
import 'package:graveyard/src/domain/dead_for_unit.dart';

CalendarDate _d(int y, int m, int d) => CalendarDate(y, m, d);

String _text(CalendarDate death, CalendarDate today) =>
    DeadFor.between(death, today).text;

void main() {
  group('day counts', () {
    final death = _d(2025, 3, 10);

    test('0 days is "Died today"', () {
      expect(_text(death, death), 'Died today');
      expect(DeadFor.between(death, death).unit, DeadForUnit.today);
      expect(DeadFor.between(death, death).count, 0);
    });

    test('1, 2 and 6 days count days', () {
      expect(_text(death, death.addDays(1)), 'Dead for 1 day');
      expect(_text(death, death.addDays(2)), 'Dead for 2 days');
      expect(_text(death, death.addDays(6)), 'Dead for 6 days');
    });

    test('7 and 13 days are 1 week, 14 days are 2 weeks', () {
      expect(_text(death, death.addDays(7)), 'Dead for 1 week');
      expect(_text(death, death.addDays(13)), 'Dead for 1 week');
      expect(_text(death, death.addDays(14)), 'Dead for 2 weeks');
    });
  });

  group('end of February', () {
    test('leap year: 2024-01-31 to 2024-02-29 is 1 month', () {
      expect(_text(_d(2024, 1, 31), _d(2024, 2, 29)), 'Dead for 1 month');
      expect(_text(_d(2024, 1, 30), _d(2024, 2, 29)), 'Dead for 1 month');
    });

    test('leap year: 2024-01-29 to 2024-02-28 is not yet a month', () {
      expect(_text(_d(2024, 1, 29), _d(2024, 2, 28)), 'Dead for 4 weeks');
    });

    test('common year: 2025-01-31 to 2025-02-28 is 1 month', () {
      expect(_text(_d(2025, 1, 29), _d(2025, 2, 28)), 'Dead for 1 month');
      expect(_text(_d(2025, 1, 30), _d(2025, 2, 28)), 'Dead for 1 month');
    });

    test('a leap day reaches a year on the last day of February', () {
      expect(_text(_d(2024, 2, 29), _d(2025, 2, 28)), 'Dead for 1 year');
      expect(_text(_d(2024, 2, 29), _d(2025, 2, 27)), 'Dead for 11 months');
    });
  });

  group('month-end clamp', () {
    test('2025-01-31 to 2025-02-28 gives "Dead for 1 month"', () {
      expect(_text(_d(2025, 1, 31), _d(2025, 2, 28)), 'Dead for 1 month');
    });

    test('2025-01-31 to 2025-02-27 gives "Dead for 3 weeks"', () {
      expect(_text(_d(2025, 1, 31), _d(2025, 2, 27)), 'Dead for 3 weeks');
    });
  });

  group('first whole month and year', () {
    final death = _d(2025, 3, 10);

    test('the day before the first month still counts weeks', () {
      expect(_text(death, _d(2025, 4, 9)), 'Dead for 4 weeks');
    });

    test('the day of the first month gives 1 month', () {
      expect(_text(death, _d(2025, 4, 10)), 'Dead for 1 month');
    });

    test('the day before the first year still counts months', () {
      expect(_text(death, _d(2026, 3, 9)), 'Dead for 11 months');
    });

    test('the day of the first year gives 1 year', () {
      expect(_text(death, _d(2026, 3, 10)), 'Dead for 1 year');
    });

    test('later years are plural', () {
      expect(_text(death, _d(2027, 3, 10)), 'Dead for 2 years');
      expect(_text(death, _d(2027, 3, 9)), 'Dead for 1 year');
    });
  });

  group('daylight saving dates', () {
    test('spring change 2026-03-08 counts calendar days', () {
      expect(_text(_d(2026, 3, 7), _d(2026, 3, 9)), 'Dead for 2 days');
      expect(_text(_d(2026, 3, 8), _d(2026, 3, 9)), 'Dead for 1 day');
    });

    test('autumn change 2026-10-25 counts calendar days', () {
      expect(_text(_d(2026, 10, 24), _d(2026, 10, 26)), 'Dead for 2 days');
      expect(_text(_d(2026, 10, 25), _d(2026, 11, 1)), 'Dead for 1 week');
    });

    test('a span across both changes counts whole months', () {
      expect(_text(_d(2026, 3, 8), _d(2026, 10, 25)), 'Dead for 7 months');
    });
  });

  group('death date after Today', () {
    test('gives "Died today"', () {
      final today = _d(2025, 3, 10);
      expect(_text(today.addDays(1), today), 'Died today');
      expect(_text(_d(2030, 1, 1), today), 'Died today');
      expect(DeadFor.between(today.addDays(1), today).count, 0);
    });
  });

  group('singular and plural forms', () {
    test('1 uses the singular for every unit', () {
      expect(const DeadFor(DeadForUnit.days, 1).text, 'Dead for 1 day');
      expect(const DeadFor(DeadForUnit.weeks, 1).text, 'Dead for 1 week');
      expect(const DeadFor(DeadForUnit.months, 1).text, 'Dead for 1 month');
      expect(const DeadFor(DeadForUnit.years, 1).text, 'Dead for 1 year');
    });

    test('2 or more uses the plural for every unit', () {
      expect(const DeadFor(DeadForUnit.days, 2).text, 'Dead for 2 days');
      expect(const DeadFor(DeadForUnit.weeks, 2).text, 'Dead for 2 weeks');
      expect(const DeadFor(DeadForUnit.months, 2).text, 'Dead for 2 months');
      expect(const DeadFor(DeadForUnit.years, 2).text, 'Dead for 2 years');
    });

    test('today ignores the count', () {
      expect(const DeadFor(DeadForUnit.today, 0).text, 'Died today');
    });
  });

  group('value semantics', () {
    test('equal unit and count are equal with the same hashCode', () {
      const a = DeadFor(DeadForUnit.weeks, 3);
      const b = DeadFor(DeadForUnit.weeks, 3);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a different unit or count is not equal', () {
      const a = DeadFor(DeadForUnit.weeks, 3);
      expect(a, isNot(const DeadFor(DeadForUnit.weeks, 4)));
      expect(a, isNot(const DeadFor(DeadForUnit.days, 3)));
    });

    test('toString names the unit and count', () {
      expect(
        const DeadFor(DeadForUnit.days, 3).toString(),
        'DeadFor(DeadForUnit.days, 3)',
      );
    });
  });
}
