import 'record_repository.dart';

/// The result of opening storage: the repository and whether it persists.
final class OpenedRepository<T> {
  /// Creates a result.
  const OpenedRepository({
    required this.repository,
    required this.isPersistent,
  });

  /// The repository to use.
  final RecordRepository<T> repository;

  /// False when the memory fallback is in use; data will not be saved.
  final bool isPersistent;
}
