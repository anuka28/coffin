import 'package:flutter/widgets.dart';

import 'graveyard_copy.dart';

/// The one-shot screen reader announcement of a Raise.
///
/// The screen bumps [announcement] once per Raise and passes the [name] of the
/// Grave that rose. While [announcement] is 0, or [name] is null, nothing is
/// exposed. Otherwise the widget exposes
/// `GraveyardCopy.risenAnnouncement(name)` as one polite live region, keyed by
/// [announcement], so a new Raise is a new announcement and a rebuild with the
/// same counter (or the Grave moving to the Living_Row) is not. It never
/// requests focus and has no visual output.
class RisenAnnouncement extends StatelessWidget {
  /// Creates the announcer for the Raise numbered [announcement].
  const RisenAnnouncement({
    super.key,
    required this.announcement,
    required this.name,
  });

  /// Count of Raises so far. 0 means none, so nothing is announced.
  final int announcement;

  /// Name of the Grave of the latest Raise.
  final String? name;

  @override
  Widget build(BuildContext context) {
    final String? who = name;
    if (announcement <= 0 || who == null) {
      return const SizedBox.shrink();
    }
    return Semantics(
      key: ValueKey<int>(announcement),
      container: true,
      liveRegion: true,
      label: GraveyardCopy.risenAnnouncement(who),
      child: const SizedBox.shrink(),
    );
  }
}
