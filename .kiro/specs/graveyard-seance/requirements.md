# Requirements Document

## Introduction

The graveyard-seance feature lets the user hold a séance for any Grave in `apps/graveyard`. The séance judges whether the abandoned project could come back to life. It gives a Revival_Score from 0 to 100 with a word band, three concrete Revival_Steps, and one spooky Verdict_Line. This is what makes Graveyard more than a list of tombstones.

Each Tombstone gets a "Hold a séance" control. The result opens in a Seance_Sheet over the Graveyard_Scene. The score and the steps come from pure Dart rules in `lib/src/domain` and read only the facts that a Grave already holds: how long it has been dead, whether it is archived, its star count, whether it has a description, and whether it was buried by hand or imported from GitHub. The Verdict_Line comes from the existing `CoffinAI` interface of `coffin_core` with `AiPurpose.seanceVerdict`, through `FallbackCoffinAI` over `OfflineCoffinAI`. It works offline, needs no network and no key, and never blocks the score or the steps.

The result is not stored. It is recomputed each time the sheet opens. The resurrection animation is a separate, later feature and is out of scope here.

This feature builds on graveyard-core (the `Grave` model, `DeadFor`, `CalendarDate`, `Clock`, the controller) and graveyard-scene (`GraveTombstone`, `GraveyardScene`, `GraveyardCopy`, `StableHash`, `DescriptionCleaner`). It follows the design language "Haunted, not horror": slow and floaty motion of 300 to 600 ms, 16 px corners, soft glows, tap targets of at least 48 by 48 logical pixels, and short, witty, never mean copy.

`coffin_core` already provides `CoffinAI`, `AiRequest`, `AiReply`, `AiPurpose.seanceVerdict`, `AiFactKeys.projectName`, `AiFactKeys.daysSinceLastCommit`, `FallbackCoffinAI` and `OfflineCoffinAI`. Because `coffin_core` stays unchanged, everything else is built in `apps/graveyard`. Exact weights, thresholds, step texts, sizes and timings that are not stated here belong to the design phase, within the bounds stated here.

## Dependency Notice

No dependency changes:

- No package is added to `apps/graveyard/pubspec.yaml`, and `pubspec.lock` stays byte-for-byte unchanged.
- No font, image, sound or other asset is added, and `CREDITS.md` stays unchanged.
- No network call is made by this feature. No API key, token or secret appears in the app, the tests or the repository.
- Only `apps/graveyard/lib`, `apps/graveyard/test` and `.kiro/specs/graveyard-seance` change. `packages/coffin_core`, `apps/hauntagotchi` and `tool/` stay unchanged. No file is created outside the repository, including `/tmp`.

## Glossary

- **Graveyard_App**: The Flutter app in `apps/graveyard`.
- **Domain**: The pure Dart code in `apps/graveyard/lib/src/domain`. It imports no Flutter library, no `dart:ui`, no `dart:io`, no `dart:html`, no networking package and no storage package, and never calls `DateTime.now()`.
- **Grave**: The existing `Grave` model of the Domain, with `id`, `name`, `dateOfDeath`, `source` and `repo`.
- **Tombstone**: One Grave drawn by `GraveTombstone` in the Graveyard_Scene, with its delete control.
- **Graveyard_Scene**: The existing `GraveyardScene` widget that paints the sky and the ground and places the Tombstones.
- **Today**: The current `CalendarDate`, read through the existing `Clock` outside the Domain and passed into the Domain as an input.
- **Day_Count**: The number of calendar days from the date of death to Today, from `DeadFor`. A date of death on or after Today gives 0.
- **Seance_Facts**: The facts the séance rules read: the Day_Count, whether the Grave is archived, the star count, whether the cleaned description is non-empty, and the Grave source (manual or GitHub). A manual Grave counts as not archived, with 0 stars and no description.
- **Seance_Rules**: The pure Domain function from a Grave and Today to a Seance_Result without verdict.
- **Revival_Score**: An integer from 0 to 100 computed by the Seance_Rules.
- **Revival_Band**: The word band of a Revival_Score, one of "Restless" (0 to 39), "Stirring" (40 to 69) and "Ready to rise" (70 to 100).
- **Revival_Step**: One short instruction that tells the user how to bring the project back. The Domain chooses it as a `RevivalStepKind` value, and the text of the instruction is the text that `GraveyardCopy` provides for that kind through `GraveyardCopy.revivalStepText`.
- **Revival_Steps**: The list of exactly three distinct `RevivalStepKind` values for one Grave.
- **Repository_Only_Step**: A `RevivalStepKind` that only makes sense for a Grave with a repository: `forkRepository` and `skimReadme`.
- **Verdict_Line**: One short spooky sentence about the project, from `CoffinAI`, or the Safe_Verdict_Line.
- **Safe_Verdict_Line**: A fixed line held in `GraveyardCopy`, shown when the Verdict_Line is not available.
- **Seance_Result**: The Revival_Score, the Revival_Band and the Revival_Steps of one Grave on one Today.
- **Seance_Control**: The "Hold a séance" button on a Tombstone.
- **Seance_Sheet**: The modal bottom sheet that shows the Seance_Result and the Verdict_Line.
- **Seance_Ai**: The `CoffinAI` that the Graveyard_App uses for the Verdict_Line: a `FallbackCoffinAI` whose primary and secondary are `OfflineCoffinAI`.
- **Verdict_Wait_Limit**: The longest time the Seance_Sheet waits for the Verdict_Line before it shows the Safe_Verdict_Line. It is set in the design phase and is at most 3 seconds.
- **Reveal**: The one-time fade-in of the Seance_Result when the Seance_Sheet opens.
- **Reduced_Motion**: The state in which `MediaQuery.disableAnimations` is true.
- **Seance_Copy**: Every user-facing string of this feature, held in `GraveyardCopy`.
- **Allowed_Characters**: Printable ASCII (U+0020 to U+007E), the letter "é" (U+00E9) in the word "séance", and the ellipsis "…" (U+2026).
- **Web_Safe_Generator**: A glados generator that avoids `any.int`, `any.intInRange`, `any.list`, `any.listWithLengthInRange`, string generators and `uint*`, which throw or differ on Flutter Web in glados 1.1.7. It is built on `anyIntBetween` and `anyListBetween` from `test/domain/support/grave_generators.dart` and keeps every generated integer below 2^53.

## Requirements

### Requirement 1: Hold a séance from a tombstone

**User Story:** As a user, I want a "Hold a séance" control on each tombstone, so that I can ask whether a dead project could rise again.

#### Acceptance Criteria

1. THE Tombstone SHALL show one Seance_Control with the visible label "Hold a séance".
2. THE Seance_Control SHALL have a tap target of at least 48 by 48 logical pixels.
3. THE Seance_Control SHALL have a semantic label that names the Grave, in the form "Hold a séance for <name>".
4. THE Seance_Control SHALL be reachable by keyboard focus, and SHALL activate on Enter and Space.
5. THE Seance_Control SHALL show a visible focus state, a hover state and a pressed state.
6. THE Seance_Control SHALL lie outside the stone area and SHALL NOT overlap the delete control or any text of the Tombstone.
7. WHEN the user activates the Seance_Control of a Grave, THE Graveyard_App SHALL open the Seance_Sheet for that Grave.
8. WHILE a Seance_Sheet is open, THE Graveyard_App SHALL open no second Seance_Sheet.

### Requirement 2: Revival score

**User Story:** As a user, I want a revival score from 0 to 100, so that I can see at a glance how alive a dead project still is.

#### Acceptance Criteria

1. THE Seance_Rules SHALL compute the Revival_Score as an integer from 0 to 100 inclusive.
2. THE Seance_Rules SHALL read only the Seance_Facts and Today, and SHALL NOT read the Grave id, the Grave name or any other field.
3. THE Seance_Rules SHALL receive Today as an argument, and SHALL NOT read the clock.
4. FOR ALL Graves and FOR ALL values of Today, calling the Seance_Rules twice with the same arguments SHALL return equal Seance_Results (determinism).
5. FOR ALL Seance_Facts, a Grave with a larger Day_Count and every other fact equal SHALL have a Revival_Score that is less than or equal to the Revival_Score of the Grave with the smaller Day_Count.
6. FOR ALL Seance_Facts, an archived Grave SHALL have a Revival_Score that is less than or equal to the Revival_Score of the same Grave when not archived.
7. FOR ALL Seance_Facts, a Grave with more stars and every other fact equal SHALL have a Revival_Score that is greater than or equal to that of the Grave with fewer stars.
8. FOR ALL Seance_Facts, a Grave with a non-empty cleaned description and every other fact equal SHALL have a Revival_Score that is greater than or equal to that of the Grave with no description.
9. WHEN the date of death is on or after Today, THE Seance_Rules SHALL treat the Day_Count as 0 and SHALL return a valid Revival_Score.
10. THE Seance_Rules SHALL never throw for any Grave and any Today.
11. THE Seance_Rules SHALL use only integer arithmetic below 2^53, so that the Revival_Score is the same on the Dart VM and on Flutter Web.

### Requirement 3: Word band

**User Story:** As a user, I want a word next to the number, so that I understand the score without reading a chart or telling colors apart.

#### Acceptance Criteria

1. THE Seance_Rules SHALL map a Revival_Score from 0 to 39 to the Revival_Band "Restless", from 40 to 69 to "Stirring", and from 70 to 100 to "Ready to rise".
2. FOR ALL Revival_Scores from 0 to 100, THE Seance_Rules SHALL return exactly one Revival_Band.
3. FOR ALL Revival_Scores, a higher score SHALL NOT map to a lower Revival_Band (monotonic).
4. THE Seance_Sheet SHALL show the Revival_Score as a number and the Revival_Band as a word, in text.
5. THE Seance_Sheet SHALL NOT use color, a gauge or an icon as the only way to show the Revival_Score or the Revival_Band.

### Requirement 4: Three revival steps

**User Story:** As a user, I want three concrete steps, so that I know where to start if I want to bring the project back.

#### Acceptance Criteria

1. THE Seance_Rules SHALL return exactly three Revival_Steps, each a `RevivalStepKind` value, for every Grave and every Today.
2. THE three `RevivalStepKind` values of one Seance_Result SHALL be distinct.
3. THE Seance_Rules SHALL choose the `RevivalStepKind` values from the Seance_Facts and Today only, with no randomness.
4. WHEN the Grave is archived and its source is GitHub, THE Seance_Rules SHALL include a step that suggests forking the repository.
5. WHEN the Day_Count is greater than 365, THE Seance_Rules SHALL include a step that suggests updating dependencies first.
6. WHEN the Grave source is manual, THE Seance_Rules SHALL include a step that suggests writing down what the project was meant to do.
7. WHEN fewer than three steps are chosen by the conditions above, THE Seance_Rules SHALL fill the remaining places from a fixed list of general steps, in a fixed order, skipping every repository-only step when the Grave source is manual, so that the result always has three distinct steps.
8. WHEN more than three conditions apply, THE Seance_Rules SHALL keep the three of highest priority, with the priority order set in the design phase.
9. FOR ALL Seance_Facts, every Revival_Step SHALL fit on one line at a width of 320 logical pixels at the default text scale, which the design phase SHALL turn into a maximum length in characters.
10. THE Revival_Steps SHALL be kind and concrete, and SHALL NOT shame the user for abandoning the project.
11. WHEN the Grave source is manual, THE Seance_Rules SHALL NOT include a repository-only step, that is the step that suggests forking the repository or the step that suggests skimming the README of the repository, even when the Seance_Facts say the Grave is archived. The steps that suggest updating dependencies and writing down the purpose are not repository-only.

### Requirement 5: Verdict line from CoffinAI

**User Story:** As a user, I want one spooky line about my project, so that the séance feels like a ritual and not a spreadsheet.

#### Acceptance Criteria

1. WHEN the Seance_Sheet opens, THE Graveyard_App SHALL ask the Seance_Ai once for a Verdict_Line, with an `AiRequest` whose purpose is `AiPurpose.seanceVerdict`.
2. THE `AiRequest` SHALL hold exactly two facts: `AiFactKeys.projectName` with the name of the Grave, and `AiFactKeys.daysSinceLastCommit` with the Day_Count.
3. THE `AiRequest` SHALL use a `maxLength` of at least 16 and at most 140, and a seed from 0 to `AiRequest.maxSeed` that is derived from the Grave id with `StableHash`, so that the same Grave on the same day gets the same line.
4. THE Seance_Ai SHALL be a `FallbackCoffinAI` whose primary and secondary are `OfflineCoffinAI`, with a timeout greater than zero and less than or equal to the Verdict_Wait_Limit.
5. THE Graveyard_App SHALL make no network call and use no API key to get the Verdict_Line.
6. THE Graveyard_App SHALL receive the Seance_Ai through its constructor or the app wiring, so that tests can supply a fake `CoffinAI`.
7. WHEN the Seance_Ai returns a reply, THE Seance_Sheet SHALL show the text of the reply as the Verdict_Line.
8. IF the Seance_Ai completes with an error, THEN THE Seance_Sheet SHALL show the Safe_Verdict_Line.
9. IF the Seance_Ai does not complete within the Verdict_Wait_Limit, THEN THE Seance_Sheet SHALL show the Safe_Verdict_Line.
10. IF the Seance_Sheet is closed before the Seance_Ai completes, THEN THE Graveyard_App SHALL drop the late reply and SHALL NOT update a disposed widget or throw.
11. THE Graveyard_App SHALL NOT change `packages/coffin_core`.

### Requirement 6: Score and steps never wait for the verdict

**User Story:** As a user, I want the score and the steps right away, so that a slow or broken verdict never leaves me staring at a blank sheet.

#### Acceptance Criteria

1. WHEN the Seance_Sheet opens, THE Seance_Sheet SHALL show the Revival_Score, the Revival_Band and the three Revival_Steps in the first frame, without waiting for the Seance_Ai.
2. WHILE the Verdict_Line is pending, THE Seance_Sheet SHALL show a ghost loader with a short caption in the place of the Verdict_Line, and SHALL keep the score and the steps visible and readable.
3. WHEN the Verdict_Line arrives, THE Seance_Sheet SHALL replace the loader with the line and SHALL NOT move the score or the steps.
4. IF the Seance_Ai fails or times out, THEN THE Seance_Sheet SHALL show the Safe_Verdict_Line with no error text, no error icon and no retry control, and the score and the steps SHALL stay unchanged.
5. THE Seance_Sheet SHALL always show a close control, in every state, including while the Verdict_Line is pending.

### Requirement 7: The result is not stored

**User Story:** As a user, I want a fresh séance each time, so that the verdict reflects today and nothing stale is kept on my device.

#### Acceptance Criteria

1. THE Graveyard_App SHALL compute the Seance_Result each time the Seance_Sheet opens, from the Grave and Today.
2. THE Graveyard_App SHALL NOT write the Seance_Result, the Verdict_Line or any séance data to storage, and SHALL NOT change the storage format of the Grave.
3. THE Graveyard_App SHALL NOT change the Grave, its id, its date of death, the sort order or the saved state when a séance is held.
4. WHEN the same Grave is opened again on the same Today, THE Seance_Sheet SHALL show the same Revival_Score, Revival_Band and Revival_Steps.

### Requirement 8: Seance sheet and reveal

**User Story:** As a user, I want the result to appear calmly over the graveyard, so that the séance feels special without getting in my way.

#### Acceptance Criteria

1. THE Seance_Sheet SHALL be a modal bottom sheet over the Graveyard_Scene, with scroll control, safe-area padding and a maximum content width of 560 logical pixels centered on wide screens.
2. THE Seance_Sheet SHALL show, in this order: the Grave name, the Revival_Score and the Revival_Band, the three Revival_Steps as a numbered list, and the Verdict_Line area.
3. WHILE motion is allowed, THE Seance_Sheet SHALL play one Reveal of the Seance_Result that fades it in, with a duration from 300 to 600 ms and an ease-in-out curve, once per opening.
4. WHILE Reduced_Motion is true, THE Seance_Sheet SHALL show the Seance_Result at once with no Reveal and no looping effect.
5. THE Seance_Sheet SHALL use 16 px corners and soft glows, and SHALL take its colors from the `CoffinColorTokens` of the active theme, with no hard-coded color.
6. THE Seance_Sheet SHALL use no loop that keeps running after the Reveal, except the ghost loader while the Verdict_Line is pending.
7. WHEN the Seance_Sheet closes, THE Graveyard_App SHALL dispose the Reveal controller, and SHALL NOT throw if the sheet closes during the Reveal.
8. IF the Seance_Sheet is open WHILE the Grave is removed from the list, THEN THE Graveyard_App SHALL keep showing the sheet for the Grave it was opened with until the user closes it.

### Requirement 9: Closing, focus and keyboard

**User Story:** As a keyboard or screen reader user, I want to open and close the sheet without getting lost, so that the séance has no dead end.

#### Acceptance Criteria

1. THE Seance_Sheet SHALL show a close button with a tap target of at least 48 by 48 logical pixels and the semantic label "Close séance".
2. WHEN the user taps the close button, presses Escape, taps outside the sheet or drags the sheet down, THE Seance_Sheet SHALL close.
3. WHEN the Seance_Sheet opens, THE Graveyard_App SHALL move focus into the sheet, to the close button or to the title.
4. WHEN the Seance_Sheet closes, THE Graveyard_App SHALL return focus to the Seance_Control that opened it, WHERE that control is still in the tree.
5. WHILE the Seance_Sheet is open, THE Graveyard_App SHALL keep keyboard focus inside the sheet.
6. WHEN the Seance_Sheet closes, THE Graveyard_Scene SHALL keep its scroll position and its Tombstones unchanged.

### Requirement 10: Accessibility of the result

**User Story:** As a screen reader user, I want the score, the band and the steps read out clearly, so that I get the same ritual as everyone else.

#### Acceptance Criteria

1. THE Seance_Sheet SHALL expose one semantic node for the result with a label of the form "Revival score <n> out of 100, <band>", where `<n>` and `<band>` are the real values.
2. THE Seance_Sheet SHALL expose each Revival_Step as its own semantic node with its position, in the form "Step <k> of 3: <text>".
3. THE Seance_Sheet SHALL expose the Verdict_Line as a live region, so that the arrival of the line is announced once without moving focus.
4. THE Seance_Sheet SHALL label the sheet with a route name that includes the Grave name, in the form "Séance for <name>".
5. THE Seance_Sheet SHALL expose no semantic node for decorative glows, the ghost loader graphic or the Reveal effect.
6. THE Seance_Sheet SHALL keep every text and icon at a contrast ratio of at least 4.5 for text and at least 3.0 for icons against the color directly behind it, in the dark theme and in the daylight theme, computed with `WcagContrast.ratio`.
7. THE Seance_Sheet SHALL stay usable at a text scale of 2.0, with text wrapping or scrolling and no clipped text.

### Requirement 11: Layout on phone and web

**User Story:** As a user on a phone or in a browser, I want the sheet and the control to fit my screen, so that nothing is cut off.

#### Acceptance Criteria

1. THE Seance_Sheet and the Seance_Control SHALL render without an overflow exception at widths of 320, 360, 768 and 1280 logical pixels, at the default text scale and at a text scale of 1.5.
2. THE Seance_Sheet SHALL scroll vertically WHEN its content is taller than the available height, with the close button staying reachable.
3. THE Tombstone with its Seance_Control SHALL keep the layout rules of graveyard-scene: the Scene_Layout column count, the tombstone width and the 3 degree tilt limit SHALL NOT change.
4. THE Seance_Control SHALL NOT change the height math of the Crack_Band, the Epitaph or the Keep_Out_Areas of the stone.
5. THE Graveyard_App SHALL run on Flutter Web and on Android and iOS screen sizes with the same behavior.

### Requirement 12: Copy tone

**User Story:** As a user, I want the séance to speak with a short, witty, kind voice, so that the app stays haunted and never mean.

#### Acceptance Criteria

1. THE Seance_Copy SHALL be held in `GraveyardCopy`, and no screen or widget of this feature SHALL hold a user-facing string of its own.
2. THE Seance_Copy SHALL use only Allowed_Characters, and SHALL contain no emoji.
3. THE Seance_Copy SHALL contain no word that names a time of day, such as "morning", "afternoon", "evening", "night", "midnight", "dawn" or "dusk".
4. THE Seance_Copy SHALL NOT contain the words "failed", "invalid" or "your fault", and SHALL contain no exception text and no raw status code.
5. THE Safe_Verdict_Line SHALL be one sentence of at most 140 characters that makes sense for every Grave, and SHALL NOT contain the Grave name.
6. THE Revival_Steps SHALL be written in the imperative, SHALL NOT shame the user, and SHALL each have at most 48 characters.
7. WHEN the Verdict_Line comes from `OfflineCoffinAI`, THE Seance_Sheet SHALL show the text as it is, and the check of Allowed_Characters and time-of-day words SHALL apply to the Seance_Copy and not to the text of `coffin_core`.

### Requirement 13: Architecture and boundaries

**User Story:** As a maintainer, I want the séance logic pure and the app boundaries intact, so that the rules are easy to test and the skeleton stays reusable.

#### Acceptance Criteria

1. THE Seance_Rules, the Revival_Band mapping and the Revival_Step choice (the choice of `RevivalStepKind` values) SHALL live in `apps/graveyard/lib/src/domain`, with the text of each Revival_Step held in `GraveyardCopy`, in a folder that follows the Domain import rules, with one public class per file in `snake_case.dart` and a doc comment on every public API.
2. THE Seance_Rules SHALL import no Flutter library, no `dart:ui`, no `dart:io`, no `dart:html`, no `package:coffin_core`, no networking package and no storage package, and SHALL NOT call `DateTime.now()`.
3. THE Graveyard_App SHALL import `coffin_core` only through `package:coffin_core/coffin_core.dart`, never a file under `coffin_core/lib/src`.
4. THE Graveyard_App SHALL NOT import Hauntagotchi, and `coffin_core` SHALL NOT import Graveyard.
5. THE Graveyard_App SHALL use no state-management package, and SHALL use `ChangeNotifier` with `ListenableBuilder` or plain `StatefulWidget` state for the sheet.
6. THE Graveyard_App SHALL pass `dart format` and `flutter analyze` with zero warnings.
7. THE Graveyard_App SHALL keep every behavior of graveyard-core and graveyard-scene that this feature does not name.

### Requirement 14: Tests

**User Story:** As a maintainer, I want the rules covered by unit and property tests, so that the score cannot silently go wrong.

#### Acceptance Criteria

1. THE test suite SHALL include a unit test for every piece of pure logic of this feature: the Revival_Score, the Revival_Band mapping, the Revival_Step choice and the verdict request builder.
2. THE test suite SHALL include glados property tests for the numeric rules, with the properties named in criteria 4 to 10 and a test count of at least 200 runs for each.
3. THE test suite SHALL treat every test task of this feature as required, and no test task SHALL be marked optional.
4. FOR ALL Seance_Facts, a property test SHALL check that the Revival_Score is an integer from 0 to 100 inclusive.
5. FOR ALL Seance_Facts, a property test SHALL check that two calls with equal arguments return equal Seance_Results (determinism).
6. FOR ALL Seance_Facts, a property test SHALL check that a larger Day_Count with every other fact equal never gives a higher Revival_Score.
7. FOR ALL Seance_Facts, a property test SHALL check that an archived Grave never gets a higher Revival_Score than the same Grave not archived.
8. FOR ALL Seance_Facts, a property test SHALL check that the Seance_Rules choose exactly three `RevivalStepKind` values and that they are distinct.
9. FOR ALL Revival_Scores from 0 to 100, a property test SHALL check that the Revival_Band is monotonic, and the test suite SHALL include a unit test of the band edges 0, 39, 40, 69, 70 and 100.
10. FOR ALL `RevivalStepKind` values, a property test SHALL check that the text `GraveyardCopy.revivalStepText` provides for the kind has at most 48 characters and uses only Allowed_Characters.
11. THE property tests SHALL use only Web_Safe_Generators, a run counter that asserts the number of runs, and the comment header `// Feature: graveyard-seance, Property N: <title>` with `// Validates: Requirements ...`.
12. THE test suite SHALL include widget tests with `FakeClock`, `MemoryRecordRepository<Grave>` and a fake `CoffinAI`, for: opening the sheet from the Seance_Control; the score, band and steps shown in the first frame with a verdict that never completes; the verdict shown when it arrives; the Safe_Verdict_Line on an error and on a timeout; no Reveal under `disableAnimations`; the close button, Escape and focus return; the semantic labels; and no overflow at the widths and text scales of Requirement 11.
13. THE test suite SHALL include a test of the verdict request: the purpose is `AiPurpose.seanceVerdict`, the facts are exactly `projectName` and `daysSinceLastCommit`, and the same Grave gives the same seed.
14. THE test suite SHALL include a source-rule test under `test/source_rules/` that checks the Domain import rules of Requirement 13 for the séance files, and that no file of this feature stores séance data.
15. THE test suite SHALL include a copy test that checks Requirement 12 for every Seance_Copy string.
16. THE test suite SHALL use no real clock, no real Hive and no network, and SHALL NOT depend on the time zone of the machine.
17. THE Graveyard_App SHALL pass `flutter test` in `apps/graveyard`, and `flutter test --platform chrome test/domain test/data` for the Domain tests, before any task of this feature is marked done.
