// Aion-2 Art Assets Manifest & Integration
// Provides constant path mappings, metadata registries, and helpers for all
// 14 high-detail Aion-2 art asset categories.

import 'package:flutter/material.dart';

/// Categories of Aion-2 Art Assets
enum Aion2AssetCategory {
  portraitsElyos,
  portraitsAsmodian,
  bossPortraits,
  empyreanLords,
  skillsElemental,
  skillsPhysical,
  weapons,
  armor,
  backgroundsElysea,
  backgroundsAsmodae,
  backgroundsDungeons,
  magicCircles,
  flipbooks,
  aion2Ui,
}

/// Extension providing display titles, badges, and icons for categories
extension Aion2AssetCategoryExt on Aion2AssetCategory {
  String get displayName {
    switch (this) {
      case Aion2AssetCategory.portraitsElyos:
        return 'Elyos Daevas';
      case Aion2AssetCategory.portraitsAsmodian:
        return 'Asmodian Daevas';
      case Aion2AssetCategory.bossPortraits:
        return 'World & Raid Bosses';
      case Aion2AssetCategory.empyreanLords:
        return 'Empyrean Lords';
      case Aion2AssetCategory.skillsElemental:
        return 'Elemental Spells';
      case Aion2AssetCategory.skillsPhysical:
        return 'Physical & Divine Skills';
      case Aion2AssetCategory.weapons:
        return 'Mythic Weapons';
      case Aion2AssetCategory.armor:
        return 'Armor & Relics';
      case Aion2AssetCategory.backgroundsElysea:
        return 'Elysea Realms';
      case Aion2AssetCategory.backgroundsAsmodae:
        return 'Asmodae Realms';
      case Aion2AssetCategory.backgroundsDungeons:
        return 'Dungeons & Abyss';
      case Aion2AssetCategory.magicCircles:
        return 'Runic Magic Circles';
      case Aion2AssetCategory.flipbooks:
        return 'VFX Sprite Flipbooks';
      case Aion2AssetCategory.aion2Ui:
        return 'Ornate UI Frames';
    }
  }

  IconData get icon {
    switch (this) {
      case Aion2AssetCategory.portraitsElyos:
        return Icons.wb_sunny_rounded;
      case Aion2AssetCategory.portraitsAsmodian:
        return Icons.nights_stay_rounded;
      case Aion2AssetCategory.bossPortraits:
        return Icons.warning_amber_rounded;
      case Aion2AssetCategory.empyreanLords:
        return Icons.auto_awesome_rounded;
      case Aion2AssetCategory.skillsElemental:
        return Icons.local_fire_department_rounded;
      case Aion2AssetCategory.skillsPhysical:
        return Icons.shield_rounded;
      case Aion2AssetCategory.weapons:
        return Icons.colorize_rounded;
      case Aion2AssetCategory.armor:
        return Icons.security_rounded;
      case Aion2AssetCategory.backgroundsElysea:
        return Icons.landscape_rounded;
      case Aion2AssetCategory.backgroundsAsmodae:
        return Icons.volcano_rounded;
      case Aion2AssetCategory.backgroundsDungeons:
        return Icons.castle_rounded;
      case Aion2AssetCategory.magicCircles:
        return Icons.trip_origin_rounded;
      case Aion2AssetCategory.flipbooks:
        return Icons.animation_rounded;
      case Aion2AssetCategory.aion2Ui:
        return Icons.filter_frames_rounded;
    }
  }
}

/// Metadata model for an individual Aion-2 Art Asset
class Aion2AssetItem {
  final String id;
  final String title;
  final String subtitle;
  final String path;
  final Aion2AssetCategory category;
  final String rarity;
  final String lore;
  final Color themeColor;
  final Map<String, dynamic> metadata;

  const Aion2AssetItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.path,
    required this.category,
    required this.rarity,
    required this.lore,
    this.themeColor = const Color(0xFFC5A059),
    this.metadata = const {},
  });

  bool get isFlipbook => category == Aion2AssetCategory.flipbooks;
  bool get isMagicCircle => category == Aion2AssetCategory.magicCircles;
  bool get isBackground =>
      category == Aion2AssetCategory.backgroundsElysea ||
      category == Aion2AssetCategory.backgroundsAsmodae ||
      category == Aion2AssetCategory.backgroundsDungeons;
}

/// Global repository of constant paths and catalog of Aion-2 Art Assets
abstract final class Aion2ArtAssets {
  // ==========================================
  // 1. Elyos Class Portraits (8 Assets)
  // ==========================================
  static const String portraitElyosAssassin =
      'assets/images/portraits/elyos/elyos_assassin.png';
  static const String portraitElyosChanter =
      'assets/images/portraits/elyos/elyos_chanter.png';
  static const String portraitElyosCleric =
      'assets/images/portraits/elyos/elyos_cleric.png';
  static const String portraitElyosGladiator =
      'assets/images/portraits/elyos/elyos_gladiator.png';
  static const String portraitElyosRanger =
      'assets/images/portraits/elyos/elyos_ranger.png';
  static const String portraitElyosSorcerer =
      'assets/images/portraits/elyos/elyos_sorcerer.png';
  static const String portraitElyosSpiritmaster =
      'assets/images/portraits/elyos/elyos_spiritmaster.png';
  static const String portraitElyosTemplar =
      'assets/images/portraits/elyos/elyos_templar.png';

  // ==========================================
  // 2. Asmodian Class Portraits (8 Assets)
  // ==========================================
  static const String portraitAsmodianAssassin =
      'assets/images/portraits/asmodian/asmodian_assassin.png';
  static const String portraitAsmodianChanter =
      'assets/images/portraits/asmodian/asmodian_chanter.png';
  static const String portraitAsmodianCleric =
      'assets/images/portraits/asmodian/asmodian_cleric.png';
  static const String portraitAsmodianGladiator =
      'assets/images/portraits/asmodian/asmodian_gladiator.png';
  static const String portraitAsmodianRanger =
      'assets/images/portraits/asmodian/asmodian_ranger.png';
  static const String portraitAsmodianSorcerer =
      'assets/images/portraits/asmodian/asmodian_sorcerer.png';
  static const String portraitAsmodianSpiritmaster =
      'assets/images/portraits/asmodian/asmodian_spiritmaster.png';
  static const String portraitAsmodianTemplar =
      'assets/images/portraits/asmodian/asmodian_templar.png';

  // ==========================================
  // 3. World & Raid Boss Portraits (6 Assets)
  // ==========================================
  static const String bossBeritra =
      'assets/images/portraits/bosses/boss_beritra.png';
  static const String bossEreshkigal =
      'assets/images/portraits/bosses/boss_ereshkigal.png';
  static const String bossKromede =
      'assets/images/portraits/bosses/boss_kromede.png';
  static const String bossStormwing =
      'assets/images/portraits/bosses/boss_stormwing.png';
  static const String bossTahabata =
      'assets/images/portraits/bosses/boss_tahabata.png';
  static const String bossTiamat =
      'assets/images/portraits/bosses/boss_tiamat.png';

  // ==========================================
  // 4. Empyrean Lords Portraits (6 Assets)
  // ==========================================
  static const String lordAriel =
      'assets/images/portraits/npcs/lord_ariel.png';
  static const String lordAzphel =
      'assets/images/portraits/npcs/lord_azphel.png';
  static const String lordKaisinel =
      'assets/images/portraits/npcs/lord_kaisinel.png';
  static const String lordMarchutan =
      'assets/images/portraits/npcs/lord_marchutan.png';
  static const String lordNezekan =
      'assets/images/portraits/npcs/lord_nezekan.png';
  static const String lordZikel =
      'assets/images/portraits/npcs/lord_zikel.png';

  // ==========================================
  // 5. Elemental Skill Icons (16 Assets)
  // ==========================================
  static const String skillAbsoluteZero =
      'assets/images/icons/skills_elemental/skill_absolute_zero.png';
  static const String skillAetherTorrent =
      'assets/images/icons/skills_elemental/skill_aether_torrent.png';
  static const String skillArcaneMissiles =
      'assets/images/icons/skills_elemental/skill_arcane_missiles.png';
  static const String skillBlizzardStorm =
      'assets/images/icons/skills_elemental/skill_blizzard_storm.png';
  static const String skillChainLightning =
      'assets/images/icons/skills_elemental/skill_chain_lightning.png';
  static const String skillCycloneVortex =
      'assets/images/icons/skills_elemental/skill_cyclone_vortex.png';
  static const String skillFlameInfusion =
      'assets/images/icons/skills_elemental/skill_flame_infusion.png';
  static const String skillFrostBarrier =
      'assets/images/icons/skills_elemental/skill_frost_barrier.png';
  static const String skillGlacialShard =
      'assets/images/icons/skills_elemental/skill_glacial_shard.png';
  static const String skillInfernoBlast =
      'assets/images/icons/skills_elemental/skill_inferno_blast.png';
  static const String skillMagmaEruption =
      'assets/images/icons/skills_elemental/skill_magma_eruption.png';
  static const String skillMeteorStrike =
      'assets/images/icons/skills_elemental/skill_meteor_strike.png';
  static const String skillPhoenixRebirth =
      'assets/images/icons/skills_elemental/skill_phoenix_rebirth.png';
  static const String skillStoneSkin =
      'assets/images/icons/skills_elemental/skill_stone_skin.png';
  static const String skillThunderClap =
      'assets/images/icons/skills_elemental/skill_thunder_clap.png';
  static const String skillVoidBlackhole =
      'assets/images/icons/skills_elemental/skill_void_blackhole.png';

  // ==========================================
  // 6. Physical & Divine Skill Icons (16 Assets)
  // ==========================================
  static const String skillAnkleSnare =
      'assets/images/icons/skills_physical/skill_ankle_snare.png';
  static const String skillBerserkerRage =
      'assets/images/icons/skills_physical/skill_berserker_rage.png';
  static const String skillBladeFlurry =
      'assets/images/icons/skills_physical/skill_blade_flurry.png';
  static const String skillDivineGrace =
      'assets/images/icons/skills_physical/skill_divine_grace.png';
  static const String skillExecutionersCleave =
      'assets/images/icons/skills_physical/skill_executioners_cleave.png';
  static const String skillHolyAegis =
      'assets/images/icons/skills_physical/skill_holy_aegis.png';
  static const String skillMantraOfWrath =
      'assets/images/icons/skills_physical/skill_mantra_of_wrath.png';
  static const String skillResurrectionLight =
      'assets/images/icons/skills_physical/skill_resurrection_light.png';
  static const String skillRighteousPunishment =
      'assets/images/icons/skills_physical/skill_righteous_punishment.png';
  static const String skillShadowStep =
      'assets/images/icons/skills_physical/skill_shadow_step.png';
  static const String skillShieldBastion =
      'assets/images/icons/skills_physical/skill_shield_bastion.png';
  static const String skillSmiteEvil =
      'assets/images/icons/skills_physical/skill_smite_evil.png';
  static const String skillSmokeBomb =
      'assets/images/icons/skills_physical/skill_smoke_bomb.png';
  static const String skillSniperArrow =
      'assets/images/icons/skills_physical/skill_sniper_arrow.png';
  static const String skillVenomousStrike =
      'assets/images/icons/skills_physical/skill_venomous_strike.png';
  static const String skillWhirlwindSlash =
      'assets/images/icons/skills_physical/skill_whirlwind_slash.png';

  // ==========================================
  // 7. Weapon Icons (16 Assets)
  // ==========================================
  static const String weaponAbyssalOrb =
      'assets/images/icons/weapons/weapon_abyssal_orb.png';
  static const String weaponAetherCannon =
      'assets/images/icons/weapons/weapon_aether_cannon.png';
  static const String weaponArchdaevaStaff =
      'assets/images/icons/weapons/weapon_archdaeva_staff.png';
  static const String weaponBeritraSpellbook =
      'assets/images/icons/weapons/weapon_beritra_spellbook.png';
  static const String weaponDivineMace =
      'assets/images/icons/weapons/weapon_divine_mace.png';
  static const String weaponEmpyreanLongbow =
      'assets/images/icons/weapons/weapon_empyrean_longbow.png';
  static const String weaponFlameChakram =
      'assets/images/icons/weapons/weapon_flame_chakram.png';
  static const String weaponFrostPolearm =
      'assets/images/icons/weapons/weapon_frost_polearm.png';
  static const String weaponKallidaShield =
      'assets/images/icons/weapons/weapon_kallida_shield.png';
  static const String weaponKromedeRapier =
      'assets/images/icons/weapons/weapon_kromede_rapier.png';
  static const String weaponShadowPistol =
      'assets/images/icons/weapons/weapon_shadow_pistol.png';
  static const String weaponStormwingDagger =
      'assets/images/icons/weapons/weapon_stormwing_dagger.png';
  static const String weaponSunBlade =
      'assets/images/icons/weapons/weapon_sun_blade.png';
  static const String weaponTahabataSpear =
      'assets/images/icons/weapons/weapon_tahabata_spear.png';
  static const String weaponTiamatGreatsword =
      'assets/images/icons/weapons/weapon_tiamat_greatsword.png';
  static const String weaponVoidScythe =
      'assets/images/icons/weapons/weapon_void_scythe.png';

  // ==========================================
  // 8. Armor & Accessory Icons (16 Assets)
  // ==========================================
  static const String armorAbyssalDreadHelm =
      'assets/images/icons/armor/armor_abyssal_dread_helm.png';
  static const String armorAbyssEarring =
      'assets/images/icons/armor/armor_abyss_earring.png';
  static const String armorArchdaevaWingsIcon =
      'assets/images/icons/armor/armor_archdaeva_wings_icon.png';
  static const String armorArchmageCelestialRobe =
      'assets/images/icons/armor/armor_archmage_celestial_robe.png';
  static const String armorAsmodianShadowWingsIcon =
      'assets/images/icons/armor/armor_asmodian_shadow_wings_icon.png';
  static const String armorBeltOfValor =
      'assets/images/icons/armor/armor_belt_of_valor.png';
  static const String armorBootsOfWind =
      'assets/images/icons/armor/armor_boots_of_wind.png';
  static const String armorCloakedMantle =
      'assets/images/icons/armor/armor_cloaked_mantle.png';
  static const String armorCrownOfLight =
      'assets/images/icons/armor/armor_crown_of_light.png';
  static const String armorDraconicGauntlets =
      'assets/images/icons/armor/armor_draconic_gauntlets.png';
  static const String armorDragonScalePauldron =
      'assets/images/icons/armor/armor_dragon_scale_pauldron.png';
  static const String armorEmpyreanPlateChest =
      'assets/images/icons/armor/armor_empyrean_plate_chest.png';
  static const String armorGodstoneRing =
      'assets/images/icons/armor/armor_godstone_ring.png';
  static const String armorPaladinGreaves =
      'assets/images/icons/armor/armor_paladin_greaves.png';
  static const String armorShadowLeatherVest =
      'assets/images/icons/armor/armor_shadow_leather_vest.png';
  static const String armorTiamatBloodNecklace =
      'assets/images/icons/armor/armor_tiamat_blood_necklace.png';

  // ==========================================
  // 9. Elysea Realm Backgrounds (4 Assets)
  // ==========================================
  static const String bgElyseaSkybox =
      'assets/images/backgrounds/elysea/bg_elysea_skybox.png';
  static const String bgHeironTemple =
      'assets/images/backgrounds/elysea/bg_heiron_temple.png';
  static const String bgPoetaClovers =
      'assets/images/backgrounds/elysea/bg_poeta_clovers.png';
  static const String bgSanctumCitadel =
      'assets/images/backgrounds/elysea/bg_sanctum_citadel.png';

  // ==========================================
  // 10. Asmodae Realm Backgrounds (4 Assets)
  // ==========================================
  static const String bgAsmodaeSkybox =
      'assets/images/backgrounds/asmodae/bg_asmodae_skybox.png';
  static const String bgBeluslanFrozenSea =
      'assets/images/backgrounds/asmodae/bg_beluslan_frozen_sea.png';
  static const String bgMorheimVolcano =
      'assets/images/backgrounds/asmodae/bg_morheim_volcano.png';
  static const String bgPandaemoniumCapital =
      'assets/images/backgrounds/asmodae/bg_pandaemonium_capital.png';

  // ==========================================
  // 11. Dungeon & Abyss Backgrounds (4 Assets)
  // ==========================================
  static const String bgAbyssCoreWarzone =
      'assets/images/backgrounds/dungeons/bg_abyss_core_warzone.png';
  static const String bgBeshmundirCrypt =
      'assets/images/backgrounds/dungeons/bg_beshmundir_crypt.png';
  static const String bgDarkPoetaBurning =
      'assets/images/backgrounds/dungeons/bg_dark_poeta_burning.png';
  static const String bgEmpyreanArena =
      'assets/images/backgrounds/dungeons/bg_empyrean_arena.png';

  // ==========================================
  // 12. Runic Magic Circles (8 Assets)
  // ==========================================
  static const String circleArchdaevaTranscendence =
      'assets/images/vfx_sprites/magic_circles/magic_circle_archdaeva_transcendence.png';
  static const String circleDivineLight =
      'assets/images/vfx_sprites/magic_circles/magic_circle_divine_light.png';
  static const String circleGlacialFrost =
      'assets/images/vfx_sprites/magic_circles/magic_circle_glacial_frost.png';
  static const String circleInfernoFlame =
      'assets/images/vfx_sprites/magic_circles/magic_circle_inferno_flame.png';
  static const String circleSpiritNature =
      'assets/images/vfx_sprites/magic_circles/magic_circle_spirit_nature.png';
  static const String circleTempestLightning =
      'assets/images/vfx_sprites/magic_circles/magic_circle_tempest_lightning.png';
  static const String circleTiamatBalaurCurse =
      'assets/images/vfx_sprites/magic_circles/magic_circle_tiamat_balaur_curse.png';
  static const String circleVoidAbyss =
      'assets/images/vfx_sprites/magic_circles/magic_circle_void_abyss.png';

  // ==========================================
  // 13. VFX Flipbook Sprite Sheets (4 Assets)
  // ==========================================
  static const String flipbookDarkVoidVortex =
      'assets/images/vfx_sprites/flipbooks/flipbook_dark_void_vortex_4x4.png';
  static const String flipbookFireExplosion =
      'assets/images/vfx_sprites/flipbooks/flipbook_fire_explosion_4x4.png';
  static const String flipbookIceNovaShatter =
      'assets/images/vfx_sprites/flipbooks/flipbook_ice_nova_shatter_4x4.png';
  static const String flipbookLightningImpact =
      'assets/images/vfx_sprites/flipbooks/flipbook_lightning_impact_4x4.png';

  // ==========================================
  // 14. Ornate UI Frames & HUD Elements (10 Assets)
  // ==========================================
  static const String uiActionBarSlot =
      'assets/images/aion2_ui/hud_action_bar_slot.png';
  static const String uiActionBarSlotHighlight =
      'assets/images/aion2_ui/hud_action_bar_slot_highlight.png';
  static const String uiDialogueParchmentBox =
      'assets/images/aion2_ui/hud_dialogue_parchment_box.png';
  static const String uiFlightWingGauge =
      'assets/images/aion2_ui/hud_flight_wing_gauge.png';
  static const String uiHealthOrbFrame =
      'assets/images/aion2_ui/hud_health_orb_frame.png';
  static const String uiManaOrbFrame =
      'assets/images/aion2_ui/hud_mana_orb_frame.png';
  static const String uiMinimapCompassBezel =
      'assets/images/aion2_ui/hud_minimap_compass_bezel.png';
  static const String uiQuestMarkerGold =
      'assets/images/aion2_ui/hud_quest_marker_gold.png';
  static const String uiTargetBossFrame =
      'assets/images/aion2_ui/hud_target_boss_frame.png';
  static const String uiTooltipFrame =
      'assets/images/aion2_ui/hud_tooltip_frame.png';

  // ==========================================
  // Complete Manifest Catalog
  // ==========================================
  static const List<Aion2AssetItem> allAssets = [
    // Elyos
    Aion2AssetItem(
      id: 'elyos_assassin',
      title: 'Elyos Assassin',
      subtitle: 'Shadow Vanguard of Sanctum',
      path: portraitElyosAssassin,
      category: Aion2AssetCategory.portraitsElyos,
      rarity: 'Heroic',
      lore: 'Swift blades blessed by the radiance of Lady Ariel, striking from the light.',
      themeColor: Color(0xFFE2C158),
    ),
    Aion2AssetItem(
      id: 'elyos_chanter',
      title: 'Elyos Chanter',
      subtitle: 'Divine Herald of Mantras',
      path: portraitElyosChanter,
      category: Aion2AssetCategory.portraitsElyos,
      rarity: 'Heroic',
      lore: 'Empowering celestial legions through uplifting battle hymns and divine staves.',
      themeColor: Color(0xFF6CC5E8),
    ),
    Aion2AssetItem(
      id: 'elyos_cleric',
      title: 'Elyos Cleric',
      subtitle: 'High Priest of Restoration',
      path: portraitElyosCleric,
      category: Aion2AssetCategory.portraitsElyos,
      rarity: 'Heroic',
      lore: 'Channels the purest aether to mend mortal wounds and purge dark curses.',
      themeColor: Color(0xFFF0E6D2),
    ),
    Aion2AssetItem(
      id: 'elyos_gladiator',
      title: 'Elyos Gladiator',
      subtitle: 'Aethelgard Warmaster',
      path: portraitElyosGladiator,
      category: Aion2AssetCategory.portraitsElyos,
      rarity: 'Heroic',
      lore: 'Frontline juggernaut wielding heavy polearms and two-handed celestial blades.',
      themeColor: Color(0xFFE67E22),
    ),
    Aion2AssetItem(
      id: 'elyos_ranger',
      title: 'Elyos Ranger',
      subtitle: 'Silver Gale Marksman',
      path: portraitElyosRanger,
      category: Aion2AssetCategory.portraitsElyos,
      rarity: 'Heroic',
      lore: 'Sharp-eyed scouts of the Elysean forests, loosing arrows infused with light.',
      themeColor: Color(0xFF2ECC71),
    ),
    Aion2AssetItem(
      id: 'elyos_sorcerer',
      title: 'Elyos Sorcerer',
      subtitle: 'Archmage of Elemental Flux',
      path: portraitElyosSorcerer,
      category: Aion2AssetCategory.portraitsElyos,
      rarity: 'Heroic',
      lore: 'Bends fire and ice through radiant orbs, devastating opposing warhosts.',
      themeColor: Color(0xFF9B59B6),
    ),
    Aion2AssetItem(
      id: 'elyos_spiritmaster',
      title: 'Elyos Spiritmaster',
      subtitle: 'Caller of Primal Elementals',
      path: portraitElyosSpiritmaster,
      category: Aion2AssetCategory.portraitsElyos,
      rarity: 'Heroic',
      lore: 'Binds the primordial spirits of Fire, Water, Earth, and Wind to their will.',
      themeColor: Color(0xFF1ABC9C),
    ),
    Aion2AssetItem(
      id: 'elyos_templar',
      title: 'Elyos Templar',
      subtitle: 'Aegis of the Sun Throne',
      path: portraitElyosTemplar,
      category: Aion2AssetCategory.portraitsElyos,
      rarity: 'Heroic',
      lore: 'Indomitable shield of Sanctum, commanding holy righteous retribution.',
      themeColor: Color(0xFFF39C12),
    ),

    // Asmodian
    Aion2AssetItem(
      id: 'asmodian_assassin',
      title: 'Asmodian Assassin',
      subtitle: 'Nightstalker of Pandaemonium',
      path: portraitAsmodianAssassin,
      category: Aion2AssetCategory.portraitsAsmodian,
      rarity: 'Heroic',
      lore: 'Hardened beneath frozen skies, lethal shadows striking with crimson claws.',
      themeColor: Color(0xFFC0392B),
    ),
    Aion2AssetItem(
      id: 'asmodian_chanter',
      title: 'Asmodian Chanter',
      subtitle: 'Warcaller of the Northern Winds',
      path: portraitAsmodianChanter,
      category: Aion2AssetCategory.portraitsAsmodian,
      rarity: 'Heroic',
      lore: 'Resonates savage war chants that stir bloodlust across Asmodae.',
      themeColor: Color(0xFF7F8C8D),
    ),
    Aion2AssetItem(
      id: 'asmodian_cleric',
      title: 'Asmodian Cleric',
      subtitle: 'Bloodweaver Hierophant',
      path: portraitAsmodianCleric,
      category: Aion2AssetCategory.portraitsAsmodian,
      rarity: 'Heroic',
      lore: 'Unforgiving healer commanding grim blessings and unyielding life wards.',
      themeColor: Color(0xFF8E44AD),
    ),
    Aion2AssetItem(
      id: 'asmodian_gladiator',
      title: 'Asmodian Gladiator',
      subtitle: 'Berserker of Morheim',
      path: portraitAsmodianGladiator,
      category: Aion2AssetCategory.portraitsAsmodian,
      rarity: 'Heroic',
      lore: 'Fierce dreadnought covered in dark iron plate and spiked battle regalia.',
      themeColor: Color(0xFFD35400),
    ),
    Aion2AssetItem(
      id: 'asmodian_ranger',
      title: 'Asmodian Ranger',
      subtitle: 'Shadowstrider of Beluslan',
      path: portraitAsmodianRanger,
      category: Aion2AssetCategory.portraitsAsmodian,
      rarity: 'Heroic',
      lore: 'Relentless tracker surviving the coldest blizzards to hunt enemy scouts.',
      themeColor: Color(0xFF16A085),
    ),
    Aion2AssetItem(
      id: 'asmodian_sorcerer',
      title: 'Asmodian Sorcerer',
      subtitle: 'Void Evoker of the Abyss',
      path: portraitAsmodianSorcerer,
      category: Aion2AssetCategory.portraitsAsmodian,
      rarity: 'Heroic',
      lore: 'Taps dark abyssal currents to unleash calamitous tempest destruction.',
      themeColor: Color(0xFF4A148C),
    ),
    Aion2AssetItem(
      id: 'asmodian_spiritmaster',
      title: 'Asmodian Spiritmaster',
      subtitle: 'Dread Summoner of Pandemonium',
      path: portraitAsmodianSpiritmaster,
      category: Aion2AssetCategory.portraitsAsmodian,
      rarity: 'Heroic',
      lore: 'Extracts primordial energy to summon corrupted nightmare elementals.',
      themeColor: Color(0xFF00695C),
    ),
    Aion2AssetItem(
      id: 'asmodian_templar',
      title: 'Asmodian Templar',
      subtitle: 'Iron Fortress of Lord Azphel',
      path: portraitAsmodianTemplar,
      category: Aion2AssetCategory.portraitsAsmodian,
      rarity: 'Heroic',
      lore: 'Gothic black-iron sentinel whose shield withstands the fury of Dragon Lords.',
      themeColor: Color(0xFF34495E),
    ),

    // Bosses
    Aion2AssetItem(
      id: 'boss_beritra',
      title: 'Dragon Lord Beritra',
      subtitle: 'Lord of Darkness & Deception',
      path: bossBeritra,
      category: Aion2AssetCategory.bossPortraits,
      rarity: 'Mythic',
      lore: 'The scheming fourth Dragon Lord whose dark machinery bends time and void.',
      themeColor: Color(0xFF512DA8),
    ),
    Aion2AssetItem(
      id: 'boss_ereshkigal',
      title: 'Dragon Lord Ereshkigal',
      subtitle: 'Lady of Cold Ice & Death',
      path: bossEreshkigal,
      category: Aion2AssetCategory.bossPortraits,
      rarity: 'Mythic',
      lore: 'Ancient Dragon Lord encased in absolute zero rime, freezing mortal souls.',
      themeColor: Color(0xFF0288D1),
    ),
    Aion2AssetItem(
      id: 'boss_kromede',
      title: 'Kromede the Corrupt',
      subtitle: 'Tragic Matron of Fire Temple',
      path: bossKromede,
      category: Aion2AssetCategory.bossPortraits,
      rarity: 'Eternal',
      lore: 'Betrayed Daeva driven mad by vengeance, wielding the weeping Judge blades.',
      themeColor: Color(0xFFD84315),
    ),
    Aion2AssetItem(
      id: 'boss_stormwing',
      title: 'Stormwing',
      subtitle: 'Emperor of the Beshmundir Sky',
      path: bossStormwing,
      category: Aion2AssetCategory.bossPortraits,
      rarity: 'Mythic',
      lore: 'Titanic dragon imprisoned within the Storm Prison, master of gale hurricanes.',
      themeColor: Color(0xFF00ACC1),
    ),
    Aion2AssetItem(
      id: 'boss_tahabata',
      title: 'Tahabata Pyrelord',
      subtitle: 'Conqueror of Dark Poeta',
      path: bossTahabata,
      category: Aion2AssetCategory.bossPortraits,
      rarity: 'Mythic',
      lore: 'The volcanic Balaur general bathed in hellfire, incinerator of alternate timelines.',
      themeColor: Color(0xFFBF360C),
    ),
    Aion2AssetItem(
      id: 'boss_tiamat',
      title: 'Dragon Lord Tiamat',
      subtitle: 'Mistress of Wrath & Ruin',
      path: bossTiamat,
      category: Aion2AssetCategory.bossPortraits,
      rarity: 'Mythic',
      lore: 'The fifth Dragon Lord commanding earth tremors and crimson blood storms.',
      themeColor: Color(0xFFB71C1C),
    ),

    // Empyrean Lords
    Aion2AssetItem(
      id: 'lord_ariel',
      title: 'Lady Ariel',
      subtitle: 'Seraphim of Light',
      path: lordAriel,
      category: Aion2AssetCategory.empyreanLords,
      rarity: 'Divine',
      lore: 'Guardian deity of the Elyos and master of the celestial Tower of Eternity.',
      themeColor: Color(0xFFFFD54F),
    ),
    Aion2AssetItem(
      id: 'lord_azphel',
      title: 'Lord Azphel',
      subtitle: 'Shadow of the Eclipse',
      path: lordAzphel,
      category: Aion2AssetCategory.empyreanLords,
      rarity: 'Divine',
      lore: 'Unyielding protector of the Asmodian people, cloaked in impenetrable midnight.',
      themeColor: Color(0xFF455A64),
    ),
    Aion2AssetItem(
      id: 'lord_kaisinel',
      title: 'Lord Kaisinel',
      subtitle: 'Lord of Illusion',
      path: lordKaisinel,
      category: Aion2AssetCategory.empyreanLords,
      rarity: 'Divine',
      lore: 'Mysterious ruler of the Elyos Cloister, weaver of arcane mirages.',
      themeColor: Color(0xFFBA68C8),
    ),
    Aion2AssetItem(
      id: 'lord_marchutan',
      title: 'Lord Marchutan',
      subtitle: 'Lord of Fate',
      path: lordMarchutan,
      category: Aion2AssetCategory.empyreanLords,
      rarity: 'Divine',
      lore: 'Stoic commander presiding over the grim destinies of mortal warriors.',
      themeColor: Color(0xFF37474F),
    ),
    Aion2AssetItem(
      id: 'lord_nezekan',
      title: 'Lord Nezekan',
      subtitle: 'Lord of Justice & Protection',
      path: lordNezekan,
      category: Aion2AssetCategory.empyreanLords,
      rarity: 'Divine',
      lore: 'The unbreakable shield among the Seraphim, defender of righteous truth.',
      themeColor: Color(0xFFFFB300),
    ),
    Aion2AssetItem(
      id: 'lord_zikel',
      title: 'Lord Zikel',
      subtitle: 'Lord of Destruction',
      path: lordZikel,
      category: Aion2AssetCategory.empyreanLords,
      rarity: 'Divine',
      lore: 'Fiercest champion of Asmodae whose sword cleaved the Balaur dreadnoughts.',
      themeColor: Color(0xFFC62828),
    ),

    // Elemental Skills
    Aion2AssetItem(
      id: 'skill_absolute_zero',
      title: 'Absolute Zero',
      subtitle: 'Frost Spell — Tier VI',
      path: skillAbsoluteZero,
      category: Aion2AssetCategory.skillsElemental,
      rarity: 'Eternal',
      lore: 'Flash-freezes ambient aether to immobilize targets in unbreakable permafrost.',
      themeColor: Color(0xFF4FC3F7),
    ),
    Aion2AssetItem(
      id: 'skill_aether_torrent',
      title: 'Aether Torrent',
      subtitle: 'Arcane Spell — Tier V',
      path: skillAetherTorrent,
      category: Aion2AssetCategory.skillsElemental,
      rarity: 'Heroic',
      lore: 'Channels a roaring spiral of pure aetheric energy through the sky.',
      themeColor: Color(0xFF81D4FA),
    ),
    Aion2AssetItem(
      id: 'skill_arcane_missiles',
      title: 'Arcane Missiles',
      subtitle: 'Arcane Spell — Tier III',
      path: skillArcaneMissiles,
      category: Aion2AssetCategory.skillsElemental,
      rarity: 'Heroic',
      lore: 'Launches multiple homing crystalline darts that pierce magical barriers.',
      themeColor: Color(0xFFB388FF),
    ),
    Aion2AssetItem(
      id: 'skill_blizzard_storm',
      title: 'Blizzard Storm',
      subtitle: 'Frost Spell — Tier V',
      path: skillBlizzardStorm,
      category: Aion2AssetCategory.skillsElemental,
      rarity: 'Heroic',
      lore: 'Conjures a tempest of razor-sharp hail over a wide battlefield zone.',
      themeColor: Color(0xFF29B6F6),
    ),
    Aion2AssetItem(
      id: 'skill_chain_lightning',
      title: 'Chain Lightning',
      subtitle: 'Tempest Spell — Tier IV',
      path: skillChainLightning,
      category: Aion2AssetCategory.skillsElemental,
      rarity: 'Heroic',
      lore: 'Discharges high-voltage electrical arcs leaping between enemy combatants.',
      themeColor: Color(0xFFFFEB3B),
    ),
    Aion2AssetItem(
      id: 'skill_cyclone_vortex',
      title: 'Cyclone Vortex',
      subtitle: 'Wind Spell — Tier IV',
      path: skillCycloneVortex,
      category: Aion2AssetCategory.skillsElemental,
      rarity: 'Heroic',
      lore: 'Spins a localized hurricane vortex that lifts targets airborne.',
      themeColor: Color(0xFF80CBC4),
    ),
    Aion2AssetItem(
      id: 'skill_flame_infusion',
      title: 'Flame Infusion',
      subtitle: 'Fire Spell — Tier III',
      path: skillFlameInfusion,
      category: Aion2AssetCategory.skillsElemental,
      rarity: 'Heroic',
      lore: 'Coats weapon blades in searing draconic fire, adding burning damage.',
      themeColor: Color(0xFFFF7043),
    ),
    Aion2AssetItem(
      id: 'skill_frost_barrier',
      title: 'Frost Barrier',
      subtitle: 'Frost Ward — Tier IV',
      path: skillFrostBarrier,
      category: Aion2AssetCategory.skillsElemental,
      rarity: 'Heroic',
      lore: 'Encases the caster in crystalline ice armor that absorbs physical impact.',
      themeColor: Color(0xFF80DEEA),
    ),
    Aion2AssetItem(
      id: 'skill_glacial_shard',
      title: 'Glacial Shard',
      subtitle: 'Frost Spell — Tier V',
      path: skillGlacialShard,
      category: Aion2AssetCategory.skillsElemental,
      rarity: 'Eternal',
      lore: 'Hurls an enormous spear of dense glacier ice with massive critical impact.',
      themeColor: Color(0xFF00E5FF),
    ),
    Aion2AssetItem(
      id: 'skill_inferno_blast',
      title: 'Inferno Blast',
      subtitle: 'Fire Spell — Tier IV',
      path: skillInfernoBlast,
      category: Aion2AssetCategory.skillsElemental,
      rarity: 'Heroic',
      lore: 'Detonates a shockwave of concentrated flame at target location.',
      themeColor: Color(0xFFFF5722),
    ),
    Aion2AssetItem(
      id: 'skill_magma_eruption',
      title: 'Magma Eruption',
      subtitle: 'Earth/Fire Spell — Tier V',
      path: skillMagmaEruption,
      category: Aion2AssetCategory.skillsElemental,
      rarity: 'Eternal',
      lore: 'Ruptures the earth beneath enemies, spewing molten basalt and slag.',
      themeColor: Color(0xFFE64A19),
    ),
    Aion2AssetItem(
      id: 'skill_meteor_strike',
      title: 'Meteor Strike',
      subtitle: 'Fire Spell — Tier VI',
      path: skillMeteorStrike,
      category: Aion2AssetCategory.skillsElemental,
      rarity: 'Mythic',
      lore: 'Pulls a burning celestial meteor from orbit to obliterate all resistance.',
      themeColor: Color(0xFFD84315),
    ),
    Aion2AssetItem(
      id: 'skill_phoenix_rebirth',
      title: 'Phoenix Rebirth',
      subtitle: 'Divine Flame Spell — Tier VI',
      path: skillPhoenixRebirth,
      category: Aion2AssetCategory.skillsElemental,
      rarity: 'Mythic',
      lore: 'Surrounds the fallen Daeva with fiery plumage to resurrect with full vitality.',
      themeColor: Color(0xFFFF9800),
    ),
    Aion2AssetItem(
      id: 'skill_stone_skin',
      title: 'Stone Skin',
      subtitle: 'Earth Ward — Tier III',
      path: skillStoneSkin,
      category: Aion2AssetCategory.skillsElemental,
      rarity: 'Heroic',
      lore: 'Hardens skin into solid granite to negate incoming physical attacks.',
      themeColor: Color(0xFF8D6E63),
    ),
    Aion2AssetItem(
      id: 'skill_thunder_clap',
      title: 'Thunder Clap',
      subtitle: 'Tempest Spell — Tier IV',
      path: skillThunderClap,
      category: Aion2AssetCategory.skillsElemental,
      rarity: 'Heroic',
      lore: 'Claps hands together creating a concussive shockwave that silences casters.',
      themeColor: Color(0xFFFFD600),
    ),
    Aion2AssetItem(
      id: 'skill_void_blackhole',
      title: 'Void Blackhole',
      subtitle: 'Dark Aether Spell — Tier VI',
      path: skillVoidBlackhole,
      category: Aion2AssetCategory.skillsElemental,
      rarity: 'Mythic',
      lore: 'Opens a gravitational singularity that pulls in all nearby entities.',
      themeColor: Color(0xFF7E57C2),
    ),

    // Physical & Divine Skills
    Aion2AssetItem(
      id: 'skill_ankle_snare',
      title: 'Ankle Snare',
      subtitle: 'Ranger Trap — Tier II',
      path: skillAnkleSnare,
      category: Aion2AssetCategory.skillsPhysical,
      rarity: 'Heroic',
      lore: 'Springs a barbed steel trap that roots fleeing adversaries in place.',
      themeColor: Color(0xFF8D6E63),
    ),
    Aion2AssetItem(
      id: 'skill_berserker_rage',
      title: 'Berserker Rage',
      subtitle: 'Gladiator Stance — Tier V',
      path: skillBerserkerRage,
      category: Aion2AssetCategory.skillsPhysical,
      rarity: 'Eternal',
      lore: 'Sacrifices defensive caution for unparalleled physical destruction.',
      themeColor: Color(0xFFC62828),
    ),
    Aion2AssetItem(
      id: 'skill_blade_flurry',
      title: 'Blade Flurry',
      subtitle: 'Assassin Strike — Tier IV',
      path: skillBladeFlurry,
      category: Aion2AssetCategory.skillsPhysical,
      rarity: 'Heroic',
      lore: 'Executes rapid-fire dual strikes that carve through enemy armor seams.',
      themeColor: Color(0xFFE53935),
    ),
    Aion2AssetItem(
      id: 'skill_divine_grace',
      title: 'Divine Grace',
      subtitle: 'Cleric Aura — Tier V',
      path: skillDivineGrace,
      category: Aion2AssetCategory.skillsPhysical,
      rarity: 'Eternal',
      lore: 'Befalls the party with sacred light, accelerating health recovery.',
      themeColor: Color(0xFFFFF176),
    ),
    Aion2AssetItem(
      id: 'skill_executioners_cleave',
      title: 'Executioner\'s Cleave',
      subtitle: 'Gladiator Finisher — Tier VI',
      path: skillExecutionersCleave,
      category: Aion2AssetCategory.skillsPhysical,
      rarity: 'Mythic',
      lore: 'Brings down a monstrous overhead strike that decapitates low-health foes.',
      themeColor: Color(0xFFB71C1C),
    ),
    Aion2AssetItem(
      id: 'skill_holy_aegis',
      title: 'Holy Aegis',
      subtitle: 'Templar Bastion — Tier VI',
      path: skillHolyAegis,
      category: Aion2AssetCategory.skillsPhysical,
      rarity: 'Mythic',
      lore: 'Projects an impenetrable radiant shield that protects the entire squad.',
      themeColor: Color(0xFFFFD54F),
    ),
    Aion2AssetItem(
      id: 'skill_mantra_of_wrath',
      title: 'Mantra of Wrath',
      subtitle: 'Chanter Chant — Tier IV',
      path: skillMantraOfWrath,
      category: Aion2AssetCategory.skillsPhysical,
      rarity: 'Heroic',
      lore: 'Continuous battlefield chant boosting physical attack power and critical rate.',
      themeColor: Color(0xFFFB8C00),
    ),
    Aion2AssetItem(
      id: 'skill_resurrection_light',
      title: 'Resurrection Light',
      subtitle: 'Cleric Miracle — Tier V',
      path: skillResurrectionLight,
      category: Aion2AssetCategory.skillsPhysical,
      rarity: 'Eternal',
      lore: 'Calls upon the Tower of Eternity to restore life to a fallen comrade.',
      themeColor: Color(0xFFFFF9C4),
    ),
    Aion2AssetItem(
      id: 'skill_righteous_punishment',
      title: 'Righteous Punishment',
      subtitle: 'Templar Strike — Tier V',
      path: skillRighteousPunishment,
      category: Aion2AssetCategory.skillsPhysical,
      rarity: 'Eternal',
      lore: 'Smites the foe with holy wrath, transferring damage into divine shielding.',
      themeColor: Color(0xFFFFC107),
    ),
    Aion2AssetItem(
      id: 'skill_shadow_step',
      title: 'Shadow Step',
      subtitle: 'Assassin Mobility — Tier IV',
      path: skillShadowStep,
      category: Aion2AssetCategory.skillsPhysical,
      rarity: 'Heroic',
      lore: 'Teleports behind the target instantly to deliver a devastating backstab.',
      themeColor: Color(0xFF5E35B1),
    ),
    Aion2AssetItem(
      id: 'skill_shield_bastion',
      title: 'Shield Bastion',
      subtitle: 'Templar Defensive — Tier IV',
      path: skillShieldBastion,
      category: Aion2AssetCategory.skillsPhysical,
      rarity: 'Heroic',
      lore: 'Plants the tower shield deep into the earth, blocking 80% incoming damage.',
      themeColor: Color(0xFF607D8B),
    ),
    Aion2AssetItem(
      id: 'skill_smite_evil',
      title: 'Smite Evil',
      subtitle: 'Cleric Offensive — Tier III',
      path: skillSmiteEvil,
      category: Aion2AssetCategory.skillsPhysical,
      rarity: 'Heroic',
      lore: 'Channels pure holiness into mace or staff to blind and daze unholy enemies.',
      themeColor: Color(0xFFFFEE58),
    ),
    Aion2AssetItem(
      id: 'skill_smoke_bomb',
      title: 'Smoke Bomb',
      subtitle: 'Assassin Escape — Tier III',
      path: skillSmokeBomb,
      category: Aion2AssetCategory.skillsPhysical,
      rarity: 'Heroic',
      lore: 'Detonates an alchemical cloud, breaking targeting and entering stealth.',
      themeColor: Color(0xFF78909C),
    ),
    Aion2AssetItem(
      id: 'skill_sniper_arrow',
      title: 'Sniper Arrow',
      subtitle: 'Ranger Shot — Tier V',
      path: skillSniperArrow,
      category: Aion2AssetCategory.skillsPhysical,
      rarity: 'Eternal',
      lore: 'Takes steady aim for massive single-target armor-piercing damage.',
      themeColor: Color(0xFF43A047),
    ),
    Aion2AssetItem(
      id: 'skill_venomous_strike',
      title: 'Venomous Strike',
      subtitle: 'Assassin Poison — Tier III',
      path: skillVenomousStrike,
      category: Aion2AssetCategory.skillsPhysical,
      rarity: 'Heroic',
      lore: 'Applies Balaur viper poison that corrodes health over time.',
      themeColor: Color(0xFF7CB342),
    ),
    Aion2AssetItem(
      id: 'skill_whirlwind_slash',
      title: 'Whirlwind Slash',
      subtitle: 'Gladiator AoE — Tier IV',
      path: skillWhirlwindSlash,
      category: Aion2AssetCategory.skillsPhysical,
      rarity: 'Heroic',
      lore: 'Spins weapon 360 degrees to cleave through surrounding enemies.',
      themeColor: Color(0xFFF4511E),
    ),

    // Weapons
    Aion2AssetItem(
      id: 'weapon_abyssal_orb',
      title: 'Abyssal Void Orb',
      subtitle: 'Mythic Sorcerer Focus',
      path: weaponAbyssalOrb,
      category: Aion2AssetCategory.weapons,
      rarity: 'Mythic',
      lore: 'Forged in the vortex of the Core, pulsing with endless void energies.',
      themeColor: Color(0xFF673AB7),
    ),
    Aion2AssetItem(
      id: 'weapon_aether_cannon',
      title: 'Aether Cannon Mk.IV',
      subtitle: 'Mechanist Siege Engine',
      path: weaponAetherCannon,
      category: Aion2AssetCategory.weapons,
      rarity: 'Eternal',
      lore: 'Dwarven clockwork firepower channeling pressurized raw aether cells.',
      themeColor: Color(0xFFFF9800),
    ),
    Aion2AssetItem(
      id: 'weapon_archdaeva_staff',
      title: 'Archdaeva Staff of Eternity',
      subtitle: 'Transcendent Pole Focus',
      path: weaponArchdaevaStaff,
      category: Aion2AssetCategory.weapons,
      rarity: 'Mythic',
      lore: 'Staff carried by the first ascended Daevas before the Great Cataclysm.',
      themeColor: Color(0xFF4DD0E1),
    ),
    Aion2AssetItem(
      id: 'weapon_beritra_spellbook',
      title: 'Beritra\'s Tome of Decay',
      subtitle: 'Draconic Spellbook',
      path: weaponBeritraSpellbook,
      category: Aion2AssetCategory.weapons,
      rarity: 'Mythic',
      lore: 'Etched with dragon runes of destruction that corrupt spells cast through it.',
      themeColor: Color(0xFF512DA8),
    ),
    Aion2AssetItem(
      id: 'weapon_divine_mace',
      title: 'Nezekan\'s Righteous Mace',
      subtitle: 'Holy One-Handed Bludgeon',
      path: weaponDivineMace,
      category: Aion2AssetCategory.weapons,
      rarity: 'Mythic',
      lore: 'Gleams with the righteous blessing of Lord Nezekan himself.',
      themeColor: Color(0xFFFFD54F),
    ),
    Aion2AssetItem(
      id: 'weapon_empyrean_longbow',
      title: 'Empyrean Phoenix Longbow',
      subtitle: 'Mythic Composite Bow',
      path: weaponEmpyreanLongbow,
      category: Aion2AssetCategory.weapons,
      rarity: 'Mythic',
      lore: 'Carved from goldwood and strung with phoenix sinew, shooting sun arrows.',
      themeColor: Color(0xFFFF7043),
    ),
    Aion2AssetItem(
      id: 'weapon_flame_chakram',
      title: 'Tahabata Flame Chakram',
      subtitle: 'Pyroclastic Circular Blade',
      path: weaponFlameChakram,
      category: Aion2AssetCategory.weapons,
      rarity: 'Mythic',
      lore: 'Forged within the heart of Dark Poeta\'s caldera, perpetually igniting.',
      themeColor: Color(0xFFBF360C),
    ),
    Aion2AssetItem(
      id: 'weapon_frost_polearm',
      title: 'Ereshkigal Frost Polearm',
      subtitle: 'Glacial Glaive of Ruin',
      path: weaponFrostPolearm,
      category: Aion2AssetCategory.weapons,
      rarity: 'Mythic',
      lore: 'Chilled blade that shatters enemy armor on contact like brittle glass.',
      themeColor: Color(0xFF00E5FF),
    ),
    Aion2AssetItem(
      id: 'weapon_kallida_shield',
      title: 'Kallida Dragon Tower Shield',
      subtitle: 'Draconic Great Shield',
      path: weaponKallidaShield,
      category: Aion2AssetCategory.weapons,
      rarity: 'Eternal',
      lore: 'Reinforced with black dragon scales, deflecting ballista bolts with ease.',
      themeColor: Color(0xFF37474F),
    ),
    Aion2AssetItem(
      id: 'weapon_kromede_rapier',
      title: 'Kromede\'s Tearful Rapier',
      subtitle: 'Corrupted Fencing Blade',
      path: weaponKromedeRapier,
      category: Aion2AssetCategory.weapons,
      rarity: 'Eternal',
      lore: 'A slender rapier imbued with sorrow, dealing devastating critical thrusts.',
      themeColor: Color(0xFFC2185B),
    ),
    Aion2AssetItem(
      id: 'weapon_shadow_pistol',
      title: 'Shadow Wing Revolver',
      subtitle: 'Aether Pistol',
      path: weaponShadowPistol,
      category: Aion2AssetCategory.weapons,
      rarity: 'Heroic',
      lore: 'Fires rapid bursts of aetheric cartridges with precision and speed.',
      themeColor: Color(0xFF455A64),
    ),
    Aion2AssetItem(
      id: 'weapon_stormwing_dagger',
      title: 'Stormwing Gale Dagger',
      subtitle: 'Tempest Main-Gauche',
      path: weaponStormwingDagger,
      category: Aion2AssetCategory.weapons,
      rarity: 'Mythic',
      lore: 'Whispers with lightning storms, increasing attack speed by 25%.',
      themeColor: Color(0xFF00ACC1),
    ),
    Aion2AssetItem(
      id: 'weapon_sun_blade',
      title: 'Sanctum Sun Blade',
      subtitle: 'Solar Broadsword',
      path: weaponSunBlade,
      category: Aion2AssetCategory.weapons,
      rarity: 'Eternal',
      lore: 'Blessed by Lady Ariel, searing unholy creatures with each slash.',
      themeColor: Color(0xFFFFB300),
    ),
    Aion2AssetItem(
      id: 'weapon_tahabata_spear',
      title: 'Tahabata\'s Pyre Spear',
      subtitle: 'Infernal Two-Handed Spear',
      path: weaponTahabataSpear,
      category: Aion2AssetCategory.weapons,
      rarity: 'Mythic',
      lore: 'The legendary weapon of Tahabata, coveted by every gladiator in Atreia.',
      themeColor: Color(0xFFE65100),
    ),
    Aion2AssetItem(
      id: 'weapon_tiamat_greatsword',
      title: 'Tiamat\'s Dragon Greatsword',
      subtitle: 'Wrathful Colossus Blade',
      path: weaponTiamatGreatsword,
      category: Aion2AssetCategory.weapons,
      rarity: 'Mythic',
      lore: 'Massive obsidian blade imbued with the draconic wrath of Lady Tiamat.',
      themeColor: Color(0xFFB71C1C),
    ),
    Aion2AssetItem(
      id: 'weapon_void_scythe',
      title: 'Abyssal Void Reaper',
      subtitle: 'Harvest Scythe of the Abyss',
      path: weaponVoidScythe,
      category: Aion2AssetCategory.weapons,
      rarity: 'Eternal',
      lore: 'Reaps souls across the fractured dimensional fractures of the Core.',
      themeColor: Color(0xFF4A148C),
    ),

    // Armor & Accessories
    Aion2AssetItem(
      id: 'armor_abyssal_dread_helm',
      title: 'Abyssal Dread Helm',
      subtitle: 'Gothic Horned Helmet',
      path: armorAbyssalDreadHelm,
      category: Aion2AssetCategory.armor,
      rarity: 'Eternal',
      lore: 'Imbued with the grim determination of Asmodian frontline commanders.',
      themeColor: Color(0xFF263238),
    ),
    Aion2AssetItem(
      id: 'armor_abyss_earring',
      title: 'Abyss Core Earring',
      subtitle: 'Aether Resonance Earring',
      path: armorAbyssEarring,
      category: Aion2AssetCategory.armor,
      rarity: 'Heroic',
      lore: 'Increases flight speed and PvP defense across contested zones.',
      themeColor: Color(0xFF00BCD4),
    ),
    Aion2AssetItem(
      id: 'armor_archdaeva_wings_icon',
      title: 'Archdaeva Radiant Wings',
      subtitle: 'Divine Flight Relic',
      path: armorArchdaevaWingsIcon,
      category: Aion2AssetCategory.armor,
      rarity: 'Mythic',
      lore: 'Shining white feathered wings bathed in gold aether, granting eternal flight.',
      themeColor: Color(0xFFFFD54F),
    ),
    Aion2AssetItem(
      id: 'armor_archmage_celestial_robe',
      title: 'Archmage Celestial Robe',
      subtitle: 'Silk Vestment of Sanctum',
      path: armorArchmageCelestialRobe,
      category: Aion2AssetCategory.armor,
      rarity: 'Mythic',
      lore: 'Woven from aether silk, granting maximum magical boost and mana recovery.',
      themeColor: Color(0xFF8E24AA),
    ),
    Aion2AssetItem(
      id: 'armor_asmodian_shadow_wings_icon',
      title: 'Asmodian Shadow Wings',
      subtitle: 'Abyssal Wing Feathers',
      path: armorAsmodianShadowWingsIcon,
      category: Aion2AssetCategory.armor,
      rarity: 'Mythic',
      lore: 'Obsidian plumage with crimson luminescence, soaring through frozen nights.',
      themeColor: Color(0xFFC2185B),
    ),
    Aion2AssetItem(
      id: 'armor_belt_of_valor',
      title: 'Belt of Unyielding Valor',
      subtitle: 'Heavy Plated War Belt',
      path: armorBeltOfValor,
      category: Aion2AssetCategory.armor,
      rarity: 'Heroic',
      lore: 'Reinforced waist guard adorned with lion emblems of the Seraphim.',
      themeColor: Color(0xFFFFA000),
    ),
    Aion2AssetItem(
      id: 'armor_boots_of_wind',
      title: 'Boots of the North Wind',
      subtitle: 'Enchanted Leather Greaves',
      path: armorBootsOfWind,
      category: Aion2AssetCategory.armor,
      rarity: 'Heroic',
      lore: 'Allows the wearer to glide seamlessly across deep snow and uneven terrain.',
      themeColor: Color(0xFF4DB6AC),
    ),
    Aion2AssetItem(
      id: 'armor_cloaked_mantle',
      title: 'Shadow Cloaked Mantle',
      subtitle: 'Assassin Shoulder Guard',
      path: armorCloakedMantle,
      category: Aion2AssetCategory.armor,
      rarity: 'Heroic',
      lore: 'Muffles sound and blends the silhouette into dim shadows.',
      themeColor: Color(0xFF37474F),
    ),
    Aion2AssetItem(
      id: 'armor_crown_of_light',
      title: 'Crown of Celestial Light',
      subtitle: 'Empyrean Diadem',
      path: armorCrownOfLight,
      category: Aion2AssetCategory.armor,
      rarity: 'Mythic',
      lore: 'Resting on the brow of high priests, radiating divine protection.',
      themeColor: Color(0xFFFFD700),
    ),
    Aion2AssetItem(
      id: 'armor_draconic_gauntlets',
      title: 'Draconic Scale Gauntlets',
      subtitle: 'Balaur Heavy Vambraces',
      path: armorDraconicGauntlets,
      category: Aion2AssetCategory.armor,
      rarity: 'Eternal',
      lore: 'Forged from molted dragon scales, impenetrable to bludgeoning.',
      themeColor: Color(0xFFE64A19),
    ),
    Aion2AssetItem(
      id: 'armor_dragon_scale_pauldron',
      title: 'Dragon Scale Pauldron',
      subtitle: 'Spiked Shoulder Plate',
      path: armorDragonScalePauldron,
      category: Aion2AssetCategory.armor,
      rarity: 'Eternal',
      lore: 'Decorated with obsidian dragon horns and runic warding seals.',
      themeColor: Color(0xFFD84315),
    ),
    Aion2AssetItem(
      id: 'armor_empyrean_plate_chest',
      title: 'Empyrean Cuirass of Glory',
      subtitle: 'Mythic Plate Chestpiece',
      path: armorEmpyreanPlateChest,
      category: Aion2AssetCategory.armor,
      rarity: 'Mythic',
      lore: 'Golden breastplate worn by high paladins defending the Tower of Eternity.',
      themeColor: Color(0xFFFFC107),
    ),
    Aion2AssetItem(
      id: 'armor_godstone_ring',
      title: 'Ring of the Ancient Godstone',
      subtitle: 'Godstone Imbued Band',
      path: armorGodstoneRing,
      category: Aion2AssetCategory.armor,
      rarity: 'Eternal',
      lore: 'Sockets a rare godstone, granting 2% chance on hit to trigger silence.',
      themeColor: Color(0xFF00E676),
    ),
    Aion2AssetItem(
      id: 'armor_paladin_greaves',
      title: 'Paladin Legguards of Nezekan',
      subtitle: 'Heavy Plate Greaves',
      path: armorPaladinGreaves,
      category: Aion2AssetCategory.armor,
      rarity: 'Eternal',
      lore: 'Solid aurium plates that ground the warrior against knockback effects.',
      themeColor: Color(0xFFFFB300),
    ),
    Aion2AssetItem(
      id: 'armor_shadow_leather_vest',
      title: 'Shadow Leather Vest',
      subtitle: 'Reinforced Scout Jerkin',
      path: armorShadowLeatherVest,
      category: Aion2AssetCategory.armor,
      rarity: 'Heroic',
      lore: 'Supple dragon leather providing maximum agility without sacrificing armor.',
      themeColor: Color(0xFF5D4037),
    ),
    Aion2AssetItem(
      id: 'armor_tiamat_blood_necklace',
      title: 'Tiamat\'s Blood Amber Necklace',
      subtitle: 'Draconic Amulet',
      path: armorTiamatBloodNecklace,
      category: Aion2AssetCategory.armor,
      rarity: 'Mythic',
      lore: 'Contains a single drop of petrified Dragon Lord blood, surging with wrath.',
      themeColor: Color(0xFFB71C1C),
    ),

    // Elysea Backgrounds
    Aion2AssetItem(
      id: 'bg_elysea_skybox',
      title: 'Elysea Skybox & Floating Islands',
      subtitle: 'Panoramic Atreian Sky',
      path: bgElyseaSkybox,
      category: Aion2AssetCategory.backgroundsElysea,
      rarity: 'Heroic',
      lore: 'Sunlit clouds drifting past floating marble crags anchored by aether pillars.',
      themeColor: Color(0xFF64B5F6),
    ),
    Aion2AssetItem(
      id: 'bg_heiron_temple',
      title: 'Heiron Ancient Temple',
      subtitle: 'Overgrown Sanctuary',
      path: bgHeironTemple,
      category: Aion2AssetCategory.backgroundsElysea,
      rarity: 'Heroic',
      lore: 'Ancient ruins veiled in morning mist, home to ancient elemental mysteries.',
      themeColor: Color(0xFF81C784),
    ),
    Aion2AssetItem(
      id: 'bg_poeta_clovers',
      title: 'Poeta Clover Fields',
      subtitle: 'Starting Valley of Light',
      path: bgPoetaClovers,
      category: Aion2AssetCategory.backgroundsElysea,
      rarity: 'Heroic',
      lore: 'Tranquil emerald meadows where aspiring Elyos awaken to their wings.',
      themeColor: Color(0xFFAED581),
    ),
    Aion2AssetItem(
      id: 'bg_sanctum_citadel',
      title: 'Sanctum Capitol Citadel',
      subtitle: 'Golden City of the Seraphim',
      path: bgSanctumCitadel,
      category: Aion2AssetCategory.backgroundsElysea,
      rarity: 'Mythic',
      lore: 'The gleaming floating capital of Elysea, crowning the glorious southern hemisphere.',
      themeColor: Color(0xFFFFD54F),
    ),

    // Asmodae Backgrounds
    Aion2AssetItem(
      id: 'bg_asmodae_skybox',
      title: 'Asmodae Aurora Skybox',
      subtitle: 'Boreal Night Sky',
      path: bgAsmodaeSkybox,
      category: Aion2AssetCategory.backgroundsAsmodae,
      rarity: 'Heroic',
      lore: 'Shimmering violet and emerald aurora ribbons sweeping above jagged crags.',
      themeColor: Color(0xFF7E57C2),
    ),
    Aion2AssetItem(
      id: 'bg_beluslan_frozen_sea',
      title: 'Beluslan Frozen Sea',
      subtitle: 'Permafrost Glaciers',
      path: bgBeluslanFrozenSea,
      category: Aion2AssetCategory.backgroundsAsmodae,
      rarity: 'Heroic',
      lore: 'Miles of pack ice and sunken ghost ships under perpetual snowstorms.',
      themeColor: Color(0xFF80DEEA),
    ),
    Aion2AssetItem(
      id: 'bg_morheim_volcano',
      title: 'Morheim Volcano & Lava Lake',
      subtitle: 'Molten Obsidian Gorge',
      path: bgMorheimVolcano,
      category: Aion2AssetCategory.backgroundsAsmodae,
      rarity: 'Heroic',
      lore: 'Sulfurous volcanic vents and rivers of red hot magma cutting dark basalt.',
      themeColor: Color(0xFFFF5722),
    ),
    Aion2AssetItem(
      id: 'bg_pandaemonium_capital',
      title: 'Pandaemonium Gothic Capital',
      subtitle: 'Fortress City of the Shadeworld',
      path: bgPandaemoniumCapital,
      category: Aion2AssetCategory.backgroundsAsmodae,
      rarity: 'Mythic',
      lore: 'Gothic black stone spires rising from subterranean chasms into the twilight.',
      themeColor: Color(0xFF455A64),
    ),

    // Dungeon & Abyss Backgrounds
    Aion2AssetItem(
      id: 'bg_abyss_core_warzone',
      title: 'Abyss Core Warzone',
      subtitle: 'Dimensional Fracture',
      path: bgAbyssCoreWarzone,
      category: Aion2AssetCategory.backgroundsDungeons,
      rarity: 'Mythic',
      lore: 'Center of Atreia where the Tower of Eternity broke; contested by all factions.',
      themeColor: Color(0xFFE91E63),
    ),
    Aion2AssetItem(
      id: 'bg_beshmundir_crypt',
      title: 'Beshmundir Temple Crypt',
      subtitle: 'Dragon Burial Grounds',
      path: bgBeshmundirCrypt,
      category: Aion2AssetCategory.backgroundsDungeons,
      rarity: 'Mythic',
      lore: 'Subterranean mausoleum guarding the Storm Prison where dragons lie dormant.',
      themeColor: Color(0xFF00ACC1),
    ),
    Aion2AssetItem(
      id: 'bg_dark_poeta_burning',
      title: 'Dark Poeta Burning Warzone',
      subtitle: 'Alternate Ruined Future',
      path: bgDarkPoetaBurning,
      category: Aion2AssetCategory.backgroundsDungeons,
      rarity: 'Mythic',
      lore: 'The devastated future where Tahabata and the Balaur conquered the valley.',
      themeColor: Color(0xFFD84315),
    ),
    Aion2AssetItem(
      id: 'bg_empyrean_arena',
      title: 'Crucible Coliseum Arena',
      subtitle: 'PvP Battlefield of Honor',
      path: bgEmpyreanArena,
      category: Aion2AssetCategory.backgroundsDungeons,
      rarity: 'Eternal',
      lore: 'Gladiatorial proving grounds where Daevas test blade and magic in combat.',
      themeColor: Color(0xFFFBC02D),
    ),

    // Magic Circles
    Aion2AssetItem(
      id: 'circle_archdaeva_transcendence',
      title: 'Archdaeva Transcendence Circle',
      subtitle: 'Sacred Runic Seal',
      path: circleArchdaevaTranscendence,
      category: Aion2AssetCategory.magicCircles,
      rarity: 'Mythic',
      lore: 'Sacred glyph of Atreia channeling the primordial light of creation.',
      themeColor: Color(0xFFFFD54F),
    ),
    Aion2AssetItem(
      id: 'circle_divine_light',
      title: 'Divine Light Healing Circle',
      subtitle: 'Seraphim Ward Seal',
      path: circleDivineLight,
      category: Aion2AssetCategory.magicCircles,
      rarity: 'Eternal',
      lore: 'Projects a sanctuary zone that purges afflictions from all allies.',
      themeColor: Color(0xFFFFF59D),
    ),
    Aion2AssetItem(
      id: 'circle_glacial_frost',
      title: 'Glacial Permafrost Circle',
      subtitle: 'Cryo-Elemental Runic Array',
      path: circleGlacialFrost,
      category: Aion2AssetCategory.magicCircles,
      rarity: 'Eternal',
      lore: 'Geometric frost mandala slowing time and freezing ground into treacherous rime.',
      themeColor: Color(0xFF80DEEA),
    ),
    Aion2AssetItem(
      id: 'circle_inferno_flame',
      title: 'Inferno Flame Summoning Seal',
      subtitle: 'Pyromancy Inscription',
      path: circleInfernoFlame,
      category: Aion2AssetCategory.magicCircles,
      rarity: 'Eternal',
      lore: 'Intricate pentagonal fire seal that summons meteoric blasts from above.',
      themeColor: Color(0xFFFF5722),
    ),
    Aion2AssetItem(
      id: 'circle_spirit_nature',
      title: 'Spirit Nature Harmony Seal',
      subtitle: 'Aether Resonance Glyph',
      path: circleSpiritNature,
      category: Aion2AssetCategory.magicCircles,
      rarity: 'Heroic',
      lore: 'Channels telluric currents to revitalize the flora and fauna of Atreia.',
      themeColor: Color(0xFF81C784),
    ),
    Aion2AssetItem(
      id: 'circle_tempest_lightning',
      title: 'Tempest Lightning Seal',
      subtitle: 'Thunder Ward Array',
      path: circleTempestLightning,
      category: Aion2AssetCategory.magicCircles,
      rarity: 'Eternal',
      lore: 'Electrostatically charged runic circle that zaps approaching adversaries.',
      themeColor: Color(0xFFFFEB3B),
    ),
    Aion2AssetItem(
      id: 'circle_tiamat_balaur_curse',
      title: 'Tiamat\'s Balaur Curse Circle',
      subtitle: 'Draconic Necromancy Seal',
      path: circleTiamatBalaurCurse,
      category: Aion2AssetCategory.magicCircles,
      rarity: 'Mythic',
      lore: 'Dark dragon glyph that corrupts the land and weakens mortal vitality.',
      themeColor: Color(0xFFC2185B),
    ),
    Aion2AssetItem(
      id: 'circle_void_abyss',
      title: 'Void Abyss Singularity Seal',
      subtitle: 'Dark Matter Inscription',
      path: circleVoidAbyss,
      category: Aion2AssetCategory.magicCircles,
      rarity: 'Mythic',
      lore: 'Twisting vortex runes pulling all matter toward the dimensional rift.',
      themeColor: Color(0xFF7E57C2),
    ),

    // Flipbooks
    Aion2AssetItem(
      id: 'flipbook_dark_void_vortex',
      title: 'Void Vortex Flipbook (4x4)',
      subtitle: '16-Frame Particle Atlas',
      path: flipbookDarkVoidVortex,
      category: Aion2AssetCategory.flipbooks,
      rarity: 'Mythic',
      lore: 'Animated dark matter implosion with purple gravitational filaments.',
      themeColor: Color(0xFF7E57C2),
      metadata: {'columns': 4, 'rows': 4, 'totalFrames': 16, 'fps': 24},
    ),
    Aion2AssetItem(
      id: 'flipbook_fire_explosion',
      title: 'Inferno Explosion Flipbook (4x4)',
      subtitle: '16-Frame Particle Atlas',
      path: flipbookFireExplosion,
      category: Aion2AssetCategory.flipbooks,
      rarity: 'Mythic',
      lore: 'Volumetric pyrotechnic detonation with expanding shockwave and sparks.',
      themeColor: Color(0xFFFF5722),
      metadata: {'columns': 4, 'rows': 4, 'totalFrames': 16, 'fps': 24},
    ),
    Aion2AssetItem(
      id: 'flipbook_ice_nova_shatter',
      title: 'Ice Nova Shatter Flipbook (4x4)',
      subtitle: '16-Frame Particle Atlas',
      path: flipbookIceNovaShatter,
      category: Aion2AssetCategory.flipbooks,
      rarity: 'Mythic',
      lore: 'Explosive radial frost eruption with crystalline shards fracturing outwards.',
      themeColor: Color(0xFF00E5FF),
      metadata: {'columns': 4, 'rows': 4, 'totalFrames': 16, 'fps': 24},
    ),
    Aion2AssetItem(
      id: 'flipbook_lightning_impact',
      title: 'Lightning Impact Flipbook (4x4)',
      subtitle: '16-Frame Particle Atlas',
      path: flipbookLightningImpact,
      category: Aion2AssetCategory.flipbooks,
      rarity: 'Mythic',
      lore: 'High-voltage lightning strike followed by radiating ground sparks.',
      themeColor: Color(0xFFFFEB3B),
      metadata: {'columns': 4, 'rows': 4, 'totalFrames': 16, 'fps': 24},
    ),

    // UI Frames & HUD Elements
    Aion2AssetItem(
      id: 'ui_action_bar_slot',
      title: 'HUD Action Bar Slot',
      subtitle: 'Standard Skill Slot Bezel',
      path: uiActionBarSlot,
      category: Aion2AssetCategory.aion2Ui,
      rarity: 'Heroic',
      lore: 'Gold-filigree bordered action bar slot for weapon skills and spells.',
      themeColor: Color(0xFFD4AF37),
    ),
    Aion2AssetItem(
      id: 'ui_action_bar_slot_highlight',
      title: 'HUD Action Slot Highlight',
      subtitle: 'Active Cast / Proccing State',
      path: uiActionBarSlotHighlight,
      category: Aion2AssetCategory.aion2Ui,
      rarity: 'Heroic',
      lore: 'Luminous cyan/gold border indicating skill readiness or combo chain.',
      themeColor: Color(0xFF00E5FF),
    ),
    Aion2AssetItem(
      id: 'ui_dialogue_parchment_box',
      title: 'HUD Dialogue Parchment Box',
      subtitle: 'NPC Dialogue Backdrop',
      path: uiDialogueParchmentBox,
      category: Aion2AssetCategory.aion2Ui,
      rarity: 'Heroic',
      lore: 'Aged parchment container with ornate brass corners for quest dialogue.',
      themeColor: Color(0xFFD7CCC8),
    ),
    Aion2AssetItem(
      id: 'ui_flight_wing_gauge',
      title: 'HUD Flight Wing Gauge',
      subtitle: 'Flight Time Indicator',
      path: uiFlightWingGauge,
      category: Aion2AssetCategory.aion2Ui,
      rarity: 'Eternal',
      lore: 'Wings of Aion gauge displaying remaining flight seconds and glide energy.',
      themeColor: Color(0xFF4FC3F7),
    ),
    Aion2AssetItem(
      id: 'ui_health_orb_frame',
      title: 'HUD Health Globe Frame',
      subtitle: 'Ornate Vitality Bezel',
      path: uiHealthOrbFrame,
      category: Aion2AssetCategory.aion2Ui,
      rarity: 'Eternal',
      lore: 'Embossed dragon-winged brass frame encompassing the red lifeblood orb.',
      themeColor: Color(0xFFE53935),
    ),
    Aion2AssetItem(
      id: 'ui_mana_orb_frame',
      title: 'HUD Mana Globe Frame',
      subtitle: 'Ornate Aether Bezel',
      path: uiManaOrbFrame,
      category: Aion2AssetCategory.aion2Ui,
      rarity: 'Eternal',
      lore: 'Seraphic filigree silver frame encompassing the blue aether energy orb.',
      themeColor: Color(0xFF1E88E5),
    ),
    Aion2AssetItem(
      id: 'ui_minimap_compass_bezel',
      title: 'HUD Minimap Compass Bezel',
      subtitle: 'Atreian Celestial Rose',
      path: uiMinimapCompassBezel,
      category: Aion2AssetCategory.aion2Ui,
      rarity: 'Heroic',
      lore: 'Intricate brass and gold compass bezel showing true north in the Abyss.',
      themeColor: Color(0xFFFFD54F),
    ),
    Aion2AssetItem(
      id: 'ui_quest_marker_gold',
      title: 'HUD Quest Marker',
      subtitle: 'Campaign Icon',
      path: uiQuestMarkerGold,
      category: Aion2AssetCategory.aion2Ui,
      rarity: 'Heroic',
      lore: 'Golden arrow badge marking major campaign quests of Lady Ariel or Lord Azphel.',
      themeColor: Color(0xFFFFC107),
    ),
    Aion2AssetItem(
      id: 'ui_target_boss_frame',
      title: 'HUD Boss Target Frame',
      subtitle: 'Raid Target Health Bar Bezel',
      path: uiTargetBossFrame,
      category: Aion2AssetCategory.aion2Ui,
      rarity: 'Mythic',
      lore: 'Gargantuan gold-crested frame displaying raid boss health and enrage timer.',
      themeColor: Color(0xFFB71C1C),
    ),
    Aion2AssetItem(
      id: 'ui_tooltip_frame',
      title: 'HUD Item Tooltip Frame',
      subtitle: 'Equipment Card Frame',
      path: uiTooltipFrame,
      category: Aion2AssetCategory.aion2Ui,
      rarity: 'Heroic',
      lore: 'Dark velvet background with etched gold borders for item statistics.',
      themeColor: Color(0xFFC5A059),
    ),
  ];

  // Helper Methods
  static List<Aion2AssetItem> byCategory(Aion2AssetCategory category) {
    return allAssets.where((asset) => asset.category == category).toList();
  }

  static Aion2AssetItem? findById(String id) {
    try {
      return allAssets.firstWhere((asset) => asset.id == id);
    } catch (_) {
      return null;
    }
  }

  static ImageProvider provider(String path) {
    return AssetImage(path);
  }

  static Widget image(
    String path, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Widget? errorWidget,
  }) {
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ??
            Container(
              width: width,
              height: height,
              color: const Color(0xFF1E1E2E),
              child: const Icon(
                Icons.broken_image_rounded,
                color: Color(0xFFE2C158),
              ),
            );
      },
    );
  }
}
