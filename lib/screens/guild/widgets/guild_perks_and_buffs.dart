import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/guild_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import 'guild_design.dart';

/// Cyber-Fantasy Perk Category classifications.
enum GuildPerkCategory {
  combat('Savaş', Icons.sports_kabaddi_rounded, Color(0xFFFF2E93)),
  economy('Ekonomi', Icons.savings_rounded, GuildPalette.gold),
  vitality('Canlılık', Icons.bolt_rounded, GuildPalette.neon),
  ascension('Yükseliş', Icons.auto_awesome_rounded, GuildPalette.iridescentCyan);

  const GuildPerkCategory(this.label, this.icon, this.accent);
  final String label;
  final IconData icon;
  final Color accent;
}

/// Guild perk icon mapper based on effect text.
IconData _perkIcon(String effect) {
  if (effect.contains('XP')) return Icons.auto_awesome_rounded;
  if (effect.contains('Gold')) return Icons.savings_rounded;
  if (effect.contains('Enerji')) return Icons.bolt_rounded;
  if (effect.contains('Overdose')) return Icons.healing_rounded;
  if (effect.contains('Üretim') || effect.contains('Tesis')) return Icons.factory_rounded;
  if (effect.contains('Luck') || effect.contains('Loot')) return Icons.card_giftcard_rounded;
  if (effect.contains('Craft')) return Icons.build_circle_rounded;
  if (effect.contains('PvP')) return Icons.shield_rounded;
  if (effect.contains('Enhance')) return Icons.upgrade_rounded;
  if (effect.contains('Boss')) return Icons.whatshot_rounded;
  if (effect.contains('Hastane')) return Icons.medical_services_rounded;
  if (effect.contains('Rep')) return Icons.military_tech_rounded;
  if (effect.contains('Stat')) return Icons.tune_rounded;
  if (effect.contains('Aura')) return Icons.flare_rounded;
  return Icons.star_rounded;
}

/// Accent color mapping with Cyber-Fantasy Iridescent tokens.
Color _perkColor(int level) {
  if (level >= 100) return GuildPalette.iridescentRose;
  if (level >= 80) return const Color(0xFFFF2E93);
  if (level >= 50) return GuildPalette.iridescentCyan;
  if (level >= 25) return GuildPalette.neon;
  return GuildPalette.gold;
}

/// Determines perk tier title.
String _perkTierName(int level) {
  if (level >= 100) return 'ETERNAL';
  if (level >= 80) return 'EFSANEVİ';
  if (level >= 50) return 'EPİK';
  if (level >= 25) return 'NADİR';
  return 'SEÇKİN';
}

/// Categorizes a perk for filtering and visual badges.
GuildPerkCategory _perkCategory(int level, String title, String effect) {
  if (level >= 80 || title.contains('ETERNAL') || title.contains('Gücü') || title.contains('Milestone')) {
    return GuildPerkCategory.ascension;
  }
  if (effect.contains('Boss') ||
      effect.contains('PvP') ||
      effect.contains('Shield') ||
      effect.contains('Hasar') ||
      effect.contains('Stat')) {
    return GuildPerkCategory.combat;
  }
  if (effect.contains('Gold') ||
      effect.contains('Loot') ||
      effect.contains('Luck') ||
      effect.contains('Craft') ||
      effect.contains('Tesis') ||
      effect.contains('Enhance')) {
    return GuildPerkCategory.economy;
  }
  return GuildPerkCategory.vitality;
}

/// Continuous breathing halo dot for active cyber-fantasy indicators.
class _PulsingBeaconDot extends StatefulWidget {
  const _PulsingBeaconDot({
    this.color = GuildPalette.neon,
    this.size = 8.0,
  });

  final Color color;
  final double size;

  @override
  State<_PulsingBeaconDot> createState() => _PulsingBeaconDotState();
}

class _PulsingBeaconDotState extends State<_PulsingBeaconDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = _controller.value;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: widget.color.withValues(alpha: 0.35 + 0.45 * t),
                blurRadius: 4.0 + 8.0 * t,
                spreadRadius: 1.0 + 2.0 * t,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Crystalline sweeping light animation for active tags.
class _ShimmerSweepDecorator extends StatefulWidget {
  const _ShimmerSweepDecorator({
    required this.child,
    this.shimmerColor = Colors.white,
  });

  final Widget child;
  final Color shimmerColor;

  @override
  State<_ShimmerSweepDecorator> createState() => _ShimmerSweepDecoratorState();
}

class _ShimmerSweepDecoratorState extends State<_ShimmerSweepDecorator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (Rect bounds) {
            final double slide = _controller.value * 2.2 - 0.6;
            return LinearGradient(
              begin: Alignment(-1.2 + slide, 0.0),
              end: Alignment(0.6 + slide, 0.0),
              colors: <Color>[
                Colors.white.withValues(alpha: 0.85),
                widget.shimmerColor,
                Colors.white.withValues(alpha: 0.85),
              ],
              stops: const <double>[0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Cyber-Fantasy Countdown / Resonance Pill.
class _ResonanceCountdownPill extends StatelessWidget {
  const _ResonanceCountdownPill({
    required this.icon,
    required this.label,
    required this.detail,
    required this.accent,
    this.isLive = false,
  });

  final IconData icon;
  final String label;
  final String detail;
  final Color accent;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accent.withValues(alpha: 0.35),
          width: 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isLive) ...<Widget>[
            _PulsingBeaconDot(color: accent, size: 6.5),
            const SizedBox(width: 6),
          ] else ...<Widget>[
            Icon(icon, size: 12, color: accent),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: GuildPalette.titanium,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            detail,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}


/// 2027 Aion 2 Guild Perks and Active Buffs Section (V3 AAA Cyber-Fantasy Edition).
class GuildPerksAndBuffsSection extends StatefulWidget {
  const GuildPerksAndBuffsSection({
    super.key,
    required this.monumentLevel,
    required this.guildLevel,
    this.onViewAllPressed,
  });

  final int monumentLevel;
  final int guildLevel;
  final VoidCallback? onViewAllPressed;

  @override
  State<GuildPerksAndBuffsSection> createState() => _GuildPerksAndBuffsSectionState();
}

class _GuildPerksAndBuffsSectionState extends State<GuildPerksAndBuffsSection> {
  @override
  Widget build(BuildContext context) {
    final List<(int, String, String)> unlocked = kMonumentBonuses
        .where(((int level, String title, String effect) b) => widget.monumentLevel >= b.$1)
        .toList();

    final (int, String, String)? nextBonus = kMonumentBonuses
        .where(((int level, String title, String effect) b) => widget.monumentLevel < b.$1)
        .firstOrNull;

    // Previous unlock level for milestone progress calculation
    final int prevBonusLevel = unlocked.isNotEmpty ? unlocked.last.$1 : 0;
    final double milestoneProgress = nextBonus != null
        ? ((widget.monumentLevel - prevBonusLevel) / (nextBonus.$1 - prevBonusLevel)).clamp(0.0, 1.0)
        : 1.0;

    return GuildGlassCard(
      accent: GuildPalette.neon,
      blurSigma: 14.0,
      glowOpacity: 0.18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header with Glowing Cyber Badge & View All Action
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      GuildPalette.neon.withValues(alpha: 0.28),
                      GuildPalette.iridescentCyan.withValues(alpha: 0.16),
                    ],
                  ),
                  border: Border.all(
                    color: GuildPalette.neon.withValues(alpha: 0.55),
                    width: 1.2,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: GuildPalette.neon.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: GuildPalette.neon,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          'AKTİF LONCA GÜÇLENDİRMELERİ',
                          style: AppTextStyles.label.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.9,
                            color: GuildPalette.textHi,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const _PulsingBeaconDot(color: GuildPalette.neon, size: 6.5),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${unlocked.length} aktif kutsama · Anıt Sv.${widget.monumentLevel} · Lonca Sv.${widget.guildLevel}',
                      style: AppTextStyles.caption.copyWith(
                        color: GuildPalette.titanium,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              GuildPressable(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (widget.onViewAllPressed != null) {
                    widget.onViewAllPressed!();
                  } else {
                    _showAllPerksDialog(context);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: GuildPalette.obsidian.withValues(alpha: 0.75),
                    border: Border.all(
                      color: GuildPalette.neon.withValues(alpha: 0.45),
                      width: 1.0,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: GuildPalette.neon.withValues(alpha: 0.15),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'TÜMÜ (${kMonumentBonuses.length})',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                          color: GuildPalette.neon,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: GuildPalette.neon,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Cyber-Fantasy Resonance & Countdown Pills
          Row(
            children: <Widget>[
              const Expanded(
                child: _ResonanceCountdownPill(
                  icon: Icons.flare_rounded,
                  label: 'KUTSAMA AĞI:',
                  detail: 'AKTİF %100',
                  accent: GuildPalette.neon,
                  isLive: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ResonanceCountdownPill(
                  icon: Icons.timer_outlined,
                  label: 'SIRADAKİ GÜÇ:',
                  detail: nextBonus != null
                      ? '${nextBonus.$1 - widget.monumentLevel} Sv. Sonra'
                      : 'ZİRVE KADEME',
                  accent: nextBonus != null ? GuildPalette.gold : GuildPalette.iridescentCyan,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Active Buff Badges or Apex Blessing Spotlight
          if (unlocked.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              decoration: BoxDecoration(
                color: GuildPalette.celestialVoid.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: GuildPalette.titanium.withValues(alpha: 0.3),
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.lock_outline_rounded,
                        color: GuildPalette.gold,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Kutsal Anıt Güçlendirmesi Henüz Uyandırılmadı',
                        style: AppTextStyles.caption.copyWith(
                          color: GuildPalette.textHi,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Anıtı Sv.5 seviyesine bağışlayarak loncanızın ilk daimi bonusunu (%5 XP) açın!',
                    style: AppTextStyles.caption.copyWith(
                      color: GuildPalette.titanium,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GuildProgressStrip(
                    label: 'İlk Kutsama Hedefi: Sv.5',
                    value: (widget.monumentLevel / 5.0).clamp(0.0, 1.0),
                    detail: 'Sv.${widget.monumentLevel} / Sv.5',
                    accent: GuildPalette.gold,
                  ),
                ],
              ),
            )
          else ...<Widget>[
            // APEX BLESSING (Highest Unlocked Perk) FEATURE CARD
            Builder(
              builder: (BuildContext context) {
                final (int level, String title, String effect) highest = unlocked.last;
                final Color apexCol = _perkColor(highest.$1);
                final String tierName = _perkTierName(highest.$1);
                final GuildPerkCategory cat = _perkCategory(highest.$1, highest.$2, highest.$3);

                return GuildPressable(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showPerkDetailsDialog(context, highest.$1, highest.$2, highest.$3, true);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          apexCol.withValues(alpha: 0.16),
                          GuildPalette.celestialSurface.withValues(alpha: 0.85),
                          GuildPalette.celestialVoid.withValues(alpha: 0.95),
                        ],
                      ),
                      border: Border.all(
                        color: apexCol.withValues(alpha: 0.55),
                        width: 1.2,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: apexCol.withValues(alpha: 0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: apexCol.withValues(alpha: 0.22),
                            border: Border.all(
                              color: apexCol,
                              width: 1.5,
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: apexCol.withValues(alpha: 0.45),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            _perkIcon(highest.$3),
                            color: apexCol,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  _ShimmerSweepDecorator(
                                    shimmerColor: apexCol,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: apexCol.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: apexCol.withValues(alpha: 0.6),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        '✦ APEX KUTSAMA · $tierName',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.6,
                                          color: apexCol,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: cat.accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Icon(cat.icon, size: 10, color: cat.accent),
                                        const SizedBox(width: 3),
                                        Text(
                                          cat.label,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: cat.accent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Sv.${highest.$1} · ${highest.$2}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: GuildPalette.textHi,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                highest.$3,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                  color: apexCol,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.touch_app_rounded,
                          size: 16,
                          color: GuildPalette.titanium,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // COMPANION ACTIVE BUFFS WRAP
            if (unlocked.length > 1) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  ...unlocked.reversed.skip(1).take(5).map(((int level, String title, String effect) b) {
                    final Color col = _perkColor(b.$1);
                    return GuildPressable(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showPerkDetailsDialog(context, b.$1, b.$2, b.$3, true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: col.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: col.withValues(alpha: 0.4),
                            width: 1.0,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: col.withValues(alpha: 0.1),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(_perkIcon(b.$3), size: 12, color: col),
                            const SizedBox(width: 5),
                            Text(
                              '${b.$2}: ',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: GuildPalette.titanium,
                              ),
                            ),
                            Text(
                              b.$3,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: GuildPalette.textHi,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (unlocked.length > 6)
                    GuildPressable(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showAllPerksDialog(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: GuildPalette.iridescentCyan.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: GuildPalette.iridescentCyan.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          '+${unlocked.length - 6} Kutsama Daha →',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: GuildPalette.iridescentCyan,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],

          // Next Milestone Progress Card
          if (nextBonus != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GuildPalette.celestialVoid.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: GuildPalette.gold.withValues(alpha: 0.4),
                  width: 1.0,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: GuildPalette.gold.withValues(alpha: 0.12),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: GuildPalette.gold.withValues(alpha: 0.18),
                          border: Border.all(
                            color: GuildPalette.gold.withValues(alpha: 0.6),
                          ),
                        ),
                        child: const Icon(
                          Icons.lock_clock_rounded,
                          size: 15,
                          color: GuildPalette.gold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Sıradaki Kutsama: ${nextBonus.$2}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: GuildPalette.gold.withValues(alpha: 0.98),
                              ),
                            ),
                            Text(
                              nextBonus.$3,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: GuildPalette.titanium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: GuildPalette.obsidian,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: GuildPalette.gold.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '${nextBonus.$1 - widget.monumentLevel} Sv. kaldı',
                          style: const TextStyle(
                            color: GuildPalette.gold,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GuildProgressStrip(
                    label: 'Anıt Seviye Hedefi',
                    value: milestoneProgress,
                    detail: 'Sv.${widget.monumentLevel} / Sv.${nextBonus.$1} (%${(milestoneProgress * 100).toInt()})',
                    accent: GuildPalette.gold,
                  ),
                ],
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[
                    Color(0x33FF2E93),
                    Color(0x3300E5FF),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: GuildPalette.iridescentCyan.withValues(alpha: 0.5),
                ),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.stars_rounded, color: GuildPalette.iridescentCyan, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '✦ TÜM ANIT KUTSAMALARI AÇIK · MAKSİMUM ETERNAL AURA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }


  void _showPerkDetailsDialog(
    BuildContext context,
    int level,
    String title,
    String effect,
    bool isUnlocked,
  ) {
    final Color col = _perkColor(level);
    final String tier = _perkTierName(level);
    final GuildPerkCategory cat = _perkCategory(level, title, effect);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              decoration: BoxDecoration(
                color: GuildPalette.celestialVoid.withValues(alpha: 0.94),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(
                  color: col.withValues(alpha: isUnlocked ? 0.6 : 0.25),
                  width: 1.2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: col.withValues(alpha: isUnlocked ? 0.25 : 0.08),
                    blurRadius: 28,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: GuildPalette.titanium.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: col.withValues(alpha: isUnlocked ? 0.22 : 0.1),
                          border: Border.all(
                            color: col.withValues(alpha: isUnlocked ? 0.8 : 0.3),
                            width: 1.5,
                          ),
                          boxShadow: isUnlocked
                              ? <BoxShadow>[
                                  BoxShadow(
                                    color: col.withValues(alpha: 0.4),
                                    blurRadius: 14,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          _perkIcon(effect),
                          color: isUnlocked ? col : GuildPalette.titanium,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: col.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: col.withValues(alpha: 0.5),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    '✦ $tier',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.6,
                                      color: col,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cat.accent.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(cat.icon, size: 10, color: cat.accent),
                                      const SizedBox(width: 3),
                                      Text(
                                        cat.label,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: cat.accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: GuildPalette.textHi,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: GuildPalette.titanium, size: 22),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(ctx).pop();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: GuildPalette.obsidian.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: col.withValues(alpha: 0.35),
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'KUTSAMA ETKİSİ',
                          style: AppTextStyles.label.copyWith(
                            fontSize: 10,
                            letterSpacing: 0.8,
                            color: GuildPalette.titanium,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          effect,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: col,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isUnlocked
                              ? 'Bu güçlendirme kutsal anıtınızın ulaştığı seviye ile aktif rezonans halindedir. Tüm lonca üyeleri için geçerlidir.'
                              : 'Bu güçlendirmenin açılması için loncanızın Kutsal Anıt seviyesini Sv.$level seviyesine çıkarması gerekmektedir.',
                          style: AppTextStyles.caption.copyWith(
                            color: GuildPalette.titanium,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      if (isUnlocked) ...<Widget>[
                        _ShimmerSweepDecorator(
                          shimmerColor: GuildPalette.neon,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: GuildPalette.neon.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: GuildPalette.neon.withValues(alpha: 0.6),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                _PulsingBeaconDot(color: GuildPalette.neon, size: 6),
                                SizedBox(width: 6),
                                Text(
                                  'AKTİF LONCA REZONANSI',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                    color: GuildPalette.neon,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...<Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: GuildPalette.obsidian,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: GuildPalette.titanium.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(Icons.lock_rounded, size: 12, color: GuildPalette.titanium),
                              const SizedBox(width: 5),
                              Text(
                                '${level - widget.monumentLevel} Anıt Seviyesi Gerekiyor',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: GuildPalette.titanium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        'Kademe: Anıt Sv.$level',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: GuildPalette.titanium,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAllPerksDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        String activeCategoryFilter = 'all';

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final List<(int, String, String)> unlocked = kMonumentBonuses
                .where(((int level, String title, String effect) b) => widget.monumentLevel >= b.$1)
                .toList();

            final List<(int, String, String)> filteredBonuses = kMonumentBonuses.where(((int level, String title, String effect) b) {
              if (activeCategoryFilter == 'active') {
                return widget.monumentLevel >= b.$1;
              }
              if (activeCategoryFilter == 'locked') {
                return widget.monumentLevel < b.$1;
              }
              if (activeCategoryFilter == 'combat') {
                return _perkCategory(b.$1, b.$2, b.$3) == GuildPerkCategory.combat;
              }
              if (activeCategoryFilter == 'economy') {
                return _perkCategory(b.$1, b.$2, b.$3) == GuildPerkCategory.economy;
              }
              if (activeCategoryFilter == 'vitality') {
                return _perkCategory(b.$1, b.$2, b.$3) == GuildPerkCategory.vitality;
              }
              if (activeCategoryFilter == 'ascension') {
                return _perkCategory(b.$1, b.$2, b.$3) == GuildPerkCategory.ascension;
              }
              return true;
            }).toList();

            final double treeProgress = (unlocked.length / kMonumentBonuses.length).clamp(0.0, 1.0);

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.82,
                  ),
                  decoration: BoxDecoration(
                    color: GuildPalette.celestialVoid.withValues(alpha: 0.94),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border.all(
                      color: GuildPalette.neon.withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: GuildPalette.neon.withValues(alpha: 0.22),
                        blurRadius: 30,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Top Drag Handle
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: GuildPalette.titanium.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Header with Title & Close Action
                      Row(
                        children: <Widget>[
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: GuildPalette.neon.withValues(alpha: 0.2),
                              border: Border.all(
                                color: GuildPalette.neon.withValues(alpha: 0.6),
                              ),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: GuildPalette.neon,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'KUTSAL ANIT AVANTAJ AĞACI',
                                  style: AppTextStyles.h3.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                    color: GuildPalette.textHi,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  'Mevcut Anıt: Sv.${widget.monumentLevel} · Toplam 20 Kademe Takımyıldızı',
                                  style: AppTextStyles.caption.copyWith(
                                    color: GuildPalette.titanium,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: GuildPalette.titanium, size: 20),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(ctx).pop();
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Constellation Tree Progress Gauge
                      GuildProgressStrip(
                        label: 'Kutsama Ağı Rezonansı',
                        value: treeProgress,
                        detail: '${unlocked.length}/${kMonumentBonuses.length} Aktif (%${(treeProgress * 100).toInt()})',
                        accent: GuildPalette.iridescentCyan,
                      ),

                      const SizedBox(height: 12),

                      // Category Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: <Widget>[
                            _buildFilterChip(
                              label: 'Tümü (${kMonumentBonuses.length})',
                              filterKey: 'all',
                              currentFilter: activeCategoryFilter,
                              accent: GuildPalette.iridescentCyan,
                              onSelect: () {
                                HapticFeedback.selectionClick();
                                setModalState(() => activeCategoryFilter = 'all');
                              },
                            ),
                            const SizedBox(width: 6),
                            _buildFilterChip(
                              label: 'Aktif (${unlocked.length})',
                              filterKey: 'active',
                              currentFilter: activeCategoryFilter,
                              accent: GuildPalette.neon,
                              onSelect: () {
                                HapticFeedback.selectionClick();
                                setModalState(() => activeCategoryFilter = 'active');
                              },
                            ),
                            const SizedBox(width: 6),
                            _buildFilterChip(
                              label: 'Savaş',
                              filterKey: 'combat',
                              currentFilter: activeCategoryFilter,
                              accent: const Color(0xFFFF2E93),
                              onSelect: () {
                                HapticFeedback.selectionClick();
                                setModalState(() => activeCategoryFilter = 'combat');
                              },
                            ),
                            const SizedBox(width: 6),
                            _buildFilterChip(
                              label: 'Ekonomi',
                              filterKey: 'economy',
                              currentFilter: activeCategoryFilter,
                              accent: GuildPalette.gold,
                              onSelect: () {
                                HapticFeedback.selectionClick();
                                setModalState(() => activeCategoryFilter = 'economy');
                              },
                            ),
                            const SizedBox(width: 6),
                            _buildFilterChip(
                              label: 'Canlılık',
                              filterKey: 'vitality',
                              currentFilter: activeCategoryFilter,
                              accent: GuildPalette.neon,
                              onSelect: () {
                                HapticFeedback.selectionClick();
                                setModalState(() => activeCategoryFilter = 'vitality');
                              },
                            ),
                            const SizedBox(width: 6),
                            _buildFilterChip(
                              label: 'Yükseliş',
                              filterKey: 'ascension',
                              currentFilter: activeCategoryFilter,
                              accent: GuildPalette.iridescentViolet,
                              onSelect: () {
                                HapticFeedback.selectionClick();
                                setModalState(() => activeCategoryFilter = 'ascension');
                              },
                            ),
                            const SizedBox(width: 6),
                            _buildFilterChip(
                              label: 'Kilitli (${kMonumentBonuses.length - unlocked.length})',
                              filterKey: 'locked',
                              currentFilter: activeCategoryFilter,
                              accent: GuildPalette.titanium,
                              onSelect: () {
                                HapticFeedback.selectionClick();
                                setModalState(() => activeCategoryFilter = 'locked');
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Constellation Tree Perk List
                      Expanded(
                        child: filteredBonuses.isEmpty
                            ? Center(
                                child: Text(
                                  'Bu filtreye uygun kutsama bulunamadı.',
                                  style: AppTextStyles.caption.copyWith(
                                    color: GuildPalette.titanium,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filteredBonuses.length,
                                separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 8),
                                itemBuilder: (BuildContext context, int index) {
                                  final (int reqLevel, String title, String effect) = filteredBonuses[index];
                                  final bool isUnlocked = widget.monumentLevel >= reqLevel;
                                  final Color col = _perkColor(reqLevel);
                                  final String tier = _perkTierName(reqLevel);
                                  final GuildPerkCategory cat = _perkCategory(reqLevel, title, effect);

                                  return GuildPressable(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      _showPerkDetailsDialog(context, reqLevel, title, effect, isUnlocked);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isUnlocked
                                            ? col.withValues(alpha: 0.12)
                                            : GuildPalette.obsidian.withValues(alpha: 0.45),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isUnlocked
                                              ? col.withValues(alpha: 0.5)
                                              : GuildPalette.titanium.withValues(alpha: 0.2),
                                          width: 1.0,
                                        ),
                                        boxShadow: isUnlocked
                                            ? <BoxShadow>[
                                                BoxShadow(
                                                  color: col.withValues(alpha: 0.12),
                                                  blurRadius: 10,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          // Node Jewel
                                          Container(
                                            width: 36,
                                            height: 36,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isUnlocked ? col.withValues(alpha: 0.25) : Colors.black45,
                                              border: Border.all(
                                                color: isUnlocked ? col : GuildPalette.titanium.withValues(alpha: 0.35),
                                                width: 1.2,
                                              ),
                                              boxShadow: isUnlocked
                                                  ? <BoxShadow>[
                                                      BoxShadow(
                                                        color: col.withValues(alpha: 0.35),
                                                        blurRadius: 8,
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Icon(
                                              isUnlocked ? _perkIcon(effect) : Icons.lock_outline_rounded,
                                              size: 16,
                                              color: isUnlocked ? col : GuildPalette.titanium,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          // Content Details
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Row(
                                                  children: <Widget>[
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                      decoration: BoxDecoration(
                                                        color: col.withValues(alpha: 0.18),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        'Sv.$reqLevel',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.w900,
                                                          color: isUnlocked ? col : GuildPalette.titanium,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      title,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w800,
                                                        color: isUnlocked ? GuildPalette.textHi : GuildPalette.titanium,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '· $tier',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w700,
                                                        color: col.withValues(alpha: 0.8),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: <Widget>[
                                                    Text(
                                                      effect,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w800,
                                                        color: isUnlocked ? col : GuildPalette.titanium.withValues(alpha: 0.75),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '(${cat.label})',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w600,
                                                        color: cat.accent.withValues(alpha: 0.7),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Status Badge
                                          if (isUnlocked)
                                            _ShimmerSweepDecorator(
                                              shimmerColor: col,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: GuildPalette.neon.withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: GuildPalette.neon.withValues(alpha: 0.5),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: const Text(
                                                  'AKTİF',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.5,
                                                    color: GuildPalette.neon,
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: GuildPalette.obsidian,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '-${reqLevel - widget.monumentLevel} Sv.',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: GuildPalette.titanium,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String filterKey,
    required String currentFilter,
    required Color accent,
    required VoidCallback onSelect,
  }) {
    final bool isSelected = currentFilter == filterKey;
    return GuildPressable(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.22) : GuildPalette.obsidian.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accent : GuildPalette.titanium.withValues(alpha: 0.3),
            width: isSelected ? 1.2 : 0.8,
          ),
          boxShadow: isSelected
              ? <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            letterSpacing: 0.3,
            color: isSelected ? accent : GuildPalette.titanium,
          ),
        ),
      ),
    );
  }
}

