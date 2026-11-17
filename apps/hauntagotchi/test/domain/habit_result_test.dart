import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/habit_book.dart';
import 'package:hauntagotchi/src/domain/habit_rejection.dart';
import 'package:hauntagotchi/src/domain/habit_result.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';

String _describe(HabitResult r) => switch (r) {
  HabitChanged(:final HabitBook book) => 'changed:${book.all.length}',
  HabitRejected(:final HabitRejection reason) => 'rejected:${reason.name}',
};

void main() {
  group('HabitResult', () {
    test('HabitChanged carries the book', () {
      final HabitBook book = HabitBook(const <Habit>[]);
      final HabitChanged r = HabitChanged(book);
      expect(identical(r.book, book), isTrue);
    });

    test('HabitRejected carries the reason', () {
      for (final HabitRejection reason in HabitRejection.values) {
        expect(HabitRejected(reason).reason, reason);
      }
    });

    test('switch over HabitResult is exhaustive and picks the right arm', () {
      final HabitBook book = HabitBook(<Habit>[
        Habit(id: 'h1', name: 'a', createdDay: LocalDay(2026, 3, 1)),
      ]);
      expect(_describe(HabitChanged(book)), 'changed:1');
      expect(
        _describe(const HabitRejected(HabitRejection.limitReached)),
        'rejected:limitReached',
      );
    });
  });
}
