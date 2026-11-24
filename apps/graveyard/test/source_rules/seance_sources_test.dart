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

/// The head of a declaration: the text before the first `(`, `=`, `;`, `{`
/// or `,`.
String _head(String line) => line.split(RegExp(r'[(=;{,]')).first;

/// True when the declaration on [line] names a private member.
bool _isPrivate(String line) {
  final tokens = _head(line).trim().split(RegExp(r'[\s<>]+'));
  return tokens.isNotEmpty && tokens.last.startsWith('_');
}

/// Public class members (two-space indent) of [source] without a doc comment.
///
/// Members marked `@override` are exempt, they inherit their docs.
List<String> undocumentedMembers(String source) {
  final lines = source.split('\n');
  final found = <String>[];
  for (var n = 0; n < lines.length; n++) {
    final m = RegExp(r'^ {2}(\S.*)$').firstMatch(lines[n]);
    if (m == null) continue;
    final text = m.group(1)!;
    if (RegExp(r'^(//|/\*|\*|\}|\)|\]|@)').hasMatch(text)) continue;
    if (_isPrivate(text)) continue;
    var p = n - 1;
    var overrides = false;
    while (p >= 0 && lines[p].trim().startsWith('@')) {
      if (lines[p].trim() == '@override') overrides = true;
      p--;
    }
    if (overrides) continue;
    if (p < 0 || !lines[p].trim().startsWith('///')) {
      found.add('${n + 1}: ${text.trim()}');
    }
  }
  return found;
}

final RegExp _classDecl = RegExp(
  r'^(abstract |final |sealed |base |interface )*(class|enum|mixin)\b',
);

/// Public top-level declarations of [source], imports and exports excluded.
List<String> publicTopLevel(String source) => [
  for (final line in source.split('\n'))
    if (line.isNotEmpty &&
        !RegExp(r'^[\s/@}\)\]]').hasMatch(line) &&
        !RegExp(r'^(import|export|part|library)\b').hasMatch(line) &&
        !_isPrivate(line))
      line,
];

void main() {
  final lib = _libDir();
  final seanceFiles = _dartFiles(Directory('${lib.path}/src/domain/seance'));
  final uiFiles = [
    File('${lib.path}/src/ui/seance_ai.dart'),
    File('${lib.path}/src/ui/seance_control.dart'),
    File('${lib.path}/src/ui/seance_sheet.dart'),
  ];
  final featureFiles = [...seanceFiles, ...uiFiles];

  group('doc-comment self-check', () {
    test('flags an undocumented public member', () {
      expect(undocumentedMembers('class A {\n  final int x;\n}'), hasLength(1));
    });

    test('accepts documented, private and overriding members', () {
      const source =
          'class A {\n  /// Doc.\n  final int x;\n  final int _y;\n'
          '  @override\n  int get hashCode => 1;\n}';
      expect(undocumentedMembers(source), isEmpty);
    });
  });

  group('seance domain sources', () {
    test('the folder has files and every feature file exists', () {
      expect(seanceFiles, isNotEmpty);
      for (final f in uiFiles) {
        expect(f.existsSync(), isTrue, reason: f.path);
      }
    });

    const banned = {
      'package:flutter': r'package:flutter\b',
      'dart:ui': r'dart:ui\b',
      'dart:io': r'dart:io\b',
      'dart:html': r'dart:html\b',
      'package:coffin_core': r'package:coffin_core\b',
      'package:http': r'package:http\b',
      'package:hive_ce': r'package:hive_ce\b',
      'DateTime.now': r'\bDateTime\s*\.\s*now\b',
      'an import of ui/': r'''^\s*(import|export)\s+['"][^'"]*\bui/''',
      'graveyard_copy.dart': r'graveyard_copy\.dart',
    };
    for (final entry in banned.entries) {
      test('no ${entry.key} under lib/src/domain/seance', () {
        final found = _matches(seanceFiles, RegExp(entry.value));
        expect(
          found,
          isEmpty,
          reason:
              'The séance domain must stay pure. Found at: ${found.join(', ')}',
        );
      });
    }

    test('every file has exactly one public class', () {
      for (final file in seanceFiles) {
        final source = _strip(file.readAsStringSync(), stripStrings: true);
        final decls = publicTopLevel(source);
        expect(
          decls,
          hasLength(1),
          reason: '${file.path} declares: ${decls.join(' | ')}',
        );
        expect(decls.single, matches(_classDecl), reason: file.path);
      }
    });

    test('every public member has a doc comment', () {
      for (final file in seanceFiles) {
        final raw = file.readAsStringSync();
        final lines = raw.split('\n');
        final top = lines.indexWhere(_classDecl.hasMatch);
        expect(top, greaterThan(0), reason: file.path);
        expect(
          lines[top - 1].trim(),
          startsWith('///'),
          reason: '${file.path}: the public class has no doc comment',
        );
        final missing = undocumentedMembers(raw);
        expect(
          missing,
          isEmpty,
          reason: '${file.path} lacks docs at ${missing.join('; ')}',
        );
      }
    });
  });

  group('feature-wide rules', () {
    test('no storage class is referenced', () {
      final found = _matches(
        featureFiles,
        RegExp(r'\b(Hive|RecordRepository|GraveStorage)\b'),
      );
      expect(
        found,
        isEmpty,
        reason: 'The séance never touches storage. Found: ${found.join(', ')}',
      );
    });

    test('no séance data is written', () {
      final found = _matches(
        featureFiles,
        RegExp(
          r'\.(save|persist|store|put|putAll|write|writeAsString)\w*\s*\(|'
          r'\b(SharedPreferences|localStorage|sessionStorage)\b',
        ),
      );
      expect(
        found,
        isEmpty,
        reason: 'Séance results are never saved. Found: ${found.join(', ')}',
      );
    });

    test('grave_codec.dart has no séance vocabulary', () {
      final codec = File('${lib.path}/src/data/grave_codec.dart');
      expect(codec.existsSync(), isTrue);
      final found = _matches([
        codec,
      ], RegExp(r'seance|revival|verdict', caseSensitive: false));
      expect(
        found,
        isEmpty,
        reason:
            'The codec must not know the séance. Found: ${found.join(', ')}',
      );
    });

    test('seance_ai.dart imports coffin_core only via the barrel', () {
      final source = _strip(
        File('${lib.path}/src/ui/seance_ai.dart').readAsStringSync(),
        stripStrings: false,
      );
      final imports = RegExp(r'''['"](package:coffin_core[^'"]*)['"]''')
          .allMatches(source)
          .map((m) => m.group(1))
          .toSet();
      expect(imports, {'package:coffin_core/coffin_core.dart'});
    });
  });

  group('lib-wide rules', () {
    final all = _dartFiles(lib);

    test('no import of coffin_core/src', () {
      final found = _matches(all, RegExp(r'coffin_core/src'));
      expect(found, isEmpty, reason: 'Found at: ${found.join(', ')}');
    });

    test('no import of Hauntagotchi', () {
      final found = _matches(
        all,
        RegExp(r'hauntagotchi', caseSensitive: false),
      );
      expect(found, isEmpty, reason: 'Found at: ${found.join(', ')}');
    });

    test('no state-management package import', () {
      final found = _matches(
        all,
        RegExp(
          r'''['"]package:(provider|flutter_riverpod|riverpod|hooks_riverpod|'''
          r'''flutter_bloc|bloc|get|getx|get_it|mobx|flutter_mobx|redux|'''
          r'''flutter_redux|signals|signals_flutter|stacked|rxdart)/''',
        ),
      );
      expect(
        found,
        isEmpty,
        reason:
            'Use ChangeNotifier and ListenableBuilder. '
            'Found at: ${found.join(', ')}',
      );
    });
  });

  group('seance ui sources', () {
    for (final entry in const {
      'Color(0x': r'\bColor\s*\(\s*0x',
      'Colors.': r'\bColors\s*\.',
    }.entries) {
      test('no ${entry.key} in the séance UI files', () {
        final found = _matches(uiFiles, RegExp(entry.value));
        expect(
          found,
          isEmpty,
          reason: 'Colors come from tokens. Found at: ${found.join(', ')}',
        );
      });
    }
  });
}
