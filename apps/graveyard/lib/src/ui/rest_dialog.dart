import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import 'graveyard_copy.dart';

/// Marks the navigators that already show a rest dialog.
final Expando<bool> _openOn = Expando<bool>('restDialogOpen');

/// Asks the user to confirm laying the grave called [name] back to rest.
///
/// Returns true only when the user presses "Lay it to rest". Escape, a tap
/// outside and "Keep it risen" all return false. While one dialog is open,
/// further calls return false at once and open nothing.
Future<bool> showRestDialog(BuildContext context, String name) async {
  final NavigatorState navigator = Navigator.of(context);
  if (_openOn[navigator] ?? false) {
    return false;
  }
  _openOn[navigator] = true;
  try {
    final bool? confirmed = await showDialog<bool>(
      context: navigator.context,
      routeSettings: RouteSettings(
        name: GraveyardCopy.restDialogRouteName(name),
      ),
      builder: (BuildContext dialogContext) => RestDialog(name: name),
    );
    return confirmed ?? false;
  } finally {
    _openOn[navigator] = false;
  }
}

/// The Lay_To_Rest confirmation dialog. It names the grave and pops true to
/// confirm or false to keep it risen.
class RestDialog extends StatelessWidget {
  /// Creates the dialog for the grave called [name].
  const RestDialog({super.key, required this.name});

  /// The name of the grave to lay back to rest.
  final String name;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CoffinColorTokens tokens = theme.brightness == Brightness.dark
        ? CoffinColorTokens.night
        : CoffinColorTokens.daylight;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: GraveyardCopy.restDialogRouteName(name),
      child: AlertDialog(
        scrollable: true,
        backgroundColor: tokens.raised,
        title: Text(GraveyardCopy.restDialogTitle(name)),
        content: Text(GraveyardCopy.restDialogBody(name)),
        actions: <Widget>[
          Semantics(
            button: true,
            label: GraveyardCopy.restCancelText,
            excludeSemantics: true,
            child: TextButton(
              key: const ValueKey<String>('rest-cancel'),
              autofocus: true,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(GraveyardCopy.restCancelText),
            ),
          ),
          Semantics(
            button: true,
            label: GraveyardCopy.restConfirmText,
            excludeSemantics: true,
            child: TextButton(
              key: const ValueKey<String>('rest-confirm'),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: tokens.primary,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(GraveyardCopy.restConfirmText),
            ),
          ),
        ],
      ),
    );
  }
}
