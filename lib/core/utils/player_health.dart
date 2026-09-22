/// Player health combat thresholds (mirrors server helpers).
library;

import 'package:flutter/material.dart';

/// Minimum health fraction required to start combat as attacker.
const double combatMinHealthFraction = 0.20;

/// Health set on hospital discharge (wounded state).
const double woundedHealthFraction = 0.50;

/// Inbox / home warning threshold.
const double lowHealthAlertFraction = 0.35;

/// Passive regen: full pool hours at base rate (5%/hour → 20h).
const double healthRegenFullPoolHours = 20;

/// Base regen percent of max health per hour (100 / healthRegenFullPoolHours).
const double baseHealthRegenPercentPerHour = 5.0;

/// Alchemist passive: +50% regen rate.
const double alchemistHealthRegenMultiplier = 1.5;

/// PvP power penalty when wounded (below 50% but above combat floor).
const double woundedPvpPowerPenalty = 0.05;

enum PlayerHealthStatus {
  healthy,
  recovering,
  wounded,
  critical,
  restricted,
}

PlayerHealthStatus resolveHealthStatus({
  required int health,
  required int maxHealth,
  bool restricted = false,
}) {
  if (restricted) {
    if (maxHealth > 0 && health < playerCombatMinHealth(maxHealth)) {
      return PlayerHealthStatus.critical;
    }
    if (maxHealth > 0 && health < playerWoundedHealth(maxHealth)) {
      return PlayerHealthStatus.wounded;
    }
    return PlayerHealthStatus.restricted;
  }
  if (maxHealth <= 0 || health >= maxHealth) return PlayerHealthStatus.healthy;
  if (health < playerCombatMinHealth(maxHealth)) return PlayerHealthStatus.critical;
  if (health < playerWoundedHealth(maxHealth)) return PlayerHealthStatus.wounded;
  return PlayerHealthStatus.recovering;
}

String healthStatusLabel(PlayerHealthStatus status) {
  return switch (status) {
    PlayerHealthStatus.healthy => 'Saglikli',
    PlayerHealthStatus.recovering => 'Iyilesiyor',
    PlayerHealthStatus.wounded => 'Yarali',
    PlayerHealthStatus.critical => 'Kritik',
    PlayerHealthStatus.restricted => 'Kisitli',
  };
}

String healthStatusTip(PlayerHealthStatus status) {
  return switch (status) {
    PlayerHealthStatus.healthy => 'Tam gucle savasa hazirsin.',
    PlayerHealthStatus.recovering =>
      'Pasif can yenilenmesi devam ediyor. Iksir veya elmas ile hizlandirabilirsin.',
    PlayerHealthStatus.wounded =>
      'Yarali durumdasin. PvP gucun %5 dusuk. Can iksiri veya elmas iyilesme onerilir.',
    PlayerHealthStatus.critical =>
      'Canin PvP icin yetersiz. Once iyiles veya can iksiri kullan.',
    PlayerHealthStatus.restricted =>
      'Hastane/hapishane sirasinda pasif can yenilenmesi durur.',
  };
}

Color healthStatusColor(PlayerHealthStatus status) {
  return switch (status) {
    PlayerHealthStatus.healthy => const Color(0xFF34D399),
    PlayerHealthStatus.recovering => const Color(0xFF5B8FFF),
    PlayerHealthStatus.wounded => const Color(0xFFE89558),
    PlayerHealthStatus.critical => const Color(0xFFEA2143),
    PlayerHealthStatus.restricted => const Color(0xFF94A3B8),
  };
}

double healthRegenPercentPerHour({bool alchemistBonus = false}) {
  return baseHealthRegenPercentPerHour *
      (alchemistBonus ? alchemistHealthRegenMultiplier : 1.0);
}

int estimateSecondsToFullHealth({
  required int health,
  required int maxHealth,
  bool alchemistBonus = false,
}) {
  if (maxHealth <= 0 || health >= maxHealth) return 0;
  final double hours =
      healthRegenFullPoolHours / (alchemistBonus ? alchemistHealthRegenMultiplier : 1.0);
  final double missingFraction = (maxHealth - health) / maxHealth;
  return (missingFraction * hours * 3600).ceil().clamp(0, 999999);
}

String formatRegenDuration(int totalSeconds) {
  if (totalSeconds <= 0) return 'Simdi';
  final Duration duration = Duration(seconds: totalSeconds);
  final int hours = duration.inHours;
  final int minutes = duration.inMinutes.remainder(60);
  if (hours >= 48) {
    final int days = hours ~/ 24;
    final int remHours = hours % 24;
    return remHours > 0 ? '$days gun $remHours sa' : '$days gun';
  }
  if (hours > 0) {
    return minutes > 0 ? '$hours sa $minutes dk' : '$hours sa';
  }
  if (minutes > 0) return '$minutes dk';
  return '${duration.inSeconds} sn';
}

int gemHealthHealCost({
  required int health,
  required int maxHealth,
  required int level,
}) {
  if (maxHealth <= 0 || health >= maxHealth) return 0;
  final int missing = maxHealth - health;
  final int tierCost = level < 10 ? 8 : (level < 20 ? 12 : 18);
  return ((missing / maxHealth) * tierCost).ceil().clamp(1, tierCost);
}

bool hasWoundedCombatPenalty({
  required int health,
  required int maxHealth,
}) {
  if (maxHealth <= 0) return false;
  return health >= playerCombatMinHealth(maxHealth) &&
      health < playerWoundedHealth(maxHealth);
}

int playerCombatMinHealth(int maxHealth) {
  final int max = maxHealth <= 0 ? 1 : maxHealth;
  return (max * combatMinHealthFraction).floor().clamp(1, max);
}

int playerWoundedHealth(int maxHealth) {
  final int max = maxHealth <= 0 ? 1 : maxHealth;
  return (max * woundedHealthFraction).floor().clamp(1, max);
}

int playerHealthFloor(int maxHealth) {
  final int max = maxHealth <= 0 ? 1 : maxHealth;
  return (max * 0.15).floor().clamp(1, max);
}

bool isHealthTooLowForCombat({required int health, required int maxHealth}) {
  if (maxHealth <= 0) return false;
  return health < playerCombatMinHealth(maxHealth);
}

bool isLowHealthAlert({required int health, required int maxHealth}) {
  if (maxHealth <= 0) return false;
  return health < (maxHealth * lowHealthAlertFraction).round();
}

double healthFraction({required int health, required int maxHealth}) {
  if (maxHealth <= 0) return 1;
  return (health / maxHealth).clamp(0.0, 1.0);
}

String formatHealthRatio(int health, int maxHealth) {
  return '$health/$maxHealth';
}

/// Estimated passive regen points if [elapsedSeconds] passed (display only).
int estimatePassiveHealthRegen({
  required int currentHealth,
  required int maxHealth,
  required int elapsedSeconds,
  bool alchemistBonus = false,
}) {
  if (maxHealth <= 0 || currentHealth >= maxHealth || elapsedSeconds <= 0) {
    return 0;
  }
  final double hours = healthRegenFullPoolHours / (alchemistBonus ? alchemistHealthRegenMultiplier : 1.0);
  final double perSecond = maxHealth / (hours * 3600);
  final int gained = (elapsedSeconds * perSecond).floor();
  return gained.clamp(0, maxHealth - currentHealth);
}
