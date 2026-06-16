import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/dungeon_model.dart';
import 'dungeon_item_utils.dart';
import 'dungeon_victory_effects.dart';

/// Scale-in wrapper for victory/defeat cards.
class AnimatedResultCard extends StatefulWidget {
  const AnimatedResultCard({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AnimatedResultCard> createState() => _AnimatedResultCardState();
}

class _AnimatedResultCardState extends State<AnimatedResultCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}

class DungeonResultBanner extends StatelessWidget {
  const DungeonResultBanner({
    super.key,
    required this.isCritical,
    required this.isFirstClear,
  });

  final bool isCritical;
  final bool isFirstClear;

  @override
  Widget build(BuildContext context) {
    if (!isCritical && !isFirstClear) return const SizedBox.shrink();

    return Column(
      children: <Widget>[
        if (isFirstClear)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  const Color(0xFFFBBF24).withValues(alpha: 0.35),
                  const Color(0xFFD97706).withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.7)),
            ),
            child: const Text(
              'İLK GEÇİŞ — Bonus ödül çarpanı aktif!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFFDE68A),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        if (isCritical)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  const Color(0xFFEF4444).withValues(alpha: 0.35),
                  const Color(0xFFF97316).withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5).withValues(alpha: 0.6)),
            ),
            child: const Text(
              'KRİTİK ZAFER! +50% altın ve XP',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFFECACA),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
      ],
    );
  }
}

class DungeonItemRevealList extends StatefulWidget {
  const DungeonItemRevealList({
    super.key,
    required this.items,
  });

  final List<DungeonItemDrop> items;

  @override
  State<DungeonItemRevealList> createState() => _DungeonItemRevealListState();
}

class _DungeonItemRevealListState extends State<DungeonItemRevealList> {
  int _revealedCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.items.isEmpty) return;
    _scheduleNext(0);
  }

  void _scheduleNext(int index) {
    if (!mounted || index >= widget.items.length) return;
    Future<void>.delayed(Duration(milliseconds: index == 0 ? 400 : 550), () {
      if (!mounted) return;
      setState(() => _revealedCount = index + 1);
      _scheduleNext(index + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final List<DungeonItemDrop> sorted = List<DungeonItemDrop>.from(widget.items)
      ..sort((DungeonItemDrop a, DungeonItemDrop b) =>
          raritySortWeight(b.rarity).compareTo(raritySortWeight(a.rarity)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text(
          'DÜŞEN EŞYALAR',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        ...List<Widget>.generate(sorted.length, (int i) {
          if (i >= _revealedCount) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
                  ),
                ),
              ),
            );
          }
          final DungeonItemDrop item = sorted[i];
          final Color color = dungeonRarityColor(item.rarity);
          final bool epicPlus = isEpicPlusRarity(item.rarity);
          return TweenAnimationBuilder<double>(
            key: ValueKey<String>(item.itemId),
            tween: Tween<double>(begin: 0, end: 1),
            duration: Duration(milliseconds: epicPlus ? 700 : 400),
            curve: epicPlus ? Curves.elasticOut : Curves.easeOutBack,
            builder: (BuildContext context, double t, Widget? child) {
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY((1 - t) * math.pi * 0.5),
                child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: epicPlus ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: epicPlus ? 0.9 : 0.5)),
                  boxShadow: epicPlus
                      ? <BoxShadow>[
                          BoxShadow(
                            color: color.withValues(alpha: 0.45),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: <Widget>[
                    Text(
                      epicPlus ? '✦' : '◆',
                      style: TextStyle(color: color, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.name.isNotEmpty ? item.name : formatDungeonItemName(item.itemId),
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      item.rarity.toUpperCase(),
                      style: TextStyle(
                        color: color.withValues(alpha: 0.85),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class DungeonMilestoneBanner extends StatelessWidget {
  const DungeonMilestoneBanner({super.key, required this.rewards});

  final List<DungeonMilestoneReward> rewards;

  @override
  Widget build(BuildContext context) {
    if (rewards.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF60A5FA).withValues(alpha: 0.5)),
      ),
      child: Column(
        children: <Widget>[
          const Text(
            'KİLOMETRE TAŞI ÖDÜLÜ',
            style: TextStyle(
              color: Color(0xFF93C5FD),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          ...rewards.map(
            (DungeonMilestoneReward r) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                r.label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DungeonVictoryPanel extends StatelessWidget {
  const DungeonVictoryPanel({
    super.key,
    required this.gold,
    required this.xp,
    required this.items,
    required this.isCritical,
    required this.isFirstClear,
    required this.milestoneRewards,
    this.rewardMultiplier,
  });

  final int gold;
  final int xp;
  final List<DungeonItemDrop> items;
  final bool isCritical;
  final bool isFirstClear;
  final List<DungeonMilestoneReward> milestoneRewards;
  final double? rewardMultiplier;

  @override
  Widget build(BuildContext context) {
    final List<Widget> badges = <Widget>[
      VictoryBadge(
        icon: '💰',
        label: 'ALTIN',
        value: '$gold',
        color: const Color(0xFFDDB200),
      ),
      const SizedBox(width: kBadgeGapBetween),
      VictoryBadge(
        icon: '✨',
        label: 'XP',
        value: '+$xp',
        color: const Color(0xFF22C55E),
      ),
      if (items.isNotEmpty) ...<Widget>[
        const SizedBox(width: kBadgeGapBetween),
        VictoryBadge(
          icon: '🎒',
          label: 'EŞYA',
          value: '${items.length}',
          color: const Color(0xFF3B82F6),
        ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DungeonResultBanner(isCritical: isCritical, isFirstClear: isFirstClear),
        DungeonMilestoneBanner(rewards: milestoneRewards),
        AnimatedResultCard(
          child: VictoryCard(
            animation: const AlwaysStoppedAnimation<double>(1.0),
            badges: badges,
            intenseGlow: isCritical || isFirstClear,
          ),
        ),
        if (rewardMultiplier != null && rewardMultiplier! < 0.99) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'Ödül çarpanı: ×${rewardMultiplier!.toStringAsFixed(2)} (farm cezası)',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
        const SizedBox(height: 12),
        DungeonItemRevealList(items: items),
      ],
    );
  }
}
