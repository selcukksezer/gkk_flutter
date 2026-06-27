import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/provider_scheduling.dart';
import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/pvp_provider.dart';
import '../../routing/app_router.dart';
import '../../l10n/l10n.dart';

class PvpHistoryScreen extends ConsumerStatefulWidget {
  const PvpHistoryScreen({super.key});

  @override
  ConsumerState<PvpHistoryScreen> createState() => _PvpHistoryScreenState();
}

class _PvpHistoryScreenState extends ConsumerState<PvpHistoryScreen> {
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    deferProviderUpdate(() {
      ref.read(pvpHistoryProvider.notifier).load();
    });
  }

  @override
  void activate() {
    super.activate();
    deferProviderUpdate(() {
      ref.read(pvpHistoryProvider.notifier).load();
    });
  }

  String _timeAgo(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Az önce';
      if (diff.inHours < 1) return '${diff.inMinutes}dk önce';
      if (diff.inDays < 1) return '${diff.inHours}sa önce';
      return '${diff.inDays}g önce';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(pvpHistoryProvider);
    final authId = SupabaseService.isInitialized
        ? SupabaseService.client.auth.currentUser?.id ?? ''
        : ref.watch(playerProvider).profile?.authId ?? '';

    List<PvpRecentMatch> filtered = history.matches;
    if (_filter == 'win') {
      filtered = history.matches.where((m) => m.winnerId == authId).toList();
    }
    if (_filter == 'loss') {
      filtered = history.matches.where((m) => m.winnerId != authId).toList();
    }

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
            colors: [Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  for (final f in [('all', 'Tümü'), ('win', 'Kazandım'), ('loss', 'Kaybettim')])
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _filter = f.$1),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _filter == f.$1
                                ? const Color(0xFFFBBF24).withValues(alpha: 0.2)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: _filter == f.$1 ? const Color(0xFFFBBF24) : Colors.transparent),
                          ),
                          child: Text(f.$2,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: _filter == f.$1 ? const Color(0xFFFBBF24) : Colors.white54)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: history.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : history.error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(history.error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.redAccent)),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => ref.read(pvpHistoryProvider.notifier).load(),
                                child: Text(context.l10n.yenile),
                              ),
                            ],
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('⚔️', style: TextStyle(fontSize: 48)),
                                  const SizedBox(height: 12),
                                  const Text('Henüz hiç PvP maçınız bulunmuyor.',
                                      style: TextStyle(color: Colors.white54)),
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
                                padding: const EdgeInsets.all(12),
                                itemCount: filtered.length,
                                itemBuilder: (context, i) {
                                  final m = filtered[i];
                                  final isAttacker = m.attackerId == authId;
                                  final isWinner = m.winnerId == authId;
                                  final opponentName = isAttacker
                                      ? (m.defenderUsername ?? 'Bilinmeyen')
                                      : (m.attackerUsername ?? 'Bilinmeyen');
                                  final isArena = m.matchSource == 'arena';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border(
                                        left: BorderSide(
                                          color: isWinner ? Colors.green : Colors.red,
                                          width: 4,
                                        ),
                                      ),
                                      color: isWinner
                                          ? Colors.green.withValues(alpha: 0.08)
                                          : Colors.red.withValues(alpha: 0.08),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                RichText(
                                                  text: TextSpan(
                                                    style: const TextStyle(
                                                        fontSize: 15, fontWeight: FontWeight.bold),
                                                    children: [
                                                      TextSpan(
                                                          text: isAttacker
                                                              ? 'Saldırdınız: '
                                                              : 'Savundunuz: '),
                                                      TextSpan(
                                                        text: opponentName,
                                                        style: TextStyle(
                                                            color: isAttacker
                                                                ? Colors.redAccent
                                                                : const Color(0xFFFBBF24)),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Sonuç: ${isWinner ? 'Kazandınız' : 'Kaybettiniz'}'
                                                  '${isArena ? ' · 🏟️ Arena' : ''}'
                                                  '${m.isCritical ? ' · 💥 Ezici Zafer' : ''}',
                                                  style: const TextStyle(
                                                      color: Colors.white54, fontSize: 12),
                                                ),
                                                Text(
                                                  _timeAgo(m.createdAt),
                                                  style: const TextStyle(
                                                      color: Colors.white38, fontSize: 11),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '${isWinner ? '+' : '-'}${m.goldStolen} Gold',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: isWinner
                                                      ? const Color(0xFFFBBF24)
                                                      : Colors.white38,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${isWinner ? '+' : '-'}${isWinner ? m.repChangeWinner : m.repChangeLoser} Rep',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isWinner ? Colors.blue : Colors.white38,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
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
