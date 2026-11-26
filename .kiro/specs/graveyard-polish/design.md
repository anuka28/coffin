# Design Document: graveyard-polish

## Overview

This feature fixes two unrelated visual defects in `apps/graveyard`:

1. **Floating ground.** `GraveyardScene` (`lib/src/ui/graveyard_scene.dart`) paints a static `GroundPainter` band pinned to the bottom 34% of the `Scene_Box`, outside the `SingleChildScrollView` that carries the rows of `GraveTombstone`. Scrolling moves the stones but not the band, so stones end up floating above the ground, in it, or in the sky. This feature moves the `GroundPainter` into the scrolling content, anchored so its visible top (the `Horizon`) lands at the shared base line of the first row of stones (the `First_Row_Base`), and keeps the Empty_State/All_Risen_State band exactly as it is today.
2. **Uneven first row.** Stones in one row are laid out top-aligned today (`CrossAxisAlignment.start` in the `Row` built by `GraveyardScene._rows`), so stones of different height (a long name wraps the epitaph/description, lengthening `TombstoneCard`) have different bottoms. This feature bottom-aligns stones within a row, so the row has one shared base line.
3. **Oversized séance sheet.** `SeanceSheet` always grows to the height the modal route offers because it sits in `Align(alignment: Alignment.topCenter)` inside a `SafeArea` that fills that height. This feature sizes the sheet to its content (by wrapping the scroll view in `Align(alignment: Alignment.topCenter, heightFactor: 1)` instead of an `Align`/`Center` that fills the height the route offers; see "Séance sheet sizing"), while still scrolling at larger text scale or on short screens, and gives the verdict a distinct quote-style presentation reserved in advance so its arrival causes no layout jump.

The work is confined to `apps/graveyard/lib`, `apps/graveyard/test` and this spec folder. No package, asset or `coffin_core` change. Every new color is a `CoffinColorTokens` member.

## Architecture

### Ground placement: how the design was chosen

Three ways to find the first row's base line were considered:

| Option | Description | Verdict |
|---|---|---|
| A. Compute purely from `SceneLayout` | `SceneLayout.cellFor`/`contentHeightFor` give `top` in terms of a caller-supplied `tombstoneHeight`, but the actual rendered height of a `GraveTombstone` is not a pure function of `SceneLayout` — it depends on text layout (wrapped description, long names), text scale, and theme fonts. `SceneLayout` deliberately stays pure Dart with no notion of rendered text size (see `scene_layout.dart`, no Flutter import). Computing the real first-row height here would require either duplicating text-measurement logic in pure Dart (fragile, duplicates `TombstoneCard`'s own `IntrinsicHeight`-free sizing) or passing in a measured height from the widget layer anyway. | Rejected as the sole source: it cannot know the real stone height without a measurement from the widget tree. |
| B. Custom `RenderObject`/layout protocol for the ground and the first row | A bespoke `RenderBox` that lays out the first row and the ground together, exposing the computed base line directly. | Rejected: large and invasive for a two-widget relationship; conflicts with keeping `GraveyardScene` a plain `StatefulWidget` built from standard widgets, and touches more surface than the bug needs. |
| **C. Measure the Stone_Box bottom after layout with a `GlobalKey` + post-frame callback, feed it into the ground's height** | Put a `GlobalKey` in `GraveTombstone` on the layout box of the stone, outside the rise translate (its bottom centre is the tilt pivot, and it excludes the controls). After layout, read that box's bottom in the coordinate system of the Scroll_Content and use it as the `First_Row_Base`. Rebuild the `Ground_Field`'s sizing from that value. | **Chosen.** This reads exactly the quantity the requirements define (the bottom of the Stone_Box), so no formula and no control-block measurement is needed. It keeps `GraveyardScene` a normal widget (no new `RenderObject`). |

Design C needs the ground to **never show in a wrong place before the first measurement**. The mitigation is the first-frame rule below (ground box height 0 until measured), not an estimated height. Concretely:

- The row's position needs no `SceneLayout` input: the measured stone box is read in the coordinate system of the rows `Column`, so `SceneLayout.cellFor` is not used for the ground. The stone's height, the row's height and the control-block height are not needed either.
- The measurement runs in a post-frame callback (see "Measurement" for when it is scheduled).
- **What the first frame shows.** The measurement can only be known after the first layout, so in the first frame (`_stoneBase == null`) the `Ground_Field` widget is already in the tree (so exactly one of Ground_Field/Ground_Band exists, Requirement 4.4/4.5) but is laid out with height 0 and paints nothing. The sky and the stones are shown as usual. The post-frame measurement then sets `_stoneBase`, and the next frame shows the ground at its exact place, directly, with no implicit animation, no `AnimatedContainer` and no fade. The ground therefore appears once, at its final position, and never moves from a fallback position to the measured one. There is no estimated fallback height (the earlier idea of an estimate derived from `TombstoneCard._portraitRatio` is dropped, because the estimate could differ from the measured height and make the ground visibly jump). Cost: one frame (about 16 ms) without ground on load, which is a draw-in rather than a displacement. Under Reduced_Motion the behavior is identical, because nothing here animates.
- The Stone_Box of a `GraveTombstone` already has a defined base: `_Tilted` rotates `alignment: Alignment.bottomCenter`, so the tilt pivot is the bottom centre of the stone box (see `grave_tombstone.dart`, `_Tilted.build`). That bottom centre is the Stone_Base. The design measures it directly, with a key on the Stone_Box, instead of deriving it from the row or from the `GraveTombstone` height (which includes the control block of 96 to 128 px).

This gives the First_Row_Base as one value read directly from the render tree, in the coordinate system of the Scroll_Content (see "Measuring the First_Row_Base"). There is no formula of the form row top + row height − control height, and the control block is not measured. Because the value is expressed in Scroll_Content coordinates, and the `Ground_Field` is a sibling painted *inside* that same scrolling content, placing the `Ground_Field`'s top at `First_Row_Base - GroundPainter.maxSoftEdge` makes it move pixel-for-pixel with the stones automatically. This satisfies Requirement 2.1 (ground moves by exactly `d` when the content scrolls by `d`) with no manual scroll-offset tracking: both the ground and the rows are children of the same scrolling content, so the scroll view's own transform applies identically to both.

### Measuring the First_Row_Base

`GraveTombstone` gets one new optional constructor parameter, `GlobalKey? stoneKey`, documented as "Key attached to the layout box of the stone (without its controls), for hosts that measure the base of the stone". It is applied as the `key` of the `ConstrainedBox(maxWidth: GraveTombstone.maxStoneWidth)` that is the child of the `Center` in `GraveTombstone.build` and the parent of `Transform.translate`. The widget chain in the real code is:

```
Column (stone + controls)
├─ Center
│  └─ ConstrainedBox(key: stoneKey)        <- keyed box
│     └─ Transform.translate (Rise)         paint only, no layout effect
│        └─ Opacity -> Semantics -> ExcludeSemantics
│           └─ _Tilted (Transform.rotate, alignment: bottomCenter)
│              └─ stone (Stack: card, epitaph, cracks, play)
└─ Wrap (Séance, Delete)                     outside the keyed box
```

Why this widget and no other:

- **(a) The translate is inside the keyed widget.** `Transform.translate`, `Opacity` and `Transform.rotate` change painting only. They do not change layout size or the layout position of their parent. The keyed `ConstrainedBox` therefore has the same size and the same layout position at every Rise_Progress, which is the stone at rest (Rise_Progress 1). `localToGlobal` on the keyed box is a transform along the render-object ancestors *above* the box, and the Rise translate is *below* it, so the translate is never part of that chain. No correction term is needed.
- **(b) The bottom centre is still the tilt pivot and the controls are excluded.** The `ConstrainedBox` only sets a maximum width, so it takes the size of its single child chain (translate, opacity and semantics widgets pass the size through, and `_Tilted` rotates inside the box without changing the size it reports). That size is the size of the `stone` `Stack`. `_Tilted` rotates around `Alignment.bottomCenter` of that same size, so the bottom centre of the keyed box is the tilt pivot. The `Wrap` with the Séance and Delete controls is a sibling of the `Center` in the outer `Column`, so it is not inside the keyed box. A key on the `Center` would be wrong, because the `Center` fills the cell width and its bottom centre could differ from the stone's if the stone were narrower than the cell. A key on `GraveTombstone` itself or on the outer `Column` would include the controls.
- **(c) The key is unique and the same widget in both scene branches.** `GraveyardScene._tombstone` builds the same `GraveTombstone` in both branches (`KeyedSubtree(child: build(1))` without a rise controller, and `KeyedSubtree(child: AnimatedBuilder(... build(progress)))` while rising). Only `riseProgress` differs. Because the key is applied inside `_GraveTombstoneState.build`, it is the same widget in both branches, and the scene only has to pass `stoneKey` to the first `GraveTombstone` of the first row, in the single `build(double progress)` helper, so both branches get it by construction. The `GlobalKey` is created once in `_GraveyardSceneState`, and it exists on exactly one `ConstrainedBox` at a time. When a rise ends the scene replaces `AnimatedBuilder` by the `GraveTombstone` directly under the same `KeyedSubtree`; the old element is deactivated and the new one is built in the same frame, which Flutter's `GlobalKey` handling allows (the key is not in the tree twice after the frame). The end of a rise is already a re-measure trigger.

The existing `super.key` is not reused, because the scene already keys the `KeyedSubtree` by grave id and a `GlobalKey` on the `GraveTombstone` itself would measure the box with the controls.

The scene passes its `_stoneKey` into the first `GraveTombstone` of the first row only. `_measureGround` then computes:

```dart
final stone = _stoneKey.currentContext?.findRenderObject() as RenderBox?;
final content = _contentKey.currentContext?.findRenderObject() as RenderBox?;
if (stone == null || content == null || !stone.attached) return;
// The tilt pivot is the bottom centre, so the tilt does not move this point.
final pivot = Offset(stone.size.width / 2, stone.size.height);
// The keyed box is outside the Rise translate, so this is the resting base
// at every Rise_Progress. No correction is needed.
final double base = stone.localToGlobal(pivot, ancestor: content).dy;
```

- `localToGlobal(..., ancestor: content)` gives the y-coordinate in the coordinate system of the rows `Column`, which scrolls with the stones. It does not depend on the scroll offset, so a scroll never needs a new measurement.
- The Stone_Base is defined at Rise_Progress 1. A rising stone is painted lower by `(1 - progress) * riseDistance` through `Transform.translate`, but that translate is a paint-only transform *inside* the keyed box, so it is not part of the transform chain from the keyed box up to `content`. The keyed box is always laid out at the stone's resting position, and the measured value equals the Stone_Base at every Rise_Progress (Requirement 1.4) without any `riseDistance` or `RiseProgress` term in `_measureGround`. The end of a rise stays a re-measure trigger because the stone's parent widget changes then.
- Bases within a row are aligned (Requirement 13), so the first stone of the first row gives the same value as any other stone of that row within Base_Tolerance.
- The value does not depend on the control-block height, so it is the same at text scale 1.0 and 2.0 for the same stone box (Requirement 1.8).

### Filling to the bottom (Requirement 2.2–2.4, 3.1)

The `Ground_Field` is a single `CustomPaint` whose **height** is computed, not fixed, each build:

```
groundHeight = max(
  contentBottom - groundTop,   // natural: from first-row-base soft edge down to the bottom of all rows + bottom padding
  viewportHeight - groundTop,  // Requirement 2.4 / 3.1: at least to the bottom of the Scene_Box when rows are short
)
```

where:
- `groundTop = First_Row_Base - GroundPainter.maxSoftEdge` (the ground box's top edge; the painter itself fades in over its own `maxSoftEdge`, so the opaque color reaches `First_Row_Base` — this satisfies Requirement 1.3).
- `contentBottom` is the bottom of the scrolling `Column`'s content — i.e. the height of the last row's bottom plus `GraveyardScene.bottomPadding` plus the bottom safe-area inset, which the `Column` underneath the `Ground_Field` already determines; it is obtained the same way as the Column's total height today (the `Column` is `CrossAxisAlignment.stretch`, so a `Stack`-based ground sibling sized with its own `LayoutBuilder` reading the Column's `RenderBox.size.height` after it is laid out, via the same `GlobalKey` technique, gives this value directly without re-deriving row maths).
- `viewportHeight` is `constraints.maxHeight` of the outer `LayoutBuilder` already present in `GraveyardScene.build` (the `height` local variable).

Because `groundHeight` is clamped to at least `viewportHeight - groundTop`, a scene with one or a few stones (so `contentBottom - groundTop < viewportHeight - groundTop`) still paints ground down to the visible bottom of the screen (Requirement 2.4), and at maximum scroll the ground still reaches at least the bottom of the scrollable content including `bottomPadding` (Requirement 2.3). Because the `Ground_Field` is one continuous `CustomPaint` (one rectangle) spanning from `groundTop` to `groundTop + groundHeight`, there is never a gap between two rows (Requirement 3.1) — multi-row scenes do not get one ground field per row; there is exactly one `Ground_Field` per build in the rows state (Requirement 1.1).

### Measurement: when it runs and how a rebuild loop is prevented

The measurement is state of `_GraveyardSceneState` (two `GlobalKey`s, `_stoneBase`, `_contentHeight`), not a separate widget, so no new file or public type is added. It mirrors the pattern of `Size? _starSize` / `_starsFor`.

**The base line is measured again exactly when one of these happens** (each sets a private flag `_needsMeasure = true`; `build` schedules one `addPostFrameCallback` only while the flag is set, and clears it when it schedules):

| Trigger | Where it is detected |
|---|---|
| First build | `_needsMeasure` starts `true` |
| Viewport size change (width or height) | The outer `LayoutBuilder` in `build` compares `constraints.biggest` with `_lastViewport` and sets the flag when it differs |
| Text scale change | `build` compares `MediaQuery.textScalerOf(context)` with `_lastScaler` (`TextScaler` equality) |
| Grave list change (add, import, **delete**, **raise**, reorder, living/rows split change) | `didUpdateWidget`, where the existing `_idsOf`/`_rowsOf` comparison already runs; a raise changes `risenOn` of a grave and therefore its stone content, so the comparison also covers `Grave` equality of the rows, not only the ids |
| Rise finished | The existing rise-completion path (the same one that disposes a rise controller) sets the flag, because a stone that has just arrived changes the row it belongs to being the steady state |

No other event re-measures. In particular a scroll, a rise tick (`riseProgress` only changes `Transform`/`Opacity`, never layout size) and a repaint do not.

**Guard against a rebuild loop.** `_measureGround` reads both render boxes and compares the new values with the stored ones:

```dart
bool changed(double? old, double now) => old == null || (now - old).abs() > 0.5;
if (changed(_stoneBase, base) || changed(_contentHeight, content)) {
  setState(() { _stoneBase = base; _contentHeight = content; });
}
```

`setState` is called only when a value is new or differs by more than 0.5 px. The rebuild that follows does not set `_needsMeasure` (none of the triggers above fires), so it schedules no further callback. The sequence is therefore at most: frame 1 (no ground) → post-frame measure → frame 2 (ground at exact place) → idle. A sub-pixel float difference between two layouts of identical content cannot restart the cycle.


### Switching between Ground_Field and Ground_Band

`GraveyardScene.build` already branches on `rows.isEmpty` for the `noRows` panel. The same `rows.isEmpty` (combined with `living.isNotEmpty` for `All_Risen_State`, matching the existing condition) decides which of `Ground_Band` (today's static `Positioned` strip, kept verbatim as a `Positioned.fill`-adjacent band outside the `SingleChildScrollView`) or `Ground_Field` (new, inside the `SingleChildScrollView`'s `Column`) is painted. Exactly one of the two exists in the tree at a time — the other is omitted (not hidden with `Visibility`), so Requirement 4.4/4.5 ("no Ground_Field while a Ground_Band is painted" and vice versa) holds structurally, not by a runtime check in a test. Switching is driven by the same `rows`/`living` values already recomputed on every `build`, so a change from empty to non-empty (or back) takes effect in the next frame with no extra state and no exception (Requirement 4.6).

## Components and Interfaces

### `GroundPainter` (`lib/src/ui/ground_painter.dart`) — unchanged

Per Requirement 5.5, the public constructor `GroundPainter({required tokens})`, `GroundPainter.maxSoftEdge` (24.0) and `shouldRepaint` (true only when `tokens` differ) stay exactly as today. Only the **doc comment** changes, to describe the ground as content that is placed either as the static Ground_Band (Empty_State/All_Risen_State) or inside the scrolling content as the Ground_Field (Requirement 11.6):

```dart
/// Paints the ground: the theme `background` color with a soft top edge that
/// fades into the sky.
///
/// The painter fills the box it is given. In the Empty_State and the
/// All_Risen_State the host places it as a static band at the bottom of the
/// scene. Otherwise the host places it inside the scrolling content, sized
/// so its soft top edge (`maxSoftEdge`) reaches the First_Row_Base. Hosts
/// wrap it in `ExcludeSemantics` and `IgnorePointer`.
```

### `GraveyardScene` (`lib/src/ui/graveyard_scene.dart`) — changed

- Class doc comment updated (Requirement 11.6) to replace "The sky, the ground and the fog never scroll" with a statement that the ground scrolls with the rows except in the Empty_State and the All_Risen_State, where it stays a static band.
- New private state fields on `_GraveyardSceneState`:
  - `final GlobalKey _stoneKey = GlobalKey();` (handed to the first `GraveTombstone` of the first row, which applies it to its keyed layout box, see "Measuring the First_Row_Base")
  - `final GlobalKey _contentKey = GlobalKey();` (end of the rows `Column`, to measure `contentBottom`)
  - `double? _stoneBase;`, `double? _contentHeight;` (null until the first measurement; `_stoneBase` is the First_Row_Base, `_contentHeight` the height of the rows `Column`)
  - `bool _needsMeasure = true;`, `Size? _lastViewport;`, `TextScaler? _lastScaler;` (the re-measure triggers listed in "Measurement")
- There is no estimate method: until `_stoneBase` is set the ground box has height 0 (see "What the first frame shows").
- New private method `void _measureGround()` scheduled by `build` through `addPostFrameCallback` only while `_needsMeasure` is set (mirrors the existing `SchedulerBinding.instance.addPostFrameCallback` pattern used for rise completion). It reads `_stoneKey.currentContext?.findRenderObject()` and `_contentKey.currentContext?.findRenderObject()` as `RenderBox`, computes `stoneBase` as described in "Measuring the First_Row_Base", and calls `setState` only when a value is new or changed by more than 0.5 px. The `groundTop`/`groundHeight` for the `CustomPaint` come from `GroundHeight.of` (`lib/src/domain/scene/ground_height.dart`).
- `_rows` passes a `GlobalKey` (`_stoneKey`) to the first `GraveTombstone` of the first row only (`start == 0` and `i == start`), through `_tombstone(grave, stoneKey: ...)`, which hands it on in the single `build(double progress)` helper that creates the `GraveTombstone(...)`, so the rising branch (with the `AnimatedBuilder`) and the non-rising branch pass it identically. `GraveTombstone` applies it to its `ConstrainedBox`, outside the rise translate. The whole rows `Column` gets `_contentKey`. No other stone receives a key, so the `GlobalKey` is unique in the tree.
- The ground `Positioned` in `build` becomes two branches:
  - Rows non-empty: inside the `Column` of the `SingleChildScrollView`, insert a `CustomPaint` sized by a `SizedBox`/`Positioned` pairing driven by the computed `groundTop`/`groundHeight`, positioned as a `Stack` layer **behind** the header/Living_Row/rows content so that visually the ground sits under the stones (implemented as the first child of an inner `Stack` that itself is the single child passed to the `SingleChildScrollView`, replacing the current direct `Column` child — the `Column`'s content becomes one of the `Stack`'s children, laid out with `Positioned.fill` for the ground and the existing `Column` on top un-modified otherwise). `IgnorePointer`+`ExcludeSemantics` wrap it exactly as today (Requirement 5.3).
  - Rows empty (Empty_State/All_Risen_State): the existing `Positioned` band, bit-for-bit as it is today, outside the `SingleChildScrollView` (Requirement 4.1–4.3).
- `SceneLayout.cellFor` and `SceneLayout.tombstoneWidthFor` are reused unchanged for the cell `left`/`width` of the rows; the ground does not use `SceneLayout` at all. No change to `scene_layout.dart`.

### `_rows` bottom alignment (Requirement 13)

Today: `Row(crossAxisAlignment: CrossAxisAlignment.start, ...)`. Changed to `CrossAxisAlignment.end`. `GraveTombstone`'s outer `Column` (the stone, then the `Wrap` of the Séance and Delete controls) sizes to its content with `mainAxisSize: MainAxisSize.min`, so bottom-aligning the `Row`'s children aligns the bottoms of the control blocks. That equals aligning the Stone_Base (the bottom of the stone, controls excluded, Glossary) only if the control block has the same height in every stone of the row.

**Verification of that claim against the real code** (`grave_tombstone.dart`, `seance_control.dart`, measured with a throwaway widget test that was not committed; two stones in one scene, one with a long wrapping name and one short, `GraveyardScene` at the given width):

| Width | Text scale | Control `Wrap` height, stone 1 / stone 2 | Outer column heights (stone + controls) |
|---|---|---|---|
| 320 | 1.0 | 96 / 96 | 445 / 441.6 |
| 320 | 2.0 | 128 / 128 | 757 / 619 |
| 768 | 1.0 | 96 / 96 | 456 / 456 |
| 768 | 2.0 | 128 / 128 | 757 / 619 |

Result:
- The statement "the controls are fixed 48x48 even at scale 2.0" is **false**. Each control has `minimumSize: Size(48, 48)` but that is only a minimum. The Séance button and the Delete button do not fit side by side in the 288–300 px stone width (the two labels plus the Delete icon and the button padding exceed it already at scale 1.0), so the `Wrap` breaks into two runs: 96 px (2 x 48) at scale 1.0 and 128 px at scale 2.0 (the scaled labels make each run taller than 48 and the buttons' padding scales with the text).
- The consequence the design relies on **does hold**: the control block's height depends only on the stone width, the text scale and the constant labels ("Séance", "Delete"), never on the grave's name, description or date. All stones of one row have the same width (one cell width per row, including a last row with fewer stones) and the same labels, so their control blocks have the same height at every width and scale (96/96 and 128/128 above). Titles, descriptions and epitaphs live in the stone above the `Wrap` and cannot change it. The vertical offset between a stone's base and its outer `Column`'s bottom is therefore identical for all stones in a row, and bottom-aligning the outer `Column`s bottom-aligns the stone bases within the 1 px Base_Tolerance.
- The claim does **not** license treating the row's bottom as the stone base for the Ground_Field. The offset between them is the control-block height (96 or 128, not 48). The Ground_Field therefore never derives the base from the row or from the `GraveTombstone` height. It reads the bottom of the Stone_Box directly (see "Ground placement" and "Measuring the First_Row_Base"), so the result does not depend on the control-block height at all.
- At width 320 (any scale) `SceneLayout.columnsFor` returns 1 (below the 720 px breakpoint), so every row holds one stone and a same-row comparison there is vacuous. The text-scale 2.0 test therefore runs at both width 320 (each stone's base measured against its own control block, and no overflow) and at the first multi-column width, 768 (2 columns), where two stones of different height share a row.

**Test for this claim** (`test/ui/graveyard_ground_test.dart`, Requirement 13.6): at text scale 2.0, for width 320 and width 768, pump a scene whose first row holds a stone with a long, wrapping name and a stone with a short name. Read each stone's base as the top of its control block, `tester.getRect(find.descendant(of: find.byType(GraveTombstone).at(i), matching: find.byType(Wrap))).top` (this is the untilted base, unlike the `Opacity`/stone rect that `_Tilted` rotates). Assert that at 768 the two bases differ by at most 1 px, that the two control-block heights are equal, and that at 320 no `RenderFlex` overflow is reported. A second case repeats this at scale 1.0 so a regression in the control-block assumption shows up at both scales.

**Test: Horizon equals the Stone_Box bottom** (`test/ui/graveyard_ground_test.dart`, Requirements 1.8 and 12.3, also covering 12.2). The test names itself after the criterion and runs at text scale 1.0 and at text scale 2.0, at a width of 360 and of 768. For each case:

1. Pump a scene whose first row holds stones that differ in height (a long wrapping name and a short name). The control block grows with the text scale (96 px at 1.0, 128 px at 2.0 in the measurements above), so the two scales give two different control-block heights for the same stone.
2. Read the Stone_Box of the first stone in the first row as the render box of the keyed `ConstrainedBox` that carries the `stoneKey` (the test passes its own `GlobalKey` to a `GraveTombstone` it pumps, or finds the `ConstrainedBox` that is the child of the first `GraveTombstone`'s `Center`). Its bottom is `box.localToGlobal(Offset(box.size.width / 2, box.size.height), ancestor: contentBox).dy`, with `contentBox` the render box of the rows `Column`. This is the test's own measurement; it does not use the scene's `_stoneBase`.
3. Read the Horizon as the top of the Ground_Field plus `min(GroundPainter.maxSoftEdge, groundHeight / 2)`, in the same coordinate system.
4. Expect `(horizon - stoneBottom).abs() <= 1` at both scales.
5. Expect that the control-block height (the `Wrap` height of the same `GraveTombstone`) differs between scale 1.0 and scale 2.0, which proves the check is independent of it: the Horizon follows the Stone_Box bottom while the control block changes size.
6. Repeat after scrolling the content by a fixed distance; the difference stays within 1 px.

### Rise interaction (Requirement 1.4, 13.4)

`GraveTombstone`'s `Transform.translate(offset: Offset(0, (1 - progress) * riseDistance))` moves the stone **down** by `(1 - progress) * riseDistance` while it rises, and it sits *inside* the keyed `ConstrainedBox`. A translate only changes painting, so the keyed box keeps its layout position, and the First_Row_Base measured from it is the resting base at every Rise_Progress. The Ground_Field's `groundTop` is derived from that value, which does not depend on `riseProgress`. A still-rising stone (`riseProgress < 1`) therefore starts painted below its resting `Stone_Base` and moves up into place, "coming up out of the ground", while the Horizon stays fixed, which satisfies Requirement 1.4. Bottom-aligning the row (`CrossAxisAlignment.end`) changes where a cell sits in the row, not how the translate is applied inside it. No change to `RiseProgress`, `riseDistance` or the translate is needed, and there is no correction term anywhere.

**Test: the Horizon does not move while the first stone rises** (`test/ui/graveyard_ground_test.dart`, Requirement 1 criterion 4 and Requirement 12, in particular 12.7). Pump a scene with a first-row stone that is rising (a new grave with a rise controller), at width 360 and 768, text scale 1.0. After the first measurement frame, record the Horizon (top of the Ground_Field plus `min(GroundPainter.maxSoftEdge, groundHeight / 2)`, in the coordinate system of the rows `Column`) and the Ground_Field rect. Then `pump(Duration)` through the Rise, sampling at several points (for example 0, 25, 50, 75 and 100 percent of `RiseProgress.durationMs`, and once after the rise has ended and the scene has settled). At every sample expect: the Horizon and the Ground_Field top are equal to the first recording within 0.5 px; `tester.binding.hasScheduledFrame` is false once the rise has ended and settled (no measurement loop); and, to prove the test really covers a rise, the painted position of the stone (the top of its `Opacity` ancestor rect, which includes the translate) moves up by about `GraveTombstone.riseDistance` between the first and the last sample while the Horizon does not. Repeat with Reduced_Motion on, where the rise has no intermediate samples and the Horizon is the same before and after.

### Tilt interaction

Tilt (`_Tilted`, `Transform.rotate(alignment: Alignment.bottomCenter)`) already pivots at the Stone's own bottom-center, which is unaffected by how the *row* aligns its children — tilt is purely local to one stone's own `RenderBox`. Bottom-aligning the row only changes the row-level `top` offset applied to each cell by `Row`'s layout, not anything inside a cell, so the tilt pivot continues to sit exactly on the (now shared) `Row_Base_Line`.

### Column layout (Requirement 13.4)

`SceneLayout.columnsFor`/`tombstoneWidthFor`/`cellFor` are unchanged; the number of columns per width and the horizontal placement of each cell are untouched. Only the row's `crossAxisAlignment` changes.

### Existing test change (Requirement 13.5)

`test/ui/graveyard_scene_test.dart`, group `layout`, the local helper `columns`:

```dart
final tops = <double>[
  for (var i = 0; i < 8; i++)
    tester.getTopLeft(find.byType(GraveTombstone).at(i)).dy,
];
return tops.where((dy) => (dy - tops.first).abs() < 1).length;
```

becomes (reading the bottom instead of the top, everything else — the grave count of 8, the 1px tolerance, the three test names `360 px shows one column`, `768 px shows 2 to 4 columns` (parametrized by width, producing the two `1280`/`768` test cases), and their expected column counts — stays the same):

```dart
final bottoms = <double>[
  for (var i = 0; i < 8; i++)
    tester.getBottomLeft(find.byType(GraveTombstone).at(i)).dy,
];
return bottoms.where((dy) => (dy - bottoms.first).abs() < 1).length;
```

No other line of that file changes.

## Data Models

No new data model or domain entity is introduced for the ground. The only pure values involved are geometry doubles (`groundTop`, `groundHeight`, `stoneBase`), which are computed inline in the widget layer because they depend on real rendered sizes (see Architecture, Option A rejection) — **except** for the Verdict_Slot height, the one case where a pure function usefully isolates the "how tall must this reserved space be" math from Flutter altogether:

### New pure type: `VerdictSlotHeight` (`lib/src/domain/seance/verdict_slot_height.dart`)

```dart
/// Computes the height to reserve for the Verdict_Slot of a séance sheet.
abstract final class VerdictSlotHeight {
  /// The height, in logical pixels, that fits [maxCodeUnits] UTF-16 code
  /// units of verdict text in a text style whose line height is
  /// [lineHeight] logical pixels, and is at least [minHeight] (the height of
  /// the `GhostLoader`). The caller computes [charsPerLine] from the
  /// available width (measured with `TextPainter` in `seance_sheet.dart`),
  /// so no width is passed.
  static double of({
    required double lineHeight,
    required double minHeight,
    required int maxCodeUnits,
    required double charsPerLine,
  });
}
```

This stays pure Dart (no Flutter import) by taking `charsPerLine` (an average character width in logical pixels for the verdict's `TextStyle`, measured once by the caller with `TextPainter` — the one Flutter-dependent step, kept in `seance_sheet.dart`) as a plain `double` input rather than measuring text itself. The function:

```
lines = ceil(maxCodeUnits / charsPerLine)
height = max(minHeight, lines * lineHeight)
```

This is one of two new files under `lib/src/domain` this feature adds (the other is `scene/ground_height.dart`, below). It gets a unit test (`test/domain/seance/verdict_slot_height_test.dart`) for concrete inputs (`verdictMaxLength` at a representative width/line-height) and a property test (`test/domain/seance/verdict_slot_height_property_test.dart`) because it has a real numeric invariant — see Property 2 below — making it suitable for PBT per the workspace's testing rules ("Logic with numeric rules or invariants ... also gets property-based tests with glados").

### New pure type: `GroundHeight` (`lib/src/domain/scene/ground_height.dart`)

The ground-height calculation is a pure function of three doubles, so it lives in the domain layer next to `SceneLayout`, not in `graveyard_scene.dart`. It takes the measured values as plain parameters and has no Flutter import.

```dart
/// Computes the height of the Ground_Field in the scrolling scene content.
abstract final class GroundHeight {
  /// The height, in logical pixels, of a ground whose top edge is [groundTop].
  ///
  /// The ground reaches at least [contentBottom] (the bottom of the scroll
  /// content) and at least [viewportHeight] (the bottom of the scene), all
  /// measured in the same coordinate space as [groundTop]. The result is never
  /// negative, also when [groundTop] lies below both bottoms.
  static double of({
    required double groundTop,
    required double contentBottom,
    required double viewportHeight,
  });
}
```

It computes `max(0, contentBottom - groundTop, viewportHeight - groundTop)`. The widget layer keeps the render-box measurements (`_stoneBase`, `_contentHeight`) and calls `GroundHeight.of` with `groundTop = stoneBase - GroundPainter.maxSoftEdge`, where `stoneBase` is the directly measured First_Row_Base. Requirement 12.10 is satisfied for the Soft_Edge by `GroundPainter.maxSoftEdge` (a plain `static const double`) and for the ground and Verdict_Slot heights by `GroundHeight.of` and `VerdictSlotHeight.of`; neither pure class adds a Flutter import to `lib/src/domain`. The real on-screen distance between the Horizon and the First_Row_Base stays a widget-test matter, because it depends on rendered text.

`GroundHeight` has one public class and doc comments on the class and on `of`, per the workspace rules. Its tests are `test/domain/scene/ground_height_test.dart` (concrete values: a short scene where the viewport term wins, a tall scene where the content term wins, `groundTop` below both bottoms returning 0) and `test/domain/scene/ground_height_property_test.dart` (Properties 1 and 3).

Both new domain files are pure Dart. Files under `lib/src/domain` this feature adds: `seance/verdict_slot_height.dart` and `scene/ground_height.dart`.

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Ground fills at least to the viewport bottom

*For all* `groundTop` in `[0, viewportHeight]` and `contentBottom >= groundTop`, the computed `groundHeight` SHALL be at least `viewportHeight - groundTop`, so `groundTop + groundHeight >= viewportHeight`.

**Validates: Requirements 2.2, 2.4**

### Property 2: Verdict slot height is monotone and bounded below

*For all* `maxCodeUnits >= 0`, `charsPerLine > 0`, `lineHeight > 0` and `minHeight >= 0`, `VerdictSlotHeight.of(...)` SHALL return a value that is at least `minHeight`, and increasing `maxCodeUnits` while holding the other inputs fixed SHALL never decrease the result (monotone non-decreasing in the text length).

**Validates: Requirements 8.1, 8.5**

### Property 3: Ground height never shrinks the content area

*For all* `groundTop`, `contentBottom >= groundTop` and `viewportHeight >= 0`, the computed `groundHeight` SHALL be at least `contentBottom - groundTop`, so the ground always reaches at least the bottom of the scrolled content.

**Validates: Requirements 2.3, 3.1**

These three properties are tested as plain Dart unit/property tests against the two pure domain classes: `VerdictSlotHeight.of` (Property 2) and `GroundHeight.of` (Properties 1 and 3), neither of which needs a widget pump. The widget-level claims (the Horizon's real on-screen distance to the First_Row_Base, the Horizon against the measured Stone_Box bottom independent of the control-block height (Requirements 1.8, 12.3), scroll-by-`d` equality, row base alignment, sheet height) stay **widget tests** per Requirements 12.2/12.3/13.6, because they depend on real text layout and are measured, not computed from a formula. Per the workflow's PBT guidance, UI rendering and alignment that depends on measured layout is not a good PBT candidate; the two pure classes are the bounded-input core where properties apply.

## Error Handling

- **Measurement not yet available** (`_stoneBase == null` on the first build): the Ground_Field is in the tree with height 0 and paints nothing; it never throws and never builds a negative-size `CustomPaint` (`GroundHeight.of` is never negative and the unmeasured case passes 0 directly). The ground appears at its exact place after the first post-frame measurement.
- **Rise in progress during a measurement**: the key sits outside the rise translate, so a measurement taken at any Rise_Progress returns the resting base. There is no `riseDistance` correction to get wrong, and a measurement while the stone rises cannot move the Horizon.
- **Grave count changes to zero mid-animation** (e.g. the last tombstone is deleted while another is rising): `_disposeAllRises`/`_disposeRise` already handle rise controllers being torn down; the ground switch to `Ground_Band` happens on the same `rows.isEmpty` check used for `noRows`, so no stale `GlobalKey` is read (the first-row `Row` and its key are simply absent from the next `build`, and the measurer only reads keys that exist in the current tree).
- **Column count changes due to resize** (Requirement 3.3): a change of the viewport size sets `_needsMeasure` (see "Measurement"), so a width change that changes `SceneLayout.columnsFor` triggers a fresh post-frame measurement of the new first row and recomputes `First_Row_Base`. The 0.5 px guard keeps this from looping.
- **Verdict longer than the reserved slot** (Requirement 8.5): the `Verdict_Slot` is not a hard-clipped `SizedBox` with a fixed height; it is a `ConstrainedBox(constraints: BoxConstraints(minHeight: reservedHeight))` holding the actual `Verdict_Block`/`GhostLoader`, so a verdict that needs more room than reserved simply grows the slot (and the sheet, and the scroll range) instead of clipping or throwing.
- **Keyboard/safe-area inset changes while the sheet is open** (Requirement 7.7): the existing `Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom))` plus `SafeArea` wrapping is kept; sizing the sheet to content (instead of `Align(topCenter)` filling available height) does not remove either of these insets-aware wrappers.

## Testing Strategy

**Dual approach:** property tests for the two pure domain classes (`VerdictSlotHeight.of`, `GroundHeight.of`), unit tests for representative concrete layouts/themes, and widget tests (per Requirement 12) for everything that depends on real measured layout, contrast or semantics — which is most of this feature, since both defects are rendering-coordinate bugs rather than business logic.

- **Property-based tests** (glados, ≥ 100 iterations each, tagged with `Feature: graveyard-polish, Property N: ...` per the design property it covers):
  - `test/domain/seance/verdict_slot_height_property_test.dart` — Property 2.
  - `test/domain/scene/ground_height_property_test.dart` — Properties 1 and 3 (mirrors `lib/src/domain/scene/ground_height.dart`).
- **Unit tests**: `test/domain/scene/ground_height_test.dart` for concrete ground heights; `test/domain/seance/verdict_slot_height_test.dart` for concrete values (e.g. `maxCodeUnits: 140` at a representative `charsPerLine`/`lineHeight`, confirming the slot comfortably fits the existing `GhostLoader` default size).
- **New widget test files** (Requirement 12.1), covering Requirements 1–10 and 13 at the Test_Widths/Test_Scales grid:
  - `test/ui/graveyard_ground_test.dart` — Horizon-to-First_Row_Base distance (≤ 1px) at each width/scale with 1, 3 and 8 graves; scroll-by-`d` equality; Empty_State/All_Risen_State band shape and the exactly-one-of-Ground_Field-or-Ground_Band invariant; Reduced_Motion; a rising grave; a row with mixed stone heights (long vs. short name) checked against both the Horizon and each other, per Requirement 13.6. Added tests for the post-frame measurement:
    - *First frame*: after the first `pumpWidget` the Ground_Field has height 0 and paints nothing; after one `pump()` it sits at its measured place.
    - *No change after a second frame*: after that frame, `pump()` again and assert that the ground's rect is unchanged (≤ 0.5 px) and that `tester.binding.hasScheduledFrame` is false, so no rebuild loop runs.
    - *Re-measure after a resize*: change `tester.view.physicalSize` (for example 400 → 768 wide, so the column count changes), `pump()` twice, and assert that the Horizon is again within 1 px of the new First_Row_Base. Variants for a text-scale change and for a delete of the first grave check the other triggers.
    - *Row base alignment at text scale 2.0*, width 320 and 768, as described under "`_rows` bottom alignment".
    - *Horizon equals the measured Stone_Box bottom, independent of the control block* (Requirement 1.8, 12.2, 12.3): see "Test: Horizon equals the Stone_Box bottom" below.
  - `test/ui/seance_sheet_polish_test.dart` — **sheet surface height** (the nearest `Material` ancestor of `SeanceSheet`, which is the `BottomSheet`'s surface, not the scroll view): with short content at text scale 1.0 on 1280×800 the surface height is `< 90%` of the view height (Requirement 7.2) and, to rule out a centered-content-in-a-full-height-surface regression, also less than the surface height measured for the same sheet when the content is made tall; at text scale 2.0 on a 320×568 screen the content is taller than the offered height, the `SingleChildScrollView` has `maxScrollExtent > 0` (it scrolls), the surface is at most the screen height, and the close button's rect lies fully inside the screen at offset 0, is hit-testable and closes the sheet on tap, and stays reachable after scrolling down and back up (Requirement 7.3/7.4/7.8/12.8); the short-screen case (320×260, scale 2.0); Verdict_Slot height stability across pending→ready and pending→fallback (no movement of title/score/steps, extending the existing two tests of `seance_sheet_test.dart` rather than duplicating them — Requirement 8.2); left/right alignment of the Verdict_Block against the Sheet_Steps' number column within 0.5px (Requirement 10.1–10.2); the verdict's larger font size and the accent bar's width/color and contrast (Requirement 9.1–9.4); the ten-`Text`/one-`Icon`/one-raised-`DecoratedBox` budget (Requirement 9.5) re-verified unchanged alongside the new accent bar, which is drawn with a `CustomPaint`/`DecoratedBox` using `tokens.primary` directly (not the `raised` fill), so it does not add to that `DecoratedBox` count.
  - A contrast-focused widget test (can live in `graveyard_ground_test.dart` or a dedicated `test/ui/ground_contrast_test.dart`) pinning ≥ 4.5 for the Séance label, the Delete label and the Delete icon color against `CoffinColorTokens.background`, in both themes, using `WcagContrast.ratio` directly — see the measured ratios and chosen tokens below.

### Measured contrast (Requirement 6, 9.3, 9.4)

Measured by a throwaway widget test (`flutter test`, not committed) that pumped a `GraveTombstone` in each theme and read the resolved `Icon`/`TextButton` label color via `DefaultTextStyle.of(element).style.color`, then computed `WcagContrast.ratio` against each theme's `CoffinColorTokens.background`:

| Theme | Current Séance/Delete color | Ratio vs. `background` | Passes 4.5? |
|---|---|---|---|
| night | `primary` (`0xFF9B6BFF`, from `textButtonTheme`'s `foregroundColor` default, i.e. `ColorScheme.primary`) | 5.51 | yes |
| daylight | `primary` (`0xFF6B3FD4`) | 5.84 | yes |

Both themes' `TextButton` foreground (set by `CoffinTheme._buttonStyle`'s default, which resolves to `ColorScheme.primary = tokens.primary`) already clears 4.5:1 against `background` in both themes today. No label color change is required by Requirement 6.4 (`IF a control label does not reach ... THEN change it`) — the condition is false in both themes. **Decision:** keep `SeanceControl`'s and the Delete `TextButton`'s colors exactly as inherited from the ambient `TextButtonTheme` (`tokens.primary`), and add Requirement 6.6's pinning test asserting `WcagContrast.ratio(tokens.primary.toARGB32(), tokens.background.toARGB32()) >= WcagContrast.aaNormalText` for both `CoffinColorTokens.night` and `CoffinColorTokens.daylight`, documenting that this is the token the controls use (no code change to `seance_control.dart` or the Delete button in `grave_tombstone.dart` is needed for Requirement 6 beyond this pinned test).

For reference, the other tokens measured against `background` (not used, since `primary` already passes): `text` 15.99/16.28, `muted` 6.45/6.89, `secondary` 8.31/5.41, `tertiary` 15.59/6.03, `error` 6.06/6.19 (night/daylight respectively).

For the Verdict_Block (Requirement 9.3–9.4), measured against `CoffinColorTokens.surface`:

| Theme | Verdict text (`tokens.text` on `surface`) | Accent bar (`tokens.primary` on `surface`) |
|---|---|---|
| night | 14.63 (≥ 4.5 ✓) | 5.04 (≥ 3.0 ✓) |
| daylight | 17.83 (≥ 4.5 ✓) | 6.39 (≥ 3.0 ✓) |

**Decision:** the Verdict_Block uses `tokens.text` for the verdict text (same as today's `_verdictArea`, no change) and `tokens.primary` for the accent bar, both already clearing their respective thresholds in both themes — matching Requirement 9.2/9.3/9.4 with no new token and no fallback branch needed.

### Séance sheet sizing (Requirement 7, 8)

**What the real code does today.** `showSeanceSheet` calls `showModalBottomSheet` with `isScrollControlled: true` and `useSafeArea: true`, and passes no `constraints`. Flutter's `_BottomSheetLayoutWithSizeListener` (`bottom_sheet.dart`, `_getConstraintsForChild`) gives the sheet `BoxConstraints(minWidth: maxWidth, maxWidth: maxWidth, maxHeight: constraints.maxHeight)` with `minHeight` 0 when `isScrollControlled` is true (with it false, `maxHeight` would be 9/16 of the screen). So the route offers a **loose** height with a full-screen maximum, and the `BottomSheet`'s `Material` surface takes the size of whatever its child reports. In `SeanceSheet.build` the chain below the surface is `Padding(viewInsets.bottom)` → `SafeArea` → `Align(topCenter)` → `ConstrainedBox(maxWidth: 560)` → `SingleChildScrollView` → `Column(mainAxisSize: min)`. An `Align` with no `heightFactor` and bounded constraints sizes itself to the **maximum** height (it only shrink-wraps when a factor is set or the constraint is unbounded). So the `Align` reports full height, the `SafeArea` and `Padding` above it report full height, and the surface is screen-tall; the content merely sits at the top of it. This is the defect.

**Why the first draft (`Align` → `Center`) is not a fix.** `Center` is an `Align` with `Alignment.center`, with the same rule: bounded constraints and no `heightFactor` give the maximum height. The surface would still be full height, with the content centered vertically inside it. That is exactly "centered content in a full-height sheet", so that approach is dropped.

**Chosen approach: keep `isScrollControlled: true` and give the `Align` a `heightFactor`.**

```dart
SafeArea(
  child: Align(
    alignment: Alignment.topCenter,
    heightFactor: 1,                       // height = child height (loose max kept)
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, ...),
      ),
    ),
  ),
)
```

- `Align(heightFactor: 1)` sizes its height to `child height * 1` and passes the child the loosened constraints (min 0, max unchanged). With no `widthFactor` it still fills the width, and `Alignment.topCenter` still centers the 560 px `ConstrainedBox` horizontally, so the width and centering that `seance_sheet_layout_test.dart` asserts do not change.
- The `SingleChildScrollView` receives `maxHeight` equal to the height the route offers (screen height, minus the top safe area from `useSafeArea: true`, minus `viewInsets.bottom` and the sheet's `SafeArea` insets). With short content it takes exactly the content height and `maxScrollExtent` is 0 (Requirement 7.1). With tall content (text scale 2.0 on a 320×568 screen) it takes the offered maximum and scrolls (Requirement 7.3), and the surface is then as tall as the offered maximum, no taller.
- `SafeArea` and the `viewInsets.bottom` `Padding` stay, so the keyboard and system insets are still honored (Requirement 7.7). Both shrink-wrap around a child of finite height.
- `isScrollControlled: true` is **kept**. Dropping it would cap the sheet at 9/16 of the screen height, which would make tall content scroll too early on a short screen. Setting `constraints: BoxConstraints(maxHeight: ...)` on the route is not needed, because the content-driven height is already below the route's maximum.
- No `IntrinsicHeight` and no `DraggableScrollableSheet`: neither is needed.

The alternative (leave `Align` and add `constraints` with a computed `maxHeight` at the call site) was rejected, because a content-dependent height cannot be known at the call site, and an upper cap alone does not shrink a widget that fills its maximum.

**Test that the surface itself is content-sized** (not only that the content is centered): see `seance_sheet_polish_test.dart` below. It measures the `Material` that is the nearest ancestor of `SeanceSheet` and compares its height with the screen height and, for the same sheet with taller content, with the larger surface.

### Verdict_Slot (Requirement 8)

`_verdictArea` currently returns either a `Center(child: GhostLoader(...))` (pending) or a `Text` (settled), with **no reserved space while pending** — i.e. nothing stops the verdict's arrival from changing the sheet's height today, other than the fact that `GhostLoader`'s default size and a single-line short verdict happen to be similar heights in the two tests that currently pin "no movement" (`a reply moves neither the score nor the steps`, `the safe line after a failure moves nothing` in `seance_sheet_test.dart`). Those two tests only ever use the specific strings `'Rise, little ghost.'` and `GraveyardCopy.safeVerdictLine`, both short one-liners, so they pass today by accident of short text, not by a real reservation. Requirement 8 requires an explicit reservation sized for `verdictMaxLength` (140 UTF-16 units), which is strictly ≥ any text that fits the existing two tests, so this feature's change (adding a `ConstrainedBox(minHeight: VerdictSlotHeight.of(...))` around the pending/settled content, replacing the bare `Center`/`Text`) can only make the slot *taller or equal*, never shorter — the two pinned tests continue to pass unmodified, because the reserved minimum height does not change *while the sheet is open* for a single long-enough verdict's text (the slot's height depends on `width`/`textScale`, which do not change mid-test in either pinned test) and the slot's height computed before the verdict and after it (pending vs. ready/fallback) is intentionally the *same* `VerdictSlotHeight.of(...)` call (same inputs: width, line height for `bodyLarge`/the new larger verdict style, `minHeight` from `GhostLoader`'s rendered size, `verdictMaxLength`), satisfying Requirement 8.2/8.3 structurally: the slot's height is computed once per `(width, textScale)` pair and reused for both the pending and the settled child, so neither state can be taller than the other's reservation unless the actual verdict text exceeds the reservation (Requirement 8.5's explicit escape hatch, via `ConstrainedBox`'s `minHeight` rather than a fixed `SizedBox` height).

### Changed/created files

**Changed:**
- `apps/graveyard/lib/src/ui/graveyard_scene.dart` — ground moved into scroll content with post-frame measurement of the Stone_Box bottom (`_stoneKey` created here and passed through `_rows`/`_tombstone` and its single `build(progress)` helper to the first `GraveTombstone` of the first row as `stoneKey`, with no rise correction) (first frame without ground, re-measure triggers, 0.5 px guard), Ground_Band/Ground_Field switch, bottom-aligned rows, class doc comment. The ground height comes from `GroundHeight.of` in the domain layer; there is no ground arithmetic helper in this file.
- `apps/graveyard/lib/src/ui/grave_tombstone.dart` — new optional constructor parameter `GlobalKey? stoneKey`, documented, applied as the `key` of the `ConstrainedBox(maxWidth: maxStoneWidth)` inside the `Center`, which is the parent of `Transform.translate` (outside the Rise translate, excluding the controls `Wrap`). It is not applied to the `stone` `Stack`. No change to layout, tilt, rise or controls.
- `apps/graveyard/lib/src/ui/ground_painter.dart` — doc comment only.
- `apps/graveyard/lib/src/ui/seance_sheet.dart` — sheet sizing (`Align(topCenter)` → `Align(topCenter, heightFactor: 1)`; `isScrollControlled` kept), Verdict_Block (larger text style, left accent bar, alignment with `Sheet_Steps`' number column), Verdict_Slot reservation using `VerdictSlotHeight.of`.
- `apps/graveyard/test/ui/graveyard_scene_test.dart` — the three named tests in group `layout`, per Requirement 13.5 (tops → bottoms). No other line changes.

**Created:**
- `apps/graveyard/lib/src/domain/seance/verdict_slot_height.dart` — pure `VerdictSlotHeight.of`.
- `apps/graveyard/lib/src/domain/scene/ground_height.dart` — pure `GroundHeight.of` (one public class, doc comments).
- `apps/graveyard/test/domain/seance/verdict_slot_height_test.dart` — unit tests.
- `apps/graveyard/test/domain/seance/verdict_slot_height_property_test.dart` — Property 2.
- `apps/graveyard/test/domain/scene/ground_height_test.dart` — unit tests for `GroundHeight.of`.
- `apps/graveyard/test/domain/scene/ground_height_property_test.dart` — Properties 1 and 3 (mirrors the `lib` path).
- `apps/graveyard/test/ui/graveyard_ground_test.dart` — widget tests for Requirements 1–5 and 13 per Requirement 12.
- `apps/graveyard/test/ui/seance_sheet_polish_test.dart` — widget tests for Requirements 7–10 per Requirement 12.
- `apps/graveyard/test/ui/ground_contrast_test.dart` — pinned contrast tests for Requirement 6 (and may also carry the Requirement 9.3/9.4 verdict/accent-bar contrast pins, or those may live in `seance_sheet_polish_test.dart`; either placement satisfies Requirement 12.9, the design does not mandate one file over the other beyond what is listed above).

No other `lib` or `test` file is touched.

### Existing tests verified unchanged

Every existing test file named in Requirement 11.4 was read in full (or in the relevant sections) during this design:

- `test/ui/ground_painter_test.dart` — tests `GroundPainter(tokens: ...)` construction with `CoffinColorTokens.night`/`.daylight`, `paint` not throwing at three sizes, and `shouldRepaint` equality/inequality. None of these depend on where a host places the painter or on its doc comment; the public constructor, `maxSoftEdge` and `shouldRepaint` are unchanged by this design. **Unaffected.**
- `test/ui/graveyard_scene_test.dart` — read in full. Only the `columns` helper inside `group('layout')` (three tests: `360 px shows one column`, and the two generated from `for (final width in <double>[768, 1280])`) changes, per Requirement 13.5. The semantics test `sky, moon, stars, ground and fog add no semantic node` asserts `withScene - bare <= 1` (at most one new semantic node, from the scroll view) and that no node carries a label — the Ground_Field, like the Ground_Band today, stays `IgnorePointer`+`ExcludeSemantics`, so it continues to add zero semantic nodes; this test is unaffected by the ground's new position. The add-button test (`the last Delete button scrolls clear of it and is tappable`) depends only on `bottomPadding`/`addButtonHeight`/`addButtonGap`, which are untouched. **Only the three named tests change; nothing else in this file changes.**
- `test/ui/resurrection_layout_test.dart` — read the `LivingRow` scrollable-ancestor assertions (lines ~399–424): `find.ancestor(of: find.byType(LivingRow), matching: find.byType(SingleChildScrollView))` expects `findsOneWidget`, and `find.descendant(of: find.byType(LivingRow), matching: find.byType(Scrollable))` expects `findsNothing`. This feature keeps exactly one `SingleChildScrollView` as the Scroll_Content's scrollable (Requirement 2.7); the ground becomes a non-scrolling sibling *inside* that same scroll view's child subtree (a `Stack` layer, not a new `Scrollable`), so there is still exactly one `SingleChildScrollView` ancestor of `LivingRow` and still no nested `Scrollable` inside `LivingRow`. **Unaffected.**
- `test/ui/layout_test.dart` — read; it asserts, among other things, that `GhostLoader`'s position does not move across a rebuild (line ~545–547) and checks overflow/tap targets across the import/add flows, none of which reference `GroundPainter`, the ground's position, or row cross-axis alignment. **Unaffected.**
- `test/ui/seance_sheet_test.dart` — read in full. The two tests named in Requirement 8 (`a reply moves neither the score nor the steps`, `the safe line after a failure moves nothing`) are preserved by construction (see "Verdict_Slot" above: the reservation can only grow the slot for text shorter than `verdictMaxLength`, never shrink it, and both states share one reservation computed from the same `(width, textScale)`). The order test (`the order is name, score and band, steps, verdict`) still holds: the Verdict_Block is still the last element after the steps, per Requirement 10.4. The remaining tests in this file (close button size/behavior, late-reply-after-close, reduced-motion content, "opening twice", controller integration) do not reference sheet height, `Align`, or verdict styling and are unaffected by adding `heightFactor: 1` to the `Align` or by the accent bar, since none of them measure the sheet's overall height or the `Text` style/color beyond what `_expectContent` checks (text presence, not exact style) — confirmed by reading `_expectContent`'s use in the file (it is `find.text(...)`-based, not style-based). **Unaffected except where Requirements 8/9/10 require the deliberate presentational changes already scoped to new test files; no existing assertion in this file is broken.**
- `test/ui/seance_sheet_layout_test.dart` — read in full. Its assertions (no overflow, no horizontally-clipped text via `_expectNoClippedText`, the `SingleChildScrollView`'s width being exactly 320 at 320px and ≤560 centered above, the short-screen scroll-and-close-stays-reachable behavior) are all expressed relative to the `SingleChildScrollView`'s own `Rect`, not to the outer `Align`/`Center` wrapper — adding `heightFactor: 1` to the `Align` does not change the `SingleChildScrollView`'s width or horizontal centering (the `Align` still fills the width and centers the child horizontally; the only behavioral difference is that its height now follows the child). The short-screen test's close-button-aligned-with-title-top assertion (`tester.getRect(close).top, closeTo(title.top, 0.5)`) is unaffected: that alignment comes from the `Row(crossAxisAlignment: CrossAxisAlignment.start)` holding the title and the close button, which this design does not touch. **Unaffected.**
- `test/ui/seance_sheet_semantics_test.dart` — read in full. It counts exactly ten `Text` widgets and one `Icon` in the ready state, and asserts every `Text`'s color against `tokens.surface` or `tokens.raised` (the score card) at ≥ 4.5, and every `Icon`'s color against `tokens.surface` at ≥ 3.0. The new accent bar is **not** a `Text` or an `Icon` — it is drawn as a thin colored shape (e.g. a `Container`/`DecoratedBox` of 2–4px width using `tokens.primary`, or a `CustomPaint`), so it does not change the count of 10 `Text` or 1 `Icon`, and it is not itself a `DecoratedBox` whose color is `tokens.raised` (Requirement 9.5 forbids exactly that, to keep the "one raised `DecoratedBox`" count at the score card only) — so the "exactly one raised `DecoratedBox`" assertion embedded in this test's loop (`behind = onRaised.contains(data) ? tokens.raised : tokens.surface`, which only inspects `Text` widgets' backgrounds, not `DecoratedBox` instances directly, but Requirement 9.5 is the authoritative constraint here) is also preserved. **Unaffected.**

No test outside this list is read as part of verifying this requirement, since Requirement 11.4 names exactly these six files as the ones this feature must keep green; other files (e.g. `grave_tombstone_test.dart`, `seance_control_test.dart`) were read during research for architecture decisions but are not among the files Requirement 11.4 requires to stay unchanged, and this design does not plan to modify them — confirmed above by their content not depending on ground placement, row alignment, or sheet sizing in a way this feature touches (e.g. `seance_control_test.dart`'s `'lies below the stone and overlaps no text or the delete'` test measures the control relative to the stone's own `Opacity` ancestor rect, not the ground or row cross-axis alignment, and remains valid since bottom-aligning the row does not change a single stone's internal layout).

