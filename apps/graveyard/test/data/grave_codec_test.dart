import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/data/grave_codec.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/repo_info.dart';

Map<String, Object?> _manual() => <String, Object?>{
  'id': 'g1',
  'name': 'Old app',
  'died': '2024-02-29',
  'source': 'manual',
};

Map<String, Object?> _github() => <String, Object?>{
  'id': 'g2',
  'name': 'flutter/flutter',
  'died': '2025-03-08',
  'source': 'github',
  'repo': <String, Object?>{
    'full_name': 'flutter/flutter',
    'html_url': 'https://github.com/flutter/flutter',
    'description': 'UI toolkit',
    'archived': true,
    'stars': 12,
  },
};

void main() {
  const codec = GraveCodec();

  group('encode', () {
    test('manual grave has exactly id, name, died, source', () {
      final json = codec.encode(
        Grave.manual(
          id: 'g1',
          name: 'Old app',
          dateOfDeath: CalendarDate(2024, 2, 29),
        ),
      );
      expect(json.keys.toList(), ['id', 'name', 'died', 'source']);
      expect(json['died'], '2024-02-29');
      expect(json['source'], 'manual');
      expect(json.containsKey('repo'), isFalse);
    });

    test('github grave has the repo key with exactly five fields', () {
      final json = codec.encode(codec.decode(_github()));
      expect(json.keys.toList(), ['id', 'name', 'died', 'source', 'repo']);
      final repo = json['repo']! as Map<String, Object?>;
      expect(repo.keys.toList(), [
        'full_name',
        'html_url',
        'description',
        'archived',
        'stars',
      ]);
      expect(json['source'], 'github');
    });
  });

  group('decode failures (FormatException)', () {
    void expectFails(String label, void Function(Map<String, Object?>) edit) {
      test(label, () {
        final json = _manual();
        edit(json);
        expect(() => codec.decode(json), throwsFormatException);
      });
    }

    expectFails('missing id', (j) => j.remove('id'));
    expectFails('id not a string', (j) => j['id'] = 7);
    expectFails('empty id', (j) => j['id'] = '');
    expectFails('id with non-ASCII', (j) => j['id'] = 'gé');
    expectFails('id over 255 units', (j) => j['id'] = 'a' * 256);
    expectFails('missing name', (j) => j.remove('name'));
    expectFails('name not a string', (j) => j['name'] = 5);
    expectFails('empty name', (j) => j['name'] = '');
    expectFails('whitespace-only name', (j) => j['name'] = ' \t\n ');
    expectFails('name over 80 code points', (j) => j['name'] = 'a' * 81);
    expectFails('missing date', (j) => j.remove('died'));
    expectFails('date not a string', (j) => j['died'] = 20240229);
    expectFails('date malformed', (j) => j['died'] = '2024/02/29');
    expectFails('date impossible', (j) => j['died'] = '2025-02-30');
    expectFails('month 13', (j) => j['died'] = '2025-13-01');
    expectFails('missing source', (j) => j.remove('source'));
    expectFails('unknown source', (j) => j['source'] = 'gitlab');
    expectFails('source not a string', (j) => j['source'] = 1);
  });

  group('decode tolerances', () {
    test('ignores unknown keys at top level and in repo', () {
      final json = _github()
        ..['extra'] = <Object?>[1, 2]
        ..['version'] = 3;
      (json['repo']! as Map<String, Object?>)['forks'] = 9;
      expect(codec.decode(json), codec.decode(_github()));
    });

    test('github grave without repo gets defaults', () {
      final json = _github()..remove('repo');
      final grave = codec.decode(json);
      expect(grave.repo, const RepoInfo(fullName: 'flutter/flutter'));
      expect(grave.repo!.archived, isFalse);
      expect(grave.repo!.stars, 0);
      expect(grave.repo!.htmlUrl, isNull);
      expect(grave.repo!.description, isNull);
    });

    test('repo of the wrong type is treated as missing', () {
      final json = _github()..['repo'] = 'nope';
      expect(codec.decode(json).repo!.fullName, 'flutter/flutter');
    });

    test('wrong-typed repo fields fall back to defaults', () {
      final json = _github()
        ..['repo'] = <String, Object?>{
          'full_name': 3,
          'html_url': 4,
          'description': false,
          'archived': 'yes',
          'stars': 'many',
        };
      final repo = codec.decode(json).repo!;
      expect(repo.fullName, 'flutter/flutter');
      expect(repo.htmlUrl, isNull);
      expect(repo.description, isNull);
      expect(repo.archived, isFalse);
      expect(repo.stars, 0);
    });

    test('negative or fractional stars become 0, integral double is kept', () {
      for (final bad in <Object>[-1, 1.5, double.nan]) {
        final json = _github();
        (json['repo']! as Map<String, Object?>)['stars'] = bad;
        expect(codec.decode(json).repo!.stars, 0, reason: '$bad');
      }
      final json = _github();
      (json['repo']! as Map<String, Object?>)['stars'] = 12.0;
      expect(codec.decode(json).repo!.stars, 12);
    });

    test('repo.full_name falls back to the grave name when empty', () {
      final json = _github()..['name'] = 'my-name';
      (json['repo']! as Map<String, Object?>)['full_name'] = '';
      expect(codec.decode(json).repo!.fullName, 'my-name');
    });

    test('repo.full_name falls back to the grave name when absent', () {
      final json = _github()..['name'] = 'my-name';
      (json['repo']! as Map<String, Object?>).remove('full_name');
      expect(codec.decode(json).repo!.fullName, 'my-name');
    });

    test('manual grave ignores a repo key', () {
      final json = _manual()..['repo'] = <String, Object?>{'stars': 3};
      expect(codec.decode(json).repo, isNull);
    });

    test('name is normalised on decode', () {
      final json = _manual()..['name'] = '  a \t b\n';
      expect(codec.decode(json).name, 'a b');
    });

    test('a stored date before 1970 is accepted', () {
      final json = _manual()..['died'] = '1969-12-31';
      expect(codec.decode(json).dateOfDeath, CalendarDate(1969, 12, 31));
    });
  });
}
