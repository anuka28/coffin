/// The box the rising ghost occupies, in stone coordinates (origin at the
/// top-left of the stone area).
final class GhostBox {
  /// Creates a box.
  const GhostBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.visible,
  });

  /// Distance from the left edge of the stone area to the box.
  final double left;

  /// Distance from the top edge of the stone area to the box.
  final double top;

  /// Width of the box in logical pixels.
  final double width;

  /// Height of the box in logical pixels.
  final double height;

  /// Whether the ghost should be drawn.
  final bool visible;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GhostBox &&
          other.left == left &&
          other.top == top &&
          other.width == width &&
          other.height == height &&
          other.visible == visible;

  @override
  int get hashCode => Object.hash(left, top, width, height, visible);

  @override
  String toString() =>
      'GhostBox(left: ${left.toStringAsFixed(2)}, '
      'top: ${top.toStringAsFixed(2)}, '
      'width: ${width.toStringAsFixed(2)}, '
      'height: ${height.toStringAsFixed(2)}, '
      'visible: $visible)';
}
