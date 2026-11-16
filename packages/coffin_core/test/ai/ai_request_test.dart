import 'package:coffin_core/src/ai/ai_purpose.dart';
import 'package:coffin_core/src/ai/ai_request.dart';
import 'package:flutter_test/flutter_test.dart';

AiRequest make({
  AiPurpose purpose = AiPurpose.ghostMoodLine,
  Map<String, Object?> facts = const <String, Object?>{},
  int maxLength = 80,
  int seed = 0,
}) =>
    AiRequest(purpose: purpose, facts: facts, maxLength: maxLength, seed: seed);

void main() {
  group('limits', () {
    test('constants', () {
      expect(AiRequest.minimumMaxLength, 16);
      expect(AiRequest.maxSeed, 4294967295);
    });

    test('maxLength 15 throws and names the minimum', () {
      expect(
        () => make(maxLength: 15),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.toString(),
            'message',
            contains('16'),
          ),
        ),
      );
    });

    test('maxLength 16 and 17 are accepted', () {
      expect(make(maxLength: 16).maxLength, 16);
      expect(make(maxLength: 17).maxLength, 17);
    });

    test('seed outside the range throws and names the range', () {
      for (final int bad in <int>[-1, 4294967296]) {
        expect(
          () => make(seed: bad),
          throwsA(
            isA<ArgumentError>().having(
              (ArgumentError e) => e.toString(),
              'message',
              contains('4294967295'),
            ),
          ),
        );
      }
    });

    test('seed 0 and 4294967295 are accepted, default seed is 0', () {
      expect(make(seed: 0).seed, 0);
      expect(make(seed: 4294967295).seed, 4294967295);
      expect(
        AiRequest(purpose: AiPurpose.seanceVerdict, maxLength: 16).seed,
        0,
      );
    });
  });

  group('facts', () {
    test('default to empty', () {
      expect(
        AiRequest(purpose: AiPurpose.ghostMoodLine, maxLength: 16).facts,
        isEmpty,
      );
    });

    test('a later change to the caller map does not reach the request', () {
      final Map<String, Object?> source = <String, Object?>{'a': 1};
      final AiRequest request = make(facts: source);
      source['b'] = 2;
      source['a'] = 9;
      expect(request.facts, <String, Object?>{'a': 1});
    });

    test('the facts map is unmodifiable', () {
      final AiRequest request = make(facts: <String, Object?>{'a': 1});
      expect(() => request.facts['b'] = 2, throwsUnsupportedError);
      expect(() => request.facts.remove('a'), throwsUnsupportedError);
    });

    test('odd facts are accepted', () {
      final Object thing = Object();
      final AiRequest request = make(
        facts: <String, Object?>{
          '': 1,
          'list': <int>[1],
          'map': <String, int>{'x': 1},
          'nan': double.nan,
          'inf': double.infinity,
          'neg': double.negativeInfinity,
          'null': null,
          'object': thing,
        },
      );
      expect(request.facts.length, 8);
      expect(request.hashCode, request.hashCode);
    });
  });

  group('equality and hash', () {
    test('insertion order does not matter', () {
      final AiRequest a = make(
        facts: <String, Object?>{'x': 1, 'y': 'two', 'z': null},
      );
      final AiRequest b = make(
        facts: <String, Object?>{'z': null, 'y': 'two', 'x': 1},
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a NaN fact equals itself and hashes the same', () {
      final AiRequest a = make(facts: <String, Object?>{'x': double.nan});
      final AiRequest b = make(facts: <String, Object?>{'x': double.nan});
      expect(a, a);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('5 equals 5.0 with the same hash', () {
      final AiRequest a = make(facts: <String, Object?>{'x': 5});
      final AiRequest b = make(facts: <String, Object?>{'x': 5.0});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('0, -0.0 and large whole numbers hash alike when equal', () {
      final List<List<num>> pairs = <List<num>>[
        <num>[0, -0.0],
        <num>[0, 0.0],
        <num>[-7, -7.0],
        <num>[9007199254740991, 9007199254740991.0],
      ];
      for (final List<num> p in pairs) {
        final AiRequest a = make(facts: <String, Object?>{'x': p[0]});
        final AiRequest b = make(facts: <String, Object?>{'x': p[1]});
        expect(a, b);
        expect(a.hashCode, b.hashCode);
      }
    });

    test('different values are not equal', () {
      expect(
        make(facts: <String, Object?>{'x': 5}),
        isNot(make(facts: <String, Object?>{'x': 6})),
      );
      expect(
        make(facts: <String, Object?>{'x': double.nan}),
        isNot(make(facts: <String, Object?>{'x': 0})),
      );
      expect(
        make(facts: <String, Object?>{'x': null}),
        isNot(make(facts: <String, Object?>{'y': null})),
      );
    });

    test('changing any one field changes equality', () {
      final AiRequest base = make(
        facts: <String, Object?>{'x': 1},
        maxLength: 40,
        seed: 3,
      );
      final Map<String, Object?> facts = <String, Object?>{'x': 1};
      expect(
        base,
        AiRequest(
          purpose: AiPurpose.ghostMoodLine,
          facts: facts,
          maxLength: 40,
          seed: 3,
        ),
      );
      expect(
        base,
        isNot(
          make(
            purpose: AiPurpose.seanceVerdict,
            facts: facts,
            maxLength: 40,
            seed: 3,
          ),
        ),
      );
      expect(
        base,
        isNot(make(facts: <String, Object?>{'x': 2}, maxLength: 40, seed: 3)),
      );
      expect(base, isNot(make(facts: facts, maxLength: 41, seed: 3)));
      expect(base, isNot(make(facts: facts, maxLength: 40, seed: 4)));
    });

    test('a custom purpose that reuses a known id is equal', () {
      expect(
        make(purpose: AiPurpose('ghost_mood_line')),
        make(purpose: AiPurpose.ghostMoodLine),
      );
    });
  });

  test('toString shows the purpose, count, limit and seed but no value', () {
    final String text = make(
      facts: <String, Object?>{'ghostName': 'Zorbulon', 'n': 31337},
      maxLength: 42,
      seed: 7,
    ).toString();
    expect(text, contains('ghost_mood_line'));
    expect(text, contains('2'));
    expect(text, contains('42'));
    expect(text, contains('7'));
    expect(text, isNot(contains('Zorbulon')));
    expect(text, isNot(contains('31337')));
  });
}
