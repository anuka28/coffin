// Feature: graveyard-scene, Property 2: Stars stay inside the sky and outside the moon
// Validates: Requirements 1.5
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/star.dart';
import 'package:graveyard/src/domain/scene/star_field.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 2: Stars stay inside the sky and outside the moon', () {
    Glados2(anySeed, anySceneSize, ExploreConfig(numRuns: numRuns)).test(
      'every star is in the sky box and outside the moon circle',
      (int seed, SceneSize size) {
        _counter.increment();
        final double width = size.width.toDouble();
        final double height = size.height.toDouble();
        // A moon in the upper third that leaves room for the stars.
        final double moonRadius = math.min(width, height) * 0.08;
        final double moonCx = width * 0.75;
        final double moonCy = height / 6;

        final List<Star> stars = StarField.generate(
          seed: seed,
          width: width,
          height: height,
          moonCx: moonCx,
          moonCy: moonCy,
          moonRadius: moonRadius,
        );

        for (final Star star in stars) {
          expect(star.dx, inInclusiveRange(0, width), reason: '$star dx');
          expect(
            star.dy,
            inInclusiveRange(0, 0.66 * height),
            reason: '$star dy',
          );
          final double distance = math.sqrt(
            (star.dx - moonCx) * (star.dx - moonCx) +
                (star.dy - moonCy) * (star.dy - moonCy),
          );
          expect(
            distance,
            greaterThanOrEqualTo(moonRadius),
            reason:
                '$star is inside the moon at ($moonCx, $moonCy) '
                'r=$moonRadius',
          );
        }
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
