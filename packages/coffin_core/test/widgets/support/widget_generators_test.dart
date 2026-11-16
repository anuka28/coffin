import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;

import 'widget_generators.dart';

/// Draws [count] values from [generator] with a fixed seed.
List<T> _draw<T>(Generator<T> generator, {int count = 2000}) {
  final math.Random random = math.Random(7);
  return <T>[for (int i = 0; i < count; i++) generator(random, 10).value];
}

void main() {
  const int two40 = 1099511627776;

  group('widget generators', () {
    test('anyIntBetween stays in range and spans 2^32', () {
      for (final int v in _draw(anyIntBetween(-3, 4))) {
        expect(v, inInclusiveRange(-3, 3));
      }
      for (final int v in _draw(anyIntBetween(0, 4294967296))) {
        expect(v, inInclusiveRange(0, 4294967295));
      }
    });

    test('anyListBetween respects the length bounds', () {
      for (final List<int> l in _draw(
        anyListBetween<int>(2, 5, anyIntBetween(0, 10)),
        count: 200,
      )) {
        expect(l.length, inInclusiveRange(2, 4));
      }
    });

    test('anySeed stays in 0..2^32-1 and hits the edge seeds', () {
      final List<int> seeds = _draw(anySeed);
      for (final int v in seeds) {
        expect(v, inInclusiveRange(0, 4294967295));
      }
      for (final int edge in edgeSeeds) {
        expect(seeds, contains(edge));
      }
    });

    test('anyWideInt stays in -2^40..2^40 and uses both signs', () {
      final List<int> values = _draw(anyWideInt);
      for (final int v in values) {
        expect(v, inInclusiveRange(-two40, two40));
      }
      expect(values.any((int v) => v < -4294967296), isTrue);
      expect(values.any((int v) => v > 4294967296), isTrue);
    });

    test('anyElapsed stays in range and hits 0, 1, -1 and the periods', () {
      final List<int> values = _draw(anyElapsed);
      for (final int v in values) {
        expect(v, inInclusiveRange(-two40, two40));
      }
      for (final int edge in <int>[0, 1, -1, ...edgePeriods]) {
        expect(values, contains(edge));
      }
    });

    test('anyCount covers negatives and values above 24, within -5..40', () {
      final List<int> values = _draw(anyCount);
      for (final int v in values) {
        expect(v, inInclusiveRange(-5, 40));
      }
      expect(values.any((int v) => v < 0), isTrue);
      expect(values.any((int v) => v > 24), isTrue);
      expect(values, contains(-5));
      expect(values, contains(40));
    });

    test('anySize stays in 0..4000 and includes 0 and 0.5', () {
      final List<double> values = _draw(anySize);
      for (final double v in values) {
        expect(v, inInclusiveRange(0, 4000));
      }
      expect(values, contains(0));
      expect(values, contains(0.5));
      expect(values, contains(1));
    });

    test('anyAmplitude stays in -5..40', () {
      final List<double> values = _draw(anyAmplitude);
      for (final double v in values) {
        expect(v, inInclusiveRange(-5, 40));
      }
      expect(values.any((double v) => v < 0), isTrue);
      expect(values.any((double v) => v > 24), isTrue);
    });

    test('RunCounter counts and resets', () {
      final RunCounter counter = RunCounter();
      expect(counter.runs, 0);
      counter
        ..increment()
        ..increment();
      expect(counter.runs, 2);
      counter.reset();
      expect(counter.runs, 0);
    });
  });
}
