import 'package:flutter/material.dart';

import 'graveyard_copy.dart';

/// A gentle banner shown when a write to storage threw. The graves stay
/// visible below it, and "Try again" repeats the pending writes.
class SaveErrorBanner extends StatelessWidget {
  /// Creates the banner. [onRetry] should call `retrySave()`.
  const SaveErrorBanner({super.key, required this.onRetry});

  /// Called when the user presses "Try again".
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.error),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              container: true,
              liveRegion: true,
              child: Text(
                GraveyardCopy.saveError,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            key: const ValueKey<String>('save-retry'),
            onPressed: onRetry,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text(GraveyardCopy.tryAgain),
          ),
        ],
      ),
    );
  }
}
