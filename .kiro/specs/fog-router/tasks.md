# Implementation Plan: fog-router

## Overview

Build the routing layer of `coffin_core` in dependency order: the one new dependency first, then the pure Dart transition math and its property tests, then the transition widget and page, then `AppRoute`, `NotFoundPage` and `FogRouter`, then the barrel and boundary checks, and finally the wiring of both apps. Each task builds on the previous ones.

All code is Dart in Flutter, matching the design. Paths are relative to the repo root. Tests use `flutter_test` and `glados`. Per the tech steering rules, unit tests and property tests for the pure logic are required, not optional. Every task is required.

Notes that apply to all tasks:

- Edit only files inside this repository (`/Users/ranmanlabs/Documents/Kiroween/coffin`). Create no temporary files outside it.
- `go_router` is pinned to exactly `17.5.0`. It is the only new package. Do not add `material_ui`, `cupertino_ui`, `intl` or any URL-strategy package.
- Do not call `usePathUrlStrategy` or `setUrlStrategy` anywhere. The apps keep the default hash strategy.
- `glados` exports its own `expect`, `group` and `test`, so test files must `hide` the clashing names from the glados import, as `packages/coffin_core/test/theme/coffin_glow_property_test.dart` does.
- `public_member_api_docs` is already enabled for `coffin_core`, so every public member needs a doc comment.
- Do not touch `DIARY.md`. The user keeps the diary.
- Do not mark a task done until `flutter test` passes for the package or app it touches.
- Tests render with the Ahem font, so assert on style strings and widget structure, never on glyph shapes.

## Tasks

- [x] 1. Dependency
  - [x] 1.1 Add `go_router` 17.5.0 to `coffin_core`
    - Read `packages/coffin_core/pubspec.yaml` first.
    - Add `go_router: 17.5.0` (exact pin, no caret) under `dependencies`. Do not add it to either app pubspec.
    - Run `flutter pub get` at the workspace root and confirm it resolves. Check the resolution added only `go_router` (and the SDK package `flutter_web_plugins`, plus `logging` and `meta` if not already present). If anything else such as `material_ui` appears, stop and report it.
    - _Requirements: 8.8, 10.7_

- [x] 2. Pure transition math
  - [x] 2.1 Implement `FogFrame`
    - Create `packages/coffin_core/lib/src/router/fog_frame.dart` with a `final class FogFrame`, a `const` constructor and `final` fields `opacity`, `dx`, `dy`, `blur`, plus `==`, `hashCode` and `toString` over all four fields.
    - Import nothing from Flutter. Doc-comment every public member.
    - _Requirements: 4.1, 4.9, 4.12, 9.1, 9.3, 9.5_

  - [x] 2.2 Implement `FogMath`
    - Create `packages/coffin_core/lib/src/router/fog_math.dart` with a `final class FogMath` as in the design.
    - `const` constructor with `maxDrift` (default 16) and `maxBlur` (default 8), asserting both are `>= 0`. Constants `defaultMaxDrift`, `defaultMaxBlur`, `minDuration` (300 ms), `maxDuration` (600 ms), `defaultDuration` (600 ms).
    - `progress(t)` clamps to 0..1 and maps NaN to 0.
    - `opacity` is `p`. `dx` is always `0.0`. `dy` is `maxDrift * (1 - p)`. `blur` is `maxBlur * (1 - p)`. When `reducedMotion` is true, `dy` and `blur` return the literal `0.0`. `opacity` is unchanged under reduced motion.
    - `frame(t, {reducedMotion})` returns a `FogFrame`.
    - `resolveDuration(requested, {reducedMotion = false, reducedDuration = Duration.zero})`: normal motion clamps `requested` into 300 to 600 ms; reduced motion returns `reducedDuration` clamped into zero to `defaultDuration`.
    - Import nothing from Flutter (`dart:core` only). Doc-comment every public member.
    - _Requirements: 2.2, 2.3, 2.4, 2.8, 3.1, 3.2, 3.5, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 4.10, 4.11, 4.12, 9.1, 9.3, 9.5_

  - [x] 2.3 Write unit tests for `FogFrame` and `FogMath`
    - Create `packages/coffin_core/test/router/fog_frame_test.dart` (equality, `hashCode`, inequality when any field differs) and `packages/coffin_core/test/router/fog_math_test.dart`.
    - `fog_math_test.dart`: defaults (16, 8, 600 ms, 300 ms, 600 ms); boundary values at progress 0.0, 0.5 and 1.0; clamped inputs -1.0 and 2.0; NaN treated as 0.0; opacity 0 at start and 1 at end; offset and blur zero at 1.0; reduced motion gives zero `dx`, `dy` and `blur` at 0.0, 0.5 and 1.0 while opacity stays in range; custom `maxDrift` and `maxBlur` scale the result; a negative `maxDrift` or `maxBlur` trips the assertion; `resolveDuration` clamps 100 ms to 300 ms and 900 ms to 600 ms, leaves 450 ms alone, returns zero under reduced motion by default, honors a 150 ms `reducedDuration`, and clamps a 2 s `reducedDuration` to `defaultDuration` (600 ms).
    - _Requirements: 2.4, 2.8, 3.5, 4.3, 4.4, 4.5, 4.6, 4.8, 4.9, 4.10, 4.11, 5.6, 10.3_

  - [x] 2.4 Write property tests for output ranges and settled state
    - Create `packages/coffin_core/test/router/fog_math_property_test.dart`, hiding the glados name clashes.
    - **Property 1: Output ranges.** `Glados2` over progress from `any.doubleInRange(-5, 5)` and a `bool` reduced flag. Assert opacity in `[0, 1]`, `dx == 0`, `dy` in `[0, maxDrift]`, `blur` in `[0, maxBlur]`. Use a reason string that includes the input value.
    - **Property 5: Settled end state.** For any `t` in `[1, 5]`, the frame is opacity 1, `dx`, `dy` and `blur` zero. For any `t` in `[-5, 0]`, opacity is 0.
    - Tag each with `// Feature: fog-router, Property N`. At least 100 runs each.
    - **Validates: Requirements 2.9, 4.3, 4.4, 4.5, 4.6, 5.1, 5.7**

  - [x] 2.5 Write property tests for monotonicity
    - In `fog_math_property_test.dart`.
    - **Property 2: Opacity is monotonic.** `Glados2` over two progress values from `any.doubleInRange(-5, 5)`, ordered so `a <= b`. Assert `opacity(a) <= opacity(b)` for both reduced flag values.
    - **Property 4: Drift and blur settle.** Same ordered pair, normal motion only. Assert `dy(a) >= dy(b)` and `blur(a) >= blur(b)`.
    - Tag with `// Feature: fog-router, Property 2` and `Property 4`. At least 100 runs each. Reasons include both input values.
    - **Validates: Requirements 2.2, 2.3, 4.3, 5.2, 5.5, 5.7**

  - [x] 2.6 Write property tests for reduced motion, durations and determinism
    - In `fog_math_property_test.dart`.
    - **Property 3: Reduced motion has no movement.** For any progress, `frame(t, reducedMotion: true)` has `dx == 0`, `dy == 0` and `blur == 0` (exactly, not approximately), with opacity in `[0, 1]`.
    - **Property 6: Duration rules.** Requested duration from `any.intInRange(-1000, 5000).map((ms) => Duration(milliseconds: ms))`. Normal motion result is within 300 to 600 ms. Reduced motion result is zero by default and always within zero to `defaultDuration` for any `reducedDuration`.
    - **Property 7: Determinism.** Two `frame` calls with equal inputs return equal frames.
    - Tag with `// Feature: fog-router, Property 3`, `Property 6` and `Property 7`. At least 100 runs each.
    - **Validates: Requirements 2.4, 2.8, 3.1, 3.2, 3.5, 4.7, 4.8, 5.3, 5.4, 5.7**

- [x] 3. Checkpoint - Pure math verification
  - Run `dart format --set-exit-if-changed .`, `flutter analyze` and `flutter test` in `packages/coffin_core`. Fix anything that fails.
  - Ensure all tests pass, ask the user if questions arise.
  - _Requirements: 10.1, 10.2, 10.6_

- [x] 4. Transition widget and page
  - [x] 4.1 Implement `FogTransition`
    - Create `packages/coffin_core/lib/src/router/fog_transition.dart` with a `StatelessWidget` taking `animation`, `child` and `math` (default `const FogMath()`).
    - In `build`, read `reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false`.
    - Derive `curved = animation.drive(CurveTween(curve: Curves.easeInOut))`.
    - Derive the opacity animation through FogMath: `curved.drive(Animatable<double>.fromCallback((t) => math.opacity(t, reducedMotion: reduced)))`. If `Animatable.fromCallback` is not available in Flutter 3.47.9, use a tiny private `Animatable<double>` subclass in the same file instead.
    - Return `FadeTransition(opacity: opacityAnimation, alwaysIncludeSemantics: true, child: AnimatedBuilder(animation: curved, child: child, builder: ...))`. Use no `Opacity` widget.
    - The `AnimatedBuilder` builder calls `math.frame(curved.value, reducedMotion: reduced)`. When `frame.dy == 0` and `frame.blur < 0.1`, return the passed child unwrapped. Otherwise wrap it in `Transform.translate(offset: Offset(frame.dx, frame.dy))` and, only when `frame.blur >= 0.1`, an `ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur, tileMode: TileMode.decal))`.
    - Ignore any secondary animation (the outgoing page is not animated). Doc-comment the class and its members.
    - _Requirements: 2.1, 2.2, 2.3, 2.5, 2.6, 2.7, 2.9, 2.10, 3.1, 3.2, 3.3, 3.4, 3.6, 9.1, 9.5_

  - [x] 4.2 Write widget tests for `FogTransition`
    - Create `packages/coffin_core/test/router/fog_transition_test.dart`.
    - Drive an `AnimationController` (with `TestVSync`) wrapped in `MediaQuery` and `Directionality`. Sample at 0.0, 0.5 and 1.0.
    - Normal motion: at 0.0 the `FadeTransition` opacity is 0, `alwaysIncludeSemantics` is true, the child is translated down and an `ImageFiltered` is present; at 0.5 opacity and drift are between the extremes; at 1.0 opacity is 1, there is no non-zero `Transform` and no `ImageFiltered`.
    - Assert no `Opacity` widget is in the tree and `FadeTransition` is the outermost fog widget.
    - Reduced motion (`MediaQuery(data: MediaQueryData(disableAnimations: true))`): at every sampled step the translation is zero and no `ImageFiltered` exists, while the `FadeTransition` still fades.
    - Semantics: a `Semantics` label on the child is found by `find.bySemanticsLabel` at progress 0, and `FogTransition` adds no extra semantics nodes.
    - Reverse: run the controller from 1.0 to 0.0 and assert the same ranges.
    - Changing `disableAnimations` between two pumps changes the behavior of the next build.
    - _Requirements: 2.1, 2.2, 2.3, 2.5, 2.6, 2.9, 2.10, 3.1, 3.2, 3.3, 3.6, 10.3, 10.4_

  - [x] 4.3 Implement `FogTransitionPage`
    - Create `packages/coffin_core/lib/src/router/fog_transition_page.dart` with `class FogTransitionPage<T> extends CustomTransitionPage<T>`.
    - Constructor: `required super.child`, `super.key`, `super.name`, `super.arguments`, `super.restorationId`, `Duration duration = FogMath.defaultDuration`, `bool reducedMotion = false`, `FogMath math = const FogMath()`.
    - Pass `transitionsBuilder` returning `FogTransition(animation: animation, math: math, child: child)`. Pass `transitionDuration` and `reverseTransitionDuration` both as `math.resolveDuration(duration, reducedMotion: reducedMotion)`, computed through a private static helper because an initializer list cannot call instance methods.
    - Doc-comment the class and its constructor.
    - _Requirements: 2.4, 2.5, 2.8, 3.4, 3.5, 9.1, 9.5_

  - [x] 4.4 Write unit tests for `FogTransitionPage`
    - Create `packages/coffin_core/test/router/fog_transition_page_test.dart`.
    - Default duration is 600 ms forward and reverse. A 100 ms request clamps to 300 ms and a 900 ms request clamps to 600 ms. With `reducedMotion: true` the duration is zero and a 100 ms request is not raised to 300 ms. The page is a `CustomTransitionPage`. `key`, `name` and `child` are passed through. The `transitionsBuilder` returns a `FogTransition`.
    - _Requirements: 2.4, 2.5, 2.8, 3.5, 10.3_

- [x] 5. Routes, not-found page and router helper
  - [x] 5.1 Implement `AppRoute`
    - Create `packages/coffin_core/lib/src/router/app_route.dart` with an `@immutable class AppRoute`.
    - Fields: `path`, `builder` (`Widget Function(BuildContext, GoRouterState)`), optional `name`, `routes` (default `const <AppRoute>[]`), `duration` (default `FogMath.defaultDuration`).
    - `GoRoute toGoRoute()` returns a `GoRoute` with the same path and name, a `pageBuilder` producing `FogTransitionPage<void>(key: state.pageKey, name: state.name, child: builder(context, state), duration: duration, reducedMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false)`, and `routes: [for (final r in routes) r.toGoRoute()]`.
    - Document go_router's path rules on `path`: top-level paths start with `/`, child paths do not.
    - _Requirements: 1.3, 1.6, 1.8, 3.4, 9.1, 9.5_

  - [x] 5.2 Write unit and widget tests for `AppRoute`
    - Create `packages/coffin_core/test/router/app_route_test.dart`.
    - `toGoRoute` keeps path and name; children become nested `GoRoute`s with the same paths, recursively two levels deep; `routes` defaults to empty.
    - Widget test using a `GoRouter` built directly from `toGoRoute()` results: navigating to a parent and to a child both build a `FogTransitionPage` (inspect via the router's current match or the `Navigator` pages).
    - Under reduced motion (set with `tester.platformDispatcher.accessibilityFeaturesTestValue`, and reset with `addTearDown`), the built page has a zero duration; under normal motion it has the requested clamped duration.
    - _Requirements: 1.3, 1.6, 3.4, 3.6, 10.3_

  - [x] 5.3 Implement `NotFoundPage`
    - Create `packages/coffin_core/lib/src/router/not_found_page.dart` with a `StatelessWidget` taking `homeLocation = '/'` and optional `message`.
    - `Scaffold` > `SafeArea` > `Center` > `SingleChildScrollView` > `ConstrainedBox(maxWidth: 480)` with padding 24, then a column (centered, `MainAxisSize.min`):
      1. `ExcludeSemantics` around a `DecoratedBox` with `CoffinGlow.decoration(color: scheme.primary, intensity: 0.6, fill: scheme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(48), bottom: Radius.circular(CoffinMetrics.cornerRadius)))` holding an `Icon(Icons.nightlight_round, size: 64)` with padding. Static, no animation.
      2. `Semantics(header: true, child: Text('This page has passed on…', style: textTheme.displaySmall, textAlign: center))`.
      3. Body `Text(message ?? 'The link you followed is a ghost now. Let\u2019s get you back to the living.', style: textTheme.bodyLarge with onSurfaceVariant)`.
      4. `FilledButton` with `Text('Back to the land of the living', semanticsLabel: 'Go back to the home page')` and `onPressed: () => context.go(homeLocation)`.
    - Import `GoRouterHelper` through `package:go_router/go_router.dart`. Take every color and text style from `Theme.of(context)`. No hard-coded colors. No `AnimationController` or other motion.
    - Doc-comment the class and members.
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 6.9, 6.10, 6.11, 9.1, 9.5_

  - [x] 5.4 Write widget tests for `NotFoundPage`
    - Create `packages/coffin_core/test/router/not_found_page_test.dart`.
    - Heading text "This page has passed on…" is shown with the display style (`displaySmall`, whose family is the Creepster family name) and the body with the body family name. A `message` override replaces the default body.
    - Pump under both `CoffinTheme.dark()` and `CoffinTheme.light()` and assert the scaffold background equals the matching tokens' background.
    - Button: tap target is at least 48x48 (measure with `tester.getSize`); the semantics label "Go back to the home page" is findable; tapping it navigates to `/` (use a small `GoRouter` with routes `/` and `/lost`, start at `/nowhere`, tap, expect the home screen) and a custom `homeLocation` goes there instead.
    - The decorative panel is excluded from semantics: the semantics tree has no node for the icon.
    - No overflow (`tester.takeException` is null) at 320x640, 1200x800 and 320x200 (short viewport scrolls: a `SingleChildScrollView` exists and scrolling reveals the button).
    - There is no `AnimationController`-driven widget: no `AnimatedBuilder` or `AnimatedWidget` subclass with a running ticker (assert `tester.hasRunningAnimations` is false after the first pump).
    - Same results with `disableAnimations` true.
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 6.9, 6.10, 10.3_

  - [x] 5.5 Implement `FogRouter`
    - Create `packages/coffin_core/lib/src/router/fog_router.dart` with `abstract final class FogRouter` and `static GoRouter create({required List<AppRoute> routes, String initialLocation = '/', Widget Function(BuildContext, GoRouterState)? notFoundBuilder, List<NavigatorObserver>? observers, bool debugLogDiagnostics = false})`.
    - Return `GoRouter(routes: [for (final r in routes) r.toGoRoute()], initialLocation: initialLocation, observers: observers, debugLogDiagnostics: debugLogDiagnostics, errorPageBuilder: ...)`. Use only `errorPageBuilder` (go_router asserts at most one of `onException`, `errorPageBuilder`, `errorBuilder`). The error page builder returns a `FogTransitionPage<void>` around `notFoundBuilder?.call(context, state) ?? const NotFoundPage()`, with `key: state.pageKey` and the same live reduced-motion read as `AppRoute`.
    - Set no URL strategy. Ship no routes of its own.
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.8, 1.9, 1.10, 7.3, 9.1, 9.5_

  - [x] 5.6 Write widget tests for `FogRouter`
    - Create `packages/coffin_core/test/router/fog_router_test.dart`, pumping `MaterialApp.router(theme: CoffinTheme.dark(), routerConfig: router)`.
    - Starts at `/` by default and at a custom `initialLocation`; navigation between two routes with `context.go` and `context.push` and `pop`; a nested child route resolves; an unknown location shows `NotFoundPage`; a custom `notFoundBuilder` replaces it; an **empty route list** still builds and shows the not-found page for `/` (this confirms Req 1.10, which the design could not verify by reading source; if it fails, report it and stop instead of changing the requirement).
    - The not-found page's button returns to `/`.
    - Reduced motion: with `tester.platformDispatcher.accessibilityFeaturesTestValue` set to disable animations (reset in `addTearDown`), a route change completes in one pump with no non-zero translation; with it off, mid-transition pumps show a non-zero translation and a `FadeTransition` opacity between 0 and 1. Do not wrap `MaterialApp.router` in an overriding `MediaQuery`, because the app builds its own from the view.
    - Confirms `MediaQuery` is available to `pageBuilder` (the design flagged this as unverified at runtime).
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.10, 3.4, 3.6, 7.4, 7.5, 10.3, 10.4_

- [x] 6. Barrel and boundary checks
  - [x] 6.1 Export the router API from the barrel
    - Edit `packages/coffin_core/lib/coffin_core.dart`, keeping every existing export.
    - Add `export 'package:go_router/go_router.dart' show GoRouter, GoRouterState, GoRouterHelper;` and `show` exports for `AppRoute`, `FogFrame`, `FogMath`, `FogRouter`, `FogTransition`, `FogTransitionPage`, `NotFoundPage` from `src/router/`.
    - _Requirements: 1.7, 8.9, 9.4_

  - [x] 6.2 Write barrel export and source-scan tests
    - Create `packages/coffin_core/test/router/router_sources_test.dart`.
    - Barrel: importing only `package:coffin_core/coffin_core.dart` gives access to all eight new names plus `GoRouter`, `GoRouterState` and the `context.go` extension; the barrel text uses `show` clauses for every export.
    - Source scan: `fog_math.dart` and `fog_frame.dart` contain no `package:flutter/` import; no file under `packages/coffin_core/lib` contains `usePathUrlStrategy`, `setUrlStrategy` or `url_strategy`; no file under `apps/hauntagotchi/lib` or `apps/graveyard/lib` contains them either; nothing under `packages/coffin_core/lib` imports `apps/`, `package:hauntagotchi` or `package:graveyard`; `apps/*/lib` files do not import each other's packages.
    - Config: `coffin_core/pubspec.yaml` pins `go_router: 17.5.0` exactly; neither app pubspec lists `go_router`; none lists `material_ui`, `cupertino_ui` or `url_strategy`; no file in `coffin_core/lib` imports `riverpod`, `hive` or an AI library.
    - Resolve repo paths relative to the test file location so the tests work from any working directory.
    - _Requirements: 1.7, 1.9, 4.1, 7.1, 7.2, 7.3, 7.6, 8.6, 8.7, 8.8, 9.3, 9.4, 9.6, 9.7, 10.7_

- [x] 7. Checkpoint - Core package verification
  - Run `dart format --set-exit-if-changed .`, `flutter analyze` and `flutter test` in `packages/coffin_core`. Fix anything that fails.
  - Ensure all tests pass, ask the user if questions arise.
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6_

- [x] 8. App wiring
  - [x] 8.1 Wire Hauntagotchi to the fog router
    - Read `apps/hauntagotchi/lib/main.dart`, `lib/src/ui/placeholder_screen.dart` and `test/ui/placeholder_screen_test.dart` first.
    - Create `apps/hauntagotchi/lib/src/ui/app_routes.dart` with a top-level `final List<AppRoute> appRoutes` holding one route: path `/`, name `home`, builder returning `const PlaceholderScreen()`.
    - Change `HauntagotchiApp` in `main.dart` to a `StatefulWidget`. Build the router once in state with `late final GoRouter _router = FogRouter.create(routes: appRoutes);`, dispose it in `dispose`, and return `MaterialApp.router(title: 'Hauntagotchi', theme: CoffinTheme.dark(), routerConfig: _router)`. `main()` stays `runApp(const HauntagotchiApp())`, with no URL-strategy call.
    - Import only `package:coffin_core/coffin_core.dart` for routing. Leave `PlaceholderScreen` unchanged.
    - Run `flutter analyze` in the app.
    - _Requirements: 7.1, 7.4, 8.1, 8.3, 8.5, 8.6, 8.7, 8.10_

  - [x] 8.2 Update and extend the Hauntagotchi tests
    - Edit `apps/hauntagotchi/test/ui/placeholder_screen_test.dart`: in the test that pumps `HauntagotchiApp`, add `await tester.pumpAndSettle();` after `pumpWidget` before finding `PlaceholderScreen`. Keep the theme assertions (`find.byType(MaterialApp)` still finds the `MaterialApp.router`; `app.theme` comparisons stay). Leave the other tests unchanged.
    - Create `apps/hauntagotchi/test/ui/app_routes_test.dart`: the app starts on the Home route and shows `PlaceholderScreen`; an unknown location shows `NotFoundPage` and its button returns to `PlaceholderScreen`. To reach an unknown location, pump `MaterialApp.router` with `FogRouter.create(routes: appRoutes, initialLocation: '/nowhere')`. Also assert `CoffinTheme.dark()` is still applied on the real `HauntagotchiApp`.
    - Run `flutter test` in the app.
    - _Requirements: 8.5, 8.11, 8.12, 10.3_

  - [x] 8.3 Wire Graveyard to the fog router
    - Same as 8.1 for `apps/graveyard`, with `GraveyardApp` and title `Graveyard`. Read the existing files first. Do not import anything from Hauntagotchi.
    - _Requirements: 7.2, 7.4, 8.2, 8.4, 8.5, 8.6, 8.7, 8.10_

  - [x] 8.4 Update and extend the Graveyard tests
    - Same as 8.2 for `apps/graveyard`: add `pumpAndSettle` to the existing app-root test, and create `apps/graveyard/test/ui/app_routes_test.dart` with the same checks.
    - Run `flutter test` in the app.
    - _Requirements: 8.5, 8.11, 8.12, 10.3_

- [x] 9. Final verification
  - [x] 9.1 Build both apps for web
    - Run `flutter build web` in `apps/hauntagotchi` and in `apps/graveyard`. Report success or the exact failure. Do not edit the design to work around a failure.
    - Confirm the generated `build/web/index.html` of each app has no `404.html` or rewrite-rule dependency, and that no `_redirects` or `.htaccess` file was added to the repo. `build/` is gitignored.
    - _Requirements: 7.6_

  - [x] 9.2 Tell the user how to check hash URLs by hand
    - Do not start a server (long-running). In the final message, give the exact commands to serve `apps/hauntagotchi/build/web` with a plain static server, and list the two URLs to open: the bare site URL (expect the home screen) and `/#/nowhere` (expect the not-found page with a working button).
    - State plainly that real address-bar behavior and the blur cost on CanvasKit were not verified by automated tests.
    - _Requirements: 7.4, 7.5, 7.6_

- [x] 10. Final checkpoint - Full workspace verification
  - Run `dart format --set-exit-if-changed .`, `flutter analyze` and `flutter test` in `packages/coffin_core`, `apps/hauntagotchi` and `apps/graveyard`. All must be clean and passing.
  - Run `flutter pub get` at the workspace root and confirm `go_router` 17.5.0 is the only new package in the lockfile resolution.
  - Confirm no secrets were added and no file outside the repository was created or edited.
  - Ensure all tests pass, ask the user if questions arise.
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8_

## Notes

- All tasks are required. Unit tests and property tests are required because the tech steering says pure logic and numeric invariants must be tested.
- Property tests use glados 1.1.7 (already a dev dependency of `coffin_core`) with at least 100 runs each and carry the property number from the design.
- Properties 1 to 7 from the design map to tasks 2.4 (1, 5), 2.5 (2, 4) and 2.6 (3, 6, 7).
- Tasks 4.1 and 4.3 are the first to import `go_router`/Flutter in `src/router/`. Tasks 2.1 and 2.2 must stay Flutter-free.
- The workflow ends once these tasks exist. Open `tasks.md` and start tasks from there. No implementation has been started.
