import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/common/app_messenger.dart';
import '../../../components/layout/game_chrome.dart';
import '../../../core/services/graphics_quality_service.dart';
import '../../../core/tutorial/tutorial_anchor.dart';
import '../../../core/tutorial/tutorial_track.dart';
import '../../../core/tutorial/tutorial_triggers.dart';
import '../../../providers/player_provider.dart';
import '../../../theme/app_colors.dart';
import '../horse_race_provider.dart';
import '../horse_race_utils.dart';
import 'horse_race_design.dart';
import 'horse_recent_winners_panel.dart';

/// Premium betting board — /tasarim dot doku + Liquid Gold CTA.
class HorseBetPanel extends ConsumerStatefulWidget {
  const HorseBetPanel({
    super.key,
    required this.raceState,
    required this.isBetting,
    required this.bettingRoundId,
  });

  final HorseRaceState raceState;
  final bool isBetting;
  final String? bettingRoundId;

  @override
  ConsumerState<HorseBetPanel> createState() => HorseBetPanelState();
}

class HorseBetPanelState extends ConsumerState<HorseBetPanel> {
  static const List<int> goldPresets = <int>[
    10000,
    50000,
    100000,
    500000,
    1000000,
  ];
  static const List<int> gemPresets = <int>[1, 5, 10, 25, 50];
  static const double horseGridAspect = 1.05;
  static const double horseCellMinHeight = 148;
  static const int horseGridCrossCount = 2;
  static const double horseGridSpacing = 10;

  String _currency = 'gold';
  String? _selectedHorseId;
  int _betAmount = 10000;
  bool _placingBet = false;
  bool _usingCustomAmount = false;
  String? _customAmountError;
  final TextEditingController _customAmountController = TextEditingController();

  @override
  void didUpdateWidget(covariant HorseBetPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bettingRoundId != null &&
        widget.bettingRoundId != oldWidget.bettingRoundId) {
      _selectedHorseId = null;
    }
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  int _minBet() => _currency == 'gems'
      ? widget.raceState.settings.gemMinBet
      : widget.raceState.settings.goldMinBet;

  int _maxBet() => _currency == 'gems'
      ? widget.raceState.settings.gemMaxBet
      : widget.raceState.settings.goldMaxBet;

  void _selectPresetAmount(int amount) {
    setState(() {
      _betAmount = amount;
      _usingCustomAmount = false;
      _customAmountError = null;
      _customAmountController.clear();
    });
  }

  void _enableCustomAmountInput() {
    if (_usingCustomAmount || _placingBet) return;
    setState(() {
      _usingCustomAmount = true;
      _customAmountError = null;
      if (_customAmountController.text.isEmpty) {
        _customAmountController.text = _betAmount.toString();
      }
    });
    _applyCustomAmount();
  }

  void _applyCustomAmount() {
    final String raw = _customAmountController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _usingCustomAmount = false;
        _customAmountError = null;
      });
      return;
    }

    final HorseBetAmountValidation validation = validateHorseBetAmount(
      raw,
      min: _minBet(),
      max: _maxBet(),
    );
    setState(() {
      _usingCustomAmount = true;
      if (validation.isValid) {
        _betAmount = validation.amount!;
        _customAmountError = null;
      } else {
        _customAmountError = validation.message;
      }
    });
  }

  bool get _canPlaceBet {
    if (_selectedHorseId == null ||
        _placingBet ||
        widget.raceState.round.id.isEmpty) {
      return false;
    }
    final String raw = _customAmountController.text.trim();
    if (raw.isNotEmpty) {
      return validateHorseBetAmount(
        raw,
        min: _minBet(),
        max: _maxBet(),
      ).isValid;
    }
    return _betAmount >= _minBet() && _betAmount <= _maxBet();
  }

  bool _commitBetAmountForSubmit() {
    final String raw = _customAmountController.text.trim();
    if (raw.isEmpty) {
      if (_betAmount < _minBet() || _betAmount > _maxBet()) {
        AppMessenger.showError(
          context,
          'Bahis ${_currency == 'gems' ? '${_minBet()}–${_maxBet()} elmas' : '${compactHorseAmount(_minBet())}–${compactHorseAmount(_maxBet())} altın'} arasında olmalı',
        );
        return false;
      }
      return true;
    }

    final HorseBetAmountValidation validation = validateHorseBetAmount(
      raw,
      min: _minBet(),
      max: _maxBet(),
    );
    if (!validation.isValid) {
      setState(() => _customAmountError = validation.message);
      AppMessenger.showError(context, validation.message ?? 'Geçersiz miktar');
      return false;
    }
    _betAmount = validation.amount!;
    _usingCustomAmount = true;
    return true;
  }

  double mainAxisExtentForWidth(double viewportWidth) {
    return horseGridMainAxisExtent(
      viewportWidth: viewportWidth,
      crossAxisCount: horseGridCrossCount,
      spacing: horseGridSpacing,
      aspectRatio: horseGridAspect,
      minCellHeight: horseCellMinHeight,
    );
  }

  Widget _buildCurrencyToggle() {
    return Row(
      children: <Widget>[
        Expanded(
          child: _currencyTile(
            'gold',
            Icons.paid_rounded,
            HorseRaceDesign.gold,
            'Altın',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _currencyTile(
            'gems',
            Icons.diamond_rounded,
            HorseRaceDesign.cyan,
            'Elmas',
          ),
        ),
      ],
    );
  }

  Widget _currencyTile(String value, IconData icon, Color color, String label) {
    final bool selected = _currency == value;
    return HorseRacePressable(
      onTap: _placingBet
          ? null
          : () => setState(() {
              _currency = value;
              _usingCustomAmount = false;
              _customAmountError = null;
              _customAmountController.clear();
              _betAmount = value == 'gems'
                  ? gemPresets.first
                  : goldPresets.first;
            }),
      child: HorseRaceNeonPanel(
        accent: selected ? color : HorseRaceDesign.obsidian,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        radius: 12,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 18,
              color: selected ? color : HorseRaceDesign.titanium,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: selected ? color : HorseRaceDesign.titanium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildControls() {
    final List<int> presets = _currency == 'gems' ? gemPresets : goldPresets;
    final int minBet = _minBet();
    final int maxBet = _maxBet();
    final Color accent = _currency == 'gems'
        ? HorseRaceDesign.cyan
        : HorseRaceDesign.gold;

    return Column(
      key: const Key('horse_race_bet_controls'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TutorialAnchorScope(
          id: TutorialAnchorId.horseBetPanel,
          child: const HorseRaceSectionHeader(
            title: 'Bahis Paneli',
            subtitle: 'Para birimi ve miktar seç',
            accent: HorseRaceDesign.gold,
          ),
        ),
        const SizedBox(height: 10),
        _buildCurrencyToggle(),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: presets.map((int amount) {
              final bool selected = !_usingCustomAmount && _betAmount == amount;
              final String label = _currency == 'gems'
                  ? '$amount'
                  : compactHorseAmount(amount);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: HorseRacePresetChip(
                  label: label,
                  selected: selected,
                  accent: accent,
                  onTap: _placingBet ? null : () => _selectPresetAmount(amount),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        HorseRaceNeonPanel(
          accent: _customAmountError != null
              ? HorseRaceDesign.ruby
              : (_usingCustomAmount ? accent : HorseRaceDesign.obsidian),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          radius: 12,
          child: TextField(
            controller: _customAmountController,
            enabled: !_placingBet,
            readOnly: !_usingCustomAmount,
            onTap: _enableCustomAmountInput,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(horseBetMaxInputLength(maxBet)),
            ],
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              labelText: 'Kendi miktarım',
              labelStyle: TextStyle(
                color: _customAmountError != null
                    ? HorseRaceDesign.ruby
                    : HorseRaceDesign.titanium,
                fontSize: 12,
              ),
              hintText: _currency == 'gems'
                  ? '$minBet – $maxBet elmas'
                  : '${compactHorseAmount(minBet)} – ${compactHorseAmount(maxBet)} altın',
              hintStyle: TextStyle(
                color: HorseRaceDesign.titanium.withValues(alpha: 0.7),
                fontSize: 12,
              ),
              errorText: _customAmountError,
              errorStyle: const TextStyle(
                color: HorseRaceDesign.ruby,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            onChanged: (_) => _applyCustomAmount(),
            onSubmitted: (_) => _applyCustomAmount(),
          ),
        ),
        const SizedBox(height: 14),
        TutorialAnchorScope(
          id: TutorialAnchorId.horsePlaceBetBtn,
          child: HorseRaceGoldButton(
            label: 'Bahis Yap',
            icon: Icons.sports_motorsports_rounded,
            loading: _placingBet,
            onPressed: _canPlaceBet
                ? () async {
                    await TutorialTriggers.onAnchorTap(
                      ref,
                      TutorialAnchorId.horsePlaceBetBtn,
                    );
                    await _placeBet();
                  }
                : null,
          ),
        ),
      ],
    );
  }

  Widget buildHorseTile(HorseRaceEntry horse, int index) {
    final bool selected = _selectedHorseId == horse.horseId;
    final double mult = _currency == 'gems'
        ? horse.gemMultiplier
        : horse.goldMultiplier;
    final Color lane = parseHorseLaneColor(
      horse.laneColor,
      horseId: horse.horseId,
    );
    final Color multColor = _currency == 'gems'
        ? HorseRaceDesign.cyan
        : HorseRaceDesign.gold;

    return HorseRaceHorseCard(
      horse: horse,
      index: index,
      selected: selected,
      multiplier: mult,
      laneColor: lane,
      multColor: multColor,
      onTap: widget.isBetting
          ? () {
              TutorialTriggers.onAnchorTap(
                ref,
                TutorialAnchorId.horseHorseGrid,
              );
              setState(() => _selectedHorseId = horse.horseId);
            }
          : null,
    );
  }

  Future<void> _placeBet() async {
    if (_selectedHorseId == null) return;
    if (!_commitBetAmountForSubmit()) return;
    final int minBet = _minBet();
    final int maxBet = _maxBet();
    if (_betAmount < minBet || _betAmount > maxBet) {
      AppMessenger.showError(
        context,
        'Bahis ${_currency == 'gems' ? '$minBet–$maxBet elmas' : '${compactHorseAmount(minBet)}–${compactHorseAmount(maxBet)} altın'} arasında olmalı',
      );
      return;
    }
    setState(() => _placingBet = true);
    try {
      final Map<String, dynamic> res = await ref
          .read(horseRaceProvider.notifier)
          .placeBet(
            roundId: widget.raceState.round.id,
            horseId: _selectedHorseId!,
            currency: _currency,
            amount: _betAmount,
          );
      if (!mounted) return;
      if (res['success'] == true) {
        AppMessenger.showSuccess(context, 'Bahis alındı');
        await ref.read(playerProvider.notifier).loadProfile();
      } else {
        AppMessenger.showError(
          context,
          res['message']?.toString() ?? 'Bahis başarısız',
        );
      }
    } catch (e) {
      if (mounted) AppMessenger.showError(context, '$e');
    } finally {
      if (mounted) setState(() => _placingBet = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomClearance = gameBottomBarClearance(context);
    final double gridWidth = MediaQuery.sizeOf(context).width - 28;
    final double extent = mainAxisExtentForWidth(gridWidth);

    return CustomScrollView(
      key: const Key('horse_race_betting_panel'),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate(<Widget>[
              HorseRaceHeroBanner(raceState: widget.raceState),
              const SizedBox(height: 10),
              _RoyalHippodromeArenaPreviewCard(
                horsesCount: widget.raceState.horses.length,
              ),
              if (widget.raceState.myBet != null) ...<Widget>[
                const SizedBox(height: 12),
                HorseRaceMyBetTicket(raceState: widget.raceState),
              ],
              if (widget.isBetting) ...<Widget>[
                const SizedBox(height: 14),
                buildControls(),
              ],
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          sliver: SliverToBoxAdapter(
            child: HorseRaceSectionHeader(
              title: 'Yarış Atları',
              subtitle: widget.isBetting
                  ? 'Bahis için bir at seç'
                  : 'Bu turdaki kadro',
              accent: HorseRaceDesign.fuchsia,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: horseGridCrossCount,
              mainAxisSpacing: horseGridSpacing,
              crossAxisSpacing: horseGridSpacing,
              mainAxisExtent: extent,
            ),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                final Widget tile =
                    buildHorseTile(widget.raceState.horses[index], index);
                if (index != 0) return tile;
                return TutorialAnchorScope(
                  id: TutorialAnchorId.horseHorseGrid,
                  child: tile,
                );
              },
              childCount: widget.raceState.horses.length,
            ),
          ),
        ),
        if (widget.raceState.recentWinners.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(14, 16, 14, bottomClearance + 10),
            sliver: SliverToBoxAdapter(
              child: HorseRecentWinnersPanel(
                winners: widget.raceState.recentWinners,
              ),
            ),
          )
        else
          SliverPadding(padding: EdgeInsets.only(bottom: bottomClearance + 10)),
      ],
    );
  }
}

class _RoyalHippodromeArenaPreviewCard extends StatelessWidget {
  const _RoyalHippodromeArenaPreviewCard({required this.horsesCount});

  final int horsesCount;

  @override
  Widget build(BuildContext context) {
    final GraphicsProfile gfx = GraphicsQualityService.instance.profile;
    final ImageProvider<Object> trackImg = ResizeImage.resizeIfNeeded(
      gfx.isLow ? 420 : 714,
      null,
      const AssetImage('assets/v15/royal_hippodrome_track.jpg'),
    );
    final ImageProvider<Object> crimsonSteed = ResizeImage.resizeIfNeeded(
      gfx.isLow ? 140 : 220,
      null,
      const AssetImage('assets/moradon/steed_crimson_bolt.png'),
    );
    final ImageProvider<Object> shadowSteed = ResizeImage.resizeIfNeeded(
      gfx.isLow ? 140 : 220,
      null,
      const AssetImage('assets/moradon/steed_shadow_mane.png'),
    );

    return Container(
      key: const Key('royal_hippodrome_preview_card'),
      height: 128,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: HorseRaceDesign.gold.withValues(alpha: 0.65),
          width: 1.2,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image(
            image: trackImg,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.25),
            filterQuality: gfx.filterQuality,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0xFF120C06)),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[
                  Color(0xE6070912),
                  Color(0x88070912),
                  Color(0xAA070912),
                ],
              ),
            ),
          ),
          Positioned(
            right: 54,
            bottom: 6,
            width: 82,
            height: 82,
            child: Image(
              image: shadowSteed,
              fit: BoxFit.contain,
              filterQuality: gfx.filterQuality,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 2,
            width: 92,
            height: 92,
            child: Image(
              image: crimsonSteed,
              fit: BoxFit.contain,
              filterQuality: gfx.filterQuality,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 118, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xD91A1105),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: HorseRaceDesign.gold.withValues(alpha: 0.78),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.stadium_rounded,
                        size: 12,
                        color: Color(0xFFFEF08A),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '2.5D KRALİYET HİPODROMU',
                        style: TextStyle(
                          color: Color(0xFFFEF08A),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '$horsesCount Safkan At Padokta Hazır',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Meşaleli 2.5D kum pist • Son düzlük kamera yakınlaştırması',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
