import 'package:flutter/material.dart';

import '../theme/coffin_color_tokens.dart';
import '../theme/coffin_glow.dart';
import '../theme/coffin_typography.dart';
import 'ghost_mood.dart';
import 'ghost_painter.dart';
import 'math/ghost_bob.dart';
import 'math/mood_blend.dart';
import 'math/mood_bob.dart';
import 'math/mood_pose.dart';
import 'math/mood_reaction.dart';
import 'math/mood_traits.dart';
import 'motion_loop.dart';
import 'spooky_tokens.dart';

/// A small bobbing ghost with an optional caption, for loading states.
///
/// The ghost floats slowly up and down. When `MediaQuery.disableAnimations`
/// is true it is drawn as a still frame and nothing ticks. The widget exposes
/// one semantics node whose label is [caption], or "Loading" without one, and
/// which is a live region.
///
/// With a [mood] the ghost wears that mood's face and posture, in a box whose
/// size depends only on [size], so a mood change never moves the layout.
class GhostLoader extends StatefulWidget {
  /// Creates a ghost loader.
  ///
  /// [size] is the ghost height in logical pixels, clamped into 24 to 256
  /// (NaN becomes 64). [caption] is shown below the ghost when not null.
  /// [bobPeriodMs] and [bobAmplitude] are clamped by `GhostBob`.
  const GhostLoader({
    super.key,
    this.size = 64,
    this.caption,
    this.bobPeriodMs = GhostBob.defaultPeriodMs,
    this.bobAmplitude = GhostBob.defaultAmplitude,
    this.mood,
    this.reactionKey = 0,
    this.onReactionEnd,
  });

  /// Ghost height in logical pixels, before clamping.
  final double size;

  /// Optional text below the ghost. Also the semantics label.
  final String? caption;

  /// Bob period in milliseconds, before clamping.
  final int bobPeriodMs;

  /// Bob amplitude in logical pixels, before clamping.
  final double bobAmplitude;

  /// The mood the ghost shows, or null for the legacy look.
  ///
  /// [bobPeriodMs] and [bobAmplitude] are ignored when this is not null. Null
  /// means the Legacy_Look: two round eyes, no mouth, no mood box.
  final GhostMood? mood;

  /// Event counter for reaction moods.
  ///
  /// The caller increments it once per event.
  final int reactionKey;

  /// Called once when a reaction run ends, or once after the first frame
  /// under reduced motion.
  final VoidCallback? onReactionEnd;

  @override
  State<GhostLoader> createState() => _GhostLoaderState();
}

class _GhostLoaderState extends State<GhostLoader>
    with SingleTickerProviderStateMixin<GhostLoader>, MotionLoop<GhostLoader> {
  late GhostBob _bob = _makeBob();

  GhostBob _makeBob() =>
      GhostBob(periodMs: widget.bobPeriodMs, amplitude: widget.bobAmplitude);

  double get _size {
    final double s = widget.size;
    return s.isNaN ? 64 : s.clamp(24.0, 256.0);
  }

  MoodPose _from = MoodPose.rest(GhostMood.thriving);
  int _blendStartMs = 0;
  int _blendMs = 0;
  int? _runStartMs;
  bool _endHandled = false;
  bool _wasReduced = false;
  bool _depsReady = false;

  /// True from a mood or key change until the settle check collapses a
  /// `dead` ghost to its rest pose. Only read for `dead`.
  bool _animating = false;

  @override
  bool get loopWanted => widget.mood != GhostMood.dead || _animating;

  @override
  void initState() {
    super.initState();
    final GhostMood? mood = widget.mood;
    if (mood != null) {
      _from = MoodPose.rest(mood);
    }
    loopController.addListener(_onTick);
  }

  @override
  void dispose() {
    loopController.removeListener(_onTick);
    super.dispose();
  }

  /// Calls [GhostLoader.onReactionEnd] once per run. Never rebuilds.
  void _onTick() {
    final GhostMood? mood = widget.mood;
    if (mood == GhostMood.dead &&
        _animating &&
        _runStartMs == null &&
        elapsedMs - _blendStartMs >= _blendMs) {
      _from = MoodPose.rest(GhostMood.dead);
      _blendStartMs = 0;
      _runStartMs = null;
      _animating = false;
      loopController.stop();
      return;
    }
    final int? start = _runStartMs;
    if (mood == null || start == null || _endHandled) {
      return;
    }
    if (elapsedMs - start >= MoodReaction.durationMs(mood)) {
      _endHandled = true;
      widget.onReactionEnd?.call();
    }
  }

  void _callEndAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        widget.onReactionEnd?.call();
      }
    });
  }

  /// Drops any blend and run and holds the rest pose of the current mood.
  void _resetToRest() {
    final GhostMood? mood = widget.mood;
    _from = MoodPose.rest(mood ?? GhostMood.thriving);
    _blendStartMs = 0;
    _blendMs = 0;
    _runStartMs = null;
    _endHandled = false;
    _animating = false;
  }

  /// The pose shown at [ms] on the loop clock.
  MoodPose poseAt(int ms, {GhostMood? mood}) {
    mood ??= widget.mood!;
    MoodPose target = MoodPose.rest(mood);
    final int? start = _runStartMs;
    if (start != null) {
      final double p = MoodReaction.progressAt(mood, ms - start);
      target = target.copyWith(
        scale: MoodReaction.scaleAt(mood, p),
        lift: MoodReaction.liftAt(mood, p),
        opacity: MoodReaction.opacityAt(mood, p),
      );
    }
    final double e = MoodBlend.progressAt(ms - _blendStartMs, _blendMs);
    return MoodBlend.mix(_from, target, e);
  }

  void _startBlend(
    int ms,
    int blendMs, {
    required GhostMood shownMood,
    required bool run,
  }) {
    _from = poseAt(ms, mood: shownMood);
    _blendStartMs = ms;
    _blendMs = blendMs;
    _runStartMs = run ? ms : null;
    _endHandled = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduced = reducedMotion;
    final GhostMood? mood = widget.mood;
    if (!_depsReady) {
      _depsReady = true;
      _wasReduced = reduced;
      if (mood != null && MoodReaction.isReaction(mood)) {
        if (reduced) {
          _callEndAfterFrame();
        } else {
          _runStartMs = 0;
        }
      }
    } else if (reduced != _wasReduced) {
      _wasReduced = reduced;
      _resetToRest();
      syncLoop();
    }
  }

  @override
  void didUpdateWidget(GhostLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bobPeriodMs != widget.bobPeriodMs ||
        oldWidget.bobAmplitude != widget.bobAmplitude) {
      _bob = _makeBob();
    }
    final GhostMood? mood = widget.mood;
    final GhostMood? old = oldWidget.mood;
    if (mood == null) {
      _resetToRest();
      syncLoop();
      return;
    }
    final bool reaction = MoodReaction.isReaction(mood);
    final bool moodChanged = old != mood;
    final bool keyChanged = oldWidget.reactionKey != widget.reactionKey;
    if (!moodChanged && !(keyChanged && reaction)) {
      return;
    }
    if (reducedMotion) {
      _resetToRest();
      if (reaction) {
        _callEndAfterFrame();
      }
      syncLoop();
      return;
    }
    if (old == null) {
      _resetToRest();
      _runStartMs = reaction ? elapsedMs : null;
      syncLoop();
      return;
    }
    _animating = true;
    _startBlend(
      elapsedMs,
      moodChanged ? MoodBlend.transitionMs : MoodBlend.restartMs,
      shownMood: old,
      run: reaction,
    );
    syncLoop();
  }

  Widget _buildMood(BuildContext context, GhostMood mood) {
    final CoffinColorTokens tokens = SpookyTokens.of(context);
    final List<BoxShadow> glow = CoffinGlow.decoration(
      color: tokens.primary,
      intensity: 0.5,
    ).boxShadow!;
    final Color body = SpookyTokens.ghostBody(tokens);
    final double size = _size;
    final double reserve = MoodTraits.reserveFor(size).toDouble();
    final String? caption = widget.caption;
    final MoodPose rest = MoodPose.rest(mood);

    GhostPainter painterFor(MoodPose pose, double offset) => GhostPainter(
      bodyColor: body,
      eyeColor: tokens.background,
      glow: glow,
      pose: pose,
      bobOffset: offset,
      headroom: reserve,
    );

    final Widget ghost = reducedMotion
        ? CustomPaint(painter: painterFor(rest, 0))
        : AnimatedBuilder(
            animation: loopController,
            builder: (BuildContext context, Widget? child) {
              final int ms = elapsedMs;
              final MoodPose pose = poseAt(ms);
              return CustomPaint(
                painter: painterFor(pose, MoodBob.mixedOffsetAt(pose, ms)),
              );
            },
          );

    return _wrap(
      tokens,
      caption,
      SizedBox(
        width: size,
        height: size + 2 * reserve,
        child: RepaintBoundary(child: ghost),
      ),
    );
  }

  Widget _wrap(CoffinColorTokens tokens, String? caption, Widget box) {
    return Semantics(
      label: caption ?? 'Loading',
      liveRegion: true,
      container: true,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            box,
            if (caption != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: CoffinTypography.textTheme(tokens).bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final GhostMood? mood = widget.mood;
    if (mood != null) {
      return _buildMood(context, mood);
    }
    final CoffinColorTokens tokens = SpookyTokens.of(context);
    final List<BoxShadow> glow = CoffinGlow.decoration(
      color: tokens.primary,
      intensity: 0.5,
    ).boxShadow!;
    final Color body = SpookyTokens.ghostBody(tokens);
    final double size = _size;
    final double headroom = _bob.amplitude;
    final String? caption = widget.caption;

    GhostPainter painterFor(double offset) => GhostPainter(
      bodyColor: body,
      eyeColor: tokens.background,
      glow: glow,
      bobOffset: offset,
      headroom: headroom,
    );

    final Widget ghost = reducedMotion
        ? CustomPaint(painter: painterFor(GhostBob.staticOffset))
        : AnimatedBuilder(
            animation: loopController,
            builder: (BuildContext context, Widget? child) =>
                CustomPaint(painter: painterFor(_bob.offsetAt(elapsedMs))),
          );

    return Semantics(
      label: caption ?? 'Loading',
      liveRegion: true,
      container: true,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 0.8 * size,
              height: size + 2 * headroom,
              child: RepaintBoundary(child: ghost),
            ),
            if (caption != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: CoffinTypography.textTheme(tokens).bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
