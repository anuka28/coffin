import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import 'src/ui/app_routes.dart';

void main() {
  runApp(const BoneShopApp());
}

/// Root widget of the Bone Shop app.
class BoneShopApp extends StatefulWidget {
  /// Creates the app root.
  const BoneShopApp({super.key});

  @override
  State<BoneShopApp> createState() => _BoneShopAppState();
}

class _BoneShopAppState extends State<BoneShopApp> {
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
      title: 'Bone Shop',
      theme: CoffinTheme.dark(),
      routerConfig: _router,
    );
  }
}
