# Hauntagotchi

A ghost pet that thrives or fades with your real daily habits.

## What it does

- Keep 3 to 5 habits and tick them off each day.
- Your ghost, Wisp, gains health when you finish habits and loses health when you skip them. With enough neglect it dies, and it can be resurrected.
- Wisp looks how it feels, with a different ghost drawn for each mood.
- Under the ghost, one short line reacts to the mood, the streak and what just happened. The line comes from the `CoffinAI` interface.
- Progress is saved on the device.

## Live

https://anuka28.github.io/coffin/ (then pick Hauntagotchi)

## Run

From this folder:

```
flutter run -d chrome
```

## Test

```
flutter test
flutter test --platform chrome test/domain test/data
```

## How it uses coffin_core

Hauntagotchi depends on `packages/coffin_core`, the shared Coffin starter kit, and imports only `package:coffin_core/coffin_core.dart`. It takes from it the theme (`CoffinTheme`), the `FogBackground` and `GhostLoader` widgets, and the `CoffinAI` interface with `OfflineCoffinAI` for the ghost's voice line. Habit and health rules live in this app under `lib/src/domain` as plain Dart, with storage in `lib/src/data` and screens in `lib/src/ui`.

## Kiro specs

Specs are in `.kiro/specs/` at the repo root. These built or shaped this app:

- `hauntagotchi-core`
- `ghost-moods`
- `ghost-voice`

Shared pieces came from `workspace-setup`, `haunted-theme`, `spooky-widgets`, `fog-router`, `crypt-storage` and `coffin-ai`. The `raise-app` spec covers the generator that creates new apps on the same skeleton.
