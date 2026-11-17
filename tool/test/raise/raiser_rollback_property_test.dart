import 'dart:io';

import 'package:coffin_raise/src/raise/disk_file_ops.dart';
import 'package:coffin_raise/src/raise/file_ops.dart';
import 'package:coffin_raise/src/raise/raise_error_kind.dart';
import 'package:coffin_raise/src/raise/raise_result.dart';
import 'package:coffin_raise/src/raise/raiser.dart';
import 'package:glados/glados.dart';

import '../support/fnv_hash.dart';
import '../support/temp_root.dart';

const _rootPubspec = '''
name: root
environment:
  sdk: ^3.13.0
workspace:
  - packages/a
''';

/// Template files a generated case can pick from (bit i of the mask).
const List<String> _templatePaths = [
  'a.txt.tmpl',
  'lib/main.dart.tmpl',
  'lib/src/ui/b.dart.tmpl',
  'web/icon.bin',
  'web/index.html.tmpl',
  'test/ui/t.dart.tmpl',
  '.kiro/steering/s.md.tmpl',
];

/// One generated scenario: which template files, and whether `apps/` exists.
final class _Case {
  const _Case(this.mask, this.hasApps, this.salt);

  final int mask;
  final bool hasApps;
  final int salt;

  @override
  String toString() => '_Case(mask: $mask, hasApps: $hasApps, salt: $salt)';
}

extension _AnyCase on Any {
  Generator<_Case> get raiseCase => combine3(
    intInRange(1, 1 << _templatePaths.length),
    this.bool,
    intInRange(0, 1000),
    (int mask, bool hasApps, int salt) => _Case(mask, hasApps, salt),
  );
}

/// When the fake fault fires relative to the faulted operation.
enum _Mode { before, after }

/// Records every operation and throws on the k-th forward write.
///
/// Forward writes are `createDirectory`, `createFileExclusive` and
/// `replaceFile` called before the fault fires. Once the fault has fired,
/// nothing else throws, so rollback can run to completion.
final class _RecordingOps implements FileOps {
  _RecordingOps(this._inner, {this.failAt, this.mode = _Mode.before});

  final FileOps _inner;
  final int? failAt;
  final _Mode mode;
  final List<String> log = [];
  int writes = 0;
  bool tripped = false;

  /// True when [op] is a counted write that should throw now.
  bool _shouldThrow() {
    if (tripped) return false;
    final index = writes++;
    if (index == failAt) {
      tripped = true;
      return true;
    }
    return false;
  }

  @override
  void createDirectory(String path) {
    log.add('createDirectory $path');
    if (_shouldThrow()) throw FileSystemException('injected fault', path);
    _inner.createDirectory(path);
  }

  @override
  void createFileExclusive(String path, List<int> bytes) {
    log.add('createFileExclusive $path');
    if (_shouldThrow()) throw FileSystemException('injected fault', path);
    _inner.createFileExclusive(path, bytes);
  }

  @override
  void replaceFile(String path, List<int> bytes) {
    log.add('replaceFile $path');
    final wasTripped = tripped;
    if (_shouldThrow()) {
      if (mode == _Mode.after) _inner.replaceFile(path, bytes);
      throw FileSystemException('injected fault', path);
    }
    // A restore after the fault is a normal write.
    if (wasTripped) log.add('restore $path');
    _inner.replaceFile(path, bytes);
  }

  @override
  void deleteFile(String path) {
    log.add('deleteFile $path');
    _inner.deleteFile(path);
  }

  @override
  void deleteEmptyDirectory(String path) {
    log.add('deleteEmptyDirectory $path');
    _inner.deleteEmptyDirectory(path);
  }

  @override
  List<int>? readFile(String path) => _inner.readFile(path);

  @override
  List<String> listDirectory(String path) => _inner.listDirectory(path);

  @override
  FileSystemEntityType typeOf(String path) => _inner.typeOf(path);
}

/// Maps every path under [root] (relative, `/` separated) to `dir`, `link`
/// or the FNV-1a hash of the file bytes.
Map<String, String> _snapshot(Directory root) {
  final prefix = '${root.path}/';
  final result = <String, String>{};
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    final relative = entity.path.substring(prefix.length);
    if (entity is Directory) {
      result[relative] = 'dir';
    } else if (entity is File) {
      result[relative] = fnv1a64(entity.readAsBytesSync()).toString();
    } else {
      result[relative] = 'link';
    }
  }
  return result;
}

Directory _writeTemplate(Directory base, _Case c) {
  final dir = Directory('${base.path}/tpl')..createSync();
  for (var i = 0; i < _templatePaths.length; i++) {
    if (c.mask & (1 << i) == 0) continue;
    final path = _templatePaths[i];
    final file = File('${dir.path}/$path')..createSync(recursive: true);
    if (path.endsWith('.tmpl')) {
      file.writeAsStringSync('hi {{display_name}} ${c.salt} $i');
    } else {
      file.writeAsBytesSync([c.salt % 256, i, 0, 255]);
    }
  }
  return dir;
}

Directory _writeRoot(Directory base, String name, _Case c) {
  final root = Directory('${base.path}/$name')..createSync();
  File('${root.path}/pubspec.yaml').writeAsStringSync(_rootPubspec);
  File('${root.path}/pubspec.lock').writeAsStringSync('lock ${c.salt}');
  File('${root.path}/packages/a/pubspec.yaml')
    ..createSync(recursive: true)
    ..writeAsStringSync('name: a\n');
  if (c.hasApps) {
    File('${root.path}/apps/other/lib/x.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('// other ${c.salt}');
  }
  return root;
}

void main() {
  group('Raiser rollback properties', () {
    // Feature: raise-app, Property 11: A failed raise leaves the Target_Root unchanged
    // Validates: Requirements 7.1, 7.4, 7.5, 7.6
    Glados(any.raiseCase, ExploreConfig(numRuns: 100)).test(
      'a fault at any write leaves the root as it was; success ends with the '
      'root pubspec replace',
      (c) {
        final base = tempRoot();
        final template = _writeTemplate(base, c);

        // Dry run: count writes and check the order on success.
        final okRoot = _writeRoot(base, 'ok', c);
        final before = _snapshot(okRoot);
        final okOps = _RecordingOps(const DiskFileOps());
        final ok = Raiser(ops: okOps).raise(
          targetRoot: okRoot,
          templateDir: template,
          appName: 'bone_shop',
        );
        expect(ok, isA<RaiseSuccess>(), reason: '$c');
        final pubspecPath = '${okRoot.path}/pubspec.yaml';
        expect(
          okOps.log.last,
          'replaceFile $pubspecPath',
          reason: 'root pubspec replace must be the last operation ($c)',
        );
        expect(
          okOps.log.where((e) => e.startsWith('replaceFile ')).length,
          1,
          reason: '$c',
        );
        expect(_snapshot(okRoot), isNot(before), reason: '$c');
        final total = okOps.writes;
        expect(total, greaterThan(1), reason: '$c');

        // Fault at every write, before it happens; and at the final replace
        // also after it happened, so the restore path runs.
        final faults = <(int, _Mode)>[
          for (var k = 0; k < total; k++) (k, _Mode.before),
          (total - 1, _Mode.after),
        ];
        var n = 0;
        for (final (k, mode) in faults) {
          final root = _writeRoot(base, 'fail_${n++}', c);
          final snapshot = _snapshot(root);
          final ops = _RecordingOps(const DiskFileOps(), failAt: k, mode: mode);
          final result = Raiser(ops: ops).raise(
            targetRoot: root,
            templateDir: template,
            appName: 'bone_shop',
          );
          final why = '$c, fault at write $k/$total ($mode), log: ${ops.log}';
          expect(result, isA<RaiseFailure>(), reason: why);
          final failure = result as RaiseFailure;
          expect(failure.kind, RaiseErrorKind.ioError, reason: why);
          expect(failure.message, contains('Nothing was changed.'));
          expect(_snapshot(root), snapshot, reason: why);
          if (mode == _Mode.after) {
            expect(
              ops.log.contains('restore ${root.path}/pubspec.yaml'),
              isTrue,
              reason: 'restore expected: $why',
            );
          }
          root.deleteSync(recursive: true);
        }
      },
    );
  });

  test('a failed restore is reported by path', () {
    const c = _Case(1, true, 7);
    final base = tempRoot();
    final template = _writeTemplate(base, c);
    final root = _writeRoot(base, 'root', c);
    final ops = _FailingRestoreOps(const DiskFileOps());
    final result = Raiser(ops: ops)
        .raise(targetRoot: root, templateDir: template, appName: 'bone_shop');
    expect(result, isA<RaiseFailure>());
    expect((result as RaiseFailure).message, contains('pubspec.yaml'));
    expect(result.message, contains('Could not remove'));
  });
}

/// Replaces the root pubspec, then throws, and refuses the restore.
final class _FailingRestoreOps implements FileOps {
  _FailingRestoreOps(this._inner);

  final FileOps _inner;
  int _replaces = 0;

  @override
  void replaceFile(String path, List<int> bytes) {
    if (_replaces++ == 0) {
      _inner.replaceFile(path, bytes);
      throw FileSystemException('injected fault', path);
    }
    throw FileSystemException('restore refused', path);
  }

  @override
  void createDirectory(String path) => _inner.createDirectory(path);

  @override
  void createFileExclusive(String path, List<int> bytes) =>
      _inner.createFileExclusive(path, bytes);

  @override
  void deleteFile(String path) => _inner.deleteFile(path);

  @override
  void deleteEmptyDirectory(String path) => _inner.deleteEmptyDirectory(path);

  @override
  List<int>? readFile(String path) => _inner.readFile(path);

  @override
  List<String> listDirectory(String path) => _inner.listDirectory(path);

  @override
  FileSystemEntityType typeOf(String path) => _inner.typeOf(path);
}
