// Feature: graveyard-resurrection, Property 16: The Rising_Ghost box stays inside the Stone_Area
// Validates: Requirements 7.10, 9.4
// Feature: graveyard-resurrection, Property 17: The Rising_Ghost box rises and then holds still
// Validates: Requirements 7.10, 7.16, 7.17
// Feature: graveyard-resurrection, Property 18: The Rising_Ghost box never covers the epitaph
// Validates: Requirements 7.17
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/resurrection/epitaph_footprint.dart';
import 'package:graveyard/src/domain/resurrection/ghost_box.dart';
import 'package:graveyard/src/domain/resurrection/play_timing.dart';
import 'package:graveyard/src/domain/resurrection/rising_ghost_box.dart';

import '../support/grave_generators.dart';

typedef _Input = ({double width, double height, double scale, int elapsedMs});

Generator<_Input> get _anyInput => any.combine4(
  anyStoneWidth,
  anyStoneHeight,
  anyTextScale,
  anyElapsedMs,
  (double width, double height, double scale, int elapsedMs) =>
      (width: width, height: height, scale: scale, elapsedMs: elapsedMs),
);

typedef _TimedInput = ({
  double width,
  double height,
  double scale,
  int a,
  int b,
});

Generator<_TimedInput> get _anyTimedInput => any.combine5(
  anyStoneWidth,
  anyStoneHeight,
  anyTextScale,
  anyIntBetween(-500, 3301),
  anyIntBetween(-500, 3301),
  (double width, double height, double scale, int x, int y) => (
    width: width,
    height: height,
    scale: scale,
    a: x <= y ? x : y,
    b: x <= y ? y : x,
  ),
);

final RunCounter _counter = RunCounter();
final RunCounter _counter17 = RunCounter();
final RunCounter _counter18 = RunCounter();

Generator<_Input> get _anyLateInput => any.combine4(
  anyStoneWidth,
  anyStoneHeight,
  anyTextScale,
  anyIntBetween(PlayTiming.ghostRiseEndMs, PlayTiming.playDurationMs + 1),
  (double width, double height, double scale, int elapsedMs) =>
      (width: width, height: height, scale: scale, elapsedMs: elapsedMs),
);

void main() {
  group('Property 16: The Rising_Ghost box stays inside the Stone_Area', () {
    Glados(_anyInput, ExploreConfig(numRuns: numRuns)).test(
      'the box lies in [0, width] x [0, height] and is at least the minimum height',
      (_Input input) {
        _counter.increment();
        final GhostBox box = RisingGhostBox.at(
          width: input.width,
          height: input.height,
          textScale: input.scale,
          elapsedMs: input.elapsedMs,
        );
        expect(box.left, greaterThanOrEqualTo(0));
        expect(box.top, greaterThanOrEqualTo(0));
        expect(box.width, isPositive);
        expect(box.height, isPositive);
        expect(box.left + box.width, lessThanOrEqualTo(input.width));
        expect(box.top + box.height, lessThanOrEqualTo(input.height));
        expect(box.height, greaterThanOrEqualTo(RisingGhostBox.minBoxHeightPx));
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });

    Glados(_anyTimedInput, ExploreConfig(numRuns: numRuns)).test(
      'Property 17: the box rises and then holds still',
      (_TimedInput i) {
        _counter17.increment();
        GhostBox at(int ms) => RisingGhostBox.at(
          width: i.width,
          height: i.height,
          textScale: i.scale,
          elapsedMs: ms,
        );
        final GhostBox boxA = at(i.a);
        final GhostBox boxB = at(i.b);
        expect(boxB.top, lessThanOrEqualTo(boxA.top));
        expect(boxB.left, boxA.left);
        expect(boxB.width, boxA.width);
        expect(boxB.height, boxA.height);
        if (i.a >= PlayTiming.ghostRiseEndMs) {
          expect(boxB.top, closeTo(boxA.top, 1e-9));
        }
        final double endTop =
            EpitaphFootprint.forStone(
              stoneWidth: i.width,
              textScale: i.scale,
            ).bottom +
            RisingGhostBox.epitaphGapPx;
        final List<(int, GhostBox)> samples = <(int, GhostBox)>[
          (i.a, boxA),
          (i.b, boxB),
        ];
        for (final (int ms, GhostBox box) in samples) {
          if (ms <= PlayTiming.ghostRiseStartMs) {
            expect(box.top, closeTo(i.height - box.height, 1e-9));
          }
          if (ms >= PlayTiming.ghostRiseEndMs) {
            expect(box.top, closeTo(endTop, 1e-9));
          }
        }
        final GhostBox start = at(PlayTiming.ghostRiseStartMs);
        final GhostBox end = at(PlayTiming.ghostRiseEndMs);
        expect(
          start.top - end.top,
          greaterThanOrEqualTo(RisingGhostBox.minTravelPx - 1e-9),
        );
      },
    );

    test('Property 17 ran the configured number of times', () {
      _counter17.expectRuns(numRuns);
    });

    Glados(_anyLateInput, ExploreConfig(numRuns: numRuns)).test(
      'Property 18: the box never covers the epitaph',
      (_Input input) {
        _counter18.increment();
        final GhostBox box = RisingGhostBox.at(
          width: input.width,
          height: input.height,
          textScale: input.scale,
          elapsedMs: input.elapsedMs,
        );
        final epitaph = EpitaphFootprint.forStone(
          stoneWidth: input.width,
          textScale: input.scale,
        );
        expect(box.top, greaterThanOrEqualTo(epitaph.bottom));
      },
    );

    test('Property 18 ran the configured number of times', () {
      _counter18.expectRuns(numRuns);
    });
  });
}
