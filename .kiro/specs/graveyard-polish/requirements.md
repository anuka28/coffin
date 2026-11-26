# Requirements Document

## Introduction

The graveyard-polish feature fixes two visual flaws of `apps/graveyard`.

**Floating tombstones.** `GraveyardScene` (`lib/src/ui/graveyard_scene.dart`) paints the ground as a `Positioned` band with `height: height * 0.34` at the bottom of the scene (a `GroundPainter` inside `IgnorePointer` and `ExcludeSemantics`, around line 265). The rows of `GraveTombstone` scroll in a separate `SingleChildScrollView` above it. The band never moves, so stones float above it, or stand in the sky, wherever the scroll position puts them. This feature moves the ground into the scrolling content. The horizon sits at the base of the first row of stones, and the ground continues below it and scrolls with the stones. The sky, moon, stars and fog stay as they are.

**Uneven stones.** Stones of different heights in one row are top-aligned today, so their bases differ and the first row has no single base line. This feature bottom-aligns the Stones within every row, so that all Stones of a row share one base line and the Horizon sits at that line. This deliberately changes one existing test (see Requirement 13). The Rise animation, the tilt and the column layout stay as they are.

**Séance sheet.** `SeanceSheet` (`lib/src/ui/seance_sheet.dart`, opened by `showSeanceSheet`) is as tall as the screen because its content sits in an `Align(topCenter)` that takes the full height offered by the modal route. The verdict line is a centered `bodyLarge` `Text` in the same style as the steps, so it reads as one more step. This feature sizes the sheet to its content, gives the verdict line a quote-style block, and aligns that block with the left edge of the steps.

The work is limited to `apps/graveyard`. `coffin_core`, `apps/hauntagotchi`, `tool/` and every `pubspec.yaml` stay unchanged. No package and no asset is added. All colors come from `CoffinColorTokens`. This feature supersedes the earlier statements of the `graveyard-scene` spec that the ground is a strip at the bottom of the scene and that "the ground never scrolls" (the class comment of `GraveyardScene`). That comment is updated by this feature.

## Glossary

- **Graveyard_App**: The Flutter app in `apps/graveyard`.
- **Graveyard_Scene**: The `GraveyardScene` widget.
- **Scene_Box**: The rectangle the Graveyard_Scene occupies, which is the full screen area given to it by the Graveyard_Screen.
- **Scroll_Content**: The content of the one `SingleChildScrollView` of the Graveyard_Scene. It holds the header, the Living_Row, the rows of tombstones and the bottom padding.
- **Stone**: The tilted, weathered `TombstoneCard` block of one `GraveTombstone`, without its Séance and Delete controls.
- **Stone_Box**: The box of a Stone whose bottom centre is the tilt pivot of the Stone. It excludes the Séance and Delete controls of the `GraveTombstone`.
- **Stone_Base**: The y-coordinate of the bottom edge of the Stone_Box of a Stone as laid out at Rise_Progress 1, measured directly from the Stone_Box in the coordinate system of the Scroll_Content. The Stone tilts around the middle of its base, so the Stone_Base is the y-coordinate of the tilt pivot and does not depend on the tilt. The Stone_Base is not computed by subtracting the height of the control block from the height of the `GraveTombstone`.
- **First_Row**: The first row of tombstones produced by `SceneLayout`, in the rows list (the graves that are not in the Living_Row).
- **Row_Base_Line**: The one y-coordinate that all Stones of a row share as their Stone_Base, because the Stones are bottom-aligned within the row.
- **First_Row_Base**: The Row_Base_Line of the First_Row, which is the Stone_Base of the first Stone of the First_Row. Because the Stones of a row are bottom-aligned, any Stone of the First_Row gives the same value within Base_Tolerance.
- **Ground_Field**: The single `CustomPaint` with a `GroundPainter` that paints the ground inside the Scroll_Content. It is `IgnorePointer` and `ExcludeSemantics`.
- **Soft_Edge**: The top part of a ground, in which the ground color fades from transparent to opaque. Its height is `min(GroundPainter.maxSoftEdge, ground height / 2)`.
- **Horizon**: The y-coordinate at which the Ground_Field becomes opaque, which is the top of the Ground_Field plus the Soft_Edge.
- **Ground_Band**: The ground as it is today: a full-width strip at the bottom of the Scene_Box with a height of 34% of the Scene_Box height, outside the Scroll_Content, which does not scroll.
- **Empty_State**: The state of the Graveyard_Scene in which the graves list is empty. It includes the empty graveyard and the load-error scene.
- **All_Risen_State**: The state in which the rows list is empty and the Living_Row is not empty (`GraveyardScene.noRows` is shown).
- **Living_Row**: The existing `LivingRow` of risen graves above the rows.
- **Night_Sky**: The existing `NightSkyPainter` layer (gradient, moon, stars).
- **Fog_Layer**: The existing `FogBackground` of `coffin_core`.
- **Reduced_Motion**: The state in which `MediaQuery.disableAnimations` is true.
- **Seance_Sheet**: The `SeanceSheet` widget as shown by `showSeanceSheet` in a modal bottom sheet.
- **Sheet_Scroll_Area**: The one `SingleChildScrollView` inside the Seance_Sheet.
- **Sheet_Steps**: The three step rows of the Seance_Sheet. Each has a number column of 32 logical pixels and the step text.
- **Verdict_Block**: The widget that shows the verdict text in the Seance_Sheet once the verdict is known.
- **Verdict_Slot**: The area at the bottom of the Sheet_Scroll_Area that holds the `GhostLoader` while the verdict is pending, and the Verdict_Block after that.
- **Test_Widths**: 320, 360, 768 and 1280 logical pixels.
- **Test_Scales**: Text scale factors 1.0, 1.5 and 2.0.
- **Base_Tolerance**: 1 logical pixel. It applies both to the distance between the Horizon and the First_Row_Base and to the difference between the Stone_Base values of Stones in one row.

## Requirements

### Requirement 1: The Horizon sits at the base of the first row

**User Story:** As a user of the Graveyard, I want the tombstones to stand on the ground, so that the scene looks like a real graveyard and not like stones floating in front of a strip.

#### Acceptance Criteria

1. WHILE the Graveyard_Scene shows at least one tombstone in the rows, THE Graveyard_Scene SHALL paint exactly one Ground_Field, and that Ground_Field SHALL be a descendant of the Scroll_Content.
2. WHILE the Graveyard_Scene shows at least one tombstone in the rows, THE Graveyard_Scene SHALL place the Horizon within Base_Tolerance of the First_Row_Base.
3. WHILE the Graveyard_Scene shows at least one tombstone in the rows, THE Ground_Field SHALL start above the Horizon by the height of the Soft_Edge, so that the Soft_Edge lies above the First_Row_Base and the Stones of the First_Row stand in the opaque ground.
4. WHILE a tombstone rises (Rise_Progress below 1), THE Graveyard_Scene SHALL keep the Horizon at the First_Row_Base of the Stones at Rise_Progress 1.
5. WHILE the Graveyard_Scene shows a Living_Row, a header, or both above the rows, THE Graveyard_Scene SHALL place the Horizon below them, so that the Living_Row is not painted over by the Ground_Field.
6. WHEN the Horizon is measured at each of the Test_Widths and each of the Test_Scales with one, three and eight graves, THE measured distance between the Horizon and the First_Row_Base SHALL be at most Base_Tolerance.
7. WHEN the Stones of the First_Row differ in height, THE Graveyard_Scene SHALL place the Horizon at the First_Row_Base, which is the Row_Base_Line shared by all Stones of that row (Requirement 13).
8. WHILE the Graveyard_Scene shows at least one tombstone in the rows, THE Graveyard_Scene SHALL place the Horizon within Base_Tolerance of the measured bottom of the Stone_Box of the first Stone of the First_Row, in the coordinate system of the Scroll_Content, independent of the height of the control block of the `GraveTombstone`, at text scale 1.0 and at text scale 2.0.

### Requirement 2: The ground scrolls with the stones and fills to the bottom

**User Story:** As a user, I want the ground to move with the tombstones when I scroll, so that the stones never leave the earth they stand in.

#### Acceptance Criteria

1. WHEN the Scroll_Content is scrolled by d logical pixels, THE Ground_Field SHALL move by exactly the same d logical pixels as the Stones, so that the distance between the Horizon and the First_Row_Base stays within Base_Tolerance at every scroll offset.
2. WHILE the Scroll_Content is at any scroll offset between 0 and its maximum scroll extent, THE Ground_Field SHALL extend at least to the bottom edge of the Scene_Box wherever the Horizon lies above that bottom edge.
3. WHILE the Scroll_Content is scrolled to its maximum extent, THE Ground_Field SHALL extend at least to the bottom of the Scroll_Content, including the bottom padding that keeps the last Delete button clear of the add button.
4. WHILE the rows are shorter than the Scene_Box, THE Ground_Field SHALL extend from the Soft_Edge down to the bottom edge of the Scene_Box.
5. THE Ground_Field SHALL span the full width of the Scene_Box.
6. THE Ground_Field SHALL use the `GroundPainter` color source `CoffinColorTokens.background` of the active theme and no other color.
7. THE Graveyard_Scene SHALL keep exactly one `SingleChildScrollView` between the Fog_Layer and the Living_Row, so that the Scroll_Content stays one scrollable.

### Requirement 3: Lower rows stand inside the field

**User Story:** As a user with many graves, I want every row to stand in the ground, so that no row floats over bare sky.

#### Acceptance Criteria

1. WHILE the Graveyard_Scene shows more than one row, THE Ground_Field SHALL be one continuous area from its top down to the bottom of the last row, so that no sky shows between two rows.
2. WHILE the Graveyard_Scene shows more than one row, THE Graveyard_Scene SHALL keep every Stone_Base of the second and later rows below the Horizon.
3. WHEN the width of the Scene_Box changes the number of columns (below 720 logical pixels one column, from 720 logical pixels two to four columns), THE Graveyard_Scene SHALL recompute the Horizon from the new First_Row_Base.
4. WHEN a grave is added or removed, THE Graveyard_Scene SHALL move the Horizon to the new First_Row_Base without an exception.

### Requirement 4: Empty and all-risen states keep the band

**User Story:** As a user with no tombstone in the rows, I want the ground to stay where it is today, so that the empty scene does not look different.

#### Acceptance Criteria

1. WHILE the Graveyard_Scene is in the Empty_State, THE Graveyard_Scene SHALL paint one Ground_Band with left 0, right 0, bottom 0 and a height of 34% of the Scene_Box height, outside the Scroll_Content.
2. WHILE the Graveyard_Scene is in the All_Risen_State, THE Graveyard_Scene SHALL paint one Ground_Band with the same placement as in the Empty_State.
3. WHILE the Graveyard_Scene paints a Ground_Band, THE Ground_Band SHALL stay at its place when the Scroll_Content scrolls.
4. WHILE the Graveyard_Scene paints a Ground_Band, THE Graveyard_Scene SHALL paint no Ground_Field.
5. WHILE the Graveyard_Scene paints a Ground_Field, THE Graveyard_Scene SHALL paint no Ground_Band.
6. WHEN the rows change from empty to non-empty, or from non-empty to empty, THE Graveyard_Scene SHALL switch between the Ground_Band and the Ground_Field in the same frame without an exception.

### Requirement 5: Sky, fog, motion and semantics stay as they are

**User Story:** As a user, I want the rest of the scene to look and behave as before, so that the fix changes only the ground.

#### Acceptance Criteria

1. THE Graveyard_Scene SHALL paint the Night_Sky with the same painter, the same inputs and the same position (a full-size layer outside the Scroll_Content) as before this feature, and SHALL paint exactly one Night_Sky.
2. THE Graveyard_Scene SHALL keep the Fog_Layer as an ancestor of the Scroll_Content, in the same stacking position relative to the Night_Sky as before this feature.
3. THE Ground_Field and the Ground_Band SHALL each be wrapped in `IgnorePointer` and `ExcludeSemantics`, so that a tap on the ground reaches the controls under it and the ground adds no semantic node.
4. WHILE Reduced_Motion is active, THE Graveyard_Scene SHALL paint the Ground_Field and the Ground_Band as static ground with no animation of their own.
5. THE public constructor `GroundPainter({required tokens})`, `GroundPainter.maxSoftEdge` and the `shouldRepaint` rule (true only when the tokens differ) SHALL stay unchanged.
6. THE Graveyard_Scene SHALL keep the rise of a new grave, the Living_Row, the header and the `noRows` widget at their current place in the Scroll_Content order.

### Requirement 6: Controls and text stay readable on the ground

**User Story:** As a user, I want the Séance and Delete buttons to stay readable, so that standing in the ground does not hide any control.

#### Acceptance Criteria

1. THE Graveyard_App SHALL show the label text and icon of the Séance control and the Delete button of every tombstone with a WCAG contrast ratio of at least `WcagContrast.aaNormalText` (4.5) against `CoffinColorTokens.background` in the night theme and in the daylight theme, because these controls now always lie on the ground.
2. THE Graveyard_App SHALL keep a tap target of at least 48 by 48 logical pixels for the Séance control and the Delete button at each of the Test_Scales.
3. WHEN the Graveyard_Scene is shown at each of the Test_Widths and each of the Test_Scales, THE Graveyard_Scene SHALL show no overflow, no clipped tombstone and no exception.
4. IF a control label does not reach the contrast ratio of Acceptance Criterion 1 in a theme, THEN THE Graveyard_App SHALL change that label color to another color of `CoffinColorTokens` that does.
5. THE design SHALL measure the contrast ratio of the Séance label and the Delete label against `CoffinColorTokens.background` in the night theme and in the daylight theme with `WcagContrast`, and SHALL choose the `CoffinColorTokens` token for each label from those measurements.
6. THE Graveyard_App SHALL include a test that pins a contrast ratio of at least 4.5 for the Séance label and the Delete label on `CoffinColorTokens.background` in both themes, using the token the design chose.

### Requirement 7: The Seance_Sheet is as tall as its content

**User Story:** As a user opening a séance, I want the sheet to be only as tall as its content, so that I still see the graveyard behind it.

#### Acceptance Criteria

1. WHEN the Seance_Sheet is shown with its content shorter than the available height, THE Seance_Sheet SHALL be as tall as its content plus its padding and the bottom safe-area inset, and the Sheet_Scroll_Area SHALL have a maximum scroll extent of 0.
2. WHEN the Seance_Sheet is shown for a grave with a short name at 1280 by 800 logical pixels and text scale 1.0, THE Seance_Sheet SHALL be less than 90% of the view height.
3. WHILE the content of the Seance_Sheet is taller than the available height (text scale up to 2.0, a short screen, or both), THE Seance_Sheet SHALL fill the available height and the Sheet_Scroll_Area SHALL scroll to every part of the content.
4. WHEN the text scale grows from 1.0 to 2.0 at one width, THE Seance_Sheet SHALL grow in height with its content until it reaches the available height.
5. THE Seance_Sheet SHALL keep a content width of at most 560 logical pixels, centered, and the full width below 560 logical pixels.
6. THE Seance_Sheet SHALL keep the close button reachable and hit-testable at the top of the content, and SHALL keep the top of the close button aligned with the top of the title.
7. WHEN the keyboard inset or the safe-area inset changes, THE Seance_Sheet SHALL keep its content above that inset.
8. THE Seance_Sheet SHALL show no overflow, and SHALL clip no text horizontally, at each combination of the Test_Widths and the Test_Scales, in the pending, ready and fallback states of the verdict.

### Requirement 8: The verdict arriving does not move the sheet

**User Story:** As a user, I want the sheet to stay still when the verdict arrives, so that the score and the steps do not jump while I read them.

A sheet that is as tall as its content and anchored to the bottom would move the title, score and steps upward by the height the verdict adds. The existing tests `a reply moves neither the score nor the steps` and `the safe line after a failure moves nothing` in `test/ui/seance_sheet_test.dart` pin that these do not move. This requirement keeps those tests valid. The reserved Verdict_Slot sized for `verdictMaxLength` is an approved decision and needs no further approval.

#### Acceptance Criteria

1. WHILE the verdict is pending, THE Seance_Sheet SHALL reserve a Verdict_Slot whose height fits a verdict of `verdictMaxLength` (140) UTF-16 code units at the current content width and text scale, and at least the height of the `GhostLoader`.
2. WHEN the verdict arrives or the safe verdict line replaces it, THE Seance_Sheet SHALL keep its own height and the position of the title, the score card and the Sheet_Steps unchanged.
3. THE Verdict_Block SHALL start at the top of the Verdict_Slot.
4. WHEN the text scale or the width changes while the Seance_Sheet is open, THE Seance_Sheet SHALL recompute the Verdict_Slot height for the new values.
5. IF a verdict is longer than the Verdict_Slot (a generator that ignores `maxLength`), THEN THE Seance_Sheet SHALL grow the Verdict_Slot to fit the verdict and keep the verdict readable by scrolling.

### Requirement 9: The verdict line has more presence

**User Story:** As a user, I want the verdict to stand out from the steps, so that I see it as the answer of the séance.

#### Acceptance Criteria

1. THE Verdict_Block SHALL show the verdict text as one `Text` widget whose effective font size is larger than the effective font size of the step text.
2. THE Verdict_Block SHALL show a vertical accent bar at its left edge, with a width from 2 to 4 logical pixels, the height of the verdict text, and the color `CoffinColorTokens.primary` of the active theme.
3. THE Verdict_Block SHALL show the verdict text in `CoffinColorTokens.text` on the sheet surface (`CoffinColorTokens.surface`) with a WCAG contrast ratio of at least 4.5 in the night theme and in the daylight theme.
4. THE accent bar SHALL reach a WCAG contrast ratio of at least 3.0 against `CoffinColorTokens.surface` in the night theme and in the daylight theme.
5. THE Verdict_Block SHALL use no `Icon`, no extra `Text` and no `DecoratedBox` whose color is `CoffinColorTokens.raised`, so that the sheet keeps exactly one `Icon` (the close button), exactly ten `Text` widgets in the ready state, and exactly one `DecoratedBox` with the color `CoffinColorTokens.raised` (the score card).
6. THE Verdict_Block SHALL keep the semantics of the verdict: one container node with the verdict as label, `liveRegion` true, and the child semantics excluded.
7. WHEN the verdict text has several lines, THE Verdict_Block SHALL wrap the text inside its width and SHALL start-align every line.
8. WHERE the verdict text is the safe verdict line (`GraveyardCopy.safeVerdictLine`), THE Verdict_Block SHALL use the same style as for a generated verdict.
9. WHEN the verdict appears, THE Verdict_Block SHALL fade in with the existing 450 ms reveal of the Seance_Sheet, and SHALL appear at once while Reduced_Motion is active.

### Requirement 10: The verdict aligns with the steps


**User Story:** As a user, I want the verdict to line up with the steps, so that the sheet reads as one clean column.

The accent-bar quote block of Requirement 9 is an approved decision and needs no further approval.

#### Acceptance Criteria

1. THE Verdict_Block SHALL align its left edge (the left edge of the accent bar) with the left edge of the step number column of the Sheet_Steps, within 0.5 logical pixels, at each of the Test_Widths and each of the Test_Scales.
2. THE Verdict_Block SHALL end at the same right edge as the Sheet_Steps, within 0.5 logical pixels.
3. WHILE the verdict is pending, THE `GhostLoader` SHALL stay centered in the Verdict_Slot as before this feature.
4. THE Verdict_Block SHALL keep the order of the sheet: title, score card, Sheet_Steps, verdict.

### Requirement 11: Scope, tokens and existing tests

**User Story:** As the maintainer of the Coffin skeleton, I want the polish to stay inside the Graveyard app and keep the existing tests green, so that the skeleton and the other app are not affected.

#### Acceptance Criteria

1. THE Graveyard_App SHALL change files only under `apps/graveyard/lib`, `apps/graveyard/test`, and the spec folder `.kiro/specs/graveyard-polish`, and SHALL leave `packages/coffin_core`, `apps/hauntagotchi`, `tool/` and every `pubspec.yaml` and `pubspec.lock` unchanged.
2. THE Graveyard_App SHALL add no package and no asset, and `CREDITS.md` SHALL stay unchanged.
3. THE Graveyard_App SHALL take every new color from `CoffinColorTokens` and SHALL write no color literal in the changed code.
4. THE Graveyard_App SHALL keep every existing test file unchanged, except for the one deliberate change of the column-count measurement in `test/ui/graveyard_scene_test.dart` named in Requirement 13, and no other requirement of this document changes what an existing test pins. The existing tests this feature must keep green unchanged are:
   - `test/ui/ground_painter_test.dart`: the constructor and `shouldRepaint` of `GroundPainter` (Requirement 5, Criterion 5).
   - `test/ui/graveyard_scene_test.dart`: one Night_Sky, `sky, moon, stars, ground and fog add no semantic node`, and the last Delete button scrolls clear of the add button. The tests of group `layout` change as stated in Requirement 13.
   - `test/ui/resurrection_layout_test.dart` and `test/ui/layout_test.dart`: one `SingleChildScrollView` ancestor of the `LivingRow` (Requirement 2, Criterion 7).
   - `test/ui/seance_sheet_test.dart`: the order of the sheet content, and the two tests named in Requirement 8 (Requirements 8 and 10).
   - `test/ui/seance_sheet_layout_test.dart`: no overflow, no clipped text, the Sheet_Scroll_Area is 320 logical pixels wide at 320 and at most 560 wide and centered above (Requirement 7).
   - `test/ui/seance_sheet_semantics_test.dart`: the semantic labels, ten `Text`, one `Icon` and one raised `DecoratedBox` (Requirement 9, Criteria 5 and 6).
   - Approved exception (found while executing task 5.1): `test/ui/seance_sheet_raise_test.dart`, test `the control leaves score, band, steps and verdict unchanged`, opened a second sheet without closing the first. It passed only because the full-height sheet covered the "open" button. With a content-sized sheet (Requirement 7), that tap lands on the modal barrier and closes the sheet. The test now closes the first sheet with the close button before opening the second. Its assertions are unchanged.
5. IF a measurement of the changed code fails an existing test other than the tests changed by Requirement 13, THEN THE Graveyard_App SHALL change the code and SHALL NOT change the test.
6. THE Graveyard_App SHALL update the class comment of `GraveyardScene` and the doc comment of `GroundPainter`, so that they describe the ground as part of the scrolling content, with the Ground_Band for the Empty_State and the All_Risen_State.
7. THE Graveyard_App SHALL pass `dart format`, `flutter analyze` with zero warnings and `flutter test` for `apps/graveyard`.

### Requirement 12: Widget tests that prove the polish

**User Story:** As a reviewer, I want widget tests for each visible rule, so that the polish cannot regress without a failing test.

#### Acceptance Criteria

1. THE Graveyard_App SHALL include new widget tests in new test files (for example `test/ui/graveyard_ground_test.dart` and `test/ui/seance_sheet_polish_test.dart`) that cover Requirements 1 to 10 and Requirement 13.
2. THE ground tests SHALL, for each of the Test_Widths and each of the Test_Scales, measure the Horizon (the top of the Ground_Field plus its Soft_Edge) and the First_Row_Base (the measured bottom of the Stone_Box of the first Stone of the First_Row, taken directly from the rendered Stone_Box in the coordinate system of the Scroll_Content, and not computed by subtracting the control block height) and expect a distance of at most Base_Tolerance.
3. THE ground tests SHALL verify Requirement 1, Criterion 8 at text scale 1.0 and at text scale 2.0, in each case with Stones whose control blocks differ in height (the control block grows with the text scale), and SHALL expect the Horizon to stay within Base_Tolerance of the measured Stone_Box bottom at both scales.
4. THE ground tests SHALL scroll the Scroll_Content by a fixed distance and expect that the Ground_Field top and the First_Row_Base move by the same distance, within Base_Tolerance, and that the bottom of the Ground_Field is at or below the bottom of the Scene_Box.
5. THE ground tests SHALL cover a scene with one grave, a scene with enough graves for several rows, the Empty_State, the All_Risen_State, a scene with a Living_Row above rows, and both themes.
6. THE ground tests SHALL expect exactly one Ground_Field and no Ground_Band when rows exist, and exactly one Ground_Band with the 34% height and no Ground_Field in the Empty_State and the All_Risen_State.
7. THE ground tests SHALL cover Reduced_Motion and a rising grave (the Horizon is the same before, during and after the rise).
8. THE sheet tests SHALL cover, for each of the Test_Widths and each of the Test_Scales and the pending, ready and fallback states: sheet height against content height, the Verdict_Slot height before and after the verdict (no movement of the title, score and steps), the left edge and right edge alignment of the Verdict_Block against the Sheet_Steps, the larger font size, the accent bar width and color, and the contrast ratios of Requirement 9.
9. THE sheet tests SHALL cover a short screen (320 by 260 logical pixels at text scale 2.0) in which the Sheet_Scroll_Area scrolls and the close button stays reachable.
10. THE contrast tests SHALL use `WcagContrast` of `coffin_core` in both themes, for the Séance and Delete controls on `CoffinColorTokens.background` (Requirement 6, with a pinned minimum of 4.5) and for the verdict text and accent bar on `CoffinColorTokens.surface` (Requirement 9).
11. THE pure measurements that the widget tests need (Soft_Edge height, Verdict_Slot height) SHALL be exposed by the changed code in a way that does not add a Flutter import to `lib/src/domain`.

### Requirement 13: Stones in a row share one base line

**User Story:** As a user with several graves, I want all tombstones of a row to stand on the same line, so that the first row has an even base and the ground horizon meets every stone.

The existing tests `360 px shows one column`, `768 px shows 2 to 4 columns` and `1280 px shows 2 to 4 columns` in group `layout` of `test/ui/graveyard_scene_test.dart` count the columns through the `columns` helper, which counts tombstones whose tops are aligned within 1 logical pixel. This requirement deliberately changes that expectation from "tops aligned" to "bases aligned within 1 px". The column counts they expect (1 column below 720 logical pixels, 2 to 4 from 720) stay the same.

#### Acceptance Criteria

1. THE Graveyard_Scene SHALL bottom-align the Stones within every row, so that the Stone_Base values of all Stones of one row differ by at most Base_Tolerance (1 logical pixel).
2. WHEN the Stones of one row differ in height, THE Graveyard_Scene SHALL give the taller and the shorter Stones the same Row_Base_Line.
3. THE Graveyard_Scene SHALL place the Horizon at the First_Row_Base, which is the Row_Base_Line of the First_Row.
4. THE Graveyard_Scene SHALL keep the Rise animation, the tilt of each Stone and the column layout (one column below 720 logical pixels, two to four columns from 720 logical pixels) as before this feature.
5. THE Graveyard_App SHALL change the expectation of the tests `360 px shows one column`, `768 px shows 2 to 4 columns` and `1280 px shows 2 to 4 columns` in `test/ui/graveyard_scene_test.dart` from "tombstone tops aligned within 1 px" to "tombstone bases aligned within 1 px", with the same expected column counts, and SHALL change no other expectation of that file.
6. THE new ground tests SHALL cover a row of Stones with different heights (for example one Stone with a long name and one with a short name) at each of the Test_Widths and each of the Test_Scales, and SHALL expect that all Stone_Base values of that row are within Base_Tolerance of each other and of the Horizon.
