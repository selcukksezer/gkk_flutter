import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/provider_scheduling.dart';
import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/pvp_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../l10n/l10n.dart';
import 'widgets/gladiator_tier_emblem.dart';

class PvpHistoryScreen extends ConsumerStatefulWidget {
  const PvpHistoryScreen({super.key});

  @override
  ConsumerState<PvpHistoryScreen> createState() => _PvpHistoryScreenState();
}

class _PvpHistoryScreenState extends ConsumerState<PvpHistoryScreen> {
  String _filter = 'all';
  String? _nemesisRivalId;
  bool _showRadar = false;

  @override
  void initState() {
    super.initState();
    deferProviderUpdate(() {
      ref.read(pvpHistoryProvider.notifier).load();
    });
    _loadNemesisRival();
  }

  Future<void> _loadNemesisRival() async {
    try {
      final dynamic res = await SupabaseService.client.rpc('get_nemesis_rival');
      if (!mounted || res is! Map) return;
      if (res['has_rival'] == true) {
        setState(() => _nemesisRivalId = res['rival_id']?.toString());
      }
    } catch (_) {}
  }

  @override
  void activate() {
    super.activate();
    deferProviderUpdate(() {
      ref.read(pvpHistoryProvider.notifier).load();
    });
  }

  /// Error/empty durumlarında da pull-to-refresh çalışsın.
  Widget _scrollableState({required Widget child}) {
    return RefreshIndicator(
      onRefresh: () => ref.read(pvpHistoryProvider.notifier).load(),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: child),
            ),
          );
        },
      ),
    );
  }

  String _timeAgo(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Az önce';
      if (diff.inHours < 1) return '${diff.inMinutes}dk önce';
      if (diff.inDays < 1) return '${diff.inHours}sa önce';
      if (diff.inDays < 7) return '${diff.inDays}g önce';
      return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return '';
    }
  }

  String _formatFullDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$day.$month.$year · $hour:$min';
    } catch (_) {
      return iso;
    }
  }

  void _showMatchDetails(
    BuildContext context, {
    required PvpRecentMatch m,
    required bool isWinner,
    required bool isAttacker,
    required String opponentName,
    required String authId,
    required GladiatorTier playerTier,
  }) {
    final opponentTier = isWinner ? GladiatorTier.silver : GladiatorTier.gold;
    final isNemesisMatch = _nemesisRivalId != null &&
        (m.attackerId == _nemesisRivalId || m.defenderId == _nemesisRivalId);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1523),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isWinner
                  ? const Color(0xFF10B981).withValues(alpha: 0.4)
                  : const Color(0xFFEF4444).withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isWinner ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                    .withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
              const BoxShadow(
                color: Colors.black,
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull Handle
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.military_tech_rounded,
                    color: isWinner ? const Color(0xFFFBBF24) : const Color(0xFFEF4444),
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'MUHAREBE AYRINTILARI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Outcome Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isWinner
                        ? [
                            const Color(0xFF065F46).withValues(alpha: 0.9),
                            const Color(0xFF047857).withValues(alpha: 0.7),
                            const Color(0xFF064E3B).withValues(alpha: 0.9),
                          ]
                        : [
                            const Color(0xFF7F1D1D).withValues(alpha: 0.9),
                            const Color(0xFF991B1B).withValues(alpha: 0.7),
                            const Color(0xFF450A0A).withValues(alpha: 0.9),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isWinner ? const Color(0xFF34D399) : const Color(0xFFF87171),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      m.isCritical && isWinner
                          ? '💥 EZİCİ ZAFER (CRITICAL)'
                          : isWinner
                              ? '🏆 GÖRKEMLİ ZAFER'
                              : '⚔️ ONURLU MAĞLUBİYET',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isWinner
                          ? (m.isCritical
                              ? 'Ezici bir vuruşla rakibinizi dize getirdiniz!'
                              : 'Arenada üstün stratejinizle zafer kazandınız.')
                          : 'Yaralarınızı sarın, intikam fırsatı çok yakında.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Versus Duelists Row
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141B2A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF253154)),
                ),
                child: Row(
                  children: [
                    // Player Info
                    Expanded(
                      child: Column(
                        children: [
                          GladiatorTierEmblem(
                            tier: playerTier,
                            size: 40,
                            showGlow: true,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Siz',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            isAttacker ? 'Saldırgan' : 'Savunan',
                            style: TextStyle(
                              color: isAttacker ? const Color(0xFFF87171) : const Color(0xFF60A5FA),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // VS Circle
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1E293B),
                        border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFBBF24).withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Text(
                        'VS',
                        style: TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    // Opponent Info
                    Expanded(
                      child: Column(
                        children: [
                          GladiatorTierEmblem(
                            tier: opponentTier,
                            size: 40,
                            showGlow: !isWinner,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            opponentName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            !isAttacker ? 'Saldırgan' : 'Savunan',
                            style: TextStyle(
                              color: !isAttacker ? const Color(0xFFF87171) : const Color(0xFF60A5FA),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Breakdown Metrics Grid
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _metricTile(
                    title: 'Ganimet Altın',
                    value: '${isWinner ? '+' : '-'}${m.goldStolen} Gold',
                    color: const Color(0xFFFBBF24),
                    icon: Icons.monetization_on_rounded,
                  ),
                  _metricTile(
                    title: 'Şöhret Değişimi',
                    value: '${isWinner ? '+' : '-'}${isWinner ? m.repChangeWinner : m.repChangeLoser} Rep',
                    color: isWinner ? const Color(0xFF34D399) : const Color(0xFFF87171),
                    icon: Icons.shield_rounded,
                  ),
                  _metricTile(
                    title: 'Kalan Can Gücü',
                    value: m.attackerHpRemaining > 0 ? '%${m.attackerHpRemaining}' : 'Belirtilmedi',
                    color: const Color(0xFF38BDF8),
                    icon: Icons.favorite_rounded,
                  ),
                  _metricTile(
                    title: 'Muharebe Alanı',
                    value: m.matchSource == 'arena' ? 'Kolezyum Arenası' : 'Düello Sahası',
                    color: const Color(0xFFA78BFA),
                    icon: Icons.stadium_rounded,
                  ),
                ],
              ),

              if (isNemesisMatch) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF450A0A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444)),
                  ),
                  child: const Row(
                    children: [
                      Text('💀', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'EZELİ RAKİP (NEMESIS) KARŞILAŞMASI\nBu düello kan davası puanınızı doğrudan etkilemiştir.',
                          style: TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),
              Text(
                'Tarih: ${_formatFullDate(m.createdAt)}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  if (!isWinner && !isAttacker) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          context.push(AppRoutes.pvp);
                        },
                        icon: const Icon(Icons.flash_on_rounded, color: Colors.black, size: 18),
                        label: const Text(
                          'İntikam Al',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFBBF24),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Color(0xFF334155)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Kapat'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metricTile({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: (MediaQuery.of(context).size.width - 40) / 2,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF101623),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(pvpHistoryProvider);
    final playerProfile = ref.watch(playerProvider).profile;
    final authId = SupabaseService.isInitialized
        ? SupabaseService.client.auth.currentUser?.id ?? ''
        : playerProfile?.authId ?? '';

    final playerRating = playerProfile?.pvpRating ?? 1200;
    final playerTier = GladiatorTier.fromRating(playerRating);

    // Filter computation
    List<PvpRecentMatch> filtered = history.matches;
    if (_filter == 'win') {
      filtered = history.matches.where((m) => m.winnerId == authId).toList();
    } else if (_filter == 'loss') {
      filtered = history.matches.where((m) => m.winnerId != authId).toList();
    } else if (_filter == 'critical') {
      filtered = history.matches.where((m) => m.isCritical).toList();
    } else if (_filter == 'nemesis' && _nemesisRivalId != null) {
      filtered = history.matches
          .where((PvpRecentMatch m) =>
              m.attackerId == _nemesisRivalId || m.defenderId == _nemesisRivalId)
          .toList();
    }

    // Career & streak stats computation
    int currentStreak = 0;
    bool isWinStreak = false;
    if (history.matches.isNotEmpty) {
      final sortedMatches = List<PvpRecentMatch>.from(history.matches)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final firstMatch = sortedMatches.first;
      isWinStreak = firstMatch.winnerId == authId;
      for (final m in sortedMatches) {
        final win = m.winnerId == authId;
        if (win == isWinStreak) {
          currentStreak++;
        } else {
          break;
        }
      }
    }

    final totalMatches = history.matches.length;
    final totalWins = history.matches.where((m) => m.winnerId == authId).length;
    final totalLosses = totalMatches - totalWins;
    final winRate = totalMatches > 0 ? (totalWins / totalMatches) : 0.0;

    final critCount = history.matches.where((m) => m.isCritical).length;
    final critWins = history.matches.where((m) => m.winnerId == authId && m.isCritical).length;
    final critRate = totalWins > 0 ? (critWins / totalWins) : 0.0;

    final attackMatches = history.matches.where((m) => m.attackerId == authId).length;
    final attackRatio = totalMatches > 0 ? (attackMatches / totalMatches) : 0.5;

    final attackDuelsWithHp = history.matches.where((m) => m.attackerId == authId && m.attackerHpRemaining > 0);
    final avgRemainingHpPct = attackDuelsWithHp.isNotEmpty
        ? (attackDuelsWithHp.fold<int>(0, (sum, m) => sum + m.attackerHpRemaining) / (attackDuelsWithHp.length * 100)).clamp(0.0, 1.0)
        : (totalWins > 0 ? 0.65 : 0.30);

    final totalGoldWon = history.matches.where((m) => m.winnerId == authId).fold<int>(0, (sum, m) => sum + m.goldStolen);
    final totalGoldLost = history.matches.where((m) => m.winnerId != authId).fold<int>(0, (sum, m) => sum + m.goldStolen);
    final netGold = totalGoldWon - totalGoldLost;

    final totalRepWon = history.matches.where((m) => m.winnerId == authId).fold<int>(0, (sum, m) => sum + m.repChangeWinner);
    final totalRepLost = history.matches.where((m) => m.winnerId != authId).fold<int>(0, (sum, m) => sum + m.repChangeLoser);
    final netRep = totalRepWon - totalRepLost;

    final avgGoldWon = totalWins > 0 ? (totalGoldWon ~/ totalWins) : 0;
    final plunderIndex = (avgGoldWon / 2000.0).clamp(0.1, 1.0);

    final nemesisMatches = _nemesisRivalId != null
        ? history.matches.where((m) => m.attackerId == _nemesisRivalId || m.defenderId == _nemesisRivalId).toList()
        : <PvpRecentMatch>[];

    final radarValues = <double>[
      winRate.clamp(0.05, 1.0),
      attackRatio.clamp(0.05, 1.0),
      critRate.clamp(0.05, 1.0),
      avgRemainingHpPct.clamp(0.05, 1.0),
      plunderIndex.clamp(0.05, 1.0),
    ];
    const radarLabels = <String>[
      'Zafer',
      'Saldırı',
      'Ezici',
      'Direnç',
      'Ganimet',
    ];

    Future<void> logout() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    }

    return GameSubScreenScaffold(
      title: context.l10n.pvp_ma_ge_mi_i,
      onLogout: logout,
      fallbackRoute: AppRoutes.pvp,
      bottomNavRoute: AppRoutes.pvpHistory,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF090D16), Color(0xFF131929), Color(0xFF0A0F1A)],
          ),
        ),
        child: Column(
          children: [
            // Streak Banner if active
            if (currentStreak >= 2)
              _StreakBanner(
                streakCount: currentStreak,
                isWinStreak: isWinStreak,
              ),

            // Combat Stats Overview Header
            _CombatStatsOverviewCard(
              playerTier: playerTier,
              playerRating: playerRating,
              totalMatches: totalMatches,
              totalWins: totalWins,
              totalLosses: totalLosses,
              winRate: winRate,
              netGold: netGold,
              netRep: netRep,
              showRadar: _showRadar,
              onToggleRadar: () => setState(() => _showRadar = !_showRadar),
            ),

            // Collapsible Combat Radar Panel
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _CombatPerformanceRadarWidget(
                values: radarValues,
                labels: radarLabels,
                winRatePct: (winRate * 100).toStringAsFixed(0),
                attackRatioPct: (attackRatio * 100).toStringAsFixed(0),
                critRatePct: (critRate * 100).toStringAsFixed(0),
                hpRemainingPct: (avgRemainingHpPct * 100).toStringAsFixed(0),
                avgGoldWon: avgGoldWon,
              ),
              crossFadeState: _showRadar ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),

            // Filter Tabs Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    for (final f in <(String, String, int)>[
                      ('all', 'Tümü', totalMatches),
                      ('win', 'Zaferler', totalWins),
                      ('loss', 'Yenilgiler', totalLosses),
                      ('critical', 'Ezici', critCount),
                      if (_nemesisRivalId != null) ('nemesis', 'Nemesis', nemesisMatches.length),
                    ])
                      GestureDetector(
                        onTap: () => setState(() => _filter = f.$1),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: _filter == f.$1
                                ? const Color(0xFFFBBF24).withValues(alpha: 0.18)
                                : const Color(0xFF141C2B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _filter == f.$1 ? const Color(0xFFFBBF24) : const Color(0xFF222E46),
                              width: _filter == f.$1 ? 1.2 : 1.0,
                            ),
                            boxShadow: _filter == f.$1
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFBBF24).withValues(alpha: 0.2),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            children: [
                              Text(
                                f.$2,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _filter == f.$1 ? FontWeight.w800 : FontWeight.w600,
                                  color: _filter == f.$1 ? const Color(0xFFFBBF24) : Colors.white60,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _filter == f.$1
                                      ? const Color(0xFFFBBF24).withValues(alpha: 0.25)
                                      : Colors.white10,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${f.$3}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _filter == f.$1 ? const Color(0xFFFBBF24) : Colors.white38,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),

            // Combat Log List
            Expanded(
              child: history.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFFFBBF24)),
                    )
                  : history.error != null
                      ? _scrollableState(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                history.error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => ref.read(pvpHistoryProvider.notifier).load(),
                                child: Text(context.l10n.yenile),
                              ),
                            ],
                          ),
                        )
                      : filtered.isEmpty
                          ? _scrollableState(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('⚔️', style: TextStyle(fontSize: 48)),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Henüz bu kriterde PvP maçınız bulunmuyor.',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: () => ref.read(pvpHistoryProvider.notifier).load(),
                                    child: Text(context.l10n.yenile),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () => ref.read(pvpHistoryProvider.notifier).load(),
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
                                itemCount: filtered.length,
                                itemBuilder: (context, i) {
                                  final m = filtered[i];
                                  final isAttacker = m.attackerId == authId;
                                  final isWinner = m.winnerId == authId;
                                  final opponentName = isAttacker
                                      ? (m.defenderUsername ?? 'Bilinmeyen Gladyatör')
                                      : (m.attackerUsername ?? 'Bilinmeyen Gladyatör');
                                  final isNemesis = _nemesisRivalId != null &&
                                      (m.attackerId == _nemesisRivalId || m.defenderId == _nemesisRivalId);

                                  return _CombatLogCard(
                                    match: m,
                                    isWinner: isWinner,
                                    isAttacker: isAttacker,
                                    opponentName: opponentName,
                                    isNemesis: isNemesis,
                                    timeAgoText: _timeAgo(m.createdAt),
                                    onTap: () => _showMatchDetails(
                                      context,
                                      m: m,
                                      isWinner: isWinner,
                                      isAttacker: isAttacker,
                                      opponentName: opponentName,
                                      authId: authId,
                                      playerTier: playerTier,
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dynamic Streak Banner for Win/Loss Streaks
class _StreakBanner extends StatelessWidget {
  const _StreakBanner({
    required this.streakCount,
    required this.isWinStreak,
  });

  final int streakCount;
  final bool isWinStreak;

  @override
  Widget build(BuildContext context) {
    final bgColor = isWinStreak ? const Color(0xFF78350F) : const Color(0xFF450A0A);
    final borderColor = isWinStreak ? const Color(0xFFFBBF24) : const Color(0xFFEF4444);
    final title = isWinStreak
        ? '🔥 $streakCount ZAFER SERİSİ'
        : '❄️ $streakCount MAĞLUBİYET - İNTİKAM VAKTİ';
    final subtitle = isWinStreak
        ? 'Durdurulamaz Gladyatör! İlave prestij kazanıyorsunuz.'
        : 'Kılıcını yeniden bile ve arenada intikamını al!';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.25),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isWinStreak ? Icons.local_fire_department_rounded : Icons.ac_unit_rounded,
            color: borderColor,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: borderColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
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

/// Overview card showing career records, net gains and radar expander
class _CombatStatsOverviewCard extends StatelessWidget {
  const _CombatStatsOverviewCard({
    required this.playerTier,
    required this.playerRating,
    required this.totalMatches,
    required this.totalWins,
    required this.totalLosses,
    required this.winRate,
    required this.netGold,
    required this.netRep,
    required this.showRadar,
    required this.onToggleRadar,
  });

  final GladiatorTier playerTier;
  final int playerRating;
  final int totalMatches;
  final int totalWins;
  final int totalLosses;
  final double winRate;
  final int netGold;
  final int netRep;
  final bool showRadar;
  final VoidCallback onToggleRadar;

  @override
  Widget build(BuildContext context) {
    final winRateText = '%${(winRate * 100).toStringAsFixed(1)}';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101726),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF22304A), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              GladiatorTierEmblem(
                tier: playerTier,
                size: 40,
                showGlow: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playerTier.title,
                      style: TextStyle(
                        color: playerTier.primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      '$playerRating MMR · $totalMatches Maç Kaydı',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onToggleRadar,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: showRadar
                        ? const Color(0xFF5B8FFF).withValues(alpha: 0.25)
                        : const Color(0xFF192338),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: showRadar ? const Color(0xFF5B8FFF) : const Color(0xFF2A3959),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.insights_rounded,
                        size: 15,
                        color: showRadar ? const Color(0xFF5B8FFF) : Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Radar',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: showRadar ? const Color(0xFF5B8FFF) : Colors.white70,
                        ),
                      ),
                      Icon(
                        showRadar ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: showRadar ? const Color(0xFF5B8FFF) : Colors.white70,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0C111C),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statColumn(label: 'Kazanma', value: winRateText, color: const Color(0xFF34D399)),
                _divider(),
                _statColumn(label: 'Skor', value: '$totalWins G / $totalLosses M', color: Colors.white),
                _divider(),
                _statColumn(
                  label: 'Net Altın',
                  value: '${netGold >= 0 ? '+' : ''}$netGold',
                  color: const Color(0xFFFBBF24),
                ),
                _divider(),
                _statColumn(
                  label: 'Net Rep',
                  value: '${netRep >= 0 ? '+' : ''}$netRep',
                  color: netRep >= 0 ? const Color(0xFF60A5FA) : const Color(0xFFF87171),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn({required String label, required String value, required Color color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 22,
      color: const Color(0xFF1E283D),
    );
  }
}

/// Custom painted 5-axis dark fantasy Combat Performance Radar widget
class _CombatPerformanceRadarWidget extends StatelessWidget {
  const _CombatPerformanceRadarWidget({
    required this.values,
    required this.labels,
    required this.winRatePct,
    required this.attackRatioPct,
    required this.critRatePct,
    required this.hpRemainingPct,
    required this.avgGoldWon,
  });

  final List<double> values;
  final List<String> labels;
  final String winRatePct;
  final String attackRatioPct;
  final String critRatePct;
  final String hpRemainingPct;
  final int avgGoldWon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1626),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF263756), width: 1.0),
      ),
      child: Row(
        children: [
          // Radar Canvas
          SizedBox(
            width: 150,
            height: 150,
            child: CustomPaint(
              painter: CombatPerformanceRadarPainter(
                values: values,
                labels: labels,
                primaryColor: const Color(0xFF5B8FFF),
                accentColor: const Color(0xFFFBBF24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Metric breakdown bars
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _barRow('Kazanma Oranı', '%$winRatePct', values[0], const Color(0xFF34D399)),
                const SizedBox(height: 6),
                _barRow('Saldırı İnisiyatifi', '%$attackRatioPct', values[1], const Color(0xFFF87171)),
                const SizedBox(height: 6),
                _barRow('Ezici Zafer Oranı', '%$critRatePct', values[2], const Color(0xFFFBBF24)),
                const SizedBox(height: 6),
                _barRow('Ort. Kalan Can', '%$hpRemainingPct', values[3], const Color(0xFF38BDF8)),
                const SizedBox(height: 6),
                _barRow('Yağma Başarısı', '$avgGoldWon G', values[4], const Color(0xFFA78BFA)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _barRow(String label, String valueText, double factor, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
            Text(
              valueText,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 4,
            child: Stack(
              children: [
                Container(color: const Color(0xFF1C263A)),
                FractionallySizedBox(
                  widthFactor: factor.clamp(0.05, 1.0),
                  child: Container(color: color),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter rendering a 5-axis dark fantasy Combat Performance Radar chart
class CombatPerformanceRadarPainter extends CustomPainter {
  const CombatPerformanceRadarPainter({
    required this.values,
    required this.labels,
    required this.primaryColor,
    required this.accentColor,
    this.animationValue = 1.0,
  });

  final List<double> values;
  final List<String> labels;
  final Color primaryColor;
  final Color accentColor;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.40;
    const count = 5;

    // Draw concentric web rings (levels 0.2, 0.4, 0.6, 0.8, 1.0)
    final webPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF263756);

    for (int step = 1; step <= 5; step++) {
      final r = radius * (step / 5);
      final path = Path();
      for (int i = 0; i < count; i++) {
        final angle = -math.pi / 2 + i * (2 * math.pi / count);
        final x = center.dx + r * math.cos(angle);
        final y = center.dy + r * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, webPaint);
    }

    // Draw axis lines from center to outer vertices
    final axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF33476E);

    for (int i = 0; i < count; i++) {
      final angle = -math.pi / 2 + i * (2 * math.pi / count);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), axisPaint);
    }

    // Draw data polygon
    final polyPath = Path();
    final points = <Offset>[];
    for (int i = 0; i < count; i++) {
      final val = (values[i] * animationValue).clamp(0.08, 1.0);
      final r = radius * val;
      final angle = -math.pi / 2 + i * (2 * math.pi / count);
      final pt = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
      points.add(pt);
      if (i == 0) {
        polyPath.moveTo(pt.dx, pt.dy);
      } else {
        polyPath.lineTo(pt.dx, pt.dy);
      }
    }
    polyPath.close();

    // Data polygon fill with gradient
    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: 0.50),
          accentColor.withValues(alpha: 0.25),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawPath(polyPath, fillPaint);

    // Data polygon border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = primaryColor;
    canvas.drawPath(polyPath, borderPaint);

    // Draw vertex dots with glow
    final dotPaint = Paint()..color = Colors.white;
    final dotGlowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (final pt in points) {
      canvas.drawCircle(pt, 4.5, dotGlowPaint);
      canvas.drawCircle(pt, 2.5, dotPaint);
    }

    // Draw axis labels
    for (int i = 0; i < count; i++) {
      final angle = -math.pi / 2 + i * (2 * math.pi / count);
      final labelR = radius + 15.0;
      final x = center.dx + labelR * math.cos(angle);
      final y = center.dy + labelR * math.sin(angle);

      final span = TextSpan(
        text: labels[i],
        style: const TextStyle(
          color: Color(0xFFC7D2FE),
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      );
      final tp = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CombatPerformanceRadarPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.values != values;
  }
}

/// Animated Rating Delta Badge with pulse scaling and neon radiance
class _AnimatedDeltaBadge extends StatefulWidget {
  const _AnimatedDeltaBadge({
    required this.repChange,
    required this.isWinner,
  });

  final int repChange;
  final bool isWinner;

  @override
  State<_AnimatedDeltaBadge> createState() => _AnimatedDeltaBadgeState();
}

class _AnimatedDeltaBadgeState extends State<_AnimatedDeltaBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPositive = widget.isWinner;
    final baseColor = isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final text = '${isPositive ? '+' : '-'}${widget.repChange} Rep';

    return ScaleTransition(
      scale: _pulseAnim,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: baseColor.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: baseColor.withValues(alpha: 0.55), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: baseColor.withValues(alpha: 0.35),
              blurRadius: 5,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPositive ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
              size: 16,
              color: baseColor,
            ),
            Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isPositive ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Polished Combat Log Entry Card
class _CombatLogCard extends StatelessWidget {
  const _CombatLogCard({
    required this.match,
    required this.isWinner,
    required this.isAttacker,
    required this.opponentName,
    required this.isNemesis,
    required this.timeAgoText,
    required this.onTap,
  });

  final PvpRecentMatch match;
  final bool isWinner;
  final bool isAttacker;
  final String opponentName;
  final bool isNemesis;
  final String timeAgoText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isArena = match.matchSource == 'arena';
    final accentColor = isWinner ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF111726),
          border: Border(
            left: BorderSide(color: accentColor, width: 4),
            top: BorderSide(color: accentColor.withValues(alpha: 0.25), width: 1),
            right: const BorderSide(color: Color(0xFF1E283D), width: 1),
            bottom: const BorderSide(color: Color(0xFF1E283D), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Badges Row
              Row(
                children: [
                  // Arena / Duel Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isArena
                          ? const Color(0xFFA78BFA).withValues(alpha: 0.2)
                          : const Color(0xFF60A5FA).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isArena ? '🏟️ ARENA' : '⚔️ DÜELLO',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: isArena ? const Color(0xFFA78BFA) : const Color(0xFF60A5FA),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),

                  // Role Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isAttacker
                          ? const Color(0xFFF87171).withValues(alpha: 0.18)
                          : const Color(0xFF38BDF8).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isAttacker ? 'SALDIRI' : 'SAVUNMA',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: isAttacker ? const Color(0xFFF87171) : const Color(0xFF38BDF8),
                      ),
                    ),
                  ),

                  // Critical Strike Pill
                  if (match.isCritical) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '💥 EZİCİ',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFBBF24),
                        ),
                      ),
                    ),
                  ],

                  // Nemesis Pill
                  if (isNemesis) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE52E2E).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '💀 NEMESIS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],

                  const Spacer(),
                  const Icon(Icons.schedule_rounded, size: 11, color: Colors.white38),
                  const SizedBox(width: 3),
                  Text(
                    timeAgoText,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Main Body Row
              Row(
                children: [
                  GladiatorTierEmblem(
                    tier: isWinner ? GladiatorTier.gold : GladiatorTier.silver,
                    size: 36,
                    showGlow: isWinner,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            children: [
                              TextSpan(
                                text: isAttacker ? 'vs ' : 'Savunma vs ',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              TextSpan(
                                text: opponentName,
                                style: TextStyle(
                                  color: isAttacker ? const Color(0xFFF87171) : const Color(0xFFFBBF24),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              isWinner ? 'Zafer' : 'Mağlubiyet',
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (match.attackerHpRemaining > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                '· %${match.attackerHpRemaining} HP',
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Rating Delta & Gold Rewards
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _AnimatedDeltaBadge(
                        repChange: isWinner ? match.repChangeWinner : match.repChangeLoser,
                        isWinner: isWinner,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.monetization_on_rounded,
                            size: 12,
                            color: isWinner ? const Color(0xFFFBBF24) : Colors.white38,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${isWinner ? '+' : '-'}${match.goldStolen}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isWinner ? const Color(0xFFFBBF24) : Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Colors.white24,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
