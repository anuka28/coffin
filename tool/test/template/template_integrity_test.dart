import 'dart:io';

import 'package:coffin_raise/src/template/placeholder_renderer.dart';
import 'package:coffin_raise/src/template/placeholders.dart';
import 'package:coffin_raise/src/template/render_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `tool/` package folder; tests run with it as the working directory.
Directory _toolDir() {
  final cwd = Directory.current;
  if (Directory('${cwd.path}/templates/app').existsSync()) return cwd;
  return Directory('${cwd.path}/tool');
}

final Directory _tool = _toolDir();
final Directory _repo = _tool.parent;
final Directory _templates = Directory('${_tool.path}/templates/app');

File _template(String relative) => File('${_templates.path}/$relative');

List<File> _textTemplates() => _templates
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.tmpl'))
    .toList();

String _render(String text) {
  final renderer = PlaceholderRenderer({
    'package_name': 'bone_shop',
    'display_name': 'Bone Shop',
    'class_name': 'BoneShop',
    'sdk_constraint': _rootSdk(),
  });
  final outcome = renderer.render(text);
  expect(outcome, isA<Rendered>());
  return (outcome as Rendered).text;
}

String _rootSdk() {
  final text = File('${_repo.path}/pubspec.yaml').readAsStringSync();
  final match = RegExp(
    r'^\s{2}sdk:\s*(.+?)\s*$',
    multiLine: true,
  ).firstMatch(text);
  expect(match, isNotNull, reason: 'root pubspec.yaml has no sdk: line');
  return match!.group(1)!;
}

/// Lines of [text] with surrounding whitespace removed and blanks dropped.
List<String> _lines(String text) => text
    .split(RegExp(r'\r?\n'))
    .map((l) => l.trimRight())
    .where((l) => l.trim().isNotEmpty)
    .toList();

void main() {
  group('template integrity', () {
    test('design.md.tmpl equals the repo design.md byte for byte', () {
      final template = _template('.kiro/steering/design.md.tmpl');
      final source = File('${_repo.path}/.kiro/steering/design.md');
      expect(template.readAsBytesSync(), source.readAsBytesSync());
    });

    test('no template contains a banned word', () {
      const banned = [
        'Hauntagotchi',
        'hauntagotchi',
        'Graveyard',
        'séance',
        'habit',
      ];
      for (final file in _textTemplates()) {
        final text = file.readAsStringSync();
        for (final word in banned) {
          expect(
            text.contains(word),
            isFalse,
            reason: '${file.path} contains "$word"',
          );
        }
      }
    });

    test('every placeholder in the templates is known', () {
      for (final file in _textTemplates()) {
        final text = file.readAsStringSync();
        for (final match in Placeholders.pattern.allMatches(text)) {
          expect(
            Placeholders.known,
            contains(match.group(1)),
            reason: '${file.path} uses unknown {{${match.group(1)}}}',
          );
        }
        expect(
          RegExp(r'\{\{(?![a-z_]+\}\})').hasMatch(text),
          isFalse,
          reason: '${file.path} has a malformed {{ marker',
        );
      }
    });

    test('README first how-to-start step is the exact line', () {
      final text = _template('.kiro/README.md.tmpl').readAsStringSync();
      final lines = text.split(RegExp(r'\r?\n'));
      final heading = lines.indexWhere(
        (l) => l.toLowerCase().startsWith('## how to start'),
      );
      expect(heading, isNonNegative);
      final first = lines
          .skip(heading + 1)
          .firstWhere((l) => l.trim().isNotEmpty);
      expect(
        first,
        '1. Open this app\'s folder in Kiro so it loads this .kiro/',
      );
      expect(text, contains('.kiro/specs/'));
    });

    test('rendered pubspec matches Hauntagotchi and the root SDK', () {
      final rendered = _render(
        _template('pubspec.yaml.tmpl').readAsStringSync(),
      );
      final haunt = File('${_repo.path}/apps/hauntagotchi/pubspec.yaml')
          .readAsStringSync();

      for (final prefix in ['  flutter_lints:', '  coffin_core:']) {
        final want = _lines(haunt).where((l) => l.startsWith(prefix));
        final got = _lines(rendered).where((l) => l.startsWith(prefix));
        expect(want, isNotEmpty);
        expect(got.toList(), want.toList());
      }
      // The path line under coffin_core must match too.
      final pathLine = _lines(haunt).firstWhere((l) => l.contains('path:'));
      expect(_lines(rendered), contains(pathLine));

      expect(_lines(rendered), contains('  sdk: ${_rootSdk()}'));

      // Dependencies: only flutter and coffin_core (plus dev: flutter_test,
      // flutter_lints).
      final names = <String, Set<String>>{};
      String? section;
      for (final line in rendered.split('\n')) {
        if (RegExp(r'^[a-z_]+:').hasMatch(line)) {
          section = line.split(':').first;
        } else if (RegExp(r'^  [a-z_]+:').hasMatch(line) && section != null) {
          names
              .putIfAbsent(section, () => {})
              .add(line.trim().split(':').first);
        }
      }
      expect(names['dependencies'], {'flutter', 'coffin_core'});
      expect(names['dev_dependencies'], {'flutter_test', 'flutter_lints'});
    });

    test('steering files have the required headings', () {
      String steering(String name) =>
          _template('.kiro/steering/$name.md.tmpl').readAsStringSync();
      final required = {
        'product': [
          '# Product:',
          '## Name',
          '## What it is',
          "## Who it's for",
          '## Product principles',
          '## Hard rules',
        ],
        'tech': [
          '# Tech Stack & Conventions',
          '## Stack',
          '## Code style',
          '## Testing rules',
          '## Dependencies',
        ],
        'structure': ['# Project Structure', '## Rules'],
      };
      required.forEach((file, headings) {
        final lines = steering(file).split(RegExp(r'\r?\n'));
        for (final heading in headings) {
          expect(
            lines.any((l) => l.startsWith(heading)),
            isTrue,
            reason: '$file.md.tmpl is missing "$heading"',
          );
        }
      });
    });

    test('hook runs dart format lib test', () {
      final hook = _template(
        '.kiro/hooks/format-analyze-dart-on-save.json.tmpl',
      ).readAsStringSync();
      expect(hook, contains('dart format lib test'));
    });
  });
}
