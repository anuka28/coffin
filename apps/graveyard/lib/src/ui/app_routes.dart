import 'package:coffin_core/coffin_core.dart';

import 'grave_list_controller.dart';
import 'graveyard_screen.dart';

/// Builds the routes of Graveyard. The home route shows the graveyard screen.
List<AppRoute> buildAppRoutes(
  GraveListController controller,
  CoffinAI seanceAi,
) => <AppRoute>[
  AppRoute(
    path: '/',
    name: 'home',
    builder: (context, state) =>
        GraveyardScreen(controller: controller, seanceAi: seanceAi),
  ),
];
