import 'package:flutter/material.dart';

import 'graveyard_copy.dart';

/// The gentle error state shown when loading the saved graves threw.
class LoadErrorView extends StatelessWidget {
  /// Creates the view. [onRetry] should call `load()`.
  const LoadErrorView({super.key, required this.onRetry});

  /// Called when the user presses "Try again".
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            container: true,
            liveRegion: true,
            child: Text(
              GraveyardCopy.loadError,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey<String>('load-retry'),
            onPressed: onRetry,
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text(GraveyardCopy.tryAgain),
          ),
        ],
      ),
    );
  }
}
