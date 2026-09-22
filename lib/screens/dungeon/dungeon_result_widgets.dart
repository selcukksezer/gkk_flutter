import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../components/common/item_icon_view.dart';
import '../../models/dungeon_model.dart';
import '../../models/dungeon_siege_model.dart';
import '../../models/reputation_model.dart';
import 'dungeon_item_utils.dart';
import 'dungeon_victory_effects.dart';
import '../../l10n/l10n.dart';

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

class DungeonSiegeResultBanner extends StatelessWidget {
  const DungeonSiegeResultBanner({
    super.key,
    required this.bonus,
  });

  final DungeonSiegeRunBonus bonus;

  @override
  Widget build(BuildContext context) {
    if (!bonus.shouldShowAny) return const SizedBox.shrink();

    if (bonus.shouldShowNoSlotWarning) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.45)),
        ),
        child: Text(
          bonus.noSlotWarningText(
            slotLootPct: bonus.slotLootBonusPct > 0 ? bonus.slotLootBonusPct : 40,
            slotGoldPct: bonus.slotGoldBonusPct > 0 ? bonus.slotGoldBonusPct : 25,
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFFDE68A),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      );
    }

    final String? holdLine = bonus.holdExtraLine();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            const Color(0xFF7C3AED).withValues(alpha: 0.38),
            const Color(0xFF2563EB).withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFA78BFA).withValues(alpha: 0.65)),
      ),
      child: Column(
        children: <Widget>[
          const Text(
            'KUŞATMA PRIME — Slot bonusu uygulandı',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFEDE9FE),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            bonus.resultSummary(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFC4B5FD),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (holdLine != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              holdLine,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFFDE68A).withValues(alpha: 0.95),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ReputationBuffResultBanner extends StatelessWidget {
  const ReputationBuffResultBanner({
    super.key,
    required this.buffs,
  });

  final List<ReputationActiveBuff> buffs;

  @override
  Widget build(BuildContext context) {
    if (buffs.isEmpty) return const SizedBox.shrink();

    final String summary = buffs.map((ReputationActiveBuff b) => b.label()).join(' · ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            const Color(0xFF059669).withValues(alpha: 0.35),
            const Color(0xFF0EA5E9).withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.55)),
      ),
      child: Column(
        children: <Widget>[
          const Text(
            'İTİBAR MAĞAZASI — Aktif buff',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFD1FAE5),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            summary,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6EE7B7),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class DungeonResultBalanceNotes extends StatelessWidget {
  const DungeonResultBalanceNotes({
    super.key,
    this.rewardMultiplier,
    this.tutorialWrapperLootCount = 0,
    this.siegeBonusApplied = false,
    this.xpBreakdown,
  });

  final double? rewardMultiplier;
  final int tutorialWrapperLootCount;
  final bool siegeBonusApplied;
  final DungeonXpBreakdown? xpBreakdown;

  @override
  Widget build(BuildContext context) {
    final bool hasFarmPenalty = rewardMultiplier != null && rewardMultiplier! < 0.99;
    final bool hasWrapperLoot = tutorialWrapperLootCount > 0;
    final DungeonXpBreakdown? xp = xpBreakdown;
    final bool hasXpBonus = xp != null && xp.hasVisibleBonuses;
    if (!hasFarmPenalty && !hasWrapperLoot && !hasXpBonus) {
      return const SizedBox.shrink();
    }

    return Column(
      children: <Widget>[
        if (hasXpBonus) ...<Widget>[
          const SizedBox(height: 10),
          if (xp.hasMonumentBonus)
            Text(
              'Lonca anıtı XP +%${xp.monumentPct.toStringAsFixed(xp.monumentPct % 1 == 0 ? 0 : 1)}'
              '${xp.monumentXp > 0 ? ' (+${xp.monumentXp})' : ''}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFF2D74C).withValues(alpha: 0.9),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (xp.hasLuckBonus) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'Şans XP ×${xp.luckMult.toStringAsFixed(3)}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
          if (xp.hasCriticalBonus) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'Kritik zafer XP ×${xp.criticalMult.toStringAsFixed(1)}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ],
        if (hasFarmPenalty) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            'Farm cezası: ×${rewardMultiplier!.toStringAsFixed(2)}'
            '${siegeBonusApplied ? ' (kuşatma bonusundan ayrı uygulandı)' : ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
        if (hasWrapperLoot) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            'Öğretici ek loot: +$tutorialWrapperLootCount eşya (kuşatma bonusuna ek, ayrı düştü)',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF93C5FD).withValues(alpha: 0.85),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
            key: ValueKey<String>('${item.itemId}_$i'),
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
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: ItemIconView(
                        iconValue: '',
                        itemId: item.itemId,
                        size: 24,
                        fallback: epicPlus ? '✦' : '◆',
                      ),
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
                    if (item.quantity > 1) ...<Widget>[
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: color.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          'x${item.quantity}',
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
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
        label: context.l10n.altin,
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
          label: context.l10n.e_ya,
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
