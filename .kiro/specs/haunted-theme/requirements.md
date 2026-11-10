# Requirements Document

## Introduction

The haunted-theme feature adds the visual foundation of `coffin_core`: color tokens for a dark "night" theme and a light "daylight" theme, two Material 3 `ThemeData` factories, a typography pairing (a spooky display font plus a clean body font, both bundled as package assets and declared in the `pubspec.yaml` of `coffin_core`), and a soft-glow decoration helper. Everything is exported through the `coffin_core.dart` barrel, and the placeholder screens of Hauntagotchi and Graveyard adopt the dark theme. The design language is "Haunted, not horror", as defined in the design steering document.

## Dependency Approval Notice

This feature requires one package that is not yet declared in the workspace. Per the tech steering rules, the user must approve it before it is added. The user has APPROVED it:

- `glados` (dev dependency of `coffin_core`): approved. It provides property-based testing. It is the testing library named in the tech steering rules but is not yet in `coffin_core/pubspec.yaml`.

`glados` may be added to `coffin_core/pubspec.yaml` as part of this feature, using a pinned version.

`google_fonts` was approved earlier but is not used. Fonts are bundled as package assets and declared with `flutter: fonts:` in the `pubspec.yaml` of `coffin_core`.

## Glossary

- **Coffin_Theme**: The `CoffinTheme` class in `coffin_core` that exposes `dark()` and `light()` factories.
- **Color_Tokens**: The immutable set of named colors for one theme variant (background, surface, raised surface, primary, accent, success, danger, text, muted text, and the on-colors onPrimary, onSecondary, onTertiary and onError).
- **Night_Tokens**: The Color_Tokens instance for the dark theme, using the palette in the design steering document.
- **Daylight_Tokens**: The Color_Tokens instance for the light theme, with the same token names remapped to light-appropriate values.
- **On_Color**: A token used for text or icons drawn on a fill color: onPrimary on primary, onSecondary on secondary (pumpkin accent), onTertiary on tertiary (ectoplasm accent), and onError on error (danger).
- **Text_Background_Pair**: A combination of one foreground token with one background token on which it is displayed. The foreground is a text-role token (text, muted text, or any color used for text or icons on a surface) or an On_Color. The background is a surface-role token (background, surface, raised surface) or a fill color (primary, secondary, tertiary, error), so that fill colors count as backgrounds.
- **Contrast_Ratio**: The WCAG 2.x relative luminance contrast ratio between two colors.
- **Display_Font**: Creepster, the characterful spooky font, used for titles only. Licensed under the SIL Open Font License 1.1.
- **Body_Font**: Outfit, the clean readable font, used for all other text. Licensed under the SIL Open Font License 1.1.
- **Font_Family_Name**: The family string `packages/coffin_core/<family>` produced by `fontFamily` with `package: 'coffin_core'`.
- **ContrastPair**: The public value type in `coffin_core` that describes one Text_Background_Pair (foreground and background token names and colors, plus its Contrast_Ratio).
- **WcagContrast**: The public plain-Dart utility in `coffin_core` that computes relative luminance and Contrast_Ratio, so developers can check their own palettes.
- **Glow_Decoration**: A helper in `coffin_core` that produces a `BoxDecoration` using soft, blurred, colored glows instead of hard shadows.
- **Barrel**: The file `packages/coffin_core/lib/coffin_core.dart`, the only public import for apps.
- **Placeholder_Screen**: The file `ui/placeholder_screen.dart` in each of Hauntagotchi and Graveyard.
- **Credits_File**: `CREDITS.md` at the repository root, which records licensed assets.
- **Contrast_Test**: The glados property-based test that checks Contrast_Ratio over all Text_Background_Pairs.

## Requirements

### Requirement 1: Night color tokens

**User Story:** As a Flutter developer using Coffin, I want a dark color token set from the design palette, so that my app looks like a moonlit graveyard.

#### Acceptance Criteria

1. THE Night_Tokens SHALL define background `#0E0B16`, surface `#1A1525`, raised surface `#241C33`, primary `#9B6BFF`, accent pumpkin `#FF8A3D`, accent ectoplasm `#7CFFB2`, danger `#FF4D6D`, text bone white `#EDE6F5`, and muted text `#9A90AB`.
2. THE Night_Tokens SHALL define onPrimary, onSecondary, onTertiary and onError as dark colors, each with a Contrast_Ratio of at least 4.5:1 against its fill color.
3. THE Color_Tokens class SHALL be immutable, with all fields declared `final` and a `const` constructor.
4. THE Color_Tokens class SHALL contain no Flutter widget imports beyond the color type it needs.
5. THE Color_Tokens class SHALL carry a doc comment on every public member.

### Requirement 2: Daylight color tokens

**User Story:** As a user who prefers light interfaces, I want a daylight token set with the same names as the night set, so that the app can switch themes without code changes.

#### Acceptance Criteria

1. THE Daylight_Tokens SHALL define a value for every token name defined in the Night_Tokens, including onPrimary, onSecondary, onTertiary and onError.
2. THE Daylight_Tokens SHALL map background, surface and raised surface to light values and text and muted text to dark values.
3. THE Daylight_Tokens SHALL retain the ghost-glow purple, pumpkin, ectoplasm green and blood-moon red hues, adjusted in lightness where needed to meet Requirement 3.
4. THE Daylight_Tokens SHALL define each On_Color with a Contrast_Ratio of at least 4.5:1 against its fill color.
5. THE Daylight_Tokens SHALL be exposed with the same type as the Night_Tokens.

### Requirement 3: WCAG AA contrast of token pairs

**User Story:** As a user with low vision, I want every text and background combination to be readable, so that the app is accessible in both themes.

#### Acceptance Criteria

1. THE Night_Tokens SHALL provide a Contrast_Ratio of at least 4.5:1 for every Text_Background_Pair, including the pairs onPrimary on primary, onSecondary on secondary, onTertiary on tertiary and onError on error.
2. THE Daylight_Tokens SHALL provide a Contrast_Ratio of at least 4.5:1 for every Text_Background_Pair, including the pairs onPrimary on primary, onSecondary on secondary, onTertiary on tertiary and onError on error.
3. THE Color_Tokens class SHALL define each On_Color as a dark color wherever a light On_Color would yield a Contrast_Ratio below 4.5:1 against its fill color, so that a light On_Color is not used on the ghost-glow purple `#9B6BFF` (bone-white `#EDE6F5` is about 2.9:1 and pure white about 3.5:1 on it).
4. THE Color_Tokens class SHALL expose the complete list of Text_Background_Pairs it guarantees, so that tests and tooling enumerate the same pairs.
5. THE Contrast_Test SHALL use glados to generate a theme variant and a Text_Background_Pair from that variant's pair list, and assert a Contrast_Ratio of at least 4.5:1 for each generated pair, covering the On_Color pairs.
6. THE Contrast_Test SHALL also assert, for every pair in both variants, that the Contrast_Ratio is symmetric when foreground and background are swapped.
7. THE Contrast_Test SHALL include a unit test that checks a known reference value: black on white yields 21:1 and identical colors yield 1:1.
8. IF a token pair in either variant yields a Contrast_Ratio below 4.5:1, THEN THE Contrast_Test SHALL fail and report the theme variant, the token names, and the measured ratio.
9. WHERE a token is used only for non-text decoration (for example a glow color), THE Color_Tokens class SHALL exclude that token from the Text_Background_Pair list.

### Requirement 4: Material 3 theme factories

**User Story:** As a Flutter developer, I want `CoffinTheme.dark()` and `CoffinTheme.light()`, so that I can theme an app with one line.

#### Acceptance Criteria

1. WHEN `CoffinTheme.dark()` is called, THE Coffin_Theme SHALL return a `ThemeData` with `useMaterial3` set to true, `Brightness.dark`, and a `ColorScheme` built from the Night_Tokens.
2. WHEN `CoffinTheme.light()` is called, THE Coffin_Theme SHALL return a `ThemeData` with `useMaterial3` set to true, `Brightness.light`, and a `ColorScheme` built from the Daylight_Tokens.
3. THE Coffin_Theme SHALL map primary to the primary token, secondary to the pumpkin accent, tertiary to the ectoplasm accent, error to the danger token, onPrimary, onSecondary, onTertiary and onError to the matching On_Colors, scaffold background to the background token, and surface roles to the surface and raised surface tokens.
4. THE Coffin_Theme SHALL set the corner radius of cards, dialogs, buttons and input fields to 16 logical pixels.
5. THE Coffin_Theme SHALL set a minimum tap target size of 48×48 logical pixels on buttons and icon buttons.
6. THE Coffin_Theme SHALL define hover, focus and pressed visual states for buttons, using a tinted overlay of the primary color, or of onPrimary on primary-filled buttons (FilledButton).
7. WHEN either factory is called twice, THE Coffin_Theme SHALL return `ThemeData` values that are equal in color scheme and text theme.

### Requirement 5: Typography

**User Story:** As a Flutter developer, I want a spooky display font for titles and a clean font for everything else, so that the app has character without hurting readability and works fully offline.

#### Acceptance Criteria

1. THE Coffin_Theme SHALL apply the Display_Font (Creepster) to the display and headline text styles only.
2. THE Coffin_Theme SHALL apply the Body_Font (Outfit) to title, body and label text styles, buttons and input text.
3. THE coffin_core package SHALL bundle the Display_Font and Body_Font files as assets, declare them under `flutter: fonts:` in its `pubspec.yaml`, and THE Coffin_Theme SHALL reference them with `fontFamily` and `package: 'coffin_core'`.
4. THE Coffin_Theme SHALL load both fonts only from bundled assets and SHALL NOT depend on any package that fetches fonts at runtime, so apps and tests never contact a font server for them.
5. THE Coffin_Theme SHALL set a body text size of at least 14 logical pixels.
6. IF a bundled font file is missing or fails to load, THEN THE Coffin_Theme SHALL render text with the platform default font and the app SHALL continue without throwing an exception.
7. THE Coffin_Theme text styles SHALL declare no font fallback that requires network access.
8. THE Credits_File SHALL record the name, author, source URL and license (SIL Open Font License 1.1) of the Display_Font and the Body_Font.
9. IF the Credits_File does not exist, THEN THE feature SHALL create it at the repository root.
10. THE coffin_core package SHALL ship the SIL Open Font License 1.1 text together with the bundled font files.

### Requirement 6: Soft-glow decoration helper

**User Story:** As a Flutter developer, I want a glow helper, so that components glow softly instead of casting hard shadows.

#### Acceptance Criteria

1. WHEN a color and an intensity are provided, THE Glow_Decoration SHALL return a `BoxDecoration` whose `boxShadow` entries use that color with a non-zero blur radius.
2. THE Glow_Decoration SHALL produce `BoxShadow` entries with zero offset, so that no hard directional shadow appears.
3. THE Glow_Decoration SHALL apply a default corner radius of 16 logical pixels.
4. THE Glow_Decoration SHALL accept an optional fill color and an optional corner radius override.
5. IF the intensity is outside the range 0.0 to 1.0, THEN THE Glow_Decoration SHALL clamp the value to that range.
6. WHEN the intensity is 0.0, THE Glow_Decoration SHALL return a decoration with no glow shadows.
7. THE Glow_Decoration SHALL be pure and deterministic, returning equal decorations for equal inputs.
8. FOR ALL intensities in the range 0.0 to 1.0, THE Glow_Decoration SHALL produce a total glow blur that is non-decreasing as intensity increases (monotonic property, verified with glados).

### Requirement 7: Accessibility support

**User Story:** As a user with low vision or who relies on assistive technology, I want visible focus indicators and decoration that stays out of the way, so that I can navigate the app and the screen reader stays clean.

#### Acceptance Criteria

1. THE Coffin_Theme SHALL expose focus indicators on interactive elements with a Contrast_Ratio of at least 3:1 against the adjacent background.
2. THE Glow_Decoration SHALL be non-semantic, so that glow effects add no extra nodes to the accessibility tree.

### Requirement 8: Barrel export and package boundaries

**User Story:** As an app developer, I want one import for the whole theme API, so that I never reach into `src/`.

#### Acceptance Criteria

1. THE Barrel SHALL export Color_Tokens, Night_Tokens, Daylight_Tokens, Coffin_Theme, the typography definitions, the Glow_Decoration, ContrastPair and WcagContrast, so that developers can check their own palettes.
2. THE Barrel SHALL export only the public names intended for apps, using `show` clauses consistent with the existing `CoffinMark` export.
3. THE theme source files SHALL live under `packages/coffin_core/lib/src/theme/`, with one public class per file named in `snake_case.dart`.
4. THE coffin_core package SHALL import nothing from `apps/hauntagotchi` or `apps/graveyard`.
5. THE theme tests SHALL live under `packages/coffin_core/test/theme/`, mirroring the `lib/` layout.
6. THE theme logic for Color_Tokens and Contrast_Ratio SHALL be plain Dart and SHALL import no Flutter widgets library.
7. EVERY public API in the theme source files SHALL carry a doc comment.

### Requirement 9: App adoption of the dark theme

**User Story:** As a hackathon judge opening either app, I want it to look haunted from the first screen, so that the theme is visibly applied.

#### Acceptance Criteria

1. WHEN Hauntagotchi starts, THE Hauntagotchi app SHALL apply `CoffinTheme.dark()` to its `MaterialApp`.
2. WHEN Graveyard starts, THE Graveyard app SHALL apply `CoffinTheme.dark()` to its `MaterialApp`.
3. THE Placeholder_Screen of each app SHALL read colors and text styles from `Theme.of(context)` instead of hard-coded values.
4. THE Placeholder_Screen of each app SHALL render its title with the display text style and its body copy with the body text style.
5. THE Placeholder_Screen of each app SHALL show at least one element decorated with the Glow_Decoration.
6. THE Hauntagotchi and Graveyard apps SHALL import only `package:coffin_core/coffin_core.dart` for theme access.
7. THE Hauntagotchi and Graveyard apps SHALL NOT import from each other.
8. THE Placeholder_Screen of each app SHALL have a widget test confirming it builds under `CoffinTheme.dark()` and that its scaffold background equals the Night_Tokens background.

### Requirement 10: Quality gates

**User Story:** As a maintainer, I want the feature to meet the workspace quality rules, so that the codebase stays clean.

#### Acceptance Criteria

1. THE feature code SHALL pass `dart format` with no changes.
2. THE feature code SHALL pass `flutter analyze` with zero warnings across the workspace.
3. THE feature SHALL include unit tests for Color_Tokens, Contrast_Ratio calculation, Coffin_Theme and Glow_Decoration.
4. THE feature SHALL include glados property-based tests for the contrast pairs (Requirement 3) and glow monotonicity (Requirement 6).
5. WHEN `flutter test` runs at the workspace packages, THE test suite SHALL pass before any task is marked done.
6. THE feature SHALL add `glados` as a dev dependency of `coffin_core` (approved) with a pinned version, and SHALL add no font-fetching dependency.
7. THE feature SHALL add no API keys, secrets or tokens to the repository.
