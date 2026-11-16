import 'package:flutter/material.dart';

import '../theme/coffin_color_tokens.dart';
import '../theme/coffin_typography.dart';
import 'math/flicker_schedule.dart';
import 'motion_loop.dart';
import 'spooky_tokens.dart';

/// Text that flickers like a dying candle. For emphasis only: use it on short
/// lines.
///
/// Only the opacity changes between frames, from 0.75 to 1.0 on a seeded
/// schedule, so the size, position and color of the text never change. Two
/// widgets with the same [seed] show the same opacity at the same time. When
/// `MediaQuery.disableAnimations` is true the text is drawn at full opacity
/// and nothing ticks. The widget exposes one semantics node whose label is
/// exactly [text].
class FlickerText extends StatefulWidget {
  /// Creates flickering text.
  ///
  /// [style] defaults to the body-large style of the ambient token set.
  /// [seed] picks the flicker schedule.
  const FlickerText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.seed = 0,
  });

  /// The text to show. Also the semantics label.
  final String text;

  /// Text style, or null for the body-large style of the token set.
  final TextStyle? style;

  /// How the text is aligned horizontally.
  final TextAlign? textAlign;

  /// Maximum number of lines, or null for no limit.
  final int? maxLines;

  /// How overflowing text is handled.
  final TextOverflow? overflow;

  /// Seed of the flicker schedule.
  final int seed;

  @override
  State<FlickerText> createState() => _FlickerTextState();
}

class _FlickerTextState extends State<FlickerText>
    with SingleTickerProviderStateMixin<FlickerText>, MotionLoop<FlickerText> {
  late FlickerSchedule _schedule = FlickerSchedule(widget.seed);

  @override
  void didUpdateWidget(FlickerText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed != widget.seed) {
      _schedule = FlickerSchedule(widget.seed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final CoffinColorTokens tokens = SpookyTokens.of(context);
    final Widget text = Text(
      widget.text,
      style: widget.style ?? CoffinTypography.textTheme(tokens).bodyLarge,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );

    return Semantics(
      label: widget.text,
      container: true,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: reducedMotion
              ? text
              : AnimatedBuilder(
                  animation: loopController,
                  child: text,
                  builder: (BuildContext context, Widget? child) => Opacity(
                    opacity: _schedule.opacityAt(elapsedMs),
                    child: child,
                  ),
                ),
        ),
      ),
    );
  }
}
