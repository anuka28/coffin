import 'name_issue_kind.dart';

/// One reason an app name was rejected.
final class NameIssue {
  /// Creates an issue of [kind] with a plain-language [reason].
  const NameIssue(this.kind, this.reason);

  /// The category of the problem.
  final NameIssueKind kind;

  /// A short, plain explanation. Spooky copy is added by the CLI, not here.
  final String reason;

  @override
  String toString() => 'NameIssue($kind, $reason)';
}
