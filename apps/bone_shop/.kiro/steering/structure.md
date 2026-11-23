---
inclusion: always
---
# Project Structure

This app lives in `apps/bone_shop` and depends on `coffin_core` at `../../packages/coffin_core`.

```
bone_shop/
├── .kiro/                    # specs, hooks, steering (always committed)
├── pubspec.yaml
├── analysis_options.yaml
├── web/                      # web entry files and icons
├── lib/
│   ├── main.dart
│   └── src/
│       ├── domain/           # pure Dart models + logic
│       ├── data/             # repositories
│       └── ui/               # screens + app-specific widgets
└── test/                     # mirrors lib/
```

## Rules
- Import only `package:coffin_core/coffin_core.dart`, never files under `coffin_core/src/`.
- `coffin_core` must never import from this app.
- This app must never import from another app.
- Anything app-specific stays in this app. Only genuinely reusable code belongs in `coffin_core`.
- Tests mirror the `lib/` folder structure.
