import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

const int bankBaseSlots = 100;
const int bankMaxSlots = 200;
const int bankSlotsPerPage = 20;
const int bankInventoryPerPage = 20;
const int bankSlotUnlockCost = 5;

/// View modes supported by the Aion 2 Bank interface.
enum BankViewMode {
  /// Split grid showing both Inventory & Royal Vault for rapid drag & batch transfer.
  transfer,

  /// Focused Royal Vault grid view with maximized inspection capacity.
  vault,

  /// Focused Adventurer Inventory grid view.
  inventory,
}

abstract final class BankDesign {
  static const int gridColumns = 5;
  static const double gridSpacing = 6;
  static const double slotAspectRatio = 0.88;

  // Primary Bank & Vault Palette
  static const Color gold = AppColors.liquidGold;
  static const Color goldLight = AppColors.goldLight;
  static const Color goldDim = AppColors.goldDim;
  static const Color deposit = AppColors.toxicNeon;
  static const Color withdraw = AppColors.mysticRuby;
  static const Color muted = AppColors.mutedTitanium;

  // Aion 2 Royal Vault Luxury Tokens
  static const Color royalObsidian = Color(0xFF0D1117);
  static const Color royalObsidianDeep = Color(0xFF070A0F);
  static const Color royalGoldFiligree = Color(0xFFE5B842);
  static const Color royalGoldGlint = Color(0xFFFFF2B2);
  static const Color royalVelvet = Color(0xFF131A26);

  // Aion 2 Crystal Tokens
  static const Color crystalCyan = Color(0xFF38BDF8);
  static const Color crystalCyanGlow = Color(0xFF00E5FF);
  static const Color crystalAmethyst = Color(0xFFC084FC);
  static const Color crystalEmerald = Color(0xFF10B981);
  static const Color crystalAmber = Color(0xFFF59E0B);
  static const Color crystalRuby = Color(0xFFF43F5E);

  // Common gradients
  static const LinearGradient royalVaultGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFF1B2230),
      Color(0xFF0F1521),
      Color(0xFF0A0E17),
    ],
    stops: <double>[0.0, 0.55, 1.0],
  );

  static const LinearGradient royalGoldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFFFEEA8),
      Color(0xFFE5B842),
      Color(0xFFB3861B),
    ],
    stops: <double>[0.0, 0.45, 1.0],
  );

  static const LinearGradient crystalCyanGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFF7DD3FC),
      Color(0xFF0284C7),
    ],
  );
}

int bankNextSlotIndex(int totalSlots) => totalSlots + 1;

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
