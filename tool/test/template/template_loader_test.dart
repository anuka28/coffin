import 'dart:io';

import 'package:coffin_raise/src/template/placeholder_renderer.dart';
import 'package:coffin_raise/src/template/render_outcome.dart';
import 'package:coffin_raise/src/template/template_loader.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/temp_root.dart';

void _write(Directory root, String relative, List<int> bytes) {
  final file = File('${root.path}/$relative');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
}

void main() {
  group('TemplateLoader', () {
    test('returns files sorted by relative path with / separators', () {
      final root = tempRoot();
      _write(root, 'z.txt', [1]);
      _write(root, 'lib/b.dart.tmpl', [2]);
      _write(root, 'a.txt', [3]);
      _write(root, 'lib/a.dart.tmpl', [4]);

      final paths = TemplateLoader.load(root).map((f) => f.relativePath);

      expect(paths, ['a.txt', 'lib/a.dart.tmpl', 'lib/b.dart.tmpl', 'z.txt']);
    });

    test('keeps binary bytes unchanged, including placeholder-like bytes', () {
      final root = tempRoot();
      final bytes = <int>[
        0x89, 0x50, 0x4e, 0x47, 0x00, 0xff, 0xfe, //
        ...'{{package_name}}'.codeUnits, 0x0d, 0x0a, 0x80,
      ];
      _write(root, 'web/icon.png', bytes);

      final file = TemplateLoader.load(root).single;

      expect(file.bytes, bytes);
      expect(file.isText, isFalse);
    });

    test('marks only .tmpl files as text', () {
      final root = tempRoot();
      _write(root, 'a.dart.tmpl', [1]);
      _write(root, 'b.png', [2]);

      final byPath = {
        for (final f in TemplateLoader.load(root)) f.relativePath: f.isText,
      };

      expect(byPath, {'a.dart.tmpl': true, 'b.png': false});
    });

    test('keeps a placeholder in a path segment as stored', () {
      final root = tempRoot();
      _write(root, 'lib/{{package_name}}/main.dart.tmpl', [1]);

      final file = TemplateLoader.load(root).single;

      expect(file.relativePath, 'lib/{{package_name}}/main.dart.tmpl');
    });

    test('throws FileSystemException when the folder is missing', () {
      final root = tempRoot();
      final missing = Directory('${root.path}/nope');

      expect(
        () => TemplateLoader.load(missing),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('PlaceholderRenderer', () {
    final renderer = PlaceholderRenderer({
      'package_name': 'bone_shop',
      'class_name': 'BoneShop',
    });

    test('replaces a placeholder in a path segment', () {
      final outcome = renderer.render('lib/{{package_name}}/main.dart.tmpl');

      expect(outcome, isA<Rendered>());
      expect((outcome as Rendered).text, 'lib/bone_shop/main.dart.tmpl');
    });

    test('replaces repeated placeholders in text', () {
      final outcome = renderer.render('{{class_name}} {{class_name}}');

      expect((outcome as Rendered).text, 'BoneShop BoneShop');
    });

    test('returns UnknownPlaceholder for an unknown key', () {
      final outcome = renderer.render('a {{package_name}} {{nope}} {{other}}');

      expect(outcome, isA<UnknownPlaceholder>());
      expect((outcome as UnknownPlaceholder).key, 'nope');
    });

    test('returns UnknownPlaceholder for an unknown key in a path', () {
      final outcome = renderer.render('lib/{{mystery}}/x.dart');

      expect((outcome as UnknownPlaceholder).key, 'mystery');
    });
  });
}
