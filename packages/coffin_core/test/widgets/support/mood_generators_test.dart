import 'dart:math' as math;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;

import 'mood_generators.dart';

/// Draws [count] values from [generator] with a fixed seed.
List<T> _draw<T>(Generator<T> generator, {int count = 2000}) {
  final math.Random random = math.Random(11);
  return <T>[for (int i = 0; i < count; i++) generator(random, 10).value];
}

void main() {
  group('mood generators', () {
    test('anyMood covers all seven values', () {
      final Set<GhostMood> seen = _draw(anyMood).toSet();
      expect(seen, equals(GhostMood.values.toSet()));
      expect(seen.length, 7);
    });

    test('anyProgress includes the special values, negatives and above 1', () {
      final List<double> values = _draw(anyProgress);
      expect(values.any((double v) => v.isNaN), isTrue);
      expect(values, contains(double.infinity));
      expect(values, contains(double.negativeInfinity));
      expect(values, contains(0));
      expect(values, contains(1));
      expect(values.any((double v) => v.isFinite && v < 0), isTrue);
      expect(values.any((double v) => v.isFinite && v > 1), isTrue);
    });

    test('anyProgress stays in -1.5..2.5 apart from the special values', () {
      for (final double v in _draw(anyProgress)) {
        if (v.isNaN || v.isInfinite) {
          continue;
        }
        expect(v, inInclusiveRange(-1.5, 2.5));
      }
    });

    test('anyChain has 1 to 6 pairs', () {
      final List<List<(GhostMood, double)>> chains = _draw(
        anyChain,
        count: 500,
      );
      for (final List<(GhostMood, double)> chain in chains) {
        expect(chain.length, inInclusiveRange(1, 6));
      }
      final Set<int> lengths = chains
          .map((List<(GhostMood, double)> c) => c.length)
          .toSet();
      expect(lengths, containsAll(<int>[1, 6]));
    });
  });
}
