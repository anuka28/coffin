import 'package:flutter/material.dart';

import 'graveyard_copy.dart';

/// The onboarding state of an empty graveyard.
///
/// It names both ways to add a grave and offers one button for each. The
/// screen opens the add sheet on the matching option.
class EmptyGraveyardPanel extends StatelessWidget {
  /// Creates the panel. [onBuryByHand] and [onImport] open the add sheet.
  const EmptyGraveyardPanel({
    super.key,
    required this.onBuryByHand,
    required this.onImport,
  });

  /// Called when the user chooses to bury a project by hand.
  final VoidCallback onBuryByHand;

  /// Called when the user chooses to import from GitHub.
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              GraveyardCopy.emptyTitle,
              textAlign: TextAlign.center,
              style: text.titleLarge,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            GraveyardCopy.emptyBody,
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey<String>('empty-bury'),
            onPressed: onBuryByHand,
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text(GraveyardCopy.buryByHand),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const ValueKey<String>('empty-import'),
            onPressed: onImport,
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text(GraveyardCopy.importFromGitHub),
          ),
        ],
      ),
    );
  }
}
