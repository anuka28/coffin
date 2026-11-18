import 'package:coffin_core/coffin_core.dart';

import '../domain/habit.dart';
import '../domain/local_day.dart';
import '../domain/name_rules.dart';

/// Converts [Habit] records to and from JSON maps.
///
/// Record shape: `{id, name, created, completed: [...], archived}` with days
/// as `YYYY-MM-DD` strings and `completed` sorted.
final class HabitCodec implements RecordCodec<Habit> {
  /// Creates a habit codec.
  const HabitCodec();

  @override
  JsonMap encode(Habit record) {
    final List<String> completed =
        record.completedDays.map((LocalDay d) => d.toIso()).toList()..sort();
    return <String, Object?>{
      'id': record.id,
      'name': record.name,
      'created': record.createdDay.toIso(),
      'completed': completed,
      'archived': record.archivedDay?.toIso(),
    };
  }

  @override
  Habit decode(JsonMap json) {
    final String id = _string(json, 'id');
    if (!KeyValidator.isValid(id)) {
      throw const FormatException('Invalid habit id.');
    }
    final String name = _string(json, 'name');
    if (NameRules.violation(name) != null) {
      throw const FormatException('Invalid habit name.');
    }
    final LocalDay created = _day(_string(json, 'created'), 'created');
    final Object? rawCompleted = _field(json, 'completed');
    if (rawCompleted is! List<Object?>) {
      throw const FormatException('Field "completed" must be a list.');
    }
    final Set<LocalDay> completed = <LocalDay>{};
    for (final Object? item in rawCompleted) {
      if (item is! String) {
        throw const FormatException('Completed days must be strings.');
      }
      final LocalDay day = _day(item, 'completed');
      if (day.compareTo(created) < 0) {
        throw const FormatException('Completed day before created.');
      }
      completed.add(day);
    }
    final Object? rawArchived = _field(json, 'archived');
    LocalDay? archived;
    if (rawArchived != null) {
      if (rawArchived is! String) {
        throw const FormatException('Field "archived" must be text or null.');
      }
      archived = _day(rawArchived, 'archived');
      if (archived.compareTo(created) < 0) {
        throw const FormatException('Archived before created.');
      }
    }
    return Habit(
      id: id,
      name: NameRules.normalize(name),
      createdDay: created,
      completedDays: completed,
      archivedDay: archived,
    );
  }

  static Object? _field(JsonMap json, String key) {
    if (!json.containsKey(key)) {
      throw FormatException('Missing field "$key".');
    }
    return json[key];
  }

  static String _string(JsonMap json, String key) {
    final Object? value = _field(json, key);
    if (value is! String) {
      throw FormatException('Field "$key" must be text.');
    }
    return value;
  }

  static LocalDay _day(String iso, String key) {
    final LocalDay? day = LocalDay.tryParse(iso);
    if (day == null) {
      throw FormatException('Field "$key" holds a malformed day.');
    }
    return day;
  }
}
