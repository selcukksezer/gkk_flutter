import 'package:gkk_flutter/core/services/supabase_service.dart';
import 'package:gkk_flutter/qa/smoke_route_registry.dart';

/// Resolves placeholder routes (sample-id) to real DB ids for integration tests.
class SmokeRouteResolver {
  const SmokeRouteResolver._();

  static Future<List<String>> integrationPaths() async {
    final String? mekanId = await _fetchId('mekans');
    final String? tournamentId = await _fetchId('guild_war_tournaments');
    final String? territoryId = await _fetchId('guild_war_territories');

    final List<String> resolved = <String>[];
    for (final String path in SmokeRouteRegistry.uniquePaths) {
      if (path.contains('sample-id')) {
        final String? mapped = _mapSamplePath(
          path,
          mekanId: mekanId,
          tournamentId: tournamentId,
          territoryId: territoryId,
        );
        if (mapped != null) {
          resolved.add(mapped);
        }
        continue;
      }
      resolved.add(path);
    }
    return resolved;
  }

  static String? _mapSamplePath(
    String path, {
    required String? mekanId,
    required String? tournamentId,
    required String? territoryId,
  }) {
    if (path.startsWith('/mekans/') && mekanId != null) {
      return path.replaceAll('sample-id', mekanId);
    }
    if (path.contains('/guild-war/tournament/') && tournamentId != null) {
      return path.replaceAll('sample-id', tournamentId);
    }
    if (path.contains('/guild-war/territory/') && territoryId != null) {
      return path.replaceAll('sample-id', territoryId);
    }
    return null;
  }

  static Future<String?> _fetchId(String table) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      final dynamic row = await SupabaseService.client
          .from(table)
          .select('id')
          .limit(1)
          .maybeSingle();
      if (row is Map<String, dynamic>) {
        return row['id'] as String?;
      }
    } catch (_) {}
    return null;
  }
}
