import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/resurrection/clod.dart';
import 'package:graveyard/src/domain/resurrection/clod_frame.dart';
import 'package:graveyard/src/domain/resurrection/clod_path.dart';

void main() {
  const clod = Clod(
    launchAngleRadians: 0.5,
    launchMs: 100,
    flightMs: 400,
    peakHeightFraction: 0.5,
    sizePx: 6,
  );
  const width = 200.0;
  const height = 300.0;
  const radius = 3.0;

  ClodFrame frameAt(Clod c, int ms, {double w = width, double h = height}) =>
      ClodPath.at(clod: c, width: w, height: h, elapsedMs: ms);

  group('ClodPath', () {
    test('is not visible before launch', () {
      expect(frameAt(clod, 99).visible, isFalse);
      expect(frameAt(clod, 0).visible, isFalse);
    });

    test('is not visible after landing', () {
      expect(frameAt(clod, 501).visible, isFalse);
      expect(frameAt(clod, 5000).visible, isFalse);
    });

    test('sits at its peak height at the midpoint of its flight', () {
      final frame = frameAt(clod, 300);
      expect(frame.visible, isTrue);
      expect(frame.y, closeTo(height - clod.peakHeightFraction * height, 1e-9));
    });

    test('sits on the ground line at launch and at landing', () {
      for (final ms in [100, 500]) {
        final frame = frameAt(clod, ms);
        expect(frame.visible, isTrue);
        expect(frame.y, closeTo(height - radius, 1e-9));
      }
    });

    test('position and size are finite', () {
      for (var ms = 0; ms <= 600; ms += 25) {
        final frame = frameAt(clod, ms);
        expect(frame.x.isFinite, isTrue);
        expect(frame.y.isFinite, isTrue);
        expect(frame.diameter.isFinite, isTrue);
      }
    });

    test('a clod near the stone edge stays inside after the clamp', () {
      const edge = Clod(
        launchAngleRadians: 1.5707963267948966,
        launchMs: 0,
        flightMs: 400,
        peakHeightFraction: 1,
        sizePx: 8,
      );
      for (var ms = 0; ms <= 400; ms += 20) {
        final frame = frameAt(edge, ms, w: 12, h: 40);
        final r = frame.diameter / 2;
        expect(frame.x, inInclusiveRange(r, 12 - r));
        expect(frame.y, inInclusiveRange(r, 40 - r));
      }
    });
  });
}
