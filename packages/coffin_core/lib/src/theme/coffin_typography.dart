import 'package:flutter/material.dart' show TextTheme;
import 'package:flutter/painting.dart';

import 'coffin_color_tokens.dart';

/// Font families and text theme for the haunted look.
abstract final class CoffinTypography {
  /// Package that bundles the fonts.
  static const String package = 'coffin_core';

  /// Display and headline family (Creepster).
  static const String displayFamily = 'Creepster';

  /// Body, title and label family (Outfit).
  static const String bodyFamily = 'Outfit';

  /// Full display family name as Flutter resolves it.
  static const String displayFamilyName = 'packages/coffin_core/Creepster';

  /// Full body family name as Flutter resolves it.
  static const String bodyFamilyName = 'packages/coffin_core/Outfit';

  static TextStyle _display(double size, Color color) => TextStyle(
    fontFamily: displayFamily,
    package: package,
    fontSize: size,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: color,
  );

  static TextStyle _body(double size, FontWeight weight, Color color) =>
      TextStyle(
        fontFamily: bodyFamily,
        package: package,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: 0,
        color: color,
      );

  /// Builds the text theme for [tokens]: text color for most slots, muted
  /// for bodySmall.
  static TextTheme textTheme(CoffinColorTokens tokens) {
    final text = tokens.text;
    return TextTheme(
      displayLarge: _display(57, text),
      displayMedium: _display(45, text),
      displaySmall: _display(36, text),
      headlineLarge: _display(32, text),
      headlineMedium: _display(28, text),
      headlineSmall: _display(24, text),
      titleLarge: _body(22, FontWeight.w500, text),
      titleMedium: _body(16, FontWeight.w500, text),
      titleSmall: _body(14, FontWeight.w500, text),
      bodyLarge: _body(16, FontWeight.w400, text),
      bodyMedium: _body(14, FontWeight.w400, text),
      bodySmall: _body(14, FontWeight.w400, tokens.muted),
      labelLarge: _body(14, FontWeight.w500, text),
      labelMedium: _body(12, FontWeight.w500, text),
      labelSmall: _body(11, FontWeight.w500, text),
    );
  }
}
