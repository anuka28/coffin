import 'dart:convert';
import 'dart:io';

import 'package:coffin_raise/src/names/display_names.dart';
import 'package:coffin_raise/src/names/name_validator.dart';
import 'package:coffin_raise/src/plan/raise_inputs.dart';
import 'package:coffin_raise/src/plan/raise_outcome.dart';
import 'package:coffin_raise/src/plan/raise_planner.dart';
import 'package:coffin_raise/src/template/template_file.dart';
import 'package:coffin_raise/src/template/template_loader.dart';
import 'package:glados/glados.dart';

const _pubspec = 'name: x\nenvironment:\n  sdk: ^3.13.0\nworkspace:\n  - a\n';

const String _letters = 'abcdefghijklmnopqrstuvwxyz';
const String _alnum = 'abcdefghijklmnopqrstuvwxyz0123456789';

const List<String> _forbidden = ['Hauntagotchi', 'hauntagotchi', 'Graveyard'];

final RegExp _packageImport = RegExp(r'''package:([a-z0-9_]+)/([^'"\s;]*)''');

extension _AnyAppName on Any {
  /// A valid App_Name built from one to four words joined by single `_`.
  Generator<String> get validAppName {
    final word = combine2(
      choose(_letters.split('')),
      listWithLengthInRange(0, 8, choose(_alnum.split(''))),
      (String first, List<String> rest) => first + rest.join(),
    );
    return listWithLengthInRange(1, 4, word).map((words) {
      final name = words.join('_');
      // Reserved words (for example "if") get a prefix so the name is valid.
      return NameValidator.validate(name) == null ? name : 'app_$name';
    });
  }
}

/// The text of every rendered file that is text, keyed by its final path.
Map<String, String> _renderedText(String name, List<TemplateFile> template) {
  final outcome = RaisePlanner.plan(
    RaiseInputs(appName: name, rootPubspec: _pubspec, template: template),
  );
  expect(outcome, isA<PlanReady>(), reason: 'plan failed for "$name"');
  final files = (outcome as PlanReady).plan.files;
  final text = <String, String>{};
  for (final file in files) {
    try {
      text[file.relativePath] = utf8.decode(file.bytes);
    } on FormatException {
      // Binary file (icons, favicon): nothing to scan.
    }
  }
  return text;
}

void main() {
  final template = TemplateLoader.load(Directory('templates/app'));

  group('Rendered real template properties', () {
    // Feature: raise-app, Property 7: A raised app only names itself and only imports the barrel
    // Validates: Requirements 4.4, 4.9
    Glados(any.validAppName, ExploreConfig(numRuns: 120)).test(
      'rendered app names only itself and imports only the barrel',
      (name) {
        expect(NameValidator.validate(name), isNull, reason: name);
        final display = DisplayNames.displayName(name);
        final text = _renderedText(name, template);

        // Every text file under web/ contains the Display_Name.
        final webText = text.entries.where((e) => e.key.startsWith('web/'));
        expect(webText, isNotEmpty);
        for (final e in webText) {
          expect(e.value, contains(display), reason: e.key);
        }

        // No file names another app.
        for (final e in text.entries) {
          for (final word in _forbidden) {
            expect(e.value, isNot(contains(word)), reason: '${e.key}: $word');
          }
        }

        // Dart files import only allowed packages, and only the barrel.
        final allowed = {'flutter', 'flutter_test', 'coffin_core', name};
        var sawBarrel = false;
        for (final e in text.entries.where((e) => e.key.endsWith('.dart'))) {
          for (final m in _packageImport.allMatches(e.value)) {
            final package = m.group(1)!;
            final rest = m.group(2)!;
            expect(allowed, contains(package), reason: '${e.key}: ${m[0]}');
            if (package == 'coffin_core') {
              expect(rest, 'coffin_core.dart', reason: '${e.key}: ${m[0]}');
              sawBarrel = true;
            }
          }
          expect(e.value, isNot(contains('coffin_core/src/')), reason: e.key);
        }
        expect(sawBarrel, isTrue, reason: 'no file imports the barrel');
      },
    );
  });
}
