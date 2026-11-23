import 'package:coffin_core/coffin_core.dart';
import 'package:graveyard/src/data/grave_codec.dart';
import 'package:graveyard/src/domain/grave.dart';

/// A [RecordRepository] of [Grave]s that fails on demand.
///
/// It delegates to an in-memory repository, so every call that is not set to
/// fail behaves like a normal repository.
class ThrowingRecordRepository implements RecordRepository<Grave> {
  /// Creates a repository that works until a failure flag is set.
  ThrowingRecordRepository({
    this.failOnPut = false,
    this.failOnDelete = false,
    this.failOnGetAll = false,
    this.error = const _InjectedStorageFailure(),
  }) : _inner = MemoryRecordRepository<Grave>(
         codec: const GraveCodec(),
         currentVersion: 1,
       );

  final MemoryRecordRepository<Grave> _inner;

  /// When true, [put] throws [error].
  bool failOnPut;

  /// When true, [delete] throws [error].
  bool failOnDelete;

  /// When true, [getAll] throws [error].
  bool failOnGetAll;

  /// The object thrown by a failing call.
  Object error;

  @override
  Future<Grave?> get(String key) => _inner.get(key);

  @override
  Future<List<Grave>> getAll() {
    if (failOnGetAll) return Future<List<Grave>>.error(error);
    return _inner.getAll();
  }

  @override
  Future<void> put(String key, Grave record) {
    if (failOnPut) return Future<void>.error(error);
    return _inner.put(key, record);
  }

  @override
  Future<void> delete(String key) {
    if (failOnDelete) return Future<void>.error(error);
    return _inner.delete(key);
  }

  @override
  Future<void> clear() => _inner.clear();

  @override
  Stream<StorageEvent> watch() => _inner.watch();

  @override
  Future<void> close() => _inner.close();
}

class _InjectedStorageFailure implements Exception {
  const _InjectedStorageFailure();

  @override
  String toString() => 'Injected storage failure';
}
