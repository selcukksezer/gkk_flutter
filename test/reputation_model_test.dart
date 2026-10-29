import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/reputation_model.dart';
import 'package:gkk_flutter/screens/reputation/widgets/faction_standing_model.dart';

void main() {
  group('ReputationShopItem', () {
    test('fromJson parses server catalog row', () {
      final ReputationShopItem item = ReputationShopItem.fromJson(<String, dynamic>{
        'id': 'gold_boost_30',
        'name': 'Altın Avcısı',
        'description': '30 dk altın +%15',
        'icon_key': 'gold',
        'cost_type': 'global',
        'cost_amount': 800,
        'rarity': 'rare',
        'effect_key': 'gold_boost',
        'effect_value': <String, dynamic>{'pct': 15},
        'duration_minutes': 30,
        'sort_order': 20,
      });

      expect(item.id, 'gold_boost_30');
      expect(item.costType, 'global');
      expect(item.costAmount, 800);
      expect(item.durationMinutes, 30);
    });
  });

  group('canAffordShopItem', () {
    const ReputationShopItem globalItem = ReputationShopItem(
      id: 'drop_boost_30',
      name: 'Loot',
      description: 'd',
      iconKey: 'loot',
      costType: 'global',
      costAmount: 1000,
      rarity: 'epic',
      effectKey: 'drop_boost',
    );

    test('global rep affordability', () {
      expect(
        canAffordShopItem(item: globalItem, globalRep: 999),
        isFalse,
      );
      expect(
        canAffordShopItem(item: globalItem, globalRep: 1000),
        isTrue,
      );
    });
  });

  group('ReputationActivityEntry', () {
    test('displaySource formats shop prefix', () {
      const ReputationActivityEntry e = ReputationActivityEntry(
        id: '1',
        activityType: 'spend',
        source: 'shop:gold_boost_30',
        amount: 800,
        currency: 'global',
      );
      expect(e.displaySource(), 'Mağaza: gold_boost_30');
    });
  });

  group('ReputationOverview', () {
    test('filters faction activity from overview json', () {
      final ReputationOverview overview = ReputationOverview.fromOverviewJson(<String, dynamic>{
        'global_reputation': 1200,
        'activity': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': '1',
            'activity_type': 'earn',
            'source': 'pvp',
            'amount': 50,
            'currency': 'global',
          },
          <String, dynamic>{
            'id': '2',
            'activity_type': 'spend',
            'source': 'donation',
            'amount': 5,
            'currency': 'faction',
          },
        ],
      });

      expect(overview.globalReputation, 1200);
      expect(overview.activity, hasLength(1));
      expect(overview.activity.first.source, 'pvp');
    });
  });

  group('rarityBorderColor', () {
    test('returns palette colors per rarity', () {
      expect(rarityBorderColor('legendary'), const Color(0xFFFFB800));
      expect(rarityBorderColor('epic'), const Color(0xFFE01E5A));
    });
  });

  group('applyReputationBuffPct', () {
    test('returns base when buff is zero', () {
      expect(applyReputationBuffPct(base: 100, buffPct: 0), 100);
    });

    test('applies percentage bonus to gold', () {
      expect(applyReputationBuffPct(base: 100, buffPct: 15), closeTo(115, 0.001));
    });

    test('applies percentage bonus to drop chance', () {
      expect(applyReputationBuffPct(base: 0.20, buffPct: 10), closeTo(0.22, 0.0001));
    });
  });

  group('computeSiegeRepGain', () {
    test('returns zero when rep bonus pct is zero', () {
      expect(computeSiegeRepGain(repBonusPct: 0), 0);
    });

    test('computes base siege rep', () {
      expect(computeSiegeRepGain(repBonusPct: 0.15), 3);
    });

    test('includes siege morale shop buff', () {
      expect(
        computeSiegeRepGain(repBonusPct: 0.15, siegeMoralePct: 25),
        3,
      );
      expect(
        computeSiegeRepGain(repBonusPct: 1.0, siegeMoralePct: 25),
        25,
      );
    });
  });

  group('FactionStandingTier & StandingData', () {
    test('tier thresholds and discounts are mapped accurately', () {
      expect(FactionStandingTier.neutral.minPoints, 0);
      expect(FactionStandingTier.neutral.vendorDiscountPct, 0);

      expect(FactionStandingTier.friendly.minPoints, 3000);
      expect(FactionStandingTier.friendly.vendorDiscountPct, 5);

      expect(FactionStandingTier.honored.minPoints, 9000);
      expect(FactionStandingTier.honored.vendorDiscountPct, 10);

      expect(FactionStandingTier.revered.minPoints, 25000);
      expect(FactionStandingTier.revered.vendorDiscountPct, 15);

      expect(FactionStandingTier.exalted.minPoints, 50000);
      expect(FactionStandingTier.exalted.vendorDiscountPct, 20);
    });

    test('faction standing points correctly compute tier and remaining progress', () {
      final List<FactionStandingData> presets = defaultFactionStandings();
      expect(presets, isNotEmpty);

      // Miragent Templars: 34,200 points -> Revered IV
      final FactionStandingData miragent = presets.firstWhere((FactionStandingData f) => f.id == 'miragent_templars');
      expect(miragent.currentTier, FactionStandingTier.revered);
      expect(miragent.vendorDiscountPct, 15);
      expect(miragent.remainingPointsToNext, 50000 - 34200);
      expect(miragent.nextTier, FactionStandingTier.exalted);
      expect(miragent.tierProgress, closeTo((34200 - 25000) / (50000 - 25000), 0.001));

      // Inggison Wardens: 2,100 points -> Neutral I
      final FactionStandingData inggison = presets.firstWhere((FactionStandingData f) => f.id == 'inggison_wardens');
      expect(inggison.currentTier, FactionStandingTier.neutral);
      expect(inggison.vendorDiscountPct, 0);
      expect(inggison.remainingPointsToNext, 3000 - 2100);
      expect(inggison.nextTier, FactionStandingTier.friendly);
    });

    test('claiming faction milestone reward immutably updates claimed state', () {
      final List<FactionStandingData> presets = defaultFactionStandings();
      final FactionStandingData fenris = presets.firstWhere((FactionStandingData f) => f.id == 'fenris_fangs');

      // Revered milestone reward f_rew_3 is initially unclaimed
      final FactionMilestoneReward initialReward = fenris.milestones.firstWhere((FactionMilestoneReward m) => m.id == 'f_rew_3');
      expect(initialReward.isClaimed, isFalse);
      expect(initialReward.isEligible(fenris.currentTier), isTrue);

      // Claim reward
      final FactionStandingData updatedFenris = fenris.claimReward('f_rew_3');
      final FactionMilestoneReward claimedReward = updatedFenris.milestones.firstWhere((FactionMilestoneReward m) => m.id == 'f_rew_3');
      expect(claimedReward.isClaimed, isTrue);
      expect(claimedReward.isEligible(updatedFenris.currentTier), isFalse);

      // Original instance remains unmodified (immutability check)
      expect(fenris.milestones.firstWhere((FactionMilestoneReward m) => m.id == 'f_rew_3').isClaimed, isFalse);
    });

    test('perks unlock strictly according to required tier', () {
      final List<FactionStandingData> presets = defaultFactionStandings();
      final FactionStandingData tigraki = presets.firstWhere((FactionStandingData f) => f.id == 'tigraki_workshop');

      // Tigraki is Honored (Tier III)
      expect(tigraki.currentTier, FactionStandingTier.honored);

      // Perks at or below Honored are unlocked
      final FactionPerk friendlyPerk = tigraki.perks.firstWhere((FactionPerk p) => p.requiredTier == FactionStandingTier.friendly);
      final FactionPerk honoredPerk = tigraki.perks.firstWhere((FactionPerk p) => p.requiredTier == FactionStandingTier.honored);
      final FactionPerk reveredPerk = tigraki.perks.firstWhere((FactionPerk p) => p.requiredTier == FactionStandingTier.revered);

      expect(friendlyPerk.isUnlockedFor(tigraki.currentTier), isTrue);
      expect(honoredPerk.isUnlockedFor(tigraki.currentTier), isTrue);
      expect(reveredPerk.isUnlockedFor(tigraki.currentTier), isFalse);
    });
  });
}
