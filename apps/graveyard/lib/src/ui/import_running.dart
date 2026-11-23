part of 'import_state.dart';

/// One request for [ref] is in flight.
final class ImportRunning extends ImportState {
  /// Creates a running state for [ref].
  const ImportRunning(this.ref);

  /// The repository being fetched.
  final RepoRef ref;

  @override
  bool operator ==(Object other) => other is ImportRunning && other.ref == ref;

  @override
  int get hashCode => Object.hash(ImportRunning, ref);
}
