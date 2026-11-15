# Implementation Plan: coffin-ai

## Overview

Build the AI layer of `coffin_core` in dependency order, with the unit tests for each step in the same task. First a baseline check that no pubspec changes. Then the value types (`AiPurpose`, `ReplySource`, `TextRules`, `AiRequest`, `AiFactKeys`, `AiReply`, the issue types, the reporter, `AiFallbackError`, `AiTimerFactory`), then the `CoffinAI` interface, then the pure test support (generators, test-side word lists, `FakeClock`, `ScriptedCoffinAI`) and the property tests of the value types and text rules. Then the internals: `SeededRandom` with the exact reference table, `CleanFacts`, `Template`, the verbatim catalog with its audit test, and `OfflineEngine` with the Recovery tests. After a checkpoint come `OfflineCoffinAI` (with the golden table and Properties 1 to 9) and `FallbackCoffinAI` (with example tests and Properties 18 to 22), a second checkpoint, the barrel, the source scan, the timing report, the Chrome run and final verification.

All code is Dart in Flutter, following design.md. Paths are relative to the repo root. Tests use `flutter_test` and `glados`. `TextRules` is built before `AiReply` because `AiReply.isUsableFor` uses `TextRules.isBlank`. Every task is required. Nothing is optional.

Notes that apply to all tasks:

- Edit only files inside this repository (`/Users/ranmanlabs/Documents/Kiroween/coffin`). Write no scratch files outside it and use no shell redirections to paths outside it.
- Do not modify `requirements.md`, `design.md` or `.config.kiro` of this spec. Do not touch `DIARY.md` (the user keeps the diary). Do not touch any file under `.kiro/specs/crypt-storage/` or any crypt-storage source or test.
- Add no package and change no `pubspec.yaml` and no `pubspec.lock`. Use no `fake_async`, `characters`, `http` or any other new import. Only `dart:core`, `dart:async` (in `fallback_coffin_ai.dart` and `ai_timer_factory.dart` only) and `package:meta/meta.dart` are imported by AI source files.
- Do not wire the AI layer into either app. No app file imports or names the AI API.
- Follow design.md's file layout under `packages/coffin_core/lib/src/ai/`, one public class per file, `snake_case.dart`. Tests mirror it under `packages/coffin_core/test/ai/`. Test files import `src/` files directly, as the router and storage tests do. Internal names (`OfflineEngine`, `TemplateCatalog`, `SeededRandom` and so on) are never exported and get no public test hook.
- Every public member in `coffin_core` carries a doc comment (`public_member_api_docs` is enabled). Doc comments in `lib/src/ai/` must avoid the words the source scan forbids (for example write "reads no clock", never the API name; no URL text; no "bearer"; no "riverpod"). The scan reads raw text, comments included.
- AI source files are plain Dart: no Flutter, `dart:io`, `dart:html`, `dart:math`, storage, router, theme, widgets, go_router, hive or riverpod. No `String.hashCode` or `Object.hashCode` in the generator files. No unseeded `Random`.
- All AI test support under `test/ai/support/` is pure and Chrome-safe. It imports no `dart:io`, no `hive_ce`, no `flutter` UI and nothing from `test/storage/support`.
- `glados` exports its own `expect`, `group` and `test`, so test files `hide` the clashing names from the glados import, as `packages/coffin_core/test/router/fog_math_property_test.dart` does. Tag each property with `// Feature: coffin-ai, Property N: <title>` and `// Validates: Requirements ...`.
- Run counts from the design: 500 runs for Properties 1 to 9 and 12; 300 runs for Properties 10, 11, 13 to 17; 200 runs for Properties 18 to 22 with at most 8 steps per sequence. Never lower a run count or sequence length. See the timing task.
- Every property test counts its runs with a `RunCounter` (top-level counter incremented in the body). A plain `test(...)` declared after the glados test in the same group asserts `runs > 0` and `runs == numRuns`. Wrapper properties also count calls and assert `calls > 0`.
- Use only these glados generators: `choose`, `either`, `oneOf`, `always`, `bool`, `combine2` to `combine10`, `doubleInRange`, `nullable`, `map`, `simple`. Use the helpers `anyIntBetween` and `anyListBetween` from `test/ai/support/ai_generators.dart`. Never use `any.intInRange`, `any.listWithLengthInRange`, `any.int`, `any.list`, `any.letters`, `any.letterOrDigits`, `any.stringOf` or any other glados string generator, `uint32`, `uint8`, `uint16`, `positiveIntOrZero` or `nonEmptyList`. They throw on Flutter Web. Keep every generated integer below 2^53, and never write `1 << 32`.
- Async glados bodies are awaited on the VM and on Chrome. Each run owns its own clock, wrapper, reporter and zone, because glados re-runs a failed body once without awaiting it. Wrap asserts in `try`/`catch` and rethrow a `TestFailure` that includes `describeRequest` or the generated sequence, so failures show the input.
- Tests pump microtasks with a fixed loop of `await Future<void>.value()` and never loop on `Future.delayed(Duration.zero)`, which costs about 4.5 ms per await on Chrome.
- Every AI test file runs on both the Dart VM and Chrome, except `ai_sources_test.dart`, which carries `@TestOn('vm')`. No Chrome-run file imports `dart:io`.
- Do not mark a task done until `flutter test` passes in `packages/coffin_core`. Tasks that touch only `coffin_core` need only that package to pass; the final verification task covers both apps.
- If any recorded number from design.md is not reproduced by the implementation (PRNG reference outputs, filled template lengths), STOP and report to the user. Never edit an expected value to make a test pass.
- Tests render with the Ahem font, so never assert on glyph shapes. (The AI layer has no UI, so this rarely applies.)

## Tasks

- [ ] 1. Baseline and dependency guard
  - [ ] 1.1 Record the pubspec baseline
    - Read `packages/coffin_core/pubspec.yaml`, `apps/hauntagotchi/pubspec.yaml`, `apps/graveyard/pubspec.yaml` and `pubspec.lock`. Run `git status --short` and `git diff --stat HEAD -- packages/coffin_core/pubspec.yaml apps/hauntagotchi/pubspec.yaml apps/graveyard/pubspec.yaml pubspec.lock`.
    - Record the baseline in the task summary: for each of the four files, whether it equals HEAD now, and a content hash from `git hash-object <file>`. If crypt-storage work already left one of them different from HEAD, say so. That difference is not caused by this feature, and the final check (task 15.3) compares against both HEAD and this recorded hash.
    - Confirm `glados`, `flutter_test` and `meta` are already declared in `packages/coffin_core/pubspec.yaml`. Add and change nothing.
    - Create no files in this task.
    - _Requirements: 16.9, 17.7, 12.7_

- [ ] 2. Value types
  - [ ] 2.1 Implement `IdentifierRules`, `AiPurpose` and `ReplySource`
    - Create `identifier_rules.dart` (internal), `ai_purpose.dart` and `reply_source.dart` in `packages/coffin_core/lib/src/ai/`, as in design.md.
    - Identifier rules: 1 to 64 code units for `AiPurpose` (32 for `ReplySource`), first character `a` to `z`, the rest `a` to `z`, `0` to `9` or `_`. The factory throws `ArgumentError` for a bad identifier, and the message gives a length or an index and never repeats the string. The two known constants use the private `const` constructor: `AiPurpose.ghostMoodLine` (`ghost_mood_line`), `AiPurpose.seanceVerdict` (`seance_verdict`) and `ReplySource.offline` (`offline`). `AiPurpose.maxIdLength` is 64 and `AiPurpose.violation(String)` is public. Equality and hash are on the identifier only, so `AiPurpose('ghost_mood_line') == AiPurpose.ghostMoodLine`. `toString` prints `AiPurpose(id)` and `ReplySource(name)`.
    - Add `identifier_rules_test.dart`, `ai_purpose_test.dart` and `reply_source_test.dart`: valid and invalid identifiers (empty, 64 and 65 units, leading digit, uppercase, space, `-`, accents, the display text "séance verdict"), the error message does not contain the rejected string, the constants are `const`, a custom purpose reusing a known identifier equals the constant and has the same hash, `ReplySource` cap of 32 and 33, `ReplySource('remote')` is accepted and not equal to `offline`, the name is stable and readable.
    - _Requirements: 2.3, 2.12, 2.13, 2.14, 2.15, 2.16, 3.4, 3.5, 12.1, 15.1, 16.1, 16.5, 17.3_

  - [ ] 2.2 Implement `TextRules` with the verbatim word lists
    - Create `text_rules.dart` (internal) with `bannedWords` (the 20 words, verbatim from design.md: `gore`, `blood`, `kill`, `murder`, `slaughter`, `mutilat`, `dismember`, `decapitat`, `behead`, `entrails`, `viscera`, `massacre`, `torture`, `stabbing`, `stabbed`, `severed`, `bludgeon`, `strangle`, `disembowel`, `maim`), `insultWords` (the 13 words, verbatim: `stupid`, `idiot`, `lazy`, `loser`, `useless`, `worthless`, `pathetic`, `dumb`, `failure`, `hopeless`, `incompetent`, `pitiful`, `ugly`), `maxNameLength` 24, `ellipsis` `\u2026`, `isWhitespaceUnit` (the Dart trim set listed in design.md), `isBlank` (empty is blank), `asciiLower` (A to Z only), `containsBanned`, `cleanName` and `truncate` exactly as specified in design.md (cleaning steps 1 to 5, truncation steps 1 to 5).
    - Add `text_rules_test.dart`: both word lists have the exact words and sizes (20 and 13), `asciiLower` leaves the Kelvin sign and accents alone, every whitespace unit of the set is blank, `containsBanned` is a substring match on the folded text (`BLOODhound` and `skillful` hit, `category`, `stable`, `august`, `gorgeous`, `claim` do not), `cleanName` examples (`'a\u0000  b\n'` gives `a b`, 14 ghost emoji gives 12, a lone surrogate is dropped, only whitespace gives empty, a cut at a high surrogate backs off one unit), `truncate` examples from design.md (`maxLength` 16 on a 48-unit text, two emoji at the cut give 15 units, text that already fits is unchanged).
    - _Requirements: 6.5, 6.10, 7.4, 7.5, 8.2, 8.3, 8.4, 8.5, 5.4, 15.2, 17.3_

  - [ ] 2.3 Implement `AiRequest` and `AiFactKeys`
    - Create `ai_request.dart` and `ai_fact_keys.dart`. `AiRequest` has `purpose`, `facts` (unmodifiable copy), `maxLength`, `seed` (default 0), `minimumMaxLength` 16 and `maxSeed` written as the literal `4294967295`. The constructor throws `ArgumentError` naming the minimum when `maxLength < 16`, and naming the allowed range when the seed is below 0 or above 4294967295. Odd facts (empty key, list, map, NaN, infinity, objects) are accepted. Equality compares the four fields with facts order independent, a pair is equal when `==` is true or both are NaN. The hash is the XOR of per-entry hashes combined with the other fields. `toString` prints the purpose id, the number of facts, `maxLength` and the seed, and no fact value. `AiFactKeys` is `abstract final class` with the four constants `streakCount`, `daysSinceLastCommit`, `ghostName`, `projectName`.
    - Add `ai_request_test.dart` and `ai_fact_keys_test.dart`: `maxLength` 15 throws, 16 and 17 are accepted, seed -1 and 4294967296 throw, seed 0 and 4294967295 are accepted, the default seed is 0, facts default to empty, mutating the caller's map after construction does not change the request, the facts map is unmodifiable, equality and hash with a different insertion order, NaN fact equals itself, `5` equals `5.0`, each of the four fields changes equality, odd facts are accepted, `toString` shows no fact value, the four key strings are exact.
    - _Requirements: 2.1, 2.2, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10, 2.11, 15.3, 15.4, 15.11, 15.12, 16.5, 17.3_

  - [ ] 2.4 Implement `AiReply`
    - Create `ai_reply.dart`: `const AiReply({required text, required source})`, value equality and hash over both fields, `isUsableFor(AiRequest)` (not blank by `TextRules.isBlank` and `text.length <= request.maxLength`) and a `toString` that prints the source and the length and never the text. Construction accepts any string.
    - Add `ai_reply_test.dart`: construction with empty, whitespace-only and very long text does not throw, equality and hash per field, `isUsableFor` for empty, whitespace-only (including U+00A0 and U+3000), exactly `maxLength`, `maxLength + 1`, `toString` has no text.
    - _Requirements: 3.1, 3.2, 3.3, 3.6, 3.7, 15.11, 17.3_

  - [ ] 2.5 Implement the issue types, the reporter, `AiFallbackError` and `AiTimerFactory`
    - Create `ai_issue_kind.dart` (`threw`, `timedOut`, `emptyReply`, `invalidReply`), `ai_issue.dart` (immutable, value equality, `AiIssue.forKind` with the four fixed messages from design.md, verbatim), `ai_issue_reporter.dart` (`AiIssueReporter` typedef, `discardAiIssues`, and the internal `reportAiIssueSafely` that swallows anything the reporter throws), `ai_fallback_error.dart` (`AiFallbackError implements Exception` with `primaryFailure` and `secondaryFailure` and a fixed `toString` with the two kind names) and `ai_timer_factory.dart` (`typedef AiTimerFactory = Timer Function(Duration duration, void Function() callback)`). Import `@immutable` from `package:meta/meta.dart`. No import of `src/storage`.
    - Add `ai_issue_test.dart`, `ai_issue_reporter_test.dart` and `ai_fallback_error_test.dart`: equality and hash per field, each fixed message text, the default reporter discards, a throwing reporter is swallowed and later calls still work, the error carries the two kinds, `toString` contains only fixed text and kind names.
    - _Requirements: 10.4, 10.5, 10.6, 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 10.3, 15.6, 15.11, 16.5, 17.3_

- [ ] 3. The interface
  - [ ] 3.1 Implement `CoffinAI`
    - Create `coffin_ai.dart`: `abstract interface class CoffinAI` with exactly one member, `Future<AiReply> ask(AiRequest request)`, and a doc comment stating the contract (a reply or an error, never a synchronous throw, no cancellation).
    - Add `coffin_ai_test.dart` with a small fake class in the test that implements `CoffinAI` and returns a reply, and a check that the interface has exactly the one expected member shape (the fake compiles with only `ask`).
    - _Requirements: 1.1, 1.2, 1.3, 1.5, 1.6, 17.3_

- [ ] 4. Pure test support
  - [ ] 4.1 Create the test-side texts and the web-safe generators
    - Create `test/ai/support/test_texts.dart`: the test-declared banned list (its own copy of the 20 words, not read from `TextRules`), the test-declared whitespace set, an ASCII fold, a lone-surrogate check, an edge-whitespace check, and an emoji counter.
    - Create `test/ai/support/ai_generators.dart`: independent web-safe copies of `anyIntBetween` and `anyListBetween` (the span may reach 4294967296, written as a literal), `anyAiPurpose` (known constants, custom valid identifiers, identifiers that reuse a known id, and custom ids with the `zzmark_` marker), `anyFacts` (known keys about 80% of the time, extra keys, an empty key, `int`, whole and fractional `double`, negative, 2^53 - 1, `NaN`, infinity, lists, maps, strings from a piece list with emoji, accents, CJK, control characters, lone surrogates, banned words and 40-unit text), `anySeed` (20% from the edge list 0, 1, 2147483647, 2147483648, 4294967294, 4294967295, otherwise `anyIntBetween(0, 4294967296)`), `anyMaxLength` (edges 16, 17, 80, 5000, otherwise 16 to 200), `anyAiRequest`, a `describeRequest` helper that prints the purpose id, every fact with escaping, the limit and the seed, and a `RunCounter`. Build strings from the piece list, never from glados string generators.
    - Add `test/ai/support/ai_generators_test.dart`: generated values stay in range (seed, `maxLength`, identifiers valid), the edge seeds appear, every generated purpose constructs, `describeRequest` is readable, and the test texts helpers behave on known strings.
    - _Requirements: 13.1, 13.7, 13.8, 13.9, 13.11, 14.10, 8.9, 16.2_

  - [ ] 4.2 Create `FakeClock` and `ScriptedCoffinAI`
    - Create `test/ai/support/fake_clock.dart`: `FakeClock` with a `create` method that is an `AiTimerFactory`, `advance(Duration)` that fires every due timer in due-time order synchronously with no microtask, `pendingTimers`, `now` (a plain `Duration`, no wall clock), and timers whose `cancel` and `isActive` behave like a real `Timer`.
    - Create `test/ai/support/scripted_ai.dart`: `ScriptedCoffinAI`, a primary driven by an outcome list. Outcomes: usable reply with a given source, synchronous throw, asynchronous error, never-completing future, reply completing later (controlled by a `Completer` the test completes), error completing later, empty or whitespace-only reply, overlong reply. It counts calls and records the request objects. Also a small `ScriptedSecondary` (throws, empty, overlong) for Property 21.
    - Add `fake_clock_test.dart` and `scripted_ai_test.dart` under `test/ai/support/`: timers fire in due order, `advance` is synchronous, a cancelled timer never fires, `pendingTimers` counts active timers only, each scripted outcome behaves as described, call counting.
    - _Requirements: 10.3, 14.1, 14.7, 12.2, 16.2_

- [ ] 5. Property tests for value types and text rules
  - [ ] 5.1 Write property test for purpose identifiers
    - Create `ai_purpose_property_test.dart`. `numRuns: 300`.
    - **Property 15: Purpose identifier rules and equality.** For any string (generator mixes valid identifiers, uppercase, digits first, spaces, accents, emoji, lone surrogates and lengths around 64), `AiPurpose(s)` is accepted exactly when the rules hold, and a rejected string raises `ArgumentError`. For any two accepted strings the purposes are equal exactly when the strings are equal, and equal purposes have equal hashes.
    - **Validates: Requirements 2.12, 2.13, 2.15, 2.16**

  - [ ] 5.2 Write property test for request equality and hash
    - Create `ai_request_property_test.dart`. `numRuns: 300`.
    - **Property 13: Request equality and hash.** For any request `r`, a request with the same purpose, a copy of the facts inserted in shuffled order, the same `maxLength` and the same seed is equal to `r` and has the same hash. Changing any one of the four fields gives a request that is not equal. Mutating the source map afterwards does not change the request.
    - **Validates: Requirements 2.1, 2.8, 2.9**

  - [ ] 5.3 Write property test for request validation
    - In `ai_request_property_test.dart`. `numRuns: 300`.
    - **Property 14: Request validation boundaries.** For any integers `maxLength` and `seed` (generated around 16 and around 0 and 4294967295, all below 2^53), the constructor throws `ArgumentError` exactly when `maxLength < 16`, or `seed < 0`, or `seed > 4294967295`, and otherwise returns a request that holds those values.
    - **Validates: Requirements 2.5, 2.6**

  - [ ] 5.4 Write property test for reply equality and the usable check
    - Create `ai_reply_property_test.dart`. `numRuns: 300`.
    - **Property 16: Reply equality and the usable check.** For any two texts and two sources, replies are equal exactly when both fields are equal and equal replies have equal hashes. For any text and request, `isUsableFor` equals a test-side oracle (not blank by the test's own whitespace set, and length at most `maxLength`). Construction never throws for any string.
    - **Validates: Requirements 3.1, 3.2, 3.3**

  - [ ] 5.5 Write property test for name cleaning
    - Create `text_rules_property_test.dart`. `numRuns: 300`.
    - **Property 10: Name cleaning.** For any string (generator with emoji, lone surrogates, control characters, runs of whitespace and long text), `TextRules.cleanName(s)` has at most 24 code units, no control character, no unpaired surrogate, no leading or trailing whitespace, no two adjacent whitespace units, and `cleanName(cleanName(s)) == cleanName(s)`.
    - **Validates: Requirements 6.5, 6.10**

  - [ ] 5.6 Write property test for truncation
    - In `text_rules_property_test.dart`. `numRuns: 300`.
    - **Property 11: Truncation keeps its promises.** For any string `s` that starts with a non-whitespace unit and has no unpaired surrogate, and any limit `m >= 16`, `TextRules.truncate(s, m)` has length at most `m`, is non-empty, has no unpaired surrogate and no trailing whitespace, equals `s` when `s.length <= m`, and otherwise ends with `…`.
    - **Validates: Requirements 7.4, 7.5**

- [ ] 6. Offline internals
  - [ ] 6.1 Implement `SeededRandom` with the exact reference table
    - Create `seeded_random.dart` (internal) with Mulberry32 exactly as in design.md: `_imul`, `nextUint32` and `nextInt(n)` for `1 <= n <= 65536` (assert `n >= 1`, never a limit near 2^32, no `1 << 32`, no `dart:math`).
    - Add `seeded_random_test.dart` with an exact-value unit test that asserts the first three `nextUint32()` values of design.md's table for every seed: seed 0 gives 1144304738, 1416247, 958946056; seed 1 gives 2693262067, 11749833, 2265367787; seed 42 gives 2581720956, 1925393290, 3661312704; seed 4294967295 gives 3850105811, 813802916, 3073704848. The test runs on the VM and on Chrome.
    - If the implementation does not reproduce these values, STOP and report to the user. Do not change the expected values.
    - Also test: `nextInt(1)` is always 0, `nextInt(65536)` stays in range, two instances with one seed give equal sequences, `nextInt(0)` fails the assert.
    - _Requirements: 5.3, 5.4, 4.5, 17.3_

  - [ ] 6.2 Write property test for the PRNG against an independent reference
    - Create `seeded_random_property_test.dart`. `numRuns: 300`.
    - **Property 17: The PRNG matches an independent reference.** For any seed in 0 to 4294967295 (edges plus `anyIntBetween(0, 4294967296)`), the first 20 values of `SeededRandom(seed).nextUint32()` equal a `BigInt` implementation of Mulberry32 written in the test file, and `nextInt(n)` for `1 <= n <= 65536` is always in `0 .. n - 1`.
    - **Validates: Requirements 5.4**

  - [ ] 6.3 Implement `CleanFacts`
    - Create `clean_facts.dart` (internal) with `CleanFacts.from(Map<String, Object?>)`. Count rule: a `num`, finite, from 0 to 1000000, equal to its own `truncateToDouble()`, then `toInt()`; everything else is missing (bool, String, null, list, fractional, non-finite, negative, above 1000000). Name rule: a `String` cleaned with `TextRules.cleanName`, missing when empty or when it contains a banned word. Read only the four `AiFactKeys` keys, ignore every other key.
    - Add `clean_facts_test.dart`: the counts in design.md's list (`0`, `-0.0`, `5.0`, `1000000`, `1000000.0`, `1000001`, `-1`, `0.5`, `NaN`, `Infinity`, `'5'`, `true`, `null`, `4294967295`) give the same results on the VM and on Chrome, `5.0` and `5` both give 5, names with emoji, accents, control characters and more than 24 units are cleaned, a name of `Murderous` and a blank name are missing, extra keys and an empty key are ignored, a wrong-type fact is missing.
    - _Requirements: 2.7, 5.5, 5.6, 6.3, 6.4, 6.5, 6.6, 6.7, 6.10, 15.2, 17.3_

  - [ ] 6.4 Implement `Template`
    - Create `template.dart` (internal) with the grammar of design.md: count slots `{key:singular/plural}` for `streakCount` and `daysSinceLastCommit`, name slots `{key|fallback}` for `ghostName` and `projectName`. The constructor parses once and throws `StateError` for an unknown key, a missing noun or fallback, a count slot with `|`, a name slot with `:` or a stray brace. Provide `isEligible`, `usedFacts`, `usesRealName` and `render(facts, {useNames = true})`. A count renders `<number> <noun>` (singular only for 1), with no separator and no locale.
    - Add `template_test.dart`: the plural rule for 0, 1, 2 and 1000000, a name slot with and without a name, `useNames: false` uses the fallback, eligibility and `usedFacts`, each parse error, a pattern with no slot.
    - _Requirements: 6.2, 6.3, 6.5, 6.7, 8.11, 17.3_

  - [ ] 6.5 Implement `TemplateSet` and the verbatim `TemplateCatalog`
    - Create `template_set.dart` and `template_catalog.dart` (internal). `TemplateSet(patterns, {required safeLine})`. `TemplateCatalog` has `ghostMoodLine`, `seanceVerdict` and `generic`, `forPurpose(AiPurpose)` (known id gives its set, else generic) and `static final standard`.
    - Use exactly the 24 template lines of design.md "Initial template copy", in that order and verbatim, including the fallback phrases inside the name slots and the ghost and pumpkin emoji. Ghost mood line G1 to G8: `Floating along.`, `Your ghost is getting hungry…`, `Mist, moonlight and good company.`, `{ghostName|Your ghost} drifts by to say boo. 👻`, `Streak: {streakCount:day/days}. The mist is on your side.`, `{ghostName|Your ghost} has counted {streakCount:day/days} and is still floating.`, `{streakCount:day/days} so far. {ghostName|Your ghost} is humming.`, `{ghostName|Your ghost} waits by the window, glowing softly.` Séance verdict V1 to V8: `The spirits are still listening.`, `Not gone, just napping.`, `Not quite gone.`, `{projectName|This project} has been dead for {daysSinceLastCommit:day/days}. Not forever, though.`, `Last commit: {daysSinceLastCommit:day/days} ago. The ghost remembers.`, `{projectName|This project} still glows faintly in the dark.`, `{daysSinceLastCommit:day/days} of silence, and {projectName|this project} is still worth a séance.`, `Every great haunting starts with one small commit.` Generic X1 to X8: `Boo. Hello from the mist.`, `Something spooky this way comes.`, `Quiet in here.`, `The pumpkins say hi. 🎃`, `{ghostName|A friendly ghost} says hello.`, `{projectName|This one} is waiting in the moonlight.`, `{streakCount:day/days} so far. The moon approves.`, `{daysSinceLastCommit:day/days} on the clock. The fog is patient.` Copy them from design.md, not from memory.
    - The three Safe_Lines, verbatim: ghost mood line `Boo. Still here.`, séance verdict `Rest, then rise.`, generic `Still here.`.
    - Add `template_set_test.dart` or cover it in `template_catalog_test.dart` (task 6.6): `forPurpose` for both known constants, for a custom purpose and for a custom purpose that reuses a known id.
    - _Requirements: 6.1, 6.2, 7.6, 8.1, 8.6, 8.7, 8.14, 2.14, 2.16, 2.17, 17.3_

  - [ ] 6.6 Write the template audit test
    - Create `template_catalog_test.dart`. It runs on the VM and on Chrome. Loop over every template of the three sets and fill it with: no facts (when eligible), count 0, 1, 2 and 1000000, a 2-unit name, a 24-unit name of `W`, a 24-unit name of emoji, a name with accents, and the no-name variant of each. The extreme fill uses count 1000000 and a 24-unit name; the no-facts fill uses no facts at all.
    - For every filled text assert: no banned word (test-declared list), no insult word (test-declared list of the 13 words), at most one emoji and only the ghost or pumpkin, non-blank, no lone surrogate, no edge whitespace.
    - Assert the length table of design.md exactly (UTF-16 code units; "No facts", "Small" with count 1 and a 2-unit name, "Extreme" with count 1000000 and a 24-unit name, "No-name at extreme"), for all 24 rows: G1 15/15/15/15, G2 29/29/29/29, G3 33/33/33/33, G4 35/27/49/35, G5 n/a/40/47/47, G6 n/a/43/72/58, G7 n/a/28/57/43, G8 47/39/61/47, V1 32/32/32/32, V2 23/23/23/23, V3 15/15/15/15, V4 n/a/48/77/65, V5 n/a/44/51/51, V6 45/35/57/45, V7 n/a/49/78/66, V8 50/50/50/50, X1 25/25/25/25, X2 32/32/32/32, X3 14/14/14/14, X4 23/23/23/23, X5 28/14/36/28, X6 37/31/53/37, X7 n/a/32/39/39, X8 n/a/39/46/46. A row cell `n/a` means the template needs a count and is not eligible without facts. The longest filled text is 78 units.
    - If any recorded length differs, STOP and report to the user. Do not change the expected numbers.
    - Also assert: at least 6 templates per set, at least 2 slot-free templates per set, at least one fact-free template of 16 units or fewer per set (G1, V3, X3), every pattern parses, the plural rule for 0, 1, 2 and 1000000, each Safe_Line is at most 16 units (16, 16 and 11 exactly) with no banned word and no insult word, and every word of the test-declared banned list is present in `TextRules.bannedWords` and every word of the test-declared insult list is in `TextRules.insultWords`, so weakening the exported lists fails a test.
    - _Requirements: 6.1, 6.2, 7.6, 8.2, 8.5, 8.7, 8.8, 8.9, 8.14, 15.13, 17.3_

  - [ ] 6.7 Implement `OfflineEngine`, `ComposedText` and `ComposePath`
    - Create `composed_text.dart`, `compose_path.dart` and `offline_engine.dart` (internal). `ComposePath` has `picked`, `truncated`, `noNameVariant`, `nextTemplate`, `safeLine`. `OfflineEngine(catalog)` has `static final standard` and `compose(AiRequest)` implementing steps 1 to 9 of design.md's "Offline selection algorithm" exactly: eligible templates, fitting templates, most used facts, seed pick with `SeededRandom(seed).nextInt`, truncation of the shortest, the banned check on the final text, Recovery (a) with fallback phrases, Recovery (b) in seed-rotated catalog order (a candidate that does not fit is skipped, never cut), Recovery (c) the Safe_Line. The purpose id is used only to choose the set and never reaches the seed or the text.
    - Add `offline_engine_test.dart` with examples on the standard catalog: a known purpose with its fact picks a template that uses it, a fact-free request picks a fact-free template, a custom purpose gets a generic template, `maxLength` 16 gives a fitting fact-free template with path `picked`, the same request gives the same result twice.
    - _Requirements: 4.5, 4.6, 4.8, 5.2, 6.8, 6.9, 7.1, 7.2, 7.3, 7.4, 7.5, 8.10, 8.11, 8.12, 8.13, 2.17, 2.18, 17.3_

  - [ ] 6.8 Write the Recovery and truncation tests
    - In `offline_engine_test.dart`, use `OfflineEngine` with injected `TemplateCatalog`s. Add no public test hook and no `@visibleForTesting` parameter.
    - Boundary case, step (a): an injected set with one template `Hush, a mur{ghostName|!}`, Safe_Line `Boo. Still here.`, facts `ghostName: 'der'`, `maxLength` 80, any seed. Assert the text equals `Hush, a mur!` exactly and the path is `noNameVariant`. With name `Bo` the same template gives `Hush, a murBo` with path `picked`.
    - Step (b): an injected set with `Hush, a mur{ghostName|der}` and `Calm night.`, name `der`. Assert text `Calm night.` and path `nextTemplate`.
    - All-banned catalog (step c): an injected set with two templates banned by their own text (`Gore galore` and `A bloody mess {ghostName|x}`) and name `Wisp`. Assert the reply text equals the Safe_Line `Boo. Still here.` and path `safeLine`. Also check through the public `OfflineCoffinAI` path that a reply from a catalog like this equals the Safe_Line when built through `OfflineEngine` in the same assertion style.
    - Truncation: an injected set with one 48-unit template (`This is a rather long template for a tiny limit.` or any 48-unit text that gives the design's result) and `maxLength` 16 gives `This is a rathe…`, 16 units, path `truncated`. An injected template with two ghost emoji at the cut gives `abcdefghijklmn…` (15 units) with no lone surrogate. If the design's quoted output cannot be reproduced with a text you choose, build the text so the design's quoted result appears, and STOP and report if the engine gives a different result for it.
    - A recovery candidate that does not fit is skipped, not cut. An empty eligible pool returns the Safe_Line with path `safeLine`.
    - _Requirements: 8.11, 8.12, 8.13, 8.15, 8.16, 7.4, 7.5, 15.13, 17.3_

  - [ ] 6.9 Write property test for Recovery
    - Create `offline_engine_property_test.dart`. `numRuns: 500`.
    - **Property 12: Recovery never returns a banned word or an overlong text.** For any injected catalog built from a pool of generated templates (some banned by their own text, some banned only through a name, some too long, some needing a count), any facts, any seed and any `maxLength >= 16`, `OfflineEngine.compose` returns text that has no banned word (test-declared list), has at most `maxLength` units and is non-empty. The same request gives the same text and path twice.
    - **Validates: Requirements 8.11, 8.12, 8.13**

- [ ] 7. Checkpoint - Pure layer verification
  - Run `dart format --set-exit-if-changed .`, `flutter analyze` and `flutter test` in `packages/coffin_core`. Fix anything that fails.
  - Confirm `git status --short` shows no pubspec change caused by this feature.
  - Ensure all tests pass, ask the user if questions arise.
  - _Requirements: 17.1, 17.2, 17.5, 16.9_

- [ ] 8. OfflineCoffinAI
  - [ ] 8.1 Implement `OfflineCoffinAI`
    - Create `offline_coffin_ai.dart`: `final class OfflineCoffinAI implements CoffinAI` with a `const` constructor and no field. `ask` calls `OfflineEngine.standard.compose(request)` and returns `Future<AiReply>.value(AiReply(text:, source: ReplySource.offline))`. No catch-all.
    - Add `offline_coffin_ai_test.dart` with example tests: one per known purpose and one for an app-defined purpose (the reply fits and has the source `offline`), a fact-using reply, missing facts, wrong-type facts, out-of-range counts, extra facts that never appear in the reply, string facts with emoji, accents, control characters and more than 24 units, `maxLength` 16 and 17, the reply completes in the next microtask (pump a fixed microtask loop, no real delay, no event-loop turn), a `const OfflineCoffinAI()` is usable, call order does not change a reply, an app purpose reusing `ghost_mood_line` gives the known-purpose reply, the purpose identifier never appears in the reply.
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.6, 4.7, 4.8, 2.3, 2.15, 2.17, 2.18, 5.6, 6.7, 6.10, 7.1, 7.2, 7.3, 15.1, 15.2, 15.3, 17.3_

  - [ ] 8.2 Write the golden table test
    - In `offline_coffin_ai_test.dart`, add a golden test with the 11 fixed requests of design.md's table. Requests: (1) ghost mood line, no facts, `maxLength` 80, seed 0; (2) ghost mood line, `streakCount: 3`, `ghostName: 'Boo'`, 80, seed 1; (3) ghost mood line, `streakCount: 1`, 40, seed 2; (4) ghost mood line, `streakCount: 5.0`, `ghostName: 'Wisp'`, 80, seed 4294967295; (5) séance verdict, `daysSinceLastCommit: 214`, `projectName: 'Todo Crypt'`, 120, seed 42; (6) séance verdict, `daysSinceLastCommit: 1`, 60, seed 7; (7) séance verdict, `projectName` of 14 ghost emoji (28 units), 100, seed 3; (8) custom `AiPurpose('my_app_hint')`, `streakCount: 2`, 60, seed 5; (9) ghost mood line, no facts, 16, seed 9; (10) ghost mood line, `streakCount: 0`, `ghostName: 'a\u0000  b\n'`, 80, seed 11; (11) ghost mood line, `streakCount: 4`, `ghostName: 'Murderous'`, 80, seed 6.
    - Produce the exact expected texts from the implementation in this task: run the 11 requests once, compare each text with the prototype column in design.md and note differences, then paste the actual texts as string literals into the test. Do not compute the expectations in the test.
    - Run the golden test on the VM AND on Chrome (`flutter test --platform chrome test/ai/offline_coffin_ai_test.dart`). Both must pass with the same literals.
    - Show the 11 golden texts to the user in the task report (as a table: request number, request summary, text, and whether it differs from the design prototype) so a human can review the tone. Say plainly that tone is subjective and that a catalog edit changes these texts.
    - _Requirements: 5.3, 5.7, 15.14, 17.6_

  - [ ] 8.3 Write property test for length and non-emptiness
    - Create `offline_coffin_ai_property_test.dart`. `numRuns: 500`. Requests come from `anyAiRequest` with `maxLength` from 16 up to 5000.
    - **Property 1: Offline reply is non-empty and fits the limit.** For any `AiRequest`, the `OfflineCoffinAI` reply text contains at least one non-whitespace character and has `length <= maxLength`.
    - **Validates: Requirements 2.4, 7.1, 7.2, 7.7, 13.2**

  - [ ] 8.4 Write property test for determinism
    - In `offline_coffin_ai_property_test.dart`. `numRuns: 500`.
    - **Property 2: Offline replies are deterministic and stateless.** For any request `r` and any other request `q`, `ask(r)` twice on one instance, `ask(r)` on a fresh instance, and `ask(r)` after `ask(q)` on the same instance all return equal replies.
    - **Validates: Requirements 4.6, 5.1, 5.2, 13.3**

  - [ ] 8.5 Write property test for always answering with the offline source
    - In `offline_coffin_ai_property_test.dart`. `numRuns: 500`.
    - **Property 3: Offline always answers, with the offline source.** For any request, `ask` returns a future without throwing synchronously, the future completes with a reply (not an error), and the source equals `ReplySource.offline`.
    - **Validates: Requirements 1.4, 4.3, 4.8, 13.6**

  - [ ] 8.6 Write property test for banned words
    - In `offline_coffin_ai_property_test.dart`. `numRuns: 500`.
    - **Property 4: No banned word in the reply.** For any request, the reply text folded with the test's ASCII-only fold contains none of the words of the banned list that the test file declares itself (`test_texts.dart`, not `TextRules.bannedWords`). Generators include facts that carry banned words, fragments of banned words and names such as `Murderous`.
    - **Validates: Requirements 8.3, 8.4, 8.10, 8.13, 13.4**

  - [ ] 8.7 Write property test for surrogates and edge whitespace
    - In `offline_coffin_ai_property_test.dart`. `numRuns: 500`.
    - **Property 5: No lone surrogate and no edge whitespace.** For any request whose facts may hold emoji, lone surrogates, control characters and long text, the reply text has no unpaired surrogate and its first and last code units are not whitespace (test-declared whitespace set).
    - **Validates: Requirements 6.10, 7.3, 7.5, 13.5**

  - [ ] 8.8 Write property test for the purpose identifier
    - In `offline_coffin_ai_property_test.dart`. `numRuns: 500`.
    - **Property 6: The purpose identifier never changes or appears in the reply.** For any request with a custom purpose whose identifier is not a known identifier and starts with the marker `zzmark_`, the reply does not contain the identifier (Req 13.13). For any two such custom purposes with otherwise equal requests, the replies are equal (Req 13.14, custom-purpose independence). For any request, replacing the purpose by `AiPurpose('ghost_mood_line')` or `AiPurpose('seance_verdict')` gives the same reply as the matching constant.
    - **Validates: Requirements 2.16, 2.17, 2.18, 13.13, 13.14**

  - [ ] 8.9 Write property test for whole doubles
    - In `offline_coffin_ai_property_test.dart`. `numRuns: 500`.
    - **Property 7: A whole double is the same fact as the int.** For any request, replacing each count fact that holds an `int` in 0 to 1000000 by the same number as a `double` gives an equal reply.
    - **Validates: Requirements 5.5**

  - [ ] 8.10 Write property test for unusable and extra facts
    - In `offline_coffin_ai_property_test.dart`. `numRuns: 500`.
    - **Property 8: Unusable and extra facts behave like absent facts.** For any request, removing every unknown key, every known-key entry with an unusable value (wrong type, fractional, non-finite, negative, above 1000000, a name that is blank after cleaning or has a banned word) and every entry with an empty key gives an equal reply to the original.
    - **Validates: Requirements 2.7, 5.6, 6.4, 6.6, 6.7**

  - [ ] 8.11 Write property test for fact usage
    - In `offline_coffin_ai_property_test.dart`. `numRuns: 500`.
    - **Property 9: Available facts are used when they fit.** For any request with `AiPurpose.ghostMoodLine` and a valid `streakCount`, or with `AiPurpose.seanceVerdict` and a valid `daysSinceLastCommit`, and any `maxLength >= 80`, the reply contains the count followed by `day` for 1 and `days` for any other number.
    - **Validates: Requirements 6.3, 6.8, 6.9**

- [ ] 9. FallbackCoffinAI
  - [ ] 9.1 Implement `FallbackCoffinAI`
    - Create `fallback_coffin_ai.dart` following design.md's skeleton and rules: the constructor throws `ArgumentError` when `timeout` is zero or negative and takes `primary`, `secondary`, `timeout`, an optional `AiIssueReporter` (default `discardAiIssues`) and an optional `AiTimerFactory` (default `Timer.new`). `ask` is `async`. A synchronous throw from `primary.ask` is caught and classified `threw` with no timer created. A `Completer` race: the timer callback settles `timedOut` synchronously, the primary result reaches `settle` only through `call.then(onValue, onError:)` attached at the start (so a late error is always handled), the first settle wins, so a completion at exactly the timeout counts as a timeout. The timer is cancelled with `whenComplete(timer.cancel)` on every outcome. Success returns the primary's reply object unchanged and reports nothing. Empty or whitespace-only text is `emptyReply` (wins over too long), text longer than `maxLength` is `invalidReply` and is never truncated. For every other outcome, report exactly one `AiIssue.forKind(kind)` through `reportAiIssueSafely` before the secondary is asked. A secondary that throws, or returns an empty or overlong reply, makes the future complete with `AiFallbackError` and reports no second issue. The class holds only `final` fields. The doc comment states the contract: a reply or an error, never a synchronous throw, no cancellation, the exact-timeout rule and that the secondary is not given a timeout.
    - Add no state, no retry, no built-in last-resort line.
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 9.9, 9.10, 9.11, 9.12, 9.13, 9.14, 9.15, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 10.9, 10.10, 1.4, 12.1, 16.1, 16.5_

  - [ ] 9.2 Write example tests for the wrapper
    - Create `fallback_coffin_ai_test.dart` using `FakeClock` from `test/ai/support/` and `ScriptedCoffinAI`. Pump microtasks with a fixed loop of `await Future<void>.value()`, never `Future.delayed(Duration.zero)`.
    - Each outcome through the wrapper with an `OfflineCoffinAI` secondary and a recording reporter: success (primary reply returned unchanged, same object, secondary not called, no issue), synchronous throw (`threw`), asynchronous error (`threw`), never-completing (`timedOut` after `advance(timeout)`), empty and whitespace-only reply (`emptyReply`), overlong reply (`invalidReply`, not truncated). Check the reporter output (kind and the fixed message) and that the issue is recorded before the returned future's completion handler runs.
    - Constructor: zero and negative timeout throw `ArgumentError`. The default reporter works with no reporter supplied.
    - The reporter throws: the secondary's reply is still returned.
    - Failing secondary (throws, empty, overlong): the future completes with `AiFallbackError` with the matching kinds, `toString` has no reply text and no fact value, and the reporter received exactly one issue.
    - Overlapping calls: two calls asked before either primary completes, completed in either order, each gets its own result and its own issue.
    - No pending timer: after success, after a failure and after a timeout, `FakeClock.pendingTimers` is 0.
    - A fake non-offline source passes through unchanged: a scripted primary that returns `AiReply(source: ReplySource('remote'))` is returned as the same reply (Req 12.2).
    - Composition: a `FallbackCoffinAI` used as the primary of another `FallbackCoffinAI`, and as the secondary of another, answer correctly for a failing and a working inner wrapper.
    - A wrapper keeps no state: a failed call does not change the next call.
    - _Requirements: 9.1, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 9.9, 9.10, 9.11, 9.12, 9.13, 9.14, 10.3, 10.4, 10.5, 10.6, 10.7, 10.9, 10.10, 12.2, 15.5, 15.6, 15.9, 15.10, 17.3_

  - [ ] 9.3 Write the timeout boundary and late-completion tests
    - In `fallback_coffin_ai_test.dart`, add the four-row boundary test of design.md with `FakeClock`: (1) the primary completes at timeout minus 1 ms and microtasks are pumped, then the clock reaches the timeout: success; (2) the clock reaches exactly the timeout, then the primary completes: `timedOut`; (3) the primary completes and in the same synchronous block the clock reaches the timeout with no pump between: `timedOut`; (4) the clock passes the timeout by 1 ms, then the primary completes: `timedOut`. Each row asserts the reply source and the reported kind and 0 pending timers. The test uses a 30 s timeout and finishes in milliseconds of real time.
    - Late completion: inside `runZonedGuarded`, a primary that completes with a value after the timeout, and a primary that completes with an error after the timeout, both ignored. Assert zero unhandled zone errors in both cases, and assert the first result of the call is the secondary's reply with exactly one `timedOut` issue.
    - _Requirements: 10.1, 10.2, 10.3, 10.10, 15.7, 15.8, 17.3_

  - [ ] 9.4 Write property test for answers and sources
    - Create `fallback_coffin_ai_property_test.dart`. `numRuns: 200`, sequences of 0 to 8 steps. Each step has a request (purposes include both known constants and custom purposes) and a scripted primary outcome from: usable reply with a generated source, synchronous throw, asynchronous error, never-completing, reply completing after the timeout, error completing after the timeout, empty or whitespace-only reply, overlong reply. Run every step through one `FallbackCoffinAI` with an `OfflineCoffinAI` secondary, a recording reporter and a per-run `FakeClock`, inside `runZonedGuarded`, with an async body.
    - **Property 18: A wrapper with an offline secondary always answers, from the right source.** Each step yields a usable, non-empty reply. For a usable primary reply the result is the primary's reply object unchanged, its source is the primary's source and the secondary was not called. For every other outcome the source is `ReplySource.offline`. The primary is called exactly once per step with the same request object.
    - Count runs and calls. Assert `runs > 0`, `runs == numRuns` and `calls > 0`.
    - **Validates: Requirements 9.4, 9.5, 9.12, 9.14, 10.8, 12.1, 12.2, 14.1, 14.2, 14.3**

  - [ ] 9.5 Write property test for the issues
    - In `fallback_coffin_ai_property_test.dart`. `numRuns: 200`.
    - **Property 19: Exactly one fixed issue per fallback.** For the same sequences, the reporter received no issue for a usable primary reply and exactly one issue for every other step. The kind is `threw` for synchronous and asynchronous errors, `timedOut` for a never-completing or late primary, `emptyReply` for an empty or whitespace-only reply and `invalidReply` for an overlong reply. The message equals the fixed message of that kind and contains neither the reply text nor any fact value from the request. The issue is already recorded when the completion handler of the returned future runs.
    - **Validates: Requirements 9.6, 9.7, 9.8, 9.9, 9.10, 9.11, 11.3, 14.4, 14.5**

  - [ ] 9.6 Write property test for timers and unhandled errors
    - In `fallback_coffin_ai_property_test.dart`. `numRuns: 200`.
    - **Property 20: No timer and no unhandled error is left behind.** For the same sequences, after each call has completed the fake clock has 0 pending timers, and after a late value or a late error from an abandoned primary has been delivered (completed after the pump), the zone that ran the sequence recorded 0 unhandled errors.
    - **Validates: Requirements 10.1, 10.10, 14.6**

  - [ ] 9.7 Write property test for a failing secondary
    - In `fallback_coffin_ai_property_test.dart`. `numRuns: 200`.
    - **Property 21: A failing secondary gives a typed error and still one issue.** For any request and any secondary that throws, returns an empty reply, or returns an overlong reply, combined with any failing primary outcome, the returned future completes with an `AiFallbackError` whose `primaryFailure` and `secondaryFailure` are the matching kinds, whose `toString` contains no reply text and no fact value, and the reporter received exactly one issue.
    - **Validates: Requirements 10.6, 10.7**

  - [ ] 9.8 Write property test for overlapping calls
    - In `fallback_coffin_ai_property_test.dart`. `numRuns: 200`.
    - **Property 22: Overlapping calls do not mix results.** For any two requests asked back to back before either primary completes, with the two primaries completed in either order, each call returns the result of its own primary (or its own fallback), and each issue and reply matches the call that produced it.
    - **Validates: Requirements 9.13, 10.9**

- [ ] 10. Checkpoint - Offline and fallback verification
  - Run `dart format --set-exit-if-changed .`, `flutter analyze` and `flutter test` in `packages/coffin_core`. Fix anything that fails.
  - Ensure all tests pass, ask the user if questions arise.
  - _Requirements: 17.1, 17.2, 17.4, 17.5_

- [ ] 11. Barrel
  - [ ] 11.1 Export the AI API from the barrel
    - Edit `packages/coffin_core/lib/coffin_core.dart`, keeping every existing export. Add `show` exports for exactly the 13 lines of design.md "Barrel exports", placed before the `src/router` lines: `AiFactKeys`, `AiFallbackError`, `AiIssue`, `AiIssueKind`, `AiIssueReporter` and `discardAiIssues`, `AiPurpose`, `AiReply`, `AiRequest`, `AiTimerFactory`, `CoffinAI`, `FallbackCoffinAI`, `OfflineCoffinAI`, `ReplySource`.
    - Do not export `reportAiIssueSafely`, `OfflineEngine`, `ComposedText`, `ComposePath`, `TemplateCatalog`, `TemplateSet`, `Template`, `CleanFacts`, `TextRules`, `SeededRandom` or `IdentifierRules`.
    - Run `flutter analyze` in the workspace and confirm no name clash in the barrel and no clash or ambiguity in `apps/hauntagotchi` or `apps/graveyard`. Fix the clash by reporting it to the user. Do not rename without asking.
    - _Requirements: 16.4, 16.7, 17.2_

  - [ ] 11.2 Write the barrel test
    - Create `ai_barrel_test.dart` (Chrome-safe, no `dart:io`). Importing only `package:coffin_core/coffin_core.dart`: every exported AI name is usable (construct a request, a reply, an issue, `OfflineCoffinAI`, `FallbackCoffinAI` with a fake clock, `AiFactKeys` keys, a `ReplySource`); a class defined in the test outside `coffin_core` implements `CoffinAI` using only the barrel and works as the primary of a `FallbackCoffinAI` (Req 1.6 and 12.1). The file imports no `src/` path.
    - The hidden names cannot be referenced through the barrel; the source scan (task 12.2) checks this on the barrel text, because a compile-time check cannot be a passing test.
    - _Requirements: 1.6, 12.1, 16.4, 17.3_

- [ ] 12. Source scan
  - [ ] 12.1 Write the scanner helpers
    - Create `test/ai/support/source_scanner.dart` (pure Dart, no `dart:io`, Chrome-safe): functions that take a file's text and return its violations for a rule list, a seedless-`Random` detector using the regular expression `(?<![A-Za-z0-9_$])Random\s*\(\s*\)` and `(?<![A-Za-z0-9_$])Random\.secure`, a `.hashCode` detector, a public-class counter that exempts typedef-only files, and a barrel-export parser.
    - Add `test/ai/support/source_scanner_test.dart` testing the scanner on sample strings: `final r = Random();` is flagged, `Random.secure()` is flagged, `SeededRandom(seed)` and `class SeededRandom {` are not flagged, each forbidden word is found case-insensitively, `.hashCode` is found, a typedef-only file counts as zero classes, two public classes count as two.
    - _Requirements: 12.4, 12.5, 5.4, 16.1_

  - [ ] 12.2 Write the source scan test
    - Create `ai_sources_test.dart` with `@TestOn('vm')`. Resolve repo paths relative to the test file location so it works from any working directory. Read every `.dart` file under `packages/coffin_core/lib/src/ai/`. Each scan asserts it found a nonzero number of files (and a nonzero number of lines scanned).
    - Fail when any file contains, case-insensitively: `http://`, `https://`, `api_key`, `apikey`, `authorization`, `bearer`, `package:http`, `dart:io`, `dart:html`, `HttpClient`, `package:flutter`, `DateTime.now`, `Stopwatch`, `src/storage`, `src/router`, `src/theme`, `src/widgets`, `package:go_router`, `package:hive`, `riverpod`, `dart:math`. Fail on a seedless `Random(` or `Random.secure` (no false positive on `SeededRandom(`). Fail on `.hashCode` member access in `offline_coffin_ai.dart`, `offline_engine.dart`, `template*.dart`, `clean_facts.dart`, `text_rules.dart` and `seeded_random.dart`.
    - Structure: each file declares at most one public class (typedef-only files exempt); no file under `lib/src/ai` imports `apps/`, `package:hauntagotchi` or `package:graveyard`; every file imports only `dart:core`, `dart:async` (in `fallback_coffin_ai.dart` and `ai_timer_factory.dart` only), `package:meta/meta.dart` and other files of `src/ai`.
    - Barrel: the barrel exports exactly the public AI names listed in task 11.1 using `show` clauses, exports nothing else from `src/ai/`, and keeps every other export. None of the internal names appear in an export.
    - Apps and pubspecs: no file under `apps/*/lib` or `apps/*/test` references the AI API names (`CoffinAI`, `OfflineCoffinAI`, `FallbackCoffinAI`, `AiRequest`, `AiReply`, `AiPurpose`, `ReplySource`, `AiFactKeys`, `AiTimerFactory`, `AiIssue`, `AiFallbackError`). Neither app pubspec mentions the AI layer. `coffin_core/pubspec.yaml` has no new dependency compared with the baseline recorded in task 1.1 (assert the dependency names present are the ones that were present at HEAD: read `git`-independent content, not a hash, so the test works without git).
    - Secrets: no file under `lib/src/ai` or `test/ai` contains a URL, `sk-`, `AKIA`, a long hex or base64 token, or a `.env` reference.
    - _Requirements: 4.2, 4.5, 5.4, 11.4, 12.3, 12.4, 12.5, 12.6, 12.7, 16.1, 16.3, 16.4, 16.6, 16.7, 16.8, 16.9, 17.7, 17.8_

- [ ] 13. Timing report
  - [ ] 13.1 Measure the AI test run time
    - In `packages/coffin_core`, run `flutter test test/ai` on the VM and measure wall-clock time (shell `time`, explicit timeout of 1800000 ms). Then measure the Chrome run separately, using the exact file list of task 14.1, with its own wall-clock time. Report both totals and the slowest files (time the heavy files separately: `offline_coffin_ai_property_test.dart`, `fallback_coffin_ai_property_test.dart`, `offline_engine_property_test.dart`, `template_catalog_test.dart`).
    - If either total exceeds about 60 seconds, STOP and tell the user the timings BEFORE lowering any run count or sequence length. Wait for their decision. Never lower counts silently. Note the first Chrome compile can take tens of seconds, and say how much of the total that was.
    - _Requirements: 13.10, 14.7, 17.5, 17.6_

- [ ] 14. Chrome run of the AI tests
  - [ ] 14.1 Run every AI test except the source scan on the web runner
    - First check that Chrome is available (`flutter devices` lists Chrome, or `flutter doctor`). If it is not, REPORT that the Chrome step could not run and why. Do not skip silently and do not mark the step as passed.
    - In `packages/coffin_core`, run `flutter test --platform chrome` with exactly this file list: `test/ai/coffin_ai_test.dart`, `test/ai/ai_purpose_test.dart`, `test/ai/ai_purpose_property_test.dart`, `test/ai/reply_source_test.dart`, `test/ai/ai_request_test.dart`, `test/ai/ai_request_property_test.dart`, `test/ai/ai_fact_keys_test.dart`, `test/ai/ai_reply_test.dart`, `test/ai/ai_reply_property_test.dart`, `test/ai/identifier_rules_test.dart`, `test/ai/text_rules_test.dart`, `test/ai/text_rules_property_test.dart`, `test/ai/seeded_random_test.dart`, `test/ai/seeded_random_property_test.dart`, `test/ai/clean_facts_test.dart`, `test/ai/template_test.dart`, `test/ai/template_catalog_test.dart`, `test/ai/offline_engine_test.dart`, `test/ai/offline_engine_property_test.dart`, `test/ai/offline_coffin_ai_test.dart`, `test/ai/offline_coffin_ai_property_test.dart`, `test/ai/fallback_coffin_ai_test.dart`, `test/ai/fallback_coffin_ai_property_test.dart`, `test/ai/ai_issue_test.dart`, `test/ai/ai_issue_reporter_test.dart`, `test/ai/ai_fallback_error_test.dart`, `test/ai/ai_barrel_test.dart`, `test/ai/support/ai_generators_test.dart`, `test/ai/support/fake_clock_test.dart`, `test/ai/support/scripted_ai_test.dart`, `test/ai/support/source_scanner_test.dart`. If any file was added or renamed during the work, update this list so it holds every file under `test/ai` except `ai_sources_test.dart`, and say so in the report.
    - The SeededRandom exact-value test (task 6.1), the template audit with its exact lengths (task 6.6) and the golden table (task 8.2) must all pass on Chrome.
    - If glados or any file fails to compile or run on the web runner, report the exact failure. If a glados generator breaks on web, fix the generator to be web-safe. Do not drop or skip the file, do not weaken assertions and do not lower run counts. If a recorded value differs on Chrome, STOP and report. If the run is slow, the timing rule of task 13 applies.
    - Report what the Chrome run does and does not cover: it checks the VM and web number and string differences (integral doubles, 32-bit arithmetic, code-unit lengths, microtask ordering) with the development compiler, but not dart2js release-mode output.
    - _Requirements: 5.3, 5.7, 7.7, 13.7, 13.8, 14.8, 14.10, 17.6_

- [ ] 15. Final verification
  - [ ] 15.1 Format, analyze and test everything
    - Run `dart format --set-exit-if-changed .` at the workspace root, `flutter analyze` (zero issues) and `flutter test` in `packages/coffin_core`, `apps/hauntagotchi` and `apps/graveyard`. All must be clean and passing. Fix failures in files this feature created only; report anything else.
    - _Requirements: 17.1, 17.2, 17.3, 17.4, 17.5_

  - [ ] 15.2 Build both apps for the web
    - Run `flutter build web` in `apps/hauntagotchi` and in `apps/graveyard`. Report success or the exact failure. Do not edit the design to work around a failure. Neither app imports the AI API, but the barrel now brings it into the compile graph.
    - _Requirements: 17.9, 16.7_

  - [ ] 15.3 Confirm the pubspecs and lockfile are unchanged
    - Run `git diff --stat HEAD -- packages/coffin_core/pubspec.yaml apps/hauntagotchi/pubspec.yaml apps/graveyard/pubspec.yaml pubspec.lock` and compare `git hash-object` of each of the four files with the baseline recorded in task 1.1. Report any difference. A difference from HEAD that was already in the baseline is not caused by this feature, and must be stated as such. A difference from the baseline is a failure: STOP and report.
    - Confirm no new `dependencies:` or `dev_dependencies:` entry and no new `workspace:` entry appeared.
    - _Requirements: 16.9, 17.7, 12.7_

  - [ ] 15.4 Confirm scope, secrets and report what was not verified
    - Run `git status --short` and confirm only these paths changed because of this feature: `.kiro/specs/coffin-ai/`, `packages/coffin_core/lib/coffin_core.dart`, `packages/coffin_core/lib/src/ai/` and `packages/coffin_core/test/ai/`. Confirm no app file, `DIARY.md`, crypt-storage file, `pubspec.yaml`, `pubspec.lock`, `CREDITS.md` or generated `*.g.dart` file was changed or added by this feature, and that nothing was created or edited outside the repository. Other changes already present from crypt-storage work are reported and left alone.
    - Run a secrets grep over the files this feature added or changed (`lib/src/ai`, `test/ai`, the barrel line additions, `.kiro/specs/coffin-ai/`): `http://`, `https://`, `api_key`, `apikey`, `authorization`, `bearer`, `sk-`, `AKIA`, `token`, `secret`. Report every hit and explain each (for example the scan test's own forbidden-word list), and confirm no real secret or URL.
    - In the final message, state plainly what was not verified: tone is subjective (the golden texts and the 24 lines need a human read), there is no real remote provider and no network call, and there is no dart2js release-mode determinism check beyond the development compiler used by `flutter test --platform chrome`. Also state that Recovery and truncation are proven only through injected catalogs, and that real-clock ordering at the exact timeout is not testable.
    - _Requirements: 12.7, 16.6, 16.7, 16.10, 17.8_

- [ ] 16. Final checkpoint - Full workspace verification
  - Confirm no package was added: `glados`, `flutter_test` and `meta` remain the only test and annotation dependencies used, and the four files from task 15.3 match the baseline.
  - Ensure all tests pass, ask the user if questions arise.
  - _Requirements: 16.9, 17.2, 17.5, 17.7_

## Notes

- All tasks are required. Nothing is optional. Unit tests and property tests are required because the tech steering says pure logic and numeric invariants must be tested.
- Property tests use glados 1.1.7 (already a dev dependency of `coffin_core`). Properties 1 to 9 and 12 run 500 times; Properties 10, 11 and 13 to 17 run 300 times; Properties 18 to 22 run 200 times with at most 8 steps.
- Property mapping: 1 in task 8.3, 2 in 8.4, 3 in 8.5, 4 in 8.6, 5 in 8.7, 6 in 8.8, 7 in 8.9, 8 in 8.10, 9 in 8.11, 10 in 5.5, 11 in 5.6, 12 in 6.9, 13 in 5.2, 14 in 5.3, 15 in 5.1, 16 in 5.4, 17 in 6.2, 18 in 9.4, 19 in 9.5, 20 in 9.6, 21 in 9.7, 22 in 9.8.
- Requirement coverage: 1 (3.1, 9.1, 11.2), 2 (2.1, 2.3, 8.1), 3 (2.1, 2.4, 5.4), 4 (6.7, 8.1, 12.2), 5 (6.1, 6.3, 8.2, 8.9), 6 (6.3 to 6.6, 8.11), 7 (2.2, 6.7, 8.3), 8 (2.2, 6.6, 6.8, 6.9, 8.6), 9 (9.1 to 9.5, 9.8), 10 (9.1, 9.3, 9.6, 9.7), 11 (2.5, 9.5), 12 (9.2, 11.2, 12.2, 15.4), 13 (4.1, 8.3 to 8.11), 14 (4.2, 9.4 to 9.8), 15 (2.1 to 2.5, 6.6, 8.1, 8.2, 9.2, 9.3), 16 (1.1, 11.1, 12.2, 15.3, 15.4), 17 (7, 10, 12.2, 14.1, 15.1 to 15.4).
- The pure layer (tasks 2 to 6) must stay free of Flutter imports. Task 12.2 enforces that with a source scan.
- Tasks 6.1, 6.6 and 14.1 are hard stops: if the PRNG reference values or the recorded template lengths are not reproduced, work stops and the user decides. Tasks 13.1 and 14.1 report and stop rather than lower counts or weaken tests.
- Task 8.2 shows the golden texts to the user for a tone review.
- The workflow ends once these tasks exist. Open `tasks.md` and start tasks from there. No implementation has been started.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["2.1"] },
    { "id": 2, "tasks": ["2.2", "2.3", "2.5"] },
    { "id": 3, "tasks": ["2.4"] },
    { "id": 4, "tasks": ["3.1", "4.1"] },
    { "id": 5, "tasks": ["4.2", "5.1", "5.2", "5.4", "5.5", "6.1", "6.3"] },
    { "id": 6, "tasks": ["5.3", "5.6", "6.2", "6.4"] },
    { "id": 7, "tasks": ["6.5"] },
    { "id": 8, "tasks": ["6.6", "6.7"] },
    { "id": 9, "tasks": ["6.8", "6.9"] },
    { "id": 10, "tasks": ["8.1", "9.1"] },
    { "id": 11, "tasks": ["8.2", "8.3", "9.2", "9.4"] },
    { "id": 12, "tasks": ["8.4", "9.3", "9.5"] },
    { "id": 13, "tasks": ["8.5", "9.6"] },
    { "id": 14, "tasks": ["8.6", "9.7"] },
    { "id": 15, "tasks": ["8.7", "9.8"] },
    { "id": 16, "tasks": ["8.8"] },
    { "id": 17, "tasks": ["8.9"] },
    { "id": 18, "tasks": ["8.10"] },
    { "id": 19, "tasks": ["8.11"] },
    { "id": 20, "tasks": ["11.1", "12.1"] },
    { "id": 21, "tasks": ["11.2", "12.2"] },
    { "id": 22, "tasks": ["13.1"] },
    { "id": 23, "tasks": ["14.1"] },
    { "id": 24, "tasks": ["15.1"] },
    { "id": 25, "tasks": ["15.2", "15.3", "15.4"] }
  ]
}
```
