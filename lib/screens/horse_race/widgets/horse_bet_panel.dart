import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/common/app_messenger.dart';
import '../../../components/layout/game_chrome.dart';
import '../../../core/tutorial/tutorial_anchor.dart';
import '../../../core/tutorial/tutorial_track.dart';
import '../../../core/tutorial/tutorial_triggers.dart';
import '../../../models/player_model.dart';
import '../../../providers/player_provider.dart';
import '../../../theme/app_colors.dart';
import '../horse_race_provider.dart';
import '../horse_race_utils.dart';
import 'horse_race_design.dart';
import 'horse_recent_winners_panel.dart';

/// 2027 Aion 2 Mobile Glassmorphism Betting Board
/// Frosted glass bento cards, luminous odds badge tickers, live dynamic
/// betting slip with payout calculations, balance validation, and responsive mobile layout.
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
  static const String _kSlotHighlightAsset =
      'assets/images/aion2_ui/hud_action_bar_slot_highlight.png';
  static const String _kCompassBezelAsset =
      'assets/images/aion2_ui/hud_minimap_compass_bezel.png';

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
    } else if (_selectedHorseId != null) {
      final bool horseExists = widget.raceState.horses.any(
        (HorseRaceEntry h) => h.horseId == _selectedHorseId,
      );
      if (!horseExists) {
        _selectedHorseId = null;
      }
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

  int _getPlayerBalance(PlayerProfile? profile) {
    if (profile == null) return 0;
    return _currency == 'gems' ? profile.gems.toInt() : profile.gold;
  }

  bool _isBalanceInsufficient(PlayerProfile? profile) {
    if (profile == null) return false;
    final int balance = _getPlayerBalance(profile);
    return _betAmount > balance;
  }

  void _selectPresetAmount(int amount) {
    HapticFeedback.selectionClick();
    setState(() {
      _betAmount = amount;
      _usingCustomAmount = false;
      _customAmountError = null;
      _customAmountController.clear();
    });
  }

  void _applyQuickModifier(String type, PlayerProfile? profile) {
    HapticFeedback.selectionClick();
    final int min = _minBet();
    final int max = _maxBet();
    final int balance = _getPlayerBalance(profile);

    int newAmount = _betAmount;
    switch (type) {
      case 'min':
        newAmount = min;
        break;
      case '25%':
        if (profile != null && balance > 0) {
          newAmount = (balance * 0.25).round().clamp(min, max);
        } else {
          newAmount = min;
        }
        break;
      case '50%':
        if (profile != null && balance > 0) {
          newAmount = (balance * 0.50).round().clamp(min, max);
        } else {
          newAmount = (max * 0.50).round().clamp(min, max);
        }
        break;
      case 'max':
        if (profile != null && balance > 0) {
          newAmount = math.min(balance, max);
        } else {
          newAmount = max;
        }
        if (newAmount < min) newAmount = min;
        break;
      case '2x':
        newAmount = math.min(_betAmount * 2, max);
        break;
      case 'half':
        newAmount = math.max((_betAmount / 2).round(), min);
        break;
      case '+10k':
        newAmount = math.min(_betAmount + 10000, max);
        break;
      case '+50k':
        newAmount = math.min(_betAmount + 50000, max);
        break;
      case '+5':
        newAmount = math.min(_betAmount + 5, max);
        break;
      case '+25':
        newAmount = math.min(_betAmount + 25, max);
        break;
    }

    setState(() {
      _betAmount = newAmount;
      _usingCustomAmount = false;
      _customAmountError = null;
      _customAmountController.clear();
    });
  }

  void _enableCustomAmountInput() {
    if (_usingCustomAmount || _placingBet) return;
    HapticFeedback.selectionClick();
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

  bool _canPlaceBet(PlayerProfile? profile) {
    if (_selectedHorseId == null ||
        _placingBet ||
        widget.raceState.round.id.isEmpty) {
      return false;
    }
    final int min = _minBet();
    final int max = _maxBet();
    final String raw = _customAmountController.text.trim();
    int currentAmount = _betAmount;

    if (raw.isNotEmpty) {
      final HorseBetAmountValidation validation = validateHorseBetAmount(
        raw,
        min: min,
        max: max,
      );
      if (!validation.isValid) return false;
      currentAmount = validation.amount!;
    }

    if (currentAmount < min || currentAmount > max) return false;
    if (profile != null && currentAmount > _getPlayerBalance(profile)) {
      return false;
    }
    return true;
  }

  bool _commitBetAmountForSubmit(PlayerProfile? profile) {
    final int min = _minBet();
    final int max = _maxBet();
    final String raw = _customAmountController.text.trim();
    int finalAmount = _betAmount;

    if (raw.isNotEmpty) {
      final HorseBetAmountValidation validation = validateHorseBetAmount(
        raw,
        min: min,
        max: max,
      );
      if (!validation.isValid) {
        setState(() => _customAmountError = validation.message);
        AppMessenger.showError(
          context,
          validation.message ?? 'Geçersiz miktar',
        );
        return false;
      }
      finalAmount = validation.amount!;
      _betAmount = finalAmount;
      _usingCustomAmount = true;
    } else {
      if (_betAmount < min || _betAmount > max) {
        AppMessenger.showError(
          context,
          'Bahis ${_currency == 'gems' ? '$min–$max elmas' : '${compactHorseAmount(min)}–${compactHorseAmount(max)} altın'} arasında olmalı',
        );
        return false;
      }
    }

    if (profile != null) {
      final int balance = _getPlayerBalance(profile);
      if (finalAmount > balance) {
        AppMessenger.showError(
          context,
          'Yetersiz bakiye! Mevcut: ${_currency == 'gems' ? '$balance elmas' : '${compactHorseAmount(balance)} altın'}',
        );
        return false;
      }
    }

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

  Widget _buildCurrencyAndBalanceHeader(PlayerProfile? profile) {
    final int balance = _getPlayerBalance(profile);
    final Color accent =
        _currency == 'gems' ? HorseRaceDesign.cyan : HorseRaceDesign.gold;
    final bool insufficient = _isBalanceInsufficient(profile);

    return Column(
      children: <Widget>[
        Row(
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
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: HorseRaceDesign.navy.withValues(alpha: 0.78),
                border: Border.all(
                  color: insufficient
                      ? HorseRaceDesign.ruby.withValues(alpha: 0.7)
                      : accent.withValues(alpha: 0.35),
                  width: insufficient ? 1.4 : 1.1,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: (insufficient ? HorseRaceDesign.ruby : accent)
                        .withValues(alpha: 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                children: <Widget>[
                  // Top specular highlight streak
                  Positioned(
                    top: 0,
                    left: 16,
                    right: 16,
                    height: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Colors.transparent,
                            (insufficient ? HorseRaceDesign.ruby : accent)
                                .withValues(alpha: 0.45),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (insufficient ? HorseRaceDesign.ruby : accent)
                                .withValues(alpha: 0.15),
                          ),
                          child: Icon(
                            _currency == 'gems'
                                ? Icons.diamond_outlined
                                : Icons.account_balance_wallet_outlined,
                            size: 16,
                            color: insufficient ? HorseRaceDesign.ruby : accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Kullanılabilir Bakiye:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                HorseRaceDesign.titanium.withValues(alpha: 0.9),
                            letterSpacing: 0.2,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          profile != null
                              ? (_currency == 'gems'
                                  ? '$balance 💎'
                                  : '${compactHorseAmount(balance)} 🪙')
                              : '—',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: insufficient ? HorseRaceDesign.ruby : accent,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (insufficient) ...<Widget>[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: HorseRaceDesign.ruby.withValues(alpha: 0.16),
                  border: Border.all(
                    color: HorseRaceDesign.ruby.withValues(alpha: 0.5),
                    width: 1.1,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 15,
                      color: HorseRaceDesign.ruby,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Yetersiz bakiye! Eksik: ${_currency == 'gems' ? '${_betAmount - balance} elmas' : '${compactHorseAmount(_betAmount - balance)} altın'}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: HorseRaceDesign.ruby,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _currencyTile(String value, IconData icon, Color color, String label) {
    final bool selected = _currency == value;
    return HorseRacePressable(
      onTap: _placingBet
          ? null
          : () {
              HapticFeedback.selectionClick();
              setState(() {
                _currency = value;
                _usingCustomAmount = false;
                _customAmountError = null;
                _customAmountController.clear();
                _betAmount =
                    value == 'gems' ? gemPresets.first : goldPresets.first;
              });
            },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.75)
                    : Colors.white.withValues(alpha: 0.12),
                width: selected ? 1.6 : 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: selected
                    ? <Color>[
                        color.withValues(alpha: 0.26),
                        HorseRaceDesign.navy.withValues(alpha: 0.92),
                      ]
                    : <Color>[
                        HorseRaceDesign.obsidian.withValues(alpha: 0.65),
                        HorseRaceDesign.void_.withValues(alpha: 0.85),
                      ],
              ),
              boxShadow: selected
                  ? <BoxShadow>[
                      BoxShadow(
                        color: color.withValues(alpha: 0.28),
                        blurRadius: 16,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  icon,
                  size: 20,
                  color: selected ? color : HorseRaceDesign.titanium,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: selected ? color : HorseRaceDesign.titanium,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickModifiersBar(PlayerProfile? profile, Color accent) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: <Widget>[
          _quickModifierChip('MİN', () => _applyQuickModifier('min', profile), accent),
          const SizedBox(width: 6),
          if (_currency == 'gold') ...<Widget>[
            _quickModifierChip('+10K', () => _applyQuickModifier('+10k', profile), accent),
            const SizedBox(width: 6),
            _quickModifierChip('+50K', () => _applyQuickModifier('+50k', profile), accent),
            const SizedBox(width: 6),
          ] else ...<Widget>[
            _quickModifierChip('+5', () => _applyQuickModifier('+5', profile), accent),
            const SizedBox(width: 6),
            _quickModifierChip('+25', () => _applyQuickModifier('+25', profile), accent),
            const SizedBox(width: 6),
          ],
          _quickModifierChip('2X', () => _applyQuickModifier('2x', profile), accent),
          const SizedBox(width: 6),
          _quickModifierChip('½', () => _applyQuickModifier('half', profile), accent),
          const SizedBox(width: 6),
          _quickModifierChip('%25', () => _applyQuickModifier('25%', profile), accent),
          const SizedBox(width: 6),
          _quickModifierChip('%50', () => _applyQuickModifier('50%', profile), accent),
          const SizedBox(width: 6),
          _quickModifierChip('MAKS', () => _applyQuickModifier('max', profile), accent, isHighlight: true),
        ],
      ),
    );
  }

  Widget _quickModifierChip(
    String label,
    VoidCallback onTap,
    Color accent, {
    bool isHighlight = false,
  }) {
    return HorseRacePressable(
      onTap: _placingBet ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isHighlight
              ? accent.withValues(alpha: 0.22)
              : HorseRaceDesign.navy.withValues(alpha: 0.72),
          border: Border.all(
            color: isHighlight
                ? accent.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.12),
            width: isHighlight ? 1.4 : 1,
          ),
          boxShadow: isHighlight
              ? <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isHighlight ? accent : HorseRaceDesign.titanium,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildBetSlip(HorseRaceEntry? horse, Color accent) {
    if (horse == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: HorseRaceDesign.obsidian.withValues(alpha: 0.55),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
                width: 1,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        HorseRaceDesign.gold.withValues(alpha: 0.2),
                        HorseRaceDesign.obsidian.withValues(alpha: 0.6),
                      ],
                    ),
                    border: Border.all(
                      color: HorseRaceDesign.gold.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.sports_motorsports_outlined,
                    size: 20,
                    color: HorseRaceDesign.gold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Bahis Kuponu',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kupon oluşturmak için aşağıdaki listeden bir at seç',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color:
                              HorseRaceDesign.titanium.withValues(alpha: 0.75),
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
    }

    final double multiplier =
        _currency == 'gems' ? horse.gemMultiplier : horse.goldMultiplier;
    final double potentialPayout = _betAmount * multiplier;
    final double netProfit = math.max(0.0, potentialPayout - _betAmount);
    final Color laneColor = parseHorseLaneColor(
      horse.laneColor,
      horseId: horse.horseId,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accent.withValues(alpha: 0.55),
              width: 1.4,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                accent.withValues(alpha: 0.18),
                HorseRaceDesign.navy.withValues(alpha: 0.94),
                HorseRaceDesign.void_.withValues(alpha: 0.98),
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              // Subtle ambient dot grid
              const Positioned.fill(
                child: CustomPaint(
                  painter: DotGridPainter(spacing: 12, dotOpacity: 0.04),
                ),
              ),
              // Top specular light streak
              Positioned(
                top: 0,
                left: 16,
                right: 16,
                height: 1,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.transparent,
                        accent.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Slip Header
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withValues(alpha: 0.18),
                        ),
                        child: Icon(
                          Icons.confirmation_number_outlined,
                          size: 14,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'CANLI BAHİS KUPONU',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Spacer(),
                      HorseRacePressable(
                        onTap: _placingBet
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedHorseId = null);
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: const Row(
                            children: <Widget>[
                              Icon(
                                Icons.close_rounded,
                                size: 12,
                                color: HorseRaceDesign.titanium,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Kaldır',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: HorseRaceDesign.titanium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Selected Horse Info Row
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: HorseRaceDesign.void_.withValues(alpha: 0.65),
                      border: Border.all(
                        color: laneColor.withValues(alpha: 0.38),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        // Aion 2 Compass Medallion
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: laneColor.withValues(alpha: 0.25),
                                  border: Border.all(
                                    color: laneColor.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Image.asset(
                                    _kCompassBezelAsset,
                                    fit: BoxFit.contain,
                                    color: accent.withValues(alpha: 0.85),
                                    colorBlendMode: BlendMode.srcATop,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                              Text(
                                horse.emoji,
                                style: const TextStyle(fontSize: 19),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                horse.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (horse.winChancePct > 0)
                                Text(
                                  'Kazanma Şansı: %${horse.winChancePct.round()}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: HorseRaceDesign.titanium
                                        .withValues(alpha: 0.85),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Multiplier Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.65),
                              width: 1.2,
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: accent.withValues(alpha: 0.2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Text(
                            'x${multiplier.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: accent,
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Calculation Breakdown Grid
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _buildCalculationCell(
                          label: 'YATIRILAN',
                          value: _currency == 'gems'
                              ? '$_betAmount 💎'
                              : '${compactHorseAmount(_betAmount)} 🪙',
                          color: HorseRaceDesign.titanium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCalculationCell(
                          label: 'TAHMİNİ KAZANÇ',
                          value: _currency == 'gems'
                              ? '${formatHorseGems(potentialPayout)} 💎'
                              : '${compactHorseAmount(potentialPayout.round())} 🪙',
                          color: accent,
                          isBold: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCalculationCell(
                          label: 'NET KÂR',
                          value: _currency == 'gems'
                              ? '+${formatHorseGems(netProfit)}'
                              : '+${compactHorseAmount(netProfit.round())}',
                          color: HorseRaceDesign.neon,
                          isBold: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalculationCell({
    required String label,
    required String value,
    required Color color,
    bool isBold = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
      decoration: BoxDecoration(
        color: HorseRaceDesign.obsidian.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isBold
              ? color.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
          width: isBold ? 1 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: HorseRaceDesign.titanium,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              color: color,
              fontFeatures: const <FontFeature>[
                FontFeature.tabularFigures(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildControls() {
    final PlayerProfile? profile = ref.watch(playerProvider).profile;
    final List<int> presets = _currency == 'gems' ? gemPresets : goldPresets;
    final int minBet = _minBet();
    final int maxBet = _maxBet();
    final Color accent =
        _currency == 'gems' ? HorseRaceDesign.cyan : HorseRaceDesign.gold;
    final HorseRaceEntry? selectedHorse = widget.raceState.horses
        .where((HorseRaceEntry h) => h.horseId == _selectedHorseId)
        .firstOrNull;
    final bool canSubmit = _canPlaceBet(profile);

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
        _buildCurrencyAndBalanceHeader(profile),
        const SizedBox(height: 12),
        // Preset Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
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
        const SizedBox(height: 8),
        // Quick Modifiers Row
        _buildQuickModifiersBar(profile, accent),
        const SizedBox(height: 12),
        // Custom Amount Input
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _customAmountError != null
                      ? HorseRaceDesign.ruby.withValues(alpha: 0.7)
                      : (_usingCustomAmount
                          ? accent.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.1)),
                  width: _usingCustomAmount ? 1.4 : 1,
                ),
                gradient: LinearGradient(
                  colors: <Color>[
                    HorseRaceDesign.navy.withValues(alpha: 0.88),
                    HorseRaceDesign.void_.withValues(alpha: 0.95),
                  ],
                ),
                boxShadow: _usingCustomAmount
                    ? <BoxShadow>[
                        BoxShadow(
                          color: (_customAmountError != null
                                  ? HorseRaceDesign.ruby
                                  : accent)
                              .withValues(alpha: 0.16),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: TextField(
                controller: _customAmountController,
                enabled: !_placingBet,
                readOnly: !_usingCustomAmount,
                onTap: _enableCustomAmountInput,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(
                    horseBetMaxInputLength(maxBet),
                  ),
                ],
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFeatures: <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  labelText: 'Kendi Miktarını Yaz',
                  labelStyle: TextStyle(
                    color: _customAmountError != null
                        ? HorseRaceDesign.ruby
                        : (_usingCustomAmount
                            ? accent
                            : HorseRaceDesign.titanium),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  hintText: _currency == 'gems'
                      ? '$minBet – $maxBet elmas'
                      : '${compactHorseAmount(minBet)} – ${compactHorseAmount(maxBet)} altın',
                  hintStyle: TextStyle(
                    color: HorseRaceDesign.titanium.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                  errorText: _customAmountError,
                  errorStyle: const TextStyle(
                    color: HorseRaceDesign.ruby,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  suffixIcon: _usingCustomAmount
                      ? IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: HorseRaceDesign.titanium,
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _customAmountController.clear();
                              _usingCustomAmount = false;
                              _customAmountError = null;
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (_) => _applyCustomAmount(),
                onSubmitted: (_) => _applyCustomAmount(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Live Bet Slip (Kupon)
        _buildBetSlip(selectedHorse, accent),
        const SizedBox(height: 14),
        TutorialAnchorScope(
          id: TutorialAnchorId.horsePlaceBetBtn,
          child: HorseRaceGoldButton(
            label: 'Bahis Yap',
            icon: Icons.sports_motorsports_rounded,
            loading: _placingBet,
            onPressed: canSubmit
                ? () async {
                    HapticFeedback.mediumImpact();
                    await TutorialTriggers.onAnchorTap(
                      ref,
                      TutorialAnchorId.horsePlaceBetBtn,
                    );
                    if (!mounted) return;
                    await _placeBet(profile);
                  }
                : null,
          ),
        ),
      ],
    );
  }

  Widget buildHorseTile(HorseRaceEntry horse, int index) {
    final bool selected = _selectedHorseId == horse.horseId;
    final double mult =
        _currency == 'gems' ? horse.gemMultiplier : horse.goldMultiplier;
    final Color lane = parseHorseLaneColor(
      horse.laneColor,
      horseId: horse.horseId,
    );
    final Color multColor =
        _currency == 'gems' ? HorseRaceDesign.cyan : HorseRaceDesign.gold;

    return HorseRaceFadeSlide(
      index: index,
      child: HorseRacePressable(
        onTap: widget.isBetting
            ? () {
                HapticFeedback.selectionClick();
                TutorialTriggers.onAnchorTap(
                  ref,
                  TutorialAnchorId.horseHorseGrid,
                );
                if (!mounted) return;
                setState(() => _selectedHorseId = horse.horseId);
              }
            : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? HorseRaceDesign.gold
                      : lane.withValues(alpha: 0.40),
                  width: selected ? 1.8 : 1.1,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: selected
                      ? <Color>[
                          lane.withValues(alpha: 0.28),
                          HorseRaceDesign.gold.withValues(alpha: 0.14),
                          HorseRaceDesign.navy.withValues(alpha: 0.95),
                        ]
                      : <Color>[
                          HorseRaceDesign.navy.withValues(alpha: 0.90),
                          HorseRaceDesign.void_.withValues(alpha: 0.96),
                        ],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: selected
                        ? HorseRaceDesign.gold.withValues(alpha: 0.35)
                        : lane.withValues(alpha: 0.15),
                    blurRadius: selected ? 20 : 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: <Widget>[
                  // Ambient dot texture
                  const Positioned.fill(
                    child: CustomPaint(
                      painter: DotGridPainter(spacing: 12, dotOpacity: 0.04),
                    ),
                  ),
                  // Aion 2 Action Bar Slot Highlight Frame Overlay
                  if (selected)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Image.asset(
                          _kSlotHighlightAsset,
                          fit: BoxFit.fill,
                          color: HorseRaceDesign.gold.withValues(alpha: 0.85),
                          colorBlendMode: BlendMode.srcATop,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  // Top specular highlight streak
                  Positioned(
                    top: 0,
                    left: 10,
                    right: 10,
                    height: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Colors.transparent,
                            (selected ? HorseRaceDesign.gold : lane)
                                .withValues(alpha: 0.45),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      // Top Row: Lane Number & Selection Pill
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: lane.withValues(alpha: 0.24),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: lane.withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '#${index + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: lane,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (selected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                gradient: HorseRaceDesign.goldGradient,
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: HorseRaceDesign.gold
                                        .withValues(alpha: 0.45),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.check_rounded,
                                    size: 11,
                                    color: HorseRaceDesign.void_,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'SEÇİLDİ',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: HorseRaceDesign.void_,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (horse.winChancePct > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: Colors.white.withValues(alpha: 0.06),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Text(
                                '%${horse.winChancePct.round()}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: HorseRaceDesign.titanium
                                      .withValues(alpha: 0.9),
                                  fontFeatures: const <FontFeature>[
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      // 3D Glass Medallion with Compass Bezel
                      Center(
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: <Color>[
                                      lane.withValues(
                                        alpha: selected ? 0.38 : 0.22,
                                      ),
                                      HorseRaceDesign.void_
                                          .withValues(alpha: 0.85),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: (selected
                                            ? HorseRaceDesign.gold
                                            : lane)
                                        .withValues(alpha: 0.55),
                                    width: 1.2,
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: (selected
                                              ? HorseRaceDesign.gold
                                              : lane)
                                          .withValues(alpha: 0.25),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Image.asset(
                                    _kCompassBezelAsset,
                                    fit: BoxFit.contain,
                                    color: selected
                                        ? HorseRaceDesign.gold
                                            .withValues(alpha: 0.9)
                                        : lane.withValues(alpha: 0.7),
                                    colorBlendMode: BlendMode.srcATop,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                              Text(
                                horse.emoji,
                                style: const TextStyle(fontSize: 25),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Horse Name
                      Text(
                        horse.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      // Gold Odds Badge Ticker
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: multColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: multColor.withValues(alpha: 0.5),
                                width: 1,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: multColor.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Text(
                              'x${mult.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: multColor,
                                fontFeatures: const <FontFeature>[
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (selected)
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    HorseRaceDesign.gold.withValues(alpha: 0.2),
                              ),
                              child: const Icon(
                                Icons.stars_rounded,
                                size: 14,
                                color: HorseRaceDesign.gold,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _placeBet([PlayerProfile? profile]) async {
    if (_selectedHorseId == null) return;
    if (!_commitBetAmountForSubmit(profile)) return;
    final int minBet = _minBet();
    final int maxBet = _maxBet();
    if (_betAmount < minBet || _betAmount > maxBet) {
      if (!mounted) return;
      AppMessenger.showError(
        context,
        'Bahis ${_currency == 'gems' ? '$minBet–$maxBet elmas' : '${compactHorseAmount(minBet)}–${compactHorseAmount(maxBet)} altın'} arasında olmalı',
      );
      return;
    }
    if (!mounted) return;
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
        if (!mounted) return;
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
