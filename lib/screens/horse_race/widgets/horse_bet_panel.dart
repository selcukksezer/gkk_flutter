import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/common/app_messenger.dart';
import '../../../components/layout/game_chrome.dart';
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
        const HorseRaceSectionHeader(
          title: 'Bahis Paneli',
          subtitle: 'Para birimi ve miktar seç',
          accent: HorseRaceDesign.gold,
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
        HorseRaceGoldButton(
          label: 'Bahis Yap',
          icon: Icons.sports_motorsports_rounded,
          loading: _placingBet,
          onPressed: _canPlaceBet ? _placeBet : null,
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
          ? () => setState(() => _selectedHorseId = horse.horseId)
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
              (BuildContext context, int index) =>
                  buildHorseTile(widget.raceState.horses[index], index),
              childCount: widget.raceState.horses.length,
            ),
          ),
        ),
        if (widget.raceState.myBet != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            sliver: SliverToBoxAdapter(
              child: HorseRaceMyBetTicket(raceState: widget.raceState),
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
