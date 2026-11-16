import 'package:coffin_core/src/ai/identifier_rules.dart';
import 'package:flutter_test/flutter_test.dart';

String? check(String id, [int max = 64]) =>
    IdentifierRules.violation(id, maxLength: max);

void main() {
  group('IdentifierRules.violation', () {
    test('accepts valid identifiers', () {
      for (final String id in <String>[
        'a',
        'ghost_mood_line',
        'x9',
        'a_',
        'seance_verdict',
        'a' * 64,
      ]) {
        expect(check(id), isNull, reason: id);
      }
    });

    test('rejects the empty string with a length', () {
      expect(check(''), contains('length 0'));
    });

    test('enforces the length cap per call', () {
      expect(check('a' * 64), isNull);
      expect(check('a' * 65), contains('length 65'));
      expect(check('a' * 32, 32), isNull);
      expect(check('a' * 33, 32), contains('length 33'));
    });

    test('rejects a bad first character with index 0', () {
      for (final String id in <String>['9ghost', '_ghost', 'Ghost', ' ghost']) {
        expect(check(id), contains('index 0'), reason: id);
      }
    });

    test('rejects bad later characters with their index', () {
      expect(check('ghost mood'), contains('index 5'));
      expect(check('ghost-mood'), contains('index 5'));
      expect(check('ghosT'), contains('index 4'));
      expect(check('caf\u00e9'), contains('index 3'));
      expect(check('s\u00e9ance verdict'), contains('index 1'));
      expect(check('a\ud83d\udc7b'), contains('index 1'));
    });

    test('rejects the display text "séance verdict"', () {
      expect(check('séance verdict'), isNotNull);
    });

    test('the message never contains the rejected text', () {
      for (final String id in <String>[
        'Zq Wx-Yy',
        'séance verdict',
        'Hello\u00e9Wxyz',
        '\u00e9clair',
        'A' * 70,
      ]) {
        expect(check(id)!.contains(id), isFalse, reason: id);
      }
    });
  });
}
