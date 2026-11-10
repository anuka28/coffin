# Implementation Plan: haunted-theme

## Overview

Build the visual foundation of `coffin_core` in dependency order: assets and config first, then the plain-Dart contrast math and color tokens, then metrics, typography, glow and the theme factories, then the barrel and boundary checks, and finally the two app placeholder screens. Each task is a coding step that builds on the previous ones, and the barrel and apps wire everything together at the end.

All code is Dart in Flutter, matching the design. Paths are relative to the repo root. Tests use `flutter_test` and `glados` (property-based). Per the tech steering rules, unit tests and property tests for pure logic are NOT optional here. No sub-task is marked optional except the DIARY entry.

Notes that apply to all tasks:

- `CREDITS.md` does not exist yet and must be created.
- `packages/coffin_core/analysis_options.yaml` currently only includes `../../analysis_options.yaml` and excludes `build/**`. Read it before editing.
- `glados` exports its own `expect` and `test`, so test files must `hide` the clashing names from one side.
- Fonts come from official sources only. The user must be told where the files came from (see task 1.1).

## Tasks

- [x] 1. Assets, dependencies and configuration
  - [x] 1.1 Download and add the font files and OFL texts
    - Download from official sources into `packages/coffin_core/assets/fonts/` and verify each file is a non-empty TTF or text file:
      - `Creepster-Regular.ttf` from `https://raw.githubusercontent.com/google/fonts/main/ofl/creepster/Creepster-Regular.ttf`
      - `OFL-Creepster.txt` from `https://raw.githubusercontent.com/google/fonts/main/ofl/creepster/OFL.txt`
      - `Outfit-Regular.ttf`, `Outfit-Medium.ttf`, `Outfit-SemiBold.ttf` from `https://raw.githubusercontent.com/Outfitio/Outfit-Fonts/main/fonts/ttf/<name>.ttf`
      - `OFL-Outfit.txt` from `https://raw.githubusercontent.com/google/fonts/main/ofl/outfit/OFL.txt`
    - Copy the OFL texts unmodified. Do not declare them as assets.
    - If a URL fails, stop and report it to the user instead of substituting another source.
    - Tell the user in the final message which URLs the files came from.
    - _Requirements: 5.3, 5.10_

  - [x] 1.2 Add `glados` and declare fonts in the `coffin_core` pubspec
    - Read `packages/coffin_core/pubspec.yaml` first.
    - Add `glados: 1.1.7` (pinned) under `dev_dependencies`. Add no font-fetching dependency (no `google_fonts`, no `http`).
    - Under `flutter:`, keep `uses-material-design: true` and add the `fonts:` block for `Creepster` and `Outfit` (weights 400, 500, 600) exactly as in the design.
    - Run `flutter pub get` at the workspace root and confirm it resolves.
    - _Requirements: 5.3, 5.4, 10.6_

  - [x] 1.3 Create `CREDITS.md` at the repo root
    - The file does not exist, so create it.
    - One entry per font: name, author (Creepster by Font Diner, Inc.; Outfit by The Outfit Project Authors), the exact source URLs used in task 1.1, license "SIL Open Font License 1.1", and a relative link to the matching `OFL-*.txt` file.
    - _Requirements: 5.8, 5.9_

  - [x] 1.4 Enable `public_member_api_docs` for `coffin_core`
    - Read `packages/coffin_core/analysis_options.yaml` first, then add a `linter: rules: public_member_api_docs: true` section while keeping the existing `include` and `analyzer.exclude`.
    - Run `flutter analyze` in `packages/coffin_core` and fix any new warning in existing code (for example a missing doc comment).
    - _Requirements: 1.5, 8.7, 10.2_

- [x] 2. Contrast math
  - [x] 2.1 Implement `WcagContrast`
    - Create `packages/coffin_core/lib/src/theme/wcag_contrast.dart` with `aaNormalText`, `relativeLuminance(int argb)` and `ratio(int a, int b)` as in the design.
    - Import nothing from Flutter or `dart:ui`. Ignore the alpha byte. Doc-comment every public member.
    - Remove `.gitkeep` from `src/theme/` once real files exist.
    - _Requirements: 3.7, 8.3, 8.6, 8.7_

  - [x] 2.2 Write unit tests for `WcagContrast`
    - Create `packages/coffin_core/test/theme/wcag_contrast_test.dart`.
    - Black on white is 21, identical colors give 1, alpha byte is ignored, luminance of black is 0 and of white is 1.
    - _Requirements: 3.7, 10.3_

  - [x] 2.3 Write property test for contrast symmetry and bounds
    - Create `packages/coffin_core/test/theme/wcag_contrast_property_test.dart` (a small addition to the design's file list, so it does not share a file with the unit tests).
    - **Property 2: Contrast ratio is symmetric, bounded and reflexive**
    - Use glados `Glados2` with opaque colors from `any.intInRange(0, 0x1000000).map((rgb) => 0xFF000000 | rgb)`, at least 100 runs. Tag with `// Feature: haunted-theme, Property 2`.
    - **Validates: Requirements 3.6, 3.7**

- [x] 3. Contrast pair type
  - [x] 3.1 Implement `ContrastPair`
    - Create `packages/coffin_core/lib/src/theme/contrast_pair.dart` with the const constructor, `ratio` and `label` as in the design. It uses `Color.toARGB32()` and `WcagContrast.ratio`.
    - _Requirements: 3.4, 8.3, 8.7_

- [x] 4. Color tokens
  - [x] 4.1 Implement `CoffinColorTokens` with `night` and `daylight`
    - Create `packages/coffin_core/lib/src/theme/coffin_color_tokens.dart`. Import only `dart:ui` plus `contrast_pair.dart`.
    - Immutable `final` fields, const constructor, `name`, `brightness`, 13 color roles, `night`, `daylight`, `variants`.
    - Use the exact hex values from the design for both variants (night on-colors `#0E0B16`, daylight on-colors `#FFFFFF`).
    - Implement `contrastPairs` returning the 22 pairs: 18 text-role-on-surface pairs plus the 4 on-color pairs. Exclude glow and decoration-only colors.
    - Doc-comment every public member.
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 2.4, 2.5, 3.3, 3.4, 3.9, 8.3, 8.6, 8.7_

  - [x] 4.2 Write unit tests for `CoffinColorTokens`
    - Create `packages/coffin_core/test/theme/coffin_color_tokens_test.dart`.
    - Exact night hex values, daylight backgrounds light and text dark, both variants have the same type, `variants` holds both, `contrastPairs` has 22 entries including the 4 on-color pairs, night on-colors are dark (darker than their fills), glow colors absent.
    - _Requirements: 1.1, 1.2, 2.1, 2.2, 2.4, 2.5, 3.3, 3.4, 3.9, 10.3_

  - [x] 4.3 Write property test for token contrast
    - Create `packages/coffin_core/test/theme/contrast_pairs_property_test.dart`.
    - **Property 1: Every guaranteed token pair meets WCAG AA**
    - Generate with `any.choose(allPairs)` where `allPairs` flattens every variant's `contrastPairs` with the variant name. Assert `ratio >= 4.5` with a `reason` naming the variant, `label` and measured ratio. Add a companion plain test that iterates all pairs exhaustively, and a symmetry check on swapped foreground and background. At least 100 runs. Tag with `// Feature: haunted-theme, Property 1`.
    - **Validates: Requirements 1.2, 2.4, 3.1, 3.2, 3.5, 3.6, 3.8**

- [x] 5. Metrics
  - [x] 5.1 Implement `CoffinMetrics`
    - Create `packages/coffin_core/lib/src/theme/coffin_metrics.dart` with `cornerRadius = 16`, `minTapTarget = 48`, `focusRingWidth = 2`. Doc-comment each.
    - _Requirements: 4.4, 4.5, 6.3, 8.3, 8.7_

- [x] 6. Typography
  - [x] 6.1 Implement `CoffinTypography`
    - Create `packages/coffin_core/lib/src/theme/coffin_typography.dart` with `package`, `displayFamily`, `bodyFamily`, `displayFamilyName`, `bodyFamilyName` and `textTheme(CoffinColorTokens)`.
    - Use `TextStyle(fontFamily: ..., package: package, ...)`. Creepster for display and headline slots (w400), Outfit for title, body and label slots with the sizes and weights from the design. `bodySmall` uses `muted`, all others `text`. Leave `fontFamilyFallback` unset.
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 8.3, 8.7_

  - [x] 6.2 Write unit tests for `CoffinTypography`
    - Create `packages/coffin_core/test/theme/coffin_typography_test.dart`.
    - Display and headline slots resolve `fontFamily` to `packages/coffin_core/Creepster`; every other slot to `packages/coffin_core/Outfit`; all three body sizes are at least 14; every slot has `fontFamilyFallback == null`; `bodySmall` uses muted and others use text, for both token sets.
    - Widget test: pumping `Text` with a nonexistent package family throws no exception.
    - Assert on style strings only, since tests render with Ahem.
    - _Requirements: 5.1, 5.2, 5.3, 5.5, 5.6, 5.7, 10.3_

- [x] 7. Glow decoration
  - [x] 7.1 Implement `CoffinGlow`
    - Create `packages/coffin_core/lib/src/theme/coffin_glow.dart` with `decoration({color, intensity = 0.5, fill, borderRadius})`.
    - Clamp intensity to 0..1 and treat NaN as 0. At 0 return a const empty `boxShadow`. Otherwise two layers with zero offset, zero spread, blur `8 + 16i` and `24 + 40i`, alpha multipliers `0.25 + 0.35i` and `0.10 + 0.20i` applied to `color.a`. Default radius `CoffinMetrics.cornerRadius`.
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 7.2, 8.3, 8.7_

  - [x] 7.2 Write unit tests for `CoffinGlow`
    - Create `packages/coffin_core/test/theme/coffin_glow_test.dart`.
    - Fill and radius overrides, default radius 16, NaN and 0 give no shadows, intensity 1 gives two shadows, and a semantics test confirms a glow-decorated container adds no semantics nodes.
    - _Requirements: 6.3, 6.4, 6.6, 7.2, 10.3_

  - [x] 7.3 Write property test for glow shape
    - Create `packages/coffin_core/test/theme/coffin_glow_property_test.dart`.
    - **Property 3: Glow shape**
    - Colors from `any.intInRange(0, 0x100000000).map(Color.new)`, intensity from `any.doubleInRange(0.0001, 1)`, radius options null or fixed values. Assert non-empty shadows, zero offset, blur above 0, RGB equal to input, default radius 16. Tag with `// Feature: haunted-theme, Property 3`.
    - **Validates: Requirements 6.1, 6.2, 6.3**

  - [x] 7.4 Write property test for intensity clamping
    - In `coffin_glow_property_test.dart`.
    - **Property 4: Intensity is clamped**
    - Intensity from `any.doubleInRange(-5, 5)`. Assert the decoration equals the one for the clamped value, and has no shadows when the clamped value is 0. Tag with `// Feature: haunted-theme, Property 4`.
    - **Validates: Requirements 6.5, 6.6**

  - [x] 7.5 Write property test for glow blur monotonicity
    - In `coffin_glow_property_test.dart`.
    - **Property 5: Glow blur is monotonic**
    - For `a <= b` in `[0, 1]` (use `Glados2` and order the pair), total blur of `a` is at most that of `b`. Tag with `// Feature: haunted-theme, Property 5`.
    - **Validates: Requirements 6.8**

  - [x] 7.6 Write property test for glow determinism
    - In `coffin_glow_property_test.dart`.
    - **Property 6: Glow is deterministic**
    - Two calls with equal color, intensity, optional fill and optional radius return equal `BoxDecoration` values. Tag with `// Feature: haunted-theme, Property 6`.
    - **Validates: Requirements 6.7**

- [x] 8. Theme factories
  - [x] 8.1 Implement `CoffinTheme.dark()` and `CoffinTheme.light()`
    - Create `packages/coffin_core/lib/src/theme/coffin_theme.dart` with a private `_build(CoffinColorTokens)`.
    - `useMaterial3: true`, `ColorScheme` per the design mapping table (including transparent `surfaceTint`), `scaffoldBackgroundColor` = background, `textTheme` from `CoffinTypography`, `MaterialTapTargetSize.padded`, hover, focus and highlight colors.
    - Component themes: Card, Dialog, Filled, Elevated, Outlined and Text buttons (min size 48x48, 16 px shape, state overlays 8% hover, 12% focus, 16% pressed), IconButton (at least 48x48), InputDecoration (filled with raised, 16 px outline, 2 px primary focus border, error borders), AppBar.
    - Overlays use `primary` tint, except `FilledButton` which uses `onPrimary`.
    - Focused buttons get a 2 px `text` colored side as the focus ring.
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 7.1, 8.3, 8.7_

  - [x] 8.2 Write unit and widget tests for `CoffinTheme`
    - Create `packages/coffin_core/test/theme/coffin_theme_test.dart`, covering both variants.
    - `useMaterial3`, brightness, every ColorScheme role in the mapping table, scaffold background.
    - 16 px radius on card, dialog, buttons and input border; `minimumSize` 48x48 on buttons and icon button; widget test measuring pumped `FilledButton` and `IconButton` sizes at least 48x48.
    - Overlay colors for hovered, focused and pressed resolve to three distinct non-transparent values; the `FilledButton` overlay is based on `onPrimary` and the other buttons on `primary`.
    - Focus ring side color has contrast at least 3 against background, surface and raised using `WcagContrast`; input focus border likewise.
    - Two factory calls give equal `colorScheme` and `textTheme`.
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 7.1, 10.3_

- [x] 9. Barrel and boundary checks
  - [x] 9.1 Export the theme API from the barrel
    - Edit `packages/coffin_core/lib/coffin_core.dart`, keeping the existing `CoffinMark` export.
    - Add `show` exports for `CoffinColorTokens`, `CoffinGlow`, `CoffinMetrics`, `CoffinTheme`, `CoffinTypography`, `ContrastPair`, `WcagContrast`.
    - _Requirements: 8.1, 8.2_

  - [x] 9.2 Write barrel export and source-scan tests
    - Create `packages/coffin_core/test/theme/theme_sources_test.dart`.
    - Barrel: importing only `package:coffin_core/coffin_core.dart` gives access to all eight public names, including `ContrastPair` and `WcagContrast`; the barrel text uses `show` clauses.
    - Source scan: `wcag_contrast.dart`, `contrast_pair.dart` and `coffin_color_tokens.dart` contain no `package:flutter/` import (the tokens file may import `dart:ui` only); nothing under `packages/coffin_core/lib/` imports `apps/` or `package:hauntagotchi` / `package:graveyard`.
    - Config: `pubspec.yaml` declares both families, every declared font file exists, no `google_fonts` or `http` dependency, `glados` pinned; both OFL files exist; `CREDITS.md` at the repo root mentions both fonts and the OFL 1.1 (skip that check if the file is not reachable from the working directory).
    - _Requirements: 1.4, 5.3, 5.4, 5.8, 5.10, 8.1, 8.2, 8.4, 8.5, 8.6, 10.6_

- [x] 10. Checkpoint - Core package verification
  - Run `dart format --set-exit-if-changed .` , `flutter analyze` and `flutter test` in `packages/coffin_core`. Fix anything that fails.
  - Ensure all tests pass, ask the user if questions arise.
  - _Requirements: 10.1, 10.2, 10.5_

- [ ] 11. App adoption
  - [ ] 11.1 Update the `CoffinMark` doc comment
    - Edit `packages/coffin_core/lib/src/widgets/coffin_mark.dart`: replace the stale "tokens arrive in a later spec" wording with a note that it inherits colors from the ambient theme. Do not change behavior.
    - _Requirements: 8.7_

  - [ ] 11.2 Adopt the dark theme in Hauntagotchi
    - Read `apps/hauntagotchi/lib/main.dart`, the `ui/placeholder_screen.dart` file and the existing placeholder test first.
    - `main.dart`: `MaterialApp(title: ..., theme: CoffinTheme.dark(), home: const PlaceholderScreen())`, no longer const.
    - `PlaceholderScreen`: centered, scrollable column with `CoffinMark` inside a `DecoratedBox` using `CoffinGlow.decoration(color: scheme.primary, intensity: 0.6, fill: scheme.surface)`, a `Hauntagotchi` title with `displayMedium`, and the body line "Your ghost is getting hungry…" with `bodyLarge` in `onSurfaceVariant`. Read colors and styles from `Theme.of(context)` only. Import only `package:coffin_core/coffin_core.dart`.
    - Update the widget test to pump `MaterialApp(theme: CoffinTheme.dark(), home: PlaceholderScreen())` and check: `CoffinMark` and `Coffin` text still present, scaffold background equals `CoffinColorTokens.night.background`, title `fontFamily` equals `CoffinTypography.displayFamilyName`, body `fontFamily` equals `bodyFamilyName`, a `DecoratedBox` with non-empty `boxShadow` exists. Add a test that the app root has `MaterialApp.theme == CoffinTheme.dark()` (compare color scheme and text theme if `ThemeData` equality is unreliable).
    - Run `flutter test` and `flutter analyze` in the app.
    - _Requirements: 9.1, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8_

  - [ ] 11.3 Adopt the dark theme in Graveyard
    - Same as 11.2 for `apps/graveyard`, with title `Graveyard` and body line "This project has been dead for 214 days". Do not import anything from Hauntagotchi.
    - Run `flutter test` and `flutter analyze` in the app.
    - _Requirements: 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8_

- [ ] 12. Final verification
  - [ ] 12.1 Verify fonts reach the web build
    - Run `flutter build web` in `apps/hauntagotchi`, then confirm `build/web/assets/FontManifest.json` lists `packages/coffin_core/Creepster` and `packages/coffin_core/Outfit`. Report the result. If it fails, report the cause rather than editing the design.
    - Delete nothing under `build/` that was tracked by git (it is ignored).
    - _Requirements: 5.3, 5.4_

  - [ ]* 12.2 Add a DIARY.md entry
    - Append a short entry to `DIARY.md` summarizing the haunted-theme build: bundled fonts instead of `google_fonts`, contrast-tested palette, glow helper.
    - _Requirements: none (project log)_

- [ ] 13. Final checkpoint - Full workspace verification
  - Run `dart format --set-exit-if-changed .`, `flutter analyze` and `flutter test` in `packages/coffin_core`, `apps/hauntagotchi` and `apps/graveyard`. All must be clean and passing.
  - Confirm no secrets were added and `CREDITS.md` lists exact font source URLs.
  - Ensure all tests pass, ask the user if questions arise.
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.7_

## Notes

- Only the DIARY entry (12.2) is optional. Unit and property tests are required because the tech steering says pure logic and numeric invariants must be tested.
- Property tests use glados 1.1.7 with at least 100 runs each and carry the property number from the design.
- Several property tests share `coffin_glow_property_test.dart`, so they sit in different waves.
- The workflow ends once these tasks exist. Open `tasks.md` and start tasks from there.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.3", "1.4", "2.1", "5.1", "11.1"] },
    { "id": 1, "tasks": ["1.2", "3.1"] },
    { "id": 2, "tasks": ["2.2", "2.3", "4.1", "7.1"] },
    { "id": 3, "tasks": ["4.2", "4.3", "6.1", "7.2", "7.3"] },
    { "id": 4, "tasks": ["6.2", "7.4", "8.1"] },
    { "id": 5, "tasks": ["7.5", "8.2"] },
    { "id": 6, "tasks": ["7.6", "9.1"] },
    { "id": 7, "tasks": ["9.2", "11.2", "11.3"] },
    { "id": 8, "tasks": ["12.1", "12.2"] }
  ]
}
```
