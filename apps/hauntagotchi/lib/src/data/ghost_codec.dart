import 'package:coffin_core/coffin_core.dart';

import '../domain/balance.dart';
import '../domain/ghost.dart';
import '../domain/local_day.dart';
import '../domain/name_rules.dart';

/// Converts [Ghost] records to and from JSON maps.
///
/// Record shape: `{name, health, lastSettled, resurrections}` with the day as
/// a `YYYY-MM-DD` string.
final class GhostCodec implements RecordCodec<Ghost> {
  /// Creates a ghost codec.
  const GhostCodec();

  @override
  JsonMap encode(Ghost record) => <String, Object?>{
    'name': record.name,
    'health': record.health,
    'lastSettled': record.lastSettledDay.toIso(),
    'resurrections': record.resurrectionCount,
  };

  @override
  Ghost decode(JsonMap json) {
    final String name = _field<String>(json, 'name');
    if (NameRules.violation(name) != null) {
      throw const FormatException('Invalid ghost name.');
    }
    final int health = _field<int>(json, 'health');
    if (health < 0 || health > Balance.maxHealth) {
      throw const FormatException('Health out of range.');
    }
    final LocalDay? settled = LocalDay.tryParse(
      _field<String>(json, 'lastSettled'),
    );
    if (settled == null) {
      throw const FormatException('Field "lastSettled" is malformed.');
    }
    final int resurrections = _field<int>(json, 'resurrections');
    if (resurrections < 0) {
      throw const FormatException('Negative resurrection count.');
    }
    return Ghost(
      name: NameRules.normalize(name),
      health: health,
      lastSettledDay: settled,
      resurrectionCount: resurrections,
    );
  }

  static T _field<T extends Object>(JsonMap json, String key) {
    if (!json.containsKey(key)) {
      throw FormatException('Missing field "$key".');
    }
    final Object? value = json[key];
    if (value is! T) {
      throw FormatException('Field "$key" has the wrong type.');
    }
    return value;
  }
}
