# Graveyard

Abandoned side projects become tombstones, and a séance tells you which ones are worth raising.

## What it does

- Add a grave by hand (project name and the date you last worked on it) or by importing a public GitHub repository. The last push date becomes the date of death.
- Graves stand as tombstones in a night scene. Older graves look more weathered, and graves older than five years show cracks.
- Hold a séance for any grave. It returns a revival score from 0 to 100 with a word band, three revival steps and one spooky verdict line.
- After a séance, raise the project. A hand bursts from the ground, a ghost rises, the stone changes from "R.I.P." to "RISEN", and the project moves to a "Back among the living" row.

The séance runs through the `CoffinAI` interface, so it also works offline with the built-in offline implementation.

## Live

https://anuka28.github.io/coffin/ (then pick Graveyard)

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

Graveyard depends on `packages/coffin_core`, the shared Coffin starter kit, and imports only `package:coffin_core/coffin_core.dart`. It takes from it the theme (`CoffinTheme`), the `FogBackground` and tombstone widgets, and the `CoffinAI` interface with `OfflineCoffinAI`. Anything specific to graves lives in this app under `lib/src/domain`, `lib/src/data` and `lib/src/ui`.

## Kiro specs

Specs are in `.kiro/specs/` at the repo root. These built or shaped this app:

- `graveyard-core`
- `graveyard-scene`
- `graveyard-seance`
- `graveyard-resurrection`

Shared pieces came from `workspace-setup`, `haunted-theme`, `spooky-widgets`, `fog-router`, `crypt-storage` and `coffin-ai`. The `raise-app` spec covers the generator that creates new apps on the same skeleton.
