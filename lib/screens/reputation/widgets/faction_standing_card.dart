import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../core/services/app_haptics.dart';
import '../../mekans/widgets/mekan_design.dart';
import 'faction_emblem_shader.dart';
import 'faction_standing_model.dart';

/// Glassmorphic Faction Standing Card adhering to V3 AAA Cyber-Fantasy luxury standard.
class FactionStandingCard extends StatefulWidget {
  const FactionStandingCard({
    super.key,
    required this.faction,
    required this.onClaimReward,
  });

  final FactionStandingData faction;
  final void Function(String factionId, String rewardId) onClaimReward;

  @override
  State<FactionStandingCard> createState() => _FactionStandingCardState();
}

class _FactionStandingCardState extends State<FactionStandingCard> {
  bool _expanded = false;

  String _formatNumber(int v) {
    return v.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  void _toggleExpanded() {
    AppHaptics.selection();
    setState(() => _expanded = !_expanded);
  }

  void _onCrestTapped() {
    AppHaptics.light();
  }

  void _onPerkPillTapped() {
    AppHaptics.selection();
    if (!_expanded) {
      setState(() => _expanded = true);
    }
  }

  void _onRewardPillTapped() {
    AppHaptics.medium();
    if (!_expanded) {
      setState(() => _expanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final FactionStandingData f = widget.faction;
    final FactionPaletteType pal = f.paletteType;
    final FactionStandingTier tier = f.currentTier;
    final Color tierColor = tier.colorForPalette(pal);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: pal.primary.withValues(alpha: 0.20),
            blurRadius: 28,
            offset: const Offset(0, 10),
            spreadRadius: -3,
          ),
          BoxShadow(
            color: MekanPalette.void_.withValues(alpha: 0.85),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: pal.primary.withValues(alpha: 0.45),
                width: 1.2,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  pal.cardGradient.first,
                  pal.cardGradient.last,
                  MekanPalette.void_.withValues(alpha: 0.98),
                ],
              ),
            ),
            child: Stack(
              children: <Widget>[
                // Dot Grid cyber pattern
                const Positioned.fill(
                  child: CustomPaint(
                    painter: DotGridPainter(spacing: 14, dotOpacity: 0.05),
                  ),
                ),
                // Specular top highlight sheen
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          pal.primary.withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // 1. Header: Allegiance Crest + Faction Info + Standing Tier Badge
                      _buildHeader(f, pal, tier, tierColor),
                      const SizedBox(height: 12),

                      // 2. Vendor Discount, Perks Pill, Reward Preview Pills
                      _buildPillsRow(f, pal),
                      const SizedBox(height: 14),

                      // 3. Standing Tier Step Indicator (Neutral -> Friendly -> Honored -> Revered -> Exalted)
                      _buildTierStepsIndicator(f, pal),
                      const SizedBox(height: 10),

                      // 4. Standing Progress Bar with Faction-Specific Gradient
                      _buildProgressBar(f, pal, tier, tierColor),
                      const SizedBox(height: 12),

                      // 5. Expandable Toggle Button with Tactile Tap
                      _buildExpandToggle(pal),

                      // 6. Expandable Area (Lore, Perks, Milestone Rewards)
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: _expanded
                            ? Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _buildExpandedDetails(f, pal, tier),
                              )
                            : const SizedBox.shrink(),
                        crossFadeState: _expanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 260),
                      ),
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

  Widget _buildHeader(
    FactionStandingData f,
    FactionPaletteType pal,
    FactionStandingTier tier,
    Color tierColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // Faction Allegiance Crest with radiant pedestal & tactile tap
        PressableScale(
          onTap: _onCrestTapped,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  pal.primary.withValues(alpha: 0.28),
                  pal.secondary.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
              ),
              border: Border.all(
                color: pal.primary.withValues(alpha: 0.55),
                width: 1.5,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: pal.primary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: FactionEmblemShaderWidget(
              paletteType: pal,
              category: f.category,
              size: 52,
              showGlow: true,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Category tag
              Row(
                children: <Widget>[
                  Icon(f.category.icon, size: 11, color: pal.glow),
                  const SizedBox(width: 4),
                  Text(
                    f.category.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: pal.glow,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                f.name,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: <Widget>[
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: pal.primary,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: pal.primary.withValues(alpha: 0.8),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      f.alignment,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: pal.primary.withValues(alpha: 0.95),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.location_on_rounded,
                    size: 10,
                    color: MekanPalette.textLow,
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      f.headquarters,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: MekanPalette.textLow,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // Current Standing Tier Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: tierColor.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tierColor.withValues(alpha: 0.65), width: 1.2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: tierColor.withValues(alpha: 0.20),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (tier == FactionStandingTier.exalted) ...<Widget>[
                    Icon(Icons.workspace_premium_rounded, size: 12, color: tierColor),
                    const SizedBox(width: 2),
                  ],
                  Text(
                    tier.romanBadge,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: tierColor,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              Text(
                tier.title.toUpperCase(),
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: tierColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPillsRow(FactionStandingData f, FactionPaletteType pal) {
    // Check if upcoming reward preview is available
    final FactionMilestoneReward? nextReward = f.milestones.cast<FactionMilestoneReward?>().firstWhere(
          (FactionMilestoneReward? m) => m != null && !m.isClaimed,
          orElse: () => null,
        );

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        // Vendor Discount Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: MekanPalette.gold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: MekanPalette.gold.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.storefront_rounded, color: MekanPalette.gold, size: 12),
              const SizedBox(width: 4),
              Text(
                'İndirim: -%${f.vendorDiscountPct}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: MekanPalette.gold,
                ),
              ),
            ],
          ),
        ),

        // Perks Pill with tactile tap
        PressableScale(
          onTap: _onPerkPillTapped,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: pal.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: pal.primary.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.military_tech_rounded, size: 12, color: pal.primary),
                const SizedBox(width: 4),
                Text(
                  '${f.unlockedPerksCount}/${f.perks.length} Ayrıcalık',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: pal.primary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Reward Preview Pill (Claimable or Upcoming Next Reward)
        if (f.claimableRewardsCount > 0)
          PressableScale(
            onTap: _onRewardPillTapped,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFFE52E2E), Color(0xFFFF5252)],
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: MekanPalette.ruby.withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '${f.claimableRewardsCount} Ödül Hazır',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (nextReward != null)
          PressableScale(
            onTap: _onRewardPillTapped,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.military_tech_outlined, color: MekanPalette.textMid, size: 11),
                  const SizedBox(width: 3),
                  Text(
                    'Sıradaki: ${nextReward.requiredTier.title}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: MekanPalette.textMid,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTierStepsIndicator(FactionStandingData f, FactionPaletteType pal) {
    const List<FactionStandingTier> tiers = FactionStandingTier.values;
    final int currentIdx = f.currentTier.index;

    return Row(
      children: List<Widget>.generate(tiers.length, (int i) {
        final FactionStandingTier t = tiers[i];
        final bool isCurrent = i == currentIdx;
        final bool isReached = i <= currentIdx;
        final Color c = t.colorForPalette(pal);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: i > 0 && i < tiers.length - 1 ? 2 : 1),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isCurrent
                    ? c.withValues(alpha: 0.28)
                    : (isReached ? c.withValues(alpha: 0.12) : const Color(0xFF0A0F1D).withValues(alpha: 0.6)),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isCurrent
                      ? c
                      : (isReached ? c.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.08)),
                  width: isCurrent ? 1.4 : 0.8,
                ),
                boxShadow: isCurrent
                    ? <BoxShadow>[
                        BoxShadow(
                          color: c.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      if (isReached && !isCurrent) ...<Widget>[
                        Icon(Icons.check_rounded, size: 8, color: c),
                        const SizedBox(width: 1),
                      ] else if (isCurrent) ...<Widget>[
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.only(right: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c,
                            boxShadow: <BoxShadow>[
                              BoxShadow(color: c, blurRadius: 4),
                            ],
                          ),
                        ),
                      ],
                      Text(
                        t.romanBadge,
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: isReached ? c : MekanPalette.textLow,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    t.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: isCurrent ? FontWeight.w900 : (isReached ? FontWeight.w700 : FontWeight.w500),
                      color: isReached ? (isCurrent ? Colors.white : c) : MekanPalette.textLow,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildProgressBar(
    FactionStandingData f,
    FactionPaletteType pal,
    FactionStandingTier tier,
    Color tierColor,
  ) {
    final bool isExalted = f.currentTier == FactionStandingTier.exalted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              isExalted
                  ? 'Maksimum Kademe: ${_formatNumber(f.points)} Puan'
                  : '${_formatNumber(f.points)} / ${_formatNumber(f.currentTier.maxPoints)} Puan',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: MekanPalette.textMid,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: tierColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: tierColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                isExalted
                    ? '★ YÜCE SEVİYE'
                    : '${_formatNumber(f.remainingPointsToNext)} itibar kaldı',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: tierColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Progress Bar Track with Faction-Specific Multi-Stop Gradient
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF090E1A),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Stack(
              children: <Widget>[
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: f.tierProgress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          pal.secondary,
                          pal.primary,
                          pal.accent,
                          pal.glow,
                        ],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: pal.primary.withValues(alpha: 0.75),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
                // Segmented subtle cyber ticks (25%, 50%, 75%)
                Row(
                  children: <Widget>[
                    const Spacer(flex: 25),
                    Container(width: 1, color: Colors.black.withValues(alpha: 0.45)),
                    const Spacer(flex: 25),
                    Container(width: 1, color: Colors.black.withValues(alpha: 0.45)),
                    const Spacer(flex: 25),
                    Container(width: 1, color: Colors.black.withValues(alpha: 0.45)),
                    const Spacer(flex: 25),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandToggle(FactionPaletteType pal) {
    return PressableScale(
      onTap: _toggleExpanded,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: pal.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: pal.primary.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _expanded ? 'Ayrıntıları Gizle' : 'Ayrıcalıklar & Ödülleri Göster',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: pal.primary.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(width: 5),
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 17,
                color: pal.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedDetails(
    FactionStandingData f,
    FactionPaletteType pal,
    FactionStandingTier currentTier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Divider(color: Colors.white12, height: 16),
        // Lore Description with quote styling
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(color: pal.primary.withValues(alpha: 0.7), width: 2.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.format_quote_rounded, size: 16, color: pal.primary.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  f.loreDescription,
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: MekanPalette.textMid,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Unlocked Perks Title
        Row(
          children: <Widget>[
            Icon(Icons.military_tech_rounded, size: 14, color: pal.primary),
            const SizedBox(width: 6),
            const Text(
              'KADEME AYRICALIKLARI',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: MekanPalette.textMid,
              ),
            ),
            const Spacer(),
            Text(
              '${f.unlockedPerksCount}/${f.perks.length} Aktif',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: pal.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...f.perks.map((FactionPerk perk) {
          final bool unlocked = perk.isUnlockedFor(currentTier);
          final Color iconColor = unlocked ? pal.primary : MekanPalette.textLow;

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: PressableScale(
              onTap: () => AppHaptics.light(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: unlocked
                      ? pal.primary.withValues(alpha: 0.08)
                      : const Color(0xFF0A0F1D).withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: unlocked ? pal.primary.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: unlocked ? pal.primary.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        unlocked ? perk.icon : Icons.lock_outline_rounded,
                        size: 15,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            perk.title,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: unlocked ? FontWeight.w800 : FontWeight.w600,
                              color: unlocked ? Colors.white : MekanPalette.textLow,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            perk.description,
                            style: TextStyle(
                              fontSize: 9.5,
                              color: unlocked ? MekanPalette.textMid : MekanPalette.textLow,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: unlocked ? pal.primary.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: unlocked ? pal.primary.withValues(alpha: 0.4) : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        perk.requiredTier.title,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: unlocked ? pal.primary : MekanPalette.textLow,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 12),

        // Milestone Rewards Section
        Row(
          children: <Widget>[
            const Icon(Icons.card_giftcard_rounded, size: 14, color: MekanPalette.gold),
            const SizedBox(width: 6),
            const Text(
              'KADEME ÖDÜLLERİ',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: MekanPalette.gold,
              ),
            ),
            const Spacer(),
            if (f.claimableRewardsCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: MekanPalette.ruby.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: MekanPalette.ruby.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '${f.claimableRewardsCount} ALINABİLİR',
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: MekanPalette.ruby,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ...f.milestones.map((FactionMilestoneReward reward) {
          final bool eligible = reward.isEligible(currentTier);
          final bool claimed = reward.isClaimed;

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: claimed
                    ? Colors.white.withValues(alpha: 0.03)
                    : (eligible ? MekanPalette.gold.withValues(alpha: 0.12) : const Color(0xFF0A0F1D).withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: claimed
                      ? Colors.white10
                      : (eligible ? MekanPalette.gold.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.05)),
                ),
                boxShadow: eligible
                    ? <BoxShadow>[
                        BoxShadow(
                          color: MekanPalette.gold.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: eligible
                          ? MekanPalette.gold.withValues(alpha: 0.20)
                          : Colors.white.withValues(alpha: 0.04),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      reward.icon,
                      size: 16,
                      color: claimed ? MekanPalette.textLow : (eligible ? MekanPalette.gold : MekanPalette.textLow),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          reward.title,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: eligible ? FontWeight.w800 : FontWeight.w600,
                            color: claimed ? MekanPalette.textLow : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          reward.rewardText,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: eligible ? MekanPalette.gold.withValues(alpha: 0.95) : MekanPalette.textLow,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (claimed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: MekanPalette.neon.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: MekanPalette.neon.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.check_circle_rounded, size: 10, color: MekanPalette.neon),
                          SizedBox(width: 3),
                          Text('Alındı', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: MekanPalette.neon)),
                        ],
                      ),
                    )
                  else if (eligible)
                    PressableScale(
                      onTap: () {
                        AppHaptics.success();
                        widget.onClaimReward(f.id, reward.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: MekanPalette.goldGrad,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: MekanPalette.gold.withValues(alpha: 0.45),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.card_giftcard_rounded, size: 11, color: Colors.black),
                            SizedBox(width: 3),
                            Text(
                              'AL',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '${reward.requiredTier.title} Gerekli',
                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: MekanPalette.textLow),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
