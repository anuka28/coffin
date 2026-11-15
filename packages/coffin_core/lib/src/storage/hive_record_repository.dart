import 'envelope_repository.dart';
import 'raw_store.dart';

/// The persistent repository over a [RawStore] (normally a `HiveRawStore`).
///
/// Data is stored unencrypted and persists in the Hive box (IndexedDB on web),
/// so it must not hold secrets. Behavior is the same as the in-memory
/// repository; closing keeps the data in the box.
final class HiveRecordRepository<T> extends EnvelopeRepository<T> {
  /// Creates a persistent repository over [store].
  ///
  /// [currentVersion] must be in `0..EnvelopeCodec.maxVersion`. [migrate]
  /// upgrades older records when they are read. [reportIssue] receives one
  /// issue per skipped entry per read.
  HiveRecordRepository({
    required super.store,
    required super.codec,
    required super.currentVersion,
    super.migrate,
    super.reportIssue,
  });
}
