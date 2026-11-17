# Requirements Document

## Introduction

The raise-app feature adds a generator, `dart run tool/raise.dart <app_name>`, that creates a new Flutter app on the Coffin skeleton in one command. The generator lives in `tool/`, which becomes a small pub workspace package named `coffin_raise`. It is pure Dart, runs from the repo root, and takes a developer from nothing to a running, themed app in minutes. The new app lives in `apps/<app_name>/`, is modelled on `apps/hauntagotchi` without any Hauntagotchi-specific names or copy, joins the pub workspace, and carries its own `.kiro/` folder (steering, hook, README) so Kiro knows the house rules from the first prompt. The generator validates the app name, refuses with a helpful and slightly spooky message on any error, never overwrites anything, and changes nothing on failure. All files it writes come from one template folder in the repo, which is the single source of truth. The generator takes a target root path so tests can run it against a temporary copy and never touch the real repo. The design language is "Haunted, not horror", as defined in the design steering document.

## Dependency Notice

This feature adds **no new third-party package**. The generator uses only `dart:io`, `dart:convert` and `dart:core`. The feature adds one new workspace package, `coffin_raise` (`tool/pubspec.yaml`), and one `tool` entry in the `workspace:` list of the root `pubspec.yaml`. The `coffin_raise` dev dependencies are limited to `flutter_test` and `glados`, which `coffin_core` already uses and `pubspec.lock` already contains, so `pubspec.lock` gains no new package. When the generator raises an app, its only `pubspec.yaml` edit is adding one Workspace_Entry to the root `pubspec.yaml`. The pubspecs of `coffin_core`, Hauntagotchi and Graveyard stay unchanged.

## Glossary

- **Raise_Package**: The workspace package `coffin_raise` in `tool/`, defined by `tool/pubspec.yaml` (`name: coffin_raise`, `publish_to: none`, `resolution: workspace`, the same SDK constraint as the root `pubspec.yaml`). It holds the Raise_Tool, the Raiser, the Template_Folder and the tests of the generator.
- **Tool_Workspace_Entry**: The line `  - tool` in the `workspace:` list of the root `pubspec.yaml`, added once by this feature. It is separate from the Workspace_Entry that the Raiser adds for each Raised_App.
- **Raise_Tool**: The command-line entry point `tool/raise.dart` in the Raise_Package. It reads arguments, calls the Raiser, prints the result and sets the exit code.
- **Raiser**: The pure Dart library behind the Raise_Tool that validates, plans and writes. It takes a Target_Root and an app name and does no reading of `stdin` or global state.
- **Target_Root**: The directory the Raiser treats as the repo root. The Raise_Tool passes the current directory. Tests pass a temporary directory.
- **App_Name**: The `<app_name>` argument. It becomes the Dart package name and the folder name under `apps/`.
- **Name_Validator**: The pure Dart logic that decides whether an App_Name is acceptable and returns a reason when it is not.
- **Template_Folder**: The single folder `tool/templates/app/` that holds every file the Raiser writes, with placeholders for the app-specific values. See Requirement 3.
- **Placeholder**: A marker in a template file that the Raiser replaces with an app-specific value.
- **Display_Name**: The human-readable title derived from the App_Name (for example `bone_shop` gives `Bone Shop`). It is used in the app title, the web manifest and the home screen copy.
- **Raise_Plan**: The full list of files and the workspace edit that the Raiser intends to make, computed before anything is written.
- **Raised_App**: The folder `apps/<app_name>/` as created by the Raiser.
- **Workspace_Entry**: The line `  - apps/<app_name>` in the `workspace:` list of the root `pubspec.yaml`.
- **App_Kiro_Folder**: The folder `apps/<app_name>/.kiro/` created inside the Raised_App.
- **Starter_Home**: The Raised_App's home screen, shown at route `/`.
- **Raise_Check_Test**: The test, tagged `raise-check`, that raises an app into a temporary copy of the repo and runs `flutter analyze` and `flutter test` on it.
- **Exit_Codes**: The sysexits values used by the Raise_Tool: 0 success, 64 usage error, 65 bad input, 74 I/O error.

## Requirements

### Requirement 1: One command raises a new app

**User Story:** As a Flutter developer using Coffin, I want one command that creates a ready-to-run app, so that I can start building my idea instead of wiring up the skeleton.

#### Acceptance Criteria

1. WHEN the developer runs `dart run tool/raise.dart <app_name>` from the repo root with a valid App_Name, THE Raise_Tool SHALL create the Raised_App, add the Workspace_Entry, print a success message and exit with code 0.
2. THE success message SHALL name the created folder and print the next commands to run (resolve dependencies, run the app in Chrome, run its tests), each as a copyable line.
3. THE Raise_Tool SHALL need no network access, no API key and no input from `stdin`.
4. WHEN the Raise_Tool is run with no argument, more than one argument, or `--help`, THE Raise_Tool SHALL print a short usage message with an example and exit with code 64 for a missing or extra argument, and 0 for `--help`.
5. WHEN a Raised_App has been created and the developer runs `flutter pub get` at the repo root, THE workspace SHALL resolve without edits to any file, except that `pubspec.lock` MAY change, and only through `flutter pub get` itself.
6. WHEN the developer runs `flutter run -d chrome` inside the Raised_App, THE app SHALL launch and show the Starter_Home in the dark Coffin theme.
7. WHEN the Raise_Tool is run with `--help`, THE Raise_Tool SHALL list every code of the Exit_Codes with its meaning in the usage message.
8. THE success message SHALL include the exact line `Open apps/<app_name> in Kiro to load its steering`, with `<app_name>` replaced by the real App_Name, because the App_Kiro_Folder takes effect only when `apps/<app_name>` is opened as its own folder in Kiro, while opening the repo root loads the root `.kiro/` instead.
9. A test SHALL fail WHEN the success message for any valid App_Name lacks the line of criterion 8 with that App_Name.

### Requirement 2: App name validation

**User Story:** As a Flutter developer, I want a bad app name rejected with a clear reason, so that I fix it once instead of debugging a broken package.

#### Acceptance Criteria

1. THE Name_Validator SHALL accept an App_Name only if it matches the Dart package rules: it starts with a lowercase letter `a-z`, contains only lowercase letters, digits and underscores, and has no leading, trailing or doubled underscores.
2. THE Name_Validator SHALL reject an App_Name that is a Dart reserved word or built-in identifier that cannot be used as a package name (for example `class`, `new`, `var`, `import`, `void`).
3. THE Name_Validator SHALL reject an App_Name that is also the name of an existing workspace package, including `coffin_core` and `coffin_raise`, because two workspace members cannot share a name.
   - **Approved extension:** THE Name_Validator SHALL also reject an App_Name that equals one of a fixed set of reserved package names that the Raised_App or the workspace depends on (`flutter`, `flutter_test`, `flutter_lints`, `go_router`, `hive_ce`, `hive_ce_flutter`, `meta`, `glados`, `test`), because a package cannot share a name with its own dependency. The set is defined in `design.md`.
4. THE Name_Validator SHALL reject an App_Name longer than 64 characters.
5. THE Name_Validator SHALL reject an empty App_Name and an App_Name that contains a path separator, a dot, whitespace, or a non-ASCII character.
6. THE Name_Validator SHALL reject an App_Name whose folder `apps/<app_name>` already exists under the Target_Root, whether it is a directory, a file or a symbolic link.
7. WHEN the App_Name is rejected, THE Raise_Tool SHALL print a message that states the reason, suggests a valid alternative where one can be derived (for example `Bone-Shop` suggests `bone_shop`), uses short and slightly spooky wording that is never mean to the user, writes it to `stderr`, and exits with code 65.
8. THE Name_Validator SHALL be pure Dart with no `dart:io` use, so its rules are testable without a file system.

### Requirement 3: Single source of truth for templates

**User Story:** As a Coffin maintainer, I want every generated file to come from one folder, so that I update the starter in one place and the generator cannot drift from it.

#### Acceptance Criteria

1. THE repo SHALL hold all file contents the Raiser writes in exactly one Template_Folder, located at `tool/templates/app/`, so that it is never mistaken for a workspace member.
2. THE Raiser SHALL contain no file content of its own. Every byte it writes into the Raised_App SHALL come from the Template_Folder, after Placeholder replacement.
3. THE Template_Folder SHALL define its Placeholders in one documented list that includes at least the package name, the Display_Name and the class-name form of the App_Name.
4. THE Raiser SHALL replace every Placeholder in every text file and in every file path of the Template_Folder.
5. IF a text file in the Template_Folder uses a Placeholder that the Raiser does not define, THEN THE Raiser SHALL fail before writing anything and name the file and the Placeholder.
6. WHEN a file in the Template_Folder is binary (for example an icon), THE Raiser SHALL copy its bytes unchanged.
7. THE Template_Folder SHALL be excluded from `flutter analyze` (through `tool/analysis_options.yaml`) and from the repo's `dart format` command, so that template files containing Placeholders produce no warnings or format changes. The design phase SHALL choose the mechanics.
8. A test SHALL fail WHEN the Template_Folder contains a Hauntagotchi-specific or Graveyard-specific name or copy (for example `Hauntagotchi`, `hauntagotchi`, `Graveyard`, `habit`, `séance`).

### Requirement 4: Contents of the Raised_App

**User Story:** As a Flutter developer, I want the new app to be wired to the skeleton and look haunted from the first run, so that I see the theme, router and widgets working before I write any code.

#### Acceptance Criteria

1. THE Raised_App SHALL contain `pubspec.yaml`, `analysis_options.yaml`, `web/index.html`, `web/manifest.json`, the web icons and favicon, `lib/main.dart`, the Starter_Home and its route list under `lib/src/ui/`, a widget test under `test/`, and the App_Kiro_Folder.
2. THE Raised_App `pubspec.yaml` SHALL set `name` to the App_Name, `publish_to: none`, `resolution: workspace`, the same SDK constraint as the root `pubspec.yaml`, a dependency on `coffin_core` by relative path `../../packages/coffin_core`, `flutter_test` and `flutter_lints` as dev dependencies at the versions Hauntagotchi uses, and no other dependency.
3. THE Raised_App `analysis_options.yaml` SHALL include the root `analysis_options.yaml` and exclude `build/**` and `web/**`, like Hauntagotchi.
4. THE Raised_App `web/index.html` and `web/manifest.json` SHALL carry the Display_Name as title, app name and short name, and SHALL NOT contain the name of any other app.
5. THE Raised_App `lib/main.dart` SHALL run an app root widget that builds its `GoRouter` once with `FogRouter.create(routes: appRoutes)`, uses `MaterialApp.router` with `CoffinTheme.dark()`, and disposes the router, following the pattern of Hauntagotchi.
6. THE Raised_App route list SHALL declare its routes as `AppRoute` values, with the Starter_Home at `/` named `home`.
7. THE Starter_Home SHALL show `FogBackground`, a `GhostLoader`, and at least one `TombstoneCard` that tells the developer where to start (for example which file to edit to add a screen).
8. THE Starter_Home SHALL follow the design steering: copy that is short, witty and slightly spooky, 16 px rounded surfaces, a semantic label on each interactive element, a tap target of at least 48×48, and a static state in place of loops when `MediaQuery.disableAnimations` is true.
9. THE Raised_App SHALL import only `package:coffin_core/coffin_core.dart` from the skeleton and SHALL NOT import any file under `src/` of `coffin_core`, and SHALL NOT import from any other app.
10. THE Raised_App widget test SHALL pump the app root and assert that the Starter_Home is shown, and SHALL pass with `flutter test` as generated, with no edits.
11. THE Raised_App code SHALL pass `dart format --set-exit-if-changed` and `flutter analyze` with zero warnings as generated, and every public class SHALL carry a doc comment.
12. THE Raised_App SHALL contain no API key, secret or token, and no font or other asset beyond those the generated app already gets from `coffin_core` and the web icons copied from the Template_Folder. Every asset in the Template_Folder SHALL have its license recorded in `CREDITS.md`.

### Requirement 5: Kiro configuration in the Raised_App

**User Story:** As a developer starting a new app with Kiro, I want the house rules and a clear first step already in the app, so that Kiro generates code that fits Coffin from the first spec.

#### Acceptance Criteria

1. THE App_Kiro_Folder SHALL contain `steering/product.md`, `steering/tech.md`, `steering/structure.md` and `steering/design.md`, plus `hooks/` with the format and analyze hook, plus a `README.md`.
2. THE `steering/product.md` SHALL be a fill-in template for the new app's idea. It SHALL contain headings for the app's name, what it is, who it is for, product principles, and hard rules, each with a short prompt in place of content, and the Display_Name where the app's name goes.
3. THE `steering/product.md` SHALL NOT contain the product description of Coffin, Hauntagotchi or Graveyard.
4. THE `steering/tech.md` SHALL be adapted from the repo's own `tech.md`: the same stack, code style, testing rules and dependency rule, with the monorepo wording adjusted so the paths and the "two apps" wording match a single app that depends on `coffin_core`.
5. THE `steering/structure.md` SHALL describe the Raised_App's own layout (`lib/main.dart`, `lib/src/domain|data|ui`, `test/` mirroring `lib/`) and the import rules that apply to it: import only `package:coffin_core/coffin_core.dart`, never `src/`, and never another app.
6. THE `steering/design.md` SHALL carry the "Haunted, not horror" design language of the repo's own `design.md` without change to colors, typography, motion, components or tone.
7. THE hook file SHALL run `dart format` and `flutter analyze` on save of a Dart file, with paths and commands that work from inside the Raised_App folder.
8. THE `README.md` in the App_Kiro_Folder SHALL explain, in under one page, how to write the first spec: fill in `product.md`, ask Kiro for a spec, review requirements, design and tasks in order, and run tasks one at a time. It SHALL name the folder where specs go.
10. THE first line of the "how to start" steps in the App_Kiro_Folder `README.md` (from `README.md.tmpl`) SHALL be exactly `Open this app's folder in Kiro so it loads this .kiro/`, because the App_Kiro_Folder takes effect only when `apps/<app_name>` is opened as its own folder in Kiro.
11. A test SHALL fail WHEN the first "how to start" step of `README.md.tmpl` differs from the line of criterion 10.
9. THE adapted steering files SHALL be produced from the Template_Folder (Requirement 3). THE Template_Folder `design.md` SHALL be a byte-for-byte copy of the repo's `.kiro/steering/design.md`, and a test SHALL fail WHEN the two files differ in any byte, so the two cannot drift apart silently.

### Requirement 6: Workspace registration

**User Story:** As a Flutter developer, I want the new app to join the pub workspace automatically, so that `flutter pub get` at the root just works.

#### Acceptance Criteria

1. WHEN the Raiser creates a Raised_App, THE Raiser SHALL add the Workspace_Entry as the last item of the `workspace:` list of the root `pubspec.yaml`.
2. THE Raiser SHALL leave every other byte of the root `pubspec.yaml` unchanged, including comments, ordering and line endings.
3. IF the root `pubspec.yaml` is missing, has no `workspace:` list, or already lists `apps/<app_name>`, THEN THE Raiser SHALL refuse with a message that states the problem, write nothing, and exit with code 65.
4. WHEN the root `pubspec.yaml` uses Windows line endings, THE Raiser SHALL write the Workspace_Entry with the same line ending.
5. THE Raiser SHALL NOT edit `pubspec.lock`, the pubspec of `coffin_core`, or the pubspec of any existing app.

### Requirement 7: Safe writes and no overwrites

**User Story:** As a Flutter developer, I want the generator never to damage my repo, so that I can run it without fear.

#### Acceptance Criteria

1. THE Raiser SHALL compute the full Raise_Plan and run every check (name, existing paths, template integrity, root `pubspec.yaml`) before writing any file.
2. THE Raiser SHALL NOT overwrite, delete, truncate or modify any existing file or folder, except for the single append to the root `pubspec.yaml` described in Requirement 6.
3. THE Raiser SHALL create `apps/<app_name>/` exclusively. WHEN the folder appears between the check and the write, THE Raiser SHALL stop and treat it as an existing-folder error.
4. IF any write fails part-way (for example a full disk or a permission error), THEN THE Raiser SHALL remove only the files and folders it created in this run, restore the root `pubspec.yaml` to its original bytes if it was already edited, print a message that says nothing was changed, and exit with code 74.
5. THE Raiser SHALL write the root `pubspec.yaml` change last, after every file of the Raised_App has been written.
6. WHEN the Raiser exits with any non-zero code, THE Target_Root SHALL be byte-for-byte identical to its state before the run.
7. THE Raiser SHALL only write paths that resolve inside `<Target_Root>/apps/<app_name>/` and the root `pubspec.yaml`, and SHALL reject any template path that would resolve elsewhere.

### Requirement 8: Testability against a throwaway root

**User Story:** As a Coffin maintainer, I want to test the generator without touching the real repo, so that tests are safe and repeatable.

#### Acceptance Criteria

1. THE Raiser SHALL take the Target_Root as an explicit parameter and SHALL NOT read the current directory or any absolute path of the real repo on its own.
2. THE Raiser SHALL locate the Template_Folder relative to a path it is given (defaulting, in the Raise_Tool, to the Template_Folder of the repo that contains the tool), so tests can pass a fixture template.
3. THE Raiser SHALL return a result value (success with the list of created paths, or failure with an error kind and message) and SHALL NOT call `exit` or print itself. Only the Raise_Tool prints and exits.
4. THE tests SHALL create every Target_Root in a unique temporary directory and delete it afterwards, including when a test fails.
5. THE tests SHALL NOT create, modify or delete anything under the real `apps/`, `packages/` or root `pubspec.yaml`. A test SHALL assert that the real repo is unchanged (checked by comparing file listings and hashes of the real `apps/` and root `pubspec.yaml` before and after the test run).
6. THE tests of the generator SHALL live in `tool/test/`, mirroring the `tool/lib/` folder structure, and SHALL use only `flutter_test` and `glados`.
7. THE Name_Validator, the Placeholder replacement, the workspace-entry edit and the display-name derivation SHALL be pure functions or pure classes with unit tests, and the name rules and the replacement SHALL also get property-based tests with glados where they have invariants.

### Requirement 9: Proof that a raised app is healthy

**User Story:** As a Coffin maintainer, I want an automated proof that a freshly raised app works, so that a template change cannot silently break the promise of the starter kit.

#### Acceptance Criteria

1. THE Raise_Check_Test SHALL copy what a raise needs (the root `pubspec.yaml`, `analysis_options.yaml`, `packages/coffin_core` and the Template_Folder) into a temporary directory, raise an app there, run `flutter pub get`, `flutter analyze` and `flutter test` inside the Raised_App, and assert that each exits with code 0.
2. THE Raise_Check_Test SHALL assert that `flutter analyze` reports no issues of any severity, including infos.
3. THE Raise_Check_Test SHALL also run `dart format --set-exit-if-changed` on the Raised_App and assert exit code 0.
4. THE Raise_Check_Test SHALL delete its temporary directory when it ends, whether it passed or failed.
5. THE Raise_Check_Test SHALL use the repo's pinned Flutter and Dart SDK and SHALL NOT need network access beyond what `flutter pub get` already needs for the packages in the existing lock file.
6. WHEN the Raise_Check_Test runs, THE copy of the repo it uses SHALL NOT include `apps/hauntagotchi` or `apps/graveyard`, and the temporary workspace SHALL list only the packages that exist in the copy.
7. THE Raise_Check_Test SHALL carry the test tag `raise-check`, and the repo's test configuration SHALL skip that tag in a normal `flutter test` run.
8. WHEN the developer runs exactly `flutter test --tags raise-check --run-skipped` in the Raise_Package, THE Raise_Check_Test SHALL run. The maintainer SHALL run it at the final checkpoint of the feature and in the nightly build job.

### Requirement 10: Documentation

**User Story:** As a Flutter developer reading the README, I want to find the command in one short section, so that I can raise my first app right away.

#### Acceptance Criteria

1. THE root `README.md` SHALL gain one short section named for raising an app. It SHALL show the command with an example name, state what it creates in one sentence, state the name rules in one sentence, show how to run the new app, and state in one sentence that the developer must open `apps/<app_name>` in Kiro to load its steering, because opening the repo root loads the root `.kiro/` instead.
2. THE section, including the Kiro sentence of criterion 1, SHALL stay under 15 lines, excluding code blocks.
3. THE section SHALL NOT change any other section of the README except the repo layout listing, which SHALL gain the `tool/` folder and the Template_Folder.
4. THE feature SHALL NOT edit the root `DIARY.md`, and THE feature SHALL update the root `CREDITS.md` only WHEN the work adds a new asset.

### Requirement 11: Repo boundaries

**User Story:** As a Coffin maintainer, I want the generator to respect the repo's rules, so that the skeleton stays clean.

#### Acceptance Criteria

1. THE feature SHALL NOT change any file under `apps/hauntagotchi`, `apps/graveyard` or `packages/coffin_core`.
2. THE feature SHALL change the root `pubspec.yaml` only by adding the Tool_Workspace_Entry, and the generator SHALL change it afterwards only by adding one Workspace_Entry per raised app.
3. THE feature SHALL add exactly one new pubspec, `tool/pubspec.yaml` for the Raise_Package, SHALL add no package to any other `pubspec.yaml`, and SHALL leave `pubspec.lock` with no new package.
4. THE `tool/` code SHALL pass `dart format` and `flutter analyze` with zero warnings, and every public API in it SHALL carry a doc comment.
5. THE Raise_Tool SHALL contain no Hauntagotchi-specific or Graveyard-specific name or copy.
6. THE Raise_Tool and the Raiser SHALL be readable in one sitting: no code generation, no reflection, and no template engine beyond plain Placeholder replacement.
