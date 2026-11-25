import 'dart:math' as math;

import '../scene/arch_fit.dart';
import '../scene/keep_out_rect.dart';

/// The epitaph rectangle of a stone, computed without measuring text.
///
/// It calls the real `ArchFit.positionFor` with text metrics from a fixed
/// model instead of a `TextPainter`, then builds the rectangle the way
/// `ArchEpitaph._layout` does: centered, width clamped to the stone, height
/// scaled with the fitted font size. The model is conservative: it may put
/// the rectangle lower or larger than the painted one, never higher or
/// smaller.
abstract final class EpitaphFootprint {
  /// Arch rise in logical pixels; equal to `ArchEpitaph.archRise`.
  static const double archRise = 140;

  /// Base font size at text scale 1; equal to `ArchEpitaph.baseFontSize`.
  static const double baseFontSize = 20;

  /// Letter spacing in logical pixels; equal to `ArchEpitaph.letterSpacing`.
  static const double letterSpacing = 2;

  /// Line height as a multiple of the font size (calibrated against Creepster, rounded up).
  static const double lineHeightPerFontPx = 1.20;

  /// Glyph advance sum of "R.I.P." per font pixel (calibrated against Creepster, rounded up).
  static const double ripAdvancePerFontPx = 1.70;

  /// Glyph advance sum of "RISEN" per font pixel (calibrated against Creepster, rounded up).
  static const double risenAdvancePerFontPx = 2.20;

  /// Lower bound of the "R.I.P." advance sum per font pixel. It places the
  /// top edge, which a narrower line moves up.
  static const double ripAdvanceFloorPerFontPx = 1.50;

  /// Lower bound of the "RISEN" advance sum per font pixel.
  static const double risenAdvanceFloorPerFontPx = 2.00;

  static const KeepOutRect _zero = KeepOutRect(
    left: 0,
    top: 0,
    right: 0,
    bottom: 0,
  );

  /// The rectangle, in stone coordinates, that covers both epitaph texts
  /// ("R.I.P." and "RISEN") for a stone of [stoneWidth] at [textScale]: the
  /// smallest rectangle enclosing the two per-text rectangles. Never throws;
  /// unusable input returns the zero rectangle at the origin.
  static KeepOutRect forStone({
    required double stoneWidth,
    required double textScale,
  }) {
    if (!stoneWidth.isFinite ||
        !textScale.isFinite ||
        stoneWidth <= 0 ||
        textScale <= 0) {
      return _zero;
    }
    final double scaledBase = baseFontSize * textScale;
    final KeepOutRect rip = _forText(
      stoneWidth: stoneWidth,
      scaledBase: scaledBase,
      advancePerFontPx: ripAdvancePerFontPx,
      advanceFloorPerFontPx: ripAdvanceFloorPerFontPx,
      glyphCount: 6,
    );
    final KeepOutRect risen = _forText(
      stoneWidth: stoneWidth,
      scaledBase: scaledBase,
      advancePerFontPx: risenAdvancePerFontPx,
      advanceFloorPerFontPx: risenAdvanceFloorPerFontPx,
      glyphCount: 5,
    );
    final KeepOutRect union = KeepOutRect(
      left: math.min(rip.left, risen.left),
      top: math.min(rip.top, risen.top),
      right: math.max(rip.right, risen.right),
      bottom: math.max(rip.bottom, risen.bottom),
    );
    if (!union.left.isFinite ||
        !union.top.isFinite ||
        !union.right.isFinite ||
        !union.bottom.isFinite) {
      return _zero;
    }
    return union;
  }

  static KeepOutRect _forText({
    required double stoneWidth,
    required double scaledBase,
    required double advancePerFontPx,
    required double advanceFloorPerFontPx,
    required int glyphCount,
  }) {
    final double textWidth =
        advancePerFontPx * scaledBase + glyphCount * letterSpacing;
    final double lineHeight = lineHeightPerFontPx * scaledBase;
    final fit = ArchFit.positionFor(
      archWidth: stoneWidth,
      archRise: archRise,
      lineHeight: lineHeight,
      textWidth: textWidth,
      fontSize: scaledBase,
    );
    // The arch puts a narrower line higher, so the top edge comes from a
    // lower bound of the text width, while the other edges come from the
    // upper bound.
    final lowFit = ArchFit.positionFor(
      archWidth: stoneWidth,
      archRise: archRise,
      lineHeight: lineHeight,
      textWidth:
          advanceFloorPerFontPx * scaledBase + glyphCount * letterSpacing,
      fontSize: scaledBase,
    );
    final double scale = fit.fontSize / scaledBase;
    final double w =
        (fit.truncated ? stoneWidth - 2 * ArchFit.margin : textWidth * scale)
            .clamp(0.0, stoneWidth);
    final double left = (stoneWidth - w) / 2;
    return KeepOutRect(
      left: left,
      top: math.min(lowFit.top, fit.top),
      right: left + w,
      bottom: fit.top + lineHeight * scale,
    );
  }
}
