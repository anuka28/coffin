# Implementation Plan: raise-app

## Overview

Build the `coffin_raise` workspace package in `tool/` (Dart), bottom-up: pure rules first (names, placeholders, workspace edit, planner), then the template folder, then the disk layer (`FileOps`, `PlanWriter`, `Raiser`), then the CLI and entry point. Property-based tests (glados) sit next to the code they check. The slow `raise-check` test and the docs come last. Nothing under `apps/hauntagotchi`, `apps/graveyard` or `packages/coffin_core` is changed.

## Tasks

- [x] 1. Set up the `tool` package and re-verify it in the real repo
  - [x] 1.1 Create the `coffin_raise` package and verify workspace resolution
    - Create `tool/pubspec.yaml` (`name: coffin_raise`, `publish_to: none`, `resolution: workspace`, SDK constraint equal to the root's, dev dependencies `flutter_test`, `flutter_lints: ^6.0.0`, `glados: 1.1.7`)
    - Create `tool/analysis_options.yaml` (include `../analysis_options.yaml`, exclude `templates/**`), `tool/dart_test.yaml` (tag `raise-check` with `skip` message and a longer timeout), and a minimal stub `tool/raise.dart` (`void main() {}`) so `dart run` can be checked
    - Add `  - tool` as the last item of the `workspace:` list in the root `pubspec.yaml`, changing nothing else
    - Run `flutter pub get` at the repo root and confirm it resolves; run `git diff --stat pubspec.lock` and confirm the lock file is unchanged (no new package)
    - Run `dart run tool/raise.dart` from the repo root and confirm it starts; run `flutter test` in `tool/` and confirm it runs (no tests yet is fine)
    - Confirm `git status` shows no change under `apps/` or `packages/`
    - _Requirements: 9.7, 11.2, 11.3, Dependency Notice_

  - [x] 1.2 Add shared test support helpers
    - Create `tool/test/support/temp_root.dart` (`tempRoot()` creates a unique temp dir and registers deletion with `addTearDown`)
    - Create `tool/test/support/fnv_hash.dart` (64-bit FNV-1a hash of bytes); add only helpers the next tasks use
    - _Requirements: 8.4, 8.5_

- [x] 2. Implement name rules (pure)
  - [x] 2.1 Implement `NameValidator`, `NameIssue`, `NameIssueKind`, `NameSuggester`, `DisplayNames`, and the reserved-word list
    - Files under `tool/lib/src/names/`; no `dart:io`; doc-comment every public API
    - Include the fixed reserved package-name set (`coffin_core`, `coffin_raise`, `flutter`, `flutter_test`, `flutter_lints`, `go_router`, `hive_ce`, `hive_ce_flutter`, `meta`, `glados`, `test`)
    - Check order: empty, too long (over 64), bad characters, bad start, bad underscore, reserved word, taken name, folder exists
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 3.3_

  - [x] 2.2 Write property test for name validation
    - **Property 1: Name validation matches the package-name rules**
    - **Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6**
    - File: `tool/test/names/name_validator_property_test.dart`

  - [x] 2.3 Write property test for name suggestions
    - **Property 2: A suggestion is always a valid name**
    - **Validates: Requirements 2.7**
    - File: `tool/test/names/name_suggester_property_test.dart`

  - [x] 2.4 Write property test for derived names
    - **Property 3: Derived names are well formed**
    - **Validates: Requirements 3.3, 4.4**
    - File: `tool/test/names/display_names_property_test.dart`

  - [x] 2.5 Write unit tests for name rules
    - Every reserved word is rejected; `Bone-Shop` suggests `bone_shop`; examples for empty, 65 characters, dots, separators, non-ASCII, `coffin_core`, `flutter_test`
    - _Requirements: 2.2, 2.3, 2.4, 2.5, 2.7_

- [x] 3. Implement template loading and placeholder rendering
  - [x] 3.1 Implement `Placeholders`, `PlaceholderRenderer`, `RenderOutcome`, `TemplateFile` and `TemplateLoader`
    - Files under `tool/lib/src/template/`
    - `Placeholders.known` is the one documented list: `package_name`, `display_name`, `class_name`, `sdk_constraint`
    - Single-pass replacement with `\{\{([a-z_]+)\}\}`; `.tmpl` files are text (suffix dropped on output), all other files are binary and copied unchanged; placeholders are also replaced in path segments
    - Loader returns files sorted by path and throws `FileSystemException` on I/O failure
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 11.6_

  - [x] 3.2 Write property test for rendering
    - **Property 5: Rendering replaces every known placeholder and preserves everything else**
    - **Validates: Requirements 3.2, 3.4, 3.6**
    - File: `tool/test/template/placeholder_renderer_property_test.dart`

  - [x] 3.3 Write unit tests for the loader and renderer
    - Sorted load order, binary bytes unchanged, placeholder in a path segment, unknown key returns `UnknownPlaceholder`
    - _Requirements: 3.4, 3.5, 3.6_

- [x] 4. Implement the workspace editor (pure)
  - [x] 4.1 Implement `WorkspaceEditor` and `WorkspaceEditResult`
    - Files under `tool/lib/src/workspace/`; line-based, no YAML parser
    - `addApp`, `sdkConstraint`, `entries`; keep line endings (LF and CRLF) and the end-of-file state; `noWorkspaceList` and `alreadyListed` problems (plain, quoted and commented entries)
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [x] 4.2 Write property tests for the workspace edit
    - **Property 8: Workspace edit adds exactly one last line and nothing else**
    - **Property 9 (editor part): Workspace edit refuses unusable files**
    - **Validates: Requirements 6.1, 6.2, 6.3, 6.4**
    - File: `tool/test/workspace/workspace_editor_property_test.dart`

  - [x] 4.3 Write unit tests for the workspace editor
    - The real root `pubspec.yaml` text gains exactly one line; CRLF example; file with no final newline; missing `sdk:` returns null
    - _Requirements: 6.1, 6.2, 6.4_

- [x] 5. Create the Template_Folder
  - [x] 5.1 Create the app templates in `tool/templates/app/`
    - `pubspec.yaml.tmpl`, `analysis_options.yaml.tmpl`, `web/index.html.tmpl`, `web/manifest.json.tmpl`, `lib/main.dart.tmpl`, `lib/src/ui/app_routes.dart.tmpl`, `lib/src/ui/home_screen.dart.tmpl`, `test/ui/home_screen_test.dart.tmpl`
    - Copy `favicon.png` and the four icons from `apps/hauntagotchi/web/` as binary files (copy only; do not edit Hauntagotchi)
    - Model on Hauntagotchi (`FogRouter.create(routes: appRoutes)` built once and disposed, `MaterialApp.router` with `CoffinTheme.dark()`), with no Hauntagotchi or Graveyard names or copy
    - Starter home: `FogBackground`, `GhostLoader`, a `TombstoneCard` with a semantic label that says to edit `lib/src/ui/app_routes.dart`; tap targets at least 48×48; short, spooky copy; doc comment on every public class; code formatted as `dart format` would
    - Widget test pumps the app with `pump(Duration)` (no `pumpAndSettle`) and also covers `disableAnimations: true`
    - Use only the placeholders in `Placeholders.known`
    - _Requirements: 3.1, 3.2, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 4.10, 4.11, 4.12_

  - [x] 5.2 Create the Kiro templates in `tool/templates/app/.kiro/`
    - `steering/design.md.tmpl` as a byte-for-byte copy of `.kiro/steering/design.md`
    - `steering/tech.md.tmpl` adapted from the repo's `tech.md` (single app that depends on `coffin_core`, neutral examples)
    - `steering/structure.md.tmpl` (app layout and import rules), `steering/product.md.tmpl` (fill-in headings with `{{display_name}}`, no Coffin, Hauntagotchi or Graveyard product text)
    - `hooks/format-analyze-dart-on-save.json.tmpl` running `dart format lib test && flutter analyze`
    - `README.md.tmpl` under one page; first "how to start" step exactly `Open this app's folder in Kiro so it loads this .kiro/`; names `.kiro/specs/` as the specs folder
    - _Requirements: 3.8, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9, 5.10_

  - [x] 5.3 Write template integrity tests
    - `design.md.tmpl` equals `.kiro/steering/design.md` byte for byte
    - No file in `templates/app/` contains `Hauntagotchi`, `hauntagotchi`, `Graveyard`, `séance`, `habit` (case-sensitive)
    - Every `{{x}}` in the template is a known placeholder
    - First "how to start" step of `README.md.tmpl` equals the exact line of criterion 5.10
    - Rendered pubspec has the same `flutter_lints` and `coffin_core` lines as Hauntagotchi's, the root SDK constraint, and no other dependency
    - Required headings in `product.md`, `tech.md`, `structure.md`; hook contains `dart format lib test`
    - File: `tool/test/template/template_integrity_test.dart`
    - _Requirements: 3.8, 4.2, 4.12, 5.1, 5.2, 5.3, 5.9, 5.10, 5.11_

- [x] 6. Implement the planner (pure)
  - [x] 6.1 Implement `RaisePlanner`, `RaiseInputs`, `RaisePlan`, `PlannedFile` and `RaiseErrorKind`
    - Files under `tool/lib/src/plan/` (and `tool/lib/src/raise/raise_error_kind.dart`)
    - Order: name validation, root pubspec edit, render every file and path, path safety (reject empty, absolute, backslash, NUL, `..`, empty segment, drive prefix, duplicate paths)
    - Build the placeholder values (including `sdk_constraint` from the root pubspec); `pubspecProblem` when `sdk:` is missing; `templateProblem` names the file and unknown placeholder
    - _Requirements: 3.4, 3.5, 6.3, 7.1, 7.7_

  - [x] 6.2 Write property test for path safety
    - **Property 10: Planned paths stay inside the app folder** (planner part)
    - **Validates: Requirements 7.2, 7.7**
    - File: `tool/test/plan/raise_planner_property_test.dart`

  - [x] 6.3 Write property test for unknown placeholders in the planner
    - **Property 6: Unknown placeholders are rejected and named**
    - **Validates: Requirements 3.5**
    - File: `tool/test/plan/unknown_placeholder_property_test.dart`

  - [x] 6.4 Write property test for the rendered real template
    - **Property 7: A raised app only names itself and only imports the barrel**
    - **Validates: Requirements 4.4, 4.9**
    - File: `tool/test/plan/rendered_template_property_test.dart`

- [x] 7. Implement the disk layer
  - [x] 7.1 Implement `FileOps`, `DiskFileOps`, `PlanWriter`, `Raiser` and `RaiseResult`
    - Files under `tool/lib/src/raise/`
    - `createFileExclusive` uses `File.create(exclusive: true)`; `replaceFile` writes a temp sibling then renames; `typeOf` does not follow symlinks
    - `PlanWriter`: create `apps/` if needed, create `apps/<name>` then check it is empty (otherwise return `folderExists` and delete nothing), write files, re-read the root pubspec and compare to the planned-from bytes, replace it last
    - On failure: restore the root pubspec if replaced, delete created files in reverse, delete created empty directories in reverse, report any path that could not be removed, return `ioError` with "Nothing was changed."
    - `Raiser.raise` takes `targetRoot`, `templateDir`, `appName`; returns a result, never prints, never calls `exit`, never reads `Directory.current`
    - Treat an existing directory, file or link at `apps/<name>` as existing; build `takenNames` from workspace entries plus the fixed set
    - _Requirements: 2.6, 6.3, 6.5, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 8.1, 8.2, 8.3_

  - [x] 7.2 Write property test for rollback
    - **Property 11: A failed raise leaves the Target_Root unchanged**
    - **Validates: Requirements 7.1, 7.4, 7.5, 7.6**
    - Use a recording `FileOps` decorator that throws on the k-th write; also assert the root pubspec is the last recorded operation on success
    - File: `tool/test/raise/raiser_rollback_property_test.dart`

  - [x] 7.3 Write property test for pubspec refusals and written paths
    - **Property 9 (raiser part): Workspace edit refuses unusable files**
    - **Property 10 (raiser part): Planned paths stay inside the app folder**
    - **Validates: Requirements 6.3, 6.5, 7.2, 7.7**
    - File: `tool/test/raise/raiser_pubspec_property_test.dart`

  - [x] 7.4 Write unit tests for the Raiser
    - Success against a fixture template and the real template into a temp root (file list matches criterion 4.1)
    - Existing `apps/<n>` as directory, file and symlink is rejected and unchanged
    - Lost creation race (non-empty folder after create) returns `folderExists` and deletes nothing
    - Missing root pubspec, no workspace list, already listed; `pubspec.lock` and other pubspecs untouched
    - _Requirements: 2.6, 4.1, 6.3, 6.5, 7.2, 7.3_

- [x] 8. Implement the CLI
  - [x] 8.1 Implement `ExitCodes`, `RaiseMessages` and `RaiseCli`
    - Files under `tool/lib/src/cli/`
    - Exactly one name, or `--help` / `-h`; no or extra arguments print usage to `err` and return 64; `--help` prints usage with an example and all four exit codes to `out` and returns 0
    - Failures print a short, slightly spooky, never mean message plus the plain reason and any suggestion to `err`; `invalidName`, `folderExists`, `pubspecProblem`, `templateProblem`, `unsafePath` return 65; `ioError` returns 74
    - Success message names the folder, prints `flutter pub get`, `flutter run -d chrome` and `flutter test` (the last two inside `apps/<name>`) and the exact line `Open apps/<name> in Kiro to load its steering`
    - `defaultTemplateDir(Uri script)` returns `<script dir>/templates/app`; no `stdin`, network or sockets
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.7, 1.8, 2.7_

  - [x] 8.2 Write property test for the success message
    - **Property 4: Success message names the folder, the three commands and the Kiro line**
    - **Validates: Requirements 1.2, 1.8, 1.9**
    - File: `tool/test/cli/raise_messages_property_test.dart`

  - [x] 8.3 Write unit tests for the CLI
    - No args and two args (64), `--help` (0, lists 0, 64, 65, 74), bad name (stderr text and suggestion, 65), success (0, stdout), injected I/O failure (74)
    - File: `tool/test/cli/raise_cli_test.dart`
    - _Requirements: 1.1, 1.4, 1.7, 2.7_

- [x] 9. Wire everything together
  - [x] 9.1 Create the barrel and the real entry point
    - Write `tool/lib/coffin_raise.dart` exporting the public API
    - Replace the stub `tool/raise.dart` with the entry point that sets `exitCode` from `RaiseCli.run(args, targetRoot: Directory.current, templateDir: RaiseCli.defaultTemplateDir(Platform.script), out: stdout, err: stderr)`
    - Run `dart run tool/raise.dart --help` from the repo root and confirm exit code 0 (do not raise a real app into the repo)
    - _Requirements: 1.1, 1.3, 1.4, 8.2, 8.3, 11.6_

  - [x] 9.2 Write the repo guard test
    - Snapshot the real `apps/` (excluding `build/` and `.dart_tool/`) and the root `pubspec.yaml` as path-to-hash maps before and after the generator tests; assert equal
    - File: `tool/test/repo_guard/repo_guard_test.dart`
    - _Requirements: 8.5, 11.1_

  - [x] 9.3 Write the source scan test
    - Scan `tool/lib` and `tool/raise.dart` for `stdin`, `HttpClient`, `Socket`, and for `Hauntagotchi` / `Graveyard`
    - File: `tool/test/repo_guard/source_scan_test.dart`
    - _Requirements: 1.3, 11.5_

- [x] 10. Checkpoint - Ensure all tests pass
  - Run `dart format tool` and `flutter analyze` (zero warnings) and `flutter test` in `tool/`. Ensure all tests pass, ask the user if questions arise.

- [x] 11. Add the raise-check integration test
  - [x] 11.1 Write the `raise-check` tagged test
    - File: `tool/test/raise_check/raise_check_test.dart`, one test tagged `raise-check`
    - Copy `analysis_options.yaml`, `pubspec.lock` and a trimmed `packages/coffin_core` (`pubspec.yaml`, `analysis_options.yaml`, `lib/`, `assets/`) into a temp dir; write a root `pubspec.yaml` whose workspace list contains only existing folders (no `tool`, no `apps/hauntagotchi`, no `apps/graveyard`)
    - Raise `raise_check_app` with the real `tool/templates/app`, then run `flutter pub get --offline`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze --no-pub` (assert `No issues found!`) and `flutter test --no-pub`, each exiting 0; print stdout and stderr of a failing command
    - Delete the temp dir with `addTearDown` on pass and fail
    - Confirm a plain `flutter test` in `tool/` skips it
    - _Requirements: 1.5, 1.6, 4.10, 4.11, 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8_

- [x] 12. Update docs and credits
  - [x] 12.1 Add the README section and layout entries
    - Add one short section on raising an app: the command with an example name, one sentence on what it creates, one sentence on name rules, how to run the new app (with `flutter pub get` first), and one sentence that the developer must open `apps/<app_name>` in Kiro to load its steering because opening the repo root loads the root `.kiro/` instead
    - Keep it under 15 lines excluding code blocks; add `tool/` and `tool/templates/app/` to the repo layout listing; change no other section
    - _Requirements: 10.1, 10.2, 10.3_

  - [x] 12.2 Update `CREDITS.md`
    - Add one entry for the web icons and favicon in the Template_Folder (Flutter default icons, BSD-3 license, same files as in Hauntagotchi)
    - _Requirements: 4.12, 10.4_


- [x] 13. Final checkpoint - Ensure all tests pass
  - Run `dart format --set-exit-if-changed tool` and `flutter analyze` at the repo root (zero warnings)
  - Run `flutter test` in `tool/` and confirm it passes
  - Run `flutter test --tags raise-check --run-skipped` in `tool/` and confirm it passes
  - Run `git status` and `git diff --stat`: confirm nothing changed under `apps/hauntagotchi`, `apps/graveyard` or `packages/coffin_core`, the root `pubspec.yaml` gained only `  - tool`, `pubspec.lock` is unchanged, and `tool/pubspec.yaml` is the only new pubspec
  - Ensure all tests pass, ask the user if questions arise.
  - _Requirements: 9.8, 11.1, 11.2, 11.3, 11.4_

## Notes

- Each task references specific requirements for traceability.
- Property tests use glados with at least 100 iterations and a comment `// Feature: raise-app, Property N: <title>`.
- Tests may import `package:coffin_raise/src/...` because they live inside the package; the barrel is created in task 9.1.
- Never run `dart run tool/raise.dart <name>` against the real repo during development; tests use temp roots.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "2.1", "3.1", "4.1", "5.1", "5.2"] },
    { "id": 2, "tasks": ["2.2", "2.3", "2.4", "2.5", "3.2", "3.3", "4.2", "4.3", "5.3", "6.1"] },
    { "id": 3, "tasks": ["6.2", "6.3", "6.4", "7.1"] },
    { "id": 4, "tasks": ["7.2", "7.3", "7.4", "8.1"] },
    { "id": 5, "tasks": ["8.2", "8.3", "9.1"] },
    { "id": 6, "tasks": ["9.2", "9.3", "11.1", "12.1", "12.2"] }
  ]
}
```
