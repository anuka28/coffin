import 'dart:ui' show ImageFilter, TileMode;

import 'package:flutter/widgets.dart';

import 'fog_math.dart';

/// Applies the fog transition to [child]: it fades in while drifting up a
/// short distance and resolving from a blur.
///
/// Opacity is applied by a [FadeTransition], which updates its render object
/// directly and does not rebuild widgets on each frame. Only drift and blur
/// use an [AnimatedBuilder]. All numbers come from [FogMath].
///
/// Reduced motion is read from [MediaQuery.disableAnimations] on every
/// build. When it is on, there is no drift and no blur, only the fade.
class FogTransition extends StatelessWidget {
  /// Creates the fog transition for [child], driven by [animation].
  ///
  /// [animation] runs from 0.0 to 1.0 when the page arrives and back to 0.0
  /// when it leaves. Any secondary animation is ignored, so the outgoing page
  /// is not animated.
  const FogTransition({
    super.key,
    required this.animation,
    required this.child,
    this.math = const FogMath(),
  });

  /// The route animation, from 0.0 to 1.0.
  final Animation<double> animation;

  /// The page being revealed.
  final Widget child;

  /// The math that maps progress to opacity, drift and blur.
  final FogMath math;

  /// Blur sigma below which no blur filter is added to the tree.
  static const double blurThreshold = 0.1;

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final Animation<double> curved = animation.drive(
      CurveTween(curve: Curves.easeInOut),
    );
    final Animation<double> opacity = curved.drive(
      Animatable<double>.fromCallback(
        (double t) => math.opacity(t, reducedMotion: reduced),
      ),
    );

    return FadeTransition(
      opacity: opacity,
      alwaysIncludeSemantics: true,
      child: AnimatedBuilder(
        animation: curved,
        child: child,
        builder: (BuildContext context, Widget? page) {
          final frame = math.frame(curved.value, reducedMotion: reduced);
          Widget result = page!;
          if (frame.blur >= blurThreshold) {
            result = ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: frame.blur,
                sigmaY: frame.blur,
                tileMode: TileMode.decal,
              ),
              child: result,
            );
          }
          if (frame.dx != 0 || frame.dy != 0) {
            result = Transform.translate(
              offset: Offset(frame.dx, frame.dy),
              child: result,
            );
          }
          return result;
        },
      ),
    );
  }
}
