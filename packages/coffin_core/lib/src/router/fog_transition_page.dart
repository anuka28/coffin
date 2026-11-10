import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'fog_math.dart';
import 'fog_transition.dart';

/// A go_router page that brings its child in with the [FogTransition].
///
/// The duration is fixed when the page is created. With normal motion it is
/// clamped into 300 to 600 ms. With [reducedMotion] it is zero (an instant
/// change) unless [FogMath.resolveDuration] is told otherwise. The visual
/// effect always follows the live [MediaQuery.disableAnimations] value, read
/// inside [FogTransition].
class FogTransitionPage<T> extends CustomTransitionPage<T> {
  /// Creates a page showing [child] with the fog transition.
  ///
  /// [duration] is the requested transition length. [reducedMotion] says
  /// whether reduced motion was on when the page was created. [math] sets the
  /// drift, blur and duration limits.
  FogTransitionPage({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    Duration duration = FogMath.defaultDuration,
    bool reducedMotion = false,
    FogMath math = const FogMath(),
  }) : super(
         transitionDuration: _resolve(math, duration, reducedMotion),
         reverseTransitionDuration: _resolve(math, duration, reducedMotion),
         transitionsBuilder: (context, animation, secondaryAnimation, child) =>
             FogTransition(animation: animation, math: math, child: child),
       );

  static Duration _resolve(FogMath math, Duration duration, bool reduced) =>
      math.resolveDuration(duration, reducedMotion: reduced);
}
