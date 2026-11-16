import 'package:coffin_core/src/ai/text_rules.dart';
import 'package:flutter_test/flutter_test.dart';

const String _ghost = '\u{1F47B}';

bool _hasLoneSurrogate(String s) {
  for (var i = 0; i < s.length; i++) {
    final u = s.codeUnitAt(i);
    if (u >= 0xD800 && u <= 0xDBFF) {
      if (i + 1 < s.length &&
          s.codeUnitAt(i + 1) >= 0xDC00 &&
          s.codeUnitAt(i + 1) <= 0xDFFF) {
        i++;
        continue;
      }
      return true;
    }
    if (u >= 0xDC00 && u <= 0xDFFF) return true;
  }
  return false;
}

void main() {
  group('word lists', () {
    test('banned words are the 20 verbatim words', () {
      expect(TextRules.bannedWords, hasLength(20));
      expect(TextRules.bannedWords, <String>[
        'gore',
        'blood',
        'kill',
        'murder',
        'slaughter',
        'mutilat',
        'dismember',
        'decapitat',
        'behead',
        'entrails',
        'viscera',
        'massacre',
        'torture',
        'stabbing',
        'stabbed',
        'severed',
        'bludgeon',
        'strangle',
        'disembowel',
        'maim',
      ]);
    });

    test('insult words are the 13 verbatim words', () {
      expect(TextRules.insultWords, hasLength(13));
      expect(TextRules.insultWords, <String>[
        'stupid',
        'idiot',
        'lazy',
        'loser',
        'useless',
        'worthless',
        'pathetic',
        'dumb',
        'failure',
        'hopeless',
        'incompetent',
        'pitiful',
        'ugly',
      ]);
    });

    test('constants', () {
      expect(TextRules.maxNameLength, 24);
      expect(TextRules.ellipsis, '\u2026');
      expect(TextRules.ellipsis.length, 1);
    });
  });

  group('asciiLower', () {
    test('folds A to Z only', () {
      expect(TextRules.asciiLower('ABCxyz XYZ 09'), 'abcxyz xyz 09');
    });

    test('leaves the Kelvin sign and accents unchanged', () {
      const text = '\u212A \u00C9\u00E9 \u0130';
      expect(TextRules.asciiLower(text), text);
    });
  });

  group('whitespace', () {
    final units = <int>[
      for (var u = 0x09; u <= 0x0D; u++) u,
      0x20,
      0x85,
      0xA0,
      0x1680,
      for (var u = 0x2000; u <= 0x200A; u++) u,
      0x2028,
      0x2029,
      0x202F,
      0x205F,
      0x3000,
      0xFEFF,
    ];

    test('every unit of the set is whitespace and blank', () {
      for (final u in units) {
        expect(TextRules.isWhitespaceUnit(u), isTrue, reason: 'U+$u');
        expect(TextRules.isBlank(String.fromCharCode(u)), isTrue);
      }
      expect(TextRules.isBlank(String.fromCharCodes(units)), isTrue);
    });

    test('neighbours of the set are not whitespace', () {
      for (final u in <int>[
        0x08,
        0x0E,
        0x1F,
        0x21,
        0x84,
        0x86,
        0x200B,
        0x180E,
      ]) {
        expect(TextRules.isWhitespaceUnit(u), isFalse, reason: 'U+$u');
      }
    });

    test('empty is blank and text is not', () {
      expect(TextRules.isBlank(''), isTrue);
      expect(TextRules.isBlank('  a '), isFalse);
    });
  });

  group('containsBanned', () {
    test('matches substrings of the folded text', () {
      expect(TextRules.containsBanned('BLOODhound'), isTrue);
      expect(TextRules.containsBanned('skillful'), isTrue);
      expect(TextRules.containsBanned('Gore'), isTrue);
    });

    test('ordinary words do not hit', () {
      for (final w in <String>[
        'category',
        'stable',
        'august',
        'gorgeous',
        'claim',
      ]) {
        expect(TextRules.containsBanned(w), isFalse, reason: w);
      }
    });

    test('the Kelvin sign does not fold into a hit', () {
      expect(TextRules.containsBanned('\u212Aill'), isFalse);
    });
  });

  group('cleanName', () {
    test('collapses whitespace and drops controls', () {
      expect(TextRules.cleanName('a\u0000  b\n'), 'a b');
    });

    test('14 ghost emoji give 12', () {
      final cleaned = TextRules.cleanName(_ghost * 14);
      expect(cleaned, _ghost * 12);
      expect(cleaned.length, 24);
    });

    test('a lone surrogate is dropped', () {
      expect(TextRules.cleanName('a\uD83Db'), 'ab');
      expect(TextRules.cleanName('a\uDC7Bb'), 'ab');
      expect(TextRules.cleanName('ab\uD83D'), 'ab');
    });

    test('whitespace only gives an empty string', () {
      expect(TextRules.cleanName(' \t\n\u00A0\u3000'), '');
      expect(TextRules.cleanName(''), '');
    });

    test('a cut on a high surrogate backs off one unit', () {
      final cleaned = TextRules.cleanName('${'a' * 23}$_ghost');
      expect(cleaned, 'a' * 23);
      expect(_hasLoneSurrogate(cleaned), isFalse);
    });

    test('trailing space left by the cut is removed', () {
      final cleaned = TextRules.cleanName('${'a' * 23} bcd');
      expect(cleaned, 'a' * 23);
    });

    test('is idempotent on a messy input', () {
      final once = TextRules.cleanName(
        '  \u0001x\uD83D  y$_ghost\t${'z' * 30}',
      );
      expect(TextRules.cleanName(once), once);
    });
  });

  group('truncate', () {
    test('48-unit text at 16 gives 16 units ending with an ellipsis', () {
      const text = 'This is a rather long ghost line for the audits.';
      expect(text.length, 48);
      final result = TextRules.truncate(text, 16);
      expect(result, 'This is a rathe\u2026');
      expect(result.length, 16);
    });

    test('two emoji at the cut give 15 units', () {
      final text = 'abcdefghijklmn$_ghost${_ghost}opq';
      final result = TextRules.truncate(text, 16);
      expect(result, 'abcdefghijklmn\u2026');
      expect(result.length, 15);
      expect(_hasLoneSurrogate(result), isFalse);
    });

    test('trailing whitespace before the ellipsis is dropped', () {
      expect(
        TextRules.truncate('abcdefghijklm   nopqrstu', 16),
        'abcdefghijklm\u2026',
      );
    });

    test('text that fits stays unchanged', () {
      expect(TextRules.truncate('short text here!', 16), 'short text here!');
      expect(TextRules.truncate('abc', 16), 'abc');
    });
  });
}
