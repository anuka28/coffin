import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'voice_announcement.dart';
import 'voice_controller.dart';
import 'voice_copy.dart';

/// Shows the ghost's current line under the ghost panel.
///
/// The panel is plain text: it has no tap target, takes no focus and is not a
/// live region. A new line cross-fades in over 450 ms, or switches at once
/// when the platform asks for reduced motion. A screen reader announces a
/// line once, and only for a check-off or a resurrection.
class VoicePanel extends StatefulWidget {
  /// Creates a panel for [controller], labelled with [ghostName].
  const VoicePanel({
    required this.controller,
    required this.ghostName,
    super.key,
  });

  /// The source of the line and of the announcements.
  final VoiceController controller;

  /// The ghost name used in the screen reader label.
  final String ghostName;

  @override
  State<VoicePanel> createState() => _VoicePanelState();
}

class _VoicePanelState extends State<VoicePanel> {
  static const Duration _fade = Duration(milliseconds: 450);
  static const double _radius = 16;

  int? _lastKey;

  @override
  void initState() {
    super.initState();
    _lastKey = widget.controller.announcement?.key;
    widget.controller.addListener(_onController);
  }

  @override
  void didUpdateWidget(VoicePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onController);
      _lastKey = widget.controller.announcement?.key;
      widget.controller.addListener(_onController);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    super.dispose();
  }

  void _onController() {
    final VoiceAnnouncement? announcement = widget.controller.announcement;
    if (!mounted || announcement == null || announcement.key == _lastKey) {
      return;
    }
    _lastKey = announcement.key;
    if (!MediaQuery.accessibleNavigationOf(context)) {
      return;
    }
    SemanticsService.sendAnnouncement(
      View.of(context),
      announcement.text,
      Directionality.of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool still = MediaQuery.disableAnimationsOf(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? _) {
        final String line = widget.controller.line ?? VoiceCopy.safeLine;
        final Widget text = Text(
          line,
          key: ValueKey<String>(line),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
        );
        final Widget content = still
            ? text
            : AnimatedSwitcher(
                duration: _fade,
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                transitionBuilder: (
                  Widget child,
                  Animation<double> animation,
                ) => FadeTransition(opacity: animation, child: child),
                child: text,
              );
        return Semantics(
          label: VoiceCopy.label(widget.ghostName, line),
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(_radius),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.2),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(width: double.infinity, child: content),
              ),
            ),
          ),
        );
      },
    );
  }
}
