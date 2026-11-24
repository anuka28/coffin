import 'dart:math' as math;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import '../domain/scene/star.dart';
import '../domain/scene/twinkle.dart';

/// Paints the night sky: a gradient, one moon with a soft glow and the stars.
///
/// The sky is decoration. It uses only [CoffinColorTokens], no image and no
/// package. Hosts wrap it in `ExcludeSemantics`, `IgnorePointer` and their own
/// `RepaintBoundary`. The [twinkle] animation is the repaint listenable, so a
/// twinkle frame repaints the sky and nothing else.
class NightSkyPainter extends CustomPainter {
  /// Creates a sky painter.
  ///
  /// [twinkle] is the Twinkle controller, with values in `[0, 1]` that map to
  /// [twinkleDuration]. Pass `null` for a still sky. When [reducedMotion] is
  /// true every star has the fixed opacity [stillOpacity] and [twinkle] is
  /// ignored for painting.
  NightSkyPainter({
    required this.tokens,
    required this.stars,
    required this.reducedMotion,
    this.twinkle,
    this.twinkleDuration = const Duration(minutes: 10),
  }) : super(repaint: reducedMotion ? null : twinkle);

  /// Opacity of every star when motion is reduced.
  static const double stillOpacity = 0.8;

  /// Moon center as a fraction of the width.
  static const double moonCxFraction = 0.78;

  /// Moon center as a fraction of the height (upper third).
  static const double moonCyFraction = 0.14;

  /// Largest moon radius in logical pixels.
  static const double maxMoonRadius = 36;

  /// The color tokens that give every color of the sky.
  final CoffinColorTokens tokens;

  /// The stars to paint, from `StarField.generate` with the moon geometry of
  /// [moonCx], [moonCy] and [moonRadius] for the same size.
  final List<Star> stars;

  /// Whether motion is reduced (fixed star opacity).
  final bool reducedMotion;

  /// The Twinkle controller, or `null` when there is none.
  final Animation<double>? twinkle;

  /// The time span that [twinkle] covers from 0 to 1.
  final Duration twinkleDuration;

  /// Horizontal moon center for a sky of [width].
  static double moonCx(double width) => width * moonCxFraction;

  /// Vertical moon center for a sky of [height].
  static double moonCy(double height) => height * moonCyFraction;

  /// Moon radius for a sky of [width] by [height]. The moon and its disc stay
  /// inside the upper third.
  static double moonRadius(double width, double height) {
    final r = math.min(width * 0.08, height * 0.1);
    if (!(r > 0)) return 0;
    return math.min(r, maxMoonRadius);
  }

  Color get _moonColor =>
      tokens.brightness == Brightness.dark ? tokens.text : tokens.secondary;

  Color get _starColor =>
      tokens.brightness == Brightness.dark ? tokens.text : tokens.primary;

  @override
  void paint(Canvas canvas, Size size) {
    if (!(size.width > 0) || !(size.height > 0)) return;
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tokens.background, tokens.surface],
        ).createShader(rect),
    );

    final center = Offset(moonCx(size.width), moonCy(size.height));
    final radius = moonRadius(size.width, size.height);
    if (radius > 0) {
      canvas.drawCircle(
        center,
        radius * 1.7,
        Paint()
          ..color = _moonColor.withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.8),
      );
      canvas.drawCircle(center, radius, Paint()..color = _moonColor);
    }

    final elapsedMs = reducedMotion || twinkle == null
        ? 0
        : (twinkle!.value * twinkleDuration.inMilliseconds).round();
    final paint = Paint();
    for (final star in stars) {
      final opacity = reducedMotion
          ? stillOpacity
          : Twinkle.opacityAt(
              phaseMs: star.phaseMs,
              elapsedMs: elapsedMs,
              periodMs: star.periodMs,
            );
      paint.color = _starColor.withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(star.dx, star.dy), star.radius, paint);
    }
  }

  @override
  bool shouldRepaint(NightSkyPainter oldDelegate) =>
      oldDelegate.tokens != tokens ||
      oldDelegate.reducedMotion != reducedMotion ||
      oldDelegate.twinkle != twinkle ||
      oldDelegate.twinkleDuration != twinkleDuration ||
      !_sameStars(oldDelegate.stars, stars);

  static bool _sameStars(List<Star> a, List<Star> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
