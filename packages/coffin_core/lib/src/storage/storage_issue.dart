import 'package:meta/meta.dart';

import 'storage_issue_kind.dart';

/// A problem report from a repository or the opener.
///
/// [message] never contains stored payload content.
@immutable
final class StorageIssue {
  /// Creates an issue of [kind] with [message], optionally for [key].
  const StorageIssue({required this.kind, required this.message, this.key});

  /// What went wrong.
  final StorageIssueKind kind;

  /// The affected key, or null when the issue is not about one record.
  final String? key;

  /// A fixed, human-readable description. Never includes payload content.
  final String message;

  @override
  bool operator ==(Object other) =>
      other is StorageIssue &&
      other.kind == kind &&
      other.key == key &&
      other.message == message;

  @override
  int get hashCode => Object.hash(kind, key, message);

  @override
  String toString() =>
      'StorageIssue(${kind.name}, key: ${key == null ? 'null' : '"$key"'}, '
      'message: "$message")';
}
