import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'ghost_mood.dart';
import 'math/eye_style.dart';
import 'math/mood_pose.dart';
import 'math/mood_traits.dart';
import 'math/mouth_style.dart';

/// Paints one ghost: a round head, straight sides and a three-scallop hem,
/// with a face.
///
/// The painter takes plain colors and picks nothing itself. It reads no theme
/// and no controller. Without [mood] and [pose] it draws the legacy look: two
/// round eyes and no mouth. With a [mood] or a [pose] it draws that mood's
/// face (eyes and mouth), leans, squashes, scales and lifts the body, and
/// fades the body and glow by the pose opacity. The face stays at full
/// strength in [eyeColor].
///
/// The ghost is `0.8` as wide as it is tall (capped by the available width)
/// and centered horizontally. The vertical space `headroom` stays free above
/// and below it, so a [bobOffset] within `[-headroom, headroom]` never moves
/// the ghost out of the box.
class GhostPainter extends CustomPainter {
  /// Creates a ghost painter.
  ///
  /// [bodyColor] fills the body and [eyeColor] fills the eyes. Each shadow in
  /// [glow] is drawn along the ghost outline before the body. [bobOffset]
  /// moves the ghost down (positive) or up, clamped into
  /// `[-headroom, headroom]`, with NaN treated as 0. [mood] draws that mood at
  /// full weight and [pose] draws a mix of moods; [pose] wins when both are
  /// given. [repaint] is passed to [CustomPainter].
  const GhostPainter({
    required this.bodyColor,
    required this.eyeColor,
    this.glow = const <BoxShadow>[],
    this.bobOffset = 0,
    this.headroom = 0,
    this.mood,
    this.pose,
    super.repaint,
  });

  /// Fill color of the ghost body.
  final Color bodyColor;

  /// Fill color of the two eyes.
  final Color eyeColor;

  /// Shadows drawn along the ghost outline, behind the body.
  final List<BoxShadow> glow;

  /// Vertical offset in logical pixels. Positive is down.
  final double bobOffset;

  /// Vertical space kept free above and below the ghost, in logical pixels.
  final double headroom;

  /// Draws this mood at full weight (its face, posture and opacity).
  ///
  /// When both [mood] and [pose] are null the painter draws the legacy look.
  /// Ignored when [pose] is not null.
  final GhostMood? mood;

  /// Draws this mix of moods, with its own opacity, lean, droop, scale and
  /// lift. Wins over [mood] when both are given.
  ///
  /// Non-finite numbers in the pose are replaced by their neutral value.
  final MoodPose? pose;

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    if (!width.isFinite || !height.isFinite || !headroom.isFinite) {
      return;
    }
    if (width <= 0 || height <= 0) {
      return;
    }
    final double room = headroom < 0 ? 0 : headroom;
    final double h = height - 2 * room;
    final double w = math.min(width, 0.8 * h);
    if (!h.isFinite || !w.isFinite || h <= 0 || w <= 0) {
      return;
    }
    final double dy = bobOffset.isNaN ? 0 : bobOffset.clamp(-room, room);

    final GhostMood? moodValue = mood;
    final MoodPose? activePose =
        pose ?? (moodValue == null ? null : MoodPose.rest(moodValue));
    if (activePose != null) {
      _paintMood(canvas, activePose, width, room + dy, h, w);
      return;
    }

    final double cx = width / 2;
    final double left = cx - w / 2;
    final double right = cx + w / 2;
    final double top = room + dy;
    final double bottom = top + h;
    final double scallop = w / 6;

    final Path path = Path()
      ..moveTo(left, top + w / 2)
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, top + w / 2), radius: w / 2),
        math.pi,
        math.pi,
        false,
      )
      ..lineTo(right, bottom - scallop);
    for (int i = 0; i < 3; i++) {
      path.arcTo(
        Rect.fromCircle(
          center: Offset(right - scallop * (2 * i + 1), bottom - scallop),
          radius: scallop,
        ),
        0,
        math.pi,
        false,
      );
    }
    path.close();

    for (final BoxShadow shadow in glow) {
      canvas.drawPath(path.shift(shadow.offset), shadow.toPaint());
    }
    canvas.drawPath(path, Paint()..color = bodyColor);

    final Paint eyePaint = Paint()..color = eyeColor;
    final double eyeRadius = 0.07 * w;
    final double eyeY = top + 0.40 * w;
    canvas.drawCircle(Offset(cx - 0.18 * w, eyeY), eyeRadius, eyePaint);
    canvas.drawCircle(Offset(cx + 0.18 * w, eyeY), eyeRadius, eyePaint);
  }

  static double _sane(double v, double neutral, double lo, double hi) {
    return v.isFinite ? v.clamp(lo, hi) : neutral;
  }

  void _paintMood(
    Canvas canvas,
    MoodPose p,
    double width,
    double top,
    double h,
    double w,
  ) {
    final double opacity = _sane(p.opacity, 1, 0, 1);
    final double lean = _sane(
      p.lean,
      0,
      -MoodTraits.maxLean,
      MoodTraits.maxLean,
    );
    final double droop = _sane(p.droop, 0, -0.10, 0.12);
    final double scale = _sane(p.scale, 1, 1, MoodTraits.fedMaxScale);
    final double lift = _sane(p.lift, 0, 0, MoodTraits.risingMaxLift);

    final double cx = width / 2;
    final double left = cx - w / 2;
    final double right = cx + w / 2;
    final double bottom = top + h;
    final double cy = top + h / 2;
    final double scallop = w / 6;

    final Path path = Path()
      ..moveTo(left, top + w / 2)
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, top + w / 2), radius: w / 2),
        math.pi,
        math.pi,
        false,
      )
      ..lineTo(right, bottom - scallop);
    for (int i = 0; i < 3; i++) {
      path.arcTo(
        Rect.fromCircle(
          center: Offset(right - scallop * (2 * i + 1), bottom - scallop),
          radius: scallop,
        ),
        0,
        math.pi,
        false,
      );
    }
    path.close();

    canvas.save();
    canvas.translate(cx, cy - lift);
    canvas.rotate(lean);
    canvas.scale(scale);
    canvas.translate(-cx, -cy);
    canvas.translate(cx, bottom);
    canvas.scale(1 + droop / 2, 1 - droop);
    canvas.translate(-cx, -bottom);

    for (final BoxShadow shadow in glow) {
      final BoxShadow faded = BoxShadow(
        color: shadow.color.withValues(alpha: shadow.color.a * opacity),
        offset: shadow.offset,
        blurRadius: shadow.blurRadius,
        spreadRadius: shadow.spreadRadius,
        blurStyle: shadow.blurStyle,
      );
      canvas.drawPath(path.shift(faded.offset), faded.toPaint());
    }
    canvas.drawPath(
      path,
      Paint()..color = bodyColor.withValues(alpha: bodyColor.a * opacity),
    );

    final int count = math.min(p.weights.length, GhostMood.values.length);
    for (int i = 0; i < count; i++) {
      final double weight = _sane(p.weights[i], 0, 0, 1);
      if (weight > 0.002) {
        final MoodTraits traits = MoodTraits.of(GhostMood.values[i]);
        final Color color = eyeColor.withValues(alpha: eyeColor.a * weight);
        _paintEyes(canvas, traits.eyes, color, cx, top, w);
        _paintMouth(canvas, traits.mouth, color, cx, top, w);
      }
    }
    canvas.restore();
  }

  static Paint _stroke(Color color, double width) {
    return Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
  }

  static void _paintEyes(
    Canvas canvas,
    EyeStyle style,
    Color color,
    double cx,
    double top,
    double w,
  ) {
    final Paint fill = Paint()..color = color;
    final double y = top + 0.40 * w;
    for (final double side in const <double>[-1, 1]) {
      final Offset c = Offset(cx + side * 0.18 * w, y);
      switch (style) {
        case EyeStyle.round:
          canvas.drawCircle(c, 0.07 * w, fill);
        case EyeStyle.wide:
          canvas.drawCircle(c, 0.095 * w, fill);
        case EyeStyle.droopy:
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.rotate(side * 0.35);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: 0.15 * w,
              height: 0.10 * w,
            ),
            fill,
          );
          canvas.restore();
        case EyeStyle.halfClosed:
          canvas.drawPath(
            Path()
              ..addArc(Rect.fromCircle(center: c, radius: 0.07 * w), 0, math.pi)
              ..close(),
            fill,
          );
        case EyeStyle.cross:
          final Paint line = _stroke(color, 0.035 * w);
          final double d = 0.046 * w;
          canvas.drawLine(c + Offset(-d, -d), c + Offset(d, d), line);
          canvas.drawLine(c + Offset(-d, d), c + Offset(d, -d), line);
        case EyeStyle.happyArc:
          canvas.drawArc(
            Rect.fromCenter(
              center: c + Offset(0, 0.02 * w),
              width: 0.14 * w,
              height: 0.12 * w,
            ),
            math.pi,
            math.pi,
            false,
            _stroke(color, 0.035 * w),
          );
      }
    }
  }

  static void _paintMouth(
    Canvas canvas,
    MouthStyle style,
    Color color,
    double cx,
    double top,
    double w,
  ) {
    final Paint fill = Paint()..color = color;
    final Offset c = Offset(cx, top + 0.62 * w);
    switch (style) {
      case MouthStyle.none:
        break;
      case MouthStyle.smile:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 0.13 * w, c.dy)
            ..quadraticBezierTo(c.dx, c.dy + 0.14 * w, c.dx + 0.13 * w, c.dy),
          _stroke(color, 0.035 * w)..strokeJoin = StrokeJoin.round,
        );
      case MouthStyle.gentleSmile:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 0.08 * w, c.dy)
            ..quadraticBezierTo(c.dx, c.dy + 0.08 * w, c.dx + 0.08 * w, c.dy),
          _stroke(color, 0.03 * w),
        );
      case MouthStyle.wideSmile:
        canvas.drawPath(
          Path()
            ..addArc(Rect.fromCircle(center: c, radius: 0.15 * w), 0, math.pi)
            ..close(),
          fill,
        );
      case MouthStyle.smallOpen:
        canvas.drawOval(
          Rect.fromCenter(center: c, width: 0.08 * w, height: 0.10 * w),
          fill,
        );
      case MouthStyle.flat:
        canvas.drawLine(
          c - Offset(0.07 * w, 0),
          c + Offset(0.07 * w, 0),
          _stroke(color, 0.03 * w),
        );
    }
  }

  @override
  bool shouldRepaint(GhostPainter oldDelegate) {
    return oldDelegate.bodyColor != bodyColor ||
        oldDelegate.eyeColor != eyeColor ||
        oldDelegate.bobOffset != bobOffset ||
        oldDelegate.headroom != headroom ||
        oldDelegate.mood != mood ||
        oldDelegate.pose != pose ||
        !listEquals(oldDelegate.glow, glow);
  }
}
