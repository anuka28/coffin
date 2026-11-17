import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';

void main() {
  group('leap years', () {
    test('Feb 29 is valid in 2000 and 2024', () {
      expect(LocalDay(2000, 2, 29).toIso(), '2000-02-29');
      expect(LocalDay(2024, 2, 29).toIso(), '2024-02-29');
    });

    test('Feb 29 is invalid in 1900 and 2023', () {
      expect(() => LocalDay(1900, 2, 29), throwsArgumentError);
      expect(() => LocalDay(2023, 2, 29), throwsArgumentError);
    });
  });

  group('invalid dates', () {
    test('constructor rejects impossible parts', () {
      expect(() => LocalDay(2026, 0, 1), throwsArgumentError);
      expect(() => LocalDay(2026, 13, 1), throwsArgumentError);
      expect(() => LocalDay(2026, 1, 0), throwsArgumentError);
      expect(() => LocalDay(2026, 1, 32), throwsArgumentError);
      expect(() => LocalDay(2026, 4, 31), throwsArgumentError);
      expect(() => LocalDay(2026, 2, 29), throwsArgumentError);
    });

    test('constructor rejects years outside 1..9999', () {
      expect(() => LocalDay(0, 1, 1), throwsArgumentError);
      expect(() => LocalDay(10000, 1, 1), throwsArgumentError);
    });
  });

  group('tryParse', () {
    test('accepts strict YYYY-MM-DD', () {
      expect(LocalDay.tryParse('2026-03-08'), LocalDay(2026, 3, 8));
      expect(LocalDay.tryParse('2024-02-29'), LocalDay(2024, 2, 29));
      expect(LocalDay.tryParse('0001-01-01'), LocalDay(1, 1, 1));
    });

    test('rejects wrong formats', () {
      for (final text in const [
        '',
        '2026/03/08',
        '20260308',
        '2026-3-08',
        '2026-03-8',
        '26-03-08',
        '2026-03-08T00:00',
        '2026-03-08-01',
        'abcd-ef-gh',
        '+026-03-08',
      ]) {
        expect(LocalDay.tryParse(text), isNull, reason: 'input "$text"');
      }
    });

    test('rejects dates that do not exist', () {
      expect(LocalDay.tryParse('2026-02-30'), isNull);
      expect(LocalDay.tryParse('2023-02-29'), isNull);
      expect(LocalDay.tryParse('2026-13-01'), isNull);
      expect(LocalDay.tryParse('2026-00-10'), isNull);
      expect(LocalDay.tryParse('2026-04-31'), isNull);
      expect(LocalDay.tryParse('2026-01-00'), isNull);
      expect(LocalDay.tryParse('0000-01-01'), isNull);
    });

    test('rejects spaces', () {
      expect(LocalDay.tryParse(' 2026-03-08'), isNull);
      expect(LocalDay.tryParse('2026-03-08 '), isNull);
      expect(LocalDay.tryParse('2026- 3-08'), isNull);
      expect(LocalDay.tryParse('2026 03 08'), isNull);
    });

    test('rejects short fields', () {
      expect(LocalDay.tryParse('202-03-08'), isNull);
      expect(LocalDay.tryParse('2026-3-8'), isNull);
      expect(LocalDay.tryParse('2026-03-'), isNull);
      expect(LocalDay.tryParse('2026-03'), isNull);
    });
  });

  group('year bounds', () {
    test('year 1 and 9999 exist', () {
      expect(LocalDay(1, 1, 1).toIso(), '0001-01-01');
      expect(LocalDay(9999, 12, 31).toIso(), '9999-12-31');
    });

    test('stepping out of range throws', () {
      expect(() => LocalDay(1, 1, 1).previous, throwsArgumentError);
      expect(() => LocalDay(9999, 12, 31).next, throwsArgumentError);
    });

    test('epoch days at the bounds round trip', () {
      final first = LocalDay(1, 1, 1);
      final last = LocalDay(9999, 12, 31);
      expect(first.epochDay, -719162);
      expect(last.epochDay, 2932896);
      expect(LocalDay.fromEpochDay(first.epochDay), first);
      expect(LocalDay.fromEpochDay(last.epochDay), last);
      expect(
        () => LocalDay.fromEpochDay(first.epochDay - 1),
        throwsArgumentError,
      );
      expect(
        () => LocalDay.fromEpochDay(last.epochDay + 1),
        throwsArgumentError,
      );
    });
  });

  group('month ends, next and previous', () {
    test('last day of each month 2026 is real and rolls to the 1st', () {
      const lengths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
      for (var m = 1; m <= 12; m++) {
        final last = LocalDay(2026, m, lengths[m - 1]);
        expect(
          () => LocalDay(2026, m, lengths[m - 1] + 1),
          throwsArgumentError,
        );
        if (m < 12) {
          expect(last.next, LocalDay(2026, m + 1, 1));
        }
      }
    });

    test('February length depends on leap year', () {
      expect(LocalDay(2024, 2, 28).next, LocalDay(2024, 2, 29));
      expect(LocalDay(2024, 2, 29).next, LocalDay(2024, 3, 1));
      expect(LocalDay(2023, 2, 28).next, LocalDay(2023, 3, 1));
      expect(LocalDay(1900, 2, 28).next, LocalDay(1900, 3, 1));
      expect(LocalDay(2000, 2, 28).next, LocalDay(2000, 2, 29));
    });

    test('next and previous across month and year', () {
      expect(LocalDay(2026, 1, 31).next, LocalDay(2026, 2, 1));
      expect(LocalDay(2026, 3, 1).previous, LocalDay(2026, 2, 28));
      expect(LocalDay(2026, 12, 31).next, LocalDay(2027, 1, 1));
      expect(LocalDay(2027, 1, 1).previous, LocalDay(2026, 12, 31));
      expect(LocalDay(2024, 3, 1).previous, LocalDay(2024, 2, 29));
    });
  });

  group('addDays', () {
    test('negative values go back', () {
      expect(LocalDay(2026, 3, 1).addDays(-1), LocalDay(2026, 2, 28));
      expect(LocalDay(2026, 1, 1).addDays(-1), LocalDay(2025, 12, 31));
      expect(LocalDay(2026, 1, 1).addDays(-365), LocalDay(2025, 1, 1));
      expect(LocalDay(2025, 1, 1).addDays(-366), LocalDay(2024, 1, 1));
    });

    test('zero and positive values', () {
      final day = LocalDay(2026, 5, 17);
      expect(day.addDays(0), day);
      expect(LocalDay(2026, 1, 1).addDays(365), LocalDay(2027, 1, 1));
      expect(LocalDay(2024, 1, 1).addDays(366), LocalDay(2025, 1, 1));
    });

    test('is unaffected by daylight saving dates', () {
      expect(LocalDay(2026, 3, 8).addDays(1), LocalDay(2026, 3, 9));
      expect(LocalDay(2026, 3, 29).addDays(1), LocalDay(2026, 3, 30));
      expect(LocalDay(2026, 10, 25).addDays(1), LocalDay(2026, 10, 26));
      expect(LocalDay(2026, 11, 1).addDays(1), LocalDay(2026, 11, 2));
    });
  });

  group('epoch days', () {
    test('1970-01-01 is epoch day 0', () {
      expect(LocalDay(1970, 1, 1).epochDay, 0);
    });

    test('neighbours of the epoch', () {
      expect(LocalDay(1970, 1, 2).epochDay, 1);
      expect(LocalDay(1969, 12, 31).epochDay, -1);
    });

    test('known epoch days', () {
      expect(LocalDay(2000, 1, 1).epochDay, 10957);
      expect(LocalDay(1971, 1, 1).epochDay, 365);
    });

    test('fromEpochDay examples', () {
      expect(LocalDay.fromEpochDay(0), LocalDay(1970, 1, 1));
      expect(LocalDay.fromEpochDay(1), LocalDay(1970, 1, 2));
      expect(LocalDay.fromEpochDay(-1), LocalDay(1969, 12, 31));
      expect(LocalDay.fromEpochDay(10957), LocalDay(2000, 1, 1));
      expect(LocalDay.fromEpochDay(365), LocalDay(1971, 1, 1));
      expect(LocalDay.fromEpochDay(10957 + 59), LocalDay(2000, 2, 29));
    });
  });

  group('daysUntil', () {
    test('counts forward, backward and zero', () {
      final a = LocalDay(2026, 2, 27);
      final b = LocalDay(2026, 3, 2);
      expect(a.daysUntil(b), 3);
      expect(b.daysUntil(a), -3);
      expect(a.daysUntil(a), 0);
    });

    test('spans a leap year and a year end', () {
      expect(LocalDay(2024, 1, 1).daysUntil(LocalDay(2025, 1, 1)), 366);
      expect(LocalDay(2025, 1, 1).daysUntil(LocalDay(2026, 1, 1)), 365);
      expect(LocalDay(2026, 12, 31).daysUntil(LocalDay(2027, 1, 1)), 1);
    });
  });

  group('compareTo', () {
    test('orders by date', () {
      final early = LocalDay(2025, 12, 31);
      final late = LocalDay(2026, 1, 1);
      expect(early.compareTo(late), isNegative);
      expect(late.compareTo(early), isPositive);
      expect(early.compareTo(LocalDay(2025, 12, 31)), 0);
    });

    test('compares month and day when years match', () {
      expect(LocalDay(2026, 1, 31).compareTo(LocalDay(2026, 2, 1)), isNegative);
      expect(LocalDay(2026, 2, 2).compareTo(LocalDay(2026, 2, 1)), isPositive);
    });

    test('sorts a list', () {
      final days = [
        LocalDay(2026, 3, 1),
        LocalDay(2024, 2, 29),
        LocalDay(2025, 1, 1),
      ]..sort();
      expect(days.map((d) => d.toIso()), [
        '2024-02-29',
        '2025-01-01',
        '2026-03-01',
      ]);
    });
  });

  group('equality and hashCode', () {
    test('same parts are equal with equal hash codes', () {
      final a = LocalDay(2026, 7, 4);
      final b = LocalDay(2026, 7, 4);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect({a, b}, hasLength(1));
    });

    test('different parts are not equal', () {
      expect(LocalDay(2026, 7, 4), isNot(LocalDay(2026, 7, 5)));
      expect(LocalDay(2026, 7, 4), isNot(LocalDay(2026, 8, 4)));
      expect(LocalDay(2026, 7, 4), isNot(LocalDay(2025, 7, 4)));
    });

    test('is not equal to other types', () {
      // ignore: unrelated_type_equality_checks
      expect(LocalDay(2026, 7, 4) == '2026-07-04', isFalse);
    });
  });

  group('toIso', () {
    test('pads year, month and day with zeros', () {
      expect(LocalDay(1, 2, 3).toIso(), '0001-02-03');
      expect(LocalDay(99, 10, 5).toIso(), '0099-10-05');
      expect(LocalDay(999, 1, 10).toIso(), '0999-01-10');
      expect(LocalDay(2026, 3, 8).toIso(), '2026-03-08');
    });

    test('toString matches toIso and parses back', () {
      final day = LocalDay(2026, 3, 8);
      expect(day.toString(), day.toIso());
      expect(LocalDay.tryParse(day.toIso()), day);
    });
  });

  group('fromDateTime', () {
    test('ignores time of day', () {
      expect(LocalDay.fromDateTime(DateTime(2026, 3, 8)), LocalDay(2026, 3, 8));
      expect(
        LocalDay.fromDateTime(DateTime(2026, 3, 8, 23, 59, 59, 999)),
        LocalDay(2026, 3, 8),
      );
      expect(
        LocalDay.fromDateTime(DateTime(2026, 3, 8, 0, 0, 0, 1)),
        LocalDay(2026, 3, 8),
      );
    });
  });
}
