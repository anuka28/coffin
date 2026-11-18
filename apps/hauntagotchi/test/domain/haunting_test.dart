import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/ghost_state.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/habit_book.dart';
import 'package:hauntagotchi/src/domain/haunt_result.dart';
import 'package:hauntagotchi/src/domain/haunting.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';

final LocalDay _today = LocalDay(2026, 3, 10);

Habit _habit(String id, {Set<LocalDay> done = const <LocalDay>{}}) => Habit(
  id: id,
  name: id,
  createdDay: LocalDay(2026, 3, 1),
  completedDays: done,
);

Ghost _ghost(int health, {LocalDay? settled}) => Ghost(
  name: 'Wisp',
  health: health,
  lastSettledDay: settled ?? _today.previous,
);

Haunting _next(HauntResult result) => switch (result) {
  HauntChanged(:final next) => next,
  HauntRejected(:final reason) => fail('unexpected rejection: $reason'),
};

void main() {
  group('Haunting.open', () {
    test('creates a fresh ghost named Wisp at Health 100 when none exists', () {
      final Haunting h = Haunting.open(
        book: HabitBook(const <Habit>[]),
        today: _today,
      );
      expect(h.ghost.name, 'Wisp');
      expect(h.ghost.health, 100);
      expect(h.ghost.resurrectionCount, 0);
      expect(h.ghost.lastSettledDay, _today.previous);
      expect(h.today, _today);
    });

    test('keeps a given ghost and settles the missed days', () {
      final Haunting h = Haunting.open(
        book: HabitBook([_habit('a')]),
        ghost: _ghost(100, settled: _today.addDays(-3)),
        today: _today,
      );
      // Days -2 and -1 are neglect days: 100 - 30.
      expect(h.ghost.health, 70);
      expect(h.ghost.lastSettledDay, _today.previous);
    });
  });

  group('Haunting.syncTo', () {
    test('returns the same instance when the day is unchanged', () {
      final Haunting h = Haunting.open(
        book: HabitBook([_habit('a')]),
        ghost: _ghost(80),
        today: _today,
      );
      expect(identical(h.syncTo(_today), h), isTrue);
    });

    test('moves today and settles the finished day', () {
      final Haunting h = Haunting.open(
        book: HabitBook([_habit('a')]),
        ghost: _ghost(80),
        today: _today,
      );
      final Haunting later = h.syncTo(_today.next);
      expect(later.today, _today.next);
      expect(later.ghost.health, 65);
      expect(later.ghost.lastSettledDay, _today);
    });

    test('revives a dead ghost whose ritual is already met', () {
      final Haunting h = Haunting(
        book: HabitBook([
          _habit('a', done: {_today}),
          _habit('b', done: {_today}),
        ]),
        ghost: _ghost(0),
        today: _today,
      );
      final Haunting synced = h.syncTo(_today);
      expect(synced.ghost.health, 40);
      expect(synced.ghost.resurrectionCount, 1);
    });
  });

  group('Haunting.liveHealth', () {
    test('adds today\'s feed to the settled Health', () {
      final Haunting h = Haunting(
        book: HabitBook([
          _habit('a', done: {_today}),
          _habit('b', done: {_today}),
          _habit('c'),
          _habit('d'),
        ]),
        ghost: _ghost(50),
        today: _today,
      );
      expect(h.liveHealth, 60);
    });

    test('is the settled Health when nothing is done', () {
      final Haunting h = Haunting(
        book: HabitBook([_habit('a')]),
        ghost: _ghost(50),
        today: _today,
      );
      expect(h.liveHealth, 50);
    });

    test('never exceeds 100', () {
      final Haunting h = Haunting(
        book: HabitBook([
          _habit('a', done: {_today}),
        ]),
        ghost: _ghost(95),
        today: _today,
      );
      expect(h.liveHealth, 100);
    });

    test('is 0 for a dead ghost', () {
      final Haunting h = Haunting(
        book: HabitBook([
          _habit('a', done: {_today}),
        ]),
        ghost: _ghost(0),
        today: _today,
      );
      expect(h.liveHealth, 0);
    });
  });

  group('Haunting.state idle caps', () {
    Haunting at(int health, Set<LocalDay> done) => Haunting(
      book: HabitBook([_habit('a', done: done)]),
      ghost: _ghost(health),
      today: _today,
    );

    test('no idle days leaves the Health band', () {
      expect(at(90, {_today.previous}).state, GhostState.thriving);
    });

    test('one idle day caps at content', () {
      final Haunting h = at(90, {_today.addDays(-2)});
      expect(h.history.idleDays, 1);
      expect(h.state, GhostState.content);
    });

    test('three idle days cap at hungry', () {
      final Haunting h = at(90, {_today.addDays(-4)});
      expect(h.history.idleDays, 3);
      expect(h.state, GhostState.hungry);
    });

    test('a completion today clears the cap', () {
      final Haunting h = at(90, {_today});
      expect(h.history.idleDays, 0);
      expect(h.state, GhostState.thriving);
    });

    test('caps never lift a low Health band', () {
      expect(at(10, {_today.addDays(-4)}).state, GhostState.fading);
      expect(at(0, {_today.addDays(-4)}).state, GhostState.dead);
    });
  });

  group('Haunting actions', () {
    test('archive after a tick keeps settled Health and drops the habit', () {
      final Haunting day1 = Haunting.open(
        book: HabitBook([
          _habit('a', done: {_today}),
          _habit('b'),
        ]),
        ghost: _ghost(60),
        today: _today,
      );
      final Haunting day2 = day1.syncTo(_today.next);
      expect(day2.ghost.health, 70); // 60 + feed(2, 1) = 70
      final Haunting archived = _next(day2.archiveHabit('b'));
      expect(archived.book.activeCount, 1);
      expect(archived.ghost.health, 70);
      expect(
        archived.book.all.firstWhere((Habit x) => x.id == 'b').archivedDay,
        _today.next,
      );
    });

    test('adding a habit lowers today\'s feed', () {
      final Haunting one = Haunting(
        book: HabitBook([
          _habit('a', done: {_today}),
        ]),
        ghost: _ghost(50),
        today: _today,
      );
      expect(one.liveHealth, 70);
      final Haunting two = _next(one.addHabit('Stretch'));
      expect(two.book.activeCount, 2);
      expect(two.liveHealth, 60);
    });

    test('completing the last candle resurrects the ghost', () {
      final Haunting dead = Haunting(
        book: HabitBook([_habit('a'), _habit('b')]),
        ghost: _ghost(0),
        today: _today,
      );
      final HauntResult first = dead.complete('a');
      expect((first as HauntChanged).resurrected, isFalse);
      final HauntResult second = first.next.complete('b');
      expect((second as HauntChanged).resurrected, isTrue);
      expect(second.next.ghost.health, 40);
      expect(second.next.liveHealth, 60); // 40 + feed(2, 2)
    });
  });
}
