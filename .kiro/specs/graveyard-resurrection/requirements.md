# Requirements Document

## Introduction

The graveyard-resurrection feature is the payoff of a séance in `apps/graveyard`. After a séance, the user can raise the project from the dead. A skeletal hand bursts from the ground in front of the Tombstone with a few clods of earth, a ghost rises, and the stone changes from "R.I.P." to "RISEN". The risen project then leaves the graveyard rows and moves to a small "Back among the living" row above the graveyard. This is the last big visual moment of the app, and it is the moment the demo video ends on.

The séance sheet gets a "Raise it" button. Raising closes the sheet and plays the Resurrection_Play on that Tombstone. A risen project in the Living_Row offers "Lay it back to rest", with a confirmation, to undo the raising.

The risen state is saved. `Grave` gains an optional "risen on" calendar date, a local `CalendarDate` and never a `Duration`. Saved graves without the field still load, as not risen. The Resurrection_Play runs once, when the user raises the project, and never again on reload.

The animation is plain Flutter: `CustomPainter` for the hand and the clods, `GhostLoader` of `coffin_core` with `GhostMood.rising` for the ghost, and the `ArchEpitaph` of graveyard-scene for the word "RISEN" (`GraveTombstone` keeps `TombstoneCard` with `showEpitaph: false` and draws the epitaph itself through `ArchEpitaph`). No package and no asset is added. `coffin_core` does not change. Everything that is pure logic (the risen-state rules, the motion curve and the geometry of the hand, the box of the rising ghost, the paths of the clods, the split of the graveyard into rows and Living_Row) lives in `apps/graveyard/lib/src/domain` and is covered by unit tests and glados property tests.

This feature builds on graveyard-core (the `Grave` model, `GraveCodec`, `CalendarDate`, `Clock`, `GraveListController`, `GraveSorter`), graveyard-scene (`GraveTombstone`, `GraveyardScene`, `RiseProgress`, `Weathering`, `ArchFit`, `ArchEpitaph`, `StableHash`, `StableRandom`, `GraveyardCopy`) and graveyard-seance (`SeanceSheet`, `showSeanceSheet`, `SeanceControl`). It follows the design language "Haunted, not horror": slow and floaty motion, 16 px corners, soft glows, tap targets of at least 48 by 48 logical pixels, and short, witty, kind copy that is a little triumphant.

Exact timings inside the bounds stated here, sizes, counts and colors that are not stated here belong to the design phase.

## Dependency Notice

No dependency changes:

- No package is added to `apps/graveyard/pubspec.yaml`, and `pubspec.lock` stays byte-for-byte unchanged.
- No font, image, sound or other asset is added, and `CREDITS.md` stays unchanged.
- No network call is made by this feature. No API key, token or secret appears in the app, the tests or the repository.
- Only `apps/graveyard/lib`, `apps/graveyard/test` and `.kiro/specs/graveyard-resurrection` change. `packages/coffin_core`, `apps/hauntagotchi` and `tool/` stay unchanged. In particular `GhostLoader`, `GhostMood`, `TombstoneCard` and `FogBackground` of `coffin_core` stay unchanged.
- No file is created outside the repository, including `/tmp`. `DIARY.md` is maintained by the user and is not protected by this spec.

## Glossary

- **Graveyard_App**: The Flutter app in `apps/graveyard`.
- **Domain**: The pure Dart code in `apps/graveyard/lib/src/domain`. It imports no Flutter library, no `dart:ui`, no `dart:io`, no `dart:html`, no `package:coffin_core`, no networking package and no storage package, and never calls `DateTime.now()`.
- **Grave**: The existing `Grave` model of the Domain, with `id`, `name`, `dateOfDeath`, `source` and `repo`, and, by this feature, `risenOn`.
- **Risen_On**: The optional `CalendarDate` on a Grave that says on which local calendar day the project was raised. Null means the Grave is not risen.
- **Risen**: A Grave whose Risen_On is not null.
- **Raise**: The action that sets the Risen_On of a Grave to Today.
- **Lay_To_Rest**: The action that clears the Risen_On of a Grave.
- **Today**: The current `CalendarDate`, read through the existing `Clock` outside the Domain and passed into the Domain as an input.
- **Grave_Codec**: The existing `GraveCodec` of `lib/src/data`.
- **Legacy_Record**: A saved record of a Grave that has no risen key, as written before this feature.
- **Tombstone**: One Grave drawn by `GraveTombstone` in the Graveyard_Scene.
- **Stone_Area**: The rectangle of one Tombstone, in stone coordinates with the origin at the top-left corner of the stone, as wide and as high as the stone as laid out by `GraveTombstone`, before the tilt of `Weathering` is applied.
- **Graveyard_Scene**: The existing `GraveyardScene` widget that paints the sky and the ground and places the Tombstones in rows.
- **Graveyard_Rows**: The rows of Tombstones in the Graveyard_Scene.
- **Living_Row**: The small row titled "Back among the living" above the Graveyard_Rows. It lists Risen Graves that are not playing.
- **Living_Entry**: One Risen Grave in the Living_Row, with its name, its "Risen on" line, its Repository_Link where it has one, and its Lay_To_Rest control.
- **Repository_Link**: The control of a Living_Entry that shows the full repository name of a GitHub Grave and gives access to its repository address.
- **Seance_Sheet**: The existing modal bottom sheet of graveyard-seance.
- **Raise_Control**: The "Raise it" button in the Seance_Sheet.
- **Lay_To_Rest_Control**: The "Lay it back to rest" button of a Living_Entry.
- **Rest_Dialog**: The confirmation dialog that Lay_To_Rest asks for before it clears the Risen_On.
- **Resurrection_Play**: The one-time animation on one Tombstone after a Raise: the Hand, the Clods, the Rising_Ghost and the epitaph change.
- **Play_Duration**: The total length of the Resurrection_Play, from 2000 to 3000 ms, and at least 2600 ms, fixed by the design phase. The play ticker runs for the full Play_Duration and stops at its end.
- **Hand**: The skeletal hand, drawn with a `CustomPainter`, that bursts up from the ground at the base of the stone and then sinks back.
- **Hand_Height**: The pure function from elapsed milliseconds to a number from 0 (hidden) to 1 (fully out) that drives the Hand.
- **Hand_Geometry**: The pure function from the Stone_Area size and elapsed milliseconds to the points of the Hand, with no drawing involved.
- **Clod**: One small clump of earth, drawn with a `CustomPainter`, that is thrown up by the Hand and falls back.
- **Clod_Path**: The pure function from a Clod and an elapsed time to a position and a size inside the Stone_Area.
- **Rising_Ghost**: The `GhostLoader` of `coffin_core` with `GhostMood.rising` that rises from the grave during the Resurrection_Play, placed inside the Rising_Ghost_Box and carried up with it.
- **Rising_Ghost_Box**: The pure function from the Stone_Area size, the text scale and elapsed milliseconds to the rectangle in which the Rising_Ghost is placed. The rectangle moves: it rises from the base of the stone (its bottom edge on the bottom edge of the Stone_Area) during the Rise_Window to an end position below the epitaph rectangle of the Epitaph_Footprint, and then holds still until the end of the play. Its horizontal center and its size never change during the play.
- **Rise_Window**: The span of the Resurrection_Play during which the Rising_Ghost_Box rises. The Rise_Window starts when the Hand has sunk back and ends before the epitaph fade starts. The design phase fixes the exact milliseconds. The ghost reaction of the Rising_Ghost starts at the start of the Rise_Window.
- **Epitaph_Footprint**: The pure Domain function from the Stone_Area width and the text scale to the epitaph rectangle of the stone. It is built on `ArchFit` and a fixed model of the text metrics, so that it needs no text measuring and no Flutter library, and it covers the rectangle that `ArchEpitaph.rectFor` returns for "R.I.P." and for "RISEN". The design phase fixes the model.
- **Epitaph_Rectangle**: The rectangle that the Epitaph_Footprint returns, in stone coordinates.
- **Rising_Ghost_Box_Top**: The vertical position of the top edge of the Rising_Ghost_Box in stone coordinates. A smaller value is higher on the stone.
- **Epitaph_Text**: The word engraved by `ArchEpitaph` in the arch of a Tombstone: "R.I.P." for a Grave that is not Risen and "RISEN" during and after a Resurrection_Play.
- **Playing_Set**: The set of Grave ids whose Resurrection_Play is running now. It lives in memory only and is never saved.
- **Living_Split**: The pure Domain function from the list of Graves and the Playing_Set to the Graveyard_Rows list and the Living_Row list.
- **Reduced_Motion**: The state in which `MediaQuery.disableAnimations` is true.
- **Risen_Announcement**: The single polite live-region message that tells a screen reader that a project has risen.
- **Resurrection_Copy**: Every user-facing string of this feature, held in `GraveyardCopy`.
- **Allowed_Characters**: Printable ASCII (U+0020 to U+007E), the letter "é" (U+00E9) and the ellipsis "…" (U+2026).
- **Web_Safe_Generator**: A glados generator that avoids `any.int`, `any.intInRange`, `any.list`, `any.listWithLengthInRange`, string generators and `uint*`, which throw or differ on Flutter Web in glados 1.1.7. It is built on `anyIntBetween` and `anyListBetween` from `test/domain/support/grave_generators.dart` and keeps every generated integer below 2^53.

## Requirements

### Requirement 1: Raise it from the séance sheet

**User Story:** As a user, I want a "Raise it" button in the séance sheet, so that I can bring a project back to life right after I hear its verdict.

#### Acceptance Criteria

1. WHILE the Grave of an open Seance_Sheet is not Risen and not in the Playing_Set, THE Seance_Sheet SHALL show one Raise_Control with the visible label "Raise it".
2. THE Raise_Control SHALL have a tap target of at least 48 by 48 logical pixels.
3. THE Raise_Control SHALL have a semantic label that names the Grave, in the form "Raise <name> from the dead".
4. THE Raise_Control SHALL be reachable by keyboard focus, SHALL activate on Enter and Space, and SHALL show a visible focus state, a hover state and a pressed state.
5. THE Raise_Control SHALL stay visible and reachable in every state of the Seance_Sheet, including while the verdict line is pending, and at every width and text scale of Requirement 15.
6. WHEN the user activates the Raise_Control, THE Graveyard_App SHALL close the Seance_Sheet, SHALL Raise the Grave with Today as the Risen_On, and SHALL start the Resurrection_Play on the Tombstone of that Grave.
7. WHEN the user activates the Raise_Control twice in quick succession, THE Graveyard_App SHALL Raise the Grave once and SHALL start one Resurrection_Play.
8. IF the Grave of the Seance_Sheet is no longer in the list when the user activates the Raise_Control, THEN THE Graveyard_App SHALL close the Seance_Sheet, SHALL start no Resurrection_Play and SHALL throw no exception.
9. THE Raise_Control SHALL NOT change the score, the band, the steps or the verdict line that the Seance_Sheet shows.
10. WHEN the Seance_Sheet closes through its close button, Escape, a tap outside the sheet or a drag down, THE Graveyard_App SHALL NOT Raise the Grave.

### Requirement 2: Risen state in the model

**User Story:** As a maintainer, I want the risen state to be a plain optional date on the Grave, so that the rules are small, pure and easy to test.

#### Acceptance Criteria

1. THE Grave SHALL hold an optional Risen_On of type `CalendarDate`, with the value null when the Grave is not Risen.
2. THE Grave SHALL keep its existing constructors callable without a Risen_On, so that every existing call site and every existing test compiles and passes unchanged.
3. THE Domain SHALL provide a Raise function that returns a copy of a Grave with the Risen_On set to the given Today, with every other field equal to the original.
4. THE Domain SHALL provide a Lay_To_Rest function that returns a copy of a Grave with the Risen_On cleared, with every other field equal to the original.
5. THE Grave SHALL include the Risen_On in its equality and its hash code.
6. THE Domain SHALL store the Risen_On as a local calendar date, SHALL use no `Duration` and no `DateTime` for it, and SHALL NOT depend on the time zone of the machine.
7. FOR ALL Graves that are not Risen and FOR ALL values of Today, Lay_To_Rest of the Raise of the Grave SHALL equal the original Grave (raise then undo returns the original).
8. FOR ALL Graves and FOR ALL values of Today, the Raise of a Risen Grave SHALL keep the Risen_On it already has, so that raising twice equals raising once (idempotence).
9. FOR ALL Graves, Lay_To_Rest of a Lay_To_Rest SHALL equal Lay_To_Rest of the Grave (idempotence).
10. FOR ALL Graves and FOR ALL values of Today, the Raise and the Lay_To_Rest SHALL keep `id`, `name`, `dateOfDeath`, `source` and `repo` unchanged.
11. THE Raise and the Lay_To_Rest SHALL never throw for any Grave and any Today.
12. THE Raise SHALL NOT change the day count, the weathering, the cracks or the revival facts of the Grave, which depend only on `dateOfDeath`, `source` and `repo`.

### Requirement 3: Saving the risen state

**User Story:** As a user, I want a risen project to stay risen after I reload, so that the payoff is not lost when I close the tab.

#### Acceptance Criteria

1. WHEN the Grave_Codec encodes a Risen Grave, THE Grave_Codec SHALL write the Risen_On under one new key as `YYYY-MM-DD`, placed after every existing key.
2. WHEN the Grave_Codec encodes a Grave that is not Risen, THE Grave_Codec SHALL write no risen key, so that the encoded map equals the map written before this feature.
3. FOR ALL valid Graves, with and without a Risen_On, decoding the encoding of the Grave SHALL return a Grave equal to the original (round trip).
4. WHEN the Grave_Codec decodes a Legacy_Record, THE Grave_Codec SHALL return a Grave that is not Risen.
5. IF the risen key of a record is present and its value is not a string of the form `YYYY-MM-DD` that names a real calendar date, THEN THE Grave_Codec SHALL throw `FormatException`, like it does for any other corrupt field.
6. FOR ALL valid records with a risen value that is not a real calendar date (a wrong type, a wrong format, a month of 13, a 30th of February), decoding SHALL throw `FormatException` and SHALL throw no other type of error.
7. THE Grave_Codec SHALL keep ignoring unknown keys and SHALL keep every decoding rule of graveyard-core that this feature does not name.
8. THE existing codec and storage tests SHALL pass unchanged, with no edit to any existing test file.
9. WHEN a Raise or a Lay_To_Rest changes a Grave, THE `GraveListController` SHALL replace the Grave through a new `replaceGrave` method that replaces the Grave in place, keeps its position in the list (without re-sorting and without appending) and its id, and writes it through the existing write queue, with the same save status and retry behavior as an added Grave.
10. WHEN the Graveyard_App loads a saved Risen Grave, THE Graveyard_App SHALL show the Grave in the Living_Row and SHALL start no Resurrection_Play.
11. IF a write of a Raise or a Lay_To_Rest fails, THEN THE Graveyard_App SHALL show the existing save error banner with its retry control, and SHALL keep the new state in memory.

### Requirement 4: Lay it back to rest

**User Story:** As a user, I want to undo a raising, so that I can put a project back in its grave if I raised it by mistake or changed my mind.

#### Acceptance Criteria

1. THE Living_Entry SHALL show one Lay_To_Rest_Control with the visible label "Lay it back to rest".
2. THE Lay_To_Rest_Control SHALL have a tap target of at least 48 by 48 logical pixels, a semantic label that names the Grave in the form "Lay <name> back to rest", keyboard focus, and visible focus, hover and pressed states.
3. WHEN the user activates the Lay_To_Rest_Control, THE Graveyard_App SHALL open the Rest_Dialog, and SHALL NOT change the Grave yet.
4. THE Rest_Dialog SHALL name the Grave, SHALL offer one confirm button "Lay it to rest" and one cancel button "Keep it risen", and SHALL have no dead end: Escape and a tap outside the dialog SHALL act as cancel.
5. WHEN the user confirms the Rest_Dialog, THE Graveyard_App SHALL Lay_To_Rest the Grave, SHALL save it, and SHALL move it from the Living_Row back to the Graveyard_Rows with no Resurrection_Play.
6. WHEN the user cancels the Rest_Dialog, THE Graveyard_App SHALL leave the Grave Risen and unchanged.
7. WHEN a Grave returns to the Graveyard_Rows after a Lay_To_Rest, THE Graveyard_Scene SHALL show its Tombstone with the Epitaph_Text "R.I.P." and SHALL apply the existing Rise of graves that appear after the first list.
8. WHEN the Rest_Dialog closes, THE Graveyard_App SHALL return focus to the Lay_To_Rest_Control that opened it, WHERE that control is still in the tree.
9. IF the Grave of the Rest_Dialog is no longer in the list when the user confirms, THEN THE Graveyard_App SHALL close the dialog and SHALL throw no exception.
10. WHILE the Rest_Dialog is open, THE Graveyard_App SHALL open no second Rest_Dialog.

### Requirement 5: Back among the living

**User Story:** As a user, I want a small row above the graveyard that shows what I have brought back, so that I can see my wins and keep a link to the project.

#### Acceptance Criteria

1. WHILE the Living_Row has at least one Living_Entry, THE Graveyard_Scene SHALL show the Living_Row above the Graveyard_Rows, below the screen title and below any notice or banner of the existing header.
2. THE Living_Row SHALL have the visible heading "Back among the living", exposed as a semantic header.
3. WHILE the Living_Row has no Living_Entry, THE Graveyard_Scene SHALL show no Living_Row, no heading and no empty placeholder for it.
4. THE Living_Entry SHALL show the name of the Grave and the line "Risen on <date>", where `<date>` is written by the existing `GraveyardCopy.date` for the Risen_On.
5. WHERE the Grave source is GitHub and the Grave has a repository address, THE Living_Entry SHALL show one Repository_Link with the full repository name.
6. WHEN the user activates the Repository_Link, THE Graveyard_App SHALL copy the repository address to the clipboard and SHALL show the confirmation "Link copied", because the app adds no package that can open an address.
7. THE Repository_Link SHALL have a tap target of at least 48 by 48 logical pixels, a semantic label of the form "Copy the repository link of <name>", keyboard focus, and visible focus, hover and pressed states.
8. WHERE the Grave source is manual, THE Living_Entry SHALL show no Repository_Link.
9. THE Living_Row SHALL list the Living_Entries with the most recent Risen_On first, and for equal Risen_On in the order of `GraveSorter`.
10. THE Living_Row SHALL stay readable and free of overflow with a project name of 80 code points, at the widths and text scales of Requirement 15.
11. WHEN the Graveyard_App has Risen Graves and no Graves left in the Graveyard_Rows, THE Graveyard_Scene SHALL show the Living_Row and, below it, the line "Every grave here has risen." in place of the Graveyard_Rows, and SHALL show no empty graveyard panel.
12. THE Living_Row SHALL have no more than one semantic node per Living_Entry for its text, with the controls of the Living_Entry as its own nodes, and SHALL expose no decorative node.
13. IF copying the repository address to the clipboard fails, THEN THE Graveyard_App SHALL show a short confirmation that the link could not be copied, SHALL throw no exception, and SHALL keep the Living_Entry unchanged.

### Requirement 6: Splitting the graveyard

**User Story:** As a user, I want a risen project to leave the graveyard rows once its moment is over, so that the graveyard only holds the dead.

#### Acceptance Criteria

1. THE Living_Split SHALL return the Graveyard_Rows list and the Living_Row list from the list of Graves and the Playing_Set.
2. THE Living_Split SHALL put a Grave in the Living_Row list exactly when the Grave is Risen and its id is not in the Playing_Set.
3. THE Living_Split SHALL put every other Grave in the Graveyard_Rows list, so that a Risen Grave whose Resurrection_Play is running stays in the Graveyard_Rows until the play ends.
4. FOR ALL lists of Graves and FOR ALL Playing_Sets, every Grave SHALL appear in exactly one of the two lists, and the two lists together SHALL hold the same Graves as the input (partition).
5. FOR ALL lists of Graves with an empty Playing_Set, the Graveyard_Rows list SHALL hold no Risen Grave and the Living_Row list SHALL hold only Risen Graves.
6. THE Living_Split SHALL keep the order of the Graveyard_Rows list equal to the order of the input, and SHALL order the Living_Row list as Requirement 5.9 says.
7. FOR ALL lists of Graves, calling the Living_Split twice with the same arguments SHALL return equal results (determinism).
8. THE Living_Split SHALL never throw, including for an empty list, a Playing_Set with ids that are not in the list and a list with equal Risen_On values.
9. THE Graveyard_Scene SHALL receive only the Graveyard_Rows list, so that `SceneLayout`, the column count and the keys of the Tombstones follow the existing rules of graveyard-scene for that list.
10. WHEN a Grave leaves the Graveyard_Rows at the end of its Resurrection_Play, THE Graveyard_Scene SHALL close the gap with no Rise for the remaining Tombstones.

### Requirement 7: The resurrection animation

**User Story:** As a user, I want the raising to be a short, strong moment, so that bringing a project back feels like an event and not a state change.

#### Acceptance Criteria

1. WHEN a Raise starts a Resurrection_Play, THE Tombstone SHALL play, in this order: the Hand bursts up from the ground at the base of the stone together with the Clods, the Hand sinks back, and the Rising_Ghost rises from the grave while the Epitaph_Text changes.
2. THE Resurrection_Play SHALL last between 2000 and 3000 ms in total, and SHALL play once. The design phase MUST fix one Play_Duration of at least 2600 ms (suggested 2800 ms), so that the 2200 ms rising reaction of the Rising_Ghost fits after the Hand has sunk back.
3. THE Resurrection_Play SHALL be drawn with plain Flutter widgets and `CustomPainter`, with no package, no image, no font and no sound added.
4. THE Hand SHALL be drawn at the base of the stone, in front of the Tombstone, with a path built in code, with soft glows instead of hard shadows and with colors taken from the `CoffinColorTokens` of the active theme.
5. THE Hand_Height SHALL be a pure function of elapsed milliseconds with these properties: it is 0 at 0 ms and at every time from Play_Duration on, it rises while the Hand bursts up, it falls while the Hand sinks back, and it is clamped for negative and very large inputs.
6. THE Hand_Height SHALL use the existing `RiseProgress` ease-in-out cubic curve for its burst and its sink, so that the Hand moves with the same timing language as a rising Tombstone.
7. FOR ALL elapsed milliseconds, the Hand_Height SHALL be a finite number from 0 to 1 inclusive.
8. FOR ALL elapsed milliseconds `a` and `b` inside the burst phase with `a <= b`, the Hand_Height of `a` SHALL be less than or equal to the Hand_Height of `b`, and inside the sink phase it SHALL be greater than or equal (monotonic phases).
9. THE Rising_Ghost SHALL be a `GhostLoader` with `GhostMood.rising` and a `reactionKey` that starts the rising reaction once, when the Hand has sunk back (the start of the Rise_Window), and its rising reaction SHALL complete inside the Play_Duration.
10. THE Rising_Ghost SHALL be placed by the Rising_Ghost_Box, a pure function of the Stone_Area size, the text scale and elapsed milliseconds, and the Rising_Ghost_Box SHALL rise from the base of the stone (its bottom edge on the bottom edge of the Stone_Area) over the Rise_Window to an end position below the Epitaph_Rectangle, using the `RiseProgress` ease-in-out curve, and SHALL hold that final position until the end of the play, with its horizontal center and its size unchanged, and with its rectangle inside the Stone_Area at every time of the play.
11. WHEN the Rising_Ghost_Box has finished rising at the end of the Rise_Window, THE Tombstone SHALL start the epitaph fade, so that the epitaph fade starts after the box has finished rising, and SHALL change the Epitaph_Text from "R.I.P." to "RISEN" with a fade of 300 to 600 ms and an ease-in-out curve, and SHALL keep "RISEN" after the play ends for as long as the Tombstone is in the Graveyard_Rows.
12. THE Resurrection_Play SHALL keep the tilt, the fade and the cracks of the Tombstone from `Weathering` and `CrackGenerator`, and SHALL draw the Hand, the Clods and the Rising_Ghost inside the same tilted layer, so that they sit on the stone as it leans.
13. THE Resurrection_Play SHALL run its ticker for the full Play_Duration, SHALL stop the ticker at the end of the Play_Duration, and SHALL use no loop that keeps running after the Play_Duration, other than the ticks of the Rising_Ghost that end with its reaction.
14. WHEN the Resurrection_Play ends, THE Graveyard_App SHALL remove the Grave id from the Playing_Set, SHALL dispose every animation controller of the play, and SHALL then move the Grave to the Living_Row.
15. IF the Tombstone is disposed during the Resurrection_Play, THEN THE Graveyard_App SHALL dispose every controller of the play, SHALL remove the Grave id from the Playing_Set, and SHALL NOT throw.
16. FOR ALL Stone_Area widths from 120 to 400 and heights from 160 to 480 logical pixels, FOR ALL text scales from 1.0 to 2.0, and FOR ALL elapsed milliseconds `a` and `b` with `a <= b`, the Rising_Ghost_Box_Top at `b` SHALL be less than or equal to the Rising_Ghost_Box_Top at `a` (the box never moves down), the left edge, the width and the height of the Rising_Ghost_Box SHALL be equal at `a` and `b`, and the Rising_Ghost_Box_Top SHALL be equal at every elapsed time from the end of the Rise_Window on (the box holds still after the Rise_Window).
17. THE Rising_Ghost_Box SHALL NOT cover the epitaph. FOR ALL Stone_Area widths from 120 to 400 and heights from 160 to 480 logical pixels, FOR ALL text scales from 1.0 to 2.0, and FOR ALL elapsed milliseconds from the end of the Rise_Window to the Play_Duration, the Rising_Ghost_Box SHALL NOT intersect the Epitaph_Rectangle, which the Graveyard_App SHALL compute from pure Domain code (the Epitaph_Footprint, built on `ArchFit`). At the end of the rise, the Rising_Ghost_Box SHALL sit below the Epitaph_Rectangle with a small gap and inside the Stone_Area. IF the stone is too small for both the Epitaph_Rectangle and the Rising_Ghost_Box at its natural size, THEN THE Rising_Ghost_Box SHALL become smaller and SHALL NOT overlap the Epitaph_Rectangle, and, below a minimum size set in the design phase, THE Rising_Ghost_Box SHALL NOT be drawn while the rest of the Resurrection_Play still runs. The design phase fixes the gap, the minimum size and the metrics of the Epitaph_Footprint.

### Requirement 8: The clods of earth

**User Story:** As a user, I want a few clods of earth to fly when the hand bursts out, so that the ground feels like it really broke.

#### Acceptance Criteria

1. THE Domain SHALL provide a Clod_Path generator that returns, for one Grave id, a list of Clods with a count from 4 to 7, each with a start point at the base of the stone, a launch direction, a flight time within the Play_Duration, a peak height and a size.
2. THE Clod_Path generator SHALL derive every value from the Grave id through `StableHash` and `StableRandom`, with no randomness from the platform, so that the same Grave id gets the same Clods on every run and on every platform.
3. FOR ALL Grave ids, generating the Clods twice SHALL return equal lists (determinism).
4. FOR ALL Grave ids, the Clods SHALL keep each Clod parameter inside its stated bound: the count from 4 to 7, a positive flight time, and a size from 2 to 8 logical pixels.
5. THE Clod_Path SHALL be a pure function of a Clod, the Stone_Area size and the elapsed milliseconds, and SHALL return a finite position and a finite size.
6. FOR ALL Grave ids, FOR ALL Stone_Area widths from 120 to 400 and heights from 160 to 480 logical pixels, and FOR ALL elapsed milliseconds from 0 to the Play_Duration, the Clod_Path SHALL give a position and a size whose whole circle lies inside the Stone_Area.
7. FOR ALL elapsed milliseconds before the launch time of a Clod and after its landing time, THE Clod_Path SHALL report the Clod as not visible.
8. THE Clods SHALL fly in an arc: they rise to their peak height and fall back to the ground at the base of the stone, and SHALL be gone when the Hand has sunk back.
9. THE Clod_Path generator SHALL import only the Domain and the Dart core libraries, and SHALL use integer arithmetic below 2^53 for the hash and the random sequence, so that the values are the same on the Dart VM and on Flutter Web.
10. THE Graveyard_App SHALL draw at most 7 Clods per Resurrection_Play, so that the play stays light on a phone and in a browser.

### Requirement 9: The animation stays on the stone

**User Story:** As a user, I want the show to stay on its own tombstone, so that it never covers the neighbors, the buttons or the text of the screen.

#### Acceptance Criteria

1. THE Resurrection_Play SHALL draw nothing outside the Stone_Area, that is the Hand, the Clods, the Rising_Ghost and every glow of them.
2. THE painter of the Hand and the Clods SHALL clip its canvas to the Stone_Area, and the geometry of the Hand and the Clods SHALL lie inside the Stone_Area before the clip is applied.
3. THE Hand_Geometry SHALL be a pure function of the Stone_Area size and the elapsed milliseconds, built on the Hand_Height, and every point of the Hand SHALL lie inside the Stone_Area at every elapsed time.
4. FOR ALL Stone_Area widths from 120 to 400 and heights from 160 to 480 logical pixels, and FOR ALL elapsed milliseconds from 0 to the Play_Duration, every point returned by the Hand_Geometry and every circle returned by the Clod_Path SHALL lie inside the Stone_Area, and, FOR ALL text scales from 1.0 to 2.0 as well, the rectangle returned by the Rising_Ghost_Box SHALL lie inside the Stone_Area.
5. THE Resurrection_Play SHALL leave the Seance_Control, the delete control, the neighbor Tombstones and the Living_Row unmoved and uncovered, and SHALL NOT change the layout size of the Tombstone at any time of the play.
6. THE Resurrection_Play SHALL NOT take pointer events away from the controls of the Graveyard_Scene, and SHALL be wrapped in `IgnorePointer`.
7. THE Resurrection_Play SHALL stay inside the Stone_Area while the Tombstone is tilted by `Weathering`, at the largest tilt of 3 degrees.
8. THE Resurrection_Play SHALL use a `RepaintBoundary`, so that its repaints do not repaint the rest of the Graveyard_Scene.

### Requirement 10: Plays once, never on reload

**User Story:** As a user, I want the resurrection to play only when I raise a project, so that opening the app never replays the show.

#### Acceptance Criteria

1. THE Graveyard_App SHALL start a Resurrection_Play only in answer to a Raise from the Raise_Control.
2. THE Graveyard_App SHALL keep the Playing_Set in memory only, and SHALL NOT write the Playing_Set, the play progress or any animation data to storage.
3. WHEN the Graveyard_App loads or reloads, THE Graveyard_App SHALL start no Resurrection_Play, including for a Grave that was Risen when the app closed.
4. WHEN the user lays a Grave back to rest and raises it again, THE Graveyard_App SHALL play one new Resurrection_Play for that Raise.
5. WHILE a Resurrection_Play is running on a Tombstone, THE Graveyard_App SHALL start no second play on the same Tombstone.
6. WHILE a Resurrection_Play is running on a Tombstone, THE Tombstone SHALL keep its Seance_Control and its delete control present, and the Seance_Control SHALL open no Seance_Sheet that offers a Raise_Control.
7. IF the user deletes a Grave during its Resurrection_Play, THEN THE Graveyard_App SHALL stop the play, SHALL dispose its controllers and SHALL throw no exception.
8. IF the screen is rebuilt during a Resurrection_Play (a new list, a new width or a changed text scale), THEN THE Graveyard_App SHALL keep the play running from its current progress without restarting it.
9. THE Graveyard_App SHALL run at most one Resurrection_Play per Grave at a time, and the Resurrection_Plays of different Graves SHALL NOT disturb each other.

### Requirement 11: The epitaph changes to RISEN

**User Story:** As a user, I want the stone itself to change from "R.I.P." to "RISEN", so that the proof of the raising is carved in the stone.

#### Acceptance Criteria

1. THE Tombstone SHALL show the Epitaph_Text "R.I.P." for every Grave that is not Risen and not in the Playing_Set.
2. THE Tombstone of a Grave in the Playing_Set SHALL show the Epitaph_Text "R.I.P." at the start of the play and "RISEN" after the change of Requirement 7.11.
3. THE Tombstone SHALL route the Epitaph_Text through `ArchEpitaph.text`, SHALL keep `showEpitaph: false` on its `TombstoneCard` so that the `epitaph` setting of `TombstoneCard` is not used, and SHALL hold the Epitaph_Text strings once in `GraveyardCopy`.
4. THE `ArchEpitaph` SHALL place the Epitaph_Text with the existing `ArchFit` search, SHALL measure it at the scaled font size, and SHALL keep it inside the half-ellipse arch of the stone on one line at every text scale up to 2.0.
5. THE `ArchEpitaph.rectFor` SHALL measure the same Epitaph_Text that `ArchEpitaph` draws, so that the keep-out area of the cracks follows the text.
6. FOR ALL widths of the Stone_Area from 120 to 400 logical pixels, the word "RISEN" SHALL fit inside the arch as `ArchFit` defines it, at the default text scale.
7. THE Tombstone SHALL keep its semantic label as it is, and SHALL expose the epitaph change only through the Risen_Announcement of Requirement 12.
8. THE `ArchEpitaph` SHALL keep drawing "R.I.P." when no Epitaph_Text is passed, so that every existing test of graveyard-scene passes unchanged.

### Requirement 12: Reduced motion and announcement

**User Story:** As a user who turns motion off, I want the same result without any movement, and as a screen reader user I want to hear that the project has risen.

#### Acceptance Criteria

1. WHILE Reduced_Motion is true, THE Resurrection_Play SHALL draw no Hand, no Clods, no moving Rising_Ghost and no fade, and SHALL create no animation controller that ticks.
2. WHILE Reduced_Motion is true, WHEN a Raise happens, THE Tombstone SHALL show its risen state at once, that is the Epitaph_Text "RISEN" on a still stone.
3. WHILE Reduced_Motion is true, THE Graveyard_App SHALL keep the still risen Tombstone in the Graveyard_Rows for the Play_Duration and SHALL then move the Grave to the Living_Row, so that the user sees the result of the Raise before it moves.
4. WHEN a Raise happens, THE Graveyard_App SHALL expose one Risen_Announcement as a polite live region with the text "<name> has risen.", once per Raise, with or without Reduced_Motion.
5. THE Risen_Announcement SHALL NOT move keyboard focus and SHALL NOT repeat when the screen rebuilds or when the Grave moves to the Living_Row.
6. WHEN the Grave moves to the Living_Row, THE Graveyard_App SHALL NOT announce a second message for the move.
7. THE Resurrection_Play SHALL expose no semantic node for the Hand, the Clods, the glows or the Rising_Ghost graphic, and the Rising_Ghost SHALL be wrapped so that its own loader label is not read.
8. WHEN Reduced_Motion changes from false to true during a Resurrection_Play, THE Graveyard_App SHALL stop the movement, show the risen state at once, and finish the play without a second Risen_Announcement.

### Requirement 13: Accessibility of the new controls

**User Story:** As a keyboard or screen reader user, I want the whole flow of raising and laying to rest to work without a mouse and without sight.

#### Acceptance Criteria

1. THE Raise_Control, the Lay_To_Rest_Control, the Repository_Link, the confirm button and the cancel button of the Rest_Dialog SHALL each have a tap target of at least 48 by 48 logical pixels and a semantic label.
2. WHEN the Rest_Dialog opens, THE Graveyard_App SHALL move focus into the dialog, and WHILE it is open, SHALL keep keyboard focus inside the dialog.
3. THE Rest_Dialog SHALL expose a route name that includes the Grave name, in the form "Lay <name> back to rest?".
4. THE Living_Row, the Living_Entry text and the Rest_Dialog SHALL keep every text and icon at a contrast ratio of at least 4.5 for text and at least 3.0 for icons against the color directly behind it, in the dark theme and in the daylight theme, computed with `WcagContrast.ratio`.
5. THE Hand, the Clods and the Rising_Ghost SHALL keep a contrast ratio of at least 3.0 against the stone and the ground where they overlap, in the dark theme and in the daylight theme, so that the Hand reads as a Hand in both themes.
6. THE Living_Row and the Rest_Dialog SHALL stay usable at a text scale of 2.0, with text wrapping or scrolling and no clipped text.
7. THE Graveyard_App SHALL take every color of this feature from the `CoffinColorTokens` of the active theme, with no hard-coded color.

### Requirement 14: Copy tone

**User Story:** As a user, I want the new words to be short, kind and a little triumphant, so that the app stays haunted and never mean.

#### Acceptance Criteria

1. THE Resurrection_Copy SHALL be held in `GraveyardCopy`, and no screen, painter or widget of this feature SHALL hold a user-facing string of its own.
2. THE Resurrection_Copy SHALL include at least: "Raise it", the Raise_Control semantic label, "RISEN", "Back among the living", "Risen on <date>", "Lay it back to rest", the Lay_To_Rest semantic label, the Rest_Dialog title, body, confirm and cancel texts, the Repository_Link label, "Link copied", the copy-failure message "That link would not copy. Try once more." (Requirement 5.13), the line "Every grave here has risen." (Requirement 5.11) and the Risen_Announcement.
3. THE Resurrection_Copy SHALL use only Allowed_Characters, and SHALL contain no emoji.
4. THE Resurrection_Copy SHALL contain no word that names a time of day, such as "morning", "afternoon", "evening", "night", "midnight", "dawn" or "dusk".
5. THE Resurrection_Copy SHALL NOT contain the words "failed", "invalid" or "your fault", and SHALL contain no exception text and no raw status code.
6. THE Resurrection_Copy SHALL be kind and a little triumphant, and SHALL NOT shame the user for abandoning the project or for laying it back to rest.
7. THE Rest_Dialog body SHALL say that the project goes back to the graveyard, and SHALL NOT say that anything is deleted.
8. THE Graveyard_App SHALL keep every existing string of `GraveyardCopy` as it is, including `GraveyardCopy.epitaph` with the value "R.I.P.".

### Requirement 15: Layout on phone and web

**User Story:** As a user on a phone or in a browser, I want the new controls and the show to fit my screen, so that nothing is cut off.

#### Acceptance Criteria

1. THE Raise_Control, the Living_Row, the Rest_Dialog and the Resurrection_Play SHALL render without an overflow exception at widths of 320, 360, 768 and 1280 logical pixels, at the default text scale and at a text scale of 1.5.
2. THE Seance_Sheet with the Raise_Control SHALL keep its maximum content width of 560 logical pixels, its scrolling and its pinned close button.
3. THE Living_Row SHALL use the same side padding and maximum width as the rest of the header of the Graveyard_Scene.
4. THE Tombstone SHALL keep the layout rules of graveyard-scene: the Scene_Layout column count, the tombstone width and the 3 degree tilt limit SHALL NOT change.
5. THE Graveyard_App SHALL run on Flutter Web and on Android and iOS screen sizes with the same behavior.
6. WHILE the Living_Row is long, THE Graveyard_Scene SHALL scroll it together with the rest of the header, and SHALL NOT trap the scroll position.

### Requirement 16: Architecture and boundaries

**User Story:** As a maintainer, I want the pure rules in the Domain and the skeleton untouched, so that the logic is easy to test and `coffin_core` stays reusable.

#### Acceptance Criteria

1. THE risen-state rules (Raise and Lay_To_Rest), the Hand_Height, the Hand_Geometry, the Epitaph_Footprint, the Rising_Ghost_Box, the Clod_Path generator, the Clod_Path function and the Living_Split SHALL live in `apps/graveyard/lib/src/domain`, with one public class per file in `snake_case.dart` and a doc comment on every public API.
2. THE new Domain files SHALL import no Flutter library, no `dart:ui`, no `dart:io`, no `dart:html`, no `package:coffin_core`, no networking package and no storage package, and SHALL NOT call `DateTime.now()`.
3. THE Graveyard_App SHALL import `coffin_core` only through `package:coffin_core/coffin_core.dart`, never a file under `coffin_core/lib/src`.
4. THE Graveyard_App SHALL NOT import Hauntagotchi, and `coffin_core` SHALL NOT import Graveyard.
5. THE Graveyard_App SHALL use no state-management package, and SHALL use `ChangeNotifier` with `ListenableBuilder` or plain `StatefulWidget` state.
6. THE Graveyard_App SHALL reuse `RiseProgress`, `Weathering`, `ArchFit`, `StableHash`, `StableRandom`, `GraveyardCopy.date` and the existing write queue of `GraveListController` where they fit, and SHALL NOT copy their logic.
7. THE Graveyard_App SHALL pass `dart format` and `flutter analyze` with zero warnings.
8. THE Graveyard_App SHALL keep every behavior of graveyard-core, graveyard-scene and graveyard-seance that this feature does not name.
9. THE diff of this feature SHALL leave `packages/coffin_core`, `apps/hauntagotchi`, `tool/`, every `pubspec.yaml` and `pubspec.lock` unchanged.

### Requirement 17: Tests

**User Story:** As a maintainer, I want the rules covered by unit and property tests, so that the raising cannot silently go wrong.

#### Acceptance Criteria

1. THE test suite SHALL include a unit test for every piece of pure logic of this feature: the Raise, the Lay_To_Rest, the Hand_Height, the Hand_Geometry, the Epitaph_Footprint, the Rising_Ghost_Box, the Clod_Path generator, the Clod_Path function and the Living_Split. The Epitaph_Footprint unit tests SHALL include a constants test (its arch rise, base font size and letter spacing equal those of `ArchEpitaph`), a cover test (for stone widths from 120 to 400 and text scales from 1.0 to 2.0, the Epitaph_Rectangle covers the rectangle of `ArchEpitaph.rectFor` for "R.I.P." and for "RISEN"), and an equality test against `ArchFit` (a rectangle built from `ArchFit.positionFor` with the same text metrics has the same top and font size).
2. THE test suite SHALL include glados property tests with at least 200 runs each, one per design property, named and numbered as in design.md: Property 1, raise then Lay_To_Rest returns the original Grave (2.7); Property 2, raising twice equals raising once (2.8); Property 3, Lay_To_Rest is idempotent (2.9); Property 4, Raise and Lay_To_Rest keep every other field (2.10, 2.12); Property 5, the codec round trip with and without the Risen_On (3.3); Property 6, legacy records decode as not risen (3.4); Property 7, a malformed risen value is rejected with `FormatException` (3.5, 3.6); Property 8, the Living_Split is a partition (6.4); Property 9, the Living_Split never throws and is deterministic (6.7, 6.8); Property 10, the Hand_Height is in 0 to 1 and monotonic per phase (7.7, 7.8); Property 11, the Clods are deterministic for the same Grave id (8.2, 8.3); Property 12, the Clods stay inside their bounds (8.4); Property 13, the Clod_Path stays inside the Stone_Area (8.6, 9.4); Property 14, the Clods are not visible outside their flight window (8.7); Property 15, the Hand_Geometry, as a pure function, keeps every point of the Hand inside the Stone_Area (9.3, 9.4); Property 16, the Rising_Ghost box stays inside the Stone_Area, also over text scales from 1.0 to 2.0 (7.10, 9.4); Property 17, the Rising_Ghost box rises and then holds still (7.10, 7.16, 7.17); and Property 18, the Rising_Ghost box never covers the epitaph (7.17).
3. THE test suite SHALL treat every test task of this feature as required, and no test task SHALL be marked optional.
4. THE property tests SHALL use only Web_Safe_Generators, a run counter that asserts the number of runs, and the comment header `// Feature: graveyard-resurrection, Property N: <title>` with `// Validates: Requirements ...`.
5. THE test suite SHALL include a unit test of the codec for the exact encoded map of a Risen Grave and of a Grave that is not Risen, and for each kind of malformed risen value, without any edit to an existing codec or storage test.
6. THE test suite SHALL include a test with a painter driven by a recording canvas (`test/support/recording_canvas.dart` or a new support file) that checks that the Hand and the Clods draw only inside the Stone_Area, and that the canvas is clipped to it.
7. THE test suite SHALL include widget tests with `FakeClock`, `MemoryRecordRepository<Grave>` and a fake `CoffinAI`, for: the Raise_Control in the Seance_Sheet; raising closes the sheet, saves the Risen_On and starts one play; the Epitaph_Text changes from "R.I.P." to "RISEN" during the play; the Grave moves to the Living_Row when the play ends; no play on load of a saved Risen Grave; no replay after a rebuild; the Lay_To_Rest with confirm and with cancel; the Repository_Link copy; the Repository_Link copy failure (a clipboard that throws shows "That link would not copy. Try once more.", throws no exception and leaves the Living_Entry unchanged); the line "Every grave here has risen." when every Grave is Risen; the empty Living_Row not shown; delete and disposal during a play; and Reduced_Motion with no ticking controller, the still risen state and exactly one Risen_Announcement.
8. THE test suite SHALL include a widget test with `pumpAndSettle`-safe timing, so that it ends within the Play_Duration with a fake clock and no real delay.
9. THE test suite SHALL include a layout test with no overflow at the widths and text scales of Requirement 15, in the dark theme and in the daylight theme.
10. THE test suite SHALL include a semantics test for the labels of Requirements 1, 4, 5, 12 and 13, and a contrast test with `WcagContrast.ratio` for Requirement 13.
11. THE test suite SHALL include a source-rule test under `test/source_rules/` that checks the Domain import rules of Requirement 16 for the new Domain files, that no file of this feature writes animation data to storage, and that no file under `lib/` adds an import of a package outside the existing dependencies.
12. THE test suite SHALL include a copy test that checks Requirement 14 for every Resurrection_Copy string.
13. THE test suite SHALL include a check that `ArchEpitaph` without an Epitaph_Text still draws "R.I.P.", and that every existing test file passes unchanged.
14. THE test suite SHALL use no real clock, no real Hive, no network, no file outside the repository and no `/tmp`, and SHALL NOT depend on the time zone of the machine.
15. THE Graveyard_App SHALL pass `flutter test` in `apps/graveyard`, and `flutter test --platform chrome test/domain test/data` for the Domain and data tests, before any task of this feature is marked done.
