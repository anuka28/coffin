# coffin_core

The reusable skeleton of the Coffin starter kit: theme, routing, storage, an AI layer and spooky widgets. It is "haunted, not horror": dark, soft, glowing, and it works offline.

## Quick start

From the repo root, raise a new app on top of this package:

```sh
dart run tool/raise.dart my_app
```

See [Raise a new app](../../README.md#raise-a-new-app) in the root README for the name rules and how to run it.

A raised app imports **only** `package:coffin_core/coffin_core.dart`. Never import files under `src/`, and never import from another app. `coffin_core` never imports from an app.

## Theme

`CoffinTheme.dark()` and `CoffinTheme.light()` build the night and daylight `ThemeData`. The colors live in `CoffinColorTokens.night` and `CoffinColorTokens.daylight`. `CoffinGlow` makes soft glows instead of hard shadows.

```dart
MaterialApp.router(
  theme: CoffinTheme.light(),
  darkTheme: CoffinTheme.dark(),
  themeMode: ThemeMode.system,
  routerConfig: router,
);

final BoxDecoration halo = CoffinGlow.decoration(
  color: CoffinColorTokens.night.primary,
  intensity: 0.6, // 0 to 1
  fill: CoffinColorTokens.night.surface,
);
```

Also exported: `CoffinTypography` (Creepster for titles, Outfit for body) and `CoffinMetrics` (16 px corners, 48 px tap target).

## Router

`FogRouter.create` builds a `GoRouter` whose pages fade in like mist. Describe routes with `AppRoute`. Unknown paths show `NotFoundPage`, or your own `notFoundBuilder`.

```dart
final GoRouter router = FogRouter.create(
  routes: <AppRoute>[
    AppRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
      routes: <AppRoute>[
        AppRoute(
          path: 'crypt',
          builder: (context, state) => const CryptScreen(),
        ),
      ],
    ),
  ],
);
// Navigate with context.go('/crypt') (GoRouterHelper is exported).
```

Create the router once (for example in a `State` field) and call `dispose()` on it, so rebuilds do not reset navigation.

## Storage

Apps use a `RecordRepository<T>` and never touch Hive directly. You write a `RecordCodec<T>`, and `StorageOpener` opens a Hive box. If Hive is unavailable, it falls back to memory, and `isPersistent` tells you which one you got.

```dart
class Note {
  const Note(this.text);
  final String text;
}

class NoteCodec implements RecordCodec<Note> {
  const NoteCodec();

  @override
  JsonMap encode(Note record) => <String, Object?>{'text': record.text};

  @override
  Note decode(JsonMap json) => Note(json['text'] as String);
}

Future<void> saveNote() async {
  final OpenedRepository<Note> opened = await const StorageOpener(
    initializer: hiveFlutterInitializer,
  ).open<Note>(
    boxName: 'notes',
    codec: const NoteCodec(),
    currentVersion: 1,
  );
  final RecordRepository<Note> notes = opened.repository;

  await notes.put('first', const Note('Rest in pixels'));
  final Note? back = await notes.get('first');
  final List<Note> all = await notes.getAll();
}
```

Raise `currentVersion` when the record shape changes and pass a `MigrationHook` to `open`. In tests, use `MemoryRecordRepository<T>(codec: ..., currentVersion: 1)`. Pass `reportIssue:` to `StorageOpener` to see problems such as `StorageIssueKind.fallbackToMemory`.

## AI

Apps call the `CoffinAI` interface and never an LLM API. `OfflineCoffinAI` writes spooky text from templates, with no network and no key. `FallbackCoffinAI` tries a primary `CoffinAI` and uses the secondary if the primary throws, times out, or returns blank or over-long text.

```dart
final CoffinAI ai = FallbackCoffinAI(
  primary: myRemoteAi, // your own CoffinAI, e.g. calling your backend
  secondary: const OfflineCoffinAI(),
  timeout: const Duration(seconds: 3),
);

final AiReply reply = await ai.ask(
  AiRequest(
    purpose: AiPurpose.ghostMoodLine,
    facts: <String, Object?>{
      AiFactKeys.ghostName: 'Boo',
      AiFactKeys.streakCount: 3,
    },
    maxLength: 80,
    seed: 7, // same seed, same offline text
  ),
);
print('${reply.text} (${reply.source.name})');
```

Built-in purposes are `AiPurpose.ghostMoodLine` and `AiPurpose.seanceVerdict`. If both implementations fail, `ask` throws `AiFallbackError`.

**No API keys in client code or in the repo.** If you want a hosted model, put the key behind your own server and have `myRemoteAi` call that.

## Widgets

```dart
FogBackground(
  child: Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const GhostLoader(caption: 'Summoning…'),
        TombstoneCard(
          title: 'old_side_project',
          dateLine: 'Dead for 214 days',
          epitaph: 'Gone too soon',
          onTap: () => context.go('/crypt'),
          child: const Text('Resurrection odds: 42%'),
        ),
        const FlickerText('It lives?'),
      ],
    ),
  ),
);
```

- `GhostLoader`: a bobbing ghost for loading states.
- `TombstoneCard`: arched card with an engraved epitaph (default `R.I.P.`, hide it with `showEpitaph: false`). Give it `onTap` and it gets hover, press and focus states.
- `FlickerText`: for emphasis only.
- `FogBackground`: drifting fog behind any `child`.
- `CryptGallery`: every widget in night and daylight. Add it as a route and open `/#/gallery` on Flutter Web:

```dart
AppRoute(
  path: '/gallery',
  name: 'gallery',
  builder: (context, state) => CryptGallery(onBack: () => context.go('/')),
),
```

## Accessibility and motion

- **Reduced motion.** `GhostLoader`, `FlickerText` and `FogBackground` stop their loops and show a still frame when `MediaQuery.disableAnimationsOf(context)` is true. Fog page transitions also drop to a plain switch.
- **Tap targets.** `CoffinTheme` sets buttons to at least 48x48 (`CoffinMetrics.minTapTarget`) and adds a visible focus ring. Do the same for custom controls.
- **Contrast.** Both themes meet WCAG AA. Tests check the token pairs with `WcagContrast` (`ratio`, `aaNormalText` = 4.5).
- **Labels.** Widgets expose semantic labels. Pass `semanticLabel` to `TombstoneCard` when the default is not enough.

## Testing

```sh
cd packages/coffin_core
flutter test                                                    # everything on the VM
flutter test --platform chrome test/widgets/math test/common  # pure folders in Chrome
flutter test $(find test -name '*_property_test.dart')          # property tests only
```

Property tests use [glados](https://pub.dev/packages/glados) and are the `*_property_test.dart` files, mirroring `lib/`. Source-scan tests (they read files with `dart:io`) and Hive tests are VM-only, so run Chrome on pure folders like the one above, not the whole suite. Format and analyze with `dart format .` and `flutter analyze`.
