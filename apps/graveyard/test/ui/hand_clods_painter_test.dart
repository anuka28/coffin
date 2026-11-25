import 'dart:ui';

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/resurrection/clod_path_generator.dart';
import 'package:graveyard/src/domain/resurrection/hand_geometry.dart';
import 'package:graveyard/src/domain/resurrection/hand_shape.dart';
import 'package:graveyard/src/domain/resurrection/play_timing.dart';
import 'package:graveyard/src/ui/clods_painter.dart';
import 'package:graveyard/src/ui/hand_painter.dart';

import '../support/geometry_recording_canvas.dart';

const List<Size> _sizes = <Size>[
  Size(120, 160),
  Size(400, 480),
  Size(200, 300),
];
const List<int> _times = <int>[0, 150, 300, 450, 600, 1400, 2800];

HandShape _shape(Size s, int ms) =>
    HandGeometry.at(width: s.width, height: s.height, elapsedMs: ms);

void _expectInside(GeometryRecordingCanvas canvas, Size size) {
  final Rect area = Offset.zero & size;
  for (final RecordedCall call in canvas.drawings) {
    final Rect b = call.bounds;
    expect(
      b.left >= area.left &&
          b.top >= area.top &&
          b.right <= area.right &&
          b.bottom <= area.bottom,
      isTrue,
      reason: '${call.method} ${call.bounds} outside $area',
    );
  }
}

void _expectClipFirst(GeometryRecordingCanvas canvas, Size size) {
  final int firstClip = canvas.calls.indexWhere(
    (RecordedCall c) => c.method == 'clipRect',
  );
  expect(firstClip, 0, reason: 'clipRect must come before any drawing');
  expect(canvas.calls.first.bounds, Offset.zero & size);
}

void main() {
  const CoffinColorTokens tokens = CoffinColorTokens.night;
  final clods = ClodPathGenerator.generate('grave-a');

  group('HandPainter', () {
    for (final Size size in _sizes) {
      for (final int ms in _times) {
        test('draws inside the stone at $ms ms on $size', () {
          final canvas = GeometryRecordingCanvas();
          final HandShape shape = _shape(size, ms);
          HandPainter(shape: shape, tokens: tokens).paint(canvas, size);
          _expectClipFirst(canvas, size);
          _expectInside(canvas, size);
          if (!shape.visible) {
            expect(canvas.drawings, isEmpty);
          } else {
            expect(canvas.drawings, isNotEmpty);
          }
        });
      }
    }

    test('nothing is drawn when the hand is not visible', () {
      final canvas = GeometryRecordingCanvas();
      HandPainter(
        shape: const HandShape(bones: [], visible: false),
        tokens: tokens,
      ).paint(canvas, _sizes.first);
      expect(canvas.drawings, isEmpty);
    });

    test('shouldRepaint is true only when an input changes', () {
      final HandShape a = _shape(_sizes.first, 300);
      final painter = HandPainter(shape: a, tokens: tokens);
      expect(
        painter.shouldRepaint(
          HandPainter(shape: _shape(_sizes.first, 300), tokens: tokens),
        ),
        isFalse,
      );
      expect(
        painter.shouldRepaint(
          HandPainter(shape: _shape(_sizes.first, 150), tokens: tokens),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          HandPainter(shape: a, tokens: CoffinColorTokens.daylight),
        ),
        isTrue,
      );
    });
  });

  group('ClodsPainter', () {
    for (final Size size in _sizes) {
      for (final int ms in _times) {
        test('draws inside the stone at $ms ms on $size', () {
          final canvas = GeometryRecordingCanvas();
          ClodsPainter(
            clods: clods,
            elapsedMs: ms,
            tokens: tokens,
          ).paint(canvas, size);
          _expectClipFirst(canvas, size);
          _expectInside(canvas, size);
          final int circles = canvas.of('drawCircle').length;
          // Each visible clod draws a glow circle and a fill circle.
          expect(circles.isEven, isTrue);
          expect(circles ~/ 2, lessThanOrEqualTo(7));
        });
      }
    }

    test('draws at least one circle while clods fly and none at the end', () {
      final during = GeometryRecordingCanvas();
      ClodsPainter(
        clods: clods,
        elapsedMs: 200,
        tokens: tokens,
      ).paint(during, _sizes[2]);
      expect(during.of('drawCircle'), isNotEmpty);

      final after = GeometryRecordingCanvas();
      ClodsPainter(
        clods: clods,
        elapsedMs: PlayTiming.playDurationMs,
        tokens: tokens,
      ).paint(after, _sizes[2]);
      expect(after.drawings, isEmpty);
    });

    test('shouldRepaint is true only when an input changes', () {
      final painter = ClodsPainter(
        clods: clods,
        elapsedMs: 200,
        tokens: tokens,
      );
      expect(
        painter.shouldRepaint(
          ClodsPainter(
            clods: ClodPathGenerator.generate('grave-a'),
            elapsedMs: 200,
            tokens: tokens,
          ),
        ),
        isFalse,
      );
      expect(
        painter.shouldRepaint(
          ClodsPainter(clods: clods, elapsedMs: 201, tokens: tokens),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          ClodsPainter(
            clods: clods,
            elapsedMs: 200,
            tokens: CoffinColorTokens.daylight,
          ),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          ClodsPainter(
            clods: ClodPathGenerator.generate('grave-b'),
            elapsedMs: 200,
            tokens: tokens,
          ),
        ),
        isTrue,
      );
    });
  });
}
