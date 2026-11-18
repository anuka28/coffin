import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart' show expect, equals, isPositive;
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/habit_book.dart';
import 'package:hauntagotchi/src/domain/haunt_result.dart';
import 'package:hauntagotchi/src/domain/haunting.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';
import 'package:hauntagotchi/src/domain/name_rules.dart';

import 'day_plan.dart';
import 'operation.dart';

export 'day_plan.dart';
export 'operation.dart';

// Pure support code: no file or process access. It also runs in Chrome. Every generated
// integer stays far below 2^53.

/// Integers from [min] inclusive to [max] exclusive.
///
/// Use this instead of `any.intInRange`: glados 1.1.7 computes `1 << 32` in
/// its range helper, which is 0 on web. This one calls `Random.nextInt`
/// directly, which works on every platform for ranges below 2^32. Shrinks
/// towards [min] (or 0 when 0 is in range).
Generator<int> anyIntBetween(int min, int max) {
  assert(min < max && max - min <= 0xFFFFFFFF);
  final int target = min <= 0 && max > 0 ? 0 : min;
  return any.simple<int>(
    generate: (math.Random random, int size) => min + random.nextInt(max - min),
    shrink: (int v) sync* {
      if (v > target) {
        yield target + (v - target) ~/ 2;
      } else if (v < target) {
        yield target - (target - v) ~/ 2;
      }
    },
  );
}

/// Lists of [item] with a length from [min] inclusive to [max] exclusive.
///
/// The web-safe counterpart of `any.listWithLengthInRange`. Shrinks by
/// dropping and shrinking elements.
Generator<List<T>> anyListBetween<T>(int min, int max, Generator<T> item) {
  assert(0 <= min && min < max);
  return (math.Random random, int size) {
    final int length = min + random.nextInt(max - min);
    return ShrinkableList<T>(<Shrinkable<T>>[
      for (int i = 0; i < length; i++) item(random, size),
    ], min);
  };
}

/// Counts the runs of a property body. Increment it in the body, then call
/// [expectRuns] in a plain test so a silent skip cannot pass.
final class RunCounter {
  /// Creates a counter at zero.
  RunCounter();

  int _runs = 0;

  /// How many times [increment] was called.
  int get runs => _runs;

  /// Records one run.
  void increment() => _runs++;

  /// Sets the count back to zero.
  void reset() => _runs = 0;

  /// Asserts that at least one run happened and that [runs] equals [numRuns].
  void expectRuns(int numRuns) {
    expect(_runs, isPositive, reason: 'the property body never ran');
    expect(_runs, equals(numRuns), reason: 'run count differs from numRuns');
  }
}

/// First epoch day the generator draws from: 2000-01-01.
const int firstGeneratedEpochDay = 10957;

/// Last epoch day the generator draws from: 2099-12-31.
const int lastGeneratedEpochDay = 47482;

/// Days that sit on calendar edges: leap days, month and year ends, and the
/// daylight saving changes of 2026 in the northern hemisphere.
final List<LocalDay> edgeLocalDays = <LocalDay>[
  LocalDay(2000, 1, 1),
  LocalDay(2000, 2, 29),
  LocalDay(2000, 12, 31),
  LocalDay(2024, 2, 28),
  LocalDay(2024, 2, 29),
  LocalDay(2024, 3, 1),
  LocalDay(2025, 2, 28),
  LocalDay(2025, 3, 1),
  LocalDay(2026, 1, 31),
  LocalDay(2026, 2, 28),
  LocalDay(2026, 3, 8),
  LocalDay(2026, 3, 29),
  LocalDay(2026, 4, 30),
  LocalDay(2026, 10, 25),
  LocalDay(2026, 11, 1),
  LocalDay(2026, 12, 31),
  LocalDay(2027, 1, 1),
  LocalDay(2096, 2, 29),
  LocalDay(2099, 12, 31),
];

/// Generates a [LocalDay] from 2000-01-01 to 2099-12-31, with the days in
/// [edgeLocalDays] about one time in four. Shrinks towards 2000-01-01.
Generator<LocalDay> get anyLocalDay => any.simple<LocalDay>(
  generate: (math.Random random, int size) {
    if (random.nextInt(4) == 0) {
      return edgeLocalDays[random.nextInt(edgeLocalDays.length)];
    }
    return LocalDay.fromEpochDay(
      firstGeneratedEpochDay +
          random.nextInt(lastGeneratedEpochDay - firstGeneratedEpochDay + 1),
    );
  },
  shrink: (LocalDay d) sync* {
    final int e = d.epochDay;
    if (e > firstGeneratedEpochDay) {
      yield LocalDay.fromEpochDay(
        firstGeneratedEpochDay + (e - firstGeneratedEpochDay) ~/ 2,
      );
    }
  },
);

/// Generates habit names: valid (1 to 40 code points, padded or not),
/// over-40 (41 to 60 code points) and whitespace-only (empty included).
///
/// About 60% valid, 20% too long, 20% blank. Shrinks towards `'a'`.
Generator<String> get anyHabitName => any.simple<String>(
  generate: (math.Random random, int size) {
    final int roll = random.nextInt(10);
    if (roll < 6) {
      final int length = random.nextBool()
          ? <int>[1, 2, NameRules.maxLength][random.nextInt(3)]
          : 1 + random.nextInt(NameRules.maxLength);
      return _pad(random, _word(random, length));
    }
    if (roll < 8) {
      final int length = NameRules.maxLength + 1 + random.nextInt(20);
      return _pad(random, _word(random, length));
    }
    final int blanks = random.nextInt(6);
    return <String>[
      for (int i = 0; i < blanks; i++) _blanks[random.nextInt(_blanks.length)],
    ].join();
  },
  shrink: (String s) => s == 'a' ? const <String>[] : const <String>['a'],
);

const List<String> _letters = <String>[
  'a', 'b', 'Z', '7', 'é', 'ß', '漢', '\u{1F47B}', '-', '!', //
];

const List<String> _blanks = <String>[' ', '\t', '\n', '\u00A0', '\u2003'];

String _word(math.Random random, int length) => <String>[
  for (int i = 0; i < length; i++) _letters[random.nextInt(_letters.length)],
].join();

/// Surrounds [core] with blanks half of the time. [core] starts and ends with
/// a letter, so trimming it leaves the same code point count.
String _pad(math.Random random, String core) {
  if (random.nextBool()) return core;
  final String lead = _blanks[random.nextInt(_blanks.length)];
  final String trail = _blanks[random.nextInt(_blanks.length)];
  return '$lead$core$trail';
}

/// Health values at the edges of the bands.
const List<int> healthEdges = <int>[0, 1, 24, 25, 49, 50, 79, 80, 100];

/// Generates a Health from 0 to 100, with the band edges in [healthEdges]
/// about half of the time. Shrinks towards 0.
Generator<int> get anyHealth => any.simple<int>(
  generate: (math.Random random, int size) => random.nextBool()
      ? healthEdges[random.nextInt(healthEdges.length)]
      : random.nextInt(101),
  shrink: (int v) => v == 0 ? const <int>[] : <int>[v ~/ 2],
);

/// Generates a valid [Habit] with the given [id], created up to 400 days
/// before [today].
///
/// About a third are archived on a day from the creation day to [today].
/// Completions fall only on days when the habit was active (up to 12 of
/// them). Names are valid and trimmed. Shrinks by dropping completions.
Generator<Habit> anyHabit(LocalDay today, {String id = 'h1'}) =>
    any.simple<Habit>(
      generate: (math.Random random, int size) =>
          _randomHabit(random, id, today),
      shrink: (Habit h) sync* {
        if (h.completedDays.isNotEmpty) {
          yield h.copyWith(completedDays: <LocalDay>{});
        }
      },
    );

/// Generates a [HabitBook] of 0 to 6 habits (ids `h1`, `h2`, ...) with
/// archive offsets and completion offsets, run through [HabitBook.restore]
/// so at most [HabitBook.maxActive] habits are active.
///
/// Shrinks by dropping the last habit.
Generator<HabitBook> anyBook(LocalDay today) => any.simple<HabitBook>(
  generate: (math.Random random, int size) {
    final int count = random.nextInt(7);
    return HabitBook.restore(<Habit>[
      for (int i = 1; i <= count; i++) _randomHabit(random, 'h$i', today),
    ], today: today);
  },
  shrink: (HabitBook b) sync* {
    if (b.all.isNotEmpty) {
      yield HabitBook(b.all.take(b.all.length - 1));
    }
  },
);

/// Generates a [Ghost] with a valid name, a Health from 0 to 100,
/// a last settled day 0 to 400 days before [today] and 0 to 20 resurrections.
///
/// Dead ghosts (Health 0) appear about one time in ten. Shrinks towards a
/// ghost with Health 0 and no resurrections.
Generator<Ghost> anyGhost(LocalDay today) => any.simple<Ghost>(
  generate: (math.Random random, int size) => Ghost(
    name: NameRules.normalize(
      _word(random, 1 + random.nextInt(NameRules.maxLength)),
    ),
    health: random.nextInt(10) == 0
        ? 0
        : random.nextBool()
        ? healthEdges[random.nextInt(healthEdges.length)]
        : random.nextInt(101),
    lastSettledDay: today.addDays(-random.nextInt(401)),
    resurrectionCount: random.nextInt(21),
  ),
  shrink: (Ghost g) sync* {
    if (g.resurrectionCount > 0) {
      yield Ghost(
        name: g.name,
        health: g.health,
        lastSettledDay: g.lastSettledDay,
      );
    }
    if (g.health > 0) {
      yield Ghost(
        name: g.name,
        health: g.health ~/ 2,
        lastSettledDay: g.lastSettledDay,
        resurrectionCount: g.resurrectionCount,
      );
    }
  },
);

Habit _randomHabit(math.Random random, String id, LocalDay today) {
  final LocalDay created = today.addDays(-random.nextInt(401));
  final int span = created.daysUntil(today);
  LocalDay? archived;
  if (random.nextInt(3) == 0) {
    archived = created.addDays(random.nextInt(span + 1));
  }
  // Days on which the habit counted as active: created up to (excluding)
  // the archive day, or through today while active.
  final int activeDays = archived == null
      ? span + 1
      : created.daysUntil(archived);
  final Set<LocalDay> done = <LocalDay>{};
  if (activeDays > 0) {
    final int picks = random.nextInt(13);
    for (int i = 0; i < picks; i++) {
      // Bias towards recent days so streaks appear.
      final int back = random.nextBool()
          ? random.nextInt(activeDays < 4 ? activeDays : 4)
          : random.nextInt(activeDays);
      done.add(created.addDays(activeDays - 1 - back));
    }
  }
  final String name = NameRules.normalize(
    _word(random, 1 + random.nextInt(NameRules.maxLength)),
  );
  return Habit(
    id: id,
    name: name,
    createdDay: created,
    completedDays: done,
    archivedDay: archived,
  );
}

/// Generates an [Operation]: add, rename, archive, complete, undo or advance.
///
/// Complete and undo are the most common. Advances are 0 to 30 days, and
/// about one in ten is a long jump of up to 10,000 days. Shrinks towards
/// `AdvanceDaysOp(0)`.
Generator<Operation> get anyOperation => any.simple<Operation>(
  generate: (math.Random random, int size) {
    final int index = random.nextInt(8);
    switch (random.nextInt(10)) {
      case 0:
        return AddHabitOp(_randomName(random));
      case 1:
        return RenameHabitOp(index, _randomName(random));
      case 2:
        return ArchiveHabitOp(index);
      case 3:
      case 4:
      case 5:
        return CompleteOp(index);
      case 6:
      case 7:
        return UndoOp(index);
      default:
        return AdvanceDaysOp(
          random.nextInt(10) == 0 ? random.nextInt(10001) : random.nextInt(31),
        );
    }
  },
  shrink: (Operation op) sync* {
    if (op is AdvanceDaysOp) {
      if (op.days > 0) yield AdvanceDaysOp(op.days ~/ 2);
    } else {
      yield const AdvanceDaysOp(0);
    }
  },
);

String _randomName(math.Random random) {
  final int roll = random.nextInt(10);
  if (roll < 7) return _word(random, 1 + random.nextInt(NameRules.maxLength));
  if (roll < 9) return _word(random, NameRules.maxLength + 1);
  return '  ';
}

/// Applies [op] to [haunting] and returns the next [Haunting].
///
/// A rejected action returns [haunting] unchanged. A habit operation picks
/// its habit by `index` into `book.all` (wrapping), or an unknown id when the
/// book is empty. [AdvanceDaysOp] moves today with `addDays` and then calls
/// `syncTo`.
Haunting applyOp(Haunting haunting, Operation op) {
  String idFor(HabitOp o) {
    final List<Habit> all = haunting.book.all.toList();
    return all.isEmpty ? 'h0' : all[o.index % all.length].id;
  }

  final HauntResult result;
  switch (op) {
    case AdvanceDaysOp(:final days):
      return haunting.syncTo(haunting.today.addDays(days));
    case AddHabitOp(:final name):
      result = haunting.addHabit(name);
    case RenameHabitOp(:final name):
      result = haunting.renameHabit(idFor(op), name);
    case ArchiveHabitOp():
      result = haunting.archiveHabit(idFor(op));
    case CompleteOp():
      result = haunting.complete(idFor(op));
    case UndoOp():
      result = haunting.undo(idFor(op));
  }
  return switch (result) {
    HauntChanged(:final next) => next,
    HauntRejected() => haunting,
  };
}

/// Generates a [DayPlan] with 1 to 5 active habits and 0 to all of them
/// completed. Shrinks towards `DayPlan(1, 0)`.
Generator<DayPlan> get anyDayPlan => any.simple<DayPlan>(
  generate: (math.Random random, int size) {
    final int n = 1 + random.nextInt(5);
    return DayPlan(n, random.nextInt(n + 1));
  },
  shrink: (DayPlan p) sync* {
    if (p.c > 0) yield DayPlan(p.n, p.c - 1);
    if (p.n > 1) yield DayPlan(p.n - 1, p.c > p.n - 1 ? p.n - 1 : p.c);
  },
);

/// Turns [plans] into steady effort: in every 7-day window (and every
/// shorter prefix) at least 5 days qualify, which is at most 2 bad days.
///
/// Walks the list in order. A bad day that would be the third bad day in the
/// 7 days ending on it is raised to all habits done. Other days stay as they
/// are. The result has the same length.
List<DayPlan> normalizeSteady(List<DayPlan> plans) {
  final List<DayPlan> out = <DayPlan>[];
  for (final DayPlan plan in plans) {
    final int start = out.length < 6 ? 0 : out.length - 6;
    final int badBefore = out.skip(start).where((p) => !p.qualifies).length;
    out.add(!plan.qualifies && badBefore >= 2 ? DayPlan(plan.n, plan.n) : plan);
  }
  return out;
}
