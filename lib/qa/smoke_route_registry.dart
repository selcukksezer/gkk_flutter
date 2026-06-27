/// Top bar + sub-screen smoke coverage registry.
/// Used by integration_test and test/smoke/route_registry_test.dart.
class SmokeRouteEntry {
  const SmokeRouteEntry({
    required this.label,
    required this.path,
    this.group = 'quick_menu',
    this.requiresAuth = true,
    this.sampleSubPaths = const <String>[],
    this.keyRpcs = const <String>[],
  });

  final String label;
  final String path;
  final String group;
  final bool requiresAuth;
  final List<String> sampleSubPaths;
  final List<String> keyRpcs;
}

class SmokeRouteRegistry {
  const SmokeRouteRegistry._();

  static const List<SmokeRouteEntry> quickMenuRoutes = <SmokeRouteEntry>[
    SmokeRouteEntry(label: 'Ana Sayfa', path: '/home', keyRpcs: <String>['loadProfile']),
    SmokeRouteEntry(label: 'Envanter', path: '/inventory', group: 'quick_menu', keyRpcs: <String>['get_inventory']),
    SmokeRouteEntry(label: 'Karakter', path: '/character', keyRpcs: <String>['claim_alchemist_detox']),
    SmokeRouteEntry(label: 'Zindan', path: '/dungeon', keyRpcs: <String>['get_dungeons', 'attack_dungeon']),
    SmokeRouteEntry(
      label: 'PvP',
      path: '/pvp',
      sampleSubPaths: <String>['/pvp/history', '/pvp/tournament'],
      keyRpcs: <String>[
        'get_pvp_dashboard',
        'get_pvp_history',
        'get_tournament_bracket',
        'join_pvp_tournament',
      ],
    ),
    SmokeRouteEntry(label: 'Sıralama', path: '/leaderboard'),
    SmokeRouteEntry(
      label: 'İtibar',
      path: '/reputation',
      keyRpcs: <String>['get_reputation'],
    ),
    SmokeRouteEntry(
      label: 'Battle Pass',
      path: '/season',
      keyRpcs: <String>['bp_ensure_player_initialized', 'buy_vip_pass'],
    ),
    SmokeRouteEntry(
      label: 'Lonca',
      path: '/guild',
      keyRpcs: <String>['get_my_guild', 'create_guild', 'join_guild'],
    ),
    SmokeRouteEntry(
      label: 'Lonca Savaşı',
      path: '/guild-war',
      sampleSubPaths: <String>[
        '/guild-war/logs',
        '/guild-war/tournament/sample-id',
        '/guild-war/territory/sample-id',
      ],
      keyRpcs: <String>['get_guild_war_season', 'get_guild_war_tournaments'],
    ),
    SmokeRouteEntry(
      label: 'Anıt',
      path: '/guild/monument',
      sampleSubPaths: <String>['/guild/monument/donate'],
      keyRpcs: <String>['get_monument_dashboard', 'upgrade_monument', 'donate_to_monument'],
    ),
    SmokeRouteEntry(
      label: 'Kasa Acma',
      path: '/loot',
      keyRpcs: <String>['get_loot_boxes_with_stats'],
    ),
    SmokeRouteEntry(
      label: 'At Yarisi',
      path: '/horse-race',
      keyRpcs: <String>['get_horse_race_state', 'place_horse_race_bet', 'qa_smoke_horse_race_fairness'],
    ),
    SmokeRouteEntry(label: 'Pazar', path: '/market', keyRpcs: <String>['loadTickers', 'loadMyOrders']),
    SmokeRouteEntry(label: 'Mağaza', path: '/shop'),
    SmokeRouteEntry(label: 'Banka', path: '/bank'),
    SmokeRouteEntry(
      label: 'Ticaret',
      path: '/trade',
      keyRpcs: <String>['initiate_trade', 'confirm_trade', 'cancel_trade'],
    ),
    SmokeRouteEntry(
      label: 'Zanaat',
      path: '/crafting',
      keyRpcs: <String>['get_craft_recipes', 'start_crafting', 'claim_crafted_item'],
    ),
    SmokeRouteEntry(label: 'Item Upgrade', path: '/enhancement'),
    SmokeRouteEntry(
      label: 'Tesisler',
      path: '/facilities',
      sampleSubPaths: <String>['/facilities/farm'],
      keyRpcs: <String>['get_player_facilities_with_queue'],
    ),
    SmokeRouteEntry(
      label: 'Mekanlar',
      path: '/mekans',
      sampleSubPaths: <String>[
        '/mekans/create',
        '/my-mekan',
        '/mekans/sample-id',
        '/mekans/sample-id/arena',
      ],
    ),
    SmokeRouteEntry(
      label: 'Görevler',
      path: '/quests',
      keyRpcs: <String>['get_available_quests', 'complete_quest', 'claim_quest_reward'],
    ),
    SmokeRouteEntry(
      label: 'Hastane',
      path: '/hospital',
      keyRpcs: <String>['heal_with_gems', 'attempt_hospital_escape'],
    ),
    SmokeRouteEntry(
      label: 'Hapishane',
      path: '/prison',
      keyRpcs: <String>['release_from_prison', 'attempt_prison_escape'],
    ),
    SmokeRouteEntry(label: 'Sohbet', path: '/chat'),
    SmokeRouteEntry(
      label: 'Ayarlar',
      path: '/settings',
      keyRpcs: <String>['update_user_profile'],
    ),
  ];

  static const List<SmokeRouteEntry> bottomNavRoutes = <SmokeRouteEntry>[
    SmokeRouteEntry(label: 'Home', path: '/home', group: 'bottom_nav'),
    SmokeRouteEntry(label: 'Inventory', path: '/inventory', group: 'bottom_nav', keyRpcs: <String>['get_inventory']),
    SmokeRouteEntry(label: 'Dungeon', path: '/dungeon', group: 'bottom_nav'),
    SmokeRouteEntry(label: 'Character', path: '/character', group: 'bottom_nav'),
    SmokeRouteEntry(label: 'Menü', path: '/home', group: 'bottom_nav'),
  ];

  /// @deprecated Use [quickMenuRoutes].
  static const List<SmokeRouteEntry> drawerRoutes = quickMenuRoutes;

  static const List<SmokeRouteEntry> authRoutes = <SmokeRouteEntry>[
    SmokeRouteEntry(label: 'Splash', path: '/', group: 'auth', requiresAuth: false),
    SmokeRouteEntry(label: 'Login', path: '/login', group: 'auth', requiresAuth: false),
    SmokeRouteEntry(label: 'Register', path: '/register', group: 'auth', requiresAuth: false),
    SmokeRouteEntry(
      label: 'Character Select',
      path: '/onboarding/character-select',
      group: 'auth',
      keyRpcs: <String>['get_character_classes'],
    ),
  ];

  static List<SmokeRouteEntry> get allRoutes => <SmokeRouteEntry>[
        ...quickMenuRoutes,
        ...bottomNavRoutes,
        ...authRoutes,
        const SmokeRouteEntry(
          label: 'Dungeon Battle',
          path: '/dungeon/battle',
          group: 'flow',
          keyRpcs: <String>['attack_dungeon', 'collect_dungeon_rewards'],
        ),
      ];

  static List<String> get uniquePaths {
    final Set<String> seen = <String>{};
    final List<String> paths = <String>[];
    for (final SmokeRouteEntry entry in allRoutes) {
      if (seen.add(entry.path)) {
        paths.add(entry.path);
      }
      for (final String sub in entry.sampleSubPaths) {
        if (seen.add(sub)) {
          paths.add(sub);
        }
      }
    }
    return paths;
  }

  static int get quickMenuRouteCount =>
      quickMenuRoutes.where((SmokeRouteEntry e) => e.group == 'quick_menu').length;

  /// Navigable quick-menu entries (excludes logout-only label).
  static int get drawerRouteCount => quickMenuRouteCount;
}
