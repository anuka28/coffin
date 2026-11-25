import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/rendering.dart';

import '../domain/resurrection/clod.dart';
import '../domain/resurrection/clod_path.dart';

/// Draws the clods of earth thrown by the Hand.
///
/// Every circle comes from `ClodPath.at` for the Stone_Area [Size] the
/// painter is given, so the painter holds no motion logic. The canvas is
/// clipped to the Stone_Area before anything is drawn.
final class ClodsPainter extends CustomPainter {
  /// Creates a painter for [clods] at [elapsedMs] in the colors of [tokens].
  const ClodsPainter({
    required this.clods,
    required this.elapsedMs,
    required this.tokens,
  });

  /// The clods to draw. A play has at most 7.
  final List<Clod> clods;

  /// Milliseconds since the start of the play.
  final int elapsedMs;

  /// The color tokens of the active theme.
  final CoffinColorTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    if (clods.isEmpty) return;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = tokens.secondary;
    final glow = Paint()
      ..style = PaintingStyle.fill
      ..color = tokens.secondary.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    for (final clod in clods) {
      final frame = ClodPath.at(
        clod: clod,
        width: size.width,
        height: size.height,
        elapsedMs: elapsedMs,
      );
      if (!frame.visible) continue;
      final center = Offset(frame.x, frame.y);
      final radius = frame.diameter / 2;
      canvas.drawCircle(center, radius * 1.5, glow);
      canvas.drawCircle(center, radius, fill);
    }
  }

  @override
  bool shouldRepaint(ClodsPainter oldDelegate) =>
      oldDelegate.elapsedMs != elapsedMs ||
      oldDelegate.tokens != tokens ||
      oldDelegate.clods.length != clods.length ||
      !_sameClods(oldDelegate.clods);

  bool _sameClods(List<Clod> other) {
    for (var i = 0; i < clods.length; i++) {
      if (other[i] != clods[i]) return false;
    }
    return true;
  }
}
