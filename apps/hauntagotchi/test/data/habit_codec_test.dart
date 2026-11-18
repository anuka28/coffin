import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/data/habit_codec.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';

Map<String, Object?> _valid() => <String, Object?>{
  'id': 'h1',
  'name': 'Stretch',
  'created': '2026-01-10',
  'completed': <Object?>['2026-01-11'],
  'archived': null,
};

void main() {
  const HabitCodec codec = HabitCodec();

  test('round trips an active and an archived habit', () {
    final Habit active = Habit(
      id: 'h1',
      name: 'Stretch',
      createdDay: LocalDay(2026, 1, 10),
      completedDays: <LocalDay>{LocalDay(2026, 1, 12), LocalDay(2026, 1, 11)},
    );
    final Habit archived = active.copyWith(archivedDay: LocalDay(2026, 2, 1));
    expect(codec.decode(codec.encode(active)), active);
    expect(codec.decode(codec.encode(archived)), archived);
  });

  test('encodes exact keys and sorted completed days', () {
    final Map<String, Object?> json = codec.encode(
      Habit(
        id: 'h1',
        name: 'Stretch',
        createdDay: LocalDay(2026, 1, 10),
        completedDays: <LocalDay>{LocalDay(2026, 1, 12), LocalDay(2026, 1, 11)},
      ),
    );
    expect(json.keys.toSet(), <String>{
      'id',
      'name',
      'created',
      'completed',
      'archived',
    });
    expect(json['completed'], <String>['2026-01-11', '2026-01-12']);
    expect(json['archived'], isNull);
  });

  test('decode trims the name', () {
    final Map<String, Object?> json = _valid()..['name'] = '  Stretch  ';
    expect(codec.decode(json).name, 'Stretch');
  });

  void rejects(String label, void Function(Map<String, Object?>) mutate) {
    test('decode throws FormatException: $label', () {
      final Map<String, Object?> json = _valid();
      mutate(json);
      expect(() => codec.decode(json), throwsFormatException);
    });
  }

  rejects('empty name', (Map<String, Object?> j) => j['name'] = '   ');
  rejects('over-40 name', (Map<String, Object?> j) => j['name'] = 'a' * 41);
  rejects('invalid id', (Map<String, Object?> j) => j['id'] = '');
  rejects('impossible date', (Map<String, Object?> j) {
    j['created'] = '2026-02-30';
  });
  rejects('missing field', (Map<String, Object?> j) => j.remove('name'));
  rejects('missing archived', (Map<String, Object?> j) => j.remove('archived'));
  rejects('wrong type name', (Map<String, Object?> j) => j['name'] = 5);
  rejects('wrong type completed', (Map<String, Object?> j) {
    j['completed'] = 'x';
  });
  rejects('wrong type completed item', (Map<String, Object?> j) {
    j['completed'] = <Object?>[3];
  });
  rejects('wrong type archived', (Map<String, Object?> j) => j['archived'] = 1);
  rejects('completed before created', (Map<String, Object?> j) {
    j['completed'] = <Object?>['2026-01-09'];
  });
  rejects('archived before created', (Map<String, Object?> j) {
    j['archived'] = '2026-01-09';
  });
}
