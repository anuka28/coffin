// Feature: graveyard-scene, Property 1: Star field determinism
// Validates: Requirements 1.4, 1.6
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/star.dart';
import 'package:graveyard/src/domain/scene/star_field.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

List<Star> _generate(int seed, SceneSize size) {
  final double width = size.width.toDouble();
  final double height = size.height.toDouble();
  return StarField.generate(
    seed: seed,
    width: width,
    height: height,
    moonCx: width * 0.8,
    moonCy: height * 0.15,
    moonRadius: 28,
  );
}

void main() {
  group('Property 1: Star field determinism', () {
    Glados2(anySeed, anySceneSize, ExploreConfig(numRuns: numRuns)).test(
      'the same seed, size and moon give equal star lists',
      (int seed, SceneSize size) {
        _counter.increment();
        final List<Star> first = _generate(seed, size);
        final List<Star> second = _generate(seed, size);
        expect(second, equals(first), reason: 'seed $seed, $size');
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
