# Design Document

## Overview

The haunted-theme feature gives `coffin_core` its visual foundation: two immutable color token sets (night and daylight), a plain-Dart WCAG contrast utility, `CoffinTheme.dark()` / `CoffinTheme.light()` Material 3 factories, a Creepster + Outfit typography pairing, and a soft-glow `BoxDecoration` helper. Both app placeholder screens adopt the dark theme and show a glowing element.

Key decisions (details in later sections):

- Fonts are bundled in `coffin_core` and declared under `flutter: fonts:`. They are referenced with `fontFamily` plus `package: 'coffin_core'`. **`google_fonts` is dropped** (see "Font strategy decision"). The user approved this, and the matching wording is already in `requirements.md` (see "Requirement impacts").
- Tokens hold `dart:ui` `Color` values. The contrast math is pure Dart on `int` ARGB values. Nothing under `lib/src/theme/` imports `package:flutter/widgets.dart` for tokens or contrast.
- `glados` 1.1.7 is the only new dependency (dev). I resolved it against Flutter 3.47.9 / Dart 3.13 in a throwaway project and ran a two-test smoke file. It passed. I have not yet resolved it inside the real workspace.

### Research summary

| Question | Finding | Source |
|---|---|---|
| How does `google_fonts` find bundled fonts? | It loads `AssetManifest`, scans every asset path ending in `.ttf` or `.otf`, and picks the first whose name (minus extension) ends with the API filename prefix such as `Creepster-Regular`. The folder name is irrelevant. | `google_fonts-6.3.2/lib/src/google_fonts_base.dart` (`loadFontIfNecessary`, `_findFamilyWithVariantAssetPath`) |
| Does it have a package-asset lookup problem? | Not for discovery. The manifest lists dependency assets as `packages/coffin_core/...`, and the suffix match accepts them. The real problems are elsewhere (next rows). | same file |
| What happens on a miss with fetching off? | `loadFontIfNecessary` prints diagnostics and **rethrows**. The caller does `loadingFuture.then(...)` with no error handler, so the failure becomes an unhandled async error. Under `flutter test` that fails the test. This conflicts with Req 5.6 ("continue without throwing"). | same file |
| When is the font ready? | Asynchronously, after the first style resolution. The family name becomes `Creepster_regular`, with the plain family as fallback. Expect a flash of fallback text unless the app waits on `GoogleFonts.pendingFonts()`. | same file (`asTextStyle`) |
| Is the latest version compatible with this SDK? | `google_fonts` 9.0.0 needs Flutter >=3.47.0 and resolves here. 6.3.2 is only in the local pub cache. | pub.dev API |
| How does Flutter resolve package fonts? | `TextStyle(fontFamily: 'X', package: 'p')` stores `packages/p/X`. For a dependency package, the tool rewrites each declared family to `packages/<pkg>/<family>` and each asset URI to `packages/<pkg>/<asset>`. | `flutter/lib/src/painting/text_style.dart` (line 507); `flutter_tools/lib/src/asset.dart` (lines ~980-1005) |
| What does the package font rewrite mean for the package's own tests? | When `coffin_core` is the root package (running its own tests), its families are not prefixed. This only matters if a test needs real glyphs, which it never does (next row). | `asset.dart` logic above |
| What does `flutter test` render with? | The tester is launched with `--use-test-fonts`, so every text style renders with the Ahem font whatever `fontFamily` says. Tests can assert on `TextStyle.fontFamily` strings but never on glyph shapes. | `flutter_tools/lib/src/test/flutter_tester_device.dart` (line 119) |
| Web | Declared fonts end up in `FontManifest.json` and are fetched by the engine. A missing or failed font falls back to the platform font without an exception. I did not read engine source for the exact load timing. The implementation includes a `flutter build web` check of `FontManifest.json` (see Testing Strategy). | Flutter docs on fonts; unverified locally for timing |
| `glados` | 1.1.7 (Dec 2023) is the latest. Its SDK range `<3.0.0` still resolves under Dart 3.13. It exports its own `expect` / `test`, so tests must hide the clashing names from one side. | pub.dev API; local smoke run |

## Font strategy decision

**Chosen: bundle the fonts in `coffin_core`, declare them under `flutter: fonts:`, and reference them with `fontFamily` + `package: 'coffin_core'`. Remove `google_fonts` from the plan.**

Why this is more reliable than `google_fonts` with bundled assets:

1. **No async load, no flash of fallback.** Declared fonts are in `FontManifest.json` and registered by the engine at startup. `google_fonts` loads bytes through `FontLoader` after first use.
2. **No unhandled errors.** If a declared font is missing, the engine falls back silently, which satisfies Req 5.6 by construction. `google_fonts` rethrows from an un-awaited future.
3. **No global mutable state.** `GoogleFonts.config.allowRuntimeFetching` is a global flag that must be set before the first style resolves (Req 5.4). With no `google_fonts`, there is no fetch code path and nothing to configure.
4. **Fewer moving parts.** `google_fonts` pulls `http`, `crypto`, `path_provider` and more into every app, and its Dart code embeds a checksum table for the whole catalogue. We need two families.
5. **Deterministic tests.** `fontFamily` is a plain string (`packages/coffin_core/Creepster`), so tests assert on it directly without stubbing asset bundles or `HttpOverrides`.
6. **Weights are explicit.** Static Outfit files at 400, 500 and 600 are mapped with `weight:` in the pubspec. Flutter picks them with normal font matching.

What `google_fonts` would still offer is a catalogue lookup API we do not need, since the fonts are fixed.

Caveats:

- Font files must be added by hand (download plan in "Credits and license plan"). `google_fonts` would need that too for offline use.
- Creepster covers Latin glyphs only. Other scripts fall back to the platform font. Titles only, so acceptable.
- On Flutter Web, CanvasKit may fetch fallback fonts from a CDN for glyphs no declared font covers. That is an engine setting, not something the theme controls. Req 5.4 only covers the theme's own font loading.

## Requirement impacts

**Status: applied and approved.** The user approved every change below, and `requirements.md` now contains them. This section is a record of what changed. Most changes follow from dropping `google_fonts`. The user's earlier approval of `google_fonts` stays an allowance that we do not use.

Requirement numbers after the update: Req 5 now has 5.7 (no network-requiring font fallback), 5.8 (credits entries), 5.9 (create the credits file if missing) and 5.10 (ship the OFL text). Req 8.1 includes `ContrastPair` and `WcagContrast`. Req 10.6 covers `glados` only.

| Location | Previous text (summary) | Applied in `requirements.md` |
|---|---|---|
| Introduction | "both bundled offline" plus Dependency Approval Notice listing two packages | Typography pairs a spooky display font with a clean body font, both bundled as package assets and declared in the `pubspec.yaml` of `coffin_core`. |
| Dependency Approval Notice | Listed `google_fonts` and `glados`, both approved | Only `glados` is approved for use. Notes that `google_fonts` was approved but is not used, and fonts are declared with `flutter: fonts:`. |
| Glossary | No `Font_Family_Name` entry | Added **Font_Family_Name**: the family string `packages/coffin_core/<family>` produced by `fontFamily` with `package: 'coffin_core'`. |
| Req 5.3 | Bundle fonts, declare in pubspec, and obtain through `google_fonts` | Bundle the font files as assets, declare them under `flutter: fonts:`, and reference them with `fontFamily` and `package: 'coffin_core'`. |
| Req 5.4 | Set `GoogleFonts.config.allowRuntimeFetching` to false | Load both fonts only from bundled assets and depend on no package that fetches fonts at runtime. |
| Req 5.6 / 5.7 | Render with the platform default if a font fails to load | 5.6 keeps that intent. New 5.7: text styles declare no fallback that requires network access (satisfied by leaving `fontFamilyFallback` unset or using platform family names only). |
| Req 5.8 / 5.9 / 5.10 | Credits and license wording in two items | 5.8 records name, author, source URL and license for both fonts. 5.9 creates the credits file if missing. 5.10 ships the OFL 1.1 text with the font files. |
| Req 8.1 | Barrel exports listed without the contrast types | The barrel also exports `ContrastPair` and `WcagContrast`. |
| Req 10.6 | Add `google_fonts` runtime dependency and `glados` dev dependency | Add `glados` as a dev dependency of `coffin_core` with a pinned version, and add no font-fetching dependency. |
| Req 3.3 | Said white on `#9B6BFF` was "about 2.9:1" | Now says bone-white `#EDE6F5` is about 2.9:1 and pure white about 3.5:1 on `#9B6BFF`. Recomputed: bone-white gives 2.90:1 and pure white gives 3.53:1, so both figures are correct. White still fails 4.5:1, so a dark on-color is used. |
| Req 4.6 | Overlay was "a tinted overlay of the primary color" | A primary overlay on a primary-filled button is invisible, so the text now allows "the primary color, or onPrimary on primary-filled buttons". |

Decisions closed: `google_fonts` is dropped, `FilledButton` uses an `onPrimary` overlay, and `ContrastPair` and `WcagContrast` are exported from the barrel.

## Architecture

```mermaid
graph TD
    subgraph coffin_core
        Tokens[CoffinColorTokens<br/>night / daylight]
        Pair[ContrastPair]
        Wcag[WcagContrast<br/>pure Dart on int ARGB]
        Metrics[CoffinMetrics<br/>16px radius, 48px tap]
        Typo[CoffinTypography<br/>Creepster + Outfit]
        Theme[CoffinTheme<br/>dark / light]
        Glow[CoffinGlow]
        Fonts[(assets/fonts/*.ttf<br/>declared in pubspec)]
    end
    Tokens --> Pair --> Wcag
    Tokens --> Theme
    Typo --> Theme
    Metrics --> Theme
    Metrics --> Glow
    Fonts -. packages/coffin_core/... .-> Typo
    Barrel[coffin_core.dart] --> Tokens & Theme & Typo & Glow & Metrics & Pair & Wcag
    App1[hauntagotchi PlaceholderScreen] --> Barrel
    App2[graveyard PlaceholderScreen] --> Barrel
```

Dependency direction: tokens and contrast depend on nothing but `dart:ui` and `dart:math`. Theme depends on tokens, typography and metrics. Apps depend only on the barrel.

## Components and Interfaces

### File layout

```
packages/coffin_core/
├── pubspec.yaml                         # fonts declared, glados dev dependency
├── assets/fonts/
│   ├── Creepster-Regular.ttf
│   ├── Outfit-Regular.ttf
│   ├── Outfit-Medium.ttf
│   ├── Outfit-SemiBold.ttf
│   ├── OFL-Creepster.txt
│   └── OFL-Outfit.txt
├── lib/
│   ├── coffin_core.dart                 # barrel
│   └── src/theme/
│       ├── wcag_contrast.dart           # WcagContrast
│       ├── contrast_pair.dart           # ContrastPair
│       ├── coffin_color_tokens.dart     # CoffinColorTokens (+ night / daylight)
│       ├── coffin_metrics.dart          # CoffinMetrics
│       ├── coffin_typography.dart       # CoffinTypography
│       ├── coffin_glow.dart             # CoffinGlow
│       └── coffin_theme.dart            # CoffinTheme
└── test/theme/
    ├── wcag_contrast_test.dart
    ├── contrast_pairs_property_test.dart
    ├── coffin_color_tokens_test.dart
    ├── coffin_typography_test.dart
    ├── coffin_theme_test.dart
    ├── coffin_glow_test.dart
    ├── coffin_glow_property_test.dart
    └── theme_sources_test.dart          # import and pubspec smoke checks
```

One public class per file, `snake_case.dart`. The `.gitkeep` in `src/theme/` is removed once files exist. `CREDITS.md` goes at the repo root. Font assets live under `assets/fonts/` because `flutter: fonts:` asset paths are relative to the package root.

### Color type decision

Options considered:

| Option | Pros | Cons |
|---|---|---|
| `int` ARGB everywhere | Truly Flutter-free, trivially testable | Every use site wraps `Color(...)`. Token fields would be less self-documenting. |
| `dart:ui` `Color` everywhere | Direct use in `ColorScheme` | The luminance helper on `Color` is not the WCAG one and its channel API changed to floats in recent Flutter. |
| **Tokens hold `Color`, contrast math takes `int` ARGB** | Tokens plug straight into the theme. The math is a pure function with no engine types. | A tiny bridge: `Color.toARGB32()`. |

Choice: the third. (White `#FFFFFF` on `#9B6BFF` gives 3.53:1 and bone-white `#EDE6F5` gives 2.90:1, which is why night on-colors are dark.) `coffin_color_tokens.dart` imports only `dart:ui`. `wcag_contrast.dart` imports nothing from Flutter or `dart:ui`. Req 1.4 and 8.6 are checked by a source-scan test (no `package:flutter/` import in these three files).

### WcagContrast

```dart
/// WCAG 2.x contrast math on opaque sRGB colors.
abstract final class WcagContrast {
  /// The AA threshold for normal text.
  static const double aaNormalText = 4.5;

  /// Relative luminance in [0, 1] for an opaque `0xAARRGGBB` value.
  /// The alpha byte is ignored.
  static double relativeLuminance(int argb);

  /// Contrast ratio in [1, 21]. Symmetric: ratio(a, b) == ratio(b, a).
  static double ratio(int a, int b);
}
```

Each channel `c / 255` is linearized with the WCAG 2.x formula (threshold 0.03928), then `L = 0.2126 R + 0.7152 G + 0.0722 B`. `ratio = (Lmax + 0.05) / (Lmin + 0.05)`. Symmetry is exact because only the max and min are ordered first.

### ContrastPair

```dart
/// A foreground/background combination that a token set guarantees.
final class ContrastPair {
  const ContrastPair({
    required this.foregroundName, required this.backgroundName,
    required this.foreground, required this.background,
  });
  final String foregroundName; // e.g. 'onPrimary'
  final String backgroundName; // e.g. 'primary'
  final Color foreground;
  final Color background;
  /// WCAG contrast ratio of [foreground] on [background].
  double get ratio => WcagContrast.ratio(foreground.toARGB32(), background.toARGB32());
  /// 'onPrimary on primary' for failure reports.
  String get label => '$foregroundName on $backgroundName';
}
```

### CoffinColorTokens

```dart
/// Named colors for one theme variant.
final class CoffinColorTokens {
  const CoffinColorTokens({
    required this.name, // 'night' | 'daylight', used in failure reports
    required this.brightness,
    required this.background, required this.surface, required this.raised,
    required this.primary, required this.secondary, required this.tertiary,
    required this.error,
    required this.text, required this.muted,
    required this.onPrimary, required this.onSecondary,
    required this.onTertiary, required this.onError,
  });

  static const CoffinColorTokens night = CoffinColorTokens(...);
  static const CoffinColorTokens daylight = CoffinColorTokens(...);
  static const List<CoffinColorTokens> variants = [night, daylight];

  /// Every text/background combination this set guarantees at 4.5:1.
  List<ContrastPair> get contrastPairs;
}
```

`brightness` is `dart:ui` `Brightness`. Token roles map to design names: `secondary` = pumpkin, `tertiary` = ectoplasm green, `error` = blood-moon red. This matches the glossary mapping in Req 4.3. Every public member carries a doc comment.

`contrastPairs` returns 22 pairs, built from two rules:

- Text-role foregrounds (`text`, `muted`, `primary`, `secondary`, `tertiary`, `error`) on each of the three surfaces (`background`, `surface`, `raised`): 18 pairs. Accent colors count because they are used for text and icons.
- On-colors on their fills: `onPrimary`/`primary`, `onSecondary`/`secondary`, `onTertiary`/`tertiary`, `onError`/`error`: 4 pairs.

Glow colors are derived at call time from these tokens and are never in the list (Req 3.9).

### Concrete palette and computed contrast

All ratios were computed with the formula above in a throwaway script (deleted afterward).

**Night tokens** (Req 1.1 values unchanged; on-colors added):

| Token | Hex |
|---|---|
| background | `#0E0B16` |
| surface | `#1A1525` |
| raised | `#241C33` |
| primary (ghost-glow) | `#9B6BFF` |
| secondary (pumpkin) | `#FF8A3D` |
| tertiary (ectoplasm) | `#7CFFB2` |
| error (blood-moon) | `#FF4D6D` |
| text (bone) | `#EDE6F5` |
| muted | `#9A90AB` |
| onPrimary / onSecondary / onTertiary / onError | `#0E0B16` (the night background) |

**Daylight tokens** (same names, remapped):

| Token | Hex | Reasoning |
|---|---|---|
| background | `#F7F3FC` | Pale lavender mist |
| surface | `#FFFFFF` | Cards lift off the mist |
| raised | `#EDE5F7` | Slightly deeper lavender for dialogs and inputs |
| primary | `#6B3FD4` | Same purple hue, darkened |
| secondary | `#A8460A` | Pumpkin, darkened to a burnt orange |
| tertiary | `#0B6B3A` | Ectoplasm green, deepened |
| error | `#B3173A` | Blood-moon red, deepened |
| text | `#1A1525` | The night surface as ink |
| muted | `#5A5068` | |
| onPrimary / onSecondary / onTertiary / onError | `#FFFFFF` | White passes on all four fills, so no dark on-color is needed (Req 3.3 only forces dark where white fails) |

**Night contrast ratios (all pairs, minimum 4.5)**

| Foreground | on background | on surface | on raised |
|---|---|---|---|
| text | 15.99 | 14.63 | 13.37 |
| muted | 6.45 | 5.90 | 5.39 |
| primary | 5.51 | 5.04 | 4.61 |
| secondary | 8.31 | 7.60 | 6.95 |
| tertiary | 15.59 | 14.27 | 13.04 |
| error | 6.06 | 5.55 | 5.07 |

| On-color pair | Ratio |
|---|---|
| onPrimary on primary | 5.51 |
| onSecondary on secondary | 8.31 |
| onTertiary on tertiary | 15.59 |
| onError on error | 6.06 |

Smallest night ratio: 4.61 (primary on raised). White on `#9B6BFF` would give 3.53, so the dark on-color is required.

**Daylight contrast ratios (all pairs, minimum 4.5)**

| Foreground | on background | on surface | on raised |
|---|---|---|---|
| text | 16.28 | 17.83 | 14.56 |
| muted | 6.89 | 7.55 | 6.17 |
| primary | 5.84 | 6.39 | 5.22 |
| secondary | 5.41 | 5.92 | 4.84 |
| tertiary | 6.03 | 6.61 | 5.40 |
| error | 6.19 | 6.77 | 5.53 |

| On-color pair | Ratio |
|---|---|
| onPrimary on primary | 6.39 |
| onSecondary on secondary | 5.92 |
| onTertiary on tertiary | 6.61 |
| onError on error | 6.77 |

Smallest daylight ratio: 4.84 (secondary on raised). The 4.5 margin is thin for night primary on raised (4.61), so a future palette edit will be caught by the property test.

### CoffinMetrics

```dart
/// Shared layout constants from the design language.
abstract final class CoffinMetrics {
  /// Corner radius for cards, dialogs, buttons, inputs and glows.
  static const double cornerRadius = 16;
  /// Minimum interactive size (width and height).
  static const double minTapTarget = 48;
  /// Width of the focus ring drawn around focused buttons.
  static const double focusRingWidth = 2;
}
```

### CoffinTypography

```dart
/// Font families and text theme for the haunted look.
abstract final class CoffinTypography {
  static const String package = 'coffin_core';
  static const String displayFamily = 'Creepster';
  static const String bodyFamily = 'Outfit';
  /// Full family string as Flutter resolves it, e.g. 'packages/coffin_core/Creepster'.
  static const String displayFamilyName = 'packages/coffin_core/Creepster';
  static const String bodyFamilyName = 'packages/coffin_core/Outfit';
  /// Builds the text theme for [tokens]: text color for most slots, muted for bodySmall.
  static TextTheme textTheme(CoffinColorTokens tokens);
}
```

Styles are built with `TextStyle(fontFamily: ..., package: package, ...)`, so the `packages/coffin_core/` prefix is added by Flutter. `fontFamilyFallback` is left unset, so a missing font uses the platform default and no style requires network access (Req 5.6, 5.7).

| Slot | Family | Size | Weight |
|---|---|---|---|
| displayLarge / Medium / Small | Creepster | 57 / 45 / 36 | w400 |
| headlineLarge / Medium / Small | Creepster | 32 / 28 / 24 | w400 |
| titleLarge / Medium / Small | Outfit | 22 / 16 / 14 | w500 |
| bodyLarge / Medium / Small | Outfit | 16 / 14 / 14 | w400 |
| labelLarge / Medium / Small | Outfit | 14 / 12 / 11 | w500 |

Notes: Creepster has a single weight, so display and headline slots stay at w400 to avoid synthetic bold. Req 5.5 is read as "body slots": all three body slots are at least 14. `bodySmall` uses the `muted` color. Every other slot uses `text`. Letter spacing is 0.

### CoffinGlow

```dart
/// Soft-glow decorations. Glows are plain BoxShadow values with zero offset.
abstract final class CoffinGlow {
  /// Returns a decoration glowing in [color].
  /// [intensity] is clamped to [0, 1]; NaN counts as 0.
  static BoxDecoration decoration({
    required Color color,
    double intensity = 0.5,
    Color? fill,
    BorderRadius? borderRadius, // default: circular(CoffinMetrics.cornerRadius)
  });
}
```

**Intensity-to-glow formula.** Let `i = clamp(intensity, 0, 1)` (NaN becomes 0).

- If `i == 0`: `boxShadow` is an empty const list.
- Otherwise two layers, both with `offset: Offset.zero` and `spreadRadius: 0`:

| Layer | blurRadius | alpha multiplier on `color.a` |
|---|---|---|
| inner | `8 + 16 i` | `0.25 + 0.35 i` |
| outer | `24 + 40 i` | `0.10 + 0.20 i` |

The layer color is `color.withValues(alpha: color.a * multiplier)`, so its RGB equals the input color.

**Monotonicity.** Total blur is `(8 + 16 i) + (24 + 40 i) = 32 + 56 i` for `i > 0`, and `0` at `i == 0`. This is strictly increasing on `(0, 1]` and `0 < 32`, so it is non-decreasing on `[0, 1]`. Each layer's blur is also non-decreasing in `i`. The function is pure, so equal inputs give equal `BoxDecoration` values (Req 6.7). `BoxDecoration` has no semantics, so a glow adds no accessibility nodes (Req 7.2).

### CoffinTheme

```dart
/// Material 3 theme factories for Coffin.
abstract final class CoffinTheme {
  /// Night theme built from [CoffinColorTokens.night].
  static ThemeData dark();
  /// Daylight theme built from [CoffinColorTokens.daylight].
  static ThemeData light();
}
```

Both call a private `_build(CoffinColorTokens)`, so the two themes differ only by tokens.

**ColorScheme mapping**

| ColorScheme role | Token |
|---|---|
| brightness | `tokens.brightness` |
| primary / onPrimary | `primary` / `onPrimary` |
| secondary / onSecondary | `secondary` / `onSecondary` (pumpkin) |
| tertiary / onTertiary | `tertiary` / `onTertiary` (ectoplasm) |
| error / onError | `error` / `onError` |
| surface | `surface` |
| onSurface | `text` |
| onSurfaceVariant, outline | `muted` |
| surfaceContainerLowest | `background` |
| surfaceContainerLow, surfaceContainer | `surface` |
| surfaceContainerHigh, surfaceContainerHighest, outlineVariant | `raised` |
| surfaceTint | fully transparent (no tint over cards) |
| inverseSurface / onInverseSurface | `text` / `background` |

`scaffoldBackgroundColor` is set to `background`, since Material would otherwise use `surface`.

**Theme-level settings**

- `useMaterial3: true`, `textTheme: CoffinTypography.textTheme(tokens)`.
- `materialTapTargetSize: MaterialTapTargetSize.padded`, `visualDensity: VisualDensity.standard`.
- `focusColor`, `hoverColor`, `highlightColor`: primary at 12%, 8%, 16% alpha. `splashFactory: InkRipple.splashFactory`.

**Component themes**

| Component | Settings |
|---|---|
| `CardThemeData` | color `surface`, elevation 0, `RoundedRectangleBorder(circular(16))`, clip `antiAlias` |
| `DialogThemeData` | background `raised`, elevation 0, shape radius 16 |
| `FilledButtonThemeData`, `ElevatedButtonThemeData`, `OutlinedButtonThemeData`, `TextButtonThemeData` | `minimumSize: Size(48, 48)`, `tapTargetSize: padded`, shape radius 16, state overlay (below), focus ring (below) |
| `IconButtonThemeData` | `minimumSize` and `fixedSize` at least 48x48, shape radius 16, state overlay |
| `InputDecorationTheme` | `filled: true`, fill `raised`, `OutlineInputBorder(radius 16)` with `muted` border, focused border 2 px `primary`, error borders `error` |
| `AppBarTheme` | background `background`, foreground `text`, elevation 0, scrolled-under elevation 0, title style `headlineSmall` |

**State overlays (Req 4.6).** `overlayColor` is a `WidgetStateProperty<Color?>`: hovered 8%, focused 12%, pressed 16%. For text, outlined and elevated buttons the tint is `primary`. For `FilledButton`, the fill is already `primary`, so a primary overlay would be invisible. It uses `onPrimary` instead (see Requirement impacts, Req 4.6).

**Focus indicator (Req 7.1).** When focused, buttons get `side: BorderSide(color: tokens.text, width: 2)`. The ring is `text`, whose contrast against `background`, `surface` and `raised` is 13.37 or higher in night and 14.56 or higher in daylight, well above 3:1. Text fields use a 2 px `primary` focused border, which is at least 4.61:1 on `raised` (night) and 5.22:1 (daylight), also above 3:1. The ring against the filled button's own fill is not guaranteed (night text on primary is below 3:1). The outside edge, which is the "adjacent background", is.

**Determinism (Req 4.7).** The factories read only const tokens and static functions, so two calls give equal `ColorScheme` and `TextTheme` values. No caching is needed.

## Data Models

There is no persisted data. The value types are:

| Type | Fields | Notes |
|---|---|---|
| `CoffinColorTokens` | `name`, `brightness`, 13 `Color` roles | Immutable, const. Two const instances plus a `variants` list. |
| `ContrastPair` | `foregroundName`, `backgroundName`, `foreground`, `background`, derived `ratio`, `label` | Built on demand by `contrastPairs`. |

## Pubspec changes

`packages/coffin_core/pubspec.yaml` (pinned, per Req 10.6):

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  glados: 1.1.7

flutter:
  uses-material-design: true
  fonts:
    - family: Creepster
      fonts:
        - asset: assets/fonts/Creepster-Regular.ttf
    - family: Outfit
      fonts:
        - asset: assets/fonts/Outfit-Regular.ttf
        - asset: assets/fonts/Outfit-Medium.ttf
          weight: 500
        - asset: assets/fonts/Outfit-SemiBold.ttf
          weight: 600
```

`flutter_lints` already exists in `coffin_core`. I will also enable `public_member_api_docs` in `packages/coffin_core/analysis_options.yaml` so the doc-comment rules (Req 1.5, 8.7) are enforced by `flutter analyze` and not by hand. I have not read that file yet, so the implementation task must check its current contents first. Apps and the workspace root are unchanged. Apps get the fonts transitively through their `coffin_core` path dependency.

## Barrel exports

```dart
library;

export 'src/theme/coffin_color_tokens.dart' show CoffinColorTokens;
export 'src/theme/coffin_glow.dart' show CoffinGlow;
export 'src/theme/coffin_metrics.dart' show CoffinMetrics;
export 'src/theme/coffin_theme.dart' show CoffinTheme;
export 'src/theme/coffin_typography.dart' show CoffinTypography;
export 'src/theme/contrast_pair.dart' show ContrastPair;
export 'src/theme/wcag_contrast.dart' show WcagContrast;
export 'src/widgets/coffin_mark.dart' show CoffinMark;
```

`ContrastPair` is exported because it is the return type of the public `contrastPairs`. `WcagContrast` is exported so developers who add their own palette can run the same check. Both are required by Req 8.1.

## App adoption

Current state (read from the repo): each `main.dart` builds `const MaterialApp(title: ..., home: PlaceholderScreen())`. Each `PlaceholderScreen` is `const Scaffold(body: Center(child: CoffinMark()))`. Each existing test pumps `MaterialApp(home: PlaceholderScreen())` and checks for `CoffinMark` and the text `Coffin`.

Changes, identical in both apps except for strings:

- `main.dart`: `MaterialApp(title: ..., theme: CoffinTheme.dark(), home: const PlaceholderScreen())`. It is no longer `const`. Using `theme:` (not `darkTheme:`) makes the app dark regardless of the system setting.
- `PlaceholderScreen` reads `Theme.of(context)` and builds a centered column:
  - The existing `CoffinMark` inside a `DecoratedBox` with `CoffinGlow.decoration(color: scheme.primary, intensity: 0.6, fill: scheme.surface)` and padding.
  - A title `Text` with `textTheme.displayMedium`: `Hauntagotchi` or `Graveyard`.
  - A body `Text` with `textTheme.bodyLarge`, in `onSurfaceVariant`: "Your ghost is getting hungry…" or "This project has been dead for 214 days". The text is centered and wraps, inside a `SingleChildScrollView`, so small phone screens do not overflow.
- No hard-coded colors or font names. Only `package:coffin_core/coffin_core.dart` is imported, and the apps never import each other.
- The stale doc comment on `CoffinMark` ("tokens arrive in a later spec") is updated. `CoffinMark` itself still has no color arguments, so it inherits the theme.

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

Prework reflection: the criteria 1.2, 2.4, 3.1, 3.2 and 3.5 all reduce to one invariant over the pair list, so they become one property. Criteria 6.1, 6.2 and 6.3 share generators and merge into one shape property. Criteria 6.5 and 6.6 merge into one clamp property. Palette values, theme mapping, fonts, tap targets, overlays and app adoption are finite fixed inputs (two variants or one instance), so they are covered by example tests and not properties.

### Property 1: Every guaranteed token pair meets WCAG AA

*For any* theme variant in `CoffinColorTokens.variants` and *any* pair in that variant's `contrastPairs` (including the four on-color pairs), the contrast ratio is at least 4.5.

**Validates: Requirements 1.2, 2.4, 3.1, 3.2, 3.5**

### Property 2: Contrast ratio is symmetric, bounded and reflexive

*For any* two opaque colors `a` and `b`, `ratio(a, b) == ratio(b, a)`, the ratio lies in `[1, 21]`, and `ratio(a, a) == 1`.

**Validates: Requirements 3.6, 3.7**

### Property 3: Glow shape

*For any* color, *any* intensity in `(0, 1]`, and either default or overridden corner radius, the decoration is non-empty and every `BoxShadow` has `offset == Offset.zero`, `blurRadius > 0`, and RGB channels equal to the input color. With no radius override the corner radius is 16.

**Validates: Requirements 6.1, 6.2, 6.3**

### Property 4: Intensity is clamped

*For any* double intensity (including values below 0 and above 1), `decoration(color, intensity)` equals `decoration(color, clamp(intensity, 0, 1))`, and when the clamped value is 0 the decoration has no shadows.

**Validates: Requirements 6.5, 6.6**

### Property 5: Glow blur is monotonic

*For any* `a` and `b` in `[0, 1]` with `a <= b`, the total blur of `decoration(color, a)` is less than or equal to the total blur of `decoration(color, b)`.

**Validates: Requirements 6.8**

### Property 6: Glow is deterministic

*For any* color, intensity, optional fill and optional radius, two calls with equal arguments return equal `BoxDecoration` values.

**Validates: Requirements 6.7**

## Error Handling

| Situation | Behavior |
|---|---|
| A bundled font file is missing or corrupt | The build fails if a file listed in the pubspec is absent. A corrupt file makes the engine fall back to the platform font. No exception reaches Dart, and the text still renders (Req 5.6). A smoke test pumps text with a nonexistent package family to prove this. |
| Intensity is NaN, infinite, negative or above 1 | `CoffinGlow` treats NaN as 0 and clamps the rest. It never throws. |
| Semi-transparent color passed to `WcagContrast` | The alpha byte is ignored. Tokens are all opaque, and the doc comment says so. |
| A palette edit drops a pair below 4.5:1 | Property 1 fails. The `reason` text names the variant, the pair label and the measured ratio (Req 3.8). |
| `glados` shrinks to a failing example | The glados output prints the failing input. |
| Web build omits a font | The `FontManifest.json` check in Testing Strategy catches it before release. |

## Testing Strategy

Property-based testing applies to the contrast math and the glow decoration: they are pure, have large input spaces, and carry numeric invariants (the tech rules ask for glados here). It does not apply to the theme mapping, typography assignment, fonts, tap targets, overlays and app screens. Those have fixed inputs, so they use example-based and widget tests.

**Library.** `glados` 1.1.7, dev dependency, not hand-rolled. Each property test runs with `ExploreConfig(numRuns: 100)` or more, and is tagged `// Feature: haunted-theme, Property N: <text>`. Each property is exactly one glados test. Tests import `package:glados/glados.dart` and `hide` the clashing `expect` / `test` names from `flutter_test`, or the reverse.

**Generators**

- Property 1: `any.choose(allPairs)` where `allPairs = [for (final v in CoffinColorTokens.variants) for (final p in v.contrastPairs) (v.name, p)]`. The assertion's `reason` is `'${variant} / ${p.label}: ${p.ratio.toStringAsFixed(2)}'`. A companion plain test iterates all pairs exhaustively.
- Property 2: `any.intInRange(0, 0x1000000).map((rgb) => 0xFF000000 | rgb)` twice, via `Glados2`.
- Properties 3 to 6: a color generator `any.intInRange(0, 0x100000000).map(Color.new)`, `any.doubleInRange(0, 1)` for in-range intensity, `any.doubleInRange(-5, 5)` for the clamp test, and `any.choose([null, 4.0, 24.0])` style radius options.

**Example and widget tests (coffin_core)**

- Tokens: exact night hex values, daylight fields all differ in lightness direction (light backgrounds, dark text), pair list contains the 4 on-color pairs and 18 text-on-surface pairs and excludes non-text tokens, night on-colors are darker than their fills.
- Contrast: black on white is 21, identical colors give 1 (Req 3.7).
- Theme: for both variants, `useMaterial3`, brightness, every ColorScheme role in the mapping table, `scaffoldBackgroundColor`, 16 px radius on card, dialog, buttons and input border, `minimumSize` 48x48, a widget test measuring a pumped `FilledButton` and `IconButton` size at least 48x48, overlay colors resolve to three distinct non-transparent values for hovered, focused and pressed, focus ring `side` color contrast at least 3 against the three surfaces, and two factory calls give equal `colorScheme` and `textTheme`.
- Typography: display and headline slots resolve to `packages/coffin_core/Creepster`, all other slots to `packages/coffin_core/Outfit`, body sizes at least 14, and every slot has a null `fontFamilyFallback` (Req 5.7). Under `flutter test` every glyph renders as Ahem, so these assert on style strings only. A widget test pumps `Text` with a missing family and expects no exception.
- Glow: fill and radius override examples, NaN gives no shadows, and a semantics test confirms a glow-decorated container adds no semantics nodes.
- Source and config smoke tests (`theme_sources_test.dart`, run from the package root): the tokens, pair and contrast files contain no `package:flutter/` import (only `dart:ui` for tokens); nothing under `lib/` imports an app; `pubspec.yaml` declares both families and every font file exists; `pubspec.yaml` has no `google_fonts` or `http` dependency; both OFL files exist (Req 5.10); the barrel exports `ContrastPair` and `WcagContrast` (Req 8.1); `CREDITS.md` mentions both fonts and the OFL 1.1 (read from the repo root, skipped if run from a different directory).

**App tests.** In each app, update the placeholder test to pump `MaterialApp(theme: CoffinTheme.dark(), home: PlaceholderScreen())` and check: `CoffinMark` and the text `Coffin` still present, scaffold background equals `CoffinColorTokens.night.background`, the title style's `fontFamily` equals `CoffinTypography.displayFamilyName`, the body style's equals `bodyFamilyName`, and a `DecoratedBox` with a non-empty `boxShadow` exists. A second test pumps the app root (`HauntagotchiApp`, `GraveyardApp`) and checks `MaterialApp.theme == CoffinTheme.dark()`.

**Web check (manual or CI, once).** Run `flutter build web` for one app and confirm `build/web/assets/FontManifest.json` lists `packages/coffin_core/Creepster` and `packages/coffin_core/Outfit`. This is the only claim in this design about the web font path that I have not verified directly. I did not run it during design.

**Gates.** `dart format` clean, `flutter analyze` with zero warnings, and `flutter test` passing in `packages/coffin_core`, `apps/hauntagotchi` and `apps/graveyard`.

## Credits and license plan

- **Fonts to download** (all HTTP 200 when I checked):
  - Creepster: `https://raw.githubusercontent.com/google/fonts/main/ofl/creepster/Creepster-Regular.ttf` and `.../ofl/creepster/OFL.txt` (copyright line names Font Diner, Inc.).
  - Outfit static files: `https://raw.githubusercontent.com/Outfitio/Outfit-Fonts/main/fonts/ttf/Outfit-Regular.ttf`, `Outfit-Medium.ttf`, `Outfit-SemiBold.ttf`, and `.../google/fonts/main/ofl/outfit/OFL.txt` (copyright: The Outfit Project Authors).
  - Static instances are used instead of Google's single variable file so that `weight:` entries in the pubspec map directly.
- **License files:** the two OFL texts are copied unmodified into `packages/coffin_core/assets/fonts/` as `OFL-Creepster.txt` and `OFL-Outfit.txt` (Req 5.10). They are not declared as assets, so they ship with the package source and not the app bundle.
- **`CREDITS.md`** (repo root, created because it does not exist, Req 5.9), one entry per font (Req 5.8) with name, author or foundry, source URL, license "SIL Open Font License 1.1", and a link to the license file. Authors: Creepster by Font Diner, Inc.; Outfit by The Outfit Project Authors (Rodrigo Fuenzalida).
- No fonts are modified, so the OFL reserved font name rule is not triggered.

## Resolved decisions

1. `google_fonts` is dropped. Fonts are bundled and declared with `flutter: fonts:` (Req 5.3, 5.4, 10.6).
2. `ContrastPair` and `WcagContrast` are exported from the barrel (Req 8.1).
3. `FilledButton` uses an `onPrimary` overlay (Req 4.6).
