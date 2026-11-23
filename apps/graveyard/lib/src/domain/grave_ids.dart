/// Makes grave ids.
abstract final class GraveIds {
  /// The smallest `gN` (N from 1) that is not in [existing].
  static String next(Iterable<String> existing) {
    final used = existing.toSet();
    var n = 1;
    while (used.contains('g$n')) {
      n++;
    }
    return 'g$n';
  }
}
