import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';

final LocalDay _d1 = LocalDay(2026, 3, 1);
final LocalDay _d2 = LocalDay(2026, 3, 2);
final LocalDay _d3 = LocalDay(2026, 3, 3);

void main() {
  group('Habit', () {
    test(
      'unarchived habit is active from createdDay onwards, never before',
      () {
        final Habit h = Habit(id: 'h1', name: 'a', createdDay: _d2);
        expect(h.isActive, isTrue);
        expect(h.isActiveOn(_d1), isFalse);
        expect(h.isActiveOn(_d2), isTrue);
        expect(h.isActiveOn(LocalDay(2030, 1, 1)), isTrue);
      },
    );

    test('archivedDay is the first inactive day', () {
      final Habit h = Habit(
        id: 'h1',
        name: 'a',
        createdDay: _d1,
        archivedDay: _d3,
      );
      expect(h.isActiveOn(_d2), isTrue);
      expect(h.isActiveOn(_d3), isFalse);
    });

    test('habit archived on its created day is never active', () {
      final Habit h = Habit(
        id: 'h1',
        name: 'a',
        createdDay: _d2,
        archivedDay: _d2,
      );
      expect(h.isActiveOn(_d2), isFalse);
    });

    test('isCompletedOn reflects completedDays', () {
      final Habit h = Habit(
        id: 'h1',
        name: 'a',
        createdDay: _d1,
        completedDays: <LocalDay>{_d2},
      );
      expect(h.isCompletedOn(_d2), isTrue);
      expect(h.isCompletedOn(_d1), isFalse);
    });

    test('equality and hashCode ignore completedDays order', () {
      final Habit a = Habit(
        id: 'h1',
        name: 'a',
        createdDay: _d1,
        completedDays: <LocalDay>{_d1, _d2},
      );
      final Habit b = Habit(
        id: 'h1',
        name: 'a',
        createdDay: _d1,
        completedDays: <LocalDay>{_d2, _d1},
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('habits differing in any field are not equal', () {
      final Habit base = Habit(
        id: 'h1',
        name: 'a',
        createdDay: _d1,
        completedDays: <LocalDay>{_d1},
      );
      expect(base, isNot(Habit(id: 'h2', name: 'a', createdDay: _d1)));
      expect(
        base,
        isNot(
          Habit(
            id: 'h1',
            name: 'b',
            createdDay: _d1,
            completedDays: <LocalDay>{_d1},
          ),
        ),
      );
      expect(
        base,
        isNot(
          Habit(
            id: 'h1',
            name: 'a',
            createdDay: _d2,
            completedDays: <LocalDay>{_d1},
          ),
        ),
      );
      expect(base, isNot(Habit(id: 'h1', name: 'a', createdDay: _d1)));
      expect(
        base,
        isNot(
          Habit(
            id: 'h1',
            name: 'a',
            createdDay: _d1,
            completedDays: <LocalDay>{_d1},
            archivedDay: _d2,
          ),
        ),
      );
    });

    test('completedDays cannot be modified, even from the default', () {
      final Habit h = Habit(id: 'h1', name: 'a', createdDay: _d1);
      expect(() => h.completedDays.add(_d1), throwsUnsupportedError);
      expect(() => h.completedDays.clear(), throwsUnsupportedError);
    });
  });
}
