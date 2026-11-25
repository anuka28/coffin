import 'stone_point.dart';

/// The Hand at one instant: its bones, each a polyline of joints.
final class HandShape {
  /// Creates a shape from its [bones] and [visible] flag.
  const HandShape({required this.bones, required this.visible});

  /// The bones, each a polyline whose vertices are its joints. Empty when
  /// not [visible].
  final List<List<StonePoint>> bones;

  /// False while the Hand's height is 0 (nothing to draw).
  final bool visible;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! HandShape ||
        other.visible != visible ||
        other.bones.length != bones.length) {
      return false;
    }
    for (int i = 0; i < bones.length; i++) {
      final List<StonePoint> a = bones[i];
      final List<StonePoint> b = other.bones[i];
      if (a.length != b.length) return false;
      for (int j = 0; j < a.length; j++) {
        if (a[j] != b[j]) return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    visible,
    Object.hashAll(bones.map((List<StonePoint> b) => Object.hashAll(b))),
  );

  @override
  String toString() => 'HandShape(visible: $visible, bones: $bones)';
}
