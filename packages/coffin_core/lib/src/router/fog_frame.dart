/// One sampled frame of the fog transition.
///
/// A plain value type with no Flutter imports. The widget layer turns [dx]
/// and [dy] into an offset and [blur] into a blur sigma.
final class FogFrame {
  /// Creates a frame.
  const FogFrame({
    required this.opacity,
    required this.dx,
    required this.dy,
    required this.blur,
  });

  /// Opacity from 0.0 (invisible) to 1.0 (opaque).
  final double opacity;

  /// Horizontal drift in logical pixels. Always 0.0 in this version.
  final double dx;

  /// Vertical drift in logical pixels. Positive moves the page down.
  final double dy;

  /// Gaussian blur sigma in logical pixels, 0.0 or more.
  final double blur;

  @override
  bool operator ==(Object other) =>
      other is FogFrame &&
      other.opacity == opacity &&
      other.dx == dx &&
      other.dy == dy &&
      other.blur == blur;

  @override
  int get hashCode => Object.hash(opacity, dx, dy, blur);

  @override
  String toString() =>
      'FogFrame(opacity: $opacity, dx: $dx, dy: $dy, blur: $blur)';
}
