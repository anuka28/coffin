part of 'manual_grave_check.dart';

/// A by-hand grave that passed every rule.
final class ManualGraveAccepted extends ManualGraveCheck {
  /// Creates an accepted result.
  const ManualGraveAccepted(this.name, this.dateOfDeath);

  /// The normalised project name.
  final String name;

  /// The validated date of death.
  final CalendarDate dateOfDeath;

  @override
  bool operator ==(Object other) =>
      other is ManualGraveAccepted &&
      other.name == name &&
      other.dateOfDeath == dateOfDeath;

  @override
  int get hashCode => Object.hash(name, dateOfDeath);
}
