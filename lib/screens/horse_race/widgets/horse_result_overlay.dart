import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/player_provider.dart';
import '../../../theme/app_colors.dart';
import '../horse_race_provider.dart';
import '../horse_race_utils.dart';
import 'horse_race_design.dart';

/// 2027 Aion 2 Mobile Glassmorphism Victory & Result Overlay
/// Frosted glass modal with celestial winner medallion, luminous payout ticker,
/// and responsive mobile dark fantasy visual juice.
class HorseResultOverlay extends ConsumerStatefulWidget {
  const HorseResultOverlay({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  ConsumerState<HorseResultOverlay> createState() => _HorseResultOverlayState();
}

class _HorseResultOverlayState extends ConsumerState<HorseResultOverlay>
    with SingleTickerProviderStateMixin {
  static const Duration _timeout = Duration(seconds: 15);
  Timer? _retryTimer;
  DateTime? _startedAt;
  bool _timedOut = false;
  bool _hasTriggeredHaptic = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _retryTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _pollResult(),
    );
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _refreshResult() async {
    if (!mounted) return;
    await ref.read(horseRaceProvider.notifier).refresh(silent: true);
    if (!mounted) return;
    await ref.read(playerProvider.notifier).loadProfile();
  }

  Future<void> _pollResult() async {
    if (!mounted) return;
    final HorseRaceBet? bet = ref.read(horseRaceProvider).myBet;
    if (bet?.won != null) {
      if (bet?.won == true && !_hasTriggeredHaptic) {
        _hasTriggeredHaptic = true;
        HapticFeedback.heavyImpact();
      }
      _retryTimer?.cancel();
      if (mounted) setState(() {});
      return;
    }
    if (_startedAt != null &&
        DateTime.now().difference(_startedAt!) >= _timeout) {
      if (mounted) setState(() => _timedOut = true);
      _retryTimer?.cancel();
      return;
    }
    await _refreshResult();
    if (mounted) setState(() {});
  }

  Future<void> _manualRetry() async {
    HapticFeedback.selectionClick();
    setState(() {
      _timedOut = false;
      _startedAt = DateTime.now();
    });
    await _refreshResult();
    if (!mounted) return;
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _pollResult(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final HorseRaceState raceState = ref.watch(horseRaceProvider);
    final String? winnerId = raceState.round.raceScript.winnerId.isNotEmpty
        ? raceState.round.raceScript.winnerId
        : raceState.round.winnerHorseId;
    HorseRaceEntry? winner;
    for (final HorseRaceEntry h in raceState.horses) {
      if (h.horseId == winnerId) {
        winner = h;
        break;
      }
    }

    final HorseRaceBet? bet = raceState.myBet;
    final bool? won = bet?.won;
    if (won == true && !_hasTriggeredHaptic) {
      _hasTriggeredHaptic = true;
      HapticFeedback.heavyImpact();
    }

    final Color accent = won == true
        ? HorseRaceDesign.neon
        : won == false
            ? HorseRaceDesign.ruby
            : HorseRaceDesign.gold;

    return Positioned.fill(
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Fullscreen Frosted Scrim with Dark Gothic Vignette
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.1,
                    colors: <Color>[
                      accent.withValues(alpha: 0.16),
                      HorseRaceDesign.void_.withValues(alpha: 0.86),
                      Colors.black.withValues(alpha: 0.94),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Victory Ambient Radial Aura (when won)
          if (won == true)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (BuildContext context, Widget? child) {
                return Positioned(
                  top: MediaQuery.sizeOf(context).height * 0.22,
                  child: IgnorePointer(
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[
                            HorseRaceDesign.gold.withValues(
                              alpha: 0.28 * _pulseController.value + 0.12,
                            ),
                            HorseRaceDesign.neon.withValues(
                              alpha: 0.15 * _pulseController.value,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          // Main Glassmorphic Result Card
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.45),
                            width: 1.5,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              HorseRaceDesign.navy.withValues(alpha: 0.94),
                              HorseRaceDesign.void_.withValues(alpha: 0.97),
                            ],
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: accent.withValues(alpha: 0.24),
                              blurRadius: 36,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: <Widget>[
                            // Background dot grid
                            const Positioned.fill(
                              child: CustomPaint(
                                painter: DotGridPainter(
                                  spacing: 16,
                                  dotOpacity: 0.05,
                                ),
                              ),
                            ),
                            // Top specular line
                            Positioned(
                              top: 0,
                              left: 30,
                              right: 30,
                              height: 1.5,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: <Color>[
                                      Colors.transparent,
                                      accent.withValues(alpha: 0.6),
                                      Colors.white.withValues(alpha: 0.8),
                                      accent.withValues(alpha: 0.6),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  // Header Pill
                                  _buildHeaderPill(won),
                                  const SizedBox(height: 18),
                                  // Winner Horse Medallion
                                  _buildWinnerMedallion(winner, accent),
                                  const SizedBox(height: 12),
                                  // Winner Name
                                  Text(
                                    winner == null ? '—' : winner.name,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  if (winner != null && winner.winChancePct > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Başlangıç Şansı: %${winner.winChancePct.round()}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: HorseRaceDesign.titanium,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 18),
                                  // Result / Payout Status Card
                                  _buildResultStatusSection(bet, won),
                                  const SizedBox(height: 22),
                                  // Dismiss Button
                                  HorseRaceGoldButton(
                                    label: 'Tamam',
                                    icon: Icons.check_circle_rounded,
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      widget.onDismiss();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderPill(bool? won) {
    final String label;
    final IconData icon;
    final Color color;

    if (won == true) {
      label = 'ŞAMPİYONLUK ZAFERİ';
      icon = Icons.emoji_events_rounded;
      color = HorseRaceDesign.gold;
    } else if (won == false) {
      label = 'YARIŞ TAMAMLANDI';
      icon = Icons.sports_score_rounded;
      color = HorseRaceDesign.ruby;
    } else {
      label = 'YARIŞ SONUCU';
      icon = Icons.hourglass_top_rounded;
      color = HorseRaceDesign.cyan;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWinnerMedallion(HorseRaceEntry? winner, Color accent) {
    return Container(
      width: 88,
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            accent.withValues(alpha: 0.35),
            HorseRaceDesign.navy.withValues(alpha: 0.9),
          ],
        ),
        border: Border.all(
          color: accent.withValues(alpha: 0.65),
          width: 2.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: winner != null
          ? Text(
              winner.emoji,
              style: const TextStyle(fontSize: 44),
            )
          : const Icon(
              Icons.help_outline_rounded,
              color: HorseRaceDesign.titanium,
              size: 40,
            ),
    );
  }

  Widget _buildResultStatusSection(HorseRaceBet? bet, bool? won) {
    if (bet == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: HorseRaceDesign.obsidian.withValues(alpha: 0.5),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: const Text(
          'Bu turda aktif bir bahsin bulunmuyor.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (won == true) {
      return _ModernWinPayoutCard(bet: bet);
    }

    if (won == false) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: HorseRaceDesign.ruby.withValues(alpha: 0.1),
          border: Border.all(
            color: HorseRaceDesign.ruby.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          children: <Widget>[
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.sentiment_dissatisfied_rounded,
                  color: HorseRaceDesign.ruby,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Bu Turda Kaybettin',
                  style: TextStyle(
                    color: HorseRaceDesign.ruby,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Yatırılan miktar: ${bet.currencyType == 'gems' ? '${bet.betAmount} elmas' : '${compactHorseAmount(bet.betAmount)} altın'}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_timedOut) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: HorseRaceDesign.obsidian.withValues(alpha: 0.6),
          border: Border.all(
            color: HorseRaceDesign.gold.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'Sunucu sonucu henüz tamamlayamadı.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            HorseRaceGoldButton(
              label: 'Tekrar Dene',
              icon: Icons.refresh_rounded,
              expand: false,
              onPressed: _manualRetry,
            ),
          ],
        ),
      );
    }

    // Calculating state
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: HorseRaceDesign.obsidian.withValues(alpha: 0.5),
        border: Border.all(
          color: HorseRaceDesign.gold.withValues(alpha: 0.25),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: HorseRaceDesign.gold,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Sonuçlar doğrulanıyor…',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernWinPayoutCard extends StatelessWidget {
  const _ModernWinPayoutCard({required this.bet});

  final HorseRaceBet bet;

  @override
  Widget build(BuildContext context) {
    final bool isGems = bet.currencyType == 'gems';
    final Color currencyColor =
        isGems ? HorseRaceDesign.cyan : HorseRaceDesign.gold;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: HorseRaceDesign.neon.withValues(alpha: 0.45),
          width: 1.2,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            HorseRaceDesign.neon.withValues(alpha: 0.12),
            HorseRaceDesign.gold.withValues(alpha: 0.08),
            HorseRaceDesign.navy.withValues(alpha: 0.8),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: HorseRaceDesign.neon.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.stars_rounded,
                size: 16,
                color: HorseRaceDesign.neon,
              ),
              const SizedBox(width: 6),
              const Text(
                'TOPLAM KAZANÇ',
                style: TextStyle(
                  color: HorseRaceDesign.neon,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.stars_rounded,
                size: 16,
                color: HorseRaceDesign.neon,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                isGems ? Icons.diamond_rounded : Icons.paid_rounded,
                color: currencyColor,
                size: 26,
              ),
              const SizedBox(width: 8),
              Text(
                '+${formatHorsePayout(bet)}',
                style: const TextStyle(
                  color: HorseRaceDesign.neon,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                  fontFeatures: <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                horseCurrencyLabel(bet.currencyType),
                style: TextStyle(
                  color: currencyColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: currencyColor.withValues(alpha: 0.14),
              border: Border.all(
                color: currencyColor.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              'Çarpan: x${bet.multiplier.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: currencyColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
