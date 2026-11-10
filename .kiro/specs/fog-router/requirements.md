# Requirements Document

## Introduction

The fog-router feature adds the routing layer of `coffin_core`: a small reusable helper built on `go_router` that each app uses to declare its own routes, a "fog" page transition (fade in with a slight drift and blur), a reduced-motion variant of that transition, and a spooky reusable not-found page with a button back home. Both Hauntagotchi and Graveyard are wired to it, and the existing `PlaceholderScreen` of each app becomes its home route. The apps keep the default hash URL strategy so they work on static hosting without server rewrites. The transition math is pure Dart and is verified with glados property tests. The design language is "Haunted, not horror", as defined in the design steering document.

## Dependency Approval Notice

This feature requires one package that is not yet declared in the workspace. Per the tech steering rules, the user must approve it before it is added. The user has APPROVED it:

- `go_router` (dependency of `coffin_core`): approved, with a pinned version. It is the routing library named in the tech steering rules but is not yet in any `pubspec.yaml`.

The exact pinned version is chosen and verified during the design phase against the Flutter and Dart versions in the tech steering rules. `go_router` supports Flutter Web and needs no secrets. No other new package is approved or required. In particular, no URL-strategy package (such as `url_strategy`) is added, and the default hash strategy is left untouched.

## Glossary

- **Fog_Router**: The reusable routing helper in `coffin_core` that builds a `GoRouter` from an app's own route declarations.
- **App_Route**: A route declared by an app (path, name, page builder and optional child App_Routes) and passed to the Fog_Router. Apps own their route lists; `coffin_core` ships none of them.
- **Fog_Transition**: The page transition in which the incoming page fades in while drifting a short distance and resolving from a blur.
- **Fog_Transition_Page**: The `go_router` page type (a `CustomTransitionPage`) that applies the Fog_Transition to an App_Route's page.
- **Fog_Math**: The pure Dart class in `coffin_core` that maps animation progress to opacity, drift offset and blur radius. It has no Flutter imports.
- **Progress**: The animation value `t` in the range 0.0 to 1.0, where 0.0 is the start of the incoming page's entrance and 1.0 is the end.
- **Fog_Frame**: The immutable value returned by Fog_Math for one Progress: opacity, offset and blur.
- **Reduced_Motion**: The state where `MediaQuery.disableAnimations` is true.
- **Not_Found_Page**: The reusable spooky page shown when no route matches, with the heading "This page has passed on…" and a button back home.
- **Home_Route**: The route at path `/` in each app. It builds the app's existing `PlaceholderScreen`.
- **Hash_Strategy**: The default Flutter Web URL strategy, where routes live after `#` in the URL (for example `/#/graves`), so static hosting needs no server rewrites.
- **Barrel**: The file `packages/coffin_core/lib/coffin_core.dart`, the only public import for apps.
- **Placeholder_Screen**: The file `ui/placeholder_screen.dart` in each of Hauntagotchi and Graveyard.
- **Fog_Property_Tests**: The glados property-based tests for Fog_Math.

## Requirements

### Requirement 1: Reusable routing helper

**User Story:** As a Flutter developer using Coffin, I want a helper that builds a `GoRouter` from my own route list, so that I declare routes in my app and never rewrite the router plumbing.

#### Acceptance Criteria

1. THE Fog_Router SHALL accept a list of App_Routes and return a configured `GoRouter`.
2. THE Fog_Router SHALL accept an initial location and default it to `/`.
3. THE Fog_Router SHALL wrap each App_Route page in the Fog_Transition_Page, so that every route uses the Fog_Transition without per-route code.
4. THE Fog_Router SHALL allow an app to supply a custom not-found builder and SHALL default to the Not_Found_Page when none is supplied.
5. THE Fog_Router SHALL ship no App_Routes of its own, so that all route declarations live in the apps.
6. THE Fog_Router SHALL expose an App_Route type that carries a path, a name and a page builder, that can optionally carry child App_Routes, and that can be converted to a `GoRoute`. Child App_Routes SHALL be converted to nested `GoRoute`s and SHALL also use the Fog_Transition.
7. THE Fog_Router SHALL expose its public API through the Barrel, so that apps never import files under `src/`.
8. THE Fog_Router source files SHALL live under `packages/coffin_core/lib/src/router/`, with one public class per file named in `snake_case.dart`.
9. THE Fog_Router SHALL NOT call any URL-strategy setter, and SHALL NOT call `usePathUrlStrategy`.
10. IF an app supplies no App_Routes, THEN THE Fog_Router SHALL still return a working `GoRouter` whose every location resolves to the not-found builder.

### Requirement 2: Fog transition behavior

**User Story:** As a user, I want pages to arrive like mist, so that navigation feels floaty and calm.

#### Acceptance Criteria

1. WHEN a route is pushed or replaced, THE Fog_Transition SHALL animate the incoming page's opacity from 0.0 to 1.0.
2. WHILE the Fog_Transition runs, THE Fog_Transition SHALL translate the incoming page by a slight vertical drift that is largest at Progress 0.0 and exactly zero at Progress 1.0.
3. WHILE the Fog_Transition runs, THE Fog_Transition SHALL blur the incoming page with a radius that is largest at Progress 0.0 and exactly zero at Progress 1.0.
4. THE Fog_Transition SHALL default to a forward duration within 300 to 600 ms, using an ease-in-out curve.
5. THE Fog_Transition SHALL use the same duration range for the reverse transition.
6. WHEN the blur radius is zero, THE Fog_Transition SHALL NOT add a blur filter to the widget tree, so that a settled page carries no blur cost.
7. THE Fog_Transition SHALL NOT animate the outgoing page, so that the incoming page alone carries the effect.
8. WHILE Reduced_Motion is off, IF a caller supplies a duration outside 300 to 600 ms, THEN THE Fog_Transition_Page SHALL clamp it into that range. WHILE Reduced_Motion is active, THE clamp SHALL NOT apply and a duration of zero SHALL be allowed (see Requirement 3.5).
9. THE Fog_Transition SHALL leave the final, settled page fully opaque, with zero offset and zero blur.
10. THE Fog_Transition SHALL add no extra nodes to the accessibility tree, and the page content SHALL remain reachable by screen readers while it animates.

### Requirement 3: Reduced motion

**User Story:** As a user who is sensitive to motion, I want page changes without movement, so that the app is comfortable to use.

#### Acceptance Criteria

1. WHILE Reduced_Motion is active, THE Fog_Transition SHALL apply no drift: the offset is always zero.
2. WHILE Reduced_Motion is active, THE Fog_Transition SHALL apply no blur: the blur radius is always zero.
3. WHILE Reduced_Motion is active, THE Fog_Transition SHALL be either an instant change or a plain opacity change, and SHALL contain no other motion.
4. WHEN the Fog_Transition_Page builds, THE Fog_Transition_Page SHALL read `MediaQuery.disableAnimations` from the context to decide between the full and the reduced behavior.
5. WHILE Reduced_Motion is active, THE Fog_Transition_Page SHALL use a transition duration that is zero or no longer than the standard Fog_Transition duration.
6. WHEN Reduced_Motion changes while the app is running, THE next navigation SHALL use the new setting.

### Requirement 4: Pure transition math

**User Story:** As a maintainer, I want the transition numbers computed in plain Dart, so that they are easy to read and test without a widget tree.

#### Acceptance Criteria

1. THE Fog_Math SHALL be a plain Dart class with no Flutter imports, in `packages/coffin_core/lib/src/router/`.
2. THE Fog_Math SHALL expose pure functions of Progress that return opacity, offset and blur radius, and a method that returns all three as one Fog_Frame.
3. THE Fog_Math SHALL return an opacity in the range 0.0 to 1.0, an offset with a vertical component in the range 0.0 to the configured maximum drift (and a horizontal component of zero), and a blur radius in the range 0.0 to the configured maximum blur, for every Progress.
4. THE Fog_Math SHALL clamp a Progress below 0.0 to 0.0 and a Progress above 1.0 to 1.0 before computing, so that out-of-range input yields in-range output.
5. THE Fog_Math SHALL return opacity 0.0 at Progress 0.0 and opacity 1.0 at Progress 1.0.
6. THE Fog_Math SHALL return offset 0.0 and blur 0.0 at Progress 1.0.
7. THE Fog_Math SHALL be deterministic: equal inputs yield equal Fog_Frames.
8. THE Fog_Math SHALL accept a reduced-motion flag, and WHEN the flag is true, it SHALL return an offset of zero and a blur of zero for every Progress, with opacity still within 0.0 to 1.0.
9. THE Fog_Math SHALL be immutable, with all fields declared `final` and a `const` constructor, and the Fog_Frame SHALL be an immutable value type with value equality.
10. THE Fog_Math SHALL expose its maximum drift and maximum blur as named constants or constructor parameters with documented defaults, and SHALL reject (by assertion) a negative maximum drift or maximum blur.
11. IF a Progress is NaN, THEN THE Fog_Math SHALL treat it as 0.0.
12. THE Fog_Math SHALL carry a doc comment on every public member.

### Requirement 5: Property-based verification of the math

**User Story:** As a maintainer, I want the transition invariants checked over many generated inputs, so that no edge case slips through.

#### Acceptance Criteria

1. THE Fog_Property_Tests SHALL use glados to generate Progress values, including values outside 0.0 to 1.0, and assert that opacity stays within 0.0 to 1.0, that the offset magnitude stays within 0.0 to the maximum drift, and that blur stays within 0.0 to the maximum blur.
2. THE Fog_Property_Tests SHALL use glados to generate pairs of Progress values and assert that opacity never decreases as Progress increases (for `a <= b`, `opacity(a) <= opacity(b)`).
3. THE Fog_Property_Tests SHALL use glados to generate Progress values with the reduced-motion flag set to true and assert that the offset is always exactly zero.
4. THE Fog_Property_Tests SHALL also assert that blur is zero for every Progress under the reduced-motion flag.
5. THE Fog_Property_Tests SHALL assert that, with the reduced-motion flag off, offset and blur never increase as Progress increases.
6. THE Fog_Property_Tests SHALL include unit tests for the boundary values: Progress 0.0, 0.5 and 1.0, the clamped inputs -1.0 and 2.0, and NaN.
7. IF any generated input violates an invariant, THEN THE Fog_Property_Tests SHALL fail and report the input value.
8. THE Fog_Property_Tests SHALL live under `packages/coffin_core/test/router/`, mirroring the `lib/` layout.

### Requirement 6: Not-found page

**User Story:** As a user who lands on a missing page, I want a friendly spooky page with a way back, so that I never reach a dead end.

#### Acceptance Criteria

1. THE Not_Found_Page SHALL display the heading "This page has passed on…" using the display text style from `Theme.of(context)`.
2. THE Not_Found_Page SHALL display a short, witty, non-blaming line of body copy using the body text style.
3. THE Not_Found_Page SHALL show a button that navigates to the home location `/`.
4. WHEN the user activates the button, THE Not_Found_Page SHALL navigate to `/` with `go_router`, replacing the current location.
5. THE Not_Found_Page SHALL take all colors and text styles from `Theme.of(context)`, with no hard-coded colors, so that it matches the haunted theme in both dark and light variants.
6. THE Not_Found_Page SHALL use the Glow_Decoration and the `CoffinMark` or an equivalent decorative element, and the decoration SHALL be excluded from the accessibility tree.
7. THE Not_Found_Page SHALL give the button a semantic label, a tap target of at least 48×48 logical pixels, and hover and press states from the theme.
8. THE Not_Found_Page SHALL accept an optional home location and an optional message override, defaulting to `/` and to the standard copy.
9. THE Not_Found_Page SHALL lay out without overflow on a 320 px wide viewport and on a desktop-width viewport, and SHALL scroll when the viewport is too short.
10. THE Not_Found_Page SHALL have no looping or moving decoration, in any motion setting.
11. THE Not_Found_Page file SHALL live under `packages/coffin_core/lib/src/router/` or `packages/coffin_core/lib/src/widgets/`, with one public widget per file.

### Requirement 7: Hash URL strategy preserved

**User Story:** As a hackathon participant deploying to static hosting, I want routes to work without server rewrites, so that judges can open the app from a plain URL.

#### Acceptance Criteria

1. THE Hauntagotchi app SHALL use the default Hash_Strategy and SHALL NOT call `usePathUrlStrategy` or any equivalent.
2. THE Graveyard app SHALL use the default Hash_Strategy and SHALL NOT call `usePathUrlStrategy` or any equivalent.
3. THE Fog_Router SHALL NOT configure a URL strategy.
4. WHEN the app is opened at the bare site URL, THE app SHALL resolve to the Home_Route.
5. WHEN the app is opened at a hash URL that matches no App_Route (for example `/#/nowhere`), THE app SHALL show the Not_Found_Page.
6. THE feature SHALL NOT require any server rewrite rule, `.htaccess`, `_redirects` file, or `404.html` workaround for in-app navigation to work.

### Requirement 8: App wiring

**User Story:** As a hackathon judge opening either app, I want it to start on a working home screen with routing in place, so that both apps are ready to grow.

#### Acceptance Criteria

1. WHEN Hauntagotchi starts, THE Hauntagotchi app SHALL build its `GoRouter` with the Fog_Router and run through `MaterialApp.router`.
2. WHEN Graveyard starts, THE Graveyard app SHALL build its `GoRouter` with the Fog_Router and run through `MaterialApp.router`.
3. THE Hauntagotchi app SHALL declare its own App_Route list in its own source tree (under `lib/src/`) with the Home_Route building its existing Placeholder_Screen.
4. THE Graveyard app SHALL declare its own App_Route list in its own source tree (under `lib/src/`) with the Home_Route building its existing Placeholder_Screen.
5. THE Hauntagotchi and Graveyard apps SHALL keep `CoffinTheme.dark()` applied to their `MaterialApp.router`, as in the haunted-theme feature.
6. THE Hauntagotchi and Graveyard apps SHALL import only `package:coffin_core/coffin_core.dart` for routing, and SHALL import `go_router` only where they need its types directly.
7. THE Hauntagotchi and Graveyard apps SHALL NOT import from each other, and `coffin_core` SHALL NOT import from either app.
8. THE `go_router` dependency SHALL be declared in `packages/coffin_core/pubspec.yaml` with a pinned version, and in an app `pubspec.yaml` only if that app imports `go_router` directly, using the same pinned version.
9. THE Barrel SHALL re-export from `go_router` only the types apps need to declare routes and navigate, using `show` clauses.
10. THE Placeholder_Screen of each app SHALL keep its current content and theme behavior, including the existing title and body copy.
11. EACH app SHALL have a widget test confirming that the app starts on the Home_Route and shows its Placeholder_Screen.
12. EACH app SHALL have a widget test confirming that an unknown location shows the Not_Found_Page, and that the button returns to the Placeholder_Screen.

### Requirement 9: Package boundaries and structure

**User Story:** As a maintainer, I want the router to follow the project structure, so that the skeleton stays easy to read.

#### Acceptance Criteria

1. THE router source files SHALL live under `packages/coffin_core/lib/src/router/`, in `snake_case.dart` files with one public class per file.
2. THE router tests SHALL live under `packages/coffin_core/test/router/`, mirroring the `lib/` layout.
3. THE Fog_Math and Fog_Frame SHALL import no Flutter library.
4. THE Barrel SHALL export only the public names intended for apps, using `show` clauses consistent with the existing exports.
5. EVERY public API in the router source files SHALL carry a doc comment.
6. THE coffin_core package SHALL import nothing from `apps/hauntagotchi` or `apps/graveyard`.
7. THE feature SHALL add no Hive, Riverpod or AI code, and no state-management dependency beyond what already exists.

### Requirement 10: Quality gates

**User Story:** As a maintainer, I want the feature to meet the workspace quality rules, so that the codebase stays clean.

#### Acceptance Criteria

1. THE feature code SHALL pass `dart format` with no changes.
2. THE feature code SHALL pass `flutter analyze` with zero warnings across the workspace.
3. THE feature SHALL include unit tests for Fog_Math, Fog_Frame, the Fog_Router helper, the Fog_Transition_Page and the Not_Found_Page.
4. THE feature SHALL include widget tests for the Fog_Transition under both normal motion and Reduced_Motion (via `MediaQuery.disableAnimations`), confirming that no translation is applied under Reduced_Motion.
5. THE feature SHALL include the glados property tests of Requirement 5.
6. WHEN `flutter test` runs at the workspace packages, THE test suite SHALL pass before any task is marked done.
7. THE feature SHALL add `go_router` with a pinned version and no other new package.
8. THE feature SHALL add no API keys, secrets or tokens to the repository.
