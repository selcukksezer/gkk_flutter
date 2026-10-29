import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../l10n/l10n.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/pvp_provider.dart';
import '../../routing/app_router.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import 'widgets/gladiator_tier_emblem.dart';

/// Dark Fantasy Aion-2 Polished PvP Tournament Screen.
/// Features live bracket visualizer, real-time countdown timer, combat status chips,
/// match transition details, glassmorphic card styling, and imperial gold/crimson badges.
class PvpTournamentScreen extends ConsumerStatefulWidget {
  const PvpTournamentScreen({super.key});

  @override
  ConsumerState<PvpTournamentScreen> createState() => _PvpTournamentScreenState();
}

class _PvpTournamentScreenState extends ConsumerState<PvpTournamentScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  Timer? _countdownTimer;
  Duration _timeRemaining = const Duration(hours: 4, minutes: 22, seconds: 45);
  int _selectedTabIndex = 0; // 0: Bracket Ağacı, 1: Ödüller & Kurallar

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _initLiveCountdown();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pvpTournamentProvider.notifier).load();
    });
  }

  void _initLiveCountdown() {
    final DateTime now = DateTime.now().toUtc();
    // Calculate target to next Sunday 20:00 UTC (weekly championship schedule)
    final int daysUntilSunday = (DateTime.sunday - now.weekday + 7) % 7;
    DateTime nextTarget = DateTime.utc(
      now.year,
      now.month,
      now.day + (daysUntilSunday == 0 && now.hour >= 20 ? 7 : daysUntilSunday),
      20,
      0,
      0,
    );
    if (nextTarget.isBefore(now)) {
      nextTarget = nextTarget.add(const Duration(days: 7));
    }
    _timeRemaining = nextTarget.difference(now);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timeRemaining.inSeconds > 0) {
          _timeRemaining = _timeRemaining - const Duration(seconds: 1);
        } else {
          _timeRemaining = const Duration(days: 7);
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _joinTournament() async {
    HapticFeedback.heavyImpact();
    final error = await ref.read(pvpTournamentProvider.notifier).join();
    if (!mounted) return;
    if (error == null) {
      AppMessenger.show(context, 'Turnuvaya başarıyla katıldınız! Arenaya hoş geldin.');
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

  void _showMatchDetails(BuildContext context, PvpTournamentMatch match, String roundTitle) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MatchDetailSheet(
        match: match,
        roundTitle: roundTitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tournamentState = ref.watch(pvpTournamentProvider);
    final data = tournamentState.data;
    final playerState = ref.watch(playerProvider);
    final currentUsername = playerState.profile?.username ?? '';

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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF090B12),
              Color(0xFF13101E),
              Color(0xFF0E1320),
              Color(0xFF08090E),
            ],
            stops: <double>[0.0, 0.35, 0.75, 1.0],
          ),
        ),
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, _) {
            return CustomPaint(
              painter: _AtmosphericDustPainter(pulseValue: _pulseAnimation.value),
              child: tournamentState.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                      ),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFFFFD700),
                      backgroundColor: const Color(0xFF161B28),
                      onRefresh: () => ref.read(pvpTournamentProvider.notifier).load(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        children: [
                          // 1. Grand Tournament Header Banner
                          _TournamentHeroHeader(
                            data: data,
                            timeRemaining: _timeRemaining,
                            formattedGold: _formatGold(data.prizePool),
                            pulseValue: _pulseAnimation.value,
                          ),
                          const SizedBox(height: 12),

                          // Error Display
                          if (tournamentState.error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7F1D1D).withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Color(0xFFF87171), size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      tournamentState.error!,
                                      style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => ref.read(pvpTournamentProvider.notifier).load(),
                                    child: Text(
                                      context.l10n.yenile,
                                      style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // 2. Segmented View Switcher (Bracket Tree vs. Prizes & Rules)
                          _TournamentTabSelector(
                            selectedIndex: _selectedTabIndex,
                            onTabSelected: (index) {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedTabIndex = index);
                            },
                          ),
                          const SizedBox(height: 16),

                          // 3. Tab Contents
                          if (_selectedTabIndex == 0) ...[
                            // Bracket Tree Section
                            if (data.rounds.isEmpty)
                              _TournamentEmptyBracketCard(
                                data: data,
                                pulseValue: _pulseAnimation.value,
                              )
                            else
                              _TournamentBracketView(
                                data: data,
                                currentUsername: currentUsername,
                                pulseValue: _pulseAnimation.value,
                                onMatchTap: (match, roundTitle) =>
                                    _showMatchDetails(context, match, roundTitle),
                              ),
                          ] else ...[
                            // Prizes & Rules Section
                            _TournamentPrizesAndRules(
                              prizePool: data.prizePool,
                              formattedGold: _formatGold(data.prizePool),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // 4. Tournament Registration Action Deck
                          _TournamentRegistrationDeck(
                            data: data,
                            isJoining: tournamentState.isJoining,
                            pulseValue: _pulseAnimation.value,
                            onJoinPressed: _joinTournament,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }
}

/// Atmospheric runic dust and spark painter for dark fantasy immersion.
class _AtmosphericDustPainter extends CustomPainter {
  const _AtmosphericDustPainter({required this.pulseValue});

  final double pulseValue;

  @override
  void paint(Canvas canvas, Size size) {
    final math.Random rng = math.Random(777);
    final Paint dustPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 26; i++) {
      final double x = rng.nextDouble() * size.width;
      final double driftFactor = (rng.nextDouble() + pulseValue * 0.15) % 1.0;
      final double y = driftFactor * size.height;
      final double radius = 0.9 + rng.nextDouble() * 1.5;
      final double alpha = (0.12 + 0.28 * math.sin(pulseValue * math.pi + i)).clamp(0.04, 0.40);

      final Color particleColor = (i % 3 == 0)
          ? const Color(0xFFFFD700)
          : (i % 3 == 1)
              ? const Color(0xFFFF1744)
              : const Color(0xFF00E5FF);

      dustPaint.color = particleColor.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, dustPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AtmosphericDustPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue;
  }
}

/// Tournament Hero Header with live countdown, gold prize pool, and phase chips.
class _TournamentHeroHeader extends StatelessWidget {
  const _TournamentHeroHeader({
    required this.data,
    required this.timeRemaining,
    required this.formattedGold,
    required this.pulseValue,
  });

  final PvpTournamentData data;
  final Duration timeRemaining;
  final String formattedGold;
  final double pulseValue;

  String _formatPad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final int hours = timeRemaining.inHours;
    final int minutes = timeRemaining.inMinutes % 60;
    final int seconds = timeRemaining.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141926).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.28 + 0.15 * pulseValue),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.12 * pulseValue),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Phase Tag & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF991B1B), Color(0xFFB45309)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE082),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFE082).withValues(alpha: 0.8),
                            blurRadius: 6,
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      data.registrationOpen
                          ? 'KAYIT AŞAMASI'
                          : data.rounds.isNotEmpty
                              ? 'CANLI BRACKET'
                              : 'HAZIRLIK EVRESİ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_alt_outlined, size: 14, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 6),
                    Text(
                      '${data.participantCount} / ${data.minParticipants} Gladyatör',
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            data.title.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Color(0xFFFFD700),
              shadows: [
                Shadow(color: Color(0xFFD97706), blurRadius: 10),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Prize pool display badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  const Color(0xFFD97706).withValues(alpha: 0.25),
                  const Color(0xFF92400E).withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🏆', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  '$formattedGold Altın Ödül Havuzu',
                  style: const TextStyle(
                    color: Color(0xFFFDE68A),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Real-time Countdown Timer Pods
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CountdownPod(label: 'SAAT', value: _formatPad(hours)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text(':', style: TextStyle(color: Color(0xFFFFD700), fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _CountdownPod(label: 'DAKİKA', value: _formatPad(minutes)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text(':', style: TextStyle(color: Color(0xFFFFD700), fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _CountdownPod(label: 'SANİYE', value: _formatPad(seconds)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.registrationOpen
                ? 'Kayıtların Kapanmasına ve Maçların Başlamasına Kalan Süre'
                : 'Sonraki Aşama Güncellemesine Kalan Süre',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

/// Stylish glass countdown block pod.
class _CountdownPod extends StatelessWidget {
  const _CountdownPod({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0C101A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.25)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFFFE082),
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Segmented Tab Switcher for toggling between the Bracket view and Rewards/Rules.
class _TournamentTabSelector extends StatelessWidget {
  const _TournamentTabSelector({
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF101420),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              title: '⚔️ Turnuva Ağacı',
              isSelected: selectedIndex == 0,
              onTap: () => onTabSelected(0),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TabButton(
              title: '🏆 Ödüller & Kurallar',
              isSelected: selectedIndex == 1,
              onTap: () => onTabSelected(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD97706).withValues(alpha: 0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.6), width: 1.2)
              : Border.all(color: Colors.transparent),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? const Color(0xFFFFD700) : Colors.white60,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/// Empty Bracket Card with registration information and minimum participant tracker.
class _TournamentEmptyBracketCard extends StatelessWidget {
  const _TournamentEmptyBracketCard({
    required this.data,
    required this.pulseValue,
  });

  final PvpTournamentData data;
  final double pulseValue;

  @override
  Widget build(BuildContext context) {
    final bool isCanceled = data.cancelReason == 'insufficient_players';
    final double progress = (data.participantCount / data.minParticipants).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF141926).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCanceled
              ? const Color(0xFFEF4444).withValues(alpha: 0.3)
              : const Color(0xFFFFD700).withValues(alpha: 0.25 + 0.15 * pulseValue),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCanceled
                  ? const Color(0xFF7F1D1D).withValues(alpha: 0.3)
                  : const Color(0xFFD97706).withValues(alpha: 0.2),
              border: Border.all(
                color: isCanceled ? const Color(0xFFEF4444) : const Color(0xFFFFD700),
                width: 1.5,
              ),
            ),
            child: Text(
              isCanceled ? '⚔️' : '🏆',
              style: const TextStyle(fontSize: 34),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isCanceled ? 'Turnuva Bu Hafta Gerçekleştirilemedi' : 'Turnuva Ağacı Henüz Oluşmadı',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isCanceled ? const Color(0xFFFCA5A5) : const Color(0xFFFFD700),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isCanceled
                ? 'Yetersiz katılımcı nedeniyle bu hafta turnuva düzenlenemedi.\nEn az ${data.minParticipants} gladyatör gerekli — gelecek haftaya hazırlan!'
                : 'Turnuva kayıtları açık.\nEn az ${data.minParticipants} katılımcıya ulaşıldığında canlı kura çekilir ve turnuva ağacı aktifleşir.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          // Participant progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Katılımcı Sayısı', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  Text(
                    '${data.participantCount} / ${data.minParticipants}',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Interactive Horizontal Tournament Bracket Visualizer with connecting links and champion podium.
class _TournamentBracketView extends StatelessWidget {
  const _TournamentBracketView({
    required this.data,
    required this.currentUsername,
    required this.pulseValue,
    required this.onMatchTap,
  });

  final PvpTournamentData data;
  final String currentUsername;
  final double pulseValue;
  final void Function(PvpTournamentMatch match, String roundTitle) onMatchTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141926).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_outlined, size: 16, color: Color(0xFFFFD700)),
              const SizedBox(width: 8),
              const Text(
                'CANLI TURNUVA AĞACI',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Kaydırılabilir Ağaç 👉',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < data.rounds.length; i++) ...[
                  _BracketColumn(
                    round: data.rounds[i],
                    roundIndex: i,
                    currentUsername: currentUsername,
                    pulseValue: pulseValue,
                    onMatchTap: onMatchTap,
                  ),
                  if (i < data.rounds.length - 1)
                    _BracketConnectorColumn(
                      hasWinner: data.rounds[i].matches.any((m) => m.winner.isNotEmpty),
                      pulseValue: pulseValue,
                    ),
                ],
                const SizedBox(width: 12),
                _FinalChampionColumn(
                  championName: data.championName,
                  pulseValue: pulseValue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single round column inside the tournament tree.
class _BracketColumn extends StatelessWidget {
  const _BracketColumn({
    required this.round,
    required this.roundIndex,
    required this.currentUsername,
    required this.pulseValue,
    required this.onMatchTap,
  });

  final PvpTournamentRound round;
  final int roundIndex;
  final String currentUsername;
  final double pulseValue;
  final void Function(PvpTournamentMatch match, String roundTitle) onMatchTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 184,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Round Title Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2538),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
            ),
            child: Text(
              round.title.isEmpty ? 'Tur ${roundIndex + 1}' : round.title,
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          for (final m in round.matches) ...[
            _MatchCard(
              match: m,
              currentUsername: currentUsername,
              pulseValue: pulseValue,
              onTap: () => onMatchTap(m, round.title),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// Dynamic Bracket Connector Column connecting adjacent rounds.
class _BracketConnectorColumn extends StatelessWidget {
  const _BracketConnectorColumn({
    required this.hasWinner,
    required this.pulseValue,
  });

  final bool hasWinner;
  final double pulseValue;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 120,
      child: CustomPaint(
        painter: _BracketConnectorPainter(
          hasWinner: hasWinner,
          pulseValue: pulseValue,
        ),
      ),
    );
  }
}

class _BracketConnectorPainter extends CustomPainter {
  const _BracketConnectorPainter({
    required this.hasWinner,
    required this.pulseValue,
  });

  final bool hasWinner;
  final double pulseValue;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Paint baseLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final Paint glowLine = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.40 + 0.30 * pulseValue)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final double midX = w / 2;
    final Path path = Path();
    path.moveTo(0, h * 0.25);
    path.lineTo(midX, h * 0.25);
    path.lineTo(midX, h * 0.75);
    path.moveTo(0, h * 0.75);
    path.lineTo(midX, h * 0.75);
    path.moveTo(midX, h * 0.5);
    path.lineTo(w, h * 0.5);

    canvas.drawPath(path, hasWinner ? glowLine : baseLine);
  }

  @override
  bool shouldRepaint(covariant _BracketConnectorPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue || oldDelegate.hasWinner != hasWinner;
  }
}

/// Glassmorphic Match Card displaying combatants, scores, status, and victor crowns.
class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.currentUsername,
    required this.pulseValue,
    required this.onTap,
  });

  final PvpTournamentMatch match;
  final String currentUsername;
  final double pulseValue;
  final VoidCallback onTap;

  bool get _isLive => match.status == 'active' || match.status == 'in_progress';
  bool get _isFinished => match.winner.isNotEmpty || match.status == 'completed';
  bool get _isMyMatch =>
      currentUsername.isNotEmpty && (match.p1 == currentUsername || match.p2 == currentUsername);

  Widget _buildPlayerRow(String name, int score, bool isWinner) {
    final bool isMe = currentUsername.isNotEmpty && name == currentUsername;

    return Container(
      color: isWinner ? const Color(0xFFFFD700).withValues(alpha: 0.12) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          // Player indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isWinner
                  ? const Color(0xFFFFD700)
                  : isMe
                      ? const Color(0xFF00E5FF)
                      : Colors.white24,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isMe ? '$name (Sen)' : name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isWinner || isMe ? FontWeight.w800 : FontWeight.w500,
                color: isWinner
                    ? const Color(0xFFFFD700)
                    : isMe
                        ? const Color(0xFF38BDF8)
                        : Colors.white70,
              ),
            ),
          ),
          if (isWinner)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Text('👑', style: TextStyle(fontSize: 10)),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isWinner
                  ? const Color(0xFFD97706)
                  : Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isWinner
                    ? const Color(0xFFFFD700)
                    : Colors.white12,
              ),
            ),
            child: Text(
              '$score',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isWinner ? Colors.white : Colors.white60,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF181F30).withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isMyMatch
                ? const Color(0xFF00E5FF)
                : _isLive
                    ? const Color(0xFFFF1744).withValues(alpha: 0.6 + 0.3 * pulseValue)
                    : _isFinished
                        ? const Color(0xFFFFD700).withValues(alpha: 0.35)
                        : Colors.white12,
            width: _isMyMatch || _isLive ? 1.5 : 1.0,
          ),
          boxShadow: [
            if (_isMyMatch)
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                blurRadius: 10,
              )
            else if (_isLive)
              BoxShadow(
                color: const Color(0xFFFF1744).withValues(alpha: 0.25 * pulseValue),
                blurRadius: 10,
              )
            else
              const BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Match Card Header with status chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: Colors.black26,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MAÇ #${match.id}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white38,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (_isLive)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFF1744),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF1744).withValues(alpha: 0.8),
                                  blurRadius: 4,
                                )
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'CANLI',
                            style: TextStyle(
                              color: Color(0xFFFF5252),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      )
                    else if (_isFinished)
                      const Text(
                        'TAMAMLANDI',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else
                      const Text(
                        'BEKLİYOR',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              _buildPlayerRow(match.p1, match.s1, match.winner == match.p1),
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              _buildPlayerRow(match.p2, match.s2, match.winner == match.p2),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grand Champion Pedestal at the pinnacle of the tournament tree.
class _FinalChampionColumn extends StatelessWidget {
  const _FinalChampionColumn({
    required this.championName,
    required this.pulseValue,
  });

  final String championName;
  final double pulseValue;

  @override
  Widget build(BuildContext context) {
    final bool hasChampion = championName.isNotEmpty;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '👑 ŞAMPİYON',
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 130,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: hasChampion
                  ? <Color>[
                      const Color(0xFFD97706),
                      const Color(0xFF92400E),
                      const Color(0xFF451A03),
                    ]
                  : <Color>[
                      const Color(0xFF1E2536),
                      const Color(0xFF141926),
                    ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.6 + 0.3 * pulseValue),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.35 * pulseValue),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GladiatorTierEmblem(
                tier: GladiatorTier.grandmaster,
                size: 38,
                showGlow: true,
              ),
              const SizedBox(height: 8),
              Text(
                hasChampion ? championName : 'Taht Sahipsiz',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasChampion ? 'Abyssal Şampiyonu' : 'Savaş Devam Ediyor',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: hasChampion ? const Color(0xFFFDE68A) : Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Match Detail Bottom Sheet showing head-to-head combatants, match juice, and outcomes.
class _MatchDetailSheet extends StatelessWidget {
  const _MatchDetailSheet({
    required this.match,
    required this.roundTitle,
  });

  final PvpTournamentMatch match;
  final String roundTitle;

  @override
  Widget build(BuildContext context) {
    final bool isP1Winner = match.winner == match.p1;
    final bool isP2Winner = match.winner == match.p2;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121622),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 30, offset: Offset(0, -6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⚔️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                '$roundTitle — Maç #${match.id}'.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Head-to-Head Clash Layout
          Row(
            children: [
              // Player 1
              Expanded(
                child: _PlayerClashCard(
                  name: match.p1,
                  score: match.s1,
                  isWinner: isP1Winner,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    Text('VS',
                        style: TextStyle(
                          color: Color(0xFFFF1744),
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 1.5,
                        )),
                    SizedBox(height: 4),
                    Text('Bo3', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ),
              // Player 2
              Expanded(
                child: _PlayerClashCard(
                  name: match.p2,
                  score: match.s2,
                  isWinner: isP2Winner,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Match Result & Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                if (match.winner.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('👑', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        'Galip: ${match.winner}',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Kazanan gladyatör bir üst tura yükseldi!',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ] else if (match.status == 'active' || match.status == 'in_progress') ...[
                  const Text(
                    '⚔️ Karşılaşma Devam Ediyor',
                    style: TextStyle(
                      color: Color(0xFFFF5252),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Raunt skorları anlık olarak güncelleniyor.',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ] else ...[
                  const Text(
                    '⌛ Karşılaşma Beklemede',
                    style: TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Önceki eşleşmeler sonuçlandığında maç başlayacaktır.',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Dismiss Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E2538),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Kapat', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerClashCard extends StatelessWidget {
  const _PlayerClashCard({
    required this.name,
    required this.score,
    required this.isWinner,
  });

  final String name;
  final int score;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWinner
            ? const Color(0xFFD97706).withValues(alpha: 0.2)
            : const Color(0xFF161C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWinner ? const Color(0xFFFFD700) : Colors.white12,
          width: isWinner ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isWinner ? const Color(0xFFD97706) : const Color(0xFF1F2937),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isWinner ? FontWeight.w900 : FontWeight.w600,
              color: isWinner ? const Color(0xFFFFD700) : Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Skor: $score',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isWinner ? const Color(0xFFFBBF24) : Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}

/// Prizes & Rules Showcase with 3-tier podium and tournament guidelines.
class _TournamentPrizesAndRules extends StatelessWidget {
  const _TournamentPrizesAndRules({
    required this.prizePool,
    required this.formattedGold,
  });

  final int prizePool;
  final String formattedGold;

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
    final int gold1st = (prizePool * 0.50).round();
    final int gold2nd = (prizePool * 0.30).round();
    final int gold3rd = (prizePool * 0.20).round();

    return Column(
      children: [
        // 3-Tier Podium Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141926).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    'Ödül Havuzu Dağılımı ($formattedGold Altın)',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 1st Place Podium Card
              _PodiumTierCard(
                rankBadge: '🥇 1. Sıra (Şampiyon)',
                title: 'Abyssal Grandmaster Unvanı',
                goldReward: '${_formatGold(gold1st)} Altın (50%)',
                borderColor: const Color(0xFFFFD700),
                gradientColors: const <Color>[Color(0xFF452205), Color(0xFF261505)],
              ),
              const SizedBox(height: 10),

              // 2nd Place Podium Card
              _PodiumTierCard(
                rankBadge: '🥈 2. Sıra (Finalist)',
                title: 'Arena Başmuhafızı Unvanı',
                goldReward: '${_formatGold(gold2nd)} Altın (30%)',
                borderColor: const Color(0xFFC0C8D8),
                gradientColors: const <Color>[Color(0xFF252A36), Color(0xFF161A22)],
              ),
              const SizedBox(height: 10),

              // 3rd Place Podium Card
              _PodiumTierCard(
                rankBadge: '🥉 3. Sıra (Yarı Final)',
                title: 'Gladyatör Şövalyesi Unvanı',
                goldReward: '${_formatGold(gold3rd)} Altın (20%)',
                borderColor: const Color(0xFFCD7F32),
                gradientColors: const <Color>[Color(0xFF321D17), Color(0xFF1C110D)],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Tournament Rules Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141926).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '⚔️ Turnuva Kuralları & Format',
                style: TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              _RuleBullet(
                icon: Icons.flash_on,
                text: 'Turnuva tekli eleme (Single Elimination) sistemiyle eşleşmeli olarak oynanır.',
              ),
              _RuleBullet(
                icon: Icons.timer,
                text: 'Her eşleşme 3 raunt üzerinden simüle edilir; en çok raunt alan tur atlar.',
              ),
              _RuleBullet(
                icon: Icons.military_tech,
                text: 'Kayıtlar kapandığında minimum katılımcı sayısı karşılanırsa kura çekilir.',
              ),
              _RuleBullet(
                icon: Icons.card_giftcard,
                text: 'Ödüller şampiyonluk maçı biter bitmez posta kutunuza teslim edilir.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PodiumTierCard extends StatelessWidget {
  const _PodiumTierCard({
    required this.rankBadge,
    required this.title,
    required this.goldReward,
    required this.borderColor,
    required this.gradientColors,
  });

  final String rankBadge;
  final String title;
  final String goldReward;
  final Color borderColor;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor.withValues(alpha: 0.6), width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rankBadge,
                  style: TextStyle(
                    color: borderColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              goldReward,
              style: TextStyle(
                color: borderColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleBullet extends StatelessWidget {
  const _RuleBullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFFFD700)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom Registration & Participation Action Deck with dark-glass glow.
class _TournamentRegistrationDeck extends StatelessWidget {
  const _TournamentRegistrationDeck({
    required this.data,
    required this.isJoining,
    required this.pulseValue,
    required this.onJoinPressed,
  });

  final PvpTournamentData data;
  final bool isJoining;
  final double pulseValue;
  final VoidCallback onJoinPressed;

  @override
  Widget build(BuildContext context) {
    if (!data.registrationOpen) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_clock, size: 16, color: Colors.white38),
            const SizedBox(width: 8),
            Text(
              data.rounds.isNotEmpty
                  ? 'Turnuva Karşılaşmaları Devam Ediyor (Kayıtlar Kapalı)'
                  : 'Kayıtlar Kapalı',
              style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.35 * pulseValue),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isJoining ? null : onJoinPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD97706),
          disabledBackgroundColor: const Color(0xFF78350F),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: const Color(0xFFFFD700).withValues(alpha: 0.6),
              width: 1.2,
            ),
          ),
        ),
        child: isJoining
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sports_kabaddi, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Turnuvaya Katıl (Ücretsiz Giriş)',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
