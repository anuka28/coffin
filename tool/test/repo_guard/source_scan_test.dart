import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Requirements 1.3, 11.5.
//
// The generator must not read input, open network connections or sockets, and
// its own source must not name the two apps. Template files are not scanned
// here: they are checked by the template integrity test.

/// The `tool/` package folder, which is the working directory of
/// `flutter test`.
Directory _toolDir() => Directory.current.absolute;

/// Every file under `tool/lib` plus `tool/raise.dart`.
List<File> _sourceFiles() {
  final tool = _toolDir().path;
  final files = <File>[
    ...Directory('$tool/lib')
        .listSync(recursive: true, followLinks: false)
        .whereType<File>(),
    File('$tool/raise.dart'),
  ];
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

/// Lines of [files] that contain any of [needles], as `path:line: text`.
List<String> _hits(List<File> files, List<String> needles) {
  final root = _toolDir().path;
  final hits = <String>[];
  for (final file in files) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      for (final needle in needles) {
        if (lines[i].contains(needle)) {
          final rel = file.path.startsWith('$root/')
              ? file.path.substring(root.length + 1)
              : file.path;
          hits.add('$rel:${i + 1}: [$needle] ${lines[i].trim()}');
        }
      }
    }
  }
  return hits;
}

void main() {
  group('generator source scan', () {
    test('scans real source files', () {
      final files = _sourceFiles();
      expect(File('${_toolDir().path}/raise.dart').existsSync(), isTrue);
      expect(files.length, greaterThan(1));
      expect(
        files.where((f) => f.path.endsWith('coffin_raise.dart')),
        isNotEmpty,
      );
    });

    test('does not read stdin or use the network or sockets', () {
      final hits = _hits(_sourceFiles(), ['stdin', 'HttpClient', 'Socket']);
      expect(hits, isEmpty, reason: hits.join('\n'));
    });

    test('does not name Hauntagotchi or Graveyard', () {
      final hits = _hits(_sourceFiles(), ['Hauntagotchi', 'Graveyard']);
      expect(hits, isEmpty, reason: hits.join('\n'));
    });
  });
}
