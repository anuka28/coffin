import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import 'src/ui/app_routes.dart';

void main() {
  runApp(const GraveyardApp());
}

/// Root widget of the Graveyard app.
class GraveyardApp extends StatefulWidget {
  /// Creates the app root.
  const GraveyardApp({super.key});

  @override
  State<GraveyardApp> createState() => _GraveyardAppState();
}

class _GraveyardAppState extends State<GraveyardApp> {
  // Built once so rebuilds and hot reloads do not reset navigation.
  late final GoRouter _router = FogRouter.create(routes: appRoutes);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Graveyard',
      theme: CoffinTheme.dark(),
      routerConfig: _router,
    );
  }
}
