import 'package:flutter/painting.dart';

import 'coffin_metrics.dart';

/// Soft-glow decorations. Glows are plain [BoxShadow] values with zero offset.
abstract final class CoffinGlow {
  /// Returns a decoration glowing in [color].
  ///
  /// [intensity] is clamped to [0, 1]; NaN counts as 0. At 0 the decoration
  /// has no shadows. Otherwise two layered shadows are produced: a tight inner
  /// glow and a wide soft halo, both scaled by the alpha of [color].
  /// [fill] is the background color, and [borderRadius] defaults to
  /// [CoffinMetrics.cornerRadius].
  static BoxDecoration decoration({
    required Color color,
    double intensity = 0.5,
    Color? fill,
    BorderRadius? borderRadius,
  }) {
    final double i = intensity.isNaN ? 0.0 : intensity.clamp(0.0, 1.0);
    final BorderRadius radius =
        borderRadius ?? BorderRadius.circular(CoffinMetrics.cornerRadius);

    if (i == 0) {
      return BoxDecoration(
        color: fill,
        borderRadius: radius,
        boxShadow: const <BoxShadow>[],
      );
    }

    return BoxDecoration(
      color: fill,
      borderRadius: radius,
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: color.withValues(alpha: color.a * (0.25 + 0.35 * i)),
          blurRadius: 8 + 16 * i,
          spreadRadius: 0,
          offset: Offset.zero,
        ),
        BoxShadow(
          color: color.withValues(alpha: color.a * (0.10 + 0.20 * i)),
          blurRadius: 24 + 40 * i,
          spreadRadius: 0,
          offset: Offset.zero,
        ),
      ],
    );
  }
}
