import '../calendar_date.dart';
import '../grave.dart';
import '../grave_source.dart';
import '../repo_info.dart';
import '../scene/description_cleaner.dart';

/// The facts a séance reads from a grave. Never reads the grave id or name.
final class SeanceFacts {
  /// Creates facts from already-computed values.
  const SeanceFacts({
    required this.dayCount,
    required this.archived,
    required this.stars,
    required this.hasDescription,
    required this.manual,
  });

  /// Builds the facts of [grave] on [today].
  factory SeanceFacts.of({required Grave grave, required CalendarDate today}) {
    final int rawDays = grave.dateOfDeath.daysUntil(today);
    final RepoInfo? repo = grave.source == GraveSource.github
        ? grave.repo
        : null;
    return SeanceFacts(
      dayCount: rawDays < 0 ? 0 : rawDays,
      archived: repo?.archived ?? false,
      stars: repo?.stars ?? 0,
      hasDescription:
          repo != null &&
          DescriptionCleaner.clean(repo.description ?? '').isNotEmpty,
      manual: grave.source == GraveSource.manual,
    );
  }

  /// Days from the date of death to today, never below 0.
  final int dayCount;

  /// Whether the repository is archived. Always false for a manual grave.
  final bool archived;

  /// The star count. Always 0 for a manual grave.
  final int stars;

  /// Whether the cleaned description is non-empty. Always false for a manual
  /// grave.
  final bool hasDescription;

  /// Whether the grave was buried by hand.
  final bool manual;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeanceFacts &&
          other.dayCount == dayCount &&
          other.archived == archived &&
          other.stars == stars &&
          other.hasDescription == hasDescription &&
          other.manual == manual;

  @override
  int get hashCode =>
      Object.hash(dayCount, archived, stars, hasDescription, manual);

  @override
  String toString() =>
      'SeanceFacts(dayCount: $dayCount, archived: $archived, stars: $stars, '
      'hasDescription: $hasDescription, manual: $manual)';
}
