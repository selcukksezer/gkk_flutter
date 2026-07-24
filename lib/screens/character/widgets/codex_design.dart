import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../models/codex_model.dart';
import '../../../theme/app_colors.dart';

/// Kodex — /tasarim pixel system (Carbon Void · Liquid Gold · Cyber Fuchsia).
abstract final class CodexPalette {
  static const Color void_ = Color(0xFF080B12);
  static const Color navy = Color(0xFF121826);
  static const Color surface = Color(0xFF161D2E);
  static const Color obsidian = Color(0xFF2A3042);
  static const Color titanium = Color(0xFF8E9CAE);
  static const Color gold = Color(0xFFFFB800);
  static const Color goldHi = Color(0xFFFFD64A);
  static const Color goldLo = Color(0xFFE08A00);
  static const Color fuchsia = Color(0xFFE01E5A);
  static const Color neon = Color(0xFF00FF66);
  static const Color solar = Color(0xFFFFD700);
  static const Color coral = Color(0xFFFF6B35);
  static const Color ruby = Color(0xFFE52E2E);
  static const Color textHi = Color(0xFFF2F6FF);

  static const LinearGradient goldGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[goldHi, gold, goldLo],
  );

  static const LinearGradient fuchsiaGoldGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[fuchsia, gold],
  );

  static LinearGradient panelGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      navy.withValues(alpha: 0.94),
      void_.withValues(alpha: 0.98),
    ],
  );
}

// ─── Press / motion ───────────────────────────────────────────────────────────

class CodexPressable extends StatefulWidget {
  const CodexPressable({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<CodexPressable> createState() => _CodexPressableState();
}

class _CodexPressableState extends State<CodexPressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && widget.onTap != null;
    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _down = true) : null,
      onTapUp: active ? (_) => setState(() => _down = false) : null,
      onTapCancel: active ? () => setState(() => _down = false) : null,
      onTap: active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class CodexStagger extends StatelessWidget {
  const CodexStagger({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + (index % 10) * 45),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double v, Widget? c) {
        final double elastic = Curves.easeOutBack.transform(v.clamp(0.0, 1.0));
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - elastic)),
            child: Transform.scale(
              scale: 0.92 + 0.08 * elastic,
              child: c,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

// ─── Vault hero (balanced mid size) ───────────────────────────────────────────

class CodexVaultHero extends StatelessWidget {
  const CodexVaultHero({
    super.key,
    required this.dashboard,
    required this.claiming,
    required this.onClaim,
  });

  final CodexDashboard dashboard;
  final bool claiming;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final double progress = dashboard.progress.clamp(0.0, 1.0);
    final int pct = (progress * 100).round();
    final bool canClaim =
        dashboard.claimableMilestones > 0 && onClaim != null && !claiming;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              gradient: CodexPalette.panelGrad,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: CodexPalette.gold.withValues(alpha: 0.38),
                width: 1.1,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: CodexPalette.gold.withValues(alpha: 0.1),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                const Positioned.fill(
                  child: CustomPaint(
                    painter: DotGridPainter(spacing: 13, dotOpacity: 0.06),
                  ),
                ),
                Positioned(
                  top: -36,
                  right: -20,
                  child: IgnorePointer(
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[
                            CodexPalette.fuchsia.withValues(alpha: 0.16),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Text(
                                      'KODEX',
                                      style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.6,
                                        height: 1,
                                        color: CodexPalette.textHi,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (dashboard.newEntries24h > 0)
                                      _StatChip(
                                        label: '+${dashboard.newEntries24h}',
                                        color: CodexPalette.neon,
                                      ),
                                    if (dashboard.luckBonus > 0) ...<Widget>[
                                      const SizedBox(width: 6),
                                      _LuckBadge(bonus: dashboard.luckBonus),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    ShaderMask(
                                      shaderCallback: (Rect b) =>
                                          CodexPalette.goldGrad.createShader(b),
                                      child: Text(
                                        '${dashboard.discovered}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w900,
                                          height: 1,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 2,
                                        left: 4,
                                      ),
                                      child: Text(
                                        '/ ${dashboard.total}',
                                        style: GoogleFonts.urbanist(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: CodexPalette.titanium,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 3),
                                      child: Text(
                                        '%$pct arşiv',
                                        style: GoogleFonts.urbanist(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: CodexPalette.gold
                                              .withValues(alpha: 0.9),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _GoldProgressBar(value: progress),
                      if (dashboard.milestones.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        CodexMilestoneTrack(milestones: dashboard.milestones),
                      ],
                      if (canClaim || claiming) ...<Widget>[
                        const SizedBox(height: 12),
                        CodexPressable(
                          onTap: claiming ? null : onClaim,
                          enabled: !claiming,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: CodexPalette.goldGrad,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color:
                                      CodexPalette.gold.withValues(alpha: 0.32),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              claiming
                                  ? 'Alınıyor...'
                                  : '${dashboard.claimableMilestones} ödül topla',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.urbanist(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: CodexPalette.void_,
                              ),
                            ),
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

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: GoogleFonts.urbanist(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _LuckBadge extends StatelessWidget {
  const _LuckBadge({required this.bonus});

  final int bonus;

  @override
  Widget build(BuildContext context) {
    return _StatChip(label: 'LUCK +$bonus', color: CodexPalette.solar);
  }
}

class _GoldProgressBar extends StatelessWidget {
  const _GoldProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: <Widget>[
            Container(color: CodexPalette.obsidian),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: CodexPalette.fuchsiaGoldGrad,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Milestones ───────────────────────────────────────────────────────────────

class CodexMilestoneTrack extends StatelessWidget {
  const CodexMilestoneTrack({super.key, required this.milestones});

  final List<CodexMilestone> milestones;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: milestones.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (BuildContext context, int index) {
          return CodexMilestoneCard(milestone: milestones[index]);
        },
      ),
    );
  }
}

class CodexMilestoneCard extends StatelessWidget {
  const CodexMilestoneCard({super.key, required this.milestone});

  final CodexMilestone milestone;

  @override
  Widget build(BuildContext context) {
    final Color accent = milestone.claimed
        ? CodexPalette.neon
        : milestone.claimable
            ? CodexPalette.gold
            : CodexPalette.titanium;
    final bool showGem = milestone.rewardGems > 0;
    final bool showGold = milestone.rewardGold > 0;

    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            CodexPalette.obsidian.withValues(alpha: 0.95),
            CodexPalette.void_.withValues(alpha: 0.96),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
        boxShadow: milestone.claimable
            ? <BoxShadow>[
                BoxShadow(
                  color: CodexPalette.gold.withValues(alpha: 0.22),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            '${milestone.threshold}',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: accent,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          if (showGold || showGem)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (showGold) ...<Widget>[
                    const Icon(
                      Icons.monetization_on_rounded,
                      size: 10,
                      color: CodexPalette.gold,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      _compact(milestone.rewardGold),
                      style: GoogleFonts.urbanist(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: CodexPalette.gold,
                      ),
                    ),
                  ],
                  if (showGold && showGem) const SizedBox(width: 4),
                  if (showGem) ...<Widget>[
                    Icon(
                      Icons.diamond_rounded,
                      size: 9,
                      color: AppColors.accentCyan,
                    ),
                    const SizedBox(width: 1),
                    Text(
                      '${milestone.rewardGems}',
                      style: GoogleFonts.urbanist(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentCyan,
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            const SizedBox(height: 11),
          const SizedBox(height: 3),
          Icon(
            milestone.claimed
                ? Icons.check_circle_rounded
                : milestone.claimable
                    ? Icons.redeem_rounded
                    : Icons.lock_outline_rounded,
            size: 13,
            color: accent.withValues(alpha: 0.9),
          ),
        ],
      ),
    );
  }

  static String _compact(int value) {
    if (value >= 1000000) {
      final double m = value / 1000000;
      return m == m.roundToDouble()
          ? '${m.toStringAsFixed(0)}M'
          : '${m.toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      final double k = value / 1000;
      return k == k.roundToDouble()
          ? '${k.toStringAsFixed(0)}K'
          : '${k.toStringAsFixed(0)}K';
    }
    return '$value';
  }
}

// ─── Category + rarity — slim Gkk-style rail ──────────────────────────────────

class CodexCategoryBar extends StatelessWidget {
  const CodexCategoryBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    required this.counts,
  });

  final List<(String type, String label, IconData icon)> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Map<String, (int discovered, int total)> counts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: CodexPalette.navy.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: CodexPalette.gold.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: List<Widget>.generate(tabs.length, (int i) {
            final (String type, String label, IconData _) = tabs[i];
            final bool active = i == selectedIndex;
            final (int d, int t) = counts[type] ?? (0, 0);
            return Expanded(
              child: CodexPressable(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  margin: EdgeInsets.only(left: i == 0 ? 0 : 3),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    gradient: active ? CodexPalette.goldGrad : null,
                    color: active ? null : Colors.transparent,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.urbanist(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: active
                              ? CodexPalette.void_
                              : CodexPalette.titanium,
                        ),
                      ),
                      Text(
                        '$d/$t',
                        style: GoogleFonts.urbanist(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? CodexPalette.void_.withValues(alpha: 0.65)
                              : CodexPalette.titanium.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class CodexRarityFilter extends StatelessWidget {
  const CodexRarityFilter({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<(String key, String label, int count)> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        physics: const BouncingScrollPhysics(),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (BuildContext context, int i) {
          final (String key, String label, int count) = options[i];
          final bool active = key == selected;
          final Color accent = _accentFor(key);
          return CodexPressable(
            onTap: () => onChanged(key),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  count > 0 ? '$label $count' : label,
                  style: GoogleFonts.urbanist(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                    color: active ? accent : CodexPalette.titanium,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 2,
                  width: active ? 18 : 0,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _accentFor(String key) {
    return switch (key) {
      'legendary' || 'mythic' => CodexPalette.gold,
      'epic' => CodexPalette.fuchsia,
      'rare' => AppColors.rarityRare,
      'hidden' => CodexPalette.coral,
      _ => CodexPalette.gold,
    };
  }
}

class CodexSectionHeader extends StatelessWidget {
  const CodexSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
      child: Row(
        children: <Widget>[
          Text(
            title,
            style: GoogleFonts.urbanist(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: CodexPalette.titanium,
            ),
          ),
          const Spacer(),
          Text(
            subtitle,
            style: GoogleFonts.urbanist(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: CodexPalette.titanium.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Entry cards (ref: 2.png collectible tiles) ───────────────────────────────

class CodexEntryCard extends StatelessWidget {
  const CodexEntryCard({
    super.key,
    required this.entry,
    required this.rarityColor,
    required this.onTap,
  });

  final CodexEntry entry;
  final Color rarityColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool discovered = entry.isDiscovered;
    final Color glow = discovered ? rarityColor : CodexPalette.fuchsia;
    final String hint = entry.hintLabel;

    return CodexPressable(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                CodexPalette.surface.withValues(alpha: 0.96),
                CodexPalette.void_.withValues(alpha: 0.98),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: discovered
                  ? rarityColor.withValues(alpha: 0.5)
                  : CodexPalette.titanium.withValues(alpha: 0.16),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: glow.withValues(alpha: discovered ? 0.16 : 0.06),
                blurRadius: 8,
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              const Positioned.fill(
                child: CustomPaint(
                  painter: DotGridPainter(spacing: 12, dotOpacity: 0.04),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                child: Column(
                  children: <Widget>[
                    if (hint.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.urbanist(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w700,
                            color: discovered
                                ? CodexPalette.solar
                                : CodexPalette.fuchsia.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Center(
                        child: _CodexEntryOrb(
                          discovered: discovered,
                          accent:
                              discovered ? rarityColor : CodexPalette.fuchsia,
                          size: 34,
                        ),
                      ),
                    ),
                    Text(
                      discovered ? entry.displayName : '???',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.urbanist(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: discovered
                            ? CodexPalette.textHi
                            : CodexPalette.titanium,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      discovered ? codexRarityLabel(entry.rarity) : 'GİZLİ',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.urbanist(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: discovered
                            ? rarityColor
                            : CodexPalette.fuchsia.withValues(alpha: 0.7),
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
}

class _CodexEntryOrb extends StatelessWidget {
  const _CodexEntryOrb({
    required this.discovered,
    required this.accent,
    this.size = 48,
  });

  final bool discovered;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final double inner = size * 0.82;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          Container(
            width: inner,
            height: inner,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  accent.withValues(alpha: 0.42),
                  accent.withValues(alpha: 0.06),
                  CodexPalette.void_.withValues(alpha: 0.4),
                ],
                stops: const <double>[0, 0.55, 1],
              ),
              border: Border.all(
                color: accent.withValues(alpha: 0.72),
                width: 1.5,
              ),
            ),
            child: Icon(
              discovered
                  ? Icons.auto_stories_rounded
                  : Icons.help_outline_rounded,
              color: discovered
                  ? accent
                  : CodexPalette.titanium.withValues(alpha: 0.85),
              size: size * 0.38,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Detail sheet (ref: 2.png popup + blur) ───────────────────────────────────

class CodexEntryDetailSheet extends StatelessWidget {
  const CodexEntryDetailSheet({
    super.key,
    required this.entry,
    required this.rarityColor,
  });

  final CodexEntry entry;
  final Color rarityColor;

  static Future<void> show(
    BuildContext context, {
    required CodexEntry entry,
    required Color rarityColor,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Kodex',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => CodexEntryDetailSheet(
        entry: entry,
        rarityColor: rarityColor,
      ),
      transitionBuilder: (BuildContext context, Animation<double> a, _, Widget child) {
        final Animation<double> curved = CurvedAnimation(
          parent: a,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String rarity = codexRarityLabel(entry.rarity);
    final String typeLabel = switch (entry.entryType) {
      'boss' => 'Boss',
      'dungeon' => 'Zindan',
      _ => 'Eşya',
    };

    return Material(
      color: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 360),
                  decoration: BoxDecoration(
                    gradient: CodexPalette.panelGrad,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: rarityColor.withValues(alpha: 0.65),
                      width: 1.5,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: rarityColor.withValues(alpha: 0.35),
                        blurRadius: 32,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: <Widget>[
                      const Positioned.fill(
                        child: CustomPaint(
                          painter: DotGridPainter(spacing: 13, dotOpacity: 0.07),
                        ),
                      ),
                      Positioned(
                        top: -30,
                        left: -20,
                        child: IgnorePointer(
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: <Color>[
                                  rarityColor.withValues(alpha: 0.3),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Align(
                              alignment: Alignment.topRight,
                              child: CodexPressable(
                                onTap: () => Navigator.of(context).pop(),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: CodexPalette.obsidian,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: CodexPalette.titanium
                                          .withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: CodexPalette.titanium,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            _CodexEntryOrb(
                              discovered: true,
                              accent: rarityColor,
                              size: 88,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'KAYIT ADI',
                              style: GoogleFonts.urbanist(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.8,
                                color: CodexPalette.titanium,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.displayName,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: CodexPalette.textHi,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${rarity.isEmpty ? 'BİLİNMEYEN' : rarity.toUpperCase()} · ${typeLabel.toUpperCase()}',
                              style: GoogleFonts.urbanist(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                color: rarityColor,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: CodexPalette.obsidian.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: CodexPalette.titanium.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Column(
                                children: <Widget>[
                                  _DetailRow(
                                    icon: Icons.place_rounded,
                                    label: 'Konum',
                                    value: entry.hintLabel,
                                  ),
                                  if (entry.discoveredAt != null) ...<Widget>[
                                    const SizedBox(height: 8),
                                    _DetailRow(
                                      icon: Icons.history_rounded,
                                      label: 'Keşif',
                                      value: _fmtDate(entry.discoveredAt!),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            CodexPressable(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: CodexPalette.goldGrad,
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: CodexPalette.gold.withValues(alpha: 0.35),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'KAPAT',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.urbanist(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                    color: CodexPalette.void_,
                                  ),
                                ),
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
          ),
        ),
      ),
    );
  }

  static String _fmtDate(DateTime dt) {
    final DateTime local = dt.toLocal();
    final String d =
        '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
    return d;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 14, color: CodexPalette.titanium),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.urbanist(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: CodexPalette.titanium,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.urbanist(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: CodexPalette.textHi,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Empty / loading ──────────────────────────────────────────────────────────

class CodexEmptyState extends StatelessWidget {
  const CodexEmptyState({super.key, required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          decoration: BoxDecoration(
            gradient: CodexPalette.panelGrad,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: CodexPalette.titanium.withValues(alpha: 0.22),
            ),
          ),
          child: Stack(
            children: <Widget>[
              const Positioned.fill(
                child: CustomPaint(
                  painter: DotGridPainter(spacing: 14, dotOpacity: 0.05),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: CodexPalette.obsidian,
                      border: Border.all(
                        color: CodexPalette.fuchsia.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(icon, size: 26, color: CodexPalette.titanium),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.urbanist(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: CodexPalette.titanium,
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

/// Legacy header kept for any external refs — maps to section header.
class CodexTabHeader extends StatelessWidget {
  const CodexTabHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.discovered,
    required this.total,
  });

  final String title;
  final IconData icon;
  final int discovered;
  final int total;

  @override
  Widget build(BuildContext context) {
    return CodexSectionHeader(
      title: title.toUpperCase(),
      subtitle: '$discovered / $total keşfedildi',
    );
  }
}
