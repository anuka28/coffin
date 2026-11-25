import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/resurrection/epitaph_footprint.dart';
import 'package:graveyard/src/domain/resurrection/ghost_box.dart';
import 'package:graveyard/src/domain/resurrection/play_timing.dart';
import 'package:graveyard/src/domain/resurrection/rising_ghost_box.dart';

GhostBox _at(double w, double h, double scale, int ms) =>
    RisingGhostBox.at(width: w, height: h, textScale: scale, elapsedMs: ms);

double _endTop(double w, double scale) =>
    EpitaphFootprint.forStone(stoneWidth: w, textScale: scale).bottom +
    RisingGhostBox.epitaphGapPx;

void main() {
  const allZero = GhostBox(
    left: 0,
    top: 0,
    width: 0,
    height: 0,
    visible: false,
  );

  group('RisingGhostBox', () {
    test('is not visible before risingGhostStartMs', () {
      expect(_at(200, 300, 1, 0).visible, isFalse);
      expect(
        _at(200, 300, 1, PlayTiming.risingGhostStartMs - 1).visible,
        isFalse,
      );
    });

    test('is visible from risingGhostStartMs to playDurationMs', () {
      expect(_at(200, 300, 1, PlayTiming.risingGhostStartMs).visible, isTrue);
      expect(_at(200, 300, 1, 1500).visible, isTrue);
      expect(_at(200, 300, 1, PlayTiming.playDurationMs).visible, isTrue);
    });

    test('is centered', () {
      final GhostBox b = _at(200, 300, 1, 1000);
      expect(b.left, closeTo((200 - b.width) / 2, 1e-9));
    });

    test('rests its bottom edge on the stone base at 600 ms and before', () {
      for (final ms in [0, 300, 600]) {
        final GhostBox b = _at(200, 300, 1, ms);
        expect(b.top + b.height, closeTo(300, 1e-9));
      }
    });

    test('top equals epitaph bottom plus 8 from 2140 to 2800 ms', () {
      final double end = _endTop(200, 1);
      for (final ms in [2140, 2500, 2800]) {
        expect(_at(200, 300, 1, ms).top, closeTo(end, 1e-9));
      }
    });

    test('top is halfway at 1370 ms', () {
      final GhostBox b = _at(200, 300, 1, 1370);
      final double start = 300 - b.height;
      expect(b.top, closeTo((start + _endTop(200, 1)) / 2, 1e-9));
    });

    test('worked example 120x160 at scale 1.0', () {
      final GhostBox a = _at(120, 160, 1, 600);
      expect(a.width, closeTo(60, 0.005));
      expect(a.height, closeTo(72, 0.005));
      expect(a.top, closeTo(88, 0.005));
      // Pinned to the calibrated EpitaphFootprint metrics of task 8.3.
      expect(_at(120, 160, 1, 1370).top, closeTo(66.31, 0.005));
      expect(_at(120, 160, 1, 2140).top, closeTo(44.63, 0.005));
    });

    test('worked example 120x160 at scale 2.0 shrinks the box', () {
      final GhostBox start = _at(120, 160, 2, 600);
      final GhostBox end = _at(120, 160, 2, 2140);
      expect(start.width, lessThan(60));
      expect(start.height, lessThan(72));
      expect(start.height, greaterThanOrEqualTo(16));
      expect(start.top - end.top, greaterThanOrEqualTo(8));
    });

    test('extreme 120x100 at scale 2.0 is the zero-area hidden box', () {
      const hidden = GhostBox(
        left: 60,
        top: 100,
        width: 0,
        height: 0,
        visible: false,
      );
      for (final ms in [0, 600, 1500, 2800]) {
        expect(_at(120, 100, 2, ms), hidden);
      }
    });

    test('unusable input gives the all-zero hidden box', () {
      const bad = [
        double.nan,
        double.infinity,
        double.negativeInfinity,
        0.0,
        -1.0,
      ];
      for (final v in bad) {
        expect(_at(v, 160, 1, 1000), allZero);
        expect(_at(120, v, 1, 1000), allZero);
        expect(_at(120, 160, v, 1000), allZero);
      }
    });

    test('margin: box is at least 16 px tall and never zero-area', () {
      const double minHeight = 16;
      for (var w = 120.0; w <= 400; w += 20) {
        for (var h = 160.0; h <= 480; h += 40) {
          for (var s = 1.0; s <= 2.0; s += 0.25) {
            final GhostBox b = _at(w, h, s, 1500);
            expect(
              b.height,
              greaterThanOrEqualTo(minHeight),
              reason: 'width $w, height $h, text scale $s',
            );
            expect(
              b.width > 0 && b.height > 0,
              isTrue,
              reason: 'zero-area at width $w, height $h, text scale $s',
            );
          }
        }
      }
    });
  });
}
