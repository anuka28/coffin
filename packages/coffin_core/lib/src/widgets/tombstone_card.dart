import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/coffin_color_tokens.dart';
import '../theme/coffin_glow.dart';
import '../theme/coffin_metrics.dart';
import '../theme/coffin_typography.dart';
import 'spooky_tokens.dart';
import 'tombstone_border.dart';

/// A tombstone-shaped card with a title, an optional date line and an optional
/// child.
///
/// The card is at most 300 px wide and centered in its parent. Its arch is
/// close to a half circle of the card width. When it has a [child] the card
/// is at least 1.2 times as tall as it is wide, like a grave marker.
///
/// It glows softly at rest. When [onTap] is not null the card is interactive: the glow grows on
/// hover and press, a focus ring shows on keyboard focus, Enter and Space
/// activate it, and it is exposed to screen readers as a button of at least
/// 48 by 48 logical pixels. Without [onTap] it is plain content.
class TombstoneCard extends StatefulWidget {
  /// Creates a tombstone card.
  ///
  /// [title] is shown in the heading style (three lines at most). [dateLine]
  /// is shown below it in the small style (two lines at most). [child] is
  /// shown below those. [onTap] makes the card interactive. [semanticLabel]
  /// replaces the default label, which is [title] or "[title], [dateLine]".
  const TombstoneCard({
    super.key,
    required this.title,
    this.dateLine,
    this.child,
    this.onTap,
    this.semanticLabel,
  });

  /// The headline of the card.
  final String title;

  /// Optional line below the title, for example "Died 214 days ago".
  final String? dateLine;

  /// Optional content below the date line.
  final Widget? child;

  /// Called when the card is activated. Null makes the card non-interactive.
  final VoidCallback? onTap;

  /// Optional screen reader label for an interactive card.
  final String? semanticLabel;

  @override
  State<TombstoneCard> createState() => _TombstoneCardState();
}

class _TombstoneCardState extends State<TombstoneCard> {
  static const double _maxWidth = 300;
  static const double _archRise = 140;
  static const double _portraitRatio = 1.2;
  static const Duration _stateDuration = Duration(milliseconds: 300);

  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;
  bool _keyDown = false;

  bool get _interactive => widget.onTap != null;

  @override
  void didUpdateWidget(TombstoneCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_interactive) {
      _hovered = false;
      _pressed = false;
      _focused = false;
      _keyDown = false;
    }
  }

  void _setHovered(bool value) {
    if (_hovered != value) {
      setState(() => _hovered = value);
    }
  }

  void _setFocused(bool value) {
    if (_focused != value) {
      setState(() => _focused = value);
    }
  }

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  static bool _isActivationKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.space;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_interactive || !_isActivationKey(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      _keyDown = true;
      _setPressed(true);
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent) {
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) {
      if (!_keyDown) {
        return KeyEventResult.ignored;
      }
      _keyDown = false;
      _setPressed(false);
      widget.onTap?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String get _label =>
      widget.semanticLabel ??
      (widget.dateLine == null
          ? widget.title
          : '${widget.title}, ${widget.dateLine}');

  @override
  Widget build(BuildContext context) {
    final CoffinColorTokens tokens = SpookyTokens.of(context);
    final TextTheme textTheme = CoffinTypography.textTheme(tokens);
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    final Duration duration = reduced ? Duration.zero : _stateDuration;
    final bool interactive = _interactive;
    final bool pressed = interactive && _pressed;
    final bool hovered = interactive && _hovered;
    final bool focused = interactive && _focused;

    final double intensity = pressed ? 0.80 : (hovered ? 0.55 : 0.30);
    final Color fill = pressed ? tokens.raised : tokens.surface;
    final BorderSide side = focused
        ? BorderSide(color: tokens.primary, width: CoffinMetrics.focusRingWidth)
        : BorderSide(color: tokens.muted);

    final Widget content = Padding(
      padding: const EdgeInsets.fromLTRB(20, _archRise + 8, 20, 20),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              widget.title,
              style: textTheme.headlineSmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (widget.dateLine != null)
              Text(
                widget.dateLine!,
                style: textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            if (widget.child != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: widget.child,
              ),
          ],
        ),
      ),
    );

    final TombstoneBorder shape = TombstoneBorder(
      side: side,
      archRise: _archRise,
    );

    // The decoration paints the glow, so it sits outside the clip: clipping
    // it would cut the glow off at the tombstone outline.
    Widget card = TweenAnimationBuilder<double>(
      tween: Tween<double>(end: intensity),
      duration: duration,
      curve: Curves.easeInOut,
      builder: (BuildContext context, double glow, Widget? child) {
        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: fill),
          duration: duration,
          curve: Curves.easeInOut,
          builder: (BuildContext context, Color? color, Widget? child) {
            return DecoratedBox(
              decoration: ShapeDecoration(
                shape: shape,
                color: color,
                shadows: CoffinGlow.decoration(
                  color: tokens.primary,
                  intensity: glow,
                ).boxShadow,
              ),
              child: child,
            );
          },
          child: child,
        );
      },
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          primary: false,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              final double width = box.maxWidth.isFinite
                  ? box.maxWidth
                  : _maxWidth;
              return ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: widget.child == null ? 0 : width * _portraitRatio,
                ),
                child: content,
              );
            },
          ),
        ),
      ),
    );

    if (interactive) {
      card = Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowHoverHighlight: _setHovered,
          onShowFocusHighlight: _setFocused,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (TapDownDetails details) => _setPressed(true),
            onTapUp: (TapUpDetails details) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            onTap: widget.onTap,
            child: card,
          ),
        ),
      );
    }

    card = Align(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: interactive ? CoffinMetrics.minTapTarget : 0,
          minHeight: interactive ? CoffinMetrics.minTapTarget : 0,
          maxWidth: _maxWidth,
        ),
        child: card,
      ),
    );

    if (!interactive) {
      return card;
    }
    return Semantics(
      button: true,
      enabled: true,
      focusable: true,
      label: _label,
      onTap: widget.onTap,
      child: ExcludeSemantics(child: card),
    );
  }
}
