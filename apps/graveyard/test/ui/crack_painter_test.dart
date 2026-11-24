import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/scene/crack.dart';
import 'package:graveyard/src/domain/scene/crack_point.dart';
import 'package:graveyard/src/ui/crack_painter.dart';

import '../support/recording_canvas.dart';

Crack _crack(int offset) => Crack([
  CrackPoint(0, offset),
  CrackPoint(5, offset + 5),
  CrackPoint(10, offset + 2),
]);

const _color = Color(0xB30E0B16);

void main() {
  group('CrackPainter paint', () {
    for (final size in const [Size(120, 160), Size(1, 1), Size.zero]) {
      test('paints without an exception at $size', () {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        final painter = CrackPainter(cracks: [_crack(0)], color: _color);
        expect(() => painter.paint(canvas, size), returnsNormally);
        recorder.endRecording();
      });
    }

    test('paints nothing for an empty crack list', () {
      final canvas = RecordingCanvas();
      const CrackPainter(
        cracks: [],
        color: _color,
      ).paint(canvas, const Size(120, 160));
      expect(canvas.calls, isEmpty);
    });

    test('paints one path per crack', () {
      final canvas = RecordingCanvas();
      CrackPainter(
        cracks: [_crack(0), _crack(20)],
        color: _color,
      ).paint(canvas, const Size(120, 160));
      expect(canvas.count('drawPath'), 2);
    });
  });

  group('CrackPainter shouldRepaint', () {
    CrackPainter make({
      List<Crack>? cracks,
      Color color = _color,
      double strokeWidth = 1.5,
    }) => CrackPainter(
      cracks: cracks ?? [_crack(0)],
      color: color,
      strokeWidth: strokeWidth,
    );

    test('is false for equal inputs', () {
      expect(make().shouldRepaint(make()), isFalse);
    });

    test('is true for a different crack list', () {
      expect(make(cracks: [_crack(3)]).shouldRepaint(make()), isTrue);
      expect(make(cracks: []).shouldRepaint(make()), isTrue);
    });

    test('is true for a different color', () {
      expect(
        make(color: const Color(0xFFFFFFFF)).shouldRepaint(make()),
        isTrue,
      );
    });

    test('is true for a different stroke width', () {
      expect(make(strokeWidth: 3).shouldRepaint(make()), isTrue);
    });
  });
}
