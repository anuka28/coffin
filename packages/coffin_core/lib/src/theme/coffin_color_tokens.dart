import 'dart:ui' show Brightness, Color;

import 'contrast_pair.dart';

/// Named colors for one theme variant.
///
/// Token roles map to the design language: [secondary] is pumpkin,
/// [tertiary] is ectoplasm green and [error] is blood-moon red.
final class CoffinColorTokens {
  /// Creates a token set.
  const CoffinColorTokens({
    required this.name,
    required this.brightness,
    required this.background,
    required this.surface,
    required this.raised,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.error,
    required this.text,
    required this.muted,
    required this.onPrimary,
    required this.onSecondary,
    required this.onTertiary,
    required this.onError,
  });

  /// The moonlit graveyard variant (dark).
  static const CoffinColorTokens night = CoffinColorTokens(
    name: 'night',
    brightness: Brightness.dark,
    background: Color(0xFF0E0B16),
    surface: Color(0xFF1A1525),
    raised: Color(0xFF241C33),
    primary: Color(0xFF9B6BFF),
    secondary: Color(0xFFFF8A3D),
    tertiary: Color(0xFF7CFFB2),
    error: Color(0xFFFF4D6D),
    text: Color(0xFFEDE6F5),
    muted: Color(0xFF9A90AB),
    onPrimary: Color(0xFF0E0B16),
    onSecondary: Color(0xFF0E0B16),
    onTertiary: Color(0xFF0E0B16),
    onError: Color(0xFF0E0B16),
  );

  /// The pale lavender mist variant (light).
  static const CoffinColorTokens daylight = CoffinColorTokens(
    name: 'daylight',
    brightness: Brightness.light,
    background: Color(0xFFF7F3FC),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFEDE5F7),
    primary: Color(0xFF6B3FD4),
    secondary: Color(0xFFA8460A),
    tertiary: Color(0xFF0B6B3A),
    error: Color(0xFFB3173A),
    text: Color(0xFF1A1525),
    muted: Color(0xFF5A5068),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFFFFFFFF),
    onTertiary: Color(0xFFFFFFFF),
    onError: Color(0xFFFFFFFF),
  );

  /// Every built-in variant.
  static const List<CoffinColorTokens> variants = [night, daylight];

  /// Variant name, used in failure reports (`night` or `daylight`).
  final String name;

  /// Whether this variant is dark or light.
  final Brightness brightness;

  /// Page background.
  final Color background;

  /// Card and sheet surface.
  final Color surface;

  /// Raised surface for dialogs and inputs.
  final Color raised;

  /// Primary brand color (ghost-glow purple).
  final Color primary;

  /// Secondary accent (pumpkin).
  final Color secondary;

  /// Tertiary accent (ectoplasm green, for success and alive states).
  final Color tertiary;

  /// Danger color (blood-moon red).
  final Color error;

  /// Main text color (bone white in night).
  final Color text;

  /// Muted text color.
  final Color muted;

  /// Content color drawn on [primary].
  final Color onPrimary;

  /// Content color drawn on [secondary].
  final Color onSecondary;

  /// Content color drawn on [tertiary].
  final Color onTertiary;

  /// Content color drawn on [error].
  final Color onError;

  /// Every text/background combination this set guarantees at 4.5:1.
  ///
  /// Returns 22 pairs: six text-role colors on each of the three surfaces,
  /// plus the four on-color pairs.
  List<ContrastPair> get contrastPairs {
    final foregrounds = <(String, Color)>[
      ('text', text),
      ('muted', muted),
      ('primary', primary),
      ('secondary', secondary),
      ('tertiary', tertiary),
      ('error', error),
    ];
    final backgrounds = <(String, Color)>[
      ('background', background),
      ('surface', surface),
      ('raised', raised),
    ];
    final fills = <(String, Color, String, Color)>[
      ('onPrimary', onPrimary, 'primary', primary),
      ('onSecondary', onSecondary, 'secondary', secondary),
      ('onTertiary', onTertiary, 'tertiary', tertiary),
      ('onError', onError, 'error', error),
    ];
    return [
      for (final fg in foregrounds)
        for (final bg in backgrounds)
          ContrastPair(
            foregroundName: fg.$1,
            backgroundName: bg.$1,
            foreground: fg.$2,
            background: bg.$2,
          ),
      for (final f in fills)
        ContrastPair(
          foregroundName: f.$1,
          backgroundName: f.$3,
          foreground: f.$2,
          background: f.$4,
        ),
    ];
  }
}
