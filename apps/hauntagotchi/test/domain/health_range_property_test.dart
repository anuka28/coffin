// Feature: hauntagotchi-core, Property 4: Health stays in range
// Validates: Requirements 3.2, 4.7, 14.2
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart'
    show equals, expect, group, inInclusiveRange, test;
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit_book.dart';
import 'package:hauntagotchi/src/domain/haunting.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';

import 'support/haunt_generators.dart';

const int _numRuns = 200;
final RunCounter _runs = RunCounter();

/// A starting haunting and a sequence of operations to apply to it.
final class _Scenario {
  const _Scenario(this.ghost, this.book, this.today, this.ops);

  final Ghost ghost;
  final HabitBook book;
  final LocalDay today;
  final List<Operation> ops;

  @override
  String toString() =>
      'ghost=$ghost, habits=${book.all.length}, today=$today, ops=$ops';
}

/// Draws a day, then a ghost and a book around it, then 1 to 40 operations.
///
/// Operations include day jumps of 0 to 10,000 days.
final Generator<_Scenario> _anyScenario = any.simple<_Scenario>(
  generate: (math.Random random, int size) {
    final LocalDay today = anyLocalDay(random, size).value;
    return _Scenario(
      anyGhost(today)(random, size).value,
      anyBook(today)(random, size).value,
      today,
      anyListBetween<Operation>(1, 41, anyOperation)(random, size).value,
    );
  },
  shrink: (_Scenario s) sync* {
    if (s.ops.length > 1) {
      yield _Scenario(
        s.ghost,
        s.book,
        s.today,
        s.ops.take(s.ops.length ~/ 2).toList(),
      );
    }
  },
);

void _expectInRange(Haunting h, String reason) {
  expect(h.ghost.health, inInclusiveRange(0, 100), reason: reason);
  expect(h.liveHealth, inInclusiveRange(0, 100), reason: reason);
}

void main() {
  group('Property 4: Health stays in range', () {
    Glados(_anyScenario, ExploreConfig(numRuns: _numRuns)).test(
      'ghost.health and liveHealth stay within 0..100 after every step',
      (_Scenario s) {
        _runs.increment();
        Haunting h = Haunting.open(
          book: s.book,
          ghost: s.ghost,
          today: s.today,
        );
        _expectInRange(h, 'open: $s');
        for (final Operation op in s.ops) {
          h = applyOp(h, op);
          _expectInRange(h, 'after $op: $s');
        }
      },
    );

    test('the property body ran numRuns times', () {
      _runs.expectRuns(_numRuns);
      expect(_numRuns, equals(200));
    });
  });
}
