import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/reputation_model.dart';

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
}
