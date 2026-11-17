import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/habit_book.dart';
import 'package:hauntagotchi/src/domain/habit_rejection.dart';
import 'package:hauntagotchi/src/domain/habit_result.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';

final LocalDay _d1 = LocalDay(2026, 3, 1);
final LocalDay _d2 = LocalDay(2026, 3, 2);
final LocalDay _d3 = LocalDay(2026, 3, 3);

HabitBook _book(HabitResult r) => (r as HabitChanged).book;

HabitRejection _why(HabitResult r) => (r as HabitRejected).reason;

HabitBook _withHabits(int n) {
  HabitBook book = HabitBook(const <Habit>[]);
  for (int i = 0; i < n; i++) {
    book = _book(book.add('Habit $i', today: _d1));
  }
  return book;
}

/// Whether two books hold equal habits in the same order.
void _expectSameHabits(HabitBook a, HabitBook b) {
  expect(a.all, orderedEquals(b.all));
}

void main() {
  group('Requirement 1.1 add', () {
    test('creates an active habit with trimmed name, today and no days', () {
      final HabitBook book = _book(
        HabitBook(const <Habit>[]).add('  Read  ', today: _d2),
      );
      final Habit h = book.all.single;
      expect(h.id, 'h1');
      expect(h.name, 'Read');
      expect(h.createdDay, _d2);
      expect(h.completedDays, isEmpty);
      expect(h.isActive, isTrue);
    });

    test('ids stay unique after archiving', () {
      HabitBook book = _withHabits(2);
      book = _book(book.archive('h1', today: _d1));
      book = _book(book.add('Third', today: _d1));
      book = _book(book.archive('h3', today: _d1));
      book = _book(book.add('Fourth', today: _d1));
      final List<String> ids = book.all.map((Habit h) => h.id).toList();
      expect(ids, <String>['h1', 'h2', 'h3', 'h4']);
      expect(ids.toSet().length, ids.length);
    });
  });

  group('Requirement 1.2 name validation', () {
    final HabitBook book = _withHabits(1);

    test('add rejects an empty or blank name', () {
      expect(_why(book.add('', today: _d1)), HabitRejection.nameEmpty);
      expect(_why(book.add('  \t ', today: _d1)), HabitRejection.nameEmpty);
    });

    test('add rejects 41 characters but accepts 40', () {
      expect(_why(book.add('a' * 41, today: _d1)), HabitRejection.nameTooLong);
      expect(book.add('a' * 40, today: _d1), isA<HabitChanged>());
      expect(book.add('  ${'a' * 40}  ', today: _d1), isA<HabitChanged>());
    });

    test('rename rejects bad names and leaves the book unchanged', () {
      expect(_why(book.rename('h1', ' ')), HabitRejection.nameEmpty);
      expect(_why(book.rename('h1', 'b' * 41)), HabitRejection.nameTooLong);
      expect(book.all.single.name, 'Habit 0');
    });
  });

  group('Requirement 1.3 and 1.13 limit', () {
    test('the sixth active habit is rejected and nothing changes', () {
      final HabitBook full = _withHabits(HabitBook.maxActive);
      final List<Habit> before = full.all;
      expect(full.canAdd, isFalse);
      expect(
        _why(full.add('One more', today: _d1)),
        HabitRejection.limitReached,
      );
      expect(full.all, orderedEquals(before));
      expect(full.activeCount, HabitBook.maxActive);
    });

    test('active count never leaves 0 to 5 over many adds', () {
      HabitBook book = HabitBook(const <Habit>[]);
      expect(book.activeCount, 0);
      for (int i = 0; i < 12; i++) {
        final HabitResult r = book.add('H$i', today: _d1);
        if (r is HabitChanged) {
          book = r.book;
        }
        expect(book.activeCount, inInclusiveRange(0, HabitBook.maxActive));
      }
    });
  });

  group('Requirement 1.4 rename', () {
    test('trims the name and keeps id, created day and completions', () {
      HabitBook book = _withHabits(1);
      book = _book(book.complete('h1', _d1, today: _d1));
      final HabitBook renamed = _book(book.rename('h1', '  New name '));
      final Habit h = renamed.all.single;
      expect(h.name, 'New name');
      expect(h.id, 'h1');
      expect(h.createdDay, _d1);
      expect(h.completedDays, <LocalDay>{_d1});
    });
  });

  group('Requirement 1.5 and 1.6 archive', () {
    test('sets archived day, keeps completions, leaves active list', () {
      HabitBook book = _withHabits(2);
      book = _book(book.complete('h1', _d1, today: _d1));
      book = _book(book.archive('h1', today: _d2));
      final Habit h = book.all.first;
      expect(h.archivedDay, _d2);
      expect(h.completedDays, <LocalDay>{_d1});
      expect(book.active.map((Habit x) => x.id), <String>['h2']);
      expect(book.all.length, 2);
    });

    test('frees one slot of the limit', () {
      HabitBook book = _withHabits(HabitBook.maxActive);
      book = _book(book.archive('h3', today: _d2));
      expect(book.activeCount, 4);
      expect(book.canAdd, isTrue);
      book = _book(book.add('Replacement', today: _d2));
      expect(book.activeCount, 5);
      expect(book.all.length, 6);
    });
  });

  group('Requirement 1.7 to 1.9 complete and undo', () {
    test('complete adds today to the completed days', () {
      final HabitBook book = _book(
        _withHabits(1).complete('h1', _d1, today: _d1),
      );
      expect(book.all.single.completedDays, <LocalDay>{_d1});
    });

    test('complete twice reports alreadyCompleted and changes nothing', () {
      final HabitBook done = _book(
        _withHabits(1).complete('h1', _d1, today: _d1),
      );
      expect(
        _why(done.complete('h1', _d1, today: _d1)),
        HabitRejection.alreadyCompleted,
      );
      expect(done.all.single.completedDays, <LocalDay>{_d1});
    });

    test('undo removes today and keeps earlier days', () {
      HabitBook book = HabitBook(<Habit>[
        Habit(
          id: 'h1',
          name: 'a',
          createdDay: _d1,
          completedDays: <LocalDay>{_d1, _d2},
        ),
      ]);
      book = _book(book.undo('h1', _d2, today: _d2));
      expect(book.all.single.completedDays, <LocalDay>{_d1});
    });

    test('undo without a completion reports notCompleted', () {
      expect(
        _why(_withHabits(1).undo('h1', _d1, today: _d1)),
        HabitRejection.notCompleted,
      );
    });
  });

  group('Requirement 1.10 only today', () {
    test('complete and undo reject yesterday and tomorrow', () {
      final HabitBook book = _withHabits(1);
      for (final LocalDay other in <LocalDay>[_d1, _d3]) {
        expect(
          _why(book.complete('h1', other, today: _d2)),
          HabitRejection.notToday,
        );
        expect(
          _why(book.undo('h1', other, today: _d2)),
          HabitRejection.notToday,
        );
      }
    });
  });

  group('Requirement 1.11 archived and unknown', () {
    test('rename, complete and undo reject an archived habit', () {
      HabitBook book = _withHabits(1);
      book = _book(book.complete('h1', _d1, today: _d1));
      book = _book(book.archive('h1', today: _d1));
      expect(_why(book.rename('h1', 'x')), HabitRejection.habitArchived);
      expect(
        _why(book.complete('h1', _d1, today: _d1)),
        HabitRejection.habitArchived,
      );
      expect(
        _why(book.undo('h1', _d1, today: _d1)),
        HabitRejection.habitArchived,
      );
      expect(
        _why(book.archive('h1', today: _d1)),
        HabitRejection.habitArchived,
      );
    });

    test('rename, complete, undo and archive reject an unknown id', () {
      final HabitBook book = _withHabits(1);
      expect(_why(book.rename('zz', 'x')), HabitRejection.unknownHabit);
      expect(
        _why(book.complete('zz', _d1, today: _d1)),
        HabitRejection.unknownHabit,
      );
      expect(
        _why(book.undo('zz', _d1, today: _d1)),
        HabitRejection.unknownHabit,
      );
      expect(_why(book.archive('zz', today: _d1)), HabitRejection.unknownHabit);
    });
  });

  group('Requirement 1.12 complete then undo', () {
    test('restores habits equal to the original', () {
      final HabitBook start = _withHabits(3);
      final HabitBook done = _book(start.complete('h2', _d1, today: _d1));
      final HabitBook back = _book(done.undo('h2', _d1, today: _d1));
      _expectSameHabits(back, start);
    });
  });

  group('Requirement 1.14 missingToSuggested', () {
    test('counts 0 to 5 active habits', () {
      const List<int> expected = <int>[3, 2, 1, 0, 0, 0];
      for (int n = 0; n <= 5; n++) {
        expect(_withHabits(n).missingToSuggested, expected[n], reason: '$n');
      }
    });

    test('archived habits do not count', () {
      HabitBook book = _withHabits(3);
      book = _book(book.archive('h1', today: _d1));
      expect(book.missingToSuggested, 1);
    });
  });

  group('counts by day', () {
    test(
      'completedCountOn ignores archived habits, anyCompletedOn does not',
      () {
        HabitBook book = _withHabits(2);
        book = _book(book.complete('h1', _d1, today: _d1));
        book = _book(book.complete('h2', _d1, today: _d1));
        book = _book(book.archive('h2', today: _d2));
        expect(book.activeCountOn(_d1), 2);
        expect(book.activeCountOn(_d2), 1);
        expect(book.completedCountOn(_d1), 2);
        expect(book.completedCountOn(_d2), 0);
        expect(book.anyCompletedOn(_d1), isTrue);
        expect(book.anyCompletedOn(_d2), isFalse);
      },
    );
  });

  group('HabitBook.restore', () {
    test('trims more than 5 active habits, keeping the oldest', () {
      final List<Habit> stored = <Habit>[
        for (int i = 1; i <= 7; i++)
          Habit(id: 'h$i', name: 'n$i', createdDay: i == 7 ? _d1 : _d2),
      ];
      final HabitBook book = HabitBook.restore(stored, today: _d3);
      expect(book.activeCount, HabitBook.maxActive);
      final Set<String> archived = book.all
          .where((Habit h) => !h.isActive)
          .map((Habit h) => h.id)
          .toSet();
      expect(archived, <String>{'h5', 'h6'});
      expect(book.all.firstWhere((Habit h) => h.id == 'h5').archivedDay, _d3);
      expect(book.all.length, 7);
    });

    test('leaves a valid book untouched', () {
      final HabitBook book = _withHabits(3);
      _expectSameHabits(HabitBook.restore(book.all, today: _d3), book);
    });

    test('ignores archived habits when counting the limit', () {
      final List<Habit> stored = <Habit>[
        for (int i = 1; i <= 5; i++)
          Habit(id: 'h$i', name: 'n$i', createdDay: _d1),
        Habit(id: 'h6', name: 'n6', createdDay: _d1, archivedDay: _d2),
      ];
      final HabitBook book = HabitBook.restore(stored, today: _d3);
      expect(book.activeCount, 5);
      expect(book.all.last.archivedDay, _d2);
    });
  });
}
