import 'package:coffin_core/coffin_core.dart';

/// A [RecordRepository] that delegates to an inner repository and can be told
/// to fail writes or reads.
final class ThrowingRecordRepository<T> implements RecordRepository<T> {
  /// Wraps [inner]. Failures are off until a flag is set.
  ThrowingRecordRepository(this.inner);

  /// The repository that handles every call that does not fail.
  final RecordRepository<T> inner;

  /// When true, [put] throws a [StateError] and writes nothing.
  bool failPut = false;

  /// When true, [get] and [getAll] throw a [StateError].
  bool failReads = false;

  @override
  Future<T?> get(String key) {
    if (failReads) {
      return Future<T?>.error(StateError('Simulated read failure'));
    }
    return inner.get(key);
  }

  @override
  Future<List<T>> getAll() {
    if (failReads) {
      return Future<List<T>>.error(StateError('Simulated read failure'));
    }
    return inner.getAll();
  }

  @override
  Future<void> put(String key, T record) {
    if (failPut) {
      return Future<void>.error(StateError('Simulated write failure'));
    }
    return inner.put(key, record);
  }

  @override
  Future<void> delete(String key) => inner.delete(key);

  @override
  Future<void> clear() => inner.clear();

  @override
  Stream<StorageEvent> watch() => inner.watch();

  @override
  Future<void> close() => inner.close();
}
