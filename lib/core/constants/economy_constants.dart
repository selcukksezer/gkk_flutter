/// Server-authoritative economy anchors — keep in sync with Supabase migrations.
abstract final class EconomyConstants {
  /// Internal loot-box RTP math only (NOT a gem→gold purchase rate).
  static const int lootRtpGoldPerGem = 600;

  /// IAP catalog (TL display; StoreKit grant via server when live).
  static const List<GemIapPackage> gemIapPackages = <GemIapPackage>[
    GemIapPackage(
      id: 'gem_starter',
      gems: 100,
      priceUsd: r'$0.99',
      priceTry: '₺39',
      storeProductId: 'com.gkk.gems.starter',
    ),
    GemIapPackage(
      id: 'gem_standard',
      gems: 500,
      priceUsd: r'$4.99',
      priceTry: '₺199',
      storeProductId: 'com.gkk.gems.standard',
    ),
    GemIapPackage(
      id: 'gem_best_value',
      gems: 1200,
      priceUsd: r'$9.99',
      priceTry: '₺399',
      storeProductId: 'com.gkk.gems.best_value',
      isBestValue: true,
    ),
    GemIapPackage(
      id: 'gem_mega',
      gems: 2600,
      priceUsd: r'$19.99',
      priceTry: '₺799',
      storeProductId: 'com.gkk.gems.mega',
    ),
  ];

  /// Where gems should be spent (PLAN_06 §7).
  static const List<GemSinkInfo> gemSinks = <GemSinkInfo>[
    GemSinkInfo('Prizma kasalar', 'Chase loot — ana elmas sink', '💎'),
    GemSinkInfo('Battle Pass VIP', '500 💎 / sezon', '🎖️'),
    GemSinkInfo('Hastane çıkış', '1–3 💎 / dk bekleme', '🏥'),
    GemSinkInfo('Banka slotu', '5 💎 / slot', '🏦'),
    GemSinkInfo('Stat reset scroll', '150–199 💎 (shop)', '📜'),
  ];

  /// Gold comes from gameplay — not gem exchange.
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
    this.isBestValue = false,
  });

  final String id;
  final int gems;
  final String priceUsd;
  final String priceTry;
  final String storeProductId;
  final bool isBestValue;
}

class GemSinkInfo {
  const GemSinkInfo(this.title, this.subtitle, this.emoji);

  final String title;
  final String subtitle;
  final String emoji;
}
