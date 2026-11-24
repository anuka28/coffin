import 'package:flutter/material.dart';

import '../domain/grave.dart';
import 'graveyard_copy.dart';

/// The button on a tombstone that opens the séance for one [Grave].
///
/// It shows [GraveyardCopy.seanceControlText], is at least 48 by 48 with a
/// padded tap target, and answers to Enter and Space. Hover, press and focus
/// states come from the ambient theme. Screen readers get one button labelled
/// with the name of the grave.
class SeanceControl extends StatelessWidget {
  /// Creates the séance control of [grave].
  const SeanceControl({
    super.key,
    required this.grave,
    required this.onPressed,
  });

  /// The grave this control holds a séance for.
  final Grave grave;

  /// Called when the control is activated.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: GraveyardCopy.seanceControlLabel(grave.name),
      excludeSemantics: true,
      onTap: onPressed,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        child: const Text(GraveyardCopy.seanceControlText),
      ),
    );
  }
}
