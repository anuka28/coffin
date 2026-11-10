import 'dart:io';

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locates the coffin_core package root whatever the working directory is.
Directory _packageRoot() {
  var dir = Directory.current.absolute;
  for (var i = 0; i < 6; i++) {
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
  fail('Could not locate packages/coffin_core from ${Directory.current.path}');
}

String _read(String path) => File(path).readAsStringSync();

/// Only the import/export directive lines of [src] (ignores comments).
String _directives(String src) => src
    .split('\n')
    .where((l) => RegExp(r'^\s*(import|export)\s').hasMatch(l))
    .join('\n');

/// Every `.dart` file under [dir], or none when [dir] does not exist.
List<File> _dartFiles(String dir) {
  final d = Directory(dir);
  if (!d.existsSync()) return const <File>[];
  return d
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

/// Code lines of [file], with `//` comment lines removed.
String _code(File file) => file
    .readAsStringSync()
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  final root = _packageRoot().path;
  final repo = Directory(root).parent.parent.path;
  final router = '$root/lib/src/router';

  group('barrel', () {
    test('exposes the router API through coffin_core.dart only', () {
      expect(const FogMath().maxDrift, 16);
      expect(const FogFrame(opacity: 1, dx: 0, dy: 0, blur: 0).opacity, 1);
      expect(FogRouter.create, isNotNull);
      expect(const NotFoundPage(), isA<Widget>());
      expect(FogTransitionPage<void>(child: const SizedBox()), isNotNull);
      expect(FogTransition, isNotNull);
      expect(
        AppRoute(path: '/', builder: (context, state) => const SizedBox()),
        isA<AppRoute>(),
      );
      // Re-exported go_router names.
      expect(GoRouter, isNotNull);
      expect(GoRouterState, isNotNull);
      // GoRouterHelper is an extension: compiling this proves it is exported.
      void goHome(BuildContext context) => GoRouterHelper(context).go('/');
      expect(goHome, isNotNull);
    });

    test('exports only through show clauses', () {
      final statements = _read('$root/lib/coffin_core.dart')
          .split(';')
          .map((s) => s.trim().split('\n').where((l) => !l.startsWith('///')))
          .map((lines) => lines.join(' ').trim())
          .where((s) => s.startsWith('export '))
          .toList();
      expect(statements, isNotEmpty);
      for (final s in statements) {
        expect(s, contains(' show '), reason: s);
      }
    });

    test('go_router re-exports are limited to the approved names', () {
      final barrel = _read('$root/lib/coffin_core.dart');
      final match = RegExp(
        r"export 'package:go_router/go_router.dart'\s+show\s+([^;]+);",
      ).firstMatch(barrel);
      expect(match, isNotNull);
      final names = match!.group(1)!.split(',').map((s) => s.trim()).toSet();
      expect(names, {'GoRouter', 'GoRouterHelper', 'GoRouterState'});
    });
  });

  group('pure Dart files', () {
    for (final name in <String>['fog_math.dart', 'fog_frame.dart']) {
      test('$name imports nothing from Flutter or dart:ui', () {
        final directives = _directives(_read('$router/$name'));
        expect(directives, isNot(contains('package:flutter/')));
        expect(directives, isNot(contains('dart:ui')));
      });
    }
  });

  group('URL strategy', () {
    final banned = RegExp(
      r'usePathUrlStrategy|setUrlStrategy|setPathUrlStrategy|url_strategy',
    );

    test('coffin_core never sets a URL strategy', () {
      for (final file in _dartFiles('$root/lib')) {
        expect(_code(file), isNot(matches(banned)), reason: file.path);
      }
    });

    test('neither app sets a URL strategy', () {
      for (final app in <String>['hauntagotchi', 'graveyard']) {
        for (final file in _dartFiles('$repo/apps/$app/lib')) {
          expect(_code(file), isNot(matches(banned)), reason: file.path);
        }
      }
    });
  });

  group('package boundaries', () {
    test('coffin_core imports nothing from the apps', () {
      for (final file in _dartFiles('$root/lib')) {
        final directives = _directives(file.readAsStringSync());
        expect(directives, isNot(contains('apps/')), reason: file.path);
        expect(
          directives,
          isNot(contains('package:hauntagotchi')),
          reason: file.path,
        );
        expect(
          directives,
          isNot(contains('package:graveyard')),
          reason: file.path,
        );
      }
    });

    test('the apps do not import each other', () {
      final apps = <String, String>{
        'hauntagotchi': 'package:graveyard',
        'graveyard': 'package:hauntagotchi',
      };
      apps.forEach((app, other) {
        for (final file in _dartFiles('$repo/apps/$app/lib')) {
          expect(
            _directives(file.readAsStringSync()),
            isNot(contains(other)),
            reason: file.path,
          );
        }
      });
    });

    test('coffin_core does not use state, storage or AI packages here', () {
      for (final file in _dartFiles(router)) {
        final directives = _directives(file.readAsStringSync());
        expect(directives, isNot(contains('riverpod')), reason: file.path);
        expect(directives, isNot(contains('hive')), reason: file.path);
      }
    });
  });

  group('dependencies', () {
    test('coffin_core pins go_router to exactly 17.5.0', () {
      expect(
        _read('$root/pubspec.yaml'),
        matches(RegExp(r'^\s+go_router:\s*17\.5\.0\s*$', multiLine: true)),
      );
    });

    test('apps declare no routing or Material package of their own', () {
      for (final app in <String>['hauntagotchi', 'graveyard']) {
        final pubspec = _read('$repo/apps/$app/pubspec.yaml');
        for (final banned in <String>[
          'go_router',
          'material_ui',
          'cupertino_ui',
          'url_strategy',
        ]) {
          expect(pubspec, isNot(contains(banned)), reason: '$app: $banned');
        }
      }
    });

    test('coffin_core declares no packages beyond the approved ones', () {
      final pubspec = _read('$root/pubspec.yaml');
      for (final banned in <String>[
        'material_ui',
        'cupertino_ui',
        'url_strategy',
        'google_fonts',
      ]) {
        expect(pubspec, isNot(contains(banned)), reason: banned);
      }
    });
  });
}
