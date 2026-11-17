# 💀 Coffin

A lean, spooky Flutter starter kit, plus two apps that prove it can carry very different ideas.

## What is Coffin?

Coffin is my Kiroween 2026 entry in the **Skeleton Crew** category. It is a small, readable skeleton (theme, routing, and more to come) for Flutter developers who want to start a polished app fast. Two apps are built on it:

- **Hauntagotchi**: a ghost pet that thrives or fades with your real daily habits.
- **Graveyard**: abandoned side projects become tombstones, and an AI séance scores their chances of coming back.

> **Status:** work in progress. `coffin_core` has its theme and router. Both apps are currently routed placeholder screens; the real features are still to be built. The storage and AI layers in `coffin_core` are not implemented yet.

## What `coffin_core` provides so far

- **Haunted theme**: dark "night" and light "daylight" themes from shared color tokens, with WCAG contrast checks (`WcagContrast`, `ContrastPair`) and property tests for them.
- **Bundled fonts**: Creepster for titles, Outfit for body text. No network font loading.
- **Soft glow**: `CoffinGlow` for glows instead of hard shadows.
- **Fog router**: a `go_router` wrapper with fog transitions between pages.
- **Reduced motion**: transitions respect `MediaQuery.disableAnimations`.
- **Spooky 404**: a `NotFoundPage` for unknown routes.

Apps import only `package:coffin_core/coffin_core.dart`.

## Repo layout

```
coffin/
├── .kiro/                  # specs, steering, hooks, MCP settings
├── packages/
│   └── coffin_core/        # theme, router, widgets (storage + ai: planned)
├── apps/
│   ├── hauntagotchi/
│   └── graveyard/
├── tool/                   # raise.dart, the app generator
│   └── templates/app/      # files copied into each raised app
├── CREDITS.md
├── DIARY.md
└── pubspec.yaml            # Dart pub workspace root
```

## Run an app in Chrome

```sh
flutter pub get            # from the repo root, resolves the whole workspace

(cd apps/hauntagotchi && flutter run -d chrome)
(cd apps/graveyard && flutter run -d chrome)
```

## Raise a new app

```sh
dart run tool/raise.dart bone_shop
```

This creates `apps/bone_shop` as a new workspace member built on `coffin_core`, with its own `.kiro/` steering. The name must be a valid Dart package name (lowercase letters, digits and single underscores, starting with a letter, at most 64 characters) and must not be a reserved word or an existing package.

To run it, resolve the workspace first, then start the app:

```sh
flutter pub get
(cd apps/bone_shop && flutter run -d chrome)
```

Open `apps/bone_shop` (your `apps/<app_name>`) in Kiro to load its steering, because opening the repo root loads the root `.kiro/` instead.

## Run the tests

Run from the repo root:

```sh
(cd packages/coffin_core && flutter test)
(cd apps/hauntagotchi && flutter test)
(cd apps/graveyard && flutter test)
```

## Built spec-first with Kiro

Everything in `.kiro/` shaped the build:

- `specs/`: requirements, design, and tasks for `workspace-setup`, `haunted-theme`, and `fog-router`.
- `steering/`: tech, structure, product, and design rules that every change follows.
- `hooks/`: a hook that formats and analyzes Dart files on save.
- `settings/mcp.json`: the Dart MCP server.
- **glados** property-based tests cover the numeric rules (contrast math, glow, fog math).

## License

MIT, see [LICENSE](LICENSE). Bundled fonts and their licenses are listed in [CREDITS.md](CREDITS.md).
