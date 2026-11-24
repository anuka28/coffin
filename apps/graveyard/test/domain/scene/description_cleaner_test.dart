import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/scene/description_cleaner.dart';

void main() {
  group('DescriptionCleaner.clean', () {
    test('leaves colon-bearing non-shortcodes unchanged', () {
      for (final text in [
        '10:30 to 11:45',
        '10:30:45',
        'localhost:8080',
        'a:b:c',
      ]) {
        expect(DescriptionCleaner.clean(text), text);
      }
    });

    test('removes a leading shortcode', () {
      expect(
        DescriptionCleaner.clean(':atom: The hackable text editor'),
        'The hackable text editor',
      );
    });

    test('removes a mid-text shortcode', () {
      expect(DescriptionCleaner.clean('Fast :rocket: builds'), 'Fast builds');
    });

    test('keeps names without an ASCII letter', () {
      expect(DescriptionCleaner.clean(':+1:'), ':+1:');
      expect(DescriptionCleaner.clean(':100:'), ':100:');
    });

    test('removes a 40-character name and keeps a 41-character name', () {
      final name40 = 'a' * 40;
      final name41 = 'a' * 41;
      expect(DescriptionCleaner.clean('x :$name40: y'), 'x y');
      expect(DescriptionCleaner.clean('x :$name41: y'), 'x :$name41: y');
    });

    test('removes names with underscores', () {
      expect(DescriptionCleaner.clean(':white_check_mark:'), '');
    });

    test('keeps an unterminated colon', () {
      expect(DescriptionCleaner.clean(':atom'), ':atom');
      expect(
        DescriptionCleaner.clean('hello :atom world'),
        'hello :atom world',
      );
    });

    test('handles empty and whitespace-only strings', () {
      expect(DescriptionCleaner.clean(''), '');
      expect(DescriptionCleaner.clean(' \t\n  '), '');
    });

    test('keeps Unicode emoji', () {
      expect(DescriptionCleaner.clean('Spooky 👻 app'), 'Spooky 👻 app');
    });

    test('does not throw on a lone surrogate', () {
      final lone = String.fromCharCode(0xD800);
      expect(() => DescriptionCleaner.clean('a $lone b'), returnsNormally);
      expect(() => DescriptionCleaner.clean(lone), returnsNormally);
    });
  });
}
