import 'package:intl/intl.dart';

import '../../models/facility_model.dart';

/// Tesis tipi metadata — client-side catalog (facilities hub ile uyumlu).
class FacilityMeta {
  const FacilityMeta({
    required this.name,
    required this.icon,
    required this.description,
    required this.baseRate,
    required this.baseUpgradeCost,
    required this.multiplier,
    required this.resources,
  });

  final String name;
  final String icon;
  final String description;
  final double baseRate;
  final int baseUpgradeCost;
  final double multiplier;
  final List<String> resources;
}

const int kFacilityProductionDurationSeconds = 120;

const String kFacilityDetailTabOverview = 'overview';
const String kFacilityDetailTabQueue = 'queue';

/// URL `?tab=` değerini güvenli tab id'ye çevirir.
String parseFacilityDetailTabId(String? raw) {
  if (raw == kFacilityDetailTabQueue || raw == 'depo') {
    return kFacilityDetailTabQueue;
  }
  return kFacilityDetailTabOverview;
}

const List<String> kFacilityResourceRarities = <String>[
  'common',
  'uncommon',
  'rare',
  'epic',
  'legendary',
  'mythic',
];

const Map<String, int> kFacilityRarityUnlockLevels = <String, int>{
  'common': 1,
  'uncommon': 3,
  'rare': 5,
  'epic': 7,
  'legendary': 9,
  'mythic': 10,
};

const Map<int, Map<String, int>> kFacilityDropRatesByLevel = <int, Map<String, int>>{
  1: <String, int>{'common': 100, 'uncommon': 0, 'rare': 0, 'epic': 0, 'legendary': 0, 'mythic': 0},
  2: <String, int>{'common': 90, 'uncommon': 10, 'rare': 0, 'epic': 0, 'legendary': 0, 'mythic': 0},
  3: <String, int>{'common': 70, 'uncommon': 25, 'rare': 5, 'epic': 0, 'legendary': 0, 'mythic': 0},
  4: <String, int>{'common': 55, 'uncommon': 30, 'rare': 13, 'epic': 2, 'legendary': 0, 'mythic': 0},
  5: <String, int>{'common': 40, 'uncommon': 30, 'rare': 20, 'epic': 8, 'legendary': 2, 'mythic': 0},
  6: <String, int>{'common': 30, 'uncommon': 28, 'rare': 22, 'epic': 14, 'legendary': 5, 'mythic': 1},
  7: <String, int>{'common': 22, 'uncommon': 25, 'rare': 23, 'epic': 18, 'legendary': 9, 'mythic': 3},
  8: <String, int>{'common': 15, 'uncommon': 22, 'rare': 24, 'epic': 22, 'legendary': 12, 'mythic': 5},
  9: <String, int>{'common': 10, 'uncommon': 18, 'rare': 24, 'epic': 24, 'legendary': 16, 'mythic': 8},
  10: <String, int>{'common': 5, 'uncommon': 14, 'rare': 22, 'epic': 26, 'legendary': 20, 'mythic': 13},
};

const Map<String, FacilityMeta> kFacilityMetaByType = <String, FacilityMeta>{
  'mining': FacilityMeta(
    name: 'Maden Ocağı',
    icon: '⛏️',
    description: 'Demir, bakır, altın ve gümüş cevheri çıkarır',
    baseRate: 10,
    baseUpgradeCost: 100000,
    multiplier: 1.5,
    resources: <String>['Ham Demir', 'Saf Bakır', 'Gümüş Damarı', 'Asil Altın', 'Mithril', 'Saf Celestium'],
  ),
  'quarry': FacilityMeta(
    name: 'Taş Ocağı',
    icon: '🪨',
    description: 'Granit, mermer ve kristal çıkarır',
    baseRate: 8,
    baseUpgradeCost: 120000,
    multiplier: 1.5,
    resources: <String>['Sıradan Taş', 'Katı Granit', 'Beyaz Mermer', 'Kara Obsidyen', 'Adamantit Parçası', 'Ebedi Taş'],
  ),
  'lumber_mill': FacilityMeta(
    name: 'Kereste Fabrikası',
    icon: '🪵',
    description: 'Meşe, çam ve bambu odunu üretir',
    baseRate: 12,
    baseUpgradeCost: 150000,
    multiplier: 1.5,
    resources: <String>['Meşe Kerestesi', 'Çam Kerestesi', 'Abanoz', 'Ejder Ağacı', 'Dünya Ağacı Dalı', 'Yggdrasil Dalı'],
  ),
  'clay_pit': FacilityMeta(
    name: 'Kil Ocağı',
    icon: '🏺',
    description: 'Seramik kili ve tuğla malzemesi çıkarır',
    baseRate: 15,
    baseUpgradeCost: 180000,
    multiplier: 1.5,
    resources: <String>['Sıradan Kil', 'Seramik Kili', 'Altın Kil', 'Ejder Kili', 'Elementel Kil', 'İlkel Kil'],
  ),
  'sand_quarry': FacilityMeta(
    name: 'Kum Ocağı',
    icon: '🏖️',
    description: 'Cam kumu ve kristal kumu toplar',
    baseRate: 20,
    baseUpgradeCost: 200000,
    multiplier: 1.5,
    resources: <String>['Sıradan Kum', 'Cam Kumu', 'Kristal Kum', 'Altın Kum', 'Yıldız Kumu', 'Zaman Kumu'],
  ),
  'farming': FacilityMeta(
    name: 'Çiftlik',
    icon: '🌾',
    description: 'Buğday, sebze ve pamuk yetiştirir',
    baseRate: 18,
    baseUpgradeCost: 250000,
    multiplier: 1.5,
    resources: <String>['Sıradan Buğday', 'Güçlü Arpa', 'Altın Pamuk', 'Ejder Meyvesi', 'Yaşam Tohumu', 'Ebedi Bitki'],
  ),
  'herb_garden': FacilityMeta(
    name: 'Ot Bahçesi',
    icon: '🌿',
    description: 'Şifalı otlar ve nadir bitkiler yetiştirir',
    baseRate: 10,
    baseUpgradeCost: 300000,
    multiplier: 1.5,
    resources: <String>['Şifalı Ot', 'Zehirli Ot', 'Ay Çiçeği', 'Ejder Kökü', 'Ölümsüzlük Otu', 'Hayat Özü'],
  ),
  'ranch': FacilityMeta(
    name: 'Hayvancılık',
    icon: '🐄',
    description: 'Deri, kemik ve yün üretir',
    baseRate: 12,
    baseUpgradeCost: 350000,
    multiplier: 1.5,
    resources: <String>['Sıradan Deri', 'Güçlü Yün', 'Canavar Boynuzu', 'Wyvern Derisi', 'Unicorn Tırnağı', 'Anka Kanı'],
  ),
  'apiary': FacilityMeta(
    name: 'Arıcılık',
    icon: '🐝',
    description: 'Bal, balmumu ve arı zehiri toplar',
    baseRate: 8,
    baseUpgradeCost: 400000,
    multiplier: 1.5,
    resources: <String>['Orman Balı', 'Saf Balmumu', 'Kraliyet Jelesi', 'Arı Zehiri Özü', 'Altın Bal', 'İlahi Ambrosia'],
  ),
  'mushroom_farm': FacilityMeta(
    name: 'Mantar Çiftliği',
    icon: '🍄',
    description: 'Şifalı ve zehirli mantarlar yetiştirir',
    baseRate: 10,
    baseUpgradeCost: 500000,
    multiplier: 1.5,
    resources: <String>['Şifalı Mantar', 'Parlayan Mantar', 'Zehirli Mantar', 'Kristal Mantar', 'Zaman Mantarı', 'İlkel Mantar'],
  ),
  'rune_mine': FacilityMeta(
    name: 'Rune Madeni',
    icon: '🔮',
    description: 'Ham rune taşları ve büyülü kristaller çıkarır',
    baseRate: 5,
    baseUpgradeCost: 600000,
    multiplier: 1.6,
    resources: <String>['Ham Rune Taşı', 'Büyü Kristali', 'Enerji Parçası', 'Rune Çekirdeği', 'Gizemli Kalp', 'Rune Özü'],
  ),
  'holy_spring': FacilityMeta(
    name: 'Kutsal Kaynak',
    icon: '⛲',
    description: 'Kutsal su ve mana kristalleri üretir',
    baseRate: 6,
    baseUpgradeCost: 700000,
    multiplier: 1.6,
    resources: <String>['Kutsal Su', 'Mana Kristali', 'Arındırma Suyu', 'Melek Gözyaşı', 'Yaşam Kaynağı', 'Ebedi Su'],
  ),
  'shadow_pit': FacilityMeta(
    name: 'Gölge Çukuru',
    icon: '🕳️',
    description: 'Karanlık esans ve gölge kristalleri toplar',
    baseRate: 4,
    baseUpgradeCost: 800000,
    multiplier: 1.6,
    resources: <String>['Gölge Tozu', 'Gölge Kristali', 'Karanlık Esansı', 'Gölge Kalbi', 'Uçurum Çekirdeği', 'Ebedi Boşluk'],
  ),
  'elemental_forge': FacilityMeta(
    name: 'Elementel Ocak',
    icon: '🔥',
    description: 'Ateş, buz ve yıldırım esansı üretir',
    baseRate: 5,
    baseUpgradeCost: 1000000,
    multiplier: 1.6,
    resources: <String>['Ateş Kıvılcımı', 'Buz Parçası', 'Yıldırım Çekirdeği', 'Toprak Kalbi', 'Saf Element', 'Beşinci Element'],
  ),
  'time_well': FacilityMeta(
    name: 'Zaman Kuyusu',
    icon: '⏳',
    description: 'Zaman kristali ve hızlandırma tozu üretir',
    baseRate: 3,
    baseUpgradeCost: 1200000,
    multiplier: 1.7,
    resources: <String>['Zaman Tozu', 'Saat Parçası', 'Zaman Kristali', 'Kronos Esansı', 'Ebedi An', 'Sonsuz Zaman'],
  ),
};

FacilityMeta? facilityMetaFor(String type) => kFacilityMetaByType[type];

int facilityUpgradeCost(String type, int currentLevel) {
  final FacilityMeta? meta = kFacilityMetaByType[type];
  if (meta == null) return 0;

  final double cost = meta.baseUpgradeCost * _pow(meta.multiplier, currentLevel - 1);
  return cost.floor();
}

double _pow(double base, int exponent) {
  if (exponent <= 0) return 1;
  double result = 1;
  for (int i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}

int sumFacilityQueueQuantity(List<FacilityQueueItem> items) {
  int total = 0;
  for (final item in items) {
    total += item.quantity;
  }
  return total;
}

String formatFacilityRemaining(DateTime? targetAt, {DateTime? now}) {
  if (targetAt == null) return '00:00';
  final DateTime clock = now ?? DateTime.now();
  final int remaining = targetAt.difference(clock).inSeconds;
  if (remaining <= 0) return '✅';

  final int mins = remaining ~/ 60;
  final int secs = remaining % 60;
  return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}

String facilityRarityLabel(String rarity) {
  switch (rarity) {
    case 'common':
      return '⚪ Yaygın';
    case 'uncommon':
      return '🟢 Sıradışı';
    case 'rare':
      return '🔵 Nadir';
    case 'epic':
      return '🟣 Epik';
    case 'legendary':
      return '🟡 Efsanevi';
    case 'mythic':
      return '🌈 Mitik';
    default:
      return rarity;
  }
}

String facilityRarityTitle(String rarity) {
  switch (rarity) {
    case 'common':
      return 'Yaygın';
    case 'uncommon':
      return 'Sıradışı';
    case 'rare':
      return 'Nadir';
    case 'epic':
      return 'Epik';
    case 'legendary':
      return 'Efsanevi';
    case 'mythic':
      return 'Mitik';
    default:
      return rarity;
  }
}

String facilityRarityEmoji(String rarity) {
  switch (rarity) {
    case 'common':
      return '⚪';
    case 'uncommon':
      return '🟢';
    case 'rare':
      return '🔵';
    case 'epic':
      return '🟣';
    case 'legendary':
      return '🟡';
    case 'mythic':
      return '🌈';
    default:
      return '⚪';
  }
}

Map<String, int> facilityRarityWeightsAtLevel(int level) {
  if (level <= 1) return kFacilityDropRatesByLevel[1]!;
  if (level >= 10) return kFacilityDropRatesByLevel[10]!;
  return kFacilityDropRatesByLevel[level] ?? kFacilityDropRatesByLevel[1]!;
}

String facilityResourceNameByRarity(String facilityType, String rarity) {
  final FacilityMeta? meta = kFacilityMetaByType[facilityType];
  if (meta == null) return rarity;

  final int idx = kFacilityResourceRarities.indexOf(rarity.toLowerCase());
  if (idx < 0 || idx >= meta.resources.length) return rarity;
  return meta.resources[idx];
}

bool facilityIsFutureIso(String? iso) {
  if (iso == null || iso.isEmpty) return false;
  final DateTime? parsed = DateTime.tryParse(iso);
  if (parsed == null) return false;
  return parsed.isAfter(DateTime.now());
}

String formatFacilityGold(int value) => NumberFormat.decimalPattern('tr_TR').format(value);
