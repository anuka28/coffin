import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/rendering.dart';

import '../domain/resurrection/hand_shape.dart';

/// Draws the skeletal Hand of the Resurrection_Play.
///
/// Holds no geometry logic: every point comes from the [shape] that
/// `HandGeometry.at` returned. Each bone is stroked as a polyline with round
/// caps, each joint gets a small dot, and a soft blurred glow sits under the
/// bones instead of a hard shadow. The canvas is clipped to the Stone_Area
/// before anything is drawn.
final class HandPainter extends CustomPainter {
  /// Creates a painter for [shape] in the colors of [tokens].
  const HandPainter({required this.shape, required this.tokens});

  /// The Hand to draw, in stone coordinates.
  final HandShape shape;

  /// The color tokens of the active theme.
  final CoffinColorTokens tokens;

  /// Stroke width of a bone in logical pixels.
  static const double boneWidth = 3;

  /// Radius of the dot drawn at each joint in logical pixels.
  static const double jointRadius = 2.5;

  /// Blur sigma of the soft glow in logical pixels.
  static const double glowSigma = 4;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    if (!shape.visible || shape.bones.isEmpty) return;

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = boneWidth * 2.5
      ..color = tokens.primary.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, glowSigma);
    final bonePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = boneWidth
      ..color = tokens.text;
    final jointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = tokens.text;

    for (final bone in shape.bones) {
      if (bone.length < 2) continue;
      final path = Path()..moveTo(bone.first.x, bone.first.y);
      for (var i = 1; i < bone.length; i++) {
        path.lineTo(bone[i].x, bone[i].y);
      }
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, bonePaint);
      for (final point in bone) {
        canvas.drawCircle(Offset(point.x, point.y), jointRadius, jointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(HandPainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.tokens != tokens;
}
