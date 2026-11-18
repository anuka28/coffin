import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/balance.dart';
import 'package:hauntagotchi/src/domain/catch_up.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/habit_book.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';

void main() {
  final LocalDay today = LocalDay(2025, 6, 15);
  final LocalDay longAgo = LocalDay(2000, 1, 1);

  HabitBook bookOf(List<Habit> habits) => HabitBook(habits);

  Ghost ghostAt(int health, LocalDay settled, {int count = 0}) => Ghost(
    name: 'Boo',
    health: health,
    lastSettledDay: settled,
    resurrectionCount: count,
  );

  group('CatchUp.run', () {
    test('fresh ghost (settled through yesterday) is a no-op', () {
      final Ghost fresh = Ghost.fresh(today);
      final HabitBook book = bookOf([
        Habit(id: 'h1', name: 'Walk', createdDay: longAgo),
      ]);
      expect(CatchUp.run(fresh, book, today), fresh);
    });

    test('5 days away equals 5 single-day catch-ups', () {
      final LocalDay start = today.addDays(-6);
      final HabitBook book = bookOf([
        Habit(
          id: 'h1',
          name: 'Walk',
          createdDay: longAgo,
          completedDays: {start.addDays(2), start.addDays(4)},
        ),
        Habit(id: 'h2', name: 'Read', createdDay: longAgo),
      ]);
      final Ghost away = ghostAt(60, start, count: 2);

      final Ghost bulk = CatchUp.run(away, book, today);

      Ghost stepped = away;
      for (var i = 1; i <= 5; i++) {
        stepped = CatchUp.run(stepped, book, start.addDays(i + 1));
      }
      expect(bulk, stepped);
      expect(bulk.lastSettledDay, today.previous);
      expect(bulk.name, 'Boo');
      expect(bulk.resurrectionCount, 2);
    });

    test('10,000 days away finishes with Health within 0..100', () {
      final HabitBook book = bookOf([
        Habit(id: 'h1', name: 'Walk', createdDay: longAgo),
      ]);
      final Ghost result = CatchUp.run(
        ghostAt(100, today.addDays(-10000)),
        book,
        today,
      );
      expect(result.health, inInclusiveRange(0, 100));
      expect(result.lastSettledDay, today.previous);
    });

    test('10,000 days away with every day completed stays at 100', () {
      final LocalDay start = today.addDays(-10000);
      final Set<LocalDay> all = {
        for (var i = 1; i < 10000; i++) start.addDays(i),
      };
      final HabitBook book = bookOf([
        Habit(id: 'h1', name: 'Walk', createdDay: longAgo, completedDays: all),
      ]);
      final Ghost result = CatchUp.run(ghostAt(50, start), book, today);
      expect(result.health, 100);
    });

    test('a clock that moved backward leaves the ghost unchanged', () {
      final Ghost ghost = ghostAt(70, today.addDays(3));
      final HabitBook book = bookOf([
        Habit(id: 'h1', name: 'Walk', createdDay: longAgo),
      ]);
      expect(CatchUp.run(ghost, book, today), ghost);
    });

    test('no active habit leaves Health unchanged but advances the day', () {
      final Ghost ghost = ghostAt(70, today.addDays(-20));
      final Ghost result = CatchUp.run(ghost, bookOf([]), today);
      expect(result.health, 70);
      expect(result.lastSettledDay, today.previous);
    });

    test('a dead ghost only advances lastSettledDay', () {
      final Ghost dead = ghostAt(0, today.addDays(-9), count: 1);
      final LocalDay start = today.addDays(-9);
      final HabitBook book = bookOf([
        Habit(
          id: 'h1',
          name: 'Walk',
          createdDay: longAgo,
          completedDays: {for (var i = 1; i < 9; i++) start.addDays(i)},
        ),
      ]);
      final Ghost result = CatchUp.run(dead, book, today);
      expect(result.health, 0);
      expect(result.isDead, isTrue);
      expect(result.name, 'Boo');
      expect(result.resurrectionCount, 1);
      expect(result.lastSettledDay, today.previous);
    });

    test('neglect drops a living ghost to 0 and stops there', () {
      final HabitBook book = bookOf([
        Habit(id: 'h1', name: 'Walk', createdDay: longAgo),
      ]);
      final Ghost result = CatchUp.run(
        ghostAt(30, today.addDays(-30)),
        book,
        today,
      );
      expect(result.health, 0);
      expect(result.lastSettledDay, today.previous);
    });

    test('settles each day with the habits active on that day', () {
      final LocalDay start = today.addDays(-4); // settles start+1 .. today-1
      final LocalDay archiveDay = start.addDays(3);
      final Habit keeper = Habit(
        id: 'h1',
        name: 'Walk',
        createdDay: longAgo,
        completedDays: {for (var i = 1; i <= 3; i++) start.addDays(i)},
      );
      final Habit archived = Habit(
        id: 'h2',
        name: 'Read',
        createdDay: longAgo,
        archivedDay: archiveDay,
      );

      final Ghost result = CatchUp.run(
        ghostAt(50, start),
        bookOf([keeper, archived]),
        today,
      );

      // start+1, start+2: 2 active, 1 done. start+3: 1 active, 1 done.
      var expected = 50;
      expected = CatchUp.settleDay(expected, 2, 1);
      expected = CatchUp.settleDay(expected, 2, 1);
      expected = CatchUp.settleDay(expected, 1, 1);
      expect(result.health, expected);
      expect(expected, 50 + 10 + 10 + 20);
    });

    test('archiving later does not change earlier days', () {
      final LocalDay start = today.addDays(-5);
      final Habit keeper = Habit(
        id: 'h1',
        name: 'Walk',
        createdDay: longAgo,
        completedDays: {start.addDays(1), start.addDays(2)},
      );
      final Habit extra = Habit(id: 'h2', name: 'Read', createdDay: longAgo);
      final Habit extraArchived = extra.copyWith(archivedDay: today);

      // Settling through yesterday: the archive on [today] is not yet felt.
      final Ghost before = CatchUp.run(
        ghostAt(80, start),
        bookOf([keeper, extra]),
        today,
      );
      final Ghost after = CatchUp.run(
        ghostAt(80, start),
        bookOf([keeper, extraArchived]),
        today,
      );
      expect(after, before);
    });
  });

  group('CatchUp.settleDay', () {
    test('no active habit leaves Health unchanged', () {
      expect(CatchUp.settleDay(55, 0, 0), 55);
    });

    test('no completion removes the neglect loss', () {
      expect(CatchUp.settleDay(55, 3, 0), 55 - Balance.neglectLoss);
    });

    test('partial completion adds a share of the full feed', () {
      expect(CatchUp.settleDay(50, 3, 1), 50 + Balance.feed(3, 1));
      expect(CatchUp.settleDay(50, 3, 1), 56);
    });

    test('full completion adds the full feed', () {
      expect(CatchUp.settleDay(50, 4, 4), 50 + Balance.fullFeed);
    });

    test('clamps at 0', () {
      expect(CatchUp.settleDay(5, 2, 0), 0);
      expect(CatchUp.settleDay(0, 2, 0), 0);
    });

    test('clamps at 100', () {
      expect(CatchUp.settleDay(95, 2, 2), 100);
      expect(CatchUp.settleDay(100, 2, 1), 100);
    });
  });
}
