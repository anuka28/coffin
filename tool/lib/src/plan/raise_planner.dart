import 'dart:convert';

import '../names/display_names.dart';
import '../names/name_issue_kind.dart';
import '../names/name_suggester.dart';
import '../names/name_validator.dart';
import '../raise/raise_error_kind.dart';
import '../template/placeholder_renderer.dart';
import '../template/render_outcome.dart';
import '../workspace/workspace_edit_result.dart';
import '../workspace/workspace_editor.dart';
import '../workspace/workspace_problem.dart';
import 'planned_file.dart';
import 'raise_inputs.dart';
import 'raise_outcome.dart';
import 'raise_plan.dart';

/// Runs every check and renders every file before anything is written. Pure.
abstract final class RaisePlanner {
  /// Plans a raise, or says why it cannot happen.
  ///
  /// Order: name validation, root pubspec edit, render of every file and
  /// path, path safety.
  static RaiseOutcome plan(RaiseInputs inputs) {
    final name = inputs.appName;

    final issue = NameValidator.validate(
      name,
      takenNames: inputs.takenNames,
      folderExists: inputs.folderExists,
    );
    if (issue != null) {
      if (issue.kind == NameIssueKind.folderExists) {
        return PlanRejected(RaiseErrorKind.folderExists, issue.reason);
      }
      return PlanRejected(
        RaiseErrorKind.invalidName,
        issue.reason,
        suggestion: NameSuggester.suggest(name, takenNames: inputs.takenNames),
      );
    }

    final edit = WorkspaceEditor.addApp(inputs.rootPubspec, name);
    final String newPubspec;
    switch (edit) {
      case Edited(:final pubspec):
        newPubspec = pubspec;
      case NotEdited(:final problem):
        return PlanRejected(RaiseErrorKind.pubspecProblem, switch (problem) {
          WorkspaceProblem.noWorkspaceList =>
            'The root pubspec.yaml has no workspace list to add to.',
          WorkspaceProblem.alreadyListed =>
            'The root pubspec.yaml already lists apps/$name.',
        });
    }
    final sdk = WorkspaceEditor.sdkConstraint(inputs.rootPubspec);
    if (sdk == null) {
      return const PlanRejected(
        RaiseErrorKind.pubspecProblem,
        'The root pubspec.yaml has no "sdk:" line under "environment:".',
      );
    }

    if (inputs.template.isEmpty) {
      return const PlanRejected(
        RaiseErrorKind.templateProblem,
        'The template folder is empty.',
      );
    }

    final renderer = PlaceholderRenderer({
      'package_name': name,
      'display_name': DisplayNames.displayName(name),
      'class_name': DisplayNames.className(name),
      'sdk_constraint': sdk,
    });

    final files = <PlannedFile>[];
    final seen = <String>{};
    for (final file in inputs.template) {
      final source = file.relativePath;

      final path = renderer.render(source);
      if (path is UnknownPlaceholder) {
        return _unknown(source, path.key);
      }
      var finalPath = (path as Rendered).text;
      if (file.isText && finalPath.endsWith('.tmpl')) {
        finalPath = finalPath.substring(0, finalPath.length - 5);
      }

      final List<int> bytes;
      if (file.isText) {
        final String text;
        try {
          text = utf8.decode(file.bytes);
        } on FormatException {
          return PlanRejected(
            RaiseErrorKind.templateProblem,
            'Template file "$source" is not valid UTF-8 text.',
          );
        }
        final body = renderer.render(text);
        if (body is UnknownPlaceholder) {
          return _unknown(source, body.key);
        }
        bytes = utf8.encode((body as Rendered).text);
      } else {
        bytes = file.bytes;
      }

      final unsafe = _pathProblem(finalPath);
      if (unsafe != null) {
        return PlanRejected(
          RaiseErrorKind.unsafePath,
          'Template file "$source" would be written to "$finalPath": '
          '$unsafe.',
        );
      }
      if (!seen.add(finalPath)) {
        return PlanRejected(
          RaiseErrorKind.unsafePath,
          'Two template files would both be written to "$finalPath".',
        );
      }
      files.add(PlannedFile(finalPath, bytes));
    }

    return PlanReady(
      RaisePlan(appName: name, files: files, newRootPubspec: newPubspec),
    );
  }

  static PlanRejected _unknown(String file, String key) => PlanRejected(
    RaiseErrorKind.templateProblem,
    'Template file "$file" uses the unknown placeholder "{{$key}}".',
  );

  /// Returns why [path] is unsafe, or null when it stays inside the app.
  static String? _pathProblem(String path) {
    if (path.isEmpty) return 'the path is empty';
    if (path.contains('\u0000')) return 'the path contains a NUL character';
    if (path.contains(r'\')) return 'the path contains a backslash';
    if (path.startsWith('/')) return 'the path is absolute';
    if (RegExp(r'^[A-Za-z]:').hasMatch(path)) {
      return 'the path has a drive prefix';
    }
    for (final segment in path.split('/')) {
      if (segment.isEmpty) return 'the path has an empty segment';
      if (segment == '..') return 'the path contains ".."';
    }
    return null;
  }
}
