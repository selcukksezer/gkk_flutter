import 'dart:math' as math;

import '../../models/player_model.dart';
import '../../theme/app_colors.dart';
import 'package:flutter/material.dart';

enum CharacterAbilityKind { passive, signature }

/// PLAN_11 — sınıf pasifleri (DB + RPC ile uyumlu).
class CharacterAbilityDef {
  const CharacterAbilityDef({
    required this.icon,
    required this.name,
    required this.effect,
    required this.kind,
    this.system,
  });

  final String icon;
  final String name;
  final String effect;
  final CharacterAbilityKind kind;
  final String? system;
}

Color accentForClass(CharacterClass? charClass) {
  return switch (charClass) {
    CharacterClass.warrior => AppColors.mysticRuby,
    CharacterClass.alchemist => AppColors.coralFlare,
    CharacterClass.shadow => AppColors.mutedTitanium,
    null => AppColors.liquidGold,
  };
}

/// Gölge: etkin şüphe tavanı 80 (Hayalet Adımlar).
int effectiveSuspicionLevel(PlayerProfile? profile) {
  final int raw = profile?.globalSuspicionLevel ?? 0;
  if (profile?.characterClass == CharacterClass.shadow) {
    return raw.clamp(0, 80);
  }
  return raw.clamp(0, 100);
}

/// Gölge: rüşvet gem maliyeti -25%.
int bribeGemCostForClass(CharacterClass? charClass, {int baseCost = 5}) {
  if (charClass == CharacterClass.shadow) {
    return math.max(1, (baseCost * 0.75).ceil());
  }
  return baseCost;
}

List<CharacterAbilityDef> abilitiesForClass(CharacterClass? charClass) {
  return switch (charClass) {
    CharacterClass.warrior => _warriorAbilities,
    CharacterClass.alchemist => _alchemistAbilities,
    CharacterClass.shadow => _shadowAbilities,
    null => const <CharacterAbilityDef>[],
  };
}

const List<CharacterAbilityDef> _warriorAbilities = <CharacterAbilityDef>[
  CharacterAbilityDef(
    icon: '⚔️',
    name: 'PvP Hasar',
    effect: '+20% PvP hasarı',
    kind: CharacterAbilityKind.passive,
    system: 'PvP',
  ),
  CharacterAbilityDef(
    icon: '💥',
    name: 'PvP Kritik',
    effect: '+10% kritik şans (şans üstüne)',
    kind: CharacterAbilityKind.passive,
    system: 'PvP',
  ),
  CharacterAbilityDef(
    icon: '👹',
    name: 'Boss Ödülü',
    effect: '+15% boss zindanı altın ödülü',
    kind: CharacterAbilityKind.passive,
    system: 'Zindan',
  ),
  CharacterAbilityDef(
    icon: '🏰',
    name: 'Zindan Başarısı',
    effect: '+5% zindan başarı oranı',
    kind: CharacterAbilityKind.passive,
    system: 'Zindan',
  ),
  CharacterAbilityDef(
    icon: '🏥',
    name: 'Hızlı İyileşme',
    effect: '-20% hastane süresi',
    kind: CharacterAbilityKind.passive,
    system: 'Hastane',
  ),
  CharacterAbilityDef(
    icon: '🩸',
    name: 'Kan Hırsı',
    effect:
        'PvP galibiyeti: 30 dk hasar +10%; 3 seri galibiyette +20%',
    kind: CharacterAbilityKind.signature,
    system: 'PvP',
  ),
];

const List<CharacterAbilityDef> _alchemistAbilities = <CharacterAbilityDef>[
  CharacterAbilityDef(
    icon: '🧪',
    name: 'İksir Etkinliği',
    effect: '+30% iksir etkinliği',
    kind: CharacterAbilityKind.passive,
    system: 'Tolerans',
  ),
  CharacterAbilityDef(
    icon: '🛡️',
    name: 'Dayanıklı Vücut',
    effect: '-25% tolerans artışı (iksir kullanımı)',
    kind: CharacterAbilityKind.passive,
    system: 'Tolerans',
  ),
  CharacterAbilityDef(
    icon: '💊',
    name: 'Aşırı Doz Koruması',
    effect: '-20% overdose riski',
    kind: CharacterAbilityKind.passive,
    system: 'Tolerans',
  ),
  CharacterAbilityDef(
    icon: '🔨',
    name: 'Usta Zanaatkar',
    effect: '+15% crafting başarı oranı',
    kind: CharacterAbilityKind.passive,
    system: 'Crafting',
  ),
  CharacterAbilityDef(
    icon: '⏱️',
    name: 'Hızlı Üretim',
    effect: '-20% craft süresi',
    kind: CharacterAbilityKind.passive,
    system: 'Crafting',
  ),
  CharacterAbilityDef(
    icon: '✨',
    name: 'Detox Gücü',
    effect: '+25% detox etkinliği',
    kind: CharacterAbilityKind.passive,
    system: 'Tolerans',
  ),
  CharacterAbilityDef(
    icon: '⚗️',
    name: 'Formül Ustası',
    effect: 'Günde 1 ücretsiz Minor Detox',
    kind: CharacterAbilityKind.signature,
    system: 'Sınıf',
  ),
];

const List<CharacterAbilityDef> _shadowAbilities = <CharacterAbilityDef>[
  CharacterAbilityDef(
    icon: '🕵️',
    name: 'Gizli Operasyon',
    effect: '-30% tesis şüphe birikimi',
    kind: CharacterAbilityKind.passive,
    system: 'Tesis',
  ),
  CharacterAbilityDef(
    icon: '💰',
    name: 'Pazarlık',
    effect: '-25% rüşvet gem maliyeti',
    kind: CharacterAbilityKind.passive,
    system: 'Tesis',
  ),
  CharacterAbilityDef(
    icon: '🎁',
    name: 'Ganimet Avcısı',
    effect: '+40% zindan drop şansı',
    kind: CharacterAbilityKind.passive,
    system: 'Zindan',
  ),
  CharacterAbilityDef(
    icon: '💨',
    name: 'PvP Kaçınma',
    effect: '+15% dodge şansı',
    kind: CharacterAbilityKind.passive,
    system: 'PvP',
  ),
  CharacterAbilityDef(
    icon: '🔓',
    name: 'Kaçış Ustası',
    effect: '+20% hapishaneden kaçış şansı',
    kind: CharacterAbilityKind.passive,
    system: 'Hapishane',
  ),
  CharacterAbilityDef(
    icon: '🏴',
    name: 'Kara Pazar',
    effect: '-20% kaçak satış şüphe ve baskın riski',
    kind: CharacterAbilityKind.passive,
    system: 'Mekan',
  ),
  CharacterAbilityDef(
    icon: '👻',
    name: 'Hayalet Adımlar',
    effect: 'Etkin şüphe tavanı 80 (ham 100 → 80 sayılır)',
    kind: CharacterAbilityKind.signature,
    system: 'Tesis',
  ),
];

bool isWarriorBloodlustActive(PlayerProfile? profile) {
  if (profile?.characterClass != CharacterClass.warrior) return false;
  final String? until = profile?.warriorBloodlustUntil;
  if (until == null || until.isEmpty) return false;
  final DateTime? parsed = DateTime.tryParse(until);
  if (parsed == null) return false;
  return parsed.isAfter(DateTime.now());
}
