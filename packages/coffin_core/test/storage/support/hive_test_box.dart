// VM ONLY. Imports dart:io and hive_ce, so never import this file from a test
// that also runs on Chrome.
import 'dart:io';
import 'dart:math';

import 'package:hive_ce/hive.dart';

/// Prefix of every box name made by [openHiveTestBox].
const String hiveTestBoxPrefix = 'crypt_t';

int _counter = 0;
final Random _random = Random.secure();

String _nextBoxName() {
  _counter += 1;
  final suffix = List<String>.generate(
    8,
    (_) => _random.nextInt(16).toRadixString(16),
  ).join();
  return '$hiveTestBoxPrefix${_counter}_$suffix';
}

/// A real Hive box in its own temp directory, with a safe disposer.
class HiveTestBox {
  HiveTestBox._(this.box, this.name, this.directory);

  /// The open box.
  final Box<dynamic> box;

  /// The unique, lowercase, ASCII box name.
  final String name;

  /// The temp directory that holds the box files.
  final Directory directory;

  bool _disposed = false;

  /// Closes this box, then deletes its directory recursively.
  ///
  /// Safe to call more than once. Touches no other box and never calls
  /// `Hive.close` or `Hive.deleteBoxFromDisk`.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      if (box.isOpen) await box.close();
    } finally {
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    }
  }
}

/// Opens a fresh box with a unique name in a fresh temp directory.
///
/// Uses `Hive.openBox(name, path:)`, so no global `Hive.init` is needed.
Future<HiveTestBox> openHiveTestBox() async {
  final directory = await Directory.systemTemp.createTemp('crypt_storage_');
  final name = _nextBoxName();
  try {
    final box = await Hive.openBox<dynamic>(name, path: directory.path);
    return HiveTestBox._(box, name, directory);
  } catch (_) {
    if (directory.existsSync()) await directory.delete(recursive: true);
    rethrow;
  }
}
