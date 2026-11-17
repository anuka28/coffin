# Requirements Document

## Introduction

The hauntagotchi-core feature builds the core loop of Hauntagotchi in `apps/hauntagotchi`: habits, ghost health, daily decay, death and resurrection, saved on the device, with one working screen at `/`. The user keeps 3 to 5 habits, ticks them off each day, and the ghost thrives or fades with the result. Animated ghost moods and the AI personality belong to later specs and are not built here. The ghost is drawn with the existing `GhostLoader` for now.

The rules live in pure Dart in `lib/src/domain` (no Flutter imports). Days are local calendar days. All time comes from an injected clock. Decay is computed by catching up on every missed day when the app opens, resumes or acts, never by a timer, because the app runs on Flutter Web where nothing runs while the tab is closed. Habits and ghost are saved through `coffin_core`'s `StorageOpener` and `RecordRepository` with `RecordCodec` implementations and `currentVersion` 1. The design language is "Haunted, not horror", as defined in the design steering document.

Concrete numbers (health gains and losses, state thresholds, the ritual, the fresh-start health, the default ghost name) belong to the design phase. This document states them as measurable behavioral outcomes that the design numbers must satisfy.

## Dependency Notice

Two project-rule questions are decided and need no further approval:

- **Property tests.** `glados: 1.1.7`, the version `coffin_core` uses, is added as one line under `dev_dependencies` of `apps/hauntagotchi/pubspec.yaml`. `glados` is already in the root `pubspec.lock`, so the lock file must stay unchanged. No other package is added.
- **State management.** The tech steering names Riverpod, which Hauntagotchi does not use and which the raised-app template copies into every new app. This feature uses Flutter's built-in `ChangeNotifier` and `ListenableBuilder` for one controller. The steering line is corrected as the first change of the feature (Requirement 15), in `.kiro/steering/tech.md` and in `tool/templates/app/.kiro/steering/tech.md.tmpl`.

The two steering lines and the one `pubspec.yaml` line are the only changes outside `apps/hauntagotchi/lib` and `apps/hauntagotchi/test`. Nothing changes in `coffin_core` or Graveyard.

The request names `RecordCodecs`. `coffin_core` exports the interface `RecordCodec<T>`, and this document uses that name.

## Glossary

- **Hauntagotchi_App**: The Flutter app in `apps/hauntagotchi`.
- **Domain**: The pure Dart code in `apps/hauntagotchi/lib/src/domain`. It imports no Flutter library and no `dart:io`.
- **Data_Layer**: The code in `apps/hauntagotchi/lib/src/data` that saves and loads habits and the ghost through `coffin_core`.
- **Home_Screen**: The one screen of this feature, shown at route `/`, replacing `PlaceholderScreen`.
- **Clock**: The injected source of time, a Domain interface with one method that returns the current local `DateTime`. Neither the Domain nor the Data_Layer calls `DateTime.now()` outside the production Clock implementation.
- **Local_Day**: A calendar day as a year, month and day value, taken from the local date of the Clock. A Local_Day carries no time of day and no time zone.
- **Day_Count**: The number of Local_Days from one Local_Day to another, computed on year, month and day values and never by dividing a duration by 24 hours.
- **Habit**: A thing the user wants to do daily. It has an id, a Habit_Name, a created Local_Day, the set of Local_Days on which it was completed, and an archived Local_Day that is empty while the Habit is active.
- **Habit_Name**: A name of 1 to 40 characters after trimming leading and trailing whitespace.
- **Active_Habit**: A Habit that is not archived.
- **Max_Active_Habits**: 5, the highest number of Active_Habits at one time.
- **Suggested_Min_Habits**: 3, the number of Active_Habits below which the Home_Screen nudges the user to add more.
- **Habit_Book**: The Domain object that holds all Habits and enforces the habit rules.
- **Ghost**: The pet. It has a Ghost_Name, a Health, a Last_Settled_Day, and a Resurrection_Count.
- **Ghost_Name**: A name of 1 to 40 characters after trimming.
- **Health**: An integer from 0 to 100 inclusive.
- **Ghost_State**: One of `thriving`, `content`, `hungry`, `fading`, `dead`. It is derived and never stored.
- **Recent_History**: The completion record of the most recent Local_Days, as defined in the design, that feeds the Ghost_State derivation.
- **Settled_Day**: A past Local_Day whose decay or feeding has been applied to Health.
- **Last_Settled_Day**: The most recent Local_Day that is a Settled_Day.
- **Today**: The Local_Day of the Clock at the moment of a check. Today is never a Settled_Day.
- **Catch_Up**: The operation that settles every Local_Day after the Last_Settled_Day and before Today, in order, and then sets the Last_Settled_Day to the day before Today.
- **Live_Health**: The Health shown to the user. It equals the Health after Catch_Up plus the feeding earned by completions made Today.
- **Neglect_Day**: A Settled_Day on which no Habit was completed while at least one Active_Habit existed.
- **Resurrection_Ritual**: The kind, non-punishing act that revives a dead Ghost. The design proposes it. It is completable only through the habit controls of the Home_Screen (completing a Habit, or archiving a Habit when that lowers the number of completions the ritual needs to a number already reached).
- **Fresh_Start_Health**: The Health of a Ghost right after the Resurrection_Ritual, set in the design.
- **Resurrection_Count**: The number of times the Ghost has been resurrected.
- **Streak**: The number of consecutive Local_Days, ending Today or yesterday, on each of which at least one Habit was completed.
- **Habit_Repository**: The `RecordRepository<Habit>` that stores Habits.
- **Ghost_Repository**: The `RecordRepository<Ghost>` that stores the Ghost.
- **Habit_Codec**: The `RecordCodec<Habit>` implementation.
- **Ghost_Codec**: The `RecordCodec<Ghost>` implementation.
- **Memory_Fallback**: The state in which `StorageOpener` returns a repository whose `isPersistent` is false.
- **Memory_Notice**: The gentle message on the Home_Screen that progress will not be saved during a Memory_Fallback.
- **Home_Controller**: The `ChangeNotifier` that owns the Habit_Book, the Ghost, the Clock and the repositories, and exposes them to the Home_Screen.
- **Fake_Clock**: A test Clock whose time the test sets.
- **Web_Safe_Generator**: A glados generator that avoids `any.intInRange` and `any.listWithLengthInRange`, which throw on Flutter Web in glados 1.1.7. It keeps every generated integer below 2^53.

## Requirements

### Requirement 1: Habit rules

**User Story:** As a user, I want a short list of daily habits that I can add, rename, archive and tick off, so that the ghost reflects what I really did.

#### Acceptance Criteria

1. WHEN the user adds a Habit with a valid Habit_Name, THE Habit_Book SHALL create an Active_Habit with a unique id, the trimmed Habit_Name, Today as the created Local_Day, and no completions.
2. IF a Habit_Name is empty or longer than 40 characters after trimming, THEN THE Habit_Book SHALL reject the add or rename with a reason and leave every Habit unchanged.
3. IF the Habit_Book already holds Max_Active_Habits Active_Habits, THEN THE Habit_Book SHALL reject an add with a reason and leave every Habit unchanged.
4. WHEN the user renames an Active_Habit with a valid Habit_Name, THE Habit_Book SHALL replace the Habit_Name with the trimmed name and keep the id, the created Local_Day and the completions.
5. WHEN the user archives an Active_Habit, THE Habit_Book SHALL set the archived Local_Day to Today, keep the completions, and exclude the Habit from the Active_Habits.
6. WHEN an Active_Habit is archived, THE Habit_Book SHALL free one slot of Max_Active_Habits.
7. WHEN the user completes an Active_Habit that has no completion for Today, THE Habit_Book SHALL add Today to the completed days of the Habit.
8. IF the user completes an Active_Habit that already has a completion for Today, THEN THE Habit_Book SHALL leave the Habit unchanged and report that the completion already exists.
9. WHEN the user undoes the completion of an Active_Habit that has a completion for Today, THE Habit_Book SHALL remove Today from the completed days of the Habit.
10. THE Habit_Book SHALL accept completion and undo only for Today, and SHALL reject a completion or undo for any other Local_Day.
11. THE Habit_Book SHALL reject a rename, completion or undo for an archived Habit and for an unknown id, and SHALL leave every Habit unchanged.
12. WHEN the user completes and then undoes the same Habit on the same Local_Day, THE Habit_Book SHALL hold Habits equal to those before the completion.
13. THE Habit_Book SHALL keep the Active_Habit count between 0 and Max_Active_Habits at all times.
14. WHILE the Habit_Book holds fewer than Suggested_Min_Habits Active_Habits, THE Hauntagotchi_App SHALL keep working with the habits present and SHALL show a gentle nudge that names how many more habits are suggested.

### Requirement 2: Local days and the injected clock

**User Story:** As a user, I want my days to match my own calendar, so that the ghost never loses a day because of daylight saving time or the hour I open the app.

#### Acceptance Criteria

1. THE Domain SHALL obtain every time value from the Clock and SHALL NOT call `DateTime.now()`, except inside the production Clock implementation.
2. THE Domain SHALL derive a Local_Day from the year, month and day of the Clock's local `DateTime`.
3. THE Domain SHALL compute the next Local_Day and the Day_Count between two Local_Days on year, month and day values, and SHALL NOT add or divide a fixed 24-hour duration.
4. FOR ALL Local_Days that span a daylight saving change (a 23-hour or a 25-hour day), THE Domain SHALL count N consecutive calendar days as a Day_Count of N.
5. FOR ALL pairs of times on the same Local_Day, THE Domain SHALL produce the same Local_Day and, after Catch_Up, the same Health, regardless of the time of day.
6. FOR ALL Local_Days, THE Local_Day encoding SHALL decode to an equal Local_Day (round-trip property).
7. THE Hauntagotchi_App SHALL provide one production Clock that returns the current local time, and SHALL inject a Fake_Clock in every test.

### Requirement 3: Ghost and derived state

**User Story:** As a user, I want to see how my ghost is doing in plain words, so that I know how my habits are going.

#### Acceptance Criteria

1. THE Ghost SHALL hold a Ghost_Name, a Health, a Last_Settled_Day and a Resurrection_Count, and SHALL NOT store the Ghost_State.
2. THE Domain SHALL keep every Health value within 0 to 100 inclusive, whatever the sequence of completions, undos, days and ritual steps.
3. THE Domain SHALL derive the Ghost_State as a pure function of Health and Recent_History.
4. WHEN Health is 0, THE Domain SHALL derive the Ghost_State `dead`.
5. WHEN Health is above 0, THE Domain SHALL derive one of `thriving`, `content`, `hungry` or `fading`, and SHALL NOT derive `dead`.
6. FOR ALL Recent_Histories, THE Domain SHALL derive a Ghost_State for a lower Health that is never healthier than the Ghost_State for a higher Health, in the order `dead`, `fading`, `hungry`, `content`, `thriving`.
7. THE Domain SHALL derive the same Ghost_State from equal Health and equal Recent_History.
8. WHEN the Hauntagotchi_App runs for the first time, THE Domain SHALL create a Ghost with a default Ghost_Name from the design, Health 100, the Resurrection_Count 0, and the Last_Settled_Day set to the day before Today.

### Requirement 4: Catch-up decay

**User Story:** As a user, I want the ghost to react fairly to the days I was away, so that being away for 5 days costs the same as opening the app on each of those days.

#### Acceptance Criteria

1. WHEN the Hauntagotchi_App opens, WHEN the app returns to the foreground, and before each user action, THE Home_Controller SHALL read the Clock and run Catch_Up for Today.
2. WHEN Catch_Up runs, THE Domain SHALL settle each Local_Day after the Last_Settled_Day and before Today exactly once, in calendar order, and SHALL set the Last_Settled_Day to the day before Today.
3. WHEN Catch_Up runs and the Last_Settled_Day is already the day before Today, THE Domain SHALL leave the Ghost unchanged.
4. FOR ALL starting Ghosts and sequences of N missed days, THE Domain SHALL produce the same Ghost from one Catch_Up over N days as from N Catch_Ups of one day each (the 5-day-away outcome equals 5 single days).
5. THE Hauntagotchi_App SHALL use no timer, background task or periodic callback to apply decay.
6. IF Today is before the Last_Settled_Day plus one day because the Clock moved backward, THEN THE Domain SHALL leave the Ghost unchanged and SHALL NOT raise an error.
7. WHEN a Catch_Up spans 10,000 missed days, THE Domain SHALL finish and return a Ghost with Health within 0 to 100.
8. WHILE the Habit_Book holds no Active_Habit on a missed day, THE Domain SHALL leave Health unchanged for that day.
9. WHEN a missed Local_Day is settled, THE Domain SHALL base the settlement on the completions recorded for that Local_Day by the Habits that were active on it, so that archiving or adding a Habit later does not change the Health of earlier days.

### Requirement 5: Feeding and decay balance

**User Story:** As a user, I want the ghost to stay healthy when I do most of my habits most days, and to fade when I stop, so that the pet feels fair and alive.

#### Acceptance Criteria

1. WHEN the user completes a Habit, THE Home_Controller SHALL raise the Live_Health by an amount greater than 0 on that same Local_Day, unless Health is already 100.
2. WHEN the user undoes a completion made Today, THE Home_Controller SHALL return the Live_Health to the value it had before that completion.
3. WHEN a Neglect_Day is settled, THE Domain SHALL lower Health by an amount greater than 0, unless Health is already 0.
4. THE design numbers SHALL make a user who completes at least 60 percent of the Active_Habits on at least 5 of every 7 consecutive days keep a Ghost that never reaches the Ghost_State `fading` or `dead`, starting from Health 100.
5. THE design numbers SHALL make a Ghost that starts a run of Neglect_Days at Health 100 reach Health 0 within 7 consecutive Neglect_Days, and stay alive for at least the first 3 of them.
6. THE design numbers SHALL make one Local_Day on which all Active_Habits are completed raise Health by at least 15 points for a living Ghost whose Health is below 85, so that one good day after a bad week is noticeable.
7. THE design numbers SHALL make the Health gained on a day with all Active_Habits completed greater than the Health lost on a Neglect_Day.
8. THE design document SHALL list every number, state the threshold of each Ghost_State, and show a worked 14-day example that demonstrates criteria 4 to 7.

### Requirement 6: Death and resurrection

**User Story:** As a user, I want a fallen ghost to come back through a kind ritual, so that failing feels sad but never like punishment.

#### Acceptance Criteria

1. WHEN Health reaches 0 during Catch_Up, THE Domain SHALL derive the Ghost_State `dead` and SHALL keep the Resurrection_Count unchanged.
2. WHILE the Ghost_State is `dead`, THE Domain SHALL keep Health at 0 through every Catch_Up, every completion, every undo and every archive that does not fulfil the Resurrection_Ritual.
3. THE design document SHALL define one Resurrection_Ritual that needs only the habit controls (completion and archive), needs at least one Active_Habit, and names Fresh_Start_Health.
4. WHEN the user fulfils the Resurrection_Ritual while the Ghost_State is `dead`, THE Domain SHALL set Health to Fresh_Start_Health, which is above 0, and SHALL increase the Resurrection_Count by 1.
5. WHEN the Ghost has been resurrected, THE Domain SHALL keep the Ghost_Name and the Habits and SHALL set the Last_Settled_Day to the day before Today.
6. WHEN the user undoes a completion after the Resurrection_Ritual so that the ritual condition no longer holds, THE Domain SHALL keep the Ghost alive and SHALL keep the Resurrection_Count.
7. IF the Ghost is dead and no Active_Habit exists, THEN THE Home_Screen SHALL tell the user to add a habit to begin the Resurrection_Ritual.
8. THE Domain SHALL increase the Resurrection_Count by exactly 1 for each completed Resurrection_Ritual, and SHALL never decrease the Resurrection_Count.

### Requirement 7: Streak

**User Story:** As a user, I want to see how many days in a row I did something, so that I feel the momentum.

#### Acceptance Criteria

1. THE Domain SHALL compute the Streak from the completion record of all Habits, including archived Habits, and SHALL NOT store the Streak.
2. WHEN at least one Habit is completed Today, THE Domain SHALL count Today in the Streak.
3. WHILE no Habit is completed Today and at least one Habit was completed yesterday, THE Domain SHALL keep the Streak that ends yesterday.
4. WHILE no Habit is completed Today and none was completed yesterday, THE Domain SHALL return a Streak of 0.
5. FOR ALL completion records, THE Streak SHALL equal the length of the longest run of consecutive Local_Days with at least one completion that ends Today or yesterday.
6. WHEN a completion is undone and no other Habit is completed on that Local_Day, THE Domain SHALL remove that Local_Day from the Streak.

### Requirement 8: Saving and loading

**User Story:** As a user, I want my habits and ghost to be there when I return, so that the pet lives across visits.

#### Acceptance Criteria

1. THE Data_Layer SHALL open the Habit_Repository and the Ghost_Repository through `StorageOpener.open` with `currentVersion` 1, `hiveFlutterInitializer` in production, and one box name per repository.
2. THE Habit_Codec and THE Ghost_Codec SHALL implement `RecordCodec` and SHALL encode only JSON-safe values, with Local_Days encoded as strings.
3. FOR ALL valid Habits, decoding the encoded Habit SHALL produce an equal Habit (round-trip property).
4. FOR ALL valid Ghosts, decoding the encoded Ghost SHALL produce an equal Ghost (round-trip property).
5. IF stored data holds a Habit_Name or Ghost_Name outside 1 to 40 characters, a Health outside 0 to 100, a malformed Local_Day, a negative Resurrection_Count, or a missing field, THEN THE codec SHALL throw on decode, so that `RecordRepository` skips the entry as corrupt.
6. WHEN the Hauntagotchi_App opens and the Ghost_Repository returns no Ghost, THE Data_Layer SHALL let the Domain create a new Ghost as in Requirement 3.8 and keep the readable Habits.
7. WHEN the Habit_Book or the Ghost changes, THE Data_Layer SHALL write the changed records before the Home_Controller reports the change as saved.
8. IF a write to a repository throws, THEN THE Home_Controller SHALL keep the in-memory state, keep the app usable, and show a gentle message with a retry action.
9. THE Data_Layer SHALL hold no secret and no personal data beyond the Habit_Names and Ghost_Name that the user typed.

### Requirement 9: Memory fallback

**User Story:** As a user in a private window, I want the app to still work and to tell me kindly that nothing will be saved, so that I am not surprised later.

#### Acceptance Criteria

1. IF `StorageOpener` returns a repository whose `isPersistent` is false, THEN THE Home_Controller SHALL run with in-memory repositories and every feature of this document SHALL keep working.
2. WHILE the Memory_Fallback is active, THE Home_Screen SHALL show the Memory_Notice, which says in short, gentle wording that progress will not be saved.
3. WHILE storage is persistent, THE Home_Screen SHALL NOT show the Memory_Notice.
4. THE Memory_Notice SHALL NOT blame the user and SHALL NOT show an exception message.

### Requirement 10: Home screen content

**User Story:** As a user, I want one screen that shows my ghost and my habits, so that I can check in at a glance.

#### Acceptance Criteria

1. THE Home_Screen SHALL replace `PlaceholderScreen` at route `/` and SHALL show the Ghost with `GhostLoader`, the Ghost_Name, the Live_Health as a number from 0 to 100, the Ghost_State in words, and the Streak.
2. THE Home_Screen SHALL list every Active_Habit with its Habit_Name and one check-off control that shows whether the Habit is completed Today.
3. WHEN the user activates the check-off control of an uncompleted Habit, THE Home_Screen SHALL complete the Habit and update the Live_Health, the Ghost_State and the Streak.
4. WHEN the user activates the check-off control of a Habit completed Today, THE Home_Screen SHALL undo the completion and update the Live_Health, the Ghost_State and the Streak.
5. THE Home_Screen SHALL offer controls to add, rename and archive a Habit.
6. WHEN the user submits an invalid Habit_Name or tries to add beyond Max_Active_Habits, THE Home_Screen SHALL show the reason in short, kind wording and keep the entered text.
7. WHEN the user chooses to archive a Habit, THE Home_Screen SHALL ask for confirmation, and SHALL archive only after the user confirms.
8. WHILE the Habit_Book holds Max_Active_Habits Active_Habits, THE Home_Screen SHALL show the add control as unavailable with a reason that the user can read.
9. WHILE the Home_Controller loads the saved data, THE Home_Screen SHALL show a `GhostLoader` with a caption.
10. THE Home_Screen SHALL read all time through the Clock of the Home_Controller.
11. THE Hauntagotchi_App SHALL keep the route `/gallery`, which shows `CryptGallery` and returns to `/` through its back control.

### Requirement 11: Empty and dead states

**User Story:** As a user, I want clear guidance when I have no habits or when the ghost has died, so that I never meet a dead end.

#### Acceptance Criteria

1. WHILE no Habit exists, THE Home_Screen SHALL show an empty state with a short spooky invitation and a control that opens the add-habit dialog.
2. WHILE the Habit_Book holds no Active_Habit but holds archived Habits, THE Home_Screen SHALL show the same empty state.
3. WHILE the Ghost_State is `dead`, THE Home_Screen SHALL show a sad but gentle state that names the Ghost, explains the Resurrection_Ritual in one short paragraph, shows the progress toward the ritual, and shows the Resurrection_Count.
4. WHILE the Ghost_State is `dead`, THE Home_Screen SHALL keep the habit list and the check-off controls available, because they are the way to the Resurrection_Ritual.
5. WHEN the user fulfils the Resurrection_Ritual, THE Home_Screen SHALL show a short message that welcomes the Ghost back.
6. THE Home_Screen SHALL NOT use gore, blame, shaming or the words "failed" or "your fault" in any state.
7. IF the data cannot be loaded as a Ghost and Habits, THEN THE Home_Screen SHALL show a gentle error state with a retry control and SHALL NOT show a blank screen.

### Requirement 12: Accessibility and layout

**User Story:** As a user on any device, I want the screen to be readable, reachable and calm, so that the app is comfortable to use.

#### Acceptance Criteria

1. THE Home_Screen SHALL give every interactive element a tap target of at least 48 by 48 logical pixels, a hover state and a press state.
2. THE Home_Screen SHALL give every interactive element a semantic label, and SHALL give each check-off control a label that names the Habit and says whether it is done Today.
3. THE Home_Screen SHALL give the ghost area one semantic label that states the Ghost_Name, the Health and the Ghost_State in words.
4. WHEN `MediaQuery.disableAnimations` is true, THE Home_Screen SHALL add no moving effect, and the `GhostLoader` SHALL draw its still frame.
5. THE Home_Screen SHALL render without overflow at a width of 360 logical pixels and at a text scale of 1.5.
6. THE Home_Screen SHALL use only theme tokens from `CoffinTheme` for color, and SHALL NOT convey the Ghost_State by color alone.
7. THE Home_Screen SHALL write all copy short and slightly spooky, and never mean to the user.

### Requirement 13: Architecture and boundaries

**User Story:** As a maintainer, I want the rules separate from the screen and the app separate from the skeleton, so that the code stays easy to read and test.

#### Acceptance Criteria

1. THE Hauntagotchi_App SHALL import only `package:coffin_core/coffin_core.dart` from `coffin_core`, and SHALL NOT import any file under `coffin_core/lib/src`.
2. THE Domain SHALL import no `package:flutter` library and no `dart:io`, and a test SHALL fail WHEN a file under `lib/src/domain` does.
3. THE Hauntagotchi_App SHALL NOT import from Graveyard, and `coffin_core` and Graveyard SHALL stay unchanged by this feature.
4. THE Hauntagotchi_App SHALL keep files in `snake_case.dart`, one public class per file, with the layout `domain`, `data`, `ui` under `lib/src`.
5. THE Hauntagotchi_App SHALL pass `dart format` and `flutter analyze` with zero warnings.
6. THE Hauntagotchi_App SHALL remove `PlaceholderScreen` and its test, and SHALL update `app_routes.dart` and its test to the Home_Screen.
7. THE Hauntagotchi_App SHALL add no asset, and `CREDITS.md` SHALL stay unchanged.
8. THE Hauntagotchi_App SHALL add exactly one line, `glados: 1.1.7`, to `dev_dependencies` in `apps/hauntagotchi/pubspec.yaml`, SHALL add no other dependency, and SHALL leave the root `pubspec.lock` unchanged (an empty `git diff` of `pubspec.lock`).

### Requirement 14: Tests

**User Story:** As a maintainer, I want the rules covered by property and unit tests, so that a change to the numbers cannot silently break the pet.

#### Acceptance Criteria

1. THE test suite SHALL mirror the `lib/` folder structure under `apps/hauntagotchi/test/`, with two extra folders: `test/support/` for test doubles and `test/source_rules/` for every test that reads source files with `dart:io`. No file under `test/domain` or `test/data` SHALL import `dart:io`, so `flutter test --platform chrome test/domain test/data` runs.
2. THE decay property tests SHALL assert, with glados, that Health stays within 0 to 100 for every generated sequence of settled days, completions, undos, archives and ritual steps.
3. THE decay property tests SHALL assert that one Catch_Up over N missed days equals N Catch_Ups of one day each, for generated starting Ghosts, Habit_Books and N from 0 to 60.
4. THE decay property tests SHALL assert that the Ghost after Catch_Up is the same for every time of day on Today.
5. THE decay property tests SHALL assert that a run of consecutive Local_Days across a daylight saving change, using the dates of a spring-forward and a fall-back change, counts one day for each calendar day and settles each day once.
6. THE decay property tests SHALL assert that a dead Ghost gains no Health through Catch_Up, completions, undos or archives until the Resurrection_Ritual is fulfilled.
7. THE property tests SHALL cover the balance outcomes of Requirement 5.4 to 5.7, the monotonic Ghost_State order of Requirement 3.6, the Streak of Requirement 7.5, and the codec round-trips of Requirement 8.3 and 8.4.
8. THE property tests SHALL use Web_Safe_Generators placed under `apps/hauntagotchi/test/domain/support/`, SHALL NOT use `any.intInRange` or `any.listWithLengthInRange`, and SHALL keep every generated integer below 2^53.
9. THE unit tests SHALL cover each acceptance criterion of Requirement 1, the Local_Day rules of Requirement 2, the codec failures of Requirement 8.5, and the controller behavior for a failed write.
10. THE widget tests SHALL cover the Home_Screen states: empty, normal, dead and the Memory_Notice, using a Fake_Clock and `MemoryRecordRepository`, and SHALL NOT use real Hive storage.
11. THE widget tests SHALL cover the check-off and undo flow, the add limit, the archive confirmation, the 360 pixel layout at a text scale of 1.5, and the reduced-motion state.
12. THE route tests SHALL assert that `/` shows the Home_Screen and that `/gallery` still shows `CryptGallery` and returns to `/`.
13. THE Hauntagotchi_App SHALL pass `flutter test` before the feature counts as done.

### Requirement 15: Steering line correction

**User Story:** As a maintainer, I want the steering to match the state management that apps really use, so that Kiro and new apps are not told to use a package they do not depend on.

#### Acceptance Criteria

1. THE first change of this feature SHALL replace the line `- State management: **Riverpod** (`flutter_riverpod`). No other state libraries.` in `.kiro/steering/tech.md` and in `tool/templates/app/.kiro/steering/tech.md.tmpl` with the line `- State management: Flutter's built-in ChangeNotifier with ListenableBuilder. No state-management packages.`
2. THE feature SHALL change no other line in those two files and no other file outside `apps/hauntagotchi`, apart from the one line of Requirement 13.8.
3. WHEN the two lines are changed, THE `tool` test suite (`flutter test` in `tool/`) SHALL keep passing, including the template integrity tests, the raiser tests and the repo-guard tests.
4. WHEN the two lines are changed, THE raise-check (`flutter test --tags raise-check --run-skipped` in `tool/`) SHALL keep passing.
