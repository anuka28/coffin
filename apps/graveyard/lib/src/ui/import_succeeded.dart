part of 'import_state.dart';

/// The repository was buried as the grave with id [graveId].
final class ImportSucceeded extends ImportState {
  /// Creates a succeeded state for the new grave [graveId].
  const ImportSucceeded(this.graveId);

  /// The id of the grave that was added.
  final String graveId;

  @override
  bool operator ==(Object other) =>
      other is ImportSucceeded && other.graveId == graveId;

  @override
  int get hashCode => Object.hash(ImportSucceeded, graveId);
}
