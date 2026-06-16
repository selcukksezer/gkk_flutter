import 'package:flutter/material.dart';

import '../../../components/common/gkk_card.dart';
import '../../../core/services/supabase_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';

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
  });

  final String status;
  final bool votingOpen;
  final String? id;
  final String? month;
  final DateTime? startAt;
  final DateTime? endAt;
  final List<KingdomCandidate> candidates;
  final KingdomWinner? winner;

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

      if (result is Map && result['error'] != null) {
        AppMessenger.showError(context, result['error'] as String);
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink();
    }

    final data = _data;
    if (data == null || !data.hasData) {
      return const SizedBox.shrink();
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
      children: [
        if (data.isCompleted && winner != null)
          _KingBanner(winner: winner, month: data.month)
        else if (data.isActive) ...[
          Text(
            '👑 Krallık Seçimi (${data.month ?? ''})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.gold,
            ),
          ),
          if (data.endAt != null) ...[
            const SizedBox(height: 6),
            Text(
              '⏳ ${_countdown(data.endAt)}',
              style: const TextStyle(color: AppColors.goldLight, fontSize: 12),
            ),
          ],
        ],
        const SizedBox(height: AppSpacing.base),
        ...data.candidates.map((candidate) {
          final ratio = totalVotes > 0 ? candidate.voteCount / totalVotes : 0.0;
          final isKing = winner != null && candidate.id == winner.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: GkkCard(
              accentColor: isKing ? AppColors.gold : null,
              borderGlow: isKing,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isKing ? Icons.emoji_events : Icons.shield_outlined,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          candidate.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isKing)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                          ),
                          child: const Text(
                            'KRAL',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      Text(
                        '${candidate.voteCount} Oy',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.gold,
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
                      backgroundColor: AppColors.borderFaint,
                      color: isKing ? AppColors.gold : AppColors.accentBlue,
                    ),
                  ),
                  if (data.votingOpen && data.id != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => _vote(data.id!, candidate.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Oy Ver'),
                      ),
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
    return GkkCard(
      borderGlow: true,
      accentColor: AppColors.gold,
      gradient: LinearGradient(
        colors: [
          AppColors.gold.withValues(alpha: 0.12),
          AppColors.bgCard,
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Row(
        children: [
          const Text('👑', style: TextStyle(fontSize: 36)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  month != null ? 'Krallık — $month' : 'Krallık',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
                Text(
                  winner.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.goldLight,
                  ),
                ),
                Text(
                  '${winner.voteCount} oy ile seçildi',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
