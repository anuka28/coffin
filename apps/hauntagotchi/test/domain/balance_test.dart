import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/balance.dart';
import 'package:hauntagotchi/src/domain/catch_up.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/habit_book.dart';
import 'package:hauntagotchi/src/domain/haunt_result.dart';
import 'package:hauntagotchi/src/domain/haunting.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';

/// Day 1 of the worked 14-day example.
final LocalDay _day1 = LocalDay(2026, 3, 1);

LocalDay _day(int n) => _day1.addDays(n - 1);

/// Four habits created on day 1, where `completed[i]` habits are done on day
/// `i + 1` (the first `c` habits each day).
HabitBook _book(List<int> completed) => HabitBook([
  for (int h = 0; h < 4; h++)
    Habit(
      id: 'h${h + 1}',
      name: 'h${h + 1}',
      createdDay: _day1,
      completedDays: {
        for (int i = 0; i < completed.length; i++)
          if (h < completed[i]) _day(i + 1),
      },
    ),
]);

Ghost _fresh(int health) =>
    Ghost(name: 'Wisp', health: health, lastSettledDay: _day(0));

void main() {
  test('constants have the designed values', () {
    expect(Balance.maxHealth, 100);
    expect(Balance.fullFeed, 20);
    expect(Balance.neglectLoss, 15);
    expect(Balance.freshStartHealth, 40);
    expect(Balance.candlesNeeded, 2);
    expect(Balance.qualifyingPercent, 60);
    expect(Balance.defaultGhostName, 'Wisp');
  });

  group('feed(n, c) table', () {
    const table = <int, List<int>>{
      1: [20],
      2: [10, 20],
      3: [6, 13, 20],
      4: [5, 10, 15, 20],
      5: [4, 8, 12, 16, 20],
    };
    table.forEach((n, values) {
      test('n=$n', () {
        final actual = [for (var c = 1; c <= n; c++) Balance.feed(n, c)];
        expect(actual, values);
      });
    });
  });

  group('worked 14-day example, 4 habits', () {
    test('feed per day is -15, +5, +10, +15, +20', () {
      expect(CatchUp.settleDay(50, 4, 0), 35);
      expect(CatchUp.settleDay(50, 4, 1), 55);
      expect(CatchUp.settleDay(50, 4, 2), 60);
      expect(CatchUp.settleDay(50, 4, 3), 65);
      expect(CatchUp.settleDay(50, 4, 4), 70);
    });

    test('track A: steady effort with two rough patches', () {
      const plan = <int>[4, 3, 0, 0, 3, 4, 3, 3, 4, 0, 0, 4, 4, 3];
      const expected = <int>[
        100, 100, 85, 70, 85, 100, 100, //
        100, 100, 85, 70, 90, 100, 100,
      ];
      final HabitBook book = _book(plan);

      // One catch-up per day, from the same starting ghost.
      for (int d = 1; d <= 14; d++) {
        final Ghost settled = CatchUp.run(_fresh(100), book, _day(d + 1));
        expect(settled.health, expected[d - 1], reason: 'day $d');
      }

      // Day by day, carrying the ghost forward.
      Ghost ghost = _fresh(100);
      for (int d = 1; d <= 14; d++) {
        ghost = CatchUp.run(ghost, book, _day(d + 1));
        expect(ghost.health, expected[d - 1], reason: 'carried day $d');
      }

      final int lowest = expected.reduce((a, b) => a < b ? a : b);
      expect(lowest, 70);
    });

    test('track B: a week away, then the ritual', () {
      // Days 1 to 7 are untouched. Day 8 is opened and two habits are done.
      const away = <int>[0, 0, 0, 0, 0, 0, 0];
      const awayHealth = <int>[85, 70, 55, 40, 25, 10, 0];
      final HabitBook awayBook = _book(away);
      for (int d = 1; d <= 7; d++) {
        final Ghost g = CatchUp.run(_fresh(100), awayBook, _day(d + 1));
        expect(g.health, awayHealth[d - 1], reason: 'day $d');
      }

      // One catch-up equals seven single-day catch-ups.
      Ghost single = _fresh(100);
      for (int d = 1; d <= 7; d++) {
        single = CatchUp.run(single, awayBook, _day(d + 1));
      }
      expect(CatchUp.run(_fresh(100), awayBook, _day(8)).health, single.health);

      // Day 8: the app opens, the ghost is gone, two candles bring it back.
      final Haunting opened = Haunting.open(
        book: awayBook,
        ghost: _fresh(100),
        today: _day(8),
      );
      expect(opened.ghost.health, 0);
      expect(opened.liveHealth, 0);

      final HauntResult first = opened.complete('h1');
      expect((first as HauntChanged).resurrected, isFalse);
      final HauntResult second = first.next.complete('h2');
      expect((second as HauntChanged).resurrected, isTrue);
      final Haunting revived = second.next;
      expect(revived.ghost.health, 40);
      expect(revived.ghost.resurrectionCount, 1);
      expect(revived.liveHealth, 50);

      // Days 8 to 14 continue from the revived ghost.
      const plan = <int>[0, 0, 0, 0, 0, 0, 0, 2, 4, 3, 0, 4, 3, 4];
      const expected = <int>[50, 70, 85, 70, 90, 100, 100];
      final HabitBook book = _book(plan);
      Ghost ghost = revived.ghost;
      for (int d = 8; d <= 14; d++) {
        ghost = CatchUp.run(ghost, book, _day(d + 1));
        expect(ghost.health, expected[d - 8], reason: 'day $d');
      }
    });
  });
}
