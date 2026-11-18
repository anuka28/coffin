// Feature: hauntagotchi-core, Property 2: Calendar arithmetic counts calendar days
// Validates: Requirements 2.3, 2.4, 14.5

import 'package:flutter_test/flutter_test.dart' show equals, expect, group;
import 'package:glados/glados.dart' hide expect, group;
import 'package:hauntagotchi/src/domain/balance.dart';
import 'package:hauntagotchi/src/domain/catch_up.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/habit_book.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';

import 'support/haunt_generators.dart';

const int _numRuns = 200;

/// Largest step count `n` the properties draw (inclusive).
const int _maxSteps = 800;

/// The four daylight saving change dates of 2026.
final List<LocalDay> _dstDays = <LocalDay>[
  LocalDay(2026, 3, 8),
  LocalDay(2026, 3, 29),
  LocalDay(2026, 10, 25),
  LocalDay(2026, 11, 1),
];

final RunCounter _addRuns = RunCounter();
final RunCounter _dstRuns = RunCounter();
final RunCounter _catchUpRuns = RunCounter();

/// Checks that [d] plus [n] days is counted as [n] calendar days.
void _expectCalendarDays(LocalDay d, int n) {
  final LocalDay end = d.addDays(n);
  expect(d.daysUntil(end), equals(n));
  expect(end.daysUntil(d), equals(-n));

  LocalDay stepped = d;
  for (int i = 0; i < n; i++) {
    stepped = stepped.next;
  }
  expect(stepped, equals(end));

  // Independent oracle: the platform calendar, which carries the day
  // overflow in local time and so passes through the daylight saving change.
  final DateTime viaDateTime = DateTime(d.year, d.month, d.day + n);
  expect(LocalDay.fromDateTime(viaDateTime), equals(end));
}

/// Settles the span after [start] with one habit that is done on the days of
/// [start] + i + 1 whose bit `i % 20` is set in [pattern], and checks the
/// result against a day-by-day fold that counts each day once.
void _expectEachDaySettledOnce(
  LocalDay start,
  int n,
  int pattern,
  int startHealth,
) {
  final Set<LocalDay> done = <LocalDay>{
    for (int i = 0; i < n; i++)
      if (((pattern >> (i % 20)) & 1) == 1) start.addDays(i + 1),
  };
  final HabitBook book = HabitBook(<Habit>[
    Habit(
      id: 'h1',
      name: 'Light a candle',
      createdDay: start,
      completedDays: done,
    ),
  ]);
  final Ghost ghost = Ghost(
    name: 'Wisp',
    health: startHealth,
    lastSettledDay: start,
  );

  final Ghost settled = CatchUp.run(ghost, book, start.addDays(n + 1));

  int expected = startHealth;
  for (int i = 1; i <= n && expected > 0; i++) {
    final LocalDay day = start.addDays(i);
    expected = CatchUp.settleDay(
      expected,
      book.activeCountOn(day),
      book.completedCountOn(day),
    );
  }
  expect(settled.health, equals(expected));
  expect(settled.lastSettledDay, equals(start.addDays(n)));

  // A second catch-up to the same day settles nothing more.
  expect(CatchUp.run(settled, book, start.addDays(n + 1)), equals(settled));
  expect(settled.health <= Balance.maxHealth, equals(true));
}

void main() {
  group('Calendar arithmetic counts calendar days (Property 2)', () {
    Glados2(
      anyLocalDay,
      anyIntBetween(0, _maxSteps + 1),
      ExploreConfig(numRuns: _numRuns),
    ).test('addDays, daysUntil and next agree for any day and n', (
      LocalDay d,
      int n,
    ) {
      _addRuns.increment();
      _expectCalendarDays(d, n);
    });

    Glados2(
      anyIntBetween(0, _dstDays.length),
      anyIntBetween(0, _maxSteps + 1),
      ExploreConfig(numRuns: _numRuns),
    ).test('the daylight saving dates count calendar days', (int index, int n) {
      _dstRuns.increment();
      final LocalDay d = _dstDays[index];
      _expectCalendarDays(d, n);
      // Walk across the change date itself, one day each side.
      expect(d.previous.daysUntil(d.next), equals(2));
    });

    Glados3(
      anyLocalDay,
      anyIntBetween(0, _maxSteps + 1),
      anyIntBetween(0, 1 << 20),
      ExploreConfig(numRuns: _numRuns),
    ).test('a catch-up over the span settles each day once', (
      LocalDay d,
      int n,
      int pattern,
    ) {
      _catchUpRuns.increment();
      _expectEachDaySettledOnce(d, n, pattern, Balance.maxHealth);
    });

    test('every property body ran numRuns times', () {
      _addRuns.expectRuns(_numRuns);
      _dstRuns.expectRuns(_numRuns);
      _catchUpRuns.expectRuns(_numRuns);
    });
  });
}
