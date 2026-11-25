// Feature: graveyard-resurrection, Property 14: Clods report not-visible outside their flight window
// Validates: Requirements 8.7
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/resurrection/clod.dart';
import 'package:graveyard/src/domain/resurrection/clod_frame.dart';
import 'package:graveyard/src/domain/resurrection/clod_path.dart';
import 'package:graveyard/src/domain/resurrection/clod_path_generator.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group(
    'Property 14: Clods report not-visible outside their flight window',
    () {
      // picks: [clod index, before/after flag, distance in ms, stone height].
      Glados3(
        anyGraveId,
        anyStoneWidth,
        anyListBetween(4, 5, anyIntBetween(0, 1000)),
        ExploreConfig(numRuns: numRuns),
      ).test('elapsed before launch or after landing is not visible', (
        String id,
        double width,
        List<int> picks,
      ) {
        _counter.increment();
        final List<Clod> clods = ClodPathGenerator.generate(id);
        final Clod clod = clods[picks[0] % clods.length];
        final int distance = 1 + picks[2];
        final int elapsedMs = picks[1].isEven
            ? clod.launchMs - distance
            : clod.launchMs + clod.flightMs + distance;
        final ClodFrame frame = ClodPath.at(
          clod: clod,
          width: width,
          height: 120.0 + picks[3] % 281,
          elapsedMs: elapsedMs,
        );
        expect(frame.visible, isFalse);
      });

      test('ran the configured number of times', () {
        _counter.expectRuns(numRuns);
      });
    },
  );
}
