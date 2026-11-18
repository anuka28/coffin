// Feature: hauntagotchi-core, Property 8: Catch-up is a no-op when nothing is missed
// Validates: Requirements 4.3, 4.6
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart'
    show equals, expect, greaterThanOrEqualTo, group, test;
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:hauntagotchi/src/domain/catch_up.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit_book.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';

import 'support/haunt_generators.dart';

const int _numRuns = 200;
final RunCounter _currentRuns = RunCounter();
final RunCounter _backwardRuns = RunCounter();

/// Today, a book, and a ghost whose last settled day is [lead] days at or
/// after yesterday.
final class _Scenario {
  const _Scenario(this.today, this.book, this.ghost, this.lead);

  final LocalDay today;
  final HabitBook book;

  /// The ghost, already settled through [today] minus 1 plus [lead] days.
  final Ghost ghost;

  /// Days from yesterday to the ghost's last settled day.
  final int lead;

  @override
  String toString() =>
      'today=${today.toIso()}, ghost=$ghost, habits=${book.all.length}, '
      'lead=$lead';
}

Ghost _settledAt(Ghost g, LocalDay day) => Ghost(
  name: g.name,
  health: g.health,
  lastSettledDay: day,
  resurrectionCount: g.resurrectionCount,
);

/// [maxLead] is exclusive; 1 gives only the "already current" case.
Generator<_Scenario> _anyScenario(int minLead, int maxLead) =>
    any.simple<_Scenario>(
      generate: (math.Random random, int size) {
        final LocalDay today = anyLocalDay(random, size).value;
        final HabitBook book = anyBook(today)(random, size).value;
        final int lead = anyIntBetween(minLead, maxLead)(random, size).value;
        final Ghost ghost = _settledAt(
          anyGhost(today)(random, size).value,
          today.previous.addDays(lead),
        );
        return _Scenario(today, book, ghost, lead);
      },
      shrink: (_Scenario s) sync* {
        if (s.lead > 0) {
          yield _Scenario(
            s.today,
            s.book,
            _settledAt(s.ghost, s.today.previous),
            0,
          );
        }
      },
    );

void main() {
  group('Property 8: catch-up is a no-op when nothing is missed', () {
    Glados(_anyScenario(0, 1), ExploreConfig(numRuns: _numRuns)).test(
      'a ghost settled through yesterday is returned unchanged',
      (_Scenario s) {
        _currentRuns.increment();
        expect(s.ghost.lastSettledDay, equals(s.today.previous));
        expect(CatchUp.run(s.ghost, s.book, s.today), equals(s.ghost));
      },
    );

    Glados(_anyScenario(0, 401), ExploreConfig(numRuns: _numRuns)).test(
      'a clock that moved backward returns the ghost unchanged, no error',
      (_Scenario s) {
        _backwardRuns.increment();
        expect(
          s.ghost.lastSettledDay.compareTo(s.today.previous),
          greaterThanOrEqualTo(0),
        );
        expect(CatchUp.run(s.ghost, s.book, s.today), equals(s.ghost));
      },
    );

    test('the property bodies ran numRuns times', () {
      _currentRuns.expectRuns(_numRuns);
      _backwardRuns.expectRuns(_numRuns);
    });
  });
}
