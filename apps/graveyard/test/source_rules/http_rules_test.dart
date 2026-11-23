import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _clientFile = 'http_github_client.dart';

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

/// Removes block comments and `//` comments (including doc comments).
String _stripComments(String source) {
  final noBlocks = source.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  return noBlocks
      .split('\n')
      .map((line) => line.replaceFirst(RegExp(r'(?<!:)//.*$'), ''))
      .join('\n');
}

String _name(File file) => file.uri.pathSegments.last;

List<File> _dartFiles(Directory root) => [
  for (final entity in root.listSync(recursive: true))
    if (entity is File && entity.path.endsWith('.dart')) entity,
];

/// Paths of files under [root] whose text matches [pattern].
///
/// Comments are kept unless [code] is true.
List<String> _matching(
  Directory root,
  RegExp pattern, {
  bool code = false,
  bool Function(File file)? allowed,
}) {
  final found = <String>[];
  for (final file in _dartFiles(root)) {
    if (allowed != null && allowed(file)) continue;
    final text = file.readAsStringSync();
    if (pattern.hasMatch(code ? _stripComments(text) : text)) {
      found.add(file.path);
    }
  }
  return found;
}

void main() {
  final lib = _libDir();

  group('http and secrets source rules', () {
    test('package:http is imported only by $_clientFile', () {
      final offenders = _matching(
        lib,
        RegExp(r'''package:http[/'"]'''),
        code: true,
        allowed: (f) => _name(f) == _clientFile,
      );
      expect(
        offenders,
        isEmpty,
        reason:
            'Only $_clientFile may import package:http. '
            'Found in: ${offenders.join(', ')}',
      );
      expect(
        File('${lib.path}/src/data/$_clientFile').readAsStringSync(),
        contains('package:http/http.dart'),
        reason: '$_clientFile should import package:http',
      );
    });

    test('no Authorization anywhere in lib', () {
      final offenders = _matching(
        lib,
        RegExp('authorization', caseSensitive: false),
      );
      expect(
        offenders,
        isEmpty,
        reason:
            'The app sends no credential. Found in: ${offenders.join(', ')}',
      );
    });

    test('api.github.com appears once in lib, in $_clientFile', () {
      final pattern = RegExp(r'api\.github\.com');
      final hits = <String, int>{};
      for (final file in _dartFiles(lib)) {
        final count = pattern
            .allMatches(_stripComments(file.readAsStringSync()))
            .length;
        if (count > 0) hits[_name(file)] = count;
      }
      expect(hits, {
        _clientFile: 1,
      }, reason: 'api.github.com must appear exactly once, in $_clientFile');
    });

    test('no ghp_, github_pat_ or token in lib', () {
      // `token` is matched as a standalone word (any case). The theme type
      // `CoffinColorTokens` and variables named `tokens` are design tokens,
      // not secrets, so letters on either side of the word exempt a match.
      final patterns = {
        'ghp_': RegExp('ghp_', caseSensitive: false),
        'github_pat_': RegExp('github_pat_', caseSensitive: false),
        'token': RegExp('(?<![A-Za-z])token(?![A-Za-z])', caseSensitive: false),
      };
      for (final entry in patterns.entries) {
        final offenders = _matching(lib, entry.value);
        expect(
          offenders,
          isEmpty,
          reason:
              '${entry.key} must not appear in lib. '
              'Found in: ${offenders.join(', ')}',
        );
      }
    });
  });
}
