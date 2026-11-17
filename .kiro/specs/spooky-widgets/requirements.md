# Requirements Document

## Introduction

The spooky-widgets feature adds four reusable widgets to `coffin_core`, in `packages/coffin_core/lib/src/widgets/`, and a gallery page that shows them off:

- **GhostLoader**: a small ghost that bobs slowly while something loads, with an optional caption. The ghost is drawn by its own public painter (`GhostPainter`) so that the later Hauntagotchi ghost-states spec can reuse it. This feature adds no moods.
- **TombstoneCard**: a tombstone-shaped card with a title, an optional date line and an optional child. When `onTap` is given, it has hover, press and focus states, a 48x48 minimum tap target and a semantic label.
- **FlickerText**: text that flickers like a dying candle, for emphasis only. The flicker pattern comes from a seed, so the same seed always gives the same pattern.
- **FogBackground**: slow drifting fog blobs behind a child widget. Positions come from a seed and stay inside the bounds.
- **CryptGallery**: a page that shows all four widgets in both the night and the daylight theme. Hauntagotchi serves it at `/gallery` through the existing `FogRouter` and `AppRoute`.

This feature first moves the internal `SeededRandom` generator from `lib/src/ai/` to a shared `lib/src/common/` folder (a pure move, see Requirement 22), so that the pure animation math, and later Graveyard and Hauntagotchi, share one copy. All animation math (bob offset, flicker schedule, fog positions) lives in pure Dart classes with no Flutter imports, so it is verified with glados property tests that run on the Dart VM and on Flutter Web (Chrome). The widgets reuse the existing theme: colors come only from `CoffinColorTokens`, glow from `CoffinGlow`, sizes and radii from `CoffinMetrics`, fonts from `CoffinTypography`. Motion follows the design steering document ("Haunted, not horror"): slow, floaty, subtle loops, and static frames when `MediaQuery.disableAnimations` is true.

## Dependency and Asset Notice

This feature adds NO new package, NO image asset, NO sound asset and NO `pubspec.yaml` change. `flutter_test` and `glados` are already dev dependencies of `coffin_core`. The Creepster and Outfit fonts are already bundled by the haunted-theme feature, so `CREDITS.md` is not changed. `DIARY.md` is not edited by this feature.

## Non-Goals

- No ghost moods or ghost states (happy, hungry, fading, dead). The ghost has one look.
- No AI wiring and no use of `CoffinAI`.
- No golden image tests.
- No Graveyard changes. Graveyard does not get the gallery route (see Assumption A1).
- No state-management code (no Riverpod) inside the widgets.
- No sound, no haptics and no image assets.
- No user-facing motion toggle in the gallery. Reduced motion follows `MediaQuery.disableAnimations` only.
- No change to existing public APIs of `coffin_core`, apart from additions to the Barrel.

## Glossary

- **Spooky_Widgets**: The four widgets GhostLoader, TombstoneCard, FlickerText and FogBackground.
- **Ghost_Loader**: The widget `GhostLoader`. It shows the ghost, bobbing, with an optional caption.
- **Ghost_Painter**: The public `CustomPainter` class `GhostPainter` that draws one ghost for a given size, bob offset and set of colors. It has no mood parameter.
- **Tombstone_Card**: The widget `TombstoneCard`.
- **Tombstone_Shape**: The outline of a Tombstone_Card: a flat base, straight sides and a round-arched top, with the bottom corners rounded by `CoffinMetrics.cornerRadius`. It is implemented as a `ShapeBorder` or as a `CustomPainter` path (the design phase chooses).
- **Flicker_Text**: The widget `FlickerText`.
- **Fog_Background**: The widget `FogBackground`.
- **Crypt_Gallery**: The page widget `CryptGallery`.
- **Gallery_Route**: The Hauntagotchi route at path `/gallery` with name `gallery`.
- **Ghost_Bob**: The pure Dart class that maps elapsed time to the vertical bob offset of the ghost.
- **Flicker_Schedule**: The pure Dart class that maps a Seed and elapsed time to a flicker opacity.
- **Fog_Field**: The pure Dart class that maps a Seed, a particle count and elapsed time to a list of Fog_Particles in unit coordinates.
- **Fog_Particle**: The immutable value for one fog blob: unit-square center `(x, y)` in 0.0 to 1.0, radius fraction, and alpha from 0.03 to 0.04.
- **Seed**: An integer that selects a pattern. The pure classes mask it with `0xFFFFFFFF`, so any Dart `int` is accepted and the effective range is 0 to 4294967295.
- **Elapsed_Time**: A non-negative integer number of milliseconds, up to 2^40, passed to the pure classes. Negative values are handled without throwing (see Requirement 7.7).
- **Reduced_Motion**: The state where `MediaQuery.disableAnimations` is true.
- **Static_Frame**: The single non-animated rendering that a looping widget shows under Reduced_Motion (defined per widget in Requirement 11).
- **Token_Set**: The `CoffinColorTokens` variant (`night` or `daylight`) that matches the brightness of the ambient `Theme`.
- **Loop_Widget**: A widget that runs an `AnimationController` loop: Ghost_Loader, Flicker_Text and Fog_Background.
- **Seeded_Generator**: The class `SeededRandom` (Mulberry32), the deterministic 32-bit pseudo-random generator used by the pure classes. After the move of Requirement 22 it lives in `packages/coffin_core/lib/src/common/seeded_random.dart` and stays internal (Decision Q1).
- **Seeded_Move**: The pure move of `SeededRandom` from `lib/src/ai/` to `lib/src/common/` described in Requirement 22.
- **Web_Safe**: Behavior that gives identical results on the Dart VM and on Flutter Web, using 32-bit integer arithmetic and integral doubles only (see Requirement 10).
- **Phone_Width**: A viewport width of 360 logical pixels (with 320 as the smallest tested width).
- **Desktop_Width**: A viewport width of 1280 logical pixels.
- **Barrel**: The file `packages/coffin_core/lib/coffin_core.dart`, the only public import for apps.
- **Widget_Property_Tests**: The glados property-based tests of Requirement 19.
- **Widget_Source_Scan**: The VM-only test of Requirement 13.5 that scans `lib/src/widgets/` for forbidden content.
- **Checkpoint**: A task in the plan after which all tests, format and analyze must pass (Requirement 21).

## Requirements

### Requirement 1: GhostLoader widget

**User Story:** As a Flutter developer using Coffin, I want a small bobbing ghost loader, so that waiting states feel alive instead of showing a plain spinner.

#### Acceptance Criteria

1. THE Ghost_Loader SHALL draw a ghost with the Ghost_Painter and SHALL contain no image asset.
2. THE Ghost_Loader SHALL accept an optional `size` (the ghost height in logical pixels) with a default of 64 and SHALL clamp it into 24 to 256.
3. THE Ghost_Loader SHALL accept an optional caption string and SHALL show it below the ghost in the `bodyMedium` style of `CoffinTypography.textTheme` for the Token_Set.
4. WHERE no caption is given, THE Ghost_Loader SHALL show the ghost alone and SHALL reserve no space for a caption.
5. WHILE Reduced_Motion is off, THE Ghost_Loader SHALL move the ghost vertically with the offset from Ghost_Bob, and SHALL NOT move the caption.
6. THE Ghost_Loader SHALL accept an optional `bobPeriodMs` and an optional `bobAmplitude`, SHALL use a bob period of 3600 ms and an amplitude of 6 logical pixels by default, and SHALL pass both to Ghost_Bob, which clamps them (Requirement 7.2), so that the loop is slow and subtle as the design steering document requires.
7. THE Ghost_Loader SHALL give the ghost a soft glow built from the `BoxShadow` values of `CoffinGlow` in the `primary` token.
8. THE Ghost_Loader SHALL be one semantic node whose label is the caption, or "Loading" when no caption is given, and SHALL exclude the painted ghost from the semantics tree.
9. THE Ghost_Loader SHALL mark its semantic node as a live region, so that assistive technology announces the loading state once.
10. THE Ghost_Loader SHALL keep the bobbing ghost inside its own layout bounds, so that the bob never moves paint outside the widget's box.

### Requirement 2: GhostPainter reuse

**User Story:** As the author of the later ghost-states spec, I want the ghost drawn by a standalone painter, so that I can reuse the same ghost in Hauntagotchi without copying drawing code.

#### Acceptance Criteria

1. THE Ghost_Painter SHALL be a public class in its own file under `lib/src/widgets/` and SHALL be exported from the Barrel.
2. THE Ghost_Painter SHALL take its colors, its bob offset and its glow as constructor parameters and SHALL read no `Theme`, no `BuildContext` and no controller.
3. THE Ghost_Painter SHALL draw a round-headed body with a wavy hem and two eyes, scaled to the `Size` given to `paint`.
4. THE Ghost_Painter SHALL contain no mood, expression or state parameter, so that the later spec adds them without changing this feature's callers.
5. THE Ghost_Painter SHALL implement `shouldRepaint` so that it returns true when the bob offset or any color changes, and false when all inputs are equal.
6. WHEN `paint` is called with a zero-width or zero-height `Size`, THE Ghost_Painter SHALL draw nothing and SHALL NOT throw.
7. THE Ghost_Loader SHALL draw the ghost body in the `text` token of the night Token_Set and in the `primary` token of the daylight Token_Set, SHALL draw the eyes in the `background` token and the glow in the `primary` token, and SHALL keep a contrast ratio of at least 3.0 for the body against the `background` token and for the eyes against the body in both Token_Sets, measured with `WcagContrast` (Decision N3 records the values).

### Requirement 3: TombstoneCard shape and content

**User Story:** As a Flutter developer using Coffin, I want a tombstone-shaped card, so that I can show an item as a grave with a title, a date and extra content.

#### Acceptance Criteria

1. THE Tombstone_Card SHALL require a `title` and SHALL accept an optional `dateLine` string and an optional `child` widget.
2. THE Tombstone_Card SHALL draw the Tombstone_Shape and SHALL clip its content to that shape.
3. THE Tombstone_Card SHALL use `CoffinMetrics.cornerRadius` for the two bottom corners of the Tombstone_Shape.
4. THE Tombstone_Card SHALL fill the shape with the `surface` token and SHALL draw a one-pixel outline in the `muted` token.
5. THE Tombstone_Card SHALL draw a resting soft glow in the `primary` token from the `BoxShadow` values of `CoffinGlow`, following the Tombstone_Shape outline.
6. THE Tombstone_Card SHALL show the title in the `headlineSmall` style, the date line in the `bodySmall` style and the child below them, in that order from top to bottom.
7. WHERE no `dateLine` is given, THE Tombstone_Card SHALL omit the date line and SHALL reserve no space for it.
8. WHERE no `child` is given, THE Tombstone_Card SHALL omit it and SHALL reserve no space for it.
9. THE Tombstone_Card SHALL keep all content inside the straight part of the shape, below the arch, with padding that clears the arched top. The arch SHALL be close to a half circle of the card width (140 logical pixels high at the maximum width of 300), and WHEN the card has a `child` it SHALL be at least 1.2 times as tall as it is wide.
10. THE Tombstone_Card SHALL accept an optional `showEpitaph` flag (default true). WHEN true, it SHALL draw a small engraved "R.I.P." centered horizontally in the arch, in the `muted` token and the Creepster display font at a size of at most 24 logical pixels, above the title and inside the arch. THE epitaph SHALL be decorative: it SHALL be excluded from semantics and SHALL NOT change the interactive card's label. WHEN false, no epitaph SHALL be drawn. The `muted` token SHALL keep at least 4.5:1 against `surface` and `raised`.
10. IF the title or the date line is longer than the available width, THEN THE Tombstone_Card SHALL wrap the title to at most 3 lines and the date line to at most 2 lines, and SHALL end a longer text with an ellipsis.
11. THE Tombstone_Card SHALL be a stateless-looking value to callers: it SHALL hold no data beyond its constructor arguments and the transient hover, press and focus state.

### Requirement 4: TombstoneCard interaction

**User Story:** As a user, I want a tappable tombstone to react when I hover, press or focus it, so that I can tell it is interactive.

#### Acceptance Criteria

1. WHERE `onTap` is given, THE Tombstone_Card SHALL call `onTap` once for each tap, and for each Enter or Space key press while focused.
2. WHERE `onTap` is given, THE Tombstone_Card SHALL have a hit area of at least `CoffinMetrics.minTapTarget` by `CoffinMetrics.minTapTarget` (48x48), even when its content is smaller.
3. WHERE `onTap` is given, WHILE a mouse pointer hovers the Tombstone_Card, THE Tombstone_Card SHALL show a hover state with a glow intensity strictly greater than the resting intensity, and SHALL show the click mouse cursor.
4. WHERE `onTap` is given, WHILE a pointer or key press is held on the Tombstone_Card, THE Tombstone_Card SHALL show a pressed state that differs from both the resting state and the hover state, using the `raised` token as fill and a glow intensity greater than the hover intensity.
5. WHERE `onTap` is given, WHILE the Tombstone_Card has keyboard focus, THE Tombstone_Card SHALL draw a focus outline of width `CoffinMetrics.focusRingWidth` in the `primary` token.
6. WHERE `onTap` is given, THE Tombstone_Card SHALL expose a semantic node that is a button, is focusable, has a tap action, and has a label equal to the title, followed by a comma and the date line when a date line is given.
7. WHERE the caller supplies a `semanticLabel`, THE Tombstone_Card SHALL use it instead of the default label of criterion 6.
8. WHERE no `onTap` is given, THE Tombstone_Card SHALL be a non-interactive node: no button flag, no tap action, no hover state, no press state, no focus stop and the default cursor.
9. WHILE Reduced_Motion is off, THE Tombstone_Card SHALL animate the change between resting, hover and pressed states over 300 ms with an ease-in-out curve.
10. WHILE Reduced_Motion is on, THE Tombstone_Card SHALL switch between states instantly, and SHALL still show the hover, pressed and focus states.
11. THE Tombstone_Card SHALL use no `AnimationController` that loops, so that a resting Tombstone_Card leaves no running ticker.
12. IF `onTap` changes from non-null to null while the pointer is hovering or pressing the Tombstone_Card, THEN THE Tombstone_Card SHALL return to the resting, non-interactive state without throwing.

### Requirement 5: FlickerText widget

**User Story:** As a Flutter developer using Coffin, I want text that flickers like a candle, so that I can emphasize one line without making the page hard to read.

#### Acceptance Criteria

1. THE Flicker_Text SHALL require a `text` string and SHALL accept an optional `style`, `textAlign`, `maxLines`, `overflow` and `seed` (default 0).
2. WHERE no `style` is given, THE Flicker_Text SHALL use the `bodyLarge` style of `CoffinTypography.textTheme` for the Token_Set.
3. WHILE Reduced_Motion is off, THE Flicker_Text SHALL set the opacity of the text from the Flicker_Schedule built from the `seed`.
4. THE Flicker_Text SHALL change only the opacity of the text, and SHALL NOT change its size, position, layout or color.
5. THE Flicker_Text SHALL use the same layout size for every opacity, so that a flicker never reflows surrounding widgets.
6. THE Flicker_Text SHALL expose one semantic node whose label is exactly the `text` for every frame, and SHALL exclude the inner text from the semantics tree so that a screen reader reads the text once.
7. THE Flicker_Text SHALL keep its semantic label independent of the `seed`, of the current opacity and of Reduced_Motion.
8. WHEN two Flicker_Text widgets are built with the same `seed` and the same elapsed time, THE two widgets SHALL show the same opacity.
9. THE Flicker_Text SHALL document, in its doc comment, that it is for emphasis only and should be used on short lines.

### Requirement 6: FogBackground widget

**User Story:** As a Flutter developer using Coffin, I want slow drifting fog behind my content, so that a screen feels misty without hurting readability.

#### Acceptance Criteria

1. THE Fog_Background SHALL require a `child` and SHALL accept optional `seed` (default 0) and `particleCount` (default 5).
2. THE Fog_Background SHALL clamp `particleCount` into 0 to 24, so that a negative count draws no fog and a count above 24 draws 24 blobs.
3. THE Fog_Background SHALL paint the fog behind the `child` and SHALL lay out the `child` exactly as it would be laid out without the fog.
4. THE Fog_Background SHALL draw each Fog_Particle as a soft round blob with a radial fade, using the `primary` token with an alpha from 0.03 to 0.04 (Decision Q5), and SHALL clip the blobs to its own bounds.
5. THE Fog_Background SHALL take the positions of all Fog_Particles from the Fog_Field, and SHALL map each unit position `(x, y)` to the pixel position `(x * width, y * height)` of its own bounds.
6. WHILE Reduced_Motion is off, THE Fog_Background SHALL move the Fog_Particles with a loop whose slowest particle completes a back-and-forth cycle in at least 30 s and whose fastest completes one in at most 90 s.
7. THE Fog_Background SHALL exclude the fog layer from the semantics tree and SHALL leave the semantics of the `child` unchanged.
8. THE Fog_Background SHALL ignore pointer events on the fog layer, so that the `child` receives all taps and hovers.
9. WHEN the incoming bounds have a width or height of 0, THE Fog_Background SHALL paint no fog and SHALL NOT throw.
10. THE Fog_Background SHALL keep body text legible: for the `text` and `muted` tokens of each Token_Set, the contrast ratio against the `background` token and against the `surface` token, each blended with five overlapping Fog_Particles at the maximum alpha of 0.04, SHALL be at least 4.5, measured with `WcagContrast` (Decision Q5 records the computed values).
11. THE Fog_Background SHALL state in its doc comment: "Put long body text on an opaque surface, not straight on the fog; the 4.5:1 guarantee covers up to 5 overlapping blobs." (Decision N2).

### Requirement 7: Ghost_Bob pure math

**User Story:** As a maintainer, I want the bob offset computed by a pure Dart class, so that it can be property-tested without Flutter.

#### Acceptance Criteria

1. THE Ghost_Bob SHALL be a plain Dart class with no Flutter imports, constructed with a period in milliseconds and an amplitude in logical pixels.
2. THE Ghost_Bob SHALL clamp the period into 2500 to 5000 ms and the amplitude into 2 to 10 logical pixels, and SHALL expose the clamped values.
3. THE Ghost_Bob SHALL provide `offsetAt(elapsedMs)` that returns a finite offset within the closed range from minus the amplitude to plus the amplitude for every Elapsed_Time.
4. THE Ghost_Bob SHALL return the same offset for `elapsedMs` and `elapsedMs + period`, so that the loop has no jump.
5. THE Ghost_Bob SHALL be eased: the offset SHALL change by at most `6 * amplitude * 16 / period + 1e-9` (1.5 times the average speed of `4 * amplitude / period`, which is the peak speed of a smoothstep ping-pong) between two Elapsed_Times 16 ms apart, so that the motion has no visible jump (Decision D1 records why the first draft of this bound was replaced).
6. THE Ghost_Bob SHALL compute the offset using only addition, subtraction, multiplication, division, comparison and absolute value, with no `sin`, `cos` or other transcendental function, so that results are identical on the Dart VM and on Flutter Web.
7. WHEN `elapsedMs` is negative, THE Ghost_Bob SHALL treat it as the equivalent time inside the loop (for example through a non-negative modulo) and SHALL return an offset within the same range without throwing.
8. THE Ghost_Bob SHALL provide a static offset of 0 for use as the Static_Frame, which lies within the range of criterion 3.

### Requirement 8: Flicker_Schedule pure math

**User Story:** As a maintainer, I want the flicker pattern computed from a seed by a pure Dart class, so that the same seed always gives the same flicker and the pattern stays safe to look at.

#### Acceptance Criteria

1. THE Flicker_Schedule SHALL be a plain Dart class with no Flutter imports, constructed from a Seed.
2. THE Flicker_Schedule SHALL describe a looping pattern of 16 levels, each reached at the start of a step of 400 ms and eased towards the next level during that step, so that one loop lasts 6400 ms.
3. THE Flicker_Schedule SHALL draw each level from the Seeded_Generator as a whole percentage from 75 to 100, and SHALL expose it as an opacity from 0.75 to 1.0.
4. THE Flicker_Schedule SHALL provide `opacityAt(elapsedMs)` that returns a finite opacity from 0.75 to 1.0 inclusive for every Elapsed_Time and every Seed, so that the text is never fully invisible and never dimmer than 75 percent.
5. THE Flicker_Schedule SHALL give the same schedule and the same `opacityAt` result for the same Seed, on every call, every instance and every platform.
6. THE Flicker_Schedule SHALL ease from the last level of the loop back to the first level, so that `opacityAt(t)` equals `opacityAt(t + 6400)` and the loop has no jump (Decision D2).
7. THE Flicker_Schedule SHALL change the opacity between neighboring levels by interpolation over the step, and the change between two neighboring levels SHALL NOT exceed 0.25.
8. THE Flicker_Schedule SHALL keep the step at or above 334 ms, so that the opacity has at most 3 local extrema in any window of 1000 ms and the text never flashes more than 3 times per second.
9. THE Flicker_Schedule SHALL include at least one level of at most 0.90 and at least one level of exactly 1.0 in every loop, so that the flicker is visible and the text returns to full brightness. IF a Seed would give no such level, THEN THE Flicker_Schedule SHALL deterministically lower one level to 0.85 or raise one level to 1.0.
10. THE Flicker_Schedule SHALL give different schedules for at least two Seeds in the range 0 to 15, so that the seed has an effect.
11. WHEN `elapsedMs` is negative, THE Flicker_Schedule SHALL treat it as the equivalent time inside the loop and SHALL return an opacity from 0.75 to 1.0 without throwing.
12. THE Flicker_Schedule SHALL provide a static opacity of 1.0 for use as the Static_Frame.
13. FOR every Token_Set and for each of the `background`, `surface` and `raised` tokens, THE `text` token drawn at the minimum opacity of 0.75 over that token SHALL have a contrast ratio of at least 4.5, measured with `WcagContrast`, so that the dimmest flicker frame stays AA-readable. IF this fails for any pair, THEN the design phase SHALL raise the minimum opacity and update criteria 3 and 4.

### Requirement 9: Fog_Field pure math

**User Story:** As a maintainer, I want fog positions computed from a seed by a pure Dart class, so that they are deterministic and always inside the bounds.

#### Acceptance Criteria

1. THE Fog_Field SHALL be a plain Dart class with no Flutter imports, constructed from a Seed and a particle count, and SHALL clamp the count into 0 to 24.
2. THE Fog_Field SHALL provide `particlesAt(elapsedMs)` that returns exactly as many Fog_Particles as the clamped count, for every Elapsed_Time.
3. THE Fog_Field SHALL return, for every Seed, count and Elapsed_Time, Fog_Particles whose unit center `(x, y)` lies in the closed range 0.0 to 1.0 on both axes.
4. THE Fog_Field SHALL give each Fog_Particle a radius fraction from 0.35 to 0.60 of the longer side of the bounds, and an alpha from 0.03 to 0.04, constant over time.
5. THE Fog_Field SHALL give the same particles for the same Seed, count and Elapsed_Time, on every call, every instance and every platform.
6. THE Fog_Field SHALL move each particle back and forth between two end points that are both inside the unit square, using the same eased motion as Ghost_Bob (polynomial, no transcendental functions), so that particles never wrap, never jump and never leave the bounds.
7. THE Fog_Field SHALL give each particle a back-and-forth period from 30000 to 90000 ms and a start phase from the Seeded_Generator.
8. THE Fog_Field SHALL give the same positions for `elapsedMs` and `elapsedMs + period` for each particle, so that the loop has no jump.
9. THE Fog_Field SHALL provide a pixel mapping function `toBounds(particle, width, height)` that returns a center `(px, py)` and a radius in logical pixels with `0 <= px <= width`, `0 <= py <= height` and `0 <= radius <= min(width, height)` for every `width` and `height` that is a finite number at or above 0, including 0 and tiny values such as 0.5.
10. IF `width` or `height` is negative, NaN or infinite, THEN THE `toBounds` function SHALL treat that dimension as 0 and SHALL NOT throw.
11. WHEN `elapsedMs` is negative, THE Fog_Field SHALL treat it as the equivalent time inside the loop and SHALL NOT throw.
12. THE Fog_Field SHALL provide a static set of particles at Elapsed_Time 0 for use as the Static_Frame.
13. WHEN the Seed changes, THE Fog_Field SHALL give a different set of particles for at least two Seeds in the range 0 to 15, so that the seed has an effect.

### Requirement 10: Determinism and web safety

**User Story:** As a developer testing in Chrome, I want the pure math to give identical results on the Dart VM and on the web, so that seeds mean the same thing everywhere.

#### Acceptance Criteria

1. THE pure classes Ghost_Bob, Flicker_Schedule and Fog_Field SHALL NOT use `dart:math` `Random`, because its sequence is not guaranteed stable across platforms and releases.
2. THE pure classes SHALL draw all seeded values from the Seeded_Generator, a 32-bit generator that uses only integer operations kept within 32 bits (with the 32-bit multiply done in exact 16-bit parts, as `SeededRandom` does) and integral doubles. The generator is the shared `SeededRandom` of Requirement 22.
3. THE pure classes SHALL mask every Seed with `0xFFFFFFFF` before use, so that a negative Seed or a Seed above 4294967295 gives the same result on the VM and on the web and does not throw.
4. THE pure classes SHALL compute every double result from exact integer numerators using only addition, subtraction, multiplication, division and comparison (no `sin`, `cos`, `pow` or `exp`), with every integer intermediate below 2^53, so that the result is the same on the VM and on the web (Decision D3).
5. THE feature SHALL include a fixed-value test that pins the first outputs of each pure class for a few fixed Seeds (for example 0, 1, 42 and 4294967295), and the same test file SHALL run unchanged on the VM and in Chrome.
6. THE pure classes SHALL NOT read the clock, `DateTime` or any global state.
7. THE pure classes SHALL be immutable: after construction, no call changes the result of a later call.

### Requirement 11: Reduced motion

**User Story:** As a user who is sensitive to motion, I want all loops to stop and show a calm static frame, so that the widgets are comfortable to look at.

#### Acceptance Criteria

1. THE Loop_Widgets SHALL read `MediaQuery.disableAnimations` (through `MediaQuery.maybeDisableAnimationsOf`, treating null as false) to decide between the animated and the static behavior.
2. WHILE Reduced_Motion is on, THE Ghost_Loader SHALL show the Static_Frame: the ghost at bob offset 0, with the caption shown, and SHALL keep its `AnimationController` stopped, so that no ticker is active.
3. WHILE Reduced_Motion is on, THE Flicker_Text SHALL show the Static_Frame: the text at opacity 1.0, and SHALL keep its `AnimationController` stopped, so that no ticker is active.
4. WHILE Reduced_Motion is on, THE Fog_Background SHALL show the Static_Frame: the fog blobs at the positions of the Fog_Field at Elapsed_Time 0, with the same count, radii and alphas as the animated version, and SHALL keep its `AnimationController` stopped, so that no ticker is active.
5. WHILE Reduced_Motion is on, THE Tombstone_Card SHALL show states instantly (Requirement 4.10).
6. WHEN Reduced_Motion changes while a Loop_Widget is mounted, THE Loop_Widget SHALL stop its loop or start it again without being rebuilt by its parent, and SHALL NOT throw.
7. THE Crypt_Gallery SHALL show every widget under Reduced_Motion in its Static_Frame, and SHALL add no loop of its own.

### Requirement 12: Animation lifecycle and performance

**User Story:** As a maintainer, I want loops to clean up after themselves and to repaint only what changed, so that the widgets do not leak tickers or waste frames.

#### Acceptance Criteria

1. WHEN a Loop_Widget is removed from the tree, THE Loop_Widget SHALL dispose its `AnimationController`, so that no ticker remains running after the dispose.
2. THE Loop_Widgets SHALL wrap their animated painting in a `RepaintBoundary`, so that an animation frame does not repaint widgets outside the animated layer.
3. THE Fog_Background SHALL paint the fog layer in its own `RepaintBoundary`, separate from the `child`, so that a fog frame does not repaint the `child`.
4. WHILE a Loop_Widget is not visible because its `TickerMode` is disabled (for example on an off-screen route), THE Loop_Widget SHALL pause its ticker through the standard ticker provider mixin.
5. THE Loop_Widgets SHALL drive their loops with a repeating `AnimationController` and SHALL NOT call `setState` on every frame; the painter or an `AnimatedBuilder` SHALL listen to the controller.
6. WHEN the `seed`, the `particleCount`, the period or the amplitude of a Loop_Widget changes, THE Loop_Widget SHALL rebuild its pure math object and SHALL keep the controller running without restarting it needlessly.
7. THE Loop_Widgets SHALL NOT create a `Timer` or a `Future.delayed`, so that widget tests need no pending-timer cleanup.

### Requirement 13: Theme and token usage

**User Story:** As a maintainer, I want every color, glow, size and font to come from the existing theme, so that the widgets match both themes and a future retheme changes them in one place.

#### Acceptance Criteria

1. THE Spooky_Widgets and the Crypt_Gallery SHALL take every color from the Token_Set of `CoffinColorTokens`, possibly with a changed alpha, and SHALL hard-code no color.
2. THE Spooky_Widgets SHALL take glow shadows from `CoffinGlow`, the corner radius and the minimum tap target from `CoffinMetrics`, and text styles from `CoffinTypography.textTheme`.
3. THE Spooky_Widgets SHALL work under `CoffinTheme.dark()` and `CoffinTheme.light()`, and SHALL pick the Token_Set from the brightness of the ambient `Theme`. The design phase SHALL decide whether to read the tokens through the `ColorScheme` that `CoffinTheme` builds from them or by matching the brightness against `CoffinColorTokens.variants`, and SHALL record it.
4. THE Spooky_Widgets SHALL use only text on tokens whose pairing is listed in `CoffinColorTokens.contrastPairs`, so that normal-size text meets WCAG AA 4.5:1 in both themes.
5. THE Widget_Source_Scan SHALL scan every file under `packages/coffin_core/lib/src/widgets/` and SHALL fail when it finds `Color(0x`, `Colors.`, `Color.fromARGB`, `Color.fromRGBO`, an import of `dart:io`, an import of `package:hive`, an import from `apps/`, or an API key pattern. The scan SHALL be marked VM-only.
6. THE Widget_Source_Scan SHALL fail when a pure math file (Ghost_Bob, Flicker_Schedule, Fog_Field, Fog_Particle and the other files of the pure math folder) or the Seeded_Generator file in `lib/src/common/` contains an import of `package:flutter`, `dart:ui`, `dart:math` or `dart:io`, a seedless `Random(` or `Random.secure`, or a `.hashCode` access. The scan of the Seeded_Generator file keeps the `.hashCode` check that the AI source scan applied to it before the Seeded_Move.
7. THE feature SHALL add no API keys, secrets or tokens to the repository.

### Requirement 14: Accessibility

**User Story:** As a user of a screen reader or a keyboard, I want the widgets to describe themselves and be reachable, so that the spooky look does not exclude me.

#### Acceptance Criteria

1. THE Spooky_Widgets SHALL expose the semantics defined in Requirements 1.8, 1.9, 4.6, 4.7, 4.8, 5.6 and 6.7, and no widget SHALL add a duplicate or unlabeled node.
2. THE Spooky_Widgets SHALL NOT convey information by animation or glow alone: the caption, title, date line and text carry all meaning.
3. WHERE a Tombstone_Card has `onTap`, THE Tombstone_Card SHALL be reachable and activatable with the keyboard alone (Tab to focus, Enter or Space to activate).
4. THE Flicker_Text SHALL never drop below the minimum opacity of Requirement 8.4 and SHALL never flash more than 3 times per second (Requirement 8.8).
5. THE Crypt_Gallery SHALL mark each theme panel heading and the page title as a semantic header.

### Requirement 15: Responsive layout

**User Story:** As a judge opening the app on a phone or a desktop browser, I want every widget and the gallery to fit the screen, so that nothing is cut off.

#### Acceptance Criteria

1. THE Spooky_Widgets SHALL lay out without a `RenderFlex` overflow or any layout exception at the widths of 320, 360 and 1280 logical pixels.
2. THE Spooky_Widgets SHALL lay out without overflow at a text scale factor of 1.0 and of 1.5.
3. THE Tombstone_Card SHALL fill the width given by its parent up to a maximum of 300 logical pixels, and SHALL be centered when the parent is wider.
4. WHEN the Tombstone_Card, Ghost_Loader or Fog_Background is placed in a parent with bounded height smaller than its natural height, THE widget SHALL NOT throw, and the Tombstone_Card content SHALL stay scrollable or clipped inside the shape rather than overflowing it.
5. WHEN the Fog_Background receives unbounded constraints on one axis, THE Fog_Background SHALL size itself to its `child` on that axis, and SHALL NOT throw.
6. THE Crypt_Gallery SHALL stack the night panel and the daylight panel vertically at widths below 900 logical pixels, and place them side by side at 900 or more.
7. THE Crypt_Gallery SHALL scroll vertically when its content is taller than the viewport.

### Requirement 16: CryptGallery page

**User Story:** As a judge or a developer, I want one page that shows all four widgets in both themes, so that I can see the skeleton's look at a glance.

#### Acceptance Criteria

1. THE Crypt_Gallery SHALL show two panels, one titled "Night" using `CoffinTheme.dark()` and one titled "Daylight" using `CoffinTheme.light()`, each applied through a `Theme` widget around the panel content.
2. THE Crypt_Gallery SHALL show in each panel: a Ghost_Loader with a caption, a Ghost_Loader without a caption, a non-interactive Tombstone_Card with a date line and a child, an interactive Tombstone_Card, a Flicker_Text, and a Fog_Background that wraps sample content.
3. THE Crypt_Gallery SHALL paint each panel with the `surface` token of that panel's Token_Set, inside a 16 px rounded frame with a one-pixel `muted` outline, so that both panels look like a pair and so that the daylight panel shows in daylight colors even inside a dark app.
4. WHEN the interactive Tombstone_Card is tapped, THE Crypt_Gallery SHALL show a short snack bar message with spooky copy and SHALL NOT navigate. `CoffinTheme` SHALL style snack bars as floating, with the `raised` background, the `text` color, 16 px rounded corners, and text and action colors of at least 4.5:1 against `raised` in both Token_Sets.
   The Fog_Background sample in each panel SHALL be 240 logical pixels high.
5. THE Crypt_Gallery SHALL use short, witty, slightly spooky copy that is never mean to the user and never gory, for example "This project has been dead for 214 days".
6. WHERE the caller supplies an `onBack` callback, THE Crypt_Gallery SHALL show a button, at least 48x48, labeled "Back to the crypt" that calls `onBack`.
7. THE Crypt_Gallery SHALL use the same Seed for the same sample in the night and the daylight panel, so that both panels show the same pattern.
8. THE Crypt_Gallery SHALL be a plain widget that needs no `GoRouter`, so that it can be tested without a router.
9. THE Crypt_Gallery SHALL live in `coffin_core` and SHALL be exported from the Barrel, because the gallery shows what a new app gets for free (Decision Q3).

### Requirement 17: Hauntagotchi gallery route

**User Story:** As a judge testing Hauntagotchi by URL, I want to open the gallery at a known address, so that I can see the widgets without extra steps.

#### Acceptance Criteria

1. THE Hauntagotchi app SHALL declare an `AppRoute` with path `/gallery` and name `gallery` in `apps/hauntagotchi/lib/src/ui/app_routes.dart`, so that it uses the existing `FogRouter` and fog transition.
2. WHEN the app is opened at `/#/gallery`, THE Hauntagotchi app SHALL show the Crypt_Gallery inside the fog transition page.
3. THE Gallery_Route SHALL pass an `onBack` callback to the Crypt_Gallery that navigates to the home route `/` through go_router.
4. THE Hauntagotchi app SHALL keep the home route and its `PlaceholderScreen` unchanged, and SHALL add no link to the gallery, so that the gallery is reachable by direct URL only (Decision Q2).
5. THE Hauntagotchi test `app_routes_test.dart` that currently asserts a single declared route SHALL be updated to the two routes `/` and `/gallery`, and a new test SHALL confirm that `/gallery` shows the Crypt_Gallery and that the back button returns to the Placeholder_Screen.
6. THE Hauntagotchi app SHALL import only `package:coffin_core/coffin_core.dart` for the gallery.
7. THE Graveyard app SHALL receive no change from this feature (see Assumption A1).

### Requirement 18: Barrel export and structure

**User Story:** As a maintainer, I want the new code to follow the project structure and the barrel rules, so that the skeleton stays easy to read.

#### Acceptance Criteria

1. THE widget source files SHALL live under `packages/coffin_core/lib/src/widgets/` in `snake_case.dart` files with one public widget or class per file (for example `ghost_loader.dart`, `ghost_painter.dart`, `tombstone_card.dart`, `flicker_text.dart`, `fog_background.dart` and `crypt_gallery.dart`).
2. THE pure math files SHALL live under `packages/coffin_core/lib/src/widgets/` as well (the design phase MAY group them in a subfolder), with one public class per file.
3. THE Barrel SHALL export `GhostLoader`, `GhostPainter`, `TombstoneCard`, `FlickerText`, `FogBackground` and `CryptGallery` with `show` clauses, in the sorted order of the existing exports.
4. THE Barrel SHALL NOT export the pure math classes (Ghost_Bob, Flicker_Schedule, Fog_Field, Fog_Particle) or the Seeded_Generator (see Assumption A3).
5. THE feature SHALL include a barrel test, in the pattern of `test/ai/ai_barrel_test.dart`, that builds each exported widget and the Ghost_Painter using only `package:coffin_core/coffin_core.dart`.
6. EVERY public API in the widget source files SHALL carry a doc comment.
7. THE tests SHALL live under `packages/coffin_core/test/widgets/`, mirroring the `lib/` layout.
8. THE coffin_core package SHALL import nothing from `apps/hauntagotchi` or `apps/graveyard`, and the two apps SHALL NOT import from each other.
9. THE feature SHALL keep the existing `CoffinMark` and its test unchanged.

### Requirement 19: Property-based verification of the math

**User Story:** As a maintainer, I want the numeric rules checked across many generated inputs, so that edge cases such as zero sizes and huge seeds cannot break the widgets.

#### Acceptance Criteria

1. THE Widget_Property_Tests SHALL use glados and SHALL run each property at least 100 times, and each property file SHALL check, with a `RunCounter`, that the property body ran.
2. THE Widget_Property_Tests SHALL use only Web_Safe generators: `anyIntBetween`, `anyListBetween`, `any.simple` and `combineN`, and SHALL NOT use `any.int`, `any.intInRange`, `any.list`, `any.listWithLengthInRange`, string generators or `uint*` generators.
3. THE feature SHALL contain an independent copy of the Web_Safe generators and `RunCounter` in `packages/coffin_core/test/widgets/support/`, with its own self-test, and SHALL NOT import test helpers from `test/ai/` (see Assumption A4).
4. THE Widget_Property_Tests SHALL include a property: FOR ALL periods, amplitudes and Elapsed_Times, the Ghost_Bob offset is within the amplitude range and `offsetAt(t)` equals `offsetAt(t + period)` (Requirements 7.3 and 7.4).
5. THE Widget_Property_Tests SHALL include a property: FOR ALL periods, amplitudes and Elapsed_Times, the offsets at two times 16 ms apart differ by no more than the bound of Requirement 7.5, and a negative Elapsed_Time gives an offset in range (Requirements 7.5 and 7.7).
6. THE Widget_Property_Tests SHALL include a property: FOR ALL Seeds in the full range 0 to 4294967295 and all Elapsed_Times, the Flicker_Schedule opacity is within 0.75 to 1.0 (Requirement 8.4).
7. THE Widget_Property_Tests SHALL include a property: FOR ALL Seeds, two Flicker_Schedules from the same Seed give the same opacity at every sampled Elapsed_Time, and the opacity at `t` equals the opacity at `t + 6400` (Requirements 8.5 and 8.6).
8. THE Widget_Property_Tests SHALL include a property: FOR ALL Seeds, sampling the Flicker_Schedule every 10 ms over a loop shows at most 3 local extrema in any window of 1000 ms, neighboring level steps of at most 0.25, at least one level of at most 0.90 and at least one level of 1.0 (Requirements 8.7, 8.8 and 8.9).
9. THE Widget_Property_Tests SHALL include a property: FOR ALL Seeds, counts (including negative and above 24) and Elapsed_Times, the Fog_Field returns the clamped number of particles, each with unit center in 0.0 to 1.0, radius fraction in 0.35 to 0.60 and alpha in 0.03 to 0.04 (Requirements 9.2, 9.3 and 9.4).
10. THE Widget_Property_Tests SHALL include a property: FOR ALL Seeds, counts, widths and heights from 0 up to 4000 (including 0 and values below 1), the pixel mapping returns centers inside the bounds and a radius from 0 to the shorter side (Requirement 9.9).
11. THE Widget_Property_Tests SHALL include a property: FOR ALL Seeds and counts, two Fog_Fields from the same Seed and count give equal particles at every sampled Elapsed_Time, and the particles at `t` equal the particles at `t + period` for each particle (Requirements 9.5 and 9.8).
12. THE Widget_Property_Tests SHALL include a property: FOR ALL integers as Seeds, including negative values and values above 2^32, the pure classes give the same result as the same Seed masked to 32 bits and do not throw (Requirement 10.3).
13. THE Widget_Property_Tests SHALL include a property: FOR ALL Seeds in a sampled range, the `text` token at the minimum flicker opacity over each of the `background`, `surface` and `raised` tokens keeps a contrast ratio of at least 4.5 in both Token_Sets (Requirement 8.13).
14. THE feature SHALL include unit tests with fixed values for the pure classes (Requirement 10.5), the clamping rules, and the exact edge cases (count 0, count 24, size 0, size 0.5).
15. THE pure tests SHALL contain no `dart:io` import except in files marked VM-only, so that all other pure test files run in Chrome.

### Requirement 20: Widget tests

**User Story:** As a maintainer, I want widget tests for the behavior the pure tests cannot see, so that reduced motion, semantics, tap targets, overflow, themes and tickers stay correct.

#### Acceptance Criteria

1. THE feature SHALL include widget tests that confirm that under Reduced_Motion each Loop_Widget shows its Static_Frame and runs no ticker, checked with `tester.binding.transientCallbackCount` equal to 0 after a pump.
2. THE feature SHALL include widget tests that confirm that under normal motion each Loop_Widget runs one ticker and that the painted bob offset, opacity or particle positions change between two pumps of different elapsed time.
3. THE feature SHALL include widget tests that confirm that after a Loop_Widget is replaced by an empty widget, `transientCallbackCount` is 0 and no exception is thrown (no ticker left running after dispose).
4. THE feature SHALL include widget tests that toggle `MediaQuery.disableAnimations` while a Loop_Widget stays mounted and confirm the ticker stops and starts (Requirement 11.6).
5. THE feature SHALL include semantics tests (`tester.getSemantics` or `SemanticsHandle`) that confirm the labels, the button flag and the tap action defined in Requirements 1.8, 1.9, 4.6, 4.7, 4.8, 5.6 and 6.7.
6. THE feature SHALL include a widget test that confirms the interactive Tombstone_Card has a hit area of at least 48x48 even with a tiny child, and that a non-interactive Tombstone_Card makes no such claim.
7. THE feature SHALL include widget tests for the hover state (a mouse `TestGesture` with `PointerDeviceKind.mouse`), the pressed state, the keyboard focus state and Enter or Space activation of the Tombstone_Card.
8. THE feature SHALL include widget tests that pump each widget and the Crypt_Gallery at 320, 360 and 1280 logical pixels, at text scales 1.0 and 1.5, and confirm that `tester.takeException()` is null.
9. THE feature SHALL include widget tests that pump each widget and the Crypt_Gallery under `CoffinTheme.dark()` and `CoffinTheme.light()`, and confirm that no exception is thrown and that the painters receive the colors of the matching Token_Set.
10. THE feature SHALL include a widget test that confirms that the Crypt_Gallery shows two panels with the two theme brightnesses, stacks them below 900 logical pixels and places them side by side at 900 or more.
11. THE feature SHALL NOT include golden image tests.
12. THE widget tests SHALL use `pump` with explicit durations rather than `pumpAndSettle` for Loop_Widgets, because a repeating controller never settles.
13. THE Hauntagotchi route tests of Requirement 17.5 SHALL pass in addition to the coffin_core tests.

### Requirement 21: Quality gates and execution plan

**User Story:** As a maintainer, I want a one-task-at-a-time plan with checkpoints, so that the feature is verified in small steps and never left half broken.

#### Acceptance Criteria

1. THE feature code SHALL pass `dart format` with no changes.
2. THE feature code SHALL pass `flutter analyze` with zero warnings across the workspace.
3. WHEN `flutter test` runs in `packages/coffin_core` and in `apps/hauntagotchi`, THE test suite SHALL pass before any task is marked done.
4. THE implementation plan SHALL execute one task at a time, and SHALL NOT start the next task before the current one is complete and its tests pass.
5. THE implementation plan SHALL order the work as: the Seeded_Move of Requirement 22 first, with its own full test run; then the pure math classes (Ghost_Bob, Flicker_Schedule, Fog_Field) with their unit and property tests; then the widgets with their widget tests; then the Crypt_Gallery, the Hauntagotchi route, and the Barrel with its barrel test.
6. THE implementation plan SHALL include a Checkpoint after the Seeded_Move, a Checkpoint after the pure math and its tests, a Checkpoint after the widgets and their tests, and a final Checkpoint at the end.
7. WHEN each Checkpoint is reached, THE team SHALL run `dart format` (no changes), `flutter analyze` (zero warnings) and `flutter test` in both packages that were touched, and all SHALL pass.
8. WHEN the Checkpoint after the pure math is reached, THE team SHALL also run the pure test files in Chrome with `flutter test --platform chrome` (excluding VM-only files) and they SHALL pass.
9. WHEN the final Checkpoint is reached, THE team SHALL also run the pure test files in Chrome and SHALL build both apps for the web with `flutter build web` (Hauntagotchi and Graveyard), and both builds SHALL succeed.
10. THE feature SHALL add no new package, no asset and no `pubspec.yaml` change, and no specification document (the files under `.kiro/specs/` of another spec) SHALL be edited. The code and test edits of the Seeded_Move are the only edits to files that belong to the coffin-ai feature.
11. IF a Checkpoint fails, THEN the team SHALL fix the failure before starting the next task.

### Requirement 22: Shared SeededRandom (Seeded_Move)

**User Story:** As a Flutter developer using Coffin, I want one shared seeded generator in the skeleton, so that Graveyard, Hauntagotchi and the spooky widgets all use the same web-safe randomness.

#### Acceptance Criteria

1. THE class `SeededRandom` SHALL live in `packages/coffin_core/lib/src/common/seeded_random.dart`, and the file `packages/coffin_core/lib/src/ai/seeded_random.dart` SHALL no longer exist.
2. THE Seeded_Move SHALL change no behavior: apart from the file path, the source of `SeededRandom` SHALL be byte-identical, and every output for every seed SHALL stay the same.
3. THE AI source that used `SeededRandom` (`lib/src/ai/offline_engine.dart`) SHALL import it from the new path, and no other file under `lib/` SHALL change except the new file location.
4. THE Barrel SHALL NOT export `SeededRandom`, which stays internal.
5. THE existing tests `test/ai/seeded_random_test.dart` and `test/ai/seeded_random_property_test.dart` SHALL move to `test/common/` (tests mirror `lib/`), with only their import paths changed.
6. THE existing `coffin_core` tests (985 tests before the move) SHALL pass after the move, and the test count after the move SHALL remain 985, with unchanged assertions and unchanged fixed values, apart from import paths and the flagged item of criterion 7.
7. IF a test needs a change beyond an import path, THEN the design SHALL list that change as a flagged item, and the change SHALL be limited to that item (the approved flagged item is one allow-list branch in `_importProblems` of `test/ai/ai_sources_test.dart` for exactly `offline_engine.dart` importing `../common/seeded_random.dart`, plus self-check `expect` lines inside the existing test "import rules flag bad directives" that keep the same import rejected in every other file; Decision N1).
8. THE Seeded_Move SHALL be the first task of the plan, and THE team SHALL run `dart format` (no changes), `flutter analyze` (zero warnings) and the full `flutter test` of `packages/coffin_core` for it, as its own Checkpoint, before any other task of this feature starts.

## Resolved decisions

The user answered the open questions. Each answer is recorded below, with the requirements it changed.

- **Q1 (Seeded_Generator source): option (b), move.** `SeededRandom` moves to `lib/src/common/` as one shared copy, because Graveyard and Hauntagotchi will also need seeded randomness. It is a pure move with no behavior change. It stays internal (the existing Barrel does not export it, and the AI source scan lists it as an internal name). The move is the first task and has its own test run. *Changed:* new Requirement 22; Glossary (Seeded_Generator, Seeded_Move); Introduction; Requirements 10.2, 13.6, 21.5, 21.6 and 21.10.
- **Q2 (Gallery access): direct URL only.** `/#/gallery` is the only way in for now. The placeholder screen gets no link. A later spec, which replaces the placeholder with the real Hauntagotchi home, adds the link. *Changed:* Requirement 17.4.
- **Q3 (Gallery location): `coffin_core`, exported.** The gallery is the skeleton's showcase of what a new app gets for free, so it belongs to the kit. *Changed:* Requirement 16.9 (no change to the location, the reason is recorded).
- **Q4 (Glow shape): reuse the `CoffinGlow` values.** The tombstone paints the `BoxShadow` values of `CoffinGlow` along the Tombstone_Shape path. The `CoffinGlow` API does not change. *Changed:* none (Requirements 3.5 and 1.7 already say this).
- **Q5 (Fog readability): readability wins.** The design computed the contrast of `text` and `muted` over four overlapping blobs. At the original maximum alpha of 0.08 both Token_Sets fail (night `muted` 4.41 over `background`, daylight `muted` 4.48). The maximum alpha is lowered to 0.05 for both Token_Sets, which gives at least 4.61 on `background` and `surface` (design.md, "Fog readability"). Particle alpha is 0.03 to 0.05. *Changed:* Requirements 6.4, 6.10, 9.4, 19.9 and the Glossary entry Fog_Particle.

- **N1 (AI source scan): approved.** One allow-list branch for exactly `offline_engine.dart` importing `../common/seeded_random.dart`, and a self-check inside the existing test so the same import is still rejected elsewhere. The test count stays 985. *Changed:* Requirement 22.6 and 22.7.
- **N2 (fog beyond four blobs): accepted, option (a).** The fog paints behind the child, so text on opaque surface cards is never affected. The limit goes into the `FogBackground` doc comment. *Changed:* Requirement 6.11 (new).
- **N3 (ghost color): `text` token in night, `primary` token in daylight.** Eyes in `background`, glow in `primary`. Measured with `WcagContrast`: night body versus `background` 15.99 and eyes versus body 15.99; daylight body versus `background` 5.84 and eyes versus body 5.84. *Changed:* Requirement 2.7.
- **N4 (seed masking on the web): accepted.** Verified in Chrome at Checkpoint A. If it fails, the property range shrinks and the limit is documented. *Changed:* none.

### Design-phase adjustments

The design phase found five places where a first-draft number or wording could not be met, and corrected them as Requirements 6.10 and 7.5 allow.

- **D1 (Requirement 7.5).** The first-draft bound `2 * amplitude * 16 / period * 2` equals 1.0 times the average speed of the ping-pong. An eased motion must be faster than its average in the middle, so no smoothstep motion can meet it. The peak speed of a smoothstep ping-pong is exactly 1.5 times the average speed `4 * amplitude / period`, so the bound is now `6 * amplitude * 16 / period` plus a floating-point margin of 1e-9.
- **D2 (Requirements 8.2 and 8.6).** "Each level held" and "last level equal to the first level" would give a flat 400 ms hold at the end of each loop. The schedule now eases from the last level back to the first, which also gives `opacityAt(t) == opacityAt(t + 6400)` with no jump.
- **D3 (Requirement 10.4).** "At most one final division" cannot hold for position math that scales by an amplitude. The rule is now: exact integer numerators, only `+ - * /` and comparisons, no transcendental function, integer intermediates below 2^53.
- **D4 (Requirements 11.2 to 11.4).** "Run no `AnimationController`" is read as "keep the controller stopped, so no ticker is active", which is what the tests (`transientCallbackCount` equal to 0) check.
- **D5 (Requirement 13.3).** The Token_Set is picked with an exhaustive switch on the ambient brightness (dark → night, light → daylight) instead of matching against `CoffinColorTokens.variants` with a night fallback. The fallback could never run because brightness has only two values and both are covered, so its test was removed (found in task 4.2; user decision).

## Accepted assumptions

All of A1 to A7 are accepted by the user.

- **A1 (accepted).** Graveyard does not get the gallery or any change unless the user says so.
- **A2 (accepted).** `CryptGallery` is exported from the Barrel so that apps use it through the public API (confirmed by Q3).
- **A3 (accepted).** The pure math classes stay internal. Tests inside `coffin_core` import them from `src/`. The later ghost-states spec can ask to export `GhostBob` if it needs it.
- **A4 (accepted).** The Web_Safe glados generators and `RunCounter` are copied into `test/widgets/support/` as an independent copy, as coffin-ai did, instead of importing helpers from `test/ai/support/`. This duplicates about 50 lines of test code on purpose, so that each feature's tests stand alone.
- **A5 (accepted, with the changes of Q5 and D1 to D2).** The numbers in this document (3600 ms period, 6 px amplitude, 16 levels of 400 ms, opacity floor 0.75, 24 particles at most, 30 to 90 s fog periods, 900 px breakpoint) are starting values chosen to satisfy the steering rules (slow, subtle, at most 3 flashes per second, WCAG AA). The fog alpha range is now 0.03 to 0.04 (see V1).
- **A6 (accepted).** Chrome runs use `flutter test --platform chrome` on the pure test files. Widget tests run on the VM, and the Chrome check of widget code is covered by the web builds.
- **A7 (accepted).** The gallery is not shown in the apps' navigation and has no persistence.
- **V1 (Visual polish after reviewing /#/gallery).** TombstoneCard: maximum width 300 px, arch height 140 px, portrait with a child (height at least 1.2 times the width). FogBackground: default 5 blobs, radius 0.35 to 0.60 of the longer side, radial fade with a middle stop, peak alpha 0.03 to 0.04. With blobs this large, 5 peaks can overlap, so the guarantee now covers 5 overlapping blobs and the alpha cap was recomputed with `WcagContrast` (worst case 4.65, night `surface` `muted`; 0.045 gives 4.45 and fails). Gallery panels use the `surface` token with a rounded `muted` outline, and the fog sample is 240 px high. `CoffinTheme` gets a snack bar theme. *Changed:* Requirements 3.9, 6.1, 6.10, 6.11, 9.4, 15.3, 16.3, 16.4, 19.9 and the Glossary entry Fog_Particle.
- **V2 (Epitaph).** The empty arch gets a decorative "R.I.P." (20 px Creepster, `muted`, 1 px shadow in `background` for the engraved look, 56 px below the top), excluded from semantics, with `showEpitaph` (default true) to turn it off. *Changed:* Requirement 3.10 (new).
