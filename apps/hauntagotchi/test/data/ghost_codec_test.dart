import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/data/ghost_codec.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';

Map<String, Object?> _valid() => <String, Object?>{
  'name': 'Boo',
  'health': 70,
  'lastSettled': '2026-01-10',
  'resurrections': 2,
};

void main() {
  const GhostCodec codec = GhostCodec();

  test('round trips a ghost', () {
    final Ghost ghost = Ghost(
      name: 'Boo',
      health: 70,
      lastSettledDay: LocalDay(2026, 1, 10),
      resurrectionCount: 2,
    );
    expect(codec.decode(codec.encode(ghost)), ghost);
  });

  test('encodes exact keys', () {
    final Map<String, Object?> json = codec.encode(
      Ghost(name: 'Boo', health: 0, lastSettledDay: LocalDay(2026, 1, 10)),
    );
    expect(json.keys.toSet(), <String>{
      'name',
      'health',
      'lastSettled',
      'resurrections',
    });
    expect(json['lastSettled'], '2026-01-10');
  });

  test('accepts boundary health 0 and 100', () {
    expect(codec.decode(_valid()..['health'] = 0).health, 0);
    expect(codec.decode(_valid()..['health'] = 100).health, 100);
  });

  test('decode trims the name', () {
    expect(codec.decode(_valid()..['name'] = '  Boo  ').name, 'Boo');
  });

  void rejects(String label, void Function(Map<String, Object?>) mutate) {
    test('decode throws FormatException: $label', () {
      final Map<String, Object?> json = _valid();
      mutate(json);
      expect(() => codec.decode(json), throwsFormatException);
    });
  }

  rejects('empty name', (Map<String, Object?> j) => j['name'] = '');
  rejects('over-40 name', (Map<String, Object?> j) => j['name'] = 'a' * 41);
  rejects('health -1', (Map<String, Object?> j) => j['health'] = -1);
  rejects('health 101', (Map<String, Object?> j) => j['health'] = 101);
  rejects('impossible date', (Map<String, Object?> j) {
    j['lastSettled'] = '2026-02-30';
  });
  rejects('negative resurrections', (Map<String, Object?> j) {
    j['resurrections'] = -1;
  });
  rejects('missing field', (Map<String, Object?> j) => j.remove('health'));
  rejects('wrong type', (Map<String, Object?> j) => j['health'] = '70');
}
