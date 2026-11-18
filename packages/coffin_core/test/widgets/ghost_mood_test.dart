// Reads source files with dart:io, so VM only.
@TestOn('vm')
library;

import 'dart:io';

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/src/widgets/ghost_mood.dart').readAsStringSync();
  final barrel = File('lib/coffin_core.dart').readAsStringSync();

  test('has the seven values in order', () {
    expect(GhostMood.values, const [
      GhostMood.thriving,
      GhostMood.content,
      GhostMood.hungry,
      GhostMood.fading,
      GhostMood.dead,
      GhostMood.fed,
      GhostMood.rising,
    ]);
  });

  test('the enum and every value have a doc comment', () {
    final lines = source.split('\n');
    bool documented(String declaration) {
      final i = lines.indexWhere((l) => l.trim() == declaration);
      return i > 0 && lines[i - 1].trim().startsWith('///');
    }

    expect(documented('enum GhostMood {'), isTrue);
    for (final mood in GhostMood.values) {
      expect(documented('${mood.name},'), isTrue, reason: mood.name);
    }
  });

  test('the source does not import Flutter or dart:ui', () {
    expect(source.contains("import 'package:flutter"), isFalse);
    expect(source.contains('dart:ui'), isFalse);
  });

  test('the barrel exports GhostMood right after ghost_loader', () {
    final lines = barrel.split('\n');
    final i = lines.indexOf(
      "export 'src/widgets/ghost_loader.dart' "
      'show GhostLoader;',
    );
    expect(i, greaterThanOrEqualTo(0));
    expect(
      lines[i + 1],
      "export 'src/widgets/ghost_mood.dart' show GhostMood;",
    );
  });

  test('the barrel mentions no later mood files', () {
    for (final name in const [
      'mood_traits',
      'mood_pose',
      'mood_bob',
      'mood_blend',
      'mood_reaction',
      'eye_style',
      'mouth_style',
      'crypt_gallery_moods',
    ]) {
      expect(barrel.contains(name), isFalse, reason: name);
    }
  });
}
