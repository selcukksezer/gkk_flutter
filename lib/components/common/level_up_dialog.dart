import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../routing/app_router.dart';
import '../../screens/dungeon/widgets/dungeon_battle_effects.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../layout/game_screen_background.dart';

/// Zindan zafer ekranı + tasarim skill — seviye atlama kutlaması.
Future<void> showLevelUpDialog(
  BuildContext context, {
  required int oldLevel,
  required int newLevel,
  required int statPoints,
}) {
  HapticFeedback.heavyImpact();
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierLabel: 'Seviye atlama',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (
      BuildContext ctx,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return _LevelUpOverlay(
        animation: animation,
        oldLevel: oldLevel,
        newLevel: newLevel,
        statPoints: statPoints,
      );
    },
    transitionBuilder: (
      BuildContext ctx,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class _LevelUpOverlay extends StatefulWidget {
  const _LevelUpOverlay({
    required this.animation,
    required this.oldLevel,
    required this.newLevel,
    required this.statPoints,
  });

  final Animation<double> animation;
  final int oldLevel;
  final int newLevel;
  final int statPoints;

  @override
  State<_LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<_LevelUpOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _fxCtrl;
  late final AnimationController _entryCtrl;
  late final Animation<double> _cardScale;

  int get _levelsGained => widget.newLevel - widget.oldLevel;
  int get _pointsGained => _levelsGained * 3;

  @override
  void initState() {
    super.initState();
    _fxCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );
    _cardScale = CurvedAnimation(
      parent: _entryCtrl,
      curve: Curves.elasticOut,
    );
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _fxCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _goCharacter() {
    Navigator.of(context).pop();
    context.push(AppRoutes.character);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: BattlePalette.carbonVoid.withValues(alpha: 0.62),
            ),
          ),
          AnimatedBuilder(
            animation: _fxCtrl,
            builder: (BuildContext context, Widget? child) {
              return CustomPaint(
                painter: ConfettiFieldPainter(
                  progress: _fxCtrl.value,
                  count: 42,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),
          SafeArea(
            child: Center(
              child: ScaleTransition(
                scale: _cardScale,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildCard(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: BattlePalette.liquidGold.withValues(alpha: 0.35),
            blurRadius: 32,
            spreadRadius: -4,
          ),
          BoxShadow(
            color: BattlePalette.cyberFuchsia.withValues(alpha: 0.12),
            blurRadius: 48,
            spreadRadius: -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      GameScreenBackground.spaceNavy.withValues(alpha: 0.98),
                      GameScreenBackground.carbonVoid.withValues(alpha: 0.99),
                    ],
                  ),
                  border: Border.all(
                    color: BattlePalette.liquidGold.withValues(alpha: 0.55),
                    width: 1.4,
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: CustomPaint(
                painter: DotGridPainter(spacing: 14, dotOpacity: 0.07),
              ),
            ),
            AnimatedBuilder(
              animation: _fxCtrl,
              builder: (BuildContext context, Widget? child) {
                return CustomPaint(
                  painter: RadiantRaysPainter(
                    progress: _fxCtrl.value,
                    color: BattlePalette.liquidGold,
                    maxOpacity: 0.22,
                  ),
                  child: const SizedBox(height: 420, width: double.infinity),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  FadeSlideIn(
                    child: _buildTopBanner(),
                  ),
                  const SizedBox(height: 18),
                  FadeSlideIn(
                    delayMs: 80,
                    child: _buildLevelHero(),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    delayMs: 140,
                    child: Text(
                      'Seviye ${widget.oldLevel} → ${widget.newLevel}',
                      style: AppTextStyles.caption.copyWith(
                        color: BattlePalette.mutedTitanium,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    delayMs: 200,
                    child: _buildRewardStrip(),
                  ),
                  const SizedBox(height: 10),
                  FadeSlideIn(
                    delayMs: 260,
                    child: Text(
                      'Stat puanlarını karakter ekranından dağıt.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.micro.copyWith(
                        color: AppColors.textTertiary,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeSlideIn(
                    delayMs: 320,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: _SecondaryActionButton(
                            label: 'Tamam',
                            onTap: _close,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: BattleCtaButton(
                            label: 'Karaktere Git',
                            icon: Icons.person_rounded,
                            onTap: _goCharacter,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            BattlePalette.warningSolar.withValues(alpha: 0.38),
            BattlePalette.liquidGold.withValues(alpha: 0.16),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: BattlePalette.liquidGold.withValues(alpha: 0.65),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: BattlePalette.liquidGold.withValues(alpha: 0.18),
            blurRadius: 14,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.auto_awesome_rounded,
            color: BattlePalette.warningSolar,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'SEVİYE ATLADIN',
            style: AppTextStyles.caption.copyWith(
              color: const Color(0xFFFDE68A),
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelHero() {
    return SizedBox(
      height: 118,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  BattlePalette.liquidGold.withValues(alpha: 0.28),
                  Colors.transparent,
                ],
              ),
              border: Border.all(
                color: BattlePalette.liquidGold.withValues(alpha: 0.75),
                width: 2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: BattlePalette.liquidGold.withValues(alpha: 0.35),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Center(
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0xFFFFF3B0),
                      Color(0xFFFFB800),
                      Color(0xFFE89400),
                    ],
                  ).createShader(bounds);
                },
                child: Text(
                  '${widget.newLevel}',
                  style: AppTextStyles.display.copyWith(
                    fontSize: 52,
                    color: Colors.white,
                    height: 1,
                    shadows: <Shadow>[
                      Shadow(
                        color: BattlePalette.carbonVoid.withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 24,
            top: 8,
            child: Transform.rotate(
              angle: -math.pi / 10,
              child: Icon(
                Icons.arrow_upward_rounded,
                size: 34,
                color: BattlePalette.toxicNeon.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardStrip() {
    return Row(
      children: <Widget>[
        Expanded(
          child: _RewardChip(
            icon: Icons.bolt_rounded,
            label: 'Bu level',
            value: '+$_pointsGained',
            sub: 'stat puanı',
            accent: BattlePalette.coralFlare,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _RewardChip(
            icon: Icons.savings_outlined,
            label: 'Toplam',
            value: '${widget.statPoints}',
            sub: 'bekleyen puan',
            accent: BattlePalette.toxicNeon,
          ),
        ),
      ],
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: BattlePalette.darkObsidian.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 16, color: accent),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.micro.copyWith(
              color: BattlePalette.mutedTitanium,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.h3.copyWith(
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: AppTextStyles.micro.copyWith(
              color: AppColors.textTertiary,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BattlePalette.darkObsidian.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}
