import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-rule test for glados generators (Requirement 14.8).
///
/// glados 1.1.7 computes `1 << 32` inside some generators, which is 0 on web.
/// Tests use the web-safe helpers in `test/domain/support/haunt_generators.dart`
/// instead. This folder is the only place that reads source files with
/// `dart:io`.

/// Matches a banned `any.<name>` generator in code.
///
/// The trailing `\b` keeps helpers such as `anyIntBetween` and `any.simple`
/// from matching, while `intInRange` and `listWithLengthInRange` are listed.
final RegExp _banned = RegExp(
  r'\bany\s*\.\s*('
  r'int|intInRange|list|listWithLengthInRange|'
  r'letter|lowercaseLetter|uppercaseLetter|letterOrDigit|digit|'
  r'letters|lowercaseLetters|uppercaseLetters|lettersOrDigits|'
  r'nonEmptyLetters|nonEmptyLowercaseLetters|nonEmptyUppercaseLetters|'
  r'nonEmptyLetterOrDigits|nonEmptyLettersOrDigits|'
  r'uint|uint8|uint16|uint32|uint64'
  r')\b',
);

/// Finds the app root whether tests run from the app or the repo root.
Directory _appRoot() {
  var dir = Directory.current.absolute;
  for (var i = 0; i < 6; i++) {
    if (File('${dir.path}/lib/src/domain/clock.dart').existsSync()) {
      return dir;
    }
    final nested = Directory('${dir.path}/apps/hauntagotchi');
    if (nested.existsSync()) {
      dir = nested;
      continue;
    }
    dir = dir.parent;
  }
  throw StateError('Cannot locate apps/hauntagotchi from ${Directory.current}');
}

/// Replaces comments with blanks, keeping line breaks so line numbers hold.
String _stripComments(String source) {
  return source
      .replaceAllMapped(
        RegExp(r'/\*[\s\S]*?\*/'),
        (m) => m[0]!.replaceAll(RegExp(r'[^\n]'), ' '),
      )
      .replaceAll(RegExp(r'//[^\n]*'), '');
}

/// Returns `line: text` for each line of [source] that uses a banned
/// generator outside comments.
List<String> findBannedGenerators(String source) {
  final lines = _stripComments(source).split('\n');
  return [
    for (var i = 0; i < lines.length; i++)
      if (_banned.hasMatch(lines[i])) '${i + 1}: ${lines[i].trim()}',
  ];
}

void main() {
  group('scanner', () {
    test('flags every banned generator', () {
      const samples = [
        'any.int',
        'any.intInRange(0, 5)',
        'any.list(any.simple)',
        'any.listWithLengthInRange(0, 3, any.simple)',
        'any.letter',
        'any.lowercaseLetter',
        'any.uppercaseLetter',
        'any.letterOrDigit',
        'any.nonEmptyLetterOrDigits',
        'any.letters',
        'any.uint',
        'any.uint8',
        'any.uint16',
        'any.uint32',
        'any.uint64',
      ];
      for (final sample in samples) {
        expect(findBannedGenerators(sample), hasLength(1), reason: sample);
      }
    });

    test('ignores web-safe helpers and comments', () {
      expect(findBannedGenerators('anyIntBetween(0, 5)'), isEmpty);
      expect(findBannedGenerators('any.simple'), isEmpty);
      expect(findBannedGenerators('any.intBetween'), isEmpty);
      expect(findBannedGenerators('// any.int'), isEmpty);
      expect(findBannedGenerators('/// use any.list\nfinal a = 1;'), isEmpty);
    });

    test('reports the line number', () {
      expect(findBannedGenerators('a\n/* x\ny */\nfinal g = any.int;'), [
        '4: final g = any.int;',
      ]);
    });
  });

  group('test tree', () {
    test('uses no banned glados generators', () {
      final root = _appRoot();
      final testDir = Directory('${root.path}/test');
      final offenders = <String>[];
      var scanned = 0;
      for (final entity in testDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('source_rules/generator_rules_test.dart')) {
          continue;
        }
        scanned++;
        final rel = entity.path.substring(root.path.length + 1);
        for (final hit in findBannedGenerators(entity.readAsStringSync())) {
          offenders.add('$rel:$hit');
        }
      }
      expect(scanned, greaterThan(0), reason: 'no Dart files scanned');
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });
}
