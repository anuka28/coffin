import 'calendar_date.dart';
import 'grave_source.dart';
import 'repo_info.dart';

/// A buried project: a name, a date of death and where it came from.
final class Grave {
  const Grave._({
    required this.id,
    required this.name,
    required this.dateOfDeath,
    required this.source,
    required this.repo,
  });

  /// Creates a grave the user typed by hand.
  const Grave.manual({
    required String id,
    required String name,
    required CalendarDate dateOfDeath,
  }) : this._(
         id: id,
         name: name,
         dateOfDeath: dateOfDeath,
         source: GraveSource.manual,
         repo: null,
       );

  /// Creates a grave imported from GitHub, carrying its [repo] facts.
  const Grave.github({
    required String id,
    required String name,
    required CalendarDate dateOfDeath,
    required RepoInfo repo,
  }) : this._(
         id: id,
         name: name,
         dateOfDeath: dateOfDeath,
         source: GraveSource.github,
         repo: repo,
       );

  /// The unique id, also the storage key.
  final String id;

  /// The normalised project name, 1 to 80 code points.
  final String name;

  /// The day the project was last worked on.
  final CalendarDate dateOfDeath;

  /// Where the grave came from.
  final GraveSource source;

  /// Repository facts; non-null exactly when [source] is github.
  final RepoInfo? repo;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Grave &&
          other.id == id &&
          other.name == name &&
          other.dateOfDeath == dateOfDeath &&
          other.source == source &&
          other.repo == repo;

  @override
  int get hashCode => Object.hash(id, name, dateOfDeath, source, repo);

  @override
  String toString() => 'Grave($id, $name, ${dateOfDeath.toIso()})';
}
