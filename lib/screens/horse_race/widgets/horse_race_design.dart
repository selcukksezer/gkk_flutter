import 'package:flutter/material.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../theme/app_colors.dart';
import '../horse_race_provider.dart';
import '../horse_race_utils.dart';

/// At Yarışı — /tasarim: Carbon Void, dot doku, Liquid Gold, Cyber Fuchsia.
abstract final class HorseRaceDesign {
  static const Color void_ = AppColors.carbonVoid;
  static const Color navy = AppColors.spaceNavy;
  static const Color obsidian = AppColors.darkObsidian;
  static const Color titanium = AppColors.mutedTitanium;
  static const Color gold = AppColors.liquidGold;
  static const Color fuchsia = AppColors.cyberFuchsia;
  static const Color neon = AppColors.toxicNeon;
  static const Color ruby = AppColors.mysticRuby;
  static const Color cyan = AppColors.accentCyan;

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFFD64A), AppColors.liquidGold, Color(0xFFE08A00)],
    stops: <double>[0.0, 0.5, 1.0],
  );

  static const LinearGradient fuchsiaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFFF4D8D),
      AppColors.cyberFuchsia,
      Color(0xFF9B1440),
    ],
    stops: <double>[0.0, 0.5, 1.0],
  );

  static LinearGradient accentGradient(Color accent) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      accent.withValues(alpha: 0.22),
      HorseRaceDesign.navy,
      HorseRaceDesign.void_,
    ],
  );
}

class HorseRaceBackdrop extends StatelessWidget {
  const HorseRaceBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GameScreenBackground(
      showAmbientGlow: true,
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -80,
            right: -60,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      HorseRaceDesign.gold.withValues(alpha: 0.14),
                      HorseRaceDesign.gold.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -80,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      HorseRaceDesign.fuchsia.withValues(alpha: 0.10),
                      HorseRaceDesign.fuchsia.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class HorseRacePressable extends StatefulWidget {
  const HorseRacePressable({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<HorseRacePressable> createState() => _HorseRacePressableState();
}

class _HorseRacePressableState extends State<HorseRacePressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && widget.onTap != null;
    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _pressed = true) : null,
      onTapUp: active ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: active ? () => setState(() => _pressed = false) : null,
      onTap: active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class HorseRaceNeonPanel extends StatelessWidget {
  const HorseRaceNeonPanel({
    super.key,
    required this.child,
    this.accent = HorseRaceDesign.gold,
    this.padding = const EdgeInsets.all(14),
    this.radius = 16,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: accent.withValues(alpha: 0.32), width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            HorseRaceDesign.navy.withValues(alpha: 0.94),
            HorseRaceDesign.void_.withValues(alpha: 0.98),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: CustomPaint(
                painter: DotGridPainter(spacing: 14, dotOpacity: 0.06),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class HorseRaceGlowChip extends StatelessWidget {
  const HorseRaceGlowChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class HorseRaceSectionHeader extends StatelessWidget {
  const HorseRaceSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.accent = HorseRaceDesign.gold,
  });

  final String title;
  final String? subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 4,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[accent, accent.withValues(alpha: 0.2)],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 8),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: 1.1,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: HorseRaceDesign.titanium,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class HorseRaceHeroBanner extends StatelessWidget {
  const HorseRaceHeroBanner({super.key, required this.raceState});

  final HorseRaceState raceState;

  @override
  Widget build(BuildContext context) {
    final HorseRacePhase phase = raceState.round.phase;
    final int left = raceState.round.secondsLeft;
    final Color accent = switch (phase) {
      HorseRacePhase.betting => HorseRaceDesign.neon,
      HorseRacePhase.racing => HorseRaceDesign.gold,
      HorseRacePhase.finished => HorseRaceDesign.cyan,
      HorseRacePhase.locked => HorseRaceDesign.ruby,
      HorseRacePhase.unknown => HorseRaceDesign.titanium,
    };

    final String pill = switch (phase) {
      HorseRacePhase.betting => 'CANLI BAHİS',
      HorseRacePhase.racing => 'YARIŞ SÜRÜYOR',
      HorseRacePhase.finished => 'SONUÇ',
      HorseRacePhase.locked => 'KAPANIYOR',
      HorseRacePhase.unknown => 'BEKLEMEDE',
    };

    final String timerLabel = switch (phase) {
      HorseRacePhase.betting ||
      HorseRacePhase.finished => formatHorseCountdown(left),
      HorseRacePhase.locked => 'Kapanıyor',
      HorseRacePhase.racing => 'Canlı',
      HorseRacePhase.unknown => '--:--',
    };

    return HorseRaceNeonPanel(
      accent: accent,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: HorseRaceDesign.fuchsia.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: HorseRaceDesign.fuchsia.withValues(alpha: 0.48),
                  ),
                ),
                child: Text(
                  pill,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: HorseRaceDesign.fuchsia,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.sports_score_rounded, color: accent, size: 22),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'KRALİYET HİPODROMU',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: 0.6,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Atını seç, bahsini koy, canlı yarışı izle. Kazanan atın çarpanı senin.',
            style: TextStyle(
              fontSize: 12,
              color: HorseRaceDesign.titanium.withValues(alpha: 0.95),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Text(
                timerLabel,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: accent,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              const Spacer(),
              HorseRaceGlowChip(
                icon: Icons.timer_outlined,
                label: horsePhaseLabel(phase),
                color: accent,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              HorseRaceGlowChip(
                icon: Icons.pets_rounded,
                label: '${raceState.horses.length} at',
                color: HorseRaceDesign.cyan,
              ),
              if (raceState.myBet != null)
                const HorseRaceGlowChip(
                  icon: Icons.check_circle_rounded,
                  label: 'Bahsin alındı',
                  color: HorseRaceDesign.neon,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class HorseRaceGoldButton extends StatelessWidget {
  const HorseRaceGoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.paid_rounded,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !loading;
    final Widget button = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: enabled ? HorseRaceDesign.goldGradient : null,
        color: enabled ? null : HorseRaceDesign.obsidian.withValues(alpha: 0.8),
        boxShadow: enabled
            ? <BoxShadow>[
                BoxShadow(
                  color: HorseRaceDesign.gold.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              children: <Widget>[
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: HorseRaceDesign.void_,
                    ),
                  )
                else
                  Icon(
                    icon,
                    size: 18,
                    color: enabled
                        ? HorseRaceDesign.void_
                        : HorseRaceDesign.titanium,
                  ),
                const SizedBox(width: 8),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: enabled
                        ? HorseRaceDesign.void_
                        : HorseRaceDesign.titanium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class HorseRacePresetChip extends StatelessWidget {
  const HorseRacePresetChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = HorseRaceDesign.gold,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return HorseRacePressable(
      onTap: onTap,
      enabled: onTap != null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected
              ? accent.withValues(alpha: 0.16)
              : HorseRaceDesign.obsidian.withValues(alpha: 0.55),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.65)
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.18),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? accent : HorseRaceDesign.titanium,
          ),
        ),
      ),
    );
  }
}

class HorseRaceFadeSlide extends StatefulWidget {
  const HorseRaceFadeSlide({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  State<HorseRaceFadeSlide> createState() => _HorseRaceFadeSlideState();
}

class _HorseRaceFadeSlideState extends State<HorseRaceFadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future<void>.delayed(Duration(milliseconds: 40 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class HorseRaceHorseCard extends StatelessWidget {
  const HorseRaceHorseCard({
    super.key,
    required this.horse,
    required this.index,
    required this.selected,
    required this.multiplier,
    required this.laneColor,
    required this.multColor,
    this.onTap,
  });

  final HorseRaceEntry horse;
  final int index;
  final bool selected;
  final double multiplier;
  final Color laneColor;
  final Color multColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return HorseRaceFadeSlide(
      index: index,
      child: HorseRacePressable(
        onTap: onTap,
        enabled: onTap != null,
        child: HorseRaceNeonPanel(
          accent: selected ? laneColor : laneColor.withValues(alpha: 0.45),
          padding: const EdgeInsets.all(12),
          radius: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: laneColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: laneColor.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      '#${index + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: laneColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: laneColor,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        laneColor.withValues(alpha: 0.28),
                        laneColor.withValues(alpha: 0.04),
                      ],
                    ),
                    border: Border.all(
                      color: laneColor.withValues(alpha: 0.55),
                      width: 1.5,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: laneColor.withValues(alpha: 0.22),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: Text(
                    horse.emoji,
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                horse.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: multColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: multColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'x${multiplier.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: multColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (horse.winChancePct > 0)
                    Text(
                      '%${horse.winChancePct.round()}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: HorseRaceDesign.titanium,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HorseRaceMyBetTicket extends StatelessWidget {
  const HorseRaceMyBetTicket({super.key, required this.raceState});

  final HorseRaceState raceState;

  @override
  Widget build(BuildContext context) {
    final HorseRaceBet bet = raceState.myBet!;
    HorseRaceEntry? horse;
    for (final HorseRaceEntry h in raceState.horses) {
      if (h.horseId == bet.horseId) {
        horse = h;
        break;
      }
    }
    final String name = horse?.name ?? bet.horseId;
    final String emoji = horse?.emoji ?? '🐴';
    final String amt = bet.currencyType == 'gems'
        ? '${formatHorseGems(bet.betAmount)} elmas'
        : '${compactHorseAmount(bet.betAmount)} altın';
    final Color accent = bet.currencyType == 'gems'
        ? HorseRaceDesign.cyan
        : HorseRaceDesign.gold;

    return HorseRaceNeonPanel(
      accent: accent,
      child: Row(
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'AKTİF BAHİS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: HorseRaceDesign.titanium,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$amt · x${bet.multiplier.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.confirmation_number_rounded,
            color: accent.withValues(alpha: 0.8),
            size: 22,
          ),
        ],
      ),
    );
  }
}
