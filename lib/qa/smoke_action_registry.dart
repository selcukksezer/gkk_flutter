/// P0 safe tap targets for integration smoke (phase 1 of 350-action gate).
/// Full inventory: reports/_ui_action_inventory.json
class SmokeActionTarget {
  const SmokeActionTarget({
    required this.route,
    required this.label,
    this.kind = 'tap',
    this.priority = 'P0',
  });

  final String route;
  final String label;
  final String kind;
  final String priority;
}

class SmokeActionRegistry {
  const SmokeActionRegistry._();

  static const List<SmokeActionTarget> _quickMenu = <SmokeActionTarget>[
    SmokeActionTarget(route: '/home', label: 'Ana Sayfa', kind: 'quick_menu'),
    SmokeActionTarget(route: '/inventory', label: 'Envanter', kind: 'quick_menu'),
    SmokeActionTarget(route: '/character', label: 'Karakter', kind: 'quick_menu'),
    SmokeActionTarget(route: '/dungeon', label: 'Zindan', kind: 'quick_menu'),
    SmokeActionTarget(route: '/pvp', label: 'PvP', kind: 'quick_menu'),
    SmokeActionTarget(route: '/leaderboard', label: 'Sıralama', kind: 'quick_menu'),
    SmokeActionTarget(route: '/season', label: 'Battle Pass', kind: 'quick_menu'),
    SmokeActionTarget(route: '/guild', label: 'Lonca', kind: 'quick_menu'),
    SmokeActionTarget(route: '/guild-war', label: 'Lonca Savaşı', kind: 'quick_menu'),
    SmokeActionTarget(route: '/guild/monument', label: 'Anıt', kind: 'quick_menu'),
    SmokeActionTarget(route: '/loot', label: 'Kasa Acma', kind: 'quick_menu'),
    SmokeActionTarget(route: '/market', label: 'Pazar', kind: 'quick_menu'),
    SmokeActionTarget(route: '/shop', label: 'Mağaza', kind: 'quick_menu'),
    SmokeActionTarget(route: '/bank', label: 'Banka', kind: 'quick_menu'),
    SmokeActionTarget(route: '/trade', label: 'Ticaret', kind: 'quick_menu'),
    SmokeActionTarget(route: '/crafting', label: 'Zanaat', kind: 'quick_menu'),
    SmokeActionTarget(route: '/enhancement', label: 'Item Upgrade', kind: 'quick_menu'),
    SmokeActionTarget(route: '/facilities', label: 'Tesisler', kind: 'quick_menu'),
    SmokeActionTarget(route: '/mekans', label: 'Mekanlar', kind: 'quick_menu'),
    SmokeActionTarget(route: '/quests', label: 'Görevler', kind: 'quick_menu'),
    SmokeActionTarget(route: '/hospital', label: 'Hastane', kind: 'quick_menu'),
    SmokeActionTarget(route: '/prison', label: 'Hapishane', kind: 'quick_menu'),
    SmokeActionTarget(route: '/chat', label: 'Sohbet', kind: 'quick_menu'),
    SmokeActionTarget(route: '/settings', label: 'Ayarlar', kind: 'quick_menu'),
  ];

  /// @deprecated Use [_quickMenu].
  static const List<SmokeActionTarget> _drawer = _quickMenu;

  static const List<SmokeActionTarget> _bottomNav = <SmokeActionTarget>[
    SmokeActionTarget(route: '/home', label: 'Home', kind: 'bottom_nav'),
    SmokeActionTarget(route: '/inventory', label: 'Envanter', kind: 'bottom_nav'),
    SmokeActionTarget(route: '/dungeon', label: 'Zindan', kind: 'bottom_nav'),
    SmokeActionTarget(route: '/character', label: 'Karakter', kind: 'bottom_nav'),
    SmokeActionTarget(route: '/home', label: 'Menü', kind: 'bottom_nav'),
  ];

  static const List<SmokeActionTarget> _tabs = <SmokeActionTarget>[
    SmokeActionTarget(route: '/market', label: 'Gozat', kind: 'tab'),
    SmokeActionTarget(route: '/market', label: 'Sat', kind: 'tab'),
    SmokeActionTarget(route: '/market', label: 'Pazarim', kind: 'tab'),
    SmokeActionTarget(route: '/quests', label: 'Tümü', kind: 'tab'),
    SmokeActionTarget(route: '/quests', label: 'Günlük', kind: 'tab'),
    SmokeActionTarget(route: '/quests', label: 'Haftalık', kind: 'tab'),
  ];

  /// Quick menu + bottom nav + tab switches — safe navigation-only taps.
  static const List<SmokeActionTarget> p0Navigation = <SmokeActionTarget>[
    ..._quickMenu,
    ..._bottomNav,
    ..._tabs,
  ];

  static int get p0Count => p0Navigation.length;

  /// Total actions from static UI inventory (reports/_ui_action_inventory.json).
  static const int fullInventoryActionCount = 350;

  static double get p0CoverageRatio => p0Count / fullInventoryActionCount;
}
