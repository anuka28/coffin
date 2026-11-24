import 'crack_point.dart';

/// A thin crack drawn as a polyline of 3 to 5 [CrackPoint]s.
final class Crack {
  /// Creates a crack from [points]. The list is copied and made unmodifiable.
  Crack(Iterable<CrackPoint> points)
    : points = List<CrackPoint>.unmodifiable(points);

  /// The polyline vertices, in drawing order. Unmodifiable.
  final List<CrackPoint> points;

  @override
  bool operator ==(Object other) {
    if (other is! Crack || other.points.length != points.length) return false;
    for (var i = 0; i < points.length; i++) {
      if (other.points[i] != points[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(points);

  @override
  String toString() => 'Crack($points)';
}
