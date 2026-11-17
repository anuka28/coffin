import 'dart:convert';
import 'dart:io';

import '../plan/raise_inputs.dart';
import '../plan/raise_outcome.dart';
import '../plan/raise_planner.dart';
import '../template/template_loader.dart';
import '../workspace/workspace_editor.dart';
import 'disk_file_ops.dart';
import 'file_ops.dart';
import 'plan_writer.dart';
import 'raise_error_kind.dart';
import 'raise_result.dart';

/// Raises a new app: reads the facts, plans every file, then writes.
///
/// Composes [TemplateLoader], [RaisePlanner] and [PlanWriter]. It never
/// prints, never calls `exit`, and never reads `Directory.current`.
final class Raiser {
  /// Creates a raiser. Disk access goes through [ops], which defaults to
  /// [DiskFileOps].
  Raiser({FileOps? ops}) : _ops = ops ?? const DiskFileOps();

  final FileOps _ops;

  /// Package names that can never be an app name, on top of the names of the
  /// packages listed in the root workspace.
  static const Set<String> reservedPackageNames = {
    'coffin_core',
    'coffin_raise',
    'flutter',
    'flutter_test',
    'flutter_lints',
    'go_router',
    'hive_ce',
    'hive_ce_flutter',
    'meta',
    'glados',
    'test',
  };

  /// Raises `apps/<appName>` inside [targetRoot] using the files in
  /// [templateDir].
  ///
  /// Returns [RaiseSuccess] or a [RaiseFailure]; never throws for I/O errors.
  /// When it fails, [targetRoot] is left as it was.
  RaiseResult raise({
    required Directory targetRoot,
    required Directory templateDir,
    required String appName,
  }) {
    try {
      return _raise(targetRoot.path, templateDir, appName);
    } on FileSystemException catch (error) {
      final path = error.path;
      final where = (path == null || path.isEmpty) ? '' : ' ($path)';
      return RaiseFailure(
        RaiseErrorKind.ioError,
        '${error.message}$where. Nothing was changed.',
      );
    }
  }

  RaiseResult _raise(String rootPath, Directory templateDir, String appName) {
    final root = rootPath.length > 1 && rootPath.endsWith('/')
        ? rootPath.substring(0, rootPath.length - 1)
        : rootPath;
    final pubspecBytes = _ops.readFile('$root/pubspec.yaml');
    if (pubspecBytes == null) {
      return RaiseFailure(
        RaiseErrorKind.pubspecProblem,
        'There is no pubspec.yaml in $root. Run this from the repo root.',
      );
    }
    final String pubspec;
    try {
      pubspec = utf8.decode(pubspecBytes);
    } on FormatException {
      return const RaiseFailure(
        RaiseErrorKind.pubspecProblem,
        'The root pubspec.yaml is not valid UTF-8 text.',
      );
    }

    final taken = <String>{...reservedPackageNames};
    for (final entry in WorkspaceEditor.entries(pubspec)) {
      final bytes = _ops.readFile('$root/$entry/pubspec.yaml');
      if (bytes == null) continue;
      final match = RegExp(
        r'^name:[ \t]*(\S+)',
        multiLine: true,
      ).firstMatch(utf8.decode(bytes, allowMalformed: true));
      if (match != null) taken.add(match.group(1)!);
    }

    final folderExists =
        RegExp(r'^[a-z0-9_]+$').hasMatch(appName) &&
        _ops.typeOf('$root/apps/$appName') != FileSystemEntityType.notFound;

    final template = TemplateLoader.load(templateDir);
    final outcome = RaisePlanner.plan(
      RaiseInputs(
        appName: appName,
        rootPubspec: pubspec,
        takenNames: taken,
        folderExists: folderExists,
        template: template,
      ),
    );
    switch (outcome) {
      case PlanRejected(:final kind, :final message, :final suggestion):
        return RaiseFailure(kind, message, suggestion: suggestion);
      case PlanReady(:final plan):
        return PlanWriter(_ops)
            .write(plan, targetRoot: root, originalPubspec: pubspecBytes);
    }
  }
}
