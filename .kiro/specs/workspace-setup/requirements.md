# Requirements Document

## Introduction

The Coffin monorepo is a spooky Flutter starter kit for the Kiroween 2026 hackathon. This feature establishes the initial scaffold: a Dart pub workspace at the repository root containing the `coffin_core` package and the `hauntagotchi` and `graveyard` apps. The scaffold provides a runnable, analytically clean starting point — a shared public API in `coffin_core`, a placeholder screen in each app that consumes one `coffin_core` export, shared `flutter_lints` configuration, and version-control hygiene that keeps the `.kiro` specs tracked.

This is a scaffolding task. It deliberately excludes feature implementations such as ghost-pet logic, séance scoring, the design-token theme, routing, storage, and the AI layer. Those land in later specs. The full application stack (Riverpod, go_router, hive_ce, the CoffinAI interface) is introduced by those feature specs, not by this scaffold. This scaffold is complete when `flutter analyze` reports zero issues and both apps run in Chrome.

## Glossary

- **Coffin**: the monorepo and starter kit project at the repository root.
- **Workspace**: the Dart pub workspace governed by the root `pubspec.yaml`, comprising all member packages and apps.
- **Root_Pubspec**: the `pubspec.yaml` at the repository root that declares the `workspace:` list.
- **Coffin_Core**: the reusable skeleton package located at `packages/coffin_core`.
- **Coffin_Core_Barrel**: the public export file `lib/coffin_core.dart`, importable as `package:coffin_core/coffin_core.dart`.
- **Hauntagotchi**: the ghost-pet Flutter app located at `apps/hauntagotchi`.
- **Graveyard**: the abandoned-projects Flutter app located at `apps/graveyard`.
- **Placeholder_Screen**: a minimal screen each app renders on launch that uses at least one symbol from the Coffin_Core_Barrel.
- **Analysis_Options**: the shared `analysis_options.yaml` at the repository root that applies `flutter_lints` across the Workspace.
- **Gitignore**: the `.gitignore` file at the repository root.

## Requirements

### Requirement 1: Dart Pub Workspace Configuration

**User Story:** As a Flutter developer, I want the repository root configured as a Dart pub workspace so that all packages and apps share one dependency-resolution context.

#### Acceptance Criteria

1. THE Root_Pubspec SHALL declare a `workspace:` list containing exactly `packages/coffin_core`, `apps/hauntagotchi`, and `apps/graveyard`.
2. THE Root_Pubspec SHALL constrain the Dart SDK to version 3.13 or a compatible higher version.
3. WHEN a member package declares a dependency on `coffin_core`, THE Workspace SHALL resolve that dependency from the local workspace path rather than the public package registry.

### Requirement 2: coffin_core Package Skeleton

**User Story:** As a developer, I want coffin_core to be a Flutter package with the prescribed source layout so that reusable code has a permanent home.

#### Acceptance Criteria

1. THE Coffin_Core SHALL be a Flutter package with a `lib/` directory and a `test/` directory.
2. THE Coffin_Core SHALL establish the source subdirectories `theme/`, `router/`, `storage/`, `ai/`, and `widgets/` under `lib/src/`, and each empty subdirectory SHALL contain a `.gitkeep` file so that Git tracks it.
3. THE Coffin_Core SHALL include a `test/` directory.

### Requirement 3: coffin_core Public API Surface

**User Story:** As a app developer, I want a single public export file in coffin_core so that I depend on a stable barrel import rather than internal files.

#### Acceptance Criteria

1. THE Coffin_Core SHALL expose its public API exclusively through the Coffin_Core_Barrel `package:coffin_core/coffin_core.dart`.
2. THE Coffin_Core_Barrel SHALL export at least one placeholder symbol that an app can use to render a Placeholder_Screen.

### Requirement 4: App Package Skeletons

**User Story:** As a developer, I want hauntagotchi and graveyard to be runnable Flutter apps with web enabled so that judges can open each app by URL.

#### Acceptance Criteria

1. THE Hauntagotchi SHALL be a Flutter app with a `lib/main.dart` entry point.
2. THE Graveyard SHALL be a Flutter app with a `lib/main.dart` entry point.
3. THE Hauntagotchi SHALL enable Flutter Web as a build target.
4. THE Graveyard SHALL enable Flutter Web as a build target.
5. THE Hauntagotchi SHALL declare a dependency on `coffin_core`.
6. THE Graveyard SHALL declare a dependency on `coffin_core`.
7. THE Hauntagotchi SHALL establish the source subdirectories `domain/`, `data/`, and `ui/` under `lib/src/`, and each empty subdirectory SHALL contain a `.gitkeep` file so that Git tracks it.
8. THE Graveyard SHALL establish the source subdirectories `domain/`, `data/`, and `ui/` under `lib/src/`, and each empty subdirectory SHALL contain a `.gitkeep` file so that Git tracks it.
9. THE Hauntagotchi and the Graveyard SHALL each include a `test/` directory.

### Requirement 5: Placeholder Screens

**User Story:** As a judge, I want each app to show a placeholder screen on launch so that I can confirm the app runs and uses the shared coffin_core API.

#### Acceptance Criteria

1. WHEN the Hauntagotchi launches, THE Hauntagotchi SHALL render a Placeholder_Screen that uses at least one symbol exported by the Coffin_Core_Barrel.
2. WHEN the Graveyard launches, THE Graveyard SHALL render a Placeholder_Screen that uses at least one symbol exported by the Coffin_Core_Barrel.

### Requirement 6: Import Boundaries

**User Story:** As a maintainer, I want strict import boundaries between layers so that coffin_core stays reusable and the apps stay decoupled.

#### Acceptance Criteria

1. THE Hauntagotchi and the Graveyard SHALL depend on Coffin_Core exclusively through the Coffin_Core_Barrel.
2. THE Coffin_Core SHALL depend only on its own sources and external packages, remaining independent of the Hauntagotchi and the Graveyard.
3. THE Hauntagotchi and the Graveyard SHALL remain mutually independent.

### Requirement 7: Shared Lint Configuration

**User Story:** As a developer, I want a shared analysis_options.yaml using flutter_lints across the workspace so that all packages and apps enforce the same style rules.

#### Acceptance Criteria

1. THE Analysis_Options SHALL apply the `flutter_lints` rules to every member package and app in the Workspace.
2. EACH member package and app SHALL have its own `analysis_options.yaml` that includes the shared root Analysis_Options via the `include:` directive, so that one ruleset governs the Workspace.

### Requirement 8: Version Control Hygiene

**User Story:** As a maintainer, I want a Flutter .gitignore that keeps the .kiro folder tracked so that specs, hooks, and steering stay versioned with the code.

#### Acceptance Criteria

1. THE Gitignore SHALL exclude standard Flutter build artifacts including `.dart_tool/` and `build/`.
2. THE Gitignore SHALL keep the `.kiro/` directory tracked by version control.

### Requirement 9: Static Analysis Verification

**User Story:** As a developer, I want the workspace to pass static analysis with zero issues so that the scaffold is clean and ready for feature work.

#### Acceptance Criteria

1. WHEN `flutter analyze` is run at the repository root, THE Workspace SHALL report zero issues.
2. WHEN `dart format` is run across the Workspace, THE Workspace SHALL require no formatting changes.

### Requirement 10: Web Execution

**User Story:** As a judge, I want both apps to run in Chrome so that I can test them by URL without installing anything.

#### Acceptance Criteria

1. WHEN the Hauntagotchi is launched with the web target in Chrome, THE Hauntagotchi SHALL start and render its Placeholder_Screen.
2. WHEN the Graveyard is launched with the web target in Chrome, THE Graveyard SHALL start and render its Placeholder_Screen.

### Requirement 11: Test Infrastructure

**User Story:** As a developer, I want the test infrastructure to work out of the box so that I can add unit and widget tests as features are built.

#### Acceptance Criteria

1. WHEN `flutter test` is run in each member directory (`packages/coffin_core`, `apps/hauntagotchi`, and `apps/graveyard`), THE Workspace SHALL execute all tests in that member with zero failures, because `flutter test` does not recurse into pub workspace members.
2. THE Coffin_Core, the Hauntagotchi, and the Graveyard SHALL each contain at least one passing test.
