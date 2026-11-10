import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import 'src/ui/placeholder_screen.dart';

void main() {
  runApp(const GraveyardApp());
}

/// Root widget of the Graveyard app.
class GraveyardApp extends StatelessWidget {
  /// Creates the app root.
  const GraveyardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Graveyard',
      theme: CoffinTheme.dark(),
      home: const PlaceholderScreen(),
    );
  }
}
