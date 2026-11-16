import 'dart:math' as math;

import 'package:coffin_core/src/common/seeded_random.dart';
import 'package:flutter_test/flutter_test.dart'
    show TestFailure, expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;

import '../ai/support/ai_generators.dart';

const int _numRuns = 300;
final RunCounter _runs = RunCounter();

final BigInt _m = BigInt.from(0xFFFFFFFF);

BigInt _imul(BigInt a, BigInt b) => (a * b) & _m;

/// Independent Mulberry32 written with BigInt and explicit 32-bit masks.
List<int> _reference(int seed, int count) {
  BigInt state = BigInt.from(seed) & _m;
  final List<int> out = <int>[];
  for (int i = 0; i < count; i++) {
    state = (state + BigInt.from(0x6D2B79F5)) & _m;
    BigInt t = state;
    t = _imul(t ^ (t >> 15), t | BigInt.one);
    t = (t ^ ((t + _imul(t ^ (t >> 7), t | BigInt.from(61))) & _m)) & _m;
    out.add(((t ^ (t >> 14)) & _m).toInt());
  }
  return out;
}

const List<int> _edgeLimits = <int>[1, 2, 3, 7, 1000, 65535, 65536];

/// Limits from 1 to 65536: about 30% edges, otherwise `anyIntBetween`.
Generator<int> get _anyLimit {
  final Generator<int> wide = anyIntBetween(1, 65537);
  return any.simple<int>(
    generate: (math.Random random, int size) {
      if (random.nextInt(100) < 30) {
        return _edgeLimits[random.nextInt(_edgeLimits.length)];
      }
      return wide(random, size).value;
    },
    shrink: (int v) => v <= 1 ? const <int>[] : <int>[1 + (v - 1) ~/ 2],
  );
}

void main() {
  group('reference sanity check (design.md table)', () {
    const Map<int, List<int>> table = <int, List<int>>{
      0: <int>[1144304738, 1416247, 958946056],
      1: <int>[2693262067, 11749833, 2265367787],
      42: <int>[2581720956, 1925393290, 3661312704],
      4294967295: <int>[3850105811, 813802916, 3073704848],
    };
    for (final MapEntry<int, List<int>> e in table.entries) {
      test('BigInt reference reproduces seed ${e.key}', () {
        expect(_reference(e.key, 3), e.value);
      });
    }
  });

  group('SeededRandom property: matches an independent reference', () {
    // Feature: coffin-ai, Property 17: The PRNG matches an independent reference
    // Validates: Requirements 5.4
    Glados2(anySeed, _anyLimit, ExploreConfig(numRuns: _numRuns)).test(
      'first 20 values equal the BigInt reference, nextInt stays in range',
      (int seed, int n) {
        _runs.increment();
        final List<int> expected = _reference(seed, 20);
        final SeededRandom actual = SeededRandom(seed);
        for (int i = 0; i < 20; i++) {
          final int got = actual.nextUint32();
          if (got != expected[i]) {
            throw TestFailure(
              'seed=$seed index=$i actual=$got reference=${expected[i]}',
            );
          }
        }
        final SeededRandom bounded = SeededRandom(seed);
        for (int i = 0; i < 20; i++) {
          final int v = bounded.nextInt(n);
          if (v < 0 || v >= n) {
            throw TestFailure('seed=$seed index=$i n=$n nextInt=$v');
          }
        }
      },
    );

    test('the property ran 300 times', () {
      expect(_runs.runs, greaterThan(0));
      expect(_runs.runs, _numRuns);
    });
  });
}
