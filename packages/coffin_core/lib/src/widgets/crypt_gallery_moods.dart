import 'package:flutter/material.dart';

import 'ghost_loader.dart';
import 'ghost_mood.dart';

/// The mood section of a crypt gallery panel: a title, one line of text and
/// one captioned ghost for each [GhostMood], in declaration order.
///
/// The ghosts have no reaction callback and start no loop of their own.
class CryptGalleryMoods extends StatelessWidget {
  /// Creates the mood section.
  const CryptGalleryMoods({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text('Seven ways to be haunted', style: textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        Text(
          'Each ghost wears its mood on its face.',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: <Widget>[
            for (final GhostMood mood in GhostMood.values)
              SizedBox(
                width: 96,
                child: GhostLoader(mood: mood, caption: mood.name),
              ),
          ],
        ),
      ],
    );
  }
}
