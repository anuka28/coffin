/// One star of the night sky.
final class Star {
  /// Creates a star at ([dx], [dy]) with the given [radius] and twinkle timing.
  const Star({
    required this.dx,
    required this.dy,
    required this.radius,
    required this.phaseMs,
    required this.periodMs,
  });

  /// Horizontal position in logical pixels.
  final double dx;

  /// Vertical position in logical pixels.
  final double dy;

  /// Radius in logical pixels (1.0 to 2.5).
  final double radius;

  /// Twinkle phase offset in milliseconds, from 0 up to [periodMs].
  final int phaseMs;

  /// Twinkle period in milliseconds (3000 to 8000).
  final int periodMs;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Star &&
          other.dx == dx &&
          other.dy == dy &&
          other.radius == radius &&
          other.phaseMs == phaseMs &&
          other.periodMs == periodMs;

  @override
  int get hashCode => Object.hash(dx, dy, radius, phaseMs, periodMs);

  @override
  String toString() =>
      'Star(dx: $dx, dy: $dy, radius: $radius, phaseMs: $phaseMs, '
      'periodMs: $periodMs)';
}
