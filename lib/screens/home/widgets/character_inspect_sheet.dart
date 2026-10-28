import 'package:flutter/material.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/enhancement_stats.dart';
import '../../../models/inventory_model.dart';
import '../../../models/item_model.dart';
import '../../../models/moradon_models.dart';
import '../../../models/player_model.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/restriction_ward_world_provider.dart';

/// Formats character combat power cleanly for overhead nameplates & inspect UI
/// (e.g. `173372` -> `173.372`, `14850` -> `14.850`, `950` -> `950`).
String formatCharacterPower(int power) {
  final int safe = power < 0 ? 0 : power;
  if (safe >= 100000000) {
    return '${(safe / 1000000).toStringAsFixed(1)}M';
  }
  final String digits = safe.toString();
  if (digits.length <= 3) return digits;
  final StringBuffer buf = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buf.write('.');
    }
    buf.write(digits[i]);
  }
  return buf.toString();
}

/// Overhead power badge rendered on EVERY character's nameplate on the Home screen
/// (Moradon local player, remote online players, ambient town citizens, royal guards,
/// and Hospital/Prison online peers + local hero).
class CharacterNameplatePowerBadge extends StatelessWidget {
  final int power;
  final bool isLocal;
  final bool isHighlighted;

  const CharacterNameplatePowerBadge({
    super.key,
    required this.power,
    this.isLocal = false,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor = isLocal
        ? const Color(0xFFFBBF24)
        : (isHighlighted
            ? const Color(0xFF4ADE80)
            : const Color(0xFFF59E0B).withValues(alpha: 0.72));
    final Color textColor = isLocal
        ? const Color(0xFFFEF08A)
        : (isHighlighted ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A));

    return Container(
      margin: const EdgeInsets.only(top: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 1.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xEB0B1222), Color(0xF017110B)],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: isLocal ? 1.0 : 0.85),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.bolt_rounded,
            size: isLocal ? 11.5 : 10.5,
            color: const Color(0xFFFBBF24),
          ),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              '${formatCharacterPower(power)} Güç',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: isLocal ? 10.2 : 9.6,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.15,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InspectedEquippedItem {
  final String equipSlot;
  final String itemId;
  final String name;
  final String icon;
  final ItemType itemType;
  final Rarity rarity;
  final int enhancementLevel;
  final int baseAttack;
  final int baseDefense;
  final int baseHealth;
  final int baseLuck;
  final int requiredLevel;

  const InspectedEquippedItem({
    required this.equipSlot,
    required this.itemId,
    required this.name,
    required this.icon,
    required this.itemType,
    required this.rarity,
    this.enhancementLevel = 0,
    this.baseAttack = 0,
    this.baseDefense = 0,
    this.baseHealth = 0,
    this.baseLuck = 0,
    this.requiredLevel = 1,
  });

  int get effectiveAttack => enhancedStat(baseAttack, enhancementLevel);
  int get effectiveDefense => enhancedStat(baseDefense, enhancementLevel);
  int get effectiveHealth => enhancedStat(baseHealth, enhancementLevel);
  int get effectiveLuck => enhancedStat(baseLuck, enhancementLevel);

  int get effectiveGearPower {
    final double raw =
        baseAttack + baseDefense + (baseHealth / 10.0) + (baseLuck * 2.0);
    return (raw * enhancementMultiplier(enhancementLevel)).floor();
  }

  String get displayNameWithEnhancement =>
      enhancementLevel > 0 ? '+$enhancementLevel $name' : name;

  factory InspectedEquippedItem.fromInventoryItem(
    String slotKey,
    InventoryItem item,
  ) {
    return InspectedEquippedItem(
      equipSlot: slotKey,
      itemId: item.itemId,
      name: item.name,
      icon: item.icon,
      itemType: item.itemType,
      rarity: item.rarity,
      enhancementLevel: item.enhancementLevel,
      baseAttack: item.attack,
      baseDefense: item.defense,
      baseHealth: item.health,
      baseLuck: item.luck,
      requiredLevel: item.requiredLevel,
    );
  }

  factory InspectedEquippedItem.fromRpcJson(Map<String, dynamic> json) {
    final EquipSlot parsedSlot = EquipSlotParsing.fromValue(
      (json['equip_slot'] ?? 'weapon').toString(),
    );
    final String slotKey = parsedSlot == EquipSlot.none
        ? (json['equip_slot'] ?? 'weapon').toString().toLowerCase()
        : parsedSlot.name;
    return InspectedEquippedItem(
      equipSlot: slotKey,
      itemId: (json['item_id'] ?? '').toString(),
      name: (json['name'] ?? 'Ekipman').toString(),
      icon: (json['icon'] ?? '').toString(),
      itemType: ItemTypeParsing.fromValue(
        (json['item_type'] ?? 'armor').toString(),
      ),
      rarity: RarityParsing.fromValue((json['rarity'] ?? 'common').toString()),
      enhancementLevel: (json['enhancement_level'] as num?)?.toInt() ?? 0,
      baseAttack: (json['attack'] as num?)?.toInt() ?? 0,
      baseDefense: (json['defense'] as num?)?.toInt() ?? 0,
      baseHealth: (json['health'] as num?)?.toInt() ?? 0,
      baseLuck: (json['luck'] as num?)?.toInt() ?? 0,
      requiredLevel: (json['required_level'] as num?)?.toInt() ?? 1,
    );
  }
}

class InspectedCharacterData {
  final String userId;
  final String username;
  final String displayName;
  final String characterClass;
  final int level;
  final int totalPower;
  final int attack;
  final int defense;
  final int health;
  final int maxHealth;
  final int luck;
  final int reputation;
  final int pvpRating;
  final int pvpWins;
  final int pvpLosses;
  final String? guildName;
  final String? cosmeticTitle;
  final bool isOnline;
  final bool isSelf;
  final bool isAmbientShowcase;
  final bool isMerchant;
  final String? merchantTitle;
  final String? statusBadgeText;
  final Color? statusBadgeColor;
  final Map<String, InspectedEquippedItem> equippedBySlot;

  const InspectedCharacterData({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.characterClass,
    required this.level,
    required this.totalPower,
    required this.attack,
    required this.defense,
    required this.health,
    required this.maxHealth,
    this.luck = 0,
    this.reputation = 0,
    this.pvpRating = 1000,
    this.pvpWins = 0,
    this.pvpLosses = 0,
    this.guildName,
    this.cosmeticTitle,
    this.isOnline = true,
    this.isSelf = false,
    this.isAmbientShowcase = false,
    this.isMerchant = false,
    this.merchantTitle,
    this.statusBadgeText,
    this.statusBadgeColor,
    this.equippedBySlot = const <String, InspectedEquippedItem>{},
  });

  InspectedCharacterData copyWith({
    String? username,
    String? displayName,
    String? characterClass,
    int? level,
    int? totalPower,
    int? attack,
    int? defense,
    int? health,
    int? maxHealth,
    int? luck,
    int? reputation,
    int? pvpRating,
    int? pvpWins,
    int? pvpLosses,
    String? guildName,
    String? cosmeticTitle,
    bool? isOnline,
    bool? isMerchant,
    String? merchantTitle,
    String? statusBadgeText,
    Color? statusBadgeColor,
    Map<String, InspectedEquippedItem>? equippedBySlot,
  }) {
    return InspectedCharacterData(
      userId: userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      characterClass: characterClass ?? this.characterClass,
      level: level ?? this.level,
      totalPower: totalPower ?? this.totalPower,
      attack: attack ?? this.attack,
      defense: defense ?? this.defense,
      health: health ?? this.health,
      maxHealth: maxHealth ?? this.maxHealth,
      luck: luck ?? this.luck,
      reputation: reputation ?? this.reputation,
      pvpRating: pvpRating ?? this.pvpRating,
      pvpWins: pvpWins ?? this.pvpWins,
      pvpLosses: pvpLosses ?? this.pvpLosses,
      guildName: guildName ?? this.guildName,
      cosmeticTitle: cosmeticTitle ?? this.cosmeticTitle,
      isOnline: isOnline ?? this.isOnline,
      isSelf: isSelf,
      isAmbientShowcase: isAmbientShowcase,
      isMerchant: isMerchant ?? this.isMerchant,
      merchantTitle: merchantTitle ?? this.merchantTitle,
      statusBadgeText: statusBadgeText ?? this.statusBadgeText,
      statusBadgeColor: statusBadgeColor ?? this.statusBadgeColor,
      equippedBySlot: equippedBySlot ?? this.equippedBySlot,
    );
  }

  static InspectedCharacterData fromLocalPlayer({
    required PlayerProfile profile,
    required InventoryState inventoryState,
    required int totalPower,
    String? statusBadgeText,
    Color? statusBadgeColor,
  }) {
    final Map<String, InspectedEquippedItem> slots =
        <String, InspectedEquippedItem>{};
    for (final MapEntry<String, InventoryItem?> entry
        in inventoryState.equippedItems.entries) {
      final InventoryItem? it = entry.value;
      if (it == null) continue;
      slots[entry.key] = InspectedEquippedItem.fromInventoryItem(entry.key, it);
    }

    return InspectedCharacterData(
      userId: profile.id,
      username: profile.username,
      displayName: (profile.displayName != null &&
              profile.displayName!.trim().isNotEmpty)
          ? profile.displayName!
          : profile.username,
      characterClass: profile.characterClass?.name ?? 'savasci',
      level: profile.level,
      totalPower: totalPower > 0 ? totalPower : profile.power,
      attack: profile.attack,
      defense: profile.defense,
      health: profile.health,
      maxHealth: profile.maxHealth,
      luck: (profile.luck ?? 0) + profile.equipBonusLuck,
      reputation: profile.reputation ?? 0,
      pvpRating: profile.pvpRating,
      pvpWins: profile.pvpWins,
      pvpLosses: profile.pvpLosses,
      guildName: profile.guildName,
      cosmeticTitle: profile.cosmeticTitle,
      isOnline: true,
      isSelf: true,
      statusBadgeText: statusBadgeText,
      statusBadgeColor: statusBadgeColor,
      equippedBySlot: slots,
    );
  }

  static InspectedCharacterData seedFromMoradonPresence(
    MoradonPlayerPresence p,
  ) {
    final bool isSynthetic =
        p.isAmbientBot ||
        p.userId.startsWith('ambient_') ||
        p.userId.startsWith('guard_');
    final Map<String, InspectedEquippedItem> gear = isSynthetic
        ? _synthesizeTownShowcaseGear(
            classRaw: p.characterClass,
            level: p.level,
            glowLevel: p.weaponGlowLevel,
            weaponVisual: p.weaponVisual,
            weaponLabel: p.weaponLabel,
          )
        : const <String, InspectedEquippedItem>{};

    int gearAtk = 0;
    int gearDef = 0;
    int gearHp = 0;
    int gearLuck = 0;
    for (final InspectedEquippedItem item in gear.values) {
      gearAtk += item.effectiveAttack;
      gearDef += item.effectiveDefense;
      gearHp += item.effectiveHealth;
      gearLuck += item.effectiveLuck;
    }

    return InspectedCharacterData(
      userId: p.userId,
      username: p.username,
      displayName: p.username,
      characterClass: p.characterClass,
      level: p.level,
      totalPower: p.totalPower,
      attack: gearAtk > 0 ? gearAtk : (p.level * 195 + 140),
      defense: gearDef > 0 ? gearDef : (p.level * 210 + 160),
      health: gearHp > 0 ? (gearHp + p.level * 120) : (p.level * 260 + 500),
      maxHealth: gearHp > 0 ? (gearHp + p.level * 120) : (p.level * 260 + 500),
      luck: gearLuck > 0 ? gearLuck : (p.level * 32),
      reputation: p.level * 48,
      pvpRating: 1000 + p.level * 8,
      pvpWins: (p.level ~/ 3) + 4,
      pvpLosses: (p.level ~/ 6) + 1,
      guildName: p.guildName,
      cosmeticTitle: p.cosmeticTitle,
      isOnline: true,
      isAmbientShowcase: isSynthetic,
      isMerchant: p.isMerchant,
      merchantTitle: p.merchantTitle,
      statusBadgeText: p.isMerchant ? '🛒 Pazar Tezgahı Açık' : null,
      statusBadgeColor: p.isMerchant ? const Color(0xFFFBBF24) : null,
      equippedBySlot: gear,
    );
  }

  static InspectedCharacterData fromPatrolGuard(MoradonPatrolGuard g) {
    final Map<String, InspectedEquippedItem> gear = _synthesizeTownShowcaseGear(
      classRaw: 'savasci',
      level: 75,
      glowLevel: 9,
      weaponVisual: MoradonWeaponVisual.imperialHalberd,
      weaponLabel: '+9 Imperial Halberd',
    );
    return InspectedCharacterData(
      userId: g.id,
      username: g.name,
      displayName: g.name,
      characterClass: 'savasci',
      level: 75,
      totalPower: g.totalPower,
      attack: 18400,
      defense: 24600,
      health: 32000,
      maxHealth: 32000,
      luck: 4200,
      reputation: 9500,
      pvpRating: 1650,
      pvpWins: 142,
      pvpLosses: 12,
      guildName: g.title,
      cosmeticTitle: 'Surların Kalkanı',
      isOnline: true,
      isAmbientShowcase: true,
      statusBadgeText: '🛡️ Kraliyet Devriyesi',
      statusBadgeColor: const Color(0xFF60A5FA),
      equippedBySlot: gear,
    );
  }

  static InspectedCharacterData seedFromWardPeer({
    required OnlineWardPeer peer,
    required String statusBadgeText,
    required Color statusBadgeColor,
  }) {
    return InspectedCharacterData(
      userId: peer.userId,
      username: peer.username,
      displayName: peer.displayName,
      characterClass: peer.characterClass,
      level: peer.level,
      totalPower: peer.power,
      attack: peer.level * 180 + 120,
      defense: peer.level * 190 + 140,
      health: peer.level * 220 + 400,
      maxHealth: peer.level * 260 + 500,
      luck: peer.level * 25,
      reputation: peer.level * 30,
      guildName: peer.guildName,
      cosmeticTitle: peer.cosmeticTitle,
      isOnline: true,
      statusBadgeText: statusBadgeText,
      statusBadgeColor: statusBadgeColor,
    );
  }

  static Map<String, InspectedEquippedItem> _synthesizeTownShowcaseGear({
    required String classRaw,
    required int level,
    required int glowLevel,
    required MoradonWeaponVisual weaponVisual,
    String? weaponLabel,
  }) {
    final String lower = classRaw.toLowerCase();
    final bool isShadow = lower.contains('golge') || lower.contains('shadow');
    final bool isAlchemist =
        lower.contains('simyaci') || lower.contains('alchemist');
    final Rarity tier = level >= 65
        ? Rarity.mythic
        : (level >= 52 ? Rarity.legendary : Rarity.epic);
    final String tierSuffix = tier.name;
    final int enh = glowLevel.clamp(4, 10);
    final int armorEnh = (enh - 1).clamp(3, 9);

    String cleanWeaponName = (weaponLabel ?? '').replaceFirst(
      RegExp(r'^\+\d+\s*'),
      '',
    );
    if (cleanWeaponName.isEmpty) {
      cleanWeaponName = isShadow
          ? 'Twilight Fang'
          : (isAlchemist ? 'Aether Asası' : 'Imperial Halberd');
    }
    final String weaponIcon = switch (weaponVisual) {
      MoradonWeaponVisual.twilightFang => 'wpn_dagger_$tierSuffix',
      MoradonWeaponVisual.aetherStaff => 'wpn_staff_$tierSuffix',
      MoradonWeaponVisual.crimsonAxe => 'wpn_axe_$tierSuffix',
      MoradonWeaponVisual.imperialHalberd ||
      MoradonWeaponVisual.illusionSabre ||
      MoradonWeaponVisual.none =>
        isShadow
            ? 'wpn_dagger_$tierSuffix'
            : (isAlchemist
                ? 'wpn_staff_$tierSuffix'
                : 'wpn_sword_$tierSuffix'),
    };

    return <String, InspectedEquippedItem>{
      'weapon': InspectedEquippedItem(
        equipSlot: 'weapon',
        itemId: weaponIcon,
        name: cleanWeaponName,
        icon: weaponIcon,
        itemType: ItemType.weapon,
        rarity: tier,
        enhancementLevel: enh,
        baseAttack: level * 48 + 320,
        baseDefense: level * 4,
        baseLuck: level * 8,
        requiredLevel: (level - 5).clamp(1, 80),
      ),
      'head': InspectedEquippedItem(
        equipSlot: 'head',
        itemId: isAlchemist
            ? 'head_crown_$tierSuffix'
            : 'head_helm_$tierSuffix',
        name: isShadow
            ? 'Gölge Maskesi'
            : (isAlchemist ? 'Arkana Tacı' : 'Kraliyet Miğferi'),
        icon: isAlchemist ? 'head_crown_$tierSuffix' : 'head_helm_$tierSuffix',
        itemType: ItemType.armor,
        rarity: tier,
        enhancementLevel: armorEnh,
        baseAttack: level * 10,
        baseDefense: level * 22 + 120,
        baseHealth: level * 26 + 180,
        requiredLevel: (level - 5).clamp(1, 80),
      ),
      'chest': InspectedEquippedItem(
        equipSlot: 'chest',
        itemId: isShadow
            ? 'chest_leather_$tierSuffix'
            : (isAlchemist
                ? 'chest_robe_$tierSuffix'
                : 'chest_plate_$tierSuffix'),
        name: isShadow
            ? 'Gece Avcısı Zırhı'
            : (isAlchemist ? 'Mistik Cübbe' : 'Obsidyen Plaka Zırh'),
        icon: isShadow
            ? 'chest_leather_$tierSuffix'
            : (isAlchemist
                ? 'chest_robe_$tierSuffix'
                : 'chest_plate_$tierSuffix'),
        itemType: ItemType.armor,
        rarity: tier,
        enhancementLevel: armorEnh,
        baseDefense: level * 38 + 260,
        baseHealth: level * 52 + 400,
        requiredLevel: (level - 5).clamp(1, 80),
      ),
      'gloves': InspectedEquippedItem(
        equipSlot: 'gloves',
        itemId: isShadow
            ? 'gloves_wraps_$tierSuffix'
            : 'gloves_mitts_$tierSuffix',
        name: isShadow ? 'Suikastçı Sargısı' : 'Rünlü Eldiven',
        icon: isShadow
            ? 'gloves_wraps_$tierSuffix'
            : 'gloves_mitts_$tierSuffix',
        itemType: ItemType.armor,
        rarity: tier,
        enhancementLevel: armorEnh,
        baseAttack: level * 14 + 60,
        baseDefense: level * 15 + 80,
        baseLuck: level * 6,
        requiredLevel: (level - 5).clamp(1, 80),
      ),
      'legs': InspectedEquippedItem(
        equipSlot: 'legs',
        itemId: 'legs_leggings_$tierSuffix',
        name: isShadow ? 'Gölge Dizlik' : 'Savaşçı Dizliği',
        icon: 'legs_leggings_$tierSuffix',
        itemType: ItemType.armor,
        rarity: tier,
        enhancementLevel: armorEnh,
        baseDefense: level * 30 + 190,
        baseHealth: level * 34 + 260,
        requiredLevel: (level - 5).clamp(1, 80),
      ),
      'boots': InspectedEquippedItem(
        equipSlot: 'boots',
        itemId: isShadow
            ? 'boots_moccasins_$tierSuffix'
            : (isAlchemist
                ? 'boots_sandals_$tierSuffix'
                : 'boots_sabaton_$tierSuffix'),
        name: isShadow
            ? 'Sessiz Adım Çizmesi'
            : (isAlchemist ? 'Kahin Sandalı' : 'Demir Sabaton'),
        icon: isShadow
            ? 'boots_moccasins_$tierSuffix'
            : (isAlchemist
                ? 'boots_sandals_$tierSuffix'
                : 'boots_sabaton_$tierSuffix'),
        itemType: ItemType.armor,
        rarity: tier,
        enhancementLevel: armorEnh,
        baseDefense: level * 18 + 110,
        baseHealth: level * 20 + 140,
        baseLuck: level * 7,
        requiredLevel: (level - 5).clamp(1, 80),
      ),
      'necklace': InspectedEquippedItem(
        equipSlot: 'necklace',
        itemId: 'neck_pendant_$tierSuffix',
        name: 'Ejderha Tılsımı',
        icon: 'neck_pendant_$tierSuffix',
        itemType: ItemType.armor,
        rarity: tier,
        enhancementLevel: (armorEnh - 1).clamp(2, 8),
        baseAttack: level * 12 + 50,
        baseDefense: level * 12 + 50,
        baseHealth: level * 30 + 200,
        baseLuck: level * 9,
        requiredLevel: (level - 5).clamp(1, 80),
      ),
      'ring': InspectedEquippedItem(
        equipSlot: 'ring',
        itemId: 'ring_loop_$tierSuffix',
        name: 'Hükümdar Yüzüğü',
        icon: 'ring_loop_$tierSuffix',
        itemType: ItemType.armor,
        rarity: tier,
        enhancementLevel: (armorEnh - 1).clamp(2, 8),
        baseAttack: level * 15 + 65,
        baseDefense: level * 14 + 55,
        baseLuck: level * 10,
        requiredLevel: (level - 5).clamp(1, 80),
      ),
    };
  }
}

class CharacterInspectService {
  CharacterInspectService._();

  static final Map<String, ({InspectedCharacterData data, DateTime fetchedAt})>
      _cache = <String, ({InspectedCharacterData data, DateTime fetchedAt})>{};

  static void clearCache() => _cache.clear();

  static Future<InspectedCharacterData> loadCharacter({
    required String userId,
    required InspectedCharacterData seed,
    bool forceRefresh = false,
  }) async {
    if (seed.isSelf ||
        seed.isAmbientShowcase ||
        userId.isEmpty ||
        userId.startsWith('ambient_') ||
        userId.startsWith('guard_')) {
      return seed;
    }

    final DateTime now = DateTime.now();
    final ({InspectedCharacterData data, DateTime fetchedAt})? cached =
        _cache[userId];
    if (!forceRefresh &&
        cached != null &&
        now.difference(cached.fetchedAt) <= const Duration(seconds: 15)) {
      return cached.data.copyWith(
        isMerchant: seed.isMerchant,
        merchantTitle: seed.merchantTitle,
        statusBadgeText: seed.statusBadgeText,
        statusBadgeColor: seed.statusBadgeColor,
      );
    }

    if (!SupabaseService.isInitialized) {
      return seed;
    }

    try {
      final dynamic res = await SupabaseService.client
          .rpc(
            'get_public_character_inspect',
            params: <String, dynamic>{'p_target_id': userId},
          )
          .timeout(const Duration(seconds: 6));

      if (res is Map && res['success'] == true && res['character'] is Map) {
        final Map<String, dynamic> ch =
            Map<String, dynamic>.from(res['character'] as Map);
        final Map<String, InspectedEquippedItem> equipped =
            <String, InspectedEquippedItem>{};
        final dynamic rawItems = ch['equipped_items'];
        if (rawItems is List) {
          for (final dynamic raw in rawItems) {
            if (raw is! Map) continue;
            final InspectedEquippedItem parsed =
                InspectedEquippedItem.fromRpcJson(
                  Map<String, dynamic>.from(raw),
                );
            equipped[parsed.equipSlot] = parsed;
          }
        }

        final int resolvedPower =
            (ch['power'] as num?)?.toInt() ?? seed.totalPower;
        final InspectedCharacterData full = InspectedCharacterData(
          userId: (ch['user_id'] ?? userId).toString(),
          username: (ch['username'] ?? seed.username).toString(),
          displayName: (ch['display_name'] ?? seed.displayName).toString(),
          characterClass:
              (ch['character_class'] ?? seed.characterClass).toString(),
          level: (ch['level'] as num?)?.toInt() ?? seed.level,
          totalPower: resolvedPower > 0 ? resolvedPower : seed.totalPower,
          attack: (ch['attack'] as num?)?.toInt() ?? seed.attack,
          defense: (ch['defense'] as num?)?.toInt() ?? seed.defense,
          health: (ch['health'] as num?)?.toInt() ?? seed.health,
          maxHealth: (ch['max_health'] as num?)?.toInt() ?? seed.maxHealth,
          luck: (ch['luck'] as num?)?.toInt() ?? seed.luck,
          reputation: (ch['reputation'] as num?)?.toInt() ?? seed.reputation,
          pvpRating: (ch['pvp_rating'] as num?)?.toInt() ?? seed.pvpRating,
          pvpWins: (ch['pvp_wins'] as num?)?.toInt() ?? seed.pvpWins,
          pvpLosses: (ch['pvp_losses'] as num?)?.toInt() ?? seed.pvpLosses,
          guildName: ch['guild_name'] as String? ?? seed.guildName,
          cosmeticTitle: ch['cosmetic_title'] as String? ?? seed.cosmeticTitle,
          isOnline: ch['is_online'] as bool? ?? true,
          isSelf: false,
          isAmbientShowcase: false,
          isMerchant: seed.isMerchant,
          merchantTitle: seed.merchantTitle,
          statusBadgeText: seed.statusBadgeText,
          statusBadgeColor: seed.statusBadgeColor,
          equippedBySlot: equipped,
        );

        _cache[userId] = (data: full, fetchedAt: now);
        return full;
      }
    } catch (_) {
      // Fallback to live presence seed if offline/uninitialized in widget tests.
    }
    return seed;
  }
}

const List<({String key, String label, IconData icon})> kCharacterEquipSlots =
    <({String key, String label, IconData icon})>[
  (key: 'weapon', label: 'Silah', icon: Icons.gavel_rounded),
  (key: 'head', label: 'Kask', icon: Icons.shield_moon_outlined),
  (key: 'chest', label: 'Zırh', icon: Icons.shield_outlined),
  (key: 'gloves', label: 'Eldiven', icon: Icons.back_hand_outlined),
  (key: 'legs', label: 'Bacak', icon: Icons.accessibility_new_rounded),
  (key: 'boots', label: 'Çizme', icon: Icons.hiking_outlined),
  (key: 'necklace', label: 'Kolye', icon: Icons.diamond_outlined),
  (key: 'ring', label: 'Yüzük', icon: Icons.radio_button_checked_rounded),
];

Color rarityAccentColor(Rarity rarity) {
  switch (rarity) {
    case Rarity.common:
      return const Color(0xFF94A3B8);
    case Rarity.uncommon:
      return const Color(0xFF4ADE80);
    case Rarity.rare:
      return const Color(0xFF38BDF8);
    case Rarity.epic:
      return const Color(0xFFC084FC);
    case Rarity.legendary:
      return const Color(0xFFF59E0B);
    case Rarity.mythic:
      return const Color(0xFFF43F5E);
  }
}

String rarityDisplayTr(Rarity rarity) {
  switch (rarity) {
    case Rarity.common:
      return 'Sıradan';
    case Rarity.uncommon:
      return 'Gelişmiş';
    case Rarity.rare:
      return 'Nadir';
    case Rarity.epic:
      return 'Destansı';
    case Rarity.legendary:
      return 'Efsanevi';
    case Rarity.mythic:
      return 'Mitik';
  }
}

String characterClassDisplayTr(String rawClass) {
  final String lower = rawClass.toLowerCase();
  if (lower.contains('golge') || lower.contains('shadow')) {
    return 'Gölge';
  }
  if (lower.contains('simyaci') || lower.contains('alchemist')) {
    return 'Simyacı';
  }
  return 'Savaşçı';
}

String characterClassPortraitAsset(String rawClass) {
  final String lower = rawClass.toLowerCase();
  if (lower.contains('golge') || lower.contains('shadow')) {
    return 'assets/characters/golge.png';
  }
  if (lower.contains('simyaci') || lower.contains('alchemist')) {
    return 'assets/characters/simyaci.png';
  }
  return 'assets/characters/savasci.png';
}

class CharacterInspectAction {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const CharacterInspectAction({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

/// Opens the full mobile-first RPG Character Inspection Sheet (`Karakter İnceleme`)
/// for any character tapped on the Home Screen.
Future<void> showCharacterInspectModal({
  required BuildContext context,
  required InspectedCharacterData seed,
  List<CharacterInspectAction> actions = const <CharacterInspectAction>[],
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      final double maxSheetH = MediaQuery.sizeOf(sheetContext).height * 0.86;
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetH, maxWidth: 540),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFA0C1324), Color(0xFC070B14)],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.55),
                width: 1.2,
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Colors.black87, blurRadius: 24),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  CharacterInspectPanel(
                    seed: seed,
                    expandedView: true,
                    onClose: () => Navigator.of(sheetContext).pop(),
                    actions: actions,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Live-fetching RPG Character Inspection Card used both inline when clicking a
/// character on the Home Screen AND inside `showCharacterInspectModal`.
class CharacterInspectPanel extends StatefulWidget {
  final InspectedCharacterData seed;
  final VoidCallback? onClose;
  final List<CharacterInspectAction> actions;
  final bool expandedView;

  const CharacterInspectPanel({
    super.key,
    required this.seed,
    this.onClose,
    this.actions = const <CharacterInspectAction>[],
    this.expandedView = false,
  });

  @override
  State<CharacterInspectPanel> createState() => _CharacterInspectPanelState();
}

class _CharacterInspectPanelState extends State<CharacterInspectPanel> {
  late InspectedCharacterData _data;
  bool _loading = false;
  String? _selectedSlotKey;

  @override
  void initState() {
    super.initState();
    _data = widget.seed;
    _pickInitialSlot();
    _fetchLiveDetails();
  }

  @override
  void didUpdateWidget(covariant CharacterInspectPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed.userId != widget.seed.userId) {
      _data = widget.seed;
      _selectedSlotKey = null;
      _pickInitialSlot();
      _fetchLiveDetails();
    } else if (widget.seed.isSelf || widget.seed.isAmbientShowcase) {
      _data = widget.seed;
    }
  }

  void _pickInitialSlot() {
    if (_data.equippedBySlot.containsKey('weapon')) {
      _selectedSlotKey = 'weapon';
    } else if (_data.equippedBySlot.isNotEmpty) {
      _selectedSlotKey = _data.equippedBySlot.keys.first;
    }
  }

  Future<void> _fetchLiveDetails() async {
    if (widget.seed.isSelf || widget.seed.isAmbientShowcase) return;
    setState(() => _loading = true);
    final InspectedCharacterData loaded =
        await CharacterInspectService.loadCharacter(
      userId: widget.seed.userId,
      seed: widget.seed,
    );
    if (!mounted || loaded.userId != widget.seed.userId) return;
    setState(() {
      _data = loaded;
      _loading = false;
      if (_selectedSlotKey == null ||
          !_data.equippedBySlot.containsKey(_selectedSlotKey)) {
        _pickInitialSlot();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final InspectedCharacterData d = _data;
    final InspectedEquippedItem? focusedItem =
        _selectedSlotKey == null ? null : d.equippedBySlot[_selectedSlotKey!];

    return Container(
      key: ValueKey<String>('character_inspect_panel_${d.userId}'),
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        widget.expandedView ? 12 : 10,
      ),
      decoration: widget.expandedView
          ? null
          : BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xF50B1222), Color(0xF5070B14)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.72),
                width: 1.25,
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Colors.black87,
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 1. Header: Portrait, Nickname, Class/Guild & Total Power Crest
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF111C33),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.75),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  characterClassPortraitAsset(d.characterClass),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.shield_rounded,
                    color: Color(0xFFFBBF24),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            'Lv.${d.level} ${d.displayName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (d.isOnline) ...<Widget>[
                          const SizedBox(width: 5),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4ADE80),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${characterClassDisplayTr(d.characterClass)}'
                      '${d.guildName != null && d.guildName!.isNotEmpty ? " • <${d.guildName}>" : ""}'
                      '${d.cosmeticTitle != null && d.cosmeticTitle!.isNotEmpty ? " • «${d.cosmeticTitle}»" : ""}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontSize: 10.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Prominent Golden Total Power Crest
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF422006), Color(0xFF1F1206)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFBBF24),
                    width: 1.1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    const Text(
                      'TOPLAM GÜÇ',
                      style: TextStyle(
                        color: Color(0xFFFDE68A),
                        fontSize: 8.2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.bolt_rounded,
                          size: 13,
                          color: Color(0xFFFBBF24),
                        ),
                        Text(
                          formatCharacterPower(d.totalPower),
                          style: const TextStyle(
                            color: Color(0xFFFEF08A),
                            fontSize: 12.8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.onClose != null) ...<Widget>[
                const SizedBox(width: 4),
                InkWell(
                  onTap: widget.onClose,
                  borderRadius: BorderRadius.circular(999),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white60,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ],
          ),

          if (d.statusBadgeText != null &&
              d.statusBadgeText!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (d.statusBadgeColor ?? const Color(0xFF38BDF8))
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (d.statusBadgeColor ?? const Color(0xFF38BDF8))
                      .withValues(alpha: 0.55),
                  width: 0.9,
                ),
              ),
              child: Text(
                d.statusBadgeText!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: d.statusBadgeColor ?? const Color(0xFFBAE6FD),
                  fontSize: 10.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),

          // 2. Combat & PvP Stats Strip
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: <Widget>[
              _buildStatChip('⚔️ Saldırı', formatCharacterPower(d.attack)),
              _buildStatChip('🛡️ Savunma', formatCharacterPower(d.defense)),
              _buildStatChip('❤️ Can', formatCharacterPower(d.maxHealth)),
              if (widget.expandedView || d.luck > 0)
                _buildStatChip('🍀 Şans', formatCharacterPower(d.luck)),
              if (widget.expandedView) ...<Widget>[
                _buildStatChip('👑 İtibar', formatCharacterPower(d.reputation)),
                _buildStatChip(
                  '🏆 PvP',
                  '${d.pvpRating} (${d.pvpWins}G/${d.pvpLosses}M)',
                ),
              ],
            ],
          ),

          const SizedBox(height: 9),

          // 3. Equipped Items Header + 8-Slot Showcase Strip / Grid
          Row(
            children: <Widget>[
              const Icon(
                Icons.shield_moon_rounded,
                size: 13,
                color: Color(0xFFFBBF24),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'KUŞANILAN EKİPMANLAR (${d.equippedBySlot.length}/8)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFDE68A),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              if (_loading) ...<Widget>[
                const SizedBox(width: 6),
                const SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: Color(0xFFFBBF24),
                  ),
                ),
              ],
              if (!widget.expandedView) ...<Widget>[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => showCharacterInspectModal(
                    context: context,
                    seed: d,
                    actions: widget.actions,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.65),
                      ),
                    ),
                    child: const Text(
                      '🔍 Tam Profil',
                      style: TextStyle(
                        color: Color(0xFFBAE6FD),
                        fontSize: 9.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // Responsive 8-slot row/wrap (fits 360px phones cleanly: 4x2 or scrollable strip)
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              final double gap = 6.0;
              final int cols = box.maxWidth >= 380 ? 8 : 4;
              final double cellW =
                  ((box.maxWidth - gap * (cols - 1)) / cols).clamp(38.0, 56.0);
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: kCharacterEquipSlots
                    .map((({String key, String label, IconData icon}) slot) {
                  final InspectedEquippedItem? item =
                      d.equippedBySlot[slot.key];
                  final bool isFocused = _selectedSlotKey == slot.key;
                  return _buildEquipSlotTile(
                    slotKey: slot.key,
                    slotLabel: slot.label,
                    fallbackIcon: slot.icon,
                    item: item,
                    size: cellW,
                    isFocused: isFocused,
                  );
                }).toList(),
              );
            },
          ),

          // 4. Selected Item Detail Strip (Instant Item Name, Rarity, +Enhancement & Stats!)
          if (focusedItem != null) ...<Widget>[
            const SizedBox(height: 7),
            _buildFocusedItemCard(focusedItem),
          ] else if (!_loading && d.equippedBySlot.isEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Bu karakterin üzerinde kuşanılmış ekipman bulunmuyor.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.54),
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          // 5. Action Buttons Row (Duel, Trade, Chat, Friend, Market, etc.)
          if (widget.actions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 9),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.actions.map((CharacterInspectAction act) {
                return InkWell(
                  onTap: act.onTap,
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: act.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: act.color.withValues(alpha: 0.72),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(act.emoji, style: const TextStyle(fontSize: 11.5)),
                        const SizedBox(width: 4),
                        Text(
                          act.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Color(0xFFE2E8F0),
          fontSize: 10.2,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildEquipSlotTile({
    required String slotKey,
    required String slotLabel,
    required IconData fallbackIcon,
    required InspectedEquippedItem? item,
    required double size,
    required bool isFocused,
  }) {
    final bool hasItem = item != null;
    final Color rarityColor =
        hasItem ? rarityAccentColor(item.rarity) : Colors.white24;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSlotKey = slotKey;
        });
      },
      child: Tooltip(
        message: hasItem
            ? '$slotLabel: ${item.displayNameWithEnhancement} (${rarityDisplayTr(item.rarity)})'
            : '$slotLabel: Boş',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF090E1A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFocused
                  ? const Color(0xFFFDE047)
                  : (hasItem
                      ? rarityColor.withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.16)),
              width: isFocused ? 1.6 : 1.1,
            ),
            boxShadow: <BoxShadow>[
              if (hasItem)
                BoxShadow(
                  color: rarityColor.withValues(alpha: isFocused ? 0.45 : 0.22),
                  blurRadius: isFocused ? 8 : 5,
                ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              if (!hasItem)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(fallbackIcon, size: 15, color: Colors.white30),
                      const SizedBox(height: 1),
                      Text(
                        slotLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white30,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(4.5),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: ItemIconView(
                      iconValue: item.icon,
                      itemId: item.itemId,
                      itemType: item.itemType,
                      size: size - 9,
                      expand: true,
                      fallback: '⚔️',
                    ),
                  ),
                ),
              if (hasItem && item.enhancementLevel > 0)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3.5,
                      vertical: 0.8,
                    ),
                    decoration: BoxDecoration(
                      color: item.enhancementLevel >= 8
                          ? const Color(0xFF991B1B)
                          : const Color(0xEB0F172A),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: item.enhancementLevel >= 8
                            ? const Color(0xFFFBBF24)
                            : rarityColor,
                        width: 0.7,
                      ),
                    ),
                    child: Text(
                      '+${item.enhancementLevel}',
                      style: const TextStyle(
                        color: Color(0xFFFEF08A),
                        fontSize: 8.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFocusedItemCard(InspectedEquippedItem item) {
    final Color rColor = rarityAccentColor(item.rarity);
    final List<String> statParts = <String>[
      if (item.effectiveAttack > 0)
        '⚔️ ${formatCharacterPower(item.effectiveAttack)}',
      if (item.effectiveDefense > 0)
        '🛡️ ${formatCharacterPower(item.effectiveDefense)}',
      if (item.effectiveHealth > 0)
        '❤️ ${formatCharacterPower(item.effectiveHealth)}',
      if (item.effectiveLuck > 0)
        '🍀 ${formatCharacterPower(item.effectiveLuck)}',
      if (item.effectiveGearPower > 0)
        '⚡ +${formatCharacterPower(item.effectiveGearPower)} Güç',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6.5),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1324),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: rColor.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  item.displayNameWithEnhancement,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: rColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: rColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${rarityDisplayTr(item.rarity)} • Sv.${item.requiredLevel}',
                  style: TextStyle(
                    color: rColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (statParts.isNotEmpty) ...<Widget>[
            const SizedBox(height: 3),
            Text(
              statParts.join('  •  '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 10.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
