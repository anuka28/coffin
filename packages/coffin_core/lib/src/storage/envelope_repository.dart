// Named parameters cannot be private, so the private fields are assigned in
// the initializer list.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'envelope.dart';
import 'envelope_codec.dart';
import 'issue_reporter.dart';
import 'json_map.dart';
import 'json_safety.dart';
import 'key_validator.dart';
import 'migration_hook.dart';
import 'operation_queue.dart';
import 'raw_store.dart';
import 'record_codec.dart';
import 'record_repository.dart';
import 'storage_event.dart';
import 'storage_issue.dart';
import 'storage_issue_kind.dart';

/// Shared behavior for every repository: keys, envelope, migration, corrupt
/// handling, ordering, events, call serialization and close.
///
/// It is written against a [RawStore], so the in-memory and the persistent
/// repositories behave the same by construction. Data is stored unencrypted.
class EnvelopeRepository<T> implements RecordRepository<T> {
  /// Creates a repository over [store].
  ///
  /// [currentVersion] is the schema version written with every record and must
  /// be in `0..EnvelopeCodec.maxVersion`. [migrate] upgrades older records
  /// when they are read. [reportIssue] receives one issue per skipped entry
  /// per read.
  EnvelopeRepository({
    required RawStore store,
    required RecordCodec<T> codec,
    required int currentVersion,
    MigrationHook? migrate,
    IssueReporter reportIssue = discardIssues,
  }) : assert(
         currentVersion >= 0 && currentVersion <= EnvelopeCodec.maxVersion,
         'currentVersion must be in 0..${EnvelopeCodec.maxVersion}',
       ),
       _store = store,
       _codec = codec,
       _currentVersion = currentVersion,
       _migrate = migrate,
       _reportIssue = reportIssue;

  final RawStore _store;
  final RecordCodec<T> _codec;
  final int _currentVersion;
  final MigrationHook? _migrate;
  final IssueReporter _reportIssue;

  final OperationQueue _queue = OperationQueue();
  final StreamController<StorageEvent> _events =
      StreamController<StorageEvent>.broadcast();

  bool _closed = false;
  Future<void>? _closeFuture;

  /// Throws [StateError] once [close] was called.
  void _checkOpen() {
    if (_closed) {
      throw StateError('This repository is closed.');
    }
  }

  @override
  Future<T?> get(String key) async {
    _checkOpen();
    KeyValidator.check(key);
    return _queue.run<T?>(() async {
      final String? raw = await _store.read(key);
      if (raw == null) return null;
      return _decode(key, raw);
    });
  }

  @override
  Future<List<T>> getAll() async {
    _checkOpen();
    return _queue.run<List<T>>(() async {
      final List<String> keys = <String>[
        for (final String key in await _store.keys())
          if (KeyValidator.isValid(key)) key,
      ]..sort((String a, String b) => a.compareTo(b));
      final List<T> records = <T>[];
      for (final String key in keys) {
        final String? raw = await _store.read(key);
        if (raw == null) continue;
        final T? record = _decode(key, raw);
        if (record != null) records.add(record);
      }
      return records;
    });
  }

  @override
  Future<void> put(String key, T record) async {
    _checkOpen();
    KeyValidator.check(key);
    // Encode at call time: a bad record never reaches the queue, the store or
    // the stream, and later changes to [record] cannot affect this write.
    final JsonMap data = _codec.encode(record);
    JsonSafety.check(data);
    final String envelope = EnvelopeCodec.encode(_currentVersion, data);
    return _queue.run<void>(() async {
      await _store.write(key, envelope);
      _emit(StorageEvent.put(key));
    });
  }

  @override
  Future<void> delete(String key) async {
    _checkOpen();
    KeyValidator.check(key);
    return _queue.run<void>(() async {
      final bool existed = await _store.remove(key);
      if (existed) _emit(StorageEvent.delete(key));
    });
  }

  @override
  Future<void> clear() async {
    _checkOpen();
    return _queue.run<void>(() async {
      await _store.removeAll();
      _emit(const StorageEvent.clear());
    });
  }

  @override
  Stream<StorageEvent> watch() =>
      _closed ? const Stream<StorageEvent>.empty() : _events.stream;

  @override
  Future<void> close() {
    // The same future for every call, so a second close is a no-op.
    return _closeFuture ??= _startClose();
  }

  Future<void> _startClose() {
    _closed = true;
    return _queue.run<void>(() async {
      try {
        await _store.close();
      } finally {
        await _events.close();
      }
    });
  }

  void _emit(StorageEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  /// Decodes [raw] by the decode table. Returns null (after reporting one
  /// issue) when the entry must be skipped. Never writes.
  T? _decode(String key, String raw) {
    final Envelope envelope;
    try {
      envelope = EnvelopeCodec.parse(raw);
    } catch (_) {
      return _skip(key, StorageIssueKind.corruptRecord, _corruptMessage);
    }

    final JsonMap data;
    if (envelope.version > _currentVersion) {
      return _skip(key, StorageIssueKind.unknownVersion, _unknownMessage);
    } else if (envelope.version < _currentVersion) {
      final MigrationHook? migrate = _migrate;
      if (migrate == null) {
        return _skip(key, StorageIssueKind.unknownVersion, _unknownMessage);
      }
      final JsonMap copy;
      try {
        copy = JsonSafety.deepCopy(envelope.data);
      } catch (_) {
        return _skip(key, StorageIssueKind.corruptRecord, _corruptMessage);
      }
      try {
        data = migrate(envelope.version, copy);
      } catch (_) {
        return _skip(key, StorageIssueKind.migrationFailed, _migrationMessage);
      }
    } else {
      data = envelope.data;
    }

    try {
      return _codec.decode(data);
    } catch (_) {
      return _skip(key, StorageIssueKind.corruptRecord, _corruptMessage);
    }
  }

  T? _skip(String key, StorageIssueKind kind, String message) {
    reportSafely(
      _reportIssue,
      StorageIssue(kind: kind, key: key, message: message),
    );
    return null;
  }

  // Fixed messages: never payload text and never an exception message.
  static const String _corruptMessage =
      'Record could not be read and was skipped.';
  static const String _unknownMessage =
      'Record has an unsupported version and was skipped.';
  static const String _migrationMessage =
      'Record migration failed and the record was skipped.';
}
