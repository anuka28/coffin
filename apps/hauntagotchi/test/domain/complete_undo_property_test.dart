// Feature: hauntagotchi-core, Property 11: Complete then undo restores the day
// Validates: Requirements 1.7, 1.9, 1.12, 5.2, 7.6
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart'
    show equals, expect, group, isA, isNotEmpty, test;
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/habit_result.dart';
import 'package:hauntagotchi/src/domain/haunt_result.dart';
import 'package:hauntagotchi/src/domain/haunting.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';

import 'support/haunt_generators.dart';

const int _numRuns = 200;
final RunCounter _runs = RunCounter();

/// A haunting opened on a day, and which active habit to tick.
final class _Scenario {
  const _Scenario(this.haunting, this.pick);

  final Haunting haunting;
  final int pick;

  @override
  String toString() =>
      'today=${haunting.today}, health=${haunting.ghost.health}, '
      'habits=${haunting.book.all.length}, pick=$pick';
}

/// Draws a day, then a book and a ghost around it, and opens the haunting.
final Generator<_Scenario> _anyScenario = any.simple<_Scenario>(
  generate: (math.Random random, int size) {
    final LocalDay today = anyLocalDay(random, size).value;
    return _Scenario(
      Haunting.open(
        book: anyBook(today)(random, size).value,
        ghost: anyGhost(today)(random, size).value,
        today: today,
      ),
      random.nextInt(5),
    );
  },
  shrink: (_Scenario s) sync* {
    if (s.pick > 0) yield _Scenario(s.haunting, 0);
  },
);

/// Returns [h] changed so that at least one active habit is not completed
/// today, and that habit's id (chosen by [pick]).
(Haunting, String) _withOpenHabit(Haunting h, int pick) {
  Haunting base = h;
  if (base.book.activeCount == 0) {
    final HauntResult added = base.addHabit('Light a candle');
    base = (added as HauntChanged).next;
  }
  List<Habit> open = base.book.active
      .where((Habit x) => !x.isCompletedOn(base.today))
      .toList();
  if (open.isEmpty) {
    // Every active habit is ticked: clear the first one directly in the book.
    final HabitResult undone = base.book.undo(
      base.book.active.first.id,
      base.today,
      today: base.today,
    );
    base = Haunting(
      book: (undone as HabitChanged).book,
      ghost: base.ghost,
      today: base.today,
    );
    open = base.book.active
        .where((Habit x) => !x.isCompletedOn(base.today))
        .toList();
  }
  return (base, open[pick % open.length].id);
}

void main() {
  group('Property 11: Complete then undo restores the day', () {
    Glados(_anyScenario, ExploreConfig(numRuns: _numRuns)).test(
      'undo after complete restores habits, Live_Health and Streak',
      (_Scenario s) {
        _runs.increment();
        final (Haunting before, String id) = _withOpenHabit(s.haunting, s.pick);
        final bool otherDoneToday = before.book.anyCompletedOn(before.today);

        final HauntResult done = before.complete(id);
        expect(done, isA<HauntChanged>(), reason: '$s');
        final HauntChanged completed = done as HauntChanged;
        // A tick never lowers Health or the Streak.
        expect(
          completed.next.liveHealth >= before.liveHealth,
          equals(true),
          reason: 'complete must not lower Live_Health: $s',
        );
        expect(
          completed.next.streak >= before.streak,
          equals(true),
          reason: 'complete must not lower the Streak: $s',
        );
        if (!otherDoneToday) {
          expect(
            completed.next.streak,
            equals(before.streak + 1),
            reason: 'a first tick today adds today to the Streak: $s',
          );
        }

        final HauntResult undone = completed.next.undo(id);
        expect(undone, isA<HauntChanged>(), reason: '$s');
        final Haunting after = (undone as HauntChanged).next;

        // 1.12: the habits are equal again.
        expect(after.book.all, isNotEmpty, reason: '$s');
        expect(after.book.all, equals(before.book.all), reason: '$s');
        expect(after.today, equals(before.today), reason: '$s');
        // 5.2, 7.6: a ghost revived by the ritual stays revived, so the
        // Health and ghost comparison applies to every other run.
        if (!completed.resurrected) {
          expect(after.ghost, equals(before.ghost), reason: '$s');
          expect(after.liveHealth, equals(before.liveHealth), reason: '$s');
          expect(after.state, equals(before.state), reason: '$s');
        }
        expect(after.streak, equals(before.streak), reason: '$s');
      },
    );

    test('the property body ran numRuns times', () {
      _runs.expectRuns(_numRuns);
      expect(_numRuns, equals(200));
    });
  });
}
