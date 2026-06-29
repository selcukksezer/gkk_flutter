import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_chrome.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import 'horse_race_live_view.dart';
import 'horse_race_provider.dart';
import '../../l10n/l10n.dart';

Color _parseColor(String raw) {
  final String hex = raw.replaceAll('#', '');
  if (hex.length == 6) {
    final int? value = int.tryParse('FF$hex', radix: 16);
    if (value != null) return Color(value);
  }
  return AppColors.accentBlue;
}

String _compact(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}

String _formatGems(num value) {
  final double v = value.toDouble();
  final double abs = v.abs();
  if (abs >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (abs >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2);
}

String _formatPayout(HorseRaceBet bet) {
  if (bet.currencyType == 'gems') {
    return _formatGems(bet.payoutAmount);
  }
  return _compact(bet.payoutAmount.round());
}

String _currencyLabel(String currencyType) {
  return currencyType == 'gems' ? 'Elmas' : 'Altin';
}

String _formatCountdown(int seconds) {
  final int m = seconds ~/ 60;
  final int s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

class HorseRaceScreen extends ConsumerStatefulWidget {
  const HorseRaceScreen({super.key});

  @override
  ConsumerState<HorseRaceScreen> createState() => _HorseRaceScreenState();
}

class _HorseRaceScreenState extends ConsumerState<HorseRaceScreen> {
  static const List<int> _goldPresets = <int>[10000, 50000, 100000, 500000, 1000000];
  static const List<int> _gemPresets = <int>[1, 5, 10, 25, 50];
  static const int _horseGridCrossCount = 2;
  static const double _horseGridSpacing = 6;
  static const double _horseGridAspect = 2.65;
  static const int _winnerGridCrossCount = 2;
  static const double _winnerGridSpacing = 6;
  static const double _winnerGridAspect = 4.4;

  String _currency = 'gold';
  String? _selectedHorseId;
  int _betAmount = 10000;
  bool _placingBet = false;

  String? _lastRacingRoundId;
  String? _bettingRoundId;
  String? _dismissedResultRoundId;
  bool _showingLiveRace = false;
  bool _showingResult = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<HorseRaceState>(horseRaceProvider, (
      HorseRaceState? prev,
      HorseRaceState next,
    ) {
      _syncPhaseFromState(next);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPhaseFromState(ref.read(horseRaceProvider));
    });
  }

  @override
  Widget build(BuildContext context) {
    final HorseRaceState raceState = ref.watch(horseRaceProvider);

    final bool isBetting =
        raceState.round.phase == HorseRacePhase.betting && raceState.myBet == null;
    final bool immersiveRace = _showingLiveRace;

    return Scaffold(
      appBar: immersiveRace
          ? null
          : GameTopBar(
              title: context.l10n.at_yarisi,
              onLogout: () async {
                await ref.read(authProvider.notifier).logout();
                ref.read(playerProvider.notifier).clear();
              },
            ),
      extendBody: !immersiveRace,
      bottomNavigationBar: (_showingLiveRace || _showingResult)
          ? null
          : GameBottomBar(
              currentRoute: AppRoutes.horseRace,
              onLogout: () async {
                await ref.read(authProvider.notifier).logout();
                ref.read(playerProvider.notifier).clear();
              },
            ),
      body: _showingLiveRace
          ? _buildLiveRaceOverlay(raceState)
          : Stack(
              children: <Widget>[
                ColoredBox(
                  color: AppColors.bgDeep,
                  child: raceState.loading && raceState.horses.isEmpty
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : raceState.error != null && raceState.horses.isEmpty
                      ? Center(
                          child: Text(
                            raceState.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        )
                      : _buildBody(raceState, isBetting),
                ),
                if (_showingResult) _buildResultOverlay(raceState),
              ],
            ),
    );
  }

  void _syncPhaseFromState(HorseRaceState next) {
    final HorseRacePhase phase = next.round.phase;
    final String roundId = next.round.id;

    if (phase == HorseRacePhase.racing &&
        roundId.isNotEmpty &&
        _lastRacingRoundId != roundId) {
      _lastRacingRoundId = roundId;
      if (mounted) {
        setState(() {
          _showingLiveRace = true;
          _showingResult = false;
        });
      }
      return;
    }

    if (phase == HorseRacePhase.finished &&
        !_showingLiveRace &&
        !_showingResult &&
        roundId.isNotEmpty &&
        _dismissedResultRoundId != roundId) {
      if (mounted) setState(() => _showingResult = true);
      return;
    }

    if (phase == HorseRacePhase.betting) {
      final bool newRound = roundId.isNotEmpty && _bettingRoundId != roundId;
      if (mounted) {
        setState(() {
          _showingLiveRace = false;
          _showingResult = false;
          if (newRound) {
            _bettingRoundId = roundId;
            _selectedHorseId = null;
          }
        });
      }
    }
  }

  Widget _buildBody(HorseRaceState raceState, bool isBetting) {
    final double bottomClearance = gameBottomBarClearance(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(12, 6, 12, bottomClearance + 8),
      children: <Widget>[
        _buildStatusStrip(raceState),
        if (isBetting) ...<Widget>[
          const SizedBox(height: 6),
          _buildControlsRow(raceState),
        ],
        const SizedBox(height: 6),
        _buildHorseSection(raceState, isBetting),
        if (raceState.myBet != null) ...<Widget>[
          const SizedBox(height: 6),
          _buildMyBetLine(raceState),
        ],
        if (raceState.recentWinners.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          _buildRecentWinners(raceState),
        ],
      ],
    );
  }

  Widget _buildStatusStrip(HorseRaceState raceState) {
    final HorseRacePhase phase = raceState.round.phase;
    final int left = raceState.round.secondsLeft;

    final String label = switch (phase) {
      HorseRacePhase.betting => _formatCountdown(left),
      HorseRacePhase.locked => 'Kapaniyor',
      HorseRacePhase.racing => 'Yaris',
      HorseRacePhase.finished => _formatCountdown(left),
      HorseRacePhase.unknown => '--:--',
    };

    final Color accent = switch (phase) {
      HorseRacePhase.betting => AppColors.success,
      HorseRacePhase.racing => AppColors.gold,
      HorseRacePhase.finished => AppColors.accentBlue,
      _ => AppColors.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderFaint),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.timer_outlined, size: 16, color: accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          Text(
            _phaseLabel(phase),
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _phaseLabel(HorseRacePhase phase) {
    return switch (phase) {
      HorseRacePhase.betting => 'Bahis acik',
      HorseRacePhase.locked => 'Kilit',
      HorseRacePhase.racing => 'Canli',
      HorseRacePhase.finished => 'Sonuc',
      HorseRacePhase.unknown => '',
    };
  }

  Widget _buildControlsRow(HorseRaceState raceState) {
    final List<int> presets = _currency == 'gems' ? _gemPresets : _goldPresets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _pillToggle('gold', Icons.paid_rounded, AppColors.gold),
            const SizedBox(width: 6),
            _pillToggle('gems', Icons.diamond_outlined, AppColors.accentCyan),
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: presets.map((int amount) {
              final bool selected = _betAmount == amount;
              final String label =
                  _currency == 'gems' ? '$amount' : _compact(amount);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(label, style: const TextStyle(fontSize: 12)),
                  selected: selected,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onSelected: _placingBet ? null : (_) => setState(() => _betAmount = amount),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _pillToggle(String value, IconData icon, Color color) {
    final bool selected = _currency == value;
    return Expanded(
      child: Material(
        color: selected ? color.withValues(alpha: 0.14) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: _placingBet
              ? null
              : () => setState(() {
                  _currency = value;
                  _betAmount = value == 'gems' ? _gemPresets.first : _goldPresets.first;
                }),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? color.withValues(alpha: 0.5) : AppColors.borderFaint,
              ),
            ),
            child: Icon(icon, size: 18, color: selected ? color : AppColors.textTertiary),
          ),
        ),
      ),
    );
  }

  double _gridHeight({
    required double width,
    required int itemCount,
    required int crossCount,
    required double spacing,
    required double aspectRatio,
  }) {
    if (itemCount <= 0) return 0;
    final double cellWidth = (width - spacing) / crossCount;
    final double cellHeight = cellWidth / aspectRatio;
    final int rows = (itemCount / crossCount).ceil();
    return rows * cellHeight + (rows - 1) * spacing;
  }

  Widget _buildHorseSection(HorseRaceState raceState, bool isBetting) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double gridHeight = _gridHeight(
          width: constraints.maxWidth,
          itemCount: raceState.horses.length,
          crossCount: _horseGridCrossCount,
          spacing: _horseGridSpacing,
          aspectRatio: _horseGridAspect,
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: gridHeight,
              child: _buildHorseGrid(raceState, isBetting),
            ),
            if (isBetting) ...<Widget>[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: _buildBetButton(raceState),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHorseGrid(HorseRaceState raceState, bool canSelect) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _horseGridCrossCount,
        mainAxisSpacing: _horseGridSpacing,
        crossAxisSpacing: _horseGridSpacing,
        childAspectRatio: _horseGridAspect,
      ),
      itemCount: raceState.horses.length,
      itemBuilder: (BuildContext context, int index) {
        final HorseRaceEntry horse = raceState.horses[index];
        final bool selected = _selectedHorseId == horse.horseId;
        final double mult =
            _currency == 'gems' ? horse.gemMultiplier : horse.goldMultiplier;
        final Color lane = _parseColor(horse.laneColor);
        final Color multColor = _currency == 'gems' ? AppColors.accentCyan : AppColors.gold;

        return Material(
          color: selected ? lane.withValues(alpha: 0.12) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: canSelect ? () => setState(() => _selectedHorseId = horse.horseId) : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? lane : AppColors.borderFaint,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Text(horse.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          horse.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'x${mult.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: multColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBetButton(HorseRaceState raceState) {
    final bool canBet =
        _selectedHorseId != null && !_placingBet && raceState.round.id.isNotEmpty;

    return FilledButton(
      onPressed: canBet ? () => _placeBet(raceState) : null,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
        disabledBackgroundColor: AppColors.bgCardElevated,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: _placingBet
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
            )
          : const Text(
              'Bahis Yap',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
    );
  }

  Future<void> _placeBet(HorseRaceState raceState) async {
    if (_selectedHorseId == null) return;
    setState(() => _placingBet = true);
    try {
      final Map<String, dynamic> res = await ref.read(horseRaceProvider.notifier).placeBet(
        roundId: raceState.round.id,
        horseId: _selectedHorseId!,
        currency: _currency,
        amount: _betAmount,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        AppMessenger.showSuccess(context, 'Bahis alindi');
        await ref.read(playerProvider.notifier).loadProfile();
      } else {
        AppMessenger.showError(context, res['message']?.toString() ?? 'Bahis basarisiz');
      }
    } catch (e) {
      if (mounted) AppMessenger.showError(context, '$e');
    } finally {
      if (mounted) setState(() => _placingBet = false);
    }
  }

  Widget _buildMyBetLine(HorseRaceState raceState) {
    final HorseRaceBet bet = raceState.myBet!;
    HorseRaceEntry? horse;
    for (final HorseRaceEntry h in raceState.horses) {
      if (h.horseId == bet.horseId) {
        horse = h;
        break;
      }
    }
    final String name = horse?.name ?? bet.horseId;
    final String amt = bet.currencyType == 'gems'
        ? '${_formatGems(bet.betAmount)} elmas'
        : '${_compact(bet.betAmount)} altin';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderFaint),
      ),
      child: Text(
        'Bahsin: $name · $amt · x${bet.multiplier.toStringAsFixed(2)}',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    );
  }

  Widget _buildRecentWinners(HorseRaceState raceState) {
    final List<HorseRaceRecentWinner> winners =
        raceState.recentWinners.take(30).toList(growable: false);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double gridHeight = _gridHeight(
          width: constraints.maxWidth,
          itemCount: winners.length,
          crossCount: _winnerGridCrossCount,
          spacing: _winnerGridSpacing,
          aspectRatio: _winnerGridAspect,
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.emoji_events_outlined, size: 14, color: AppColors.gold),
                const SizedBox(width: 6),
                const Text(
                  'Son Kazananlar',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '${winners.length}',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: gridHeight,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _winnerGridCrossCount,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: _winnerGridSpacing,
                  childAspectRatio: _winnerGridAspect,
                ),
                itemCount: winners.length,
                itemBuilder: (BuildContext context, int index) {
                  final HorseRaceRecentWinner w = winners[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderFaint),
                    ),
                    child: Row(
                      children: <Widget>[
                        Text(w.winnerEmoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            w.winnerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLiveRaceOverlay(HorseRaceState raceState) {
    return HorseRaceLiveView(
      horses: raceState.horses,
      raceScript: raceState.round.raceScript,
      winnerHorseId: raceState.round.winnerHorseId,
      myBet: raceState.myBet,
      onFinished: () {
        if (!mounted) return;
        setState(() {
          _showingLiveRace = false;
          _showingResult = true;
        });
        ref.read(playerProvider.notifier).loadProfile();
      },
    );
  }

  Widget _buildWinPayout(HorseRaceBet bet) {
    final bool isGems = bet.currencyType == 'gems';
    final Color color = isGems ? AppColors.accentCyan : AppColors.gold;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text(
          'Kazandin',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isGems ? Icons.diamond_rounded : Icons.paid_rounded,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              '+${_formatPayout(bet)}',
              style: TextStyle(
                color: AppColors.success,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFeatures: isGems
                    ? const <FontFeature>[FontFeature.tabularFigures()]
                    : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _currencyLabel(bet.currencyType),
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultOverlay(HorseRaceState raceState) {
    final String? winnerId = raceState.round.winnerHorseId;
    HorseRaceEntry? winner;
    for (final HorseRaceEntry h in raceState.horses) {
      if (h.horseId == winnerId) {
        winner = h;
        break;
      }
    }

    final HorseRaceBet? bet = raceState.myBet;
    final bool? won = bet?.won;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                winner == null ? '—' : '${winner.emoji} ${winner.name}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              if (bet == null)
                const Text('Bahis yok', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
              else if (won == true)
                _buildWinPayout(bet)
              else if (won == false)
                const Text('Kaybettin', style: TextStyle(color: AppColors.danger, fontSize: 14))
              else
                const Text('...', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: FilledButton(
                  onPressed: () => setState(() {
                    _showingResult = false;
                    _dismissedResultRoundId = raceState.round.id;
                  }),
                  child: const Text('Tamam'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
