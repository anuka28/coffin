import '../calendar_date.dart';
import '../dead_for_formatter.dart';
import '../grave.dart';
import '../grave_source.dart';
import 'tombstone_fragment.dart';
import 'tombstone_fragment_kind.dart';

/// Decides which text a tombstone shows, so each fact appears once.
abstract final class TombstoneFacts {
  /// The fragments of [grave] in display order: title, date line, dead-for
  /// text, then the full name only for a GitHub grave whose `full_name`
  /// differs from its name. Each kind occurs at most once.
  static List<TombstoneFragment> of({
    required Grave grave,
    required CalendarDate today,
    required String dateLine,
  }) {
    final repo = grave.repo;
    return List<TombstoneFragment>.unmodifiable([
      TombstoneFragment(TombstoneFragmentKind.title, grave.name),
      TombstoneFragment(TombstoneFragmentKind.dateLine, dateLine),
      TombstoneFragment(
        TombstoneFragmentKind.deadFor,
        DeadForFormatter.format(grave.dateOfDeath, today),
      ),
      if (grave.source == GraveSource.github &&
          repo != null &&
          repo.fullName != grave.name)
        TombstoneFragment(TombstoneFragmentKind.fullName, repo.fullName),
    ]);
  }
}
