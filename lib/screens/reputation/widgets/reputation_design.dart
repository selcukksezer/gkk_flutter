import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../components/common/gkk_tab_bar.dart';
import '../../../components/layout/game_screen_background.dart';
import '../../mekans/widgets/mekan_design.dart';

export '../../mekans/widgets/mekan_design.dart' show MekanPalette, PressableScale, GlowChip, NeonPanel;

/// Section title with gold accent bar — Han/Mekan style.
class ReputationSectionTitle extends StatelessWidget {
  const ReputationSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: MekanPalette.gold,
                borderRadius: BorderRadius.circular(2),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: MekanPalette.gold.withValues(alpha: 0.45),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: MekanPalette.textHi,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 13),
            child: Text(
              subtitle!,
              style: const TextStyle(fontSize: 11.5, color: MekanPalette.textMid),
            ),
          ),
        ],
      ],
    );
  }
}

/// Vault-style hero card for total reputation + tier progress.
class ReputationVaultHeader extends StatelessWidget {
  const ReputationVaultHeader({
    super.key,
    required this.totalRep,
    required this.tierTitle,
    required this.tierColor,
    required this.nextTierTitle,
    required this.progress,
    this.activeBuffs = const <String>[],
  });

  final int totalRep;
  final String tierTitle;
  final Color tierColor;
  final String nextTierTitle;
  final double progress;
  final List<String> activeBuffs;

  String _formatRep(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                MekanPalette.navy.withValues(alpha: 0.88),
                MekanPalette.void_.withValues(alpha: 0.94),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: MekanPalette.gold.withValues(alpha: 0.35)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: MekanPalette.gold.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              const Positioned.fill(
                child: CustomPaint(painter: DotGridPainter(spacing: 14, dotOpacity: 0.05)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: MekanPalette.fuchsia.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: MekanPalette.fuchsia.withValues(alpha: 0.5)),
                        ),
                        child: const Text(
                          'TOPLAM İTİBAR',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: MekanPalette.fuchsia,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.military_tech_rounded, color: tierColor, size: 28),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      const Icon(Icons.star_rounded, color: MekanPalette.gold, size: 36),
                      const SizedBox(width: 8),
                      Text(
                        _formatRep(totalRep),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: MekanPalette.textHi,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: tierColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: tierColor.withValues(alpha: 0.45)),
                        ),
                        child: Text(
                          tierTitle,
                          style: TextStyle(
                            color: tierColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Sonraki: $nextTierTitle',
                        style: const TextStyle(fontSize: 10, color: MekanPalette.textMid),
                      ),
                      Text(
                        '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 10, color: tierColor, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: MekanPalette.obsidian,
                      valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                    ),
                  ),
                  if (activeBuffs.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: activeBuffs
                          .map(
                            (String b) => GlowChip(
                              icon: Icons.auto_awesome_rounded,
                              label: b,
                              color: MekanPalette.neon,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Segmented tab pill row.
class ReputationTabBar extends StatelessWidget {
  const ReputationTabBar({
    super.key,
    required this.index,
    required this.onChanged,
  });

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const List<String> labels = <String>['Kazan', 'Harca', 'Geçmiş'];
    return GkkSegmentedTabBar(
      labels: labels,
      activeIndex: index,
      onChanged: onChanged,
      padding: EdgeInsets.zero,
    );
  }
}

/// Fade + slide list item wrapper.
class ReputationSlideIn extends StatefulWidget {
  const ReputationSlideIn({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  State<ReputationSlideIn> createState() => _ReputationSlideInState();
}

class _ReputationSlideInState extends State<ReputationSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future<void>.delayed(Duration(milliseconds: 40 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
