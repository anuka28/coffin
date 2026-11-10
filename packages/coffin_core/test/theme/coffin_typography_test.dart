import 'package:coffin_core/src/theme/coffin_color_tokens.dart';
import 'package:coffin_core/src/theme/coffin_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final tokens in [CoffinColorTokens.night, CoffinColorTokens.daylight]) {
    group('CoffinTypography.textTheme (${tokens.name})', () {
      final theme = CoffinTypography.textTheme(tokens);
      final slots = <String, TextStyle?>{
        'displayLarge': theme.displayLarge,
        'displayMedium': theme.displayMedium,
        'displaySmall': theme.displaySmall,
        'headlineLarge': theme.headlineLarge,
        'headlineMedium': theme.headlineMedium,
        'headlineSmall': theme.headlineSmall,
        'titleLarge': theme.titleLarge,
        'titleMedium': theme.titleMedium,
        'titleSmall': theme.titleSmall,
        'bodyLarge': theme.bodyLarge,
        'bodyMedium': theme.bodyMedium,
        'bodySmall': theme.bodySmall,
        'labelLarge': theme.labelLarge,
        'labelMedium': theme.labelMedium,
        'labelSmall': theme.labelSmall,
      };

      test('display and headline use Creepster, others use Outfit', () {
        slots.forEach((name, style) {
          final isDisplay =
              name.startsWith('display') || name.startsWith('headline');
          expect(
            style!.fontFamily,
            isDisplay
                ? 'packages/coffin_core/Creepster'
                : 'packages/coffin_core/Outfit',
            reason: name,
          );
        });
      });

      test('body sizes are at least 14', () {
        for (final style in [
          theme.bodyLarge!,
          theme.bodyMedium!,
          theme.bodySmall!,
        ]) {
          expect(style.fontSize, greaterThanOrEqualTo(14));
        }
      });

      test('no slot has a font fallback', () {
        slots.forEach((name, style) {
          expect(style!.fontFamilyFallback, isNull, reason: name);
        });
      });

      test('bodySmall is muted, all other slots use text color', () {
        slots.forEach((name, style) {
          expect(
            style!.color,
            name == 'bodySmall' ? tokens.muted : tokens.text,
            reason: name,
          );
        });
      });
    });
  }

  testWidgets('missing package font family does not throw', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Text(
          'boo',
          style: TextStyle(fontFamily: 'Nonexistent', package: 'no_such_pkg'),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('boo'), findsOneWidget);
  });
}
