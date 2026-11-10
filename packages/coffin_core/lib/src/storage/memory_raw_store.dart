import 'key_validator.dart';
import 'raw_store.dart';

/// A Map-backed store. Closing drops the entries. Shares no state between
/// instances.
final class MemoryRawStore implements RawStore {
  /// Creates a store holding a copy of [seed].
  ///
  /// Throws [ArgumentError] when a seed key fails [KeyValidator], so a seed
  /// cannot hold a key the Hive store would not.
  MemoryRawStore([Map<String, String> seed = const {}])
    : _entries = _validatedCopy(seed);

  final Map<String, String> _entries;

  static Map<String, String> _validatedCopy(Map<String, String> seed) {
    for (final key in seed.keys) {
      KeyValidator.check(key);
    }
    return Map<String, String>.of(seed);
  }

  @override
  Future<String?> read(String key) async => _entries[key];

  @override
  Future<List<String>> keys() async => List<String>.of(_entries.keys);

  @override
  Future<void> write(String key, String value) async {
    _entries[key] = value;
  }

  @override
  Future<bool> remove(String key) async => _entries.remove(key) != null;

  @override
  Future<void> removeAll() async {
    _entries.clear();
  }

  @override
  Future<void> close() async {
    _entries.clear();
  }
}
