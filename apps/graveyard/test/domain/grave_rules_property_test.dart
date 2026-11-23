// Feature: graveyard-core, Property 5: Manual validation matches its rules
// Validates: Requirements 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave_rejection.dart';
import 'package:graveyard/src/domain/grave_rules.dart';
import 'package:graveyard/src/domain/manual_grave_check.dart';

import 'support/grave_generators.dart';

final RunCounter _counter = RunCounter();

/// One input of `GraveRules.checkManual`.
final class _Case {
  const _Case(this.rawName, this.year, this.month, this.day, this.today);

  final String rawName;
  final int? year;
  final int? month;
  final int? day;
  final CalendarDate today;

  @override
  String toString() => '_Case($rawName, $year-$month-$day, today $today)';
}

bool _isLeap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

int _daysIn(int y, int m) {
  const List<int> days = <int>[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  return m == 2 && _isLeap(y) ? 29 : days[m - 1];
}

/// Orders dates as plain integers, independent of `CalendarDate`.
int _key(int y, int m, int d) => y * 10000 + m * 100 + d;

/// The model: applies the rules in order, with its own arithmetic.
Object _model(_Case c) {
  final String name = c.rawName.trim().split(RegExp(r'\s+')).join(' ');
  if (name.isEmpty) return GraveRejection.nameEmpty;
  if (name.runes.length > 80) return GraveRejection.nameTooLong;
  final int? y = c.year;
  final int? m = c.month;
  final int? d = c.day;
  if (y == null || m == null || d == null) return GraveRejection.dateMissing;
  final bool real = m >= 1 && m <= 12 && d >= 1 && d <= _daysIn(y, m);
  if (!real) return GraveRejection.dateNotReal;
  if (_key(y, m, d) < _key(1970, 1, 1)) return GraveRejection.dateTooEarly;
  if (_key(y, m, d) > _key(c.today.year, c.today.month, c.today.day)) {
    return GraveRejection.dateInFuture;
  }
  return (name, y, m, d);
}

int? _maybe(math.Random r, int value) => r.nextInt(12) == 0 ? null : value;

/// Parts mixing real dates (edges, today, 1970-01-01, neighbours), impossible
/// dates such as 2025-02-30, out-of-range parts and missing parts.
Generator<_Case> get _anyCase => any.simple<_Case>(
  generate: (math.Random r, int size) {
    final String name = anyProjectName(r, size).value;
    final CalendarDate today = anyCalendarDate(r, size).value;
    int y;
    int m;
    int d;
    switch (r.nextInt(6)) {
      case 0: // today exactly
        y = today.year;
        m = today.month;
        d = today.day;
      case 1: // the earliest day
        y = 1970;
        m = 1;
        d = 1;
      case 2: // a neighbour of today or of 1970-01-01
        final CalendarDate base = r.nextBool() ? today : CalendarDate.earliest;
        final CalendarDate n = base.addDays(r.nextInt(3) - 1);
        y = n.year;
        m = n.month;
        d = n.day;
      case 3: // any real date
        final CalendarDate any = anyCalendarDate(r, size).value;
        y = any.year;
        m = any.month;
        d = any.day;
      case 4: // impossible or out-of-range parts
        y = 1960 + r.nextInt(150);
        m = r.nextInt(15) - 1;
        d = r.nextInt(34) - 1;
      default: // 30 February and friends
        y = 1960 + r.nextInt(150);
        m = 2;
        d = 29 + r.nextInt(3);
    }
    return _Case(name, _maybe(r, y), _maybe(r, m), _maybe(r, d), today);
  },
  shrink: (_Case c) sync* {
    if (c.rawName.isNotEmpty) {
      yield _Case(
        String.fromCharCodes(c.rawName.runes.take(c.rawName.runes.length ~/ 2)),
        c.year,
        c.month,
        c.day,
        c.today,
      );
    }
  },
);

void main() {
  group('Property 5: Manual validation matches its rules', () {
    Glados(
      _anyCase,
      ExploreConfig(numRuns: numRuns),
    ).test('checkManual equals the ordered-rules model', (_Case c) {
      _counter.increment();
      final ManualGraveCheck actual = GraveRules.checkManual(
        rawName: c.rawName,
        year: c.year,
        month: c.month,
        day: c.day,
        today: c.today,
      );
      final Object expected = _model(c);
      if (expected is GraveRejection) {
        expect(actual, isA<ManualGraveRejected>());
        expect((actual as ManualGraveRejected).reason, expected);
      } else {
        final (String name, int y, int m, int d) =
            expected as (String, int, int, int);
        expect(actual, isA<ManualGraveAccepted>());
        final ManualGraveAccepted ok = actual as ManualGraveAccepted;
        expect(ok.name, name);
        expect(
          <int>[ok.dateOfDeath.year, ok.dateOfDeath.month, ok.dateOfDeath.day],
          <int>[y, m, d],
          reason: 'the date must be exact, never shifted',
        );
      }
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
