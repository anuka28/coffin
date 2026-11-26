import 'dart:math' as math;

/// Computes the height reserved for the séance verdict before it arrives.
///
/// Reserving the worst-case height up front means the verdict appearing
/// causes no layout jump. The caller computes `charsPerLine` from the
/// available width, so no width is passed here. Pure Dart, no Flutter
/// imports.
abstract final class VerdictSlotHeight {
  /// Returns the height to reserve for a verdict slot.
  ///
  /// The verdict needs `ceil(maxCodeUnits / charsPerLine)` lines of
  /// [lineHeight] each. The result is never below [minHeight].
  ///
  /// The caller computes [charsPerLine] from the available width. No width
  /// is passed.
  ///
  /// Unusable input (a non-finite value, `charsPerLine <= 0` or a negative
  /// [maxCodeUnits]) returns [minHeight]. This method never throws.
  static double of({
    required double lineHeight,
    required double minHeight,
    required int maxCodeUnits,
    required double charsPerLine,
  }) {
    if (!lineHeight.isFinite ||
        !minHeight.isFinite ||
        !charsPerLine.isFinite ||
        charsPerLine <= 0 ||
        maxCodeUnits < 0) {
      return minHeight;
    }
    final double lines = (maxCodeUnits / charsPerLine).ceilToDouble();
    final double needed = lines * lineHeight;
    if (!needed.isFinite) return minHeight;
    return math.max(minHeight, needed);
  }
}
