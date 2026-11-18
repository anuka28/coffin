import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/habit_book.dart';
import 'package:hauntagotchi/src/domain/habit_result.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';
import 'package:hauntagotchi/src/domain/resurrection_ritual.dart';
import 'package:hauntagotchi/src/domain/ritual_progress.dart';

final LocalDay _today = LocalDay(2026, 3, 10);

Habit _habit(String id, {bool done = false, LocalDay? archivedDay}) => Habit(
  id: id,
  name: id,
  createdDay: LocalDay(2026, 1, 1),
  completedDays: done ? <LocalDay>{_today} : const <LocalDay>{},
  archivedDay: archivedDay,
);

final Ghost _dead = Ghost(
  name: 'Boo',
  health: 0,
  lastSettledDay: LocalDay(2026, 3, 1),
  resurrectionCount: 2,
);

void main() {
  group('ResurrectionRitual.progress', () {
    test('is null with no active habit', () {
      expect(ResurrectionRitual.progress(HabitBook(const []), _today), isNull);
      expect(
        ResurrectionRitual.progress(
          HabitBook([_habit('a', done: true, archivedDay: _today)]),
          _today,
        ),
        isNull,
      );
    });

    test('one active habit needs one candle', () {
      expect(
        ResurrectionRitual.progress(HabitBook([_habit('a')]), _today),
        const RitualProgress(done: 0, needed: 1),
      );
      expect(
        ResurrectionRitual.progress(
          HabitBook([_habit('a', done: true)]),
          _today,
        ),
        const RitualProgress(done: 1, needed: 1),
      );
    });

    test('two or more active habits need two candles', () {
      for (final int n in <int>[2, 3, 5]) {
        final HabitBook book = HabitBook([
          for (int i = 0; i < n; i++) _habit('h$i', done: i == 0),
        ]);
        expect(
          ResurrectionRitual.progress(book, _today),
          const RitualProgress(done: 1, needed: 2),
          reason: '$n habits',
        );
      }
    });

    test('counts only completions on today', () {
      final HabitBook book = HabitBook([
        Habit(
          id: 'a',
          name: 'a',
          createdDay: LocalDay(2026, 1, 1),
          completedDays: <LocalDay>{_today.previous},
        ),
        _habit('b', done: true),
      ]);
      expect(
        ResurrectionRitual.progress(book, _today),
        const RitualProgress(done: 1, needed: 2),
      );
    });

    test('archiving an unticked habit fulfils the ritual', () {
      final HabitBook book = HabitBook([_habit('a', done: true), _habit('b')]);
      expect(ResurrectionRitual.progress(book, _today)!.isComplete, isFalse);
      final HabitResult result = book.archive('b', today: _today);
      expect(result, isA<HabitChanged>());
      final HabitBook archived = (result as HabitChanged).book;
      expect(
        ResurrectionRitual.progress(archived, _today),
        const RitualProgress(done: 1, needed: 1),
      );
      expect(ResurrectionRitual.progress(archived, _today)!.isComplete, isTrue);
    });
  });

  group('ResurrectionRitual.apply', () {
    test('returns null for a living ghost', () {
      final Ghost alive = Ghost(
        name: 'Boo',
        health: 1,
        lastSettledDay: _today.previous,
      );
      final HabitBook book = HabitBook([
        _habit('a', done: true),
        _habit('b', done: true),
      ]);
      expect(ResurrectionRitual.apply(alive, book, _today), isNull);
    });

    test('returns null when the ritual is incomplete', () {
      final HabitBook book = HabitBook([_habit('a', done: true), _habit('b')]);
      expect(ResurrectionRitual.apply(_dead, book, _today), isNull);
    });

    test('returns null with no active habit', () {
      expect(
        ResurrectionRitual.apply(_dead, HabitBook(const []), _today),
        isNull,
      );
    });

    test('revives with Health 40, same name, settled yesterday, count + 1', () {
      final HabitBook book = HabitBook([
        _habit('a', done: true),
        _habit('b', done: true),
      ]);
      final Ghost? revived = ResurrectionRitual.apply(_dead, book, _today);
      expect(revived, isNotNull);
      expect(revived!.health, 40);
      expect(revived.name, 'Boo');
      expect(revived.lastSettledDay, _today.previous);
      expect(revived.resurrectionCount, 3);
      expect(revived.isDead, isFalse);
    });
  });
}
