---
inclusion: always
---

# Project Structure

```
coffin/
├── .kiro/                    # specs, hooks, steering (always committed)
├── pubspec.yaml              # pub workspace root
├── packages/
│   └── coffin_core/
│       ├── lib/
│       │   ├── coffin_core.dart        # public exports only
│       │   └── src/
│       │       ├── theme/              # design tokens, ThemeData, text styles
│       │       ├── router/             # go_router helpers, fog transitions
│       │       ├── storage/            # repository interfaces + hive_ce impls
│       │       ├── ai/                 # CoffinAI interface + implementations
│       │       └── widgets/            # spooky reusable widgets
│       └── test/
├── apps/
│   ├── hauntagotchi/
│   │   ├── lib/
│   │   │   ├── main.dart
│   │   │   └── src/
│   │   │       ├── domain/            # pure Dart models + logic
│   │   │       ├── data/              # repositories
│   │   │       └── ui/                # screens + app-specific widgets
│   │   └── test/
│   └── graveyard/                     # same layout as hauntagotchi
├── DIARY.md                  # daily build log (used for write-up + blog)
└── README.md
```

## Rules
- Apps import only `package:coffin_core/coffin_core.dart`, never files under `src/`.
- `coffin_core` must never import from an app.
- The two apps must never import from each other.
- Tests mirror the `lib/` folder structure.
