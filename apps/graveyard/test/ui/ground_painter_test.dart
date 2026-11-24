import 'dart:ui';

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/ui/ground_painter.dart';

void main() {
  group('GroundPainter paint', () {
    for (final size in const [Size(300, 80), Size(1, 1), Size.zero]) {
      test('paints without an exception at $size', () {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        expect(
          () =>
              const GroundPainter(tokens: CoffinColorTokens.night)
                  .paint(canvas, size),
          returnsNormally,
        );
        recorder.endRecording();
      });
    }
  });

  group('GroundPainter shouldRepaint', () {
    test('is false for equal inputs', () {
      const a = GroundPainter(tokens: CoffinColorTokens.night);
      const b = GroundPainter(tokens: CoffinColorTokens.night);
      expect(a.shouldRepaint(b), isFalse);
    });

    test('is true for different tokens', () {
      const a = GroundPainter(tokens: CoffinColorTokens.daylight);
      const b = GroundPainter(tokens: CoffinColorTokens.night);
      expect(a.shouldRepaint(b), isTrue);
    });
  });
}
