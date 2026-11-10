import 'package:meta/meta.dart';

import 'storage_event_kind.dart';

/// One change made to a repository.
///
/// [key] is null for [StorageEventKind.clear].
@immutable
final class StorageEvent {
  /// Creates an event of [kind] for [key].
  const StorageEvent(this.kind, [this.key]);

  /// A record was written under [key].
  const StorageEvent.put(String key) : this(StorageEventKind.put, key);

  /// The record under [key] was removed.
  const StorageEvent.delete(String key) : this(StorageEventKind.delete, key);

  /// Every record was removed.
  const StorageEvent.clear() : this(StorageEventKind.clear);

  /// What happened.
  final StorageEventKind kind;

  /// The affected key, or null for a clear event.
  final String? key;

  @override
  bool operator ==(Object other) =>
      other is StorageEvent && other.kind == kind && other.key == key;

  @override
  int get hashCode => Object.hash(kind, key);

  @override
  String toString() => key == null
      ? 'StorageEvent.${kind.name}()'
      : 'StorageEvent.${kind.name}("$key")';
}
