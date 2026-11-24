import 'dart:math' as math;

import 'scene_cell.dart';

/// Pure grid layout of tombstones in the graveyard scene.
///
/// All widths are in logical pixels. The scene keeps [sidePadding] free on
/// each side, so every row fits in `availableWidth - 2 * sidePadding`.
abstract final class SceneLayout {
  /// Width from which the scene uses 2 to 4 columns.
  static const double breakpoint = 720;

  /// Smallest tombstone width, unless the space itself is smaller.
  static const double minTombstoneWidth = 240;

  /// Largest tombstone width.
  static const double maxTombstoneWidth = 300;

  /// Horizontal gap between two tombstones.
  static const double gap = 24;

  /// Vertical gap between two rows.
  static const double rowGap = 32;

  /// Free space kept on the left and on the right of the grid.
  static const double sidePadding = 16;

  /// Width left for the grid after both side paddings, never negative.
  static double _usableWidth(double availableWidth) =>
      math.max(0, availableWidth - 2 * sidePadding);

  /// Number of columns for [availableWidth]: 1 below [breakpoint], else the
  /// largest count in 2..4 whose tombstones are at least [minTombstoneWidth]
  /// wide, defaulting to 2.
  static int columnsFor(double availableWidth) {
    if (availableWidth < breakpoint) return 1;
    for (var c = 4; c >= 2; c--) {
      if (_rawWidth(availableWidth, c) >= minTombstoneWidth) return c;
    }
    return 2;
  }

  static double _rawWidth(double availableWidth, int columns) =>
      (_usableWidth(availableWidth) - gap * (columns - 1)) / columns;

  /// Tombstone width for [availableWidth] and [columns].
  ///
  /// The width is clamped to [minTombstoneWidth]..[maxTombstoneWidth]. When
  /// the space per tombstone is below the minimum, that remaining (raw) width
  /// is returned so the row never overflows.
  static double tombstoneWidthFor(double availableWidth, int columns) {
    final raw = _rawWidth(availableWidth, columns);
    if (raw < minTombstoneWidth) return math.max(0, raw);
    return math.min(raw, maxTombstoneWidth);
  }

  /// Cell for grave index [index] of [graveCount] at [availableWidth].
  ///
  /// The whole grid is centered in the available width, and a last row with
  /// fewer tombstones than columns (including a single row when
  /// [graveCount] is below the column count) is centered by shifting `left`
  /// by `(columns - used) * (width + gap) / 2`. [tombstoneHeight] is used for
  /// `top` and defaults to 0.
  static SceneCell cellFor({
    required int index,
    required int graveCount,
    required double availableWidth,
    double tombstoneHeight = 0,
  }) {
    final columns = columnsFor(availableWidth);
    final width = tombstoneWidthFor(availableWidth, columns);
    final row = index ~/ columns;
    final column = index % columns;
    final used = math.min(columns, graveCount - row * columns);
    final gridWidth = columns * width + (columns - 1) * gap;
    final gridLeft =
        sidePadding + (_usableWidth(availableWidth) - gridWidth) / 2;
    final left =
        gridLeft +
        column * (width + gap) +
        (columns - used) * (width + gap) / 2;
    return SceneCell(
      row: row,
      column: column,
      left: left,
      top: row * (tombstoneHeight + rowGap),
      width: width,
    );
  }

  /// Total content height for [graveCount] graves of [tombstoneHeight]; 0
  /// when there are none.
  static double contentHeightFor({
    required int graveCount,
    required double availableWidth,
    required double tombstoneHeight,
  }) {
    if (graveCount <= 0) return 0;
    final columns = columnsFor(availableWidth);
    final rows = (graveCount + columns - 1) ~/ columns;
    return rows * tombstoneHeight + (rows - 1) * rowGap;
  }
}
