import 'dart:convert';

import 'package:coffin_raise/src/plan/raise_inputs.dart';
import 'package:coffin_raise/src/plan/raise_outcome.dart';
import 'package:coffin_raise/src/plan/raise_planner.dart';
import 'package:coffin_raise/src/raise/raise_error_kind.dart';
import 'package:coffin_raise/src/template/template_file.dart';
import 'package:flutter_test/flutter_test.dart';

const _pubspec = 'name: x\nenvironment:\n  sdk: ^3.13.0\nworkspace:\n  - a\n';

TemplateFile _text(String path, String body) =>
    TemplateFile(path, utf8.encode(body));

RaiseOutcome _plan(List<TemplateFile> files, {String name = 'bone_shop'}) =>
    RaisePlanner.plan(
      RaiseInputs(appName: name, rootPubspec: _pubspec, template: files),
    );

void main() {
  test('renders paths and text, strips .tmpl, edits the root pubspec', () {
    final outcome = _plan([
      _text(
        'lib/{{package_name}}.dart.tmpl',
        '{{class_name}} {{sdk_constraint}}',
      ),
      const TemplateFile('web/icon.png', [1, 2, 3]),
    ]);
    final plan = (outcome as PlanReady).plan;
    expect(plan.files[0].relativePath, 'lib/bone_shop.dart');
    expect(utf8.decode(plan.files[0].bytes), 'BoneShop ^3.13.0');
    expect(plan.files[1].bytes, [1, 2, 3]);
    expect(plan.newRootPubspec, contains('  - apps/bone_shop'));
  });

  test('bad name is invalidName with a suggestion', () {
    final r = _plan([_text('a.tmpl', 'x')], name: 'Bone-Shop') as PlanRejected;
    expect(r.kind, RaiseErrorKind.invalidName);
    expect(r.suggestion, 'bone_shop');
  });

  test('unknown placeholder names file and key', () {
    final r = _plan([_text('a.md.tmpl', '{{nope}}')]) as PlanRejected;
    expect(r.kind, RaiseErrorKind.templateProblem);
    expect(r.message, allOf(contains('a.md.tmpl'), contains('nope')));
  });

  test('path escapes and duplicates are unsafePath', () {
    for (final p in ['../x.tmpl', '/x.tmpl', 'a//b.tmpl', r'a\b.tmpl']) {
      final r = _plan([_text(p, 'x')]) as PlanRejected;
      expect(r.kind, RaiseErrorKind.unsafePath, reason: p);
    }
    final dup = _plan([
      _text('a.tmpl', 'x'),
      const TemplateFile('a', [1]),
    ]);
    expect((dup as PlanRejected).kind, RaiseErrorKind.unsafePath);
  });

  test('missing sdk is pubspecProblem', () {
    final r = RaisePlanner.plan(
      RaiseInputs(
        appName: 'bone_shop',
        rootPubspec: 'workspace:\n  - a\n',
        template: [_text('a.tmpl', 'x')],
      ),
    ) as PlanRejected;
    expect(r.kind, RaiseErrorKind.pubspecProblem);
  });
}
