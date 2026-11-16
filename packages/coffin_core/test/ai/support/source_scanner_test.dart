import 'package:flutter_test/flutter_test.dart';

import 'source_scanner.dart';

void main() {
  group('seedless Random', () {
    test('flags Random()', () {
      expect(findSeedlessRandom('final r = Random();'), hasLength(1));
      expect(findSeedlessRandom('final r = Random( );'), hasLength(1));
    });

    test('flags Random.secure()', () {
      expect(findSeedlessRandom('final r = Random.secure();'), hasLength(1));
    });

    test('does not flag SeededRandom', () {
      expect(findSeedlessRandom('SeededRandom(seed)'), isEmpty);
      expect(findSeedlessRandom('class SeededRandom {'), isEmpty);
      expect(findSeedlessRandom('final r = SeededRandom();'), isEmpty);
      expect(findSeedlessRandom('final r = _Random();'), isEmpty);
    });

    test('Random(seed) is left to the dart:math rule', () {
      expect(findSeedlessRandom('Random(7)'), isEmpty);
      expect(findForbiddenWords("import 'dart:math';"), hasLength(1));
    });
  });

  group('forbidden words', () {
    test('each word is found in lower, upper and mixed case', () {
      for (final String word in forbiddenWords) {
        final String upper = word.toUpperCase();
        final String lower = word.toLowerCase();
        for (final String variant in <String>[word, upper, lower]) {
          final List<ScanViolation> found = findForbiddenWords('x $variant y');
          expect(found, isNotEmpty, reason: variant);
        }
      }
    });

    test('are found inside comments (raw text)', () {
      expect(findForbiddenWords('// see https://x.dev'), isNotEmpty);
      expect(findForbiddenWords('/// uses DateTime.now here'), isNotEmpty);
    });

    test('reports the 1-based line', () {
      final List<ScanViolation> found = findForbiddenWords('a\nb\nBearer\n');
      expect(found.single.line, 3);
      expect(found.single.rule, 'bearer');
    });

    test('a comment saying "Flutter Web" is not flagged', () {
      expect(findForbiddenWords('/// Safe on Flutter Web.'), isEmpty);
      expect(findForbiddenWords('// flutter web, no 64-bit math'), isEmpty);
    });

    test('a package:flutter import is flagged', () {
      expect(
        findForbiddenWords("import 'package:flutter/material.dart';"),
        hasLength(1),
      );
    });

    test('clean code has no violation', () {
      expect(
        findForbiddenWords("import 'package:meta/meta.dart';\nclass A {}"),
        isEmpty,
      );
    });
  });

  group('.hashCode', () {
    test('member access is found', () {
      expect(findHashCode('final h = name.hashCode;'), hasLength(1));
      expect(findHashCode('super.hashCode'), hasLength(1));
    });

    test('declaration and other names are not member access', () {
      expect(findHashCode('int get hashCode => 1;'), isEmpty);
      expect(findHashCode('x.hashCodes'), isEmpty);
    });
  });

  group('countPublicClasses', () {
    test('typedef-only file counts zero', () {
      const String src = '''
/// A factory.
typedef AiTimerFactory = Timer Function(Duration d, void Function() f);
''';
      expect(countPublicClasses(src), 0);
    });

    test('two public classes count two', () {
      const String src = '''
class A {}
final class B {}
''';
      expect(countPublicClasses(src), 2);
    });

    test('private names, comments, strings and extensions are ignored', () {
      const String src = '''
// class Commented {}
/* class Block {} */
class _Private {}
extension Ext on int {}
const s = """
class InString {}
""";
final class Public {}
''';
      expect(publicTypeNames(src), <String>['Public']);
    });

    test('every declaration form is counted', () {
      const String src = '''
class A {}
final class B {}
abstract class C {}
abstract interface class D {}
interface class E {}
sealed class F {}
base class G {}
mixin class H {}
enum I { a }
mixin J {}
extension type K(int v) {}
extension type const L(int v) {}
@immutable
final class M {}
''';
      expect(publicTypeNames(src), <String>[
        'A',
        'B',
        'C',
        'D',
        'E',
        'F',
        'G',
        'H',
        'I',
        'J',
        'K',
        'L',
        'M',
      ]);
    });
  });

  group('parseBarrelExports', () {
    test('parses multi-line show lists, hide and plain exports', () {
      const String src = '''
// export 'src/ai/commented.dart' show Nope;
export 'package:go_router/go_router.dart'
    show GoRouter,
        GoRoute;
export 'src/ai/ai_issue_reporter.dart' show AiIssueReporter, discardAiIssues;
export 'src/a.dart' hide Secret;
export "src/b.dart";
''';
      final List<BarrelExport> exports = parseBarrelExports(src);
      expect(exports.map((BarrelExport e) => e.uri), <String>[
        'package:go_router/go_router.dart',
        'src/ai/ai_issue_reporter.dart',
        'src/a.dart',
        'src/b.dart',
      ]);
      expect(exports[0].shown, <String>['GoRouter', 'GoRoute']);
      expect(exports[1].shown, <String>['AiIssueReporter', 'discardAiIssues']);
      expect(exports[2].hidden, <String>['Secret']);
      expect(exports[2].shown, isNull);
      expect(exports[3].shown, isNull);
      expect(exports[3].hidden, isNull);
    });
  });
}
