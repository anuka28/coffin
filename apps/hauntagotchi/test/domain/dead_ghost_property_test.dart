// Feature: hauntagotchi-core, Property 15: A dead ghost stays dead until the ritual
// Validates: Requirements 6.1, 6.2, 14.6
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart'
    show equals, expect, group, isNotNull, test;
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:hauntagotchi/src/domain/balance.dart';
import 'package:hauntagotchi/src/domain/catch_up.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/ghost_state.dart';
import 'package:hauntagotchi/src/domain/habit_book.dart';
import 'package:hauntagotchi/src/domain/haunting.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';
import 'package:hauntagotchi/src/domain/resurrection_ritual.dart';
import 'package:hauntagotchi/src/domain/ritual_progress.dart';

import 'support/haunt_generators.dart';

const int _numRuns = 200;
final RunCounter _runs = RunCounter();

/// A starting ghost and book, and a sequence of operations to apply.
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

/// Draws a day, a book and a ghost (dead about half of the time), then 1 to
/// 30 operations, including long day jumps.
final Generator<_Scenario> _anyScenario = any.simple<_Scenario>(
  generate: (math.Random random, int size) {
    final LocalDay today = anyLocalDay(random, size).value;
    final Ghost drawn = anyGhost(today)(random, size).value;
    final Ghost ghost = random.nextBool()
        ? Ghost(
            name: drawn.name,
            health: 0,
            lastSettledDay: drawn.lastSettledDay,
            resurrectionCount: drawn.resurrectionCount,
          )
        : drawn;
    return _Scenario(
      ghost,
      anyBook(today)(random, size).value,
      today,
      anyListBetween<Operation>(1, 31, anyOperation)(random, size).value,
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

/// Checks one step from [before] to [after].
///
/// A ghost that was dead stays dead, at Health 0 and with the same
/// Resurrection_Count, unless the ritual is fulfilled in [after]. Then it is
/// revived once, at the fresh-start Health. A ghost that dies keeps its count.
void _expectStep(Haunting prior, Haunting after, String reason) {
  // Days settle before the action, so a ghost that died in Catch_Up counts
  // as dead here, with its count unchanged (6.1).
  final Haunting before = Haunting(
    book: prior.book,
    ghost: CatchUp.run(prior.ghost, prior.book, after.today),
    today: after.today,
  );
  expect(
    before.ghost.resurrectionCount,
    equals(prior.ghost.resurrectionCount),
    reason: 'Catch_Up leaves the count unchanged: $reason',
  );
  final bool dead = after.ghost.isDead;
  expect(after.ghost.health == 0, equals(dead), reason: reason);
  if (dead) {
    expect(after.liveHealth, equals(0), reason: reason);
    expect(after.state, equals(GhostState.dead), reason: reason);
    expect(
      after.ghost.resurrectionCount,
      equals(before.ghost.resurrectionCount),
      reason: 'a dead ghost keeps its count: $reason',
    );
    // Still dead, so the ritual must not be fulfilled.
    final RitualProgress? p = ResurrectionRitual.progress(
      after.book,
      after.today,
    );
    expect(
      p == null || !p.isComplete,
      equals(true),
      reason: 'a fulfilled ritual must revive the ghost: $reason',
    );
    return;
  }
  if (before.ghost.isDead) {
    // Revived: only the ritual does this, once.
    final RitualProgress? p = ResurrectionRitual.progress(
      after.book,
      after.today,
    );
    expect(p, isNotNull, reason: 'revived without a ritual: $reason');
    expect(p!.isComplete, equals(true), reason: 'ritual not met: $reason');
    expect(
      after.ghost.resurrectionCount,
      equals(before.ghost.resurrectionCount + 1),
      reason: 'revived exactly once: $reason',
    );
    expect(
      after.ghost.health,
      equals(Balance.freshStartHealth),
      reason: reason,
    );
  } else {
    expect(
      after.ghost.resurrectionCount,
      equals(before.ghost.resurrectionCount),
      reason: 'only the ritual raises the count: $reason',
    );
  }
}

void main() {
  group('Property 15: A dead ghost stays dead until the ritual', () {
    Glados(
      _anyScenario,
      ExploreConfig(numRuns: _numRuns),
    ).test('dead ghosts stay at Health 0 with the same count unless the ritual '
        'is fulfilled', (_Scenario s) {
      _runs.increment();
      final Haunting start = Haunting(
        book: s.book,
        ghost: s.ghost,
        today: s.today,
      );
      Haunting h = Haunting.open(book: s.book, ghost: s.ghost, today: s.today);
      _expectStep(start, h, 'open: $s');
      for (final Operation op in s.ops) {
        final Haunting next = applyOp(h, op);
        _expectStep(h, next, 'after $op: $s');
        h = next;
      }
    });

    test('the property body ran numRuns times', () {
      _runs.expectRuns(_numRuns);
      expect(_numRuns, equals(200));
    });
  });
}
