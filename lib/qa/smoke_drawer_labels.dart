import '../components/layout/game_quick_menu.dart';

/// Quick menu labels — must match [kGameMenuItems] in game_quick_menu.dart.
class SmokeMenuLabels {
  const SmokeMenuLabels._();

  static List<String> get all => kGameMenuLabels;
}

/// @deprecated Use [SmokeMenuLabels].
class SmokeDrawerLabels {
  const SmokeDrawerLabels._();

  static List<String> get all => SmokeMenuLabels.all;
}

/// P0 integration flows — ordered smoke pack.
class SmokeP0Flow {
  const SmokeP0Flow({
    required this.id,
    required this.title,
    required this.steps,
  });

  final String id;
  final String title;
  final List<String> steps;
}

class SmokeP0Flows {
  const SmokeP0Flows._();

  static const List<SmokeP0Flow> all = <SmokeP0Flow>[
    SmokeP0Flow(
      id: 'auth_home',
      title: 'Auth → Home',
      steps: <String>['login', 'home_load', 'profile_visible'],
    ),
    SmokeP0Flow(
      id: 'inventory_open',
      title: 'Open inventory',
      steps: <String>['bottom_nav_inventory', 'inventory_load'],
    ),
    SmokeP0Flow(
      id: 'dungeon_nav',
      title: 'Dungeon navigation',
      steps: <String>['bottom_nav_dungeon', 'dungeon_list'],
    ),
    SmokeP0Flow(
      id: 'character_nav',
      title: 'Character screen',
      steps: <String>['bottom_nav_character', 'character_load'],
    ),
    SmokeP0Flow(
      id: 'quick_menu_open',
      title: 'Quick menu grid',
      steps: <String>['bottom_nav_menu', 'menu_grid_visible'],
    ),
    SmokeP0Flow(
      id: 'shop_nav',
      title: 'Shop via quick menu',
      steps: <String>['open_menu', 'tap_magaza', 'shop_load'],
    ),
    SmokeP0Flow(
      id: 'bank_nav',
      title: 'Bank via quick menu',
      steps: <String>['open_menu', 'tap_banka', 'bank_load'],
    ),
    SmokeP0Flow(
      id: 'quests_nav',
      title: 'Quests via quick menu',
      steps: <String>['open_menu', 'tap_gorevler', 'quests_load'],
    ),
    SmokeP0Flow(
      id: 'guild_nav',
      title: 'Guild via quick menu',
      steps: <String>['open_menu', 'tap_lonca', 'guild_load'],
    ),
    SmokeP0Flow(
      id: 'settings_nav',
      title: 'Settings via quick menu',
      steps: <String>['open_menu', 'tap_ayarlar', 'settings_load'],
    ),
  ];
}
