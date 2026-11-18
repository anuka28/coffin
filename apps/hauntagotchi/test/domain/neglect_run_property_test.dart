// Feature: hauntagotchi-core, Property 12: A neglect run from full Health
// Validates: Requirements 5.5

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart'
    show equals, expect, group, isFalse, isTrue, test;
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:hauntagotchi/src/domain/balance.dart';
import 'package:hauntagotchi/src/domain/catch_up.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/habit_book.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';

import 'support/haunt_generators.dart';

const int _numRuns = 200;

final RunCounter _settleRuns = RunCounter();
final RunCounter _catchUpRuns = RunCounter();

/// A neglect run: [activeCount] habits created on [start], none ever
/// completed, and [days] finished days after [start] to settle.
final class _Run {
  const _Run(this.start, this.activeCount, this.days);

  final LocalDay start;
  final int activeCount;
  final int days;

  /// The first day the clock shows: the last neglect day is yesterday.
  LocalDay get today => start.addDays(days + 1);

  HabitBook get book => HabitBook(<Habit>[
    for (int i = 1; i <= activeCount; i++)
      Habit(id: 'h$i', name: 'Habit $i', createdDay: start),
  ]);

  Ghost get fullGhost =>
      Ghost(name: 'Wisp', health: Balance.maxHealth, lastSettledDay: start);

  int get expectedHealth {
    final int h = Balance.maxHealth - Balance.neglectLoss * days;
    return h < 0 ? 0 : h;
  }

  @override
  String toString() =>
      'start=${start.toIso()}, activeCount=$activeCount, days=$days';
}

/// Start day, 1 to 5 active habits and a run of 0 to 10 neglect days.
Generator<_Run> get _anyRun => any.simple<_Run>(
  generate: (math.Random random, int size) => _Run(
    anyLocalDay(random, size).value,
    anyIntBetween(1, HabitBook.maxActive + 1)(random, size).value,
    anyIntBetween(0, 11)(random, size).value,
  ),
  shrink: (_Run r) sync* {
    if (r.days > 0) yield _Run(r.start, r.activeCount, r.days ~/ 2);
    if (r.activeCount > 1) yield _Run(r.start, 1, r.days);
  },
);

void main() {
  group('Property 12: a neglect run from full Health', () {
    Glados(_anyRun, ExploreConfig(numRuns: _numRuns)).test(
      'settleDay applied k times gives max(0, 100 - 15k)',
      (_Run r) {
        _settleRuns.increment();
        int health = Balance.maxHealth;
        for (int day = 1; day <= r.days; day++) {
          health = CatchUp.settleDay(health, r.activeCount, 0);
          final int expected = Balance.maxHealth - 15 * day;
          expect(health, equals(expected < 0 ? 0 : expected));
        }
        expect(health, equals(r.expectedHealth));
        if (r.days <= 3) expect(health > 0, isTrue);
        if (r.days >= 7) expect(health, equals(0));
      },
    );

    Glados(_anyRun, ExploreConfig(numRuns: _numRuns)).test(
      'CatchUp.run over k never-completed days gives max(0, 100 - 15k)',
      (_Run r) {
        _catchUpRuns.increment();
        final Ghost settled = CatchUp.run(r.fullGhost, r.book, r.today);
        expect(settled.health, equals(r.expectedHealth));
        expect(settled.lastSettledDay, equals(r.today.previous));
        if (r.days <= 3) expect(settled.health > 0, isTrue);
        if (r.days >= 7) expect(settled.health == 0, isTrue);
        if (r.days >= 1 && r.days <= 3) {
          expect(settled.health, equals(100 - 15 * r.days));
        }
        expect(settled.health == 0 && r.days < 7, isFalse);
      },
    );

    test('the property bodies ran numRuns times', () {
      _settleRuns.expectRuns(_numRuns);
      _catchUpRuns.expectRuns(_numRuns);
    });
  });
}
