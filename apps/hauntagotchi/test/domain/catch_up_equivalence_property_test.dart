// Feature: hauntagotchi-core, Property 7: One catch-up equals many single catch-ups
// Validates: Requirements 4.2, 4.4, 14.3
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart'
    show equals, expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:hauntagotchi/src/domain/catch_up.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit_book.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';

import 'support/haunt_generators.dart';

const int _numRuns = 200;
final RunCounter _stepRuns = RunCounter();
final RunCounter _splitRuns = RunCounter();

/// A starting ghost and book plus a number of extra days away.
final class _Scenario {
  const _Scenario(this.ghost, this.book, this.extraDays, this.splitAt);

  final Ghost ghost;
  final HabitBook book;

  /// N, from 0 to 60.
  final int extraDays;

  /// A day offset in `[0, extraDays + 1]` used for the split property.
  final int splitAt;

  @override
  String toString() =>
      'ghost=$ghost, habits=${book.all.length}, N=$extraDays, split=$splitAt';
}

/// Draws a base day, then a book and a ghost built around it.
final Generator<_Scenario> _anyScenario = any.simple<_Scenario>(
  generate: (math.Random random, int size) {
    final LocalDay base = anyLocalDay(random, size).value;
    final HabitBook book = anyBook(base)(random, size).value;
    final Ghost ghost = anyGhost(base)(random, size).value;
    final int n = anyIntBetween(0, 61)(random, size).value;
    return _Scenario(ghost, book, n, random.nextInt(n + 2));
  },
  shrink: (_Scenario s) sync* {
    if (s.extraDays > 0) {
      final int n = s.extraDays ~/ 2;
      yield _Scenario(
        s.ghost,
        s.book,
        n,
        s.splitAt > n + 1 ? n + 1 : s.splitAt,
      );
    }
  },
);

void main() {
  group('Property 7: one catch-up equals many single catch-ups', () {
    Glados(_anyScenario, ExploreConfig(numRuns: _numRuns)).test(
      'N+1 day-by-day catch-ups equal one catch-up over the span',
      (_Scenario s) {
        _stepRuns.increment();
        final LocalDay start = s.ghost.lastSettledDay;
        final LocalDay finalToday = start.addDays(s.extraDays + 2);

        final Ghost jumped = CatchUp.run(s.ghost, s.book, finalToday);

        Ghost stepped = s.ghost;
        for (int k = 0; k <= s.extraDays; k++) {
          stepped = CatchUp.run(stepped, s.book, start.addDays(k + 2));
        }

        expect(stepped, equals(jumped), reason: '$s');
      },
    );

    Glados(_anyScenario, ExploreConfig(numRuns: _numRuns)).test(
      'a gap jump equals a jump to any day in between, then the rest',
      (_Scenario s) {
        _splitRuns.increment();
        final LocalDay start = s.ghost.lastSettledDay;
        final LocalDay finalToday = start.addDays(s.extraDays + 2);
        final LocalDay middle = start.addDays(s.splitAt + 1);

        final Ghost whole = CatchUp.run(s.ghost, s.book, finalToday);
        final Ghost viaMiddle = CatchUp.run(
          CatchUp.run(s.ghost, s.book, middle),
          s.book,
          finalToday,
        );

        expect(viaMiddle, equals(whole), reason: '$s');
      },
    );

    test('the property bodies ran numRuns times', () {
      _stepRuns.expectRuns(_numRuns);
      _splitRuns.expectRuns(_numRuns);
    });
  });
}
