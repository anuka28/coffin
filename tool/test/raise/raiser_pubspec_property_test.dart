import 'dart:io';

import 'package:coffin_raise/src/raise/disk_file_ops.dart';
import 'package:coffin_raise/src/raise/file_ops.dart';
import 'package:coffin_raise/src/raise/raise_error_kind.dart';
import 'package:coffin_raise/src/raise/raise_result.dart';
import 'package:coffin_raise/src/raise/raiser.dart';
import 'package:glados/glados.dart';

import '../support/fnv_hash.dart';
import '../support/temp_root.dart';

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

/// Number of unusable root pubspec variants, see [_unusablePubspec].
const int _variantCount = 9;

/// The root pubspec text for [variant], or null when the file is missing.
///
/// Every variant is one the Raiser must refuse for app [name].
String? _unusablePubspec(int variant, String name) {
  const head = 'name: root\nenvironment:\n  sdk: ^3.13.0\n';
  switch (variant) {
    case 0:
      return null;
    case 1:
      return head;
    case 2:
      return '${head}workspace:\ndependencies:\n  foo: ^1.0.0\n';
    case 3:
      return '${head}workspace:\n';
    case 4:
      return '${head}workspace:\n  - packages/a\n  - apps/$name\n';
    case 5:
      return '${head}workspace:\n  - packages/a\n  - "apps/$name"\n';
    case 6:
      return "${head}workspace:\n  - 'apps/$name'\n  - packages/a\n";
    case 7:
      return '${head}workspace:\n  - apps/$name # mine\n';
    default:
      return '${head}workspace:\r\n  - packages/a\r\n  - apps/$name\r\n'
          '  - tool\r\n';
  }
}

/// One generated scenario.
final class _Case {
  const _Case(this.variant, this.mask, this.salt);

  final int variant;
  final int mask;
  final int salt;

  /// A valid, unreserved app name derived from [salt].
  String get appName => 'zapp_${salt.toRadixString(36)}';

  @override
  String toString() => '_Case(variant: $variant, mask: $mask, salt: $salt)';
}

extension _AnyCase on Any {
  Generator<_Case> get refusalCase => combine3(
    intInRange(0, _variantCount),
    intInRange(1, 1 << _templatePaths.length),
    intInRange(0, 100000),
    (int variant, int mask, int salt) => _Case(variant, mask, salt),
  );

  Generator<_Case> get successCase => combine2(
    intInRange(1, 1 << _templatePaths.length),
    intInRange(0, 100000),
    (int mask, int salt) => _Case(-1, mask, salt),
  );
}

/// Records every operation that changes the disk, delegating to [_inner].
final class _RecordingOps implements FileOps {
  _RecordingOps(this._inner);

  final FileOps _inner;

  /// Paths of every create, replace and delete call, in order.
  final List<String> written = [];

  @override
  void createDirectory(String path) {
    written.add(path);
    _inner.createDirectory(path);
  }

  @override
  void createFileExclusive(String path, List<int> bytes) {
    written.add(path);
    _inner.createFileExclusive(path, bytes);
  }

  @override
  void replaceFile(String path, List<int> bytes) {
    written.add(path);
    _inner.replaceFile(path, bytes);
  }

  @override
  void deleteFile(String path) {
    written.add(path);
    _inner.deleteFile(path);
  }

  @override
  void deleteEmptyDirectory(String path) {
    written.add(path);
    _inner.deleteEmptyDirectory(path);
  }

  @override
  List<int>? readFile(String path) => _inner.readFile(path);

  @override
  List<String> listDirectory(String path) => _inner.listDirectory(path);

  @override
  FileSystemEntityType typeOf(String path) => _inner.typeOf(path);
}

/// Maps every path under [root] to `dir`, `link` or the hash of its bytes.
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

/// Builds a root with [pubspec] (skipped when null), a lock file, another
/// workspace package and another app.
Directory _writeRoot(Directory base, String? pubspec, _Case c) {
  final root = Directory('${base.path}/root')..createSync();
  if (pubspec != null) {
    File('${root.path}/pubspec.yaml').writeAsStringSync(pubspec);
  }
  File('${root.path}/pubspec.lock').writeAsStringSync('lock ${c.salt}');
  File('${root.path}/packages/a/pubspec.yaml')
    ..createSync(recursive: true)
    ..writeAsStringSync('name: a\n');
  File('${root.path}/apps/other/pubspec.yaml')
    ..createSync(recursive: true)
    ..writeAsStringSync('name: other\n');
  return root;
}

const String _goodPubspec =
    'name: root\nenvironment:\n  sdk: ^3.13.0\nworkspace:\n  - packages/a\n'
    '  - apps/other\n';

bool _insideApp(String path, String rootPath, String name) {
  final appDir = '$rootPath/apps/$name';
  return path == appDir || path.startsWith('$appDir/');
}

void main() {
  group('Raiser pubspec properties', () {
    // Feature: raise-app, Property 9: Workspace edit refuses unusable files
    // Validates: Requirements 6.3, 6.5
    Glados(any.refusalCase, ExploreConfig(numRuns: 100)).test(
      'a missing, list-less or already-listing root pubspec is refused and '
      'nothing is written',
      (c) {
        final base = tempRoot();
        final template = _writeTemplate(base, c);
        final root = _writeRoot(
          base,
          _unusablePubspec(c.variant, c.appName),
          c,
        );
        final before = _snapshot(root);
        final ops = _RecordingOps(const DiskFileOps());

        final result = Raiser(ops: ops)
            .raise(targetRoot: root, templateDir: template, appName: c.appName);

        expect(result, isA<RaiseFailure>(), reason: '$c');
        expect(
          (result as RaiseFailure).kind,
          RaiseErrorKind.pubspecProblem,
          reason: '$c: ${result.message}',
        );
        expect(ops.written, isEmpty, reason: '$c');
        expect(_snapshot(root), before, reason: '$c');
        expect(
          File('${root.path}/pubspec.lock').readAsStringSync(),
          'lock ${c.salt}',
          reason: '$c',
        );
        expect(
          File('${root.path}/packages/a/pubspec.yaml').readAsStringSync(),
          'name: a\n',
          reason: '$c',
        );
        expect(
          File('${root.path}/apps/other/pubspec.yaml').readAsStringSync(),
          'name: other\n',
          reason: '$c',
        );
        expect(
          Directory('${root.path}/apps/${c.appName}').existsSync(),
          isFalse,
          reason: '$c',
        );
      },
    );

    // Feature: raise-app, Property 10: Planned paths stay inside the app folder
    // Validates: Requirements 7.2, 7.7
    Glados(
      any.successCase,
      ExploreConfig(numRuns: 100),
    ).test('every path the Raiser writes is inside apps/<name>/ or is the root '
        'pubspec.yaml', (c) {
      final base = tempRoot();
      final template = _writeTemplate(base, c);
      final root = _writeRoot(base, _goodPubspec, c);
      final before = _snapshot(root);
      final ops = _RecordingOps(const DiskFileOps());

      final result = Raiser(ops: ops)
          .raise(targetRoot: root, templateDir: template, appName: c.appName);

      expect(result, isA<RaiseSuccess>(), reason: '$c');
      expect(ops.written, isNotEmpty, reason: '$c');
      final rootPubspec = '${root.path}/pubspec.yaml';
      for (final path in ops.written) {
        final allowed =
            path == rootPubspec || _insideApp(path, root.path, c.appName);
        expect(allowed, isTrue, reason: '$c wrote outside the app: $path');
      }
      // Files the Raiser did not create are untouched.
      final after = _snapshot(root);
      for (final entry in before.entries) {
        if (entry.key == 'pubspec.yaml') continue;
        expect(after[entry.key], entry.value, reason: '$c: ${entry.key}');
      }
      for (final key in after.keys) {
        final isNew = !before.containsKey(key);
        if (isNew) {
          expect(
            key == 'apps/${c.appName}' || key.startsWith('apps/${c.appName}/'),
            isTrue,
            reason: '$c created $key',
          );
        }
      }
    });
  });
}
