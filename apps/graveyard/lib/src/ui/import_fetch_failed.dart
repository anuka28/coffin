part of 'import_state.dart';

/// The request ended in a [failure].
final class ImportFetchFailed extends ImportState {
  /// Creates a failed state holding [failure].
  const ImportFetchFailed(this.failure);

  /// Why the import did not work.
  final ImportFailure failure;

  @override
  bool operator ==(Object other) =>
      other is ImportFetchFailed && other.failure == failure;

  @override
  int get hashCode => Object.hash(ImportFetchFailed, failure);
}
