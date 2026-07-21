/// Client-side mirror of [use_potion] tolerance efficiency (display only).
library;

double potionEfficiencyForTolerance(int tolerance) {
  if (tolerance <= 20) return 1.0;
  if (tolerance <= 40) return 0.85;
  if (tolerance <= 60) return 0.65;
  if (tolerance <= 80) return 0.45;
  return 0.25;
}

int effectiveEnergyRestore({
  required int baseRestore,
  required int tolerance,
  bool alchemistBonus = false,
}) {
  double efficiency = potionEfficiencyForTolerance(tolerance);
  if (alchemistBonus) {
    efficiency = efficiency > 1.0 ? efficiency : (efficiency * 1.30).clamp(0.0, 1.0);
  }
  return (baseRestore * efficiency).floor();
}

bool isEnergyPotionItem(Map<String, dynamic> item) {
  final String type = (item['item_type'] ?? item['type'] ?? '')
      .toString()
      .toLowerCase();
  if (!type.contains('potion') && !type.contains('consumable')) {
    return false;
  }
  final String potionType =
      (item['potion_type'] ?? '').toString().toLowerCase();
  if (potionType.isNotEmpty && potionType != 'energy') {
    return false;
  }
  final int restore = _readInt(item['energy_restore']);
  return restore > 0;
}

String? shopEnergyPotionSubtitle(Map<String, dynamic> item, int tolerance) {
  if (!isEnergyPotionItem(item)) return null;
  final int base = _readInt(item['energy_restore']);
  if (base <= 0) return null;
  final int effective =
      effectiveEnergyRestore(baseRestore: base, tolerance: tolerance);
  if (effective >= base) {
    return '+$base enerji';
  }
  return 'Toleransla +$effective (etiket +$base)';
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
