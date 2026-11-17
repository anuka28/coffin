import 'dart:convert';

import 'package:coffin_raise/src/plan/raise_inputs.dart';
import 'package:coffin_raise/src/plan/raise_outcome.dart';
import 'package:coffin_raise/src/plan/raise_planner.dart';
import 'package:coffin_raise/src/raise/raise_error_kind.dart';
import 'package:coffin_raise/src/template/placeholder_renderer.dart';
import 'package:coffin_raise/src/template/placeholders.dart';
import 'package:coffin_raise/src/template/render_outcome.dart';
import 'package:coffin_raise/src/template/template_file.dart';
import 'package:glados/glados.dart';

const _pubspec = 'name: x\nenvironment:\n  sdk: ^3.13.0\nworkspace:\n  - a\n';

const List<String> _keyChars = [
  'a',
  'b',
  'c',
  'k',
  'x',
  'z',
  '_',
  'p',
  'n',
  'e',
];

/// Filler text that contains no braces, so it cannot form a marker.
const List<String> _filler = ['', 'hello ', 'line\n', '  ', 'name: x\n'];

/// One generated case: an unknown key placed in a body or in a path.
final class _Case {
  const _Case(this.key, this.laterKey, this.inPath, this.before, this.after);

  final String key;
  final String laterKey;
  final bool inPath;
  final String before;
  final String after;

  @override
  String toString() =>
      '_Case(key: $key, laterKey: $laterKey, inPath: $inPath, '
      'before: "$before", after: "$after")';
}

extension _AnyUnknown on Any {
  /// A well-formed placeholder name that is not in [Placeholders.known].
  Generator<String> get unknownKey =>
      listWithLengthInRange(1, 10, choose(_keyChars)).map((chars) {
        final key = chars.join();
        return Placeholders.known.contains(key) ? '${key}_x' : key;
      });

  Generator<_Case> get unknownCase => combine5(
    unknownKey,
    unknownKey,
    this.bool,
    choose(_filler),
    choose(_filler),
    _Case.new,
  );
}

void main() {
  final renderer = PlaceholderRenderer({
    for (final k in Placeholders.known) k: 'v',
  });

  group('Unknown placeholder properties', () {
    // Feature: raise-app, Property 6: Unknown placeholders are rejected and named
    // Validates: Requirements 3.5
    Glados(
      any.unknownCase,
      ExploreConfig(numRuns: 200),
    ).test('renderer returns the first unknown key', (c) {
      final text =
          '${c.before}{{package_name}}{{${c.key}}}{{${c.laterKey}}}${c.after}';
      final outcome = renderer.render(text);
      expect(outcome, isA<UnknownPlaceholder>());
      expect((outcome as UnknownPlaceholder).key, c.key);
    });

    // Feature: raise-app, Property 6: Unknown placeholders are rejected and named
    // Validates: Requirements 3.5
    Glados(any.unknownCase, ExploreConfig(numRuns: 200)).test(
      'planner fails with templateProblem naming the file and the key',
      (c) {
        const goodPath = 'lib/{{package_name}}.dart.tmpl';
        final badPath = 'lib/{{${c.key}}}.dart.tmpl';
        final body = '${c.before}{{class_name}}{{${c.key}}}${c.after}';
        final bad = c.inPath
            ? TemplateFile(badPath, utf8.encode('plain'))
            : const TemplateFile('lib/bad.dart.tmpl', <int>[]).withBody(body);
        final template = [
          TemplateFile(goodPath, utf8.encode('ok {{display_name}}')),
          bad,
        ];

        final outcome = RaisePlanner.plan(
          RaiseInputs(
            appName: 'bone_shop',
            rootPubspec: _pubspec,
            template: template,
          ),
        );

        expect(outcome, isA<PlanRejected>());
        final rejected = outcome as PlanRejected;
        expect(rejected.kind, RaiseErrorKind.templateProblem);
        expect(rejected.message, contains(bad.relativePath));
        expect(rejected.message, contains(c.key));
      },
    );
  });
}

extension on TemplateFile {
  TemplateFile withBody(String body) =>
      TemplateFile(relativePath, utf8.encode(body));
}
