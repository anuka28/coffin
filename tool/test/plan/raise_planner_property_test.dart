import 'package:coffin_raise/src/plan/raise_inputs.dart';
import 'package:coffin_raise/src/plan/raise_outcome.dart';
import 'package:coffin_raise/src/plan/raise_planner.dart';
import 'package:coffin_raise/src/raise/raise_error_kind.dart';
import 'package:coffin_raise/src/template/template_file.dart';
import 'package:glados/glados.dart';

const _pubspec = 'name: x\nenvironment:\n  sdk: ^3.13.0\nworkspace:\n  - a\n';

/// Path pieces, hostile and harmless. Only known placeholders appear.
const List<String> _pieces = [
  'lib',
  'web',
  'main.dart',
  'a.txt',
  '..',
  '.',
  '',
  'C:',
  'c:x',
  r'x\y',
  r'..\z',
  '{{package_name}}',
  '{{class_name}}.dart',
];

const List<String> _prefixes = ['', '/', '//', r'\', 'C:/', '../'];

const List<String> _suffixes = ['', '.tmpl', '.png'];

extension _AnyPlan on Any {
  Generator<String> get hostilePath => combine3(
    choose(_prefixes),
    listWithLengthInRange(1, 5, choose(_pieces)),
    choose(_suffixes),
    (String prefix, List<String> parts, String suffix) =>
        '$prefix${parts.join('/')}$suffix',
  );

  Generator<List<String>> get hostilePaths =>
      listWithLengthInRange(1, 5, hostilePath);
}

/// Why [path] is not a safe relative path inside the app folder, or null.
String? _violation(String path) {
  if (path.isEmpty) return 'empty';
  if (path.startsWith('/')) return 'absolute';
  if (path.contains(r'\')) return 'backslash';
  if (RegExp(r'^[A-Za-z]:').hasMatch(path)) return 'drive prefix';
  var depth = 0;
  for (final segment in path.split('/')) {
    if (segment.isEmpty) return 'empty segment';
    if (segment == '..') return 'dot-dot segment';
    if (segment == '.') continue;
    depth++;
  }
  // Resolving "." segments must leave at least one real segment, so the
  // file is inside apps/<n>/ and not the folder itself.
  if (depth == 0) return 'resolves to the app folder itself';
  return null;
}

void main() {
  group('RaisePlanner path safety properties', () {
    // Feature: raise-app, Property 10: Planned paths stay inside the app folder
    // Validates: Requirements 7.2, 7.7
    Glados(any.hostilePaths, ExploreConfig(numRuns: 300)).test(
      'every planned path is safe, otherwise the plan is unsafePath',
      (paths) {
        final template = [
          for (final p in paths) TemplateFile(p, const [104, 105]),
        ];
        final outcome = RaisePlanner.plan(
          RaiseInputs(
            appName: 'bone_shop',
            rootPubspec: _pubspec,
            template: template,
          ),
        );
        switch (outcome) {
          case PlanReady(:final plan):
            for (final file in plan.files) {
              final why = _violation(file.relativePath);
              if (why != null) {
                throw TestFailure(
                  'planned "${file.relativePath}" ($why) from $paths',
                );
              }
            }
          case PlanRejected(:final kind, :final message):
            if (kind != RaiseErrorKind.unsafePath) {
              throw TestFailure(
                'expected unsafePath but got $kind ("$message") for $paths',
              );
            }
        }
      },
    );
  });
}
