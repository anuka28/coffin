# Implementation Plan: graveyard-resurrection

## Overview

The plan builds the resurrection bottom-up in Dart. First comes the Domain, in this order: the risen-state rules (`RaiseRules` and the `risenOn` field of `Grave`), the codec key, `LivingSplit`, `PlayTiming`, `HandHeight`, `HandGeometry`, the Clod generator and path, `EpitaphFootprint` and `RisingGhostBox`. Each unit has its unit tests and its glados property tests (Properties 1 to 18). A checkpoint closes the Domain. Next come the `GraveListController` methods `replaceGrave`, `raise` and `layToRest`, with their tests, and a second checkpoint. Then comes the UI, in this order: the Resurrection_Copy, the painters, `ResurrectionPlay`, the `ArchEpitaph` text, `GraveTombstone`, the `Seance_Sheet` Raise_Control, the Living_Row, the Rest_Dialog, the `RepositoryLink` with `GraveyardClipboard`, and the wiring through `GraveyardScene`, `GraveyardScreen` and the app root. Widget tests, the source-rule and copy-rule tests and a final verification follow. Each task builds on the previous ones and ends wired into the app, so no code is left orphaned. No package, asset or lock change is part of this plan.

Rules for every task:

- Edit only `apps/graveyard/lib`, `apps/graveyard/test` and `.kiro/specs/graveyard-resurrection`. Nothing changes in `packages/coffin_core`, `apps/hauntagotchi`, `tool/`, any `pubspec.yaml`, `pubspec.lock`, `CREDITS.md`, `.github/` or any other spec. `DIARY.md` is maintained by the user, is not a protected file, and no task here edits it.
- Never create files outside the repository, including `/tmp`. Scratch output goes inside the repo only if a task says so, and is deleted before the task ends.
- Doc-comment every public API in `lib/src/domain`. One public class per file, `snake_case.dart`. Code passes `dart format` and `flutter analyze` with zero warnings.
- The new Domain files (`lib/src/domain/raise_rules.dart`, `lib/src/domain/living_split.dart` and everything under `lib/src/domain/resurrection`) import no Flutter library, no `dart:ui`, no `dart:io`, no `dart:html`, no `package:coffin_core`, no networking package and no storage package, call no `DateTime.now()`, use no `Duration` and no `Timer`, and import nothing from `lib/src/ui`. Their integer arithmetic stays below 2^53. The existing `test/source_rules/domain_sources_test.dart` scans `lib/src/domain` recursively and must pass without any change.
- Apps import only `package:coffin_core/coffin_core.dart`, never files under `coffin_core/lib/src`. Graveyard never imports Hauntagotchi. No state-management package. No package is added.
- Every user-facing string lives in `GraveyardCopy`. Colors come from `CoffinColorTokens`, with no hard-coded color.
- Existing test files stay as they are. New tests go in new files. An existing test file is touched only when a new constructor parameter forces a compile fix, and then only the constructor call changes and never an assertion. New constructor parameters get defaults wherever the design allows it, so existing tests compile unchanged.
- Tests mirror `lib/` without `src/`: `lib/src/domain/resurrection/x.dart` is tested in `test/domain/resurrection/x_test.dart`, and `lib/src/ui/x.dart` in `test/ui/x_test.dart`. Tests under `test/domain` and `test/data` never import `dart:io`. Every test that reads source files lives in `test/source_rules/`.
- Widget tests use `FakeClock`, `MemoryRecordRepository<Grave>`, `ControllerHarness` and a fake `CoffinAI`, never real Hive, never the network and never a real clock. No test depends on the time zone of the machine. Animations and the play timer are advanced with `tester.pump(duration)`, never with a real wait, `Future.delayed` or a real `Timer`.
- Property tests use glados 1.1.7 with web-safe generators only (no `any.int`, `any.intInRange`, `any.list`, `any.listWithLengthInRange`, string generators or `uint*`), built on `anyIntBetween` and `anyListBetween` from `test/domain/support/grave_generators.dart`, every generated integer below 2^53, `numRuns: 200`, a `RunCounter` that asserts the run count, and the comment header `// Feature: graveyard-resurrection, Property N: <title>` plus `// Validates: Requirements ...`.
- Every test task (unit, property, calibration, widget, source rule, copy) is required. None is optional.
- A task is marked done only after `flutter test` passes in `apps/graveyard`. Domain and data tests must also pass with `flutter test --platform chrome test/domain test/data`.

## Tasks

- [x] 1. Risen-state rules (`RaiseRules` and `Grave.risenOn`)
  - [x] 1.1 Add `risenOn` to `Grave` and implement `RaiseRules`
    - Edit `lib/src/domain/grave.dart`: add the optional field `CalendarDate? risenOn` (null means not Risen), an optional `risenOn` parameter (default null) on the private constructor, `Grave.manual` and `Grave.github` so every existing call site compiles unchanged, the method `copyWithRisenOn(CalendarDate? risenOn)`, and `risenOn` in `==`, `hashCode` and `toString`. No `Duration` and no `DateTime`.
    - Create `lib/src/domain/raise_rules.dart` with `RaiseRules.raise(Grave, CalendarDate today)` (returns the same Grave when it is already Risen, else a copy with `risenOn` set to `today`) and `RaiseRules.layToRest(Grave)` (returns the same Grave when it is not Risen, else a copy with `risenOn` cleared). Both are total and never throw. `raise_rules.dart` imports only `grave.dart` and `calendar_date.dart`.
    - Every existing Domain and data test must still pass unchanged.
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.10, 2.11, 2.12, 16.1, 16.2_

  - [x] 1.2 Extend the test generators for this feature
    - Add to `test/domain/support/grave_generators.dart` (web-safe only, all integers below 2^53): `anyRisenOn` (null, or a valid `CalendarDate` from the existing date generator), `anyGraveWithRisen` (any existing Grave generator with `risenOn` drawn from `anyRisenOn`, for GitHub and manual Graves), `anyGraveList` of 0 to 12 Graves with unique ids and a fixed share of equal `risenOn` values, `anyPlayingSet` (a set of ids drawn from a generated Grave list plus up to two ids that are not in the list), `anyGraveId` (a non-empty id string built from `anyIntBetween` code points in a safe ASCII range, without any string generator), `anyStoneWidth` (`anyIntBetween(120, 400)` as double), `anyStoneHeight` (`anyIntBetween(160, 480)` as double), `anyTextScale` (`anyIntBetween(100, 200) / 100`) and `anyElapsedMs` helpers (`anyIntBetween(0, PlayTiming.playDurationMs)` and a wide variant `anyIntBetween(-500, 3300)`), with the fixed edge values folded in.
    - Add no `dart:io` import. Extend `test/domain/support/grave_generators_test.dart` only if a new generator needs a range check, in a new test group.
    - _Requirements: 17.2, 17.4_

  - [x] 1.3 Write unit tests for `RaiseRules` and the `Grave` field
    - Create `test/domain/raise_rules_test.dart`: raising a fresh Grave sets `risenOn` to Today; raising an already Risen Grave keeps its first date even with a different Today; laying a not Risen Grave to rest returns an equal Grave; laying a Risen Grave to rest clears `risenOn`; `id`, `name`, `dateOfDeath`, `source` and `repo` stay equal for GitHub and manual Graves; `risenOn` takes part in `==` and `hashCode` (two Graves that differ only in `risenOn` are not equal); a Grave built without `risenOn` is not Risen; the day count of the dead-for rules and the weathering input do not change after a Raise; no call throws for the extreme dates `0001-01-01` and `9999-12-31`.
    - _Requirements: 2.2, 2.3, 2.4, 2.5, 2.7, 2.8, 2.9, 2.10, 2.11, 2.12, 17.1_

  - [x] 1.4 Write property test for raise then Lay_To_Rest
    - **Property 1: Raise then Lay_To_Rest returns the original Grave**
    - **Validates: Requirements 2.7**
    - Create `test/domain/raise_rules_undo_property_test.dart` over not Risen Graves and any Today.

  - [x] 1.5 Write property test for raising twice
    - **Property 2: Raising twice equals raising once**
    - **Validates: Requirements 2.8**
    - Create `test/domain/raise_rules_idempotent_raise_property_test.dart` over `anyGraveWithRisen` and two different values of Today (the second Today never replaces the first date).

  - [x] 1.6 Write property test for Lay_To_Rest idempotence
    - **Property 3: Lay_To_Rest is idempotent**
    - **Validates: Requirements 2.9**
    - Create `test/domain/raise_rules_idempotent_rest_property_test.dart` over `anyGraveWithRisen`.

  - [x] 1.7 Write property test for the kept fields
    - **Property 4: Raise and Lay_To_Rest keep every other field**
    - **Validates: Requirements 2.10, 2.12**
    - Create `test/domain/raise_rules_fields_property_test.dart` over `anyGraveWithRisen` and any Today: `id`, `name`, `dateOfDeath`, `source` and `repo` are equal after `raise` and after `layToRest`.

- [x] 2. Risen key in the codec
  - [x] 2.1 Read and write the risen key in `GraveCodec`
    - Edit `lib/src/data/grave_codec.dart`: `encode` writes `'risen': risenOn.toIso()` as the last key only when `risenOn != null`, so a Grave that is not Risen encodes to exactly the map written before this feature. `decode` runs every existing check first and unchanged, then reads `json['risen']`: absent gives not Risen; a non-string value or a string that `CalendarDate.tryParse` rejects throws `FormatException` and no other error type; a valid date sets `risenOn` on the decoded `Grave.manual` or `Grave.github`. Unknown keys stay ignored.
    - The codec holds no vocabulary of the play (no "playing" and no "ResurrectionPlay").
    - _Requirements: 3.1, 3.2, 3.4, 3.5, 3.6, 3.7_

  - [x] 2.2 Write unit tests for the risen key
    - Create `test/data/grave_codec_risen_test.dart` (a new file; no existing codec or storage test file is edited): the exact encoded map of a Risen manual Grave and a Risen GitHub Grave (the `risen` key is last, formatted `YYYY-MM-DD`); the exact encoded map of a Grave that is not Risen (no `risen` key, equal to the pre-feature map); a Legacy_Record decodes as not Risen; each kind of malformed value throws `FormatException` (a number, a boolean, a list, a map, `2024-13-01`, `2024-02-30`, `24-01-01`, an empty string, a string with a time part); a record that is invalid for an unrelated reason still fails for that reason first; unknown keys stay ignored.
    - _Requirements: 3.1, 3.2, 3.4, 3.5, 3.7, 3.8, 17.5_

  - [x] 2.3 Write property test for the codec round trip
    - **Property 5: Codec round trip, with and without Risen_On**
    - **Validates: Requirements 3.3**
    - Create `test/data/grave_codec_risen_round_trip_property_test.dart` over `anyGraveWithRisen`.

  - [x] 2.4 Write property test for legacy records
    - **Property 6: Legacy records decode as not risen**
    - **Validates: Requirements 3.4**
    - Create `test/data/grave_codec_legacy_property_test.dart`: encode a generated Grave with `risenOn` null (or remove the `risen` key from a Risen encoding) and check `decode(map).risenOn` is null.

  - [x] 2.5 Write property test for malformed risen values
    - **Property 7: A malformed risen value is rejected with FormatException**
    - **Validates: Requirements 3.5, 3.6**
    - Create `test/data/grave_codec_risen_malformed_property_test.dart`: replace the `risen` value of a valid encoding with a generated malformed value (wrong type chosen by `anyIntBetween`, wrong format, month 13, day 30 of February) and check that decoding throws `FormatException` and nothing else.

- [ ] 3. Splitting the graveyard
  - [ ] 3.1 Implement `LivingSplit`
    - Create `lib/src/domain/living_split.dart` with `LivingSplit.split({graves, playing})` returning the record `(List<Grave> graveyardRows, List<Grave> livingRow)`: a Grave goes to `livingRow` exactly when `risenOn != null` and its id is not in `playing`; every other Grave goes to `graveyardRows` in input order; `livingRow` is ordered by `risenOn` descending, then lower-cased name, then id. Total, never throws.
    - _Requirements: 5.9, 6.1, 6.2, 6.3, 6.5, 6.6, 6.8, 16.1, 16.2_

  - [ ] 3.2 Write unit tests for `LivingSplit`
    - Create `test/domain/living_split_test.dart`: a concrete list with Risen, playing and plain Graves; a Risen Grave that is playing stays in the graveyard rows; the graveyard rows keep the input order; two Risen Graves with different dates order most recent first; a tie on date is broken by lower-cased name and then by id; an empty list, a playing set with ids that are not in the list, and a list where every Grave is Risen all return without throwing.
    - _Requirements: 5.9, 6.2, 6.3, 6.5, 6.6, 6.8, 17.1_

  - [ ] 3.3 Write property test for the partition
    - **Property 8: Living_Split is a partition**
    - **Validates: Requirements 6.4**
    - Create `test/domain/living_split_partition_property_test.dart` over `anyGraveList` and `anyPlayingSet`: every Grave appears in exactly one list and the two lists together hold the input as a multiset.

  - [ ] 3.4 Write property test for totality and determinism
    - **Property 9: Living_Split never throws and is deterministic**
    - **Validates: Requirements 6.7, 6.8**
    - Create `test/domain/living_split_determinism_property_test.dart`: two calls with the same arguments return equal results, for lists with equal `risenOn` values and for an empty list.

- [ ] 4. Play timing
  - [ ] 4.1 Implement `PlayTiming`
    - Create `lib/src/domain/resurrection/play_timing.dart` with the constants of the design, all `int` milliseconds: `playDurationMs` 2800, `handBurstEndMs` 300, `handSinkEndMs` 600, `risingGhostStartMs` 600, `ghostRiseStartMs` 600, `epitaphFadeStartMs` 2140, `ghostRiseEndMs` equal to `epitaphFadeStartMs`, `epitaphFadeMs` 400. Doc-comment each constant with its reason.
    - _Requirements: 7.2, 7.9, 7.10, 7.11, 7.13, 16.1_

  - [ ] 4.2 Write unit tests for `PlayTiming`
    - Create `test/domain/resurrection/play_timing_test.dart`: `playDurationMs` is at least 2600 and at most 3000; the milestones are strictly ordered (burst end, sink end, rise start, rise end, play end); `risingGhostStartMs + 2200` (the rising reaction length, written as a literal in this Domain test) is at most `playDurationMs`; `epitaphFadeMs` is between 300 and 600; `epitaphFadeStartMs + epitaphFadeMs` is at most `playDurationMs`; `ghostRiseEndMs` equals `epitaphFadeStartMs`; the rise window starts when the Hand has sunk back.
    - _Requirements: 7.2, 7.9, 7.10, 7.11, 7.13, 17.1_

- [ ] 5. Hand height
  - [ ] 5.1 Implement `HandHeight`
    - Create `lib/src/domain/resurrection/hand_height.dart` with `HandHeight.at(int elapsedMs)` as in the design: 0 for negative input and from `handSinkEndMs` on; the burst uses `RiseProgress.at` rescaled onto its own 0 to 600 ms domain; the sink is `1 - RiseProgress.at(...)` over the sink phase. It reuses `RiseProgress` and does not copy its formula.
    - _Requirements: 7.5, 7.6, 7.7, 16.1, 16.6_

  - [ ] 5.2 Write unit tests for `HandHeight`
    - Create `test/domain/resurrection/hand_height_test.dart`: `at(0)` is 0; `at(300)` is 1 (the peak); `at(600)` is 0; every value from `playDurationMs` on, and a very large input, is 0; a negative input is 0; the midpoint of the burst is 0.5; the midpoint of the sink is 0.5; the burst uses the same curve values as `RiseProgress`.
    - _Requirements: 7.5, 7.6, 17.1_

  - [ ] 5.3 Write property test for the Hand_Height range and phases
    - **Property 10: Hand_Height stays in range and is monotonic per phase**
    - **Validates: Requirements 7.7, 7.8**
    - Create `test/domain/resurrection/hand_height_property_test.dart` over `anyIntBetween(-100000, 100000)` for the range, and two ordered values inside the burst phase and inside the sink phase for the monotonic claims.

- [ ] 6. Hand geometry
  - [ ] 6.1 Implement `StonePoint`, `HandShape` and `HandGeometry`
    - Create `lib/src/domain/resurrection/stone_point.dart`, `hand_shape.dart` and `hand_geometry.dart` as in the design: `HandGeometry.at({width, height, elapsedMs})` returns an invisible empty `HandShape` while `HandHeight.at` is 0 or the size is not usable, else the two wrist points on the ground line, the two palm corners and five fingertips, all inside `[0, width] x [0, height]`. Value types with value equality. No `dart:ui`.
    - _Requirements: 9.3, 9.4, 16.1, 16.2_

  - [ ] 6.2 Write unit tests for `HandGeometry`
    - Create `test/domain/resurrection/hand_geometry_test.dart`: no points and `visible` false at 0 ms and from `handSinkEndMs` on; at `handBurstEndMs` the five fingertips share one y and the wrist points sit on the ground line (`y == height`); the points are centered on the stone; a non-finite or non-positive size returns the invisible empty shape; value equality of the shapes.
    - _Requirements: 9.3, 9.4, 17.1_

  - [ ] 6.3 Write property test for the Hand inside the stone
    - **Property 15: The Hand stays inside the Stone_Area**
    - **Validates: Requirements 7.7, 9.3, 9.4**
    - Create `test/domain/resurrection/hand_geometry_property_test.dart` over `anyStoneWidth`, `anyStoneHeight` and `anyElapsedMs`: every point of `HandGeometry.at` lies in `[0, width] x [0, height]`. The test targets the pure function, never `HandPainter`.

- [ ] 7. Clods
  - [ ] 7.1 Implement `Clod`, `ClodFrame`, `ClodPathGenerator` and `ClodPath`
    - Create `lib/src/domain/resurrection/clod.dart`, `clod_frame.dart` (plain `double x, y, diameter` and `bool visible`, no `dart:ui`), `clod_path_generator.dart` and `clod_path.dart` as in the design. `ClodPathGenerator.generate(graveId)` seeds a `StableRandom` from `StableHash.of(graveId)` and returns 4 to 7 Clods, each with a launch angle, a `launchMs` inside the burst, a positive `flightMs`, a peak height fraction and a size from 2 to 8, and every `launchMs + flightMs` is at most `PlayTiming.handSinkEndMs`. `ClodPath.at({clod, stoneArea width and height, elapsedMs})` returns not visible outside the flight window and otherwise a parabolic arc whose whole circle is clamped inside the Stone_Area. Integer arithmetic only for the hash and the random sequence. Imports only `dart:math` and Domain files.
    - _Requirements: 8.1, 8.2, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9, 16.1, 16.2_

  - [ ] 7.2 Write unit tests for `ClodPathGenerator`
    - Create `test/domain/resurrection/clod_path_generator_test.dart`: two pinned Grave ids give two different lists that are each stable (pinned count and first Clod values, equal on the VM and on the web); the count is 4 to 7 across a sample of 200 ids; every Clod lands at or before `handSinkEndMs`; `launchMs` is inside the burst; `Clod` has value equality.
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.8, 8.9, 17.1_

  - [ ] 7.3 Write unit tests for `ClodPath`
    - Create `test/domain/resurrection/clod_path_test.dart`: a Clod before its launch and after its landing is not visible; at the midpoint of its flight a Clod sits at its peak height above the ground line; at launch and at landing it sits on the ground line (`y == height` minus its radius at most); the position and size are finite; a Clod near the stone edge stays inside after the clamp.
    - _Requirements: 8.5, 8.6, 8.7, 8.8, 17.1_

  - [ ] 7.4 Write property test for Clod determinism
    - **Property 11: The same Grave id always gets the same Clods**
    - **Validates: Requirements 8.2, 8.3**
    - Create `test/domain/resurrection/clod_determinism_property_test.dart` over `anyGraveId`.

  - [ ] 7.5 Write property test for Clod bounds
    - **Property 12: Clods stay inside their bounds**
    - **Validates: Requirements 8.4**
    - Create `test/domain/resurrection/clod_bounds_property_test.dart`: the count is 4 to 7, every `flightMs` is positive and every `sizePx` is from 2 to 8.

  - [ ] 7.6 Write property test for the Clod path inside the stone
    - **Property 13: Clod_Path stays inside the Stone_Area**
    - **Validates: Requirements 8.6, 9.4**
    - Create `test/domain/resurrection/clod_path_inside_property_test.dart` over `anyGraveId`, `anyStoneWidth`, `anyStoneHeight` and `anyElapsedMs`: every visible frame's circle lies in `[0, width] x [0, height]`.

  - [ ] 7.7 Write property test for the Clod flight window
    - **Property 14: Clods report not-visible outside their flight window**
    - **Validates: Requirements 8.7**
    - Create `test/domain/resurrection/clod_window_property_test.dart`: for elapsed times strictly before `launchMs` or strictly after `launchMs + flightMs`, `visible` is false.

- [ ] 8. Epitaph footprint
  - [ ] 8.1 Let `ArchEpitaph.rectFor` measure a given text
    - Calibration needs the real rectangle of "RISEN". Edit `lib/src/ui/arch_epitaph.dart` only as far as this needs: add the optional parameter `String? text` to `ArchEpitaph.rectFor` and to the private `_layout`, defaulting to `GraveyardCopy.epitaph` ("R.I.P.") so every existing call and test is unchanged. The widget `build` is changed later, in task 16.1.
    - _Requirements: 11.4, 11.5, 11.8_

  - [ ] 8.2 Implement `EpitaphFootprint` with the provisional metrics
    - Create `lib/src/domain/resurrection/epitaph_footprint.dart` as in the design: the constants `archRise` 140, `baseFontSize` 20, `letterSpacing` 2, `lineHeightPerFontPx` 1.5, `ripAdvancePerFontPx` 3.6 and `risenAdvancePerFontPx` 3.4 (provisional upper bounds), and `forStone({stoneWidth, textScale})` returning the `KeepOutRect` that encloses the per-text rectangles of "R.I.P." and "RISEN". Each per-text rectangle calls the real `ArchFit.positionFor` and builds the rectangle like `ArchEpitaph._layout` does (centered, width clamped to the stone, height scaled with the fitted font size). Unusable input returns the zero rectangle at the origin. Never throws. Imports only `dart:math`, `arch_fit.dart` and `keep_out_rect.dart`.
    - _Requirements: 7.17, 16.1, 16.2_

  - [ ] 8.3 Write the calibration tests and calibrate the metrics
    - Create `test/ui/epitaph_footprint_cover_test.dart` with three tests. The constants test: `EpitaphFootprint.archRise`, `baseFontSize` and `letterSpacing` equal `ArchEpitaph.archRise`, `baseFontSize` and `letterSpacing`. The cover test: for stone widths 120 to 400 in steps of 20 and text scales 1.0 to 2.0 in steps of 0.25, `EpitaphFootprint.forStone` covers both `ArchEpitaph.rectFor(text: 'R.I.P.')` and `ArchEpitaph.rectFor(text: 'RISEN')` (left and top at most, right and bottom at least those of each real rectangle). The equality test: a rectangle built from `ArchFit.positionFor` with the real measured width and line height, the way `ArchEpitaph._layout` does it, has the same `top` and `fontSize` as the model whenever the model's metrics equal the measured ones (checked with metrics set to the measured values).
    - Calibrate: measure "R.I.P." and "RISEN" with `TextPainter` and the Creepster style at 20 px, round the advance sums and the line height up, and write the smallest numbers that make the cover test pass into `epitaph_footprint.dart`.
    - If the cover test fails, RAISE the model's metrics (the advance and line-height constants) until it passes. NEVER weaken the cover test (no looser tolerance, no narrower grid, no skipped width or scale, no dropped text) and NEVER weaken the margin test of task 9.2. The 16 px minimum box height and the 8 px gap stay as they are.
    - _Requirements: 7.17, 11.4, 11.5, 11.6, 17.1_

  - [ ] 8.4 Write unit tests for `EpitaphFootprint`
    - Create `test/domain/resurrection/epitaph_footprint_test.dart` with the numbers pinned to the calibrated metrics from task 8.3 (the provisional worked values of the design, a 120 by 160 stone at scale 1.0 with left 18, top 22.16, right 102 and bottom 55.48, and at scale 2.0 with bottom 99.03, are replaced by the calibrated values and written to two decimals): the union rectangle for those two cases; the rectangle never leaves `[0, stoneWidth]` horizontally; the union contains both per-text rectangles; a non-finite, zero or negative input returns the zero rectangle; the rectangle is deterministic.
    - _Requirements: 7.17, 17.1_

- [ ] 9. Rising ghost box
  - [ ] 9.1 Implement `GhostBox` and `RisingGhostBox`
    - Create `lib/src/domain/resurrection/ghost_box.dart` and `rising_ghost_box.dart` as in the design: the constants `epitaphGapPx` 8, `minTravelPx` 8, `minBoxHeightPx` 16 and `aspect` 1.2; `RisingGhostBox.at({width, height, textScale, elapsedMs})` builds the natural box (half the stone width wide, `min(width * 0.5 * aspect, height * 0.7)` tall, centered), shrinks it with `boxH = min(naturalH, height - endTop - minTravelPx)` where `endTop = EpitaphFootprint.forStone(...).bottom + epitaphGapPx`, scales the width by the same factor, moves the top from `height - boxH` to `endTop` over `PlayTiming.ghostRiseStartMs` to `ghostRiseEndMs` with the `RiseProgress` curve rescaled like `HandHeight` does, holds it until the end of the play, and returns the zero-area hidden box on the bottom edge when `boxH < minBoxHeightPx` and the all-zero hidden box for unusable input. `visible` is true from `risingGhostStartMs` to `playDurationMs`. Never throws.
    - _Requirements: 7.10, 7.16, 7.17, 9.4, 16.1, 16.2_

  - [ ] 9.2 Write unit tests for `RisingGhostBox`
    - Create `test/domain/resurrection/rising_ghost_box_test.dart`: `visible` is false before `risingGhostStartMs` and true from there to `playDurationMs`; the box is centered; at 600 ms and before, its bottom edge rests on the base of the stone; from 2140 ms to 2800 ms its top is exactly the epitaph bottom plus 8; at 1370 ms its top is halfway between the two; the worked example of a 120 by 160 stone at scale 1.0 (box 60 by 72, top 88 at 600 ms, 75.74 at 1370 ms and 63.48 at 2140 ms, all pinned to the calibrated metrics of task 8.3) and of a 120 by 160 stone at scale 2.0 (a shrunk box, start top above end top by at least 8); the extreme case, a 120 by 100 stone at scale 2.0, returns the zero-area hidden box on the bottom edge; NaN, infinite, zero and negative inputs return the all-zero hidden box.
    - The margin test: over a grid of widths 120 to 400 in steps of 20, heights 160 to 480 in steps of 40 and text scales 1.0 to 2.0 in steps of 0.25, the box height is at least 16 and the box is never the zero-area case. NEVER weaken the margin test, and keep the 16 px minimum and the 8 px gap. If it fails with the calibrated metrics, do not change the test, the 16 px minimum or the gap: stop and report the failing size and scale to the user.
    - _Requirements: 7.10, 7.16, 7.17, 17.1_

  - [ ] 9.3 Write property test for the box inside the stone
    - **Property 16: The Rising_Ghost box stays inside the Stone_Area**
    - **Validates: Requirements 7.10, 9.4**
    - Create `test/domain/resurrection/rising_ghost_box_property_test.dart` with this first test over `anyStoneWidth`, `anyStoneHeight`, `anyTextScale` and `anyElapsedMs`: `0 <= left`, `0 <= top`, `left + width <= stoneWidth`, `top + height <= stoneHeight`, positive `width` and `height`, and `height >= RisingGhostBox.minBoxHeightPx`.

  - [ ] 9.4 Write property test for the rise and the hold
    - **Property 17: The Rising_Ghost box rises and then holds still**
    - **Validates: Requirements 7.10, 7.16, 7.17**
    - Add this test to `test/domain/resurrection/rising_ghost_box_property_test.dart` with its own `RunCounter`, over the sizes, the scale and two ordered times `a <= b` from `anyIntBetween(-500, 3300)`: the top at `b` is at most the top at `a`; `left`, `width` and `height` are equal at `a` and `b`; the tops are equal for `a, b >= ghostRiseEndMs`; the top at or before `ghostRiseStartMs` equals `height - boxHeight`; the top at or after `ghostRiseEndMs` equals the `EpitaphFootprint` bottom plus 8; the start top exceeds the end top by at least 8.

  - [ ] 9.5 Write property test for the epitaph never covered
    - **Property 18: The Rising_Ghost box never covers the epitaph**
    - **Validates: Requirements 7.17**
    - Add this test to `test/domain/resurrection/rising_ghost_box_property_test.dart` with its own `RunCounter`, over the sizes, the scale and elapsed times from `anyIntBetween(PlayTiming.ghostRiseEndMs, PlayTiming.playDurationMs)`: the box and the `EpitaphFootprint.forStone` rectangle share no area (`box.top >= epitaph.bottom`).

- [ ] 10. Checkpoint - Domain complete
  - Run in `apps/graveyard`: `flutter analyze` (zero issues), `flutter test` (all graveyard tests), and `flutter test --platform chrome test/domain test/data` (the domain and data tests in Chrome, so every score, path and box is equal on the VM and on the web).
  - From the repository root, confirm `git status --porcelain -- pubspec.lock pubspec.yaml apps/graveyard/pubspec.yaml packages/coffin_core apps/hauntagotchi tool` prints nothing (`pubspec.lock` and `packages/coffin_core` unchanged, Hauntagotchi and `tool/` unchanged, no new package; this also catches new untracked files).
  - Fix any failure at its cause. Create no file outside the repository, including `/tmp`.
  - Ensure all tests pass, ask the user if questions arise.
  - _Requirements: 16.2, 16.7, 16.9, 17.15_

- [ ] 11. Controller
  - [ ] 11.1 Add `replaceGrave`, `raise` and `layToRest` to `GraveListController`
    - Edit `lib/src/ui/grave_list_controller.dart` as in the design. `replaceGrave(Grave)` replaces the Grave with the same id at the same list index (no re-sort, no append), removes the id from `_pendingDeletes`, adds it to `_pendingPuts`, notifies and calls `_enqueueWrite()`, so the write has the same save status and retry behavior as an added Grave; it does nothing (no write, no notification) when the id is not in the list. `raise(String id)` finds the Grave, calls `replaceGrave(RaiseRules.raise(grave, today))` and returns true, or returns false when the id is not in the list. `layToRest(String id)` calls `replaceGrave(RaiseRules.layToRest(grave))` and returns normally when the id is not in the list. The controller knows nothing about the Playing_Set.
    - _Requirements: 1.6, 1.8, 3.9, 3.11, 4.5, 4.9, 16.5, 16.6_

  - [ ] 11.2 Write tests for the controller methods
    - Create `test/ui/grave_list_controller_raise_test.dart` (a new file) with `ControllerHarness`, `FakeClock`, `MemoryRecordRepository<Grave>` and `ThrowingRecordRepository`: `raise` sets `risenOn` to the clock's Today, keeps the list index and the other Graves, and writes the record (the stored record has the `risen` key); `layToRest` clears it and the stored record has no `risen` key; `raise` of an id that is not in the list returns false, writes nothing and does not notify; `layToRest` and `replaceGrave` of a missing id do nothing and throw nothing; a failing write sets the existing save error status, keeps the new state in memory, and the retry writes it; the save status sequence equals the one of an added Grave; a Grave deleted while a write is queued is not written back by a later `replaceGrave` of the same id; a second `raise` of an already Risen Grave keeps the first date.
    - _Requirements: 1.6, 1.8, 3.9, 3.11, 4.5, 4.9, 17.7_

- [ ] 12. Checkpoint - Controller complete
  - Run in `apps/graveyard`: `flutter analyze` (zero issues), `flutter test` (all graveyard tests), and `flutter test --platform chrome test/domain test/data` (the domain and data tests in Chrome).
  - From the repository root, confirm `git status --porcelain -- pubspec.lock pubspec.yaml apps/graveyard/pubspec.yaml packages/coffin_core apps/hauntagotchi tool` prints nothing (`pubspec.lock` and `packages/coffin_core` unchanged, Hauntagotchi and `tool/` unchanged, no new package; this also catches new untracked files).
  - Fix any failure at its cause. Create no file outside the repository, including `/tmp`.
  - Ensure all tests pass, ask the user if questions arise.
  - _Requirements: 16.7, 16.9, 17.15_

- [ ] 13. Resurrection copy
  - [ ] 13.1 Add the Resurrection_Copy to `GraveyardCopy`
    - In `lib/src/ui/graveyard_copy.dart` add, with no change to any existing string (`GraveyardCopy.epitaph` stays "R.I.P."): `raiseControlText` ("Raise it"), `raiseControlLabel(name)` ("Raise <name> from the dead"), `epitaphRisen` ("RISEN"), `livingRowHeading` ("Back among the living"), `risenOnLine(date)` ("Risen on <date>", built with the existing `GraveyardCopy.date`), `layToRestText` ("Lay it back to rest"), `layToRestLabel(name)` ("Lay <name> back to rest"), `restDialogRouteName(name)` ("Lay <name> back to rest?"), `restDialogTitle(name)`, `restDialogBody(name)` (says the project goes back to the graveyard and never says anything is deleted), `restConfirmText` ("Lay it to rest"), `restCancelText` ("Keep it risen"), `repositoryLinkLabel(name)` ("Copy the repository link of <name>"), `linkCopied` ("Link copied"), `linkCopyFailed` ("That link would not copy. Try once more."), `allRisen` ("Every grave here has risen.") and `risenAnnouncement(name)` ("<name> has risen.").
    - Use only Allowed_Characters, no emoji, no time-of-day word, none of "failed", "invalid" or "your fault". Kind and a little triumphant, never shaming. No Flutter import in `graveyard_copy.dart`.
    - _Requirements: 1.1, 1.3, 4.1, 4.2, 4.4, 5.2, 5.4, 5.6, 5.7, 5.11, 5.13, 11.3, 12.4, 13.3, 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 14.7, 14.8_

- [ ] 14. Painters
  - [ ] 14.1 Implement `HandPainter` and `ClodsPainter`
    - Create `lib/src/ui/hand_painter.dart` and `lib/src/ui/clods_painter.dart`. `HandPainter` takes a `HandShape` and the colors, converts the `StonePoint` list to a `Path` (curves through the points) and draws it with a soft glow (no hard shadow); it holds no geometry logic. `ClodsPainter` takes the list of `Clod`, the elapsed milliseconds and the colors, calls `ClodPath.at` for each Clod with the Stone_Area size it is given and draws one circle per visible frame (at most 7). Both clip the canvas to the Stone_Area (`clipRect(Offset.zero & size)`) before any drawing call. Colors come from the `CoffinColorTokens` the caller passes in, with no hard-coded color. `shouldRepaint` compares the inputs.
    - _Requirements: 7.4, 8.10, 9.1, 9.2, 9.3, 13.5, 13.7_

- [ ] 15. Resurrection play
  - [ ] 15.1 Implement `ResurrectionPlay`
    - Create `lib/src/ui/resurrection_play.dart` as in the design: a `StatefulWidget` with `graveId`, `stoneSize`, `textScale`, `onEnd` and `onEpitaphRisen`. On the animated path it owns one tick `AnimationController` of `PlayTiming.playDurationMs` that runs once to the end (its completion calls `onEnd` exactly once), one epitaph fade controller of `PlayTiming.epitaphFadeMs` with an ease-in-out curve started at `epitaphFadeStartMs`, and the `reactionKey` of the `GhostLoader`. One `AnimatedBuilder` draws the Hand (`HandGeometry`), the Clods (`ClodPathGenerator` and `ClodPath`) and the Rising_Ghost from the same elapsed milliseconds; the `GhostLoader(mood: GhostMood.rising)` is built only while `RisingGhostBox.at(...).visible` is true, placed in a `Positioned` and `SizedBox` from the box, its reaction key increments once at `risingGhostStartMs`, and it is wrapped so its own loader label is not read. On the reduced-motion path (`MediaQuery.disableAnimationsOf`) it creates no ticking controller: it calls `onEpitaphRisen` at once, builds the ghost with no `onReactionEnd`, and holds one cancellable `Timer` of `playDurationMs` that calls `onEnd`. When Reduced_Motion turns on mid-play it stops the controllers, snaps to the risen state, and finishes with one `Timer` for the remaining time without a second announcement. `dispose` cancels the timer and disposes every controller with null checks; `onEnd` is guarded so it never fires after dispose or twice. A rebuild with new size or scale does not restart the play.
    - _Requirements: 7.1, 7.3, 7.9, 7.10, 7.11, 7.13, 7.14, 7.15, 9.5, 10.7, 10.8, 12.1, 12.2, 12.3, 12.7, 12.8, 13.7_

- [ ] 16. ArchEpitaph text
  - [ ] 16.1 Let the `ArchEpitaph` widget draw a given text
    - Edit `lib/src/ui/arch_epitaph.dart`: add the optional constructor parameter `String? text` and make `build` draw `text ?? GraveyardCopy.epitaph` with the same `ArchFit` search, the same scaled font size and the same single-line, inside-the-arch rules, so `rectFor` and the widget measure the same text. `ArchEpitaph()` with no text keeps drawing "R.I.P." exactly as before.
    - _Requirements: 11.3, 11.4, 11.5, 11.6, 11.8_

- [ ] 17. Tombstone
  - [ ] 17.1 Add the play layer and the epitaph switch to `GraveTombstone`
    - Edit `lib/src/ui/grave_tombstone.dart`: add the parameters `playing` (default false) and `onPlayEnd` (default null). While `playing`, add one layer to the existing stack inside the same tilted layer as the card and the cracks: `Positioned.fill` with `IgnorePointer`, `ExcludeSemantics`, `RepaintBoundary`, a `LayoutBuilder` for the Stone_Area size and a `ClipRect` around `ResurrectionPlay`, with `textScale` computed as `MediaQuery.textScalerOf(context).scale(ArchEpitaph.baseFontSize) / ArchEpitaph.baseFontSize`. The Epitaph_Text is `GraveyardCopy.epitaph` until `onEpitaphRisen` fires and `GraveyardCopy.epitaphRisen` after, passed to `ArchEpitaph(text: ...)` and to `ArchEpitaph.rectFor` for the crack keep-out area, with a 300 to 600 ms ease-in-out fade between the two (none under Reduced_Motion). `TombstoneCard` keeps `showEpitaph: false` and `coffin_core` is not edited. The semantic label, the Seance_Control, the delete control, the Crack_Band, the Keep_Out_Areas math, the column count, the tombstone width and the 3 degree tilt limit stay unchanged, and the layout size of the stone never changes during the play. The Seance_Control and the delete control stay present while playing.
    - _Requirements: 3.10, 7.1, 7.11, 7.12, 9.1, 9.2, 9.5, 9.6, 9.7, 9.8, 10.1, 10.3, 10.5, 10.6, 10.9, 11.1, 11.2, 11.3, 11.7, 12.2, 12.7, 15.4_

- [ ] 18. Seance sheet
  - [ ] 18.1 Add the Raise_Control to `SeanceSheet` and wire it from the tombstone
    - Edit `lib/src/ui/seance_sheet.dart`: `showSeanceSheet` and `SeanceSheet` get an optional `onRaise` callback (`ValueChanged<Grave>`, default null). When it is not null the sheet shows one Raise_Control with the visible label `GraveyardCopy.raiseControlText`, `Semantics(button: true, label: GraveyardCopy.raiseControlLabel(grave.name))`, a minimum size of 48 by 48, keyboard focus, Enter and Space activation, and hover, press and focus states from the theme, placed so it stays visible and reachable in every sheet state (also while the verdict is pending) at every width and text scale, inside the sheet's 560 maximum content width, scrolling and pinned close button. Activating it closes the sheet and then calls `onRaise(grave)` once (a second activation does nothing). Closing through the close button, Escape, a tap outside or a drag down never calls `onRaise`. The score, band, steps and verdict line do not change.
    - Edit `lib/src/ui/grave_tombstone.dart`: add the optional parameter `onRaise` and pass `onRaise` to `showSeanceSheet` only while the Grave is not Risen and not `playing`, so a playing Tombstone opens a sheet with no Raise_Control.
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.9, 1.10, 10.6, 13.1, 14.1, 15.2_

- [ ] 19. Living row
  - [ ] 19.1 Implement `LivingRow`
    - Create `lib/src/ui/living_row.dart` with `LivingRow` (`entries` already ordered by `LivingSplit`, `onLayToRest`), which renders nothing at all (no heading, no placeholder) when `entries` is empty, else a semantic header `GraveyardCopy.livingRowHeading` and one entry per Grave. Each entry is a private widget in the same file that shows the name, the line `GraveyardCopy.risenOnLine(risenOn)` in one semantic node, and the Lay_To_Rest_Control (visible label `GraveyardCopy.layToRestText`, semantic label `GraveyardCopy.layToRestLabel(name)`, at least 48 by 48, keyboard focus, hover, press and focus states, `FocusNode` kept so focus can return to it). A manual Grave shows no repository part. Text wraps and a name of 80 code points stays readable, with no decorative node. The row uses the same side padding and maximum width as the rest of the header, keeps every color from `CoffinColorTokens`, and stays usable at a text scale of 2.0.
    - _Requirements: 4.1, 4.2, 5.2, 5.3, 5.4, 5.8, 5.9, 5.10, 5.12, 13.1, 13.4, 13.6, 13.7, 15.3, 15.6_

- [ ] 20. Rest dialog
  - [ ] 20.1 Implement `RestDialog` and `showRestDialog`
    - Create `lib/src/ui/rest_dialog.dart` following the existing `DeleteGraveDialog` pattern: `showRestDialog(context, name)` returns a `Future<bool>` (true only on confirm). The dialog route name is `GraveyardCopy.restDialogRouteName(name)`; it names the Grave, shows `restDialogBody` (the project goes back to the graveyard, nothing is deleted), one confirm button `restConfirmText` and one cancel button `restCancelText`, each at least 48 by 48 with a semantic label. Escape and a tap outside act as cancel. Focus moves into the dialog when it opens and stays inside while it is open. It stays usable at a text scale of 2.0 with wrapping or scrolling and no clipped text, and keeps contrast through `CoffinColorTokens`. A second dialog cannot open while one is open.
    - _Requirements: 4.3, 4.4, 4.10, 13.1, 13.2, 13.3, 13.4, 13.6, 13.7, 14.7_

- [ ] 21. Repository link
  - [ ] 21.1 Implement `GraveyardClipboard`
    - Create `lib/src/ui/graveyard_clipboard.dart` with the `abstract interface class GraveyardClipboard` (`Future<void> copy(String text)`, may throw) and `SystemGraveyardClipboard`, a `const` implementation backed by `Clipboard.setData(ClipboardData(text: text))` from `package:flutter/services.dart`. No package is added.
    - _Requirements: 5.6, 5.13, 16.3_

  - [ ] 21.2 Implement `RepositoryLink` and place it in the Living_Row
    - Create `lib/src/ui/repository_link.dart` with `RepositoryLink` (`name`, `fullName`, `address`, `clipboard`). It shows the full repository name, has a semantic label `GraveyardCopy.repositoryLinkLabel(name)`, a tap target of at least 48 by 48, keyboard focus, and hover, press and focus states. Activating it calls `clipboard.copy(address)` inside a `try` and `catch` and shows `GraveyardCopy.linkCopied` on success or `GraveyardCopy.linkCopyFailed` on any thrown object, with no exception escaping and no change to the entry. Edit `lib/src/ui/living_row.dart`: `LivingRow` gets the `clipboard` parameter and each entry of a GitHub Grave with a repository address shows one `RepositoryLink`; a manual Grave shows none.
    - _Requirements: 5.5, 5.6, 5.7, 5.8, 5.13, 13.1, 13.7_

- [ ] 22. Wiring
  - [ ] 22.1 Implement `RisenAnnouncement`
    - Create `lib/src/ui/risen_announcement.dart`: a widget that exposes `GraveyardCopy.risenAnnouncement(name)` as one polite live region, once per Raise (keyed by the announcement counter of the screen), never moves keyboard focus, and does not repeat on rebuilds or when the Grave moves to the Living_Row. It has no visual output.
    - _Requirements: 12.4, 12.5, 12.6_

  - [ ] 22.2 Wire `GraveyardScene`
    - Edit `lib/src/ui/graveyard_scene.dart`: add the parameters `playingIds` (default empty), `onPlayEnd`, `onRaise` and `clipboard` and `onLayToRest`. Call `LivingSplit.split(graves: ..., playing: playingIds)` once per build, place `LivingRow` in the scrolling header below the title, notices and banners and above the rows, and pass only the graveyard rows list to `SceneLayout`, so the column count, the tombstone width, the keys and the tilt follow the existing rules. Give each `GraveTombstone` its `playing` flag, `onPlayEnd` and `onRaise`. When a Grave leaves the rows at the end of its play the gap closes with no Rise for the other Tombstones; a Grave that returns after Lay_To_Rest gets the existing Rise for graves that appear after the first list. Existing tests that build the scene keep compiling through the defaults.
    - _Requirements: 3.10, 5.1, 5.3, 6.9, 6.10, 10.8, 15.3, 15.4, 15.6_

  - [ ] 22.3 Wire `GraveyardScreen`
    - Edit `lib/src/ui/graveyard_screen.dart` as in the design. The screen owns the in-memory `Playing_Set` and the announcement counter (neither is saved). `_raise(grave)` calls `controller.raise(grave.id)`; when it returns true the id is added to the set and the counter is bumped in one `setState`; when it returns false no play starts and nothing throws. `_onPlayEnd(id)` removes the id. `_layToRest(grave)` opens `showRestDialog`, calls `controller.layToRest(id)` only on confirm, and returns focus to the Lay_To_Rest_Control that opened it while that control is in the tree. `_delete` also removes the id from the set in the same `setState`. A saved Risen Grave shows in the Living_Row with no play, and the set is empty on load and reload. The empty state follows the design: `EmptyGraveyardPanel` only when both lists are empty, and `GraveyardCopy.allRisen` instead of the graveyard rows (with no empty panel) when only the Living_Row has entries. `RisenAnnouncement` is mounted once. The existing save error banner and retry control show for a failed write of a Raise or a Lay_To_Rest.
    - _Requirements: 1.6, 1.7, 1.8, 3.10, 3.11, 4.3, 4.5, 4.6, 4.7, 4.8, 4.9, 5.11, 10.1, 10.2, 10.3, 10.4, 10.5, 10.7, 10.9, 12.4, 12.5, 12.6_

  - [ ] 22.4 Thread the clipboard from the app root
    - Edit `lib/src/ui/app_routes.dart` or `lib/main.dart`, wherever the controller and the Seance_Ai are built: build one `const SystemGraveyardClipboard()` at the root and pass it down to `GraveyardScreen` and `GraveyardScene`, with no default lower in the tree. Update any existing test that constructs these widgets only by adding the new constructor argument (a fake clipboard), without changing what it asserts.
    - _Requirements: 5.6, 16.3, 16.5_

- [ ] 23. Widget tests
  - [ ] 23.1 Add the clipboard fakes
    - Create `test/support/fake_graveyard_clipboard.dart` with `RecordingGraveyardClipboard` (records every copied text, succeeds) and `ThrowingGraveyardClipboard` (always throws).
    - _Requirements: 5.6, 5.13, 17.7_

  - [ ] 23.2 Write the painter tests with a recording canvas
    - Create `test/ui/hand_clods_painter_test.dart` with `test/support/recording_canvas.dart`: drive `HandPainter` (given `HandGeometry.at` shapes) and `ClodsPainter` at several elapsed times across the play and for several stone sizes (120 by 160, 400 by 480, 200 by 300); every recorded drawing call lies inside the Stone_Area; a `clipRect` call equal to the Stone_Area is recorded before any Hand or Clod drawing call; at most 7 circles are drawn; nothing is drawn when the Hand is not visible; `shouldRepaint` is true only when an input changes.
    - _Requirements: 8.10, 9.1, 9.2, 9.3, 17.6_

  - [ ] 23.3 Write widget tests for `ResurrectionPlay`
    - Create `test/ui/resurrection_play_test.dart` and `test/ui/resurrection_dispose_test.dart` with a small host and `tester.pump(Duration(...))` only: the Hand and the Clods paint during the first 600 ms and are gone afterwards; no `GhostLoader` before 600 ms and one from 600 ms to the end; its box rises (top at 1370 ms is between the start and end tops) and holds from 2140 ms; `onEpitaphRisen` is called once at 2140 ms; `onEnd` is called exactly once at 2800 ms and never twice; the play ends within `playDurationMs` of pumped time and no animation is left running after it (`tester.hasRunningAnimations` false); `MoodReaction.risingDurationMs` of `coffin_core` equals 2200 and `risingGhostStartMs + 2200` is at most `playDurationMs`; a rebuild with a new size or text scale does not restart the play (the elapsed time continues); disposing the widget mid-play (at 0, 300, 700 and 2300 ms) throws nothing, calls `onEnd` never, and leaves no pending timer or ticker; with `disableAnimations` true no ticking controller exists (`hasRunningAnimations` false at once), `onEpitaphRisen` is called at once, no Hand, Clod or ghost movement is drawn, and `onEnd` fires at 2800 ms; switching `disableAnimations` from false to true mid-play finishes the play at the same total time with `onEpitaphRisen` called once; the play exposes no semantic node.
    - _Requirements: 7.1, 7.9, 7.10, 7.11, 7.13, 7.14, 7.15, 10.7, 10.8, 12.1, 12.2, 12.3, 12.7, 12.8, 17.7, 17.8_

  - [ ] 23.4 Write widget tests for the `ArchEpitaph` text
    - Create `test/ui/arch_epitaph_text_test.dart` (a new file): `ArchEpitaph()` with no text draws "R.I.P." and `ArchEpitaph.rectFor` with no text returns the same rectangle as before this feature (compared with `GraveyardCopy.epitaph`); `ArchEpitaph(text: 'RISEN')` draws "RISEN" and `rectFor(text: 'RISEN')` measures the same text; "RISEN" fits inside the arch on one line (not truncated) for widths 120 to 400 in steps of 20 at the default text scale and stays on one line inside the arch up to text scale 2.0; `GraveyardCopy.epitaph` still equals "R.I.P.".
    - _Requirements: 11.3, 11.4, 11.5, 11.6, 11.8, 14.8, 17.13_

  - [ ] 23.5 Write widget tests for the tombstone during a play
    - Create `test/ui/grave_tombstone_resurrection_test.dart`: the Epitaph_Text is "R.I.P." at the start of a play, still "R.I.P." at 600 ms and "RISEN" after `epitaphFadeStartMs + epitaphFadeMs`; the fade lasts 300 to 600 ms; the crack keep-out area follows the text; the play layer is inside the tilted layer, wrapped in `IgnorePointer`, `ExcludeSemantics`, `RepaintBoundary` and `ClipRect`; a tap on the Seance_Control and on the delete control still works during the play; the Seance_Control opens a sheet with no Raise_Control while playing; the layout size, the column count, the tombstone width and the tilt are equal before, during and after the play, also at the largest tilt of 3 degrees; neighbor tombstones do not move; the semantic label of the stone is unchanged; a not playing, not Risen Tombstone shows "R.I.P." and no play layer.
    - _Requirements: 7.11, 7.12, 9.1, 9.5, 9.6, 9.7, 9.8, 10.6, 11.1, 11.2, 11.7, 15.4, 17.7_

  - [ ] 23.6 Write widget tests for the Raise_Control
    - Create `test/ui/seance_sheet_raise_test.dart` with a fake `CoffinAI`: the visible label "Raise it"; the semantic label "Raise <name> from the dead"; the tap target is at least 48 by 48; Enter and Space activate it; hover, pressed and focused states are visible; it stays visible and reachable while the verdict is pending, in the ready and fallback states, and at the widths 320, 360, 768 and 1280 and the text scales 1.0, 1.5 and 2.0; activating it closes the sheet, sets `risenOn` to Today, saves the record and starts exactly one play; two quick activations raise once; a Grave removed before the activation closes the sheet with no play and no exception; the close button, Escape, a tap outside and a drag down do not raise the Grave; the score, band, steps and verdict text on screen are unchanged by the control; a sheet opened for a playing Grave has no Raise_Control.
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 10.6, 17.7_

  - [ ] 23.7 Write widget tests for the Living_Row
    - Create `test/ui/living_row_test.dart`: the heading "Back among the living" is a semantic header; entries show the name and "Risen on <date>"; most recent `risenOn` first and ties in `GraveSorter` order; an empty list shows no row, no heading and no placeholder; a name of 80 code points renders with no overflow; one semantic node per entry text and no decorative node; a manual Grave has no Repository_Link; the Lay_To_Rest_Control has the visible label "Lay it back to rest", the semantic label "Lay <name> back to rest" and a tap target of at least 48 by 48, and reacts to focus, hover and press.
    - _Requirements: 4.1, 4.2, 5.2, 5.3, 5.4, 5.8, 5.9, 5.10, 5.12, 13.1, 17.7_

  - [ ] 23.8 Write widget tests for the Repository_Link
    - Create `test/ui/repository_link_test.dart` with the clipboard fakes: a GitHub Grave shows the full repository name; activating the link copies the repository address (the recording clipboard holds it) and shows "Link copied"; a `ThrowingGraveyardClipboard` shows "That link would not copy. Try once more.", `tester.takeException()` is null, and the Living_Entry text and controls are unchanged; the semantic label is "Copy the repository link of <name>"; the tap target is at least 48 by 48; Enter and Space activate it; a manual Grave shows no link.
    - _Requirements: 5.5, 5.6, 5.7, 5.8, 5.13, 13.1, 17.7_

  - [ ] 23.9 Write widget tests for Lay_To_Rest
    - Create `test/ui/lay_to_rest_test.dart`: activating "Lay it back to rest" opens the dialog and does not change the Grave yet; the dialog names the Grave, shows the body that says the project goes back to the graveyard and never says "delete", and shows "Lay it to rest" and "Keep it risen"; confirm clears `risenOn`, saves, moves the Grave back to the graveyard rows with the Epitaph_Text "R.I.P.", no play, and the Rise of a grave that appears after the first list; cancel, Escape and a tap outside leave the Grave Risen and unchanged; focus moves into the dialog and stays inside it while it is open, and returns to the Lay_To_Rest_Control afterwards while that control is in the tree; the route name is "Lay <name> back to rest?"; a Grave deleted before the confirm closes the dialog with no exception; a second dialog cannot open while one is open; both buttons are at least 48 by 48 with a semantic label.
    - _Requirements: 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 4.10, 13.1, 13.2, 13.3, 14.7, 17.7_

  - [ ] 23.10 Write widget tests for the whole flow on the screen
    - Create `test/ui/graveyard_resurrection_flow_test.dart` with `FakeClock`, `ControllerHarness` and a fake `CoffinAI`, driven only by `tester.pump(Duration(...))`: séance, "Raise it", the sheet closes, the record is saved with `risenOn`, one play runs, the Epitaph_Text changes from "R.I.P." to "RISEN", and at 2800 ms the Grave leaves the rows and shows in the Living_Row, the gap closes with no Rise for the others, and the whole test ends within the Play_Duration of pumped time; a saved Risen Grave on load shows in the Living_Row and starts no play, also after a second `pumpWidget` with a new controller of the same saved data (no replay); no replay after a rebuild, a new width or a changed text scale mid-play; lay to rest and raise again plays one new play; two plays on different Graves do not disturb each other; deleting a Grave mid-play stops the play with no exception and no leftover timer; the Playing_Set and the play progress are not written to the repository; when every Grave is Risen the screen shows the Living_Row and "Every grave here has risen." and no empty graveyard panel; with no Risen Grave the Living_Row is not shown; the Living_Row sits below the title and any notice or banner; a failing write of a Raise shows the existing save error banner with its retry, keeps the new state, and the retry saves it.
    - _Requirements: 1.6, 1.7, 1.8, 3.10, 3.11, 4.5, 4.7, 5.1, 5.3, 5.11, 6.10, 7.1, 7.14, 10.1, 10.2, 10.3, 10.4, 10.5, 10.7, 10.8, 10.9, 17.7, 17.8, 17.14_

  - [ ] 23.11 Write widget tests for reduced motion and the announcement
    - Create `test/ui/resurrection_reduced_motion_test.dart`: with `disableAnimations` true, a Raise shows "RISEN" on a still stone at once with `tester.hasRunningAnimations` false right after the triggering pump, with no Hand, no Clods and no moving ghost, the Grave stays in the graveyard rows for 2800 ms and then moves to the Living_Row; exactly one polite live-region node "<name> has risen." exists per Raise, with and without Reduced_Motion, it does not move keyboard focus, it does not repeat on a rebuild, and no second message is announced when the Grave moves to the Living_Row; switching `disableAnimations` from false to true mid-play stops the movement, shows "RISEN" at once, finishes the play at the same total time and announces nothing a second time.
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.8, 17.7_

  - [ ] 23.12 Write layout tests
    - Create `test/ui/resurrection_layout_test.dart`: the Raise_Control in the sheet, the Living_Row (with a name of 80 code points and a GitHub repository name), the Rest_Dialog and a running Resurrection_Play render with no overflow exception at the widths 320, 360, 768 and 1280 and the text scales 1.0 and 1.5, in `CoffinTheme.dark()` and in the daylight theme; the Living_Row and the Rest_Dialog also stay usable at 2.0 with no clipped text; the sheet keeps its content width of at most 560, its scrolling and its pinned close button; the Living_Row uses the same side padding and maximum width as the header; a long Living_Row scrolls with the rest of the header and does not trap the scroll position; the Scene_Layout column count, tombstone width and tilt limit are unchanged.
    - _Requirements: 5.10, 13.6, 15.1, 15.2, 15.3, 15.4, 15.5, 15.6, 17.9_

  - [ ] 23.13 Write semantics and contrast tests
    - Create `test/ui/resurrection_semantics_test.dart`: exact labels "Raise <name> from the dead", "Lay <name> back to rest", "Copy the repository link of <name>", the dialog route name "Lay <name> back to rest?" and the live-region text "<name> has risen."; the Living_Row heading is a header and each entry has one text node with the controls as their own nodes; the play exposes no node for the Hand, the Clods, the glows or the ghost graphic and its loader label is not read; every control of this feature has a tap target of at least 48 by 48 and a semantic label; `WcagContrast.ratio` of at least 4.5 for every text and 3.0 for every icon of the Living_Row, the Living_Entry and the Rest_Dialog against the color directly behind it, and of at least 3.0 for the Hand, the Clods and the ghost against the stone and the ground where they overlap, in the dark theme and in the daylight theme, with the colors read from `CoffinColorTokens`.
    - _Requirements: 1.3, 4.2, 5.7, 5.12, 12.4, 12.7, 13.1, 13.3, 13.4, 13.5, 13.7, 17.10_

- [ ] 24. Source-rule and copy-rule tests
  - [ ] 24.1 Write source-rule tests for the resurrection
    - Create `test/source_rules/resurrection_sources_test.dart` (the only place of this feature that reads source files with `dart:io`): no new Domain file (`lib/src/domain/raise_rules.dart`, `lib/src/domain/living_split.dart` and every file under `lib/src/domain/resurrection`) contains `package:flutter`, `dart:ui`, `dart:io`, `dart:html`, `package:coffin_core`, `package:http`, `package:hive_ce`, `DateTime.now`, `Duration` or `Timer`, and none imports anything from `ui`; each of those files has one public class and a doc comment on each public member; no file under `lib` imports `coffin_core/src` or Hauntagotchi, and no file under `lib` adds a package import outside the existing dependencies; `grave_codec.dart` contains none of "playing", "Playing_Set" or "ResurrectionPlay" and no file of this feature writes play data to storage; the `pubspec.yaml` of `apps/graveyard` still lists exactly its existing dependencies (`flutter`, `coffin_core`, `http` and the unchanged dev dependencies) and no new package, font or asset entry; the new UI files use no `Color(0x` and no `Colors.`; the new UI files hold no user-facing string literal (no `Text('` or `Text("` with a literal) because every string comes from `GraveyardCopy`; the `dispose` method of `ResurrectionPlay` mentions the cancel or dispose call of every controller and timer field the class declares; no `import` of a state-management package.
    - The check that `packages/coffin_core`, `apps/hauntagotchi`, `tool/`, every `pubspec.yaml` and `pubspec.lock` are unchanged is made with `git status --porcelain` (which prints nothing when they are unchanged and also catches new untracked files) in the final checkpoint, because a Dart test cannot read git state.
    - _Requirements: 2.6, 10.2, 16.1, 16.2, 16.3, 16.4, 16.5, 16.9, 17.11, 17.14_

  - [ ] 24.2 Write the copy-rule tests
    - Create `test/ui/resurrection_copy_test.dart` (a new file): every Resurrection_Copy string and every output of the label functions (for a few fixed names, including one of 80 code points and one with "é") uses only Allowed_Characters and contains no emoji, no time-of-day word ("morning", "afternoon", "evening", "night", "midnight", "dawn", "dusk"), none of "failed", "invalid" or "your fault", no exception text and no raw status code; the exact strings "Raise it", "RISEN", "Back among the living", "Risen on <date>", "Lay it back to rest", "Lay it to rest", "Keep it risen", "Link copied", "That link would not copy. Try once more.", "Every grave here has risen." and "<name> has risen." are pinned; the Rest_Dialog body mentions the graveyard and does not contain "delete"; `GraveyardCopy.epitaph` still equals "R.I.P."; every pre-existing string of `GraveyardCopy` is unchanged.
    - _Requirements: 11.3, 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 14.7, 14.8, 17.12_

- [ ] 25. Final checkpoint - Verification
  - Run in `apps/graveyard`: `dart format --output=none --set-exit-if-changed .`, `flutter analyze` (zero issues), `flutter test` (all graveyard tests), and `flutter test --platform chrome test/domain test/data` (the domain tests in Chrome). Check `grep -rl "dart:io" test/domain test/data` finds nothing.
  - Run `flutter test` in `packages/coffin_core` (it must pass unchanged), in `apps/hauntagotchi` and in `tool/`.
  - Run `flutter pub get --enforce-lockfile` at the repository root, and check it succeeds (no new package, so no lockfile change; the status check on the next line also covers `pubspec.lock`).
  - From the repository root, check `git status --porcelain -- pubspec.lock pubspec.yaml apps/graveyard/pubspec.yaml packages/coffin_core apps/hauntagotchi tool` prints nothing (this also catches new untracked files), and that no other spec under `.kiro/specs` changed.
  - Check `git status --short` lists only these paths: `apps/graveyard/lib`, `apps/graveyard/test` and `.kiro/specs/graveyard-resurrection`. Ignore any `DIARY.md` entry, because the user maintains that file. If it lists any other path (for example `packages/coffin_core`, `apps/hauntagotchi`, `tool/`, `pubspec.lock` or another spec), report it to the user and do not revert it.
  - Fix any failure at its cause. Create no file outside the repository, including `/tmp`.
  - Ensure all tests pass, ask the user if questions arise.
  - _Requirements: 15.5, 16.2, 16.3, 16.4, 16.7, 16.8, 16.9, 17.3, 17.14, 17.15_

## Notes

- Every test sub-task is required and none is marked optional. The project testing rules and Requirement 17.3 require unit tests for pure logic and glados property tests for numeric rules and invariants.
- Every property of the design (1 to 18) has its own sub-task, and no property is covered twice: P1 (1.4), P2 (1.5), P3 (1.6), P4 (1.7), P5 (2.3), P6 (2.4), P7 (2.5), P8 (3.3), P9 (3.4), P10 (5.3), P11 (7.4), P12 (7.5), P13 (7.6), P14 (7.7), P15 (6.3), P16 (9.3), P17 (9.4), P18 (9.5).
- The Epitaph_Footprint is calibrated in task 8.3 against `ArchEpitaph.rectFor` for "R.I.P." and "RISEN". If the cover test fails, the model's metrics are raised. The cover test of task 8.3 and the margin test of task 9.2 are never weakened, and the 16 px minimum box height and the 8 px gap stay.
- Task 8.1 adds only the optional `text` parameter to `ArchEpitaph.rectFor`, because the calibration in task 8.3 needs the real rectangle of "RISEN". The widget itself learns the parameter in task 16.1.
- Tasks 13.1, 17.1, 18.1, 19.1, 21.2, 22.2 and 22.3 edit shared UI files (`graveyard_copy.dart`, `grave_tombstone.dart`, `living_row.dart`, `graveyard_scene.dart`, `graveyard_screen.dart`), so each sits in a different wave from any other task that edits the same file.
- `LivingRow` keeps its entry widget private in `living_row.dart`, so the file holds one public class. `GraveyardClipboard` and `SystemGraveyardClipboard` live in `graveyard_clipboard.dart` as the design lists them.
- The three checkpoints (after the Domain, after the controller, at the end) each run `flutter analyze`, all graveyard tests, the Domain and data tests in Chrome, and `git status --porcelain` over `pubspec.lock`, `pubspec.yaml`, `apps/graveyard/pubspec.yaml`, `packages/coffin_core`, `apps/hauntagotchi` and `tool/`, which must print nothing.
- The play is driven in tests only by `tester.pump(duration)`. No test uses a real wait, a real clock, real Hive, the network, a file outside the repository or `/tmp`, and none depends on the time zone of the machine.
- No task edits `DIARY.md`. The final `git status` check ignores any `DIARY.md` entry and otherwise lists only `apps/graveyard/lib`, `apps/graveyard/test` and `.kiro/specs/graveyard-resurrection`.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "4.1", "8.1"] },
    { "id": 1, "tasks": ["1.2", "2.1", "3.1", "5.1", "7.1", "8.2"] },
    { "id": 2, "tasks": ["1.3", "1.4", "1.5", "1.6", "1.7", "2.2", "2.3", "2.4", "2.5", "3.2", "3.3", "3.4", "4.2", "5.2", "5.3", "6.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "8.3"] },
    { "id": 3, "tasks": ["6.2", "6.3", "8.4", "9.1"] },
    { "id": 4, "tasks": ["9.2", "9.3"] },
    { "id": 5, "tasks": ["9.4"] },
    { "id": 6, "tasks": ["9.5"] },
    { "id": 7, "tasks": ["10"] },
    { "id": 8, "tasks": ["11.1"] },
    { "id": 9, "tasks": ["11.2"] },
    { "id": 10, "tasks": ["12"] },
    { "id": 11, "tasks": ["13.1", "14.1", "16.1", "21.1"] },
    { "id": 12, "tasks": ["15.1", "19.1", "20.1", "22.1"] },
    { "id": 13, "tasks": ["17.1", "21.2"] },
    { "id": 14, "tasks": ["18.1"] },
    { "id": 15, "tasks": ["22.2"] },
    { "id": 16, "tasks": ["22.3"] },
    { "id": 17, "tasks": ["22.4"] },
    { "id": 18, "tasks": ["23.1"] },
    { "id": 19, "tasks": ["23.2", "23.3", "23.4", "23.5", "23.6", "23.7", "23.8", "23.9", "23.10", "23.11", "23.12", "23.13"] },
    { "id": 20, "tasks": ["24.1", "24.2"] },
    { "id": 21, "tasks": ["25"] }
  ]
}
```
