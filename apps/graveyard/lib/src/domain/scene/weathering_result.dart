/// The visual aging of one tombstone.
class WeatheringResult {
  /// Creates a weathering result.
  const WeatheringResult({
    required this.level,
    required this.tiltRadians,
    required this.fade,
  });

  /// Age from 0 (fresh) to 1 (fully weathered).
  final double level;

  /// Signed tilt of the stone in radians.
  final double tiltRadians;

  /// Amount of color fade, from 0 to 0.25.
  final double fade;

  @override
  bool operator ==(Object other) =>
      other is WeatheringResult &&
      other.level == level &&
      other.tiltRadians == tiltRadians &&
      other.fade == fade;

  @override
  int get hashCode => Object.hash(level, tiltRadians, fade);

  @override
  String toString() =>
      'WeatheringResult(level: $level, tiltRadians: $tiltRadians, '
      'fade: $fade)';
}
