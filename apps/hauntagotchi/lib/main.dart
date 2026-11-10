import 'package:flutter/material.dart';

import 'src/ui/placeholder_screen.dart';

void main() {
  runApp(const HauntagotchiApp());
}

/// Root widget of the Hauntagotchi app.
class HauntagotchiApp extends StatelessWidget {
  /// Creates the app root.
  const HauntagotchiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'Hauntagotchi', home: PlaceholderScreen());
  }
}
