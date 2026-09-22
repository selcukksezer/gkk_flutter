import '../../models/item_model.dart';

/// Knight Online style NPC vendor sell — mirrors `compute_npc_sell_price` SQL.
///
/// Equip (weapon/armor): +0 sell is 6× prior capped price, then
/// `×(1 + enhancement × 0.15)` (same curve as combat stats).
/// Materials / potions / craft mats: prior mild `×(1 + enh × 0.06)` + hard cap.
int computeNpcSellPrice({
  required String itemId,
  required Rarity rarity,
  required ItemType itemType,
  required int requiredLevel,
  required int basePrice,
  required int attack,
  required int defense,
  required int power,
  required int luck,
  required int energyRestore,
  required int healthRestore,
  required bool isTradeable,
  required bool isHanOnly,
  int enhancementLevel = 0,
}) {
  if (!isTradeable ||
      isHanOnly ||
      itemType == ItemType.cosmetic ||
      itemId.startsWith('box_') ||
      itemId.startsWith('badge_')) {
    return 0;
  }

  final int level = requiredLevel < 1 ? 1 : requiredLevel;
  final int enh = enhancementLevel.clamp(0, 10);
  final int stat = attack + defense + power + luck;
  final bool isEquip =
      itemType == ItemType.weapon || itemType == ItemType.armor;

  int worth = (stat ~/ 15) + (level * 6);
  if (worth < 10) worth = 10;

  switch (itemType) {
    case ItemType.potion:
    case ItemType.consumable:
      final int potionWorth =
          (energyRestore * 3) + (healthRestore * 2) + (level * 2);
      if (potionWorth > worth) worth = potionWorth;
    case ItemType.material:
      final int materialWorth = 12 + (level * 8);
      if (materialWorth > worth) worth = materialWorth;
    case ItemType.recipe:
    case ItemType.scroll:
    case ItemType.rune:
      final int craftWorth = 20 + (level * 10);
      if (craftWorth > worth) worth = craftWorth;
    default:
      break;
  }

  final int shopCap = _shopCap(rarity, level);
  final double sellPct = _sellPct(rarity);
  final int shopRef = _min(_max(basePrice, worth), shopCap);

  int sell = (shopRef * sellPct).floor();
  final int maxSell = _maxSellCap(rarity, level);
  sell = _min(sell, maxSell);

  if (isEquip) {
    sell = sell * 6;
    sell = (sell * (1.0 + (enh * 0.15))).floor();
  } else {
    sell = (sell * (1.0 + (enh * 0.06))).floor();
    sell = _min(sell, maxSell);
  }

  if (sell <= 0) return 0;
  return sell < 1 ? 1 : sell;
}

int _shopCap(Rarity rarity, int level) {
  return switch (rarity) {
    Rarity.common => 280 + (level * 220),
    Rarity.uncommon => 240 + (level * 180),
    Rarity.rare => 200 + (level * 160),
    Rarity.epic => 180 + (level * 130),
    Rarity.legendary => 150 + (level * 100),
    Rarity.mythic => 120 + (level * 75),
  };
}

double _sellPct(Rarity rarity) {
  return switch (rarity) {
    Rarity.common => 0.35,
    Rarity.uncommon => 0.30,
    Rarity.rare => 0.25,
    Rarity.epic => 0.20,
    Rarity.legendary => 0.15,
    Rarity.mythic => 0.12,
  };
}

int _maxSellCap(Rarity rarity, int level) {
  return switch (rarity) {
    Rarity.common => 80 + (level * 85),
    Rarity.uncommon => 70 + (level * 70),
    Rarity.rare => 60 + (level * 58),
    Rarity.epic => 50 + (level * 45),
    Rarity.legendary => 40 + (level * 35),
    Rarity.mythic => 30 + (level * 28),
  };
}

int _min(int a, int b) => a < b ? a : b;

int _max(int a, int b) => a > b ? a : b;
