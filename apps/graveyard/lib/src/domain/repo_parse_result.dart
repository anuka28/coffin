import 'repo_parse_problem.dart';
import 'repo_ref.dart';

part 'repo_parse_failed.dart';
part 'repo_parsed.dart';

/// The outcome of parsing import text: a reference or a problem.
sealed class RepoParseResult {
  /// Creates a parse result.
  const RepoParseResult();
}
