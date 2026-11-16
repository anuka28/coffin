// Source scan of the barrel. Reads a file with dart:io, so VM only.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const List<String> _newLines = <String>[
  "export 'src/widgets/crypt_gallery.dart' show CryptGallery;",
  "export 'src/widgets/flicker_text.dart' show FlickerText;",
  "export 'src/widgets/fog_background.dart' show FogBackground;",
  "export 'src/widgets/ghost_loader.dart' show GhostLoader;",
  "export 'src/widgets/ghost_painter.dart' show GhostPainter;",
  "export 'src/widgets/tombstone_card.dart' show TombstoneCard;",
];

const List<String> _internal = <String>[
  'SeededRandom',
  'PingPong',
  'GhostBob',
  'FlickerSchedule',
  'FogParticle',
  'FogDisc',
  'FogField',
  'SpookyTokens',
  'MotionLoop',
  'TombstoneBorder',
  'CryptGalleryPanel',
];

/// The barrel text, resolved relative to this test file.
String _barrel() {
  final File self = File.fromUri(Platform.script);
  final List<Directory> starts = <Directory>[
    Directory.current.absolute,
    if (Platform.script.scheme == 'file') self.parent.absolute,
  ];
  for (final Directory start in starts) {
    Directory dir = start;
    for (int i = 0; i < 8; i++) {
      final File f = File('${dir.path}/lib/coffin_core.dart');
      if (f.existsSync() &&
          File('${dir.path}/test/widgets/widgets_barrel_sources_test.dart')
              .existsSync()) {
        return f.readAsStringSync();
      }
      dir = dir.parent;
    }
  }
  fail('Could not locate packages/coffin_core/lib/coffin_core.dart');
}

/// Export directives, each joined into one string up to its `;`.
List<String> _exports(String text) {
  final List<String> result = <String>[];
  final StringBuffer current = StringBuffer();
  bool open = false;
  for (final String line in text.split('\n')) {
    final String t = line.trim();
    if (!open && t.startsWith('export ')) open = true;
    if (open) {
      if (current.isNotEmpty) current.write(' ');
      current.write(t);
      if (t.endsWith(';')) {
        result.add(current.toString());
        current.clear();
        open = false;
      }
    }
  }
  return result;
}

void main() {
  final String text = _barrel();
  final List<String> exports = _exports(text);

  test('every export uses show', () {
    expect(exports, isNotEmpty);
    for (final String e in exports) {
      expect(e, contains(' show '), reason: e);
    }
  });

  test('the six widget exports are present, in sorted order', () {
    final List<String> lines = text.split('\n').map((l) => l.trim()).toList();
    int previous = -1;
    for (final String expected in _newLines) {
      final int index = lines.indexOf(expected);
      expect(index, greaterThan(previous), reason: expected);
      previous = index;
    }
    final List<String> widgetLines = lines
        .where((l) => l.startsWith("export 'src/widgets/"))
        .toList();
    expect(widgetLines, <String>[
      "export 'src/widgets/coffin_mark.dart' show CoffinMark;",
      ..._newLines,
    ]);
  });

  test('no internal name appears in an export', () {
    for (final String e in exports) {
      for (final String name in _internal) {
        expect(RegExp('\\b$name\\b').hasMatch(e), isFalse, reason: '$name: $e');
      }
    }
  });
}
