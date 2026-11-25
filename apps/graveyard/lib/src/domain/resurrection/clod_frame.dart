/// The position, size and visibility of one Clod at one elapsed time, in
/// Stone_Area coordinates (origin top-left). Pure Domain value.
final class ClodFrame {
  /// Creates a frame.
  const ClodFrame({
    required this.x,
    required this.y,
    required this.diameter,
    required this.visible,
  });

  /// Horizontal center of the clod.
  final double x;

  /// Vertical center of the clod.
  final double y;

  /// Diameter of the clod in logical pixels.
  final double diameter;

  /// Whether the clod is in the air and should be drawn.
  final bool visible;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClodFrame &&
          other.x == x &&
          other.y == y &&
          other.diameter == diameter &&
          other.visible == visible;

  @override
  int get hashCode => Object.hash(x, y, diameter, visible);

  @override
  String toString() =>
      'ClodFrame(x: $x, y: $y, diameter: $diameter, visible: $visible)';
}
