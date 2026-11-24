/// Finds which graves appeared between two renders of the scene.
abstract final class NewGraveIds {
  /// Returns the ids in [next] that are absent from [previous].
  ///
  /// The result keeps the order of [next]. Equal lists give an empty result.
  /// The scene passes the first loaded list as both [previous] and [next], so
  /// graves loaded from storage are never reported as new.
  static List<String> diff({
    required List<String> previous,
    required List<String> next,
  }) {
    final seen = previous.toSet();
    return [
      for (final id in next)
        if (!seen.contains(id)) id,
    ];
  }
}
