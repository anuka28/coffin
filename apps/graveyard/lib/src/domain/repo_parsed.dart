part of 'repo_parse_result.dart';

/// The text held a valid repository reference.
final class RepoParsed extends RepoParseResult {
  /// Creates a successful result.
  const RepoParsed(this.ref);

  /// The parsed reference.
  final RepoRef ref;

  @override
  bool operator ==(Object other) => other is RepoParsed && other.ref == ref;

  @override
  int get hashCode => ref.hashCode;
}
