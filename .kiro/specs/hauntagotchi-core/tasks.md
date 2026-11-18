# Implementation Plan: hauntagotchi-core

## Overview

The plan builds Hauntagotchi's core loop bottom-up in Dart: steering line and dependency first, then the pure domain (days, habits, ghost rules, catch-up, ritual, streak, the `Haunting` aggregate), then the data layer, the `HomeController`, the UI, the route wiring, and a final verification. Each task builds on the previous ones and ends wired into the app, so no code is left orphaned.

Rules for every task:

- Edit only `apps/hauntagotchi/lib`, `apps/hauntagotchi/test`, `.kiro/specs/hauntagotchi-core`, and the three allowed edits (the two steering lines and the one `glados` line). Nothing changes in `packages/coffin_core`, `apps/graveyard`, `pubspec.lock`, the root `pubspec.yaml` or `CREDITS.md`.
- Never create files outside the repository, including `/tmp`. Scratch output goes inside the repo only if a task says so, and is deleted before the task ends.
- Doc-comment every public API. One public class per file, `snake_case.dart`. Code passes `dart format` and `flutter analyze` with zero warnings.
- `lib/src/domain` imports no Flutter library and no `dart:io`. Only `SystemClock` calls `DateTime.now()`.
- Tests under `test/domain` and `test/data` never import `dart:io`. Every test that reads source files lives in `test/source_rules/`.
- Property tests use glados 1.1.7 with web-safe generators only (no `any.int`, `any.intInRange`, `any.list`, `any.listWithLengthInRange`, string generators or `uint*`), `numRuns: 200`, a `RunCounter` that asserts the run count, and the comment header `// Feature: hauntagotchi-core, Property N: <title>` plus `// Validates: Requirements ...`.
- A task is marked done only after `flutter test` passes in `apps/hauntagotchi` (and in `tool/` for task 1.1).

## Tasks

- [x] 1. Steering line and dependency (first change of the feature)
  - [x] 1.1 Correct the state-management line in both steering files
    - In `.kiro/steering/tech.md` (line 10) and `tool/templates/app/.kiro/steering/tech.md.tmpl` (line 9), replace ``- State management: **Riverpod** (`flutter_riverpod`). No other state libraries.`` with `- State management: Flutter's built-in ChangeNotifier with ListenableBuilder. No state-management packages.`
    - Change no other line in either file. Check `git diff -U0` shows one removed and one added line per file, and `grep -rniI riverpod .kiro/steering tool/templates` finds nothing.
    - Run `flutter test` in `tool/` (template integrity, raiser and repo-guard tests) while nothing else edits `apps/`. Then run `flutter test --tags raise-check --run-skipped` in `tool/`. Both must pass.
    - _Requirements: 15.1, 15.2, 15.3, 15.4_

  - [x] 1.2 Add `glados: 1.1.7` to Hauntagotchi dev dependencies
    - In `apps/hauntagotchi/pubspec.yaml`, add exactly one line, `glados: 1.1.7`, under `dev_dependencies` after `flutter_lints`. Add no other dependency.
    - Run `flutter pub get --enforce-lockfile` at the repo root. Check `git diff --exit-code -- pubspec.lock` exits 0 and `git diff -U0 -- apps/hauntagotchi/pubspec.yaml` shows one added line. If the lock would change, stop and ask the user.
    - _Requirements: 13.8_

- [x] 2. Local days, clock and name rules
  - [x] 2.1 Implement `LocalDay`, `Clock` and `NameRules` in `lib/src/domain`
    - Create `local_day.dart` with the integer civil-calendar `epochDay`/`fromEpochDay`, `fromDateTime`, `tryParse`, `toIso`, `next`, `previous`, `addDays`, `daysUntil`, `Comparable`, and value equality. No `Duration` and no 24-hour arithmetic.
    - Create `clock.dart` (`abstract interface class Clock { DateTime now(); }`) and `name_rules.dart` (`maxLength` 40, `violation`, `normalize`, counting code points).
    - Remove `lib/src/domain/.gitkeep`.
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.6, 1.2, 13.2, 13.4_

  - [x] 2.2 Create web-safe test generators (base set)
    - Create `test/domain/support/haunt_generators.dart` with `anyIntBetween`, `anyListBetween` (built on `any.simple` and `Random.nextInt`), a `RunCounter`, `anyLocalDay` (epoch days 10957 to 47482 plus fixed edge days: leap days, month and year ends, 2026-03-08, 2026-03-29, 2026-10-25, 2026-11-01), `anyHabitName` (valid, over-40 and whitespace-only values) and `anyHealth` (extra weight on band edges).
    - Keep every generated integer far below 2^53.
    - _Requirements: 14.8_

  - [x] 2.3 Write unit tests for `LocalDay` and `NameRules`
    - Create `test/domain/local_day_test.dart` and `test/domain/name_rules_test.dart`: leap years, invalid dates, strict `tryParse`, year bounds, month ends, negative `addDays`, trimming and code-point counting at 1 and 40.
    - _Requirements: 2.2, 2.3, 2.4, 2.6, 1.2_

  - [x] 2.4 Write property test for the `LocalDay` round trip
    - **Property 1: LocalDay round trip**
    - **Validates: Requirements 2.6**
    - Create `test/domain/local_day_property_test.dart`.

  - [x] 2.5 Create test doubles in `test/support/`
    - Create `fake_clock.dart` (`FakeClock` whose time the test sets) and `throwing_record_repository.dart` (`ThrowingRecordRepository` implementing `RecordRepository`, throwing on `put` or `getAll`/`get` on demand). Neither imports `dart:io`.
    - _Requirements: 2.7, 14.9, 14.10_

- [x] 3. Habits and the habit book
  - [x] 3.1 Implement `Habit`, `HabitBook` and the result types
    - Create `habit.dart` (`isActive`, `isActiveOn`, `isCompletedOn`, equality, unmodifiable `completedDays`), `habit_rejection.dart` (enum), `habit_result.dart` (sealed), `habit_changed.dart`, `habit_rejected.dart`, `habit_book.dart` (`maxActive` 5, `suggestedMin` 3, `add` with ids `h1`, `h2`, ..., `rename`, `archive`, `complete`, `undo`, `activeCountOn`, `completedCountOn`, `anyCompletedOn`, `missingToSuggested`, `restore`).
    - Reject completion and undo for any day but Today, and reject rename, complete and undo for archived or unknown ids.
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 1.11, 1.12, 1.13, 1.14, 4.9_

  - [x] 3.2 Extend the test generators with habits, books and ghosts
    - Add `anyBook(today)` (0 to 6 habits, archive offsets, completion offsets, run through `HabitBook.restore`), `anyHabit` and `anyGhost` to `test/domain/support/haunt_generators.dart`.
    - _Requirements: 14.8_

  - [x] 3.3 Write unit tests for `HabitBook`
    - Create `test/domain/habit_book_test.dart` covering each criterion of Requirement 1 with named examples, `missingToSuggested` from 0 to 5, id uniqueness after archiving, and `restore` trimming more than 5 active habits.
    - _Requirements: 1.1 to 1.14, 14.9_

  - [x] 3.4 Write property test for rejections and the limit
    - **Property 18: Rejections change nothing and the limit holds**
    - **Validates: Requirements 1.2, 1.3, 1.8, 1.10, 1.11, 1.13**
    - Create `test/domain/habit_book_rejection_property_test.dart`.

  - [x] 3.5 Write property test for add, rename and archive
    - **Property 19: Add, rename and archive keep what they should**
    - **Validates: Requirements 1.1, 1.4, 1.5, 1.6**
    - Create `test/domain/habit_book_edit_property_test.dart`.

- [x] 4. Ghost, state derivation and balance numbers
  - [x] 4.1 Implement `Ghost`, `GhostState`, `RecentHistory`, `GhostStateRules` and `Balance`
    - Create `ghost.dart` (with `Ghost.fresh` named `Wisp`, Health 100, last settled day before Today), `ghost_state.dart` (ordered enum), `recent_history.dart`, `ghost_state_rules.dart` (bands 0 / 1-24 / 25-49 / 50-79 / 80-100 and the idle caps), `balance.dart` (`maxHealth` 100, `fullFeed` 20, `neglectLoss` 15, `freshStartHealth` 40, `candlesNeeded` 2, `qualifyingPercent` 60, `defaultGhostName`, and `feed(n, c) = (20 * c) ~/ n`).
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 5.8_

  - [x] 4.2 Write unit tests for state bands and balance constants
    - Create `test/domain/ghost_state_rules_test.dart` (band edges 0, 1, 24, 25, 49, 50, 79, 80, 100, and both caps) and `test/domain/balance_test.dart` (constants and the feed table equal the design tables).
    - _Requirements: 3.3, 3.4, 3.5, 5.8_

  - [x] 4.3 Write property test for dead if and only if Health is zero
    - **Property 5: Dead if and only if Health is zero**
    - **Validates: Requirements 3.3, 3.4, 3.5, 3.7**
    - Create `test/domain/ghost_state_dead_property_test.dart`.

  - [x] 4.4 Write property test for state monotonicity
    - **Property 6: Lower Health is never healthier**
    - **Validates: Requirements 3.6**
    - Create `test/domain/ghost_state_order_property_test.dart`.

- [x] 5. Catch-up, streak and the resurrection ritual
  - [x] 5.1 Implement `CatchUp`
    - Create `catch_up.dart` with `run(ghost, book, today)` and `settleDay(health, activeCount, completedCount)`: no-op when already current or the clock moved backward, dead ghosts only advance `lastSettledDay`, ordered day loop with early stop at Health 0, no active habit leaves Health unchanged.
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.6, 4.7, 4.8, 4.9, 5.3, 6.1, 6.2_

  - [x] 5.2 Implement `Streak`
    - Create `streak.dart` with `Streak.compute(book, today)` over all habits including archived ones, anchored on Today or yesterday.
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_

  - [x] 5.3 Implement `ResurrectionRitual` and `RitualProgress`
    - Create `ritual_progress.dart` and `resurrection_ritual.dart`: `progress` is null with no active habit, needs `min(2, activeCount)` completed active habits Today, and `apply` returns the revived ghost (Health 40, same name, `lastSettledDay` = yesterday, count + 1) or null.
    - _Requirements: 6.3, 6.4, 6.5, 6.6, 6.8_

  - [x] 5.4 Write unit tests for `CatchUp`
    - Create `test/domain/catch_up_test.dart`: fresh ghost, 5 days away equals 5 single days, 10,000 days, backward clock, no active habit, dead ghost.
    - _Requirements: 4.2, 4.3, 4.4, 4.6, 4.7, 4.8, 14.9_

  - [x] 5.5 Write unit tests for `Streak`
    - Create `test/domain/streak_test.dart`: archived habits, Today only, yesterday only, a gap, undo removing the day.
    - _Requirements: 7.1 to 7.6_

  - [x] 5.6 Write unit tests for the ritual
    - Create `test/domain/resurrection_ritual_test.dart`: one habit needs one candle, two or more need two, progress values, no active habit, and an archive that fulfils the ritual (2 active habits, 1 ticked, archive the other).
    - _Requirements: 6.3, 6.4, 6.5, 6.7_

  - [x] 5.7 Write property test for catch-up equivalence
    - **Property 7: One catch-up equals many single catch-ups**
    - **Validates: Requirements 4.2, 4.4, 14.3**
    - Create `test/domain/catch_up_equivalence_property_test.dart` with N from 0 to 60.

  - [x] 5.8 Write property test for catch-up no-ops
    - **Property 8: Catch-up is a no-op when nothing is missed**
    - **Validates: Requirements 4.3, 4.6**
    - Create `test/domain/catch_up_noop_property_test.dart`.

  - [x] 5.9 Write property test for settled days
    - **Property 9: A settled day depends only on the habits active that day**
    - **Validates: Requirements 4.8, 4.9**
    - Create `test/domain/settled_day_property_test.dart`.

  - [x] 5.10 Write property test for feeding and neglect
    - **Property 10: Feeding raises Health and neglect lowers it**
    - **Validates: Requirements 5.1, 5.3**
    - Create `test/domain/feeding_property_test.dart`.

  - [x] 5.11 Write property test for a neglect run
    - **Property 12: A neglect run from full Health**
    - **Validates: Requirements 5.5**
    - Create `test/domain/neglect_run_property_test.dart`.

  - [x] 5.12 Write property test for a fully done day
    - **Property 13: A fully done day beats a neglect day**
    - **Validates: Requirements 5.6, 5.7**
    - Create `test/domain/full_day_property_test.dart`.

  - [x] 5.13 Write property test for the streak
    - **Property 17: Streak equals the run ending Today or yesterday**
    - **Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5**
    - Create `test/domain/streak_property_test.dart`.

  - [x] 5.14 Write property test for calendar arithmetic across daylight saving
    - **Property 2: Calendar arithmetic counts calendar days**
    - **Validates: Requirements 2.3, 2.4, 14.5**
    - Create `test/domain/calendar_arithmetic_property_test.dart`; `n` from 0 to 800, including the four daylight saving dates; a catch-up over the span settles each day once.

- [x] 6. Checkpoint - Domain building blocks
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. The `Haunting` aggregate
  - [x] 7.1 Implement `Haunting` and its results
    - Create `haunting.dart`, `haunt_result.dart` (sealed), `haunt_changed.dart` (`next`, `resurrected`), `haunt_rejected.dart`. Include `open` (fresh ghost when none, then `syncTo`), `syncTo`, `liveHealth`, `history` (idle days capped at 7), `state`, `streak`, `ritual`, and `addHabit`, `renameHabit`, `archiveHabit`, `complete`, `undo`, each running the ritual check afterwards.
    - _Requirements: 3.8, 4.1, 4.2, 5.1, 5.2, 6.2, 6.4, 6.5, 6.6, 6.8_

  - [x] 7.2 Extend the test generators with operations and day plans
    - Add the sealed `Operation` set, a pure `applyOp(Haunting, Operation)` helper, `anyDayPlan` (`n` 1 to 5, `c` 0 to `n`) and `normalizeSteady` to `test/domain/support/haunt_generators.dart`.
    - _Requirements: 14.8_

  - [x] 7.3 Write property test for time of day
    - **Property 3: Time of day does not matter**
    - **Validates: Requirements 2.2, 2.5, 14.4**
    - Create `test/domain/time_of_day_property_test.dart`.

  - [x] 7.4 Write property test for Health range
    - **Property 4: Health stays in range**
    - **Validates: Requirements 3.2, 4.7, 14.2**
    - Create `test/domain/health_range_property_test.dart`, with jumps of up to 10,000 days.

  - [x] 7.5 Write property test for complete then undo
    - **Property 11: Complete then undo restores the day**
    - **Validates: Requirements 1.7, 1.9, 1.12, 5.2, 7.6**
    - Create `test/domain/complete_undo_property_test.dart`.

  - [x] 7.6 Write property test for a dead ghost
    - **Property 15: A dead ghost stays dead until the ritual**
    - **Validates: Requirements 6.1, 6.2, 14.6**
    - Create `test/domain/dead_ghost_property_test.dart`.

  - [x] 7.7 Write property test for the ritual
    - **Property 16: The ritual brings the ghost back once**
    - **Validates: Requirements 6.4, 6.5, 6.6, 6.8**
    - Create `test/domain/ritual_property_test.dart`, including the archive-fulfils-ritual case.

  - [x] 7.8 Write property test for Live Health
    - **Property 23: Live Health is what the next day settles**
    - **Validates: Requirements 4.2, 5.1, 5.2**
    - Create `test/domain/live_health_property_test.dart`.

  - [x] 7.9 Write property test for steady effort
    - **Property 14: Steady effort keeps the ghost out of danger**
    - **Validates: Requirements 5.4**
    - Create `test/domain/steady_effort_property_test.dart` using `normalizeSteady`.

  - [x] 7.10 Write unit tests for `Haunting` and the worked 14-day examples
    - Create `test/domain/haunting_test.dart` (open with and without a ghost, `syncTo`, `liveHealth`, state with idle caps, archive after a tick, add lowers today's feed) and add the tracks A and B of the design's 14-day example to `test/domain/balance_test.dart`, reproducing the Health values exactly.
    - _Requirements: 3.8, 5.4, 5.5, 5.6, 5.7, 5.8, 6.4_

- [x] 8. Checkpoint - Domain complete
  - Ensure all tests pass, ask the user if questions arise. Also run `flutter test --platform chrome test/domain` in `apps/hauntagotchi` once the data tests exist (task 9) and again at task 15.

- [x] 9. Data layer
  - [x] 9.1 Implement `SystemClock`, `HabitCodec` and `GhostCodec` in `lib/src/data`
    - Create `system_clock.dart` (the only `DateTime.now()` call), `habit_codec.dart` and `ghost_codec.dart` implementing `RecordCodec`, encoding only JSON-safe values with days as sorted `YYYY-MM-DD` strings, and throwing `FormatException` for every violation in the design's decode table.
    - Remove `lib/src/data/.gitkeep`.
    - _Requirements: 2.7, 8.2, 8.3, 8.4, 8.5, 8.9_

  - [x] 9.2 Implement `HauntStorage`
    - Create `haunt_storage.dart` with `open(StorageOpener)` using box names `hauntagotchi_habits` and `hauntagotchi_ghost`, `currentVersion` 1, key `ghost`, `isPersistent` true only when both repositories are persistent, and `close`.
    - _Requirements: 8.1, 8.6, 9.1_

  - [x] 9.3 Write unit tests for the codecs
    - Create `test/data/habit_codec_test.dart` and `test/data/ghost_codec_test.dart`: every failure in Requirement 8.5 (empty and over-40 names, Health -1 and 101, `2026-02-30`, negative count, missing field, wrong type, `archived` before `created`) and the exact key sets. No `dart:io` import.
    - _Requirements: 8.2, 8.5, 8.9, 14.9_

  - [x] 9.4 Write property tests for the codec round trips
    - **Property 20: Habit codec round trip**
    - **Property 21: Ghost codec round trip**
    - **Validates: Requirements 8.2, 8.3, 8.4**
    - Create `test/data/codec_round_trip_property_test.dart`, including a trip through `jsonEncode` and `jsonDecode`.

  - [x] 9.5 Write property test for corrupt records
    - **Property 22: Corrupt records are rejected**
    - **Validates: Requirements 8.5**
    - Create `test/data/codec_corruption_property_test.dart`.

  - [x] 9.6 Write unit tests for `HauntStorage`
    - Create `test/data/haunt_storage_test.dart` with a fake `StorageOpener`: box names, version 1, `isPersistent` from both repositories.
    - _Requirements: 8.1, 9.1_

- [x] 10. Home controller
  - [x] 10.1 Implement `HomeController`, `HomeStatus` and `SaveStatus`
    - Create `home_status.dart`, `save_status.dart` and `home_controller.dart` in `lib/src/ui` (a `ChangeNotifier`, no package). Include `load`, `refresh`, `addHabit`, `renameHabit`, `archiveHabit`, `toggle`, `retrySave`, `dismissWelcome`, `disposeStorage`, `welcomeBack`, `isPersistent`.
    - Sync with the Clock before every action. If the day changed, notify and ignore that tap. Change memory first, notify, then write changed habits and the ghost, and report saved only after the writes finish. Keep state and show a retry on a failed write. Use no timer. Guard notifications after dispose.
    - _Requirements: 4.1, 4.5, 8.6, 8.7, 8.8, 9.1, 10.10, 11.5, 11.7_

  - [x] 10.2 Write unit tests for `HomeController`
    - Create `test/ui/home_controller_test.dart` with `FakeClock`, `MemoryRecordRepository` and `ThrowingRecordRepository`: load with no data and with habits only, resume, day change ignoring a tap, save order, failed write and retry, memory fallback, load error and retry.
    - _Requirements: 4.1, 8.6, 8.7, 8.8, 9.1, 11.7, 14.9_

- [x] 11. Home screen widgets
  - [x] 11.1 Implement `HauntCopy`
    - Create `lib/src/ui/haunt_copy.dart` holding every user-facing string (state words, nudge, memory notice, save error, ritual text, welcome back, rejection reasons), short, spooky, kind, with no "failed" and no "your fault".
    - _Requirements: 9.4, 11.6, 12.7_

  - [x] 11.2 Implement `GhostPanel` and `HabitTile`
    - Create `ghost_panel.dart` (`GhostLoader` with caption, Health number and bar, state in words plus a per-state icon, Streak line, one semantics label such as `Wisp, health 85 of 100, thriving`) and `habit_tile.dart` (48 by 48 check-off control with the label `<name>, done today` or `<name>, not done yet`, a 48 by 48 menu for Rename and Archive, hover and press states).
    - Use only `CoffinTheme` tokens for color.
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 12.1, 12.2, 12.3, 12.6_

  - [x] 11.3 Implement `HabitNameDialog` and `ArchiveDialog`
    - Create `habit_name_dialog.dart` (add and rename, keeps typed text, shows the rejection reason) and `archive_dialog.dart` (archives only after the user confirms).
    - _Requirements: 10.5, 10.6, 10.7, 12.1, 12.2_

  - [x] 11.4 Implement the state panels
    - Create `empty_habits_panel.dart` (no habit or only archived ones), `resurrection_panel.dart` (names the ghost, ritual in one paragraph, progress such as `1 of 2 candles lit`, Resurrection_Count, and "add a habit" text when none is active), `memory_notice.dart`, `save_error_banner.dart` (Retry) and `load_error_view.dart` (Retry).
    - _Requirements: 6.7, 9.2, 9.3, 9.4, 8.8, 11.1, 11.2, 11.3, 11.7_

  - [x] 11.5 Implement `HomeScreen`
    - Create `home_screen.dart`: `FogBackground`, centered column of max width 560 in a `ListView`, `ListenableBuilder` on the controller, loading `GhostLoader` with a caption, ghost panel, habit list, add control that shows a readable reason when 5 habits exist, the nudge below 3 habits, the dead state that keeps the habit list usable, the welcome-back message, and a `WidgetsBindingObserver` that calls `refresh()` on resume. No moving effect when `MediaQuery.disableAnimations` is true.
    - _Requirements: 1.14, 4.1, 10.1, 10.2, 10.3, 10.4, 10.5, 10.8, 10.9, 10.10, 11.3, 11.4, 11.5, 12.4_

- [x] 12. Wiring and cleanup
  - [x] 12.1 Wire the app and remove the placeholder
    - Change `lib/src/ui/app_routes.dart` to `buildAppRoutes(HomeController)` with `/` showing `HomeScreen` and `/gallery` unchanged. Make `HauntagotchiApp` take a required `HomeController`, call `load()` in `initState` and `disposeStorage()` in `dispose`. Update `main.dart` to build the controller with `SystemClock` and `StorageOpener(initializer: () => hiveFlutterInitializer('hauntagotchi'))`.
    - Delete `lib/src/ui/placeholder_screen.dart` and `test/ui/placeholder_screen_test.dart`. Update `test/ui/app_routes_test.dart` and `test/ui/gallery_route_test.dart` so the existing tests compile and pass against the Home_Screen. Import only `package:coffin_core/coffin_core.dart` from `coffin_core`.
    - _Requirements: 8.1, 10.1, 10.11, 13.1, 13.3, 13.6_

- [x] 13. UI tests
  - [x] 13.1 Write widget tests for the screen states
    - Create `test/ui/home_screen_test.dart` using `FakeClock` and `MemoryRecordRepository` (never real Hive): loading, empty (no habit and only archived), normal, dead with progress and count, dead with no active habit, welcome back, Memory_Notice shown and hidden, save error banner, load error with retry, nudge below 3 habits.
    - _Requirements: 9.2, 9.3, 11.1, 11.2, 11.3, 11.5, 11.7, 1.14, 14.10_

  - [x] 13.2 Write widget tests for the interactions
    - Create `test/ui/home_screen_actions_test.dart`: check-off and undo update Live_Health, state and Streak; add limit disables the control with a readable reason; invalid name keeps the text and shows the reason; archive needs confirmation; rename; the dead state keeps the habit list usable and resurrects through check-off.
    - _Requirements: 10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 11.4, 14.11_

  - [x] 13.3 Write widget tests for layout, accessibility and reduced motion
    - Create `test/ui/home_screen_a11y_test.dart`: no overflow at 360 px width and text scale 1.5, tap targets of at least 48 by 48, semantic labels (check-off and ghost area), state shown by words and icon, and `disableAnimations` giving the still `GhostLoader` frame.
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 14.11_

  - [x] 13.4 Write route tests
    - Extend `test/ui/app_routes_test.dart` and `test/ui/gallery_route_test.dart`: `/` shows `HomeScreen`, `/gallery` shows `CryptGallery` and its back control returns to `/`, the not-found page still works.
    - _Requirements: 10.11, 14.12_

  - [x] 13.5 Write the copy test
    - Create `test/ui/haunt_copy_test.dart`: no string in `HauntCopy` contains "failed" or "your fault".
    - _Requirements: 11.6, 12.7_

- [x] 14. Source-rule tests
  - [x] 14.1 Write source-rule tests for the domain and the test tree
    - Create `test/source_rules/domain_sources_test.dart`: no `package:flutter`, no `dart:io`, no `DateTime.now` under `lib/src/domain`; no `DateTime.now` outside `system_clock.dart`; no `Timer` or `Timer.periodic` anywhere in `lib`; no import of `coffin_core/src`, Graveyard or `dart:io` outside allowed files; no `dart:io` in any file under `test/domain` or `test/data`. This folder is the only place that reads source files with `dart:io`.
    - _Requirements: 2.1, 4.5, 13.1, 13.2, 13.3, 14.1_

  - [x] 14.2 Write the generator-rules test
    - Create `test/source_rules/generator_rules_test.dart`: none of `any.int`, `any.intInRange`, `any.list`, `any.listWithLengthInRange`, string generators or `uint*` appears under `test/`.
    - _Requirements: 14.8_

- [x] 15. Final verification
  - [x] 15.1 Run the full verification plan
    - In `apps/hauntagotchi`, run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` (zero issues), `flutter test`, and `flutter test --platform chrome test/domain test/data`. Check `grep -rl "dart:io" test/domain test/data` finds nothing.
    - Run `flutter test` in `packages/coffin_core` and in `tool/`, then `flutter test --tags raise-check --run-skipped` in `tool/`.
    - Run `flutter pub get --enforce-lockfile` at the repo root and check `git diff --exit-code -- pubspec.lock`. Check `git status --short` lists only the two steering files, `apps/hauntagotchi/pubspec.yaml`, files under `apps/hauntagotchi/lib` and `apps/hauntagotchi/test`, and `.kiro/specs/hauntagotchi-core`.
    - Fix any failure at its cause. Create no file outside the repository, including `/tmp`.
    - _Requirements: 13.1, 13.2, 13.3, 13.5, 13.6, 13.7, 13.8, 14.1, 14.13, 15.2, 15.3, 15.4_

## Notes

- Test sub-tasks are not marked optional: the project testing rules and Requirement 14 require unit tests for pure logic and glados property tests for numeric rules.
- Every property in the design (1 to 23) has its own sub-task: P1 (2.4), P2 (5.14), P3 (7.3), P4 (7.4), P5 (4.3), P6 (4.4), P7 (5.7), P8 (5.8), P9 (5.9), P10 (5.10), P11 (7.5), P12 (5.11), P13 (5.12), P14 (7.9), P15 (7.6), P16 (7.7), P17 (5.13), P18 (3.4), P19 (3.5), P20 and P21 (9.4), P22 (9.5), P23 (7.8).
- Task 1.1 must be the first change. Task 1.2 follows it so the raise-check in 1.1 runs before the pubspec edit.
- This workflow only creates the plan. Start execution by opening this file and choosing "Start task" on a task.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2"] },
    { "id": 2, "tasks": ["2.1"] },
    { "id": 3, "tasks": ["2.2", "2.3", "2.5", "3.1", "4.1", "11.1"] },
    { "id": 4, "tasks": ["2.4", "3.2", "3.3", "4.2", "4.3", "4.4", "5.1", "5.2", "5.3", "9.1"] },
    { "id": 5, "tasks": ["3.4", "3.5", "5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "5.10", "5.11", "5.12", "5.13", "5.14", "7.1", "9.2", "9.3", "9.4", "9.5"] },
    { "id": 6, "tasks": ["7.2", "7.10", "9.6", "10.1", "14.1"] },
    { "id": 7, "tasks": ["7.3", "7.4", "7.5", "7.6", "7.7", "7.8", "7.9", "10.2", "11.2", "11.3", "11.4"] },
    { "id": 8, "tasks": ["11.5"] },
    { "id": 9, "tasks": ["12.1"] },
    { "id": 10, "tasks": ["13.1", "13.2", "13.3", "13.4", "13.5", "14.2"] },
    { "id": 11, "tasks": ["15.1"] }
  ]
}
```
