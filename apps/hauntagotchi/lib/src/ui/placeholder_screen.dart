import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

/// Temporary home screen that proves the app consumes `coffin_core`.
class PlaceholderScreen extends StatelessWidget {
  /// Creates the placeholder screen.
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CoffinMark()));
  }
}
