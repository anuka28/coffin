import 'dart:ui';

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/resurrection/clod_path.dart';
import 'package:graveyard/src/domain/resurrection/clod_path_generator.dart';
import 'package:graveyard/src/ui/clods_painter.dart';

import '../support/recording_canvas.dart';

void main() {
  const size = Size(200, 300);
  final clods = ClodPathGenerator.generate('grave-1');

  int visibleAt(int ms) => clods
      .where(
        (c) => ClodPath.at(
          clod: c,
          width: size.width,
          height: size.height,
          elapsedMs: ms,
        ).visible,
      )
      .length;

  test('clips first and draws one circle pair per visible clod', () {
    for (final ms in <int>[0, 150, 300, 450, 2000]) {
      final canvas = RecordingCanvas();
      ClodsPainter(
        clods: clods,
        elapsedMs: ms,
        tokens: CoffinColorTokens.night,
      ).paint(canvas, size);
      expect(canvas.count('clipRect'), 1);
      expect(canvas.count('drawCircle'), visibleAt(ms) * 2);
      expect(visibleAt(ms), lessThanOrEqualTo(7));
    }
  });

  test('shouldRepaint compares the inputs', () {
    final painter = ClodsPainter(
      clods: clods,
      elapsedMs: 100,
      tokens: CoffinColorTokens.night,
    );
    ClodsPainter other({int ms = 100, CoffinColorTokens? t}) => ClodsPainter(
      clods: clods,
      elapsedMs: ms,
      tokens: t ?? CoffinColorTokens.night,
    );
    expect(painter.shouldRepaint(other()), isFalse);
    expect(painter.shouldRepaint(other(ms: 200)), isTrue);
    expect(painter.shouldRepaint(other(t: CoffinColorTokens.daylight)), isTrue);
    expect(
      painter.shouldRepaint(
        ClodsPainter(
          clods: clods.sublist(1),
          elapsedMs: 100,
          tokens: CoffinColorTokens.night,
        ),
      ),
      isTrue,
    );
  });
}
