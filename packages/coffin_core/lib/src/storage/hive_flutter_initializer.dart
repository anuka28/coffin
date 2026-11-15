import 'package:hive_ce_flutter/hive_ce_flutter.dart' show Hive, HiveX;

/// Initializes hive_ce for Flutter apps (documents directory on mobile,
/// IndexedDB on web). Pass it as `StorageOpener.initializer`. [subDir] is an
/// optional folder inside the documents directory.
///
/// Note: hive_ce_flutter's `Hive.initFlutter` registers the Flutter Color and
/// TimeOfDay type adapters (type ids 200 and 201). Coffin registers no adapters
/// of its own, and coffin boxes hold only JSON strings, so those two adapters
/// are never used. Data is stored unencrypted.
///
/// On web each box is its own IndexedDB database in the app's origin. Use
/// prefixed box names such as `hauntagotchi_ghosts` to avoid collisions if
/// both apps are ever served from one origin.
Future<void> hiveFlutterInitializer([String? subDir]) =>
    Hive.initFlutter(subDir);
