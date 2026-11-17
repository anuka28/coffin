import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/name_rules.dart';

void main() {
  test('maxLength is 40', () {
    expect(NameRules.maxLength, 40);
  });

  group('violation', () {
    test('accepts ordinary names', () {
      expect(NameRules.violation('Drink water'), isNull);
    });

    test('rejects empty and whitespace-only text', () {
      expect(NameRules.violation(''), isNotNull);
      expect(NameRules.violation('   '), isNotNull);
      expect(NameRules.violation(' \t\n '), isNotNull);
    });

    test('trims before counting', () {
      expect(NameRules.violation('  a  '), isNull);
      expect(NameRules.violation('  ${'a' * 40}  '), isNull);
      expect(NameRules.violation('  ${'a' * 41}  '), isNotNull);
    });

    test('1 and 40 characters are valid, 41 is invalid', () {
      expect(NameRules.violation('a'), isNull);
      expect(NameRules.violation('a' * 40), isNull);
      expect(NameRules.violation('a' * 41), isNotNull);
    });

    test('counts an emoji as one character', () {
      expect('👻'.length, 2);
      expect(NameRules.violation('👻'), isNull);
      expect(NameRules.violation('👻' * 40), isNull);
      expect(NameRules.violation('👻' * 41), isNotNull);
      expect(NameRules.violation('${'a' * 39}👻'), isNull);
      expect(NameRules.violation('${'a' * 40}👻'), isNotNull);
    });
  });

  group('normalize', () {
    test('removes surrounding whitespace only', () {
      expect(NameRules.normalize('  Drink water \n'), 'Drink water');
      expect(NameRules.normalize('a  b'), 'a  b');
    });

    test('leaves clean text and emoji unchanged', () {
      expect(NameRules.normalize('Stretch'), 'Stretch');
      expect(NameRules.normalize(' 👻 '), '👻');
    });

    test('whitespace-only becomes empty', () {
      expect(NameRules.normalize('   '), '');
    });
  });
}
