/// A rectangle in stone coordinates that cracks must stay below.
///
/// The origin is the stone's top-left corner. Only [bottom] affects crack
/// placement, but the whole rectangle is kept so callers describe the text
/// area they protect.
final class KeepOutRect {
  /// Creates a keep-out rectangle from its four edges.
  const KeepOutRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  /// Left edge in logical pixels.
  final double left;

  /// Top edge in logical pixels.
  final double top;

  /// Right edge in logical pixels.
  final double right;

  /// Bottom edge in logical pixels.
  final double bottom;

  @override
  bool operator ==(Object other) =>
      other is KeepOutRect &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() =>
      'KeepOutRect(left: $left, top: $top, right: $right, bottom: $bottom)';
}
