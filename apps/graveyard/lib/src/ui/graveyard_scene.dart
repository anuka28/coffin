import 'dart:math' as math;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../domain/calendar_date.dart';
import '../domain/grave.dart';
import '../domain/living_split.dart';
import '../domain/scene/new_grave_ids.dart';
import '../domain/scene/rise_progress.dart';
import '../domain/scene/scene_layout.dart';
import '../domain/scene/star.dart';
import '../domain/scene/star_field.dart';
import 'grave_tombstone.dart';
import 'graveyard_clipboard.dart';
import 'ground_painter.dart';
import 'living_row.dart';
import 'night_sky_painter.dart';

/// The Graveyard night scene: sky, ground and fog behind rows of tombstones.
///
/// The sky, the ground and the fog never scroll. Only the rows of tombstones
/// scroll. [SceneLayout] places the rows: one column below 720 px, two to four
/// from 720 px, with a short last row centered. Each grave that appears after
/// the first list rises once out of the ground. Graves in the first list never
/// rise. With `MediaQuery.disableAnimations` the scene is still: no twinkle,
/// no rise and no fog drift.
///
/// The scene reads no clock. The age of every grave comes from [today].
class GraveyardScene extends StatefulWidget {
  /// Creates the scene for [graves], counted to [today].
  const GraveyardScene({
    super.key,
    required this.graves,
    required this.today,
    required this.onDelete,
    required this.seanceAi,
    this.header,
    this.noRows,
    this.playingIds = const <String>{},
    this.onPlayEnd,
    this.onRaise,
    this.onLayToRest = _ignoreLayToRest,
    this.clipboard = const SystemGraveyardClipboard(),
  });

  static void _ignoreLayToRest(Grave grave) {}

  /// The graves to show, in display order.
  final List<Grave> graves;

  /// The current day.
  final CalendarDate today;

  /// Called with the grave whose delete button was pressed.
  final ValueChanged<Grave> onDelete;

  /// The AI that words the verdict line of each séance.
  final CoffinAI seanceAi;

  /// Optional content shown at the top of the scrolling content, above the
  /// rows. It scrolls with the graves while the sky, ground and fog stay put.
  final Widget? header;

  /// Shown below the Living_Row in place of the rows, when no grave is left
  /// in the rows but the Living_Row is not empty.
  final Widget? noRows;

  /// Ids of the graves whose Resurrection_Play runs now. A risen grave stays
  /// in the rows until its id leaves this set.
  final Set<String> playingIds;

  /// Called with the id of a grave when its Resurrection_Play ends.
  final ValueChanged<String>? onPlayEnd;

  /// Called with the grave the user raised from its séance sheet.
  final ValueChanged<Grave>? onRaise;

  /// Called with the grave whose "Lay it back to rest" was pressed.
  final ValueChanged<Grave> onLayToRest;

  /// Where repository links of the Living_Row are copied to.
  final GraveyardClipboard clipboard;

  /// Side padding of the Living_Row, equal to the one of the screen header.
  static const double _livingSide = 16;

  /// Widest content column of the Living_Row.
  static const double _livingMaxWidth = 560;

  /// Seed of the star field.
  static const int starSeed = 13;

  /// Vertical padding above and below the rows.
  static const double verticalPadding = 24;

  /// Height of the floating add button (`FloatingActionButton.extended`).
  static const double addButtonHeight = 56;

  /// Free space kept between the last row and the floating add button.
  static const double addButtonGap = 32;

  /// Bottom padding of the scrolling rows. The add button floats over the
  /// scene, so the last Delete button must be able to scroll clear of it.
  static const double bottomPadding = addButtonHeight + addButtonGap;

  /// Horizontal tilt margin of a stone of [tombstoneWidth] (3 degrees).
  static double tiltMargin(double tombstoneWidth) =>
      tombstoneWidth * math.sin(3 * math.pi / 180);

  @override
  State<GraveyardScene> createState() => _GraveyardSceneState();
}

class _GraveyardSceneState extends State<GraveyardScene>
    with TickerProviderStateMixin<GraveyardScene> {
  /// Repeating Twinkle controller. Same idea as `MotionLoop`: it runs while
  /// motion is allowed and stops while `disableAnimations` is true.
  late final AnimationController _twinkle = AnimationController(
    vsync: this,
    duration: const Duration(minutes: 10),
  );

  final Map<String, AnimationController> _rises =
      <String, AnimationController>{};
  late List<String> _previousIds;

  Size? _starSize;
  List<Star> _stars = const <Star>[];

  static List<String> _idsOf(List<Grave> graves) => <String>[
    for (final grave in graves) grave.id,
  ];

  /// The graves shown in the rows: every grave that is not in the Living_Row.
  static List<Grave> _rowsOf(GraveyardScene scene) =>
      LivingSplit.split(graves: scene.graves, playing: scene.playingIds).$1;

  bool get _reduced => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    _previousIds = _idsOf(_rowsOf(widget));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduced) {
      _twinkle.stop();
      _disposeAllRises();
    } else if (!_twinkle.isAnimating) {
      _twinkle.repeat();
    }
  }

  @override
  void didUpdateWidget(GraveyardScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _idsOf(_rowsOf(widget));
    final fresh = NewGraveIds.diff(previous: _previousIds, next: next);
    final alive = next.toSet();
    for (final id in _rises.keys.toList()) {
      if (!alive.contains(id)) _disposeRise(id);
    }
    if (!_reduced) {
      for (final id in fresh) {
        _startRise(id);
      }
    }
    _previousIds = next;
  }

  void _startRise(String id) {
    if (_rises.containsKey(id)) return;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: RiseProgress.durationMs),
    );
    controller.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _rises[id] != controller) return;
        setState(() => _disposeRise(id));
      });
    });
    _rises[id] = controller;
    controller.forward();
  }

  void _disposeRise(String id) => _rises.remove(id)?.dispose();

  void _disposeAllRises() {
    for (final id in _rises.keys.toList()) {
      _disposeRise(id);
    }
  }

  @override
  void dispose() {
    _disposeAllRises();
    _twinkle.dispose();
    super.dispose();
  }

  List<Star> _starsFor(Size size) {
    if (_starSize != size) {
      _starSize = size;
      _stars = StarField.generate(
        seed: GraveyardScene.starSeed,
        width: size.width,
        height: size.height,
        moonCx: NightSkyPainter.moonCx(size.width),
        moonCy: NightSkyPainter.moonCy(size.height),
        moonRadius: NightSkyPainter.moonRadius(size.width, size.height),
      );
    }
    return _stars;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).brightness == Brightness.dark
        ? CoffinColorTokens.night
        : CoffinColorTokens.daylight;
    final reduced = _reduced;
    final split = LivingSplit.split(
      graves: widget.graves,
      playing: widget.playingIds,
    );
    final List<Grave> rows = split.$1;
    final List<Grave> living = split.$2;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final size = Size(width, height);
        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: NightSkyPainter(
                          tokens: tokens,
                          stars: _starsFor(size),
                          reducedMotion: reduced,
                          twinkle: reduced ? null : _twinkle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: height * 0.34,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: CustomPaint(painter: GroundPainter(tokens: tokens)),
                  ),
                ),
              ),
              Positioned.fill(
                child: FogBackground(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      top: GraveyardScene.verticalPadding,
                      bottom:
                          GraveyardScene.bottomPadding +
                          MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (widget.header != null) widget.header!,
                        if (living.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal:
                                  GraveyardScene._livingSide +
                                  math.max(
                                    0,
                                    (width - GraveyardScene._livingMaxWidth) /
                                        2,
                                  ),
                            ),
                            child: LivingRow(
                              entries: living,
                              onLayToRest: widget.onLayToRest,
                              clipboard: widget.clipboard,
                            ),
                          ),
                        if (rows.isEmpty &&
                            living.isNotEmpty &&
                            widget.noRows != null)
                          widget.noRows!
                        else
                          _rows(width, rows),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _rows(double availableWidth, List<Grave> graves) {
    final columns = SceneLayout.columnsFor(availableWidth);
    final children = <Widget>[];
    for (var start = 0; start < graves.length; start += columns) {
      final end = math.min(start + columns, graves.length);
      final first = SceneLayout.cellFor(
        index: start,
        graveCount: graves.length,
        availableWidth: availableWidth,
      );
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: SceneLayout.rowGap));
      }
      children.add(
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.only(left: first.left),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (var i = start; i < end; i++) ...<Widget>[
                  if (i > start) const SizedBox(width: SceneLayout.gap),
                  SizedBox(width: first.width, child: _tombstone(graves[i])),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _tombstone(Grave grave) {
    final rise = _rises[grave.id];
    Widget build(double progress) => GraveTombstone(
      grave: grave,
      today: widget.today,
      onDelete: () => widget.onDelete(grave),
      seanceAi: widget.seanceAi,
      riseProgress: progress,
      playing: widget.playingIds.contains(grave.id),
      onPlayEnd: () => widget.onPlayEnd?.call(grave.id),
      onRaise: widget.onRaise,
    );
    if (rise == null) {
      return KeyedSubtree(key: ValueKey<String>(grave.id), child: build(1));
    }
    return KeyedSubtree(
      key: ValueKey<String>(grave.id),
      child: AnimatedBuilder(
        animation: rise,
        builder: (context, _) => build(
          RiseProgress.at((rise.value * RiseProgress.durationMs).round()),
        ),
      ),
    );
  }
}
