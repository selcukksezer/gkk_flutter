import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/power_helpers.dart';
import '../../screens/dungeon/widgets/dungeon_battle_effects.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

Future<void> showPowerChangeOverlay(
  BuildContext context, {
  required int oldPower,
  required int newPower,
}) {
  final int delta = newPower - oldPower;
  if (delta == 0) return Future<void>.value();

  if (delta > 0) {
    HapticFeedback.mediumImpact();
  } else {
    HapticFeedback.lightImpact();
  }

  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Power degisimi',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (
      BuildContext ctx,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return _PowerChangeOverlay(
        animation: animation,
        oldPower: oldPower,
        newPower: newPower,
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

class _PowerChangeOverlay extends StatefulWidget {
  const _PowerChangeOverlay({
    required this.animation,
    required this.oldPower,
    required this.newPower,
  });

  final Animation<double> animation;
  final int oldPower;
  final int newPower;

  @override
  State<_PowerChangeOverlay> createState() => _PowerChangeOverlayState();
}

class _PowerChangeOverlayState extends State<_PowerChangeOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _counterCtrl;
  late final AnimationController _exitCtrl;
  late final Animation<double> _heroScale;
  late final Animation<double> _deltaSlide;
  late final Animation<double> _counterTween;
  Timer? _autoDismiss;

  int get _delta => widget.newPower - widget.oldPower;
  bool get _isIncrease => _delta > 0;

  Color get _accent =>
      _isIncrease ? AppColors.toxicNeon : AppColors.coralFlare;

  Color get _accentSecondary =>
      _isIncrease ? AppColors.cyberFuchsia : AppColors.mysticRuby;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _counterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _heroScale = CurvedAnimation(
      parent: _entryCtrl,
      curve: Curves.elasticOut,
    );
    _deltaSlide = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
    );
    _counterTween = CurvedAnimation(
      parent: _counterCtrl,
      curve: Curves.easeOutCubic,
    );

    _entryCtrl.forward();
    _counterCtrl.forward();
    _autoDismiss = Timer(const Duration(milliseconds: 2400), _dismiss);
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _counterCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (!mounted || _exitCtrl.isAnimating) return;
    _autoDismiss?.cancel();
    await _exitCtrl.forward();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismiss,
      behavior: HitTestBehavior.opaque,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                color: BattlePalette.carbonVoid.withValues(alpha: 0.38),
              ),
            ),
            if (_isIncrease)
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (BuildContext context, Widget? child) {
                  return CustomPaint(
                    painter: ConfettiFieldPainter(
                      progress: _pulseCtrl.value,
                      count: 28,
                    ),
                    child: const SizedBox.expand(),
                  );
                },
              ),
            Center(
              child: FadeTransition(
                opacity: Tween<double>(begin: 1, end: 0).animate(
                  CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn),
                ),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 1, end: 0.88).animate(
                    CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn),
                  ),
                  child: ScaleTransition(
                    scale: _heroScale,
                    child: _buildHero(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: <Widget>[
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (BuildContext context, Widget? child) {
                final double pulse = 0.92 + (math.sin(_pulseCtrl.value * math.pi * 2) * 0.08);
                return Transform.scale(
                  scale: pulse,
                  child: CustomPaint(
                    painter: RadiantRaysPainter(
                      progress: _pulseCtrl.value,
                      color: _accent,
                      maxOpacity: _isIncrease ? 0.28 : 0.16,
                    ),
                    child: const SizedBox(width: 260, height: 260),
                  ),
                );
              },
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    AppColors.spaceNavy.withValues(alpha: 0.97),
                    AppColors.carbonVoid.withValues(alpha: 0.99),
                  ],
                ),
                border: Border.all(
                  color: _accent.withValues(alpha: 0.72),
                  width: 1.6,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.42),
                    blurRadius: 36,
                    spreadRadius: -6,
                  ),
                  BoxShadow(
                    color: _accentSecondary.withValues(alpha: 0.18),
                    blurRadius: 48,
                    spreadRadius: -10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.bolt_rounded,
                        color: _accent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'POWER',
                        style: AppTextStyles.caption.copyWith(
                          color: _accent,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AnimatedBuilder(
                    animation: _counterTween,
                    builder: (BuildContext context, Widget? child) {
                      final int display = (widget.oldPower +
                              (_delta * _counterTween.value))
                          .round();
                      return ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Colors.white,
                              _accent,
                            ],
                          ).createShader(bounds);
                        },
                        child: Text(
                          formatPowerValue(display),
                          style: AppTextStyles.display.copyWith(
                            fontSize: 56,
                            color: Colors.white,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            shadows: <Shadow>[
                              Shadow(
                                color: _accent.withValues(alpha: 0.55),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${formatPowerValue(widget.oldPower)} → ${formatPowerValue(widget.newPower)}',
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.mutedTitanium,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -18,
              child: FadeTransition(
                opacity: _deltaSlide,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_deltaSlide),
                  child: _DeltaBadge(
                    delta: _delta,
                    accent: _accent,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -22,
              child: FadeTransition(
                opacity: _deltaSlide,
                child: Icon(
                  _isIncrease
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  color: _accent.withValues(alpha: 0.9),
                  size: 32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({
    required this.delta,
    required this.accent,
  });

  final int delta;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final String prefix = delta > 0 ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            accent.withValues(alpha: 0.95),
            accent.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(99),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.45),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Text(
        '$prefix${formatPowerValue(delta)}',
        style: AppTextStyles.h3.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
