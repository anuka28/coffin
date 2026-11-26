# Implementation Plan: graveyard-polish

## Overview

The plan builds the polish in Dart, bottom-up. First comes the domain: `GroundHeight` and `VerdictSlotHeight`, each with unit tests and glados property tests (Properties 1 to 3), closed by a checkpoint. Next comes the scene: the `stoneKey` on `GraveTombstone`, the Ground_Field in the scrolling content with the Ground_Band kept for the Empty_State and the All_Risen_State, the post-frame measurement of the Stone_Box bottom, bottom alignment of every row together with the update of the three named layout tests, and the class comment. Then comes the séance sheet: content-sized surface, the reserved Verdict_Slot, the accent-bar Verdict_Block, and its alignment with the steps. The remaining widget tests follow, and a final checkpoint closes the plan. Each task builds on the previous ones and ends wired into the app, so no code is left orphaned. No package, asset or lock change is part of this plan.

Rules for every task:

- Edit only `apps/graveyard/lib`, `apps/graveyard/test` and `.kiro/specs/graveyard-polish`. Nothing changes in `packages/coffin_core`, `apps/hauntagotchi`, `tool/`, any `pubspec.yaml`, `pubspec.lock`, `CREDITS.md`, `.github/` or any other spec.
- Never create files outside the repository, including `/tmp`. Scratch output goes inside the repo only if a task says so, and is deleted before the task ends.
- Doc-comment every public API in `lib/src/domain`. One public class per file, `snake_case.dart`. Code passes `dart format` and `flutter analyze` with zero warnings.
- The two new domain files (`lib/src/domain/scene/ground_height.dart` and `lib/src/domain/seance/verdict_slot_height.dart`) import no Flutter library, no `dart:ui`, no `dart:io`, no `package:coffin_core` and nothing from `lib/src/ui`, and call no `DateTime.now()`. The existing `test/source_rules/domain_sources_test.dart` scans `lib/src/domain` recursively and must pass without any change.
- Apps import only `package:coffin_core/coffin_core.dart`, never files under `coffin_core/lib/src`. No state-management package. No package is added.
- Every new color comes from `CoffinColorTokens`, with no color literal in the changed code. Every user-facing string stays in `GraveyardCopy`, and this feature adds none.
- Existing test files stay as they are. The one exception is `test/ui/graveyard_scene_test.dart`, where only the three tests `360 px shows one column`, `768 px shows 2 to 4 columns` and `1280 px shows 2 to 4 columns` change (task 4.4). New tests go in new files. If a measurement of the changed code fails any other existing test, the code changes and the test does not.
- Tests mirror `lib/` without `src/`: `lib/src/domain/scene/x.dart` is tested in `test/domain/scene/x_test.dart`, and `lib/src/ui/x.dart` in `test/ui/x_test.dart`. Tests under `test/domain` and `test/data` never import `dart:io`.
- Widget tests use `tester.pump(duration)` and never a real wait, `Future.delayed`, a real `Timer`, the network or real Hive. No test depends on the time zone of the machine. The Test_Widths are 320, 360, 768 and 1280. The Test_Scales are 1.0, 1.5 and 2.0. Base_Tolerance is 1 logical pixel.
- Property tests use glados with web-safe generators only (built on `anyIntBetween` and `anyDoubleBetween` from `test/domain/support/grave_generators.dart`, no `any.int` and no `uint*`), every generated integer below 2^53, `numRuns: 200`, and the comment header `// Feature: graveyard-polish, Property N: <title>` plus `// Validates: Requirements ...`.
- Every task, including every test task, is required. None is optional.
- A task is marked done only after `flutter test` passes in `apps/graveyard`.

## Tasks

- [x] 1. Ground height (domain)
  - [x] 1.1 Implement `GroundHeight`
    - Create `lib/src/domain/scene/ground_height.dart` with `abstract final class GroundHeight` and `static double of({required double groundTop, required double contentBottom, required double viewportHeight})` returning `max(0, contentBottom - groundTop, viewportHeight - groundTop)`. It never returns a negative value, also when `groundTop` lies below both bottoms. Doc-comment the class and `of`. Import only `dart:math`.
    - _Requirements: 2.2, 2.3, 2.4, 3.1, 12.11_

  - [x] 1.2 Write unit tests for `GroundHeight`
    - Create `test/domain/scene/ground_height_test.dart`: a short scene where the viewport term wins; a tall scene where the content term wins; both terms equal; `groundTop` below both bottoms returns 0; `groundTop` of 0; `contentBottom` smaller than `groundTop` returns the viewport term or 0, never a negative number.
    - _Requirements: 2.2, 2.3, 2.4, 3.1_

  - [x] 1.3 Write property test for the ground reaching the viewport bottom
    - **Property 1: Ground fills at least to the viewport bottom**
    - **Validates: Requirements 2.2, 2.4**
    - Create `test/domain/scene/ground_height_property_test.dart` with a `RunCounter`-style run-count assertion. Over `groundTop` in `[0, viewportHeight]` and `contentBottom >= groundTop`, check `groundTop + of(...) >= viewportHeight`.

  - [x] 1.4 Write property test for the ground reaching the content bottom
    - **Property 3: Ground height never shrinks the content area**
    - **Validates: Requirements 2.3, 3.1**
    - Add this test to `test/domain/scene/ground_height_property_test.dart` with its own run-count assertion. Over any `groundTop`, `contentBottom >= groundTop` and `viewportHeight >= 0`, check `of(...) >= contentBottom - groundTop` and `of(...) >= 0`.

- [x] 2. Verdict slot height (domain)
  - [x] 2.1 Implement `VerdictSlotHeight`
    - Create `lib/src/domain/seance/verdict_slot_height.dart` with `abstract final class VerdictSlotHeight` and `static double of({required double width, required double lineHeight, required double minHeight, required int maxCodeUnits, required double charsPerLine})`. It computes `lines = ceil(maxCodeUnits / charsPerLine)` and returns `max(minHeight, lines * lineHeight)`. Unusable input (non-finite, `charsPerLine <= 0`, negative `maxCodeUnits`) returns `minHeight` and never throws. Doc-comment the class and `of`. Import only `dart:math`.
    - _Requirements: 8.1, 8.4, 8.5, 12.11_

  - [x] 2.2 Write unit tests for `VerdictSlotHeight`
    - Create `test/domain/seance/verdict_slot_height_test.dart`: `maxCodeUnits` 140 at a representative `charsPerLine` and `lineHeight` gives the pinned number of lines times the line height; the result is never below `minHeight` (a short text with a tall `minHeight`); a narrower `width` (smaller `charsPerLine`) gives a taller slot; a larger `lineHeight` (text scale) gives a taller slot; `maxCodeUnits` of 0 returns `minHeight`; unusable input returns `minHeight` and throws nothing.
    - _Requirements: 8.1, 8.4, 8.5_

  - [x] 2.3 Write property test for the verdict slot height
    - **Property 2: Verdict slot height is monotone and bounded below**
    - **Validates: Requirements 8.1, 8.5**
    - Create `test/domain/seance/verdict_slot_height_property_test.dart` with a run-count assertion. Over `maxCodeUnits >= 0`, `charsPerLine > 0`, `lineHeight > 0` and `minHeight >= 0`, check `of(...) >= minHeight`, and check that a larger `maxCodeUnits` with the other inputs fixed never gives a smaller result.

- [x] 3. Checkpoint - Domain complete
  - Run each command in order, with the working directory shown.
  - In `/Users/ranmanlabs/Documents/Kiroween/coffin/apps/graveyard`: `dart format --output=none --set-exit-if-changed .` (must exit 0).
  - In `/Users/ranmanlabs/Documents/Kiroween/coffin/apps/graveyard`: `flutter analyze` (zero issues).
  - In `/Users/ranmanlabs/Documents/Kiroween/coffin/apps/graveyard`: `flutter test` (all graveyard tests pass).
  - In `/Users/ranmanlabs/Documents/Kiroween/coffin/apps/graveyard`: `flutter test --platform chrome test/domain test/data` (domain and data tests pass in Chrome).
  - In the repository root `/Users/ranmanlabs/Documents/Kiroween/coffin` (the path list is relative to the repo root): `git status --porcelain -- pubspec.lock pubspec.yaml apps/graveyard/pubspec.yaml packages/coffin_core apps/hauntagotchi tool` must print nothing. This also catches new untracked files.
  - Fix any failure at its cause. Create no file outside the repository, including `/tmp`.
  - Ensure all tests pass, ask the user if questions arise.
  - _Requirements: 11.1, 11.2, 11.7_

- [ ] 4. Scene: ground in the scrolling content
  - [ ] 4.1 Add `stoneKey` to `GraveTombstone`
    - Edit `lib/src/ui/grave_tombstone.dart`: add the optional constructor parameter `GlobalKey? stoneKey`, doc-commented as the key attached to the layout box of the stone for hosts that measure the base of the stone. Apply it as the `key` of the `ConstrainedBox(maxWidth: GraveTombstone.maxStoneWidth)` that is the child of the `Center` and the parent of `Transform.translate`, so the keyed box lies outside the Rise translate and contains neither the Séance control nor the Delete button. The existing `super.key` is not reused. No change to layout, tilt, rise or controls, and every existing call compiles unchanged because the parameter is optional.
    - _Requirements: 1.8, 11.4, 13.4_

  - [ ] 4.2 Place the Ground_Field in the scroll content and keep the Ground_Band for empty states
    - Edit `lib/src/ui/graveyard_scene.dart`. When the rows are non-empty, replace the single child of the `SingleChildScrollView` with an inner `Stack` whose first layer is the Ground_Field and whose second layer is the existing `Column`, un-modified otherwise. The Ground_Field is one `CustomPaint(painter: GroundPainter(tokens: ...))` wrapped in `IgnorePointer` and `ExcludeSemantics`, full width, with `top = stoneBase - GroundPainter.maxSoftEdge` and `height = GroundHeight.of(groundTop:, contentBottom:, viewportHeight:)`. While `_stoneBase` is null (first frame) the Ground_Field is in the tree with height 0 and paints nothing. The ground has no implicit animation, no `AnimatedContainer` and no fade.
    - When the rows are empty (Empty_State and All_Risen_State), keep today's `Positioned` Ground_Band with left 0, right 0, bottom 0 and a height of 34% of the Scene_Box height, outside the `SingleChildScrollView`, wrapped in `IgnorePointer` and `ExcludeSemantics`. Exactly one of Ground_Field and Ground_Band is in the tree, chosen by the same `rows.isEmpty` check that already decides the `noRows` widget, with no `Visibility`. Keep exactly one `SingleChildScrollView` between the Fog_Layer and the Living_Row. Leave the Night_Sky, the Fog_Layer, the Living_Row, the header and the `noRows` widget at their current place. `GroundPainter`'s constructor, `maxSoftEdge` and `shouldRepaint` stay unchanged.
    - _Requirements: 1.1, 1.3, 1.5, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 3.1, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

  - [ ] 4.3 Measure the First_Row_Base after layout
    - Edit `lib/src/ui/graveyard_scene.dart`: add to `_GraveyardSceneState` the fields `GlobalKey _stoneKey`, `GlobalKey _contentKey`, `double? _stoneBase`, `double? _contentHeight`, `bool _needsMeasure = true`, `Size? _lastViewport` and `TextScaler? _lastScaler`. Pass `_stoneKey` through `_rows` and `_tombstone` to the first `GraveTombstone` of the first row only (also in the rising branch), and give the rows `Column` the `_contentKey`.
    - Add `_measureGround()`, scheduled with one `addPostFrameCallback` only while `_needsMeasure` is set (cleared when scheduled). It reads the keyed Stone_Box render box and the content render box and computes the base as `stone.localToGlobal(Offset(stone.size.width / 2, stone.size.height), ancestor: content).dy`. The keyed `ConstrainedBox` sits above `Transform.translate`, so this value is the resting base at every Rise_Progress: there is no `(1 - progress) * riseDistance` correction and no `RiseProgress` term. It calls `setState` only when a value is new or differs by more than 0.5 px. It never derives the base from the row height or the control-block height.
    - Set `_needsMeasure` on: first build, a change of the viewport size (compared with `_lastViewport` in the outer `LayoutBuilder`), a change of the text scaler (compared with `_lastScaler`), a change of the rows list including `Grave` equality (in `didUpdateWidget`, so add, import, delete, raise and reorder all trigger it), and the end of a rise. A scroll, a rise tick and a repaint do not trigger a measurement. The measurement must not throw when the keys are absent (for example the last grave was deleted).
    - _Requirements: 1.2, 1.3, 1.4, 1.6, 1.7, 1.8, 2.1, 3.2, 3.3, 3.4_

  - [ ] 4.4 Bottom-align the Stones in every row and update the three layout tests
    - Edit `lib/src/ui/graveyard_scene.dart`: change `crossAxisAlignment` of the `Row` built by `_rows` from `CrossAxisAlignment.start` to `CrossAxisAlignment.end`. `SceneLayout`, the column counts (one column below 720 logical pixels, two to four from 720), the cell widths, the Rise animation and the tilt stay unchanged. Edit nothing in `scene_layout.dart`.
    - In the same task, edit `test/ui/graveyard_scene_test.dart`, group `layout`, only the local helper `columns`: read `tester.getBottomLeft(find.byType(GraveTombstone).at(i)).dy` instead of `getTopLeft`, name the list `bottoms`, and compare the bases within 1 px. Keep the 8 graves and the three test names `360 px shows one column`, `768 px shows 2 to 4 columns` and `1280 px shows 2 to 4 columns` with their expected column counts. No other line of that file changes.
    - Confirm that the three updated tests, every other test of that file, and `test/ui/ground_painter_test.dart`, `test/ui/resurrection_layout_test.dart`, `test/ui/layout_test.dart` and `test/ui/seance_sheet_*_test.dart` pass, so the task ends with no failing test.
    - _Requirements: 1.7, 11.4, 11.5, 13.1, 13.2, 13.3, 13.4, 13.5_

  - [ ] 4.5 Update the class comment of `GraveyardScene` and the doc comment of `GroundPainter`
    - Edit the class doc comment in `lib/src/ui/graveyard_scene.dart`: remove the statements that the ground is a strip at the bottom of the scene and that "the ground never scrolls", and state that the ground scrolls with the rows as the Ground_Field, and that the Ground_Band stays a static band in the Empty_State and the All_Risen_State. Edit only the doc comment of `GroundPainter` in `lib/src/ui/ground_painter.dart`, using the wording of the design, with no code change.
    - _Requirements: 11.6, 5.5_

- [ ] 5. Séance sheet
  - [ ] 5.1 Size the sheet surface to its content
    - Edit `lib/src/ui/seance_sheet.dart`: change the content `Align(alignment: Alignment.topCenter, ...)` to `Align(alignment: Alignment.topCenter, heightFactor: 1, ...)` inside the existing `SafeArea` and the `viewInsets.bottom` `Padding`, keeping the `ConstrainedBox(maxWidth: 560)` and the `SingleChildScrollView`. Keep `isScrollControlled: true` and `useSafeArea: true` in `showSeanceSheet`. Short content gives a sheet as tall as its content with a scroll extent of 0. Tall content (text scale 2.0, short screen) fills the offered height and scrolls to every part. The close button stays at the top of the content, aligned with the top of the title.
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7_

  - [ ] 5.2 Reserve the Verdict_Slot
    - Edit `lib/src/ui/seance_sheet.dart`: replace the bare pending `Center(child: GhostLoader(...))` and the settled `Text` of `_verdictArea` with one Verdict_Slot, a `ConstrainedBox(constraints: BoxConstraints(minHeight: reserved))` holding the `GhostLoader` (centered) while pending and the verdict after that. `reserved` is `VerdictSlotHeight.of(lineHeight:, minHeight:, maxCodeUnits: verdictMaxLength, charsPerLine:)`, where `charsPerLine` and `lineHeight` are measured once per `(width, text scale)` pair with `TextPainter` for the verdict style, and `minHeight` is at least the rendered `GhostLoader` height. The same `reserved` value is used for the pending, ready and fallback states. The height is recomputed when the text scale or the width changes. A verdict longer than the slot grows the slot, because the constraint is a minimum and not a fixed height. The verdict stays at the top of the slot.
    - Do not change the tests `a reply moves neither the score nor the steps` and `the safe line after a failure moves nothing`; the title, the score card and the steps must not move when the verdict arrives.
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 10.3_

  - [ ] 5.3 Build the accent-bar Verdict_Block
    - Edit `lib/src/ui/seance_sheet.dart`: render the settled verdict (generated or `GraveyardCopy.safeVerdictLine`, same style for both) as one Verdict_Block: a vertical accent bar of 3 logical pixels in `CoffinColorTokens.primary` at the left edge, with the height of the verdict text, followed by one `Text` in `CoffinColorTokens.text` whose font size is larger than the step text, start-aligned and wrapping inside the block width. The bar is a `DecoratedBox` or `Container` with the `primary` color, never `raised`. The block adds no `Icon`, no extra `Text` and no `DecoratedBox` with the `raised` color, so the sheet keeps one `Icon`, ten `Text` widgets in the ready state and one raised `DecoratedBox` (the score card). Keep the semantics: one container node with the verdict as label, `liveRegion` true and the child semantics excluded. Keep the existing 450 ms reveal, and show the block at once under Reduced_Motion. Keep the order of the sheet: title, score card, steps, verdict.
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 9.9, 10.4_

  - [ ] 5.4 Align the Verdict_Block with the steps
    - Edit `lib/src/ui/seance_sheet.dart`: place the Verdict_Block so its left edge (the left edge of the accent bar) is at the left edge of the step number column of the steps, and its right edge is at the right edge of the steps, within 0.5 logical pixels, at each Test_Width and each Test_Scale. The `GhostLoader` stays centered in the Verdict_Slot. If the 32 logical pixel number column and the bar need a shared inset constant, define it once in `seance_sheet.dart` and use it for both.
    - _Requirements: 10.1, 10.2, 10.3_

- [ ] 6. Widget tests for the polish
  - [ ] 6.1 Write the ground placement tests
    - Create `test/ui/graveyard_ground_test.dart`: for each Test_Width and each Test_Scale, with one, three and eight graves, the Horizon (top of the Ground_Field plus `min(GroundPainter.maxSoftEdge, groundHeight / 2)`) is within Base_Tolerance of the First_Row_Base, with the First_Row_Base measured directly from the rendered Stone_Box bottom in the coordinate system of the rows `Column` and not by subtracting the control-block height; the Ground_Field is a descendant of the one `SingleChildScrollView`, spans the full width of the Scene_Box and uses `CoffinColorTokens.background` of the active theme; after scrolling the content by a fixed distance the Ground_Field top and the First_Row_Base move by the same distance within Base_Tolerance and the Ground_Field bottom is at or below the Scene_Box bottom; scrolled to the maximum extent the ground reaches the bottom of the content including the bottom padding; with several rows every Stone_Base of the second and later rows is below the Horizon and the ground is one continuous area; a scene with a Living_Row, a header or both above the rows has the Horizon below them; a scene with one grave extends the ground to the bottom of the Scene_Box; both themes (`CoffinTheme.dark()` and daylight).
    - _Requirements: 1.1, 1.2, 1.3, 1.5, 1.6, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 3.1, 3.2, 12.1, 12.2, 12.4, 12.5_

  - [ ] 6.2 Write the test that the Horizon equals the Stone_Box bottom
    - Create `test/ui/graveyard_ground_stone_box_test.dart`, named after Requirement 1.8: at text scale 1.0 and at text scale 2.0, at widths 360 and 768, pump a scene whose first row holds stones that differ in height (a long wrapping name and a short name). Read the Stone_Box of the first stone as the render box of the keyed `ConstrainedBox` (the `stoneKey` box, above `Transform.translate`) and its bottom as `box.localToGlobal(Offset(box.size.width / 2, box.size.height), ancestor: contentBox).dy`, with `contentBox` the rendered rows `Column`; this is the test's own measurement and does not read `_stoneBase`. Expect the Horizon to be within Base_Tolerance of that bottom at both scales. Expect the control-block height (the `Wrap` of the same `GraveTombstone`) to differ between scale 1.0 and scale 2.0 (96 and 128 logical pixels in the design measurements), which proves the Horizon follows the Stone_Box bottom and not the control block. Repeat after scrolling by a fixed distance.
    - _Requirements: 1.8, 12.2, 12.3_

  - [ ] 6.3 Write the ground state tests
    - Create `test/ui/graveyard_ground_states_test.dart`: with rows, exactly one Ground_Field and no Ground_Band; in the Empty_State (empty graves and the load-error scene) and the All_Risen_State, exactly one Ground_Band with left 0, right 0, bottom 0 and a height of 34% of the Scene_Box height, no Ground_Field, and the band stays at its place when the Scroll_Content scrolls; switching from empty to non-empty rows and back swaps the two in the same frame with no exception (`tester.takeException()` is null); adding and deleting a grave moves the Horizon to the new First_Row_Base with no exception; a width change that changes the column count (below and from 720 logical pixels) recomputes the Horizon; the Ground_Field and the Ground_Band are each wrapped in `IgnorePointer` and `ExcludeSemantics`, a tap on the ground reaches the control under it, and the existing semantic tree gains no node; Reduced_Motion (`disableAnimations` true) paints static ground with no animation of its own; a rising grave keeps the Horizon at the same place before, during and after the rise; one Night_Sky is painted and the Fog_Layer is an ancestor of the Scroll_Content.
    - _Requirements: 1.4, 2.7, 3.3, 3.4, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 5.1, 5.2, 5.3, 5.4, 5.6, 12.5, 12.6, 12.7_

  - [ ] 6.4 Write the post-frame measurement tests
    - Create `test/ui/graveyard_ground_measure_test.dart`: after the first `pumpWidget` the Ground_Field has height 0 and paints nothing; after one `pump()` it sits at its measured place within Base_Tolerance of the First_Row_Base, with no move from a fallback position; after that frame a further `pump()` leaves the ground rect unchanged within 0.5 px and `tester.binding.hasScheduledFrame` is false, so no rebuild loop runs; re-measure after a resize (change `tester.view.physicalSize`, for example from 400 to 768 wide so the column count changes, then `pump()` twice) puts the Horizon within Base_Tolerance of the new First_Row_Base; the same after a text scale change and after deleting the first grave; a scroll alone schedules no measurement; deleting the last grave while another grave rises throws nothing.
    - _Requirements: 1.2, 1.4, 1.6, 3.3, 3.4, 4.6, 12.2_

  - [ ] 6.5 Write the bottom alignment tests
    - Create `test/ui/graveyard_row_base_test.dart`: for each Test_Width and each Test_Scale, a first row of Stones with different heights (a long wrapping name and a short name) has Stone_Base values within Base_Tolerance of each other and of the Horizon, with each Stone_Base taken from the rendered Stone_Box bottom; at text scale 2.0 at widths 320 and 768 the two stones of the first multi-column row (768) have bases within 1 px and equal control-block heights, and at 320 (one column) no `RenderFlex` overflow is reported and each stone's base equals the top of its own control block within 1 px; the same at text scale 1.0; the column counts are 1 below 720 logical pixels and 2 to 4 from 720; the Rise animation still runs for a grave added after the first list and the tilt of each Stone is unchanged; the Séance control and the Delete button keep a tap target of at least 48 by 48 at every Test_Scale and the scene shows no overflow, no clipped tombstone and no exception at every Test_Width and Test_Scale.
    - _Requirements: 6.2, 6.3, 13.1, 13.2, 13.3, 13.4, 13.6, 12.5_

  - [ ] 6.6 Write the séance sheet size and slot tests
    - Create `test/ui/seance_sheet_polish_test.dart`: the surface height is that of the nearest `Material` ancestor of `SeanceSheet`; for a short name at 1280 by 800 and text scale 1.0 the surface is less than 90% of the view height, the Sheet_Scroll_Area has a maximum scroll extent of 0, and the surface is smaller than the surface of the same sheet with tall content; at text scale 2.0 on 320 by 568 the content is taller than the offered height, the scroll area scrolls to every part, the surface is at most the screen height, and the close button lies inside the screen, is hit-testable, closes the sheet on tap, and stays reachable after scrolling down and back up; the short screen 320 by 260 at text scale 2.0 scrolls and keeps the close button reachable; growing the text scale from 1.0 to 2.0 at one width grows the sheet until it reaches the available height; the content width is at most 560 and centered, and the full width below 560; the top of the close button aligns with the top of the title; the content stays above a keyboard inset and a safe-area inset; for each Test_Width, each Test_Scale and the pending, ready and fallback states there is no overflow and no horizontally clipped text; the Verdict_Slot height is equal before and after the verdict (pending to ready and pending to fallback) and the title, score card and steps do not move; the slot height is recomputed when the text scale or the width changes; a verdict longer than the slot (a fake `CoffinAI` that ignores `maxLength`) grows the slot, stays readable by scrolling and throws nothing.
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 8.1, 8.2, 8.3, 8.4, 8.5, 12.8, 12.9_

  - [ ] 6.7 Write the Verdict_Block tests
    - Create `test/ui/seance_sheet_verdict_test.dart`: for each Test_Width, each Test_Scale and the ready and fallback states, the left edge of the Verdict_Block (the accent bar) is within 0.5 logical pixels of the left edge of the step number column and its right edge is within 0.5 of the right edge of the steps; the verdict `Text` has an effective font size larger than the step text; the accent bar width is from 2 to 4 logical pixels, its height equals the verdict text height and its color is `CoffinColorTokens.primary` of the active theme; the safe verdict line uses the same style as a generated verdict; multi-line verdicts wrap inside the block and every line is start-aligned; the order of the sheet is title, score card, steps, verdict; the sheet keeps exactly one `Icon`, exactly ten `Text` widgets in the ready state and exactly one `DecoratedBox` with the `raised` color; the verdict semantics node has the verdict as label, `liveRegion` true and no child semantics; the verdict fades in over 450 ms and appears at once with `disableAnimations` true; the pending `GhostLoader` stays centered in the Verdict_Slot. Use `WcagContrast` of `coffin_core` to expect the verdict text on `CoffinColorTokens.surface` to be at least 4.5 and the accent bar on `surface` to be at least 3.0, in both themes.
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 9.9, 10.1, 10.2, 10.3, 10.4, 12.8_

  - [ ] 6.8 Write the contrast tests for the ground controls
    - Create `test/ui/ground_contrast_test.dart`: in both themes (`CoffinColorTokens.night` and `CoffinColorTokens.daylight`), `WcagContrast.ratio` of the resolved Séance label color, the Delete label color and the Delete icon color against `CoffinColorTokens.background` is at least `WcagContrast.aaNormalText` (4.5), with the colors read from a pumped `GraveTombstone` in each theme and with the pinned expectation that the token in use is `primary`; the Séance control and the Delete button keep a tap target of at least 48 by 48 at each Test_Scale; the verdict text and accent bar contrast pins of Requirement 9 may live here or in `seance_sheet_verdict_test.dart`, and are not duplicated.
    - _Requirements: 6.1, 6.2, 6.4, 6.5, 6.6, 12.10_

  - [ ] 6.9 Write the test that the Horizon does not move while the first stone rises
    - Create `test/ui/graveyard_ground_rise_test.dart`, named `Horizon does not move while the first stone rises`. At widths 360 and 768, text scale 1.0, pump a scene whose first-row stone is rising (a new grave with a rise controller). After the first measurement frame, record the Horizon (top of the Ground_Field plus `min(GroundPainter.maxSoftEdge, groundHeight / 2)`, in the coordinate system of the rows `Column`) and the Ground_Field rect. Then `pump(Duration)` through the Rise, sampling at about 0, 25, 50, 75 and 100 percent of `RiseProgress.durationMs`, and once after the rise has ended and the scene has settled.
    - At every sample expect the Horizon and the Ground_Field top to equal the first recording within 0.5 px. Expect `tester.binding.hasScheduledFrame` to be false once the rise has ended and settled. To prove the test covers a real rise, expect the painted top of the stone (the rect of its `Opacity` ancestor, which includes the translate) to move up by about `GraveTombstone.riseDistance` between the first and the last sample while the Horizon does not move. Repeat with Reduced_Motion on (`disableAnimations` true), where there are no intermediate samples and the Horizon is the same before and after.
    - _Requirements: 1.4, 12.7_

- [ ] 7. Final checkpoint - Verification
  - Run each command in order, with the working directory shown.
  - In `/Users/ranmanlabs/Documents/Kiroween/coffin/apps/graveyard`: `dart format --output=none --set-exit-if-changed .` (must exit 0).
  - In `/Users/ranmanlabs/Documents/Kiroween/coffin/apps/graveyard`: `flutter analyze` (zero issues).
  - In `/Users/ranmanlabs/Documents/Kiroween/coffin/apps/graveyard`: `flutter test` (all graveyard tests pass, including the three updated layout tests and every unchanged existing test).
  - In `/Users/ranmanlabs/Documents/Kiroween/coffin/apps/graveyard`: `flutter test --platform chrome test/domain test/data` (domain and data tests pass in Chrome).
  - In the repository root `/Users/ranmanlabs/Documents/Kiroween/coffin` (the path list is relative to the repo root): `git status --porcelain -- pubspec.lock pubspec.yaml apps/graveyard/pubspec.yaml packages/coffin_core apps/hauntagotchi tool` must print nothing. This also catches new untracked files.
  - Fix any failure at its cause. Create no file outside the repository, including `/tmp`.
  - Ensure all tests pass, ask the user if questions arise.
  - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.7_

## Notes

- Every task, including every test task, is required. None is marked optional, and the project testing rules require unit tests for pure logic and glados property tests for numeric rules and invariants.
- The three design properties each have one sub-task: P1 (1.3), P2 (2.3), P3 (1.4). The widget-level claims (Horizon against the measured Stone_Box bottom, scroll equality, row base alignment, sheet height) are widget tests, because they depend on real text layout.
- The design names `test/ui/graveyard_ground_test.dart`, `test/ui/seance_sheet_polish_test.dart` and `test/ui/ground_contrast_test.dart`. Requirement 12.1 allows other names ("for example"), so the widget tests of tasks 6.1 to 6.7 and 6.9 are split into separate new files, so that the test tasks can run in parallel without writing the same file.
- Tasks 4.2, 4.3, 4.4 and 4.5 edit `graveyard_scene.dart`, and tasks 5.1 to 5.4 edit `seance_sheet.dart`, so each of those tasks sits in a different wave from any other task that edits the same file. Task 4.4 changes the row alignment and the column helper of the three layout tests together, so no task ends with a failing test.
- The measured contrast of the design (night 5.51 and daylight 5.84 for the controls on `background`, 14.63 and 17.83 for the verdict text, 5.04 and 6.39 for the accent bar on `surface`) means no color change is needed, and task 6.8 pins the ratios.
- The two checkpoints (3 and 7) each run `dart format`, `flutter analyze`, `flutter test`, `flutter test --platform chrome test/domain test/data` in `apps/graveyard`, and `git status --porcelain` over `pubspec.lock`, `pubspec.yaml`, `apps/graveyard/pubspec.yaml`, `packages/coffin_core`, `apps/hauntagotchi` and `tool` from the repository root, which must print nothing.
- No test uses a real wait, a real clock, real Hive, the network, a file outside the repository or `/tmp`, and none depends on the time zone of the machine.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1"] },
    { "id": 1, "tasks": ["1.2", "1.3", "2.2", "2.3"] },
    { "id": 2, "tasks": ["1.4"] },
    { "id": 3, "tasks": ["3"] },
    { "id": 4, "tasks": ["4.1", "5.1"] },
    { "id": 5, "tasks": ["4.2", "5.2"] },
    { "id": 6, "tasks": ["4.3", "5.3"] },
    { "id": 7, "tasks": ["4.4", "5.4"] },
    { "id": 8, "tasks": ["4.5"] },
    { "id": 9, "tasks": ["6.1", "6.2", "6.3", "6.4", "6.5", "6.6", "6.7", "6.8", "6.9"] },
    { "id": 10, "tasks": ["7"] }
  ]
}
```
