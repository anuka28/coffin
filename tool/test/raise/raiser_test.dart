import 'dart:io';

import 'package:coffin_raise/src/raise/disk_file_ops.dart';
import 'package:coffin_raise/src/raise/file_ops.dart';
import 'package:coffin_raise/src/raise/raise_error_kind.dart';
import 'package:coffin_raise/src/raise/raise_result.dart';
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

const _lockText = '# lock file\npackages: {}\n';
const _otherPubspec = 'name: a\n';

/// A fake repo root with a root pubspec, a lock file and one other package.
Directory _makeRoot(Directory base, {String pubspec = _rootPubspec}) {
  final root = Directory('${base.path}/root')..createSync();
  File('${root.path}/pubspec.yaml').writeAsStringSync(pubspec);
  File('${root.path}/pubspec.lock').writeAsStringSync(_lockText);
  Directory('${root.path}/packages/a').createSync(recursive: true);
  File('${root.path}/packages/a/pubspec.yaml').writeAsStringSync(_otherPubspec);
  return root;
}

Directory _fixtureTemplate(Directory base) {
  final dir = Directory('${base.path}/tpl')..createSync();
  File('${dir.path}/hello.txt.tmpl').writeAsStringSync('hi {{display_name}}');
  Directory('${dir.path}/sub').createSync();
  File('${dir.path}/sub/data.bin').writeAsBytesSync([0, 1, 2]);
  return dir;
}

Directory _realTemplate() =>
    Directory('${Directory.current.absolute.path}/templates/app');

/// Every file and directory under [dir] mapped to its content (null for
/// directories and links). Does not follow links.
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

/// Lets the test slip a foreign file into a folder right after it is created.
final class _RacingOps implements FileOps {
  _RacingOps(this.raceDir);

  final String raceDir;
  final DiskFileOps _inner = const DiskFileOps();
  final List<String> deleted = [];

  @override
  void createDirectory(String path) {
    _inner.createDirectory(path);
    if (path == raceDir) {
      File('$path/theirs.txt').writeAsStringSync('not ours');
    }
  }

  @override
  void createFileExclusive(String path, List<int> bytes) =>
      _inner.createFileExclusive(path, bytes);

  @override
  void replaceFile(String path, List<int> bytes) =>
      _inner.replaceFile(path, bytes);

  @override
  void deleteFile(String path) {
    deleted.add(path);
    _inner.deleteFile(path);
  }

  @override
  void deleteEmptyDirectory(String path) {
    deleted.add(path);
    _inner.deleteEmptyDirectory(path);
  }

  @override
  List<int>? readFile(String path) => _inner.readFile(path);

  @override
  List<String> listDirectory(String path) => _inner.listDirectory(path);

  @override
  FileSystemEntityType typeOf(String path) => _inner.typeOf(path);
}

void main() {
  group('success', () {
    test('fixture template: files rendered, pubspec edited last', () {
      final base = tempRoot();
      final root = _makeRoot(base);
      final result = Raiser().raise(
        targetRoot: root,
        templateDir: _fixtureTemplate(base),
        appName: 'bone_shop',
      );

      expect(result, isA<RaiseSuccess>());
      expect(
        File('${root.path}/apps/bone_shop/hello.txt').readAsStringSync(),
        'hi Bone Shop',
      );
      expect(
        File('${root.path}/apps/bone_shop/sub/data.bin').readAsBytesSync(),
        [0, 1, 2],
      );
      expect(
        File('${root.path}/pubspec.yaml').readAsStringSync(),
        '$_rootPubspec  - apps/bone_shop\n',
      );
    });

    test('real template: creates the files listed in requirement 4.1', () {
      final base = tempRoot();
      final root = _makeRoot(base);
      final result = Raiser().raise(
        targetRoot: root,
        templateDir: _realTemplate(),
        appName: 'bone_shop',
      );

      expect(result, isA<RaiseSuccess>());
      final app = '${root.path}/apps/bone_shop';
      const expected = [
        'pubspec.yaml',
        'analysis_options.yaml',
        'web/index.html',
        'web/manifest.json',
        'web/favicon.png',
        'web/icons/Icon-192.png',
        'web/icons/Icon-512.png',
        'web/icons/Icon-maskable-192.png',
        'web/icons/Icon-maskable-512.png',
        'lib/main.dart',
        'lib/src/ui/app_routes.dart',
        'lib/src/ui/home_screen.dart',
        'test/ui/home_screen_test.dart',
        '.kiro/README.md',
        '.kiro/steering/design.md',
        '.kiro/steering/product.md',
        '.kiro/steering/structure.md',
        '.kiro/steering/tech.md',
        '.kiro/hooks/format-analyze-dart-on-save.json',
      ];
      for (final path in expected) {
        expect(File('$app/$path').existsSync(), isTrue, reason: path);
      }
      final files = Directory(app)
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path.substring(app.length + 1))
          .toSet();
      expect(files, expected.toSet());
      expect(
        files.any((p) => p.endsWith('.tmpl')),
        isFalse,
        reason: 'the .tmpl suffix is dropped',
      );
      expect(
        File('$app/pubspec.yaml').readAsStringSync(),
        contains('name: bone_shop'),
      );
      expect(
        File('${root.path}/pubspec.yaml').readAsStringSync(),
        '$_rootPubspec  - apps/bone_shop\n',
      );
    });

    test('leaves pubspec.lock and other pubspecs untouched', () {
      final base = tempRoot();
      final root = _makeRoot(base);
      final result = Raiser().raise(
        targetRoot: root,
        templateDir: _fixtureTemplate(base),
        appName: 'bone_shop',
      );

      expect(result, isA<RaiseSuccess>());
      expect(File('${root.path}/pubspec.lock').readAsStringSync(), _lockText);
      expect(
        File('${root.path}/packages/a/pubspec.yaml').readAsStringSync(),
        _otherPubspec,
      );
    });
  });

  group('existing apps/<name>', () {
    for (final kind in ['directory', 'file', 'symlink']) {
      test('$kind is rejected and left unchanged', () {
        final base = tempRoot();
        final root = _makeRoot(base);
        Directory('${root.path}/apps').createSync();
        final path = '${root.path}/apps/bone_shop';
        switch (kind) {
          case 'directory':
            Directory(path).createSync();
            File('$path/keep.txt').writeAsStringSync('mine');
          case 'file':
            File(path).writeAsStringSync('mine');
          case 'symlink':
            final target = Directory('${base.path}/elsewhere')..createSync();
            File('${target.path}/keep.txt').writeAsStringSync('mine');
            Link(path).createSync(target.path);
        }
        final before = _snapshot(root);

        final result = Raiser().raise(
          targetRoot: root,
          templateDir: _fixtureTemplate(base),
          appName: 'bone_shop',
        );

        expect(result, isA<RaiseFailure>());
        expect((result as RaiseFailure).kind, RaiseErrorKind.folderExists);
        expect(_snapshot(root), before);
        if (kind == 'symlink') {
          expect(
            File('${base.path}/elsewhere/keep.txt').readAsStringSync(),
            'mine',
          );
        }
      });
    }
  });

  test('lost creation race returns folderExists and deletes nothing', () {
    final base = tempRoot();
    final root = _makeRoot(base);
    Directory('${root.path}/apps').createSync();
    final ops = _RacingOps('${root.path}/apps/bone_shop');

    final result = Raiser(ops: ops).raise(
      targetRoot: root,
      templateDir: _fixtureTemplate(base),
      appName: 'bone_shop',
    );

    expect(result, isA<RaiseFailure>());
    expect((result as RaiseFailure).kind, RaiseErrorKind.folderExists);
    expect(ops.deleted, isEmpty);
    expect(
      File('${root.path}/apps/bone_shop/theirs.txt').readAsStringSync(),
      'not ours',
    );
    expect(Directory('${root.path}/apps/bone_shop').listSync(), hasLength(1));
    expect(File('${root.path}/pubspec.yaml').readAsStringSync(), _rootPubspec);
  });

  group('root pubspec problems', () {
    test('missing root pubspec', () {
      final base = tempRoot();
      final root = Directory('${base.path}/root')..createSync();

      final result = Raiser().raise(
        targetRoot: root,
        templateDir: _fixtureTemplate(base),
        appName: 'bone_shop',
      );

      expect(result, isA<RaiseFailure>());
      expect((result as RaiseFailure).kind, RaiseErrorKind.pubspecProblem);
      expect(Directory('${root.path}/apps').existsSync(), isFalse);
    });

    test('no workspace list', () {
      final base = tempRoot();
      const text = 'name: root\nenvironment:\n  sdk: ^3.13.0\n';
      final root = _makeRoot(base, pubspec: text);

      final result = Raiser().raise(
        targetRoot: root,
        templateDir: _fixtureTemplate(base),
        appName: 'bone_shop',
      );

      expect(result, isA<RaiseFailure>());
      expect((result as RaiseFailure).kind, RaiseErrorKind.pubspecProblem);
      expect(File('${root.path}/pubspec.yaml').readAsStringSync(), text);
      expect(Directory('${root.path}/apps').existsSync(), isFalse);
    });

    test('app already listed in the workspace', () {
      final base = tempRoot();
      const text = '$_rootPubspec  - apps/bone_shop\n';
      final root = _makeRoot(base, pubspec: text);

      final result = Raiser().raise(
        targetRoot: root,
        templateDir: _fixtureTemplate(base),
        appName: 'bone_shop',
      );

      expect(result, isA<RaiseFailure>());
      expect((result as RaiseFailure).kind, RaiseErrorKind.pubspecProblem);
      expect(File('${root.path}/pubspec.yaml').readAsStringSync(), text);
      expect(Directory('${root.path}/apps').existsSync(), isFalse);
    });
  });
}
