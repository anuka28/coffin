import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import 'haunt_copy.dart';

/// A gentle full-area message shown when saved data could not be read.
class LoadErrorView extends StatelessWidget {
  /// Creates the view. [onRetry] is called when Retry is pressed.
  const LoadErrorView({super.key, required this.onRetry});

  /// Called when the user asks to load again.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                HauntCopy.loadError,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: CoffinMetrics.minTapTarget,
                minHeight: CoffinMetrics.minTapTarget,
              ),
              child: Semantics(
                button: true,
                label: HauntCopy.retry,
                excludeSemantics: true,
                child: FilledButton(
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
