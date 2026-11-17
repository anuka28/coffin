import 'dart:convert';
import 'dart:io';

import '../plan/raise_plan.dart';
import 'file_ops.dart';
import 'raise_error_kind.dart';
import 'raise_result.dart';

/// Writes a [RaisePlan] to disk through [FileOps], and undoes it on failure.
///
/// Only paths this writer created are ever removed. The root `pubspec.yaml`
/// is replaced last.
final class PlanWriter {
  /// Creates a writer that performs every disk operation through [ops].
  const PlanWriter(this.ops);

  /// The disk operations used for every read and write.
  final FileOps ops;

  /// Writes [plan] under [targetRoot].
  ///
  /// [originalPubspec] holds the bytes of the root `pubspec.yaml` that the plan
  /// was built from. If the file differs just before the final replace, the
  /// raise stops. On any failure the writer restores the root pubspec if a
  /// replace was attempted, deletes the files it created in reverse order, then the
  /// directories it created in reverse order.
  RaiseResult write(
    RaisePlan plan, {
    required String targetRoot,
    required List<int> originalPubspec,
  }) {
    final root = _trimSeparator(targetRoot);
    final appsDir = '$root/apps';
    final appDir = '$appsDir/${plan.appName}';
    final pubspecPath = '$root/pubspec.yaml';
    final createdFiles = <String>[];
    final createdDirs = <String>[];
    var replaceAttempted = false;
    try {
      if (ops.typeOf(appsDir) == FileSystemEntityType.notFound) {
        ops.createDirectory(appsDir);
        createdDirs.add(appsDir);
      }
      ops.createDirectory(appDir);
      if (ops.listDirectory(appDir).isNotEmpty) {
        // Someone else filled it in the gap. Never delete what we did not
        // create. Remove only an `apps/` folder we made ourselves.
        final leftovers = _rollback(
          ops,
          createdFiles: createdFiles,
          createdDirs: createdDirs,
        );
        return RaiseFailure(
          RaiseErrorKind.folderExists,
          'The folder apps/${plan.appName} already exists.'
          '${_leftoverNote(leftovers)}',
        );
      }
      createdDirs.add(appDir);
      for (final file in plan.files) {
        final segments = file.relativePath.split('/');
        var current = appDir;
        for (final dir in segments.take(segments.length - 1)) {
          current = '$current/$dir';
          if (!createdDirs.contains(current)) {
            ops.createDirectory(current);
            createdDirs.add(current);
          }
        }
        final path = '$appDir/${file.relativePath}';
        ops.createFileExclusive(path, file.bytes);
        createdFiles.add(path);
      }
      final now = ops.readFile(pubspecPath);
      if (now == null || !_sameBytes(now, originalPubspec)) {
        throw FileSystemException(
          'pubspec.yaml changed while raising',
          pubspecPath,
        );
      }
      // Set before the call: replaceFile may throw after its rename.
      replaceAttempted = true;
      ops.replaceFile(pubspecPath, _encode(plan.newRootPubspec));
      return RaiseSuccess([
        for (final path in [...createdDirs, ...createdFiles]) path,
      ]);
    } on Object catch (error) {
      final leftovers = <String>[];
      if (replaceAttempted) {
        try {
          ops.replaceFile(pubspecPath, originalPubspec);
        } on Object {
          leftovers.add(pubspecPath);
        }
      }
      leftovers.addAll(
        _rollback(ops, createdFiles: createdFiles, createdDirs: createdDirs),
      );
      return RaiseFailure(
        RaiseErrorKind.ioError,
        '${_describe(error)}${_leftoverNote(leftovers, always: true)}',
      );
    }
  }

  static List<String> _rollback(
    FileOps ops, {
    required List<String> createdFiles,
    required List<String> createdDirs,
  }) {
    final leftovers = <String>[];
    for (final path in createdFiles.reversed) {
      try {
        ops.deleteFile(path);
      } on Object {
        leftovers.add(path);
      }
    }
    for (final path in createdDirs.reversed) {
      try {
        ops.deleteEmptyDirectory(path);
      } on Object {
        leftovers.add(path);
      }
    }
    return leftovers;
  }

  static String _leftoverNote(List<String> leftovers, {bool always = false}) {
    if (leftovers.isEmpty) return always ? ' Nothing was changed.' : '';
    return ' Could not remove: ${leftovers.join(', ')}. '
        'Please delete these by hand.';
  }

  static String _describe(Object error) {
    if (error is FileSystemException) {
      final path = error.path;
      final where = (path == null || path.isEmpty) ? '' : ' ($path)';
      return '${error.message}$where.';
    }
    return '$error.';
  }

  static String _trimSeparator(String path) =>
      path.length > 1 && (path.endsWith('/') || path.endsWith(r'\'))
      ? path.substring(0, path.length - 1)
      : path;

  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static List<int> _encode(String text) => utf8.encode(text);
}
