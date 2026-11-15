# Requirements Document

## Introduction

The coffin-ai feature is step 1 of the AI layer of `coffin_core`. It adds a provider-agnostic `CoffinAI` interface with one async method, `ask`, that takes a small Request (a purpose, a map of facts and a maximum reply length) and returns a Reply (text plus the source that produced it). It adds an `OfflineCoffinAI` implementation, which is a deterministic, template-based spooky text generator in plain Dart, and a `FallbackCoffinAI` wrapper that tries a primary `CoffinAI` with a timeout and falls back to a secondary one (normally the offline one) when the primary throws, times out or returns an unusable reply. The wrapper reports why it fell back through an injectable reporter, analogous to the storage layer's `IssueReporter`.

This step makes no network calls and holds no API keys, URLs or secrets. Step 2 will add a remote implementation that calls a proxy server. The interface, the Request, the Reply and the wrapper are designed so that this remote implementation drops in as one more `CoffinAI`, with no change to those four types. Apps are NOT wired to the AI layer in this feature; each app adopts it in its own spec.

The pure logic (Request, Reply, interface, offline generator, wrapper, issue type) is plain Dart with no Flutter imports. The offline generator and the wrapper are verified with glados property tests that are safe to run on the Dart VM and on Flutter Web (Chrome). The copy follows the design steering document: short, witty, slightly spooky, never mean to the user, never gory ("Haunted, not horror"). The feature has no UI.

## Non-Goals

- No network calls, no remote provider, no proxy server and no HTTP code.
- No API keys, tokens, URLs or endpoints anywhere in the repository.
- No streaming replies.
- No cancellation of an in-flight `ask`.
- No localization: all copy is English.
- No wiring into Hauntagotchi or Graveyard.
- No persistence or caching of replies.
- No real LLM and no prompt engineering.

## Dependency Notice

This feature requires NO new package. `glados` and `flutter_test` are already dev dependencies of `coffin_core` and are reused. The `characters` package is NOT added, so lengths are measured in UTF-16 code units (see Requirement 2). A fake clock for timeout tests comes from `flutter_test` (which re-exports or depends on `fake_async`) or from an injectable timeout function; the design phase verifies which of the two is available without adding or declaring a new dependency. No app `pubspec.yaml` changes.

## Glossary

- **Coffin_AI**: The abstract interface `CoffinAI` in `coffin_core` with one method, `Future<Reply> ask(Request request)`.
- **Request**: The immutable value that describes one question to a Coffin_AI: a Purpose, Facts, a Max_Length and a Seed.
- **Purpose**: The part of a Request that says what kind of text is wanted. A Purpose is an open, immutable value type with value equality on a non-empty identifier String, not an enum, so that apps can define their own Purposes without changing `coffin_core`. `coffin_core` provides constants for the two Known_Purposes "ghost mood line" and "séance verdict" (see Requirement 2).
- **Known_Purpose**: A Purpose, equal to one of the two `coffin_core` Purpose constants, that the Offline_AI has dedicated templates for.
- **Unknown_Purpose**: A Purpose that is not a Known_Purpose, which the Offline_AI answers with generic templates.
- **Facts**: An unmodifiable `Map<String, Object?>` carried by a Request, whose values are Fact_Scalars.
- **Fact_Scalar**: A value that is `null`, `bool`, `int`, a finite `double` or a `String`.
- **Known_Fact**: A fact key that the Offline_AI templates read. The initial Known_Facts are `streakCount`, `daysSinceLastCommit`, `ghostName` and `projectName`. The design phase may add keys but SHALL list them.
- **Max_Length**: The maximum length of a Reply text, measured in UTF-16 code units (`String.length`).
- **Minimum_Max_Length**: The smallest Max_Length that a Request accepts. The design phase chooses a value of at most 16 and records it.
- **Seed**: A non-negative integer in the range 0 to 4294967295 carried by a Request that selects among templates. The default is 0.
- **Reply**: The immutable value returned by `ask`: a text and a Source.
- **Source**: The value on a Reply that identifies which implementation produced it. Initially it has the value `offline`. The design phase confirms whether it is an open value type or an enum (see Requirement 3).
- **Usable_Reply**: A Reply whose text is non-empty after trimming whitespace and whose text length is at most the Max_Length of the Request it answers.
- **Offline_AI**: The class `OfflineCoffinAI`, the deterministic, template-based Coffin_AI.
- **Template**: A fixed English text pattern with named slots that the Offline_AI fills from Facts.
- **Banned_Words**: A small explicit list of gory words, defined in code, that the Offline_AI output must never contain.
- **Insult_Words**: A small explicit list of mean or insulting words that no Template may contain.
- **Safe_Line**: A fixed, built-in Offline_AI reply text that a test verifies to contain no Banned_Word and no Insult_Word, and whose length is at most the Minimum_Max_Length, so that it fits every accepted Max_Length without truncation. The design phase MAY define one Safe_Line per Purpose or a single Safe_Line.
- **Recovery**: The deterministic sequence of steps (a), (b) and (c) of Requirement 8.11 that the Offline_AI applies when a filled Template yields final text that contains a Banned_Word.
- **Fallback_AI**: The class `FallbackCoffinAI`, which wraps a primary and a secondary Coffin_AI.
- **Primary**: The Coffin_AI that the Fallback_AI tries first.
- **Secondary**: The Coffin_AI that the Fallback_AI uses when the Primary fails.
- **Primary_Outcome**: One of: success (a Usable_Reply in time), throw (an error, synchronous or asynchronous), timeout (no result within the Fallback_Timeout), empty (a Reply whose text is empty or whitespace only) and invalid (a Reply whose text is longer than the Max_Length).
- **Fallback_Timeout**: The positive `Duration` that the Fallback_AI waits for the Primary.
- **AI_Issue**: The immutable value that describes one fallback: a kind and a fixed message.
- **AI_Issue_Kind**: The enum with the values `threw`, `timedOut`, `emptyReply` and `invalidReply`.
- **AI_Issue_Reporter**: The injectable callback `void Function(AI_Issue)` that receives every AI_Issue.
- **Fake_Time**: A test mechanism (fake async zone or injected timeout function) that advances time without real waiting.
- **Barrel**: The file `packages/coffin_core/lib/coffin_core.dart`, the only public import for apps.
- **AI_Property_Tests**: The glados property-based tests defined in Requirements 13 and 14.
- **Source_Scan_Test**: The test defined in Requirement 12 that scans the files under `packages/coffin_core/lib/src/ai/` for forbidden content.

## Requirements

### Requirement 1: Provider-agnostic interface

**User Story:** As a Flutter developer using Coffin, I want one small AI interface, so that my app code never depends on a specific provider.

#### Acceptance Criteria

1. THE Coffin_AI SHALL be an abstract interface that declares exactly one member: `Future<Reply> ask(Request request)`.
2. THE Coffin_AI SHALL expose no Flutter type, no HTTP type and no provider-specific type in any signature.
3. THE Coffin_AI SHALL carry a doc comment that states the contract of `ask`: the returned future completes with a Reply, or completes with an error when the implementation cannot answer.
4. WHEN `ask` is called with a constructed Request, THE Coffin_AI implementations in this feature SHALL NOT throw synchronously, and SHALL report every failure through the returned future.
5. THE Coffin_AI SHALL define no cancellation member, so that cancellation stays out of scope.
6. THE Coffin_AI SHALL be implementable by a class outside `coffin_core` without importing any file under `src/`.

### Requirement 2: Request value type

**User Story:** As a developer, I want a small, validated request, so that every implementation receives the same well-formed input.

#### Acceptance Criteria

1. THE Request SHALL be an immutable value type with a `const`-friendly or `final`-field design and with value equality and a matching hash code over the Purpose, the Facts, the Max_Length and the Seed.
2. THE Request SHALL carry a Purpose, Facts, a Max_Length and a Seed, where the Facts default to empty and the Seed defaults to 0.
3. THE Purpose SHALL support the two Known_Purposes "ghost mood line" and "séance verdict", and SHALL support any other valid Purpose (an Unknown_Purpose) without throwing.
4. THE Request SHALL measure the Max_Length in UTF-16 code units, so that the limit has the same meaning on the Dart VM and on Flutter Web.
5. IF the Max_Length is below the Minimum_Max_Length, THEN THE Request constructor SHALL throw an `ArgumentError` that names the minimum.
6. IF the Seed is negative or greater than 4294967295, THEN THE Request constructor SHALL throw an `ArgumentError`.
7. IF a Facts key is an empty String, or a Facts value is not a Fact_Scalar (for example a `List`, a `Map`, a non-finite `double` or an arbitrary object), THEN THE Request constructor SHALL accept the Request and THE Offline_AI SHALL treat that entry as absent (see Requirement 5.6), so that unexpected facts never crash a caller.
8. THE Request SHALL keep an unmodifiable copy of the Facts, so that mutating the caller's map after construction cannot change the Request.
9. THE Request SHALL use value equality on the Facts content, regardless of map insertion order.
10. THE design phase SHALL choose the Minimum_Max_Length (at most 16), and SHALL record it in `design.md`.
11. THE Request SHALL be a plain Dart class with no Flutter imports.
12. THE Purpose SHALL be an immutable value type, not an enum, with value equality and a matching hash code on a non-empty identifier String. THE design phase SHALL decide the exact identifier rules (for example trimmed, non-empty, a length cap) and SHALL record them in `design.md`.
13. IF a Purpose identifier is invalid under the identifier rules of the design, THEN THE Purpose constructor SHALL reject it at construction with an `ArgumentError`, consistent with the Max_Length and Seed rules. THE design phase SHALL record the constructor shape.
14. THE coffin_core package SHALL provide a public constant for each of the two Known_Purposes "ghost mood line" and "séance verdict". THE design phase SHALL decide the identifier strings (for example `ghost_mood_line` and `seance_verdict`), and the display text SHALL NOT be used as the identifier.
15. WHEN an app creates a Purpose with its own identifier, THE Purpose SHALL be usable in a Request with no change to coffin_core.
16. WHEN two Purposes have the same identifier, THE Purpose equality SHALL treat them as equal, so that an app-defined Purpose that reuses a Known_Purpose identifier is treated as that Known_Purpose.
17. WHEN the Offline_AI receives a Purpose that is not a Known_Purpose, THE Offline_AI SHALL answer with the generic Templates of Requirement 6.1 and 6.2, and those generic Templates SHALL follow the same length, tone, banned-word, insult-word and recovery rules as the purpose-specific Templates (Requirements 7 and 8).
18. THE Offline_AI SHALL NOT echo the Purpose identifier into the reply text, so that app-defined identifiers never appear in the copy.

### Requirement 3: Reply value type

**User Story:** As a developer, I want a reply that says where its text came from, so that an app can tell offline text from remote text.

#### Acceptance Criteria

1. THE Reply SHALL be an immutable value type with a text and a Source, with value equality and a matching hash code.
2. THE Reply SHALL accept any String as text without throwing, so that the Fallback_AI can detect and classify unusable text from a misbehaving implementation instead of failing at construction.
3. THE Reply SHALL expose a check that reports whether it is a Usable_Reply for a given Request.
4. THE Source SHALL be designed so that adding a new Source in step 2 (for example `remote`) requires no change to the Coffin_AI, the Request, the Reply field types or the Fallback_AI. The design phase SHALL choose between an open value type and an enum, SHALL justify the choice, and SHALL record it in `design.md`.
5. THE Source SHALL have a stable, human-readable name that tests and logs can compare.
6. THE Reply SHALL carry no other field unless the design phase justifies it in `design.md`.
7. THE Reply SHALL be a plain Dart class with no Flutter imports.

### Requirement 4: Offline generator contract

**User Story:** As an app developer, I want a spooky text generator that works with no network and no key, so that my app always has something to say.

#### Acceptance Criteria

1. THE Offline_AI SHALL implement Coffin_AI.
2. THE Offline_AI SHALL be plain Dart with no Flutter import, no `dart:io` import, no `dart:html` import and no network code.
3. THE Offline_AI SHALL return a Reply with the Source `offline`.
4. THE Offline_AI SHALL complete `ask` without any real waiting, so that tests and apps get the reply in the same event-loop turn or the next microtask.
5. THE Offline_AI SHALL read no clock (no `DateTime.now`, no `Stopwatch`), no unseeded `Random`, no environment value, no locale and no other hidden global state.
6. THE Offline_AI SHALL keep no state between calls, so that call order does not change any reply.
7. THE Offline_AI SHALL have a `const`-friendly or argument-free constructor, so that apps and tests can create one cheaply.
8. THE Offline_AI SHALL never throw for a constructed Request.

### Requirement 5: Offline determinism

**User Story:** As a tester, I want the same request and seed to always give the same reply, so that behavior is reproducible on every platform.

#### Acceptance Criteria

1. FOR ALL Requests, THE Offline_AI SHALL return equal Replies when called twice with equal Requests, on the same instance and on fresh instances.
2. THE Offline_AI SHALL use the Seed, the Purpose and the Facts as its only inputs.
3. THE Offline_AI SHALL produce identical text for equal Requests on the Dart VM and on Flutter Web.
4. THE Offline_AI SHALL NOT use `String.hashCode`, `Object.hashCode` or `Random` without a verified cross-platform sequence. THE design phase SHALL either verify that `dart:math` `Random(seed)` yields identical sequences on the Dart VM and on Chrome, or SHALL define a small internal pseudo-random generator that uses only 32-bit-safe integer arithmetic, and SHALL record the choice and the evidence in `design.md`.
5. THE Offline_AI SHALL format integer Facts in a platform-independent way, so that a whole-valued `double` such as `5.0` and the `int` `5` produce the same text, because Flutter Web does not distinguish them.
6. WHEN a Fact is absent, or has a type that the Template slot does not accept, or is out of the accepted range, THE Offline_AI SHALL treat the Fact as missing and SHALL choose from the Templates that need no such Fact.
7. THE test suite SHALL include a golden test with a fixed table of Requests and their exact expected reply texts, and the same table SHALL pass on the Dart VM and on Chrome.

### Requirement 6: Offline templates and fact usage

**User Story:** As a user, I want short, witty, slightly spooky lines that mention my real numbers, so that the text feels about me and my ghosts.

#### Acceptance Criteria

1. THE Offline_AI SHALL hold at least 6 Templates for the Known_Purpose "ghost mood line", at least 6 for "séance verdict", and at least 6 generic Templates for Unknown_Purposes, including app-defined Purposes.
2. THE Offline_AI SHALL hold at least 2 Templates per Known_Purpose, and at least 2 generic Templates, that need no Fact, so that every Request has a Template whatever the Facts.
3. WHERE a Template has a slot for `streakCount` or `daysSinceLastCommit`, THE Offline_AI SHALL fill the slot with a decimal integer and SHALL use the singular or plural noun that matches the number (for example "1 day" and "2 days").
4. THE Offline_AI SHALL accept a numeric Fact for a count slot only when it is an `int` or a whole-valued finite `double` in the range 0 to 1000000, and SHALL treat any other value as missing.
5. WHERE a Template has a slot for `ghostName` or `projectName`, THE Offline_AI SHALL fill it from a String Fact after trimming it, collapsing runs of whitespace to one space and removing control characters, and SHALL include at most the first 24 UTF-16 code units, without splitting a surrogate pair.
6. IF a String Fact is empty after cleaning, or its cleaned text contains a Banned_Word, THEN THE Offline_AI SHALL treat that Fact as missing. This check is an early filter only; the final-text check and Recovery of Requirement 8.10 and 8.11 are the guarantee, because a Banned_Word can form across a Template and slot boundary.
7. THE Offline_AI SHALL echo a String Fact only inside the slot of a Template, and SHALL NOT echo any other Fact key or value, so that unexpected data never leaks into the reply.
8. WHEN several Templates fit the Max_Length, THE Offline_AI SHALL pick one of them using the Seed.
9. THE Offline_AI SHALL prefer Templates that use the available Facts over Templates that use none, so that a Request with a `streakCount` Fact mentions the streak when a matching Template fits.
10. THE Offline_AI SHALL handle a String Fact that contains emoji, accented letters or other non-ASCII text without throwing and without producing a lone surrogate in the reply.

### Requirement 7: Offline length rules

**User Story:** As a UI developer, I want a hard length limit, so that text always fits the space I have.

#### Acceptance Criteria

1. FOR ALL Requests, THE Offline_AI SHALL return a Reply whose text length is at most the Max_Length of the Request.
2. FOR ALL Requests, THE Offline_AI SHALL return a Reply whose text is non-empty and contains at least one character that is not whitespace.
3. THE Offline_AI SHALL return a Reply whose text has no leading or trailing whitespace.
4. WHEN no filled Template fits the Max_Length, THE Offline_AI SHALL choose among the shortest available Templates, and SHALL shorten the chosen text by cutting it at the Max_Length, removing trailing whitespace and then ending it with an ellipsis "…" within the limit.
5. WHEN the Offline_AI cuts text, THE Offline_AI SHALL NOT split a surrogate pair, and SHALL NOT leave a lone surrogate at the end.
6. THE Offline_AI SHALL hold at least one built-in Template whose filled length is at most the Minimum_Max_Length, so that the smallest accepted Max_Length still yields a non-empty reply.
7. THE Offline_AI SHALL produce a reply of length equal to or below the Max_Length on the Dart VM and on Flutter Web, because both measure `String.length` in UTF-16 code units.

### Requirement 8: Offline tone and banned words

**User Story:** As a user, I want text that is spooky and kind, never gory or mean, so that the app stays "haunted, not horror".

#### Acceptance Criteria

1. THE Offline_AI Templates SHALL follow the design steering tone: short, witty, slightly spooky, never mean to the user and never gory.
2. THE Offline_AI SHALL define the Banned_Words as an explicit list in code with at least 8 entries covering gore and graphic violence, and the list SHALL be exposed to tests.
3. FOR ALL Requests, THE Offline_AI SHALL return a Reply whose text contains no Banned_Word, compared case-insensitively. The design phase SHALL choose between whole-word and substring matching and SHALL record it, with a preference for substring matching on the lowercased final text.
4. THE banned-word check SHALL apply to the final output text, including filled slots and any ellipsis, and not only to the Template sources.
5. THE Offline_AI SHALL define the Insult_Words as an explicit list in code with at least 8 entries, and a test SHALL assert that no Template contains an Insult_Word, case-insensitively.
6. THE Offline_AI Templates SHALL address a missed habit, a stale project or a low score without blame, using playful phrasing such as "Your ghost is getting hungry…" in place of criticism.
7. THE Offline_AI Templates SHALL use no more than one emoji, and only the ghost or pumpkin emoji.
8. THE test suite SHALL check every Template, after filling it with a set of extreme Fact values, against the Banned_Words list and the Max_Length rules, so that a bad Template fails a test even when the generated inputs never pick it.
9. THE property tests SHALL check the banned words against a list that the test file declares itself, and not only against the list exported by the Offline_AI, so that weakening the exported list cannot weaken the test.
10. AFTER filling a Template, THE Offline_AI SHALL check the final text, including any ellipsis, for Banned_Words using the case-insensitive matching rule chosen in design (Requirement 8.3). This final-text check is the guarantee of Requirement 8.3, and the String Fact filter of Requirement 6.6 is only an early filter.
11. IF the final text contains a Banned_Word, THEN THE Offline_AI SHALL apply this Recovery in this order: (a) retry the same Template with the name slots (`ghostName`, `projectName`) treated as missing, which means picking that Template's no-name variant or the Template set without name slots, as the design defines; (b) if the text is still banned, or no such variant exists, try the next Template for that Purpose in a fixed, seed-determined order; (c) as a last resort, return the Safe_Line. Each step SHALL respect the Max_Length rules of Requirement 7.
12. THE Recovery SHALL be deterministic, so that the same Request and Seed always take the same Recovery path.
13. THE Offline_AI SHALL never throw and never return a Banned_Word after Recovery, and the length rules of Requirement 7 SHALL still hold after Recovery.
14. THE Safe_Line SHALL contain no Banned_Word and no Insult_Word, and SHALL have a length of at most the Minimum_Max_Length, and a test SHALL verify these three properties for every Safe_Line.
15. THE test suite SHALL include a test that builds a boundary case in which a Template's text ends with a fragment and a name Fact begins with the rest of a Banned_Word, so that only the combined text is banned. The test SHALL assert that the reply contains no Banned_Word and that Recovery step (a) was taken, either through a test-only hook that is internal and not part of the public API, or by asserting that the reply equals the expected no-name text.
16. THE test suite SHALL include a test in which Recovery steps (a) and (b) cannot help, for example a template set in which every candidate is made banned, and the reply SHALL equal the Safe_Line. THE design phase SHALL provide a non-public way to inject templates for this test, or SHALL prove the step through another deterministic construction, without making Templates part of the public API.

### Requirement 9: Fallback wrapper behavior

**User Story:** As an app developer, I want a wrapper that tries the smart provider and quietly falls back to the offline one, so that my app never goes silent.

#### Acceptance Criteria

1. THE Fallback_AI SHALL implement Coffin_AI, so that wrappers compose and a Fallback_AI can serve as the Primary or the Secondary of another Fallback_AI.
2. THE Fallback_AI SHALL accept a Primary, a Secondary, a Fallback_Timeout and an optional AI_Issue_Reporter through its constructor.
3. IF the Fallback_Timeout is zero or negative, THEN THE Fallback_AI constructor SHALL throw an `ArgumentError`.
4. WHEN `ask` is called, THE Fallback_AI SHALL call `ask` on the Primary with the same Request.
5. WHEN the Primary returns a Usable_Reply before the Fallback_Timeout elapses, THE Fallback_AI SHALL return that Reply unchanged, with the Source set by the Primary, and SHALL NOT call the Secondary and SHALL NOT report an AI_Issue.
6. IF the Primary throws, whether synchronously from `ask` or through the returned future, THEN THE Fallback_AI SHALL call the Secondary, SHALL report one AI_Issue of kind `threw`, and SHALL return the Secondary's Reply.
7. IF the Primary does not complete within the Fallback_Timeout, THEN THE Fallback_AI SHALL call the Secondary, SHALL report one AI_Issue of kind `timedOut`, and SHALL return the Secondary's Reply.
8. IF the Primary returns a Reply whose text is empty or whitespace only, THEN THE Fallback_AI SHALL call the Secondary, SHALL report one AI_Issue of kind `emptyReply`, and SHALL return the Secondary's Reply.
9. IF the Primary returns a Reply whose text is longer than the Max_Length, THEN THE Fallback_AI SHALL treat it as a failure (and SHALL NOT truncate it), SHALL call the Secondary, SHALL report one AI_Issue of kind `invalidReply`, and SHALL return the Secondary's Reply.
10. THE Fallback_AI SHALL report exactly one AI_Issue for each fallback, and none for a call where the Primary succeeds.
11. THE Fallback_AI SHALL report the AI_Issue before the returned future completes.
12. THE Fallback_AI SHALL NOT retry the Primary within one `ask` call.
13. THE Fallback_AI SHALL keep no state between calls, so that a failed call does not change the next call.
14. WHEN the Fallback_AI falls back to an Offline_AI Secondary, THE Fallback_AI SHALL return a non-empty Usable_Reply whose Source is `offline`, for every Request and every Primary_Outcome.
15. THE Fallback_AI SHALL be a plain Dart class with no Flutter imports.

### Requirement 10: Fallback edge cases and secondary failure

**User Story:** As a developer, I want the wrapper to stay calm under odd conditions, so that a slow or broken provider never crashes the app.

#### Acceptance Criteria

1. IF the Primary completes after the Fallback_Timeout has already elapsed, THEN THE Fallback_AI SHALL ignore the late result, and SHALL cause no unhandled asynchronous error, including when the late completion is an error.
2. IF the Primary completes at exactly the Fallback_Timeout, THEN THE Fallback_AI SHALL behave deterministically. THE design phase SHALL define whether this counts as success or timeout (confirmed by the user: timeout), SHALL verify that the chosen timer mechanism makes the rule achievable, and SHALL record the rule and a test for it in `design.md`.
3. THE Fallback_AI SHALL apply the Fallback_Timeout through an injectable mechanism, so that tests advance Fake_Time and wait for no real time.
4. IF the AI_Issue_Reporter throws, THEN THE Fallback_AI SHALL swallow the exception and SHALL still return the Secondary's Reply.
5. WHERE no AI_Issue_Reporter is supplied, THE Fallback_AI SHALL use a reporter that discards AI_Issues.
6. IF the Secondary also throws, or returns a reply that is not a Usable_Reply, THEN THE Fallback_AI SHALL complete its future with a typed error that carries the failure reason and no reply text and no Fact value. THE design phase SHALL choose the error type and SHALL justify the choice in `design.md`, and the Fallback_AI SHALL NOT invent a built-in last-resort line unless the design records why.
7. WHEN the Secondary also fails, THE Fallback_AI SHALL still have reported exactly one AI_Issue for the Primary failure, and SHALL NOT report a second AI_Issue.
8. THE Fallback_AI SHALL guarantee a non-empty Usable_Reply for every Primary_Outcome WHEN the Secondary is an Offline_AI, because the Offline_AI never fails (Requirements 4.8 and 7).
9. WHEN two `ask` calls overlap, THE Fallback_AI SHALL answer each call from its own Primary result, so that the results of one call never reach the other.
10. THE Fallback_AI SHALL NOT keep a timer running after `ask` has returned its Reply, so that no pending timer remains for the test framework or the app to flag.

### Requirement 11: AI issue and reporter

**User Story:** As a developer, I want fallbacks reported without leaking user data, so that I can see why the AI fell back and nothing private ends up in logs.

#### Acceptance Criteria

1. THE AI_Issue SHALL be an immutable value type with value equality and a matching hash code, with a kind from AI_Issue_Kind and a message.
2. THE AI_Issue_Kind SHALL be an enum with the values `threw`, `timedOut`, `emptyReply` and `invalidReply`.
3. THE AI_Issue message SHALL be a fixed text chosen from the kind (optionally with the Purpose name), and SHALL NOT include the Reply text, any Fact key or value, the error message or the stack trace of the Primary.
4. THE AI_Issue_Reporter SHALL be an AI-specific callback type that is analogous to the storage layer's `IssueReporter`. THE AI files SHALL NOT import any file under `packages/coffin_core/lib/src/storage/`.
5. THE AI layer SHALL provide a reporter that discards issues, for use as the default.
6. THE AI_Issue, the AI_Issue_Kind and the AI_Issue_Reporter SHALL be plain Dart with no Flutter imports.

### Requirement 12: Step 2 readiness and secret hygiene

**User Story:** As a maintainer, I want the step 2 remote provider to drop in without redesign, and I want proof that no secrets slipped in.

#### Acceptance Criteria

1. THE Coffin_AI, the Request, the Reply and the Fallback_AI SHALL allow a future `RemoteCoffinAI` that calls a proxy server to implement Coffin_AI and to serve as the Fallback_AI's Primary, with no change to the Coffin_AI, the Request, the Reply or the Fallback_AI.
2. THE test suite SHALL include a test with a fake Coffin_AI that returns a Reply with a Source other than `offline` and that is used as the Primary of a Fallback_AI, confirming that the Reply passes through unchanged.
3. THE AI files SHALL contain no URL, no endpoint, no API key, no token and no HTTP code.
4. THE Source_Scan_Test SHALL read every `.dart` file under `packages/coffin_core/lib/src/ai/` and SHALL fail if any file contains, case-insensitively: `http://`, `https://`, `api_key`, `apikey`, `authorization`, `bearer`, `package:http`, `dart:io`, `dart:html`, `HttpClient`, `package:flutter`, `DateTime.now`, `Stopwatch` or an import path containing `src/storage`.
5. THE Source_Scan_Test SHALL fail if any file under `packages/coffin_core/lib/src/ai/` contains `Random(` without a seed argument.
6. THE Source_Scan_Test SHALL run on the Dart VM, and WHERE the platform has no file access (Chrome), THE Source_Scan_Test SHALL be tagged or skipped explicitly for that platform and SHALL NOT fail there.
7. THE feature SHALL add no secret, token or URL to any file in the repository.

### Requirement 13: Property-based verification of the offline generator

**User Story:** As a maintainer, I want the offline invariants checked over many generated inputs on every platform, so that no edge case slips through.

#### Acceptance Criteria

1. THE AI_Property_Tests SHALL use glados to generate Requests that cover: the two Known_Purpose constants and app-defined custom Purposes with random valid identifiers (including identifiers that reuse a Known_Purpose identifier), Facts with missing keys, extra keys and mixed value types (including strings with emoji, accents, control characters and long text, whole and fractional doubles, negative numbers, very large numbers and lists as values), Seeds across the full allowed range including the minimum and maximum, and Max_Length values across a range that includes the Minimum_Max_Length, values just above it and large values.
2. FOR ALL generated Requests, THE AI_Property_Tests SHALL assert that the Offline_AI reply is non-empty, has a non-whitespace character and has length at most the Max_Length.
3. FOR ALL generated Requests, THE AI_Property_Tests SHALL assert that two calls on the same instance and a call on a fresh instance return equal Replies.
4. FOR ALL generated Requests, THE AI_Property_Tests SHALL assert that the reply contains none of the banned words, compared case-insensitively, using a list declared in the test file.
5. FOR ALL generated Requests, THE AI_Property_Tests SHALL assert that the reply has no lone surrogate and no leading or trailing whitespace.
6. FOR ALL generated Requests, THE AI_Property_Tests SHALL assert that the Source of the reply is `offline`.
7. THE AI_Property_Tests SHALL NOT use the glados generators `any.intInRange` or `any.listWithLengthInRange`, because they throw on Flutter Web in glados 1.1.7. THE tests SHALL use web-safe generator helpers, in the style of `packages/coffin_core/test/storage/support/storage_generators.dart`, kept under `packages/coffin_core/test/ai/support/`.
8. THE AI_Property_Tests SHALL keep every generated integer within the range that both the Dart VM and JavaScript represent exactly (no value above 2^53).
9. THE AI_Property_Tests SHALL count the runs executed and SHALL assert that the count is greater than zero and equals the configured number of runs, so that no test passes vacuously.
10. THE AI_Property_Tests SHALL use a configured number of runs of at least 200 per property, and the design phase SHALL state the numbers.
11. IF any generated input violates an invariant, THEN THE AI_Property_Tests SHALL fail and report the input.
12. THE AI_Property_Tests SHALL follow the style of the existing glados tests under `packages/coffin_core/test/router/` and `packages/coffin_core/test/storage/`.
13. FOR ALL generated custom Purposes whose identifier is not a Known_Purpose identifier, THE AI_Property_Tests SHALL assert that the reply does not contain the Purpose identifier. THE generators SHALL give these identifiers a distinctive marker, so that short identifiers cannot overlap natural words in the copy.
14. FOR ALL generated Requests, THE AI_Property_Tests SHALL assert that the Offline_AI reply is the same for two Requests that differ only in a custom Purpose identifier, as long as neither identifier is a Known_Purpose identifier.

### Requirement 14: Property-based verification of the fallback

**User Story:** As a maintainer, I want the fallback guarantees checked for every combination of primary outcomes, so that the app can rely on getting a reply.

#### Acceptance Criteria

1. THE AI_Property_Tests SHALL use glados to generate sequences of Primary_Outcomes (success, throw, timeout, empty and invalid) together with Requests, whose Purposes include the two Known_Purpose constants and app-defined custom Purposes with random identifiers, and SHALL run each sequence through one Fallback_AI with an Offline_AI Secondary, a recording reporter and Fake_Time.
2. FOR ALL generated sequences, THE AI_Property_Tests SHALL assert that every call returns a non-empty Usable_Reply.
3. FOR ALL generated sequences, THE AI_Property_Tests SHALL assert that the Source of the reply is the Primary's Source for a success and `offline` for every other outcome.
4. FOR ALL generated sequences, THE AI_Property_Tests SHALL assert that the reporter received exactly one AI_Issue per non-success outcome and none for a success, and that the AI_Issue kind matches the outcome (throw to `threw`, timeout to `timedOut`, empty to `emptyReply`, invalid to `invalidReply`).
5. FOR ALL generated sequences, THE AI_Property_Tests SHALL assert that no AI_Issue message contains the reply text or any Fact value from the Request.
6. FOR ALL generated sequences that include late Primary completions after a timeout, THE AI_Property_Tests SHALL assert that the test zone records no unhandled error.
7. THE fallback property tests SHALL use Fake_Time and SHALL wait for no real time, so that the whole property run finishes within the normal test timeout.
8. THE fallback property tests SHALL NOT rely on an async glados test body unless the design phase confirms that glados 1.1.7 awaits async bodies, as the crypt-storage design confirmed. Otherwise THE tests SHALL drive the async work with `FakeAsync` or a synchronous driver inside the property body.
9. THE fallback property tests SHALL count the runs executed and the calls executed, SHALL assert that both are greater than zero, and SHALL assert that the runs executed equal the configured number of runs.
10. THE fallback property tests SHALL use web-safe generators under the same rule as Requirement 13.7.

### Requirement 15: Example-based tests

**User Story:** As a maintainer, I want the specific behaviors covered by plain tests, so that failures are easy to read.

#### Acceptance Criteria

1. THE test suite SHALL include a unit test of the Offline_AI for each Known_Purpose and for an app-defined Purpose, and unit tests of Purpose validation (invalid identifier rejected with `ArgumentError`) and equality (same identifier equal, including a custom Purpose that reuses a Known_Purpose identifier).
2. THE test suite SHALL include unit tests for missing Facts, for Facts of the wrong type, for out-of-range counts, for extra Facts and for String Facts with emoji, accents, control characters and more than 24 UTF-16 code units.
3. THE test suite SHALL include unit tests for a Max_Length equal to the Minimum_Max_Length, one above it, and one below it (which throws an `ArgumentError`).
4. THE test suite SHALL include unit tests for Seed validation (negative, above the maximum, at both limits).
5. THE test suite SHALL include unit tests that cover each Primary_Outcome through the Fallback_AI, with the reporter output checked.
6. THE test suite SHALL include a unit test in which the AI_Issue_Reporter throws, and the Fallback_AI still returns a Reply.
7. THE test suite SHALL include a timeout boundary test (a Primary that completes just before the timeout, exactly at the timeout, and just after) using Fake_Time.
8. THE test suite SHALL include a late-completion test, for a Primary that completes with a value and for a Primary that completes with an error after the timeout, with no unhandled error.
9. THE test suite SHALL include a test of a failing Secondary that confirms the typed error of Requirement 10.6 and a single reported AI_Issue.
10. THE test suite SHALL include a test of a Fallback_AI used as the Primary of another Fallback_AI.
11. THE test suite SHALL include value-equality tests for the Request (including Facts order independence), the Reply and the AI_Issue.
12. THE test suite SHALL include a test that mutating the map passed to a Request does not change the Request.
13. THE test suite SHALL include the Template checks of Requirement 8.8 and the Insult_Words check of Requirement 8.5.
14. THE test suite SHALL include the golden test of Requirement 5.7.

### Requirement 16: Package boundaries and scope

**User Story:** As a maintainer, I want the AI layer to follow the project structure, so that the skeleton stays easy to read.

#### Acceptance Criteria

1. THE AI source files SHALL live under `packages/coffin_core/lib/src/ai/`, in `snake_case.dart` files with one public class per file.
2. THE AI tests SHALL live under `packages/coffin_core/test/ai/`, mirroring the `lib/` layout.
3. THE AI source files SHALL be plain Dart: no `package:flutter`, no `dart:io`, no `dart:html` and no network package.
4. THE Barrel SHALL export the public AI names using `show` clauses consistent with the existing exports, and SHALL export nothing else from `src/ai/`.
5. EVERY public API in the AI source files SHALL carry a doc comment.
6. THE coffin_core package SHALL import nothing from `apps/hauntagotchi` or `apps/graveyard`.
7. THE Hauntagotchi and Graveyard apps SHALL NOT import the AI API in this feature, and no app `pubspec.yaml` SHALL change.
8. THE AI source files SHALL contain no Riverpod, storage or routing code, and SHALL NOT import any file from `src/storage/`, `src/router/`, `src/theme/` or `src/widgets/`.
9. THE feature SHALL add no new package to any `pubspec.yaml`.
10. THE feature SHALL write no files outside the repository.

### Requirement 17: Quality gates

**User Story:** As a maintainer, I want the feature to meet the workspace quality rules on every platform, so that the codebase stays clean and the web build keeps working.

#### Acceptance Criteria

1. THE feature code SHALL pass `dart format` with no changes.
2. THE feature code SHALL pass `flutter analyze` with zero warnings across the workspace.
3. THE feature SHALL include unit tests for every class under `packages/coffin_core/lib/src/ai/`.
4. THE feature SHALL include the glados property tests of Requirements 13 and 14.
5. WHEN `flutter test` runs for `coffin_core` and for both apps, THE test suite SHALL pass before any task is marked done.
6. THE AI tests (all of them except the Source_Scan_Test) SHALL pass with `flutter test --platform chrome` in `packages/coffin_core`, and the implementation plan SHALL include a task that runs them on Chrome.
7. THE feature SHALL add no new package and SHALL leave every `pubspec.yaml` and `pubspec.lock` free of new dependencies.
8. THE feature SHALL add no API keys, secrets, tokens or URLs to the repository.
9. THE feature SHALL leave `flutter build web` compiling for both apps.
