// Feature: hauntagotchi-core, Property 13: A fully done day beats a neglect day
// Validates: Requirements 5.6, 5.7
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart'
    show equals, expect, greaterThan, greaterThanOrEqualTo, group, test;
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:hauntagotchi/src/domain/balance.dart';
import 'package:hauntagotchi/src/domain/catch_up.dart';

import 'support/haunt_generators.dart';

const int _numRuns = 200;
final RunCounter _gainRuns = RunCounter();
final RunCounter _compareRuns = RunCounter();

/// Active count [n] (1 to 5) with every habit done, and a Health [h].
final class _FullDay {
  const _FullDay(this.n, this.h);

  final int n;
  final int h;

  @override
  String toString() => 'n=$n, h=$h';
}

/// A fully done day for a living ghost with Health from [minH] to [maxH].
Generator<_FullDay> _anyFullDay(int minH, int maxH) => any.simple<_FullDay>(
  generate: (math.Random random, int size) =>
      _FullDay(1 + random.nextInt(5), minH + random.nextInt(maxH - minH + 1)),
  shrink: (_FullDay d) sync* {
    if (d.n > 1) yield _FullDay(d.n - 1, d.h);
    if (d.h > minH) yield _FullDay(d.n, minH + (d.h - minH) ~/ 2);
  },
);

void main() {
  group('Property 13: a fully done day beats a neglect day', () {
    // Health 1 to 84: a full day adds at least the 15 a neglect day removes.
    Glados(_anyFullDay(1, 84), ExploreConfig(numRuns: _numRuns)).test(
      'a fully done day raises living Health by at least 15',
      (_FullDay d) {
        _gainRuns.increment();
        final int fed = CatchUp.settleDay(d.h, d.n, d.n);
        expect(Balance.feed(d.n, d.n), equals(20));
        expect(fed - d.h, greaterThanOrEqualTo(15));
        expect(
          math.min(Balance.maxHealth, d.h + Balance.feed(d.n, d.n)) - d.h,
          greaterThanOrEqualTo(15),
        );
      },
    );

    // Health 15 to 80: neither the feed nor the loss reaches a clamp.
    Glados(_anyFullDay(15, 80), ExploreConfig(numRuns: _numRuns)).test(
      'the gain of a fully done day is greater than the neglect loss',
      (_FullDay d) {
        _compareRuns.increment();
        final int gain = CatchUp.settleDay(d.h, d.n, d.n) - d.h;
        final int loss = d.h - CatchUp.settleDay(d.h, d.n, 0);
        expect(gain, equals(Balance.feed(d.n, d.n)));
        expect(loss, equals(Balance.neglectLoss));
        expect(gain, greaterThan(loss));
      },
    );

    test('the property bodies ran numRuns times', () {
      _gainRuns.expectRuns(_numRuns);
      _compareRuns.expectRuns(_numRuns);
    });

    test('feed(n, n) is 20 for every n from 1 to 5', () {
      for (int n = 1; n <= 5; n++) {
        expect(Balance.feed(n, n), equals(20));
        expect(Balance.feed(n, n), greaterThan(Balance.neglectLoss));
      }
    });
  });
}
