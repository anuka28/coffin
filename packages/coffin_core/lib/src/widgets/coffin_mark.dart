import 'package:flutter/material.dart';

/// A small spooky brand-mark shown by apps in their placeholder screens.
///
/// This is a simple scaffold widget. It sets no colors of its own and
/// inherits them from the ambient [Theme], so it picks up the Coffin
/// haunted or daylight theme whenever one is applied. It exists so apps
/// can prove they consume the `coffin_core` public API.
class CoffinMark extends StatelessWidget {
  /// Creates a [CoffinMark].
  const CoffinMark({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.nightlight_round, size: 64),
        SizedBox(height: 16),
        Text('Coffin'),
      ],
    );
  }
}
