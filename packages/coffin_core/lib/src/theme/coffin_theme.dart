import 'package:flutter/material.dart';

import 'coffin_color_tokens.dart';
import 'coffin_metrics.dart';
import 'coffin_typography.dart';

/// Material 3 theme factories for Coffin.
abstract final class CoffinTheme {
  /// Night theme built from [CoffinColorTokens.night].
  static ThemeData dark() => _build(CoffinColorTokens.night);

  /// Daylight theme built from [CoffinColorTokens.daylight].
  static ThemeData light() => _build(CoffinColorTokens.daylight);

  static const RoundedRectangleBorder _roundedShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(CoffinMetrics.cornerRadius)),
  );

  static const BorderRadius _radius = BorderRadius.all(
    Radius.circular(CoffinMetrics.cornerRadius),
  );

  static const Size _minTapSize = Size(
    CoffinMetrics.minTapTarget,
    CoffinMetrics.minTapTarget,
  );

  static ThemeData _build(CoffinColorTokens tokens) {
    final ColorScheme scheme = ColorScheme(
      brightness: tokens.brightness,
      primary: tokens.primary,
      onPrimary: tokens.onPrimary,
      secondary: tokens.secondary,
      onSecondary: tokens.onSecondary,
      tertiary: tokens.tertiary,
      onTertiary: tokens.onTertiary,
      error: tokens.error,
      onError: tokens.onError,
      surface: tokens.surface,
      onSurface: tokens.text,
      onSurfaceVariant: tokens.muted,
      outline: tokens.muted,
      outlineVariant: tokens.raised,
      surfaceContainerLowest: tokens.background,
      surfaceContainerLow: tokens.surface,
      surfaceContainer: tokens.surface,
      surfaceContainerHigh: tokens.raised,
      surfaceContainerHighest: tokens.raised,
      surfaceTint: const Color(0x00000000),
      inverseSurface: tokens.text,
      onInverseSurface: tokens.background,
    );

    final TextTheme textTheme = CoffinTypography.textTheme(tokens);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.background,
      textTheme: textTheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      focusColor: tokens.primary.withValues(alpha: 0.12),
      hoverColor: tokens.primary.withValues(alpha: 0.08),
      highlightColor: tokens.primary.withValues(alpha: 0.16),
      splashFactory: InkRipple.splashFactory,
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        shape: _roundedShape,
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.raised,
        elevation: 0,
        shape: _roundedShape,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _buttonStyle(tokens, overlayTint: tokens.onPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _buttonStyle(tokens, overlayTint: tokens.primary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _buttonStyle(
          tokens,
          overlayTint: tokens.primary,
          restingSide: BorderSide(color: tokens.muted),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _buttonStyle(tokens, overlayTint: tokens.primary),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll<Size>(_minTapSize),
          fixedSize: const WidgetStatePropertyAll<Size>(_minTapSize),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: const WidgetStatePropertyAll<OutlinedBorder>(_roundedShape),
          overlayColor: _overlay(tokens.primary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.raised,
        border: _inputBorder(tokens.muted, 1),
        enabledBorder: _inputBorder(tokens.muted, 1),
        focusedBorder: _inputBorder(tokens.primary, 2),
        errorBorder: _inputBorder(tokens.error, 1),
        focusedErrorBorder: _inputBorder(tokens.error, 2),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.background,
        foregroundColor: tokens.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.headlineSmall,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, double width) =>
      OutlineInputBorder(
        borderRadius: _radius,
        borderSide: BorderSide(color: color, width: width),
      );

  static WidgetStateProperty<Color?> _overlay(Color tint) =>
      WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        if (states.contains(WidgetState.pressed)) {
          return tint.withValues(alpha: 0.16);
        }
        if (states.contains(WidgetState.focused)) {
          return tint.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return tint.withValues(alpha: 0.08);
        }
        return null;
      });

  static ButtonStyle _buttonStyle(
    CoffinColorTokens tokens, {
    required Color overlayTint,
    BorderSide? restingSide,
  }) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll<Size>(_minTapSize),
      tapTargetSize: MaterialTapTargetSize.padded,
      shape: const WidgetStatePropertyAll<OutlinedBorder>(_roundedShape),
      overlayColor: _overlay(overlayTint),
      side: WidgetStateProperty.resolveWith<BorderSide?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.focused)) {
          return BorderSide(
            color: tokens.text,
            width: CoffinMetrics.focusRingWidth,
          );
        }
        return restingSide;
      }),
    );
  }
}
