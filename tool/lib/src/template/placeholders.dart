/// The placeholder names a template may use, written `{{name}}`.
abstract final class Placeholders {
  /// The only placeholder names the renderer accepts.
  ///
  /// - `package_name`: the app name, e.g. `bone_shop`.
  /// - `display_name`: the title, e.g. `Bone Shop`.
  /// - `class_name`: the title without spaces, e.g. `BoneShop`.
  /// - `sdk_constraint`: the `sdk:` value of the root `pubspec.yaml`.
  static const List<String> known = [
    'package_name',
    'display_name',
    'class_name',
    'sdk_constraint',
  ];

  /// Matches one `{{name}}` marker; group 1 is the name.
  static final RegExp pattern = RegExp(r'\{\{([a-z_]+)\}\}');
}
