import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source rules for the pure voice domain files.

const _voiceFiles = [
  'voice_trigger.dart',
  'voice_snapshot.dart',
  'voice_policy.dart',
  'voice_seed.dart',
];

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

/// Removes block and line comments.
String _stripComments(String source) {
  return source
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'//[^\n]*'), '');
}

/// Removes comments, then the content of single and double quoted strings.
String _stripCommentsAndStrings(String source) {
  return _stripComments(source)
      .replaceAll(RegExp(r"'(?:\\.|[^'\\\n])*'"), "''")
      .replaceAll(RegExp(r'"(?:\\.|[^"\\\n])*"'), '""');
}

final _forbiddenImport = RegExp(
  r'''^\s*(?:import|export)\s+['"](?:package:coffin_core|package:flutter|dart:ui)''',
  multiLine: true,
);

final _bitOperator = RegExp(r'<<|>>|&|\||\^|~');

final _publicType = RegExp(
  r'^(?:(?:abstract|base|final|sealed|interface|mixin)\s+)*'
  r'(?:class|enum|mixin|extension\s+type)\s+([A-Za-z]\w*)',
  multiLine: true,
);

/// Whether [source] imports or exports a forbidden library.
bool _hasForbiddenDirective(String source) =>
    _forbiddenImport.hasMatch(_stripComments(source));

/// Whether [source] uses a bitwise operator in code.
bool _hasBitOperator(String source) =>
    _bitOperator.hasMatch(_stripCommentsAndStrings(source));

/// Names of the public top-level types declared in [source].
List<String> _publicTypes(String source) => [
  for (final m in _publicType.allMatches(_stripComments(source)))
    if (!m.group(1)!.startsWith('_')) m.group(1)!,
];

void main() {
  final domainDir = Directory('${_appRoot().path}/lib/src/domain');

  group('voice domain sources', () {
    test('no domain file imports coffin_core, flutter or dart:ui', () {
      final files = domainDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      expect(files, isNotEmpty);
      final offenders = [
        for (final f in files)
          if (_hasForbiddenDirective(f.readAsStringSync())) f.path,
      ];
      expect(offenders, isEmpty);
    });

    test('voice_seed.dart uses no bitwise operator', () {
      final source = File('${domainDir.path}/voice_seed.dart');
      expect(source.existsSync(), isTrue);
      expect(_hasBitOperator(source.readAsStringSync()), isFalse);
    });

    test('voice files exist and declare at most one public type', () {
      for (final name in _voiceFiles) {
        final file = File('${domainDir.path}/$name');
        expect(file.existsSync(), isTrue, reason: '$name must exist');
        final types = _publicTypes(file.readAsStringSync());
        expect(types.length, lessThanOrEqualTo(1), reason: '$name: $types');
      }
    });
  });

  group('self-checks', () {
    test('directive rule flags bad samples and spares good ones', () {
      expect(
        _hasForbiddenDirective(
          "import 'package:coffin_core/coffin_core.dart';",
        ),
        isTrue,
      );
      expect(
        _hasForbiddenDirective("export 'package:flutter/material.dart';"),
        isTrue,
      );
      expect(_hasForbiddenDirective("import 'dart:ui';"), isTrue);
      expect(_hasForbiddenDirective("import 'clock.dart';"), isFalse);
      expect(
        _hasForbiddenDirective("// import 'package:flutter/widgets.dart';"),
        isFalse,
      );
    });

    test('operator rule flags bad samples and spares good ones', () {
      for (final bad in [
        'final a = b << 2;',
        'final a = b >> 2;',
        'final a = b >>> 2;',
        'final a = b & c;',
        'final a = b | c;',
        'final a = b ^ c;',
        'final a = ~b;',
      ]) {
        expect(_hasBitOperator(bad), isTrue, reason: bad);
      }
      expect(_hasBitOperator('final a = (b * 3 + c) % 7;'), isFalse);
      expect(_hasBitOperator('// a << b & c'), isFalse);
      expect(_hasBitOperator("final s = 'a | b ^ ~ &';"), isFalse);
      expect(_hasBitOperator('final s = "<< >>";'), isFalse);
    });

    test('type rule flags two public types and spares one', () {
      expect(_publicTypes('class A {}\nenum B { x }'), ['A', 'B']);
      expect(_publicTypes('abstract final class A {}\nclass _B {}'), ['A']);
      expect(_publicTypes('// class A {}\nenum E { x }'), ['E']);
      expect(_publicTypes('const x = 1;'), isEmpty);
    });
  });
}
