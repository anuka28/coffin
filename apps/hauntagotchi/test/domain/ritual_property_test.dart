// Feature: hauntagotchi-core, Property 16: The ritual brings the ghost back once
// Validates: Requirements 6.4, 6.5, 6.6, 6.8
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart'
    show equals, expect, group, isA, isFalse, isTrue, test;
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:hauntagotchi/src/domain/balance.dart';
import 'package:hauntagotchi/src/domain/catch_up.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/habit_book.dart';
import 'package:hauntagotchi/src/domain/habit_result.dart';
import 'package:hauntagotchi/src/domain/haunt_result.dart';
import 'package:hauntagotchi/src/domain/haunting.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';
import 'package:hauntagotchi/src/domain/ritual_progress.dart';

import 'support/haunt_generators.dart';

const int _numRuns = 200;
final RunCounter _runs = RunCounter();

/// A day, a book, a dead ghost and operations to apply.
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

/// Draws a day, a book, a dead ghost and 0 to 20 operations. Complete
/// operations for every habit follow them, so most runs reach the ritual.
final Generator<_Scenario> _anyScenario = any.simple<_Scenario>(
  generate: (math.Random random, int size) {
    final LocalDay today = anyLocalDay(random, size).value;
    final Ghost drawn = anyGhost(today)(random, size).value;
    final Ghost ghost = Ghost(
      name: drawn.name,
      health: 0,
      lastSettledDay: drawn.lastSettledDay,
      resurrectionCount: drawn.resurrectionCount,
    );
    final List<Operation> ops = <Operation>[
      ...anyListBetween<Operation>(0, 21, anyOperation)(random, size).value,
      for (int i = 0; i < 8; i++) CompleteOp(i),
    ];
    return _Scenario(ghost, anyBook(today)(random, size).value, today, ops);
  },
  shrink: (_Scenario s) sync* {
    if (s.ops.length > 8) {
      yield _Scenario(s.ghost, s.book, s.today, s.ops.skip(1).toList());
    }
  },
);

/// Applies [op] like `applyOp`, and also returns the `resurrected` flag.
(Haunting, bool) _step(Haunting haunting, Operation op) {
  if (op is AdvanceDaysOp) {
    return (applyOp(haunting, op), false);
  }
  final List<Habit> all = haunting.book.all;
  String idFor(HabitOp o) => all.isEmpty ? 'h0' : all[o.index % all.length].id;
  final HauntResult result = switch (op) {
    AddHabitOp(:final name) => haunting.addHabit(name),
    RenameHabitOp(:final name) => haunting.renameHabit(idFor(op), name),
    ArchiveHabitOp() => haunting.archiveHabit(idFor(op)),
    CompleteOp() => haunting.complete(idFor(op)),
    UndoOp() => haunting.undo(idFor(op)),
    AdvanceDaysOp() => throw StateError('handled above'),
  };
  return switch (result) {
    HauntChanged(:final next, :final resurrected) => (next, resurrected),
    HauntRejected() => (haunting, false),
  };
}

/// Checks one step from [prior] to [after].
///
/// The count never decreases. It goes up by exactly one only when the ghost
/// was dead (after settling days) and the ritual is fulfilled, and then the
/// ghost has Health 40, the same name and is settled through yesterday.
/// [flagged] is `HauntChanged.resurrected`: true exactly when a habit action
/// raised the count.
void _expectStep(
  Haunting prior,
  Haunting after,
  bool flagged,
  bool isHabitAction,
  String reason,
) {
  final Ghost settled = CatchUp.run(prior.ghost, prior.book, after.today);
  final int before = prior.ghost.resurrectionCount;
  final int now = after.ghost.resurrectionCount;
  expect(now >= before, isTrue, reason: 'the count never drops: $reason');
  expect(
    now == before || now == before + 1,
    isTrue,
    reason: 'the count rises by at most one: $reason',
  );
  if (isHabitAction) {
    expect(
      flagged,
      equals(now == before + 1),
      reason: 'resurrected flag matches the count: $reason',
    );
  } else {
    expect(flagged, isFalse, reason: reason);
  }
  if (now == before) {
    return;
  }
  expect(settled.isDead, isTrue, reason: 'revived while alive: $reason');
  final RitualProgress? p = after.ritual;
  expect(p != null && p.isComplete, isTrue, reason: 'ritual unmet: $reason');
  expect(after.ghost.health, equals(Balance.freshStartHealth), reason: reason);
  expect(after.ghost.name, equals(prior.ghost.name), reason: reason);
  expect(
    after.ghost.lastSettledDay,
    equals(after.today.previous),
    reason: reason,
  );
  expect(after.ghost.isDead, isFalse, reason: reason);
}

/// After a revival, undoing today's completions keeps the ghost alive and
/// the count unchanged.
void _expectUndoKeepsGhost(Haunting revived, String reason) {
  Haunting h = revived;
  for (final Habit habit in revived.book.all) {
    if (!habit.isCompletedOn(h.today)) continue;
    final HauntResult r = h.undo(habit.id);
    if (r is! HauntChanged) continue;
    h = r.next;
    expect(r.resurrected, isFalse, reason: 'undo never revives: $reason');
    expect(h.ghost.isDead, isFalse, reason: 'undo keeps it alive: $reason');
    expect(
      h.ghost.resurrectionCount,
      equals(revived.ghost.resurrectionCount),
      reason: 'undo keeps the count: $reason',
    );
    expect(h.ghost.health, equals(revived.ghost.health), reason: reason);
  }
}

void main() {
  group('Property 16: The ritual brings the ghost back once', () {
    Glados(_anyScenario, ExploreConfig(numRuns: _numRuns)).test(
      'a fulfilled ritual revives a dead ghost once, at Health 40',
      (_Scenario s) {
        _runs.increment();
        final Haunting start = Haunting(
          book: s.book,
          ghost: s.ghost,
          today: s.today,
        );
        Haunting h = Haunting.open(
          book: s.book,
          ghost: s.ghost,
          today: s.today,
        );
        _expectStep(start, h, false, false, 'open: $s');
        for (final Operation op in s.ops) {
          final (Haunting next, bool flagged) = _step(h, op);
          _expectStep(h, next, flagged, op is! AdvanceDaysOp, 'after $op: $s');
          if (flagged) {
            _expectUndoKeepsGhost(next, 'after $op: $s');
          }
          h = next;
        }
      },
    );

    test('the property body ran numRuns times', () {
      _runs.expectRuns(_numRuns);
      expect(_numRuns, equals(200));
    });

    test('archiving the unticked habit fulfils the ritual', () {
      final LocalDay today = LocalDay(2026, 5, 10);
      HabitBook book = HabitBook(const <Habit>[]);
      for (final String name in <String>['Read', 'Walk']) {
        book = (book.add(name, today: today) as HabitChanged).book;
      }
      book = (book.complete('h1', today, today: today) as HabitChanged).book;
      final Haunting dead = Haunting(
        book: book,
        ghost: Ghost(
          name: 'Boo',
          health: 0,
          lastSettledDay: today.previous,
          resurrectionCount: 2,
        ),
        today: today,
      );
      expect(dead.ritual!.isComplete, isFalse);

      final HauntResult result = dead.archiveHabit('h2');
      expect(result, isA<HauntChanged>());
      final HauntChanged changed = result as HauntChanged;
      expect(changed.resurrected, isTrue);
      expect(changed.next.ghost.health, equals(Balance.freshStartHealth));
      expect(changed.next.ghost.name, equals('Boo'));
      expect(changed.next.ghost.lastSettledDay, equals(today.previous));
      expect(changed.next.ghost.resurrectionCount, equals(3));

      final HauntResult again = changed.next.undo('h1');
      expect((again as HauntChanged).resurrected, isFalse);
      expect(again.next.ghost.isDead, isFalse);
      expect(again.next.ghost.resurrectionCount, equals(3));
    });
  });
}
