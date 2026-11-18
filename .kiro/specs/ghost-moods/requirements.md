# Requirements Document

## Introduction

Today `GhostLoader` draws the same ghost in every state, so the state of Wisp shows only through words and an icon. The ghost-moods feature makes the ghost look how it feels.

`coffin_core` gains a public `GhostMood` enum and mood support in `GhostPainter` and `GhostLoader`, so that every Coffin app can use it (Graveyard will reuse it later for its resurrect moment). A mood changes the shape and the motion of the ghost, not only its color: eyes and mouth, opacity, bob speed and height, and posture. Two moods are one-shot reactions: `fed` (a short happy pop) and `rising` (the resurrection moment).

Hauntagotchi maps each `GhostState` to a mood, animates between moods, plays `fed` after every successful check-off (also at Health 100), plays `rising` once when a ritual completes, and no longer shows the ghost against the top edge of the home screen. The `CryptGallery` shows every mood side by side.

All mood math (opacity, bob parameters, blend curves, reaction curves) lives in pure Dart classes in `packages/coffin_core/lib/src/widgets/math/` with no Flutter imports, verified with glados property tests that use only Web_Safe generators, under the same rules as the spooky-widgets spec.

## Dependency and Asset Notice

This feature adds NO new package, NO image asset, NO animation asset, NO sound asset and NO `pubspec.yaml` change. `pubspec.lock` SHALL stay unchanged. It uses plain Flutter only: `CustomPainter`, implicit animations and explicit animations. `CREDITS.md` and `DIARY.md` are not edited.

## Non-Goals

- No Graveyard change. Graveyard keeps passing unchanged. Using moods in Graveyard is a later feature.
- No change to the raise template (`tool/`). It keeps passing unchanged.
- No new `GhostState` values, no change to health, decay or ritual rules.
- No sound, no haptics, no particles or confetti, no image or animation assets.
- No golden image tests.
- No user-facing motion toggle. Reduced motion follows `MediaQuery.disableAnimations` only.
- No new semantics text: the labels of `GhostLoader` and `GhostPanel` stay as they are.
- No change to `DIARY.md`, `CREDITS.md`, `pubspec.yaml` files or `pubspec.lock`.

## Glossary

- **Ghost_Mood**: The public enum `GhostMood` in `coffin_core` with seven values: `thriving`, `content`, `hungry`, `fading`, `dead`, `fed` and `rising`.
- **Steady_Mood**: One of `thriving`, `content`, `hungry`, `fading`, `dead`. A Steady_Mood has no end and is held until the caller changes it.
- **Reaction_Mood**: One of `fed`, `rising`. A Reaction_Mood plays once, from progress 0 to 1, and then holds its final pose until the caller changes the mood.
- **Reaction_Key**: The optional `int` parameter `reactionKey` of Ghost_Loader, default 0. The caller increments it once per event to start a new reaction of the same Reaction_Mood. A Reaction_Key has no effect while the mood is a Steady_Mood.
- **Reaction_Run**: One play of a Reaction_Mood from progress 0 to 1. A Reaction_Run starts when the mood changes to a Reaction_Mood, when the Ghost_Loader is first built with a Reaction_Mood, or when the Reaction_Key changes while the mood stays the same Reaction_Mood.
- **Legacy_Look**: The ghost that `GhostPainter` and `GhostLoader` draw today when no mood is given: same shape, same two round eyes, same bob defaults (3600 ms, 6 logical pixels), same layout size.
- **Ghost_Painter**: The public `GhostPainter` class.
- **Ghost_Loader**: The public `GhostLoader` widget.
- **Crypt_Gallery**: The public `CryptGallery` page.
- **Mood_Traits**: The pure Dart value that describes one mood: eye style, mouth style, posture (lean and droop), opacity, and bob profile. It is a fixed table, one entry per Ghost_Mood.
- **Eye_Style**: The shape of the eyes: for example round, wide, droopy, half-closed, cross (X) and happy arc (^).
- **Mouth_Style**: The shape of the mouth: for example none, smile, small open, flat and wobble.
- **Mood_Bob**: The pure Dart class that maps a mood and elapsed time to a vertical bob offset, built on `GhostBob` for the moods that bob. For `dead` it returns offset 0 without calling `GhostBob`.
- **Mood_Blend**: The pure Dart class that maps two moods and a transition progress to blended numeric values (opacity, bob amplitude, posture) through an eased curve. It blends no bob period.
- **Mood_Reaction**: The pure Dart class that maps a Reaction_Mood and elapsed time to a progress and to the pose values of the reaction (scale, lift, opacity).
- **Mood_Transition**: The animated change from one mood to another, 500 ms with an ease-in-out curve.
- **Still_Frame**: The single non-animated rendering of a mood under Reduced_Motion. For a Reaction_Mood it is the final held pose.
- **Motionless_Pose**: The pose shown when nothing on the ghost moves: the mood is `dead` (no bob), no Mood_Transition and no Reaction_Run is running, and Reduced_Motion is off; or any Still_Frame under Reduced_Motion.
- **Reduced_Motion**: The state where `MediaQuery.disableAnimations` is true.
- **Ghost_State**: The existing Hauntagotchi enum `GhostState` (`dead`, `fading`, `hungry`, `content`, `thriving`).
- **Mood_Map**: The Hauntagotchi function that maps a Ghost_State to a Steady_Mood.
- **Home_Controller**: The existing Hauntagotchi `HomeController`.
- **Home_Screen**: The existing Hauntagotchi `HomeScreen`.
- **Ghost_Panel**: The existing Hauntagotchi `GhostPanel`.
- **Check_Off**: A call to `HomeController.toggle` that completes a habit for today (not an undo).
- **Ritual**: The existing resurrection ritual of a dead ghost.
- **Ritual_Completion**: A `HauntChanged` result whose `resurrected` flag is true.
- **Web_Safe**: Behavior that gives identical results on the Dart VM and on Flutter Web, using integer arithmetic and `+ - * /` and comparisons only (as defined in the spooky-widgets spec, Requirement 10).
- **Phone_Width**: A viewport width of 360 logical pixels (320 is the smallest tested width). **Desktop_Width**: 1280.
- **Barrel**: The file `packages/coffin_core/lib/coffin_core.dart`.
- **Checkpoint**: A task after which `dart format` (no changes), `flutter analyze` (zero warnings) and `flutter test` pass.

## Requirements

### Requirement 1: The GhostMood enum

**User Story:** As a Flutter developer using Coffin, I want a public set of ghost moods, so that any app can make its ghost look how it feels.

#### Acceptance Criteria

1. THE Ghost_Mood SHALL be a public enum in its own file under `packages/coffin_core/lib/src/widgets/` with exactly the values `thriving`, `content`, `hungry`, `fading`, `dead`, `fed` and `rising`.
2. THE Barrel SHALL export `GhostMood` with a `show` clause, in the sorted order of the existing exports.
3. THE Ghost_Mood SHALL carry a doc comment on the enum and on every value, and SHALL state which values are Steady_Moods and which are Reaction_Moods.
4. THE Ghost_Mood SHALL import nothing from Flutter, so that Hauntagotchi domain-adjacent code and tests can use it without a widget tree.
5. THE Barrel SHALL NOT export the pure mood math classes (Mood_Traits, Mood_Bob, Mood_Blend, Mood_Reaction), and apps SHALL use moods only through `GhostMood`, `GhostPainter` and `GhostLoader`.

### Requirement 2: Optional mood on GhostPainter and GhostLoader

**User Story:** As a maintainer, I want the mood to be optional, so that existing callers, tests and the raise template keep working unchanged.

#### Acceptance Criteria

1. THE Ghost_Painter SHALL accept an optional mood parameter that defaults to null, and THE Ghost_Loader SHALL accept an optional `mood` parameter that defaults to null.
2. WHEN no mood is given, THE Ghost_Painter SHALL draw the Legacy_Look and THE Ghost_Loader SHALL show the Legacy_Look, with the same layout size and the same bob as before this feature.
3. WHEN a painter is built with a null mood and the mood-related parameters at their defaults, THE Ghost_Painter SHALL produce the same rendered pixels as a painter built without those parameters, checked by rendering both to an image and comparing the bytes.
4. THE existing tests of `GhostPainter`, `GhostLoader`, `CryptGallery`, the spooky-widgets barrel test, the Graveyard app and the raise template SHALL pass unchanged, apart from the gallery test adjustments of Requirement 15.9.
5. THE Ghost_Painter SHALL keep taking plain values only (colors, offsets, mood values) and SHALL read no `Theme`, no `BuildContext` and no controller.
6. THE Ghost_Painter SHALL include every new input in `shouldRepaint`, so that it returns true when any mood input changes and false when all inputs are equal.
7. THE Ghost_Painter and THE Ghost_Loader SHALL document every new public parameter in a doc comment.
8. THE Ghost_Loader SHALL accept an optional `onReactionEnd` callback, called once when a Reaction_Mood has finished playing (Requirement 9.5).
9. THE Ghost_Loader SHALL accept an optional `reactionKey` parameter of type `int` that defaults to 0, and SHALL document in its doc comment that the caller increments the Reaction_Key once per event to start a new Reaction_Run of the same Reaction_Mood (Requirement 9.2 and 9.10).
10. THE Ghost_Painter SHALL NOT take the Reaction_Key, because the Reaction_Key is not a drawing input; THE Ghost_Loader SHALL repaint through its reaction controller when a new Reaction_Run starts, and its `didUpdateWidget` SHALL treat a changed Reaction_Key as an input change.
11. WHEN no `reactionKey` is given, THE Ghost_Loader SHALL behave as with Reaction_Key 0, so that existing callers, the gallery and the raise template keep working unchanged.

### Requirement 3: Moods differ in shape and motion, not color alone

**User Story:** As a user who cannot tell colors apart, I want each mood to look different in shape and movement, so that I can read how the ghost feels without relying on color.

#### Acceptance Criteria

1. THE Mood_Traits SHALL define, for each Ghost_Mood, an Eye_Style, a Mouth_Style, a posture (lean angle and droop of the body), an opacity and a bob profile.
2. FOR every pair of different Ghost_Mood values, THE Mood_Traits SHALL differ in at least one of Eye_Style, Mouth_Style or posture, so that no two moods differ by opacity or bob alone.
3. THE Ghost_Painter SHALL draw `thriving` with wide round eyes and a smile, `content` with round eyes and a small gentle smile, `hungry` with droopy eyes and a small open mouth, `fading` with half-closed eyes, a flat mouth and a drooping body, and `dead` with cross-shaped (X) eyes and a slumped, tilted body.
4. THE Ghost_Painter SHALL draw `fed` with happy-arc (^) eyes and a wide smile, and `rising` with wide eyes, a small open mouth and a stretched body.
5. THE Ghost_Painter SHALL use only the `eyeColor` and `bodyColor` it receives for eyes and mouth, so that expression is drawn in shape and the colors come from the Token_Set (Requirement 14.1).
6. THE Ghost_Painter SHALL draw each mood within the same drawing box, so that no mood moves paint outside the box given to `paint` (Requirement 6.4).
7. THE feature SHALL include a unit test that renders every mood with the Ghost_Painter to an image and asserts that no two moods give the same pixels, in both Token_Sets.
8. THE feature SHALL include a test that renders every pair of moods with identical opacity and identical bob and asserts that the pixels still differ, so that distinction by shape is proven.

### Requirement 4: Mood opacity

**User Story:** As a user, I want a healthy ghost to look solid and a failing ghost to look faint, so that I see health at a glance.

#### Acceptance Criteria

1. THE Mood_Traits SHALL give each Steady_Mood an opacity, with the values `thriving` 1.00, `content` 0.92, `hungry` 0.85, `fading` 0.78 and `dead` 0.72.
2. THE Mood_Traits SHALL give the opacities in strictly decreasing order from `thriving` to `dead`, and every opacity of every mood SHALL lie in the closed range 0.72 to 1.00.
3. THE Ghost_Painter SHALL apply the opacity to the body and the glow, and SHALL keep the eyes and mouth drawn at full strength, so that the expression stays readable on a faint ghost.
4. FOR every mood and both Token_Sets, THE body color of the ghost blended at the mood's opacity over the `background` token SHALL keep a contrast ratio of at least 3.0, measured with `WcagContrast`, and the eyes SHALL keep at least 3.0 against the blended body. THE opacity values of criterion 1 were chosen to meet this rule in both Token_Sets (smallest daylight ratio about 3.39 for `dead`).
5. THE `fed` mood SHALL use opacity 1.00 and THE `rising` mood SHALL start at the opacity of `dead` and end at the opacity of `thriving` (Requirement 8.4).

### Requirement 5: Mood bob

**User Story:** As a user, I want a lively ghost to bob quickly and a weak ghost to bob slowly and barely, so that I feel its energy in the motion.

#### Acceptance Criteria

1. THE Mood_Traits SHALL give each Steady_Mood a bob profile (period in milliseconds, amplitude in logical pixels), with the starting values `thriving` 3000 ms and 8 px, `content` 3600 ms and 6 px, `hungry` 4400 ms and 4 px, `fading` 5000 ms and 2 px, and `dead` no bob (offset 0 and amplitude 0).
2. THE Mood_Traits SHALL give the bob periods in strictly increasing order and the bob amplitudes in strictly decreasing order from `thriving` to `fading`, so that a healthier ghost bobs faster and higher.
3. THE Mood_Bob SHALL return, for `dead`, the offset 0 for every Elapsed_Time, without calling `GhostBob`.
4. FOR every Steady_Mood except `dead`, THE Mood_Bob SHALL return the offset of a `GhostBob` built with the mood's period and amplitude, and SHALL keep the offset within the closed range from minus the amplitude to plus the amplitude, finite, for every Elapsed_Time including negative values.
5. THE Mood_Bob SHALL return the same offset for `elapsedMs` and `elapsedMs + period` for every bobbing mood, so that the loop has no jump.
6. THE Mood_Bob SHALL keep the bob profile of every bobbing mood (every mood except `dead`) inside the clamp range of `GhostBob` (period 2500 to 5000 ms, amplitude 2 to 10 px), so that `GhostBob` is reused without change; this criterion does not apply to `dead`, which has no bob.
7. THE Mood_Bob SHALL be a plain Dart class with no Flutter imports, and SHALL compute the offset only with addition, subtraction, multiplication, division, comparison and absolute value.

### Requirement 6: Fixed layout and stay-inside-bounds

**User Story:** As a developer, I want the ghost to occupy the same space in every mood, so that a mood change never reflows the page or clips the ghost.

#### Acceptance Criteria

1. WHERE a mood is given, THE Ghost_Loader SHALL reserve one fixed width and one fixed height for the ghost that depend only on `size`, and SHALL NOT change them when the mood changes.
2. WHERE a mood is given, THE Ghost_Loader SHALL reserve enough vertical room above and below the ghost for the largest bob, the lift of `rising` and the lift of `fed`, and enough horizontal room for the scale pop of `fed`.
3. THE Ghost_Loader SHALL clamp `size` into 24 to 256 (NaN becomes 64) as before, for every mood.
4. FOR every mood, every progress value and every Elapsed_Time, THE painted ghost, including its pop, lift and bob, SHALL stay inside the box that the Ghost_Loader reserves for it.
5. WHEN a mood changes, THE Ghost_Loader SHALL keep the caption in the same position, and SHALL NOT move or resize the caption.

### Requirement 7: Mood transitions

**User Story:** As a user, I want the ghost to change mood smoothly, so that a change of state feels like a feeling and not a flicker.

#### Acceptance Criteria

1. WHEN the `mood` of a Ghost_Loader changes and Reduced_Motion is off, THE Ghost_Loader SHALL animate the Mood_Transition from the old mood to the new mood over 500 ms with an ease-in-out curve.
2. THE Mood_Blend SHALL blend opacity, bob amplitude and posture (lean and droop) between two moods with an eased progress, and SHALL NOT blend a bob period, and SHALL return the exact values of the first mood at progress 0 and of the second mood at progress 1.
3. THE Mood_Blend SHALL return, for every progress value, each blended number between the two endpoint numbers (inclusive), finite, and SHALL clamp a progress below 0 to 0, a progress above 1 to 1 and NaN to 1.
4. THE Mood_Blend easing curve SHALL be monotonic non-decreasing, SHALL map 0 to 0 and 1 to 1, and SHALL change by at most 1.5 times the average speed per frame of 16 ms over the transition (the peak speed of a smoothstep).
5. THE Ghost_Painter SHALL cross-fade the discrete features (Eye_Style and Mouth_Style) during a Mood_Transition by drawing the old and the new feature with complementary opacity, so that no frame shows a missing or doubled face at full strength.
6. WHEN the mood changes again during a Mood_Transition, THE Ghost_Loader SHALL start the new transition from the currently shown blend, so that there is no jump.
7. WHEN the mood changes to the same mood that is already shown, THE Ghost_Loader SHALL start no transition.
8. WHEN a transition has finished, THE Ghost_Loader SHALL leave no active ticker for the transition, so that only the ticker that the resulting pose needs runs: the bob loop for a bobbing mood, and no ticker for a Motionless_Pose (Requirement 24).
9. WHILE Reduced_Motion is on, WHEN the mood changes, THE Ghost_Loader SHALL show the Still_Frame of the new mood at once, with no transition and no active ticker.

### Requirement 8: Reaction moods (fed and rising)

**User Story:** As a user, I want a short happy reaction when I tick a habit and a special moment when my ghost comes back, so that these actions feel rewarding.

#### Acceptance Criteria

1. WHEN the `mood` of a Ghost_Loader changes to `fed` and Reduced_Motion is off, THE Ghost_Loader SHALL play the `fed` reaction once over 900 ms: a quick scale pop up to at most 1.10 of the ghost size, a lift of at most 6 px, and a return to the resting pose.
2. WHEN the `mood` of a Ghost_Loader changes to `rising` and Reduced_Motion is off, THE Ghost_Loader SHALL play the `rising` reaction once over 2200 ms: the ghost lifts upward by at most 10 px, stretches, and the opacity grows from the opacity of `dead` to the opacity of `thriving`.
3. THE Mood_Reaction SHALL map elapsed time to a progress from 0 to 1 over the reaction duration, clamping times below 0 to progress 0 and times at or above the duration to progress 1.
4. THE Mood_Reaction SHALL give the `fed` pop scale 1.0, the lift 0 and the opacity 1.0 at progress 0 and at progress 1, so that the reaction starts and ends without a jump, and SHALL give the `rising` opacity the value of `dead` at progress 0 and the value of `thriving` at progress 1.
5. THE Mood_Reaction SHALL keep the `fed` scale between 1.0 and 1.10, the `fed` lift between 0 and 6 px, the `rising` lift between 0 and 10 px and the `rising` opacity between the opacity of `dead` and of `thriving`, for every progress value, finite, and SHALL treat NaN as progress 1.
6. THE Mood_Reaction SHALL be a plain Dart class with no Flutter imports, SHALL compute every value with `+ - * /` and comparisons only, and SHALL derive progress from integer milliseconds.
7. WHEN a Reaction_Mood has played to progress 1, THE Ghost_Loader SHALL hold the final pose with the face of that mood (the `fed` face or the `rising` face) until the caller changes the mood, and SHALL keep running the bob of the final pose (`fed` and `rising` both bob with the `thriving` profile).
8. THE `rising` final pose SHALL use the bob profile of `thriving`, and THE `fed` final pose SHALL use the bob profile of `thriving`.
9. THE reactions SHALL stay slow and floaty as the design steering document requires: no reaction curve (scale, lift and opacity of `fed` and `rising`) SHALL move faster than 1.5 times its average speed per 16 ms frame, and no reaction SHALL flash or strobe. This bound applies to the reaction curves themselves, not to the restart blend of Requirement 9.11.

### Requirement 9: Reaction lifecycle

**User Story:** As a maintainer, I want one-shot reactions to start once, end once and clean up, so that they never repeat by accident or leak tickers.

#### Acceptance Criteria

1. WHEN the `mood` changes to a Reaction_Mood, THE Ghost_Loader SHALL start the reaction from progress 0.
2. WHEN the same Reaction_Mood is given again with the same Reaction_Key and without an intermediate different mood (for example in a rebuild), THE Ghost_Loader SHALL NOT restart the reaction.
3. WHEN a Ghost_Loader is first built with a Reaction_Mood and Reduced_Motion is off, THE Ghost_Loader SHALL play the reaction once from progress 0.
4. WHEN the mood changes away from a Reaction_Mood before it has finished, THE Ghost_Loader SHALL stop the reaction and start the Mood_Transition to the new mood from the currently shown pose, and SHALL NOT call `onReactionEnd`.
5. WHEN a Reaction_Mood reaches progress 1, THE Ghost_Loader SHALL call `onReactionEnd` exactly once for that reaction.
6. WHILE Reduced_Motion is on, WHEN the mood is a Reaction_Mood, THE Ghost_Loader SHALL show the Still_Frame of that mood, SHALL start no ticker, and SHALL call `onReactionEnd` exactly once after the first frame that shows the Still_Frame.
7. WHEN a Ghost_Loader is removed from the tree, THE Ghost_Loader SHALL dispose every `AnimationController` it created, SHALL call no callback afterwards, and SHALL leave no active ticker.
8. THE Ghost_Loader SHALL NOT create a `Timer` or a `Future.delayed`, SHALL NOT call `setState` on every animation frame, and SHALL wrap the animated painting in a `RepaintBoundary`.
9. WHEN `Reduced_Motion` changes while a Ghost_Loader is mounted, THE Ghost_Loader SHALL stop or start its animations without being rebuilt by its parent, and SHALL NOT throw.
10. WHEN the Reaction_Key changes while the mood stays the same Reaction_Mood and Reduced_Motion is off, THE Ghost_Loader SHALL end the running Reaction_Run, if any, and start a new Reaction_Run from progress 0.
11. WHEN a new Reaction_Run starts because the Reaction_Key changed during a running Reaction_Run, THE Ghost_Loader SHALL show in the first frame of the new run the same pose (scale, lift, opacity) as in the last frame of the interrupted run, and SHALL blend from that pose to the pose curve of the new run over 200 ms with an ease-in-out curve, so that no frame of the restart blend moves by more than 1.5 times the average speed of that 200 ms blend per 16 ms frame. The speed of the restart blend is bounded by the blend, not by Requirement 8.9.
12. WHEN the Reaction_Key changes while the mood stays the same Reaction_Mood, THE Ghost_Loader SHALL call `onReactionEnd` exactly once for the new Reaction_Run when it reaches progress 1, and SHALL NOT call `onReactionEnd` for the interrupted Reaction_Run.
13. WHEN the Reaction_Key changes while the mood is a Steady_Mood, THE Ghost_Loader SHALL start no reaction and no transition.
14. WHILE Reduced_Motion is on, WHEN the Reaction_Key changes while the mood stays the same Reaction_Mood, THE Ghost_Loader SHALL keep showing the Still_Frame, SHALL start no ticker, and SHALL call `onReactionEnd` exactly once after the next frame, as in criterion 6.
15. WHEN the mood changes to a Reaction_Mood, THE Ghost_Loader SHALL start a Reaction_Run whatever the Reaction_Key is, so that the Reaction_Key matters only while the mood stays the same Reaction_Mood.

### Requirement 10: Reduced motion

**User Story:** As a user who is sensitive to motion, I want no movement at all but still want to see how the ghost feels, so that the state stays readable.

#### Acceptance Criteria

1. THE Ghost_Loader SHALL read `MediaQuery.disableAnimations` through `MediaQuery.maybeDisableAnimationsOf`, treating null as false.
2. WHILE Reduced_Motion is on, THE Ghost_Loader SHALL draw the Still_Frame of the mood: bob offset 0, scale 1.0, lift 0, no transition and no active ticker, checked with `tester.binding.transientCallbackCount` equal to 0.
3. THE Still_Frame of every mood SHALL keep the Eye_Style, Mouth_Style, posture and opacity of that mood, so that the mood stays recognisable without movement.
4. THE Still_Frame of the `rising` mood SHALL show the final pose of the reaction: the `rising` face, the stretched body and the opacity of `thriving`.
5. THE Still_Frame of the `fed` mood SHALL show the `fed` face (happy arcs and wide smile) at scale 1.0 and lift 0.
6. FOR every pair of different moods, THE Still_Frames SHALL render different pixels (Requirement 3.7), so that no mood depends on motion to be recognised.

### Requirement 11: Semantics unchanged

**User Story:** As a screen-reader user, I want the same announcements as before, so that adding moods does not add noise or change labels.

#### Acceptance Criteria

1. THE Ghost_Loader SHALL expose the same single semantics node as before for every mood: the label is the caption, or "Loading" when no caption is given, and the node is a live region.
2. THE Ghost_Loader SHALL exclude the painted ghost from the semantics tree for every mood, and SHALL NOT put the mood name in any label.
3. THE Ghost_Loader SHALL NOT change its semantics when the mood changes or when a reaction plays or ends.
4. THE Ghost_Panel SHALL keep its single semantics node and its label format `<name>, health <n> of 100, <state word>`, unchanged.
5. THE feature SHALL include semantics tests for criteria 1 to 4 over all seven moods.

### Requirement 12: Pure mood math and web safety

**User Story:** As a maintainer, I want the mood math in pure Dart, so that it can be property-tested without Flutter and gives identical results on the VM and on the web.

#### Acceptance Criteria

1. THE Mood_Traits, Mood_Bob, Mood_Blend and Mood_Reaction SHALL live in `packages/coffin_core/lib/src/widgets/math/`, one public class per file, with doc comments on every public API.
2. THE pure mood classes SHALL import no `package:flutter`, no `dart:ui`, no `dart:math`, no `dart:io`, no `Random`, and SHALL NOT read the clock, `DateTime` or any global state.
3. THE pure mood classes SHALL use no `sin`, `cos`, `pow`, `exp` or other transcendental function.
4. THE pure mood classes SHALL compute every double from integers or from exact doubles using `+ - * /` and comparisons, with every integer intermediate below 2^53, so that results are identical on the VM and in Chrome.
5. THE pure mood classes SHALL be immutable and SHALL return equal results for equal inputs on every call.
6. THE pure mood classes SHALL handle NaN, infinite and negative inputs without throwing, as stated in Requirements 5, 7 and 8.
7. THE feature SHALL include a fixed-value test that pins the outputs of each pure class for every mood at a few fixed times and progress values (for example progress 0, 0.25, 0.5, 1), and the same file SHALL run unchanged on the VM and in Chrome.
8. THE Mood_Traits table SHALL be the single source of the mood numbers, so that the Ghost_Painter, the Mood_Bob and the Mood_Blend read the same values.

### Requirement 13: Hauntagotchi mood mapping

**User Story:** As a Hauntagotchi player, I want Wisp to look like its state, so that I see at a glance whether it is thriving or fading.

#### Acceptance Criteria

1. THE Mood_Map SHALL map `GhostState.thriving` to `GhostMood.thriving`, `content` to `content`, `hungry` to `hungry`, `fading` to `fading` and `dead` to `dead`, and SHALL map every Ghost_State to a Steady_Mood.
2. THE Mood_Map SHALL live in `apps/hauntagotchi/lib/src/ui/` as a pure function, with its test in `apps/hauntagotchi/test/ui/` (tests mirror `lib/`).
3. THE Ghost_Panel SHALL pass the mood to its Ghost_Loader, and SHALL keep the health number, the bar, the state word, the state icon and the streak line unchanged.
4. WHEN the Ghost_State changes, THE Ghost_Panel SHALL show the Mood_Transition from the old mood to the new mood (Requirement 7.1) and SHALL NOT remount the Ghost_Loader.
5. THE Home_Screen loading state SHALL keep its Ghost_Loader without a mood, so that "Waking the ghost…" shows the Legacy_Look.
6. THE Hauntagotchi app SHALL import only `package:coffin_core/coffin_core.dart` for moods.
7. WHEN the app opens or reloads with a stored ghost, THE Home_Screen SHALL show the Steady_Mood of the ghost's state at once, with no reaction.

### Requirement 14: Theme and token usage

**User Story:** As a maintainer, I want every mood to use the existing theme tokens, so that moods look right in both themes and a retheme changes them in one place.

#### Acceptance Criteria

1. THE Ghost_Painter and THE Ghost_Loader SHALL take every color from the Token_Set of `CoffinColorTokens` as before (body from `text` in night and `primary` in daylight, eyes from `background`, glow from `primary`), possibly with a changed alpha, and SHALL hard-code no color.
2. THE moods SHALL work under `CoffinTheme.dark()` and `CoffinTheme.light()` with the contrast rules of Requirement 4.4.
3. THE existing Widget_Source_Scan of `packages/coffin_core/lib/src/widgets/` and its pure math scan SHALL pass for the new files, and the pure mood files SHALL be covered by the pure math scan.
4. THE feature SHALL add no API key, secret or token to the repository.

### Requirement 15: Crypt gallery shows every mood

**User Story:** As a judge or a developer, I want to see every mood side by side, so that I can compare them at a glance.

#### Acceptance Criteria

1. THE Crypt_Gallery SHALL show, in each of its two panels (Night and Daylight), one Ghost_Loader for each of the seven Ghost_Mood values, side by side, with the mood name as the caption.
2. THE Crypt_Gallery SHALL arrange the mood ghosts so that they wrap to further rows when the width is too small, and SHALL NOT overflow at the widths 320, 360 and 1280 and at the text scales 1.0 and 1.5.
3. THE Crypt_Gallery SHALL label the mood section with a semantic header.
4. WHILE Reduced_Motion is on, THE Crypt_Gallery SHALL show every mood in its Still_Frame and SHALL add no loop and no ticker of its own.
5. WHILE Reduced_Motion is off, THE Crypt_Gallery SHALL let `fed` and `rising` play once on first build and hold their final pose, and SHALL pass no `onReactionEnd`.
6. THE Crypt_Gallery SHALL keep the existing Ghost_Loader samples with their existing captions and SHALL use the same mood order in the Night and the Daylight panel.
7. THE Crypt_Gallery SHALL use short, witty, slightly spooky copy for the mood section title and subtitle, never mean to the user and never gory.
8. THE Crypt_Gallery SHALL need no `GoRouter` and SHALL keep its public API unchanged.
9. IF an existing gallery test asserts the number of `GhostLoader` widgets in a panel or in the page, THEN THE feature SHALL update only that count in that test, and SHALL list the change as a flagged item in the design.

### Requirement 16: Fed reaction on every successful check-off

**User Story:** As a Hauntagotchi player, I want a happy reaction every time I tick a habit, so that ticking feels rewarding even when Health is already 100.

#### Acceptance Criteria

1. WHEN a Check_Off succeeds and the ghost is not dead after the Check_Off, THE Home_Controller SHALL publish one fed event, whatever the Health value, including Health 100.
2. WHILE Reduced_Motion is off, WHEN the Home_Screen receives a fed event and the ghost is not dead, THE Ghost_Panel SHALL play the `fed` reaction once through the Ghost_Loader, passing the Reaction_Key of that event, and SHALL then return to the Steady_Mood of the ghost's state when `onReactionEnd` is called.
3. WHILE Reduced_Motion is off, WHEN two Check_Offs happen in a row, THE Ghost_Panel SHALL play the `fed` reaction for each of them, and each fed event SHALL carry a new Reaction_Key, so that a Check_Off during a running `fed` reaction restarts the reaction from progress 0 without a jump (Requirement 9.10 and 9.11).
4. WHEN a habit is un-ticked (undo), WHEN a toggle is rejected, WHEN the tap is ignored because the day changed, or WHEN a habit is added, renamed or archived, THE Home_Controller SHALL publish no fed event.
5. WHEN the app opens, reloads or returns to the foreground, THE Home_Controller SHALL publish no fed event.
6. IF the ghost is dead after a Check_Off (a Ritual step while the Ritual is not complete), THEN THE Home_Controller SHALL publish no event for that Check_Off.
7. WHEN a Check_Off changes the Ghost_State, THE Ghost_Panel SHALL play `fed` first and then the Mood_Transition to the new Steady_Mood, so that the reward shows before the change of state.
8. THE fed event SHALL carry no data that persists, apart from its in-memory Reaction_Key (Requirement 19.6 and 19.7): it SHALL NOT be written to storage and SHALL NOT change `Haunting`, `Ghost` or any domain value.
9. WHILE Reduced_Motion is on, WHEN the Home_Screen receives a fed event, THE Ghost_Panel SHALL play no reaction, SHALL pass no Reaction_Mood to its Ghost_Loader, and SHALL show the Steady_Mood of the ghost's state, so that the tick mark of the habit carries the feedback and no still frame of `fed` is shown.
10. WHILE the ghost is dead and the Ritual is not complete, THE Ghost_Panel SHALL keep the `dead` mood and SHALL NOT play `fed`, even if it receives a fed event (a second guard behind criterion 6).

### Requirement 17: Rising reaction after a completed ritual

**User Story:** As a Hauntagotchi player, I want a special moment when my ghost comes back, so that the resurrection feels earned.

#### Acceptance Criteria

1. WHEN the Home_Controller receives a Ritual_Completion, THE Home_Controller SHALL publish one rising event and SHALL NOT publish a fed event for the same Check_Off.
2. WHILE Reduced_Motion is off, WHEN the Home_Screen receives a rising event, THE Ghost_Panel SHALL play the `rising` reaction once through the Ghost_Loader, passing the Reaction_Key of that event, and SHALL then show the Steady_Mood of the ghost's new state when `onReactionEnd` is called.
3. THE `rising` reaction SHALL play exactly once per Ritual_Completion, and SHALL NOT play again after a rebuild, a reload, a return to the foreground or a day change.
4. WHEN the ghost has been resurrected, THE Home_Screen SHALL keep showing the welcome-back message and the resurrection copy as before, and SHALL NOT delay them for the reaction.
5. WHEN the app opens with an already resurrected ghost, THE Home_Screen SHALL show the Steady_Mood of the ghost's state with no reaction.
6. WHILE Reduced_Motion is on, WHEN the Home_Screen receives a rising event, THE Ghost_Panel SHALL play no reaction, SHALL pass no Reaction_Mood to its Ghost_Loader, and SHALL show the Steady_Mood of the ghost's new state, so that the welcome-back message carries the feedback and no still frame of `rising` is shown.
7. THE rising event, including its Reaction_Key, SHALL NOT be written to storage and SHALL NOT change any domain value.

### Requirement 18: Ghost clear of the top edge

**User Story:** As a Hauntagotchi player, I want the ghost to have breathing room at the top of the home screen, so that it does not look glued to the edge of the window.

#### Acceptance Criteria

1. THE Home_Screen SHALL keep a distance of at least 24 logical pixels between the top of the safe area and the highest painted point of the ghost body, measured at the highest point of the bob and of the `rising` lift, for every mood.
2. THE Home_Screen SHALL keep this distance at the widths 320, 360 and 1280, at the text scales 1.0 and 1.5, and when the welcome-back message, the memory notice or the save-error banner is present or absent.
3. THE Home_Screen SHALL keep the ghost, the health line, the habits and the controls reachable without a layout exception at the widths 320, 360 and 1280.
4. THE fix SHALL change no other spacing of the Home_Screen beyond what criterion 1 requires, and SHALL keep the existing Home_Screen tests passing, apart from a test that pins the exact old top spacing, if one exists (to be listed as a flagged item in the design).
5. THE feature SHALL include a widget test that measures the distance of criterion 1 for the five Steady_Moods and for `rising`.

### Requirement 19: Controller events and lifecycle

**User Story:** As a maintainer, I want the reaction events to be simple and safe, so that they cannot leak or fire at the wrong time.

#### Acceptance Criteria

1. THE Home_Controller SHALL expose the reaction events in a way that a plain `ListenableBuilder` and plain Flutter can consume, with no new package and no state-management library.
2. THE Home_Controller SHALL publish an event only after the changed `Haunting` is set, so that the Ghost_Panel sees the new state and the event together.
3. WHEN the Home_Controller is disposed, THE Home_Controller SHALL publish no further event and SHALL NOT throw.
4. THE Home_Controller SHALL NOT create a `Timer` or a `Future.delayed` for reactions.
5. THE Home_Screen SHALL consume each event once, so that a rebuild for another reason (a save status change, a theme change, a habit rename) SHALL NOT replay a reaction.
6. THE Home_Controller SHALL give each published event (fed or rising) a Reaction_Key that is an `int` greater than the Reaction_Key of every earlier event of the same Home_Controller, so that two events never share a Reaction_Key.
7. THE Reaction_Key of an event SHALL live in memory only, SHALL NOT be written to storage, and SHALL start again from its initial value in a new Home_Controller.
8. THE Ghost_Panel SHALL pass the Reaction_Key of the current event to `GhostLoader.reactionKey`, and SHALL keep that value unchanged on every rebuild that does not come from a new event.

### Requirement 20: Documentation

**User Story:** As a Flutter developer reading Coffin, I want a short guide to moods, so that I can use them in my own app.

#### Acceptance Criteria

1. THE `packages/coffin_core/README.md` SHALL gain a section "Ghost moods" that lists the seven moods, shows a short code example that passes a `GhostMood` to `GhostLoader`, explains the Reaction_Moods and `onReactionEnd`, and states that no mood is the Legacy_Look.
2. THE README section SHALL state that moods differ in shape and motion and that Reduced_Motion shows a Still_Frame.
3. THE README section SHALL not name a package that is not already a dependency.
4. THE feature SHALL edit no other documentation file (`DIARY.md`, `CREDITS.md` and the root `README.md` stay unchanged).

### Requirement 21: Property-based verification

**User Story:** As a maintainer, I want the numeric rules checked across many generated inputs, so that edge cases cannot break the ghost.

#### Acceptance Criteria

1. THE property tests SHALL use glados, SHALL run each property at least 100 times, and SHALL check with a `RunCounter` that the property body ran.
2. THE property tests SHALL use only Web_Safe generators: `anyIntBetween`, `anyListBetween`, `any.simple` and `combineN`, and SHALL NOT use `any.int`, `any.intInRange`, `any.list`, `any.listWithLengthInRange`, string generators or `uint*` generators.
3. THE feature SHALL reuse the independent Web_Safe generators and `RunCounter` in `packages/coffin_core/test/widgets/support/`, and SHALL NOT import helpers from `test/ai/`.
4. THE property tests SHALL include: FOR ALL moods and Elapsed_Times (including negative), the Mood_Bob offset is finite and within the amplitude of the mood, is 0 for `dead`, and equals the offset one period later (Requirement 5).
5. THE property tests SHALL include: FOR ALL pairs of moods and progress values (including values below 0, above 1 and NaN), every blended number lies between the endpoint numbers, equals the first mood at progress 0 and the second at progress 1, and is finite (Requirement 7).
6. THE property tests SHALL include: FOR ALL progress values, the easing curve is within 0 to 1, is monotonic non-decreasing over sorted samples, and changes by at most the peak-speed bound over 16 ms of a 500 ms transition (Requirement 7.4).
7. THE property tests SHALL include: FOR ALL Elapsed_Times and both Reaction_Moods, the reaction progress is within 0 to 1, the `fed` scale is within 1.0 to 1.10, the `fed` lift is within 0 to 6, the `rising` lift is within 0 to 10, the `rising` opacity is within the opacity of `dead` and `thriving`, and the start and end values of Requirement 8.4 hold.
8. THE property tests SHALL include: FOR ALL pairs of different moods, the Mood_Traits differ in Eye_Style, Mouth_Style or posture (Requirement 3.2), and the five Steady_Mood opacities keep the order, and the bob periods and bob amplitudes of the four bobbing Steady_Moods keep the orders of Requirements 4.2 and 5.2.
9. THE property tests SHALL include: FOR ALL moods and both Token_Sets, the contrast rules of Requirement 4.4 hold.
10. THE feature SHALL include unit tests with fixed values for the table, the clamping rules and the edge cases (progress 0, 1, NaN, -1, 2; elapsed 0, negative, 2^40).
11. THE pure test files SHALL contain no `dart:io` import, so that they run in Chrome.

### Requirement 22: Widget and app tests

**User Story:** As a maintainer, I want widget tests for what the pure tests cannot see, so that reduced motion, semantics, transitions, tickers and the Hauntagotchi wiring stay correct.

#### Acceptance Criteria

1. THE feature SHALL include widget tests that confirm that under Reduced_Motion every mood shows its Still_Frame and `transientCallbackCount` is 0 after a pump.
2. THE feature SHALL include widget tests that confirm that under normal motion a bobbing mood runs one ticker and the painted offset changes between two pumps, that `dead` has no bob offset, and that after a finished reaction only the bob loop runs. The tests for a steady `dead` ghost are in Requirement 24.
3. THE feature SHALL include widget tests for the Mood_Transition: the blended values at 0 ms, 250 ms and 500 ms, a mid-transition mood change without a jump, and a change to the same mood without a transition.
4. THE feature SHALL include widget tests for reactions: `onReactionEnd` is called exactly once at the end, not on a change away, not twice after a rebuild, and once after the first frame under Reduced_Motion.
5. THE feature SHALL include widget tests that confirm that after a Ghost_Loader is replaced by an empty widget, `transientCallbackCount` is 0, no exception is thrown and no callback is called.
6. THE feature SHALL include widget tests that toggle `MediaQuery.disableAnimations` while a Ghost_Loader stays mounted and confirm that tickers stop and start.
7. THE feature SHALL include widget tests that pump the Ghost_Loader with every mood, and the Crypt_Gallery, at 320, 360 and 1280 logical pixels, at the text scales 1.0 and 1.5, under `CoffinTheme.dark()` and `CoffinTheme.light()`, and confirm that `tester.takeException()` is null and that the layout size of the Ghost_Loader does not change between moods.
8. THE feature SHALL include Hauntagotchi tests for the Mood_Map (all five states), for the Home_Controller events (fed on a successful Check_Off at Health 100 and below while the ghost is not dead afterwards; no fed on undo, rejection, day change, load and refresh; a Ritual step while the ghost is dead publishes nothing; rising and no fed on Ritual_Completion), and for the Home_Screen (the Ghost_Panel shows the mood of the state, plays `fed` after a tick, plays `rising` once after a ritual, does not replay after a rebuild, and keeps its semantics label).
9. THE feature SHALL include a Hauntagotchi widget test of the top clearance of Requirement 18.
10. THE feature SHALL use `pump` with explicit durations rather than `pumpAndSettle` for looping widgets, because a repeating controller never settles.
11. THE feature SHALL NOT include golden image tests; pixel comparisons SHALL render to an in-memory image and compare bytes.
12. THE feature SHALL include Ghost_Loader widget tests for the Reaction_Key: a rebuild with the same mood and the same key does not restart the reaction; a changed key with the same Reaction_Mood restarts the reaction from progress 0; the first frame after the restart shows the pose of the last frame before it (no jump); `onReactionEnd` is called once for the new run and not for the interrupted run; a changed key with a Steady_Mood starts nothing; a mood change to a Reaction_Mood starts a run whatever the key is; and, under Reduced_Motion, a changed key starts no ticker and calls `onReactionEnd` once.
13. THE feature SHALL include a Ghost_Painter test that confirms that `shouldRepaint` returns false for equal inputs and true for each changed mood input, and a Ghost_Loader test that confirms that the Reaction_Key has a default of 0 and that omitting it behaves as key 0.
14. THE feature SHALL include Hauntagotchi tests that confirm: two Check_Offs in a row publish events with different Reaction_Keys, the Ghost_Panel passes the new key to the Ghost_Loader, a second Check_Off during a running `fed` reaction restarts it, and a rebuild for another reason keeps the key and does not replay the reaction.
15. THE feature SHALL include Hauntagotchi widget tests that confirm that under Reduced_Motion a Check_Off and a Ritual_Completion show the Steady_Mood of the state in every frame, never a Still_Frame of `fed` or `rising`, and that the Ghost_Loader inside the Ghost_Panel never receives a Reaction_Mood.

### Requirement 23: Quality gates, scope and execution plan

**User Story:** As a maintainer, I want the work limited to the agreed folders and verified in small steps, so that nothing else breaks.

#### Acceptance Criteria

1. THE feature SHALL edit only files under `packages/coffin_core/lib`, `packages/coffin_core/test`, the "Ghost moods" section of `packages/coffin_core/README.md`, `apps/hauntagotchi/lib`, `apps/hauntagotchi/test` and `.kiro/specs/ghost-moods`, and SHALL create no file outside the repository, including `/tmp`.
2. THE feature SHALL leave `pubspec.yaml` files and `pubspec.lock` unchanged, checked with `git diff --stat` at the final Checkpoint.
3. THE feature SHALL pass `dart format` with no changes and `flutter analyze` with zero warnings across the workspace.
4. WHEN `flutter test` runs in `packages/coffin_core`, `apps/hauntagotchi`, `apps/graveyard` and `tool`, THE test suites SHALL pass, with the Graveyard and `tool` suites unchanged.
5. THE implementation plan SHALL contain no optional test task: every test task is required.
6. THE implementation plan SHALL execute one task at a time, and SHALL NOT mark a task done before its tests pass.
7. THE implementation plan SHALL order the work as: `GhostMood` and the pure mood math with its unit and property tests; then the painter and the loader with their widget tests; then the Crypt_Gallery; then the Hauntagotchi mapping, controller events, Ghost_Panel wiring and top-edge fix; then the README section.
8. THE implementation plan SHALL include a Checkpoint after the pure math, a Checkpoint after the painter and loader, a Checkpoint after the gallery, and a final Checkpoint at the end.
9. WHEN the Checkpoint after the pure math and the final Checkpoint are reached, THE team SHALL also run the pure test files in Chrome with `flutter test --platform chrome`, and they SHALL pass.
10. WHEN the final Checkpoint is reached, THE team SHALL also build Hauntagotchi and Graveyard for the web with `flutter build web`, and both builds SHALL succeed.
11. THE feature SHALL leave `DIARY.md`, `CREDITS.md`, the root `README.md` and the other specs unchanged.

### Requirement 24: No ticker for a Motionless_Pose

**User Story:** As a user who leaves a dead ghost open in a browser tab for days, I want the ghost to cost no repaint work while nothing on it moves, so that the tab does not burn battery or CPU at 60 frames per second.

#### Acceptance Criteria

1. WHILE the mood of a Ghost_Loader is `dead` and no Mood_Transition and no Reaction_Run is running and Reduced_Motion is off, THE Ghost_Loader SHALL run no ticker and SHALL schedule no frame, checked with `tester.binding.transientCallbackCount` equal to 0 after a pump.
2. WHILE Reduced_Motion is on, THE Ghost_Loader SHALL run no ticker for any mood (Requirement 10.2).
3. WHEN a Mood_Transition into `dead` has finished and Reduced_Motion is off, THE Ghost_Loader SHALL stop its ticker, so that the resulting Motionless_Pose runs no ticker.
4. WHEN the mood changes away from `dead` while Reduced_Motion is off, THE Ghost_Loader SHALL resume ticking before the first frame of the Mood_Transition, so that the transition plays over 500 ms as in Requirement 7.1.
5. WHEN the Reaction_Key changes while the mood stays the same Reaction_Mood and Reduced_Motion is off, THE Ghost_Loader SHALL have a running ticker for the new Reaction_Run (Requirement 9.10).
6. WHILE the mood of a Ghost_Loader is not null and is not `dead`, and WHILE the mood is null (the Legacy_Look), THE Ghost_Loader SHALL keep its bob loop running as before this requirement, because those looks bob.
7. IF `MotionLoop` needs a change to meet criteria 1, 3 and 4, THEN the change SHALL be the smallest one possible, for example an optional should-run check that defaults to the behaviour of today (always run while motion is allowed), so that `FlickerText`, `FogBackground` and the Legacy_Look of `GhostLoader` keep ticking exactly as before.
8. THE existing `FlickerText`, `FogBackground`, `GhostLoader` and `CryptGallery` tests, and the Hauntagotchi `home_screen_a11y_test.dart`, SHALL pass unchanged after this requirement is implemented.
9. THE feature SHALL include a Ghost_Loader widget test that confirms that a steady `dead` Ghost_Loader has `transientCallbackCount` equal to 0 after a pump of 1 second with Reduced_Motion off, and that its painted bob offset stays 0.
10. THE feature SHALL include a Ghost_Loader widget test that confirms that the same Ghost_Loader resumes ticking (`transientCallbackCount` above 0) when its mood changes from `dead` to another mood, and stops ticking again after a transition back to `dead` has finished.
11. THE feature SHALL include a Ghost_Loader widget test that confirms that a Ghost_Loader without a mood, and a Ghost_Loader with a bobbing mood, still run one ticker.

## Assumptions

- **A1 (approved).** `mood` is nullable and defaults to null. Null means the Legacy_Look, so there is no "none" enum value. The five Steady_Moods have their own looks; `content` is close to, but not required to equal, the Legacy_Look.
- **A2 (approved).** The numbers in this document (opacity 0.72 to 1.00, bob 3000 to 5000 ms and 2 to 8 px, 500 ms transition, `fed` 900 ms with pop at most 1.10, `rising` 2200 ms with lift at most 10 px, 24 px top clearance) are starting values. The opacities were raised from the first draft (0.80, 0.65, 0.50) to 0.85, 0.78, 0.72 because the first values fail the Requirement 4.4 contrast rule in daylight.
- **A3 (replaced by a decision).** Under Reduced_Motion the Hauntagotchi Ghost_Panel plays no reaction and shows the Steady_Mood of the ghost's state, with no one-frame still flash of `fed` or `rising`. The tick mark and the welcome-back message carry the feedback (Requirements 16.9 and 17.6). The Ghost_Loader itself may still show the Still_Frame of `fed` and `rising` when a caller asks (the Crypt_Gallery does), and may still call `onReactionEnd` once (Requirement 9.6). A Reaction_Mood plays once and then holds its final pose; the caller leaves it through `onReactionEnd`, and a new reaction of the same mood starts with a new Reaction_Key (Requirement 9). This needs no `Timer`.
- **A4 (approved).** While the ghost is dead and the Ritual is incomplete, ticking a Ritual step does not play `fed`, because a dead ghost cannot be fed. `rising` plays when the Ritual completes.
- **A5 (approved).** The cause of the ghost sitting against the top edge is not yet confirmed. The design phase finds it by measuring the home screen, then fixes it with the smallest spacing change that gives 24 px.
- **A6 (approved).** The pure mood classes stay internal, like `GhostBob`. Only `GhostMood` is added to the Barrel.
- **A7 (approved).** The Mood_Map sits in `apps/hauntagotchi/lib/src/ui/` and not in `domain/`, because `domain/` is pure Dart and `GhostMood` is exported by a Flutter package.
