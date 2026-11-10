import 'json_map.dart';

/// Upgrades [data] from [fromVersion] to the repository's current version.
///
/// Receives a copy of the stored map, so changing it never alters stored data.
/// Returns the upgraded map. If it throws, the entry is skipped and a
/// migration failure is reported.
typedef MigrationHook = JsonMap Function(int fromVersion, JsonMap data);
