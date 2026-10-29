import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';

/// Tactical PvP combat skill / stance data model for thumb deck actions.
class PvpCombatSkill {
  const PvpCombatSkill({
    required this.id,
    required this.name,
    required this.icon,
    required this.cooldown,
    required this.accentColor,
    this.description = '',
    this.comboPoints = 1,
  });

  final String id;
  final String name;
  final IconData icon;
  final Duration cooldown;
  final Color accentColor;
  final String description;
  final int comboPoints;
}

/// Ergonomic Mobile Thumb Combat Action Deck.
/// Provides one-handed thumb combat triggers, quick wager steppers, skill cooldown
/// ripples, tactile heavy impact feedback, glowing combo indicators, and smooth
/// micro-animations on skill tap and combo release.
class PvpThumbActionDeck extends StatefulWidget {
  const PvpThumbActionDeck({
    super.key,
    required this.onQuickDuel,
    this.onWagerSelected,
    this.onSkillTriggered,
    this.onComboRelease,
    this.skills,
    this.initialWager = 0,
    this.initialCombo = 0,
    this.maxGold = 10000,
    this.disabled = false,
  });

  /// Primary duel action callback triggered by thumb button.
  final Future<void> Function(int wager) onQuickDuel;

  /// Optional callback invoked when a wager chip is selected.
  final ValueChanged<int>? onWagerSelected;

  /// Optional callback invoked when a combat skill is triggered.
  final ValueChanged<PvpCombatSkill>? onSkillTriggered;

  /// Optional callback invoked when the combo is unleashed on duel start.
  final ValueChanged<int>? onComboRelease;

  /// Custom combat skills list (defaults to 4 gladiator combat skills).
  final List<PvpCombatSkill>? skills;

  /// Initial gold wager amount.
  final int initialWager;

  /// Initial combo streak count.
  final int initialCombo;

  /// Maximum gold profile has available.
  final int maxGold;

  /// Whether the action deck is currently disabled (e.g. low health / hospital).
  final bool disabled;

  @override
  State<PvpThumbActionDeck> createState() => _PvpThumbActionDeckState();
}

class _PvpThumbActionDeckState extends State<PvpThumbActionDeck>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _comboReleaseController;
  late int _selectedWager;
  late int _comboCount;
  bool _submitting = false;
  Timer? _comboDecayTimer;
  Timer? _cooldownTicker;

  // Active cooldown map: skillId -> finish timestamp
  final Map<String, DateTime> _cooldowns = <String, DateTime>{};

  // Cooldown ripple controllers per skill
  final Map<String, AnimationController> _skillRippleControllers =
      <String, AnimationController>{};

  static const int _maxCombo = 4;
  static const List<int> _wagerPresets = <int>[0, 100, 500, 1000];

  static const List<PvpCombatSkill> _defaultSkills = <PvpCombatSkill>[
    PvpCombatSkill(
      id: 'slash',
      name: 'Taarruz',
      icon: Icons.flash_on_rounded,
      cooldown: Duration(milliseconds: 2200),
      accentColor: AppColors.liquidGold,
      description: 'Hızlı darbe & kombo başlatıcı',
      comboPoints: 1,
    ),
    PvpCombatSkill(
      id: 'shield',
      name: 'Kalkan',
      icon: Icons.shield_rounded,
      cooldown: Duration(milliseconds: 3400),
      accentColor: AppColors.accentCyan,
      description: 'Gelen ilk darbeyi soğurur',
      comboPoints: 1,
    ),
    PvpCombatSkill(
      id: 'crit',
      name: 'Kritik',
      icon: Icons.local_fire_department_rounded,
      cooldown: Duration(milliseconds: 4500),
      accentColor: AppColors.cyberFuchsia,
      description: '%150 kritik vuruş gücü',
      comboPoints: 2,
    ),
    PvpCombatSkill(
      id: 'wrath',
      name: 'Gazap',
      icon: Icons.auto_awesome_rounded,
      cooldown: Duration(milliseconds: 6000),
      accentColor: AppColors.toxicNeon,
      description: 'Öfke patlaması & kombo salınımı',
      comboPoints: 2,
    ),
  ];

  List<PvpCombatSkill> get _activeSkills => widget.skills ?? _defaultSkills;

  @override
  void initState() {
    super.initState();
    _selectedWager = widget.initialWager;
    _comboCount = widget.initialCombo.clamp(0, _maxCombo);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _comboReleaseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    for (final PvpCombatSkill skill in _activeSkills) {
      _skillRippleControllers[skill.id] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 650),
      );
    }

    _cooldownTicker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      final DateTime now = DateTime.now();
      bool hasActiveCooldown = false;
      for (final DateTime end in _cooldowns.values) {
        if (end.isAfter(now)) {
          hasActiveCooldown = true;
          break;
        }
      }
      if (hasActiveCooldown) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _comboDecayTimer?.cancel();
    _cooldownTicker?.cancel();
    _pulseController.dispose();
    _comboReleaseController.dispose();
    for (final AnimationController controller in _skillRippleControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _triggerSkill(PvpCombatSkill skill) {
    if (widget.disabled || _submitting) return;

    final DateTime now = DateTime.now();
    final DateTime? cdEnd = _cooldowns[skill.id];

    // Tactile light rejection when skill is still on cooldown
    if (cdEnd != null && cdEnd.isAfter(now)) {
      unawaited(HapticFeedback.lightImpact());
      return;
    }

    // Arm skill cooldown
    _cooldowns[skill.id] = now.add(skill.cooldown);

    // Trigger visual ripple micro-animation
    _skillRippleControllers[skill.id]?.forward(from: 0.0);

    // Tactile hit feedback
    final int newCombo = math.min(_comboCount + skill.comboPoints, _maxCombo);
    if (newCombo >= _maxCombo && _comboCount < _maxCombo) {
      unawaited(HapticFeedback.heavyImpact());
    } else {
      unawaited(HapticFeedback.mediumImpact());
    }

    setState(() {
      _comboCount = newCombo;
    });

    widget.onSkillTriggered?.call(skill);

    // Auto-decay combo after 8 seconds of inactivity
    _comboDecayTimer?.cancel();
    _comboDecayTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && _comboCount > 0) {
        setState(() => _comboCount = 0);
      }
    });
  }

  Future<void> _triggerDuel() async {
    if (_submitting || widget.disabled) return;
    setState(() => _submitting = true);

    // Tactile heavy impact on duel start trigger
    await HapticFeedback.heavyImpact();

    // If combo was active, release burst and deliver secondary vibration feedback
    if (_comboCount > 0) {
      unawaited(Future<void>.delayed(const Duration(milliseconds: 90), () {
        HapticFeedback.vibrate();
      }));
      _comboReleaseController.forward(from: 0.0);
      widget.onComboRelease?.call(_comboCount);
    }

    try {
      await widget.onQuickDuel(_selectedWager);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _comboCount = 0; // Combo consumed into duel initiation
        });
      }
    }
  }

  String _getComboBadgeText() {
    return switch (_comboCount) {
      0 => 'Kombo: Hazır',
      1 => '⚡ 1x Hızlı Vuruş (+10%)',
      2 => '🔥 2x Öfke (+25%)',
      3 => '💥 3x Ezici (+50%)',
      _ => '🌟 MAX KOMBO (+75%)',
    };
  }

  Color _getComboAccentColor() {
    return switch (_comboCount) {
      0 => AppColors.liquidGold,
      1 => AppColors.accentCyan,
      2 => AppColors.coralFlare,
      3 => AppColors.cyberFuchsia,
      _ => AppColors.toxicNeon,
    };
  }

  @override
  Widget build(BuildContext context) {
    final Color comboColor = _getComboAccentColor();
    final bool isMaxCombo = _comboCount >= _maxCombo;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (BuildContext context, Widget? child) {
        final double pulseVal = _pulseController.value;

        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF0E1322), Color(0xFF151B2C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                border: Border.all(
                  color: _comboCount > 0
                      ? comboColor.withValues(alpha: 0.45 + 0.25 * pulseVal)
                      : AppColors.liquidGold.withValues(alpha: 0.3),
                  width: _comboCount > 0 ? 1.5 : 1.2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.75),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                  if (_comboCount > 0)
                    BoxShadow(
                      color: comboColor.withValues(alpha: 0.12 + 0.12 * pulseVal),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // 1. Header: Quick Wager Stepper & Gold Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Row(
                        children: <Widget>[
                          Icon(
                            Icons.monetization_on_rounded,
                            size: 14,
                            color: AppColors.liquidGold,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'BAHİS MİKTARI',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: <Widget>[
                          Text(
                            _selectedWager == 0
                                ? 'Bahissiz (Dostluk)'
                                : '$_selectedWager 🪙 Altın',
                            style: const TextStyle(
                              color: AppColors.liquidGold,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (widget.maxGold > 0) ...<Widget>[
                            const SizedBox(width: 8),
                            Text(
                              '(Kasa: ${widget.maxGold})',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 2. Wager Quick Chips (Ergonomic thumb-reachable row)
                  Row(
                    children: <Widget>[
                      for (final int amount in _wagerPresets)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.5),
                            child: _WagerChip(
                              label: amount == 0 ? '0' : '+$amount',
                              isSelected: _selectedWager == amount,
                              onTap: widget.disabled
                                  ? null
                                  : () {
                                      unawaited(HapticFeedback.selectionClick());
                                      setState(() => _selectedWager = amount);
                                      widget.onWagerSelected?.call(amount);
                                    },
                            ),
                          ),
                        ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.5),
                          child: _WagerChip(
                            label: 'Max',
                            isSelected: _selectedWager >= widget.maxGold &&
                                widget.maxGold > 0,
                            onTap: widget.disabled
                                ? null
                                : () {
                                    unawaited(HapticFeedback.selectionClick());
                                    setState(() => _selectedWager = widget.maxGold);
                                    widget.onWagerSelected?.call(widget.maxGold);
                                  },
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 3. Ergonomic Thumb Combat Skill Stance & Glowing Combo Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Row(
                        children: <Widget>[
                          Icon(
                            Icons.sports_martial_arts_rounded,
                            size: 13,
                            color: Colors.white60,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'STANS & BECERİ DESTEĞİ',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.9,
                            ),
                          ),
                        ],
                      ),
                      // Glowing combo streak badge
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: _comboCount > 0
                              ? comboColor.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          border: Border.all(
                            color: _comboCount > 0
                                ? comboColor.withValues(alpha: 0.6)
                                : Colors.white12,
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          _getComboBadgeText(),
                          style: TextStyle(
                            color: _comboCount > 0 ? comboColor : Colors.white54,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // 4. Glowing Combo Charge Indicator Nodes
                  _ComboChargeMeter(
                    comboCount: _comboCount,
                    maxCombo: _maxCombo,
                    activeColor: comboColor,
                    pulseFactor: pulseVal,
                  ),

                  const SizedBox(height: 8),

                  // 5. Thumb Skill Action Row (Quick Reach Arc)
                  Row(
                    children: <Widget>[
                      for (final PvpCombatSkill skill in _activeSkills)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.5),
                            child: _ThumbSkillButton(
                              skill: skill,
                              cooldownEnd: _cooldowns[skill.id],
                              rippleAnimation: _skillRippleControllers[skill.id] ??
                                  _pulseController,
                              disabled: widget.disabled || _submitting,
                              onTap: () => _triggerSkill(skill),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 6. Primary Thumb Trigger Button: Quick Duel & Combo Release
                  _DuelTriggerButton(
                    submitting: _submitting,
                    disabled: widget.disabled,
                    selectedWager: _selectedWager,
                    comboCount: _comboCount,
                    isMaxCombo: isMaxCombo,
                    pulseValue: pulseVal,
                    onPressed: _triggerDuel,
                  ),
                ],
              ),
            ),

            // 7. Full-Deck Luminous Combo Release Shockwave Overlay
            _DeckComboReleaseOverlay(
              animation: _comboReleaseController,
              accentColor: comboColor,
            ),
          ],
        );
      },
    );
  }
}

/// Dynamic Wager Chip with ergonomic touch hitbox and subtle micro-bounce.
class _WagerChip extends StatefulWidget {
  const _WagerChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  State<_WagerChip> createState() => _WagerChipState();
}

class _WagerChipState extends State<_WagerChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: widget.onTap != null
          ? (_) {
              setState(() => _isPressed = false);
              widget.onTap?.call();
            }
          : null,
      onTapCancel: widget.onTap != null ? () => setState(() => _isPressed = false) : null,
      child: AnimatedScale(
        scale: _isPressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutQuad,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.liquidGold
                : const Color(0xFF161C2C),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.liquidGold
                  : Colors.white24,
              width: widget.isSelected ? 1.4 : 0.8,
            ),
            boxShadow: widget.isSelected
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.liquidGold.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isSelected ? Colors.black : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

/// Glowing 4-Segment Combo Charge Meter.
class _ComboChargeMeter extends StatelessWidget {
  const _ComboChargeMeter({
    required this.comboCount,
    required this.maxCombo,
    required this.activeColor,
    required this.pulseFactor,
  });

  final int comboCount;
  final int maxCombo;
  final Color activeColor;
  final double pulseFactor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 1; i <= maxCombo; i++)
          Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: i <= comboCount
                    ? activeColor
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(2),
                boxShadow: i <= comboCount
                    ? <BoxShadow>[
                        BoxShadow(
                          color: activeColor.withValues(
                            alpha: 0.5 + 0.3 * pulseFactor,
                          ),
                          blurRadius: 6,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// Ergonomic Thumb Combat Skill Button with cooldown ripples & radial sweep.
class _ThumbSkillButton extends StatefulWidget {
  const _ThumbSkillButton({
    required this.skill,
    required this.cooldownEnd,
    required this.rippleAnimation,
    required this.disabled,
    required this.onTap,
  });

  final PvpCombatSkill skill;
  final DateTime? cooldownEnd;
  final Animation<double> rippleAnimation;
  final bool disabled;
  final VoidCallback onTap;

  @override
  State<_ThumbSkillButton> createState() => _ThumbSkillButtonState();
}

class _ThumbSkillButtonState extends State<_ThumbSkillButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime? cdEnd = widget.cooldownEnd;
    final bool isOnCooldown = cdEnd != null && cdEnd.isAfter(now);

    double progress = 0.0;
    String cdText = '';
    if (isOnCooldown) {
      final double remainingMs =
          cdEnd.difference(now).inMilliseconds.toDouble();
      final double totalMs =
          widget.skill.cooldown.inMilliseconds.toDouble();
      progress = (remainingMs / totalMs).clamp(0.0, 1.0);
      cdText = '${(remainingMs / 1000.0).toStringAsFixed(1)}s';
    }

    return GestureDetector(
      onTapDown: !widget.disabled
          ? (_) => setState(() => _isPressed = true)
          : null,
      onTapUp: !widget.disabled
          ? (_) {
              setState(() => _isPressed = false);
              widget.onTap();
            }
          : null,
      onTapCancel: !widget.disabled
          ? () => setState(() => _isPressed = false)
          : null,
      child: AnimatedScale(
        scale: _isPressed ? 0.91 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  const Color(0xFF161C2C),
                  widget.skill.accentColor.withValues(alpha: 0.12),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isOnCooldown
                    ? Colors.white12
                    : widget.skill.accentColor.withValues(alpha: 0.5),
                width: isOnCooldown ? 0.8 : 1.2,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // Animated Skill Ripple Wave
                CustomPaint(
                  size: const Size(double.infinity, 52),
                  painter: _SkillRipplePainter(
                    animation: widget.rippleAnimation,
                    color: widget.skill.accentColor,
                  ),
                ),

                // Radial Cooldown Sweep Overlay
                if (isOnCooldown)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SkillCooldownPainter(
                        progress: progress,
                        cooldownColor: widget.skill.accentColor,
                      ),
                    ),
                  ),

                // Skill Content: Icon & Name or Cooldown Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      if (isOnCooldown)
                        Text(
                          cdText,
                          style: TextStyle(
                            color: widget.skill.accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        )
                      else ...<Widget>[
                        Icon(
                          widget.skill.icon,
                          size: 19,
                          color: widget.disabled
                              ? Colors.white30
                              : widget.skill.accentColor,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.skill.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.disabled ? Colors.white38 : Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Expanding shockwave ripple painter triggered when a skill button is tapped.
class _SkillRipplePainter extends CustomPainter {
  _SkillRipplePainter({
    required this.animation,
    required this.color,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double value = animation.value;
    if (value <= 0.0 || value >= 1.0) return;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double maxRadius = math.sqrt(size.width * size.width + size.height * size.height) * 0.7;
    final double currentRadius = maxRadius * value;
    final double opacity = (1.0 - value).clamp(0.0, 1.0);

    // Shockwave expansion ring
    final Paint wavePaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 * (1.0 - value * 0.6);

    canvas.drawCircle(center, currentRadius, wavePaint);

    // Core luminous flash
    final Paint glowPaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.28)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, currentRadius * 0.65, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _SkillRipplePainter oldDelegate) => true;
}

/// Circular radial sweep painter visualizing remaining skill cooldown.
class _SkillCooldownPainter extends CustomPainter {
  _SkillCooldownPainter({
    required this.progress,
    required this.cooldownColor,
  });

  final double progress;
  final Color cooldownColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final Rect rect = Offset.zero & size;
    final Paint sweepPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.72)
      ..style = PaintingStyle.fill;

    final Paint arcBorderPaint = Paint()
      ..color = cooldownColor.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final double sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, true, sweepPaint);
    canvas.drawArc(rect.deflate(1.0), -math.pi / 2, sweepAngle, false, arcBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _SkillCooldownPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.cooldownColor != cooldownColor;
}

/// Primary Ergonomic Duel Trigger Button with Combo Release Visuals.
class _DuelTriggerButton extends StatelessWidget {
  const _DuelTriggerButton({
    required this.submitting,
    required this.disabled,
    required this.selectedWager,
    required this.comboCount,
    required this.isMaxCombo,
    required this.pulseValue,
    required this.onPressed,
  });

  final bool submitting;
  final bool disabled;
  final int selectedWager;
  final int comboCount;
  final bool isMaxCombo;
  final double pulseValue;
  final VoidCallback onPressed;

  String _getButtonLabel() {
    if (isMaxCombo) {
      return selectedWager == 0
          ? '💥 MAX KOMBO TAARRUZ!'
          : '💥 MAX KOMBO TAARRUZ ($selectedWager 🪙)';
    }
    if (comboCount > 0) {
      return selectedWager == 0
          ? '🔥 ${comboCount}X KOMBO İLE DÜELLO'
          : '🔥 ${comboCount}X KOMBO DÜELLO ($selectedWager 🪙)';
    }
    return selectedWager == 0
        ? '⚡ HIZLI DÜELLO ARA'
        : '⚡ BAHİSLİ DÜELLO BAŞLAT';
  }

  IconData _getButtonIcon() {
    if (isMaxCombo) return Icons.local_fire_department_rounded;
    if (comboCount > 0) return Icons.bolt_rounded;
    return Icons.flash_on_rounded;
  }

  Color _getButtonPrimaryColor() {
    if (disabled) return Colors.grey.shade800;
    if (isMaxCombo) return const Color(0xFFFF2A4B);
    if (comboCount > 0) return const Color(0xFFFF6D00);
    return const Color(0xFFFF9100);
  }

  @override
  Widget build(BuildContext context) {
    final Color buttonColor = _getButtonPrimaryColor();

    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: disabled || submitting ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: disabled ? 0 : 8,
          shadowColor: buttonColor.withValues(
            alpha: disabled ? 0.0 : (0.4 + 0.35 * pulseValue),
          ),
        ),
        child: submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.black,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(_getButtonIcon(), size: 19, color: Colors.black),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _getButtonLabel(),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Deck-wide Luminous Combo Release Shockwave Overlay.
class _DeckComboReleaseOverlay extends StatelessWidget {
  const _DeckComboReleaseOverlay({
    required this.animation,
    required this.accentColor,
  });

  final Animation<double> animation;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double value = animation.value;
        if (value <= 0.0 || value >= 1.0) return const SizedBox.shrink();

        final double opacity = (1.0 - value).clamp(0.0, 1.0);
        return Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                border: Border.all(
                  color: accentColor.withValues(alpha: opacity * 0.9),
                  width: 3.5 * (1.0 - value * 0.5),
                ),
                gradient: RadialGradient(
                  center: Alignment.bottomCenter,
                  radius: 0.4 + value * 1.3,
                  colors: <Color>[
                    accentColor.withValues(alpha: opacity * 0.4),
                    AppColors.liquidGold.withValues(alpha: opacity * 0.2),
                    Colors.transparent,
                  ],
                  stops: const <double>[0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
