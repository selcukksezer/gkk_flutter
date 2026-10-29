import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/matchmaking/matchmaking_offer.dart';
import '../core/matchmaking/matchmaking_service.dart';
import '../core/services/supabase_service.dart';
import '../models/mekan_model.dart';

/// Central access point for all mekan RPC + table calls.
///
/// Keeps every RPC parameter name in one place so screens never drift out of
/// sync with the backend signatures.
class MekanRepository {
  const MekanRepository();

  String get _uid => SupabaseService.client.auth.currentUser?.id ?? '';

  Future<Map<String, dynamic>> _rpc(String fn, [Map<String, dynamic>? params]) async {
    final dynamic res = await SupabaseService.client.rpc(fn, params: params);
    if (res is Map) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(res);
      if (map['success'] == false) {
        throw MekanException(map['error']?.toString() ?? 'İşlem başarısız');
      }
      return map;
    }
    return <String, dynamic>{'success': true};
  }

  // ── Reads ────────────────────────────────────────────────────────────────

  Future<Mekan?> fetchMyMekan() async {
    final dynamic res = await SupabaseService.client
        .from('mekans')
        .select('*')
        .eq('owner_id', _uid)
        .maybeSingle();
    if (res == null) return null;
    return Mekan.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<Mekan?> fetchMekan(String mekanId) async {
    final dynamic res = await SupabaseService.client
        .from('mekans')
        .select('*')
        .eq('id', mekanId)
        .maybeSingle();
    if (res == null) return null;
    return Mekan.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<List<MekanStockEntry>> fetchStock(String mekanId, {bool onlyAvailable = false}) async {
    var query = SupabaseService.client
        .from('mekan_stock')
        .select(
          '*, items(name, name_tr, type, sub_type, rarity, is_han_only, icon, energy_restore)',
        )
        .eq('mekan_id', mekanId);
    if (onlyAvailable) {
      query = query.gt('quantity', 0).gt('sell_price', 0);
    }
    final dynamic res = await query;
    return (res as List)
        .map((dynamic e) => MekanStockEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((MekanStockEntry s) => s.eligible && (!onlyAvailable || s.isListedForSale))
        .toList();
  }

  /// First few listed-for-sale item icons per mekan for the hub list card.
  Future<Map<String, List<MekanStockPeek>>> fetchStockPreviews(
    List<String> mekanIds, {
    int perMekan = 4,
  }) async {
    if (mekanIds.isEmpty) return <String, List<MekanStockPeek>>{};
    final dynamic res = await SupabaseService.client
        .from('mekan_stock')
        .select('mekan_id, item_id, sell_price, quantity, items(icon, rarity, is_han_only, type)')
        .inFilter('mekan_id', mekanIds)
        .gt('quantity', 0)
        .gt('sell_price', 0);
    final Map<String, List<MekanStockPeek>> byMekan =
        <String, List<MekanStockPeek>>{};
    for (final dynamic raw in res as List) {
      final Map<String, dynamic> row =
          Map<String, dynamic>.from(raw as Map);
      final Map<String, dynamic> item = row['items'] is Map
          ? Map<String, dynamic>.from(row['items'] as Map)
          : const <String, dynamic>{};
      final bool han = item['is_han_only'] == true;
      final String? type = item['type']?.toString();
      if (!mekanItemEligible(isHanOnly: han, type: type)) continue;
      if (_toInt(row['quantity']) <= 0 || _toInt(row['sell_price']) <= 0) continue;

      final String mekanId = (row['mekan_id'] ?? '').toString();
      final List<MekanStockPeek> list =
          byMekan.putIfAbsent(mekanId, () => <MekanStockPeek>[]);
      if (list.length >= perMekan) continue;
      list.add(MekanStockPeek(
        itemId: (row['item_id'] ?? '').toString(),
        icon: (item['icon'] ?? '').toString(),
        rarity: (item['rarity'] ?? 'common').toString(),
      ));
    }
    return byMekan;
  }

  /// Inventory items that may be stocked, aggregated by item_id (fixes the
  /// duplicate-value dropdown crash that blocked stocking).
  Future<List<MekanInventoryEntry>> fetchEligibleInventory() async {
    final dynamic res = await SupabaseService.client
        .from('inventory')
        .select('item_id, quantity, is_equipped, items(name, name_tr, type, sub_type, rarity, is_han_only, icon)')
        .eq('user_id', _uid)
        .gt('quantity', 0);

    final Map<String, MekanInventoryEntry> byId = <String, MekanInventoryEntry>{};
    for (final dynamic e in res as List) {
      final Map<String, dynamic> row = Map<String, dynamic>.from(e as Map);
      if (row['is_equipped'] == true) continue;
      final MekanInventoryEntry entry = MekanInventoryEntry.fromJson(row);
      if (!entry.eligible || entry.quantity <= 0) continue;
      final MekanInventoryEntry? prev = byId[entry.itemId];
      byId[entry.itemId] = prev == null ? entry : entry.copyAdd(prev.quantity);
    }
    final List<MekanInventoryEntry> list = byId.values.toList()
      ..sort((MekanInventoryEntry a, MekanInventoryEntry b) => a.name.compareTo(b.name));
    return list;
  }

  /// Sayfalı çekim — varsayılan 20 satır; fame'e göre sıralı.
  static const int defaultPageSize = 20;

  Future<List<Mekan>> fetchAllMekans({int limit = defaultPageSize, int offset = 0}) async {
    final dynamic res = await SupabaseService.client
        .from('mekans')
        .select('*')
        .order('fame', ascending: false)
        .range(offset, offset + limit - 1);
    return (res as List)
        .map((dynamic e) => Mekan.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<MekanStats> fetchStats(String mekanId) async {
    final Map<String, dynamic> res = await _rpc('get_mekan_stats', <String, dynamic>{'p_mekan_id': mekanId});
    return MekanStats.fromJson(res);
  }

  Future<List<MekanLeaderboardRow>> fetchFameLeaderboard({int limit = 20}) async {
    final Map<String, dynamic> res = await _rpc('get_mekan_fame_leaderboard', <String, dynamic>{'p_limit': limit});
    final List<dynamic> rows = (res['leaderboard'] as List?) ?? <dynamic>[];
    return rows
        .map((dynamic e) => MekanLeaderboardRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<ArenaRankRow>> fetchArenaRanking({int limit = 50}) async {
    final Map<String, dynamic> res = await _rpc('get_mekan_arena_ranking', <String, dynamic>{'p_limit': limit});
    final List<dynamic> rows = (res['ranking'] as List?) ?? <dynamic>[];
    return rows
        .map((dynamic e) => ArenaRankRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Server-issued random offers (N≈6) + refresh cooldown metadata.
  Future<MatchmakingOffersResult> fetchArenaOpponentOffers() async {
    const MatchmakingService svc = MatchmakingService();
    try {
      return await svc.fetchOffers(MatchmakingService.modeArena);
    } on MatchmakingException catch (e) {
      throw MekanException(e.message);
    }
  }

  /// Bracket matchmaking: server RPC level/rating bandı + newbie shield uygular.
  /// Eski top-15-global sorgusu newbie crush'a yol açıyordu (QA bulgusu).
  Future<List<ArenaOpponent>> fetchArenaOpponents() async {
    final MatchmakingOffersResult result = await fetchArenaOpponentOffers();
    return result.offers
        .map(
          (MatchmakingOffer o) => ArenaOpponent(
            offerId: o.offerId,
            authId: o.authId,
            username: o.username,
            level: o.level,
            pvpRating: o.pvpRating,
            power: o.power > 0 ? o.power : (o.attack + o.defense),
          ),
        )
        .toList();
  }

  /// Server-side unlock costs — same values as [open_mekan].
  Future<List<MekanTypeCatalogRow>> fetchTypeCatalog() async {
    final Map<String, dynamic> res = await _rpc('get_mekan_type_catalog');
    final List<dynamic> rows = (res['types'] as List?) ?? <dynamic>[];
    return rows
        .map((dynamic e) => MekanTypeCatalogRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ── Writes ───────────────────────────────────────────────────────────────

  Future<void> createMekan({required String type, required String name}) =>
      _rpc('create_mekan', <String, dynamic>{'p_mekan_type': type, 'p_name': name});

  Future<void> toggleStatus({required String mekanId, required bool isOpen}) =>
      _rpc('toggle_mekan_status', <String, dynamic>{'p_mekan_id': mekanId, 'p_is_open': isOpen});

  Future<void> updateStock({
    required String mekanId,
    required String itemId,
    required int quantity,
    required int sellPrice,
  }) =>
      _rpc('update_mekan_stock', <String, dynamic>{
        'p_mekan_id': mekanId,
        'p_item_id': itemId,
        'p_quantity': quantity,
        'p_sell_price': sellPrice,
      });

  Future<Map<String, dynamic>> buy({
    required String mekanId,
    required String itemId,
    required int quantity,
  }) =>
      _rpc('buy_from_mekan', <String, dynamic>{
        'p_mekan_id': mekanId,
        'p_item_id': itemId,
        'p_quantity': quantity,
      });

  Future<Map<String, dynamic>> upgrade(String mekanId) =>
      _rpc('upgrade_mekan', <String, dynamic>{'p_mekan_id': mekanId});

  Future<void> payRent(String mekanId) =>
      _rpc('pay_mekan_rent', <String, dynamic>{'p_mekan_id': mekanId});

  Future<void> setHappyHour({required String mekanId, required bool active}) =>
      _rpc('set_mekan_happy_hour', <String, dynamic>{'p_mekan_id': mekanId, 'p_active': active});

  /// Crims-like status: tickets, addiction mult, level/rep gates.
  Future<MekanNightlifeStatus> getNightlifeStatus({String? mekanId}) async {
    final Map<String, dynamic> res = await _rpc(
      'get_nightlife_status',
      <String, dynamic>{'p_mekan_id': mekanId},
    );
    return MekanNightlifeStatus.fromJson(res);
  }

  Future<Map<String, dynamic>> refillQuote({
    required String mekanId,
    required String itemId,
  }) =>
      _rpc('mekan_refill_quote', <String, dynamic>{
        'p_mekan_id': mekanId,
        'p_item_id': itemId,
      });

  /// Core loop: spend 1 ticket + buy bar consumable → energy to max.
  Future<MekanRefillResult> refill({
    required String mekanId,
    required String itemId,
  }) async {
    final Map<String, dynamic> res = await _rpc('mekan_refill', <String, dynamic>{
      'p_mekan_id': mekanId,
      'p_item_id': itemId,
    });
    return MekanRefillResult.fromJson(res);
  }

  /// Nightlife: owner starts a party window (reuses happy_hour_until).
  Future<Map<String, dynamic>> startParty({
    required String mekanId,
    int durationMinutes = 60,
  }) =>
      _rpc('mekan_start_party', <String, dynamic>{
        'p_mekan_id': mekanId,
        'p_duration_minutes': durationMinutes,
      });

  @Deprecated('Use refill — hang_out deprecated server-side')
  Future<MekanNightlifeResult> hangOut(String mekanId) async {
    final Map<String, dynamic> res = await _rpc('mekan_hang_out', <String, dynamic>{
      'p_mekan_id': mekanId,
    });
    return MekanNightlifeResult.fromJson(res);
  }

  @Deprecated('Use refill — join_party deprecated server-side')
  Future<MekanNightlifeResult> joinParty(String mekanId) async {
    final Map<String, dynamic> res = await _rpc('mekan_join_party', <String, dynamic>{
      'p_mekan_id': mekanId,
    });
    return MekanNightlifeResult.fromJson(res);
  }

  Future<Map<String, dynamic>> pvpBet({
    required String mekanId,
    required String defenderId,
    required int wager,
    required String offerId,
  }) =>
      _rpc('mekan_pvp_bet', <String, dynamic>{
        'p_mekan_id': mekanId,
        'p_defender_id': defenderId,
        'p_wager': wager,
        'p_offer_id': offerId,
      });

  Future<ArenaWeeklyRewardStatus> fetchArenaWeeklyRewardStatus() async {
    final Map<String, dynamic> res = await _rpc('get_arena_weekly_reward_status');
    return ArenaWeeklyRewardStatus.fromJson(res);
  }

  Future<int> claimArenaWeeklyReward() async {
    final Map<String, dynamic> res = await _rpc('claim_arena_weekly_reward');
    return _toInt(res['reward_gold']);
  }
}

class MekanStockPeek {
  const MekanStockPeek({
    required this.itemId,
    required this.icon,
    required this.rarity,
  });

  final String itemId;
  final String icon;
  final String rarity;
}

final Provider<MekanRepository> mekanRepositoryProvider =
    Provider<MekanRepository>((Ref ref) => const MekanRepository());

/// Increment after create/toggle so hub list screens reload.
class MekanHubRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void touch() => state = state + 1;
}

final NotifierProvider<MekanHubRefreshNotifier, int> mekanHubRefreshProvider =
    NotifierProvider<MekanHubRefreshNotifier, int>(MekanHubRefreshNotifier.new);

class MekanTypeCatalogRow {
  const MekanTypeCatalogRow({
    required this.type,
    required this.cost,
    required this.reqLevel,
  });

  final String type;
  final int cost;
  final int reqLevel;

  factory MekanTypeCatalogRow.fromJson(Map<String, dynamic> json) => MekanTypeCatalogRow(
        type: (json['type'] ?? '').toString(),
        cost: _toInt(json['cost']),
        reqLevel: _toInt(json['req_level']),
      );
}

class MekanException implements Exception {
  const MekanException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Result of deprecated hang/party RPCs (kept for type compat).
class MekanNightlifeResult {
  const MekanNightlifeResult({
    required this.mode,
    required this.outcome,
    required this.message,
    required this.energyDelta,
    required this.energyCost,
    required this.goldDelta,
    required this.coverPaid,
    required this.vibeDelta,
    required this.nightlifeVibe,
    required this.hospital,
    required this.hospitalMinutes,
    this.hospitalReason,
    this.cooldownUntil,
    required this.cooldownSeconds,
    required this.partyActive,
  });

  final String mode;
  final String outcome;
  final String message;
  final int energyDelta;
  final int energyCost;
  final int goldDelta;
  final int coverPaid;
  final int vibeDelta;
  final int nightlifeVibe;
  final bool hospital;
  final int hospitalMinutes;
  final String? hospitalReason;
  final String? cooldownUntil;
  final int cooldownSeconds;
  final bool partyActive;

  bool get isGood => outcome == 'good';
  bool get isScam => outcome == 'scam';
  bool get isFight => outcome == 'fight';

  factory MekanNightlifeResult.fromJson(Map<String, dynamic> json) => MekanNightlifeResult(
        mode: (json['mode'] ?? 'hang').toString(),
        outcome: (json['outcome'] ?? 'neutral').toString(),
        message: (json['message'] ?? '').toString(),
        energyDelta: _toInt(json['energy_delta']),
        energyCost: _toInt(json['energy_cost']),
        goldDelta: _toInt(json['gold_delta']),
        coverPaid: _toInt(json['cover_paid']),
        vibeDelta: _toInt(json['vibe_delta']),
        nightlifeVibe: _toInt(json['nightlife_vibe']),
        hospital: json['hospital'] == true,
        hospitalMinutes: _toInt(json['hospital_minutes']),
        hospitalReason: json['hospital_reason']?.toString(),
        cooldownUntil: json['cooldown_until']?.toString(),
        cooldownSeconds: _toInt(json['cooldown_seconds']),
        partyActive: json['party_active'] == true,
      );
}

class MekanNightlifeStatus {
  const MekanNightlifeStatus({
    required this.tickets,
    required this.ticketsMax,
    required this.dailyGrant,
    required this.addictionLevel,
    required this.tolerance,
    required this.addictionPriceMult,
    required this.energy,
    required this.maxEnergy,
    required this.nightlifeVibe,
    required this.sessionRefills,
    required this.canEnter,
    this.gateError,
    required this.isOwn,
    required this.partyActive,
    required this.reqLevel,
    required this.reqReputation,
  });

  final int tickets;
  final int ticketsMax;
  final int dailyGrant;
  final int addictionLevel;
  final int tolerance;
  final double addictionPriceMult;
  final int energy;
  final int maxEnergy;
  final int nightlifeVibe;
  final int sessionRefills;
  final bool canEnter;
  final String? gateError;
  final bool isOwn;
  final bool partyActive;
  final int reqLevel;
  final int reqReputation;

  factory MekanNightlifeStatus.fromJson(Map<String, dynamic> json) => MekanNightlifeStatus(
        tickets: _toInt(json['tickets']),
        ticketsMax: _toInt(json['tickets_max'], fallback: 100),
        dailyGrant: _toInt(json['daily_grant'], fallback: 24),
        addictionLevel: _toInt(json['addiction_level']),
        tolerance: _toInt(json['tolerance']),
        addictionPriceMult: _toDouble(json['addiction_price_mult'], fallback: 1),
        energy: _toInt(json['energy']),
        maxEnergy: _toInt(json['max_energy'], fallback: 100),
        nightlifeVibe: _toInt(json['nightlife_vibe']),
        sessionRefills: _toInt(json['session_refills']),
        canEnter: json['can_enter'] != false,
        gateError: json['gate_error']?.toString(),
        isOwn: json['is_own'] == true,
        partyActive: json['party_active'] == true,
        reqLevel: _toInt(json['req_level'], fallback: 1),
        reqReputation: _toInt(json['req_reputation']),
      );
}

class MekanRefillResult {
  const MekanRefillResult({
    required this.outcome,
    required this.message,
    required this.hospital,
    required this.hospitalMinutes,
    this.hospitalReason,
    required this.energyBefore,
    required this.energyAfter,
    required this.energyDelta,
    required this.goldPaid,
    required this.ticketSpent,
    required this.ticketsLeft,
    required this.addictionLevel,
    required this.tolerance,
    required this.addictionPriceMult,
    required this.isOwn,
    required this.partyActive,
    required this.vibeDelta,
    required this.nightlifeVibe,
    required this.odNextWarning,
  });

  final String outcome;
  final String message;
  final bool hospital;
  final int hospitalMinutes;
  final String? hospitalReason;
  final int energyBefore;
  final int energyAfter;
  final int energyDelta;
  final int goldPaid;
  final int ticketSpent;
  final int ticketsLeft;
  final int addictionLevel;
  final int tolerance;
  final double addictionPriceMult;
  final bool isOwn;
  final bool partyActive;
  final int vibeDelta;
  final int nightlifeVibe;
  final bool odNextWarning;

  bool get isOverdose => outcome == 'overdose';
  bool get isRefill => outcome == 'refill';

  factory MekanRefillResult.fromJson(Map<String, dynamic> json) => MekanRefillResult(
        outcome: (json['outcome'] ?? 'refill').toString(),
        message: (json['message'] ?? '').toString(),
        hospital: json['hospital'] == true,
        hospitalMinutes: _toInt(json['hospital_minutes']),
        hospitalReason: json['hospital_reason']?.toString(),
        energyBefore: _toInt(json['energy_before']),
        energyAfter: _toInt(json['energy_after']),
        energyDelta: _toInt(json['energy_delta']),
        goldPaid: _toInt(json['gold_paid']),
        ticketSpent: _toInt(json['ticket_spent'], fallback: 1),
        ticketsLeft: _toInt(json['tickets_left']),
        addictionLevel: _toInt(json['addiction_level']),
        tolerance: _toInt(json['tolerance']),
        addictionPriceMult: _toDouble(json['addiction_price_mult'], fallback: 1),
        isOwn: json['is_own'] == true,
        partyActive: json['party_active'] == true,
        vibeDelta: _toInt(json['vibe_delta']),
        nightlifeVibe: _toInt(json['nightlife_vibe']),
        odNextWarning: json['od_next_warning'] == true,
      );
}

// ── Row models ───────────────────────────────────────────────────────────────

bool mekanItemEligible({required bool isHanOnly, required String? type}) =>
    isHanOnly || (type ?? '').toLowerCase() == 'potion';

int _toInt(dynamic v, {int fallback = 0}) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

double _toDouble(dynamic v, {double fallback = 0}) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

class MekanStockEntry {
  const MekanStockEntry({
    required this.stockId,
    required this.itemId,
    required this.name,
    required this.icon,
    required this.rarity,
    required this.subType,
    required this.isHanOnly,
    required this.quantity,
    required this.sellPrice,
    required this.eligible,
    this.energyRestore = 0,
    this.itemType,
  });

  final String stockId;
  final String itemId;
  final String name;
  final String icon;
  final String rarity;
  final String subType;
  final bool isHanOnly;
  final int quantity;
  final int sellPrice;
  final bool eligible;
  final int energyRestore;
  final String? itemType;

  /// Bar refill shelf (Crims drink/ticket) — energy / han / potion.
  bool get canRefill =>
      eligible && isListedForSale && (energyRestore > 0 || isHanOnly || (itemType ?? '').toLowerCase() == 'potion');

  factory MekanStockEntry.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> it =
        json['items'] is Map ? Map<String, dynamic>.from(json['items'] as Map) : <String, dynamic>{};
    final bool han = it['is_han_only'] == true;
    final String? type = it['type']?.toString();
    final String nameTr = (it['name_tr'] ?? '').toString();
    return MekanStockEntry(
      stockId: (json['id'] ?? '').toString(),
      itemId: (json['item_id'] ?? '').toString(),
      name: nameTr.isNotEmpty ? nameTr : (it['name']?.toString() ?? (json['item_id'] ?? '').toString()),
      icon: it['icon']?.toString() ?? '',
      rarity: (it['rarity'] ?? 'common').toString(),
      subType: (it['sub_type'] ?? '').toString(),
      isHanOnly: han,
      quantity: _toInt(json['quantity']),
      sellPrice: _toInt(json['sell_price']),
      eligible: mekanItemEligible(isHanOnly: han, type: type),
      energyRestore: _toInt(it['energy_restore']),
      itemType: type,
    );
  }
}

extension MekanStockEntrySale on MekanStockEntry {
  bool get isListedForSale => quantity > 0 && sellPrice > 0;
}

/// Hub list card — hide vitrin peek when mekan is not actively selling.
List<MekanStockPeek> mekanHubVitrinPeek(Mekan mekan, List<MekanStockPeek> peek) {
  if (!mekan.isOpen || mekan.raidClosed) return const <MekanStockPeek>[];
  return peek;
}

/// Visitor vitrin — only open mekans with priced, in-stock listings.
List<MekanStockEntry> mekanVitrinStock(Mekan mekan, List<MekanStockEntry> stock) {
  if (!mekan.isOpen || mekan.raidClosed) return const <MekanStockEntry>[];
  return stock.where((MekanStockEntry s) => s.isListedForSale).toList(growable: false);
}

class MekanInventoryEntry {
  const MekanInventoryEntry({
    required this.itemId,
    required this.name,
    required this.icon,
    required this.rarity,
    required this.subType,
    required this.isHanOnly,
    required this.quantity,
    required this.eligible,
  });

  final String itemId;
  final String name;
  final String icon;
  final String rarity;
  final String subType;
  final bool isHanOnly;
  final int quantity;
  final bool eligible;

  MekanInventoryEntry copyAdd(int extra) => MekanInventoryEntry(
        itemId: itemId,
        name: name,
        icon: icon,
        rarity: rarity,
        subType: subType,
        isHanOnly: isHanOnly,
        quantity: quantity + extra,
        eligible: eligible,
      );

  factory MekanInventoryEntry.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> it =
        json['items'] is Map ? Map<String, dynamic>.from(json['items'] as Map) : <String, dynamic>{};
    final bool han = it['is_han_only'] == true;
    final String? type = it['type']?.toString();
    final String nameTr = (it['name_tr'] ?? '').toString();
    return MekanInventoryEntry(
      itemId: (json['item_id'] ?? '').toString(),
      name: nameTr.isNotEmpty ? nameTr : (it['name']?.toString() ?? (json['item_id'] ?? '').toString()),
      icon: it['icon']?.toString() ?? '',
      rarity: (it['rarity'] ?? 'common').toString(),
      subType: (it['sub_type'] ?? '').toString(),
      isHanOnly: han,
      quantity: _toInt(json['quantity']),
      eligible: mekanItemEligible(isHanOnly: han, type: type),
    );
  }
}

class MekanLeaderboardRow {
  const MekanLeaderboardRow({
    required this.id,
    required this.name,
    required this.typeKey,
    required this.level,
    required this.fame,
    required this.isOpen,
    required this.ownerName,
    required this.rank,
  });

  final String id;
  final String name;
  final String typeKey;
  final int level;
  final int fame;
  final bool isOpen;
  final String ownerName;
  final int rank;

  factory MekanLeaderboardRow.fromJson(Map<String, dynamic> json) => MekanLeaderboardRow(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        typeKey: (json['mekan_type'] ?? '').toString(),
        level: _toInt(json['level'], fallback: 1),
        fame: _toInt(json['fame']),
        isOpen: json['is_open'] == true,
        ownerName: (json['owner_name'] ?? '???').toString(),
        rank: _toInt(json['rank']),
      );
}

class ArenaWeeklyRewardStatus {
  const ArenaWeeklyRewardStatus({
    required this.claimOpen,
    required this.rewardGold,
    required this.rank,
    required this.alreadyClaimed,
    this.weekStart,
  });

  final bool claimOpen;
  final int rewardGold;
  final int rank;
  final bool alreadyClaimed;
  final String? weekStart;

  bool get canClaim => claimOpen && rewardGold > 0 && !alreadyClaimed;

  factory ArenaWeeklyRewardStatus.fromJson(Map<String, dynamic> json) =>
      ArenaWeeklyRewardStatus(
        claimOpen: json['claim_open'] == true,
        rewardGold: _toInt(json['reward_gold']),
        rank: _toInt(json['rank']),
        alreadyClaimed: json['already_claimed'] == true,
        weekStart: json['week_start']?.toString(),
      );
}

class ArenaRankRow {
  const ArenaRankRow({
    required this.authId,
    required this.username,
    required this.level,
    required this.pvpRating,
    required this.wins,
    required this.losses,
    required this.rank,
    required this.weeklyReward,
  });

  final String authId;
  final String username;
  final int level;
  final int pvpRating;
  final int wins;
  final int losses;
  final int rank;
  final int weeklyReward;

  factory ArenaRankRow.fromJson(Map<String, dynamic> json) => ArenaRankRow(
        authId: (json['auth_id'] ?? '').toString(),
        username: (json['username'] ?? '???').toString(),
        level: _toInt(json['level']),
        pvpRating: _toInt(json['pvp_rating'], fallback: 1000),
        wins: _toInt(json['pvp_wins']),
        losses: _toInt(json['pvp_losses']),
        rank: _toInt(json['rank']),
        weeklyReward: _toInt(json['weekly_reward']),
      );
}

class ArenaOpponent {
  const ArenaOpponent({
    required this.offerId,
    required this.authId,
    required this.username,
    required this.level,
    required this.pvpRating,
    required this.power,
  });

  final String offerId;
  final String authId;
  final String username;
  final int level;
  final int pvpRating;
  final int power;

  factory ArenaOpponent.fromJson(Map<String, dynamic> json) => ArenaOpponent(
        offerId: (json['offer_id'] ?? '').toString(),
        authId: (json['auth_id'] ?? '').toString(),
        username: (json['username'] ?? '?').toString(),
        level: _toInt(json['level']),
        pvpRating: _toInt(json['pvp_rating'], fallback: 1000),
        power: _toInt(json['power']) > 0
            ? _toInt(json['power'])
            : _toInt(json['attack']) + _toInt(json['defense']),
      );
}
