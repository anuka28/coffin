import 'envelope_repository.dart';
import 'memory_raw_store.dart';

/// The in-memory repository.
///
/// Same behavior as the persistent repository, but data is lost on [close] and
/// when the app ends.
final class MemoryRecordRepository<T> extends EnvelopeRepository<T> {
  /// Creates an in-memory repository.
  ///
  /// [seed] holds raw envelope text by key (for example to start with
  /// existing or corrupt entries). Every seed key must be a valid storage key,
  /// otherwise an [ArgumentError] is thrown.
  MemoryRecordRepository({
    required super.codec,
    required super.currentVersion,
    Map<String, String> seed = const <String, String>{},
    super.migrate,
    super.reportIssue,
  }) : super(store: MemoryRawStore(seed));
}
