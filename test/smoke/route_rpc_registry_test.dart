import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/qa/smoke_route_registry.dart';

void main() {
  group('SmokeRouteRegistry route↔RPC', () {
    test('all keyRpcs use snake_case DB names (no client aliases)', () {
      final List<String> invalid = <String>[];
      for (final SmokeRouteEntry entry in SmokeRouteRegistry.allRoutes) {
        for (final String rpc in entry.keyRpcs) {
          if (!SmokeRouteRegistry.isValidKeyRpc(rpc)) {
            invalid.add('${entry.path} → $rpc');
          }
        }
      }
      expect(
        invalid,
        isEmpty,
        reason: 'Invalid keyRpc entries:\n${invalid.join('\n')}',
      );
    });

    test('stale client aliases are blocked', () {
      for (final String alias in SmokeRouteRegistry.staleClientAliases) {
        expect(SmokeRouteRegistry.isValidKeyRpc(alias), isFalse);
      }
    });

    test('production keyRpcs cover core gameplay screens', () {
      final Set<String> rpcs =
          SmokeRouteRegistry.productionKeyRpcs.toSet();

      const List<String> required = <String>[
        'get_codex_dashboard',
        'get_dungeon_siege_hub',
        'get_guild_war_season',
        'get_player_facilities_with_queue',
        'get_market_tickers',
        'get_my_inbox_notifications',
        'heal_health_with_gems',
      ];

      for (final String rpc in required) {
        expect(rpcs, contains(rpc), reason: 'Missing production RPC: $rpc');
      }
    });

    test('each route path maps to unique valid keyRpc list', () {
      for (final MapEntry<String, List<String>> entry
          in SmokeRouteRegistry.routeKeyRpcMap.entries) {
        expect(entry.key, startsWith('/'));
        expect(entry.value, isNotEmpty);
        expect(entry.value.toSet().length, entry.value.length,
            reason: 'Duplicate RPC on ${entry.key}');
        for (final String rpc in entry.value) {
          expect(SmokeRouteRegistry.isValidKeyRpc(rpc), isTrue,
              reason: '$rpc on ${entry.key}');
        }
      }
    });

    test('siege/guild-war/facilities routes declare expected RPCs', () {
      String rpcsFor(String path) {
        return SmokeRouteRegistry.allRoutes
            .firstWhere((SmokeRouteEntry e) => e.path == path)
            .keyRpcs
            .join(',');
      }

      expect(
        rpcsFor('/dungeon/siege'),
        contains('get_dungeon_siege_hub'),
      );
      expect(
        rpcsFor('/guild-war'),
        contains('get_guild_war_season'),
      );
      expect(
        rpcsFor('/facilities'),
        contains('get_player_facilities_with_queue'),
      );
    });

    test('qa_smoke RPCs only on explicit smoke routes', () {
      for (final SmokeRouteEntry entry in SmokeRouteRegistry.allRoutes) {
        for (final String rpc in entry.keyRpcs) {
          if (!rpc.startsWith('qa_smoke_')) continue;
          expect(
            entry.path,
            anyOf('/horse-race', contains('smoke')),
            reason: 'qa_smoke RPC $rpc on unexpected route ${entry.path}',
          );
        }
      }
    });
  });
}
