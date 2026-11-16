import 'package:meta/meta.dart';

import 'ai_issue_kind.dart';

/// One report that an AI source failed and a fallback was used.
///
/// The message is fixed text per kind. It never contains a request, a fact
/// or a reply.
@immutable
final class AiIssue {
  /// Creates an issue with an explicit [kind] and [message].
  const AiIssue({required this.kind, required this.message});

  /// Creates the issue for [kind], with its fixed message.
  factory AiIssue.forKind(AiIssueKind kind) =>
      AiIssue(kind: kind, message: _messageFor(kind));

  /// What went wrong.
  final AiIssueKind kind;

  /// Fixed, human readable text for [kind].
  final String message;

  static String _messageFor(AiIssueKind kind) {
    switch (kind) {
      case AiIssueKind.threw:
        return 'The AI source threw an error, so the fallback was used.';
      case AiIssueKind.timedOut:
        return 'The AI source did not answer in time, '
            'so the fallback was used.';
      case AiIssueKind.emptyReply:
        return 'The AI source returned an empty reply, '
            'so the fallback was used.';
      case AiIssueKind.invalidReply:
        return 'The AI source returned a reply that was too long, '
            'so the fallback was used.';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiIssue && other.kind == kind && other.message == message;

  @override
  int get hashCode => Object.hash(kind, message);

  @override
  String toString() => 'AiIssue(kind: ${kind.name}, message: $message)';
}
