part of 'repo_parse_result.dart';

/// The text could not be turned into a repository reference.
final class RepoParseFailed extends RepoParseResult {
  /// Creates a failed result.
  const RepoParseFailed(this.problem);

  /// What was wrong with the text.
  final RepoParseProblem problem;

  @override
  bool operator ==(Object other) =>
      other is RepoParseFailed && other.problem == problem;

  @override
  int get hashCode => problem.hashCode;
}
