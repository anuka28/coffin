import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/coffin_color_tokens.dart';
import 'math/fog_disc.dart';
import 'math/fog_field.dart';
import 'math/fog_particle.dart';
import 'motion_loop.dart';
import 'spooky_tokens.dart';

/// Slow drifting fog behind [child].
///
/// Put long body text on an opaque surface, not straight on the fog; the 4.5:1 guarantee covers up to 5 overlapping blobs.
///
/// The fog is painted on its own repaint layer, ignores pointer events and
/// adds no semantics node. The widget lays out exactly like [child]. When
/// `MediaQuery.disableAnimations` is true the fog is drawn once as a static
/// frame and nothing ticks.
class FogBackground extends StatefulWidget {
  /// Creates a fog layer behind [child].
  ///
  /// [seed] picks the blobs. [particleCount] is clamped into
  /// 0..[FogField.maxCount].
  const FogBackground({
    super.key,
    required this.child,
    this.seed = 0,
    this.particleCount = FogField.defaultCount,
  });

  /// The widget drawn in front of the fog.
  final Widget child;

  /// Seed of the fog field.
  final int seed;

  /// Number of fog blobs, clamped into 0..[FogField.maxCount].
  final int particleCount;

  @override
  State<FogBackground> createState() => _FogBackgroundState();
}

class _FogBackgroundState extends State<FogBackground>
    with
        SingleTickerProviderStateMixin<FogBackground>,
        MotionLoop<FogBackground> {
  late FogField _field = FogField(
    seed: widget.seed,
    count: widget.particleCount,
  );

  @override
  void didUpdateWidget(FogBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed != widget.seed ||
        oldWidget.particleCount != widget.particleCount) {
      _field = FogField(seed: widget.seed, count: widget.particleCount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final CoffinColorTokens tokens = SpookyTokens.of(context);
    final bool reduced = reducedMotion;
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _FogPainter(
                    _field,
                    tokens.primary,
                    reduced ? null : loopController,
                    () => reduced ? 0 : elapsedMs,
                  ),
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _FogPainter extends CustomPainter {
  _FogPainter(this.field, this.color, Listenable? repaint, this.elapsed)
    : super(repaint: repaint);

  final FogField field;
  final Color color;
  final int Function() elapsed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.clipRect(Offset.zero & size);
    final List<FogParticle> particles = field.particlesAt(elapsed());
    final Color clear = color.withValues(alpha: 0);
    for (final FogParticle p in particles) {
      final FogDisc d = FogField.toBounds(p, size.width, size.height);
      if (d.radius <= 0) continue;
      final Offset center = Offset(d.x, d.y);
      final Paint paint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          d.radius,
          <Color>[
            color.withValues(alpha: p.alpha),
            color.withValues(alpha: p.alpha * 0.45),
            clear,
          ],
          <double>[0, 0.5, 1],
        );
      canvas.drawCircle(center, d.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_FogPainter oldDelegate) =>
      oldDelegate.field.seed != field.seed ||
      oldDelegate.field.count != field.count ||
      oldDelegate.color != color;
}
