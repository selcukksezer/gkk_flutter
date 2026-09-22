import '../../models/inventory_model.dart';
import '../../models/item_model.dart';
import 'potion_energy.dart';

/// Server `use_potion` heal fractions (% of max_health). Null → flat restore.
double? healthPotionHealFraction(String itemId) {
  switch (itemId) {
    case 'potion_health_minor':
      return 0.25;
    case 'potion_health_major':
      return 0.50;
    case 'potion_health_supreme':
      return 1.0;
    case 'han_item_restoration':
      return 0.40;
    default:
      return null;
  }
}

int effectiveHealthRestore({
  required int baseRestore,
  required int tolerance,
  bool alchemistBonus = false,
  int? maxHealth,
  String? itemId,
}) {
  double efficiency = potionEfficiencyForTolerance(tolerance);
  if (alchemistBonus) {
    efficiency = efficiency > 1.0 ? efficiency : (efficiency * 1.30).clamp(0.0, 1.0);
  }
  final double? fraction =
      itemId == null ? null : healthPotionHealFraction(itemId);
  if (fraction != null && maxHealth != null && maxHealth > 0) {
    return (maxHealth * fraction * efficiency).floor();
  }
  return (baseRestore * efficiency).floor();
}

bool isHealthPotionItem(InventoryItem item) {
  if (item.healthRestore > 0) return true;
  if (healthPotionHealFraction(item.itemId) != null) return true;
  if (item.potionType == PotionType.health) return true;
  final String type = item.itemType.name.toLowerCase();
  if (!type.contains('potion') && item.itemType != ItemType.consumable) {
    return false;
  }
  final String potionType = item.potionType.name.toLowerCase();
  return potionType == 'health' || potionType.contains('health');
}

String? healthPotionEffectLabel({
  required InventoryItem item,
  required int tolerance,
  bool alchemistBonus = false,
  int? maxHealth,
}) {
  if (!isHealthPotionItem(item)) return null;
  final double? fraction = healthPotionHealFraction(item.itemId);
  if (fraction != null) {
    final int pct = (fraction * 100).round();
    if (maxHealth != null && maxHealth > 0) {
      final int effective = effectiveHealthRestore(
        baseRestore: item.healthRestore,
        tolerance: tolerance,
        alchemistBonus: alchemistBonus,
        maxHealth: maxHealth,
        itemId: item.itemId,
      );
      return '+$pct% can (~$effective)';
    }
    return '+$pct% max can';
  }
  final int base = item.healthRestore;
  if (base <= 0) return null;
  final int effective = effectiveHealthRestore(
    baseRestore: base,
    tolerance: tolerance,
    alchemistBonus: alchemistBonus,
  );
  if (effective >= base) {
    return '+$base can';
  }
  return 'Toleransla +$effective (etiket +$base)';
}

String? healthPotionUseMessage({
  required String itemName,
  required int health,
  required int maxHealth,
  required int healedAmount,
}) {
  if (healedAmount <= 0) return '$itemName kullanildi.';
  return '$itemName kullanildi. Can: $health/$maxHealth (+$healedAmount)';
}
