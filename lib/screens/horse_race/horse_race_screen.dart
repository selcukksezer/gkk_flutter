import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../utils/logout_helper.dart';
import '../../l10n/l10n.dart';
import 'horse_race_live_view.dart';
import 'horse_race_provider.dart';
import 'widgets/horse_bet_panel.dart';
import 'widgets/horse_race_design.dart';
import 'widgets/horse_result_overlay.dart';

class HorseRaceScreen extends ConsumerStatefulWidget {
  const HorseRaceScreen({super.key});

  @override
  ConsumerState<HorseRaceScreen> createState() => _HorseRaceScreenState();
}

class _HorseRaceScreenState extends ConsumerState<HorseRaceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TutorialTriggers.onRouteEnter(ref, AppRoutes.horseRace);
    });
  }

  Future<void> _confirmExitLiveRace() async {
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.spaceNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Canlı yarışı bırak?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'Yarış arka planda devam eder. Bahis ekranına döneceksin.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HorseRaceDesign.gold,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Bırak',
              style: TextStyle(color: HorseRaceDesign.void_),
            ),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      ref.read(horseRaceProvider.notifier).dismissLiveRace();
    }
  }

  @override
  Widget build(BuildContext context) {
    final HorseRaceState raceState = ref.watch(horseRaceProvider);
    final bool isBetting =
        raceState.round.phase == HorseRacePhase.betting &&
        raceState.myBet == null;
    final bool showLive = raceState.uiPhase == HorseRaceUiPhase.live;
    final bool showResult = raceState.uiPhase == HorseRaceUiPhase.result;

    return Scaffold(
      backgroundColor: HorseRaceDesign.void_,
      appBar: showLive
          ? null
          : GameTopBar(
              title: context.l10n.at_yarisi,
              onLogout: () async => performLogout(ref),
            ),
      extendBody: !showLive,
      bottomNavigationBar: raceState.isImmersiveUi
          ? null
          : GameBottomBar(
              currentRoute: AppRoutes.horseRace,
              onLogout: () async => performLogout(ref),
            ),
      body: showLive
          ? HorseRaceLiveView(
              horses: raceState.horses,
              raceScript: raceState.round.raceScript,
              winnerHorseId: raceState.round.winnerHorseId,
              myBet: raceState.myBet,
              onRequestExit: _confirmExitLiveRace,
              onFinished: () {
                ref.read(horseRaceProvider.notifier).showResultOverlay();
                ref.read(playerProvider.notifier).loadProfile();
              },
            )
          : HorseRaceBackdrop(
              child: Stack(
                children: <Widget>[
                  if (raceState.loading && raceState.horses.isEmpty)
                    const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: HorseRaceDesign.gold,
                      ),
                    )
                  else if (raceState.error != null && raceState.horses.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: HorseRaceNeonPanel(
                          accent: HorseRaceDesign.ruby,
                          child: Text(
                            raceState.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    HorseBetPanel(
                      raceState: raceState,
                      isBetting: isBetting,
                      bettingRoundId: raceState.activeBettingRoundId,
                    ),
                  if (showResult)
                    HorseResultOverlay(
                      onDismiss: () => ref
                          .read(horseRaceProvider.notifier)
                          .dismissResultOverlay(),
                    ),
                ],
              ),
            ),
    );
  }
}
