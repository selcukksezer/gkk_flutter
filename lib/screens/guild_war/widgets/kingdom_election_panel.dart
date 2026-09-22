import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/common/app_messenger.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../core/services/supabase_service.dart';
import '../../../providers/kingdom_market_blessing_provider.dart';
import '../../../providers/live_ticker_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import 'guild_war_design.dart';

class KingdomReigningKing {
  const KingdomReigningKing({
    required this.guildName,
    this.leaderUsername,
    this.month,
  });

  final String guildName;
  final String? leaderUsername;
  final String? month;

  factory KingdomReigningKing.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const KingdomReigningKing(guildName: '');
    }
    return KingdomReigningKing(
      guildName: (json['guild_name'] ?? '').toString(),
      leaderUsername: json['leader_username']?.toString(),
      month: json['month']?.toString(),
    );
  }

  bool get hasData => guildName.isNotEmpty || (leaderUsername?.isNotEmpty ?? false);

  String get displayKingName {
    final String? user = leaderUsername?.trim();
    if (user != null && user.isNotEmpty) return user;
    return guildName;
  }
}

class KingdomKingPowers {
  const KingdomKingPowers({
    required this.isKing,
    required this.blessingActive,
    required this.blessingUsedToday,
    required this.maxGoldPct,
    required this.maxGemPct,
    required this.activeGoldPct,
    required this.activeGemPct,
    this.blessingExpiresAt,
    this.blessingStartedAt,
    this.activatedByUsername,
    this.activatedByGuildName,
    this.treasuryGold = 0,
    this.treasuryGems = 0,
    this.maxGiftAmount = 1000000,
    this.durationMinutes = 30,
  });

  final bool isKing;
  final bool blessingActive;
  final bool blessingUsedToday;
  final int maxGoldPct;
  final int maxGemPct;
  final int activeGoldPct;
  final int activeGemPct;
  final DateTime? blessingExpiresAt;
  final DateTime? blessingStartedAt;
  final String? activatedByUsername;
  final String? activatedByGuildName;
  final num treasuryGold;
  final num treasuryGems;
  final int maxGiftAmount;
  final int durationMinutes;

  factory KingdomKingPowers.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const KingdomKingPowers(
        isKing: false,
        blessingActive: false,
        blessingUsedToday: false,
        maxGoldPct: 20,
        maxGemPct: 10,
        activeGoldPct: 0,
        activeGemPct: 0,
      );
    }
    return KingdomKingPowers(
      isKing: json['is_king'] == true,
      blessingActive: json['blessing_active'] == true,
      blessingUsedToday: json['blessing_used_today'] == true,
      maxGoldPct: (json['max_gold_pct'] as num?)?.toInt() ?? 20,
      maxGemPct: (json['max_gem_pct'] as num?)?.toInt() ?? 10,
      activeGoldPct: (json['active_gold_pct'] as num?)?.toInt() ?? 0,
      activeGemPct: (json['active_gem_pct'] as num?)?.toInt() ?? 0,
      blessingExpiresAt: KingdomElectionData._parseDate(json['blessing_expires_at']),
      blessingStartedAt: KingdomElectionData._parseDate(json['blessing_started_at']),
      activatedByUsername: json['blessing_activated_by_username']?.toString(),
      activatedByGuildName: json['blessing_activated_by_guild_name']?.toString(),
      treasuryGold: json['treasury_gold'] as num? ?? 0,
      treasuryGems: json['treasury_gems'] as num? ?? 0,
      maxGiftAmount: (json['max_gift_amount'] as num?)?.toInt() ?? 1000000,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 30,
    );
  }

  KingdomKingPowers copyWithTreasury({
    num? treasuryGold,
    num? treasuryGems,
    int? maxGiftAmount,
  }) {
    return KingdomKingPowers(
      isKing: isKing,
      blessingActive: blessingActive,
      blessingUsedToday: blessingUsedToday,
      maxGoldPct: maxGoldPct,
      maxGemPct: maxGemPct,
      activeGoldPct: activeGoldPct,
      activeGemPct: activeGemPct,
      blessingExpiresAt: blessingExpiresAt,
      blessingStartedAt: blessingStartedAt,
      activatedByUsername: activatedByUsername,
      activatedByGuildName: activatedByGuildName,
      treasuryGold: treasuryGold ?? this.treasuryGold,
      treasuryGems: treasuryGems ?? this.treasuryGems,
      maxGiftAmount: maxGiftAmount ?? this.maxGiftAmount,
      durationMinutes: durationMinutes,
    );
  }

  String get activatorLabel {
    final String? guild = activatedByGuildName?.trim();
    final String? user = activatedByUsername?.trim();
    if (guild != null && guild.isNotEmpty && user != null && user.isNotEmpty) {
      return '$guild · $user';
    }
    if (guild != null && guild.isNotEmpty) return guild;
    if (user != null && user.isNotEmpty) return user;
    return 'Krallık lideri';
  }

  String activeBlessingDescription() {
    final List<String> parts = <String>[];
    if (activeGoldPct > 0) parts.add('altın %$activeGoldPct');
    if (activeGemPct > 0) parts.add('elmas %$activeGemPct');
    final String amounts = parts.isEmpty ? 'indirim' : parts.join(', ');
    return 'Aktif kral indirimi: $amounts — $activatorLabel uyguladı';
  }

  bool get canGift => isKing;
}

class KingdomElectionVoter {
  const KingdomElectionVoter({
    required this.isLeader,
    required this.canVote,
    required this.alreadyVoted,
    required this.maxRank,
    this.guildRank,
  });

  final bool isLeader;
  final bool canVote;
  final bool alreadyVoted;
  final int maxRank;
  final int? guildRank;

  factory KingdomElectionVoter.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const KingdomElectionVoter(
        isLeader: false,
        canVote: false,
        alreadyVoted: false,
        maxRank: 20,
      );
    }
    return KingdomElectionVoter(
      isLeader: json['is_leader'] == true,
      canVote: json['can_vote'] == true,
      alreadyVoted: json['already_voted'] == true,
      maxRank: (json['max_rank'] as num?)?.toInt() ?? 20,
      guildRank: (json['guild_rank'] as num?)?.toInt(),
    );
  }
}

class KingdomElectionData {
  const KingdomElectionData({
    required this.status,
    required this.votingOpen,
    this.id,
    this.month,
    this.startAt,
    this.endAt,
    this.candidates = const [],
    this.winner,
    this.reigningKing,
    this.kingPowers = const KingdomKingPowers(
      isKing: false,
      blessingActive: false,
      blessingUsedToday: false,
      maxGoldPct: 20,
      maxGemPct: 10,
      activeGoldPct: 0,
      activeGemPct: 0,
    ),
    this.voter = const KingdomElectionVoter(
      isLeader: false,
      canVote: false,
      alreadyVoted: false,
      maxRank: 20,
    ),
  });

  final String status;
  final bool votingOpen;
  final String? id;
  final String? month;
  final DateTime? startAt;
  final DateTime? endAt;
  final List<KingdomCandidate> candidates;
  final KingdomWinner? winner;
  final KingdomReigningKing? reigningKing;
  final KingdomKingPowers kingPowers;
  final KingdomElectionVoter voter;

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get hasData => status != 'none';

  factory KingdomElectionData.fromJson(Map<String, dynamic> json) {
    final winnerJson = json['winner'];
    final rawStatus = json['status']?.toString();
    final isActiveFlag = json['active'] == true;
    final status = rawStatus != null && rawStatus.isNotEmpty
        ? rawStatus
        : (isActiveFlag ? 'active' : 'none');

    return KingdomElectionData(
      status: status,
      votingOpen: json['voting_open'] == true,
      id: json['id']?.toString(),
      month: json['month']?.toString(),
      startAt: _parseDate(json['start_at']),
      endAt: _parseDate(json['end_at']),
      candidates: _parseCandidates(json['candidates']),
      winner: winnerJson is Map
          ? KingdomWinner.fromJson(Map<String, dynamic>.from(winnerJson))
          : null,
      reigningKing: json['reigning_king'] is Map
          ? KingdomReigningKing.fromJson(Map<String, dynamic>.from(json['reigning_king'] as Map))
          : null,
      kingPowers: KingdomKingPowers.fromJson(
        json['king_powers'] is Map ? Map<String, dynamic>.from(json['king_powers'] as Map) : null,
      ),
      voter: KingdomElectionVoter.fromJson(
        json['voter'] is Map ? Map<String, dynamic>.from(json['voter'] as Map) : null,
      ),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static List<KingdomCandidate> _parseCandidates(dynamic data) {
    final dynamic decoded = _decodeJsonValue(data);
    if (decoded is! List) return const [];
    return decoded
        .map((e) => KingdomCandidate.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

Map<String, dynamic>? _decodeElectionMap(dynamic result) {
  final dynamic decoded = _decodeJsonValue(result);
  if (decoded is Map) {
    return Map<String, dynamic>.from(decoded);
  }
  return null;
}

dynamic _decodeJsonValue(dynamic data) {
  if (data is String && data.trim().isNotEmpty) {
    return jsonDecode(data);
  }
  return data;
}

class KingdomCandidate {
  const KingdomCandidate({
    required this.id,
    required this.name,
    required this.voteCount,
    this.rank,
    this.guildName,
    this.leaderUsername,
  });

  final String id;
  final String name;
  final int voteCount;
  final int? rank;
  final String? guildName;
  final String? leaderUsername;

  String get displayLeaderName {
    final String? user = leaderUsername?.trim();
    if (user != null && user.isNotEmpty) return user;
    return name;
  }

  String get displayGuildName {
    final String? guild = guildName?.trim();
    if (guild != null && guild.isNotEmpty) return guild;
    return name;
  }

  factory KingdomCandidate.fromJson(Map<String, dynamic> json) {
    return KingdomCandidate(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt(),
      guildName: json['guild_name']?.toString(),
      leaderUsername: json['leader_username']?.toString(),
    );
  }
}

class KingdomTreasuryGift {
  const KingdomTreasuryGift({
    required this.recipientUsername,
    required this.currency,
    required this.amount,
    this.kingUsername,
    this.createdAt,
  });

  final String recipientUsername;
  final String currency;
  final num amount;
  final String? kingUsername;
  final DateTime? createdAt;

  factory KingdomTreasuryGift.fromJson(Map<String, dynamic> json) {
    return KingdomTreasuryGift(
      recipientUsername: (json['recipient_username'] ?? '').toString(),
      currency: (json['currency'] ?? 'gold').toString(),
      amount: json['amount'] as num? ?? 0,
      kingUsername: json['king_username']?.toString(),
      createdAt: KingdomElectionData._parseDate(json['created_at']),
    );
  }
}

class KingdomTreasuryLedgerEntry {
  const KingdomTreasuryLedgerEntry({
    required this.kind,
    required this.currency,
    required this.amount,
    this.note,
    this.createdAt,
  });

  final String kind;
  final String currency;
  final num amount;
  final String? note;
  final DateTime? createdAt;

  factory KingdomTreasuryLedgerEntry.fromJson(Map<String, dynamic> json) {
    return KingdomTreasuryLedgerEntry(
      kind: (json['kind'] ?? '').toString(),
      currency: (json['currency'] ?? 'gold').toString(),
      amount: json['amount'] as num? ?? 0,
      note: json['note']?.toString(),
      createdAt: KingdomElectionData._parseDate(json['created_at']),
    );
  }

  String get kindLabel {
    switch (kind) {
      case 'shop_tax':
        return 'Mağaza vergisi';
      case 'market_tax':
        return 'Pazar vergisi';
      case 'king_gift':
        return 'Kral hediyesi';
      default:
        return kind.isEmpty ? 'İşlem' : kind;
    }
  }
}

class KingdomTreasuryStatus {
  const KingdomTreasuryStatus({
    required this.goldBalance,
    required this.gemsBalance,
    required this.isKing,
    this.maxGiftAmount = 1000000,
    this.recentGifts = const <KingdomTreasuryGift>[],
    this.recentLedger = const <KingdomTreasuryLedgerEntry>[],
  });

  final num goldBalance;
  final num gemsBalance;
  final bool isKing;
  final int maxGiftAmount;
  final List<KingdomTreasuryGift> recentGifts;
  final List<KingdomTreasuryLedgerEntry> recentLedger;

  factory KingdomTreasuryStatus.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(
      dynamic raw,
      T Function(Map<String, dynamic>) map,
    ) {
      final dynamic decoded = _decodeJsonValue(raw);
      if (decoded is! List) return <T>[];
      return decoded
          .whereType<Map>()
          .map((Map e) => map(Map<String, dynamic>.from(e)))
          .toList();
    }

    return KingdomTreasuryStatus(
      goldBalance: json['gold_balance'] as num? ?? 0,
      gemsBalance: json['gems_balance'] as num? ?? 0,
      isKing: json['is_king'] == true,
      maxGiftAmount: (json['max_gift_amount'] as num?)?.toInt() ?? 1000000,
      recentGifts: parseList(json['recent_gifts'], KingdomTreasuryGift.fromJson),
      recentLedger:
          parseList(json['recent_ledger'], KingdomTreasuryLedgerEntry.fromJson),
    );
  }
}

class KingdomWinner {
  const KingdomWinner({
    required this.id,
    required this.name,
    required this.voteCount,
    this.guildName,
    this.leaderUsername,
  });

  final String id;
  final String name;
  final int voteCount;
  final String? guildName;
  final String? leaderUsername;

  String get displayLeaderName {
    final String? user = leaderUsername?.trim();
    if (user != null && user.isNotEmpty) return user;
    return name;
  }

  String get displayGuildName {
    final String? guild = guildName?.trim();
    if (guild != null && guild.isNotEmpty) return guild;
    return name;
  }

  factory KingdomWinner.fromJson(Map<String, dynamic> json) {
    return KingdomWinner(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
      guildName: json['guild_name']?.toString(),
      leaderUsername: json['leader_username']?.toString(),
    );
  }
}

class KingdomElectionPanel extends ConsumerStatefulWidget {
  const KingdomElectionPanel({super.key, this.refreshToken = 0});

  /// Parent artırınca panel yeniden yüklenir (pull-to-refresh köprüsü).
  final int refreshToken;

  @override
  ConsumerState<KingdomElectionPanel> createState() => _KingdomElectionPanelState();
}

enum _KingdomSubTab { election, desk }

class _KingdomElectionPanelState extends ConsumerState<KingdomElectionPanel> {
  KingdomElectionData? _data;
  KingdomTreasuryStatus? _treasury;
  bool _loading = true;
  String? _error;
  bool _activatingBlessing = false;
  bool _sendingGift = false;
  bool _voting = false;
  _KingdomSubTab _subTab = _KingdomSubTab.election;
  final TextEditingController _giftUsername = TextEditingController();
  final TextEditingController _giftAmount = TextEditingController(text: '10000');
  final TextEditingController _giftNote = TextEditingController();

  @override
  void dispose() {
    _giftUsername.dispose();
    _giftAmount.dispose();
    _giftNote.dispose();
    super.dispose();
  }

  String _fmtNum(num value) {
    final String raw = value.round().toString();
    final StringBuffer buf = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buf.write('.');
      buf.write(raw[i]);
    }
    return buf.toString();
  }

  Future<void> _sendKingGift() async {
    if (_sendingGift) return;
    final String username = _giftUsername.text.trim();
    final int amount = int.tryParse(_giftAmount.text.trim()) ?? 0;
    final String note = _giftNote.text.trim();
    final KingdomKingPowers powers = _data?.kingPowers ??
        const KingdomKingPowers(
          isKing: false,
          blessingActive: false,
          blessingUsedToday: false,
          maxGoldPct: 20,
          maxGemPct: 10,
          activeGoldPct: 0,
          activeGemPct: 0,
        );
    final num balance = powers.treasuryGold;

    if (username.length < 2) {
      AppMessenger.showError(context, 'Oyuncu adı gerekli.');
      return;
    }
    if (amount < 1 || amount > powers.maxGiftAmount) {
      AppMessenger.showError(
        context,
        'Hediye 1–${_fmtNum(powers.maxGiftAmount)} arası olmalı.',
      );
      return;
    }
    if (amount > balance) {
      AppMessenger.showError(
        context,
        'Kasada yeterli altın yok (${_fmtNum(balance)}).',
      );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: WarPalette.obsidian,
          title: const Text('Hediye onayla', style: TextStyle(color: WarPalette.gold)),
          content: Text(
            '@$username oyuncusuna ${_fmtNum(amount)} altın göndereceksin.\n'
            'Kalan kasa: ${_fmtNum(balance - amount)} altın.\n'
            'Oyuncu başına haftada 1 hediye. Elmas hediye yok.',
            style: const TextStyle(color: WarPalette.titanium, fontSize: 13, height: 1.4),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: WarPalette.gold),
              child: const Text('Gönder', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _sendingGift = true);
    try {
      final Map<String, dynamic> params = <String, dynamic>{
        'p_recipient_username': username,
        'p_currency': 'gold',
        'p_amount': amount,
      };
      if (note.isNotEmpty) params['p_note'] = note;
      final dynamic result = await SupabaseService.client.rpc(
        'king_gift_to_player',
        params: params,
      );
      if (!mounted) return;
      if (result is Map && result['success'] == false) {
        AppMessenger.showError(
          context,
          (result['error'] ?? 'Hediye verilemedi.') as String,
        );
      } else {
        AppMessenger.showSuccess(
          context,
          '@$username → +$amount 🪙',
        );
        _giftUsername.clear();
        _giftNote.clear();
        await _load();
        await ref.read(liveTickerProvider.notifier).load(silent: true);
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showError(context, userFacingErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _sendingGift = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(KingdomElectionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _load();
    }
  }

  Future<void> _loadTreasury() async {
    try {
      final dynamic raw =
          await SupabaseService.client.rpc('get_kingdom_treasury_status');
      if (!mounted) return;
      final Map<String, dynamic>? map = _decodeElectionMap(raw);
      if (map == null) return;
      final KingdomTreasuryStatus status = KingdomTreasuryStatus.fromJson(map);
      setState(() {
        _treasury = status;
        final KingdomElectionData? data = _data;
        if (data != null) {
          _data = KingdomElectionData(
            status: data.status,
            votingOpen: data.votingOpen,
            id: data.id,
            month: data.month,
            startAt: data.startAt,
            endAt: data.endAt,
            candidates: data.candidates,
            winner: data.winner,
            reigningKing: data.reigningKing,
            kingPowers: data.kingPowers.copyWithTreasury(
              treasuryGold: status.goldBalance,
              treasuryGems: status.gemsBalance,
              maxGiftAmount: status.maxGiftAmount,
            ),
            voter: data.voter,
          );
        }
      });
    } catch (_) {
      // Hazine geçmişi opsiyonel — ana paneli bozma.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dynamic result =
          await SupabaseService.client.rpc('get_current_election');
      if (!mounted) return;
      final Map<String, dynamic>? map = _decodeElectionMap(result);
      final KingdomElectionData? parsed =
          map == null ? null : KingdomElectionData.fromJson(map);
      setState(() {
        _data = parsed;
        _loading = false;
        if (parsed != null &&
            !parsed.hasData &&
            _subTab == _KingdomSubTab.election) {
          _subTab = _KingdomSubTab.desk;
        }
      });
      await _loadTreasury();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Seçim bilgisi yüklenemedi.';
        });
      }
    }
  }

  Future<void> _activateBlessing({
    required double goldPct,
    required double gemPct,
  }) async {
    if (_activatingBlessing) return;
    final int duration = _data?.kingPowers.durationMinutes ?? 30;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: WarPalette.obsidian,
          title: const Text(
            'Kral indirimi',
            style: TextStyle(color: WarPalette.gold),
          ),
          content: Text(
            'Altın %${goldPct.round()}, elmas %${gemPct.round()} indirim '
            '$duration dakika tüm sunucuya uygulanacak.\n'
            'Günde 1 kez kullanılabilir.',
            style: const TextStyle(
              color: WarPalette.titanium,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: WarPalette.gold),
              child: const Text('Başlat', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _activatingBlessing = true);
    try {
      final result = await SupabaseService.client.rpc(
        'king_activate_market_blessing',
        params: <String, dynamic>{
          'p_gold_discount_pct': goldPct.round(),
          'p_gem_discount_pct': gemPct.round(),
        },
      );
      if (!mounted) return;
      if (result is Map &&
          (result['success'] == false || result['error'] != null)) {
        AppMessenger.showError(
          context,
          (result['error'] ?? 'İndirim başlatılamadı.') as String,
        );
      } else {
        final int goldPctApplied = goldPct.round();
        final int gemPctApplied = gemPct.round();
        AppMessenger.showSuccess(
          context,
          '👑 Kral indirimi aktif: altın %$goldPctApplied, elmas %$gemPctApplied · '
          '$duration dk tüm sunucuya uygulandı.',
        );
        await _load();
        await ref.read(kingdomMarketBlessingProvider.notifier).load();
        await ref.read(liveTickerProvider.notifier).load(silent: true);
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showError(context, userFacingErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _activatingBlessing = false);
    }
  }

  Future<void> _vote(String electionId, String candidateId) async {
    if (_voting) return;
    setState(() => _voting = true);
    try {
      final result = await SupabaseService.client.rpc(
        'vote_in_election',
        params: <String, dynamic>{
          'p_election_id': electionId,
          'p_candidate_guild_id': candidateId,
        },
      );

      if (!mounted) return;

      if (result is Map &&
          (result['error'] != null || result['success'] == false)) {
        AppMessenger.showError(
          context,
          (result['error'] ?? 'Oy kullanılamadı.') as String,
        );
      } else {
        AppMessenger.showSuccess(context, '👑 Oyunuz kaydedildi!');
        await _load();
      }
    } catch (e) {
      if (mounted) {
        final String raw = e.toString();
        final String message = raw.contains('foreign key constraint') ||
                raw.contains('23503')
            ? 'Oy kaydedilemedi. Lonca bilgin geçersiz — lonca üyeliğini kontrol et.'
            : userFacingErrorMessage(e, fallback: 'Oy kullanılamadı. Tekrar dene.');
        AppMessenger.showError(context, message);
      }
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  String _countdown(DateTime? endAt) {
    if (endAt == null) return '';
    final diff = endAt.difference(DateTime.now());
    if (diff.isNegative) return 'Süre doldu';
    if (diff.inDays > 0) return '${diff.inDays}g ${diff.inHours % 24}sa kaldı';
    if (diff.inHours > 0) return '${diff.inHours}sa ${diff.inMinutes % 60}dk kaldı';
    return '${diff.inMinutes}dk kaldı';
  }

  String? _voterStatusMessage(KingdomElectionData data) {
    if (!data.votingOpen) return null;
    final KingdomElectionVoter v = data.voter;
    if (v.alreadyVoted) return 'Bu seçimde oy kullandın.';
    if (v.canVote) return 'Aday loncalardan birine oy verebilirsin.';
    return 'Oy kullanmak için giriş yapmalısın.';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: WarPalette.gold)),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: <Widget>[
            const Text('⚠️', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 16, color: WarPalette.gold),
              label: const Text(
                'Tekrar Dene',
                style: TextStyle(color: WarPalette.gold),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: WarPalette.gold.withValues(alpha: 0.4)),
              ),
            ),
          ],
        ),
      );
    }

    final data = _data;
    if (data == null) {
      return WarEmptyTab(
        icon: '👑',
        message: 'Krallık bilgisi yüklenemedi.',
        actionLabel: 'Tekrar Dene',
        onAction: _load,
      );
    }

    final bool showKingDesk = data.kingPowers.isKing;
    final bool showElectionBody = data.hasData;
    final bool showReigning =
        data.reigningKing != null && data.reigningKing!.hasData;

    // Seçim yok ama kral / kasa var → paneli tamamen gizleme.
    if (!showElectionBody && !showKingDesk && !showReigning) {
      return const WarEmptyTab(
        icon: '👑',
        message:
            'Krallık seçimi şu an aktif değil. Her ayın başında 7 günlük oylama açılır; '
            'sezon sıralamasındaki ilk 20 lonca aday olur.',
      );
    }

    final totalVotes =
        data.candidates.fold<int>(0, (sum, c) => sum + c.voteCount);
    final winner = data.winner ??
        (data.isCompleted && data.candidates.isNotEmpty
            ? KingdomWinner(
                id: data.candidates.first.id,
                name: data.candidates.first.displayLeaderName,
                voteCount: data.candidates.first.voteCount,
                guildName: data.candidates.first.displayGuildName,
                leaderUsername: data.candidates.first.leaderUsername,
              )
            : null);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showReigning) _IncumbentKingBanner(reign: data.reigningKing!),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: <Widget>[
              Expanded(
                child: WarFilterChip(
                  label: 'Oylama',
                  selected: _subTab == _KingdomSubTab.election,
                  accent: WarPalette.solar,
                  onTap: () => setState(() => _subTab = _KingdomSubTab.election),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: WarFilterChip(
                  label: 'Kasa & Yetki',
                  selected: _subTab == _KingdomSubTab.desk,
                  accent: WarPalette.gold,
                  onTap: () => setState(() => _subTab = _KingdomSubTab.desk),
                ),
              ),
            ],
          ),
        ),
        if (_subTab == _KingdomSubTab.desk)
          ..._buildDeskSection(data: data, showKingDesk: showKingDesk)
        else
          ..._buildElectionSection(
            data: data,
            showElectionBody: showElectionBody,
            totalVotes: totalVotes,
            winner: winner,
          ),
      ],
    );
  }

  List<Widget> _buildDeskSection({
    required KingdomElectionData data,
    required bool showKingDesk,
  }) {
    return <Widget>[
      if (!showKingDesk && data.kingPowers.blessingActive)
        _PublicBlessingBanner(powers: data.kingPowers),
      if (showKingDesk)
        _KingPowersPanel(
          powers: data.kingPowers,
          activating: _activatingBlessing,
          onActivate: (double goldPct, double gemPct) =>
              _activateBlessing(goldPct: goldPct, gemPct: gemPct),
        )
      else
        const WarDottedPanel(
          child: Text(
            'Kral yetkisi: günde 1 kez mağaza · pazar · gece pazarına indirim açabilir. '
            'Bu kontroller yalnızca görevdeki kralda görünür.',
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: WarPalette.titanium,
            ),
          ),
        ),
      _KingTreasuryPanel(
        powers: data.kingPowers,
        treasury: _treasury,
        canManage: showKingDesk,
        sending: _sendingGift,
        usernameController: _giftUsername,
        amountController: _giftAmount,
        noteController: _giftNote,
        onSend: _sendKingGift,
      ),
    ];
  }

  List<Widget> _buildElectionSection({
    required KingdomElectionData data,
    required bool showElectionBody,
    required int totalVotes,
    required KingdomWinner? winner,
  }) {
    return <Widget>[
      if (!showElectionBody)
        const WarDottedPanel(
          child: Text(
            'Bu ay henüz seçim turu yok. Mevcut kral görevde; ay başında oylama açılır.',
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: WarPalette.titanium,
            ),
          ),
        )
      else if (data.isCompleted && winner != null)
        _KingBanner(winner: winner, month: data.month)
      else if (data.isActive) ...<Widget>[
        WarSectionHeader(
          title: 'Krallık Seçimi',
          subtitle: data.month ?? '',
          accent: WarPalette.solar,
          trailing: data.endAt != null
              ? WarStatusPill(
                  label: _countdown(data.endAt),
                  color: WarPalette.gold,
                  pulse: true,
                )
              : null,
        ),
      ] else
        const WarSectionHeader(
          title: 'Krallık',
          subtitle: 'Aday loncalar',
          accent: WarPalette.solar,
        ),
      if (data.isActive && data.candidates.isEmpty)
        const WarDottedPanel(
          child: Text(
            'Aktif sezon sıralamasında henüz aday lonca yok. Lonca Savaşı sıralamasına giren ilk 20 lonca burada listelenir.',
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: WarPalette.titanium,
            ),
          ),
        ),
      if (showElectionBody && _voterStatusMessage(data) != null)
        WarDottedPanel(
          borderColor: data.voter.canVote
              ? WarPalette.neon.withValues(alpha: 0.35)
              : WarPalette.coral.withValues(alpha: 0.35),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                data.voter.canVote ? '✅' : 'ℹ️',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _voterStatusMessage(data)!,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: data.voter.canVote
                        ? WarPalette.neon
                        : WarPalette.titanium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ...data.candidates.map((KingdomCandidate candidate) {
        final ratio = totalVotes > 0 ? candidate.voteCount / totalVotes : 0.0;
        final isKing = winner != null && candidate.id == winner.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: WarNeonCard(
            accent: isKing ? WarPalette.gold : WarPalette.solar,
            glow: isKing,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      isKing
                          ? Icons.emoji_events_rounded
                          : Icons.shield_outlined,
                      color: WarPalette.gold,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            candidate.rank != null
                                ? '#${candidate.rank} ${candidate.displayLeaderName}'
                                : candidate.displayLeaderName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            candidate.displayGuildName,
                            style: const TextStyle(
                              color: WarPalette.titanium,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (candidate.rank == 1)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: WarStatusPill(
                          label: '#1',
                          color: WarPalette.neon,
                        ),
                      ),
                    if (isKing)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: WarStatusPill(
                          label: 'Kral',
                          color: WarPalette.gold,
                        ),
                      ),
                    Text(
                      '${candidate.voteCount} oy',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: WarPalette.gold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: WarPalette.obsidian,
                    color: isKing ? WarPalette.gold : WarPalette.fuchsia,
                  ),
                ),
                if (data.voter.canVote && data.id != null) ...<Widget>[
                  const SizedBox(height: 10),
                  WarGoldButton(
                    label: _voting ? 'Oy kaydediliyor…' : 'Oy Ver',
                    onPressed: _voting
                        ? null
                        : () => _vote(data.id!, candidate.id),
                    expand: false,
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    ];
  }
}

class _IncumbentKingBanner extends StatelessWidget {
  const _IncumbentKingBanner({required this.reign});

  final KingdomReigningKing reign;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: WarDottedPanel(
        borderColor: WarPalette.gold.withValues(alpha: 0.35),
        child: Row(
          children: <Widget>[
            const Text('👑', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    reign.month != null ? 'Mevcut kral — ${reign.month}' : 'Mevcut kral',
                    style: const TextStyle(color: WarPalette.titanium, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    reign.displayKingName,
                    style: const TextStyle(color: WarPalette.gold, fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                  if (reign.guildName.isNotEmpty)
                    Text(
                      reign.guildName,
                      style: const TextStyle(color: WarPalette.titanium, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KingPowersPanel extends StatefulWidget {
  const _KingPowersPanel({
    required this.powers,
    required this.activating,
    required this.onActivate,
  });

  final KingdomKingPowers powers;
  final bool activating;
  final void Function(double goldPct, double gemPct) onActivate;

  @override
  State<_KingPowersPanel> createState() => _KingPowersPanelState();
}

class _KingPowersPanelState extends State<_KingPowersPanel> {
  late double _goldPct = widget.powers.maxGoldPct.toDouble();
  late double _gemPct = widget.powers.maxGemPct.toDouble();

  String _blessingRemaining(DateTime? endAt) {
    if (endAt == null) return '';
    final Duration diff = endAt.difference(DateTime.now());
    if (diff.isNegative) return 'Süre doldu';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} dk kaldı';
    return '${diff.inSeconds.clamp(0, 59)} sn kaldı';
  }

  @override
  Widget build(BuildContext context) {
    final KingdomKingPowers powers = widget.powers;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: WarNeonCard(
        accent: WarPalette.gold,
        glow: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Kral Yetkisi — İndirim',
              style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              powers.blessingActive
                  ? '${powers.activeBlessingDescription()}${powers.blessingExpiresAt == null ? '' : ' · ${_blessingRemaining(powers.blessingExpiresAt)}'}'
                  : 'Günde 1 kez, ${powers.durationMinutes} dk mağaza · pazar · gece pazarına indirim. '
                      'Üst sınır: altın %${powers.maxGoldPct}, elmas %${powers.maxGemPct}.',
              style: const TextStyle(color: WarPalette.titanium, fontSize: 11, height: 1.35),
            ),
            if (!powers.blessingActive && !powers.blessingUsedToday) ...<Widget>[
              const SizedBox(height: 10),
              Text('Altın indirimi: %${_goldPct.round()}', style: const TextStyle(fontSize: 11, color: WarPalette.gold)),
              Slider(
                value: _goldPct,
                min: 0,
                max: powers.maxGoldPct.toDouble(),
                divisions: powers.maxGoldPct,
                activeColor: WarPalette.gold,
                onChanged: (double v) => setState(() => _goldPct = v),
              ),
              Text('Gem indirimi: %${_gemPct.round()}', style: const TextStyle(fontSize: 11, color: WarPalette.gold)),
              Slider(
                value: _gemPct,
                min: 0,
                max: powers.maxGemPct.toDouble(),
                divisions: powers.maxGemPct,
                activeColor: WarPalette.fuchsia,
                onChanged: (double v) => setState(() => _gemPct = v),
              ),
              WarGoldButton(
                label: widget.activating
                    ? 'Aktifleştiriliyor…'
                    : 'İndirimi Başlat (${powers.durationMinutes} dk)',
                onPressed: widget.activating || (_goldPct <= 0 && _gemPct <= 0)
                    ? null
                    : () => widget.onActivate(_goldPct, _gemPct),
                expand: true,
              ),
            ] else if (powers.blessingUsedToday && !powers.blessingActive)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Bugünkü kral indirimi kullanıldı.', style: TextStyle(color: WarPalette.coral, fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }
}

class _PublicBlessingBanner extends StatelessWidget {
  const _PublicBlessingBanner({required this.powers});

  final KingdomKingPowers powers;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: WarDottedPanel(
        borderColor: WarPalette.gold.withValues(alpha: 0.4),
        child: Text(
          powers.activeBlessingDescription(),
          style: const TextStyle(
            color: WarPalette.gold,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _KingTreasuryPanel extends StatelessWidget {
  const _KingTreasuryPanel({
    required this.powers,
    required this.treasury,
    required this.canManage,
    required this.sending,
    required this.usernameController,
    required this.amountController,
    required this.noteController,
    required this.onSend,
  });

  final KingdomKingPowers powers;
  final KingdomTreasuryStatus? treasury;
  final bool canManage;
  final bool sending;
  final TextEditingController usernameController;
  final TextEditingController amountController;
  final TextEditingController noteController;
  final VoidCallback onSend;

  String _fmt(num value) {
    final String raw = value.round().toString();
    final StringBuffer buf = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buf.write('.');
      buf.write(raw[i]);
    }
    return buf.toString();
  }

  String _relativeTime(DateTime? at) {
    if (at == null) return '';
    final Duration d = DateTime.now().difference(at.toLocal());
    if (d.inDays > 0) return '${d.inDays}g önce';
    if (d.inHours > 0) return '${d.inHours}sa önce';
    if (d.inMinutes > 0) return '${d.inMinutes}dk önce';
    return 'az önce';
  }

  @override
  Widget build(BuildContext context) {
    final num treasuryBalance = powers.treasuryGold;
    final List<KingdomTreasuryGift> gifts =
        (treasury?.recentGifts ?? const <KingdomTreasuryGift>[])
            .where((KingdomTreasuryGift g) => g.currency == 'gold')
            .take(6)
            .toList(growable: false);
    final List<KingdomTreasuryLedgerEntry> goldLedger =
        (treasury?.recentLedger ?? const <KingdomTreasuryLedgerEntry>[])
            .where((KingdomTreasuryLedgerEntry e) => e.currency == 'gold')
            .take(10)
            .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: WarNeonCard(
        accent: WarPalette.neon,
        glow: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Krallık Kasası',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              canManage
                  ? 'Yalnızca altın birikir (pazar %5 · mağaza %3 altın vergisi). '
                      'Elmas hediye yok. Oyuncu başına haftada 1 altın hediye.'
                  : 'Yalnızca altın birikir. Elmas kasaya girmez. '
                      'Son 10 altın girişi/çıkışı herkese açık.',
              style: const TextStyle(
                color: WarPalette.titanium,
                fontSize: 11,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            _TreasuryBalanceChip(
              icon: '🪙',
              label: 'Altın kasa',
              value: _fmt(powers.treasuryGold),
              selected: true,
            ),
            if (canManage) ...<Widget>[
              const SizedBox(height: 10),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Oyuncu adı',
                  hintText: 'kullaniciadi',
                  isDense: true,
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                decoration: InputDecoration(
                  labelText: 'Altın miktarı (max ${_fmt(powers.maxGiftAmount)})',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Not (opsiyonel)',
                  hintText: 'Kısa mesaj',
                  isDense: true,
                ),
                maxLength: 80,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 4),
              Text(
                'Kasa: ${_fmt(treasuryBalance)} 🪙',
                style: TextStyle(
                  color: treasuryBalance <= 0
                      ? WarPalette.coral
                      : WarPalette.titanium,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              WarGoldButton(
                label: sending ? 'Gönderiliyor…' : 'Altın Hediye Gönder',
                onPressed: sending ? null : onSend,
                expand: true,
              ),
              if (gifts.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                const Text(
                  'Son hediyeler',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                ...gifts.map((KingdomTreasuryGift g) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '→ @${g.recipientUsername}  ${_fmt(g.amount)} 🪙',
                            style: const TextStyle(
                              color: WarPalette.titanium,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          _relativeTime(g.createdAt),
                          style: TextStyle(
                            color: WarPalette.titanium.withValues(alpha: 0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
            const SizedBox(height: 12),
            const Text(
              'Son 10 altın hareketi',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            if (goldLedger.isEmpty)
              const Text(
                'Henüz altın hareketi yok.',
                style: TextStyle(
                  color: WarPalette.titanium,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              ...goldLedger.map((KingdomTreasuryLedgerEntry e) {
                final bool out = e.kind == 'king_gift';
                final String sign = out ? '−' : '+';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${e.kindLabel}  $sign${_fmt(e.amount)} 🪙',
                          style: TextStyle(
                            color: out ? WarPalette.coral : WarPalette.neon,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _relativeTime(e.createdAt),
                        style: TextStyle(
                          color: WarPalette.titanium.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _TreasuryBalanceChip extends StatelessWidget {
  const _TreasuryBalanceChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    this.onTap,
  });

  final String icon;
  final String label;
  final String value;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected
                ? WarPalette.gold.withValues(alpha: 0.12)
                : Colors.black26,
            border: Border.all(
              color: selected
                  ? WarPalette.gold.withValues(alpha: 0.5)
                  : Colors.white12,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  color: WarPalette.titanium,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$icon $value',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KingBanner extends StatelessWidget {
  const _KingBanner({required this.winner, this.month});

  final KingdomWinner winner;
  final String? month;

  @override
  Widget build(BuildContext context) {
    return WarHeroBanner(
      accent: WarPalette.solar,
      child: Row(
        children: <Widget>[
          const Text('👑', style: TextStyle(fontSize: 40)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  month != null ? 'Krallık — $month' : 'Krallık',
                  style: const TextStyle(
                    color: WarPalette.titanium,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  winner.displayLeaderName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: WarPalette.gold,
                  ),
                ),
                Text(
                  winner.displayGuildName,
                  style: const TextStyle(
                    color: WarPalette.titanium,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${winner.voteCount} oy ile seçildi',
                  style: const TextStyle(
                    color: WarPalette.titanium,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
