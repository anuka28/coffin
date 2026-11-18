// Feature: hauntagotchi-core, Property 3: Time of day does not matter
// Validates: Requirements 2.2, 2.5, 14.4
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart'
    show equals, expect, group, isNot, test;
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:hauntagotchi/src/domain/catch_up.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit_book.dart';
import 'package:hauntagotchi/src/domain/haunting.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';

import 'support/haunt_generators.dart';

const int _numRuns = 200;
final RunCounter _runs = RunCounter();

/// One calendar date, two times on it, and a ghost and book that are a gap of
/// days behind that date.
final class _Scenario {
  const _Scenario(this.date, this.first, this.second, this.book, this.ghost);

  final LocalDay date;
  final DateTime first;
  final DateTime second;
  final HabitBook book;
  final Ghost ghost;

  @override
  String toString() =>
      'first=$first, second=$second, ghost=$ghost, habits=${book.all.length}';
}

DateTime _timeOn(LocalDay d, math.Random random, int size) => DateTime(
  d.year,
  d.month,
  d.day,
  anyIntBetween(0, 24)(random, size).value,
  anyIntBetween(0, 60)(random, size).value,
  anyIntBetween(0, 60)(random, size).value,
  anyIntBetween(0, 1000)(random, size).value,
);

final Generator<_Scenario> _anyScenario = any.simple<_Scenario>(
  generate: (math.Random random, int size) {
    final LocalDay date = anyLocalDay(random, size).value;
    return _Scenario(
      date,
      _timeOn(date, random, size),
      _timeOn(date, random, size),
      anyBook(date)(random, size).value,
      anyGhost(date)(random, size).value,
    );
  },
  shrink: (_Scenario s) sync* {
    if (s.first != DateTime(s.date.year, s.date.month, s.date.day)) {
      yield _Scenario(
        s.date,
        DateTime(s.date.year, s.date.month, s.date.day),
        s.second,
        s.book,
        s.ghost,
      );
    }
  },
);

void main() {
  group('Property 3: time of day does not matter', () {
    Glados(
      _anyScenario,
      ExploreConfig(numRuns: _numRuns),
    ).test('two times on one date give the same day, ghost and Health', (
      _Scenario s,
    ) {
      _runs.increment();
      final LocalDay a = LocalDay.fromDateTime(s.first);
      final LocalDay b = LocalDay.fromDateTime(s.second);
      expect(a, equals(s.date));
      expect(b, equals(a));

      final Haunting ha = Haunting.open(book: s.book, ghost: s.ghost, today: a);
      final Haunting hb = Haunting.open(book: s.book, ghost: s.ghost, today: b);
      expect(hb.today, equals(ha.today));
      expect(hb.ghost, equals(ha.ghost));
      expect(hb.ghost.health, equals(ha.ghost.health));
      expect(hb.liveHealth, equals(ha.liveHealth));
      expect(hb.state, equals(ha.state));

      final Haunting synced = Haunting(
        book: s.book,
        ghost: s.ghost,
        today: s.ghost.lastSettledDay,
      ).syncTo(b);
      expect(synced.ghost, equals(ha.ghost));
      expect(
        CatchUp.run(s.ghost, s.book, b),
        equals(CatchUp.run(s.ghost, s.book, a)),
      );
    });

    test('a time on the next date gives a different day', () {
      final LocalDay d = LocalDay(2026, 3, 8);
      expect(
        LocalDay.fromDateTime(DateTime(2026, 3, 8, 23, 59, 59)),
        isNot(equals(LocalDay.fromDateTime(DateTime(2026, 3, 9)))),
      );
      expect(LocalDay.fromDateTime(DateTime(2026, 3, 8, 0, 0)), equals(d));
    });

    test('the property body ran numRuns times', () {
      _runs.expectRuns(_numRuns);
    });
  });
}
