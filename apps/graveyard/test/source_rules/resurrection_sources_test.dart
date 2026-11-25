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
  // Fields whose type holds a record, like `List<(double, double)> _a = ...`.
  if (RegExp(r'\s_\w+\s*(=|;)').hasMatch(line)) return true;
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

/// Body of `dispose` in [source], from its first brace to the closing one.
String _disposeBody(String source) {
  final start = source.indexOf(RegExp(r'void\s+dispose\s*\(\s*\)'));
  if (start < 0) return '';
  final open = source.indexOf('{', start);
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(open, i + 1);
    }
  }
  return source.substring(open);
}

/// Keys indented by two spaces under the top-level [name] of a pubspec.
List<String> _pubspecKeys(List<String> lines, String name) {
  final start = lines.indexWhere((l) => l == '$name:');
  expect(start, greaterThanOrEqualTo(0), reason: name);
  final keys = <String>[];
  for (var i = start + 1; i < lines.length; i++) {
    final l = lines[i];
    if (l.isNotEmpty && !l.startsWith(' ')) break;
    final m = RegExp(r'^  ([a-z_0-9-]+):').firstMatch(l);
    if (m != null) keys.add(m.group(1)!);
  }
  return keys;
}

void main() {
  final lib = _libDir();
  final domainFiles = [
    File('${lib.path}/src/domain/raise_rules.dart'),
    File('${lib.path}/src/domain/living_split.dart'),
    ..._dartFiles(Directory('${lib.path}/src/domain/resurrection')),
  ];
  final uiFiles = [
    for (final name in const [
      'clods_painter',
      'graveyard_clipboard',
      'hand_painter',
      'living_row',
      'repository_link',
      'rest_dialog',
      'resurrection_play',
      'risen_announcement',
    ])
      File('${lib.path}/src/ui/$name.dart'),
  ];
  final playFiles = [
    ...domainFiles.where((f) => f.path.contains('resurrection/')),
    File('${lib.path}/src/ui/clods_painter.dart'),
    File('${lib.path}/src/ui/hand_painter.dart'),
    File('${lib.path}/src/ui/resurrection_play.dart'),
  ];

  group('doc-comment self-check', () {
    test('flags an undocumented public member', () {
      expect(undocumentedMembers('class A {\n  final int x;\n}'), hasLength(1));
    });
  });

  group('resurrection domain sources', () {
    test('every expected file exists', () {
      for (final f in [...domainFiles, ...uiFiles]) {
        expect(f.existsSync(), isTrue, reason: f.path);
      }
      expect(domainFiles.length, greaterThan(2));
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
      'Duration': r'\bDuration\b',
      'Timer': r'\bTimer\b',
      'an import of ui/': r'''^\s*(import|export)\s+['"][^'"]*\bui/''',
    };
    for (final entry in banned.entries) {
      test('no ${entry.key} in the new domain files', () {
        final found = _matches(domainFiles, RegExp(entry.value));
        expect(
          found,
          isEmpty,
          reason: 'The domain must stay pure. Found at: ${found.join(', ')}',
        );
      });
    }

    test('every file has exactly one public class', () {
      for (final file in domainFiles) {
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
      for (final file in domainFiles) {
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

    test('only flutter, coffin_core, http and the app are imported', () {
      final packages = <String>{};
      for (final file in all) {
        final source = _strip(file.readAsStringSync(), stripStrings: false);
        for (final m in RegExp(
          r'''^\s*(?:import|export)\s+['"]package:([a-z_0-9]+)/''',
          multiLine: true,
        ).allMatches(source)) {
          packages.add(m.group(1)!);
        }
      }
      expect(
        packages.difference({'flutter', 'coffin_core', 'http', 'graveyard'}),
        isEmpty,
      );
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
      expect(found, isEmpty, reason: 'Found at: ${found.join(', ')}');
    });
  });

  group('storage rules', () {
    test('grave_codec.dart has no play vocabulary', () {
      final codec = File('${lib.path}/src/data/grave_codec.dart');
      expect(codec.existsSync(), isTrue);
      final found = _matches([
        codec,
      ], RegExp(r'playing|Playing_Set|ResurrectionPlay'));
      expect(found, isEmpty, reason: 'Found at: ${found.join(', ')}');
    });

    test('no play file writes to storage', () {
      final found = _matches(
        playFiles,
        RegExp(
          r'\.(save|persist|store|put|putAll|write|writeAsString)\w*\s*\(|'
          r'\b(Hive|GraveStorage|RecordRepository|SharedPreferences|'
          r'localStorage|sessionStorage)\b',
        ),
      );
      expect(found, isEmpty, reason: 'Found at: ${found.join(', ')}');
    });
  });

  group('pubspec', () {
    test('lists exactly the existing dependencies, no assets or fonts', () {
      final file = File('${lib.path}/../pubspec.yaml');
      final text = file.readAsStringSync();
      final lines = text.split('\n');
      expect(_pubspecKeys(lines, 'dependencies'), [
        'flutter',
        'coffin_core',
        'http',
      ]);
      expect(_pubspecKeys(lines, 'dev_dependencies'), [
        'flutter_test',
        'flutter_lints',
        'glados',
      ]);
      expect(_pubspecKeys(lines, 'flutter'), ['uses-material-design']);
      expect(text, isNot(contains('assets:')));
      expect(text, isNot(contains('fonts:')));
    });
  });

  group('resurrection ui sources', () {
    for (final entry in const {
      'Color(0x': r'\bColor\s*\(\s*0x',
      'Colors.': r'\bColors\s*\.',
    }.entries) {
      test('no ${entry.key} in the new UI files', () {
        final found = _matches(uiFiles, RegExp(entry.value));
        expect(found, isEmpty, reason: 'Found at: ${found.join(', ')}');
      });
    }

    test('no string literal in a Text widget', () {
      final found = _matches(uiFiles, RegExp(r'''\bText\s*\(\s*['"]'''));
      expect(
        found,
        isEmpty,
        reason: 'Copy comes from GraveyardCopy. Found at: ${found.join(', ')}',
      );
    });

    test('ResurrectionPlay.dispose releases every controller and timer', () {
      final source = _strip(
        File('${lib.path}/src/ui/resurrection_play.dart').readAsStringSync(),
        stripStrings: true,
      );
      final fields = RegExp(
        r'^  (?:AnimationController|Timer|Ticker)\??\s+(_?\w+)\s*[;=]',
        multiLine: true,
      ).allMatches(source).map((m) => m.group(1)!).toSet();
      expect(fields, isNotEmpty);
      final body = _disposeBody(source);
      expect(body, isNotEmpty);
      for (final name in fields) {
        expect(
          body,
          matches(RegExp('\\b$name\\??\\.(dispose|cancel)\\(', dotAll: true)),
          reason: 'dispose does not release $name',
        );
      }
    });
  });
}
