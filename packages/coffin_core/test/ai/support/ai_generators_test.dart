import 'dart:math' as math;

import 'package:coffin_core/src/ai/ai_purpose.dart';
import 'package:coffin_core/src/ai/ai_request.dart';
import 'package:flutter_test/flutter_test.dart'
    show expect, group, isTrue, test;
import 'package:glados/glados.dart' hide expect, group, test;

import 'ai_generators.dart';
import 'test_texts.dart';

const int _numRuns = 200;
final RunCounter _counter = RunCounter();

void main() {
  const String ghost = '\u{1F47B}';

  group('generators', () {
    final math.Random random = math.Random(2024);
    final List<AiRequest> samples = <AiRequest>[
      for (int i = 0; i < 3000; i++) anyAiRequest(random, 10).value,
    ];

    Glados(anyAiRequest, ExploreConfig(numRuns: _numRuns)).test(
      'requests stay in range and construct',
      (AiRequest r) {
        _counter.increment();
        expect(r.seed >= 0 && r.seed <= 4294967295, isTrue);
        expect(r.maxLength >= 16, isTrue);
        expect(AiPurpose.violation(r.purpose.id), null);
      },
    );

    test('the run counter counted every run', () {
      expect(_counter.runs > 0, isTrue);
      expect(_counter.runs, _numRuns);
    });

    test('seeds, limits and ids stay in range', () {
      for (final AiRequest r in samples) {
        expect(r.seed >= 0 && r.seed <= 4294967295, isTrue);
        expect(r.maxLength >= 16 && r.maxLength <= 5000, isTrue);
        expect(AiPurpose.violation(r.purpose.id), null);
        expect(r.purpose.id.length <= 64, isTrue);
      }
    });

    test('edge seeds and limits appear', () {
      final Set<int> seeds = samples.map((AiRequest r) => r.seed).toSet();
      for (final int edge in edgeSeeds) {
        expect(seeds.contains(edge), isTrue, reason: 'seed $edge');
      }
      final Set<int> limits = samples.map((AiRequest r) => r.maxLength).toSet();
      for (final int edge in edgeMaxLengths) {
        expect(limits.contains(edge), isTrue, reason: 'limit $edge');
      }
      expect(seeds.any((int s) => s > 65536 && !edgeSeeds.contains(s)), isTrue);
    });

    test('every kind of purpose and fact appears', () {
      final Set<String> ids = samples
          .map((AiRequest r) => r.purpose.id)
          .toSet();
      expect(ids.contains('ghost_mood_line'), isTrue);
      expect(ids.contains('seance_verdict'), isTrue);
      expect(ids.any((String s) => s.startsWith(purposeMarker)), isTrue);
      expect(ids.any((String s) => s.length == 64), isTrue);
      final List<Object?> values = <Object?>[
        for (final AiRequest r in samples) ...r.facts.values,
      ];
      expect(values.any((Object? v) => v is double && v.isNaN), isTrue);
      expect(values.any((Object? v) => v == double.infinity), isTrue);
      expect(values.any((Object? v) => v == 9007199254740991), isTrue);
      expect(values.any((Object? v) => v is List), isTrue);
      expect(values.any((Object? v) => v is Map), isTrue);
      expect(values.any((Object? v) => v is String), isTrue);
      expect(samples.any((AiRequest r) => r.facts.containsKey('')), isTrue);
      expect(
        samples.any((AiRequest r) => r.facts.containsKey('ghostName')),
        isTrue,
      );
    });

    test('anyIntBetween reaches the top of a 2^32 span', () {
      final Generator<int> gen = anyIntBetween(0, 4294967296);
      final math.Random r = math.Random(5);
      int largest = 0;
      for (int i = 0; i < 2000; i++) {
        final int v = gen(r, 10).value;
        expect(v >= 0 && v < 4294967296, isTrue);
        if (v > largest) largest = v;
      }
      expect(largest > 4000000000, isTrue);
    });

    test('anyListBetween respects its length range', () {
      final Generator<List<int>> gen = anyListBetween(
        2,
        5,
        anyIntBetween(0, 9),
      );
      final math.Random r = math.Random(6);
      for (int i = 0; i < 200; i++) {
        final int n = gen(r, 10).value.length;
        expect(n >= 2 && n < 5, isTrue);
      }
    });
  });

  group('describeRequest', () {
    test('prints id, escaped facts, limit and seed', () {
      final AiRequest r = AiRequest(
        purpose: AiPurpose.ghostMoodLine,
        facts: <String, Object?>{
          'ghostName': 'Bo\n"x"\u0000',
          'streakCount': 5,
          'odd': <Object?>[double.nan, null],
          '': ghost,
        },
        maxLength: 80,
        seed: 4294967295,
      );
      final String text = describeRequest(r);
      expect(text.contains('ghost_mood_line'), isTrue);
      expect(text.contains(r'"ghostName": "Bo\n\"x\"\u0000"'), isTrue);
      expect(text.contains('"streakCount": 5'), isTrue);
      expect(text.contains('[NaN, null]'), isTrue);
      expect(text.contains(r'"": "\uD83D\uDC7B"'), isTrue);
      expect(text.contains('maxLength: 80'), isTrue);
      expect(text.contains('seed: 4294967295'), isTrue);
      expect(text.codeUnits.every((int u) => u >= 0x20 && u < 0x7F), isTrue);
    });
  });

  group('test texts', () {
    test('word lists have the right sizes', () {
      expect(testBannedWords.length, 20);
      expect(testInsultWords.length, 13);
      expect(testBannedWords.toSet().length, 20);
    });

    test('asciiFold lowers A to Z only', () {
      expect(asciiFold('BLOODhound ÉK\u212A'), 'bloodhound Ék\u212A');
    });

    test('banned and insult checks use substrings', () {
      expect(hasTestBannedWord('BLOODhound'), isTrue);
      expect(hasTestBannedWord('skillful'), isTrue);
      expect(hasTestBannedWord('category stable august gorgeous claim'), false);
      expect(hasTestInsultWord('Such a LAZY ghost'), isTrue);
      expect(hasTestInsultWord('Floating along.'), false);
    });

    test('whitespace set and blank check', () {
      for (final int u in <int>[
        9,
        13,
        32,
        0x85,
        0xA0,
        0x1680,
        0x2005,
        0x3000,
      ]) {
        expect(isTestWhitespace(u), isTrue, reason: '$u');
      }
      expect(isTestWhitespace(0x200B), false);
      expect(isTestWhitespace(0x41), false);
      expect(isTestBlank(''), isTrue);
      expect(isTestBlank(' \u00A0\u3000\n'), isTrue);
      expect(isTestBlank(' a '), false);
    });

    test('lone surrogate check', () {
      expect(hasLoneSurrogate(ghost), false);
      expect(hasLoneSurrogate('a\uD800'), isTrue);
      expect(hasLoneSurrogate('\uDC00a'), isTrue);
      expect(hasLoneSurrogate('\uD800\uD800\uDC00'), isTrue);
      expect(hasLoneSurrogate('plain'), false);
    });

    test('edge whitespace check', () {
      expect(hasEdgeWhitespace(' a'), isTrue);
      expect(hasEdgeWhitespace('a\u3000'), isTrue);
      expect(hasEdgeWhitespace('a b'), false);
      expect(hasEdgeWhitespace(''), false);
    });

    test('emoji counter', () {
      expect(countEmoji('Boo. $ghost'), 1);
      expect(countEmoji('$ghost\u{1F383}'), 2);
      expect(countEmoji('Your ghost is getting hungry\u2026'), 0);
      expect(countEmoji('caf\u00E9 \u6F22'), 0);
      expect(countEmoji('\uD83D'), 0);
    });
  });
}
