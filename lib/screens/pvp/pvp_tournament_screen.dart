import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/pvp_provider.dart';
import '../../routing/app_router.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import '../../l10n/l10n.dart';

class PvpTournamentScreen extends ConsumerStatefulWidget {
  const PvpTournamentScreen({super.key});

  @override
  ConsumerState<PvpTournamentScreen> createState() => _PvpTournamentScreenState();
}

class _PvpTournamentScreenState extends ConsumerState<PvpTournamentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pvpTournamentProvider.notifier).load();
    });
  }

  Future<void> _joinTournament() async {
    final error = await ref.read(pvpTournamentProvider.notifier).join();
    if (!mounted) return;
    if (error == null) {
      AppMessenger.show(context, 'Turnuvaya başarıyla katıldınız!');
    } else {
      AppMessenger.showError(context, error);
    }
  }

  String _formatGold(int amount) {
    final text = amount.toString();
    if (text.length <= 3) return text;
    final buf = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) buf.write(',');
      buf.write(text[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final tournamentState = ref.watch(pvpTournamentProvider);
    final data = tournamentState.data;

    Future<void> logout() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    }

    return GameSubScreenScaffold(
      title: context.l10n.haftal_k_turnuva,
      onLogout: logout,
      fallbackRoute: AppRoutes.pvp,
      bottomNavRoute: AppRoutes.pvpTournament,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)],
          ),
        ),
        child: tournamentState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => ref.read(pvpTournamentProvider.notifier).load(),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      data.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFBBF24)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${data.participantCount} katılımcı · ${_formatGold(data.prizePool)} altın ödül',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    if (tournamentState.error != null) ...[
                      const SizedBox(height: 12),
                      Text(tournamentState.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.read(pvpTournamentProvider.notifier).load(),
                        child: Text(context.l10n.yenile),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (data.rounds.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2533),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                            const Text('🏆', style: TextStyle(fontSize: 40)),
                            const SizedBox(height: 8),
                            const Text(
                              'Bracket henüz oluşmadı.\nKayıt ol — 2+ katılımcı olunca canlı bracket açılır.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2533),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              for (final round in data.rounds) ...[
                                _BracketColumn(round: round),
                                const SizedBox(width: 12),
                              ],
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Şampiyon',
                                      style: TextStyle(
                                          color: Color(0xFFFBBF24),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                          colors: [Color(0xFFD97706), Color(0xFFB45309)],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFFBBF24), width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                            color: const Color(0xFFFBBF24).withValues(alpha: 0.4),
                                            blurRadius: 16)
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        const Text('👑', style: TextStyle(fontSize: 28)),
                                        const SizedBox(height: 4),
                                        Text(
                                          data.championName.isEmpty ? '—' : data.championName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🏆 Ödül Havuzu (${_formatGold(data.prizePool)} Altın)',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFFFBBF24))),
                          const SizedBox(height: 12),
                          for (final item in [
                            ('🥇', '1.', '50% altın'),
                            ('🥈', '2.', '30% altın'),
                            ('🥉', '3.', '20% altın'),
                          ])
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(children: [
                                Text(item.$1, style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 8),
                                Text('${item.$2} — ',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                Expanded(
                                    child: Text(item.$3,
                                        style: const TextStyle(color: Colors.white70))),
                              ]),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: data.registrationOpen
                          ? ElevatedButton(
                              onPressed: tournamentState.isJoining ? null : _joinTournament,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD97706),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: tournamentState.isJoining
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Turnuvaya Katıl',
                                      style: TextStyle(
                                          color: Colors.white, fontWeight: FontWeight.bold)),
                            )
                          : ElevatedButton(
                              onPressed: null,
                              style: ElevatedButton.styleFrom(
                                  disabledBackgroundColor: Colors.white12,
                                  padding: const EdgeInsets.symmetric(vertical: 14)),
                              child: const Text('Turnuvaya Katıl (Kayıtlar Kapalı)',
                                  style: TextStyle(color: Colors.white38)),
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _BracketColumn extends StatelessWidget {
  const _BracketColumn({required this.round});
  final PvpTournamentRound round;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(round.title,
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          for (final m in round.matches) ...[
            _MatchCard(match: m),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});
  final PvpTournamentMatch match;

  Widget _row(String name, int score, bool isWinner) => Container(
        color: isWinner ? const Color(0xFFFBBF24).withValues(alpha: 0.15) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Expanded(
                child: Text(name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                        color: isWinner ? const Color(0xFFFBBF24) : Colors.white54))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration:
                  BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(4)),
              child: Text('$score', style: const TextStyle(fontSize: 11)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A2030),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Column(
            children: [
              _row(match.p1, match.s1, match.winner == match.p1),
              const Divider(height: 1, color: Colors.white12),
              _row(match.p2, match.s2, match.winner == match.p2),
            ],
          ),
        ),
      );
}
