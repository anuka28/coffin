import 'dart:io';

import 'package:coffin_raise/coffin_raise.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fnv_hash.dart';
import '../support/temp_root.dart';

// Requirements 8.5, 11.1.
//
// `flutter test` runs each test file in its own isolate, so a snapshot in this
// file can only watch the real repo while this file runs. The guard therefore
// does two things:
//  1. It snapshots in setUpAll and compares in tearDownAll, so anything that
//     changes the real `apps/` or root `pubspec.yaml` while this file runs
//     fails the run.
//  2. It runs the generator itself (Raiser and RaiseCli, with the real
//     template) against temp roots and compares the snapshot right after.

const _sep = '/';

/// The repo root: the parent of the `tool/` package, which is the working
/// directory of `flutter test`.
Directory _repoRoot() => Directory.current.absolute.parent;

String _rel(String root, String path) {
  var p = path.replaceAll(Platform.pathSeparator, _sep);
  final r = root.replaceAll(Platform.pathSeparator, _sep);
  if (p.startsWith('$r$_sep')) p = p.substring(r.length + 1);
  return p;
}

bool _skipped(String relativePath) {
  final parts = relativePath.split(_sep);
  return parts.contains('build') || parts.contains('.dart_tool');
}

/// Maps repo-relative path to FNV-1a hash for every file under `apps/`
/// (skipping `build/` and `.dart_tool/`) plus the root `pubspec.yaml`.
/// Reads only. Symlinks are recorded by target, not followed.
Map<String, int> _snapshot(Directory repo) {
  final root = repo.path;
  final result = <String, int>{};

  final pubspec = File('$root/pubspec.yaml');
  if (pubspec.existsSync()) {
    result['pubspec.yaml'] = fnv1a64(pubspec.readAsBytesSync());
  }

  final apps = Directory('$root/apps');
  if (apps.existsSync()) {
    for (final entity in apps.listSync(recursive: true, followLinks: false)) {
      final rel = _rel(root, entity.path);
      if (_skipped(rel)) continue;
      if (entity is File) {
        result[rel] = fnv1a64(entity.readAsBytesSync());
      } else if (entity is Link) {
        result[rel] = fnv1a64(entity.targetSync().codeUnits);
      }
    }
  }
  return result;
}

void main() {
  final repo = _repoRoot();
  late Map<String, int> before;

  setUpAll(() {
    expect(
      File('${repo.path}/pubspec.yaml').existsSync(),
      isTrue,
      reason: 'expected the repo root at ${repo.path}',
    );
    before = _snapshot(repo);
    expect(before.keys, contains('pubspec.yaml'));
    expect(before.keys.any((k) => k.startsWith('apps/')), isTrue);
  });

  tearDownAll(() {
    expect(
      _snapshot(repo),
      equals(before),
      reason: 'apps/ or the root pubspec.yaml changed during the test run',
    );
  });

  group('repo guard', () {
    final templateDir = Directory('${repo.path}/tool/templates/app');

    Directory newRoot() {
      final root = tempRoot();
      File('${root.path}/pubspec.yaml').writeAsStringSync(
        'name: guard_workspace\n'
        'environment:\n'
        "  sdk: '>=3.0.0 <4.0.0'\n"
        'workspace:\n'
        '  - apps/placeholder\n',
      );
      return root;
    }

    test('raising into a temp root leaves the real repo unchanged', () {
      final root = newRoot();

      final result = Raiser().raise(
        appName: 'guard_app',
        targetRoot: root,
        templateDir: templateDir,
      );

      expect(result, isA<RaiseSuccess>());
      expect(Directory('${root.path}/apps/guard_app').existsSync(), isTrue);
      expect(_snapshot(repo), equals(before));
    });

    test('a failing raise into a temp root leaves the real repo unchanged', () {
      final root = newRoot();

      final result = Raiser().raise(
        appName: 'Not A Name',
        targetRoot: root,
        templateDir: templateDir,
      );

      expect(result, isA<RaiseFailure>());
      expect(_snapshot(repo), equals(before));
    });

    test('RaiseCli into a temp root leaves the real repo unchanged', () {
      final root = newRoot();
      final out = StringBuffer();
      final err = StringBuffer();

      final code = RaiseCli.run(
        ['guard_cli_app'],
        targetRoot: root,
        templateDir: templateDir,
        out: out,
        err: err,
      );

      expect(code, ExitCodes.ok, reason: '$err');
      expect(_snapshot(repo), equals(before));
    });
  });
}
