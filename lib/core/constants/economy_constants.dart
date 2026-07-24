/// Server-authoritative economy anchors — keep in sync with Supabase migrations.
abstract final class EconomyConstants {
  /// Internal loot-box RTP math only.
  static const int lootRtpGoldPerGem = 600;

  /// Shop gem→gold rate — must match `buy_gold_with_gems` migration.
  static const int shopGoldPerGem = 7000;

  /// VIP Battle Pass cost — must match `buy_vip_pass` RPC.
  static const int battlePassVipGemCost = 500;

  /// Preset gold packages (gems computed server-side from [shopGoldPerGem]).
  static const List<GoldShopPackage> goldShopPackages = <GoldShopPackage>[
    GoldShopPackage(id: 'gold_50k', gold: 50000),
    GoldShopPackage(id: 'gold_250k', gold: 250000),
    GoldShopPackage(id: 'gold_500k', gold: 500000),
    GoldShopPackage(id: 'gold_1m', gold: 1000000),
    GoldShopPackage(id: 'gold_2_5m', gold: 2500000),
    GoldShopPackage(id: 'gold_5m', gold: 5000000, isBestValue: true),
    GoldShopPackage(id: 'gold_10m', gold: 10000000),
  ];

  static int gemsRequiredForGold(int goldAmount) {
    if (goldAmount <= 0) return 0;
    return (goldAmount + shopGoldPerGem - 1) ~/ shopGoldPerGem;
  }

  /// IAP catalog (TL display; StoreKit grant via server when live).
  /// Bonus % vs [gem_starter] per-$ rate (100 💎 @ $0.99).
  static const List<GemIapPackage> gemIapPackages = <GemIapPackage>[
    GemIapPackage(
      id: 'gem_starter',
      gems: 100,
      priceUsd: r'$0.99',
      priceTry: '₺39',
      storeProductId: 'com.gkk.gems.starter',
      label: 'Başlangıç',
    ),
    GemIapPackage(
      id: 'gem_mini',
      gems: 250,
      priceUsd: r'$1.99',
      priceTry: '₺79',
      storeProductId: 'com.gkk.gems.mini',
      label: 'Mini Paket',
      bonusPercent: 25,
    ),
    GemIapPackage(
      id: 'gem_standard',
      gems: 500,
      priceUsd: r'$4.99',
      priceTry: '₺199',
      storeProductId: 'com.gkk.gems.standard',
      label: 'Standart',
    ),
    GemIapPackage(
      id: 'gem_plus',
      gems: 800,
      priceUsd: r'$6.99',
      priceTry: '₺279',
      storeProductId: 'com.gkk.gems.plus',
      label: 'Plus',
      bonusPercent: 15,
    ),
    GemIapPackage(
      id: 'gem_best_value',
      gems: 1200,
      priceUsd: r'$9.99',
      priceTry: '₺399',
      storeProductId: 'com.gkk.gems.best_value',
      label: 'Popüler',
      bonusPercent: 20,
      isBestValue: true,
    ),
    GemIapPackage(
      id: 'gem_mega',
      gems: 2600,
      priceUsd: r'$19.99',
      priceTry: '₺799',
      storeProductId: 'com.gkk.gems.mega',
      label: 'Mega',
      bonusPercent: 30,
    ),
    GemIapPackage(
      id: 'gem_ultra',
      gems: 5500,
      priceUsd: r'$39.99',
      priceTry: '₺1.599',
      storeProductId: 'com.gkk.gems.ultra',
      label: 'Ultra',
      bonusPercent: 40,
    ),
    GemIapPackage(
      id: 'gem_legend',
      gems: 12000,
      priceUsd: r'$79.99',
      priceTry: '₺3.199',
      storeProductId: 'com.gkk.gems.legend',
      label: 'Efsane',
      bonusPercent: 50,
    ),
  ];

  /// Where gems should be spent (PLAN_06 §7).
  static const List<GemSinkInfo> gemSinks = <GemSinkInfo>[
    GemSinkInfo('Prizma kasalar', 'Chase loot — ana elmas sink', '💎'),
    GemSinkInfo('Battle Pass VIP', '500 💎 / sezon', '🎖️'),
    GemSinkInfo('Hastane çıkış', '1–3 💎 / dk bekleme', '🏥'),
    GemSinkInfo('Banka slotu', '5 💎 / slot', '🏦'),
    GemSinkInfo('Stat reset scroll', '150–199 💎 (shop)', '📜'),
    GemSinkInfo('Gece Pazarı', 'Her gün 20–22 TR — sınırlı gem teklifleri', '🌙'),
  ];

  /// Primary gold sources (shop gem→gold is supplemental).
  static const List<String> goldSources = <String>[
    'Zindan ödülleri (birincil kaynak)',
    'Tesis üretimi & NPC satış',
    'Oyuncu pazarı (%5 komisyon sonrası)',
    'Vendor satış (~base_price %35)',
    'Günlük ödül & quest',
  ];
}

class GemIapPackage {
  const GemIapPackage({
    required this.id,
    required this.gems,
    required this.priceUsd,
    required this.priceTry,
    required this.storeProductId,
    this.label,
    this.bonusPercent,
    this.isBestValue = false,
  });

  final String id;
  final int gems;
  final String priceUsd;
  final String priceTry;
  final String storeProductId;
  final String? label;
  final int? bonusPercent;
  final bool isBestValue;
}

class GemSinkInfo {
  const GemSinkInfo(this.title, this.subtitle, this.emoji);

  final String title;
  final String subtitle;
  final String emoji;
}

class GoldShopPackage {
  const GoldShopPackage({
    required this.id,
    required this.gold,
    this.isBestValue = false,
  });

  final String id;
  final int gold;
  final bool isBestValue;

  int get gems => EconomyConstants.gemsRequiredForGold(gold);
}
