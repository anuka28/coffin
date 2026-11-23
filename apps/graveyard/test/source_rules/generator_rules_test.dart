import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Locates `apps/graveyard/test`, whether the test runs from the app folder
/// or from the repository root.
Directory _testDir() {
  for (final path in const ['test', 'apps/graveyard/test']) {
    final dir = Directory(path);
    if (File('${dir.path}/source_rules/generator_rules_test.dart')
        .existsSync()) {
      return dir;
    }
  }
  throw StateError(
    'Could not find apps/graveyard/test from ${Directory.current.path}',
  );
}

List<File> _dartFiles(Directory root) => [
  for (final entity in root.listSync(recursive: true))
    if (entity is File && entity.path.endsWith('.dart')) entity,
];

/// Paths of files under [root] whose text (comments included) matches
/// [pattern]. The `source_rules` folder is skipped because those tests
/// describe the forbidden patterns.
List<String> _matching(Directory root, RegExp pattern) => [
  for (final file in _dartFiles(root))
    if (!file.path.contains('source_rules') &&
        pattern.hasMatch(file.readAsStringSync()))
      file.path,
];

void main() {
  final testDir = _testDir();

  // The patterns are built from pieces so this file never matches itself.
  const any = 'any';
  final forbiddenGenerators = RegExp(
    '\\b$any\\.(int|intInRange|list|listWithLengthInRange|uint\\w*|'
    'letter\\w*|lowercaseLetter\\w*|uppercaseLetter\\w*|digit\\w*|'
    'nonEmpty\\w*|string\\w*|utf\\w*)\\b',
  );
  final dartIo = RegExp(
    'dart:'
    'io\\b',
  );

  test('no web-unsafe or string generators appear under test/', () {
    expect(_matching(testDir, forbiddenGenerators), isEmpty);
  });

  test('no file under test/domain or test/data uses dart:io', () {
    final offenders = [
      ..._matching(Directory('${testDir.path}/domain'), dartIo),
      ..._matching(Directory('${testDir.path}/data'), dartIo),
    ];
    expect(offenders, isEmpty);
  });
}
