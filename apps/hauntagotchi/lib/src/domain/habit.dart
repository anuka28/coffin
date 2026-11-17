import 'local_day.dart';

/// One daily habit with its completion history.
final class Habit {
  /// Creates a habit. [completedDays] is copied and made unmodifiable.
  Habit({
    required this.id,
    required this.name,
    required this.createdDay,
    Set<LocalDay> completedDays = const <LocalDay>{},
    this.archivedDay,
  }) : completedDays = Set<LocalDay>.unmodifiable(completedDays);

  /// Storage key such as `h1`.
  final String id;

  /// Trimmed display name.
  final String name;

  /// The day the habit was created.
  final LocalDay createdDay;

  /// Days on which the habit was completed (unmodifiable).
  final Set<LocalDay> completedDays;

  /// The day the habit was archived, or null while active.
  final LocalDay? archivedDay;

  /// Whether the habit is not archived.
  bool get isActive => archivedDay == null;

  /// Whether the habit counted as active on [d].
  bool isActiveOn(LocalDay d) {
    final LocalDay? archived = archivedDay;
    return createdDay.compareTo(d) <= 0 &&
        (archived == null || d.compareTo(archived) < 0);
  }

  /// Whether the habit was completed on [d].
  bool isCompletedOn(LocalDay d) => completedDays.contains(d);

  /// A copy with the given fields replaced.
  Habit copyWith({
    String? name,
    Set<LocalDay>? completedDays,
    LocalDay? archivedDay,
  }) => Habit(
    id: id,
    name: name ?? this.name,
    createdDay: createdDay,
    completedDays: completedDays ?? this.completedDays,
    archivedDay: archivedDay ?? this.archivedDay,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Habit &&
          other.id == id &&
          other.name == name &&
          other.createdDay == createdDay &&
          other.archivedDay == archivedDay &&
          other.completedDays.length == completedDays.length &&
          other.completedDays.containsAll(completedDays);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    createdDay,
    archivedDay,
    Object.hashAllUnordered(completedDays),
  );

  @override
  String toString() => 'Habit($id, $name)';
}
