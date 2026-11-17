import 'dart:io';

import 'template_file.dart';

/// Reads the template folder from disk.
abstract final class TemplateLoader {
  /// Reads every file under [dir], sorted by relative path.
  ///
  /// Paths use `/` on every platform. Throws [FileSystemException] when [dir]
  /// or any file in it cannot be read.
  static List<TemplateFile> load(Directory dir) {
    if (!dir.existsSync()) {
      throw FileSystemException('Template folder not found', dir.path);
    }
    final root = dir.absolute.path;
    final prefixLength = root.endsWith(Platform.pathSeparator)
        ? root.length
        : root.length + 1;
    final files = <TemplateFile>[];
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = entity.absolute.path
          .substring(prefixLength)
          .replaceAll(Platform.pathSeparator, '/');
      files.add(TemplateFile(relative, entity.readAsBytesSync()));
    }
    files.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return files;
  }
}
