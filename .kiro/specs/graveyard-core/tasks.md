# Implementation Plan: graveyard-core

## Overview

The plan builds Graveyard's core loop bottom-up in Dart. The dependency and lock change comes first. Then the pure domain (calendar dates, names, grave rules, sorting, duplicates, the two parsers, the dead-for text), the data layer (codec, storage), the GitHub client with `MockClient` tests, the controller, the UI, the route wiring, the screen tests, the source-rule tests, the deploy workflow change, and a final verification. Each task builds on the previous ones and ends wired into the app, so no code is left orphaned.

Rules for every task:

- Edit only `apps/graveyard/lib`, `apps/graveyard/test`, `.kiro/specs/graveyard-core`, and the four allowed edits: the two lines in `apps/graveyard/pubspec.yaml`, the `http` entry in the root `pubspec.lock`, the `http` entry in `CREDITS.md`, and the two Graveyard steps in `.github/workflows/deploy-web.yml`. Nothing changes in `packages/coffin_core`, `apps/hauntagotchi`, `tool/` or `tool/templates`.
- Never create files outside the repository, including `/tmp`. Scratch output goes inside the repo only if a task says so, and is deleted before the task ends.
- Doc-comment every public API in `domain` and `data`. One public class per file, `snake_case.dart`. Code passes `dart format` and `flutter analyze` with zero warnings.
- `lib/src/domain` imports no Flutter library, no `dart:io`, no `dart:html`, no `package:http` and no `package:hive_ce`, and calls no `DateTime.now()`. Only `SystemClock` calls `DateTime.now()`. Only `http_github_client.dart` imports `package:http`.
- Apps import only `package:coffin_core/coffin_core.dart`, never files under `coffin_core/lib/src`. Graveyard never imports Hauntagotchi.
- Tests under `test/domain` and `test/data` never import `dart:io`. Every test that reads source files lives in `test/source_rules/`.
- Widget and controller tests use `FakeClock`, `FakeGitHubClient` and `MemoryRecordRepository<Grave>`, never real Hive and never the network. No test depends on the time zone of the machine (inject `FixedOffsetZone`).
- Property tests use glados 1.1.7 with web-safe generators only (no `any.int`, `any.intInRange`, `any.list`, `any.listWithLengthInRange`, string generators or `uint*`), `numRuns: 200`, a `RunCounter` that asserts the run count, and the comment header `// Feature: graveyard-core, Property N: <title>` plus `// Validates: Requirements ...`.
- Every test task (unit, property, widget) is required. None is optional.
- A task is marked done only after `flutter test` passes in `apps/graveyard`.

## Tasks

- [ ] 1. Dependencies and lock (first change of the feature)
  - [ ] 1.1 Add `http` and `glados` to the Graveyard pubspec
    - In `apps/graveyard/pubspec.yaml`, add exactly `http: 1.6.0` (no caret, no range) as the last line under `dependencies`, and exactly `glados: 1.1.7` under `dev_dependencies` after `flutter_lints`. Touch no other pubspec.
    - Check `git diff -U0 -- apps/graveyard/pubspec.yaml` shows exactly two added lines and nothing removed.
    - _Requirements: 16.1, 16.5_

  - [ ] 1.2 Run a plain `flutter pub get` and report the exact lock diff
    - Run `flutter pub get` once at the repo root. Do not use `--enforce-lockfile` here, because it fails by design while the lock must change.
    - Run `git diff -U0 -- pubspec.lock` and paste the full output into the task report. Name each package the lock gained, with its version (expected: `http` 1.6.0 only, one entry placed before `http_parser`).
    - If the diff holds anything beyond the one `http` entry (another package, a version change, a removed line), stop and ask the user. Do not continue and do not edit the lock by hand.
    - _Requirements: 16.1, 16.4_

  - [ ] 1.3 Re-run with `--enforce-lockfile` and check the lock is stable
    - Run `flutter pub get --enforce-lockfile` at the repo root. It must succeed.
    - Run `git diff -U0 -- pubspec.lock` again and check it is identical to the diff reported in 1.2.
    - _Requirements: 16.4_

  - [ ] 1.4 Add the `http` entry to `CREDITS.md`
    - Add a `## Packages` heading and one `### http` entry in the existing entry style (author "The Dart project authors", used for the GitHub import, license BSD 3-Clause, links to the pub.dev package page and to the license text), exactly as written in the design's "Dependency and lock change plan".
    - Check the license URL answers (for example with `curl -sI`) before finishing. Change no existing line.
    - Check `git diff -U0 -- CREDITS.md` shows only the added heading and the `http` entry.
    - _Requirements: 16.1, 16.6_

- [ ] 2. Calendar dates, clock, zone and name rules
  - [ ] 2.1 Implement `CalendarDate`, `Clock` and `ZoneConverter` in `lib/src/domain`
    - Create `calendar_date.dart` (integer civil-calendar `epochDay`/`fromEpochDay`, `tryCreate`, `fromDateTime` reading year, month and day only, strict `tryParse`, `toIso`, `earliest`, `daysInMonth`, `isLastDayOfMonth`, `addDays`, `addMonthsClamped`, `daysUntil`, `wholeMonthsUntil`, `Comparable`, value equality, no `Duration`).
    - Create `clock.dart` (`abstract interface class Clock { DateTime now(); }`) and `zone_converter.dart` (`typedef ZoneConverter` and the default `localZone` that calls `toLocal()`).
    - Remove `lib/src/domain/.gitkeep`.
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.6, 1.7, 4.3, 5.7_

  - [ ] 2.2 Implement `NameRules`
    - Create `name_rules.dart` with `maxLength` 80, `normalize` (trim and collapse every whitespace run to one space), `length` (code points), `keyOf` (normalised, lower-cased) and `forRepo`: the normalised `full_name` when it has at most 80 code points, otherwise the first 79 code points of the repo segment (or of the whole text when there is no slash) followed by `…`.
    - _Requirements: 2.3, 2.11, 2.12, 6.13, 8.5_

  - [ ] 2.3 Create web-safe test generators (base set)
    - Create `test/domain/support/grave_generators.dart` with `anyIntBetween`, `anyListBetween` (built on `any.simple` and `Random.nextInt`), a `RunCounter`, `anyCalendarDate` (epoch days 0 to 47482 plus fixed edge days: leap days, month and year ends, 2026-03-08, 2026-03-29, 2026-10-25, 2026-11-01), `anyInstantSeconds`, `anyOffsetMinutes` (index 0 to 52 mapped to -720 + 30 * index) and `anyProjectName` (ASCII, accents, CJK, an emoji, tabs, newlines, runs of spaces, 0 to 90 code points).
    - Keep every generated integer far below 2^53.
    - _Requirements: 17.3_

  - [ ] 2.4 Create the clock and zone test doubles
    - Create `test/support/fake_clock.dart` (`FakeClock` whose local time the test sets) and `test/support/fixed_offset_zone.dart` (`FixedOffsetZone(Duration offset)` whose `call` returns `utc.add(offset)`). Neither imports `dart:io`.
    - _Requirements: 1.7, 4.17_

  - [ ] 2.5 Write unit tests for `CalendarDate` and `NameRules`
    - Create `test/domain/calendar_date_test.dart` and `test/domain/name_rules_test.dart`: leap years, month ends, strict `tryParse` (wrong shape, month 13, 2025-02-30), year bounds, negative `addDays`, `wholeMonthsUntil` clamp cases, trimming and collapsing, code-point counting at 80 and 81, and `forRepo` at 80 and 81 code points, with and without a slash.
    - _Requirements: 1.3, 1.4, 1.6, 2.3, 2.7, 5.7, 8.5_

  - [ ] 2.6 Write property test for the calendar date round trip
    - **Property 1: Calendar date round trip**
    - **Validates: Requirements 1.6**
    - Create `test/domain/calendar_date_round_trip_property_test.dart`.

  - [ ] 2.7 Write property test for calendar day counts across daylight saving
    - **Property 2: Day counts are calendar days, also across daylight saving**
    - **Validates: Requirements 1.3, 1.4**
    - Create `test/domain/calendar_arithmetic_property_test.dart`; `n` from 0 to 800, including the four daylight saving dates.

  - [ ] 2.8 Write property test for time of day
    - **Property 3: Time of day does not change Today or the text**
    - **Validates: Requirements 1.2, 1.5**
    - Create `test/domain/time_of_day_property_test.dart`. It uses `DeadForFormatter` from task 6.1, so schedule it after that task.

  - [ ] 2.9 Write property test for name normalisation
    - **Property 4: Name normalisation is idempotent and well formed**
    - **Validates: Requirements 2.12**
    - Create `test/domain/name_normalisation_property_test.dart`.

- [ ] 3. Graves, manual rules, sorting and duplicates
  - [ ] 3.1 Implement the grave model, `GraveRules` and `GraveIds`
    - Create `grave_source.dart`, `repo_info.dart`, `grave.dart` (`Grave.manual`, `Grave.github`, value equality), `grave_rejection.dart`, `manual_grave_check.dart` (sealed), `manual_grave_accepted.dart`, `manual_grave_rejected.dart`, `grave_rules.dart` (`checkManual` over name and date parts, checks in the order: empty name, name over 80, date missing, date not real, before 1970-01-01, after Today) and `grave_ids.dart` (`next` gives the smallest unused `gN`).
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.11, 12.5_

  - [ ] 3.2 Implement `GraveSorter` and `DuplicateRules`
    - Create `grave_sorter.dart` (new list; date descending, then lower-cased name, then id) and `duplicate_rules.dart` (GitHub against GitHub by `full_name` key, manual against manual by name key and date, never across sources).
    - _Requirements: 6.1, 6.2, 6.3, 6.8, 6.9, 6.10, 6.11, 6.13_

  - [ ] 3.3 Extend the test generators with graves
    - Add `anyGrave` and `anyGraveList` (0 to 12 graves, small id numbers, colliding dates, names that differ only in letter case, GitHub graves with descriptions of Markdown, emoji shortcodes and 2,000-character text) to `test/domain/support/grave_generators.dart`.
    - _Requirements: 17.3_

  - [ ] 3.4 Write unit tests for grave rules, ids, sorting and duplicates
    - Create `test/domain/grave_rules_test.dart` (each criterion of Requirement 2 with named examples, Today and 1970-01-01 accepted, 2025-02-30 rejected and never shifted), `test/domain/grave_ids_test.dart`, `test/domain/grave_sorter_test.dart` (ties by name and id, input not mutated) and `test/domain/duplicate_rules_test.dart` (each rule of Requirement 6 with examples).
    - _Requirements: 2.1 to 2.9, 6.1 to 6.3, 6.8 to 6.11_

  - [ ] 3.5 Write property test for manual validation
    - **Property 5: Manual validation matches its rules**
    - **Validates: Requirements 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9**
    - Create `test/domain/grave_rules_property_test.dart` with a model that applies the rules in order.

  - [ ] 3.6 Write property test for generated ids
    - **Property 6: Generated grave ids are unique**
    - **Validates: Requirements 2.1**
    - Create `test/domain/grave_ids_property_test.dart`.

  - [ ] 3.7 Write property test for sorting
    - **Property 19: Sorting orders, keeps, and does not mutate**
    - **Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.5, 6.7**
    - Create `test/domain/grave_sorter_property_test.dart`.

  - [ ] 3.8 Write property test for sort confluence
    - **Property 20: Sorting does not depend on the input order**
    - **Validates: Requirements 6.6**
    - Create `test/domain/grave_sorter_order_property_test.dart`.

  - [ ] 3.9 Write property test for duplicates
    - **Property 21: Duplicate rules**
    - **Validates: Requirements 6.8, 6.9, 6.10, 6.11, 6.13**
    - Create `test/domain/duplicate_rules_property_test.dart`.

- [ ] 4. Parsing `owner/repo` and GitHub URLs
  - [ ] 4.1 Implement `RepoRef` and `RepoInputParser`
    - Create `repo_ref.dart` (`isValidOwner`, `isValidRepo` including the rule that a Repo_Name may not end in `.git` in any letter case, `toString` as `owner/repo`), `repo_parse_problem.dart`, `repo_parse_result.dart` (sealed), `repo_parsed.dart`, `repo_parse_failed.dart` and `repo_input_parser.dart`, following the design algorithm: trim, cut at `?` and `#`, scheme `http` or `https` only, host `github.com` or `www.github.com`, first two path segments, strip one `.git`, reject `.` and `..`, keep letter case, never throw and never decode percent escapes.
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10_

  - [ ] 4.2 Extend the test generators with repository references
    - Add `anyRepoRef` (owner of 1 to 39 characters, repo of 1 to 100 characters, never `.`, `..` or ending in `.git`), `anyUrlDecoration` (scheme, host case, whitespace, trailing slash, `.git`, extra segments, query, fragment) and `anyUrlText` (text assembled from URL fragments and arbitrary code points) to `test/domain/support/grave_generators.dart`.
    - _Requirements: 17.3_

  - [ ] 4.3 Write unit tests for `RepoInputParser`
    - Create `test/domain/repo_input_parser_test.dart`: the four inputs of Requirement 3.8, each failure kind, `.`, `..`, `repo.git`, `repo.GIT`, a repo that is only `.git`, `github.com` alone, `example.com/a/b`, `ftp://github.com/a/b`, owner with a leading hyphen, owner over 39 characters, repo over 100 characters, empty and whitespace-only input, and letter case kept.
    - _Requirements: 3.1 to 3.10_

  - [ ] 4.4 Write property test for the repository reference round trip
    - **Property 7: Repo reference round trip**
    - **Validates: Requirements 3.1, 3.9, 3.11**
    - Create `test/domain/repo_ref_round_trip_property_test.dart`.

  - [ ] 4.5 Write property test for optional URL parts
    - **Property 8: Optional URL parts do not change the reference**
    - **Validates: Requirements 3.2, 3.3, 3.9, 3.12**
    - Create `test/domain/repo_input_decoration_property_test.dart`.

  - [ ] 4.6 Write property test for parser totality
    - **Property 9: The input parser is total and only returns valid references**
    - **Validates: Requirements 3.4, 3.6, 3.10**
    - Create `test/domain/repo_input_total_property_test.dart`.

- [ ] 5. Parsing the GitHub response
  - [ ] 5.1 Implement the failure types, `RepoResponseParser` and `RateLimitWait`
    - Create `import_failure_kind.dart`, `import_failure.dart` (`resetAt` for `rateLimited` only), `fetched_repo.dart`, `fetch_result.dart` (sealed), `fetch_succeeded.dart`, `fetch_failed.dart`, `repo_response_parser.dart` and `rate_limit_wait.dart`.
    - Parser rules: `jsonDecode` inside `try` with `on Object`; a non-object body is `malformedResponse`; `pushed_at` must be a string that matches `^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$` and that `DateTime.parse` accepts (a date without time, or a time without `Z` or a numeric offset, is `malformedResponse`); `updated_at` and `created_at` are never read; apply the injected `ZoneConverter` to the UTC instant, then read year, month and day; clamp to Today and to 1970-01-01.
    - Safety rules: `full_name` is used only when it is a string of 1 to 140 code points after normalisation, otherwise the requested `owner/repo`; `stargazers_count` accepts an integral non-negative `num` (so `12.0` on the VM and `12` on the web give the same result), otherwise 0; every unknown field is ignored.
    - `RateLimitWait.minutes` is `max(1, (ms + 59999) ~/ 60000)`.
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 4.10, 4.11, 4.12, 4.13, 4.14, 4.15, 4.17, 9.3_

  - [ ] 5.2 Extend the test generators with JSON
    - Add `anyJsonText`, `anyJsonValue` (depth at most 4), mutators that replace one field with a value of another type (absent, `null`, string, integer, negative integer, boolean, list, object), a `pushedAtBody` builder, and an `anyCorruption` list for the codec to `test/domain/support/grave_generators.dart`.
    - _Requirements: 17.3_

  - [ ] 5.3 Write unit tests for `RepoResponseParser` and `RateLimitWait`
    - Create `test/domain/repo_response_parser_test.dart`: the four real repositories at fixed offset +00:00 with the dates, archived flags and star counts of Requirement 4.16, `updated_at` different from `pushed_at` and ignored, the three offset cases of Requirements 4.18, 4.19 and 4.20 (mandatory, with "Died today" through `DeadForFormatter` for the first two), clamps in both directions, every default of Requirements 4.5 to 4.9, `full_name` fallback (empty, non-string, over 140 code points), `pushed_at` without `Z` or offset, `pushed_at` as a date only, and a `12.0` star count.
    - Create `test/domain/rate_limit_wait_test.dart`: 30 s gives 1, 61 s gives 2, a past reset gives 1.
    - _Requirements: 4.1 to 4.21, 9.3_

  - [ ] 5.4 Write property test for the local date
    - **Property 10: The local date is the instant plus the offset**
    - **Validates: Requirements 4.1, 4.3, 4.17, 4.22**
    - Create `test/domain/local_date_property_test.dart`, comparing against integer arithmetic `floorDiv(seconds + offsetSeconds, 86400)`.

  - [ ] 5.5 Write property test for a push made now
    - **Property 11: A push made now reads as "Died today"**
    - **Validates: Requirements 4.18, 4.22**
    - Create `test/domain/died_today_property_test.dart`. It uses `DeadForFormatter` from task 6.1.

  - [ ] 5.6 Write property test for clamping
    - **Property 12: Clamping keeps the date in range**
    - **Validates: Requirements 4.12, 4.13**
    - Create `test/domain/clamp_property_test.dart`.

  - [ ] 5.7 Write property test for optional fields
    - **Property 13: Optional fields default, extra fields are ignored**
    - **Validates: Requirements 4.2, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 4.14**
    - Create `test/domain/response_defaults_property_test.dart`.

  - [ ] 5.8 Write property test for a missing push date
    - **Property 14: A body without a usable push date is malformed**
    - **Validates: Requirements 4.2, 4.10, 4.11**
    - Create `test/domain/response_malformed_property_test.dart`.

  - [ ] 5.9 Write property test for response parser totality
    - **Property 15: The response parser is total**
    - **Validates: Requirements 4.15**
    - Create `test/domain/response_total_property_test.dart`, including deeply nested JSON.

  - [ ] 5.10 Write property test for the rate-limit wait
    - **Property 22: The rate-limit wait is rounded up and at least one minute**
    - **Validates: Requirements 9.3**
    - Create `test/domain/rate_limit_wait_property_test.dart`.

- [ ] 6. Dead-for text
  - [ ] 6.1 Implement `DeadForUnit`, `DeadFor` and `DeadForFormatter`
    - Create `dead_for_unit.dart` (order: today, days, weeks, months, years), `dead_for.dart` (`between`, `text`) and `dead_for_formatter.dart`, following the design's decision table. Use year, month and day arithmetic only. No `Duration` and no `DateTime` in these files.
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9, 5.10_

  - [ ] 6.2 Write unit tests for the dead-for text
    - Create `test/domain/dead_for_test.dart`: Day_Counts 0, 1, 2, 6, 7, 13, 14, the end of February in a leap year and in a common year, the month-end clamp (2025-01-31 to 2025-02-28 gives "Dead for 1 month", to 2025-02-27 gives "Dead for 3 weeks"), the day before and the day of the first whole month and of the first whole year, a span across 2026-03-08 and 2026-10-25, a death date after Today, and the singular forms.
    - _Requirements: 5.1 to 5.9, 5.13_

  - [ ] 6.3 Write property test for the calendar model
    - **Property 16: The dead-for text follows the calendar model**
    - **Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.9**
    - Create `test/domain/dead_for_model_property_test.dart`.

  - [ ] 6.4 Write property test for well-formed text
    - **Property 17: The dead-for text is never malformed**
    - **Validates: Requirements 5.8, 5.11**
    - Create `test/domain/dead_for_shape_property_test.dart`.

  - [ ] 6.5 Write property test for monotonic age
    - **Property 18: Waiting one more day never makes the project look younger**
    - **Validates: Requirements 5.12**
    - Create `test/domain/dead_for_monotonic_property_test.dart`.

- [ ] 7. Checkpoint - Domain complete
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 8. Data layer
  - [ ] 8.1 Implement `SystemClock` and `GraveCodec`
    - Create `lib/src/data/system_clock.dart` (the only `DateTime.now()` call) and `grave_codec.dart` implementing `RecordCodec<Grave>`. Encode only JSON-safe values with a fixed key order and the date as `YYYY-MM-DD`; a manual grave has no `repo` key. Decode with the design's rules table: throw `FormatException` for a missing or invalid id (`KeyValidator`), a name that is empty or over 80 code points after normalisation, a malformed or impossible date, an unknown source, or a wrong type; default the optional `repo` fields; ignore unknown keys.
    - Remove `lib/src/data/.gitkeep`.
    - _Requirements: 1.1, 10.2, 10.3, 10.4, 10.5, 10.6_

  - [ ] 8.2 Implement `GraveStorage`
    - Create `grave_storage.dart` with `boxName` `graveyard_graves`, `currentVersion` 1, `subDirectory` `graveyard`, `open(StorageOpener)` and `memory()` (a `MemoryRecordRepository<Grave>` with `isPersistent` false).
    - _Requirements: 10.1, 10.12, 11.1_

  - [ ] 8.3 Write unit tests for `GraveCodec`
    - Create `test/data/grave_codec_test.dart`: the exact key sets for both shapes, every failure of Requirement 10.6, every tolerance of Requirements 10.4 and 10.5, `repo.full_name` falling back to the grave's name, and a stored date before 1970 accepted. No `dart:io` import.
    - _Requirements: 10.2, 10.4, 10.5, 10.6_

  - [ ] 8.4 Write property test for the codec round trip
    - **Property 23: Grave codec round trip**
    - **Validates: Requirements 10.2, 10.3**
    - Create `test/data/grave_codec_round_trip_property_test.dart`, including a trip through `jsonEncode` and `jsonDecode`.

  - [ ] 8.5 Write property test for unknown and missing fields
    - **Property 24: The codec ignores unknown fields and fills missing optional ones**
    - **Validates: Requirements 10.4, 10.5**
    - Create `test/data/grave_codec_tolerance_property_test.dart`.

  - [ ] 8.6 Write property test for corrupt records
    - **Property 25: Corrupt records are rejected**
    - **Validates: Requirements 10.6**
    - Create `test/data/grave_codec_corruption_property_test.dart`.

  - [ ] 8.7 Write unit tests for `GraveStorage`
    - Create `test/data/grave_storage_test.dart` with a fake `StorageOpener`: box name, version 1, sub directory `graveyard`, `isPersistent` taken from the opener, and a corrupt seed entry in `MemoryRecordRepository` skipped while the readable entries load.
    - _Requirements: 10.1, 10.7, 10.12_

  - [ ] 8.8 Create the failing repository test double
    - Create `test/support/throwing_record_repository.dart` (`ThrowingRecordRepository` implementing `RecordRepository<Grave>`, throwing on `put`, `delete` or `getAll` on demand). It does not import `dart:io`.
    - _Requirements: 10.10, 10.11_

- [ ] 9. GitHub client
  - [ ] 9.1 Implement `GitHubClient` and `HttpGitHubClient`
    - Create `lib/src/data/github_client.dart` (`fetch(RepoRef, {required CalendarDate today})`, never throws) and `http_github_client.dart` (the only file that imports `package:http` and the only file with an `api.github.com` URL). One GET to `https://api.github.com/repos/{owner}/{repo}` built with `pathSegments`, only the header `Accept: application/vnd.github+json`, no `Authorization`, no `User-Agent`, no other header. Request timeout of 10 seconds through an injectable `TimeoutTimerFactory`; a late response is dropped. Map 200 to the parser, 404 to `notFoundOrPrivate`, 429 or 403 with `x-ratelimit-remaining: 0` or `retry-after` to `rateLimited` (`Retry-After` wins over `x-ratelimit-reset`, with the design's bounds), anything else to `unexpectedStatus`, every thrown error to `offline`, and a last `catch (Object)` around the whole method.
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 7.9, 7.10, 7.11, 7.12, 7.13, 7.14, 7.15, 7.16, 15.4_

  - [ ] 9.2 Create `FakeGitHubClient`
    - Create `test/support/fake_github_client.dart`: scripted results, records every call (ref and today), and can hold a result open with a `Completer`. Results use `FixedOffsetZone`, so no widget test depends on the machine's time zone. No network call.
    - _Requirements: 7.17, 17.7_

  - [ ] 9.3 Write `MockClient` tests for `HttpGitHubClient`
    - Create `test/data/http_github_client_test.dart`: exactly one GET to the exact URL, `Accept` set, no `Authorization`, percent-encoding of the path, statuses 200, 404, 429, 403 with and without `x-ratelimit-remaining: 0` and `Retry-After`, 301, 500, `Retry-After` and `x-ratelimit-reset` with and without a readable value (and both together), `ClientException` and any other exception giving `offline`, a malformed 200 body giving `malformedResponse`, the timeout with a manual timer and a request that never completes (no test waits 10 real seconds), and a late response after the timeout dropped. No `dart:io` import.
    - _Requirements: 7.1 to 7.19, 17.6_

- [ ] 10. Checkpoint - Data layer and client complete
  - Ensure all tests pass, ask the user if questions arise. Also run `flutter test --platform chrome test/domain test/data` in `apps/graveyard`; it must pass.

- [ ] 11. Controller
  - [ ] 11.1 Implement the controller state types
    - Create in `lib/src/ui`: `grave_list_status.dart` (loading, ready, loadError), `save_status.dart` (saved, saving, saveError), `import_state.dart` (sealed), `import_idle.dart`, `import_running.dart`, `import_input_rejected.dart`, `import_fetch_failed.dart`, `import_duplicate_found.dart` and `import_succeeded.dart`.
    - _Requirements: 8.2, 8.5, 8.6, 8.7_

  - [ ] 11.2 Implement `GraveListController`
    - Create `grave_list_controller.dart` (a `ChangeNotifier`, no package): `load` (also the retry), `refreshToday`, `addManual`, `startImport`, `cancelImport`, `deleteGrave`, `retrySave`, `disposeStorage`, `dispose`, plus `graves` (sorted, unmodifiable), `status`, `saveStatus`, `isPersistent`, `importState`, `clock` and `today`.
    - Follow the design rules: Today read from the Clock at each add and import; one in-flight import with a generation counter so a result after `cancelImport` or `dispose` is dropped; duplicate check against the list as it is when the result arrives; change memory first, notify, then write through one ordered write chain; report saved only after the writes finish; keep state and the pending ids on a failed write and repeat them in `retrySave`; every notification goes through `_notify()`, which does nothing after disposal; `disposeStorage` swallows a `StateError`; no timer.
    - _Requirements: 2.1, 2.10, 6.8, 6.9, 8.2, 8.3, 8.5, 8.6, 8.7, 8.8, 8.9, 8.10, 8.11, 8.12, 10.8, 10.9, 10.10, 10.11, 11.1, 12.14, 12.17_

  - [ ] 11.3 Write unit tests for `GraveListController`
    - Create `test/support/controller_harness.dart` (builds a controller from `FakeClock`, `FakeGitHubClient` and a `MemoryRecordRepository<Grave>` with the real `GraveCodec`) and `test/ui/grave_list_controller_test.dart`: load with no data, with data and with a corrupt entry; sort after an add; by-hand add and every rejection leaving the list unchanged; import success, each failure, input rejected without a request, duplicate; a long imported name cut to 79 characters plus `…` while `full_name` stays whole; double submit starting one request; `cancelImport` and dispose with a late result dropped and no notification after dispose; Today read at each add; write order; failed write then retry; failed load then retry; memory fallback; delete.
    - _Requirements: 2.1, 2.10, 6.8, 6.9, 8.1 to 8.12, 10.7 to 10.11, 11.1, 17.5_

- [ ] 12. Graveyard screen widgets
  - [ ] 12.1 Implement `GraveyardCopy`
    - Create `lib/src/ui/graveyard_copy.dart` holding every user-facing string, exactly the messages of the design's error taxonomy, short, spooky and kind, with no "failed", "invalid" or "your fault", no exception text and no raw status code, and the date line with English month names and no `intl` package.
    - _Requirements: 9.1 to 9.10, 12.4, 13.6, 13.7_

  - [ ] 12.2 Implement `GraveTile`
    - Create `grave_tile.dart`: `TombstoneCard` with the name as the title, the date line, the Dead_For_Text in the body, and the epitaph shown only while `textScaler.scale(1) <= 1.2`. A GitHub grave shows `full_name`, the star glyph and count, "Archived" in words, and the description as plain `Text` with `maxLines: 3` and an ellipsis; a manual grave shows "Buried by hand.". One `Semantics(container: true)` label with the name, the Dead_For_Text, the source, and the full description and archived state; the card is excluded from semantics. A delete button below the card (48 by 48, label `Delete <name>`, hover and press states).
    - _Requirements: 12.2, 12.3, 12.4, 12.5, 12.6, 12.7, 12.8, 14.1, 14.2, 14.3, 14.10, 14.11_

  - [ ] 12.3 Implement the add sheet and its forms
    - Create `add_mode.dart`, `add_grave_sheet.dart` (modal bottom sheet, `isScrollControlled`, `useSafeArea`, keyboard padding, a `SegmentedButton<AddMode>` of at least 48 by 48; `showAddGraveSheet` calls `cancelImport()` when the sheet closes for any reason; Escape closes it through `CallbackShortcuts`), `bury_by_hand_form.dart` (name field, date field that opens `showDatePicker` with `firstDate` 1970-01-01 and `lastDate` Today, Enter submits, rejection reason under the field, text kept) and `import_form.dart` (one field, Enter submits, `GhostLoader` with a caption and a disabled submit while running, the failure message in a `liveRegion`, a "Try again" button, text kept, field, selector and close always enabled).
    - _Requirements: 8.1, 8.2, 8.4, 8.7, 9.11, 9.12, 12.9, 12.10, 12.11, 14.5_

  - [ ] 12.4 Implement the dialog and the state panels
    - Create `delete_grave_dialog.dart` (`AlertDialog` naming the grave, "Keep it" with `autofocus: true` and "Delete", `Semantics(scopesRoute: true, namesRoute: true, label: 'Delete <name>?')`, Escape closes it), `empty_graveyard_panel.dart` (invitation naming both ways and one button for each, opening the sheet on that option), `memory_notice.dart`, `save_error_banner.dart` (Try again) and `load_error_view.dart` (Try again).
    - _Requirements: 10.10, 10.11, 11.2, 11.4, 12.12, 12.13, 13.1, 13.2, 13.3, 13.5, 14.4, 14.5_

  - [ ] 12.5 Implement `GraveyardScreen`
    - Create `graveyard_screen.dart`: `Scaffold` over `FogBackground`, a centered column of max width 560 in a scrolling list with 16 px side padding and 96 bottom padding, `ListenableBuilder` on the controller, the loading `GhostLoader` with a caption inside `Semantics(label: 'Loading graves')`, the state table of the design (loading, loadError, empty, list, Memory_Notice, save banner), an extended `FloatingActionButton` that opens the sheet, the delete flow through the dialog, and a `WidgetsBindingObserver` that calls `refreshToday()` on resume. No moving effect when `MediaQuery.disableAnimations` is true. Color only from `CoffinTheme` tokens.
    - _Requirements: 12.1, 12.12, 12.13, 12.14, 12.15, 12.17, 12.18, 13.1, 13.2, 13.3, 13.4, 14.1, 14.6, 14.8, 14.9, 14.12_

- [ ] 13. Wiring and cleanup
  - [ ] 13.1 Wire the app and remove the placeholder
    - Change `lib/src/ui/app_routes.dart` to `buildAppRoutes(GraveListController)` with the single route `/` named `home` showing `GraveyardScreen`. Make `GraveyardApp` take a required `GraveListController`, call `load()` in `initState` and `disposeStorage()` in `dispose`, and keep `CoffinTheme.dark()` and `FogRouter`. Update `lib/main.dart` to build `SystemClock`, `HttpGitHubClient(clock: clock)` and the controller with `StorageOpener(initializer: () => hiveFlutterInitializer(GraveStorage.subDirectory))`.
    - Delete `lib/src/ui/placeholder_screen.dart` and `test/ui/placeholder_screen_test.dart`. Update `test/ui/app_routes_test.dart` so it compiles and passes against the new routes.
    - _Requirements: 10.1, 12.1, 12.16, 15.1, 15.6, 15.7_

- [ ] 14. Screen tests
  - [ ] 14.1 Write widget tests for the screen states
    - Create `test/ui/graveyard_screen_test.dart` using `FakeClock`, `FakeGitHubClient` and `MemoryRecordRepository<Grave>`: loading (caption and the "Loading graves" label), empty with both invitation buttons, list, load error with retry, Memory_Notice shown and hidden, save error banner with the tombstones still visible, retry of a save.
    - _Requirements: 11.2, 11.3, 12.15, 13.1, 13.2, 13.3, 13.4, 13.5, 14.12, 17.7_

  - [ ] 14.2 Write widget tests for adding and importing
    - Create `test/ui/add_import_test.dart`: add by hand, each by-hand rejection shown under the field with the text kept, the date picker bounds, import from the `FakeGitHubClient`, a parse problem starting no request, each import failure message with the typed text kept and "Try again" and the by-hand option still usable, the failure message as a live region, the double-submit guard (disabled submit and one request), closing the sheet during an import adding nothing, and the duplicate message with the text kept.
    - _Requirements: 6.12, 8.1 to 8.9, 9.1 to 9.12, 12.9, 12.10, 12.11, 17.8_

  - [ ] 14.3 Write widget tests for delete, sort and "Died today"
    - Create `test/ui/delete_and_order_test.dart`: the delete confirmation names the grave, confirm removes it from the list and the repository, cancel leaves the list unchanged, the sort order after an add, and the `flutter/flutter` import reading "Died today" with a `FixedOffsetZone` and a `FakeClock` on the same instant.
    - _Requirements: 4.18, 6.1, 12.12, 12.13, 12.14, 12.18, 17.8_

  - [ ] 14.4 Write widget tests for `GraveTile`
    - Create `test/ui/grave_tile_test.dart`: the semantic label for a manual and for a GitHub grave (name, Dead_For_Text, source, full untruncated description, archived), the description limited to 3 lines with an ellipsis, "Archived" shown in words, and Markdown and `:atom:` shortcodes shown as plain text.
    - _Requirements: 12.5, 12.6, 12.7, 12.8, 14.3, 14.10, 14.11_

  - [ ] 14.5 Write widget tests for layout, accessibility and reduced motion
    - Create `test/ui/layout_test.dart`: no overflow exception at 320 and 360 px width, at text scale 1.0 and 1.5, in the states list, empty, loading, error and the add sheet with a failure message; tap targets of at least 48 by 48; semantic labels on every control; the epitaph hidden above text scale 1.2 and shown below it; Enter submits and Escape closes the sheet and the delete dialog without changing the list; focus moves into the delete dialog and returns to the delete button after it closes; hover and press states; `disableAnimations` giving the still `GhostLoader` frame.
    - _Requirements: 14.1 to 14.12, 17.9_

  - [ ] 14.6 Write the copy test
    - Create `test/ui/graveyard_copy_test.dart`: no string in `GraveyardCopy` contains "failed", "invalid" or "your fault", one distinct message per `ImportFailureKind`, no raw status code, no exception text, and the rate-limit message shows the minutes from `RateLimitWait` (never less than 1).
    - _Requirements: 9.1 to 9.10, 13.6, 13.7_

  - [ ] 14.7 Write route tests
    - Extend `test/ui/app_routes_test.dart`: `/` shows `GraveyardScreen`, there is one route named `home`, an unknown location shows `NotFoundPage`, and its button returns to the screen.
    - _Requirements: 12.16, 17.10_

- [ ] 15. Source-rule tests
  - [ ] 15.1 Write source-rule tests for the domain
    - Create `test/source_rules/domain_sources_test.dart`: no `package:flutter`, `dart:io`, `dart:html`, `package:http` or `package:hive_ce` under `lib/src/domain`; no `DateTime.now` outside `system_clock.dart`; no `Duration` in the date-count files (`calendar_date.dart`, `dead_for.dart`, `dead_for_formatter.dart`); no `Timer` outside `http_github_client.dart`. This folder is the only place that reads source files with `dart:io`.
    - _Requirements: 1.1, 1.3, 5.10, 15.2, 17.11_

  - [ ] 15.2 Write source-rule tests for HTTP and secrets
    - Create `test/source_rules/http_rules_test.dart`: `package:http` imported only by `http_github_client.dart`; no `Authorization`; `api.github.com` appears once, in that file; no `ghp_`, `github_pat_` or `token` in `lib/`.
    - _Requirements: 7.4, 15.4, 16.8, 17.11_

  - [ ] 15.3 Write source-rule tests for imports
    - Create `test/source_rules/import_rules_test.dart`: no import of `coffin_core/src`; no import of Hauntagotchi; `ui` files import no Hive and not `data/http_github_client.dart`; no state-management package in `apps/graveyard/pubspec.yaml`.
    - _Requirements: 15.1, 15.3, 15.6, 17.11_

  - [ ] 15.4 Write the generator-rules test
    - Create `test/source_rules/generator_rules_test.dart`: none of `any.int`, `any.intInRange`, `any.list`, `any.listWithLengthInRange`, string generators or `uint*` appears under `test/`, and no file under `test/domain` or `test/data` contains `dart:io`.
    - _Requirements: 17.2, 17.3_

- [ ] 16. Deploy workflow
  - [ ] 16.1 Add Graveyard analyze and test steps to `deploy-web.yml`
    - First run `git diff --exit-code -- .github/workflows/deploy-web.yml`. If it shows changes the feature did not make, stop and ask the user.
    - Read `.github/workflows/deploy-web.yml`. In the `build` job, the current order is: "Test hauntagotchi" (`working-directory: apps/hauntagotchi`, `run: flutter test`), then "Build hauntagotchi", then "Build graveyard". Insert the two steps after the blank line that follows the "Test hauntagotchi" step and before `- name: Build hauntagotchi`, with the same 6-space step indent and one blank line between steps:

      ```yaml
            - name: Analyze graveyard
              working-directory: apps/graveyard
              run: flutter analyze

            - name: Test graveyard
              working-directory: apps/graveyard
              run: flutter test

      ```

    - Change nothing else in the file: no other step, no reordering, no version bump, no formatting change, no change to the trailing newline. A failing Graveyard analyze or test must stop the job before any build, so the deploy job never runs.
    - Diff review (required, paste the output into the task report): `git diff -U0 -- .github/workflows/deploy-web.yml` shows exactly one hunk with only added lines and no removed line, `git diff --numstat -- .github/workflows/deploy-web.yml` reports 8 added and 0 removed lines, the hunk starts right after the "Test hauntagotchi" `run: flutter test` line and its blank line, and the first line after the hunk is `- name: Build hauntagotchi`. Check the step names appear in the order Test hauntagotchi, Analyze graveyard, Test graveyard, Build hauntagotchi, Build graveyard.
    - _Requirements: 16.1, 16.7_

- [ ] 17. Final verification
  - [ ] 17.1 Run the full verification plan
    - In `apps/graveyard`, run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` (zero issues), `flutter test`, and `flutter test --platform chrome test/domain test/data`. Check `grep -rl "dart:io" test/domain test/data` finds nothing and `grep -rniE "ghp_|github_pat_|authorization" lib` finds nothing.
    - Run `flutter test` in `apps/hauntagotchi`, in `packages/coffin_core` and in `tool/` (template integrity, raiser and repo-guard tests, with nothing else editing `apps/`), then `flutter test --tags raise-check --run-skipped` in `tool/`. All must pass unchanged.
    - Run `flutter pub get --enforce-lockfile` at the repo root and check `git diff -U0 -- pubspec.lock` still equals the diff reported in task 1.2 (only the `http` entry).
    - Check `git diff --exit-code -- packages/coffin_core apps/hauntagotchi tool` exits 0, so the `tool/templates` raise template is unchanged too.
    - Check `git diff -U0 -- apps/graveyard/pubspec.yaml` shows only the two added lines, `git diff -U0 -- CREDITS.md` shows only the `## Packages` heading and the `http` entry, and `git diff -U0 -- .github/workflows/deploy-web.yml` shows only the eight added lines of task 16.1.
    - Check `git status --short` lists only these allowed paths: `apps/graveyard/lib`, `apps/graveyard/test`, `apps/graveyard/pubspec.yaml`, `pubspec.lock`, `CREDITS.md`, `.github/workflows/deploy-web.yml` and `.kiro/specs/graveyard-core`. If it lists any other path, report it to the user and do not revert it.
    - Fix any failure at its cause. Create no file outside the repository, including `/tmp`.
    - _Requirements: 15.9, 16.1, 16.2, 16.3, 16.4, 16.5, 16.6, 16.7, 16.8, 17.11, 17.12_

## Notes

- Every test sub-task is required and none is marked optional. The project testing rules and Requirement 17.1 require unit tests for pure logic and glados property tests for numeric and calendar rules.
- Every property in the design (1 to 25) has its own sub-task: P1 (2.6), P2 (2.7), P3 (2.8), P4 (2.9), P5 (3.5), P6 (3.6), P7 (4.4), P8 (4.5), P9 (4.6), P10 (5.4), P11 (5.5), P12 (5.6), P13 (5.7), P14 (5.8), P15 (5.9), P16 (6.3), P17 (6.4), P18 (6.5), P19 (3.7), P20 (3.8), P21 (3.9), P22 (5.10), P23 (8.4), P24 (8.5), P25 (8.6).
- Task 1 must be the first change. Task 1.2 uses a plain `flutter pub get` because `--enforce-lockfile` fails by design while the lock must change; task 1.3 then proves the lock is stable.
- Tasks 2.8 and 5.5 use `DeadForFormatter`, so they run after task 6.1 (see the dependency graph).
- Generator tasks 2.3, 3.3, 4.2 and 5.2 all edit `test/domain/support/grave_generators.dart`, so they sit in different waves.
- The two deploy steps (16.1) come after all tests exist, so the new CI steps pass on the first run.
- This workflow only creates the plan. Start execution by opening this file and choosing "Start task" on a task.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2"] },
    { "id": 2, "tasks": ["1.3", "1.4"] },
    { "id": 3, "tasks": ["2.1"] },
    { "id": 4, "tasks": ["2.2", "2.3", "2.4", "4.1", "6.1"] },
    { "id": 5, "tasks": ["2.5", "2.6", "2.7", "2.9", "3.1", "4.3", "5.1", "6.2", "6.3", "6.4", "6.5"] },
    { "id": 6, "tasks": ["2.8", "3.2", "3.3", "5.3", "5.4", "5.5", "5.6", "5.10"] },
    { "id": 7, "tasks": ["3.4", "3.5", "3.6", "3.7", "3.8", "3.9", "4.2"] },
    { "id": 8, "tasks": ["4.4", "4.5", "4.6", "5.2"] },
    { "id": 9, "tasks": ["5.7", "5.8", "5.9"] },
    { "id": 10, "tasks": ["7"] },
    { "id": 11, "tasks": ["8.1", "8.8", "9.1"] },
    { "id": 12, "tasks": ["8.2", "8.3", "8.4", "8.5", "8.6", "9.2", "9.3"] },
    { "id": 13, "tasks": ["8.7"] },
    { "id": 14, "tasks": ["10"] },
    { "id": 15, "tasks": ["11.1", "12.1"] },
    { "id": 16, "tasks": ["11.2"] },
    { "id": 17, "tasks": ["11.3", "12.2", "12.3", "12.4"] },
    { "id": 18, "tasks": ["12.5"] },
    { "id": 19, "tasks": ["13.1"] },
    { "id": 20, "tasks": ["14.1", "14.2", "14.3", "14.4", "14.5", "14.6", "14.7", "15.1", "15.2", "15.3", "15.4"] },
    { "id": 21, "tasks": ["16.1"] },
    { "id": 22, "tasks": ["17.1"] }
  ]
}
```
