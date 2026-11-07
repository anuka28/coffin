---
inclusion: always
---

# Tech Stack & Conventions

## Stack
- Flutter 3.47 (stable), Dart 3.13. Primary target: **Flutter Web**. Must also work on Android/iOS screen sizes.
- Monorepo using a **Dart pub workspace** (root `pubspec.yaml` with `workspace:` listing the packages and apps).
- State management: **Riverpod** (`flutter_riverpod`). No other state libraries.
- Routing: **go_router**.
- Local storage: **hive_ce** (works on web), always behind a repository interface.
- AI: the `CoffinAI` interface in `coffin_core`. Apps never call an LLM API directly. It must have an offline/mock implementation so the apps work without a network or key.
- Testing: `flutter_test` for unit and widget tests, **glados** for property-based tests.

## Code style
- Follow `flutter_lints`. Code must pass `dart format` and `flutter analyze` with zero warnings.
- Prefer small, immutable classes. Use `final` everywhere it's possible.
- Keep pure logic (e.g. ghost health decay, resurrection scoring) in plain Dart classes with no Flutter imports, so it's easy to test.
- Name files in `snake_case.dart`, one public widget/class per file.
- Doc-comment every public API in `coffin_core`.

## Testing rules
- Every piece of pure logic gets unit tests.
- Logic with numeric rules or invariants (health, decay, scores, streaks) also gets property-based tests with glados.
- Don't mark a task done until `flutter test` passes.

## Dependencies
- Ask before adding a new package. Prefer well-maintained packages with web support.
- Never add packages that require secrets in client code.
