import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import '../domain/resurrection/clod.dart';
import '../domain/resurrection/clod_path_generator.dart';
import '../domain/resurrection/ghost_box.dart';
import '../domain/resurrection/hand_geometry.dart';
import '../domain/resurrection/play_timing.dart';
import '../domain/resurrection/rising_ghost_box.dart';
import 'clods_painter.dart';
import 'hand_painter.dart';

/// Plays the Hand, the Clods, the Rising_Ghost and the epitaph fade once,
/// then calls [onEnd].
///
/// Owns every controller of the play and disposes them all in
/// `dispose`, however the widget leaves the tree. Under reduced motion
/// nothing is painted: the epitaph is announced at once and a delayed
/// future waits out `PlayTiming.playDurationMs`.
class ResurrectionPlay extends StatefulWidget {
  /// Creates a play for the Grave [graveId] on a stone of [stoneSize].
  const ResurrectionPlay({
    super.key,
    required this.graveId,
    required this.stoneSize,
    required this.textScale,
    required this.onEnd,
    required this.onEpitaphRisen,
  });

  /// Id of the Grave, which seeds the Clods.
  final String graveId;

  /// Size of the Stone_Area the play is drawn in.
  final Size stoneSize;

  /// Epitaph text scale (1.0 to 2.0), used to keep the ghost under the text.
  final double textScale;

  /// Called exactly once when the play is over, never after dispose.
  final VoidCallback onEnd;

  /// Called once when the epitaph turns to "RISEN".
  final VoidCallback onEpitaphRisen;

  @override
  State<ResurrectionPlay> createState() => _ResurrectionPlayState();
}

class _ResurrectionPlayState extends State<ResurrectionPlay>
    with TickerProviderStateMixin {
  AnimationController? _tickController;
  AnimationController? _epitaphFade;
  int _waitGeneration = 0;
  late List<Clod> _clods;
  bool _started = false;
  bool _reduced = false;
  bool _ended = false;
  bool _epitaphAnnounced = false;
  int _reactionKey = 0;

  @override
  void initState() {
    super.initState();
    _clods = ClodPathGenerator.generate(widget.graveId);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    if (!_started) {
      _started = true;
      _reduced = reduced;
      if (reduced) {
        _startReduced(PlayTiming.playDurationMs);
      } else {
        _startAnimated();
      }
    } else if (reduced && !_reduced) {
      _reduced = true;
      _switchToReduced();
    }
  }

  @override
  void didUpdateWidget(ResurrectionPlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.graveId != widget.graveId) {
      _clods = ClodPathGenerator.generate(widget.graveId);
    }
  }

  void _startAnimated() {
    final AnimationController tick = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: PlayTiming.playDurationMs),
    );
    _tickController = tick;
    _epitaphFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: PlayTiming.epitaphFadeMs),
    );
    tick.addListener(_onTick);
    tick.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) _end();
    });
    tick.forward();
  }

  int get _elapsedMs {
    final AnimationController? tick = _tickController;
    if (tick == null) return PlayTiming.playDurationMs;
    return (tick.value * PlayTiming.playDurationMs).round();
  }

  void _onTick() {
    final int elapsed = _elapsedMs;
    if (_reactionKey == 0 && elapsed >= PlayTiming.risingGhostStartMs) {
      _reactionKey = 1;
    }
    if (!_epitaphAnnounced && elapsed >= PlayTiming.epitaphFadeStartMs) {
      _announceEpitaph();
      _epitaphFade?.forward();
    }
  }

  void _announceEpitaph() {
    if (_epitaphAnnounced) return;
    _epitaphAnnounced = true;
    widget.onEpitaphRisen();
  }

  void _startReduced(int remainingMs) {
    _announceEpitaph();
    final int generation = ++_waitGeneration;
    Future<void>.delayed(
      Duration(milliseconds: remainingMs < 0 ? 0 : remainingMs),
    ).then((_) {
      if (generation != _waitGeneration || !mounted || _ended) return;
      _end();
    });
  }

  void _switchToReduced() {
    final int remaining = PlayTiming.playDurationMs - _elapsedMs;
    _tickController?.dispose();
    _tickController = null;
    _epitaphFade?.dispose();
    _epitaphFade = null;
    _startReduced(remaining < 0 ? 0 : remaining);
  }

  void _end() {
    if (_ended || !mounted) return;
    _ended = true;
    widget.onEnd();
  }

  @override
  void dispose() {
    _waitGeneration++;
    _tickController?.dispose();
    _epitaphFade?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = widget.stoneSize;
    final CoffinColorTokens tokens =
        Theme.of(context).brightness == Brightness.dark
        ? CoffinColorTokens.night
        : CoffinColorTokens.daylight;
    final AnimationController? tick = _tickController;
    final Widget body = tick == null
        ? _frame(size, tokens, PlayTiming.playDurationMs, animated: false)
        : AnimatedBuilder(
            animation: tick,
            builder: (BuildContext context, Widget? _) =>
                _frame(size, tokens, _elapsedMs, animated: true),
          );
    return ExcludeSemantics(
      child: IgnorePointer(
        child: SizedBox(width: size.width, height: size.height, child: body),
      ),
    );
  }

  Widget _frame(
    Size size,
    CoffinColorTokens tokens,
    int elapsedMs, {
    required bool animated,
  }) {
    final GhostBox box = RisingGhostBox.at(
      width: size.width,
      height: size.height,
      textScale: widget.textScale,
      elapsedMs: animated ? elapsedMs : PlayTiming.ghostRiseEndMs,
    );
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: <Widget>[
        if (animated) ...<Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: HandPainter(
                shape: HandGeometry.at(
                  width: size.width,
                  height: size.height,
                  elapsedMs: elapsedMs,
                ),
                tokens: tokens,
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: ClodsPainter(
                clods: _clods,
                elapsedMs: elapsedMs,
                tokens: tokens,
              ),
            ),
          ),
        ],
        if (animated ? box.visible : box.width > 0)
          Positioned(
            left: box.left,
            top: box.top,
            width: box.width,
            height: box.height,
            child: ExcludeSemantics(
              child: FittedBox(
                child: GhostLoader(
                  size: box.height,
                  mood: GhostMood.rising,
                  reactionKey: _reactionKey,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
