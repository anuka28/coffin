import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-rule tests for Hauntagotchi.
///
/// This folder is the only place that reads source files with `dart:io`.

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

/// Removes block and line comments so prose cannot cause false positives.
String _stripComments(String source) {
  return source
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'//[^\n]*'), '');
}

/// Dart files under [relative] (relative to the app root) with comments
/// stripped, keyed by their path relative to the app root.
Map<String, String> _sources(String relative) {
  final root = _appRoot();
  final dir = Directory('${root.path}/$relative');
  if (!dir.existsSync()) throw StateError('$relative must exist');
  final result = <String, String>{};
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final rel = entity.path.substring(root.path.length + 1);
      result[rel] = _stripComments(entity.readAsStringSync());
    }
  }
  if (result.isEmpty) throw StateError('$relative has no Dart files');
  return result;
}

/// Paths of files in [sources] whose code matches [pattern].
List<String> _offenders(Map<String, String> sources, RegExp pattern) => [
  for (final entry in sources.entries)
    if (pattern.hasMatch(entry.value)) entry.key,
];

void main() {
  final flutterImport = RegExp('package:flutter');
  final dartIo = RegExp('dart:io');
  final dateTimeNow = RegExp(r'\bDateTime\s*\.\s*now\b');
  final timer = RegExp(r'\bTimer\b');
  final coreSrc = RegExp(r'coffin_core/src');
  final graveyard = RegExp('graveyard');

  group('domain sources', () {
    final domain = _sources('lib/src/domain');

    test('import no package:flutter', () {
      expect(_offenders(domain, flutterImport), isEmpty);
    });

    test('import no dart:io', () {
      expect(_offenders(domain, dartIo), isEmpty);
    });

    test('never call DateTime.now', () {
      expect(_offenders(domain, dateTimeNow), isEmpty);
    });
  });

  group('lib sources', () {
    final lib = _sources('lib');

    test('call DateTime.now only in data/system_clock.dart', () {
      expect(
        _offenders(lib, dateTimeNow),
        everyElement(equals('lib/src/data/system_clock.dart')),
      );
    });

    test('use no Timer or Timer.periodic', () {
      expect(_offenders(lib, timer), isEmpty);
    });

    test('import no coffin_core/src', () {
      expect(_offenders(lib, coreSrc), isEmpty);
    });

    test('mention no Graveyard import', () {
      expect(_offenders(lib, graveyard), isEmpty);
    });

    test('import no dart:io', () {
      expect(_offenders(lib, dartIo), isEmpty);
    });
  });

  group('test tree', () {
    test('test/domain has no dart:io', () {
      expect(_offenders(_sources('test/domain'), dartIo), isEmpty);
    });

    test('test/data has no dart:io', () {
      expect(_offenders(_sources('test/data'), dartIo), isEmpty);
    });
  });
}
