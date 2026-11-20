import 'package:flutter/material.dart';

import '../theme/coffin_color_tokens.dart';
import '../theme/coffin_metrics.dart';
import 'crypt_gallery_moods.dart';
import 'flicker_text.dart';
import 'fog_background.dart';
import 'ghost_loader.dart';
import 'spooky_tokens.dart';
import 'tombstone_card.dart';

/// One themed column of the crypt gallery: a heading and one sample of every
/// spooky widget, painted with the token set of [theme].
class CryptGalleryPanel extends StatelessWidget {
  /// Creates a panel headed [title] that shows its samples under [theme].
  ///
  /// [onGraveTap] is called when the interactive tombstone is activated.
  const CryptGalleryPanel({
    super.key,
    required this.title,
    required this.theme,
    required this.onGraveTap,
  });

  /// The panel heading, for example "Night".
  final String title;

  /// The theme the samples are built under.
  final ThemeData theme;

  /// Called when the interactive tombstone card is activated.
  final VoidCallback onGraveTap;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: theme,
      child: Builder(
        builder: (BuildContext context) {
          final CoffinColorTokens tokens = SpookyTokens.of(context);
          final TextTheme textTheme = Theme.of(context).textTheme;
          return Material(
            color: tokens.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CoffinMetrics.cornerRadius),
              side: BorderSide(color: tokens.muted),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Semantics(
                    header: true,
                    child: Text(title, style: textTheme.titleLarge),
                  ),
                  const SizedBox(height: 16),
                  const GhostLoader(caption: 'Summoning your ghost…'),
                  const SizedBox(height: 16),
                  const GhostLoader(),
                  const SizedBox(height: 16),
                  const CryptGalleryMoods(),
                  const SizedBox(height: 16),
                  const TombstoneCard(
                    title: 'Old Todo App',
                    dateLine: 'Died 214 days ago',
                    child: Text('This project has been dead for 214 days'),
                  ),
                  const SizedBox(height: 16),
                  TombstoneCard(
                    title: 'Weather Widget',
                    dateLine: 'Abandoned last March',
                    onTap: onGraveTap,
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: FlickerText('The candle is not out yet…', seed: 7),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 240,
                    child: FogBackground(
                      seed: 13,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Fog drifts past the gate.',
                          style: textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
