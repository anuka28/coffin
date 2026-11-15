import 'package:hive_ce/hive.dart';

import 'raw_store.dart';

/// A [RawStore] backed by a Hive box.
///
/// Data is stored unencrypted. The store registers no adapters and calls no
/// global initializer, so the box must already be open (see [open]).
final class HiveRawStore implements RawStore {
  /// Wraps an already open [_box].
  HiveRawStore(this._box);

  final Box<dynamic> _box;

  /// Opens the box [boxName] and wraps it.
  ///
  /// [location] is the directory on the VM and null on the web. It is passed
  /// to `Hive.openBox` as `path`, so no global `Hive.init` is needed.
  static Future<HiveRawStore> open(String boxName, String? location) async {
    final box = await Hive.openBox<dynamic>(boxName, path: location);
    return HiveRawStore(box);
  }

  @override
  Future<String?> read(String key) async {
    final value = _box.get(key);
    if (value == null) return null;
    return value is String ? value : '';
  }

  @override
  Future<List<String>> keys() async =>
      _box.keys.whereType<String>().toList(growable: false);

  @override
  Future<void> write(String key, String value) => _box.put(key, value);

  @override
  Future<bool> remove(String key) async {
    if (!_box.containsKey(key)) return false;
    await _box.delete(key);
    return true;
  }

  @override
  Future<void> removeAll() async {
    await _box.clear();
  }

  @override
  Future<void> close() => _box.close();
}
