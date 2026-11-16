import 'dart:math' as math;

import 'package:coffin_core/src/ai/text_rules.dart';
import 'package:flutter_test/flutter_test.dart' show expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;

import 'support/ai_generators.dart';
import 'support/test_texts.dart';

const int _numRuns = 300;

final List<String> _whitespacePieces = <String>[
  for (final int u in (testWhitespaceUnits.toList()..sort()))
    String.fromCharCode(u),
];

// Pieces for raw text: ASCII, whitespace runs, control characters, emoji,
// lone surrogates, accents, CJK and long text.
final List<String> _rawPieces = <String>[
  'a',
  'Z',
  '7',
  '-',
  'é',
  '漢',
  '\u{1F47B}',
  '\u{1F383}',
  '\u{1F468}\u200D\u{1F469}',
  '\uD800',
  '\uDBFF',
  '\uDC00',
  '\uDFFF',
  '\u0000',
  '\u0001',
  '\u001F',
  '\u007F',
  '\u0080',
  '\u009F',
  '\u0085',
  ..._whitespacePieces,
  '   ',
  '\n\n\t \r',
  '\u2003\u2003\u3000',
  'W' * 23,
  'W' * 40,
  'x' * 200,
];

String _rawText(math.Random random) {
  final int count = random.nextInt(12);
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < count; i++) {
    buffer.write(_rawPieces[random.nextInt(_rawPieces.length)]);
  }
  // Often put an emoji or a lone high surrogate on the 24-unit boundary.
  if (random.nextInt(100) < 25) {
    final String edge = random.nextBool() ? '\u{1F47B}' : '\uD83D';
    return '${'W' * (22 + random.nextInt(3))}$edge$buffer';
  }
  return buffer.toString();
}

/// Raw strings for name cleaning: emoji, lone surrogates, control characters,
/// runs of whitespace and long text. Built from a piece list, so it is safe on
/// Flutter Web. Shrinks by dropping the first or last half of the text.
Generator<String> get anyRawName => any.simple<String>(
  generate: (math.Random random, int size) => _rawText(random),
  shrink: (String s) sync* {
    if (s.isEmpty) return;
    yield '';
    if (s.length > 1) {
      yield s.substring(0, s.length ~/ 2);
      yield s.substring(s.length ~/ 2);
    }
  },
);

bool _isControl(int u) => u < 0x20 || (u >= 0x7F && u <= 0x9F);

/// Returns the first broken promise of a cleaned name, or null when it holds.
String? nameViolation(String out) {
  if (out.length > 24) return 'longer than 24 code units (${out.length})';
  final List<int> units = out.codeUnits;
  for (int i = 0; i < units.length; i++) {
    if (_isControl(units[i])) return 'control unit at index $i';
    if (i > 0 && isTestWhitespace(units[i]) && isTestWhitespace(units[i - 1])) {
      return 'adjacent whitespace at index $i';
    }
  }
  if (hasLoneSurrogate(out)) return 'unpaired surrogate';
  if (hasEdgeWhitespace(out)) return 'leading or trailing whitespace';
  return null;
}

final RunCounter _nameRuns = RunCounter();

/// One input of Property 11: a text and a limit.
final class _TruncateCase {
  const _TruncateCase(this.text, this.limit);

  final String text;
  final int limit;
}

// First units that are neither whitespace nor surrogate halves on their own.
const List<String> _startPieces = <String>[
  'a',
  'Z',
  '7',
  'é',
  '漢',
  '\u{1F47B}',
  '\u{1F383}',
];

// Whole pieces only, so no piece ever holds a lone surrogate.
final List<String> _bodyPieces = <String>[
  'a',
  'b',
  '-',
  'é',
  '漢',
  '\u{1F47B}',
  '\u{1F383}',
  '\u{1F468}\u200D\u{1F469}',
  ..._whitespacePieces,
  '   ',
  '\n\t ',
  '\u2003\u3000',
  'word ',
  'W' * 9,
];

_TruncateCase _truncateCase(math.Random random) {
  final int m = random.nextInt(100) < 40
      ? 16 + random.nextInt(3)
      : 16 + random.nextInt(185);
  final List<int> lengths = <int>[
    m - 1,
    m,
    m + 1,
    m + 2,
    m + 3,
    m + 1 + random.nextInt(300),
  ];
  final int target = lengths[random.nextInt(lengths.length)];

  final StringBuffer buffer = StringBuffer(
    _startPieces[random.nextInt(_startPieces.length)],
  );
  String current() => buffer.toString();
  void fillTo(int end) {
    while (current().length < end) {
      final String piece = _bodyPieces[random.nextInt(_bodyPieces.length)];
      if (current().length + piece.length > end) {
        buffer.write('a');
      } else {
        buffer.write(piece);
      }
    }
  }

  // Half of the time an emoji starts at m - 3, m - 2 or m - 1, so the cut at
  // m - 1 lands on or next to a surrogate pair.
  if (random.nextBool()) {
    final int start = m - 3 + random.nextInt(3);
    fillTo(start);
    buffer.write(random.nextBool() ? '\u{1F47B}' : '\u{1F383}');
  }
  fillTo(target);
  return _TruncateCase(current(), m);
}

/// Texts that start with a non-whitespace unit and have no lone surrogate,
/// paired with a limit of 16 or more. Texts are about `m - 1`, `m`, `m + 1`
/// or much longer, with emoji at the cut. Built from pieces, safe on Web.
Generator<_TruncateCase> get _anyTruncateCase => any.simple<_TruncateCase>(
  generate: (math.Random random, int size) => _truncateCase(random),
  shrink: (_TruncateCase c) => const Iterable<_TruncateCase>.empty(),
);

final RunCounter _truncateRuns = RunCounter();

void main() {
  group('TextRules property: name cleaning', () {
    // Feature: coffin-ai, Property 10: Name cleaning
    // Validates: Requirements 6.5, 6.10
    Glados(anyRawName, ExploreConfig(numRuns: _numRuns)).test(
      'cleanName keeps its promises and is idempotent',
      (String raw) {
        _nameRuns.increment();
        final String out = TextRules.cleanName(raw);
        final String again = TextRules.cleanName(out);
        final String why =
            'input ${escapeForReport(raw)} output ${escapeForReport(out)} '
            'second pass ${escapeForReport(again)}';

        final String? broken = nameViolation(out);
        expect(broken, isNull, reason: '$broken: $why');
        expect(again, out, reason: 'not idempotent: $why');
      },
    );

    test('the property ran 300 times', () {
      expect(_nameRuns.runs, greaterThan(0));
      expect(_nameRuns.runs, _numRuns);
    });
  });

  group('TextRules property: truncation', () {
    // Feature: coffin-ai, Property 11: Truncation keeps its promises
    // Validates: Requirements 7.4, 7.5
    Glados(_anyTruncateCase, ExploreConfig(numRuns: _numRuns)).test(
      'truncate stays within the limit, keeps text that fits, ends with an '
      'ellipsis otherwise',
      (_TruncateCase c) {
        _truncateRuns.increment();
        final String s = c.text;
        final int m = c.limit;
        final String out = TextRules.truncate(s, m);
        final String why =
            'input ${escapeForReport(s)} (length ${s.length}) limit $m '
            'output ${escapeForReport(out)} (length ${out.length})';

        // Guard the generator itself.
        expect(m, greaterThanOrEqualTo(16), reason: 'bad generator: $why');
        expect(isTestWhitespace(s.codeUnits.first), isFalse, reason: why);
        expect(hasLoneSurrogate(s), isFalse, reason: 'bad generator: $why');

        expect(out.length, lessThanOrEqualTo(m), reason: 'too long: $why');
        expect(out, isNotEmpty, reason: 'empty: $why');
        expect(hasLoneSurrogate(out), isFalse, reason: 'lone: $why');
        if (s.length <= m) {
          expect(out, s, reason: 'fitting text changed: $why');
        } else {
          expect(out.endsWith('\u2026'), isTrue, reason: 'no ellipsis: $why');
          expect(
            isTestWhitespace(out.codeUnits.last),
            isFalse,
            reason: 'trailing whitespace: $why',
          );
        }
      },
    );

    test('the property ran 300 times', () {
      expect(_truncateRuns.runs, greaterThan(0));
      expect(_truncateRuns.runs, _numRuns);
    });
  });
}
