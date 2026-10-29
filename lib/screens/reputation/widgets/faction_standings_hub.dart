import 'package:flutter/material.dart';

import '../../mekans/widgets/mekan_design.dart';
import 'faction_standing_card.dart';
import 'faction_standing_model.dart';

/// Full interactive hub for Aion 2 Mobile Faction Standings & Order Alliances.
class FactionStandingsHub extends StatefulWidget {
  const FactionStandingsHub({
    super.key,
    this.factions,
    this.onRewardClaimed,
  });

  final List<FactionStandingData>? factions;
  final void Function(String factionId, String rewardId)? onRewardClaimed;

  @override
  State<FactionStandingsHub> createState() => _FactionStandingsHubState();
}

class _FactionStandingsHubState extends State<FactionStandingsHub> {
  late List<FactionStandingData> _factions;
  int _categoryIndex = 0; // 0: All, 1: Order, 2: Craft, 3: Council

  @override
  void initState() {
    super.initState();
    _factions = widget.factions ?? defaultFactionStandings();
  }

  void _claimReward(String factionId, String rewardId) {
    setState(() {
      _factions = _factions.map((FactionStandingData f) {
        if (f.id == factionId) {
          return f.claimReward(rewardId);
        }
        return f;
      }).toList();
    });

    widget.onRewardClaimed?.call(factionId, rewardId);

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: <Widget>[
            const Icon(Icons.check_circle_rounded, color: MekanPalette.neon, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Fraksiyon Ã¶dÃ¼lÃ¼ baÅŸarÄ±yla teslim alÄ±ndÄ±!',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 2200),
      ),
    );
  }

  List<FactionStandingData> get _filteredFactions {
    switch (_categoryIndex) {
      case 1:
        return _factions.where((FactionStandingData f) => f.category == FactionCategory.order).toList();
      case 2:
        return _factions.where((FactionStandingData f) => f.category == FactionCategory.craft).toList();
      case 3:
        return _factions.where((FactionStandingData f) => f.category == FactionCategory.council).toList();
      default:
        return _factions;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<FactionStandingData> items = _filteredFactions;
    final int totalClaimable = _factions.fold(0, (int sum, FactionStandingData f) => sum + f.claimableRewardsCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Realm Standing Summary Strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF081426).withValues(alpha: 0.85),
            border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.shield_moon_rounded, color: Color(0xFF00E5FF), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${_factions.length} Aktif Birlik',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              if (totalClaimable > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: MekanPalette.ruby.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: MekanPalette.ruby.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.stars_rounded, color: MekanPalette.ruby, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        '$totalClaimable Ã–dÃ¼l HazÄ±r',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: MekanPalette.ruby,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              _categoryChip(0, 'TÃ¼mÃ¼', Icons.all_inclusive_rounded),
              const SizedBox(width: 6),
              _categoryChip(1, 'Hanedanlar', Icons.military_tech_rounded),
              const SizedBox(width: 6),
              _categoryChip(2, 'Zanaat', Icons.handyman_rounded),
              const SizedBox(width: 6),
              _categoryChip(3, 'Konseyler', Icons.account_balance_rounded),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Faction Cards List
        ...List<Widget>.generate(items.length, (int i) {
          final FactionStandingData faction = items[i];
          return Padding(
            padding: EdgeInsets.only(bottom: i < items.length - 1 ? 12 : 0),
            child: FactionStandingCard(
              faction: faction,
              onClaimReward: _claimReward,
            ),
          );
        }),
      ],
    );
  }

  Widget _categoryChip(int index, String label, IconData icon) {
    final bool active = _categoryIndex == index;
    return InkWell(
      onTap: () => setState(() => _categoryIndex = index),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? MekanPalette.gold.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? MekanPalette.gold : Colors.white.withValues(alpha: 0.1),
            width: active ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 13,
              color: active ? MekanPalette.gold : MekanPalette.textLow,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? MekanPalette.gold : MekanPalette.textMid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
