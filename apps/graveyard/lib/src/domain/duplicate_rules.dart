import 'grave.dart';
import 'grave_source.dart';
import 'name_rules.dart';

/// Decides whether a new grave repeats one that is already buried.
abstract final class DuplicateRules {
  /// Whether [candidate] duplicates a grave in [existing].
  ///
  /// Two GitHub graves match when their `full_name` keys are equal. Two manual
  /// graves match when their name keys and dates of death are equal. A manual
  /// grave never matches a GitHub grave. Keys ignore letter case and
  /// surrounding or repeated whitespace.
  static bool isDuplicate(Grave candidate, Iterable<Grave> existing) {
    for (final other in existing) {
      if (_matches(candidate, other)) return true;
    }
    return false;
  }

  static bool _matches(Grave a, Grave b) {
    if (a.source != b.source) return false;
    switch (a.source) {
      case GraveSource.github:
        final aRepo = a.repo;
        final bRepo = b.repo;
        if (aRepo == null || bRepo == null) return false;
        return NameRules.keyOf(aRepo.fullName) ==
            NameRules.keyOf(bRepo.fullName);
      case GraveSource.manual:
        return NameRules.keyOf(a.name) == NameRules.keyOf(b.name) &&
            a.dateOfDeath == b.dateOfDeath;
    }
  }
}
