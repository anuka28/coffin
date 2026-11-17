/// Derives human-facing names from a package name. Pure.
abstract final class DisplayNames {
  /// Words split on `_`, first letter upper-cased: `bone_shop` -> `Bone Shop`.
  static String displayName(String packageName) =>
      _words(packageName).map(_capitalize).join(' ');

  /// The same words joined without spaces: `bone_shop` -> `BoneShop`.
  static String className(String packageName) =>
      _words(packageName).map(_capitalize).join();

  static Iterable<String> _words(String packageName) =>
      packageName.split('_').where((w) => w.isNotEmpty);

  static String _capitalize(String word) =>
      word[0].toUpperCase() + word.substring(1);
}
