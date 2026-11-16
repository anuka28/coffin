import 'package:flutter/material.dart';

import '../theme/coffin_color_tokens.dart';
import '../theme/coffin_glow.dart';
import '../theme/coffin_typography.dart';
import 'ghost_painter.dart';
import 'math/ghost_bob.dart';
import 'motion_loop.dart';
import 'spooky_tokens.dart';

/// A small bobbing ghost with an optional caption, for loading states.
///
/// The ghost floats slowly up and down. When `MediaQuery.disableAnimations`
/// is true it is drawn as a still frame and nothing ticks. The widget exposes
/// one semantics node whose label is [caption], or "Loading" without one, and
/// which is a live region.
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
  });

  /// Ghost height in logical pixels, before clamping.
  final double size;

  /// Optional text below the ghost. Also the semantics label.
  final String? caption;

  /// Bob period in milliseconds, before clamping.
  final int bobPeriodMs;

  /// Bob amplitude in logical pixels, before clamping.
  final double bobAmplitude;

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

  @override
  void didUpdateWidget(GhostLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bobPeriodMs != widget.bobPeriodMs ||
        oldWidget.bobAmplitude != widget.bobAmplitude) {
      _bob = _makeBob();
    }
  }

  @override
  Widget build(BuildContext context) {
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
