# Implementation Plan: graveyard-scene

## Overview

The plan builds the Graveyard night scene bottom-up in Dart. The pure scene math comes first, each unit with its unit tests and its glados property tests: the stable hash, the star field and twinkle, the layout, the new-grave diff, weathering and rise, the arch fit, the description cleaner and thousands formatter, the crack generator, and the tombstone facts. Then come the copy changes, the painters, the new tombstone, the scene and the screen wiring, the widget tests, the source-rule tests, and a final verification. Each task builds on the previous ones and ends wired into the app, so no code is left orphaned. No package, asset or lock change is part of this plan.

Rules for every task:

- Edit only `apps/graveyard/lib`, `apps/graveyard/test` and `.kiro/specs/graveyard-scene`. Nothing changes in `packages/coffin_core`, `apps/hauntagotchi`, `tool/`, `tool/templates`, any `pubspec.yaml`, `pubspec.lock`, `CREDITS.md` or `.github/`. `DIARY.md` is not a protected file, but no task here edits it.
- Never create files outside the repository, including `/tmp`. Scratch output goes inside the repo only if a task says so, and is deleted before the task ends.
- Doc-comment every public API in `lib/src/domain`. One public class per file, `snake_case.dart`. Code passes `dart format` and `flutter analyze` with zero warnings.
- The scene math lives in `lib/src/domain/scene`. It imports no Flutter library, no `dart:ui`, no `dart:io`, no `dart:html`, no `package:http` and no `package:hive_ce`, calls no `DateTime.now()`, never reads `hashCode`, and uses colors as plain integers or numbers only. `crack_generator.dart`, `stable_hash.dart` and `stable_random.dart` import no `dart:math`.
- Apps import only `package:coffin_core/coffin_core.dart`, never files under `coffin_core/lib/src`. Graveyard never imports Hauntagotchi.
- Tests mirror `lib/` without `src/`: `lib/src/domain/scene/x.dart` is tested in `test/domain/scene/x_test.dart`, and `lib/src/ui/x.dart` in `test/ui/x_test.dart`. Tests under `test/domain` and `test/data` never import `dart:io`. Every test that reads source files lives in `test/source_rules/`.
- Widget and controller tests use `FakeClock`, `FakeGitHubClient`, `MemoryRecordRepository<Grave>` and `ControllerHarness`, never real Hive and never the network. No test depends on the time zone of the machine (inject `FixedOffsetZone`). Animations are advanced with `pump(duration)`, never with a real wait.
- Property tests use glados 1.1.7 with web-safe generators only (no `any.int`, `any.intInRange`, `any.list`, `any.listWithLengthInRange`, string generators or `uint*`), built on `anyIntBetween` and `anyListBetween` from `test/domain/support/grave_generators.dart`, every generated integer below 2^53, `numRuns: 200`, a `RunCounter` that asserts the run count, and the comment header `// Feature: graveyard-scene, Property N: <title>` plus `// Validates: Requirements ...`.
- Every test task (unit, property, widget, source rule) is required. None is optional.
- A task is marked done only after `flutter test` passes in `apps/graveyard`.

## Tasks

- [x] 1. Stable hash and stable random
  - [x] 1.1 Implement `StableHash` and `StableRandom`
    - Create `lib/src/domain/scene/stable_hash.dart` (`StableHash.of(String)`: start `h = 7`, then for each UTF-16 code unit `c`, `h = (h * 31 + c) % 2147483648`, using `%` and not `&`) and `lib/src/domain/scene/stable_random.dart` (`StableRandom(int seed)`: state `(seed % 2147483646) + 1`, `nextInt(max)` sets `state = state * 48271 % 2147483647` and returns `state % max`, and returns 0 when `max < 1`). Every intermediate value stays below 2^53. No `dart:math`, no `hashCode`.
    - Remove nothing else. Doc-comment both public types.
    - _Requirements: 7.18, 7.19, 7.28, 15.3, 15.7_

  - [x] 1.2 Write unit tests for `StableHash` and `StableRandom`
    - Create `test/domain/scene/stable_hash_test.dart` and `test/domain/scene/stable_random_test.dart`: fixed strings give fixed integers (the empty string, `g1`, a 200-character string, a non-ASCII string, a string with a lone surrogate), the hash is below 2^31, the same input gives the same output, `StableRandom` gives a fixed sequence for a fixed seed (including seed 0 and a negative seed), every value stays in `[0, max)`, and `max` of 0 or less gives 0. Pin the values so the same test passes on the VM and with `--platform chrome`.
    - _Requirements: 7.18, 7.19, 7.28_

- [x] 2. Night sky math
  - [x] 2.1 Implement `Star`, `StarField` and `Twinkle`
    - Create `star.dart` (value equality; `dx`, `dy`, `radius`, `phaseMs`, `periodMs`), `star_field.dart` (`StarField.generate`, a new `math.Random(seed)` on every call, count `(12 + (width * height / 1400).round()).clamp(12, 60)`, rejection sampling of at most 200 attempts per star with a deterministic fallback position, stars above the ground line at 0.66 of the height and outside the moon circle plus a 4 px margin, empty list for a size of 0 or less, period `3000 + nextInt(5000)`, phase `nextInt(period)`) and `twinkle.dart` (`opacityAt = 0.625 + 0.375 * sin(2 * pi * (elapsedMs + phaseMs) / periodMs)`) in `lib/src/domain/scene`.
    - _Requirements: 1.3, 1.4, 1.5, 1.6, 2.1, 2.2, 2.3, 2.4, 15.3_

  - [x] 2.2 Extend the test generators with scene sizes, widths and id lists
    - Add to `test/domain/support/grave_generators.dart`: `anyDoubleBetween(min, max)` (an integer in thousandths divided by 1000, web-safe), `anySeed`, `anySceneSize` (width 1 to 2000, height 1 to 4000, plus fixed edge sizes 1 by 1 and 320 by 640), `anyTwinkleInput` (phase, period 3000 to 8000, elapsed 0 to 10^9), `anyAvailableWidth` (1 to 4096 plus the edges 319, 320, 719, 720, 1000, 1280, 4096), `anyTextScale` (1.0 to 2.0 in steps of 0.05), `anyColumnCount` (1 to 4), `anyGraveCount` (0 to 60) and `anyIdList` (0 to 12 distinct ids from a pool of 15, in any order).
    - Keep every generated integer far below 2^53 and add no `dart:io` import.
    - _Requirements: 16.2, 16.3_

  - [x] 2.3 Write unit tests for `StarField` and `Twinkle`
    - Create `test/domain/scene/star_field_test.dart` (zero and negative size give an empty list; one fixed small size pinned to exact star count and positions; the count at the smallest and the largest sizes is 12 and 60) and `test/domain/scene/twinkle_test.dart` (opacity at phase 0 and elapsed 0 is 0.625; the minimum 0.25 and the maximum 1.0 are reached).
    - _Requirements: 1.3, 1.5, 2.2_

  - [x] 2.4 Write property test for star field determinism
    - **Property 1: Star field determinism**
    - **Validates: Requirements 1.4, 1.6**
    - Create `test/domain/scene/star_field_determinism_property_test.dart`.

  - [x] 2.5 Write property test for stars inside the sky and outside the moon
    - **Property 2: Stars stay inside the sky and outside the moon**
    - **Validates: Requirements 1.5**
    - Create `test/domain/scene/star_field_bounds_property_test.dart`.

  - [x] 2.6 Write property test for the star count
    - **Property 3: Star count scales within bounds**
    - **Validates: Requirements 1.3**
    - Create `test/domain/scene/star_field_count_property_test.dart`.

  - [x] 2.7 Write property test for twinkle range
    - **Property 4: Twinkle opacity stays in range**
    - **Validates: Requirements 2.2**
    - Create `test/domain/scene/twinkle_range_property_test.dart`.

  - [x] 2.8 Write property test for twinkle periodicity
    - **Property 5: Twinkle is periodic**
    - **Validates: Requirements 2.3**
    - Create `test/domain/scene/twinkle_period_property_test.dart` with a tolerance of 1e-9.

  - [x] 2.9 Write property test for twinkle smoothness
    - **Property 6: Twinkle has no hard flicker**
    - **Validates: Requirements 2.4**
    - Create `test/domain/scene/twinkle_smooth_property_test.dart`.

- [x] 3. Layout and new graves
  - [x] 3.1 Implement `SceneCell` and `SceneLayout`
    - Create `scene_cell.dart` and `scene_layout.dart` in `lib/src/domain/scene`: `breakpoint` 720, `minTombstoneWidth` 240, `maxTombstoneWidth` 300, `gap` 24, `rowGap` 32, `columnsFor`, `tombstoneWidthFor` (with the exception clause when the space is below the minimum), `cellFor` (row `i ~/ columns`, column `i % columns`, a short last row and a graves count below the column count centered through one code path) and `contentHeightFor`.
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.8, 4.9, 15.3_

  - [x] 3.2 Implement `NewGraveIds`
    - Create `new_grave_ids.dart`: `diff({previous, next})` returns the ids of `next` that are not in `previous`, in the order of `next`, with `previous.toSet()`.
    - _Requirements: 5.11, 5.12, 15.3_

  - [x] 3.3 Write unit tests for `SceneLayout`
    - Create `test/domain/scene/scene_layout_test.dart`: column counts at the widths 319, 320, 719, 720, 1000, 1280 and 4096, the empty and single-grave layouts, the centering of 1 grave at 2, 3 and 4 columns and of 5 graves at 3 columns, and the width below the minimum tombstone width.
    - _Requirements: 4.1, 4.2, 4.4, 4.8, 4.9_

  - [x] 3.4 Write unit tests for `NewGraveIds`
    - Create `test/domain/scene/new_grave_ids_test.dart`: equal lists give an empty diff (the scene treats the first loaded list as the previous list, so loaded graves are never new), an empty previous list returns every id of the next list in order, a mixed before and after list, a removed id, and a reordered list with no new id.
    - _Requirements: 5.5, 5.11, 5.12_

  - [x] 3.5 Write property test for column bounds
    - **Property 7: Column count stays within bounds**
    - **Validates: Requirements 4.3**
    - Create `test/domain/scene/scene_layout_columns_property_test.dart`.

  - [x] 3.6 Write property test for the row width
    - **Property 8: Tombstone rows fit the available width**
    - **Validates: Requirements 4.4**
    - Create `test/domain/scene/scene_layout_width_property_test.dart`.

  - [x] 3.7 Write property test for layout order
    - **Property 9: Layout preserves list order**
    - **Validates: Requirements 4.5**
    - Create `test/domain/scene/scene_layout_order_property_test.dart`.

  - [x] 3.8 Write property test for layout injectivity
    - **Property 10: Layout is injective**
    - **Validates: Requirements 4.6**
    - Create `test/domain/scene/scene_layout_injective_property_test.dart`.

  - [x] 3.9 Write property test for the new-grave diff
    - **Property 12: New-grave diff is a set difference**
    - **Validates: Requirements 5.12**
    - Create `test/domain/scene/new_grave_ids_property_test.dart`.

- [x] 4. Weathering and rise
  - [x] 4.1 Implement `WeatheringResult`, `Weathering` and `RiseProgress`
    - Create `weathering_result.dart`, `weathering.dart` (`level = (max(0, dayCount) / 3650).clamp(0, 1)`, `fade = level * 0.25`, `tiltRadians = level * 3 degrees * sign` with the sign from `StableHash.of(graveId).isEven`, a negative day count treated as 0) and `rise_progress.dart` (`durationMs` 600, ease-in-out cubic with no Flutter import) in `lib/src/domain/scene`.
    - _Requirements: 5.1, 5.2, 5.3, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 7.9, 7.28, 15.3_

  - [x] 4.2 Extend the test generators with day counts, ids, arch inputs, descriptions and counts
    - Add to `test/domain/support/grave_generators.dart`: `anyDayCount` (-5 to 4000 plus the fixed edge days 0, 1, 1824, 1825, 1826, 3649, 3650, 3651), `anyGraveId` (ids `g1` to `g99` plus ids with non-ASCII characters, an empty-looking id of one space, and a 200-character id), `anyThemeTokens` (index mapped to `CoffinColorTokens.night` or `.daylight`), `anyArchInput` (arch width 120 to 300, rise 60 to 200, line height 8 to 60, text width 1 to arch width), `anyDescription` (shortcodes, times, ports, runs of whitespace, `:+1:`, `:100:`, Unicode emoji, lone colons, up to 2,000 characters), `anyDateLine` and `anyNonNegativeInt` (0 to 2^53 - 1 built from two integer halves, plus the fixed values 0, 7, 999, 1000, 60683, 181478 and 1234567).
    - Keep every generated integer below 2^53 and add no `dart:io` import.
    - _Requirements: 16.2, 16.3_

  - [x] 4.3 Write unit tests for `Weathering` and `RiseProgress`
    - Create `test/domain/scene/weathering_test.dart` (Day_Count 0 gives level 0, tilt 0 and fade 0; a negative Day_Count behaves like 0; 3650 and above give level 1; the tilt sign is fixed for fixed ids, differs between at least one pair of ids, and equals the sign of `StableHash.of(id).isEven`) and `test/domain/scene/rise_progress_test.dart` (0 at 0 ms, 1 at 600 ms and after, 0.5 at 300 ms, negative elapsed gives 0).
    - _Requirements: 5.3, 7.1, 7.2, 7.7, 7.9, 7.28_

  - [x] 4.4 Write the contrast table unit test
    - Create `test/domain/scene/weathering_contrast_test.dart`: compute `WcagContrast.ratio` for every text token (text, muted, primary, secondary, tertiary, as listed in `CoffinColorTokens.contrastPairs`) over the stone color at the Weathering levels 0, 0.5 and 1, for `CoffinColorTokens.night` and `CoffinColorTokens.daylight`, and fail when any ratio is below 3.0. Also check that the focus ring and the delete button label color keep at least 3.0 over the `background` token.
    - _Requirements: 8.1, 8.3, 8.4, 8.8_

  - [x] 4.5 Write property test for rise progress
    - **Property 11: Rise progress stays in range and is monotonic**
    - **Validates: Requirements 5.3**
    - Create `test/domain/scene/rise_progress_property_test.dart`.

  - [x] 4.6 Write property test for the weathering level
    - **Property 13: Weathering level stays in range and is monotonic**
    - **Validates: Requirements 7.3, 7.4**
    - Create `test/domain/scene/weathering_level_property_test.dart`.

  - [x] 4.7 Write property test for tilt and fade limits
    - **Property 14: Tilt and fade stay within their limits**
    - **Validates: Requirements 7.5, 7.6**
    - Create `test/domain/scene/weathering_limits_property_test.dart`.

  - [x] 4.8 Write property test for weathering determinism
    - **Property 15: Weathering is deterministic**
    - **Validates: Requirements 7.8**
    - Create `test/domain/scene/weathering_determinism_property_test.dart`.

  - [x] 4.9 Write property test for weathered contrast
    - **Property 16: Weathered contrast stays above the minimum**
    - **Validates: Requirements 8.1, 8.5**
    - Create `test/domain/scene/weathering_contrast_property_test.dart`, over every day count and both themes.

- [x] 5. Arch fit
  - [x] 5.1 Implement `ArchFitResult` and `ArchFit`
    - Create `arch_fit_result.dart` and `arch_fit.dart` in `lib/src/domain/scene`: `minFontSize` 12, `margin` 4, the ellipse containment formula of the design, a search of at most 40 fixed shrink steps, `truncated` when the text does not fit at 12, and the fallback `top 0, fontSize 12, truncated true` for an arch width of 0 or less. The function never throws.
    - _Requirements: 9.2, 9.3, 9.4, 15.3_

  - [x] 5.2 Write unit tests for `ArchFit`
    - Create `test/domain/scene/arch_fit_test.dart`: "R.I.P." (a text width measured as 6 characters at the base size) at the arch widths 240, 270 and 300 and at the text scales 1.0, 1.5 and 2.0 never needs truncation, a text wider than the arch shrinks and then truncates, and the zero-width arch returns the documented fallback.
    - _Requirements: 9.1, 9.2, 9.4, 9.6_

  - [x] 5.3 Write property test for arch fit containment
    - **Property 17: Arch fit keeps the line inside the arch**
    - **Validates: Requirements 9.3**
    - Create `test/domain/scene/arch_fit_property_test.dart`.

- [x] 6. Description cleaner and thousands formatter
  - [x] 6.1 Implement `DescriptionCleaner`
    - Create `description_cleaner.dart` in `lib/src/domain/scene`: find whole-word candidates of the shape `:name:` bounded by the start or whitespace on the left and whitespace or the end on the right, keep only those with `name` of 1 to 40 characters from `[A-Za-z0-9_+-]` and at least one ASCII letter, replace them with one space, then collapse every whitespace run to one space and trim. It never throws and does not touch Unicode emoji.
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.7, 15.3_

  - [x] 6.2 Implement `ThousandsFormatter`
    - Create `thousands_formatter.dart` in `lib/src/domain/scene`: `format(int)` puts a comma between each group of three digits counted from the right, formats a negative value as `-` plus its absolute value, treats `-0` as `0`, uses no `intl` and no locale, and never throws.
    - _Requirements: 12.1, 12.2, 12.6, 12.7, 12.10, 15.3_

  - [x] 6.3 Write unit tests for `DescriptionCleaner`
    - Create `test/domain/scene/description_cleaner_test.dart`: "10:30 to 11:45", "10:30:45", "localhost:8080" and "a:b:c" unchanged, ":atom: The hackable text editor" gives "The hackable text editor", "Fast :rocket: builds" gives "Fast builds", `:+1:` and `:100:` kept, a 40-character name removed and a 41-character name kept, `:white_check_mark:` removed, an unterminated colon, an empty string, an all-whitespace string, Unicode emoji kept, and a lone surrogate not throwing.
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.7_

  - [x] 6.4 Write unit tests for `ThousandsFormatter`
    - Create `test/domain/scene/thousands_formatter_test.dart`: 0, 7, 999, 1000, 60683, 181478 and 1234567 give "0", "7", "999", "1,000", "60,683", "181,478" and "1,234,567"; -1234 gives "-1,234"; the largest integer below 2^53 formats.
    - _Requirements: 12.2, 12.6_

  - [x] 6.5 Write property test for whole-word shortcode removal
    - **Property 19: Description cleaner removes only whole-word shortcodes**
    - **Validates: Requirements 11.8**
    - Create `test/domain/scene/description_cleaner_output_property_test.dart`.

  - [x] 6.6 Write property test for cleaner idempotence
    - **Property 20: Description cleaner is idempotent**
    - **Validates: Requirements 11.7**
    - Create `test/domain/scene/description_cleaner_idempotent_property_test.dart`.

  - [x] 6.7 Write property test for shortcode-free text
    - **Property 21: Description cleaner leaves shortcode-free text unchanged apart from whitespace**
    - **Validates: Requirements 11.9**
    - Create `test/domain/scene/description_cleaner_identity_property_test.dart`.

  - [x] 6.8 Write property test for the thousands round trip
    - **Property 22: Thousands formatter round-trips**
    - **Validates: Requirements 12.3**
    - Create `test/domain/scene/thousands_formatter_round_trip_property_test.dart`.

  - [x] 6.9 Write property test for thousands grouping
    - **Property 23: Thousands formatter groups digits correctly**
    - **Validates: Requirements 12.4**
    - Create `test/domain/scene/thousands_formatter_groups_property_test.dart`.

  - [x] 6.10 Write property test for thousands characters
    - **Property 24: Thousands formatter output is digits and commas only**
    - **Validates: Requirements 12.5**
    - Create `test/domain/scene/thousands_formatter_chars_property_test.dart`.

- [x] 7. Cracks
  - [x] 7.1 Implement `KeepOutRect`, `CrackPoint`, `Crack` and `CrackGenerator`
    - Create `keep_out_rect.dart`, `crack_point.dart`, `crack.dart` (unmodifiable list of 3 to 5 points, value equality) and `crack_generator.dart` in `lib/src/domain/scene`, following the five steps of the design: an empty list when `dayCount <= 1825` (strict), an empty list for a non-finite or non-positive stone size or for a band under 6 px high or 8 px wide, `StableRandom(StableHash.of(graveId))`, `count = 1 + nextInt(3)`, `pointCount = 3 + nextInt(3)`, integer coordinates clamped to `[minX, maxX] x [minY, maxY]`. Constants: `ageThresholdDays` 1825, `sideInset` 20, `baseInset` 6, `bandHeight` 16, `gap` 2, `strokeWidth` 1.5. The day count is used only for the threshold test. No `dart:math`, no `hashCode`, no `DateTime`.
    - _Requirements: 7.15, 7.16, 7.17, 7.18, 7.19, 7.20, 7.21, 7.22, 15.3_

  - [x] 7.2 Extend the test generators with crack inputs
    - Add `anyCrackInput` to `test/domain/support/grave_generators.dart`: a stone width 240 to 300, a stone height 260 to 900 (integers), a day count from `anyDayCount`, a grave id from `anyGraveId`, and the keep-out list as the tombstone builds it (the content box `(20, 0, width - 20, height - 20)` and an epitaph rectangle placed inside the arch).
    - _Requirements: 16.2, 16.3_

  - [x] 7.3 Write unit tests for `CrackGenerator`
    - Create `test/domain/scene/crack_generator_test.dart`: Day_Counts 1824 and 1825 give an empty list, 1826 gives 1 to 3 cracks, 0 and a negative Day_Count give an empty list; a pinned crack list for one fixed id at width 270 and height 480; an empty keep-out list uses the bottom 16 px band; a keep-out list that leaves no band gives an empty list; a zero, a negative, a NaN and an infinite stone size give an empty list; at least 8 of 10 fixed ids give different lists; the same id at 1826 and at 3650 days gives equal lists; every point is an integer-valued double or an `int`.
    - _Requirements: 7.15, 7.16, 7.17, 7.18, 7.19, 7.21_

  - [x] 7.4 Write property test for cracks
    - **Property 25: Cracks stay inside the stone, outside the text, and depend on the id only**
    - **Validates: Requirements 7.15, 7.16, 7.17, 7.18, 7.19, 7.20, 7.22, 8.9, 8.10**
    - Create `test/domain/scene/crack_generator_property_test.dart` as one glados test over `anyCrackInput`: clause 1 (empty at or below 1825, 1 to 3 cracks of 3 to 5 integer points above), clause 2 (at least 8 samples on each segment plus both ends, 20 px from the side edges and 6 px above the base, and outside every keep-out rectangle and inside the stone after expanding by 0.75), clause 3 (the same arguments give equal cracks, and any other day count above 1825 gives the same cracks).

- [x] 8. Tombstone facts
  - [x] 8.1 Implement `TombstoneFragmentKind`, `TombstoneFragment` and `TombstoneFacts`
    - Create `tombstone_fragment_kind.dart`, `tombstone_fragment.dart` and `tombstone_facts.dart` in `lib/src/domain/scene`: `TombstoneFacts.of({grave, today, dateLine})` returns the fragments in display order (title, date line, dead-for text from `DeadForFormatter`, then a full-name fragment only for a GitHub grave whose `repo.fullName` differs from `grave.name`).
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.10, 15.3_

  - [x] 8.2 Write unit tests for `TombstoneFacts`
    - Create `test/domain/scene/tombstone_facts_test.dart`: a manual grave (3 fragments), an imported grave whose name equals its `full_name` (3 fragments, no full-name fragment), an imported grave with a different name (4 fragments), the `atom/atom` example, and a project named like its own dead-for text (kinds still counted once).
    - _Requirements: 10.1, 10.3, 10.4, 10.5, 10.10_

  - [x] 8.3 Write property test for visible fragments
    - **Property 18: Visible text fragments are unique**
    - **Validates: Requirements 10.1, 10.3, 10.4, 10.5, 10.10**
    - Create `test/domain/scene/tombstone_facts_property_test.dart` over `anyGrave` and `anyDateLine`.

- [x] 9. Checkpoint - Scene math complete
  - Ensure all tests pass, ask the user if questions arise. Also run `flutter test --platform chrome test/domain test/data` in `apps/graveyard`; it must pass, so the hash, the random numbers and the cracks are equal on the VM and on the web.

- [x] 10. Copy
  - [x] 10.1 Update `GraveyardCopy`
    - In `lib/src/ui/graveyard_copy.dart`: make `epitaph` the constant `"R.I.P."` (no longer a function of the dead-for text), format the star count with `ThousandsFormatter` (both the visible star line and the semantic label, keeping "1 star" and "stars"), and clean the description with `DescriptionCleaner` in the semantic label. Add any new visible string here (none is required). Update `lib/src/ui/grave_tile.dart` and `test/ui/grave_tile_test.dart` only as far as needed to compile and pass; both are replaced in task 12.3.
    - _Requirements: 9.5, 10.2, 11.12, 12.8, 12.9, 14.1, 14.2, 14.3_

  - [x] 10.2 Update the copy tests
    - Update `test/ui/graveyard_copy_test.dart`: the epitaph is "R.I.P." and does not contain the dead-for text, the star line shows "60,681" for 60681, the label shows the thousands separators and the cleaned description, the singular "1 star" and the plural stay, and no string contains "failed", "invalid" or "your fault".
    - _Requirements: 9.5, 11.12, 12.8, 12.9, 14.1, 14.2, 14.4_

- [x] 11. Painters and tombstone parts
  - [x] 11.1 Implement `NightSkyPainter` and `GroundPainter`
    - Create `lib/src/ui/night_sky_painter.dart` (vertical gradient from the `background` token to the `surface` token, one Moon with a blurred glow in the upper third, the stars from `StarField` with `Twinkle` opacity, or a fixed opacity of 0.8 when motion is reduced, repainted by the Twinkle controller as its `repaint` listenable) and `lib/src/ui/ground_painter.dart` (a strip from a token color with a soft edge). Colors derive from `CoffinColorTokens`. No image, no package, no hard-coded color outside token blends.
    - _Requirements: 1.1, 1.2, 1.7, 1.8, 1.9, 1.10, 2.1, 6.2, 13.1, 13.7_

  - [x] 11.2 Implement `ArchEpitaph`
    - Create `lib/src/ui/arch_epitaph.dart`: paints `GraveyardCopy.epitaph` ("R.I.P.") positioned by `ArchFit` inside the `archRise` 140 arch, measures the text with `TextPainter` at the scaled font size, shrinks down to 12 px, then truncates on one line with an ellipsis, never wraps, and is wrapped in `ExcludeSemantics`. It exposes its rectangle for the crack keep-out.
    - _Requirements: 9.1, 9.2, 9.4, 9.5, 9.6, 9.8, 9.9, 13.2, 15.5_

  - [x] 11.3 Implement `CrackPainter`
    - Create `lib/src/ui/crack_painter.dart`: draws each crack as one `Path` of line segments with `PaintingStyle.stroke`, round caps and joins, the given color and stroke width of 1.5. No controller, no ticker, no listenable. `shouldRepaint` compares the crack lists by value, the color and the stroke width. The color is passed in (the `background` token at 70% alpha), so the painter has no hard-coded color.
    - _Requirements: 7.23, 7.24, 7.25, 7.26, 13.7, 15.5_

  - [x] 11.4 Write unit tests for the painters
    - Create `test/ui/night_sky_painter_test.dart`, `test/ui/ground_painter_test.dart` and `test/ui/crack_painter_test.dart`: each paints into a `PictureRecorder` canvas without an exception for a normal, a tiny (1 by 1) and a zero size; `shouldRepaint` is false for equal inputs and true for a different crack list, color or stroke width; the night sky paints no star for an empty star list; the crack painter paints nothing for an empty crack list.
    - _Requirements: 1.8, 1.10, 7.23, 7.25, 7.26_

- [x] 12. Tombstone, scene and screen
  - [x] 12.1 Implement `GraveTombstone`
    - Create `lib/src/ui/grave_tombstone.dart` (the successor of `GraveTile`): a `Stack` with the fade halo behind `TombstoneCard(showEpitaph: false)`, the `ArchEpitaph` and, for a Day_Count above 1825, the crack layer exactly as in the design (`Positioned.fill`, `IgnorePointer`, `ExcludeSemantics`, `LayoutBuilder`, `RepaintBoundary`, `CustomPaint` with the key `cracks-<id>`), the whole `Stack` inside `Transform.rotate` around the base center and the rise `Transform.translate` plus `Opacity`. The texts come from `TombstoneFacts`, the description from `DescriptionCleaner` (3 lines, ellipsis, no line when empty), the stars from `ThousandsFormatter`, "Archived" in words, "Buried by hand." for a manual grave, and one `Semantics(container: true)` label. The delete button keeps a 48 by 48 target, its label, and hover, press and focus states, and lies below the stone. The Day_Count comes from `DeadFor.between` and Today passed in. Keep-out areas: the content box and the epitaph rectangle.
    - _Requirements: 5.1, 5.2, 5.4, 5.9, 7.2, 7.10, 7.12, 7.13, 7.14, 7.22, 7.23, 7.24, 7.25, 7.26, 8.2, 8.6, 8.7, 9.9, 10.1, 10.2, 10.3, 10.4, 10.6, 10.7, 10.8, 11.6, 11.12, 11.13, 12.8, 13.2, 13.3, 13.5, 13.8_

  - [x] 12.2 Implement `GraveyardScene`
    - Create `lib/src/ui/graveyard_scene.dart`: a non-scrolling background `Stack` (the sky painter in its own `RepaintBoundary`, the ground painter, the `FogBackground` above them), the scrolling rows on top placed by `SceneLayout` (one column below 720, 2 to 4 at 720 and above, centered short rows, margin of `tombstoneWidth * sin(3 degrees)`), one Twinkle controller through the `MotionLoop` style of `coffin_core` that stops when `MediaQuery.disableAnimations` is true, one Rise controller per new tombstone created from `NewGraveIds.diff` in `didUpdateWidget` (the previous ids are seeded from the first list, so loaded and retried graves never rise), disposed once when the Rise ends, when the grave is removed or on dispose, and the Still_Scene when motion is reduced. It recomputes the Weathering and the cracks when Today changes, without replaying a Rise. Colors only from tokens. It reads no clock.
    - _Requirements: 1.1, 1.10, 2.5, 2.6, 2.7, 3.1, 3.2, 3.3, 3.4, 4.1, 4.2, 4.7, 4.8, 4.9, 4.10, 4.11, 4.12, 5.1, 5.4, 5.5, 5.6, 5.7, 5.8, 5.10, 5.11, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 7.10, 7.11, 7.27, 13.1, 13.4, 13.9, 13.10_

  - [x] 12.3 Wire the screen and replace the old tile
    - Edit `lib/src/ui/graveyard_screen.dart` to host `GraveyardScene` instead of the `ListView` of `GraveTile`, keeping the loading, load error, empty, Memory_Notice and save-error states (drawn over the sky and fog), the add control above the scene, and the delete flow. Delete `lib/src/ui/grave_tile.dart` and `test/ui/grave_tile_test.dart`. Update `graveyard_screen_test.dart`, `layout_test.dart`, `delete_and_order_test.dart`, `add_import_test.dart`, `state_panels_test.dart` and any other test that finds `GraveTile` or the repeated texts, so each expects the single text and the new structure.
    - _Requirements: 4.7, 10.9, 13.6, 13.9, 13.10, 13.11, 16.9_

- [x] 13. Widget tests
  - [x] 13.1 Write widget tests for `GraveTombstone` content
    - Create `test/ui/grave_tombstone_test.dart`: the Dead_For_Text once in the body and `owner/repo` once for `atom/atom`, the different-name case showing the full name once as a source line, the cleaned description ("The hackable text editor"), no empty gap for an empty cleaned description, "60,681", "Archived" in words, "Buried by hand.", the semantic labels for a manual and a GitHub grave (cleaned description, no cracks mentioned), the description limited to 3 lines, the 48 by 48 delete target and its label, hover and press states, in the dark and the daylight theme.
    - _Requirements: 10.1, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 11.4, 11.6, 11.12, 11.13, 12.8, 12.9, 13.3, 16.6_

  - [x] 13.2 Write widget tests for the epitaph fit
    - Create `test/ui/arch_epitaph_test.dart`: "R.I.P." at the widths 240, 270 and 300 and the text scales 1.0, 1.5 and 2.0 is fully inside the arch region and not clipped (`tester.getRect` against a geometric check that mirrors `ArchFit`), never loses its first or last character, is not exposed as a semantic node, and rotates with a tilted tombstone.
    - _Requirements: 9.1, 9.5, 9.6, 9.7, 9.8, 9.9, 16.6_

  - [x] 13.3 Write widget tests for cracks
    - Create `test/ui/tombstone_cracks_test.dart`: a grave of 1826 days has a `CustomPaint` with the key `cracks-<id>` and 1 to 3 cracks, a grave of 1825 days has none; at the widths 240, 270 and 300 and the text scales 1.0, 1.5 and 2.0 the bounds of every painted crack, expanded by 0.75, do not intersect the rect of any rendered text (title, date line, Dead_For_Text, description and Epitaph); the same cracks after a rebuild and after a resize; the same cracks with `disableAnimations` true and false, with no frame scheduled by the painter; no semantics node for the crack layer and no mention in the label; the painter color equals the `background` token in the dark and the daylight theme; the delete control keeps its 48 by 48 target and is hit-testable; `refreshToday` across the threshold adds the cracks and plays no Rise.
    - _Requirements: 7.15, 7.16, 7.20, 7.22, 7.23, 7.24, 7.25, 7.26, 7.27, 8.9, 8.10, 13.3, 16.6_

  - [x] 13.4 Write widget tests for tilt, fade and contrast
    - Create `test/ui/tombstone_weathering_test.dart`: a ten-year-old grave is tilted by at most 3 degrees and has a fade halo, a fresh grave has neither, the tilt is the same after a rebuild, the base stays on the ground, and the rendered text and stone colors of a fresh and of a ten-year-old grave keep a `WcagContrast.ratio` of at least 3.0 in the dark and the daylight theme, with and without cracks.
    - _Requirements: 7.2, 7.5, 7.6, 7.12, 7.13, 8.1, 8.2, 8.3, 8.6, 16.6, 16.8_

  - [x] 13.5 Write widget tests for the scene
    - Create `test/ui/graveyard_scene_test.dart`: the states empty, loading, list, load error, Memory_Notice and save error render over the sky and fog without overflow at the widths 320, 360, 768 and 1280 and the text scales 1.0 and 1.5; one column at 360 and 2 to 4 columns at 768 and 1280; the Rise on an added grave and none on loaded graves, on a retried load, or when another grave is deleted; two quick adds rise independently; the Still_Scene with `disableAnimations` true has no running animation after the first frame, draws the cracks and every tombstone at rest; motion turning off mid-Rise or mid-Twinkle does not throw; the order of semantic nodes follows the order of the graves; the sky, moon, stars, ground and fog add no semantic node; disposal during a Rise does not throw.
    - _Requirements: 1.8, 3.4, 4.1, 4.2, 4.10, 5.1, 5.4, 5.5, 5.6, 5.7, 5.8, 5.10, 6.1, 6.2, 6.4, 6.5, 6.6, 6.8, 13.1, 13.2, 13.9, 13.10, 16.6, 16.7_

- [x] 14. Source-rule tests
  - [x] 14.1 Write source-rule tests for the scene
    - Create `test/source_rules/scene_sources_test.dart`: no file under `lib/src/domain/scene` reads `String.hashCode` (the rule matches uses, not overrides: it bans a `.hashCode` member access such as `id.hashCode`, and allows the declaration `int get hashCode => Object.hash(...)` in value classes), and none contains `package:flutter`, `dart:ui`, `dart:io`, `dart:html` or `DateTime.now`; `crack_generator.dart`, `stable_hash.dart` and `stable_random.dart` do not import `dart:math`; the scene and tombstone files under `lib/src/ui` contain no `Color(0x` and no `Colors.` (colors come from tokens); no file under `lib` imports `coffin_core/src` or Hauntagotchi; and the `grave_tile.dart` file no longer exists. This folder is the only place that reads source files with `dart:io`.
    - Write the hashing rule as a function over source text that strips comments and string literals, then flags the regex `\.hashCode\b` (a member access) and does not flag `get hashCode`. Add a self-check in the same file that runs the function on two inline snippets: one allowed (`int get hashCode => Object.hash(a, b);`, must produce no violation) and one banned (`final seed = id.hashCode;`, must produce a violation).
    - _Requirements: 7.18, 7.25, 13.7, 15.3, 15.4, 15.5, 15.8_

- [x] 15. Final verification
  - [x] 15.1 Run the full verification plan
    - In `apps/graveyard`, run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` (zero issues), `flutter test`, and `flutter test --platform chrome test/domain test/data`. Check `grep -rl "dart:io" test/domain test/data` finds nothing.
    - Run `flutter test` in `apps/hauntagotchi`, in `packages/coffin_core` and in `tool/`, then `flutter test --tags raise-check --run-skipped` in `tool/`. All must pass unchanged.
    - Run `flutter pub get --enforce-lockfile` at the repo root, then check `git diff --exit-code -- pubspec.lock` exits 0 (no new package, so no lockfile change).
    - Check `git diff --exit-code -- packages/coffin_core apps/hauntagotchi tool` exits 0.
    - Check `git status --short` lists only these paths: `apps/graveyard/lib`, `apps/graveyard/test` and `.kiro/specs/graveyard-scene`. Ignore any `DIARY.md` entry, because the user maintains that file. If it lists any other path, report it to the user and do not revert it.
    - Fix any failure at its cause. Create no file outside the repository, including `/tmp`.
    - _Requirements: 15.1, 15.2, 15.7, 15.8, 15.10, 16.1, 16.2, 16.9, 16.10_

## Notes

- Every test sub-task is required and none is marked optional. The project testing rules and Requirement 16.1 require unit tests for pure logic and glados property tests for numeric rules.
- Every property in the design (1 to 25) has its own sub-task: P1 (2.4), P2 (2.5), P3 (2.6), P4 (2.7), P5 (2.8), P6 (2.9), P7 (3.5), P8 (3.6), P9 (3.7), P10 (3.8), P11 (4.5), P12 (3.9), P13 (4.6), P14 (4.7), P15 (4.8), P16 (4.9), P17 (5.3), P18 (8.3), P19 (6.5), P20 (6.6), P21 (6.7), P22 (6.8), P23 (6.9), P24 (6.10), P25 (7.4).
- Property 25 is the crack property: count 1 to 3 above 1825 days and none at or below, every crack point inside the stone and outside the text areas, and the same cracks for the same id. The 1824, 1825 and 1826 boundary is pinned by unit tests in 7.3 and the rendered check against real text rectangles is in 13.3.
- Generator tasks 2.2, 4.2 and 7.2 all edit `test/domain/support/grave_generators.dart`, so they sit in different waves.
- Task 10.1 changes `GraveyardCopy.epitaph` from a function to a constant, so it also patches `grave_tile.dart` and its test just enough to compile. Task 12.3 then deletes both.
- The design adds `StableHash`, `StableRandom` and `TombstoneFacts`, which the requirements now name (Requirements 7.28 and 10.10). The tilt sign uses `StableHash`, in place of `String.hashCode`.
- No task edits `DIARY.md`. The user maintains it and it changes during the build, so the final `git status` check ignores any `DIARY.md` entry and otherwise lists only `apps/graveyard/lib`, `apps/graveyard/test` and `.kiro/specs/graveyard-scene`.
- This workflow only creates the plan. Start execution by opening this file and choosing "Start task" on a task.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1", "2.2", "3.1", "3.2", "5.1", "6.1", "6.2", "8.1"] },
    { "id": 1, "tasks": ["1.2", "2.3", "2.4", "2.5", "2.6", "2.7", "2.8", "2.9", "3.3", "3.4", "3.5", "3.6", "3.7", "3.8", "3.9", "4.1", "4.2", "5.2", "6.3", "6.4", "7.1", "8.2"] },
    { "id": 2, "tasks": ["4.3", "4.4", "4.5", "4.6", "4.7", "4.8", "4.9", "5.3", "6.5", "6.6", "6.7", "6.8", "6.9", "6.10", "7.2", "7.3", "8.3"] },
    { "id": 3, "tasks": ["7.4"] },
    { "id": 4, "tasks": ["9"] },
    { "id": 5, "tasks": ["10.1", "11.1", "11.3"] },
    { "id": 6, "tasks": ["10.2", "11.2", "11.4"] },
    { "id": 7, "tasks": ["12.1"] },
    { "id": 8, "tasks": ["12.2"] },
    { "id": 9, "tasks": ["12.3"] },
    { "id": 10, "tasks": ["13.1", "13.2", "13.3", "13.4", "13.5", "14.1"] },
    { "id": 11, "tasks": ["15.1"] }
  ]
}
```
