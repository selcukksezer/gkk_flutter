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
      expect(item.usesFactionRep, isFalse);
      expect(item.costAmount, 800);
      expect(item.durationMinutes, 30);
    });

    test('usesFactionRep true for faction cost type', () {
      const ReputationShopItem item = ReputationShopItem(
        id: 'energy_refill',
        name: 'Enerji',
        description: 'test',
        iconKey: 'bolt',
        costType: 'faction',
        costAmount: 10,
        rarity: 'uncommon',
        effectKey: 'energy_refill',
      );
      expect(item.usesFactionRep, isTrue);
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

    const ReputationShopItem factionItem = ReputationShopItem(
      id: 'energy_refill',
      name: 'Enerji',
      description: 'd',
      iconKey: 'bolt',
      costType: 'faction',
      costAmount: 10,
      rarity: 'uncommon',
      effectKey: 'energy_refill',
    );

    test('global rep affordability', () {
      expect(
        canAffordShopItem(item: globalItem, globalRep: 999, factionRep: 100),
        isFalse,
      );
      expect(
        canAffordShopItem(item: globalItem, globalRep: 1000, factionRep: 0),
        isTrue,
      );
    });

    test('faction rep affordability', () {
      expect(
        canAffordShopItem(item: factionItem, globalRep: 99999, factionRep: 9),
        isFalse,
      );
      expect(
        canAffordShopItem(item: factionItem, globalRep: 0, factionRep: 10),
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

  group('factionTierLabel', () {
    test('maps rep bands to Turkish tiers', () {
      expect(factionTierLabel(0), 'Düşman');
      expect(factionTierLabel(45), 'Dostane');
      expect(factionTierLabel(90), 'Onurlu');
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
