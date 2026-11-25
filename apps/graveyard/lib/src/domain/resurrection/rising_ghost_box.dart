import 'dart:math' as math;

import '../scene/keep_out_rect.dart';
import '../scene/rise_progress.dart';
import 'epitaph_footprint.dart';
import 'ghost_box.dart';
import 'play_timing.dart';

/// Pure function from the stone area size, the text scale and elapsed
/// milliseconds to the box of the rising ghost.
abstract final class RisingGhostBox {
  /// Clear space in logical pixels between the bottom of the epitaph
  /// rectangle and the top of the box once the ghost has risen.
  static const double epitaphGapPx = 8;

  /// Least distance in logical pixels the top of the box travels, so the
  /// ghost always visibly rises.
  static const double minTravelPx = 8;

  /// Smallest box height in logical pixels. A smaller box is not drawn.
  static const double minBoxHeightPx = 16;

  /// Height of the natural box as a multiple of its width.
  static const double aspect = 1.2;

  static const GhostBox _unusable = GhostBox(
    left: 0,
    top: 0,
    width: 0,
    height: 0,
    visible: false,
  );

  /// Returns the box after [elapsedMs] milliseconds of the play.
  ///
  /// The box is centered, `boxH` tall and as wide as the shrink factor
  /// allows (see below). Its top moves from `height - boxH` to the end top
  /// (the bottom of the epitaph footprint plus [epitaphGapPx]) between
  /// [PlayTiming.ghostRiseStartMs] and [PlayTiming.ghostRiseEndMs] along
  /// [RiseProgress], and holds there. Before the rise it rests on the base
  /// of the stone.
  ///
  /// `boxH = min(naturalH, height - endTop - minTravelPx)`, where
  /// `naturalH = min(width * 0.5 * aspect, height * 0.7)`; the width is
  /// scaled by `boxH / naturalH`. When `boxH` is below [minBoxHeightPx] the
  /// result is the hidden zero-area box at the bottom center. Unusable input
  /// (non-finite or non-positive) gives the all-zero hidden box. Never
  /// throws.
  ///
  /// [GhostBox.visible] is true from [PlayTiming.risingGhostStartMs] to
  /// [PlayTiming.playDurationMs], both included.
  static GhostBox at({
    required double width,
    required double height,
    required double textScale,
    required int elapsedMs,
  }) {
    if (!width.isFinite ||
        !height.isFinite ||
        !textScale.isFinite ||
        width <= 0 ||
        height <= 0 ||
        textScale <= 0) {
      return _unusable;
    }
    final KeepOutRect epitaph = EpitaphFootprint.forStone(
      stoneWidth: width,
      textScale: textScale,
    );
    final double endTop = epitaph.bottom + epitaphGapPx;
    final double naturalH = math.min(width * 0.5 * aspect, height * 0.7);
    final double boxH = math.min(naturalH, height - endTop - minTravelPx);
    final hidden = GhostBox(
      left: width / 2,
      top: height,
      width: 0,
      height: 0,
      visible: false,
    );
    if (!naturalH.isFinite ||
        !boxH.isFinite ||
        naturalH <= 0 ||
        boxH < minBoxHeightPx) {
      return hidden;
    }
    final double boxW = width * 0.5 * (boxH / naturalH);
    final double startTop = height - boxH;
    final double progress = RiseProgress.at(_rescale(elapsedMs));
    final double top = startTop + (endTop - startTop) * progress;
    return GhostBox(
      left: (width - boxW) / 2,
      top: top,
      width: boxW,
      height: boxH,
      visible:
          elapsedMs >= PlayTiming.risingGhostStartMs &&
          elapsedMs <= PlayTiming.playDurationMs,
    );
  }

  /// Maps the rise window onto [RiseProgress]'s own domain, like
  /// `HandHeight` does for its phases.
  static int _rescale(int elapsedMs) {
    final int ms = elapsedMs - PlayTiming.ghostRiseStartMs;
    final int span = PlayTiming.ghostRiseEndMs - PlayTiming.ghostRiseStartMs;
    return (ms * RiseProgress.durationMs / span).round();
  }
}
