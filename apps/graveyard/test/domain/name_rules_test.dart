import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/name_rules.dart';

void main() {
  group('maxLength', () {
    test('is 80', () => expect(NameRules.maxLength, 80));
  });

  group('normalize', () {
    test('trims the ends', () {
      expect(NameRules.normalize('  hello  '), 'hello');
    });

    test('collapses spaces, tabs and newlines to one space', () {
      expect(NameRules.normalize('a  b\t\tc\n\nd \t\n e'), 'a b c d e');
    });

    test('is idempotent', () {
      for (final raw in ['  a \t b\n', 'plain', '', '   ', 'x\n\ny']) {
        final once = NameRules.normalize(raw);
        expect(NameRules.normalize(once), once);
      }
    });
  });

  group('length', () {
    test('counts ASCII characters', () {
      expect(NameRules.length('abc'), 3);
    });

    test('counts emoji as one code point each', () {
      expect(NameRules.length('👻🎃'), 2);
    });

    test('counts CJK characters as one code point each', () {
      expect(NameRules.length('幽霊墓地'), 4);
    });
  });

  group('keyOf', () {
    test('lower-cases', () {
      expect(NameRules.keyOf('MyProject'), 'myproject');
    });

    test('ignores whitespace differences', () {
      expect(
        NameRules.keyOf('  My \t Project\n'),
        NameRules.keyOf('my project'),
      );
      expect(NameRules.keyOf('My   Project'), 'my project');
    });
  });

  group('forRepo', () {
    test('returns normalized name at exactly 80 code points', () {
      final name = 'o/${'a' * 78}';
      expect(NameRules.length(name), 80);
      expect(NameRules.forRepo(name), name);
    });

    test('normalizes before measuring', () {
      expect(NameRules.forRepo('  owner/repo  '), 'owner/repo');
    });

    test('81 code points with slash keeps 79 code points of repo segment', () {
      // An empty owner is the only way a 81-point name has an 80-point segment.
      final repo = '${'r' * 79}X';
      final name = '/$repo';
      expect(NameRules.length(name), 81);
      final result = NameRules.forRepo(name);
      expect(result, '${'r' * 79}…');
      expect(NameRules.length(result), 80);
    });

    test('81 code points with slash and short repo keeps whole segment', () {
      final name = '${'o' * 70}/repo-names';
      expect(NameRules.length(name), 81);
      expect(NameRules.forRepo(name), 'repo-names…');
    });

    test('81 code points without slash keeps first 79 of whole text', () {
      final name = 'b' * 81;
      expect(NameRules.forRepo(name), '${'b' * 79}…');
    });

    test('counts code points, not UTF-16 units, when truncating', () {
      final name = '👻' * 81;
      final result = NameRules.forRepo(name);
      expect(result, '${'👻' * 79}…');
      expect(NameRules.length(result), 80);
    });
  });
}
