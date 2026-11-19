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

  /// Whether the loop should run while motion is allowed.
  ///
  /// Defaults to true, so the loop always runs unless motion is reduced.
  /// Override it to pause the loop, then call [syncLoop] after the answer
  /// changes.
  bool get loopWanted => true;

  /// Starts or stops the loop to match [reducedMotion] and [loopWanted].
  ///
  /// Stops the loop when motion is reduced or the loop is not wanted. Otherwise
  /// it starts the loop if it is not already running.
  void syncLoop() {
    if (reducedMotion || !loopWanted) {
      loopController.stop();
    } else if (!loopController.isAnimating) {
      loopController.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncLoop();
  }

  @override
  void dispose() {
    loopController.dispose();
    super.dispose();
  }
}
