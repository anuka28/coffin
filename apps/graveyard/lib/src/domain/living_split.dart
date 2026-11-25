import 'grave.dart';
import 'grave_sorter.dart';

/// Pure rule that splits the graves into the graveyard rows and the living row.
abstract final class LivingSplit {
  /// Splits [graves] into `(graveyardRows, livingRow)`.
  ///
  /// A grave goes to the living row exactly when it is Risen (`risenOn` is not
  /// null) and its id is not in [playing]. Every other grave goes to the
  /// graveyard rows, in input order. The living row is ordered by `risenOn`
  /// descending (most recent first). Graves risen on the same day use the
  /// [GraveSorter.compare] order: date of death descending, then lower-cased
  /// name, then id.
  ///
  /// Total: never throws, and the same arguments give equal results.
  static (List<Grave> graveyardRows, List<Grave> livingRow) split({
    required List<Grave> graves,
    required Set<String> playing,
  }) {
    final graveyardRows = <Grave>[];
    final livingRow = <Grave>[];
    for (final grave in graves) {
      if (grave.risenOn != null && !playing.contains(grave.id)) {
        livingRow.add(grave);
      } else {
        graveyardRows.add(grave);
      }
    }
    livingRow.sort(_compareLiving);
    return (graveyardRows, livingRow);
  }

  static int _compareLiving(Grave a, Grave b) {
    final byDate = b.risenOn!.compareTo(a.risenOn!);
    if (byDate != 0) return byDate;
    return GraveSorter.compare(a, b);
  }
}
