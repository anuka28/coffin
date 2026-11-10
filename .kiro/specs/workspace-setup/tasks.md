# Implementation Plan: Workspace Setup

## Overview

This plan scaffolds the Coffin monorepo as a Dart pub workspace with one reusable package (`coffin_core`) and two Flutter web apps (`hauntagotchi`, `graveyard`). It follows the design's four-step approach: author root config files, hand-author `coffin_core`, generate each app's web shell with `flutter create --platforms web --no-pub` and overlay hand-authored files, then run the verification gates (`flutter pub get`, `flutter analyze`, `dart format`, `flutter test` per member). The scaffold is complete when analysis reports zero issues, formatting is clean, every member has a passing widget test, and both apps are web-launchable.

The design defines no Correctness Properties (the scaffold contains no pure logic or input-dependent behavior), so property-based testing does not apply. Verification uses example-based widget tests plus build/analysis gates.

## Tasks

- [x] 1. Author root workspace configuration files
  - [x] 1.1 Create the root `pubspec.yaml`
    - Declare `name: _`, `publish_to: none`, and an `environment.sdk` constraint of `^3.13.0`
    - Add a `workspace:` list containing exactly `packages/coffin_core`, `apps/hauntagotchi`, and `apps/graveyard`
    - Add `flutter_lints: ^6.0.0` under `dev_dependencies` so the root analysis context can resolve the `package:flutter_lints/flutter.yaml` include
    - _Requirements: 1.1, 1.2_
  - [x] 1.2 Create the root `analysis_options.yaml`
    - Include `package:flutter_lints/flutter.yaml`
    - Enable `strict-casts: true` and `strict-raw-types: true` under `analyzer.language`
    - Add `prefer_single_quotes: true` under `linter.rules`
    - _Requirements: 7.1_
  - [x] 1.3 Create the root `.gitignore`
    - Exclude Flutter build artifacts: `.dart_tool/`, `.flutter-plugins`, `.flutter-plugins-dependencies`, `build/`, `.pub-cache/`, `.pub/`, `coverage/`, platform build outputs (android/.gradle, ios/Pods, ios/Flutter), and OS/editor cruft (`.DS_Store`, `.idea/`)
    - Do not ignore `.kiro/`; add a comment stating it is intentionally tracked because specs, hooks, and steering live there
    - _Requirements: 8.1, 8.2_

- [x] 2. Build the coffin_core package skeleton
  - [x] 2.1 Create `packages/coffin_core/pubspec.yaml` and `analysis_options.yaml`
    - pubspec: `name: coffin_core`, `publish_to: none`, `version: 0.1.0`, SDK `^3.13.0`, `resolution: workspace`, `flutter` dependency, `flutter_test` + `flutter_lints` dev dependencies, `flutter.uses-material-design: true`
    - analysis_options: `include: ../../analysis_options.yaml`
    - _Requirements: 2.1, 7.2_
  - [x] 2.2 Create the public barrel and CoffinMark widget
    - `lib/coffin_core.dart`: `export 'src/widgets/coffin_mark.dart' show CoffinMark;` with a doc comment explaining apps must import only this barrel, never files under `src/`
    - `lib/src/widgets/coffin_mark.dart`: a `const CoffinMark` StatelessWidget rendering `Icon(Icons.nightlight_round, size: 64)`, a `SizedBox(height: 16)`, and `Text('Coffin')` in a centered `Column`; uses default Material styling only (no design tokens)
    - coffin_core must import only its own sources and external packages, never from an app
    - _Requirements: 2.2, 3.1, 3.2, 6.2_
  - [x] 2.3 Add `.gitkeep` files to empty src subdirectories
    - Create empty `.gitkeep` in `lib/src/theme/`, `lib/src/router/`, `lib/src/storage/`, and `lib/src/ai/`
    - `lib/src/widgets/` needs no `.gitkeep` because it already holds `coffin_mark.dart`
    - _Requirements: 2.2_
  - [x] 2.4 Write the widget test for CoffinMark
    - `test/widgets/coffin_mark_test.dart`: pump `CoffinMark` inside `MaterialApp`/`Scaffold`, then assert `CoffinMark`, exactly one `Icon`, and the text "Coffin" are found
    - _Requirements: 11.2_

- [x] 3. Scaffold the hauntagotchi app
  - [x] 3.1 Generate the web app shell with `flutter create`
    - Run `flutter create --platforms web --no-pub apps/hauntagotchi` to produce the `web/` directory (`index.html`, `manifest.json`, `icons/`) and a valid Flutter app shell with a `lib/main.dart` entry point
    - The `--no-pub` flag prevents a stray `pubspec.lock` and `.dart_tool/` in the app folder; `flutter pub get` runs once at the root later
    - _Requirements: 4.1, 4.3_
  - [x] 3.2 Replace `pubspec.yaml` and add `analysis_options.yaml`
    - pubspec: `name: hauntagotchi`, `publish_to: none`, `version: 0.1.0+1`, SDK `^3.13.0`, `resolution: workspace`, `flutter` dependency, `coffin_core` path dependency at `../../packages/coffin_core`, `flutter_test` + `flutter_lints` dev dependencies, `flutter.uses-material-design: true`
    - analysis_options: `include: ../../analysis_options.yaml`
    - The pubspec must not reference graveyard, keeping the apps mutually independent
    - _Requirements: 4.5, 6.3, 7.2_
  - [x] 3.3 Author `main.dart` and `placeholder_screen.dart`
    - `lib/main.dart`: `HauntagotchiApp` StatelessWidget whose `build` returns `const MaterialApp(title: 'Hauntagotchi', home: PlaceholderScreen())`; imports ordered as `package:coffin_core/coffin_core.dart`, `package:flutter/material.dart`, then the relative `src/ui/placeholder_screen.dart`
    - `lib/src/ui/placeholder_screen.dart`: `PlaceholderScreen` rendering `const Scaffold(body: Center(child: CoffinMark()))`, consuming the shared `CoffinMark` symbol from the barrel only
    - _Requirements: 5.1, 6.1_
  - [x] 3.4 Add `.gitkeep` files and remove generated artifacts
    - Create empty `.gitkeep` in `lib/src/domain/` and `lib/src/data/`
    - Remove the generated counter test `test/widget_test.dart` (replaced by 3.5) and the app-level `.gitignore` in favor of the root one
    - Also delete `apps/hauntagotchi/pubspec.lock` (workspace members must not have their own lockfile) and the generated `*.iml` file(s) in the app
    - Add `*.iml` to the root `.gitignore` (shared with 4.4; do it once)
    - _Requirements: 4.7_
  - [x] 3.5 Write the widget test for the placeholder screen
    - `test/ui/placeholder_screen_test.dart`: import `package:hauntagotchi/src/ui/placeholder_screen.dart`, pump `PlaceholderScreen` inside `MaterialApp`, then assert `PlaceholderScreen` and `CoffinMark` are found and the text "Coffin" appears
    - _Requirements: 4.9, 11.2_

- [x] 4. Scaffold the graveyard app
  - [x] 4.1 Generate the web app shell with `flutter create`
    - Run `flutter create --platforms web --no-pub apps/graveyard` to produce the `web/` directory and a valid Flutter app shell with a `lib/main.dart` entry point
    - _Requirements: 4.2, 4.4_
  - [x] 4.2 Replace `pubspec.yaml` and add `analysis_options.yaml`
    - Same shape as 3.2 with `name: graveyard`, a description for the abandoned-projects app, `version: 0.1.0+1`, SDK `^3.13.0`, `resolution: workspace`, `coffin_core` path dependency at `../../packages/coffin_core`, `flutter_test` + `flutter_lints` dev dependencies, `flutter.uses-material-design: true`
    - analysis_options: `include: ../../analysis_options.yaml`
    - The pubspec must not reference hauntagotchi, keeping the apps mutually independent
    - _Requirements: 4.6, 6.3, 7.2_
  - [x] 4.3 Author `main.dart` and `placeholder_screen.dart`
    - `lib/main.dart`: `GraveyardApp` StatelessWidget whose `build` returns `const MaterialApp(title: 'Graveyard', home: PlaceholderScreen())`; imports ordered as `package:coffin_core/coffin_core.dart`, `package:flutter/material.dart`, then the relative `src/ui/placeholder_screen.dart`
    - `lib/src/ui/placeholder_screen.dart`: structurally identical to hauntagotchi's, rendering `const Scaffold(body: Center(child: CoffinMark()))`
    - _Requirements: 5.2, 6.1_
  - [x] 4.4 Add `.gitkeep` files and remove generated artifacts
    - Create empty `.gitkeep` in `lib/src/domain/` and `lib/src/data/`
    - Remove the generated counter test `test/widget_test.dart` (replaced by 4.5) and the app-level `.gitignore` in favor of the root one
    - Also delete `apps/graveyard/pubspec.lock` (workspace members must not have their own lockfile) and the generated `*.iml` file(s) in the app
    - Ensure `*.iml` is in the root `.gitignore` (added in 3.4 if not already present)
    - _Requirements: 4.8_
  - [x] 4.5 Write the widget test for the placeholder screen
    - `test/ui/placeholder_screen_test.dart`: import `package:graveyard/src/ui/placeholder_screen.dart`, pump `PlaceholderScreen` inside `MaterialApp`, then assert `PlaceholderScreen` and `CoffinMark` are found and the text "Coffin" appears
    - _Requirements: 4.9, 11.2_

- [x] 5. Checkpoint - Resolve dependencies and run static analysis
  - Run `flutter pub get` at the repository root to produce the shared `pubspec.lock` and `.dart_tool/package_config.json`
  - Run `flutter analyze` at the repository root; it must report zero issues across all members
  - Ensure all tests pass, ask the user if questions arise.
  - _Requirements: 1.3, 9.1_

- [x] 6. Final verification - Formatting, tests, and web readiness
  - [x] 6.1 Run `dart format --set-exit-if-changed .` at the root and fix any files it reports
    - _Requirements: 9.2_
  - [x] 6.2 Run `flutter test` in each member directory (`packages/coffin_core`, `apps/hauntagotchi`, `apps/graveyard`); each must pass with zero failures
    - Pub workspaces do not recurse tests into members, so run the command inside each member directory
    - _Requirements: 11.1, 11.2_
  - [x] 6.3 Verify each app's `web/` directory contains `index.html`, `manifest.json`, and `icons/` so Chrome launch is supported
    - Actual Chrome launch is a manual step for judges (a long-running command); the widget tests already confirm the placeholder screens render
    - _Requirements: 10.1, 10.2_

## Notes

- All test tasks (2.4, 3.5, 4.5) are required since Requirement 11 mandates a passing test in every member.
- Each task references specific acceptance criteria for traceability.
- The design defines no Correctness Properties, so no property-based tests are included; verification uses widget tests and build/analysis gates.
- `flutter create --platforms web --no-pub` is used for both apps per the approved implementation note, so `flutter pub get` runs once at the workspace root.
- Checkpoints ensure incremental validation; the final verification task is the scaffold's acceptance gate.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3", "2.1", "3.1", "4.1"] },
    { "id": 1, "tasks": ["2.2", "2.3", "3.2", "3.4", "4.2", "4.4"] },
    { "id": 2, "tasks": ["2.4", "3.3", "4.3"] },
    { "id": 3, "tasks": ["3.5", "4.5"] },
    { "id": 4, "tasks": ["6.1"] },
    { "id": 5, "tasks": ["6.2", "6.3"] }
  ]
}
```
