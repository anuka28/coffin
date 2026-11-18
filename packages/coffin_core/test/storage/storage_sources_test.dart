// Source scans for the crypt-storage spec. Reads files with dart:io, so this
// file is VM only and is never part of the Chrome run.
@TestOn('vm')
library;

import 'dart:io';

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locates the coffin_core package root whatever the working directory is,
/// starting from this test file's location and falling back to the cwd.
Directory _packageRoot() {
  final starts = <Directory>[
    if (Platform.script.scheme == 'file')
      File.fromUri(Platform.script).parent.absolute,
    Directory.current.absolute,
  ];
  for (final start in starts) {
    var dir = start;
    for (var i = 0; i < 8; i++) {
      final pubspec = File('${dir.path}/pubspec.yaml');
      if (pubspec.existsSync() &&
          pubspec.readAsStringSync().contains(
            RegExp(r'^name:\s*coffin_core\s*$', multiLine: true),
          )) {
        return dir;
      }
      final nested = Directory('${dir.path}/packages/coffin_core');
      if (nested.existsSync()) return nested;
      dir = dir.parent;
    }
  }
  fail('Could not locate packages/coffin_core from ${Directory.current.path}');
}

String _read(String path) => File(path).readAsStringSync();

/// [src] without `//` comments (including doc comments) and block comments.
String _stripComments(String src) => src
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .split('\n')
    .map((l) => l.replaceFirst(RegExp(r'//.*$'), ''))
    .join('\n');

/// The URIs of every import and export directive in [src] (comments ignored).
List<String> _uris(String src) => RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
).allMatches(_stripComments(src)).map((m) => m.group(1)!).toList();

/// Every `.dart` file under [dir], or none when [dir] does not exist.
List<File> _dartFiles(String dir) {
  final d = Directory(dir);
  if (!d.existsSync()) return const <File>[];
  return d
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

String _name(File f) => f.uri.pathSegments.last;

const _skippedDirs = {'.dart_tool', 'build', '.git', 'node_modules', '.idea'};

/// Files under [dir] whose name satisfies [match], skipping generated and
/// tooling directories.
List<File> _walk(Directory dir, bool Function(String name) match) {
  final out = <File>[];
  for (final entity in dir.listSync(followLinks: false)) {
    final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
    if (entity is Directory) {
      if (_skippedDirs.contains(name)) continue;
      out.addAll(_walk(entity, match));
    } else if (entity is File && match(name)) {
      out.add(entity);
    }
  }
  return out;
}

/// The Chrome-run list from design.md, "Chrome run of the pure storage tests".
const _chromeFiles = <String>[
  'key_validator_test.dart',
  'key_validator_property_test.dart',
  'json_safety_test.dart',
  'json_safety_property_test.dart',
  'envelope_codec_test.dart',
  'envelope_codec_property_test.dart',
  'record_codec_property_test.dart',
  'storage_event_test.dart',
  'storage_issue_test.dart',
  'issue_reporter_test.dart',
  'operation_queue_test.dart',
  'memory_raw_store_test.dart',
  'memory_record_repository_test.dart',
  'envelope_repository_property_test.dart',
];

const _exportedNames = <String>{
  'hiveFlutterInitializer',
  'IssueReporter',
  'discardIssues',
  'JsonMap',
  'KeyValidator',
  'MemoryRecordRepository',
  'MigrationHook',
  'OpenedRepository',
  'RecordCodec',
  'RecordRepository',
  'StorageEvent',
  'StorageEventKind',
  'StorageIssue',
  'StorageIssueKind',
  'StorageInitializer',
  'StorageOpener',
};

const _hiddenNames = <String>{
  'RawStore',
  'RawStoreOpener',
  'MemoryRawStore',
  'HiveRawStore',
  'EnvelopeRepository',
  'HiveRecordRepository',
  'OperationQueue',
  'Envelope',
  'EnvelopeCodec',
  'JsonSafety',
  'reportSafely',
};

/// Storage export statements (`src/storage/`) of the barrel, mapped to their `show` names.
Map<String, Set<String>> _storageExports(String barrel) {
  final result = <String, Set<String>>{};
  final statements = _stripComments(barrel)
      .split(';')
      .map((s) => s.trim().replaceAll(RegExp(r'\s+'), ' '))
      .where((s) => s.startsWith('export '));
  for (final s in statements) {
    final m = RegExp(r"^export '([^']+)' show (.+)$").firstMatch(s);
    if (m == null) continue;
    if (!m.group(1)!.startsWith('src/storage/')) continue;
    result[m.group(1)!] = m.group(2)!.split(',').map((n) => n.trim()).toSet();
  }
  return result;
}

/// Top-level public type declarations in [src] (comments ignored).
List<String> _publicTypes(String src) {
  final decl = RegExp(
    r'^(?:(?:abstract|final|sealed|base|interface|mixin)\s+)*'
    r'(?:class|enum|mixin)\s+(\w+)',
    multiLine: true,
  );
  return decl
      .allMatches(_stripComments(src))
      .map((m) => m.group(1)!)
      .where((n) => !n.startsWith('_'))
      .toList();
}

/// Resolves a local import of [from] to a file, or null for external URIs.
File? _resolveLocal(File from, String uri, String root) {
  if (uri.startsWith('dart:')) return null;
  if (uri.startsWith('package:coffin_core/')) {
    return File('$root/lib/${uri.substring('package:coffin_core/'.length)}');
  }
  if (uri.startsWith('package:')) return null;
  return File.fromUri(from.uri.resolve(uri));
}

void main() {
  final root = _packageRoot().path;
  final repo = Directory(root).parent.parent.path;
  final storage = '$root/lib/src/storage';
  final testStorage = '$root/test/storage';
  final libFiles = _dartFiles(storage);
  final barrel = _read('$root/lib/coffin_core.dart');

  test('scan roots exist and are non-empty', () {
    expect(libFiles, isNotEmpty);
    expect(_dartFiles(testStorage), isNotEmpty);
  });

  group('barrel', () {
    test('every exported storage name is usable from the barrel alone', () {
      // Compile-time references: a missing export is a compile error.
      final references = <Object>[
        hiveFlutterInitializer,
        discardIssues,
        IssueReporter,
        JsonMap,
        KeyValidator,
        MemoryRecordRepository,
        MigrationHook,
        OpenedRepository,
        RecordCodec,
        RecordRepository,
        StorageEvent,
        StorageEventKind,
        StorageIssue,
        StorageIssueKind,
        StorageInitializer,
        StorageOpener,
      ];
      expect(references, hasLength(_exportedNames.length));
    });

    test('the show lists contain exactly the exported storage names', () {
      final exports = _storageExports(barrel);
      expect(exports, isNotEmpty);
      final names = exports.values.expand((s) => s).toSet();
      expect(names, _exportedNames);
    });

    test('every storage export uses show', () {
      final statements = _stripComments(barrel)
          .split(';')
          .map((s) => s.trim().replaceAll(RegExp(r'\s+'), ' '))
          .where((s) => s.startsWith('export ') && s.contains('src/storage/'))
          .toList();
      expect(statements, isNotEmpty);
      for (final s in statements) {
        expect(s, contains(' show '), reason: s);
        expect(s, isNot(contains(' hide ')), reason: s);
      }
    });

    test('no hidden storage name is exported', () {
      final exports = _storageExports(barrel);
      final shown = exports.values.expand((s) => s).toSet();
      for (final name in _hiddenNames) {
        expect(shown, isNot(contains(name)), reason: name);
      }
      // Also by file: the barrel never mentions the internal files.
      final code = _stripComments(barrel);
      for (final file in <String>[
        'raw_store.dart',
        'memory_raw_store.dart',
        'hive_raw_store.dart',
        'envelope_repository.dart',
        'hive_record_repository.dart',
        'operation_queue.dart',
        'envelope.dart',
        'envelope_codec.dart',
        'json_safety.dart',
      ]) {
        expect(code, isNot(contains("/$file'")), reason: file);
      }
    });
  });

  group('storage imports', () {
    test('scans every lib/src/storage file', () {
      expect(libFiles.length, greaterThan(20));
    });

    test('no storage file imports Flutter', () {
      for (final f in libFiles) {
        for (final uri in _uris(f.readAsStringSync())) {
          expect(uri, isNot(startsWith('package:flutter/')), reason: f.path);
        }
      }
    });

    test('only hive_raw_store.dart imports package:hive_ce/', () {
      final importers = libFiles
          .where(
            (f) =>
                _uris(f.readAsStringSync())
                    .any((u) => u.startsWith('package:hive_ce/')),
          )
          .map(_name)
          .toList();
      expect(importers, ['hive_raw_store.dart']);
    });

    test('only hive_flutter_initializer.dart imports hive_ce_flutter', () {
      final importers = libFiles
          .where(
            (f) =>
                _uris(f.readAsStringSync())
                    .any((u) => u.startsWith('package:hive_ce_flutter/')),
          )
          .map(_name)
          .toList();
      expect(importers, ['hive_flutter_initializer.dart']);
    });

    test('storage imports nothing from the apps', () {
      for (final f in libFiles) {
        for (final uri in _uris(f.readAsStringSync())) {
          expect(uri, isNot(contains('apps/')), reason: f.path);
          expect(uri, isNot(startsWith('package:hauntagotchi')));
          expect(uri, isNot(startsWith('package:graveyard')));
        }
      }
    });

    test('storage imports no Riverpod, AI or routing code', () {
      for (final f in libFiles) {
        for (final uri in _uris(f.readAsStringSync())) {
          expect(uri, isNot(contains('riverpod')), reason: f.path);
          expect(uri, isNot(contains('go_router')), reason: f.path);
          expect(uri, isNot(contains('/ai/')), reason: f.path);
          expect(uri, isNot(contains('/router/')), reason: f.path);
          // Stricter: relative imports stay inside the storage folder.
          if (!uri.contains(':')) {
            expect(uri, isNot(contains('/')), reason: '${f.path}: $uri');
          }
        }
      }
    });
  });

  group('Chrome rule', () {
    final testFiles = [for (final n in _chromeFiles) File('$testStorage/$n')];

    test('every Chrome-run file exists', () {
      expect(testFiles, hasLength(14));
      for (final f in testFiles) {
        expect(f.existsSync(), isTrue, reason: f.path);
      }
    });

    test('Chrome-run files and their local imports stay platform neutral', () {
      var scanned = 0;
      final visited = <String>{};
      final pending = [...testFiles];
      while (pending.isNotEmpty) {
        final file = pending.removeLast();
        if (!visited.add(file.path)) continue;
        expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
        final src = file.readAsStringSync();
        final isTest = file.path.startsWith(testStorage);
        scanned++;
        if (isTest) {
          expect(
            _stripComments(src),
            isNot(contains('@TestOn')),
            reason: '${file.path} carries @TestOn',
          );
        }
        for (final uri in _uris(src)) {
          expect(uri, isNot('dart:io'), reason: file.path);
          expect(uri, isNot(startsWith('package:hive_ce')), reason: file.path);
          expect(uri, isNot(contains('hive_test_box')), reason: file.path);
          final next = _resolveLocal(file, uri, root);
          if (next != null) pending.add(next);
        }
      }
      // 14 test files plus at least the support files and storage sources.
      expect(scanned, greaterThan(_chromeFiles.length));
    });

    test('the transitive scan reaches the support files', () {
      final support = _dartFiles('$testStorage/support');
      expect(support, isNotEmpty);
      final imported = <String>{};
      for (final f in testFiles) {
        for (final uri in _uris(f.readAsStringSync())) {
          if (uri.startsWith('support/')) imported.add(uri);
        }
      }
      expect(imported, isNotEmpty);
    });
  });

  group('structure', () {
    test('each storage file declares at most one public type', () {
      for (final f in libFiles) {
        final types = _publicTypes(f.readAsStringSync());
        expect(types.length, lessThanOrEqualTo(1), reason: '${f.path}: $types');
      }
    });

    test('no adapter or encryption code in lib/src/storage', () {
      final banned = RegExp(
        r'TypeAdapter|registerAdapter|encryptionCipher|HiveAesCipher'
        r'|package:(?:encrypt|pointycastle|cryptography|crypto|steel_crypt)\b',
      );
      for (final f in libFiles) {
        final code = _stripComments(f.readAsStringSync());
        expect(banned.hasMatch(code), isFalse, reason: f.path);
      }
    });

    test('Hive repository and opener docs say the data is unencrypted', () {
      for (final name in <String>[
        'hive_record_repository.dart',
        'storage_opener.dart',
      ]) {
        final docs = _read('$storage/$name')
            .split('\n')
            .where((l) => l.trimLeft().startsWith('///'))
            .join('\n');
        expect(docs, contains('unencrypted'), reason: name);
      }
    });
  });

  group('packages', () {
    final pubspecs = _walk(Directory(repo), (n) => n == 'pubspec.yaml');

    String codeOf(String path) =>
        _read(path)
            .split('\n')
            .map((l) => l.replaceFirst(RegExp(r'#.*$'), ''))
            .join('\n');

    test('finds the workspace pubspecs', () {
      expect(pubspecs.length, greaterThanOrEqualTo(4));
    });

    test('coffin_core pins the storage packages exactly', () {
      final pubspec = codeOf('$root/pubspec.yaml');
      for (final pin in <String, String>{
        'hive_ce': '2.23.3',
        'hive_ce_flutter': '2.3.4',
        'meta': '1.19.0',
      }.entries) {
        expect(
          pubspec,
          matches(
            RegExp(
              '^\\s+${pin.key}:\\s*${RegExp.escape(pin.value)}\\s*\$',
              multiLine: true,
            ),
          ),
          reason: pin.key,
        );
      }
    });

    test('no pubspec lists a code generator or an encryption package', () {
      final banned = RegExp(
        r'^\s*(?:hive_ce_generator|build_runner|encrypt|pointycastle'
        r'|cryptography|crypto|steel_crypt)\s*:',
        multiLine: true,
      );
      for (final f in pubspecs) {
        expect(banned.hasMatch(codeOf(f.path)), isFalse, reason: f.path);
      }
    });

    test('neither app pubspec lists hive_ce or hive_ce_flutter', () {
      for (final app in <String>['hauntagotchi', 'graveyard']) {
        final pubspec = codeOf('$repo/apps/$app/pubspec.yaml');
        expect(pubspec, isNot(contains('hive_ce')), reason: app);
      }
    });

    test('no generated *.g.dart file exists under packages/ or apps/', () {
      final dirs = [Directory('$repo/packages'), Directory('$repo/apps')];
      var scanned = 0;
      for (final d in dirs) {
        expect(d.existsSync(), isTrue, reason: d.path);
        scanned += _walk(d, (n) => n.endsWith('.dart')).length;
        expect(_walk(d, (n) => n.endsWith('.g.dart')), isEmpty);
      }
      expect(scanned, greaterThan(0));
    });

    /// Apps may use coffin_core only through its barrel file, so any import
    /// or export of `package:coffin_core/src/` is reported as `file:line`.
    test('apps import coffin_core only through package:coffin_core/coffin_core.dart', () {
      final directive = RegExp(
        r'''^\s*(?:import|export)\s+['"]package:coffin_core/src/''',
      );
      final offenders = <String>[];
      var scanned = 0;
      final appsDir = Directory('$repo/apps');
      expect(appsDir.existsSync(), isTrue, reason: appsDir.path);
      for (final app in appsDir.listSync().whereType<Directory>()) {
        for (final dir in <String>['lib', 'test']) {
          for (final f in _dartFiles('${app.path}/$dir')) {
            scanned++;
            final lines = f.readAsLinesSync();
            for (var i = 0; i < lines.length; i++) {
              if (directive.hasMatch(lines[i])) {
                offenders.add('${f.path}:${i + 1}');
              }
            }
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
      expect(scanned, greaterThan(0));
    });
  });
}
