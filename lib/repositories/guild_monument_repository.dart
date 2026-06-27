import '../core/services/supabase_service.dart';
import '../models/guild_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<GuildMonumentRepository> guildMonumentRepositoryProvider =
    Provider<GuildMonumentRepository>((Ref ref) => SupabaseGuildMonumentRepository());

class MonumentContributor {
  const MonumentContributor({
    required this.userId,
    required this.username,
    required this.contributionScore,
    required this.goldDonated,
  });

  final String userId;
  final String username;
  final int contributionScore;
  final int goldDonated;

  factory MonumentContributor.fromJson(Map<String, dynamic> json) {
    return MonumentContributor(
      userId: (json['user_id'] ?? '').toString(),
      username: (json['username'] ?? 'Oyuncu').toString(),
      contributionScore: (json['contribution_score'] as num?)?.toInt() ?? 0,
      goldDonated: (json['gold_donated'] as num?)?.toInt() ?? 0,
    );
  }
}

class MonumentBlueprint {
  const MonumentBlueprint({
    required this.blueprintType,
    required this.fragments,
    required this.fragmentsRequired,
    required this.isComplete,
  });

  final String blueprintType;
  final int fragments;
  final int fragmentsRequired;
  final bool isComplete;

  factory MonumentBlueprint.fromJson(Map<String, dynamic> json) {
    return MonumentBlueprint(
      blueprintType: (json['blueprint_type'] ?? '').toString(),
      fragments: (json['fragments'] as num?)?.toInt() ?? 0,
      fragmentsRequired: (json['fragments_required'] as num?)?.toInt() ?? 0,
      isComplete: json['is_complete'] == true,
    );
  }
}

class MonumentGuildSnapshot {
  const MonumentGuildSnapshot({
    required this.id,
    required this.name,
    required this.monumentLevel,
    required this.structural,
    required this.mystical,
    required this.critical,
    required this.goldPool,
  });

  final String id;
  final String name;
  final int monumentLevel;
  final int structural;
  final int mystical;
  final int critical;
  final int goldPool;

  factory MonumentGuildSnapshot.fromJson(Map<String, dynamic> json) {
    return MonumentGuildSnapshot(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      monumentLevel: (json['monument_level'] as num?)?.toInt() ?? 0,
      structural: (json['monument_structural'] as num?)?.toInt() ?? 0,
      mystical: (json['monument_mystical'] as num?)?.toInt() ?? 0,
      critical: (json['monument_critical'] as num?)?.toInt() ?? 0,
      goldPool: (json['monument_gold_pool'] as num?)?.toInt() ?? 0,
    );
  }
}

class MonumentMyStats {
  const MonumentMyStats({
    required this.totals,
    required this.today,
    required this.wallet,
    required this.contributionScore,
  });

  final MonumentResourceSnapshot totals;
  final MonumentResourceSnapshot today;
  final MonumentResourceSnapshot wallet;
  final int contributionScore;

  int donatedTotal(MonumentResourceKind kind) => totals.forKind(kind);

  int donatedToday(MonumentResourceKind kind) => today.forKind(kind);

  int owned(MonumentResourceKind kind) => wallet.forKind(kind);

  int dailyLeft(MonumentResourceKind kind) {
    final int max = kind.dailyMax;
    return (max - donatedToday(kind)).clamp(0, max);
  }

  int maxDonatable(MonumentResourceKind kind) {
    final int ownedAmount = owned(kind);
    final int left = dailyLeft(kind);
    if (ownedAmount <= 0 || left <= 0) return 0;
    return ownedAmount < left ? ownedAmount : left;
  }
}

class MonumentDashboard {
  const MonumentDashboard({
    required this.guild,
    required this.memberCount,
    required this.contributors,
    required this.blueprints,
    required this.myStats,
    this.nextCost,
  });

  final MonumentGuildSnapshot guild;
  final int memberCount;
  final List<MonumentContributor> contributors;
  final List<MonumentBlueprint> blueprints;
  final MonumentMyStats myStats;
  final Map<String, dynamic>? nextCost;

  factory MonumentDashboard.fromRpc(Map<String, dynamic> json) {
    final Map<String, dynamic> guildJson =
        Map<String, dynamic>.from(json['guild'] as Map? ?? <String, dynamic>{});
    final dynamic rawNext = json['next_cost'];
    final Map<String, dynamic> totalsJson =
        Map<String, dynamic>.from(json['my_totals'] as Map? ?? <String, dynamic>{});
    return MonumentDashboard(
      guild: MonumentGuildSnapshot.fromJson(guildJson),
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      contributors: (json['contributors'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => MonumentContributor.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      blueprints: (json['blueprints'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => MonumentBlueprint.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      myStats: MonumentMyStats(
        totals: MonumentResourceSnapshot.fromJson(totalsJson),
        today: MonumentResourceSnapshot.fromJson(
          Map<String, dynamic>.from(json['my_today'] as Map? ?? <String, dynamic>{}),
        ),
        wallet: MonumentResourceSnapshot.fromJson(
          Map<String, dynamic>.from(json['my_wallet'] as Map? ?? <String, dynamic>{}),
        ),
        contributionScore: (totalsJson['contribution_score'] as num?)?.toInt() ?? 0,
      ),
      nextCost: rawNext is Map ? Map<String, dynamic>.from(rawNext) : null,
    );
  }
}

class MonumentResourceProgress {
  const MonumentResourceProgress({
    required this.kind,
    required this.current,
    required this.required,
    required this.progress,
  });

  final MonumentResourceKind kind;
  final int current;
  final int required;
  final double progress;

  int get filledPercent => (progress * 100).round().clamp(0, 100);

  int get remainingPercent => (100 - filledPercent).clamp(0, 100);
}

class MonumentUpgradeProgress {
  const MonumentUpgradeProgress({
    required this.nextLevel,
    required this.resources,
    required this.overallProgress,
    required this.blueprintRequired,
    required this.blueprintComplete,
    this.blueprintType,
  });

  final int nextLevel;
  final List<MonumentResourceProgress> resources;
  final double overallProgress;
  final bool blueprintRequired;
  final bool blueprintComplete;
  final String? blueprintType;

  int get filledPercent => (overallProgress * 100).round().clamp(0, 100);

  int get remainingPercent => (100 - filledPercent).clamp(0, 100);

  bool get isReady =>
      remainingPercent <= 0 &&
      (!blueprintRequired || blueprintComplete);

  static MonumentUpgradeProgress? compute({
    required MonumentGuildSnapshot guild,
    required Map<String, dynamic>? nextCost,
    required List<MonumentBlueprint> blueprints,
  }) {
    if (nextCost == null || nextCost['max_level'] == true || nextCost.containsKey('error')) {
      return null;
    }

    final int nextLevel = (nextCost['next_level'] as num?)?.toInt() ?? guild.monumentLevel + 1;
    final List<MonumentResourceProgress> resources = <MonumentResourceProgress>[
      _resourceProgress(
        kind: MonumentResourceKind.structural,
        current: guild.structural,
        required: (nextCost['structural'] as num?)?.toInt() ?? 0,
      ),
      _resourceProgress(
        kind: MonumentResourceKind.mystical,
        current: guild.mystical,
        required: (nextCost['mystical'] as num?)?.toInt() ?? 0,
      ),
      _resourceProgress(
        kind: MonumentResourceKind.critical,
        current: guild.critical,
        required: (nextCost['critical'] as num?)?.toInt() ?? 0,
      ),
      _resourceProgress(
        kind: MonumentResourceKind.gold,
        current: guild.goldPool,
        required: (nextCost['gold'] as num?)?.toInt() ?? 0,
      ),
    ];

    final String? blueprintType = nextCost['blueprint_type']?.toString();
    final bool blueprintRequired = blueprintType != null && blueprintType.isNotEmpty;
    final bool blueprintComplete = !blueprintRequired ||
        blueprints.any(
          (MonumentBlueprint b) => b.blueprintType == blueprintType && b.isComplete,
        );

    double overall = resources.map((MonumentResourceProgress r) => r.progress).reduce(
          (double a, double b) => a < b ? a : b,
        );
    if (blueprintRequired && !blueprintComplete) {
      overall = 0;
    }

    return MonumentUpgradeProgress(
      nextLevel: nextLevel,
      resources: resources,
      overallProgress: overall.clamp(0.0, 1.0),
      blueprintRequired: blueprintRequired,
      blueprintComplete: blueprintComplete,
      blueprintType: blueprintType,
    );
  }

  static MonumentResourceProgress _resourceProgress({
    required MonumentResourceKind kind,
    required int current,
    required int required,
  }) {
    if (required <= 0) {
      return MonumentResourceProgress(kind: kind, current: current, required: 0, progress: 1);
    }
    return MonumentResourceProgress(
      kind: kind,
      current: current,
      required: required,
      progress: (current / required).clamp(0.0, 1.0),
    );
  }
}

class MonumentDonateResult {
  const MonumentDonateResult({required this.scoreAdded});

  final int scoreAdded;

  factory MonumentDonateResult.fromRpc(Map<String, dynamic> json) {
    return MonumentDonateResult(scoreAdded: (json['score_added'] as num?)?.toInt() ?? 0);
  }
}

abstract class GuildMonumentRepository {
  Future<MonumentDashboard> fetchDashboard(String guildId);

  Future<MonumentDonateResult> donate({
    required int structural,
    required int mystical,
    required int critical,
    required int gold,
  });
}

class SupabaseGuildMonumentRepository implements GuildMonumentRepository {
  @override
  Future<MonumentDashboard> fetchDashboard(String guildId) async {
    final dynamic raw = await SupabaseService.client.rpc(
      'get_monument_dashboard',
      params: <String, dynamic>{'p_guild_id': guildId},
    );
    if (raw is! Map) {
      throw Exception('Anıt verileri işlenemedi');
    }
    final Map<String, dynamic> payload = Map<String, dynamic>.from(raw);
    if (payload['success'] != true) {
      throw Exception((payload['error'] ?? 'Anıt verileri yüklenemedi').toString());
    }
    return MonumentDashboard.fromRpc(payload);
  }

  @override
  Future<MonumentDonateResult> donate({
    required int structural,
    required int mystical,
    required int critical,
    required int gold,
  }) async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) throw Exception('Oturum yok');

    final dynamic raw = await SupabaseService.client.rpc(
      'donate_to_monument',
      params: <String, dynamic>{
        'p_user_id': user.id,
        'p_structural': structural,
        'p_mystical': mystical,
        'p_critical': critical,
        'p_gold': gold,
      },
    );
    if (raw is! Map) throw Exception('Bağış yanıtı işlenemedi');
    final Map<String, dynamic> result = Map<String, dynamic>.from(raw);
    if (result['success'] != true) {
      throw Exception((result['error'] ?? 'Bağış başarısız').toString());
    }
    return MonumentDonateResult.fromRpc(result);
  }
}

Map<String, int> monumentAmountsForKind(MonumentResourceKind kind, int amount) {
  return <String, int>{
    'structural': kind == MonumentResourceKind.structural ? amount : 0,
    'mystical': kind == MonumentResourceKind.mystical ? amount : 0,
    'critical': kind == MonumentResourceKind.critical ? amount : 0,
    'gold': kind == MonumentResourceKind.gold ? amount : 0,
  };
}

Future<MonumentDonateResult> monumentDonateKind({
  required GuildMonumentRepository repository,
  required MonumentResourceKind kind,
  required int amount,
  required MonumentMyStats stats,
}) async {
  final int capped = monumentDonateCap(
    owned: stats.owned(kind),
    donatedToday: stats.donatedToday(kind),
    dailyMax: kind.dailyMax,
    requested: amount,
  );
  if (capped <= 0) {
    throw Exception('Bağışlanacak kaynak yok veya günlük limit doldu');
  }
  final Map<String, int> amounts = monumentAmountsForKind(kind, capped);
  return repository.donate(
    structural: amounts['structural']!,
    mystical: amounts['mystical']!,
    critical: amounts['critical']!,
    gold: amounts['gold']!,
  );
}
