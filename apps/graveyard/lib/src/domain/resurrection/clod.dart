/// One clump of earth thrown by the Hand.
///
/// Every field is derived once, by `ClodPathGenerator`, from the Grave id and
/// never changes.
final class Clod {
  /// Creates a clod from its launch and flight values.
  const Clod({
    required this.launchAngleRadians,
    required this.launchMs,
    required this.flightMs,
    required this.peakHeightFraction,
    required this.sizePx,
  });

  /// Direction from straight up, in radians (negative leans left).
  final double launchAngleRadians;

  /// Millisecond at which the clod leaves the ground, inside the burst.
  final int launchMs;

  /// How long the clod stays airborne, in milliseconds (greater than 0).
  final int flightMs;

  /// Height of the arc's peak as a fraction (0 to 1, generated as 0.10 to 0.45) of the Stone_Area
  /// height.
  final double peakHeightFraction;

  /// Diameter in logical pixels (2 to 8).
  final double sizePx;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Clod &&
          other.launchAngleRadians == launchAngleRadians &&
          other.launchMs == launchMs &&
          other.flightMs == flightMs &&
          other.peakHeightFraction == peakHeightFraction &&
          other.sizePx == sizePx;

  @override
  int get hashCode => Object.hash(
    launchAngleRadians,
    launchMs,
    flightMs,
    peakHeightFraction,
    sizePx,
  );

  @override
  String toString() =>
      'Clod(angle: $launchAngleRadians, launchMs: $launchMs, '
      'flightMs: $flightMs, peak: $peakHeightFraction, size: $sizePx)';
}
