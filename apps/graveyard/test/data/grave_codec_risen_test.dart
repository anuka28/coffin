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

Grave _manualGrave({CalendarDate? risenOn}) => Grave.manual(
  id: 'g1',
  name: 'Old app',
  dateOfDeath: CalendarDate(2024, 2, 29),
  risenOn: risenOn,
);

Grave _githubGrave({CalendarDate? risenOn}) => Grave.github(
  id: 'g2',
  name: 'flutter/flutter',
  dateOfDeath: CalendarDate(2025, 3, 8),
  risenOn: risenOn,
  repo: const RepoInfo(
    fullName: 'flutter/flutter',
    htmlUrl: 'https://github.com/flutter/flutter',
    description: 'UI toolkit',
    archived: true,
    stars: 12,
  ),
);

void main() {
  const codec = GraveCodec();

  group('encode', () {
    test('a risen manual grave has the risen key last', () {
      final json = codec.encode(
        _manualGrave(risenOn: CalendarDate(2025, 10, 31)),
      );
      expect(json, <String, Object?>{..._manual(), 'risen': '2025-10-31'});
      expect(json.keys.toList(), ['id', 'name', 'died', 'source', 'risen']);
    });

    test('a risen github grave has the risen key last', () {
      final json = codec.encode(
        _githubGrave(risenOn: CalendarDate(2026, 1, 5)),
      );
      expect(json, <String, Object?>{..._github(), 'risen': '2026-01-05'});
      expect(json.keys.toList(), [
        'id',
        'name',
        'died',
        'source',
        'repo',
        'risen',
      ]);
    });

    test('a grave that is not risen has no risen key', () {
      final manual = codec.encode(_manualGrave());
      expect(manual, _manual());
      expect(manual.keys.toList(), ['id', 'name', 'died', 'source']);
      final github = codec.encode(_githubGrave());
      expect(github, _github());
      expect(github.containsKey('risen'), isFalse);
    });
  });

  group('decode', () {
    test('a legacy record decodes as not risen', () {
      expect(codec.decode(_manual()).risenOn, isNull);
      expect(codec.decode(_github()).risenOn, isNull);
    });

    test('a valid risen date decodes for both sources', () {
      expect(
        codec.decode(<String, Object?>{..._manual(), 'risen': '2025-10-31'}),
        _manualGrave(risenOn: CalendarDate(2025, 10, 31)),
      );
      expect(
        codec.decode(<String, Object?>{..._github(), 'risen': '2026-01-05'}),
        _githubGrave(risenOn: CalendarDate(2026, 1, 5)),
      );
    });

    test('each malformed risen value throws FormatException', () {
      final bad = <String, Object?>{
        'number': 5,
        'boolean': true,
        'list': <Object?>['2025-10-31'],
        'map': <String, Object?>{'y': 2025},
        'month 13': '2024-13-01',
        'impossible day': '2024-02-30',
        'short year': '24-01-01',
        'empty': '',
        'time part': '2025-10-31T00:00:00',
        'null': null,
      };
      bad.forEach((label, value) {
        expect(
          () => codec.decode(<String, Object?>{..._manual(), 'risen': value}),
          throwsFormatException,
          reason: label,
        );
      });
    });

    test('an unrelated invalid field still fails for its own reason', () {
      for (final risen in <Object?>['2025-10-31', 5, '']) {
        final json = <String, Object?>{
          ..._manual(),
          'name': '',
          'risen': risen,
        };
        expect(
          () => codec.decode(json),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('name'),
            ),
          ),
          reason: '$risen',
        );
      }
    });

    test('unknown keys stay ignored next to risen', () {
      final json = <String, Object?>{
        ..._manual(),
        'risen': '2025-10-31',
        'extra': <Object?>[1],
        'version': 3,
      };
      expect(
        codec.decode(json),
        _manualGrave(risenOn: CalendarDate(2025, 10, 31)),
      );
    });
  });
}
