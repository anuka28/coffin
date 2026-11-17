// Feature: hauntagotchi-core, Property 18: Rejections change nothing and the limit holds
// Validates: Requirements 1.2, 1.3, 1.8, 1.10, 1.11, 1.13

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart'
    show equals, expect, group, inInclusiveRange, isA, isNull, test;
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/habit_book.dart';
import 'package:hauntagotchi/src/domain/habit_rejection.dart';
import 'package:hauntagotchi/src/domain/habit_result.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';
import 'package:hauntagotchi/src/domain/name_rules.dart';

import 'support/haunt_generators.dart';

const int _numRuns = 200;
final RunCounter _runs = RunCounter();

/// The rejection the rules call for, or null when the change must apply.
HabitRejection? _expectedName(String raw) {
  final String trimmed = raw.trim();
  if (trimmed.isEmpty) return HabitRejection.nameEmpty;
  if (trimmed.runes.length > NameRules.maxLength) {
    return HabitRejection.nameTooLong;
  }
  return null;
}

HabitRejection? _expectedState(HabitBook book, String id) {
  final List<Habit> found = book.all.where((Habit h) => h.id == id).toList();
  if (found.isEmpty) return HabitRejection.unknownHabit;
  return found.single.isActive ? null : HabitRejection.habitArchived;
}

/// Applies one operation chosen by [code] and returns the result with the
/// rejection the rules call for (null when the change must apply).
(HabitResult, HabitRejection?) _step(
  HabitBook book,
  int code,
  math.Random random,
  LocalDay today,
) {
  final HabitResult result;
  final HabitRejection? expected;
  final String id = 'h${1 + random.nextInt(8)}';
  final String name = anyHabitName(random, 10).value;
  final LocalDay other = today.addDays(
    (random.nextBool() ? 1 : -1) * (1 + random.nextInt(5)),
  );
  switch (code % 7) {
    case 0:
      result = book.add(name, today: today);
      expected =
          _expectedName(name) ??
          (book.canAdd ? null : HabitRejection.limitReached);
    case 1:
      result = book.rename(id, name);
      expected = _expectedName(name) ?? _expectedState(book, id);
    case 2:
      result = book.complete(id, today, today: today);
      expected =
          _expectedState(book, id) ??
          (book.all.any((Habit h) => h.id == id && h.isCompletedOn(today))
              ? HabitRejection.alreadyCompleted
              : null);
    case 3:
      result = book.undo(id, today, today: today);
      expected =
          _expectedState(book, id) ??
          (book.all.any((Habit h) => h.id == id && h.isCompletedOn(today))
              ? null
              : HabitRejection.notCompleted);
    case 4:
      result = book.complete(id, other, today: today);
      expected = HabitRejection.notToday;
    case 5:
      result = book.undo(id, other, today: today);
      expected = HabitRejection.notToday;
    default:
      result = book.archive(id, today: today);
      expected = _expectedState(book, id);
  }
  return (result, expected);
}

void main() {
  group('Property 18: rejections change nothing and the limit holds', () {
    Glados3(
      anyLocalDay,
      anyIntBetween(0, 1 << 30),
      anyListBetween(1, 40, anyIntBetween(0, 1 << 30)),
      ExploreConfig(numRuns: _numRuns),
    ).test('rejections leave the book equal; active count stays in 0..5', (
      LocalDay today,
      int seed,
      List<int> codes,
    ) {
      _runs.increment();
      final math.Random random = math.Random(seed);
      HabitBook book = anyBook(today)(random, 10).value;
      for (final int code in codes) {
        final List<Habit> before = book.all.toList();
        final (HabitResult result, HabitRejection? expected) = _step(
          book,
          code,
          random,
          today,
        );
        switch (result) {
          case HabitRejected(:final HabitRejection reason):
            expect(reason, equals(expected));
            expect(book.all, equals(before));
          case HabitChanged(book: final HabitBook next):
            expect(expected, isNull);
            expect(next.activeCount, inInclusiveRange(0, HabitBook.maxActive));
            book = next;
        }
        expect(book.activeCount, inInclusiveRange(0, HabitBook.maxActive));
      }
    });

    test('add at five active habits is limitReached and changes nothing', () {
      final LocalDay today = LocalDay(2026, 1, 1);
      final HabitBook full = HabitBook(<Habit>[
        for (int i = 1; i <= 5; i++)
          Habit(id: 'h$i', name: 'x', createdDay: today),
      ]);
      final HabitResult r = full.add('more', today: today);
      expect(r, isA<HabitRejected>());
      expect((r as HabitRejected).reason, HabitRejection.limitReached);
      expect(full.activeCount, 5);
    });

    test('every property body ran numRuns times', () {
      _runs.expectRuns(_numRuns);
    });
  });
}
