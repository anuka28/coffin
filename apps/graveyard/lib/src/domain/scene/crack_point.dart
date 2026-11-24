/// One vertex of a crack, in integer stone coordinates.
final class CrackPoint {
  /// Creates a point at ([x], [y]).
  const CrackPoint(this.x, this.y);

  /// Horizontal position in logical pixels from the stone's left edge.
  final int x;

  /// Vertical position in logical pixels from the stone's top edge.
  final int y;

  @override
  bool operator ==(Object other) =>
      other is CrackPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'CrackPoint($x, $y)';
}
