import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/habit_book.dart';
import 'package:hauntagotchi/src/domain/habit_result.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';
import 'package:hauntagotchi/src/domain/streak.dart';

final LocalDay _today = LocalDay(2026, 3, 10);

LocalDay _ago(int n) => _today.addDays(-n);

Habit _habit(String id, Iterable<int> daysAgo, {LocalDay? archivedDay}) =>
    Habit(
      id: id,
      name: id,
      createdDay: _ago(30),
      completedDays: daysAgo.map(_ago).toSet(),
      archivedDay: archivedDay,
    );

int _streak(Iterable<Habit> habits) =>
    Streak.compute(HabitBook(habits), _today);

void main() {
  group('Requirement 7.1 all habits count', () {
    test('an archived habit still counts toward the run', () {
      final Habit archived = _habit('h1', <int>[0, 1, 2], archivedDay: _ago(0));
      expect(_streak(<Habit>[archived]), 3);
    });

    test('completions of different habits join one run', () {
      expect(
        _streak(<Habit>[
          _habit('h1', <int>[0, 2]),
          _habit('h2', <int>[1], archivedDay: _ago(0)),
        ]),
        3,
      );
    });
  });

  group('Requirement 7.2 today', () {
    test('only today gives a streak of 1', () {
      expect(
        _streak(<Habit>[
          _habit('h1', <int>[0]),
        ]),
        1,
      );
    });

    test('two habits done today still count one day', () {
      expect(
        _streak(<Habit>[
          _habit('h1', <int>[0]),
          _habit('h2', <int>[0]),
        ]),
        1,
      );
    });
  });

  group('Requirement 7.3 yesterday', () {
    test('only yesterday keeps a streak of 1', () {
      expect(
        _streak(<Habit>[
          _habit('h1', <int>[1]),
        ]),
        1,
      );
    });

    test('a run ending yesterday keeps its length', () {
      expect(
        _streak(<Habit>[
          _habit('h1', <int>[1, 2, 3, 4]),
        ]),
        4,
      );
    });
  });

  group('Requirement 7.4 and 7.5 gaps and nothing', () {
    test('no completions give 0', () {
      expect(_streak(<Habit>[_habit('h1', <int>[])]), 0);
      expect(_streak(const <Habit>[]), 0);
    });

    test('a run that ended two days ago gives 0', () {
      expect(
        _streak(<Habit>[
          _habit('h1', <int>[2, 3, 4]),
        ]),
        0,
      );
    });

    test('a gap breaks the run and only the latest run counts', () {
      expect(
        _streak(<Habit>[
          _habit('h1', <int>[0, 1, 3, 4, 5, 6]),
        ]),
        2,
      );
    });

    test('a gap right before today leaves only today', () {
      expect(
        _streak(<Habit>[
          _habit('h1', <int>[0, 2, 3]),
        ]),
        1,
      );
    });
  });

  group('Requirement 7.6 undo', () {
    test('undoing the only completion today shortens the streak', () {
      HabitBook book = HabitBook(<Habit>[
        _habit('h1', <int>[1, 2]),
      ]);
      book = (book.complete('h1', _today, today: _today) as HabitChanged).book;
      expect(Streak.compute(book, _today), 3);

      book = (book.undo('h1', _today, today: _today) as HabitChanged).book;
      expect(Streak.compute(book, _today), 2);
    });

    test('undo keeps the day when another habit completed it', () {
      HabitBook book = HabitBook(<Habit>[
        _habit('h1', <int>[0, 1]),
        _habit('h2', <int>[0]),
      ]);
      book = (book.undo('h1', _today, today: _today) as HabitChanged).book;
      expect(Streak.compute(book, _today), 2);
    });

    test('undoing the only completion of a fresh start gives 0', () {
      HabitBook book = HabitBook(<Habit>[
        _habit('h1', <int>[0]),
      ]);
      book = (book.undo('h1', _today, today: _today) as HabitChanged).book;
      expect(Streak.compute(book, _today), 0);
    });
  });
}
