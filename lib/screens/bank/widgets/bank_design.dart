import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

const int bankBaseSlots = 100;
const int bankMaxSlots = 200;
const int bankSlotsPerPage = 20;
const int bankInventoryPerPage = 20;

abstract final class BankDesign {
  static const int gridColumns = 5;
  static const double gridSpacing = 6;
  static const double slotAspectRatio = 0.88;
  static const Color gold = AppColors.liquidGold;
  static const Color deposit = AppColors.toxicNeon;
  static const Color withdraw = AppColors.mysticRuby;
  static const Color muted = AppColors.mutedTitanium;
}

int bankExpandCost(int total) {
  if (total >= 175) return 500;
  if (total >= 150) return 200;
  if (total >= 125) return 100;
  return 50;
}

int bankAsInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

enum BankDragSourceType { inventory, bank }

class BankDragPayload {
  const BankDragPayload({
    required this.sourceType,
    required this.sourceId,
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.isStackable,
  });

  final BankDragSourceType sourceType;
  final String sourceId;
  final String itemId;
  final String name;
  final int quantity;
  final bool isStackable;
}

bool bankRowIsStackable(Map<String, dynamic> row) {
  final int maxStack = bankAsInt(row['max_stack'], fallback: 1);
  if (row.containsKey('max_stack')) return maxStack > 1;
  return bankAsInt(row['quantity']) > 1;
}
