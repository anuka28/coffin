import 'package:coffin_core/coffin_core.dart';

import 'grave_list_controller.dart';
import 'graveyard_clipboard.dart';
import 'graveyard_screen.dart';

/// Builds the routes of Graveyard. The home route shows the graveyard screen,
/// which hands [clipboard] down to the Living_Row.
List<AppRoute> buildAppRoutes(
  GraveListController controller,
  CoffinAI seanceAi, [
  GraveyardClipboard clipboard = const SystemGraveyardClipboard(),
]) => <AppRoute>[
  AppRoute(
    path: '/',
    name: 'home',
    builder: (context, state) => GraveyardScreen(
      controller: controller,
      seanceAi: seanceAi,
      clipboard: clipboard,
    ),
  ),
];
