import 'dart:math' as math;

/// WCAG 2.x contrast math on opaque sRGB colors.
///
/// Works on plain `0xAARRGGBB` integers so it has no dependency on Flutter or
/// `dart:ui`. The alpha byte is ignored.
abstract final class WcagContrast {
  /// The AA threshold for normal text (4.5:1).
  static const double aaNormalText = 4.5;

  /// Relative luminance in `[0, 1]` for an opaque `0xAARRGGBB` value.
  ///
  /// The alpha byte is ignored. Black is 0 and white is 1.
  static double relativeLuminance(int argb) {
    final r = _linearize((argb >> 16) & 0xFF);
    final g = _linearize((argb >> 8) & 0xFF);
    final b = _linearize(argb & 0xFF);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Contrast ratio between two `0xAARRGGBB` colors, in `[1, 21]`.
  ///
  /// Symmetric: `ratio(a, b) == ratio(b, a)`. Identical colors give 1.
  static double ratio(int a, int b) {
    final la = relativeLuminance(a);
    final lb = relativeLuminance(b);
    final lighter = math.max(la, lb);
    final darker = math.min(la, lb);
    return (lighter + 0.05) / (darker + 0.05);
  }

  static double _linearize(int channel) {
    final c = channel / 255;
    return c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }
}
