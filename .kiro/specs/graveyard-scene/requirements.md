# Requirements Document

## Introduction

The graveyard-scene feature turns the Graveyard_Screen of `apps/graveyard` from a list of cards into a graveyard at night. Behind everything is a night sky with a moon and a few softly twinkling stars, with the `FogBackground` of `coffin_core` drifting low over the ground. The tombstones stand in rows on the ground: a grid of 2 to 4 columns on wide screens, one column on phones. Each tombstone rises gently out of the ground once, when it is added. Older graves look a little more weathered (fainter, slightly tilted), and graves older than five years also show one to three thin cracks near the base of the stone, so age is visible at a glance, and never at the cost of contrast. This is the visual centrepiece of the app, and it must support the function of the app: the scene makes the age of each project readable before any text is read.

The feature also fixes four problems seen on the live site, all on the tombstone built by `GraveTile` in `lib/src/ui/grave_tile.dart`:

- The engraved epitaph ("Dead for 3 years. Rest easy.", built by `GraveyardCopy.epitaph`) is placed by `TombstoneCard` at a fixed distance from the top and is clipped by the curve of the arch, so "DEAD FOR 3 YEARS" loses its first letter. The fix is to engrave the short word "R.I.P." on every grave and to make sure that word fits inside the arch at every width and text scale.
- The epitaph and the body both state the Dead_For_Text (`Text(deadFor)` in `GraveTile`), and an imported grave shows `owner/repo` twice, once as the title (the Project_Name is the `full_name`) and once as `repo.fullName`. The fix is that the body keeps the "Dead for N ..." line, in the readable body font and always visible, and the epitaph no longer repeats it.
- GitHub descriptions can hold emoji shortcodes such as `:atom:` (the description of `atom/atom` is ":atom: The hackable text editor"). They are shown as typed. Only a shortcode that stands alone between whitespace is removed, so times, ports and similar text stay as typed.
- Star counts are shown without separators (`GraveyardCopy.stars` prints `60681`).

The scene is plain Flutter: `CustomPainter`, `AnimationController` and the existing widgets. No package and no image asset is added. The layout math, the weathering math, the crack math, the twinkle math and the rise math are pure Dart in `apps/graveyard/lib/src/domain`, with no Flutter import, so that they are tested with unit tests and glados property tests. The scene reads time only through the existing Clock and the existing `MotionLoop` style of `coffin_core`; it does not change the rules of graveyard-core (sorting, duplicates, storage, import).

`coffin_core` already provides `FogBackground` (it respects `MediaQuery.disableAnimations`, ignores pointer events and adds no semantics), `TombstoneCard` (a fixed arch of 140 px, a fixed epitaph position, a maximum width of 300 px), `SpookyTokens`, `CoffinColorTokens` and `WcagContrast`. Because `coffin_core` stays unchanged, any tombstone behavior that `TombstoneCard` cannot give (an epitaph that fits the arch, a tilt, a fade, a rise) is built in `apps/graveyard`. Whether that is a wrapper around `TombstoneCard` or an app-owned tombstone widget is a design decision.

The design language is "Haunted, not horror", as defined in the design steering document: slow, floaty motion of 300 to 600 ms for one-time transitions, subtle loops, soft glows, 16 px corners, a tap target of at least 48 by 48 logical pixels, and short, witty, never mean copy.

Concrete numbers that are not stated here (star count, exact sizes, exact colors, exact durations of loops, exact tilt angle) belong to the design phase, within the bounds stated here.

## Dependency Notice

No dependency changes:

- No package is added to `apps/graveyard/pubspec.yaml`, and `pubspec.lock` stays byte-for-byte unchanged.
- No font, image, sound or other asset is added, and `CREDITS.md` stays unchanged.
- Thousands separators are written by hand in Dart. The `intl` package is not added.
- No API key, token or secret appears in the app, the tests or the repository.

## Glossary

- **Graveyard_App**: The Flutter app in `apps/graveyard`.
- **Domain**: The pure Dart code in `apps/graveyard/lib/src/domain`. It imports no Flutter library, no `dart:ui`, no `dart:io`, no `dart:html`, no networking package and no storage package. Scene math lives here, or in a folder under `lib/src/domain` that follows the same import rules.
- **Graveyard_Screen**: The screen at route `/`, in `lib/src/ui/graveyard_screen.dart`.
- **Graveyard_Scene**: The widget that paints the Night_Sky and the Ground, hosts the Fog_Layer, and places the tombstones on the Ground. It is part of the Graveyard_Screen.
- **Night_Sky**: The painted background: a vertical gradient from the background token, a Moon, and the Stars.
- **Moon**: One painted circle with a soft glow in the Night_Sky.
- **Star**: One small painted point in the Night_Sky. A Star has a position, a size and a Twinkle_Phase.
- **Star_Field**: The pure, seeded list of Stars for a given scene size.
- **Twinkle**: The slow change of a Star's opacity over time.
- **Twinkle_Phase**: The offset in time of one Star's Twinkle, so that Stars do not blink together.
- **Fog_Layer**: The existing `FogBackground` from `coffin_core`, used unchanged.
- **Ground**: The painted strip at the bottom of the Graveyard_Scene on which the tombstones stand, with a soft edge against the Night_Sky.
- **Tombstone**: One Grave drawn in the Graveyard_Scene, built by `GraveTile` or its successor, together with its delete control.
- **Scene_Layout**: The pure function that turns the available width, the text scale and the number of Graves into a number of columns and a tombstone width, and each Grave index into a row and a column.
- **Wide_Screen**: A scene whose available width is at least 720 logical pixels.
- **Narrow_Screen**: A scene whose available width is below 720 logical pixels.
- **Weathering**: The pure function that turns the Day_Count since the Date_Of_Death into a Weathering_Level in the range 0 to 1, and a Weathering_Level into a Tilt and a Fade.
- **Weathering_Level**: A number from 0 (fresh) to 1 (oldest). It never decreases as the Day_Count grows.
- **Tilt**: The rotation of a Tombstone in radians, derived from the Weathering_Level and the Grave id. Its absolute value never exceeds 3 degrees.
- **Fade**: The factor from 0 to 1 by which the Tombstone's stone color is blended toward the Ground color.
- **Crack_Age_Threshold**: 1825 days (five years of 365 days). A Grave is cracked only WHEN its Day_Count is strictly greater than this number. A Day_Count of 1825 has no Cracks, and a Day_Count of 1826 has Cracks.
- **Stone_Box**: The rectangle of the Tombstone's stone as laid out (the card without its delete control), with its origin at the top-left corner and its width and height in logical pixels.
- **Keep_Out_Area**: A rectangle in Stone_Box coordinates that holds text (the title, the date line, the Dead_For_Text body, or the Epitaph). No Crack stroke may touch it.
- **Crack_Band**: The strip near the base of the Stone_Box in which Cracks lie. Horizontally it runs from 20 to the stone width minus 20. Vertically it runs from the larger of (stone height minus 16) and (the lowest bottom edge of every Keep_Out_Area plus 2) down to the stone height minus 6, all in logical pixels.
- **Crack**: One thin polyline of 3 to 5 points with integer coordinates in Stone_Box coordinates, painted as a stroke (no fill) inside the Crack_Band.
- **Crack_Generator**: The pure function from the Day_Count, the Grave id, the Stone_Box size and the Keep_Out_Areas to a list of Cracks.
- **Crack_Painter**: The foreground painter that draws the Cracks of one Tombstone above its stone.
- **Stable_Hash**: A pure integer hash of a string computed from its UTF-16 code units with integer arithmetic below 2^53, so that it returns the same value on the Dart VM and on Flutter Web for every release. `String.hashCode` is not a Stable_Hash.
- **Tombstone_Facts**: The pure function that lists the visible text fragments of a Tombstone, each with a kind (dead-for text, date line, title, full name).
- **Rise**: The one-time upward and fade-in movement of a Tombstone out of the Ground when the Grave is added.
- **Rise_Progress**: A number from 0 to 1 that is the eased progress of a Rise.
- **Reduced_Motion**: The state in which `MediaQuery.disableAnimations` is true.
- **Still_Scene**: The scene drawn in Reduced_Motion: the Night_Sky with Stars at a fixed opacity, the Moon, the Ground, a static Fog_Layer frame, and every Tombstone at Rise_Progress 1.
- **Epitaph**: The short text engraved in the arch of a Tombstone. It is the constant string "R.I.P." (`GraveyardCopy.epitaph`), the same for every Grave, and it does not depend on the Dead_For_Text.
- **Arch_Fit**: The pure function that, for an arch of a given width and rise, a text line height and a text width, returns the vertical position at which the line lies fully inside the arch.
- **Epitaph_Font_Size**: The font size of the Epitaph. It starts at the base size scaled by the text scale and shrinks to a minimum of 12 logical pixels.
- **Dead_For_Text**: The phrase produced by `DeadForFormatter`, such as "Dead for 3 years" or "Died today". It is shown in the body of the Tombstone, once.
- **Day_Count**: The number of calendar days from the Date_Of_Death to Today, from the existing `DeadFor` domain code.
- **Emoji_Shortcode**: A whitespace-delimited word of a description that has the shape `:name:`, where `name` has 1 to 40 characters, every character is an ASCII letter, a digit, `_`, `+` or `-`, and `name` contains at least one ASCII letter. Examples: `:atom:`, `:rocket:`, `:white_check_mark:`. Not shortcodes: `:+1:` and `:100:` (no letter), `10:30:45` and `a:b:c` (not delimited by whitespace on both sides), `localhost:8080`.
- **Description_Cleaner**: The pure function that turns a GitHub description into plain display text without Emoji_Shortcodes.
- **Thousands_Formatter**: The pure function that turns a non-negative integer into text with a comma between each group of three digits.
- **Contrast_Minimum**: A WCAG contrast ratio of 3.0 between a text or icon color and the color directly behind it, computed with `WcagContrast.ratio`.
- **Seed**: The integer from which the Star_Field is generated. It is a constant of the app, so that the sky looks the same on every visit.
- **Web_Safe_Generator**: A glados generator that avoids `any.intInRange` and `any.listWithLengthInRange`, which throw on Flutter Web in glados 1.1.7. It keeps every generated integer below 2^53.

## Requirements

### Requirement 1: Night sky

**User Story:** As a user, I want the screen to look like a moonlit sky, so that opening the app feels like walking into a graveyard at night.

#### Acceptance Criteria

1. THE Graveyard_Scene SHALL paint the Night_Sky behind every other element of the Graveyard_Screen, as a vertical gradient between the `background` token and the `surface` token of the active `CoffinColorTokens`.
2. THE Night_Sky SHALL contain one Moon, drawn as a filled circle with a soft glow, placed in the upper third of the scene.
3. THE Night_Sky SHALL contain between 12 and 60 Stars, and the Star_Field SHALL scale the number of Stars with the scene area within that range.
4. THE Star_Field SHALL be a pure function of the Seed and the scene size, and SHALL NOT use `DateTime.now()` or an unseeded random source.
5. FOR ALL scene sizes with positive width and height, every Star position SHALL lie inside the Night_Sky area above the Ground, and no Star SHALL lie inside the Moon circle.
6. FOR ALL scene sizes and the same Seed, calling the Star_Field twice SHALL return equal lists of Stars (determinism).
7. THE Night_Sky SHALL be painted with `CustomPainter` and the Flutter canvas API, with no image asset and no package.
8. THE Night_Sky SHALL be excluded from semantics and SHALL ignore pointer events.
9. WHERE the active theme is the daylight theme, THE Night_Sky SHALL use the daylight tokens and SHALL draw the Moon and the Stars in colors that keep the Tombstones and the text above the Contrast_Minimum.
10. THE Graveyard_Scene SHALL paint the Night_Sky on its own repaint layer, so that a Twinkle repaint does not repaint the Tombstones.

### Requirement 2: Twinkle

**User Story:** As a user, I want the stars to flicker softly, so that the sky feels alive without distracting me.

#### Acceptance Criteria

1. WHILE motion is allowed, THE Night_Sky SHALL change the opacity of each Star over time with a Twinkle period between 3 and 8 seconds, with a Twinkle_Phase different from that of most other Stars.
2. FOR ALL Stars and FOR ALL elapsed times, THE Twinkle function SHALL return an opacity between 0.25 and 1.0 inclusive.
3. FOR ALL Stars and FOR ALL elapsed times, THE Twinkle opacity at elapsed time `t` and at elapsed time `t` plus one Twinkle period SHALL be equal within a tolerance of 1e-9 (periodicity).
4. FOR ALL Stars and FOR ALL elapsed times `t`, the change of Twinkle opacity between `t` and `t` plus 100 ms SHALL NOT exceed 0.15 (no hard flicker).
5. THE Twinkle SHALL use a single `AnimationController` for the whole Night_Sky, and SHALL NOT create one controller per Star.
6. THE Twinkle SHALL stop its controller WHILE Reduced_Motion is true, and SHALL start it again WHEN Reduced_Motion becomes false.
7. WHEN the Graveyard_Screen is disposed, THE Graveyard_Scene SHALL dispose the Twinkle controller.

### Requirement 3: Fog over the ground

**User Story:** As a user, I want fog drifting low over the graves, so that the scene feels haunted and the stones sit in the mist.

#### Acceptance Criteria

1. THE Graveyard_Scene SHALL use the existing `FogBackground` from `coffin_core` as the Fog_Layer, and SHALL NOT copy or modify its code.
2. THE Fog_Layer SHALL be drawn above the Night_Sky and the Ground and behind the text of the Tombstones, so that the fog drifts low over the ground without covering the Epitaph or the buttons.
3. THE Graveyard_Scene SHALL NOT place long body text directly on the Fog_Layer, and SHALL keep every text on the opaque stone color of its Tombstone or on the screen background, as the `FogBackground` documentation requires.
4. WHILE Reduced_Motion is true, THE Fog_Layer SHALL be drawn as the static frame that `FogBackground` draws in that state, and nothing SHALL drift.

### Requirement 4: Tombstones standing in rows

**User Story:** As a user on a wide screen, I want the tombstones in rows like a real graveyard, and as a user on a phone, I want one column that I can scroll, so that the scene fits my device.

#### Acceptance Criteria

1. WHEN the available width is below 720 logical pixels, THE Scene_Layout SHALL return one column.
2. WHEN the available width is 720 logical pixels or more, THE Scene_Layout SHALL return a number of columns from 2 to 4, chosen so that each Tombstone is at least 240 logical pixels wide and at most 300 logical pixels wide.
3. FOR ALL available widths from 1 to 4096 logical pixels and FOR ALL text scales from 1.0 to 2.0, THE Scene_Layout SHALL return a column count of at least 1 and at most 4.
4. FOR ALL available widths from 1 to 4096 logical pixels, the Scene_Layout SHALL return a tombstone width with `columns * tombstoneWidth + (columns - 1) * gap` not greater than the available width minus the side padding, except WHEN the available width minus the side padding is below the minimum Tombstone width, in which case the tombstone width SHALL equal that remaining width.
5. FOR ALL column counts and FOR ALL Grave counts, THE Scene_Layout SHALL place Grave index `i` at row `i ~/ columns` and column `i % columns`, so that the list order of Requirement 6 of graveyard-core (newest death first) reads left to right, then top to bottom (invariant).
6. FOR ALL Grave counts, the Scene_Layout SHALL give every Grave exactly one cell and no two Graves the same cell (injectivity).
7. THE Graveyard_Screen SHALL keep the Graves in the order that `GraveSorter` returns, and SHALL NOT reorder them for layout.
8. WHEN the number of Graves is smaller than the column count, THE Scene_Layout SHALL center the used columns, so that a short row does not hug the left edge.
9. WHEN a row has fewer Graves than columns (the last row), THE Scene_Layout SHALL center that row.
10. THE Graveyard_Scene SHALL scroll vertically WHEN the rows are taller than the available height, and SHALL render without overflow at widths of 320, 360, 768 and 1280 logical pixels, at the default text scale and at a text scale of 1.5.
11. THE Ground SHALL extend under every row, and WHILE the user scrolls, THE Night_Sky SHALL stay fixed behind the scrolling rows.
12. WHEN the text scale grows, THE Scene_Layout SHALL keep each Tombstone tall enough for its text, with the text wrapping or truncating with an ellipsis, and SHALL NOT clip text.

### Requirement 5: Rise from the ground

**User Story:** As a user, I want a new tombstone to rise gently out of the ground once, so that adding a grave feels like something happened.

#### Acceptance Criteria

1. WHEN a Grave is added to the list while the Graveyard_Screen is visible, THE Graveyard_Scene SHALL play the Rise for that Tombstone once, with a duration of 600 ms and an ease-in-out curve.
2. THE Rise SHALL move the Tombstone upward from a start offset of at most 24 logical pixels below its resting position, and SHALL fade it in from opacity 0 to opacity 1.
3. FOR ALL elapsed times of a Rise, THE Rise_Progress SHALL be between 0 and 1 inclusive, SHALL be 0 at time 0 and SHALL be 1 at the duration and after it, and SHALL NOT decrease as the time grows (monotonic property).
4. WHEN a Rise has ended, THE Tombstone SHALL stay at its resting position and SHALL NOT play the Rise again, including WHEN the list is rebuilt, the window is resized, or another Grave is added or deleted.
5. WHEN the Graveyard_Screen first shows Graves that were loaded from storage, THE Graveyard_Scene SHALL draw those Tombstones at their resting position and SHALL NOT play a Rise for them.
6. WHEN the user retries a failed load and the Graves appear, THE Graveyard_Scene SHALL draw them at their resting position and SHALL NOT play a Rise for them.
7. WHEN two Graves are added in quick succession, THE Graveyard_Scene SHALL play one Rise for each added Tombstone, independently.
8. WHEN a Grave is deleted, THE Graveyard_Scene SHALL remove its Tombstone and SHALL NOT play a Rise for the Tombstones that remain.
9. THE Rise SHALL NOT change the size of the Tombstone or the position of any other Tombstone while it plays.
10. WHEN the Graveyard_Screen is disposed during a Rise, THE Graveyard_Scene SHALL dispose the Rise controller without an error.
11. THE Graveyard_Scene SHALL decide which Graves are new by comparing Grave ids with the ids of the previous list, in a pure function of two id lists, where a new Grave is an id that is in the new list and not in the previous list.
12. FOR ALL pairs of id lists, THE new-grave function SHALL return exactly the ids of the new list that are absent from the previous list, in the order of the new list, and SHALL return an empty list WHEN the previous list is the first list loaded (set difference property).

### Requirement 6: Reduced motion

**User Story:** As a user who asks for reduced motion, I want a still scene that still looks complete, so that I lose nothing but the movement.

#### Acceptance Criteria

1. WHILE Reduced_Motion is true, THE Graveyard_Scene SHALL draw the Still_Scene.
2. WHILE Reduced_Motion is true, THE Night_Sky SHALL draw every Star at a fixed opacity between 0.6 and 1.0 and SHALL NOT start an `AnimationController` or a `Ticker`.
3. WHILE Reduced_Motion is true, THE Fog_Layer SHALL be static, as in Requirement 3.4.
4. WHILE Reduced_Motion is true, THE Graveyard_Scene SHALL draw each Tombstone at Rise_Progress 1, with no offset and full opacity.
5. WHEN Reduced_Motion becomes true while a Rise or a Twinkle is running, THE Graveyard_Scene SHALL stop it and draw the Still_Scene without an exception.
6. WHEN Reduced_Motion becomes false, THE Graveyard_Scene SHALL start the Twinkle again, and SHALL NOT replay a Rise that has ended or was skipped.
7. THE Still_Scene SHALL contain the Moon, the Stars, the Ground, the fog frame and every Tombstone with its Weathering (Tilt, Fade and Cracks), so that the Still_Scene looks the same as a frame of the animated scene, except for the Twinkle opacity of the Stars.
8. THE widget tests SHALL verify that no frame is scheduled by the Graveyard_Scene while Reduced_Motion is true, after the first frame has been drawn (`tester.hasRunningAnimations` is false or the pending frame count is zero).

### Requirement 7: Weathering by age

**User Story:** As a user, I want old graves to look older than fresh ones, so that I see how long each project has been dead before I read a word.

#### Acceptance Criteria

1. THE Weathering function SHALL compute the Weathering_Level from the Day_Count only, using a monotonic curve that reaches 1 at a Day_Count of 3650 (10 years) or more.
2. WHEN the Day_Count is 0, THE Weathering function SHALL return the Weathering_Level 0, the Tilt 0 and the Fade 0.
3. FOR ALL Day_Counts, THE Weathering_Level SHALL be between 0 and 1 inclusive.
4. FOR ALL pairs of Day_Counts `a` and `b` with `a` not greater than `b`, THE Weathering_Level of `a` SHALL NOT be greater than that of `b` (monotonic property).
5. FOR ALL Day_Counts and FOR ALL Grave ids, THE absolute Tilt SHALL NOT exceed 3 degrees, and the absolute Tilt SHALL NOT exceed the Weathering_Level multiplied by 3 degrees.
6. FOR ALL Day_Counts and FOR ALL Grave ids, THE Fade SHALL be between 0 and 0.25 inclusive, and SHALL NOT decrease as the Day_Count grows.
7. THE Tilt SHALL be a pure function of the Weathering_Level and the Grave id, so that the same Grave has the same Tilt on every build and on every visit, and its sign (left or right) varies between ids.
8. FOR ALL Day_Counts and Grave ids, calling the Weathering function twice with the same arguments SHALL return equal values (determinism).
9. THE Weathering function SHALL accept a negative Day_Count (a Date_Of_Death after Today) and SHALL treat it as 0.
10. THE Graveyard_Scene SHALL compute the Day_Count with the existing `DeadFor.between` and the Today of the Graveyard_Controller, and SHALL NOT read the clock itself.
11. WHEN Today changes (the controller's `refreshToday` runs), THE Graveyard_Scene SHALL recompute the Weathering of every Tombstone without replaying a Rise.
12. THE Weathering SHALL be shown only as Tilt, as Fade and, for a Grave older than the Crack_Age_Threshold, as Cracks of the stone, and SHALL NOT change the size of the Tombstone, the position of its cell, or the position of its text.
13. THE Tilt SHALL rotate the Tombstone around the middle of its base, so that the base stays on the Ground and no Tombstone overlaps the next cell of its row.
14. THE Tombstone SHALL leave a margin around its cell of at least `tombstoneWidth * sin(3 degrees)` so that a tilted Tombstone does not overlap its neighbours.
15. WHEN the Day_Count is strictly greater than the Crack_Age_Threshold of 1825 days, THE Crack_Generator SHALL return between 1 and 3 Cracks.
16. WHEN the Day_Count is 1825 or less, including 0 and every negative value, THE Crack_Generator SHALL return an empty list.
17. FOR ALL Grave ids, Stone_Box sizes and Keep_Out_Areas, THE Crack_Generator SHALL return equal Cracks for the same arguments (determinism), and SHALL return equal Cracks for any two Day_Counts above the Crack_Age_Threshold, so that the same Grave always looks the same and its Cracks do not change as it ages further.
18. THE Crack_Generator SHALL derive the Cracks from the Stable_Hash of the Grave id only (and the Stone_Box size and Keep_Out_Areas), and SHALL NOT use `String.hashCode`, `DateTime.now()` or `math.Random`.
19. THE Crack_Generator SHALL return Cracks of 3 to 5 points, with every point inside the Crack_Band and every coordinate an integer value, so that the result is identical on the Dart VM and on Flutter Web.
20. FOR ALL Cracks returned, every point of every segment, expanded by half the stroke width of 1.5 logical pixels, SHALL lie inside the Stone_Box and outside every Keep_Out_Area (containment).
21. IF the Crack_Band is shorter than 6 logical pixels or narrower than 8 logical pixels, THEN THE Crack_Generator SHALL return an empty list.
22. THE Tombstone SHALL pass to the Crack_Generator, as Keep_Out_Areas, the content box of the card (from the top of the arch to 20 logical pixels above the stone base, and from 20 logical pixels inside the left edge to 20 logical pixels inside the right edge) and the rectangle of the Epitaph, so that the Cracks never overlap the title, the date line, the Dead_For_Text body, the description lines or the Epitaph.
23. THE Tombstone SHALL draw the Cracks with the Crack_Painter as a foreground layer above the stone, inside the same rotated subtree as the stone, so that the Tilt carries the Cracks, as strokes of 1.5 logical pixels with round caps and no fill.
24. THE Crack_Painter SHALL be excluded from semantics, SHALL ignore pointer events and SHALL NOT take focus, and the semantic label of the Tombstone SHALL NOT mention Cracks.
25. THE Crack_Painter SHALL use only a color derived from a `CoffinColorTokens` token (through `SpookyTokens` or the theme), in the dark and the daylight theme, and SHALL add no hard-coded color.
26. WHILE Reduced_Motion is true, THE Tombstone SHALL draw its Cracks exactly as it does when motion is allowed, because Cracks are static and use no controller and no ticker.
27. WHEN Today changes so that the Day_Count of a Grave crosses the Crack_Age_Threshold, THE Graveyard_Scene SHALL add or remove its Cracks without replaying a Rise.
28. THE Stable_Hash SHALL also choose the sign of the Tilt (left or right) in place of `String.hashCode`, so that the Tilt of a Grave is the same on the Dart VM, on Flutter Web and on every visit.

### Requirement 8: Contrast of the weathered state

**User Story:** As a user with low vision, I want every text on every tombstone to stay readable, however old the grave is, so that weathering never hides information.

#### Acceptance Criteria

1. FOR ALL Weathering_Levels from 0 to 1, THE Tombstone SHALL keep the contrast ratio between each text color and the weathered stone color behind it at or above the Contrast_Minimum of 3.0, in the dark theme and in the daylight theme.
2. THE Fade SHALL blend the stone color toward the Ground color only, and SHALL NOT change the text color, the icon color or the focus ring color.
3. THE design SHALL choose the maximum Fade (at most 0.25) so that the lowest contrast of requirement 8.1 is at least 3.0 for the Epitaph, the title, the date line, the Dead_For_Text, the description and the star count, in both themes.
4. THE unit tests SHALL compute `WcagContrast.ratio` for every text token over the stone color at the Weathering_Levels 0, 0.5 and 1, for `CoffinColorTokens.night` and `CoffinColorTokens.daylight`, and SHALL fail WHEN any ratio is below 3.0.
5. THE property tests SHALL verify, FOR ALL Day_Counts and in both themes, that the stone color after the Fade of the Weathering function and each text token keep a ratio of at least 3.0.
6. THE Tombstone SHALL keep the 3.0 minimum when the Fog_Layer overlaps its stone, because the text sits on the opaque stone color and not on the fog.
7. THE weathered state SHALL NOT be the only sign of age, because the Dead_For_Text and the date line remain on every Tombstone.
8. FOR ALL colors of the Night_Sky behind the Tombstones, THE focus ring and the delete button label SHALL keep a ratio of at least 3.0 against the color directly behind them, in both themes.
9. THE Cracks SHALL NOT overlap the title, the date line, the Dead_For_Text, the description or the Epitaph (Requirements 7.20 and 7.22), so that the color directly behind every text stays the stone color and the ratios of criteria 8.1 to 8.5 are the same with and without Cracks, at every Weathering_Level, in both themes.
10. THE Cracks SHALL NOT cover the focus ring, the glow or the delete control, because every Crack point stays at least 20 logical pixels from the left and the right edge of the stone and at least 6 logical pixels above its base, and the delete control lies outside the stone.

### Requirement 9: Epitaph fits the arch

**User Story:** As a user, I want the engraved line at the top of each tombstone to be fully visible, so that I can read it without losing letters.

#### Acceptance Criteria

1. THE Tombstone SHALL draw the Epitaph so that the whole text lies inside the arch, with no letter clipped by the curve, at every Tombstone width from 240 to 300 logical pixels and at every text scale from 1.0 to 2.0.
2. THE Arch_Fit function SHALL return, for an arch width, an arch rise, a line height and a text width, the top position at which the full line rectangle lies inside the arch curve, with a margin of at least 4 logical pixels between the line corners and the curve.
3. FOR ALL arch widths from 120 to 300, arch rises from 60 to 200, line heights from 8 to 60 and text widths from 1 to the arch width, WHEN the Arch_Fit function returns a position, THE two upper corners of the line rectangle placed at that position SHALL lie inside the arch curve (invariant).
4. IF the Epitaph text width at the base font size is larger than the width available inside the arch at the position of Arch_Fit, THEN THE Tombstone SHALL shrink the Epitaph_Font_Size, down to 12 logical pixels at the most, and WHEN the Epitaph still does not fit at 12 logical pixels, THE Tombstone SHALL truncate it with an ellipsis on a single line, never clip it. The Epitaph is the one word "R.I.P." and is never wrapped.
5. THE Epitaph SHALL read "R.I.P." on screen, as in the constant `GraveyardCopy.epitaph`, except for ellipsis truncation as in criterion 4, and SHALL NOT lose its first or last character to clipping.
6. THE Tombstone SHALL keep the Epitaph visible at every text scale from 1.0 to 2.0, and SHALL NOT hide it with the rule that `GraveTile` uses today (`_maxEpitaphScale`); instead it SHALL apply criterion 4 so that "R.I.P." fits inside the arch at every width from 240 to 300 logical pixels and every text scale up to 2.0.
7. THE widget tests SHALL render the Epitaph "R.I.P." at the widths 240, 270 and 300 and at the text scales 1.0, 1.5 and 2.0, and SHALL assert that the painted bounds of the text lie inside the arch region and that the text is not clipped.
8. THE Epitaph SHALL stay hidden from screen readers as a decoration, and the Tombstone label of Requirement 10.8 SHALL carry the meaning of the Tombstone.
9. WHILE the Tombstone is tilted by the Weathering, THE Epitaph SHALL rotate with the Tombstone, and Criterion 1 SHALL still hold in the rotated frame.
10. THE fix SHALL live in `apps/graveyard`, because `coffin_core` stays unchanged. The design SHALL decide whether the app wraps `TombstoneCard` (for example by turning off its engraved epitaph and drawing an Epitaph inside the app's own arch) or draws its own tombstone.

### Requirement 10: Show each fact once

**User Story:** As a user, I want each fact on a tombstone shown once, so that the stone is clean and quick to read.

#### Acceptance Criteria

1. THE Tombstone SHALL show the Dead_For_Text exactly once in its visible content, as a line of the body in the body font, at every text scale.
2. THE Epitaph SHALL be the constant "R.I.P." for every Grave and SHALL NOT contain the Dead_For_Text or any part of it, so that the body line is the single place that states how long the project has been dead.
3. FOR ALL Graves with the source GitHub, THE Tombstone SHALL show the `full_name` once, as the title, WHEN the Project_Name equals the `full_name` of the Repo_Info, and SHALL NOT show the `full_name` as a second line.
4. FOR ALL Graves with the source GitHub, WHEN the Project_Name differs from the `full_name` (data from an older version), THE Tombstone SHALL show the Project_Name as the title and the `full_name` once as a source line.
5. FOR ALL Graves, THE visible text of a Tombstone SHALL contain each of the Dead_For_Text, the date line, the Project_Name and, for a GitHub Grave, the `full_name` at most once (uniqueness property on the list of visible text fragments).
6. THE Tombstone SHALL keep a visible by-hand marker ("Buried by hand.") for a Manual Grave, and a visible source line for a GitHub Grave, as `GraveyardCopy.buriedByHand` and the star line do now.
7. WHEN the Archived flag is true, THE Tombstone SHALL keep the visible word "Archived" next to the star count, so that the state is not conveyed by color alone.
8. THE semantic label of the Tombstone SHALL keep stating the Project_Name, the Dead_For_Text, the source and, for a GitHub Grave, the `full_name`, the stars and the archived state, as in requirement 14.3 of graveyard-core. The label is read by screen readers only, so the same facts there are not a repetition on screen.
9. THE existing tests of `grave_tile_test.dart` and `graveyard_screen_test.dart` that expect the duplicate texts SHALL be changed to expect the single text.
10. THE Tombstone_Facts function SHALL return, for a Grave, its Today and its date line text, a list of fragments in which each kind (dead-for text, date line, title, full name) occurs at most once, and in which a full-name fragment occurs only for a GitHub Grave whose Project_Name differs from the `full_name`. It SHALL be a pure function in `lib/src/domain` and the Tombstone SHALL show exactly the fragments it returns.

### Requirement 11: Plain-text descriptions

**User Story:** As a user, I want descriptions to read as plain text, so that ":atom:" and other code words do not litter my tombstones.

#### Acceptance Criteria

1. THE Description_Cleaner SHALL remove every Emoji_Shortcode from a description, and SHALL then collapse every run of whitespace to one space and trim the ends.
2. THE Description_Cleaner SHALL treat a text as an Emoji_Shortcode only WHEN it is `:name:` with `name` of 1 to 40 characters from [A-Za-z0-9_+-] that contains at least one ASCII letter, is preceded by the start of the text or whitespace, and is followed by the end of the text or whitespace.
3. WHEN a description contains the text "10:30 to 11:45", "10:30:45", "localhost:8080" or "a:b:c", THE Description_Cleaner SHALL return it unchanged, because no word of it is an Emoji_Shortcode.
4. WHEN the description is ":atom: The hackable text editor", THE Description_Cleaner SHALL return "The hackable text editor", and WHEN the description is "Fast :rocket: builds", THE Description_Cleaner SHALL return "Fast builds".
5. THE Description_Cleaner SHALL NOT remove Unicode emoji characters that the author typed. It removes only Emoji_Shortcodes, and SHALL NOT add any emoji.
6. WHEN the cleaned description is empty, THE Tombstone SHALL show no description line and SHALL NOT show an empty gap.
7. THE Description_Cleaner SHALL be a pure function that never throws, whatever text it receives.
8. FOR ALL descriptions, THE Description_Cleaner applied twice SHALL give the same result as applied once (idempotence).
9. FOR ALL descriptions, THE output of the Description_Cleaner SHALL contain no Emoji_Shortcode, SHALL contain no leading, trailing or doubled whitespace, and SHALL NOT be longer than the input (invariant).
10. FOR ALL descriptions in which no whitespace-delimited word is an Emoji_Shortcode, THE Description_Cleaner SHALL return the whitespace-normalised input (identity apart from whitespace).
11. THE Description_Cleaner SHALL be applied at display time, and SHALL NOT change the stored Repo_Info, the `Grave_Codec` or the data written to storage, so that the stored description stays as GitHub sent it.
12. THE semantic label of the Tombstone SHALL carry the cleaned description, so that screen readers do not read ":atom:".
13. THE Tombstone SHALL keep showing the cleaned description as plain text, truncated to at most 3 lines with an ellipsis, and SHALL NOT interpret Markdown, HTML or emoji shortcodes.

### Requirement 12: Star counts with thousands separators

**User Story:** As a user, I want star counts I can read at a glance, so that "60,683" does not look like a wall of digits.

#### Acceptance Criteria

1. THE Thousands_Formatter SHALL return the digits of a non-negative integer with a comma between each group of three digits, counted from the right.
2. WHEN the count is 0, 7, 999, 1000, 60683, 181478 or 1234567, THE Thousands_Formatter SHALL return "0", "7", "999", "1,000", "60,683", "181,478" or "1,234,567".
3. FOR ALL non-negative integers below 2^53, removing the commas from the output of the Thousands_Formatter SHALL give the decimal text of the integer (round-trip property).
4. FOR ALL non-negative integers below 2^53, every comma of the output SHALL be followed by exactly three digits, and the first group SHALL have one to three digits and no leading zero, except for the integer 0 (invariant).
5. FOR ALL non-negative integers below 2^53, the output SHALL contain no character other than digits and commas.
6. IF the integer is negative, THEN THE Thousands_Formatter SHALL format its absolute value with a leading minus sign, and SHALL NOT throw.
7. THE Thousands_Formatter SHALL NOT use the `intl` package and SHALL NOT depend on the device locale.
8. THE visible star line of a GitHub Tombstone SHALL use the Thousands_Formatter, for example "60,681" for `atom/atom`, together with the word "Archived" WHEN the archived flag is true.
9. THE semantic label of a GitHub Tombstone SHALL read the star count with the Thousands_Formatter, and SHALL keep the singular "1 star" and the plural "stars".
10. THE Thousands_Formatter SHALL be a pure function in `lib/src/domain` with no Flutter import.

### Requirement 13: Interaction and accessibility of the scene

**User Story:** As a user with a screen reader, a keyboard or a touch screen, I want the scene to be just as usable as the old list, so that the picture adds beauty and takes nothing away.

#### Acceptance Criteria

1. THE Night_Sky, the Moon, the Stars, the Ground and the Fog_Layer SHALL be excluded from semantics and SHALL NOT take focus.
2. THE Graveyard_Scene SHALL expose each Tombstone as one semantic node in the order of the Graves (left to right, then top to bottom), with the label of Requirement 10.8, and SHALL NOT expose the Epitaph as a second node.
3. THE delete control of each Tombstone SHALL keep a tap target of at least 48 by 48 logical pixels, a hover state, a press state, a visible focus indicator and the semantic label of `GraveyardCopy.deleteLabel`, including on a tilted Tombstone and WHILE a Rise plays.
4. THE focus order of the Graveyard_Screen SHALL follow the order of the Graves (left to right, then top to bottom) and SHALL then reach the add control.
5. WHILE a Tombstone rises, THE delete control SHALL be reachable and SHALL NOT move away from under the pointer by more than the 24 logical pixels of the start offset.
6. THE add control (`GraveyardCopy.addButton`) SHALL stay visible and reachable above the scene, with a tap target of at least 48 by 48 logical pixels and a label.
7. THE Graveyard_Scene SHALL use only color tokens from `CoffinColorTokens` (through `SpookyTokens` or the theme), and SHALL add no hard-coded color outside the token set, except for the white-to-transparent blends that the Moon glow and the Star points need, which SHALL derive from a token.
8. THE Graveyard_Scene SHALL NOT convey any state (archived, error, age) by color alone.
9. THE Graveyard_Scene SHALL keep the existing states: loading with `GhostLoader`, the load error with retry, the empty state with both add options, the Memory_Notice, and the save error banner, each drawn on top of the Night_Sky and the Fog_Layer without overflow at widths of 320 and 360 logical pixels and a text scale of 1.5.
10. WHILE the list is empty, THE Graveyard_Screen SHALL show the Night_Sky, the Moon, the Stars, the Ground and the empty-state panel, so that the first visit already looks like a graveyard at night.
11. THE Graveyard_Scene SHALL keep the existing keyboard behavior: Enter and Escape in the Add_Sheet and in the delete dialog, as in graveyard-core Requirement 14.5.

### Requirement 14: Copy tone

**User Story:** As a user, I want any new words in the scene to be short, witty and kind, so that the app keeps one voice.

#### Acceptance Criteria

1. WHERE the scene adds visible copy (for example a ground line under the Moon, a label or a hint), THE Graveyard_App SHALL define it in `GraveyardCopy`, short, slightly spooky and never mean to the user, and SHALL NOT use gore, blame or the words "failed" or "your fault".
2. THE Epitaph copy `GraveyardCopy.epitaph` SHALL be the constant "R.I.P.", which is short enough to meet Requirement 9 at the width of 240 logical pixels and the text scale of 2.0.
3. THE Graveyard_App SHALL write no new copy in a widget file outside `GraveyardCopy`, except for strings of no user-facing meaning (keys, debug names).
4. THE `graveyard_copy_test.dart` tests SHALL cover each new string and each changed string of this feature.

### Requirement 15: Architecture and boundaries

**User Story:** As a maintainer, I want the scene math separate from the drawing and the app separate from the skeleton, so that the code stays easy to read and test.

#### Acceptance Criteria

1. THE implementation of this feature SHALL edit only `apps/graveyard/lib`, `apps/graveyard/test` and `.kiro/specs/graveyard-scene`, and the `git diff` of every other path SHALL be empty.
2. THE `git diff` of `packages/coffin_core`, `apps/hauntagotchi`, `tool/`, `pubspec.lock`, every `pubspec.yaml`, `CREDITS.md` and `.github/` SHALL be empty.
3. THE Domain SHALL hold the pure scene math (Star_Field, Twinkle, Scene_Layout, Weathering, Rise_Progress, Arch_Fit, the new-grave function, the Crack_Generator, the Stable_Hash, the Tombstone_Facts, the Description_Cleaner and the Thousands_Formatter) in `lib/src/domain` or in one folder under it, and SHALL import no `package:flutter` library, no `dart:ui`, no `dart:io` and no `dart:html`. Colors in the Domain are plain integers or numbers, not `Color` objects.
4. THE Graveyard_App SHALL import only `package:coffin_core/coffin_core.dart` from `coffin_core`, SHALL NOT import any file under `coffin_core/lib/src`, and SHALL NOT import from Hauntagotchi.
5. THE painters and widgets of the scene SHALL live in `lib/src/ui`, SHALL keep files in `snake_case.dart` with one public class per file, and SHALL contain only drawing and wiring, with the numbers computed by the Domain.
6. THE Graveyard_App SHALL use `ChangeNotifier` with `ListenableBuilder` for state, `AnimationController` for animation, and no state-management package and no animation package.
7. THE Graveyard_App SHALL pass `dart format` and `flutter analyze` with zero warnings, and SHALL document each public Domain type with a doc comment.
8. THE existing source-rule tests (`test/source_rules`) SHALL keep passing, and the Domain import rule SHALL cover the new Domain files.
9. THE implementation SHALL NOT treat `DIARY.md` as a protected file, and SHALL NOT edit it as part of this feature unless the user asks.
10. THE implementation and its tests SHALL NOT create any file outside the repository, including under `/tmp`. Tests that need files SHALL NOT write to disk, and any helper output SHALL stay inside the repository workspace.

### Requirement 16: Tests

**User Story:** As a maintainer, I want the scene covered by tests that always run, so that a later change cannot silently break the look or the rules.

#### Acceptance Criteria

1. THE unit tests, the property tests and the widget tests of this document SHALL be mandatory, and no test task SHALL be marked optional or skippable.
2. THE test suite SHALL mirror the `lib/` folder structure under `apps/graveyard/test/`, with pure-math tests under `test/domain` and widget tests under `test/ui`. No file under `test/domain` SHALL import `dart:io`, so `flutter test --platform chrome test/domain` runs.
3. THE property tests SHALL use glados with Web_Safe_Generators (reusing the support folder `test/domain/support/`), SHALL NOT use `any.intInRange` or `any.listWithLengthInRange`, SHALL keep every generated integer below 2^53, and SHALL run at least 100 iterations each.
4. THE property tests SHALL cover: Star_Field determinism, bounds and Moon clearance (1.3 to 1.6), Twinkle range, periodicity and smoothness (2.2 to 2.4), Scene_Layout column bounds, width fit, row and column mapping and injectivity (4.3 to 4.6), Rise_Progress bounds and monotonicity (5.3), the new-grave function (5.12), Weathering bounds, monotonicity, tilt limit, fade limit and determinism (7.3 to 7.8), the contrast of the weathered stone in both themes (8.5), Arch_Fit containment (9.3), the uniqueness of visible facts (10.5), the Description_Cleaner properties (11.8 to 11.10), the Thousands_Formatter properties (12.3 to 12.5), and the Crack_Generator property (7.15 to 7.22: count 1 to 3 above the threshold and none at or below it, containment inside the stone and outside the Keep_Out_Areas, and determinism from the Grave id).
5. THE unit tests SHALL cover: the examples of Requirements 11.3, 11.4 and 12.2, the negative number of 12.6, the zero Day_Count of 7.2, the negative Day_Count of 7.9, the contrast table of 8.4, the column count at the widths 319, 320, 719, 720, 1000, 1280 and 4096, the empty and single-Grave layouts, the Crack_Age_Threshold boundary (Day_Counts 1824, 1825 and 1826, 0 and a negative value), a Stone_Box with no room for Cracks (7.21), a pinned Crack list for one fixed Grave id, and the Stable_Hash of fixed strings (including the empty string and a non-ASCII string).
6. THE widget tests SHALL cover: the scene in the states empty, loading, list, load error, Memory_Notice and save error; one column at 360 and 2 to 4 columns at 768 and 1280; the Rise on an added Grave and no Rise on loaded Graves; no Rise when another Grave is deleted; the Still_Scene with `disableAnimations` true and no pending frame; the Epitaph "R.I.P." at widths 240, 270 and 300 and text scales 1.0, 1.5 and 2.0; the single display of the Dead_For_Text in the body and of `owner/repo`; the cleaned `atom/atom` description; "60,681" on the `atom/atom` tombstone; the tilt and fade of an old Grave against a fresh one; the Cracks of a Grave older than 1825 days and no Cracks at 1825 days, with the painted Crack bounds outside every rendered text rectangle at widths 240, 270 and 300 and text scales 1.0, 1.5 and 2.0; the same Cracks after a rebuild and after a resize; the Cracks under `disableAnimations` true; the Cracks excluded from semantics; and the semantic labels and 48 by 48 tap targets of the delete control.
7. THE widget tests SHALL use a Fake_Clock, a Fake_GitHub_Client and `MemoryRecordRepository`, and SHALL NOT use real Hive storage, the network, or the real time. Animations in tests SHALL be advanced with `pump(duration)`, and SHALL NOT use real waits.
8. THE widget tests SHALL render in the dark and the daylight theme, and SHALL verify the 3.0 contrast of requirement 8 on the rendered colors of a fresh and of a ten-year-old Grave.
9. THE existing tests of `apps/graveyard` that depended on the old list layout or on the repeated texts SHALL be updated in the same change, and the whole suite SHALL pass.
10. THE Graveyard_App SHALL pass `flutter analyze` with zero warnings, `dart format --set-exit-if-changed` with no changes, and `flutter test` in `apps/graveyard` before the feature counts as done. The `flutter test` suites of `coffin_core`, `apps/hauntagotchi` and `tool/` SHALL pass unchanged.

## Out of Scope

The following belong to later specs or are not planned. This feature builds none of them:

- Any Epitaph text other than "R.I.P.", such as a per-grave epitaph, a choice of epitaph, or an epitaph that states the age.
- The AI séance, the resurrection score and the 3-step revival plan.
- Resurrection of a project.
- Editing a Grave, search, filter, or a sort order other than newest death first.
- Moving tombstones by drag, free placement of tombstones, or a user-chosen layout.
- Parallax, a moving moon, shooting stars, bats, owls, or any other scene element beyond the Moon, the Stars, the Ground and the fog.
- Sound.
- Changes to `coffin_core`, including a new shared widget, a change to `TombstoneCard`, or a change to `FogBackground`.
- A change to the storage format, the codec, the GitHub client, the import flow, or the sorting and duplicate rules.
- Locale-aware number formatting beyond the comma separator of Requirement 12.
