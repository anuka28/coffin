import 'package:coffin_core/src/theme/coffin_color_tokens.dart';
import 'package:coffin_core/src/widgets/spooky_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_spooky.dart';

void main() {
  group('SpookyTokens.of', () {
    testWidgets('returns night under CoffinTheme.dark()', (tester) async {
      late CoffinColorTokens tokens;
      await pumpSpooky(
        tester,
        Builder(
          builder: (context) {
            tokens = SpookyTokens.of(context);
            return const SizedBox();
          },
        ),
      );
      expect(tokens, same(CoffinColorTokens.night));
    });

    testWidgets('returns daylight under CoffinTheme.light()', (tester) async {
      late CoffinColorTokens tokens;
      await pumpSpooky(
        tester,
        Builder(
          builder: (context) {
            tokens = SpookyTokens.of(context);
            return const SizedBox();
          },
        ),
        brightness: Brightness.light,
      );
      expect(tokens, same(CoffinColorTokens.daylight));
    });

    testWidgets('follows a brightness switch after the theme animation', (
      tester,
    ) async {
      late CoffinColorTokens tokens;
      final probe = Builder(
        builder: (context) {
          tokens = SpookyTokens.of(context);
          return const SizedBox();
        },
      );
      await pumpSpooky(tester, probe);
      expect(tokens, same(CoffinColorTokens.night));
      await pumpSpooky(tester, probe, brightness: Brightness.light);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tokens, same(CoffinColorTokens.daylight));
    });
  });

  group('SpookyTokens.ghostBody', () {
    test('is text in night', () {
      expect(
        SpookyTokens.ghostBody(CoffinColorTokens.night),
        CoffinColorTokens.night.text,
      );
    });

    test('is primary in daylight', () {
      expect(
        SpookyTokens.ghostBody(CoffinColorTokens.daylight),
        CoffinColorTokens.daylight.primary,
      );
    });
  });
}
