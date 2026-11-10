import 'package:coffin_core/src/storage/key_validator.dart';
import 'package:flutter_test/flutter_test.dart' show expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;

const int _numRuns = 200;

/// Boundary keys B1 to B11 from the design's boundary key table.
final List<String> _boundaryKeys = <String>[
  '', // B1
  'a', // B2
  'k' * 255, // B3
  'k' * 256, // B4
  'x\u007F', // B5
  '\u0000', // B6
  'x\u0080', // B7
  '\u{1F47B}', // B8
  '\uD800', // B9
  'é' * 128, // B10
  'a/b..c d', // B11
];

/// Code units that are not ASCII: accented letters, CJK, lone surrogates and
/// the two halves of an emoji.
const List<int> _nonAsciiUnits = <int>[
  0x80,
  0xE9, // é
  0xFF,
  0x4E2D, // CJK
  0xD800, // lone high surrogate
  0xDC00, // lone low surrogate
  0xD83D, // emoji high half
  0xDC7B, // emoji low half
  0xFFFF,
];

/// Builds an ASCII string of [length] units from [seeds] (cycled).
String _ascii(int length, List<int> seeds) {
  if (seeds.isEmpty) return 'k' * length;
  return String.fromCharCodes(<int>[
    for (var i = 0; i < length; i++) seeds[i % seeds.length].abs() % 0x80,
  ]);
}

/// Mixes ASCII, accented letters, emoji, lone surrogates, lengths around 255
/// and the boundary keys.
Generator<String> get _anyKey => any.combine3(
  any.intInRange(0, 5),
  any.intInRange(0, 300),
  any.listWithLengthInRange(0, 24, any.intInRange(0, 0x10000)),
  (int mode, int n, List<int> seeds) {
    switch (mode) {
      case 0: // a boundary key
        return _boundaryKeys[n % _boundaryKeys.length];
      case 1: // plain ASCII of any length up to 299
        return _ascii(n, seeds);
      case 2: // lengths 250..260, ASCII only
        return _ascii(250 + n % 11, seeds);
      case 3: // lengths 250..260 with one non-ASCII unit somewhere
        final String base = _ascii(250 + n % 11, seeds);
        final int at = n % base.length;
        final int unit = _nonAsciiUnits[n % _nonAsciiUnits.length];
        return base.replaceRange(at, at + 1, String.fromCharCode(unit));
      case 4: // short strings of arbitrary code units
        return String.fromCharCodes(<int>[
          for (var i = 0; i < n % 6; i++)
            i.isEven && seeds.isNotEmpty
                ? seeds[i % seeds.length]
                : _nonAsciiUnits[(n + i) % _nonAsciiUnits.length],
        ]);
      default: // short ASCII, possibly empty
        return _ascii(n % 4, seeds);
    }
  },
);

/// The rule, written from the requirement text: non-empty, at most 255 code
/// units, every code unit at most 0x7F. Deliberately does not use KeyValidator.
bool _oracle(String key) {
  if (key.isEmpty || key.length > 255) return false;
  for (final int unit in key.codeUnits) {
    if (unit > 0x7F) return false;
  }
  return true;
}

int _runs = 0;

void main() {
  group('KeyValidator property: matches its rule', () {
    // Feature: crypt-storage, Property 3: key validator matches its rule
    // Validates: Requirements 3.1, 3.5, 3.6
    Glados(_anyKey, ExploreConfig(numRuns: _numRuns)).test(
      'isValid equals the rule; check throws a key-free ArgumentError',
      (key) {
        _runs++;
        final bool expected = _oracle(key);
        final String why =
            'key length=${key.length} '
            'units=${key.codeUnits.take(12).toList()}';

        expect(KeyValidator.isValid(key), expected, reason: why);

        if (expected) {
          KeyValidator.check(key); // must not throw
          return;
        }

        Object? thrown;
        try {
          KeyValidator.check(key);
        } catch (e) {
          thrown = e;
        }
        expect(thrown, isA<ArgumentError>(), reason: why);
        final String message = thrown.toString();

        // "The message does not contain the input" is only meaningful when
        // the input could plausibly appear in a message. An empty or 1-2 char
        // input is trivially a substring of any text, so whole-input
        // containment is checked from length 3 up. On top of that:
        //  - every window of 8 units of the input must be absent (random text
        //    never matches 8 units of fixed message wording, so no flakiness),
        //  - the message is plain ASCII, so any non-ASCII unit of the input
        //    must be absent, which also covers short non-ASCII keys.
        if (key.length >= 3) {
          expect(message.contains(key), isFalse, reason: why);
        }
        for (var i = 0; i + 8 <= key.length; i++) {
          expect(
            message.contains(key.substring(i, i + 8)),
            isFalse,
            reason: '$why window at $i',
          );
        }
        for (final int unit in key.codeUnits.where((u) => u > 0x7F)) {
          expect(
            message.contains(String.fromCharCode(unit)),
            isFalse,
            reason: '$why non-ASCII unit $unit leaked',
          );
        }
      },
    );

    test('the property body ran numRuns times', () {
      expect(_runs, _numRuns);
    });
  });
}
