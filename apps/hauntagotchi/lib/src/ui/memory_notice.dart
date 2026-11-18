import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import 'haunt_copy.dart';

/// A gentle note shown while progress is not saved to the device.
class MemoryNotice extends StatelessWidget {
  /// Creates the notice.
  const MemoryNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: HauntCopy.memoryNotice,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(CoffinMetrics.cornerRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: scheme.tertiary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    HauntCopy.memoryNotice,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
