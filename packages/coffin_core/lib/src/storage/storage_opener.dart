import 'hive_raw_store.dart';
import 'hive_record_repository.dart';
import 'issue_reporter.dart';
import 'memory_record_repository.dart';
import 'migration_hook.dart';
import 'opened_repository.dart';
import 'raw_store.dart';
import 'record_codec.dart';
import 'storage_issue.dart';
import 'storage_issue_kind.dart';

/// Prepares hive_ce, e.g. `hiveFlutterInitializer` in apps or
/// `() async => Hive.init(tempDir.path)` in VM tests.
typedef StorageInitializer = Future<void> Function();

/// Opens the raw store for a box name at a location (null for the default).
typedef RawStoreOpener = Future<RawStore> Function(
  String boxName,
  String? location,
);

/// The longest box name Hive accepts.
const int _maxBoxNameLength = 255;

/// Opens a persistent repository, or falls back to memory.
///
/// Data in the persistent repository is stored unencrypted, so it must not
/// hold secrets. Hive lowercases box names, so `Notes` and `notes` are the
/// same box.
final class StorageOpener {
  /// Creates an opener.
  ///
  /// [initializer] prepares hive_ce before the box is opened. [openStore]
  /// opens the box (tests inject fakes). [reportIssue] receives the
  /// fallback issue and, unless overridden per call, the repository's issues.
  const StorageOpener({
    required this.initializer,
    this.openStore = HiveRawStore.open,
    this.reportIssue = discardIssues,
  });

  /// Prepares hive_ce before the first box is opened.
  final StorageInitializer initializer;

  /// Opens the raw store for a box name and location.
  final RawStoreOpener openStore;

  /// Receives the opener's own issues.
  final IssueReporter reportIssue;

  /// Opens the box [boxName] and returns a repository for [codec].
  ///
  /// Never throws. Runs [initializer], then [openStore]. On any failure
  /// (including an invalid [boxName]) it returns a [MemoryRecordRepository]
  /// with `isPersistent` false and reports one
  /// [StorageIssueKind.fallbackToMemory] issue whose message names the
  /// exception type but not its text. On success nothing is reported.
  ///
  /// [location] is the directory on the VM and is ignored on the web.
  /// [repositoryIssues] receives the repository's own issues and defaults to
  /// [reportIssue].
  Future<OpenedRepository<T>> open<T>({
    required String boxName,
    required RecordCodec<T> codec,
    required int currentVersion,
    String? location,
    MigrationHook? migrate,
    IssueReporter? repositoryIssues,
  }) async {
    final IssueReporter repoReporter = repositoryIssues ?? reportIssue;
    try {
      _checkBoxName(boxName);
      await initializer();
      final RawStore store = await openStore(boxName, location);
      try {
        return OpenedRepository<T>(
          repository: HiveRecordRepository<T>(
            store: store,
            codec: codec,
            currentVersion: currentVersion,
            migrate: migrate,
            reportIssue: repoReporter,
          ),
          isPersistent: true,
        );
      } catch (_) {
        // Do not leak the opened store when the repository cannot be built.
        try {
          await store.close();
        } catch (_) {}
        rethrow;
      }
    } catch (error) {
      return _fallback<T>(
        error,
        codec: codec,
        currentVersion: currentVersion,
        migrate: migrate,
        repoReporter: repoReporter,
      );
    }
  }

  OpenedRepository<T> _fallback<T>(
    Object error, {
    required RecordCodec<T> codec,
    required int currentVersion,
    required MigrationHook? migrate,
    required IssueReporter repoReporter,
  }) {
    reportSafely(
      reportIssue,
      StorageIssue(
        kind: StorageIssueKind.fallbackToMemory,
        message:
            'Persistent storage unavailable; using memory '
            '(${error.runtimeType})',
      ),
    );
    // Memory construction can only fail on a bad currentVersion, which would
    // also have failed above. Let that one case surface as an assert in
    // debug rather than hide it.
    return OpenedRepository<T>(
      repository: MemoryRecordRepository<T>(
        codec: codec,
        currentVersion: currentVersion,
        migrate: migrate,
        reportIssue: repoReporter,
      ),
      isPersistent: false,
    );
  }

  /// Throws [ArgumentError] when Hive would not accept [boxName].
  static void _checkBoxName(String boxName) {
    final String lower = boxName.toLowerCase();
    if (lower.isEmpty || lower.length > _maxBoxNameLength) {
      throw ArgumentError('Invalid box name length');
    }
    for (final int unit in lower.codeUnits) {
      if (unit > 0x7F) {
        throw ArgumentError('Invalid box name characters');
      }
    }
  }
}
