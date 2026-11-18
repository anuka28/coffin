// Feature: hauntagotchi-core, Property 10: Feeding raises Health and neglect lowers it
// Validates: Requirements 5.1, 5.3
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart'
    show equals, expect, greaterThan, group, lessThan, test;
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:hauntagotchi/src/domain/balance.dart';
import 'package:hauntagotchi/src/domain/catch_up.dart';

import 'support/haunt_generators.dart';

const int _numRuns = 200;
final RunCounter _feedRuns = RunCounter();
final RunCounter _neglectRuns = RunCounter();

/// Active count [n] (1 to 5), completed count [c] (1 to [n]) and a Health [h].
final class _Day {
  const _Day(this.n, this.c, this.h);

  final int n;
  final int c;
  final int h;

  @override
  String toString() => 'n=$n, c=$c, h=$h';
}

/// A day with at least one completion and a living, not full ghost (1 to 99).
Generator<_Day> get _anyFedDay => any.simple<_Day>(
  generate: (math.Random random, int size) {
    final int n = 1 + random.nextInt(5);
    return _Day(n, 1 + random.nextInt(n), 1 + random.nextInt(99));
  },
  shrink: (_Day d) sync* {
    if (d.n > 1) yield _Day(d.n - 1, math.min(d.c, d.n - 1), d.h);
    if (d.c > 1) yield _Day(d.n, d.c - 1, d.h);
    if (d.h > 1) yield _Day(d.n, d.c, d.h ~/ 2 < 1 ? 1 : d.h ~/ 2);
  },
);

/// A day with no completion and a living ghost (Health 1 to 100).
Generator<_Day> get _anyNeglectDay => any.simple<_Day>(
  generate: (math.Random random, int size) =>
      _Day(1 + random.nextInt(5), 0, 1 + random.nextInt(100)),
  shrink: (_Day d) sync* {
    if (d.n > 1) yield _Day(d.n - 1, 0, d.h);
    if (d.h > 1) yield _Day(d.n, 0, d.h ~/ 2 < 1 ? 1 : d.h ~/ 2);
  },
);

void main() {
  group('Property 10: feeding raises Health and neglect lowers it', () {
    Glados(_anyFedDay, ExploreConfig(numRuns: _numRuns)).test(
      'completing a habit raises the Health of a living ghost',
      (_Day d) {
        _feedRuns.increment();
        final int live = math.min(
          Balance.maxHealth,
          d.h + Balance.feed(d.n, d.c),
        );
        expect(Balance.feed(d.n, d.c), greaterThan(0));
        expect(live, greaterThan(d.h));
        expect(CatchUp.settleDay(d.h, d.n, d.c), equals(live));
      },
    );

    Glados(_anyNeglectDay, ExploreConfig(numRuns: _numRuns)).test(
      'a neglect day lowers the Health of a living ghost',
      (_Day d) {
        _neglectRuns.increment();
        expect(CatchUp.settleDay(d.h, d.n, 0), lessThan(d.h));
      },
    );

    test('the property bodies ran numRuns times', () {
      _feedRuns.expectRuns(_numRuns);
      _neglectRuns.expectRuns(_numRuns);
    });

    test('edges: a full ghost stays full and a dead ghost stays dead', () {
      expect(CatchUp.settleDay(100, 3, 1), equals(100));
      expect(CatchUp.settleDay(0, 3, 0), equals(0));
    });
  });
}
