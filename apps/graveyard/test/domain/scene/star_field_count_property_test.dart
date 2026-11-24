// Feature: graveyard-scene, Property 3: Star count scales within bounds
// Validates: Requirements 1.3
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/star_field.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

int _count(int seed, num width, num height) => StarField.generate(
  seed: seed,
  width: width.toDouble(),
  height: height.toDouble(),
  moonCx: width * 0.8,
  moonCy: height * 0.15,
  moonRadius: 24,
).length;

int _expected(int width, int height) =>
    (12 + (width * height / 1400).round()).clamp(12, 60);

void main() {
  group('Property 3: Star count scales within bounds', () {
    Glados2(anySeed, anySceneSize, ExploreConfig(numRuns: numRuns)).test(
      'the count follows the area formula and stays within 12..60',
      (int seed, SceneSize size) {
        _counter.increment();
        final int count = _count(seed, size.width, size.height);
        expect(count, _expected(size.width, size.height));
        expect(count, inInclusiveRange(12, 60));
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });

    final RunCounter widening = RunCounter();
    Glados3(
      anySeed,
      anySceneSize,
      anyIntBetween(0, 2001),
      ExploreConfig(numRuns: numRuns),
    ).test('widening at a fixed height never lowers the count', (
      int seed,
      SceneSize size,
      int extraWidth,
    ) {
      widening.increment();
      final int narrow = _count(seed, size.width, size.height);
      final int wide = _count(seed, size.width + extraWidth, size.height);
      expect(wide, greaterThanOrEqualTo(narrow));
    });

    test('widening property ran the configured number of times', () {
      widening.expectRuns(numRuns);
    });
  });
}
