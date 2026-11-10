import 'package:coffin_core/src/theme/coffin_color_tokens.dart';
import 'package:coffin_core/src/theme/coffin_theme.dart';
import 'package:coffin_core/src/theme/wcag_contrast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Map<CoffinColorTokens, ThemeData Function()> variants =
      <CoffinColorTokens, ThemeData Function()>{
        CoffinColorTokens.night: CoffinTheme.dark,
        CoffinColorTokens.daylight: CoffinTheme.light,
      };

  const BorderRadius radius16 = BorderRadius.all(Radius.circular(16));

  int rgb(Color c) => c.toARGB32() & 0x00FFFFFF;

  variants.forEach((CoffinColorTokens tokens, ThemeData Function() build) {
    group('CoffinTheme ${tokens.name}', () {
      final ThemeData theme = build();

      test('uses Material 3, brightness and scaffold background', () {
        expect(theme.useMaterial3, isTrue);
        expect(theme.brightness, tokens.brightness);
        expect(theme.colorScheme.brightness, tokens.brightness);
        expect(theme.scaffoldBackgroundColor, tokens.background);
      });

      test('maps every ColorScheme role to its token', () {
        final ColorScheme s = theme.colorScheme;
        expect(s.primary, tokens.primary);
        expect(s.onPrimary, tokens.onPrimary);
        expect(s.secondary, tokens.secondary);
        expect(s.onSecondary, tokens.onSecondary);
        expect(s.tertiary, tokens.tertiary);
        expect(s.onTertiary, tokens.onTertiary);
        expect(s.error, tokens.error);
        expect(s.onError, tokens.onError);
        expect(s.surface, tokens.surface);
        expect(s.onSurface, tokens.text);
        expect(s.onSurfaceVariant, tokens.muted);
        expect(s.outline, tokens.muted);
        expect(s.outlineVariant, tokens.raised);
        expect(s.surfaceContainerLowest, tokens.background);
        expect(s.surfaceContainerLow, tokens.surface);
        expect(s.surfaceContainer, tokens.surface);
        expect(s.surfaceContainerHigh, tokens.raised);
        expect(s.surfaceContainerHighest, tokens.raised);
        expect(s.surfaceTint.a, 0);
        expect(s.inverseSurface, tokens.text);
        expect(s.onInverseSurface, tokens.background);
      });

      test('uses a 16 px radius on card and dialog', () {
        expect(
          (theme.cardTheme.shape! as RoundedRectangleBorder).borderRadius,
          radius16,
        );
        expect(
          (theme.dialogTheme.shape! as RoundedRectangleBorder).borderRadius,
          radius16,
        );
      });

      final Map<String, ButtonStyle?> buttonStyles = <String, ButtonStyle?>{
        'filled': theme.filledButtonTheme.style,
        'elevated': theme.elevatedButtonTheme.style,
        'outlined': theme.outlinedButtonTheme.style,
        'text': theme.textButtonTheme.style,
        'icon': theme.iconButtonTheme.style,
      };

      buttonStyles.forEach((String name, ButtonStyle? style) {
        test('$name button has 16 px radius and 48x48 minimum size', () {
          expect(style, isNotNull);
          final OutlinedBorder shape = style!.shape!.resolve(<WidgetState>{})!;
          expect((shape as RoundedRectangleBorder).borderRadius, radius16);
          final Size min = style.minimumSize!.resolve(<WidgetState>{})!;
          expect(min.width, greaterThanOrEqualTo(48));
          expect(min.height, greaterThanOrEqualTo(48));
        });

        test('$name button overlays are distinct and non-transparent', () {
          final Color? hovered = style!.overlayColor!.resolve(<WidgetState>{
            WidgetState.hovered,
          });
          final Color? focused = style.overlayColor!.resolve(<WidgetState>{
            WidgetState.focused,
          });
          final Color? pressed = style.overlayColor!.resolve(<WidgetState>{
            WidgetState.pressed,
          });
          for (final Color? c in <Color?>[hovered, focused, pressed]) {
            expect(c, isNotNull);
            expect(c!.a, greaterThan(0));
          }
          expect(<int>{
            hovered!.toARGB32(),
            focused!.toARGB32(),
            pressed!.toARGB32(),
          }, hasLength(3));

          final Color base = name == 'filled'
              ? tokens.onPrimary
              : tokens.primary;
          expect(rgb(hovered), rgb(base));
          expect(rgb(focused), rgb(base));
          expect(rgb(pressed), rgb(base));
        });
      });

      test('focused buttons draw a text-colored ring with >= 3:1 contrast', () {
        for (final ButtonStyle? style in <ButtonStyle?>[
          theme.filledButtonTheme.style,
          theme.elevatedButtonTheme.style,
          theme.outlinedButtonTheme.style,
          theme.textButtonTheme.style,
        ]) {
          final BorderSide? side = style!.side!.resolve(<WidgetState>{
            WidgetState.focused,
          });
          expect(side, isNotNull);
          expect(side!.color, tokens.text);
          for (final Color bg in <Color>[
            tokens.background,
            tokens.surface,
            tokens.raised,
          ]) {
            expect(
              WcagContrast.ratio(side.color.toARGB32(), bg.toARGB32()),
              greaterThanOrEqualTo(3),
            );
          }
        }
      });

      test(
        'input borders use 16 px radius and focused border has contrast',
        () {
          final InputDecorationThemeData input = theme.inputDecorationTheme;
          final List<InputBorder?> borders = <InputBorder?>[
            input.border,
            input.enabledBorder,
            input.focusedBorder,
            input.errorBorder,
            input.focusedErrorBorder,
          ];
          for (final InputBorder? b in borders) {
            expect((b! as OutlineInputBorder).borderRadius, radius16);
          }
          final Color focus =
              (input.focusedBorder! as OutlineInputBorder).borderSide.color;
          expect(
            WcagContrast.ratio(focus.toARGB32(), tokens.raised.toARGB32()),
            greaterThanOrEqualTo(3),
          );
        },
      );

      testWidgets('FilledButton and IconButton render at least 48x48', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Column(
                children: <Widget>[
                  FilledButton(onPressed: () {}, child: const Text('x')),
                  IconButton(
                    onPressed: () {},
                    tooltip: 'icon',
                    icon: const Icon(Icons.add, size: 12),
                  ),
                ],
              ),
            ),
          ),
        );
        for (final Finder f in <Finder>[
          find.byType(FilledButton),
          find.byType(IconButton),
        ]) {
          final Size size = tester.getSize(f);
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }
      });

      test('is deterministic across calls', () {
        final ThemeData again = build();
        expect(again.colorScheme, theme.colorScheme);
        expect(again.textTheme, theme.textTheme);
      });
    });
  });
}
