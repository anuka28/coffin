/// One fog blob in pixels. Immutable, with value equality.
final class FogDisc {
  /// Creates a disc from pixel values.
  const FogDisc({required this.x, required this.y, required this.radius});

  /// Center x in pixels.
  final double x;

  /// Center y in pixels.
  final double y;

  /// Radius in pixels.
  final double radius;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FogDisc &&
          other.x == x &&
          other.y == y &&
          other.radius == radius;

  @override
  int get hashCode => Object.hash(x, y, radius);

  @override
  String toString() => 'FogDisc(x: $x, y: $y, radius: $radius)';
}
