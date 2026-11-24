import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Locates `apps/graveyard/lib`, whether the test runs from the app folder
/// or from the repository root.
Directory _libDir() {
  for (final path in const ['lib', 'apps/graveyard/lib']) {
    final dir = Directory(path);
    if (File('${dir.path}/main.dart').existsSync()) return dir;
  }
  throw StateError(
    'Could not find apps/graveyard/lib from ${Directory.current.path}',
  );
}

/// Removes comments, and string literals too when [stripStrings] is true.
///
/// Newlines are kept so line numbers stay valid. Handles `//`, nested
/// `/* */`, single, double, raw and triple-quoted strings.
String _strip(String s, {required bool stripStrings}) {
  final out = StringBuffer();
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    final next = i + 1 < s.length ? s[i + 1] : '';
    if (c == '/' && next == '/') {
      while (i < s.length && s[i] != '\n') {
        i++;
      }
    } else if (c == '/' && next == '*') {
      var depth = 1;
      i += 2;
      while (i < s.length && depth > 0) {
        if (s.startsWith('/*', i)) {
          depth++;
          i += 2;
        } else if (s.startsWith('*/', i)) {
          depth--;
          i += 2;
        } else {
          if (s[i] == '\n') out.write('\n');
          i++;
        }
      }
    } else if (c == "'" || c == '"') {
      final raw = i > 0 && s[i - 1] == 'r';
      final triple = s.startsWith(c * 3, i);
      final quote = triple ? c * 3 : c;
      final start = i;
      i += quote.length;
      while (i < s.length && !s.startsWith(quote, i)) {
        if (!raw && s[i] == '\\') i++;
        if (!triple && i < s.length && s[i] == '\n') break;
        i++;
      }
      i = (i + quote.length).clamp(0, s.length);
      final literal = s.substring(start, i);
      if (stripStrings) {
        out.write('\n' * '\n'.allMatches(literal).length);
      } else {
        out.write(literal);
      }
    } else {
      out.write(c);
      i++;
    }
  }
  return out.toString();
}

final RegExp _hashCodeAccess = RegExp(r'\.hashCode\b');

/// Returns the 1-based line numbers where [source] reads `.hashCode`.
///
/// Comments and string literals are ignored. A declaration such as
/// `int get hashCode => ...` has no leading dot, so it is not flagged.
List<int> hashCodeViolations(String source) {
  final code = _strip(source, stripStrings: true);
  final lines = code.split('\n');
  return [
    for (var n = 0; n < lines.length; n++)
      if (_hashCodeAccess.hasMatch(lines[n])) n + 1,
  ];
}

String _name(File file) => file.uri.pathSegments.last;

List<File> _dartFiles(Directory root) => [
  for (final e in root.listSync(recursive: true))
    if (e is File && e.path.endsWith('.dart')) e,
];

/// `path:line` for every line of [files] whose code (comments removed)
/// matches [pattern].
List<String> _matches(Iterable<File> files, RegExp pattern) {
  final found = <String>[];
  for (final file in files) {
    final lines = _strip(
      file.readAsStringSync(),
      stripStrings: false,
    ).split('\n');
    for (var n = 0; n < lines.length; n++) {
      if (pattern.hasMatch(lines[n])) found.add('${file.path}:${n + 1}');
    }
  }
  return found;
}

void main() {
  final lib = _libDir();
  final scene = Directory('${lib.path}/src/domain/scene');
  final ui = Directory('${lib.path}/src/ui');

  group('hashing rule self-check', () {
    test('allows a hashCode declaration', () {
      expect(
        hashCodeViolations('int get hashCode => Object.hash(a, b);'),
        isEmpty,
      );
    });

    test('flags a hashCode member access', () {
      expect(hashCodeViolations('final seed = id.hashCode;'), [1]);
    });

    test('ignores comments and string literals', () {
      const source =
          "// id.hashCode\nfinal a = 'x.hashCode';\n/* y.hashCode */";
      expect(hashCodeViolations(source), isEmpty);
    });
  });

  group('scene domain sources', () {
    final sceneFiles = _dartFiles(scene);

    test('the scene folder has files', () {
      expect(sceneFiles, isNotEmpty);
    });

    test('no String.hashCode read under lib/src/domain/scene', () {
      final found = <String>[];
      for (final file in sceneFiles) {
        for (final line in hashCodeViolations(file.readAsStringSync())) {
          found.add('${file.path}:$line');
        }
      }
      expect(
        found,
        isEmpty,
        reason:
            'String.hashCode differs between runtimes. Use StableHash. '
            'Found at: ${found.join(', ')}',
      );
    });

    const banned = {
      'package:flutter': r'package:flutter\b',
      'dart:ui': r'dart:ui\b',
      'dart:io': r'dart:io\b',
      'dart:html': r'dart:html\b',
      'DateTime.now': r'\bDateTime\s*\.\s*now\b',
    };
    for (final entry in banned.entries) {
      test('no ${entry.key} under lib/src/domain/scene', () {
        final found = _matches(sceneFiles, RegExp(entry.value));
        expect(
          found,
          isEmpty,
          reason:
              'The scene domain must stay pure and deterministic. '
              'Found at: ${found.join(', ')}',
        );
      });
    }

    test('hash and random files do not import dart:math', () {
      const names = {
        'crack_generator.dart',
        'stable_hash.dart',
        'stable_random.dart',
      };
      final files = sceneFiles.where((f) => names.contains(_name(f))).toList();
      expect(files.map(_name).toSet(), names);
      final found = _matches(files, RegExp(r'dart:math\b'));
      expect(
        found,
        isEmpty,
        reason:
            'Use StableRandom, not dart:math. Found at: ${found.join(', ')}',
      );
    });
  });

  group('scene ui sources', () {
    final sceneUi = _dartFiles(ui).where((f) {
      final name = _name(f);
      return name.contains('scene') ||
          name.contains('tombstone') ||
          name.contains('painter') ||
          name == 'arch_epitaph.dart';
    }).toList();

    test('scene and tombstone files are found', () {
      expect(sceneUi, isNotEmpty);
    });

    for (final entry in const {
      'Color(0x': r'\bColor\s*\(\s*0x',
      'Colors.': r'\bColors\s*\.',
    }.entries) {
      test('no ${entry.key} in scene and tombstone files', () {
        final found = _matches(sceneUi, RegExp(entry.value));
        expect(
          found,
          isEmpty,
          reason: 'Colors come from tokens. Found at: ${found.join(', ')}',
        );
      });
    }
  });

  group('lib-wide rules', () {
    final all = _dartFiles(lib);

    test('no import of coffin_core/src', () {
      final found = _matches(all, RegExp(r'coffin_core/src'));
      expect(
        found,
        isEmpty,
        reason:
            'Import package:coffin_core/coffin_core.dart only. '
            'Found at: ${found.join(', ')}',
      );
    });

    test('no import of Hauntagotchi', () {
      final found = _matches(
        all,
        RegExp(r'hauntagotchi', caseSensitive: false),
      );
      expect(
        found,
        isEmpty,
        reason:
            'Apps must not import each other. Found at: ${found.join(', ')}',
      );
    });

    test('grave_tile.dart no longer exists', () {
      final found = all.where((f) => _name(f) == 'grave_tile.dart');
      expect(
        found,
        isEmpty,
        reason: 'GraveTile was replaced by GraveTombstone',
      );
    });
  });
}
