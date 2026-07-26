import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/player_provider.dart';
import '../../../theme/app_colors.dart';
import '../horse_race_provider.dart';
import '../horse_race_utils.dart';
import 'horse_race_design.dart';

class HorseResultOverlay extends ConsumerStatefulWidget {
  const HorseResultOverlay({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  ConsumerState<HorseResultOverlay> createState() => _HorseResultOverlayState();
}

class _HorseResultOverlayState extends ConsumerState<HorseResultOverlay> {
  static const Duration _timeout = Duration(seconds: 15);
  Timer? _retryTimer;
  DateTime? _startedAt;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _retryTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _pollResult(),
    );
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
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
      _retryTimer?.cancel();
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
    final Color accent = won == true
        ? HorseRaceDesign.neon
        : won == false
        ? HorseRaceDesign.ruby
        : HorseRaceDesign.gold;

    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: HorseRaceDesign.void_.withValues(alpha: 0.72),
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: HorseRaceNeonPanel(
              accent: accent,
              padding: const EdgeInsets.all(20),
              radius: 18,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'YARIŞ SONUCU',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: HorseRaceDesign.titanium,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (winner != null)
                    Text(winner.emoji, style: const TextStyle(fontSize: 42))
                  else
                    const Icon(
                      Icons.help_outline_rounded,
                      color: HorseRaceDesign.titanium,
                      size: 36,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    winner == null ? '—' : winner.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (bet == null)
                    const Text(
                      'Bahis yok',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    )
                  else if (won == true)
                    _HorseRaceWinPayout(bet: bet)
                  else if (won == false)
                    const Text(
                      'Kaybettin',
                      style: TextStyle(
                        color: HorseRaceDesign.ruby,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  else if (_timedOut)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text(
                          'Sonuç alınamadı',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        HorseRaceGoldButton(
                          label: 'Tekrar dene',
                          icon: Icons.refresh_rounded,
                          expand: false,
                          onPressed: _manualRetry,
                        ),
                      ],
                    )
                  else
                    const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: HorseRaceDesign.gold,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Sonuç hesaplanıyor…',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 18),
                  HorseRaceGoldButton(
                    label: 'Tamam',
                    icon: Icons.check_rounded,
                    onPressed: widget.onDismiss,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HorseRaceWinPayout extends StatelessWidget {
  const _HorseRaceWinPayout({required this.bet});

  final HorseRaceBet bet;

  @override
  Widget build(BuildContext context) {
    final bool isGems = bet.currencyType == 'gems';
    final Color color = isGems ? HorseRaceDesign.cyan : HorseRaceDesign.gold;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text(
          'KAZANDIN',
          style: TextStyle(
            color: HorseRaceDesign.titanium,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isGems ? Icons.diamond_rounded : Icons.paid_rounded,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              '+${formatHorsePayout(bet)}',
              style: TextStyle(
                color: HorseRaceDesign.neon,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontFeatures: isGems
                    ? const <FontFeature>[FontFeature.tabularFigures()]
                    : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              horseCurrencyLabel(bet.currencyType),
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
