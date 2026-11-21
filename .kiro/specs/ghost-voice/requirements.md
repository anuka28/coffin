# Requirements Document

## Introduction

Wisp speaks. Under the ghost, Hauntagotchi shows one short line that reacts to Wisp's mood, the streak and what just happened: opening the app, a check-off, a mood change or a resurrection. The line comes from `CoffinAI` with the purpose `AiPurpose.ghostMoodLine`.

Everything runs offline. Hauntagotchi builds a `FallbackCoffinAI` over an `OfflineCoffinAI`. There is no network call, no API key and no new package.

Mood awareness belongs in `coffin_core`, so every Coffin app can use it. `coffin_core` gains a mood fact and mood-aware offline templates for `ghostMoodLine`. A request that does not carry the new facts produces exactly the same text as today.

The line is not chatty. It changes only on four triggers, it is stable for the same situation on the same day, and it never blocks or breaks the screen.

## Dependency and Asset Notice

This feature adds NO new package, NO font, NO image, NO sound and NO `pubspec.yaml` change. `pubspec.lock` SHALL stay unchanged. It uses no network and no secret. `CREDITS.md` and `DIARY.md` are not edited.

## Non-Goals

- No network AI, no API key, no remote implementation of `CoffinAI`.
- No change to health, decay, streak or ritual rules, and no new `GhostState` value.
- No change to the existing `GhostMood` enum or to ghost painting.
- No Graveyard change, no change to the raise template (`tool/`). Both keep passing unchanged.
- No chat history, no scrolling log of past lines, no user-typed prompt.
- No sound, no haptics, no push notification, no speech synthesis.
- No change to the `ghostMoodLine` copy for requests without the new facts.
- No change to `DIARY.md`, `CREDITS.md`, `pubspec.yaml` files or `pubspec.lock`.

## Glossary

- **Ghost_Voice**: The Hauntagotchi feature that shows one line under the ghost.
- **Voice_Line**: The single line of text shown under the ghost.
- **Voice_Trigger**: One of four events that may change the Voice_Line: `appOpened`, `checkedOff`, `moodChanged`, `resurrected`. It is a pure Dart enum `VoiceTrigger` in `apps/hauntagotchi/lib/src/domain/`, and its `name` is the value of the Event_Fact.
- **Mood_Fact**: The new fact key in `AiFactKeys` (named `ghostMood`) whose value is the `name` of a steady `GhostMood`: `thriving`, `content`, `hungry`, `fading` or `dead`.
- **Event_Fact**: The new fact key in `AiFactKeys` (named `ghostEvent`) whose value is the name of a Voice_Trigger. See the open question in Requirement 1.
- **Mood_Templates**: The mood-aware offline templates for `ghostMoodLine` in `coffin_core`, selected by the Mood_Fact and the Event_Fact.
- **Legacy_Request**: An `AiRequest` for `ghostMoodLine` that carries neither the Mood_Fact nor the Event_Fact.
- **Voice_Seed**: The `AiRequest.seed` that Hauntagotchi computes from the local day, the Ghost_State, the Voice_Trigger, the streak and the number of habits completed today.
- **Ghost_State**: The existing Hauntagotchi enum `GhostState` (`dead`, `fading`, `hungry`, `content`, `thriving`).
- **Streak**: `Haunting.streak`, the number of consecutive days with at least one completed habit. Hauntagotchi has no per-habit streak.
- **Completed_Today**: `HabitBook.completedCountOn(today)`, the number of active habits completed today.
- **Mood_Mapping**: The Hauntagotchi function in `lib/src/ui/` that maps a Ghost_State to the Mood_Fact value (the name of the steady `GhostMood` from `moodFor`).
- **Voice_Request_Builder**: The Hauntagotchi function in `lib/src/ui/` that builds the `AiRequest` from a Voice_Trigger, a Ghost_State, the Streak, the Completed_Today count, the ghost name and the local day.
- **Domain_Folder**: `apps/hauntagotchi/lib/src/domain/`, pure Dart that imports no Flutter and no `coffin_core` (see Requirement 13.2).
- **Fallback_Line**: The text shown when the AI call is slow or fails: the line from the offline path, or the fixed safe line of Hauntagotchi if even that is missing.
- **Voice_Controller**: The Hauntagotchi class (a `ChangeNotifier`) that decides when to ask for a new line and holds the current Voice_Line.
- **Voice_Policy**: The pure Dart class in the Domain_Folder that decides whether an event is a Voice_Trigger. It works on Ghost_State, not on `GhostMood`.
- **Voice_Panel**: The Hauntagotchi widget that shows the Voice_Line under the ghost.
- **Reduced_Motion**: The state where `MediaQuery.disableAnimations` is true.
- **Web_Safe**: Behavior that gives identical results on the Dart VM and on Flutter Web, using integer arithmetic and `+ - * /` and comparisons only, with every intermediate value an integer below 2^53, so that the Dart VM and the JavaScript number type agree. No bitwise operator SHALL be applied to a value of 2^31 or more, because JavaScript bitwise operators truncate their operands to 32 bits.
- **Checkpoint**: A task after which `dart format` (no changes), `flutter analyze` (zero warnings) and `flutter test` pass.

## Requirements

### Requirement 1: Mood fact in coffin_core

**User Story:** As a Flutter developer using Coffin, I want to pass a ghost's mood to the offline AI, so that any Coffin app can get mood-aware lines.

#### Acceptance Criteria

1. THE `AiFactKeys` class SHALL gain a public constant for the Mood_Fact (`ghostMood`) with a doc comment that lists the five accepted values.
2. THE Mood_Fact value SHALL be the `name` of a steady `GhostMood`. THE offline generator SHALL read it as a string and SHALL NOT make the `ai/` folder import Flutter.
3. WHEN the Mood_Fact is missing, is not a string, or is a name outside the five accepted values (including `fed` and `rising`), THE offline generator SHALL treat it as absent, without throwing.
4. THE `AiFactKeys` class SHALL gain a second public constant for the Event_Fact (`ghostEvent`), documented, with the accepted values `appOpened`, `checkedOff`, `moodChanged` and `resurrected`. An unknown or non-string value SHALL be treated as absent.
5. THE clean-facts step SHALL keep its existing cleaning rules for `streakCount`, `daysSinceLastCommit`, `ghostName` and `projectName` unchanged.
6. THE Barrel SHALL keep exporting `AiFactKeys` and SHALL NOT export any new internal AI class.

**Open question for review:** Decision 2 names only the mood fact. The four situations (open, check-off, mood change, resurrection) need a second fact, so this spec adds the Event_Fact. If you prefer one fact, the event could be folded into a combined value, but two facts keep each one simple to validate.

### Requirement 2: Mood-aware offline templates

**User Story:** As a user, I want Wisp's line to match how Wisp feels, so that the words and the ghost agree.

#### Acceptance Criteria

1. WHEN a `ghostMoodLine` request carries a valid Mood_Fact, THE offline generator SHALL pick its line from the Mood_Templates for that mood, and from the subset for the Event_Fact when that fact is valid.
2. THE Mood_Templates SHALL cover every combination of the five moods and the four Voice_Triggers with at least 3 templates per combination (so a seed has a real choice), plus at least 3 templates per mood that apply when the Event_Fact is absent.
3. WHEN the request also carries a valid `streakCount`, THE Mood_Templates for `thriving`, `content` and `appOpened` or `checkedOff` SHALL be able to mention the streak with the existing count slot syntax, and THE templates SHALL be eligible only when their slots have facts, as today.
4. WHEN the request carries a valid `ghostName`, THE Mood_Templates SHALL be able to use the name with the existing slot syntax, with a default when the name is absent.
5. EVERY template in the Mood_Templates SHALL fit in 80 characters after filling its slots with the largest allowed values (name of 40 characters, streak of 1000000), or the spec SHALL reduce the name slot length. THE test for this SHALL render every template.
6. IF no mood template is eligible for a request, THEN THE offline generator SHALL fall back to the existing `ghostMoodLine` safe line, never to an empty string.
7. THE Mood_Templates SHALL be deterministic: the same request (purpose, facts, max length, seed) SHALL give the same text on every call and on every platform.
8. THE catalog SHALL keep the existing `forPurpose` mapping, and `seanceVerdict` and `generic` copy SHALL stay unchanged.

### Requirement 3: Legacy requests are byte-for-byte unchanged

**User Story:** As a maintainer, I want the new feature to leave current callers alone, so that nothing else breaks.

#### Acceptance Criteria

1. WHEN a request has no Mood_Fact and no Event_Fact, THE offline generator SHALL return exactly the same text and the same compose path as before this feature, for every seed, every max length and every combination of the existing facts.
2. WHEN a request has an invalid Mood_Fact and an invalid Event_Fact, THE offline generator SHALL behave as for a Legacy_Request.
3. THE existing tests under `packages/coffin_core/test/ai/` SHALL pass unchanged, with no edited assertion, except the one expired guard replaced under Requirement 5.6. New tests go in new files, or in new `test`/`group` blocks that do not change existing ones. Shared support files (for example the generators) MAY gain additions only.
4. A glados property test SHALL check Requirement 3.1: for generated Legacy_Requests, the new engine and a frozen copy of the old template list give the same text. The frozen copy lives in the test only.
5. THE existing `ghostMoodLine` templates SHALL stay in the catalog, in the same order, and SHALL NOT be reused by the Mood_Templates unless a Mood_Fact is present.

### Requirement 4: Tone

**User Story:** As a user, I want Wisp to be warm and kind, so that I want to come back.

#### Acceptance Criteria

1. THE Mood_Templates SHALL be one line each: no line break, no list, at most 80 characters, and ending in punctuation or an emoji.
2. THE Mood_Templates SHALL be spooky and warm, in the tone of the design rules ("Haunted, not horror"), and SHALL contain no gore.
3. THE Mood_Templates for `hungry` and `fading` (a missed day) SHALL be a gentle nudge: they SHALL NOT shame, blame, threaten or count the days lost, and they SHALL NOT use words such as "failed", "lazy", "worthless", "abandoned" or "neglected".
4. THE Mood_Templates for `dead` SHALL speak hopefully about the ritual and SHALL NOT say the user caused the death.
5. THE Mood_Templates for `resurrected` SHALL be celebratory and SHALL NOT mention the time spent dead.
6. A unit test SHALL scan every template of the Mood_Templates for a list of banned words (shame words and gore words) and for the length and one-line rules.
7. THE copy SHALL use no em-dash chains and SHALL keep the voice of the existing templates ("Your ghost is getting hungry…").
8. NO template and no safe line of the Mood_Templates SHALL contain an emoji or a pictograph. Plain words only, because offline web may draw an emoji as an empty box and a screen reader reads its name aloud. Every character of a template or safe line SHALL be printable ASCII (U+0020 to U+007E) or the ellipsis U+2026. A unit test SHALL check every template pattern, every safe line and every rendered line.
9. EVERY streak SHALL read naturally with its unit and the correct singular or plural: "1 day", "3 days". A template SHALL NOT show a bare number such as "3 and counting". Every count slot SHALL be `{streakCount:day/days}` (the existing slot renders "1 day" and "2 days"), so no new slot syntax is needed. A unit test SHALL render every Mood_Templates template that holds a count slot for a streak of 1 and for several streaks of 2 or more (including 1000000), and SHALL check that every digit run of the rendered line is followed by exactly " day" for 1 and " days" for 2 or more, and that "1 days" and "2 day" never appear.

### Requirement 5: Hauntagotchi uses the offline AI only

**User Story:** As a judge testing the app by URL, I want the app to work without a network or a key, so that it runs anywhere.

#### Acceptance Criteria

1. THE Hauntagotchi app SHALL build one `FallbackCoffinAI` with an `OfflineCoffinAI` as both the primary and the secondary, or as primary and secondary as the design chooses, so that the existing fallback and timeout rules apply. The app SHALL ask with `AiPurpose.ghostMoodLine`.
2. THE app SHALL make no network call, read no environment variable for a key and contain no secret.
3. THE app SHALL import AI types only from `package:coffin_core/coffin_core.dart`.
4. THE `HomeController` constructor and the `HauntagotchiApp` constructor SHALL stay source compatible: the AI SHALL be an optional parameter with a default, so that existing tests compile without edits.
5. THE feature SHALL NOT change any `pubspec.yaml` and SHALL NOT change `pubspec.lock`. A task SHALL check this with `git diff --exit-code` on those files.
6. THE test "no app file references the AI API" in `packages/coffin_core/test/ai/ai_sources_test.dart` expired when the first app began to use the AI layer (Graveyard will use it next). IT SHALL be replaced by the lasting rule, as the storage tests already do: every app file under `lib` and `test` imports `coffin_core` only through `package:coffin_core/coffin_core.dart`, and any `import` or `export` of `package:coffin_core/src/` is reported as `file:line`. The helper names and the self-check lines of the old test SHALL be removed or replaced so that `flutter analyze` stays clean, and the rule SHALL have a self-check that flags a bad sample and spares a good one. The test "app pubspecs do not mention the AI layer" stays unchanged.

### Requirement 6: Voice triggers

**User Story:** As a user, I want Wisp to speak at meaningful moments only, so that the line feels alive and not noisy.

#### Acceptance Criteria

1. THE Voice_Policy SHALL be a pure Dart class in the Domain_Folder with no Flutter import and no `coffin_core` import, and SHALL decide a Voice_Trigger from plain values (previous and next Ghost_State, the kind of event, the day).
2. WHEN the home screen finishes loading and shows the ghost, THE Ghost_Voice SHALL ask for exactly one line with the trigger `appOpened`.
3. WHEN a check-off succeeds (a habit is completed for today, not undone), THE Ghost_Voice SHALL ask for exactly one line with the trigger `checkedOff`, also when the ghost is already at full health.
4. WHEN the ghost's steady mood changes for any reason other than a check-off or a resurrection (for example a day passes while the app is open, or an undo lowers the state), THE Ghost_Voice SHALL ask for exactly one line with the trigger `moodChanged`.
5. WHEN a ritual completes and the ghost is resurrected, THE Ghost_Voice SHALL ask for exactly one line with the trigger `resurrected`.
6. WHEN one action causes more than one trigger (a check-off that also changes the mood, or a check-off that resurrects), THE Ghost_Voice SHALL ask once, with the trigger of the highest priority: `resurrected`, then `checkedOff`, then `moodChanged`, then `appOpened`.
7. THE Ghost_Voice SHALL NOT ask for a new line on a widget rebuild, a save, a save retry, a rename, an archive, an add, a refresh that changes nothing, an undo that keeps the mood, a route change, a theme change or a window resize. Tests SHALL pump rebuilds and perform each of these actions and SHALL check that the number of AI calls and the Voice_Line do not change.
8. WHEN a trigger fires while an earlier request is still running, THE Voice_Controller SHALL ignore the result of the earlier request, so that the Voice_Line always matches the latest trigger.
9. A glados property test SHALL check, over generated sequences of events, that the number of AI calls equals the number of Voice_Triggers and never exceeds it.

### Requirement 7: Stable, seeded lines

**User Story:** As a user, I want the same situation to give the same line on the same day, so that tapping does not make Wisp babble.

#### Acceptance Criteria

1. THE Voice_Seed SHALL be a pure function of the local day (its `epochDay`), the Ghost_State, the Voice_Trigger, the Streak and the Completed_Today count, and of nothing else (no clock read, no random source, no habit name).
2. THE Voice_Seed SHALL be in the range `0` to `AiRequest.maxSeed` and SHALL be Web_Safe: it SHALL use integer arithmetic (`+`, `*`, `%`) with every intermediate value below 2^53, and no bitwise operator.
3. WHEN the same situation (same day, Ghost_State, trigger, Streak and Completed_Today) occurs twice, THE Ghost_Voice SHALL show the same Voice_Line both times, also after an app restart.
4. WHEN two check-offs happen on the same day, THE Completed_Today count differs between them, so THE Voice_Seed SHOULD differ and each check-off gets its own line. A test SHALL check this with a scripted session of several check-offs on one day.
5. WHEN any one of the five inputs differs, THE Voice_Seed SHOULD differ. A property test SHALL check that changing one input changes the seed for at least 99 percent of generated pairs, and a unit test SHALL pin a few known seeds.
6. THE Voice_Seed SHALL live in plain Dart in the Domain_Folder, with no Flutter import and no `coffin_core` import.

### Requirement 8: Facts sent to the AI

**User Story:** As a maintainer, I want the request to hold only what the line needs, so that nothing private leaks into it.

#### Acceptance Criteria

1. THE request facts SHALL be limited to the Mood_Fact, the Event_Fact, `streakCount` and `ghostName`.
2. THE request SHALL NOT contain habit names, notes or any other user text. The ghost name is the only user text and SHALL pass through the existing name cleaning of `coffin_core`.
3. WHEN the streak is 0, THE request SHALL omit `streakCount` (the engine accepts counts of 1 or more).
4. THE request SHALL use a `maxLength` of 80.
5. THE Mood_Mapping SHALL live in `lib/src/ui/`, next to `moodFor`, and SHALL be a total function from Ghost_State to the Mood_Fact value, with a unit test for each of the five states. It SHALL NOT live in the Domain_Folder.
6. THE `streakCount` fact SHALL be `Haunting.streak`, the one streak Hauntagotchi has. There is no per-habit streak. A unit test SHALL check the value sent for a streak of 0 (omitted), 1 and a larger number.
7. THE Voice_Request_Builder SHALL live in `lib/src/ui/`, because it uses `AiRequest`, `AiPurpose` and `AiFactKeys` from `coffin_core`. A unit test SHALL check the purpose, the facts, the `maxLength` and the seed of the built request.

### Requirement 9: Never blocks or breaks the screen

**User Story:** As a user, I want my habits to work even when the voice is slow or broken, so that Wisp's words never get in my way.

#### Acceptance Criteria

1. THE Home_Screen SHALL show the habits and accept check-offs while a Voice_Line is being requested. The AI call SHALL NOT block `toggle`, `load`, saving or navigation.
2. WHEN the AI call is slow (longer than the `FallbackCoffinAI` timeout) or fails, THE Voice_Controller SHALL show the Fallback_Line, and a test with a scripted slow AI and a scripted throwing AI SHALL check this.
3. WHEN the AI call throws synchronously or returns an error, THE Voice_Controller SHALL catch it, SHALL NOT surface an error to the user and SHALL NOT crash the app.
4. WHILE no line has arrived yet, THE Voice_Panel SHALL show the previous line, or the Fallback_Line when there is none, and SHALL NOT show a spinner or an empty box.
5. THE Voice_Controller SHALL not call `notifyListeners` after it is disposed, and a test SHALL dispose it with a request in flight.
6. THE `HomeController` state and the storage writes SHALL be identical with and without the Ghost_Voice (a test SHALL compare them for a scripted session).
7. THE timeout and the retry rules of `FallbackCoffinAI` SHALL NOT be changed.

### Requirement 10: The Voice Panel

**User Story:** As a user, I want to read Wisp's line under the ghost on any screen size, so that the ghost feels like it is talking to me.

#### Acceptance Criteria

1. THE Home_Screen SHALL show the Voice_Panel directly under the ghost and above the habit list.
2. THE Voice_Panel SHALL show the Voice_Line as real `Text` (not an image or a painted shape), in the body font of the theme, and SHALL wrap without overflow and without cutting the text (no `maxLines`, no ellipsis) at Phone_Width (320 and 360 logical pixels) and at 1280, also at a text scale of 2.0. The home list scrolls, so a longer line only makes the panel taller.
3. THE Voice_Panel SHALL follow the design rules: 16 px rounded corners, soft glow instead of a hard shadow, and text contrast that meets WCAG AA in the night and the daylight themes.
4. THE Voice_Panel SHALL NOT be an interactive element, so the 48 by 48 tap target rule does not apply to it. It SHALL NOT take focus.
5. THE Voice_Panel SHALL show no more than one line at a time (one `Voice_Line`, no history).
6. THE existing home screen tests SHALL pass unchanged, apart from changes that the new panel makes unavoidable (for example a finder that now matches two widgets). Each such change SHALL be listed in the design.

### Requirement 11: Accessibility

**User Story:** As a screen reader user, I want to hear Wisp when I ask and not be flooded, so that the app stays usable.

#### Acceptance Criteria

1. THE Voice_Panel SHALL expose the Voice_Line to the semantics tree as a labelled text node, with a label such as "Wisp says: <line>", and SHALL use the ghost's name instead of "Wisp" when the ghost has one.
2. THE Voice_Panel SHALL NOT use a live region that announces every change. It SHALL announce at most one line per Voice_Trigger, and SHALL NOT announce the line on `appOpened`, on `moodChanged` caused by time passing, or when the line text equals the previous line.
3. WHEN a check-off or a resurrection changes the line, THE app MAY announce the new line once with a polite announcement, and SHALL NOT announce twice for the same trigger. A test SHALL count announcements over a scripted session of 10 check-offs and SHALL check that it is at most one per check-off.
4. THE Voice_Panel SHALL show no typing effect, no per-character animation and no flicker.
5. WHILE Reduced_Motion is on, THE Voice_Panel SHALL show a new line at once, with no fade and no slide and no animation controller running. A widget test SHALL check that no animation is scheduled after the line changes.
6. WHILE Reduced_Motion is off, THE Voice_Panel MAY fade the new line in over 300 to 600 ms with an ease-in-out curve, once per change, with no loop.
7. THE semantics of the Voice_Panel SHALL NOT duplicate the semantics of the ghost (`GhostPanel` labels stay as they are), so a screen reader reads each fact once.

### Requirement 12: Pure logic and tests

**User Story:** As a maintainer, I want pure logic covered by unit and property tests, so that regressions show up fast.

#### Acceptance Criteria

1. THE Voice_Policy, the Voice_Seed and the Voice_Trigger SHALL be pure Dart in the Domain_Folder with no Flutter import and no `coffin_core` import. THE Mood_Mapping and the Voice_Request_Builder SHALL be plain functions in `lib/src/ui/` that need no widget tree. Unit tests SHALL mirror the `lib/` folder structure.
2. THE feature SHALL have glados property tests for: Legacy_Request equality (Requirement 3.4), the Voice_Seed range, Web_Safety and sensitivity to each of its five inputs (Requirement 7), the trigger count (Requirement 6.9), and determinism of the Mood_Templates (same request, same text).
3. A glados property test SHALL check, for every steady mood and trigger and for generated seeds, streaks and names, that the Mood_Templates return a line of at most 80 characters, with no line break, and never an empty string.
4. ALL property tests SHALL use only Web_Safe generators: integer ranges below 2^32, `int` and `bool` and enum choices and strings built from a fixed alphabet. They SHALL NOT use `double` generators, `DateTime.now` or `Random` without a seed.
5. THE widget tests SHALL cover: the line under the ghost, no change on rebuild, save, rename and archive, one call per trigger, slow and failing AI, Reduced_Motion on and off, the semantics label, the announcement count, and no overflow at 320, 360 and 1280 logical pixels.
6. TEST tasks SHALL NOT be optional in `tasks.md`: none SHALL be marked with an optional `*`.
7. THE feature SHALL touch no file outside the allowed list of Requirement 13.
8. EVERY task of this feature SHALL end at a Checkpoint, and a task SHALL NOT be marked done until `flutter test` passes in `packages/coffin_core` and `apps/hauntagotchi`.

### Requirement 13: Scope, boundaries and hygiene

**User Story:** As the maintainer of the Coffin skeleton, I want the change to stay in its lane, so that the skeleton stays clear and the other apps stay untouched.

#### Acceptance Criteria

1. THE feature SHALL edit only: `packages/coffin_core/lib/src/ai/`, `packages/coffin_core/test/ai/`, the AI section of `packages/coffin_core/README.md`, `apps/hauntagotchi/lib/`, `apps/hauntagotchi/test/`, and `.kiro/specs/ghost-voice/`. A final task SHALL check this with `git status` and `git diff --stat`.
2. THE `coffin_core` package SHALL NOT import from an app, the apps SHALL NOT import each other, and Hauntagotchi SHALL import only `package:coffin_core/coffin_core.dart`, never a file under `src/`. No file in the Domain_Folder SHALL import `package:coffin_core`, `package:flutter` or `dart:ui`, because `GhostMood` and the AI types come from a Flutter package. A source-rule test in `apps/hauntagotchi/test/source_rules/` SHALL check this for every file in the Domain_Folder, including the new ones.
3. THE Graveyard tests, the `tool/` tests (including the raise template) and every existing `coffin_core` and Hauntagotchi test SHALL pass unchanged, except for the allowed changes of Requirement 10.6 and the one replaced guard of Requirement 5.6.
4. THE README AI section SHALL document the Mood_Fact, the Event_Fact, their accepted values, and the rule that requests without them are unchanged. Every new public API in `coffin_core` SHALL have a doc comment.
5. THE one-public-class-per-file and snake_case file naming rules SHALL hold for every new file.
6. THE feature SHALL create no file outside the repository, including `/tmp`. Tests SHALL use no temporary file, or only a folder inside the repository that is skipped by the repo scans and removed after the test.
7. THE final task SHALL run the full `flutter test` in `packages/coffin_core`, `apps/hauntagotchi`, `apps/graveyard` and `tool`, `dart format` and `flutter analyze`, and report the results.
