import 'dart:io';

import 'package:coffin_raise/src/cli/raise_cli.dart';
import 'package:coffin_raise/src/raise/disk_file_ops.dart';
import 'package:coffin_raise/src/raise/file_ops.dart';
import 'package:coffin_raise/src/raise/raiser.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/temp_root.dart';

const _rootPubspec = '''
name: root
environment:
  sdk: ^3.13.0
workspace:
  - packages/a
''';

/// A [FileOps] that behaves like the disk but fails every file creation.
final class _FailingOps implements FileOps {
  final FileOps _inner = const DiskFileOps();

  @override
  void createDirectory(String path) => _inner.createDirectory(path);

  @override
  void createFileExclusive(String path, List<int> bytes) =>
      throw FileSystemException('disk is full', path);

  @override
  void replaceFile(String path, List<int> bytes) =>
      _inner.replaceFile(path, bytes);

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

/// A fake repo root (inside a temp folder) with a root pubspec and one package.
Directory _makeRoot() {
  final root = Directory('${tempRoot().path}/root')..createSync();
  File('${root.path}/pubspec.yaml').writeAsStringSync(_rootPubspec);
  Directory('${root.path}/packages/a').createSync(recursive: true);
  File('${root.path}/packages/a/pubspec.yaml').writeAsStringSync('name: a\n');
  return root;
}

Directory _realTemplate() =>
    Directory('${Directory.current.absolute.path}/templates/app');

/// Every file and directory under [dir] mapped to its content (or type).
Map<String, Object?> _snapshot(Directory dir) {
  final result = <String, Object?>{};
  for (final entity in dir.listSync(recursive: true, followLinks: false)) {
    final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
    result[entity.path] = type == FileSystemEntityType.file
        ? File(entity.path).readAsBytesSync()
        : type.toString();
  }
  return result;
}

class _Run {
  _Run(this.code, this.out, this.err);
  final int code;
  final String out;
  final String err;
}

_Run _run(List<String> args, Directory root, {Raiser? raiser}) {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = RaiseCli.run(
    args,
    targetRoot: root,
    templateDir: _realTemplate(),
    out: out,
    err: err,
    raiser: raiser,
  );
  return _Run(code, out.toString(), err.toString());
}

void main() {
  group('arguments', () {
    test('no arguments print usage to stderr and return 64', () {
      final root = _makeRoot();
      final before = _snapshot(root);
      final result = _run([], root);
      expect(result.code, 64);
      expect(result.err, contains('Usage:'));
      expect(result.out, isEmpty);
      expect(_snapshot(root), before);
    });

    test('two arguments print usage to stderr and return 64', () {
      final root = _makeRoot();
      final before = _snapshot(root);
      final result = _run(['one', 'two'], root);
      expect(result.code, 64);
      expect(result.err, contains('Usage:'));
      expect(result.out, isEmpty);
      expect(_snapshot(root), before);
    });
  });

  group('help', () {
    for (final flag in ['--help', '-h']) {
      test('$flag returns 0 and lists exit codes and an example', () {
        final root = _makeRoot();
        final before = _snapshot(root);
        final result = _run([flag], root);
        expect(result.code, 0);
        expect(result.err, isEmpty);
        expect(result.out, contains('Example:'));
        expect(result.out, contains('dart run tool/raise.dart bone_shop'));
        for (final code in ['0', '64', '65', '74']) {
          expect(
            RegExp('^\\s+$code\\s', multiLine: true).hasMatch(result.out),
            isTrue,
            reason: 'exit code $code is listed',
          );
        }
        expect(_snapshot(root), before);
      });
    }
  });

  group('bad name', () {
    test('prints the reason and a suggestion, returns 65, writes nothing', () {
      final root = _makeRoot();
      final before = _snapshot(root);
      final result = _run(['Bone-Shop'], root);
      expect(result.code, 65);
      expect(result.out, isEmpty);
      expect(result.err, contains('Reason:'));
      expect(result.err, contains('Try this name instead: bone_shop'));
      expect(_snapshot(root), before);
    });
  });

  group('success', () {
    test('raises the real template into a temp root and returns 0', () {
      final root = _makeRoot();
      final result = _run(['bone_shop'], root);
      expect(result.code, 0);
      expect(result.err, isEmpty);
      expect(result.out, contains('apps/bone_shop'));
      expect(result.out, contains('flutter pub get'));
      expect(result.out, contains('flutter run -d chrome'));
      expect(result.out, contains('flutter test'));
      expect(
        result.out.split('\n'),
        contains('Open apps/bone_shop in Kiro to load its steering'),
      );
      expect(
        File('${root.path}/apps/bone_shop/pubspec.yaml').existsSync(),
        isTrue,
      );
      expect(
        File('${root.path}/pubspec.yaml').readAsStringSync(),
        contains('  - apps/bone_shop'),
      );
    });
  });

  group('failures', () {
    test('an injected I/O failure returns 74 and changes nothing', () {
      final root = _makeRoot();
      final before = _snapshot(root);
      final result = _run(
        ['bone_shop'],
        root,
        raiser: Raiser(ops: _FailingOps()),
      );
      expect(result.code, 74);
      expect(result.out, isEmpty);
      expect(result.err, contains('Nothing was changed.'));
      expect(_snapshot(root), before);
    });

    test('an existing app folder returns 65 and leaves it alone', () {
      final root = _makeRoot();
      Directory('${root.path}/apps/bone_shop').createSync(recursive: true);
      File('${root.path}/apps/bone_shop/keep.txt').writeAsStringSync('mine');
      final before = _snapshot(root);
      final result = _run(['bone_shop'], root);
      expect(result.code, 65);
      expect(result.out, isEmpty);
      expect(result.err, isNotEmpty);
      expect(_snapshot(root), before);
    });
  });

  group('defaultTemplateDir', () {
    test('is templates/app next to the script', () {
      final dir = RaiseCli.defaultTemplateDir(
        Uri.file('/some/where/tool/raise.dart'),
      );
      expect(dir.path, '/some/where/tool/templates/app');
    });
  });
}
