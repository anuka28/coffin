# Implementation Plan: graveyard-seance

## Overview

The plan builds the séance bottom-up in Dart. First come the Seance_Copy strings, then the pure Domain rules in `lib/src/domain/seance` (facts, band, step kinds, steps, result, rules; the Domain holds step kinds, never step text, and `GraveyardCopy.revivalStepText` maps kinds to text in the UI layer), each unit with its unit tests and its glados property tests (Properties 1 to 12) and the eight worked examples. Then come the verdict request builder and the `FallbackCoffinAI` wiring in `lib/src/ui/seance_ai.dart`, the Seance_Control, the Seance_Sheet, and the wiring through the tombstone, the scene, the screen and the app. Widget tests, source-rule tests and a final verification follow. Each task builds on the previous ones and ends wired into the app, so no code is left orphaned. No package, asset or lock change is part of this plan.

Rules for every task:

- Edit only `apps/graveyard/lib`, `apps/graveyard/test` and `.kiro/specs/graveyard-seance`. Nothing changes in `packages/coffin_core`, `apps/hauntagotchi`, `tool/`, any `pubspec.yaml`, `pubspec.lock`, `CREDITS.md`, `.github/` or any other spec. `DIARY.md` is not a protected file, but no task here edits it.
- Never create files outside the repository, including `/tmp`. Scratch output goes inside the repo only if a task says so, and is deleted before the task ends.
- Doc-comment every public API in `lib/src/domain/seance`. One public class per file, `snake_case.dart`. Code passes `dart format` and `flutter analyze` with zero warnings.
- The séance rules live in `lib/src/domain/seance`. They import no Flutter library, no `dart:ui`, no `dart:io`, no `dart:html`, no `package:coffin_core`, no networking package and no storage package, and call no `DateTime.now()`. They import nothing from `lib/src/ui`, with no exception and no allow-list: the Domain returns the pure enum `RevivalStepKind` and carries no step text. Integer arithmetic stays below 2^53.
- The verdict request builder (`buildVerdictRequest`) and the `FallbackCoffinAI` wiring (`buildSeanceAi`) live in `lib/src/ui/seance_ai.dart`, not in the Domain, because they need `coffin_core`.
- Apps import only `package:coffin_core/coffin_core.dart`, never files under `coffin_core/lib/src`. Graveyard never imports Hauntagotchi. No state-management package.
- Every user-facing string lives in `GraveyardCopy`. Colors come from `CoffinColorTokens`, with no hard-coded color.
- Tests mirror `lib/` without `src/`: `lib/src/domain/seance/x.dart` is tested in `test/domain/seance/x_test.dart`, and `lib/src/ui/x.dart` in `test/ui/x_test.dart`. Tests under `test/domain` and `test/data` never import `dart:io`. Every test that reads source files lives in `test/source_rules/`.
- Widget tests use `FakeClock`, `MemoryRecordRepository<Grave>`, `ControllerHarness` and a fake `CoffinAI`, never real Hive, never the network and never a real clock. No test depends on the time zone of the machine. Animations are advanced with `pump(duration)`, never with a real wait.
- Property tests use glados 1.1.7 with web-safe generators only (no `any.int`, `any.intInRange`, `any.list`, `any.listWithLengthInRange`, string generators or `uint*`), built on `anyIntBetween` and `anyListBetween` from `test/domain/support/grave_generators.dart`, every generated integer below 2^53, `numRuns: 200`, a `RunCounter` that asserts the run count, and the comment header `// Feature: graveyard-seance, Property N: <title>` plus `// Validates: Requirements ...`.
- Every test task (unit, property, worked examples, widget, source rule) is required. None is optional.
- A task is marked done only after `flutter test` passes in `apps/graveyard`.

## Tasks

- [x] 1. Seance copy
  - [x] 1.1 Add the Seance_Copy to `GraveyardCopy`
    - In `lib/src/ui/graveyard_copy.dart` add: `seanceControlText` ("Hold a séance"), `seanceControlLabel(name)` ("Hold a séance for <name>"), `revivalBandLabel(RevivalBand)` ("Restless", "Stirring", "Ready to rise"), `revivalScoreLabel(score, band)` ("Revival score <n> out of 100, <band>"), `revivalStepLabel(k, total, text)` ("Step <k> of 3: <text>"), `seanceRouteName(name)` ("Séance for <name>"), `closeSeanceLabel` ("Close séance"), `seanceThinkingCaption`, `safeVerdictLine` (one sentence, at most 140 characters, no Grave name), the seven step constants `stepForkRepository`, `stepWriteDownPurpose`, `stepUpdateDependencies`, `stepSkimReadme`, `stepFixOneThing`, `stepAskAFriend`, `stepAddOneTest` with the exact texts of the design (each at most 48 characters, imperative, kind), and `revivalStepText(RevivalStepKind kind)`, an exhaustive `switch` expression with no default branch that maps each kind to its constant.
    - Use only Allowed_Characters, no emoji, no time-of-day word, none of "failed", "invalid" or "your fault". `graveyard_copy.dart` imports `revival_band.dart` and `revival_step_kind.dart` (UI to Domain, the allowed direction), both created in task 2.1, before this task. No Flutter import in `graveyard_copy.dart`.
    - _Requirements: 1.1, 1.3, 3.4, 4.9, 4.10, 6.2, 9.1, 10.1, 10.2, 10.4, 12.1, 12.2, 12.3, 12.4, 12.5, 12.6_

  - [x] 1.2 Write the copy tests
    - Extend `test/ui/graveyard_copy_test.dart`: every Seance_Copy string and every output of the label functions (for a few fixed names and all three bands) uses only Allowed_Characters, contains no emoji, no time-of-day word ("morning", "afternoon", "evening", "night", "midnight", "dawn", "dusk"), none of "failed", "invalid", "your fault", no exception text and no raw status code; `safeVerdictLine` is one sentence of at most 140 characters, has no `{` and no Grave name token; every `step*` constant has at most 48 characters; for every value of `RevivalStepKind.values`, `revivalStepText(kind)` is non-empty, has at most 48 characters, uses only Allowed_Characters and no emoji, and no two kinds share the same text (the mapping is total and injective); the exact label forms of Requirements 1.3, 10.1, 10.2 and 10.4 are pinned.
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 14.15_

- [x] 2. Séance rules (Domain)
  - [x] 2.1 Implement `SeanceFacts`, `RevivalBand` and `RevivalStepKind`
    - Create `lib/src/domain/seance/seance_facts.dart` (immutable, value equality; `dayCount`, `archived`, `stars`, `hasDescription`, `manual`; `SeanceFacts.of({grave, today})` reads only the source, `repo` fields, `dateOfDeath.daysUntil(today)` clamped to 0, and `DescriptionCleaner.clean` of the description; a manual Grave gives `archived false`, `stars 0`, `hasDescription false`; never reads the id or the name) and `lib/src/domain/seance/revival_band.dart` (`restless`, `stirring`, `readyToRise`; `forScore(int)` clamps to 0..100 first, then 0..39, 40..69, 70..100) and `lib/src/domain/seance/revival_step_kind.dart` (the pure enum `RevivalStepKind` with the values `forkRepository`, `writeDownPurpose`, `updateDependencies`, `skimReadme`, `fixOneThing`, `askAFriend`, `addOneTest`, each doc-commented, carrying no text).
    - _Requirements: 2.2, 2.3, 2.9, 2.10, 3.1, 3.2, 13.1, 13.2_

  - [x] 2.2 Implement `RevivalSteps`, `SeanceResult` and `SeanceRules`
    - Create `revival_steps.dart` (`RevivalSteps` with the const `generalKinds` list `skimReadme`, `fixOneThing`, `askAFriend`, `addOneTest` in that order, and `choose(facts)` returning a `List<RevivalStepKind>`: condition kinds in the fixed priority order archived and not manual (`forkRepository`), manual (`writeDownPurpose`), old (`updateDependencies` when `dayCount > 365`), `take(3)`, then fill from `generalKinds` in order skipping kinds already chosen and, for a manual Grave, the repository-only kinds `skimReadme` and `forkRepository` (`repositoryOnlyKinds`), so the result always has three distinct kinds), `seance_result.dart` (`score`, `band`, `steps` as three `RevivalStepKind` values, value equality that compares the kinds in order) and `seance_rules.dart` (`evaluate(SeanceFacts)`: age staircase 70/66/56/46/34/24/14/6/0 at the edges 30/90/180/365/730/1095/1825/3650, star points `0` for `stars <= 0` else `min(10, (stars + 1).bitLength)`, Remembered_Bonus `+6` when `hasDescription || manual`, archived penalty `-25`, sum clamped to 0..100, band from `RevivalBand.forScore`) in `lib/src/domain/seance`.
    - Integer arithmetic only, no `dart:math`, no `DateTime.now()`, no randomness. These files import nothing from `lib/src/ui`, no Flutter, no `dart:ui` and no `package:coffin_core`, and hold no step text. The existing Domain source rules must pass without any change to their allow-list.
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.10, 2.11, 3.1, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.11, 13.1, 13.2_

- [x] 3. Test generators
  - [x] 3.1 Extend the generators with séance facts
    - Add to `test/domain/support/grave_generators.dart`: `anySeanceFacts` (`dayCount` from `anyIntBetween(0, 20000)` with the fixed edges 0, 30, 31, 90, 91, 180, 181, 365, 366, 730, 731, 1095, 1096, 1825, 1826, 3650, 3651 folded in; `stars` from `anyIntBetween(0, 1048576)` with the fixed values 0, 1, 511, 1023, 2000, 60680 and 181400 folded in; `archived`, `hasDescription` and `manual` from `anyIntBetween(0, 1)` mapped to a bool; a manual fact forces `archived false`, `stars 0`, `hasDescription false`), `anyManualFacts` (`manual true`, `archived false`, `stars 0`, `hasDescription` random), `anyScore` (0 to 100 plus the edges 0, 39, 40, 69, 70, 100) and `anyGraveWithSource` for the request tests (a Grave from the existing generators with a name from `anyProjectName`, normalised to 1 to 80 code points).
    - Keep every generated integer far below 2^53 and add no `dart:io` import.
    - _Requirements: 14.2, 14.11_

- [x] 4. Unit tests for the rules
  - [x] 4.1 Write unit tests for `SeanceFacts`
    - Create `test/domain/seance/seance_facts_test.dart`: a manual Grave gives `archived false`, `stars 0`, `hasDescription false`, `manual true`; a GitHub Grave with no description gives `hasDescription false`; a GitHub Grave whose description cleans to empty (only a shortcode, only whitespace) gives `hasDescription false`; a GitHub Grave with a real description gives `true`; a future date of death gives `dayCount 0`; a date of death equal to Today gives 0; facts do not change when only the id or the name changes.
    - _Requirements: 2.2, 2.9, 7.4_

  - [x] 4.2 Write unit tests for `SeanceRules`
    - Create `test/domain/seance/seance_rules_test.dart`: the age-point boundaries at the Day_Counts 0, 30, 31, 90, 91, 180, 181, 365, 366, 730, 731, 1095, 1096, 1825, 1826, 3650 and 3651; `stars 0` gives 0 star points, `stars 1` gives 2, `stars 511` gives 10, `stars 1023` and above give exactly 10; the Remembered_Bonus is 6 for a manual Grave with `hasDescription` true or false and for a described GitHub Grave and 0 for an undescribed GitHub Grave; the archived penalty is 25; the raw maximum 86 stays at 86; an archived Grave dead 4,015 days with no bonus clamps to 0; the same facts give an equal result twice; the largest `stars` below 2^53 does not throw.
    - _Requirements: 2.1, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10, 2.11, 14.1_

  - [x] 4.3 Write unit tests for `RevivalBand`
    - Create `test/domain/seance/revival_band_test.dart`: the band edges 0, 39, 40, 69, 70 and 100 map to Restless, Restless, Stirring, Stirring, Ready to rise, Ready to rise; a score below 0 and one above 100 are clamped and do not throw.
    - _Requirements: 3.1, 14.1, 14.9_

  - [x] 4.4 Write unit tests for `RevivalSteps`
    - Create `test/domain/seance/revival_steps_test.dart`: zero conditions give the first three `generalKinds` in order; archived only and old only each give that kind first followed by the fill in order; manual only gives `writeDownPurpose`, `fixOneThing`, `askAFriend`; archived and old gives `forkRepository`, `updateDependencies`, `skimReadme`; manual and old gives `writeDownPurpose`, `updateDependencies`, `fixOneThing`; a manual Grave never gets `skimReadme` or `forkRepository`, also when `archived` is true (archived and manual, and archived, manual and old, give no repository-only kind); `dayCount` 365 does not trigger `updateDependencies` and 366 does; every result has three distinct kinds; two calls give equal lists.
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.11, 14.1_

  - [x] 4.5 Write the worked examples test
    - Create `test/domain/seance/worked_examples_test.dart` with all eight rows of the design table, each building the `SeanceFacts` shown (manual rows: `manual true`, `archived false`, `stars 0`, `hasDescription false`) and asserting that `SeanceRules.evaluate` returns the exact score, the exact band and the exact three `RevivalStepKind` values in order (the text of each kind is checked in the copy test, so this Domain test imports nothing from `ui`): row 1 (10 stars, described, 30 days: 80, Ready to rise), row 2 (182 days: 56, Stirring), row 3 (manual, 60 days: 72, Ready to rise, steps `writeDownPurpose`, `fixOneThing`, `askAFriend`), row 4 (manual, 4,015 days: 6, Restless, steps `writeDownPurpose`, `updateDependencies`, `fixOneThing`), row 5 (181,400 stars, 0 days: 86, Ready to rise), row 6 (`atom/atom`, archived, 1,095 days: 15, Restless), row 7 (`mojombo/grit`, 1,095 days, 2,000 stars: 40, Stirring) and row 8 (`octocat/Hello-World`, no description, 4,000 stars, 730 days: 44, Stirring). Also check the stability rows: 28 to 31 days stay Ready to rise for row 1, 180 to 184 days stay Stirring for row 2, and 59 to 62 days stay Ready to rise for row 3.
    - _Requirements: 2.1, 2.5, 3.1, 4.4, 4.5, 4.6, 4.7, 4.11, 14.1_

- [x] 5. Property tests for the rules
  - [x] 5.1 Write property test for score range
    - **Property 1: Revival_Score stays in range**
    - **Validates: Requirements 2.1, 2.10, 14.4**
    - Create `test/domain/seance/seance_score_range_property_test.dart` over `anySeanceFacts`.

  - [x] 5.2 Write property test for determinism
    - **Property 2: Evaluation is deterministic**
    - **Validates: Requirements 2.4, 7.4, 14.5**
    - Create `test/domain/seance/seance_determinism_property_test.dart`.

  - [x] 5.3 Write property test for age monotonicity
    - **Property 3: Older death never scores higher**
    - **Validates: Requirements 2.5, 14.6**
    - Create `test/domain/seance/seance_age_property_test.dart` over a facts value and two Day_Counts.

  - [x] 5.4 Write property test for the archived penalty
    - **Property 4: Archived never scores higher**
    - **Validates: Requirements 2.6, 14.7**
    - Create `test/domain/seance/seance_archived_property_test.dart`.

  - [x] 5.5 Write property test for stars
    - **Property 5: More stars never scores lower**
    - **Validates: Requirements 2.7**
    - Create `test/domain/seance/seance_stars_property_test.dart`.

  - [x] 5.6 Write property test for the description
    - **Property 6: A description never scores lower**
    - **Validates: Requirements 2.8**
    - Create `test/domain/seance/seance_description_property_test.dart`.

  - [x] 5.7 Write property test for the steps
    - **Property 7: Exactly three distinct steps**
    - **Validates: Requirements 4.1, 4.2, 14.8**
    - Create `test/domain/seance/revival_steps_count_property_test.dart`: `RevivalSteps.choose` returns exactly three pairwise distinct `RevivalStepKind` values, and `SeanceRules.evaluate(facts).steps` equals it.

  - [x] 5.8 Write property test for the band
    - **Property 8: Revival_Band is total and monotonic**
    - **Validates: Requirements 3.2, 3.3, 14.9**
    - Create `test/domain/seance/revival_band_property_test.dart` over `anyScore` pairs.

  - [x] 5.9 Write the per-kind step text test
    - **Property 9: Revival_Step text obeys the copy rules for every kind**
    - **Validates: Requirements 4.9, 12.6, 14.10**
    - Create `test/ui/revival_step_text_test.dart` (it reads `GraveyardCopy`, so it lives with the UI tests, not under `test/domain`): iterate `RevivalStepKind.values` (a finite enum, so no generator is needed) and assert that `GraveyardCopy.revivalStepText(kind)` is non-empty, has at most 48 characters and only Allowed_Characters, and that no two kinds share the same text. `RevivalSteps.choose` returns only kinds, so this covers the text of every step any facts can produce.

  - [x] 5.10 Write property test for manual graves
    - **Property 11: Manual graves get the Remembered_Bonus and can reach every band**
    - **Validates: Requirements 2.1, 2.8, 3.1, 4.6**
    - Create `test/domain/seance/seance_manual_property_test.dart` over `anyManualFacts`: the score equals `clamp(agePoints + 6)`, equals the score of a described, non-archived, 0-star GitHub fact set of the same Day_Count, and does not differ between `hasDescription` true and false. Add the three pinned examples (60, 365 and 4,015 days) in the same file.

- [x] 6. Checkpoint - Rules complete
  - Ensure all tests pass, ask the user if questions arise. Also run `flutter test --platform chrome test/domain test/data` in `apps/graveyard`; it must pass, so the score is equal on the VM and on the web.

- [x] 7. Verdict request and Seance_Ai
  - [x] 7.1 Implement `buildVerdictRequest` and `buildSeanceAi`
    - Create `lib/src/ui/seance_ai.dart` with `verdictMaxLength` (140), `verdictWaitLimit` (3 seconds), `buildVerdictRequest({grave, facts})` (purpose `AiPurpose.seanceVerdict`, exactly the two facts `AiFactKeys.projectName` and `AiFactKeys.daysSinceLastCommit`, `maxLength` 140, seed `StableHash.of(grave.id) % (AiRequest.maxSeed + 1)`) and `buildSeanceAi()` (`FallbackCoffinAI` with `OfflineCoffinAI` as primary and as secondary and `timeout: verdictWaitLimit`). Import only `package:coffin_core/coffin_core.dart`. No network call, no key.
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.11, 13.3_

  - [x] 7.2 Write unit tests for the verdict request and the Seance_Ai
    - Create `test/ui/seance_ai_test.dart`: the purpose is `AiPurpose.seanceVerdict`; the fact keys are exactly `projectName` and `daysSinceLastCommit` with the Grave name and the Day_Count; `maxLength` is between 16 and 140; the seed is between 0 and `AiRequest.maxSeed`; the same Grave id gives the same seed with different facts; two ids give a fixed pinned seed each; `buildSeanceAi()` is a `FallbackCoffinAI` whose primary and secondary are `OfflineCoffinAI` and whose timeout is greater than zero and at most 3 seconds; asking it for a request returns a non-blank reply with no network.
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 14.1, 14.13_

  - [x] 7.3 Write property test for the verdict request
    - **Property 10: Verdict request facts and seed are stable**
    - **Validates: Requirements 5.2, 5.3, 14.13**
    - Create `test/ui/seance_ai_property_test.dart` over `anyGraveWithSource` and `anySeanceFacts`: the facts map has exactly the two keys with the right values, and two calls with the same Grave id and different facts give the same seed in `[0, AiRequest.maxSeed]`.

- [x] 8. Control, sheet and wiring
  - [x] 8.1 Add the fake `CoffinAI` test support
    - Create `test/support/fake_coffin_ai.dart`: a `CoffinAI` that can reply at once, reply after a completer is completed, throw, never complete, or return a blank or an over-length reply, and that records the requests it received.
    - _Requirements: 5.6, 14.12_

  - [x] 8.2 Implement `SeanceControl`
    - Create `lib/src/ui/seance_control.dart`: a button with the visible label `GraveyardCopy.seanceControlText`, a minimum size of 48 by 48 with a padded tap target, `Semantics(button: true, label: GraveyardCopy.seanceControlLabel(grave.name))`, keyboard activation on Enter and Space, and hover, press and focus states from the ambient theme. It takes `grave` and `onPressed`, holds no string of its own and uses no hard-coded color.
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 12.1_

  - [x] 8.3 Implement `SeanceSheet` and `showSeanceSheet`
    - Create `lib/src/ui/seance_sheet.dart`: `showSeanceSheet(context, {grave, today, seanceAi})` opens `showModalBottomSheet` with `isScrollControlled: true`, `RouteSettings(name: GraveyardCopy.seanceRouteName(grave.name))`, safe-area padding and a content width of at most 560 centered. `SeanceSheet` computes `SeanceFacts.of` and `SeanceRules.evaluate` once in `initState`, asks the Seance_Ai once with `buildVerdictRequest`, and keeps the final `Grave` it was opened with. Layout in order: title row with the Grave name and a 48 by 48 close button labelled "Close séance" with autofocus; the score as a number and the band as a word in text; the numbered list of three steps, each kind rendered as text through `GraveyardCopy.revivalStepText`; the Verdict_Line area (`GhostLoader` with `seanceThinkingCaption` while pending, the reply text when ready, `safeVerdictLine` on an error or when the wait limit passes, with no error text, icon or retry). Guard every `setState` with a disposed flag so a late reply is dropped. One non-looping fade `AnimationController` (300 to 600 ms, ease-in-out) plays once unless `MediaQuery.disableAnimations` is true, then starts at 1; dispose it once, also when the sheet closes mid-Reveal. Semantics: one node `revivalScoreLabel`, one node per step `revivalStepLabel(k, 3, GraveyardCopy.revivalStepText(kind))`, the Verdict_Line in a live region, decorative parts excluded. Colors from `CoffinColorTokens`, 16 px corners, soft glow, text wraps, the content scrolls with the close button reachable. Store nothing.
    - _Requirements: 3.4, 3.5, 5.1, 5.6, 5.7, 5.8, 5.9, 5.10, 6.1, 6.2, 6.3, 6.4, 6.5, 7.1, 7.2, 7.3, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 9.1, 9.2, 9.3, 9.4, 9.5, 10.1, 10.2, 10.3, 10.4, 10.5, 11.2, 12.1_

  - [x] 8.4 Wire the control and the Seance_Ai through the app
    - Edit `lib/src/ui/grave_tombstone.dart` to place the `SeanceControl` below the stone next to the delete control (outside the stone, no overlap with the delete control or any stone text, with the Crack_Band, Epitaph and Keep_Out_Areas math, the column count, the tombstone width and the tilt limit unchanged) and to open `showSeanceSheet` with the Grave, Today and the Seance_Ai. Thread a `CoffinAI seanceAi` constructor argument through `GraveyardScene` and `GraveyardScreen`, and build it once with `buildSeanceAi()` in `app_routes.dart` or `main.dart` where the controller is built. Update the existing tests that construct these widgets so they compile and pass (pass a fake or the default `buildSeanceAi()`), without changing what they assert.
    - _Requirements: 1.6, 1.7, 1.8, 5.6, 9.6, 11.3, 11.4, 13.7_

  - [x] 8.5 Manual graves never get repository-only steps
    - Rule change found in the running app: a manual Grave got "Open the repository and skim the README", but a manual Grave has no repository. A manual Grave never gets the repository-only kinds `skimReadme` and `forkRepository`. `RevivalSteps` fills its remaining places from the general kinds that are left (`fixOneThing`, `askAFriend`, `addOneTest`, in that order), and the result still has exactly three distinct kinds. Scores do not change.
    - Update `requirements.md` (Requirement 4: criteria 4 and 7 and one new criterion, with the rule and the numbering kept consistent), `design.md` (the `RevivalSteps` section and code sample, the worked examples table where the manual rows 3 and 4 change their steps and the scores stay, the testing section, and a new Property 12 "A manual Grave never gets a repository-only step") and the `.kiro/specs/graveyard-seance/tasks.md` text of tasks 2.2, 4.4, 4.5 and the property notes so that they match.
    - Edit `lib/src/domain/seance/revival_steps.dart` (Domain stays pure, no new import, no step text; the `generalKinds` list keeps its order and a manual Grave skips `skimReadme` while filling; a manual Grave never gets `forkRepository` even when `archived` is true), then update `test/domain/seance/revival_steps_test.dart` and `test/domain/seance/worked_examples_test.dart` (the manual rows get the new steps, scores and bands unchanged). Add a glados property test `test/domain/seance/revival_steps_property_test.dart` (or the existing property file for steps, if there is one, extending it) with the header `// Feature: graveyard-seance, Property 12: A manual Grave never gets a repository-only step` and `// Validates: Requirements 4.1, 4.2, 4.11`: for all facts with `manual` true (any `archived`, `dayCount`, `stars`, `hasDescription`), the steps never include `skimReadme` or `forkRepository`, and are still three distinct kinds. Keep the existing properties passing.
    - Check any widget or copy test that expects the old manual steps and update it to the new rule without weakening what it asserts.
    - _Requirements: 4.1, 4.2, 4.4, 4.6, 4.7, 4.11, 14.1_

- [x] 9. Checkpoint - Séance wired
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 10. Widget tests
  - [ ] 10.1 Write widget tests for the control
    - Create `test/ui/seance_control_test.dart`: the visible label "Hold a séance"; the semantic label names the Grave; the tap target is at least 48 by 48; Enter and Space activate it; hover, pressed and focused states are visible; it lies outside the stone and its rect does not overlap the delete control or any text of the tombstone; activating it opens the Seance_Sheet for that Grave; while a sheet is open no second sheet opens; the Scene_Layout column count, tombstone width and tilt of a tombstone are unchanged by the control.
    - Also edit `test/ui/graveyard_scene_test.dart`, group `semantics`, test `node order follows the grave order`: stop skipping the séance label that task 8.4 added to the label walk, and assert the full per-grave order for every grave at every width in the test (320, 360, 768 and 1280): the stone label, then `GraveyardCopy.seanceControlLabel(name)` ("Hold a séance for <name>"), then the delete label ("Delete <name>"), with the graves in grave order.
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 11.3, 11.4, 14.12_

  - [ ] 10.2 Write widget tests for the sheet content and the verdict
    - Create `test/ui/seance_sheet_test.dart`: with a fake `CoffinAI` that never completes, the first frame shows the score, the band word and the three steps, plus the ghost loader and its caption; when the fake replies, the line replaces the loader and the score and steps do not move (`getTopLeft` unchanged); on an error and after pumping past `verdictWaitLimit` the Safe_Verdict_Line shows with no error text, no error icon and no retry control and the score and steps stay unchanged; the order is name, score and band, steps, verdict; the numbers and words are text; the request sent to the fake has the purpose, the two facts and the seed of Requirement 5; the same Grave on the same Today shows the same score, band and steps when opened twice; nothing is written to the repository (`MemoryRecordRepository` unchanged, the Grave, order and saved state unchanged); a Grave removed while the sheet is open leaves the sheet showing; the close button is always present, also while pending.
    - _Requirements: 3.4, 3.5, 5.1, 5.2, 5.7, 5.8, 5.9, 6.1, 6.2, 6.3, 6.4, 6.5, 7.1, 7.2, 7.3, 7.4, 8.2, 8.8, 14.12_

  - [ ] 10.3 Write widget tests for closing, focus and reduced motion
    - Create `test/ui/seance_sheet_close_test.dart`: the close button (48 by 48, label "Close séance"), Escape, a tap outside and a drag down each close the sheet; focus moves into the sheet when it opens and returns to the Seance_Control when it closes while the control is in the tree; focus stays inside the sheet while open; the scene keeps its scroll position and tombstones after closing; closing during the Reveal does not throw; a late fake reply after closing is dropped with no exception (`tester.takeException()` is null after pumping past the delay); with `disableAnimations` true the result shows at once with no running animation, and without it one Reveal of 300 to 600 ms plays once and then no animation keeps running except the ghost loader while pending.
    - _Requirements: 5.10, 8.3, 8.4, 8.6, 8.7, 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 14.12_

  - [ ] 10.4 Write widget tests for accessibility and contrast
    - Create `test/ui/seance_sheet_semantics_test.dart`: one node labelled "Revival score <n> out of 100, <band>" with the real values; one node per step "Step <k> of 3: <text>"; the Verdict_Line is a live region; the route name is "Séance for <name>"; no node for the glows, the ghost loader graphic or the Reveal; every text and icon of the sheet keeps `WcagContrast.ratio` of at least 4.5 for text and 3.0 for icons against the color directly behind it in the dark and the daylight theme, with the sheet colors read from `CoffinColorTokens`.
    - _Requirements: 8.5, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 14.12_

  - [ ] 10.5 Write widget tests for layout
    - Create `test/ui/seance_sheet_layout_test.dart`: the control and the sheet render without an overflow exception at the widths 320, 360, 768 and 1280 and the text scales 1.0, 1.5 and 2.0 (the sheet also at 2.0, with no clipped text); the content is at most 560 wide and centered on wide screens; the sheet scrolls when taller than the available height and the close button stays reachable; every sheet state (pending, ready, fallback) is covered.
    - _Requirements: 8.1, 10.7, 11.1, 11.2, 11.5, 14.12_

- [ ] 11. Source-rule tests
  - [ ] 11.1 Write source-rule tests for the séance
    - Create `test/source_rules/seance_sources_test.dart`: no file under `lib/src/domain/seance` contains `package:flutter`, `dart:ui`, `dart:io`, `dart:html`, `package:coffin_core`, `package:http`, `package:hive_ce` or `DateTime.now`, and none imports anything from `ui` (no import path containing `ui/`, no `graveyard_copy.dart`), with no allow-list and no exception; every file under `lib/src/domain/seance` has one public class and a doc comment on each public member; no file of this feature (`lib/src/domain/seance`, `seance_ai.dart`, `seance_control.dart`, `seance_sheet.dart`) references a storage class (`Hive`, `RecordRepository`, `GraveStorage`) or writes séance data; `grave_codec.dart` contains none of "seance", "revival" or "verdict"; `seance_ai.dart` imports `coffin_core` only through `package:coffin_core/coffin_core.dart`; no file under `lib` imports `coffin_core/src` or Hauntagotchi; the new UI files use no `Color(0x` and no `Colors.`; no file adds a state-management package import. This folder is the only place that reads source files with `dart:io`.
    - _Requirements: 5.11, 7.2, 8.5, 13.1, 13.2, 13.3, 13.4, 13.5, 14.14_

- [ ] 12. Final checkpoint - Verification
  - Run in `apps/graveyard`: `dart format --output=none --set-exit-if-changed .`, `flutter analyze` (zero issues), `flutter test`, and `flutter test --platform chrome test/domain test/data`. Check `grep -rl "dart:io" test/domain test/data` finds nothing.
  - Run `flutter test` in `packages/coffin_core` (it must pass unchanged, which shows the AI layer is unaffected), in `apps/hauntagotchi` and in `tool/`.
  - Run `flutter pub get --enforce-lockfile` at the repo root, then check `git diff --exit-code -- pubspec.lock` exits 0 (no new package, so no lockfile change).
  - Check `git diff --exit-code -- packages/coffin_core apps/hauntagotchi tool` exits 0, and that no other spec under `.kiro/specs` changed.
  - Check `git status --short` lists only these paths: `apps/graveyard/lib`, `apps/graveyard/test` and `.kiro/specs/graveyard-seance`. Ignore any `DIARY.md` entry, because the user maintains that file. If it lists any other path (for example `packages/coffin_core`, `apps/hauntagotchi`, `tool/`, `pubspec.lock` or another spec), report it to the user and do not revert it.
  - Fix any failure at its cause. Create no file outside the repository, including `/tmp`.
  - Ensure all tests pass, ask the user if questions arise.
  - _Requirements: 5.11, 13.3, 13.4, 13.6, 13.7, 14.16, 14.17_

## Notes

- Every test sub-task is required and none is marked optional. The project testing rules and Requirement 14.3 require unit tests for pure logic and glados property tests for numeric rules.
- Every property in the design (1 to 12) has its own sub-task: P1 (5.1), P2 (5.2), P3 (5.3), P4 (5.4), P5 (5.5), P6 (5.6), P7 (5.7), P8 (5.8), P9 (5.9), P10 (7.3), P11 (5.10), P12 (8.5).
- The eight worked examples of the design are pinned in task 4.5 with exact score, band and steps.
- Requirement 5.9 (timeout) is covered with a fake `CoffinAI` that never completes, pumped past `verdictWaitLimit`, because the default `OfflineCoffinAI` always replies at once.
- Task 1.1 needs `RevivalBand` and `RevivalStepKind` from task 2.1 for `revivalBandLabel` and `revivalStepText`. The wave order runs 2.1 before 1.1, so both files already exist when 1.1 adds the imports in `graveyard_copy.dart`. The Domain never imports `graveyard_copy.dart`.
- Tasks 1.2, 3.1 and 8.4 edit shared files (`graveyard_copy_test.dart`, `grave_generators.dart`, the tombstone, scene and screen files), so each sits in a different wave from any other task that edits the same file.
- No task edits `DIARY.md`. The final `git status` check ignores any `DIARY.md` entry and otherwise lists only `apps/graveyard/lib`, `apps/graveyard/test` and `.kiro/specs/graveyard-seance`.
- This workflow only creates the plan. Start execution by opening this file and choosing "Start task" on a task.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["2.1"] },
    { "id": 1, "tasks": ["1.1", "3.1", "4.1", "4.3", "8.1"] },
    { "id": 2, "tasks": ["1.2", "2.2", "5.8"] },
    { "id": 3, "tasks": ["4.2", "4.4", "4.5", "5.1", "5.2", "5.3", "5.4", "5.5", "5.6", "5.7", "5.9", "5.10"] },
    { "id": 4, "tasks": ["6"] },
    { "id": 5, "tasks": ["7.1", "8.2"] },
    { "id": 6, "tasks": ["7.2", "7.3", "8.3"] },
    { "id": 7, "tasks": ["8.4"] },
    { "id": 8, "tasks": ["8.5"] },
    { "id": 9, "tasks": ["9"] },
    { "id": 10, "tasks": ["10.1", "10.2", "10.3", "10.4", "10.5", "11.1"] },
    { "id": 11, "tasks": ["12"] }
  ]
}
```
