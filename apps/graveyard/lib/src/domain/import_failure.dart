import 'import_failure_kind.dart';

/// A failed import: a [kind] and, for rate limits, when to try again.
final class ImportFailure {
  /// Creates a failure. Pass [resetAt] only for [ImportFailureKind.rateLimited].
  const ImportFailure(this.kind, {this.resetAt})
    : assert(
        resetAt == null || kind == ImportFailureKind.rateLimited,
        'resetAt is only for rateLimited',
      );

  /// What went wrong.
  final ImportFailureKind kind;

  /// When GitHub allows another request, for a rate limit only.
  final DateTime? resetAt;

  @override
  bool operator ==(Object other) =>
      other is ImportFailure && other.kind == kind && other.resetAt == resetAt;

  @override
  int get hashCode => Object.hash(kind, resetAt);

  @override
  String toString() => 'ImportFailure($kind)';
}
