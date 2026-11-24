import 'crack.dart';
import 'crack_point.dart';
import 'keep_out_rect.dart';
import 'stable_hash.dart';
import 'stable_random.dart';

/// Generates the cracks shown near the base of an old tombstone.
///
/// The result depends only on the grave id and the stone geometry. The day
/// count is used solely to decide whether the grave is old enough.
abstract final class CrackGenerator {
  /// Cracks appear only when the day count is strictly above this value.
  static const int ageThresholdDays = 1825;

  /// Fewest cracks on one stone.
  static const int minCracks = 1;

  /// Most cracks on one stone.
  static const int maxCracks = 3;

  /// Distance kept from the left and right edges of the stone.
  static const double sideInset = 20;

  /// Distance kept from the bottom edge of the stone.
  static const double baseInset = 6;

  /// Height of the band above the base that cracks may use.
  static const double bandHeight = 16;

  /// Clearance kept under the lowest keep-out rectangle.
  static const double gap = 2;

  /// Stroke width used to paint a crack.
  static const double strokeWidth = 1.5;

  /// Smallest usable band height; a shorter band yields no cracks.
  static const double minBandHeight = 6;

  /// Smallest usable band width; a narrower band yields no cracks.
  static const double minBandWidth = 8;

  /// Returns the cracks for a grave, or an empty list when none apply.
  ///
  /// [stoneWidth] and [stoneHeight] are the stone size in logical pixels and
  /// [keepOut] lists text areas in stone coordinates that cracks stay below.
  static List<Crack> generate({
    required int dayCount,
    required String graveId,
    required double stoneWidth,
    required double stoneHeight,
    required List<KeepOutRect> keepOut,
  }) {
    if (dayCount <= ageThresholdDays) return const <Crack>[];
    if (!stoneWidth.isFinite ||
        !stoneHeight.isFinite ||
        stoneWidth <= 0 ||
        stoneHeight <= 0) {
      return const <Crack>[];
    }

    var lowest = 0.0;
    for (final rect in keepOut) {
      final bottom = rect.bottom;
      if (bottom.isNaN) continue;
      if (bottom > lowest) lowest = bottom;
    }
    if (!lowest.isFinite) return const <Crack>[];

    final minX = sideInset.ceil();
    final maxX = (stoneWidth - sideInset).floor();
    final bandTop = _maxDouble(stoneHeight - bandHeight, lowest + gap);
    final minY = bandTop.ceil();
    final maxY = (stoneHeight - baseInset).floor();
    if (maxX - minX < minBandWidth || maxY - minY < minBandHeight) {
      return const <Crack>[];
    }

    final rng = StableRandom(StableHash.of(graveId));
    final count = minCracks + rng.nextInt(maxCracks - minCracks + 1);
    final cracks = <Crack>[];
    for (var c = 0; c < count; c++) {
      final pointCount = 3 + rng.nextInt(3);
      var x = minX + rng.nextInt(maxX - minX + 1);
      var y = _clamp(maxY - rng.nextInt(3), minY, maxY);
      final points = <CrackPoint>[CrackPoint(x, y)];
      for (var p = 1; p < pointCount; p++) {
        x = _clamp(x + rng.nextInt(17) - 8, minX, maxX);
        y = _clamp(y - (2 + rng.nextInt(4)), minY, maxY);
        points.add(CrackPoint(x, y));
      }
      cracks.add(Crack(points));
    }
    return List<Crack>.unmodifiable(cracks);
  }

  static int _clamp(int value, int low, int high) =>
      value < low ? low : (value > high ? high : value);

  static double _maxDouble(double a, double b) => a > b ? a : b;
}
