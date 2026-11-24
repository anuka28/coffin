import 'dart:math' as math;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

/// Paints the ground strip: the theme `background` color with a soft top edge that
/// fades into the sky.
///
/// The painter fills the box it is given. The host sizes and places it at the
/// bottom of the scene. Hosts wrap it in `ExcludeSemantics` and `IgnorePointer`.
class GroundPainter extends CustomPainter {
  /// Creates a ground painter that takes its color from [tokens].
  const GroundPainter({required this.tokens});

  /// Largest height of the soft edge in logical pixels.
  static const double maxSoftEdge = 24;

  /// The color tokens that give the ground color.
  final CoffinColorTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    if (!(size.width > 0) || !(size.height > 0)) return;
    final ground = tokens.background;
    final edge = math.min(maxSoftEdge, size.height / 2);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ground.withValues(alpha: 0), ground, ground],
          stops: [0, edge / size.height, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(GroundPainter oldDelegate) => oldDelegate.tokens != tokens;
}
