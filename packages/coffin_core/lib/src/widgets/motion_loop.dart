import 'package:flutter/widgets.dart';

/// Shared lifecycle for widgets that loop an animation.
///
/// The loop runs while motion is allowed and stops while
/// `MediaQuery.disableAnimations` is true.
mixin MotionLoop<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  /// Repeating controller. Its value is never read; only its ticks and
  /// elapsed time matter.
  late final AnimationController loopController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  /// True when the ambient `MediaQuery` asks for no animations.
  ///
  /// A missing `MediaQuery` counts as false.
  bool get reducedMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Milliseconds since the loop (re)started, or 0 when it is stopped.
  int get elapsedMs => loopController.isAnimating
      ? loopController.lastElapsedDuration?.inMilliseconds ?? 0
      : 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion) {
      loopController.stop();
    } else if (!loopController.isAnimating) {
      loopController.repeat();
    }
  }

  @override
  void dispose() {
    loopController.dispose();
    super.dispose();
  }
}
