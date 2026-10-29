/// Player health combat thresholds (mirrors server helpers).
library;

import 'package:flutter/material.dart';

/// Minimum health fraction required to start combat as attacker.
const double combatMinHealthFraction = 0.20;

/// Health set on hospital discharge (wounded state).
const double woundedHealthFraction = 0.50;

/// Inbox / home warning threshold (flags wounded / critical conditions below 50%).
const double lowHealthAlertFraction = 0.50;

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
  if (health <= 0) return PlayerHealthStatus.critical;
  if (restricted) {
    if (maxHealth > 0 && health < playerCombatMinHealth(maxHealth)) {
      return PlayerHealthStatus.critical;
    }
    if (maxHealth > 0 && health < playerWoundedHealth(maxHealth)) {
      return PlayerHealthStatus.wounded;
    }
    return PlayerHealthStatus.restricted;
  }
  if (maxHealth <= 0) return PlayerHealthStatus.critical;
  if (health >= maxHealth) return PlayerHealthStatus.healthy;
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
  final int clampedHealth = health.clamp(0, maxHealth);
  final double hours =
      healthRegenFullPoolHours / (alchemistBonus ? alchemistHealthRegenMultiplier : 1.0);
  final double missingFraction = (maxHealth - clampedHealth) / maxHealth;
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
  final int clampedHealth = health.clamp(0, maxHealth);
  final int missing = maxHealth - clampedHealth;
  final int effectiveLevel = level < 1 ? 1 : level;
  final int tierCost = effectiveLevel < 10 ? 8 : (effectiveLevel < 20 ? 12 : 18);
  return ((missing / maxHealth) * tierCost).ceil().clamp(1, tierCost);
}

bool hasWoundedCombatPenalty({
  required int health,
  required int maxHealth,
}) {
  if (maxHealth <= 0 || health <= 0) return false;
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
  if (maxHealth <= 0 || health <= 0) return true;
  return health < playerCombatMinHealth(maxHealth);
}

bool isLowHealthAlert({
  required int health,
  required int maxHealth,
  double alertFraction = lowHealthAlertFraction,
}) {
  if (maxHealth <= 0) return false;
  return health < (maxHealth * alertFraction).round();
}

double healthFraction({required int health, required int maxHealth}) {
  if (maxHealth <= 0) return 0.0;
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
  final int clampedHealth = currentHealth.clamp(0, maxHealth);
  final double hours = healthRegenFullPoolHours / (alchemistBonus ? alchemistHealthRegenMultiplier : 1.0);
  final double perSecond = maxHealth / (hours * 3600);
  final int gained = (elapsedSeconds * perSecond).floor();
  return gained.clamp(0, maxHealth - clampedHealth);
}

/// Clamps player health within valid boundaries [minHealth, maxHealth].
/// Safe against negative health, zero or inverted bounds, and integer overflow.
int clampPlayerHealth({
  required int health,
  required int maxHealth,
  int minHealth = 0,
}) {
  if (maxHealth <= 0) return 0;
  final int safeMin = minHealth < 0 ? 0 : (minHealth > maxHealth ? maxHealth : minHealth);
  return health.clamp(safeMin, maxHealth);
}

/// Returns true if health is 0 or negative (fainted / dead state).
bool isHealthZeroOrDead(int health) => health <= 0;

/// Returns true if health is at or exceeds maximum health capacity.
bool isHealthFull({required int health, required int maxHealth}) =>
    maxHealth > 0 && health >= maxHealth;

/// Result of damage calculation including shield absorption, buff mitigations,
/// 0 HP clamping, and fatality status.
@immutable
class DamageResult {
  const DamageResult({
    required this.newHealth,
    required this.newShield,
    required this.damageDealtToHealth,
    required this.damageAbsorbedByShield,
    required this.mitigatedDamage,
    required this.isFatal,
    required this.shieldDepleted,
  });

  final int newHealth;
  final int newShield;
  final int damageDealtToHealth;
  final int damageAbsorbedByShield;
  final int mitigatedDamage;
  final bool isFatal;
  final bool shieldDepleted;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DamageResult &&
          runtimeType == other.runtimeType &&
          newHealth == other.newHealth &&
          newShield == other.newShield &&
          damageDealtToHealth == other.damageDealtToHealth &&
          damageAbsorbedByShield == other.damageAbsorbedByShield &&
          mitigatedDamage == other.mitigatedDamage &&
          isFatal == other.isFatal &&
          shieldDepleted == other.shieldDepleted;

  @override
  int get hashCode => Object.hash(
        newHealth,
        newShield,
        damageDealtToHealth,
        damageAbsorbedByShield,
        mitigatedDamage,
        isFatal,
        shieldDepleted,
      );

  @override
  String toString() =>
      'DamageResult(newHealth: $newHealth, newShield: $newShield, damageToHealth: $damageDealtToHealth, shieldAbsorbed: $damageAbsorbedByShield, mitigated: $mitigatedDamage, fatal: $isFatal, shieldDepleted: $shieldDepleted)';
}

/// Result of healing application including overheal tracking and revive verification.
@immutable
class HealResult {
  const HealResult({
    required this.newHealth,
    required this.actualHealed,
    required this.overheal,
    required this.isFullyHealed,
  });

  final int newHealth;
  final int actualHealed;
  final int overheal;
  final bool isFullyHealed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealResult &&
          runtimeType == other.runtimeType &&
          newHealth == other.newHealth &&
          actualHealed == other.actualHealed &&
          overheal == other.overheal &&
          isFullyHealed == other.isFullyHealed;

  @override
  int get hashCode => Object.hash(
        newHealth,
        actualHealed,
        overheal,
        isFullyHealed,
      );

  @override
  String toString() =>
      'HealResult(newHealth: $newHealth, actualHealed: $actualHealed, overheal: $overheal, isFullyHealed: $isFullyHealed)';
}

/// Result of applying shield points to a character.
@immutable
class ShieldApplyResult {
  const ShieldApplyResult({
    required this.newShield,
    required this.actualShieldAdded,
    required this.overflowShield,
  });

  final int newShield;
  final int actualShieldAdded;
  final int overflowShield;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShieldApplyResult &&
          runtimeType == other.runtimeType &&
          newShield == other.newShield &&
          actualShieldAdded == other.actualShieldAdded &&
          overflowShield == other.overflowShield;

  @override
  int get hashCode => Object.hash(
        newShield,
        actualShieldAdded,
        overflowShield,
      );

  @override
  String toString() =>
      'ShieldApplyResult(newShield: $newShield, added: $actualShieldAdded, overflow: $overflowShield)';
}

/// Computes mitigated damage applying defense buffs and vulnerability debuffs.
int calculateEffectiveDamage({
  required int rawDamage,
  double defenseReductionMultiplier = 0.0,
  double vulnerabilityMultiplier = 0.0,
}) {
  if (rawDamage <= 0) return 0;
  final double clampedReduction = defenseReductionMultiplier.clamp(0.0, 1.0);
  final double clampedVulnerability = vulnerabilityMultiplier < 0.0 ? 0.0 : vulnerabilityMultiplier;
  final double netMultiplier = (1.0 - clampedReduction) * (1.0 + clampedVulnerability);
  final int mitigated = (rawDamage * netMultiplier).round();
  return mitigated < 0 ? 0 : mitigated;
}

/// Applies combat damage to a player taking into account shields, defense buffs,
/// vulnerability debuffs, 0 HP boundary condition, and overflow protection.
DamageResult applyDamageToPlayer({
  required int currentHealth,
  required int maxHealth,
  required int rawDamage,
  int currentShield = 0,
  double defenseReductionMultiplier = 0.0,
  double vulnerabilityMultiplier = 0.0,
}) {
  final int safeMaxHealth = maxHealth <= 0 ? 0 : maxHealth;
  final int sanitizedHealth = currentHealth.clamp(0, safeMaxHealth);
  final int sanitizedShield = currentShield < 0 ? 0 : currentShield;

  if (rawDamage <= 0) {
    return DamageResult(
      newHealth: sanitizedHealth,
      newShield: sanitizedShield,
      damageDealtToHealth: 0,
      damageAbsorbedByShield: 0,
      mitigatedDamage: 0,
      isFatal: sanitizedHealth <= 0,
      shieldDepleted: false,
    );
  }

  final int mitigatedDamage = calculateEffectiveDamage(
    rawDamage: rawDamage,
    defenseReductionMultiplier: defenseReductionMultiplier,
    vulnerabilityMultiplier: vulnerabilityMultiplier,
  );

  if (sanitizedHealth <= 0) {
    return DamageResult(
      newHealth: 0,
      newShield: sanitizedShield,
      damageDealtToHealth: 0,
      damageAbsorbedByShield: 0,
      mitigatedDamage: mitigatedDamage,
      isFatal: true,
      shieldDepleted: false,
    );
  }

  int newShield = sanitizedShield;
  int damageAbsorbed = 0;
  int damageRemaining = mitigatedDamage;
  bool shieldDepleted = false;

  if (sanitizedShield > 0) {
    if (sanitizedShield >= mitigatedDamage) {
      damageAbsorbed = mitigatedDamage;
      newShield = sanitizedShield - mitigatedDamage;
      damageRemaining = 0;
      shieldDepleted = (newShield == 0);
    } else {
      damageAbsorbed = sanitizedShield;
      damageRemaining = mitigatedDamage - sanitizedShield;
      newShield = 0;
      shieldDepleted = true;
    }
  }

  final int damageDealtToHealth = damageRemaining;
  final int newHealth = (sanitizedHealth - damageDealtToHealth).clamp(0, safeMaxHealth);
  final bool isFatal = newHealth <= 0;

  return DamageResult(
    newHealth: newHealth,
    newShield: newShield,
    damageDealtToHealth: damageDealtToHealth,
    damageAbsorbedByShield: damageAbsorbed,
    mitigatedDamage: mitigatedDamage,
    isFatal: isFatal,
    shieldDepleted: shieldDepleted,
  );
}

/// Applies healing to a player taking into account maxHealth boundary,
/// overheal tracking, dead player state, and healing multipliers/buffs.
HealResult applyHealingToPlayer({
  required int currentHealth,
  required int maxHealth,
  required int rawHeal,
  double healingMultiplier = 1.0,
  bool allowRevive = false,
}) {
  final int safeMaxHealth = maxHealth <= 0 ? 0 : maxHealth;
  final int sanitizedHealth = currentHealth.clamp(0, safeMaxHealth);

  if (safeMaxHealth <= 0) {
    return const HealResult(
      newHealth: 0,
      actualHealed: 0,
      overheal: 0,
      isFullyHealed: false,
    );
  }

  if (sanitizedHealth <= 0 && !allowRevive) {
    return const HealResult(
      newHealth: 0,
      actualHealed: 0,
      overheal: 0,
      isFullyHealed: false,
    );
  }

  if (rawHeal <= 0) {
    return HealResult(
      newHealth: sanitizedHealth,
      actualHealed: 0,
      overheal: 0,
      isFullyHealed: sanitizedHealth >= safeMaxHealth,
    );
  }

  final double clampedMultiplier = healingMultiplier < 0.0 ? 0.0 : healingMultiplier;
  final int effectiveHeal = (rawHeal * clampedMultiplier).round();
  final int missingHealth = safeMaxHealth - sanitizedHealth;

  if (effectiveHeal <= missingHealth) {
    final int newHealth = sanitizedHealth + effectiveHeal;
    return HealResult(
      newHealth: newHealth,
      actualHealed: effectiveHeal,
      overheal: 0,
      isFullyHealed: newHealth >= safeMaxHealth,
    );
  } else {
    final int actualHealed = missingHealth;
    final int overheal = effectiveHeal - missingHealth;
    return HealResult(
      newHealth: safeMaxHealth,
      actualHealed: actualHealed,
      overheal: overheal,
      isFullyHealed: true,
    );
  }
}

/// Applies shields/barriers to a player with optional maxShield capacity.
ShieldApplyResult applyShieldToPlayer({
  required int currentShield,
  required int shieldAmount,
  int? maxShield,
  double shieldMultiplier = 1.0,
}) {
  final int sanitizedShield = currentShield < 0 ? 0 : currentShield;

  if (shieldAmount <= 0) {
    return ShieldApplyResult(
      newShield: sanitizedShield,
      actualShieldAdded: 0,
      overflowShield: 0,
    );
  }

  final double clampedMultiplier = shieldMultiplier < 0.0 ? 0.0 : shieldMultiplier;
  final int effectiveShield = (shieldAmount * clampedMultiplier).round();

  if (maxShield != null && maxShield > 0) {
    final int capacity = maxShield - sanitizedShield;
    if (capacity <= 0) {
      return ShieldApplyResult(
        newShield: sanitizedShield > maxShield ? maxShield : sanitizedShield,
        actualShieldAdded: 0,
        overflowShield: effectiveShield,
      );
    }
    if (effectiveShield <= capacity) {
      return ShieldApplyResult(
        newShield: sanitizedShield + effectiveShield,
        actualShieldAdded: effectiveShield,
        overflowShield: 0,
      );
    } else {
      return ShieldApplyResult(
        newShield: maxShield,
        actualShieldAdded: capacity,
        overflowShield: effectiveShield - capacity,
      );
    }
  }

  return ShieldApplyResult(
    newShield: sanitizedShield + effectiveShield,
    actualShieldAdded: effectiveShield,
    overflowShield: 0,
  );
}
