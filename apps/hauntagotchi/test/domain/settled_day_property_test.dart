// Feature: hauntagotchi-core, Property 9: A settled day depends only on the habits active that day
// Validates: Requirements 4.8, 4.9
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart'
    show equals, expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:hauntagotchi/src/domain/catch_up.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/habit_book.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';

import 'support/haunt_generators.dart';

const int _numRuns = 200;
final RunCounter _dayRuns = RunCounter();
final RunCounter _laterRuns = RunCounter();
final RunCounter _emptyRuns = RunCounter();

/// A book and a ghost settled through the day before [day]. Catching up on
/// [today] (the day after [day]) settles exactly [day].
final class _Scenario {
  const _Scenario(this.today, this.book, this.ghost);

  final LocalDay today;
  final HabitBook book;
  final Ghost ghost;

  /// The past day that the catch-up settles.
  LocalDay get day => today.previous;

  @override
  String toString() =>
      'today=${today.toIso()}, ghost=$ghost, habits=${book.all.length}';
}

Generator<_Scenario> get _anyScenario => any.simple<_Scenario>(
  generate: (math.Random random, int size) {
    final LocalDay today = anyLocalDay(random, size).value;
    final HabitBook book = anyBook(today)(random, size).value;
    final Ghost g = anyGhost(today)(random, size).value;
    return _Scenario(
      today,
      book,
      Ghost(
        name: g.name,
        // A dead ghost only advances its day, so keep the ghost alive.
        health: g.health == 0 ? 1 : g.health,
        lastSettledDay: today.addDays(-2),
        resurrectionCount: g.resurrectionCount,
      ),
    );
  },
  shrink: (_Scenario s) sync* {
    if (s.book.all.isNotEmpty) {
      yield _Scenario(
        s.today,
        HabitBook(s.book.all.take(s.book.all.length - 1)),
        s.ghost,
      );
    }
  },
);

/// The same book after later edits: every active habit is archived on
/// [today], and two new habits are created on [today] and completed on it.
HabitBook _editedLater(HabitBook book, LocalDay today) => HabitBook(<Habit>[
  for (final Habit h in book.all)
    h.isActive ? h.copyWith(archivedDay: today) : h,
  Habit(
    id: 'x1',
    name: 'Late',
    createdDay: today,
    completedDays: <LocalDay>{today},
  ),
  Habit(id: 'x2', name: 'Later', createdDay: today.next),
]);

void main() {
  group('Property 9: a settled day depends only on the habits active then', () {
    Glados(_anyScenario, ExploreConfig(numRuns: _numRuns)).test(
      'catch-up over one day equals settleDay on that day\'s counts',
      (_Scenario s) {
        _dayRuns.increment();
        final int active = s.book.activeCountOn(s.day);
        final int done = s.book.completedCountOn(s.day);
        final Ghost out = CatchUp.run(s.ghost, s.book, s.today);
        expect(
          out.health,
          equals(CatchUp.settleDay(s.ghost.health, active, done)),
        );
        expect(out.lastSettledDay, equals(s.day));
      },
    );

    Glados(_anyScenario, ExploreConfig(numRuns: _numRuns)).test(
      'archiving or adding habits later does not change the settled day',
      (_Scenario s) {
        _laterRuns.increment();
        final HabitBook later = _editedLater(s.book, s.today);
        expect(later.activeCountOn(s.day), equals(s.book.activeCountOn(s.day)));
        expect(
          later.completedCountOn(s.day),
          equals(s.book.completedCountOn(s.day)),
        );
        expect(
          CatchUp.run(s.ghost, later, s.today),
          equals(CatchUp.run(s.ghost, s.book, s.today)),
        );
      },
    );

    Glados(_anyScenario, ExploreConfig(numRuns: _numRuns)).test(
      'a day with no active habit leaves Health unchanged',
      (_Scenario s) {
        _emptyRuns.increment();
        final HabitBook none = HabitBook(
          s.book.all.where((Habit h) => !h.isActiveOn(s.day)),
        );
        expect(none.activeCountOn(s.day), equals(0));
        expect(
          CatchUp.run(s.ghost, none, s.today).health,
          equals(s.ghost.health),
        );
      },
    );

    test('the property bodies ran numRuns times', () {
      _dayRuns.expectRuns(_numRuns);
      _laterRuns.expectRuns(_numRuns);
      _emptyRuns.expectRuns(_numRuns);
    });
  });
}
