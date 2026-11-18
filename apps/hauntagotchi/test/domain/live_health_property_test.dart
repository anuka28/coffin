// Feature: hauntagotchi-core, Property 23: Live Health is what the next day settles
// Validates: Requirements 4.2, 5.1, 5.2
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart'
    show equals, expect, group, greaterThan, isA, test;
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:hauntagotchi/src/domain/balance.dart';
import 'package:hauntagotchi/src/domain/catch_up.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/habit_result.dart';
import 'package:hauntagotchi/src/domain/haunt_result.dart';
import 'package:hauntagotchi/src/domain/haunting.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';

import 'support/haunt_generators.dart';

const int _numRuns = 200;
final RunCounter _runs = RunCounter();

/// A living haunting settled through yesterday, and which habit to tick.
final class _Scenario {
  const _Scenario(this.haunting, this.pick);

  final Haunting haunting;
  final int pick;

  @override
  String toString() =>
      'today=${haunting.today}, health=${haunting.ghost.health}, '
      'active=${haunting.book.activeCount}, '
      'done=${haunting.book.completedCountOn(haunting.today)}, pick=$pick';
}

/// Draws a day and a book, then a living ghost settled through yesterday.
final Generator<_Scenario> _anyScenario = any.simple<_Scenario>(
  generate: (math.Random random, int size) {
    final LocalDay today = anyLocalDay(random, size).value;
    final int health = 1 + random.nextInt(Balance.maxHealth);
    return _Scenario(
      Haunting(
        book: anyBook(today)(random, size).value,
        ghost: Ghost(
          name: 'Wisp',
          health: health,
          lastSettledDay: today.previous,
        ),
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
    base = (base.addHabit('Light a candle') as HauntChanged).next;
  }
  List<Habit> open = base.book.active
      .where((Habit x) => !x.isCompletedOn(base.today))
      .toList();
  if (open.isEmpty) {
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
  group('Property 23: Live Health is what the next day settles', () {
    Glados(_anyScenario, ExploreConfig(numRuns: _numRuns)).test(
      'liveHealth is min(100, health + feed) and equals the settled day',
      (_Scenario s) {
        _runs.increment();
        final Haunting h = s.haunting;
        final int n = h.book.activeCountOn(h.today);
        final int c = h.book.completedCountOn(h.today);
        final int health = h.ghost.health;

        final int expected = math.min(
          Balance.maxHealth,
          health + Balance.feed(n, c),
        );
        expect(h.liveHealth, equals(expected), reason: '$s');

        if (c > 0) {
          expect(
            h.liveHealth,
            equals(CatchUp.settleDay(health, n, c)),
            reason: 'settleDay must agree: $s',
          );
          // The next day settles today with the same counts.
          final Ghost settled = CatchUp.run(h.ghost, h.book, h.today.next);
          expect(settled.health, equals(h.liveHealth), reason: '$s');
        } else {
          expect(h.liveHealth, equals(health), reason: 'no tick, no feed: $s');
        }

        // Complete raises Live_Health (unless full); undo restores it.
        final (Haunting before, String id) = _withOpenHabit(h, s.pick);
        final HauntResult done = before.complete(id);
        expect(done, isA<HauntChanged>(), reason: '$s');
        final Haunting ticked = (done as HauntChanged).next;
        if (before.liveHealth < Balance.maxHealth) {
          expect(
            ticked.liveHealth,
            greaterThan(before.liveHealth),
            reason: 'a tick must raise Live_Health: $s',
          );
        } else {
          expect(ticked.liveHealth, equals(Balance.maxHealth), reason: '$s');
        }

        final HauntResult undone = ticked.undo(id);
        expect(undone, isA<HauntChanged>(), reason: '$s');
        expect(
          (undone as HauntChanged).next.liveHealth,
          equals(before.liveHealth),
          reason: 'undo must restore Live_Health: $s',
        );
      },
    );

    test('the property body ran numRuns times', () {
      _runs.expectRuns(_numRuns);
      expect(_numRuns, equals(200));
    });
  });
}
