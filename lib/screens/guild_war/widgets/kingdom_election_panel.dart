import 'package:flutter/material.dart';

import '../../../core/services/supabase_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import 'guild_war_design.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';

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
    if (data is! List) return const [];
    return data
        .map((e) => KingdomCandidate.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

class KingdomCandidate {
  const KingdomCandidate({
    required this.id,
    required this.name,
    required this.voteCount,
  });

  final String id;
  final String name;
  final int voteCount;

  factory KingdomCandidate.fromJson(Map<String, dynamic> json) {
    return KingdomCandidate(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class KingdomWinner {
  const KingdomWinner({
    required this.id,
    required this.name,
    required this.voteCount,
  });

  final String id;
  final String name;
  final int voteCount;

  factory KingdomWinner.fromJson(Map<String, dynamic> json) {
    return KingdomWinner(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class KingdomElectionPanel extends StatefulWidget {
  const KingdomElectionPanel({super.key});

  @override
  State<KingdomElectionPanel> createState() => _KingdomElectionPanelState();
}

class _KingdomElectionPanelState extends State<KingdomElectionPanel> {
  KingdomElectionData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await SupabaseService.client.rpc('get_current_election');
      if (mounted) {
        setState(() {
          _data = result is Map
              ? KingdomElectionData.fromJson(Map<String, dynamic>.from(result))
              : null;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
    if (v.alreadyVoted) return 'Bu seçimde loncan adına oy kullandın.';
    if (!v.isLeader) return 'Oy kullanmak için lonca lideri olmalısın.';
    if (v.guildRank == null) return 'Loncan bu sezon sıralamada değil — oy hakkın yok.';
    if (v.guildRank! > v.maxRank) {
      return 'Oy hakkı yalnızca ilk ${v.maxRank} loncanın liderlerine ait. Loncan #$v.guildRank sırada.';
    }
    if (v.canVote) return 'Loncan #$v.guildRank sırada — oy kullanabilirsin.';
    return null;
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
                name: data.candidates.first.name,
                voteCount: data.candidates.first.voteCount,
              )
            : null);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
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
                        child: Text(
                          candidate.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
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
                  winner.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: WarPalette.gold,
                  ),
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
