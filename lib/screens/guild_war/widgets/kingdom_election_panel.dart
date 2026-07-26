import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/debug/staff_hub_debug_log.dart';
import '../../../core/services/supabase_service.dart';
import '../../../providers/kingdom_market_blessing_provider.dart';
import '../../../providers/live_ticker_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import 'guild_war_design.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';

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
    return 'Aktif kral indirimi: $amounts — ${activatorLabel} uyguladı';
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
  const KingdomElectionPanel({super.key});

  @override
  ConsumerState<KingdomElectionPanel> createState() => _KingdomElectionPanelState();
}

class _KingdomElectionPanelState extends ConsumerState<KingdomElectionPanel> {
  KingdomElectionData? _data;
  bool _loading = true;
  bool _activatingBlessing = false;
  bool _sendingGift = false;
  final TextEditingController _giftUsername = TextEditingController();
  final TextEditingController _giftAmount = TextEditingController(text: '10000');
  String _giftCurrency = 'gold';

  @override
  void dispose() {
    _giftUsername.dispose();
    _giftAmount.dispose();
    super.dispose();
  }

  Future<void> _sendKingGift() async {
    if (_sendingGift) return;
    final String username = _giftUsername.text.trim();
    final int amount = int.tryParse(_giftAmount.text.trim()) ?? 0;
    if (username.length < 2) {
      AppMessenger.showError(context, 'Oyuncu adı gerekli.');
      return;
    }
    if (amount < 1 || amount > 1000000) {
      AppMessenger.showError(context, 'Hediye 1–1.000.000 arası olmalı.');
      return;
    }
    setState(() => _sendingGift = true);
    try {
      final dynamic result = await SupabaseService.client.rpc(
        'king_gift_to_player',
        params: <String, dynamic>{
          'p_recipient_username': username,
          'p_currency': _giftCurrency,
          'p_amount': amount,
        },
      );
      if (!mounted) return;
      if (result is Map && result['success'] == false) {
        AppMessenger.showError(context, (result['error'] ?? 'Hediye verilemedi.') as String);
      } else {
        AppMessenger.showSuccess(context, '@$username → +$amount ${_giftCurrency == 'gems' ? '💎' : '🪙'}');
        _giftUsername.clear();
        await _load();
        await ref.read(liveTickerProvider.notifier).load(silent: true);
      }
    } catch (e) {
      if (mounted) AppMessenger.showError(context, 'Hata: $e');
    } finally {
      if (mounted) setState(() => _sendingGift = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dynamic result = await SupabaseService.client.rpc('get_current_election');
      if (mounted) {
        final Map<String, dynamic>? map = _decodeElectionMap(result);
        final KingdomElectionData? parsed =
            map == null ? null : KingdomElectionData.fromJson(map);
        setState(() {
          _data = parsed;
          _loading = false;
        });
        // #region agent log
        StaffHubDebugLog.log(
          'A',
          'kingdom_election_panel.dart:_load',
          'election_state',
          data: <String, Object?>{
            'status': parsed?.status,
            'active': parsed?.isActive,
            'month': parsed?.month,
            'candidateCount': parsed?.candidates.length,
            'reigningKing': parsed?.reigningKing?.guildName,
            'isKing': parsed?.kingPowers.isKing,
          },
          runId: 'kingdom-election',
        );
        // #endregion
      }
    } catch (e) {
      // #region agent log
      StaffHubDebugLog.log(
        'A',
        'kingdom_election_panel.dart:_load',
        'election_load_error',
        data: <String, Object?>{'error': e.toString()},
        runId: 'kingdom-election',
      );
      // #endregion
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _activateBlessing({required double goldPct, required double gemPct}) async {
    if (_activatingBlessing) return;
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
      if (result is Map && (result['success'] == false || result['error'] != null)) {
        AppMessenger.showError(context, (result['error'] ?? 'İndirim başlatılamadı.') as String);
      } else {
        final int goldPctApplied = goldPct.round();
        final int gemPctApplied = gemPct.round();
        AppMessenger.showSuccess(
          context,
          '👑 Kral indirimi aktif: altın %$goldPctApplied, elmas %$gemPctApplied · 30 dk tüm sunucuya uygulandı.',
        );
        await _load();
        await ref.read(kingdomMarketBlessingProvider.notifier).load();
        await ref.read(liveTickerProvider.notifier).load(silent: true);
      }
    } catch (e) {
      if (mounted) AppMessenger.showError(context, 'Hata: $e');
    } finally {
      if (mounted) setState(() => _activatingBlessing = false);
    }
  }

  Future<void> _vote(String electionId, String candidateId) async {
    try {
      final result = await SupabaseService.client.rpc('vote_in_election', params: {
        'p_election_id': electionId,
        'p_candidate_guild_id': candidateId,
      });

      if (!mounted) return;

      if (result is Map && (result['error'] != null || result['success'] == false)) {
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
        AppMessenger.showError(context, 'Hata: $e');
      }
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

    final data = _data;
    if (data == null || !data.hasData) {
      return const WarEmptyTab(
        icon: '👑',
        message: 'Krallık seçimi şu an aktif değil. Sezon sonunda aday loncalar burada listelenecek.',
      );
    }

    final totalVotes = data.candidates.fold<int>(0, (sum, c) => sum + c.voteCount);
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
        if (data.isActive && data.reigningKing != null && data.reigningKing!.hasData)
          _IncumbentKingBanner(reign: data.reigningKing!),
        if (data.kingPowers.isKing) ...<Widget>[
          _KingPowersPanel(
            powers: data.kingPowers,
            activating: _activatingBlessing,
            onActivate: (double goldPct, double gemPct) =>
                _activateBlessing(goldPct: goldPct, gemPct: gemPct),
          ),
          _KingTreasuryPanel(
            powers: data.kingPowers,
            sending: _sendingGift,
            usernameController: _giftUsername,
            amountController: _giftAmount,
            currency: _giftCurrency,
            onCurrencyChanged: (String v) => setState(() => _giftCurrency = v),
            onSend: _sendKingGift,
          ),
        ],
        if (data.isCompleted && winner != null)
          _KingBanner(winner: winner, month: data.month)
        else if (data.isActive) ...<Widget>[
          WarSectionHeader(
            title: 'Krallık Seçimi',
            subtitle: data.month ?? '',
            accent: WarPalette.solar,
            trailing: data.endAt != null
                ? WarStatusPill(label: _countdown(data.endAt), color: WarPalette.gold, pulse: true)
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
        if (_voterStatusMessage(data) != null)
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
                      color: data.voter.canVote ? WarPalette.neon : WarPalette.titanium,
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
                        isKing ? Icons.emoji_events_rounded : Icons.shield_outlined,
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
                          child: WarStatusPill(label: '#1', color: WarPalette.neon),
                        ),
                      if (isKing)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: WarStatusPill(label: 'Kral', color: WarPalette.gold),
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
                      label: 'Oy Ver',
                      onPressed: () => _vote(data.id!, candidate.id),
                      expand: false,
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
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
                  : 'Günde 1 kez, 30 dk mağaza · pazar · eşya satışlarına indirim.',
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
                label: widget.activating ? 'Aktifleştiriliyor…' : 'İndirimi Başlat (30 dk)',
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

class _KingTreasuryPanel extends StatelessWidget {
  const _KingTreasuryPanel({
    required this.powers,
    required this.sending,
    required this.usernameController,
    required this.amountController,
    required this.currency,
    required this.onCurrencyChanged,
    required this.onSend,
  });

  final KingdomKingPowers powers;
  final bool sending;
  final TextEditingController usernameController;
  final TextEditingController amountController;
  final String currency;
  final ValueChanged<String> onCurrencyChanged;
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

  @override
  Widget build(BuildContext context) {
    final bool gems = currency == 'gems';
    final num treasuryBalance = gems ? powers.treasuryGems : powers.treasuryGold;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: WarNeonCard(
        accent: WarPalette.neon,
        glow: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Krallık Kasası — Hediye',
              style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pazar ve mağaza vergileri kasada birikir. Oyuncu başına haftada 1 hediye (max 1.000.000). '
              'Hediye live ticker ve genel sohbette duyurulur.',
              style: TextStyle(color: WarPalette.titanium, fontSize: 11, height: 1.35),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _TreasuryBalanceChip(
                    icon: '🪙',
                    label: 'Altın kasa',
                    value: _fmt(powers.treasuryGold),
                    selected: !gems,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TreasuryBalanceChip(
                    icon: '💎',
                    label: 'Elmas kasa',
                    value: _fmt(powers.treasuryGems),
                    selected: gems,
                  ),
                ),
              ],
            ),
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
                labelText: 'Miktar (max ${_fmt(powers.maxGiftAmount)})',
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: ChoiceChip(
                    label: const Text('🪙 Altın'),
                    selected: !gems,
                    onSelected: (_) => onCurrencyChanged('gold'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('💎 Elmas'),
                    selected: gems,
                    onSelected: (_) => onCurrencyChanged('gems'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Seçili kasa: ${_fmt(treasuryBalance)} ${gems ? '💎' : '🪙'}',
              style: const TextStyle(color: WarPalette.titanium, fontSize: 10, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            WarGoldButton(
              label: sending ? 'Gönderiliyor…' : 'Hediye Gönder',
              onPressed: sending ? null : onSend,
              expand: true,
            ),
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
  });

  final String icon;
  final String label;
  final String value;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: selected ? WarPalette.gold.withValues(alpha: 0.12) : Colors.black26,
        border: Border.all(
          color: selected ? WarPalette.gold.withValues(alpha: 0.5) : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(color: WarPalette.titanium, fontSize: 9, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('$icon $value', style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w900)),
        ],
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
                  style: const TextStyle(color: WarPalette.titanium, fontSize: 11, fontWeight: FontWeight.w700),
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
                  style: const TextStyle(color: WarPalette.titanium, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${winner.voteCount} oy ile seçildi',
                  style: const TextStyle(color: WarPalette.titanium, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
