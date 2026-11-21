// Source scan for the coffin-ai spec. Reads files with dart:io, so this file
// is VM only and is never part of the Chrome run.
//
// This file and the two scanner files are the only files under `test/ai`
// that hold the forbidden words as data, so they are the only exclusions of
// the `test/ai` secrets scan.
@TestOn('vm')
library;

import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';

import 'support/source_scanner.dart';

// ---------------------------------------------------------------------------
// Locations
// ---------------------------------------------------------------------------

/// Locates the coffin_core package root whatever the working directory is.
/// Starts at this test file's location (script and package URI), then falls
/// back to the current directory.
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
final Directory _repo = _pkg.parent.parent;
final String _aiLib = '${_pkg.path}/lib/src/ai';
final String _aiTest = '${_pkg.path}/test/ai';

String _name(File f) => f.uri.pathSegments.last;

String _rel(File f) => f.path.startsWith(_repo.path)
    ? f.path.substring(_repo.path.length + 1)
    : f.path;

List<File> _files(String dir, {bool Function(File)? where}) {
  final d = Directory(dir);
  if (!d.existsSync()) return const <File>[];
  final out =
      d
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => where == null || where(f))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return out;
}

List<File> _dartFiles(String dir) =>
    _files(dir, where: (f) => f.path.endsWith('.dart'));

int _lineCount(String text) => text.split('\n').length;

/// Prints the group summary and asserts the scan was not vacuous.
void _assertScanned(String group, List<File> files, [String note = '']) {
  var lines = 0;
  for (final f in files) {
    lines += _lineCount(f.readAsStringSync());
  }
  // ignore: avoid_print
  print('[scan] $group: ${files.length} files, $lines lines. $note');
  expect(files, isNotEmpty, reason: '$group scanned no files');
  expect(lines, greaterThan(0), reason: '$group scanned no lines');
}

// ---------------------------------------------------------------------------
// Rules under test
// ---------------------------------------------------------------------------

/// Files whose `.hashCode` use is forbidden.
bool _hashCodeFile(String name) =>
    const <String>{
      'offline_coffin_ai.dart',
      'offline_engine.dart',
      'clean_facts.dart',
      'text_rules.dart',
      'seeded_random.dart',
    }.contains(name) ||
    (name.startsWith('template') && name.endsWith('.dart'));

/// Files that may import `dart:async`.
const Set<String> _asyncFiles = <String>{
  'fallback_coffin_ai.dart',
  'ai_timer_factory.dart',
};

final RegExp _directive = RegExp(
  r'''^\s*(import|export|part)\s+(?:'([^']*)'|"([^"]*)")''',
  multiLine: true,
);

/// Directive problems of one AI source file. [siblings] are the file names of
/// `lib/src/ai`.
List<String> _importProblems(String name, String text, Set<String> siblings) {
  final problems = <String>[];
  final code = stripComments(text);
  for (final m in _directive.allMatches(code)) {
    final kind = m[1]!;
    final uri = m[2] ?? m[3]!;
    if (kind == 'part') {
      problems.add('part directive "$uri"');
    } else if (uri == 'dart:core') {
      continue;
    } else if (uri == 'dart:async') {
      if (!_asyncFiles.contains(name)) problems.add('dart:async not allowed');
    } else if (uri == 'package:meta/meta.dart') {
      continue;
    } else if (name == 'offline_engine.dart' &&
        uri == '../common/seeded_random.dart') {
      continue;
    } else if (!uri.contains(':') &&
        !uri.contains('/') &&
        siblings.contains(uri)) {
      continue;
    } else {
      problems.add('$kind "$uri" not allowed');
    }
  }
  return problems;
}

/// A file may import no app: neither by path nor by package name.
final RegExp _appImport = RegExp(
  r'''(?:import|export)\s+['"][^'"]*(?:apps/|package:hauntagotchi|package:graveyard)''',
);

/// The 13 public AI exports of task 11.1.
const Map<String, List<String>> _expectedAiExports = <String, List<String>>{
  'src/ai/ai_fact_keys.dart': <String>['AiFactKeys'],
  'src/ai/ai_fallback_error.dart': <String>['AiFallbackError'],
  'src/ai/ai_issue.dart': <String>['AiIssue'],
  'src/ai/ai_issue_kind.dart': <String>['AiIssueKind'],
  'src/ai/ai_issue_reporter.dart': <String>[
    'AiIssueReporter',
    'discardAiIssues',
  ],
  'src/ai/ai_purpose.dart': <String>['AiPurpose'],
  'src/ai/ai_reply.dart': <String>['AiReply'],
  'src/ai/ai_request.dart': <String>['AiRequest'],
  'src/ai/ai_timer_factory.dart': <String>['AiTimerFactory'],
  'src/ai/coffin_ai.dart': <String>['CoffinAI'],
  'src/ai/fallback_coffin_ai.dart': <String>['FallbackCoffinAI'],
  'src/ai/offline_coffin_ai.dart': <String>['OfflineCoffinAI'],
  'src/ai/reply_source.dart': <String>['ReplySource'],
};

/// Names and file stems that must never be exported.
const List<String> _internalNames = <String>[
  'reportAiIssueSafely',
  'OfflineEngine',
  'ComposedText',
  'ComposePath',
  'TemplateCatalog',
  'TemplateSet',
  'Template',
  'CleanFacts',
  'TextRules',
  'SeededRandom',
  'IdentifierRules',
];

const List<String> _internalFiles = <String>[
  'offline_engine',
  'composed_text',
  'compose_path',
  'template',
  'template_catalog',
  'template_set',
  'clean_facts',
  'text_rules',
  'seeded_random',
  'identifier_rules',
];

/// Non-AI exports the barrel held before this feature. They must stay.
const List<String> _keptExports = <String>[
  'package:go_router/go_router.dart',
  'src/router/app_route.dart',
  'src/router/fog_frame.dart',
  'src/router/fog_math.dart',
  'src/router/fog_router.dart',
  'src/router/fog_transition.dart',
  'src/router/fog_transition_page.dart',
  'src/router/not_found_page.dart',
  'src/storage/hive_flutter_initializer.dart',
  'src/storage/issue_reporter.dart',
  'src/storage/json_map.dart',
  'src/storage/key_validator.dart',
  'src/storage/memory_record_repository.dart',
  'src/storage/migration_hook.dart',
  'src/storage/opened_repository.dart',
  'src/storage/record_codec.dart',
  'src/storage/record_repository.dart',
  'src/storage/storage_event.dart',
  'src/storage/storage_event_kind.dart',
  'src/storage/storage_issue.dart',
  'src/storage/storage_issue_kind.dart',
  'src/storage/storage_opener.dart',
  'src/theme/coffin_color_tokens.dart',
  'src/theme/coffin_glow.dart',
  'src/theme/coffin_metrics.dart',
  'src/theme/coffin_theme.dart',
  'src/theme/coffin_typography.dart',
  'src/theme/contrast_pair.dart',
  'src/theme/wcag_contrast.dart',
  'src/widgets/coffin_mark.dart',
];

/// Problems of a barrel source.
List<String> _barrelProblems(String source) {
  final problems = <String>[];
  final exports = parseBarrelExports(source);
  final ai = exports.where((e) => e.uri.startsWith('src/ai/')).toList();
  for (final e in exports) {
    if (e.uri.contains('/ai/') && !e.uri.startsWith('src/ai/')) {
      problems.add('unexpected AI path ${e.uri}');
    }
    if (e.uri.startsWith('src/ai/')) {
      if (e.shown == null) problems.add('${e.uri} has no show clause');
      if (e.hidden != null) problems.add('${e.uri} uses hide');
    }
    final names = <String>[...?e.shown, ...?e.hidden];
    for (final n in names) {
      if (_internalNames.contains(n)) problems.add('internal name $n exported');
    }
    final stem = e.uri.split('/').last.replaceAll('.dart', '');
    if (e.uri.startsWith('src/ai/') && _internalFiles.contains(stem)) {
      problems.add('internal file ${e.uri} exported');
    }
  }
  final actual = <String, List<String>>{
    for (final e in ai) e.uri: <String>[...?e.shown]..sort(),
  };
  if (ai.length != actual.length) problems.add('duplicate AI export');
  for (final entry in _expectedAiExports.entries) {
    final got = actual[entry.key];
    if (got == null) {
      problems.add('missing export ${entry.key}');
    } else if (got.join(',') != (<String>[...entry.value]..sort()).join(',')) {
      problems.add('${entry.key} shows $got, expected ${entry.value}');
    }
  }
  for (final uri in actual.keys) {
    if (!_expectedAiExports.containsKey(uri)) problems.add('extra export $uri');
  }
  final uris = exports.map((e) => e.uri).toSet();
  for (final kept in _keptExports) {
    if (!uris.contains(kept)) problems.add('lost export $kept');
  }
  return problems;
}

/// A directive that reaches into `package:coffin_core/src/`. Apps may use
/// coffin_core only through its barrel file.
final RegExp _coreSrcDirective = RegExp(
  r'''^\s*(?:import|export)\s+['"]package:coffin_core/src/''',
);

/// What a pubspec may not say about the AI layer. The apps may describe
/// themselves with the letters "AI", so the check looks for API names and
/// paths, not the bare word.
final RegExp _pubspecAiMention = RegExp(
  r'CoffinAI|coffin_ai|src/ai\b|OfflineCoffinAI|FallbackCoffinAI',
  caseSensitive: false,
);

/// Names under `dependencies:` and `dev_dependencies:` of a pubspec.
({Set<String> deps, Set<String> dev}) _dependencyNames(String pubspec) {
  final deps = <String>{};
  final dev = <String>{};
  Set<String>? current;
  for (final line in pubspec.split('\n')) {
    if (RegExp(r'^\S').hasMatch(line)) {
      final key = line.split(':').first.trim();
      current = switch (key) {
        'dependencies' => deps,
        'dev_dependencies' => dev,
        _ => null,
      };
      continue;
    }
    final m = RegExp(r'^  ([A-Za-z0-9_]+)\s*:').firstMatch(line);
    if (m != null) current?.add(m[1]!);
  }
  return (deps: deps, dev: dev);
}

/// Baseline of `coffin_core/pubspec.yaml` at HEAD, task 1.1.
const Set<String> _baselineDeps = <String>{
  'flutter',
  'go_router',
  'hive_ce',
  'hive_ce_flutter',
  'meta',
};
const Set<String> _baselineDevDeps = <String>{
  'flutter_test',
  'flutter_lints',
  'glados',
};

/// Secret and URL rules. A long token is 32 or more hex characters, or 40 or
/// more base64 characters.
final List<ScanRule> _secretRules = <ScanRule>[
  ScanRule('URL', RegExp(r'https?://', caseSensitive: false)),
  ScanRule('sk- key', RegExp(r'(?<![A-Za-z0-9])sk-')),
  ScanRule('AKIA key', RegExp('AKIA')),
  ScanRule('long hex token', RegExp(r'(?<![0-9A-Za-z])[0-9a-fA-F]{32,}')),
  ScanRule('long base64 token', RegExp(r'[A-Za-z0-9+/]{40,}')),
  ScanRule('.env reference', RegExp(r'\.env\b', caseSensitive: false)),
];

/// The only files of `test/ai` left out of the secrets scan: they hold the
/// forbidden words as data.
const Set<String> _secretExclusions = <String>{
  'ai_sources_test.dart',
  'support/source_scanner.dart',
  'support/source_scanner_test.dart',
};

String _expect(List<ScanViolation> v, File f) =>
    v.map((x) => '${_rel(f)}: $x').join('\n');

void main() {
  late Set<String> siblings;
  late List<File> aiFiles;

  setUpAll(() {
    aiFiles = _dartFiles(_aiLib);
    siblings = aiFiles.map(_name).toSet();
  });

  group('forbidden words in lib/src/ai', () {
    test('no file contains a forbidden word, in any letter case', () {
      _assertScanned(
        'forbidden words',
        aiFiles,
        '${forbiddenWords.length} words',
      );
      final bad = <String>[];
      for (final f in aiFiles) {
        bad.add(_expect(findForbiddenWords(f.readAsStringSync()), f));
      }
      expect(bad.where((s) => s.isNotEmpty), isEmpty);
    });

    test('no seedless Random and no Random.secure', () {
      _assertScanned('seedless random', aiFiles);
      final bad = <String>[];
      for (final f in aiFiles) {
        bad.add(
          _expect(scanText(f.readAsStringSync(), seedlessRandomRules), f),
        );
      }
      expect(bad.where((s) => s.isNotEmpty), isEmpty);
    });

    test('no .hashCode access in the generator files', () {
      final files = aiFiles.where((f) => _hashCodeFile(_name(f))).toList();
      _assertScanned('hashCode', files, files.map(_name).join(', '));
      final bad = <String>[];
      for (final f in files) {
        bad.add(_expect(scanText(f.readAsStringSync(), [hashCodeRule]), f));
      }
      expect(bad.where((s) => s.isNotEmpty), isEmpty);
    });
  });

  group('structure of lib/src/ai', () {
    test('each file declares at most one public class', () {
      _assertScanned('class count', aiFiles);
      final bad = <String>[];
      for (final f in aiFiles) {
        final names = publicTypeNames(f.readAsStringSync());
        if (names.length > 1) bad.add('${_rel(f)}: $names');
      }
      expect(bad, isEmpty);
    });

    test('no file imports an app', () {
      _assertScanned('app imports', aiFiles);
      final bad = <String>[
        for (final f in aiFiles)
          if (_appImport.hasMatch(stripComments(f.readAsStringSync()))) _rel(f),
      ];
      expect(bad, isEmpty);
    });

    test('imports are limited to the allowed set', () {
      _assertScanned('imports', aiFiles);
      final bad = <String>[];
      for (final f in aiFiles) {
        for (final p in _importProblems(
          _name(f),
          f.readAsStringSync(),
          siblings,
        )) {
          bad.add('${_rel(f)}: $p');
        }
      }
      expect(bad, isEmpty);
    });
  });

  group('barrel', () {
    test('exports exactly the AI API, keeps the rest, hides internals', () {
      final file = File('${_pkg.path}/lib/coffin_core.dart');
      expect(file.existsSync(), isTrue);
      _assertScanned('barrel', [
        file,
      ], '${_expectedAiExports.length} AI exports');
      expect(_barrelProblems(file.readAsStringSync()), isEmpty);
    });
  });

  group('apps and pubspecs', () {
    test('no app file imports or exports package:coffin_core/src/', () {
      final files = <File>[
        for (final sub in const ['lib', 'test'])
          for (final app in Directory('${_repo.path}/apps').listSync())
            if (app is Directory) ..._dartFiles('${app.path}/$sub'),
      ];
      _assertScanned('apps lib+test directives', files);
      final bad = <String>[];
      for (final f in files) {
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (_coreSrcDirective.hasMatch(lines[i])) {
            bad.add('${_rel(f)}:${i + 1}');
          }
        }
      }
      expect(bad, isEmpty);
    });

    test('app pubspecs do not mention the AI layer', () {
      final files = <File>[
        for (final app in const ['hauntagotchi', 'graveyard'])
          File('${_repo.path}/apps/$app/pubspec.yaml'),
      ];
      for (final f in files) {
        expect(f.existsSync(), isTrue, reason: _rel(f));
      }
      _assertScanned('app pubspecs', files);
      final bad = <String>[
        for (final f in files)
          if (_pubspecAiMention.hasMatch(f.readAsStringSync())) _rel(f),
      ];
      expect(bad, isEmpty);
    });

    test('coffin_core pubspec dependencies equal the baseline', () {
      final f = File('${_pkg.path}/pubspec.yaml');
      _assertScanned('coffin_core pubspec', [f]);
      final got = _dependencyNames(f.readAsStringSync());
      expect(got.deps, equals(_baselineDeps));
      expect(got.dev, equals(_baselineDevDeps));
    });
  });

  group('secrets', () {
    test('lib/src/ai holds no URL, key or token', () {
      _assertScanned('secrets lib/src/ai', aiFiles);
      final bad = <String>[
        for (final f in aiFiles)
          _expect(scanText(f.readAsStringSync(), _secretRules), f),
      ];
      expect(bad.where((s) => s.isNotEmpty), isEmpty);
    });

    test('test/ai holds no URL, key or token', () {
      final all = _dartFiles(_aiTest);
      final files = <File>[
        for (final f in all)
          if (!_secretExclusions.any((e) => f.path.endsWith('/$e'))) f,
      ];
      expect(
        all.length - files.length,
        _secretExclusions.length,
        reason: 'every exclusion must match exactly one file',
      );
      _assertScanned(
        'secrets test/ai',
        files,
        'excluded: ${_secretExclusions.join(', ')}',
      );
      final bad = <String>[
        for (final f in files)
          _expect(scanText(f.readAsStringSync(), _secretRules), f),
      ];
      expect(bad.where((s) => s.isNotEmpty), isEmpty);
    });
  });

  group('self-checks: each rule flags a bad sample', () {
    test('every forbidden word is flagged, in upper case too', () {
      for (final w in forbiddenWords) {
        expect(
          findForbiddenWords('final x = "${w.toUpperCase()}";'),
          isNotEmpty,
          reason: w,
        );
      }
      expect(findForbiddenWords('class SeededRandom {}'), isEmpty);
    });

    test('seedless random rules flag bad samples and spare SeededRandom', () {
      expect(findSeedlessRandom('final r = Random();'), isNotEmpty);
      expect(findSeedlessRandom('final r = Random ( );'), isNotEmpty);
      expect(findSeedlessRandom('final r = Random.secure();'), isNotEmpty);
      expect(findSeedlessRandom('final r = SeededRandom(42);'), isEmpty);
      expect(findSeedlessRandom('final r = SeededRandom();'), isEmpty);
    });

    test('hashCode rule flags member access', () {
      expect(findHashCode('final h = name.hashCode;'), isNotEmpty);
      expect(findHashCode('int get hashCode => 1;'), isEmpty);
    });

    test('hashCode file selection', () {
      for (final n in const [
        'offline_coffin_ai.dart',
        'offline_engine.dart',
        'template.dart',
        'template_set.dart',
        'template_catalog.dart',
        'clean_facts.dart',
        'text_rules.dart',
        'seeded_random.dart',
      ]) {
        expect(_hashCodeFile(n), isTrue, reason: n);
      }
      expect(_hashCodeFile('ai_request.dart'), isFalse);
    });

    test('class counter flags two public classes', () {
      expect(countPublicClasses('class A {}\nclass B {}'), 2);
      expect(countPublicClasses('class A {}\nclass _B {}'), 1);
      expect(countPublicClasses('typedef F = void Function();'), 0);
    });

    test('import rules flag bad directives', () {
      const sib = <String>{'a.dart', 'b.dart'};
      expect(_importProblems('a.dart', "import 'dart:io';", sib), isNotEmpty);
      expect(
        _importProblems('a.dart', "import 'dart:async';", sib),
        isNotEmpty,
      );
      expect(
        _importProblems('fallback_coffin_ai.dart', "import 'dart:async';", sib),
        isEmpty,
      );
      expect(
        _importProblems(
          'a.dart',
          "import 'package:flutter/material.dart';",
          sib,
        ),
        isNotEmpty,
      );
      expect(_importProblems('a.dart', "import 'c.dart';", sib), isNotEmpty);
      expect(
        _importProblems(
          'offline_engine.dart',
          "import '../common/seeded_random.dart';",
          sib,
        ),
        isEmpty,
      );
      expect(
        _importProblems(
          'a.dart',
          "import '../common/seeded_random.dart';",
          sib,
        ),
        isNotEmpty,
      );
      expect(
        _importProblems('a.dart', "import '../storage/x.dart';", sib),
        isNotEmpty,
      );
      expect(
        _importProblems(
          'a.dart',
          "import 'package:meta/meta.dart';\nimport 'b.dart';",
          sib,
        ),
        isEmpty,
      );
      expect(
        _appImport.hasMatch("import 'package:hauntagotchi/x.dart';"),
        isTrue,
      );
      expect(_appImport.hasMatch("import 'package:graveyard/x.dart';"), isTrue);
      expect(_appImport.hasMatch("import '../../apps/x/y.dart';"), isTrue);
      expect(_appImport.hasMatch("import 'b.dart';"), isFalse);
    });

    test('barrel check flags bad barrels', () {
      final good = <String>[
        for (final e in _expectedAiExports.entries)
          "export '${e.key}' show ${e.value.join(', ')};",
        for (final k in _keptExports) "export '$k';",
      ].join('\n');
      expect(_barrelProblems(good), isEmpty);
      expect(_barrelProblems(good.replaceAll(' show AiReply', '')), isNotEmpty);
      expect(
        _barrelProblems("$good\nexport 'src/ai/offline_engine.dart' show X;"),
        isNotEmpty,
      );
      expect(
        _barrelProblems("$good\nexport 'src/ai/ai_reply.dart' show TextRules;"),
        isNotEmpty,
      );
      expect(
        _barrelProblems(good.replaceAll("export 'src/ai/ai_reply.dart'", '//')),
        isNotEmpty,
      );
      expect(
        _barrelProblems(
          good.replaceAll("export 'src/router/fog_math.dart'", '//'),
        ),
        isNotEmpty,
      );
      expect(
        _barrelProblems(
          good.replaceAll(
            "export 'src/ai/ai_issue_reporter.dart' show AiIssueReporter, discardAiIssues;",
            "export 'src/ai/ai_issue_reporter.dart' show AiIssueReporter;",
          ),
        ),
        isNotEmpty,
      );
    });

    test('app name scan and pubspec scan flag bad samples', () {
      expect(_pubspecAiMention.hasMatch('  coffin_ai: any'), isTrue);
      expect(_pubspecAiMention.hasMatch('uses OfflineCoffinAI'), isTrue);
      expect(_pubspecAiMention.hasMatch('An AI seance scores it'), isFalse);
    });

    test('core src directive rule flags bad lines and spares the barrel', () {
      expect(
        _coreSrcDirective.hasMatch(
          "import 'package:coffin_core/src/ai/ai_request.dart';",
        ),
        isTrue,
      );
      expect(
        _coreSrcDirective.hasMatch('export "package:coffin_core/src/x.dart";'),
        isTrue,
      );
      expect(
        _coreSrcDirective.hasMatch(
          "import 'package:coffin_core/coffin_core.dart';",
        ),
        isFalse,
      );
    });

    test('dependency parser sees added and removed names', () {
      const base =
          'dependencies:\n  flutter:\n    sdk: flutter\n  meta: 1\n'
          'dev_dependencies:\n  glados: 1\nflutter:\n  uses: true\n';
      final a = _dependencyNames(base);
      expect(a.deps, {'flutter', 'meta'});
      expect(a.dev, {'glados'});
      final b = _dependencyNames(
        base.replaceFirst('  meta: 1\n', '  http: 1\n'),
      );
      expect(b.deps, isNot(equals(a.deps)));
      final c = _dependencyNames(base.replaceFirst('  glados: 1\n', ''));
      expect(c.dev, isNot(equals(a.dev)));
    });

    test('secret rules flag bad samples and spare plain text', () {
      final hex = List.filled(32, 'a').join();
      final b64 = List.filled(40, 'Q').join();
      for (final bad in <String>[
        'see ${'ht'}tp://x.dev',
        'see ${'ht'}tps://x.dev',
        'key = sk-abc123',
        'id AKIAIOSFODNN7EXAMPLE',
        'tok $hex',
        'tok $b64',
        'load .env now',
      ]) {
        expect(scanText(bad, _secretRules), isNotEmpty, reason: bad);
      }
      final shortHex = List.filled(31, 'a').join();
      final shortB64 = List.filled(39, 'Q').join();
      for (final ok in <String>[
        'task-1 and desk-2',
        'a ghost with 31 hex $shortHex',
        'b64 $shortB64',
        'a secret token word',
        'environment',
      ]) {
        expect(scanText(ok, _secretRules), isEmpty, reason: ok);
      }
    });
  });
}
