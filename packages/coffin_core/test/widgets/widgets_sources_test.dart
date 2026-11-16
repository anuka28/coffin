// Source scan for the spooky-widgets spec. Reads files with dart:io, so this
// file is VM only and is never part of the Chrome run.
//
// Which text each rule sees:
//
// * RAW text (comments included): the `apps/` and app package names, URLs,
//   key patterns, `dart:io` and `package:hive`. A comment must not hold them
//   either.
// * CODE only (comments removed): `Color(0x`, `Colors.`, `Color.fromARGB`,
//   `Color.fromRGBO`, import directives, seedless `Random`, `.hashCode` and
//   the public type counter. A doc comment may talk about them.
@TestOn('vm')
library;

import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Locations
// ---------------------------------------------------------------------------

Directory _packageRoot() {
  final starts = <Directory>[
    if (Platform.script.scheme == 'file')
      File.fromUri(Platform.script).parent.absolute,
    Directory.current.absolute,
  ];
  try {
    final resolved = Isolate.resolvePackageUriSync(
      Uri.parse('package:coffin_core/coffin_core.dart'),
    );
    if (resolved != null && resolved.scheme == 'file') {
      starts.insert(0, File.fromUri(resolved).parent.parent.absolute);
    }
  } on Object {
    // Fall through to the other starting points.
  }
  for (final start in starts) {
    var dir = start;
    for (var i = 0; i < 8; i++) {
      final pubspec = File('${dir.path}/pubspec.yaml');
      if (pubspec.existsSync() &&
          pubspec.readAsStringSync().contains(
            RegExp(r'^name:\s*coffin_core\s*$', multiLine: true),
          )) {
        return dir;
      }
      final nested = Directory('${dir.path}/packages/coffin_core');
      if (nested.existsSync()) return nested;
      dir = dir.parent;
    }
  }
  fail('Could not locate packages/coffin_core from ${Directory.current.path}');
}

final Directory _pkg = _packageRoot();

List<File> _dartFiles(String dir) {
  final d = Directory(dir);
  if (!d.existsSync()) return const <File>[];
  return d
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

String _name(File f) => f.uri.pathSegments.last;

String _rel(File f) => f.path.startsWith(_pkg.path)
    ? f.path.substring(_pkg.path.length + 1)
    : f.path;

void _assertScanned(String group, List<File> files) {
  var lines = 0;
  for (final f in files) {
    lines += f.readAsStringSync().split('\n').length;
  }
  // ignore: avoid_print
  print('[scan] $group: ${files.length} files, $lines lines.');
  expect(files, isNotEmpty, reason: '$group scanned no files');
  expect(lines, greaterThan(0), reason: '$group scanned no lines');
}

// ---------------------------------------------------------------------------
// Scanner
// ---------------------------------------------------------------------------

/// One scan rule.
class _Rule {
  const _Rule(this.name, this.pattern);
  final String name;
  final RegExp pattern;
}

int _lineOf(String text, int offset) {
  var line = 1;
  for (var i = 0; i < offset; i++) {
    if (text.codeUnitAt(i) == 0x0A) line++;
  }
  return line;
}

/// Messages like `name at line N: "match"` for every match of every rule.
List<String> _scan(String text, List<_Rule> rules) => <String>[
  for (final r in rules)
    for (final m in r.pattern.allMatches(text))
      '${r.name} at line ${_lineOf(text, m.start)}: "${m[0]}"',
];

/// Replaces `//` and nested `/* */` comments with spaces, keeps newlines and
/// string contents. A `//` inside a string literal is not a comment.
String _stripComments(String text) {
  final out = StringBuffer();
  final n = text.length;
  var i = 0;
  while (i < n) {
    final c = text[i];
    final next = i + 1 < n ? text[i + 1] : '';
    if (c == '/' && next == '/') {
      while (i < n && text[i] != '\n') {
        out.write(' ');
        i++;
      }
    } else if (c == '/' && next == '*') {
      var depth = 0;
      while (i < n) {
        final a = text[i];
        final b = i + 1 < n ? text[i + 1] : '';
        if (a == '/' && b == '*') {
          depth++;
          out.write('  ');
          i += 2;
        } else if (a == '*' && b == '/') {
          depth--;
          out.write('  ');
          i += 2;
          if (depth == 0) break;
        } else {
          out.write(a == '\n' ? '\n' : ' ');
          i++;
        }
      }
    } else if (c == "'" || c == '"') {
      final raw = i > 0 && text[i - 1] == 'r';
      final triple = text.startsWith(c * 3, i);
      final quote = triple ? c * 3 : c;
      out.write(quote);
      i += quote.length;
      while (i < n && !text.startsWith(quote, i)) {
        final s = text[i];
        if (s == r'\' && !raw && i + 1 < n) {
          out.write('$s${text[i + 1]}');
          i += 2;
          continue;
        }
        if (!triple && s == '\n') break;
        out.write(s);
        i++;
      }
      if (i < n && text.startsWith(quote, i)) {
        out.write(quote);
        i += quote.length;
      }
    } else {
      out.write(c);
      i++;
    }
  }
  return out.toString();
}

// ---------------------------------------------------------------------------
// Rules
// ---------------------------------------------------------------------------

/// Widget rules on RAW text.
final List<_Rule> _widgetRawRules = <_Rule>[
  _Rule('dart:io', RegExp(r'dart:io')),
  _Rule('package:hive', RegExp(r'package:hive')),
  _Rule('apps/', RegExp(r'apps/')),
  _Rule('package:hauntagotchi', RegExp(r'package:hauntagotchi')),
  _Rule('package:graveyard', RegExp(r'package:graveyard')),
  _Rule('URL', RegExp(r'https?://', caseSensitive: false)),
  _Rule('api_key', RegExp(r'api_key', caseSensitive: false)),
  _Rule('apikey', RegExp(r'apikey', caseSensitive: false)),
  _Rule('sk- key', RegExp(r'(?<![A-Za-z0-9])sk-')),
  _Rule('AKIA key', RegExp(r'AKIA')),
  _Rule('bearer', RegExp(r'bearer', caseSensitive: false)),
  _Rule('authorization', RegExp(r'authorization', caseSensitive: false)),
];

/// Widget rules on CODE (comments removed).
final List<_Rule> _widgetCodeRules = <_Rule>[
  _Rule('Color(0x', RegExp(r'Color\s*\(\s*0x')),
  _Rule('Colors.', RegExp(r'(?<![A-Za-z0-9_$])Colors\s*\.')),
  _Rule('Color.fromARGB', RegExp(r'Color\s*\.\s*fromARGB')),
  _Rule('Color.fromRGBO', RegExp(r'Color\s*\.\s*fromRGBO')),
];

/// Forbidden imports for pure files.
final RegExp _pureImport = RegExp(
  r'''^\s*(?:import|export)\s+['"](package:flutter[^'"]*|dart:ui|dart:math|dart:io)['"]''',
  multiLine: true,
);

/// Pure-file rules on CODE (comments removed).
final List<_Rule> _pureCodeRules = <_Rule>[
  _Rule('forbidden import', _pureImport),
  _Rule('seedless Random()', RegExp(r'(?<![A-Za-z0-9_$])Random\s*\(\s*\)')),
  _Rule('Random.secure', RegExp(r'(?<![A-Za-z0-9_$])Random\s*\.\s*secure')),
  _Rule('.hashCode', RegExp(r'\.hashCode\b')),
];

List<String> _widgetProblems(String text) => <String>[
  ..._scan(text, _widgetRawRules),
  ..._scan(_stripComments(text), _widgetCodeRules),
];

List<String> _pureProblems(String text) =>
    _scan(_stripComments(text), _pureCodeRules);

// A public type declaration at the start of a line: any `class` modifier
// combination, `enum`, `mixin` (not `mixin class`, which is a class),
// `extension type` and a named `extension`.
final RegExp _declaration = RegExp(
  r'^[ \t]*(?:@[\w.]+(?:\([^)]*\))?\s+)*(?:'
  r'(?:(?:abstract|base|final|interface|sealed|mixin)\s+)*class\s+([A-Za-z_$][\w$]*)'
  r'|enum\s+([A-Za-z_$][\w$]*)'
  r'|(?:base\s+)?mixin\s+(?!class\b)([A-Za-z_$][\w$]*)'
  r'|extension\s+type\s+(?:const\s+)?([A-Za-z_$][\w$]*)'
  r'|extension\s+(?!type\b)(?!on\b)([A-Za-z_$][\w$]*)'
  r')',
  multiLine: true,
);

/// Blanks string contents so a `class X` inside a string does not count.
String _blankStrings(String code) => code.replaceAllMapped(
  RegExp(
    r"'[^'\n]*'|"
    r'"[^"\n]*"',
  ),
  (m) => ' ' * m[0]!.length,
);

List<String> _publicTypes(String source) {
  final code = _blankStrings(_stripComments(source));
  return <String>[
    for (final m in _declaration.allMatches(code))
      if (!(m[1] ?? m[2] ?? m[3] ?? m[4] ?? m[5]!).startsWith('_'))
        (m[1] ?? m[2] ?? m[3] ?? m[4] ?? m[5]!),
  ];
}

/// The N2 doc line. Lines are joined after removing `///`, so a split over
/// several doc lines also matches.
const String _n2 =
    'Put long body text on an opaque surface, not straight on the fog; '
    'the 4.5:1 guarantee covers up to 4 overlapping blobs.';

bool _hasN2(String source) {
  final doc = source
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.startsWith('///'))
      .map((l) => l.substring(3).trim())
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  return doc.contains(_n2);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late List<File> widgetFiles;
  late List<File> pureFiles;

  setUpAll(() {
    widgetFiles = _dartFiles('${_pkg.path}/lib/src/widgets');
    final seeded = File('${_pkg.path}/lib/src/common/seeded_random.dart');
    pureFiles = <File>[
      ...widgetFiles.where((f) => f.path.contains('/src/widgets/math/')),
      if (seeded.existsSync()) seeded,
    ];
  });

  group('lib/src/widgets', () {
    test('no color literal, app reference, URL or key pattern', () {
      _assertScanned('widget words', widgetFiles);
      final bad = <String>[
        for (final f in widgetFiles)
          for (final p in _widgetProblems(f.readAsStringSync()))
            '${_rel(f)}: $p',
      ];
      expect(bad, isEmpty);
    });

    test('each file declares at most one public type', () {
      _assertScanned('public types', widgetFiles);
      final bad = <String>[
        for (final f in widgetFiles)
          if (_publicTypes(f.readAsStringSync()).length > 1)
            '${_rel(f)}: ${_publicTypes(f.readAsStringSync())}',
      ];
      expect(bad, isEmpty);
    });

    test('fog_background.dart carries the N2 doc line', () {
      final fog = widgetFiles.where((f) => _name(f) == 'fog_background.dart');
      _assertScanned('N2 doc line', fog.toList());
      expect(fog, hasLength(1));
      expect(_hasN2(fog.single.readAsStringSync()), isTrue);
    });
  });

  group('lib/src/widgets/math and lib/src/common', () {
    test(
      'no Flutter, ui, math or io import, no seedless Random, no hashCode',
      () {
        expect(
          pureFiles.any((f) => _name(f) == 'seeded_random.dart'),
          isTrue,
          reason: 'seeded_random.dart missing',
        );
        _assertScanned('pure files', pureFiles);
        final bad = <String>[
          for (final f in pureFiles)
            for (final p in _pureProblems(f.readAsStringSync()))
              '${_rel(f)}: $p',
        ];
        expect(bad, isEmpty);
      },
    );
  });

  group('self-checks', () {
    void flags(List<String> Function(String) scan, String bad, String rule) {
      final found = scan(bad);
      expect(found.any((p) => p.startsWith(rule)), isTrue, reason: bad);
    }

    test('widget rules flag bad samples', () {
      flags(_widgetProblems, 'final c = Color(0xFF000000);', 'Color(0x');
      flags(_widgetProblems, 'final c = Colors.red;', 'Colors.');
      flags(_widgetProblems, 'Color.fromARGB(1, 2, 3, 4)', 'Color.fromARGB');
      flags(_widgetProblems, 'Color.fromRGBO(1, 2, 3, 1)', 'Color.fromRGBO');
      flags(_widgetProblems, "import 'dart:io';", 'dart:io');
      flags(
        _widgetProblems,
        "import 'package:hive/hive.dart';",
        'package:hive',
      );
      flags(_widgetProblems, '// see apps/hauntagotchi', 'apps/');
      flags(_widgetProblems, '// package:hauntagotchi', 'package:hauntagotchi');
      flags(_widgetProblems, '// package:graveyard', 'package:graveyard');
      flags(_widgetProblems, "const u = 'http://x.test';", 'URL');
      flags(_widgetProblems, "const u = 'HTTPS://x.test';", 'URL');
      flags(_widgetProblems, 'const k = api_key;', 'api_key');
      flags(_widgetProblems, 'const k = apiKey;', 'apikey');
      flags(_widgetProblems, "const k = 'sk-abc';", 'sk- key');
      flags(_widgetProblems, "const k = 'AKIAABC';", 'AKIA key');
      flags(_widgetProblems, "const k = 'Bearer x';", 'bearer');
      flags(_widgetProblems, "const k = 'Authorization';", 'authorization');
    });

    test('widget rules pass good samples', () {
      expect(_widgetProblems('final c = tokens.primary;'), isEmpty);
      expect(_widgetProblems('final c = SpookyColors.ok;'), isEmpty);
      expect(_widgetProblems('final risk-free = 1;'), isEmpty);
      expect(_widgetProblems('// Colors. and Color(0x in a comment'), isEmpty);
      expect(_widgetProblems('final c = Color(value);'), isEmpty);
      expect(_widgetProblems('final c = MyColors.red;'), isEmpty);
    });

    test('pure rules flag bad samples', () {
      for (final uri in <String>[
        'package:flutter/material.dart',
        'dart:ui',
        'dart:math',
        'dart:io',
      ]) {
        flags(_pureProblems, "import '$uri';", 'forbidden import');
      }
      flags(_pureProblems, 'final r = Random();', 'seedless Random()');
      flags(_pureProblems, 'final r = Random.secure();', 'Random.secure');
      flags(_pureProblems, 'final h = a.hashCode;', '.hashCode');
    });

    test('pure rules pass good samples', () {
      expect(_pureProblems("import 'ping_pong.dart';"), isEmpty);
      expect(_pureProblems('final h = Object.hash(a, b);'), isEmpty);
      expect(_pureProblems('final r = Random(seed);'), isEmpty);
      expect(_pureProblems("// import 'dart:math'; a.hashCode"), isEmpty);
    });

    test('public type counter', () {
      expect(_publicTypes('class A {}\nclass B {}'), <String>['A', 'B']);
      expect(_publicTypes('abstract final class A {}'), <String>['A']);
      expect(_publicTypes('mixin M {}\nenum E { a }'), <String>['M', 'E']);
      expect(_publicTypes('extension X on int {}'), <String>['X']);
      expect(_publicTypes('class A {}\nclass _P {}'), <String>['A']);
      expect(_publicTypes("// class C {}\nconst s = 'class D {}';"), isEmpty);
    });

    test('N2 check', () {
      expect(_hasN2('/// $_n2\nclass A {}'), isTrue);
      final cut = _n2.indexOf('; ') + 2;
      expect(
        _hasN2('/// ${_n2.substring(0, cut)}\n/// ${_n2.substring(cut)}'),
        isTrue,
      );
      expect(_hasN2('/// Put long body text on the fog.'), isFalse);
      expect(_hasN2('// $_n2'), isFalse);
    });
  });
}
