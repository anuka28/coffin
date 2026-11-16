import 'dart:math' as math;

import 'package:coffin_core/src/ai/ai_reply.dart';
import 'package:coffin_core/src/ai/ai_request.dart';
import 'package:coffin_core/src/ai/reply_source.dart';
import 'package:flutter_test/flutter_test.dart' show expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;

import 'support/ai_generators.dart';
import 'support/test_texts.dart';

const int _numRuns = 300;

/// Everything one run needs: a request, two texts and two sources.
final class _Case {
  const _Case(this.request, this.textA, this.textB, this.sourceA, this.sourceB);

  final AiRequest request;
  final String textA;
  final String textB;
  final ReplySource sourceA;
  final ReplySource sourceB;

  @override
  String toString() =>
      '${describeRequest(request)} textA=${escapeForReport(textA)} '
      'textB=${escapeForReport(textB)} sourceA=${sourceA.name} '
      'sourceB=${sourceB.name}';
}

final List<String> _whitespacePieces = <String>[
  for (final int u in (testWhitespaceUnits.toList()..sort()))
    String.fromCharCode(u),
];

final List<String> _pieces = <String>[
  '',
  'a',
  'Z',
  '7',
  ..._whitespacePieces,
  '\u00A0',
  '\u3000',
  '\uFEFF',
  '\u{1F47B}',
  '\u{1F383}',
  '\uD800',
  '\uDC00',
  '\u0000',
  'é',
  '漢',
  'W' * 40,
  'x' * 6000,
];

const List<String> _sourceNames = <String>[
  'offline',
  'remote',
  'zz_test',
  'a',
  'x1_y2',
];

String _pieceText(math.Random random) {
  final int count = random.nextInt(6);
  return <String>[
    for (int i = 0; i < count; i++) _pieces[random.nextInt(_pieces.length)],
  ].join();
}

/// A text whose length is `maxLength` plus -1, 0 or +1, in a few shapes.
String _nearLimitText(math.Random random, int maxLength) {
  final int length = maxLength + random.nextInt(3) - 1;
  final String unit =
      _whitespacePieces[random.nextInt(_whitespacePieces.length)];
  switch (random.nextInt(4)) {
    case 0:
      return 'a' * length;
    case 1:
      // Blank text of the exact length.
      return unit * length;
    case 2:
      // Blank except for the last unit.
      return '${unit * (length - 1)}a';
    default:
      // Mostly text, with a whitespace edge.
      return 'a${unit * (length - 1)}';
  }
}

String _anyText(math.Random random, int maxLength) => random.nextInt(100) < 40
    ? _nearLimitText(random, maxLength)
    : _pieceText(random);

ReplySource _anySource(math.Random random) {
  final String name = _sourceNames[random.nextInt(_sourceNames.length)];
  return name == 'offline' ? ReplySource.offline : ReplySource(name);
}

Generator<_Case> get _anyCase => any.simple<_Case>(
  generate: (math.Random random, int size) {
    final AiRequest request = anyAiRequest(random, size).value;
    final String a = _anyText(random, request.maxLength);
    // Half of the pairs repeat a field so equal replies are common.
    final String b = random.nextBool()
        ? a
        : _anyText(random, request.maxLength);
    final ReplySource sa = _anySource(random);
    final ReplySource sb = random.nextBool() ? sa : _anySource(random);
    return _Case(request, a, b, sa, sb);
  },
  shrink: (_Case c) => const <_Case>[],
);

/// The test's own usable check.
bool _oracle(String text, int maxLength) =>
    !isTestBlank(text) && text.length <= maxLength;

final RunCounter _runs = RunCounter();

void main() {
  group('AiReply property: equality and the usable check', () {
    // Feature: coffin-ai, Property 16: Reply equality and the usable check
    // Validates: Requirements 3.1, 3.2, 3.3
    Glados(_anyCase, ExploreConfig(numRuns: _numRuns)).test(
      'equality, hash and isUsableFor match the oracle',
      (_Case c) {
        _runs.increment();
        final String why = 'input $c';

        final AiReply a = AiReply(text: c.textA, source: c.sourceA);
        final AiReply b = AiReply(text: c.textB, source: c.sourceB);

        final bool fieldsEqual =
            c.textA == c.textB && c.sourceA.name == c.sourceB.name;
        expect(a == b, fieldsEqual, reason: why);
        expect(b == a, fieldsEqual, reason: why);
        if (fieldsEqual) {
          expect(a.hashCode, b.hashCode, reason: why);
        }

        // A reply equals a fresh copy of itself, with the same hash.
        final AiReply copy = AiReply(text: c.textA, source: c.sourceA);
        expect(a, copy, reason: why);
        expect(a.hashCode, copy.hashCode, reason: why);

        expect(
          a.isUsableFor(c.request),
          _oracle(c.textA, c.request.maxLength),
          reason: 'A: $why',
        );
        expect(
          b.isUsableFor(c.request),
          _oracle(c.textB, c.request.maxLength),
          reason: 'B: $why',
        );
      },
    );

    test('the property ran 300 times', () {
      expect(_runs.runs, greaterThan(0));
      expect(_runs.runs, _numRuns);
    });
  });
}
