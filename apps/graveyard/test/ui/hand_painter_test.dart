import 'dart:ui';

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/resurrection/hand_geometry.dart';
import 'package:graveyard/src/domain/resurrection/hand_shape.dart';
import 'package:graveyard/src/domain/resurrection/play_timing.dart';
import 'package:graveyard/src/ui/hand_painter.dart';

import '../support/recording_canvas.dart';

void main() {
  const size = Size(200, 300);
  final shown = HandGeometry.at(
    width: size.width,
    height: size.height,
    elapsedMs: PlayTiming.handBurstEndMs,
  );

  test('clips to the stone and draws a path per bone and a dot per joint', () {
    final canvas = RecordingCanvas();
    HandPainter(
      shape: shown,
      tokens: CoffinColorTokens.night,
    ).paint(canvas, size);
    final joints = shown.bones.fold<int>(0, (n, b) => n + b.length);
    expect(canvas.count('clipRect'), 1);
    expect(canvas.count('drawCircle'), joints);
    expect(canvas.count('drawPath'), shown.bones.length * 2);
  });

  test('draws nothing but the clip while the hand is hidden', () {
    final canvas = RecordingCanvas();
    HandPainter(
      shape: const HandShape(bones: [], visible: false),
      tokens: CoffinColorTokens.night,
    ).paint(canvas, size);
    expect(canvas.count('clipRect'), 1);
    expect(canvas.count('drawPath'), 0);
    expect(canvas.count('drawCircle'), 0);
  });

  test('shouldRepaint compares the inputs', () {
    final painter = HandPainter(shape: shown, tokens: CoffinColorTokens.night);
    expect(
      painter.shouldRepaint(
        HandPainter(shape: shown, tokens: CoffinColorTokens.night),
      ),
      isFalse,
    );
    expect(
      painter.shouldRepaint(
        HandPainter(shape: shown, tokens: CoffinColorTokens.daylight),
      ),
      isTrue,
    );
    expect(
      painter.shouldRepaint(
        HandPainter(
          shape: const HandShape(bones: [], visible: false),
          tokens: CoffinColorTokens.night,
        ),
      ),
      isTrue,
    );
  });
}
