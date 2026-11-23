part of 'import_state.dart';

/// The typed text was rejected before any request was made.
final class ImportInputRejected extends ImportState {
  /// Creates a rejected state with the [problem] found.
  const ImportInputRejected(this.problem);

  /// What was wrong with the text.
  final RepoParseProblem problem;

  @override
  bool operator ==(Object other) =>
      other is ImportInputRejected && other.problem == problem;

  @override
  int get hashCode => Object.hash(ImportInputRejected, problem);
}
