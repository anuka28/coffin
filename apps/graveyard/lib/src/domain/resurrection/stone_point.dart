/// A point in stone coordinates (origin top-left of the Stone_Area).
final class StonePoint {
  /// Creates a point at ([x], [y]).
  const StonePoint(this.x, this.y);

  /// Horizontal position, growing to the right.
  final double x;

  /// Vertical position, growing downwards.
  final double y;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StonePoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'StonePoint($x, $y)';
}
