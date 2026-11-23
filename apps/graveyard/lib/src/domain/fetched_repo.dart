import 'calendar_date.dart';
import 'repo_info.dart';

/// A repository read from GitHub, with the date its project died.
final class FetchedRepo {
  /// Creates a fetched repository.
  const FetchedRepo({required this.info, required this.dateOfDeath});

  /// The repository facts.
  final RepoInfo info;

  /// The local calendar date of the last push, clamped to the valid range.
  final CalendarDate dateOfDeath;

  @override
  bool operator ==(Object other) =>
      other is FetchedRepo &&
      other.info == info &&
      other.dateOfDeath == dateOfDeath;

  @override
  int get hashCode => Object.hash(info, dateOfDeath);

  @override
  String toString() => 'FetchedRepo(${info.fullName}, $dateOfDeath)';
}
