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
    this.risenOn,
  });

  /// Creates a grave the user typed by hand.
  const Grave.manual({
    required String id,
    required String name,
    required CalendarDate dateOfDeath,
    CalendarDate? risenOn,
  }) : this._(
         id: id,
         name: name,
         dateOfDeath: dateOfDeath,
         source: GraveSource.manual,
         repo: null,
         risenOn: risenOn,
       );

  /// Creates a grave imported from GitHub, carrying its [repo] facts.
  const Grave.github({
    required String id,
    required String name,
    required CalendarDate dateOfDeath,
    required RepoInfo repo,
    CalendarDate? risenOn,
  }) : this._(
         id: id,
         name: name,
         dateOfDeath: dateOfDeath,
         source: GraveSource.github,
         repo: repo,
         risenOn: risenOn,
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

  /// The day the project was raised from the dead; null when not Risen.
  final CalendarDate? risenOn;

  /// Returns a copy of this grave with [risenOn] replaced (null clears it).
  Grave copyWithRisenOn(CalendarDate? risenOn) => Grave._(
    id: id,
    name: name,
    dateOfDeath: dateOfDeath,
    source: source,
    repo: repo,
    risenOn: risenOn,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Grave &&
          other.id == id &&
          other.name == name &&
          other.dateOfDeath == dateOfDeath &&
          other.source == source &&
          other.repo == repo &&
          other.risenOn == risenOn;

  @override
  int get hashCode => Object.hash(id, name, dateOfDeath, source, repo, risenOn);

  @override
  String toString() =>
      'Grave($id, $name, ${dateOfDeath.toIso()}, risenOn: ${risenOn?.toIso()})';
}
