import 'dart:math' as math;

import 'package:coffin_core/src/ai/ai_purpose.dart';
import 'package:flutter_test/flutter_test.dart'
    show expect, group, isTrue, test, throwsArgumentError;
import 'package:glados/glados.dart' hide expect, group, test;

import 'support/ai_generators.dart';

const int _numRuns = 300;

const String _lower = 'abcdefghijklmnopqrstuvwxyz';
const String _rest = 'abcdefghijklmnopqrstuvwxyz0123456789_';

// Pieces for the bad strings: uppercase, digits, spaces, accents, emoji,
// lone surrogates, punctuation.
const List<String> _badPieces = <String>[
  'A',
  'Z',
  '0',
  '9',
  ' ',
  '-',
  '.',
  'é',
  'ß',
  '漢',
  '\u{1F47B}',
  '\uD800',
  '\uDC00',
  '\n',
  '\u0000',
];

String _fromAlphabet(math.Random r, String alphabet, int length) =>
    String.fromCharCodes(<int>[
      for (int i = 0; i < length; i++)
        alphabet.codeUnitAt(r.nextInt(alphabet.length)),
    ]);

String _validOfLength(math.Random r, int length) =>
    _fromAlphabet(r, _lower, 1) + _fromAlphabet(r, _rest, length - 1);

/// Strings that mix valid identifiers with every kind of near miss, with
/// lengths around 64.
Generator<String> get _anyCandidate => any.simple<String>(
  generate: (math.Random r, int size) {
    final int kind = r.nextInt(8);
    // Length near the 64 limit about half of the time.
    final int length = r.nextBool() ? 62 + r.nextInt(5) : 1 + r.nextInt(70);
    switch (kind) {
      case 0:
      case 1:
        return _validOfLength(r, length);
      case 2:
        return ''; // empty
      case 3:
        // Valid, then one bad piece somewhere.
        final String base = _validOfLength(r, math.min(length, 60));
        final int at = r.nextInt(base.length + 1);
        final String bad = _badPieces[r.nextInt(_badPieces.length)];
        return base.substring(0, at) + bad + base.substring(at);
      case 4:
        // Leading digit, uppercase or underscore.
        return _fromAlphabet(r, '0123456789_ABZ', 1) +
            _fromAlphabet(r, _rest, length - 1);
      case 5:
        // Random bad pieces only.
        final int n = 1 + r.nextInt(5);
        return <String>[
          for (int i = 0; i < n; i++) _badPieces[r.nextInt(_badPieces.length)],
        ].join();
      case 6:
        // Exactly 64 or 65 units, valid characters.
        return _validOfLength(r, 64 + r.nextInt(2));
      default:
        // Valid known identifiers and their uppercase forms.
        const List<String> known = <String>[
          'ghost_mood_line',
          'seance_verdict',
          'Ghost_mood_line',
          'séance_verdict',
          'séance verdict',
        ];
        return known[r.nextInt(known.length)];
    }
  },
  shrink: (String s) sync* {
    if (s.length > 1) {
      yield s.substring(0, s.length ~/ 2);
      yield s.substring(1);
    }
  },
);

const List<String> _pool = <String>[
  'a',
  'b',
  'ab',
  'a_1',
  'ghost_mood_line',
  'seance_verdict',
  'z9',
];

/// Accepted identifiers from a small pool, so two draws are often equal.
/// One in six is a random valid identifier, including the 64 unit one.
Generator<String> get _anyAccepted => any.simple<String>(
  generate: (math.Random r, int size) {
    final int pick = r.nextInt(7);
    if (pick < 5) return _pool[r.nextInt(_pool.length)];
    if (pick == 5) return _validOfLength(r, 64);
    return _validOfLength(r, 1 + r.nextInt(64));
  },
  shrink: (String s) => s == 'a' ? const <String>[] : const <String>['a'],
);

// The rules, written from the requirement text.
bool _oracle(String s) {
  final List<int> units = s.codeUnits;
  if (units.isEmpty || units.length > 64) return false;
  final int first = units.first;
  if (first < 0x61 || first > 0x7A) return false;
  for (final int u in units.skip(1)) {
    final bool ok =
        (u >= 0x61 && u <= 0x7A) || (u >= 0x30 && u <= 0x39) || u == 0x5F;
    if (!ok) return false;
  }
  return true;
}

void main() {
  group('AiPurpose property: identifier rules', () {
    final RunCounter rulesRuns = RunCounter();

    // Feature: coffin-ai, Property 15: Purpose identifier rules and equality
    // Validates: Requirements 2.12, 2.13, 2.15, 2.16
    Glados(_anyCandidate, ExploreConfig(numRuns: _numRuns)).test(
      'accepted exactly when the rules hold',
      (s) {
        rulesRuns.increment();
        final String why =
            'input ${escapeForReport(s)} '
            '(${s.codeUnits.length} units)';
        final bool expected = _oracle(s);
        AiPurpose? made;
        Object? error;
        try {
          made = AiPurpose(s);
        } catch (e) {
          error = e;
        }
        if (expected) {
          expect(error, null, reason: 'should be accepted: $why');
          expect(made!.id, s, reason: why);
        } else {
          expect(
            error is ArgumentError,
            isTrue,
            reason: 'should raise ArgumentError, got $error: $why',
          );
          expect(() => AiPurpose(s), throwsArgumentError, reason: why);
        }
      },
    );

    test('the identifier property ran 300 times', () {
      expect(rulesRuns.runs, _numRuns);
    });
  });

  group('AiPurpose property: equality', () {
    final RunCounter equalityRuns = RunCounter();

    // Feature: coffin-ai, Property 15: Purpose identifier rules and equality
    // Validates: Requirements 2.12, 2.13, 2.15, 2.16
    Glados2(_anyAccepted, _anyAccepted, ExploreConfig(numRuns: _numRuns)).test(
      'equal exactly when the strings are equal, with equal hashes',
      (a, b) {
        equalityRuns.increment();
        final String why =
            'inputs ${escapeForReport(a)} and '
            '${escapeForReport(b)}';
        final AiPurpose pa = AiPurpose(a);
        final AiPurpose pb = AiPurpose(b);
        expect(pa == pb, a == b, reason: why);
        expect(pb == pa, a == b, reason: why);
        if (pa == pb) {
          expect(pa.hashCode, pb.hashCode, reason: why);
        }
        // A fresh purpose from the same string is always equal.
        expect(AiPurpose(a), pa, reason: why);
        expect(AiPurpose(a).hashCode, pa.hashCode, reason: why);
      },
    );

    test('the equality property ran 300 times', () {
      expect(equalityRuns.runs, _numRuns);
    });
  });
}
