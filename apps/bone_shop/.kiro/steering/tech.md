---
inclusion: always
---
# Tech Stack & Conventions

## Stack
- Flutter 3.47 (stable), Dart 3.13. Primary target: **Flutter Web**. Must also work on Android/iOS screen sizes.
- This app is one member of a **Dart pub workspace**. It lives in `apps/bone_shop` and depends on `coffin_core` by path (`../../packages/coffin_core`).
- State management: Flutter's built-in ChangeNotifier with ListenableBuilder. No state-management packages.
- Routing: **go_router**, through the helpers in `coffin_core`.
- Local storage: **hive_ce** (works on web), always behind a repository interface.
- AI: the `CoffinAI` interface in `coffin_core`. This app never calls an LLM API directly. Use the offline/mock implementation so the app works without a network or key.
- Testing: `flutter_test` for unit and widget tests, **glados** for property-based tests.

## Code style
- Follow `flutter_lints`. Code must pass `dart format` and `flutter analyze` with zero warnings.
- Prefer small, immutable classes. Use `final` everywhere it's possible.
- Keep pure logic (domain rules, scoring, calculations) in plain Dart classes with no Flutter imports, so it's easy to test.
- Name files in `snake_case.dart`, one public widget/class per file.
- Doc-comment every public API.

## Testing rules
- Every piece of pure logic gets unit tests.
- Logic with numeric rules or invariants (limits, scores, counters, streaks) also gets property-based tests with glados.
- Don't mark a task done until `flutter test` passes.
- Run `flutter test` and `flutter analyze` from this app's folder.

## Dependencies
- Ask before adding a new package. Prefer well-maintained packages with web support.
- Never add packages that require secrets in client code.
- Never put API keys, secrets or tokens in the repo.
