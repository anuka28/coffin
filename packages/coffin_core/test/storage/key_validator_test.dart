import 'package:coffin_core/src/storage/key_validator.dart';
import 'package:flutter_test/flutter_test.dart';

String _k(int n) => 'k' * n;

void main() {
  // Boundary key table B1 to B11 with the expected coffin verdict.
  final boundary = <String, ({String key, bool valid})>{
    'B1 empty': (key: '', valid: false),
    'B2 shortest valid': (key: 'a', valid: true),
    'B3 255 units': (key: _k(255), valid: true),
    'B4 256 units': (key: _k(256), valid: false),
    'B5 highest char 0x7F': (key: 'x\u007F', valid: true),
    'B6 lowest char 0x00': (key: '\u0000', valid: true),
    'B7 first invalid char 0x80': (key: 'x\u0080', valid: false),
    'B8 non-BMP': (key: '\u{1F47B}', valid: false),
    'B9 lone surrogate': (key: '\uD800', valid: false),
    'B10 128 x e-acute': (key: 'é' * 128, valid: false),
    'B11 ordinary punctuation': (key: 'a/b..c d', valid: true),
  };

  group('KeyValidator boundary keys', () {
    for (final entry in boundary.entries) {
      final key = entry.value.key;
      final valid = entry.value.valid;
      test('${entry.key} is ${valid ? 'accepted' : 'rejected'}', () {
        expect(KeyValidator.isValid(key), valid);
        expect(KeyValidator.violation(key), valid ? isNull : isNotNull);
        if (valid) {
          expect(() => KeyValidator.check(key), returnsNormally);
        } else {
          expect(() => KeyValidator.check(key), throwsArgumentError);
        }
      });
    }
  });

  group('KeyValidator messages', () {
    test('constants match the design', () {
      expect(KeyValidator.maxLength, 255);
      expect(KeyValidator.maxCodeUnit, 0x7F);
    });

    test('empty key message', () {
      expect(KeyValidator.violation(''), 'must not be empty');
    });

    test('too long message states the length', () {
      expect(
        KeyValidator.violation(_k(256)),
        'longer than 255 code units (was 256)',
      );
    });

    test('bad character message states the index', () {
      expect(
        KeyValidator.violation('abc\u0080'),
        'contains a code unit above 0x7F at index 3',
      );
    });

    test('error messages never contain the key text', () {
      final longKey = _k(256);
      final badChar = 'abc\u00E9def';
      final longError = _thrown(longKey);
      final charError = _thrown(badChar);
      expect(longError.toString(), isNot(contains('kkkkkkkk')));
      expect(longError.toString(), contains('256'));
      expect(charError.toString(), isNot(contains('\u00E9')));
      expect(charError.toString(), isNot(contains('abc')));
      expect(charError.toString(), contains('index 3'));
    });
  });
}

ArgumentError _thrown(String key) {
  try {
    KeyValidator.check(key);
  } on ArgumentError catch (e) {
    return e;
  }
  throw StateError('expected ArgumentError');
}
