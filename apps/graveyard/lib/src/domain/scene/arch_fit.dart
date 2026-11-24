import 'dart:math' as math;

import 'arch_fit_result.dart';

/// Places a one-line label inside the half-ellipse arch of a tombstone.
abstract final class ArchFit {
  /// Smallest font size the search will shrink to.
  static const double minFontSize = 12;

  /// Clearance in logical pixels between the line's upper corners and the
  /// arch curve.
  static const double margin = 4;

  /// Number of equal shrink steps between the base size and [minFontSize].
  static const int maxSteps = 40;

  /// Returns the top position, font size and truncation flag for a line.
  ///
  /// The arch is the top half of an ellipse with semi-axes `archWidth / 2`
  /// and `min(archRise, archWidth / 2)`. [textWidth] and [lineHeight] were
  /// measured at [fontSize]; they scale in proportion when the font shrinks.
  /// The search takes at most 40 steps from [fontSize] down to 12. When the
  /// text does not fit at 12, `truncated` is true and `top` is computed for a
  /// line of half the arch width, which is the width the ellipsis text may
  /// use.
  ///
  /// Never throws. An [archWidth] of 0 or less, or any non-finite or
  /// otherwise unusable input, returns top 0, font size 12 and truncated.
  static ArchFitResult positionFor({
    required double archWidth,
    required double archRise,
    required double lineHeight,
    required double textWidth,
    required double fontSize,
  }) {
    const fallback = ArchFitResult(
      top: 0,
      fontSize: minFontSize,
      truncated: true,
    );
    if (!archWidth.isFinite ||
        !archRise.isFinite ||
        !lineHeight.isFinite ||
        !textWidth.isFinite ||
        !fontSize.isFinite ||
        archWidth <= 0 ||
        archRise <= 0 ||
        fontSize <= 0 ||
        textWidth < 0) {
      return fallback;
    }
    final rx = archWidth / 2;
    final ry = math.min(archRise, rx);
    final base = math.max(fontSize, minFontSize);

    for (var step = 0; step <= maxSteps; step++) {
      final size = base + (minFontSize - base) * step / maxSteps;
      final halfWidth = textWidth * (size / fontSize) / 2;
      if (halfWidth + margin < rx) {
        return ArchFitResult(
          top: _topFor(halfWidth, rx, ry),
          fontSize: size,
          truncated: false,
        );
      }
    }
    final cap = math.max(0.0, rx / 2 - margin);
    return ArchFitResult(
      top: _topFor(cap, rx, ry),
      fontSize: minFontSize,
      truncated: true,
    );
  }

  /// Top edge for a line of half-width [halfWidth]: the arc height at
  /// `halfWidth + margin`, plus [margin]. Requires `halfWidth + margin < rx`.
  static double _topFor(double halfWidth, double rx, double ry) {
    final ratio = (halfWidth + margin) / rx;
    final yAllowed = -ry * math.sqrt(math.max(0.0, 1 - ratio * ratio));
    return ry + yAllowed + margin;
  }
}
