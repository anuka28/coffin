import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import 'graveyard_clipboard.dart';
import 'graveyard_copy.dart';

/// The link of a living entry to its repository.
///
/// The app cannot open addresses, so activating the link copies [address] to
/// the clipboard and says so under the link. A clipboard that throws anything
/// gives the failure line instead. Nothing escapes and the entry is unchanged.
class RepositoryLink extends StatefulWidget {
  /// Creates the link for the grave called [name].
  const RepositoryLink({
    super.key,
    required this.name,
    required this.fullName,
    required this.address,
    required this.clipboard,
  });

  /// The project name, used in the semantic label.
  final String name;

  /// The `owner/repo` name shown on the link.
  final String fullName;

  /// The repository address that is copied.
  final String address;

  /// Where the address is copied to.
  final GraveyardClipboard clipboard;

  @override
  State<RepositoryLink> createState() => _RepositoryLinkState();
}

class _RepositoryLinkState extends State<RepositoryLink> {
  String? _status;

  Future<void> _copy() async {
    String message;
    try {
      await widget.clipboard.copy(widget.address);
      message = GraveyardCopy.linkCopied;
    } catch (_) {
      message = GraveyardCopy.linkCopyFailed;
    }
    if (!mounted) {
      return;
    }
    setState(() => _status = message);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CoffinColorTokens tokens = theme.brightness == Brightness.dark
        ? CoffinColorTokens.night
        : CoffinColorTokens.daylight;
    final String? status = _status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          button: true,
          label: GraveyardCopy.repositoryLinkLabel(widget.name),
          excludeSemantics: true,
          onTap: _copy,
          child: TextButton(
            onPressed: _copy,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            child: Text(widget.fullName),
          ),
        ),
        if (status != null)
          Semantics(
            container: true,
            liveRegion: true,
            label: status,
            excludeSemantics: true,
            child: Text(
              status,
              style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
            ),
          ),
      ],
    );
  }
}
