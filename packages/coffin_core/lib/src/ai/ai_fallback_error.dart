import 'ai_issue_kind.dart';

/// Both the primary and the secondary AI source failed.
///
/// Carries kinds only: no reply text, no fact value, no cause and no stack
/// trace.
final class AiFallbackError implements Exception {
  /// Creates the error from the two failure kinds.
  const AiFallbackError({
    required this.primaryFailure,
    required this.secondaryFailure,
  });

  /// Why the primary source was not used.
  final AiIssueKind primaryFailure;

  /// Why the secondary source was not used. Never [AiIssueKind.timedOut].
  final AiIssueKind secondaryFailure;

  @override
  String toString() =>
      'AiFallbackError: both AI sources failed '
      '(primary: ${primaryFailure.name}, secondary: ${secondaryFailure.name})';
}
