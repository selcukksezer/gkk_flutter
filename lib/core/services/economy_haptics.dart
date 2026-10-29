import 'package:flutter/services.dart';

import 'app_settings_service.dart';

/// Tactile mobile haptic feedback engine dedicated to economy & transaction interactions.
///
/// Delivers rich tactile sensory feedback across Crafting, Market, Shop, Trade, and Bank:
/// - Crisp ticks on tab switching, filters, stepper adjustments, and item slot selections.
/// - Medium impact on item drags, trade lock-in, listing items, deposit, and withdraw.
/// - Heavy resounding impact on forge hammer strikes, purchases, trade execution, and vault upgrades.
/// - Error vibration on insufficient gold/gems, full inventory/vault, or cancelled trades.
///
/// Respects [AppSettingsService.instance.hapticEnabled] and catches platform errors defensively.
abstract final class EconomyHaptics {
  static bool get isEnabled {
    try {
      return AppSettingsService.instance.hapticEnabled;
    } catch (_) {
      return true;
    }
  }

  /// Subtle click for tab switching and navigation across economy hubs.
  static Future<void> tabSwitch() async {
    if (!isEnabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Crisp click when selecting category or rarity filters.
  static Future<void> filterSelect() async {
    if (!isEnabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Tactile tap when selecting or tapping an item slot.
  static Future<void> slotSelect() async {
    if (!isEnabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Light tick on counter or stepper increment/decrement.
  static Future<void> counterStep() async {
    if (!isEnabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Tactile feedback when picking up or beginning to drag an item slot.
  static Future<void> itemDragStart() async {
    if (!isEnabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Soft tactile feedback when dropping an item slot.
  static Future<void> itemDrop() async {
    if (!isEnabled) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Strong tactile response for anvil strike and forge activation.
  static Future<void> anvilStrike() async {
    if (!isEnabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Heavy impact on craft success or equipment upgrade.
  static Future<void> craftSuccess() async {
    if (!isEnabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Resounding double-impact for critical or epic craft results.
  static Future<void> craftCritical() async {
    if (!isEnabled) return;
    try {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 90));
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Heavy tactile feedback on completing a purchase (Shop, Market, Night Market).
  static Future<void> purchaseSuccess() async {
    if (!isEnabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Medium tactile feedback on selling an item or listing in market.
  static Future<void> saleSuccess() async {
    if (!isEnabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Medium latch feedback when locking in trade offer.
  static Future<void> tradeLock() async {
    if (!isEnabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Light feedback when unlocking trade offer.
  static Future<void> tradeUnlock() async {
    if (!isEnabled) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Celebratory heavy feedback when player-to-player trade is executed and finalized.
  static Future<void> tradeComplete() async {
    if (!isEnabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Medium tactile feedback when depositing an item into bank/vault.
  static Future<void> depositSuccess() async {
    if (!isEnabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Medium tactile feedback when withdrawing an item from bank/vault.
  static Future<void> withdrawSuccess() async {
    if (!isEnabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Deep heavy feedback when expanding bank capacity / unlocking vault row.
  static Future<void> vaultUpgrade() async {
    if (!isEnabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Tactile error vibration when insufficient gold, inventory full, or action rejected.
  static Future<void> error() async {
    if (!isEnabled) return;
    try {
      await HapticFeedback.vibrate();
    } catch (_) {}
  }

  /// Warning feedback (e.g. trade cancelled, invalid amount).
  static Future<void> warning() async {
    if (!isEnabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Generic button tap.
  static Future<void> buttonTap() async {
    if (!isEnabled) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }
}
