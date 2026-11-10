import 'storage_event.dart';

/// A keyed store of records of type [T].
///
/// Keys are non-empty ASCII strings of at most 255 characters. Calls are
/// applied in the order they are made. Data is stored unencrypted, so never
/// keep secrets in it.
abstract interface class RecordRepository<T> {
  /// The record stored under [key].
  ///
  /// Returns null when [key] is absent, and also when the stored entry is
  /// corrupt or from an unreadable version (the entry is skipped, reported
  /// as an issue, and left untouched). Throws [ArgumentError] for an invalid
  /// key and [StateError] after [close].
  Future<T?> get(String key);

  /// Every readable record, ordered by key in ascending UTF-16 code unit
  /// order (the order of `String.compareTo`).
  ///
  /// Corrupt or unreadable entries are skipped and reported. Returns an empty
  /// list when nothing is stored. Throws [StateError] after [close].
  Future<List<T>> getAll();

  /// Stores [record] under [key], overwriting any existing entry.
  ///
  /// Completes after the record is written, then emits a put event, even when
  /// the new value equals the old one. Throws [ArgumentError] for an invalid
  /// key or a record the codec turns into non-JSON-safe data (nothing is
  /// written and no event is emitted). Throws [StateError] after [close].
  Future<void> put(String key, T record);

  /// Removes [key].
  ///
  /// Completes normally when [key] is absent, and then emits nothing. Emits a
  /// delete event only when a record was removed. Throws [ArgumentError] for
  /// an invalid key and [StateError] after [close].
  Future<void> delete(String key);

  /// Removes every record and emits exactly one clear event, even when the
  /// repository was already empty. Throws [StateError] after [close].
  Future<void> clear();

  /// A broadcast stream of changes made after you subscribe.
  ///
  /// Events are delivered in the order the changes were applied. Late
  /// listeners get no replay. After [close] the returned stream completes
  /// without emitting events.
  Stream<StorageEvent> watch();

  /// Closes the repository after earlier calls finish.
  ///
  /// Safe to call more than once. Every other method throws [StateError]
  /// afterwards, except [watch]. Persistent repositories keep their data on
  /// close; in-memory repositories lose it.
  Future<void> close();
}
