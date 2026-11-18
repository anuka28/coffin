import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import 'haunt_copy.dart';

/// A gentle message shown when a change could not be written, with Retry.
class SaveErrorBanner extends StatelessWidget {
  /// Creates the banner. [onRetry] is called when Retry is pressed.
  const SaveErrorBanner({super.key, required this.onRetry});

  /// Called when the user asks to try saving again.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(CoffinMetrics.cornerRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  HauntCopy.saveError,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: CoffinMetrics.minTapTarget,
                minHeight: CoffinMetrics.minTapTarget,
              ),
              child: Semantics(
                button: true,
                label: HauntCopy.retry,
                excludeSemantics: true,
                child: TextButton(
                  onPressed: onRetry,
                  child: const Text(HauntCopy.retry),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
