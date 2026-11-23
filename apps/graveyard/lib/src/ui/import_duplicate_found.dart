part of 'import_state.dart';

/// The repository is already in the graveyard.
final class ImportDuplicateFound extends ImportState {
  /// Creates a duplicate state for the repository named [fullName].
  const ImportDuplicateFound(this.fullName);

  /// The `owner/repo` name of the existing grave.
  final String fullName;

  @override
  bool operator ==(Object other) =>
      other is ImportDuplicateFound && other.fullName == fullName;

  @override
  int get hashCode => Object.hash(ImportDuplicateFound, fullName);
}
