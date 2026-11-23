import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import '../domain/calendar_date.dart';
import '../domain/dead_for_formatter.dart';
import '../domain/grave.dart';
import '../domain/grave_source.dart';
import '../domain/repo_info.dart';
import 'graveyard_copy.dart';

/// One tombstone for a [Grave], with its delete button below it.
///
/// The tombstone is plain content. Screen readers get one label that states
/// the name, the Dead_For_Text, the source, and the full description and
/// archived state. The engraved epitaph hides when the text scale is above
/// 1.2, so large text keeps room.
class GraveTile extends StatelessWidget {
  /// Creates a tile for [grave], with the dead-for text counted to [today].
  const GraveTile({
    super.key,
    required this.grave,
    required this.today,
    required this.onDelete,
  });

  /// The grave to show.
  final Grave grave;

  /// The current day, used for the Dead_For_Text.
  final CalendarDate today;

  /// Called when the delete button is pressed.
  final VoidCallback onDelete;

  static const double _maxEpitaphScale = 1.2;

  @override
  Widget build(BuildContext context) {
    final String deadFor = DeadForFormatter.format(grave.dateOfDeath, today);
    final RepoInfo? repo = grave.source == GraveSource.github
        ? grave.repo
        : null;
    final bool showEpitaph =
        MediaQuery.textScalerOf(context).scale(1) <= _maxEpitaphScale;
    final CoffinColorTokens tokens =
        Theme.of(context).brightness == Brightness.dark
        ? CoffinColorTokens.night
        : CoffinColorTokens.daylight;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final String label = repo == null
        ? GraveyardCopy.manualGraveLabel(name: grave.name, deadForText: deadFor)
        : GraveyardCopy.githubGraveLabel(
            name: grave.name,
            deadForText: deadFor,
            fullName: repo.fullName,
            stars: repo.stars,
            archived: repo.archived,
            description: repo.description,
          );

    final Widget card = TombstoneCard(
      title: grave.name,
      dateLine: GraveyardCopy.dateLine(grave.dateOfDeath),
      showEpitaph: showEpitaph,
      epitaph: GraveyardCopy.epitaph(deadFor),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(deadFor, textAlign: TextAlign.center),
          if (repo == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                GraveyardCopy.buriedByHand,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall,
              ),
            )
          else ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                repo.fullName,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      GraveyardCopy.stars(repo.stars, archived: repo.archived),
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 4),
                  ExcludeSemantics(
                    child: Icon(Icons.star, size: 16, color: tokens.tertiary),
                  ),
                ],
              ),
            ),
            if (repo.description != null && repo.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  repo.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall,
                ),
              ),
          ],
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          container: true,
          label: label,
          child: ExcludeSemantics(child: card),
        ),
        Semantics(
          button: true,
          label: GraveyardCopy.deleteLabel(grave.name),
          excludeSemantics: true,
          onTap: onDelete,
          child: TextButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            label: const Text(GraveyardCopy.delete),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
          ),
        ),
      ],
    );
  }
}
