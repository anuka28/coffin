/// One fog blob in unit coordinates. Immutable, with value equality.
final class FogParticle {
  /// Creates a particle from unit values.
  const FogParticle({
    required this.x,
    required this.y,
    required this.radius,
    required this.alpha,
  });

  /// Center as a fraction of the width, 0 to 1.
  final double x;

  /// Center as a fraction of the height, 0 to 1.
  final double y;

  /// Radius as a fraction of the shorter side, 0.12 to 0.30.
  final double radius;

  /// Opacity at the center, 0.03 to 0.05, constant over time.
  final double alpha;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FogParticle &&
          other.x == x &&
          other.y == y &&
          other.radius == radius &&
          other.alpha == alpha;

  @override
  int get hashCode => Object.hash(x, y, radius, alpha);

  @override
  String toString() =>
      'FogParticle(x: $x, y: $y, radius: $radius, alpha: $alpha)';
}
