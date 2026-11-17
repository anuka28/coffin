import 'dart:io';

import 'file_ops.dart';

/// The real [FileOps], backed by `dart:io`.
final class DiskFileOps implements FileOps {
  /// Creates a disk-backed [FileOps].
  const DiskFileOps();

  @override
  void createDirectory(String path) => Directory(path).createSync();

  @override
  void createFileExclusive(String path, List<int> bytes) {
    final file = File(path)..createSync(exclusive: true);
    file.writeAsBytesSync(bytes, flush: true);
  }

  @override
  void replaceFile(String path, List<int> bytes) {
    final temp = File('$path.coffin-tmp');
    temp.createSync(exclusive: true);
    try {
      temp.writeAsBytesSync(bytes, flush: true);
      temp.renameSync(path);
    } on Object {
      if (temp.existsSync()) temp.deleteSync();
      rethrow;
    }
  }

  @override
  void deleteFile(String path) => File(path).deleteSync();

  @override
  void deleteEmptyDirectory(String path) => Directory(path).deleteSync();

  @override
  List<int>? readFile(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;
    return file.readAsBytesSync();
  }

  @override
  List<String> listDirectory(String path) => [
    for (final entity in Directory(path).listSync(followLinks: false))
      entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
  ];

  @override
  FileSystemEntityType typeOf(String path) =>
      FileSystemEntity.typeSync(path, followLinks: false);
}
