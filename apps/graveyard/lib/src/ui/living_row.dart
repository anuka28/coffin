import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import '../domain/grave.dart';
import '../domain/grave_source.dart';
import 'graveyard_clipboard.dart';
import 'graveyard_copy.dart';
import 'repository_link.dart';

/// The "Back among the living" row: the graves that have risen.
///
/// [entries] must already be ordered by `LivingSplit`. With no entries the row
/// renders nothing at all: no heading and no placeholder. The row takes the
/// side padding and maximum width of its parent, so it sits in the same
/// column as the screen title.
class LivingRow extends StatelessWidget {
  /// Creates the row for [entries].
  const LivingRow({
    super.key,
    required this.entries,
    required this.onLayToRest,
    this.clipboard = const SystemGraveyardClipboard(),
  });

  /// The risen graves to list, most recently risen first.
  final List<Grave> entries;

  /// Called when the user activates "Lay it back to rest" on a grave.
  final ValueChanged<Grave> onLayToRest;

  /// Where repository links are copied to.
  final GraveyardClipboard clipboard;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    final CoffinColorTokens tokens = theme.brightness == Brightness.dark
        ? CoffinColorTokens.night
        : CoffinColorTokens.daylight;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                GraveyardCopy.livingRowHeading,
                style: theme.textTheme.titleLarge?.copyWith(color: tokens.text),
              ),
            ),
          ),
          for (final Grave grave in entries)
            _LivingEntry(
              key: ValueKey<String>('living-${grave.id}'),
              grave: grave,
              tokens: tokens,
              onLayToRest: onLayToRest,
              clipboard: clipboard,
            ),
        ],
      ),
    );
  }
}

class _LivingEntry extends StatefulWidget {
  const _LivingEntry({
    super.key,
    required this.grave,
    required this.tokens,
    required this.onLayToRest,
    required this.clipboard,
  });

  final Grave grave;
  final CoffinColorTokens tokens;
  final ValueChanged<Grave> onLayToRest;
  final GraveyardClipboard clipboard;

  @override
  State<_LivingEntry> createState() => _LivingEntryState();
}

class _LivingEntryState extends State<_LivingEntry> {
  final FocusNode _focus = FocusNode(debugLabel: 'lay-to-rest');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Grave grave = widget.grave;
    final CoffinColorTokens tokens = widget.tokens;
    final TextTheme text = Theme.of(context).textTheme;
    final String risenLine = GraveyardCopy.risenOnLine(grave.risenOn!);
    final String? address = grave.source == GraveSource.github
        ? grave.repo?.htmlUrl
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            container: true,
            label: '${grave.name}. $risenLine',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  grave.name,
                  style: text.titleMedium?.copyWith(color: tokens.text),
                ),
                Text(
                  risenLine,
                  style: text.bodyMedium?.copyWith(color: tokens.muted),
                ),
              ],
            ),
          ),
          if (address != null)
            Align(
              alignment: Alignment.centerLeft,
              child: RepositoryLink(
                key: ValueKey<String>('repository-link-${grave.id}'),
                name: grave.name,
                fullName: grave.repo!.fullName,
                address: address,
                clipboard: widget.clipboard,
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: GraveyardCopy.layToRestLabel(grave.name),
              excludeSemantics: true,
              onTap: () => widget.onLayToRest(grave),
              child: TextButton(
                key: ValueKey<String>('lay-to-rest-${grave.id}'),
                focusNode: _focus,
                onPressed: () => widget.onLayToRest(grave),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                child: const Text(GraveyardCopy.layToRestText),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
