import 'dart:ui';

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/scene/star.dart';
import 'package:graveyard/src/ui/night_sky_painter.dart';

import '../support/recording_canvas.dart';

const _star = Star(dx: 10, dy: 20, radius: 1.5, phaseMs: 100, periodMs: 3000);

NightSkyPainter _painter({
  CoffinColorTokens tokens = CoffinColorTokens.night,
  List<Star> stars = const [_star],
  bool reducedMotion = false,
}) =>
    NightSkyPainter(tokens: tokens, stars: stars, reducedMotion: reducedMotion);

void main() {
  group('NightSkyPainter paint', () {
    for (final size in const [Size(300, 200), Size(1, 1), Size.zero]) {
      test('paints without an exception at $size', () {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        expect(() => _painter().paint(canvas, size), returnsNormally);
        recorder.endRecording();
      });
    }

    test('paints no star for an empty star list', () {
      final empty = RecordingCanvas();
      _painter(stars: const []).paint(empty, const Size(300, 200));
      final withStars = RecordingCanvas();
      _painter(stars: const [_star, _star, _star])
          .paint(withStars, const Size(300, 200));
      // Moon glow and moon disc are the only circles without stars.
      expect(empty.count('drawCircle'), 2);
      expect(withStars.count('drawCircle'), 5);
    });
  });

  group('NightSkyPainter shouldRepaint', () {
    test('is false for equal inputs', () {
      expect(_painter().shouldRepaint(_painter()), isFalse);
    });

    test('is true for different tokens', () {
      expect(
        _painter(tokens: CoffinColorTokens.daylight).shouldRepaint(_painter()),
        isTrue,
      );
    });

    test('is true for a different star list', () {
      expect(_painter(stars: const []).shouldRepaint(_painter()), isTrue);
    });

    test('is true for a different reduced motion flag', () {
      expect(_painter(reducedMotion: true).shouldRepaint(_painter()), isTrue);
    });
  });
}
