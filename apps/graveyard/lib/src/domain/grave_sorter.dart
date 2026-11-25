import 'grave.dart';

/// Orders graves for display.
abstract final class GraveSorter {
  /// Returns a new list of [graves], most recent date of death first.
  ///
  /// Graves with the same date are ordered by lower-cased name, then by id
  /// as plain string comparison. The input is never modified.
  static List<Grave> sort(Iterable<Grave> graves) {
    final sorted = List<Grave>.of(graves);
    sorted.sort(compare);
    return sorted;
  }

  /// Compares two graves in display order.
  ///
  /// Orders by date of death descending (most recent first), then by
  /// lower-cased name, then by id as plain string comparison.
  static int compare(Grave a, Grave b) {
    final byDate = b.dateOfDeath.compareTo(a.dateOfDeath);
    if (byDate != 0) return byDate;
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (byName != 0) return byName;
    return a.id.compareTo(b.id);
  }
}
