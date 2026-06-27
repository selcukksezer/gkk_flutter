import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/qa/smoke_route_registry.dart';
import 'package:gkk_flutter/routing/app_router.dart';

void main() {
  group('SmokeRouteRegistry', () {
    test('covers all AppRoutes quick menu paths', () {
      const List<String> requiredQuickMenuPaths = <String>[
        AppRoutes.home,
        AppRoutes.inventory,
        AppRoutes.character,
        AppRoutes.dungeon,
        AppRoutes.pvp,
        AppRoutes.leaderboard,
        AppRoutes.reputation,
        AppRoutes.season,
        AppRoutes.guild,
        AppRoutes.guildWar,
        AppRoutes.guildMonument,
        AppRoutes.loot,
        AppRoutes.market,
        AppRoutes.shop,
        AppRoutes.bank,
        AppRoutes.trade,
        AppRoutes.crafting,
        AppRoutes.enhancement,
        AppRoutes.facilities,
        AppRoutes.mekans,
        AppRoutes.quests,
        AppRoutes.hospital,
        AppRoutes.prison,
        AppRoutes.chat,
        AppRoutes.settings,
        AppRoutes.horseRace,
      ];

      final Set<String> covered = SmokeRouteRegistry.quickMenuRoutes
          .where((SmokeRouteEntry e) => e.group == 'quick_menu')
          .map((SmokeRouteEntry e) => e.path)
          .toSet();

      for (final String path in requiredQuickMenuPaths) {
        expect(covered, contains(path), reason: 'Missing quick menu route: $path');
      }

      expect(SmokeRouteRegistry.quickMenuRouteCount, 26);
    });

    test('includes mandatory sub-screens', () {
      final Set<String> all = SmokeRouteRegistry.uniquePaths.toSet();

      const List<String> requiredSubs = <String>[
        '/facilities/farm',
        '/guild-war/logs',
        '/guild-war/tournament/sample-id',
        '/guild-war/territory/sample-id',
        '/guild/monument/donate',
        '/mekans/create',
        '/my-mekan',
        '/mekans/sample-id',
        '/mekans/sample-id/arena',
        '/pvp/history',
        '/pvp/tournament',
        '/dungeon/battle',
        AppRoutes.inventory,
      ];

      for (final String path in requiredSubs) {
        expect(all, contains(path), reason: 'Missing sub-route: $path');
      }
    });

    test('unique path count meets smoke matrix minimum', () {
      expect(
        SmokeRouteRegistry.uniquePaths.length,
        greaterThanOrEqualTo(35),
      );
    });
  });
}
