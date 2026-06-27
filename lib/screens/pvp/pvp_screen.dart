import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/provider_scheduling.dart';
import '../../components/layout/game_chrome.dart';
import '../../l10n/l10n.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/pvp_provider.dart';
import '../../routing/app_router.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';

class PvpScreen extends ConsumerStatefulWidget {
  const PvpScreen({super.key});

  @override
  ConsumerState<PvpScreen> createState() => _PvpScreenState();
}

class _PvpScreenState extends ConsumerState<PvpScreen> {
  @override
  void initState() {
    super.initState();
    deferProviderUpdate(() {
      ref.read(playerProvider.notifier).loadProfile();
      ref.read(pvpDashboardProvider.notifier).load();
    });
  }

  @override
  void activate() {
    super.activate();
    deferProviderUpdate(() {
      ref.read(playerProvider.notifier).loadProfile();
      ref.read(pvpDashboardProvider.notifier).load();
    });
  }

  bool _isRestricted(String? until) {
    if (until == null || until.isEmpty) return false;
    final dt = DateTime.tryParse(until);
    return dt != null && dt.isAfter(DateTime.now());
  }

  String _timeAgo(String? createdAt) {
    if (createdAt == null || createdAt.isEmpty) return '';
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}g önce';
    if (diff.inHours > 0) return '${diff.inHours}s önce';
    if (diff.inMinutes > 0) return '${diff.inMinutes}dk önce';
    return 'az önce';
  }

  String _mekanTypeLabel(String type) {
    switch (type) {
      case 'dovus_kulubu':
        return 'Dövüş Kulübü';
      case 'luks_lounge':
        return 'Lüks Lounge';
      case 'yeralti':
        return 'Yeraltı';
      default:
        return type;
    }
  }

  Future<void> _refresh() async {
    await Future.wait<void>([
      ref.read(playerProvider.notifier).loadProfile(),
      ref.read(pvpDashboardProvider.notifier).load(),
    ]);
  }

  Future<void> _doLogout() async {
    await ref.read(authProvider.notifier).logout();
    ref.read(playerProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(playerProvider).profile;
    final dashboard = ref.watch(pvpDashboardProvider);
    final pvpRating = profile?.pvpRating ?? 1000;
    final pvpWins = profile?.pvpWins ?? 0;
    final pvpLosses = profile?.pvpLosses ?? 0;
    final energy = profile?.energy ?? 0;
    final isHospitalized = _isRestricted(profile?.hospitalUntil);
    final isImprisoned = _isRestricted(profile?.prisonUntil);

    final currentUserId = SupabaseService.isInitialized
        ? SupabaseService.client.auth.currentUser?.id ?? ''
        : '';

    final total = pvpWins + pvpLosses;
    final winRate = total > 0 ? (pvpWins / total * 100).toStringAsFixed(1) : '0.0';

    return Scaffold(
      appBar: GameTopBar(title: context.l10n.routePvp, onLogout: _doLogout),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(currentRoute: AppRoutes.pvp, onLogout: _doLogout),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: <Widget>[
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('⚔️ PvP İstatistikleri',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        _StatChip(label: context.l10n.rating, value: '$pvpRating', color: Colors.amber),
                        const SizedBox(width: 10),
                        _StatChip(
                            label: context.l10n.kazanma_oran, value: '$winRate%', color: Colors.greenAccent),
                        const SizedBox(width: 10),
                        _StatChip(
                            label: context.l10n.enerji_2, value: '$energy', color: const Color(0xFF00D7D7)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        _StatChip(
                            label: context.l10n.galibiyet, value: '$pvpWins', color: Colors.greenAccent),
                        const SizedBox(width: 10),
                        _StatChip(
                            label: context.l10n.ma_lubiyet, value: '$pvpLosses', color: Colors.redAccent),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go(AppRoutes.pvpHistory),
                      icon: const Icon(Icons.history_rounded, size: 16),
                      label: Text(context.l10n.ge_mi_i_a),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        foregroundColor: Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go(AppRoutes.pvpTournament),
                      icon: const Icon(Icons.emoji_events_rounded, size: 16),
                      label: Text(context.l10n.turnuva),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.amber),
                        foregroundColor: Colors.amber,
                      ),
                    ),
                  ),
                ],
              ),
              if (isHospitalized) ...<Widget>[
                const SizedBox(height: 12),
                _warningBanner(
                  icon: Icons.local_hospital_rounded,
                  message:
                      'Hastanede tedavi görüyorsunuz. PvP için serbest olmanız gerekiyor.',
                  color: Colors.redAccent,
                ),
              ],
              if (isImprisoned) ...<Widget>[
                const SizedBox(height: 12),
                _warningBanner(
                  icon: Icons.gavel_rounded,
                  message:
                      'Hapishanede bulunuyorsunuz. PvP için serbest olmanız gerekiyor.',
                  color: Colors.orangeAccent,
                ),
              ],
              const SizedBox(height: 20),
              const Text('🏟️ Açık Arenalar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              if (dashboard.isLoading)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ))
              else if (dashboard.error != null)
                _errorCard('Arenalar yüklenemedi: ${dashboard.error}')
              else if (dashboard.arenas.isEmpty)
                _emptyCard('Şu anda açık arena yok.')
              else
                ...dashboard.arenas.map((arena) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ArenaCard(
                        arenaName: arena.name,
                        mekanTypeLabel: _mekanTypeLabel(arena.mekanType),
                        onTap: () {
                          if (isHospitalized || isImprisoned) {
                            AppMessenger.showError(context, isHospitalized
                                    ? '🏥 Hastanedeyken arenaya giremezsiniz!'
                                    : '👮 Cezaevindeyken arenaya giremezsiniz!');
                            return;
                          }
                          context.go('/mekans/${arena.id}/arena');
                        },
                      ),
                    )),
              const SizedBox(height: 20),
              const Text('📋 Son Maçlar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              if (!dashboard.isLoading && dashboard.recentMatches.isEmpty)
                _emptyCard('Henüz maç yok.')
              else
                ...dashboard.recentMatches.map((match) {
                  final isAttacker = match.attackerId == currentUserId;
                  final won = match.winnerId == currentUserId;
                  final opponentName = isAttacker
                      ? (match.defenderUsername ?? 'Rakip')
                      : (match.attackerUsername ?? 'Rakip');
                  final repChange = won ? match.repChangeWinner : match.repChangeLoser;
                  final goldStolen = won ? match.goldStolen : -match.goldStolen;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MatchCard(
                      opponentName: opponentName,
                      isAttacker: isAttacker,
                      won: won,
                      isArena: match.matchSource == 'arena',
                      timeAgo: _timeAgo(match.createdAt),
                      hpRemaining: match.attackerHpRemaining,
                      goldStolen: goldStolen,
                      repChange: repChange,
                      isCritical: match.isCritical,
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }

  Widget _warningBanner(
      {required IconData icon, required String message, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white12),
      ),
      child: Center(child: Text(message, style: const TextStyle(color: Colors.white54))),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.red.withValues(alpha: 0.08),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Text(message, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: color.withValues(alpha: 0.10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: <Widget>[
            Text(value,
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ArenaCard extends StatelessWidget {
  const _ArenaCard({
    required this.arenaName,
    required this.mekanTypeLabel,
    required this.onTap,
  });

  final String arenaName;
  final String mekanTypeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.sports_kabaddi_rounded, color: Colors.redAccent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(arenaName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(mekanTypeLabel,
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            child: Text(context.l10n.arenaya_git),
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.opponentName,
    required this.isAttacker,
    required this.won,
    required this.isArena,
    required this.timeAgo,
    required this.hpRemaining,
    required this.goldStolen,
    required this.repChange,
    required this.isCritical,
  });

  final String opponentName;
  final bool isAttacker;
  final bool won;
  final bool isArena;
  final String timeAgo;
  final int hpRemaining;
  final int goldStolen;
  final int repChange;
  final bool isCritical;

  @override
  Widget build(BuildContext context) {
    final resultColor = won ? Colors.greenAccent : Colors.redAccent;
    final resultText = won ? 'Kazandın' : 'Kaybettin';
    final roleText = isAttacker ? 'Saldırı' : 'Savunma';
    final goldSign = goldStolen >= 0 ? '+' : '';
    final repSign = repChange >= 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isAttacker
                      ? Colors.redAccent.withValues(alpha: 0.2)
                      : Colors.blueAccent.withValues(alpha: 0.2),
                ),
                child: Text(roleText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isAttacker ? Colors.redAccent : Colors.blueAccent,
                    )),
              ),
              if (isArena) ...<Widget>[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.amber.withValues(alpha: 0.15),
                  ),
                  child: const Text('Arena',
                      style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w700, color: Colors.amber)),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: Text(opponentName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
              Text(timeAgo, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(width: 8),
              Text(resultText,
                  style: TextStyle(fontWeight: FontWeight.w700, color: resultColor)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _MatchStat(
                  icon: Icons.favorite_rounded,
                  label: 'HP',
                  value: '$hpRemaining',
                  color: Colors.redAccent),
              const SizedBox(width: 16),
              _MatchStat(
                icon: Icons.paid_rounded,
                label: context.l10n.alt_n,
                value: '$goldSign$goldStolen',
                color: goldStolen >= 0 ? Colors.amber : Colors.red,
              ),
              const SizedBox(width: 16),
              _MatchStat(
                icon: Icons.star_rounded,
                label: context.l10n.i_tibar,
                value: '$repSign$repChange',
                color: repChange >= 0 ? Colors.greenAccent : Colors.redAccent,
              ),
            ],
          ),
          if (isCritical) ...<Widget>[
            const SizedBox(height: 8),
            const Text('⚡ Kritik zafer kaydı',
                style: TextStyle(
                    color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

class _MatchStat extends StatelessWidget {
  const _MatchStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
      ],
    );
  }
}
