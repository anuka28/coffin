// Feature: hauntagotchi-core, Property 17: Streak equals the run ending Today or yesterday
// Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart'
    show equals, expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/habit_book.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';
import 'package:hauntagotchi/src/domain/streak.dart';

import 'support/haunt_generators.dart';

const int _numRuns = 200;
final RunCounter _denseRuns = RunCounter();
final RunCounter _sharedRuns = RunCounter();

/// A book and the Today it is read on.
final class _Case {
  const _Case(this.book, this.today);

  final HabitBook book;
  final LocalDay today;

  @override
  String toString() =>
      'today=${today.toIso()}, habits=${[for (final Habit h in book.all) '${h.id}${h.isActive ? '' : '(archived)'}:'
            '${(h.completedDays.map((LocalDay d) => d.toIso()).toList()..sort()).join(',')}']}';
}

/// Books with long runs: 1 to 4 habits (some archived) that complete each of
/// the last 0 to 30 days with a per-case probability, so runs of many days,
/// gaps, runs ending yesterday and empty days all show up.
Generator<_Case> get _anyDenseCase => any.simple<_Case>(
  generate: (math.Random random, int size) {
    final LocalDay today = anyLocalDay(random, size).value;
    final int count = 1 + random.nextInt(4);
    final int span = random.nextInt(31);
    final int chance = 1 + random.nextInt(10);
    final List<Habit> habits = <Habit>[];
    for (int i = 1; i <= count; i++) {
      final Set<LocalDay> done = <LocalDay>{};
      for (int back = 0; back < span; back++) {
        if (random.nextInt(10) < chance && random.nextInt(count) == 0) {
          done.add(today.addDays(-back));
        }
      }
      // Archived habits keep their completions and still count.
      final LocalDay? archived = random.nextInt(4) == 0 ? today : null;
      habits.add(
        Habit(
          id: 'h$i',
          name: 'habit $i',
          createdDay: today.addDays(-40),
          completedDays: done,
          archivedDay: archived,
        ),
      );
    }
    // Plain construction keeps the completions as generated, even when a
    // completion falls on or after an archive day.
    return _Case(HabitBook(habits), today);
  },
  shrink: (_Case c) sync* {
    if (c.book.all.isNotEmpty) {
      yield _Case(HabitBook(c.book.all.take(c.book.all.length - 1)), c.today);
    }
  },
);

/// Books from the shared generator, read on a random Today.
Generator<_Case> get _anySharedCase => any.simple<_Case>(
  generate: (math.Random random, int size) {
    final LocalDay today = anyLocalDay(random, size).value;
    return _Case(anyBook(today)(random, size).value, today);
  },
  shrink: (_Case c) sync* {
    if (c.book.all.isNotEmpty) {
      yield _Case(HabitBook(c.book.all.take(c.book.all.length - 1)), c.today);
    }
  },
);

/// Independent reference: the longest run of consecutive days with at least
/// one completion by any habit, archived included, that ends Today or
/// yesterday. 0 when neither day has a completion.
int _reference(HabitBook book, LocalDay today) {
  final Set<int> done = <int>{
    for (final Habit h in book.all)
      for (final LocalDay d in h.completedDays) d.epochDay,
  };
  int end = today.epochDay;
  if (!done.contains(end)) {
    end -= 1;
    if (!done.contains(end)) return 0;
  }
  int length = 0;
  while (done.contains(end - length)) {
    length++;
  }
  return length;
}

void _check(_Case c, RunCounter counter) {
  counter.increment();
  expect(Streak.compute(c.book, c.today), equals(_reference(c.book, c.today)));
}

void main() {
  group('Property 17: streak equals the run ending Today or yesterday', () {
    Glados(_anyDenseCase, ExploreConfig(numRuns: _numRuns)).test(
      'dense books match the reference',
      (_Case c) => _check(c, _denseRuns),
    );

    Glados(_anySharedCase, ExploreConfig(numRuns: _numRuns)).test(
      'generated books match the reference',
      (_Case c) => _check(c, _sharedRuns),
    );

    test('the property bodies ran numRuns times', () {
      _denseRuns.expectRuns(_numRuns);
      _sharedRuns.expectRuns(_numRuns);
    });
  });
}
