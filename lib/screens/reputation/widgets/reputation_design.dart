import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../components/common/gkk_tab_bar.dart';
import '../../../components/layout/game_screen_background.dart';
import '../../mekans/widgets/mekan_design.dart';

export '../../mekans/widgets/mekan_design.dart' show MekanPalette, PressableScale, GlowChip, NeonPanel;
export 'faction_emblem_shader.dart';
export 'faction_standing_card.dart';
export 'faction_standing_model.dart';
export 'faction_standings_hub.dart';

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
    this.remainingToNext,
  });

  final int totalRep;
  final String tierTitle;
  final Color tierColor;
  final String nextTierTitle;
  final double progress;
  final List<String> activeBuffs;
  final int? remainingToNext;

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
                        remainingToNext != null && remainingToNext! > 0
                            ? 'Sonraki: $nextTierTitle · ${_formatRep(remainingToNext!)} itibar kaldı'
                            : 'Sonraki: $nextTierTitle',
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

/// Tüm itibar kademeleri — mevcut kademe vurgulu dikey merdiven.
class ReputationTierLadder extends StatelessWidget {
  const ReputationTierLadder({super.key, required this.currentRep});

  final int currentRep;

  static const List<(String, int, Color)> _tiers = <(String, int, Color)>[
    ('Acemi', 0, Color(0xFF9CA3AF)),
    ('Tanınan', 5000, Color(0xFF4ADE80)),
    ('Saygın', 20000, Color(0xFF60A5FA)),
    ('Ünlü', 80000, Color(0xFFC084FC)),
    ('Efsanevi', 170000, Color(0xFFFBBF24)),
    ('Destansı', 280000, Color(0xFFF87171)),
    ('İmparator', 356000, Color(0xFFFFD700)),
  ];

  String _formatRep(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
  }

  int get _currentIndex {
    int idx = 0;
    for (int i = 0; i < _tiers.length; i++) {
      if (currentRep > _tiers[i].$2 || (i == 0 && currentRep >= 0)) idx = i;
    }
    return idx;
  }

  @override
  Widget build(BuildContext context) {
    final int currentIdx = _currentIndex;

    return NeonPanel(
      accent: MekanPalette.gold,
      padding: const EdgeInsets.all(14),
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'KADEMELER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: MekanPalette.textMid,
            ),
          ),
          const SizedBox(height: 10),
          for (int i = _tiers.length - 1; i >= 0; i--)
            Padding(
              padding: EdgeInsets.only(bottom: i > 0 ? 6 : 0),
              child: _tierRow(i, isCurrent: i == currentIdx, reached: i <= currentIdx),
            ),
        ],
      ),
    );
  }

  Widget _tierRow(int i, {required bool isCurrent, required bool reached}) {
    final (String title, int minRep, Color color) = _tiers[i];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrent
            ? color.withValues(alpha: 0.12)
            : MekanPalette.obsidian.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrent
              ? color.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            reached ? Icons.military_tech_rounded : Icons.lock_outline_rounded,
            size: 16,
            color: reached ? color : MekanPalette.textLow,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
                color: reached ? color : MekanPalette.textLow,
              ),
            ),
          ),
          if (isCurrent)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'BURADASIN',
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: color),
              ),
            ),
          Text(
            i == 0 ? '—' : '${_formatRep(minRep)}+',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: reached ? MekanPalette.textMid : MekanPalette.textLow,
            ),
          ),
        ],
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
    this.labels = const <String>['Birlikler', 'Kazan', 'Harca', 'Geçmiş'],
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
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
