// Feature: graveyard-resurrection, Property 13: Clod_Path stays inside the Stone_Area
// Validates: Requirements 8.6, 9.4
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/resurrection/clod.dart';
import 'package:graveyard/src/domain/resurrection/clod_frame.dart';
import 'package:graveyard/src/domain/resurrection/clod_path.dart';
import 'package:graveyard/src/domain/resurrection/clod_path_generator.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

/// A Stone_Area size as a (width, height) pair.
typedef _Size = ({double width, double height});

Generator<_Size> get _anyStoneSize => any.combine2(
  anyStoneWidth,
  anyStoneHeight,
  (double width, double height) => (width: width, height: height),
);

void main() {
  group('Property 13: Clod_Path stays inside the Stone_Area', () {
    Glados3(
      anyGraveId,
      _anyStoneSize,
      anyElapsedMs,
      ExploreConfig(numRuns: numRuns),
    ).test('every visible circle lies in [0, width] x [0, height]', (
      String id,
      _Size size,
      int elapsedMs,
    ) {
      _counter.increment();
      for (final Clod clod in ClodPathGenerator.generate(id)) {
        final ClodFrame frame = ClodPath.at(
          clod: clod,
          width: size.width,
          height: size.height,
          elapsedMs: elapsedMs,
        );
        if (!frame.visible) continue;
        final double r = frame.diameter / 2;
        expect(frame.x - r, greaterThanOrEqualTo(0));
        expect(frame.x + r, lessThanOrEqualTo(size.width));
        expect(frame.y - r, greaterThanOrEqualTo(0));
        expect(frame.y + r, lessThanOrEqualTo(size.height));
      }
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
