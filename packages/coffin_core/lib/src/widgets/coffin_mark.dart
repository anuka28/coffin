import 'package:flutter/material.dart';

/// A small spooky brand-mark shown by apps in their placeholder screens.
///
/// This is a temporary scaffold widget. It intentionally uses default
/// Material styling rather than the Coffin design tokens, which arrive
/// in a later spec. It exists so apps can prove they consume the
/// `coffin_core` public API before any real UI is built.
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
