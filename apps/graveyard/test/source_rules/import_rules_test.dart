// Source rules for imports and dependencies.
// Validates: Requirements 15.1, 15.3, 15.6, 17.11
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Matches the URI of an `import`, `export` or `part` directive that starts
/// a line.
final RegExp _directive = RegExp(
  r'''^\s*(?:import|export|part)\s+(?:'([^']*)'|"([^"]*)")''',
  multiLine: true,
);

/// Finds the Graveyard app directory, whatever the working directory is.
Directory _appDir() {
  var dir = Directory.current.absolute;
  for (var i = 0; i < 6; i++) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains(
          RegExp(r'^name:\s*graveyard\s*$', multiLine: true),
        )) {
      return dir;
    }
    final nested = Directory('${dir.path}/apps/graveyard');
    if (nested.existsSync()) return nested;
    dir = dir.parent;
  }
  fail('Could not locate apps/graveyard from ${Directory.current.path}');
}

/// Lists the Dart files under [relative] inside the app directory.
List<File> _dartFiles(String relative) {
  final dir = Directory('${_appDir().path}/$relative');
  if (!dir.existsSync()) fail('$relative must exist');
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

/// Returns the directive URIs of [file].
List<String> _uris(File file) => _directive
    .allMatches(file.readAsStringSync())
    .map((m) => m.group(1) ?? m.group(2)!)
    .toList();

/// Returns `path: uri` for every URI in [files] that [bad] flags.
List<String> _violations(List<File> files, bool Function(String) bad) => [
  for (final f in files)
    for (final u in _uris(f))
      if (bad(u)) '${f.path}: $u',
];

void main() {
  List<File> appFiles() => [..._dartFiles('lib'), ..._dartFiles('test')];

  test('no file imports coffin_core/src', () {
    expect(appFiles(), isNotEmpty);
    expect(
      _violations(appFiles(), (u) => u.contains('coffin_core/src')),
      isEmpty,
    );
  });

  test('no file imports Hauntagotchi', () {
    expect(
      _violations(
        appFiles(),
        (u) => u.contains('package:hauntagotchi') || u.contains('hauntagotchi'),
      ),
      isEmpty,
    );
  });

  test('ui files import no Hive and not the http GitHub client', () {
    final ui = _dartFiles('lib/src/ui');
    expect(ui, isNotEmpty);
    expect(
      _violations(
        ui,
        (u) =>
            u.startsWith('package:hive') ||
            u.contains('hive_ce') ||
            u.contains('data/http_github_client.dart') ||
            u.endsWith('http_github_client.dart'),
      ),
      isEmpty,
    );
  });

  test('pubspec lists no state-management package', () {
    const banned = {
      'provider',
      'riverpod',
      'flutter_riverpod',
      'hooks_riverpod',
      'bloc',
      'flutter_bloc',
      'get',
      'getx',
      'get_it',
      'mobx',
      'flutter_mobx',
      'redux',
      'flutter_redux',
      'signals',
      'signals_flutter',
      'stacked',
      'states_rebuilder',
      'rxdart',
    };
    final lines = File('${_appDir().path}/pubspec.yaml').readAsLinesSync();
    final keys = <String>{
      for (final line in lines)
        if (RegExp(r'^\s+([a-z_][a-z0-9_]*):').firstMatch(line) case final m?)
          m.group(1)!,
    };
    expect(keys, contains('flutter'));
    expect(keys.intersection(banned), isEmpty);
  });
}
