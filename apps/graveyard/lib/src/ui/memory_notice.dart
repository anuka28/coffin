import 'package:flutter/material.dart';

import 'graveyard_copy.dart';

/// A gentle note shown while graves live only in memory.
class MemoryNotice extends StatelessWidget {
  /// Creates the notice.
  const MemoryNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.secondary),
        ),
        child: Row(
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(Icons.info_outline, color: colors.secondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                GraveyardCopy.memoryNotice,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
