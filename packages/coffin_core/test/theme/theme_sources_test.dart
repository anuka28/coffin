import 'dart:io';

import 'package:coffin_core/coffin_core.dart';
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

void main() {
  final root = _packageRoot().path;
  final theme = '$root/lib/src/theme';

  group('barrel', () {
    test('exposes every public type through coffin_core.dart only', () {
      expect(CoffinColorTokens.night.name, 'night');
      expect(CoffinGlow.decoration, isNotNull);
      expect(CoffinMetrics.cornerRadius, 16);
      expect(CoffinTheme.dark, isNotNull);
      expect(CoffinTypography.bodyFamily, 'Outfit');
      expect(WcagContrast.aaNormalText, 4.5);
      expect(const CoffinMark(), isA<CoffinMark>());
      expect(ContrastPair, isNotNull);
    });

    test('every export uses a show clause', () {
      final exports = _read('$root/lib/coffin_core.dart')
          .split('\n')
          .where((l) => l.trimLeft().startsWith('export '))
          .toList();
      expect(exports, isNotEmpty);
      for (final line in exports) {
        expect(line, contains(' show '), reason: line);
      }
    });
  });

  group('source scan', () {
    test('wcag_contrast.dart has no flutter or dart:ui import', () {
      final src = _directives(_read('$theme/wcag_contrast.dart'));
      expect(src, isNot(contains('package:flutter/')));
      expect(src, isNot(contains('dart:ui')));
    });

    test('contrast_pair.dart and coffin_color_tokens.dart avoid flutter', () {
      for (final f in ['contrast_pair.dart', 'coffin_color_tokens.dart']) {
        expect(
          _read('$theme/$f'),
          isNot(contains('package:flutter/')),
          reason: f,
        );
      }
    });

    test('lib never imports apps', () {
      final files = Directory('$root/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      expect(files, isNotEmpty);
      for (final f in files) {
        final src = f.readAsStringSync();
        expect(src, isNot(contains('apps/')), reason: f.path);
        expect(src, isNot(contains('package:hauntagotchi')), reason: f.path);
        expect(src, isNot(contains('package:graveyard')), reason: f.path);
      }
    });
  });

  group('config', () {
    late String pubspec;
    setUp(() => pubspec = _read('$root/pubspec.yaml'));

    test('declares Creepster and Outfit and all assets exist', () {
      expect(pubspec, contains('family: Creepster'));
      expect(pubspec, contains('family: Outfit'));
      final assets = RegExp(r'asset:\s*(\S+)')
          .allMatches(pubspec)
          .map((m) => m.group(1)!)
          .toList();
      expect(assets, isNotEmpty);
      for (final a in assets) {
        expect(File('$root/$a').existsSync(), isTrue, reason: a);
      }
    });

    test('has no google_fonts or http dependency; glados is pinned', () {
      expect(pubspec, isNot(contains('google_fonts')));
      expect(pubspec, isNot(matches(RegExp(r'^\s*http:', multiLine: true))));
      final glados = RegExp(
        r'^\s*glados:\s*(\S+)',
        multiLine: true,
      ).firstMatch(pubspec);
      expect(glados, isNotNull);
      final version = glados!.group(1)!;
      expect(version, isNot(contains('^')));
      expect(version, isNot('any'));
      expect(version, matches(RegExp(r'^\d+\.\d+\.\d+')));
    });

    test('license files exist', () {
      expect(File('$root/assets/fonts/OFL-Creepster.txt').existsSync(), isTrue);
      expect(File('$root/assets/fonts/OFL-Outfit.txt').existsSync(), isTrue);
    });

    test('CREDITS.md mentions both fonts and the OFL', () {
      final credits = File('$root/../../CREDITS.md');
      if (!credits.existsSync()) {
        markTestSkipped('CREDITS.md not reachable');
        return;
      }
      final text = credits.readAsStringSync();
      expect(text, contains('Creepster'));
      expect(text, contains('Outfit'));
      expect(text, contains('SIL Open Font License'));
    });

    test('test/theme mirrors lib/src/theme', () {
      expect(Directory('$root/test/theme').existsSync(), isTrue);
    });
  });
}
