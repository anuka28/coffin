import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Creates a unique temporary directory inside the repo, under
/// `tool/.test_tmp/`, and deletes it when the current test finishes.
///
/// The parent folder is created when missing. Must be called from inside a
/// test or `setUp` body, because the cleanup is registered with [addTearDown].
/// Tests run with the package directory (`tool/`) as the working directory.
Directory tempRoot() {
  final parent = Directory(
    '${Directory.current.absolute.path}${Platform.pathSeparator}.test_tmp',
  );
  parent.createSync(recursive: true);
  final dir = parent.createTempSync('raise_test_');
  addTearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
  return dir;
}
