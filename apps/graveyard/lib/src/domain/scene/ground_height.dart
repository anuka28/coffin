import 'dart:math' as math;

/// Pure height rule for the ground field that scrolls with the gravestones.
///
/// The ground must reach at least the bottom of the scrolling content and at
/// least the bottom of the visible scene, so it never leaves a gap below the
/// last row or below a short list of stones.
abstract final class GroundHeight {
  /// Returns the height of the ground box.
  ///
  /// [groundTop] is the top edge of the ground box, [contentBottom] is the
  /// bottom of the scrolling content (including bottom padding) and
  /// [viewportHeight] is the height of the scene. The result is the larger of
  /// `contentBottom - groundTop` and `viewportHeight - groundTop`, and never
  /// negative, also when [groundTop] lies below both bottoms.
  static double of({
    required double groundTop,
    required double contentBottom,
    required double viewportHeight,
  }) {
    return math.max(
      0,
      math.max(contentBottom - groundTop, viewportHeight - groundTop),
    );
  }
}
