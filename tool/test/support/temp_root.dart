import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Creates a unique temporary directory and deletes it when the current test
/// finishes.
///
/// Must be called from inside a test or `setUp` body, because the cleanup is
/// registered with [addTearDown].
Directory tempRoot() {
  final dir = Directory.systemTemp.createTempSync('raise_test_');
  addTearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
  return dir;
}
