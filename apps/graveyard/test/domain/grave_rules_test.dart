import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave_rejection.dart';
import 'package:graveyard/src/domain/grave_rules.dart';
import 'package:graveyard/src/domain/manual_grave_check.dart';

void main() {
  final today = CalendarDate(2026, 6, 15);

  ManualGraveRejected rejected(String name, int? y, int? m, int? d) =>
      GraveRules.checkManual(
        rawName: name,
        year: y,
        month: m,
        day: d,
        today: today,
      ) as ManualGraveRejected;

  test('accepts a normalised name and a valid date', () {
    final r = GraveRules.checkManual(
      rawName: '  Old   Blog ',
      year: 2024,
      month: 2,
      day: 29,
      today: today,
    );
    expect(r, ManualGraveAccepted('Old Blog', CalendarDate(2024, 2, 29)));
  });

  test('rejects empty and too long names', () {
    expect(rejected('  \t', 2020, 1, 1).reason, GraveRejection.nameEmpty);
    expect(rejected('a' * 81, 2020, 1, 1).reason, GraveRejection.nameTooLong);
    expect(
      GraveRules.checkManual(
        rawName: 'a' * 80,
        year: 2020,
        month: 1,
        day: 1,
        today: today,
      ),
      isA<ManualGraveAccepted>(),
    );
  });

  test('rejects missing, unreal, early and future dates', () {
    expect(rejected('x', null, 1, 1).reason, GraveRejection.dateMissing);
    expect(rejected('x', 2025, 2, 30).reason, GraveRejection.dateNotReal);
    expect(rejected('x', 1969, 12, 31).reason, GraveRejection.dateTooEarly);
    expect(rejected('x', 2026, 6, 16).reason, GraveRejection.dateInFuture);
  });

  test('accepts Today and 1970-01-01', () {
    for (final p in [
      [2026, 6, 15],
      [1970, 1, 1],
    ]) {
      expect(
        GraveRules.checkManual(
          rawName: 'x',
          year: p[0],
          month: p[1],
          day: p[2],
          today: today,
        ),
        isA<ManualGraveAccepted>(),
      );
    }
  });

  test('checks run in order: name before date', () {
    expect(rejected('', null, null, null).reason, GraveRejection.nameEmpty);
  });

  group('name criteria', () {
    test('whitespace-only names of every kind are empty', () {
      expect(rejected(' \n\t ', 2020, 1, 1).reason, GraveRejection.nameEmpty);
    });
    test('length counts code points after normalising', () {
      expect(
        GraveRules.checkManual(
          rawName: '👻' * 80,
          year: 2020,
          month: 1,
          day: 1,
          today: today,
        ),
        isA<ManualGraveAccepted>(),
      );
      expect(
        rejected('👻' * 81, 2020, 1, 1).reason,
        GraveRejection.nameTooLong,
      );
      expect(
        GraveRules.checkManual(
          rawName: '  ${'a' * 80}  ',
          year: 2020,
          month: 1,
          day: 1,
          today: today,
        ),
        isA<ManualGraveAccepted>(),
      );
      expect(
        rejected('a  b${'c' * 78}', 2020, 1, 1).reason,
        GraveRejection.nameTooLong,
      );
    });
  });

  group('date criteria', () {
    test('each missing part is a missing date', () {
      expect(rejected('x', 2020, null, 1).reason, GraveRejection.dateMissing);
      expect(rejected('x', 2020, 1, null).reason, GraveRejection.dateMissing);
      expect(
        rejected('x', null, null, null).reason,
        GraveRejection.dateMissing,
      );
    });
    test('impossible dates are rejected, never shifted', () {
      expect(rejected('x', 2025, 2, 30).reason, GraveRejection.dateNotReal);
      expect(rejected('x', 2025, 2, 29).reason, GraveRejection.dateNotReal);
      expect(rejected('x', 2025, 13, 1).reason, GraveRejection.dateNotReal);
      expect(rejected('x', 2025, 4, 31).reason, GraveRejection.dateNotReal);
      expect(rejected('x', 2025, 1, 0).reason, GraveRejection.dateNotReal);
      expect(
        GraveRules.checkManual(
          rawName: 'x',
          year: 2025,
          month: 2,
          day: 30,
          today: today,
        ),
        isNot(isA<ManualGraveAccepted>()),
      );
    });
    test('leap day is accepted in a leap year', () {
      expect(
        GraveRules.checkManual(
          rawName: 'x',
          year: 2024,
          month: 2,
          day: 29,
          today: today,
        ),
        ManualGraveAccepted('x', CalendarDate(2024, 2, 29)),
      );
    });
    test('the day before 1970-01-01 is too early, the day after is fine', () {
      expect(rejected('x', 1969, 12, 31).reason, GraveRejection.dateTooEarly);
      expect(
        GraveRules.checkManual(
          rawName: 'x',
          year: 1970,
          month: 1,
          day: 2,
          today: today,
        ),
        isA<ManualGraveAccepted>(),
      );
    });
    test('Today is accepted, tomorrow is in the future', () {
      expect(
        GraveRules.checkManual(
          rawName: 'x',
          year: 2026,
          month: 6,
          day: 14,
          today: today,
        ),
        isA<ManualGraveAccepted>(),
      );
      expect(rejected('x', 2026, 6, 16).reason, GraveRejection.dateInFuture);
      expect(rejected('x', 2027, 1, 1).reason, GraveRejection.dateInFuture);
    });
  });

  group('order of checks', () {
    test('name length comes before the date checks', () {
      expect(
        rejected('a' * 81, null, null, null).reason,
        GraveRejection.nameTooLong,
      );
    });
    test('missing date comes before not real', () {
      expect(rejected('x', 2025, 2, null).reason, GraveRejection.dateMissing);
    });
    test('not real comes before too early and in future', () {
      expect(rejected('x', 1969, 2, 30).reason, GraveRejection.dateNotReal);
      expect(rejected('x', 2030, 2, 30).reason, GraveRejection.dateNotReal);
    });
  });
}
