import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Locates `apps/graveyard/lib`, whether the test runs from the app folder
/// or from the repository root.
Directory _libDir() {
  for (final path in const ['lib', 'apps/graveyard/lib']) {
    final dir = Directory(path);
    if (File('${dir.path}/main.dart').existsSync()) return dir;
  }
  throw StateError(
    'Could not find apps/graveyard/lib from ${Directory.current.path}',
  );
}

/// Removes block comments and `//` comments (including doc comments) so that
/// prose mentioning a banned word does not count.
String _stripComments(String source) {
  final noBlocks = source.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  return noBlocks
      .split('\n')
      .map((line) => line.replaceFirst(RegExp(r'(?<!:)//.*$'), ''))
      .join('\n');
}

String _name(File file) => file.uri.pathSegments.last;

/// Dart files under [root] whose code (comments removed) matches [pattern]
/// and which [allowed] does not exempt.
List<String> _offenders(
  Directory root,
  RegExp pattern, {
  bool Function(File file)? allowed,
}) {
  final found = <String>[];
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (allowed != null && allowed(entity)) continue;
    if (pattern.hasMatch(_stripComments(entity.readAsStringSync()))) {
      found.add(entity.path);
    }
  }
  return found;
}

void main() {
  final lib = _libDir();
  final domain = Directory('${lib.path}/src/domain');

  group('domain sources', () {
    const banned = {
      'package:flutter': r'''package:flutter[/'"]''',
      'dart:io': r'''dart:io\b''',
      'dart:html': r'''dart:html\b''',
      'package:http': r'''package:http[/'"]''',
      'package:hive_ce': r'''package:hive_ce[/'"_a-z]''',
    };
    for (final entry in banned.entries) {
      test('no ${entry.key} under lib/src/domain', () {
        final offenders = _offenders(domain, RegExp(entry.value));
        expect(
          offenders,
          isEmpty,
          reason:
              'The domain must stay pure Dart. ${entry.key} found in: '
              '${offenders.join(', ')}',
        );
      });
    }

    test('DateTime.now is read only in system_clock.dart', () {
      final offenders = _offenders(
        lib,
        RegExp(r'\bDateTime\s*\.\s*now\b'),
        allowed: (f) => _name(f) == 'system_clock.dart',
      );
      expect(
        offenders,
        isEmpty,
        reason:
            'DateTime.now may appear only in system_clock.dart. '
            'Found in: ${offenders.join(', ')}',
      );
    });

    test('date-count files do not use Duration', () {
      const files = {
        'calendar_date.dart',
        'dead_for.dart',
        'dead_for_formatter.dart',
      };
      for (final name in files) {
        expect(
          File('${domain.path}/$name').existsSync(),
          isTrue,
          reason: '$name should exist under lib/src/domain',
        );
      }
      final offenders = _offenders(
        domain,
        RegExp(r'\bDuration\b'),
        allowed: (f) => !files.contains(_name(f)),
      );
      expect(
        offenders,
        isEmpty,
        reason:
            'Day counts must use calendar dates, not Duration. '
            'Found in: ${offenders.join(', ')}',
      );
    });

    test('Timer appears only in http_github_client.dart', () {
      final offenders = _offenders(
        lib,
        RegExp(r'\bTimer\b'),
        allowed: (f) => _name(f) == 'http_github_client.dart',
      );
      expect(
        offenders,
        isEmpty,
        reason:
            'Timer may appear only in http_github_client.dart. '
            'Found in: ${offenders.join(', ')}',
      );
    });
  });
}
