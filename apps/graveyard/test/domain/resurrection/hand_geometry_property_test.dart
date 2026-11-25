// Feature: graveyard-resurrection, Property 15: The Hand stays inside the Stone_Area
// Validates: Requirements 7.7, 9.3, 9.4
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/resurrection/hand_geometry.dart';
import 'package:graveyard/src/domain/resurrection/hand_shape.dart';
import 'package:graveyard/src/domain/resurrection/stone_point.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 15: The Hand stays inside the Stone_Area', () {
    Glados3(
      anyStoneWidth,
      anyStoneHeight,
      anyElapsedMs,
      ExploreConfig(numRuns: numRuns),
    ).test('every point of every bone lies in [0, width] x [0, height]', (
      double width,
      double height,
      int elapsedMs,
    ) {
      _counter.increment();
      final HandShape shape = HandGeometry.at(
        width: width,
        height: height,
        elapsedMs: elapsedMs,
      );
      if (!shape.visible) {
        expect(shape.bones, isEmpty);
      }
      for (final List<StonePoint> bone in shape.bones) {
        for (final StonePoint p in bone) {
          expect(p.x, inInclusiveRange(0, width));
          expect(p.y, inInclusiveRange(0, height));
        }
      }
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
