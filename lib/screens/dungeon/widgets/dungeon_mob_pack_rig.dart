import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/services/graphics_quality_service.dart';
import '../dungeon_battle_profiles.dart';

final Expando<ui.ImageShader> _kDungeonSpriteShaderCache =
    Expando<ui.ImageShader>('DungeonSpriteShaderCache');

ui.ImageShader _shaderForDungeonImage(ui.Image image) {
  final ui.ImageShader? cached = _kDungeonSpriteShaderCache[image];
  if (cached != null) return cached;
  final ui.ImageShader created = ui.ImageShader(
    image,
    TileMode.clamp,
    TileMode.clamp,
    Float64List.fromList(const <double>[
      1, 0, 0, 0,
      0, 1, 0, 0,
      0, 0, 1, 0,
      0, 0, 0, 1,
    ]),
  );
  _kDungeonSpriteShaderCache[image] = created;
  return created;
}

const int _kDungeonMeshCols = 8;
const int _kDungeonMeshRows = 8;

final Uint16List _kDungeonMeshIndices = (() {
  final Uint16List out =
      Uint16List(_kDungeonMeshCols * _kDungeonMeshRows * 6);
  int k = 0;
  const int stride = _kDungeonMeshCols + 1;
  for (int r = 0; r < _kDungeonMeshRows; r++) {
    for (int c = 0; c < _kDungeonMeshCols; c++) {
      final int i0 = r * stride + c;
      final int i1 = i0 + 1;
      final int i2 = i0 + stride;
      final int i3 = i2 + 1;
      out[k++] = i0;
      out[k++] = i1;
      out[k++] = i2;
      out[k++] = i1;
      out[k++] = i3;
      out[k++] = i2;
    }
  }
  return out;
})();

double _meshSmoothstep(double e0, double e1, double x) {
  final double t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

/// Descriptor for a single monster inside a multi-mob dungeon encounter pack.
class DungeonMobPackMember {
  const DungeonMobPackMember({
    required this.slotIndex,
    required this.name,
    required this.roleLabel,
    required this.spriteAsset,
    required this.isLeader,
    required this.isBoss,
    required this.scale,
    required this.xSpreadFactor,
    required this.depthYOffset,
    required this.strideFreq,
    required this.phaseSeed,
    required this.hover,
    required this.hpWeight,
    this.tintColor,
    this.tintStrength = 0.0,
  });

  final int slotIndex;
  final String name;
  final String roleLabel;
  final String spriteAsset;
  final bool isLeader;
  final bool isBoss;

  /// Height multiplier relative to `fighterBaseH`.
  final double scale;

  /// Horizontal offset from `baseEnemyX` expressed as a multiple of `arenaGap`.
  /// Negative values place vanguards closer to the Hero; positive values anchor rear guards/leaders.
  final double xSpreadFactor;

  /// 2.5D isometric ground-plane Y offset in logical pixels (negative = deeper/back row, positive = closer/front row).
  final double depthYOffset;

  /// Stride cycle multiplier so pack members never step in robotic unison.
  final double strideFreq;

  /// 0..1 phase offset for patrol, breathing, and gait cycles.
  final double phaseSeed;

  /// True for winged/levitating creatures (dragons, wyrms, seraphs, liches, djinn).
  final bool hover;

  /// Relative share of total encounter HP bar.
  final double hpWeight;

  final Color? tintColor;
  final double tintStrength;
}

class _MinionArchetype {
  const _MinionArchetype({
    required this.name,
    required this.spriteAsset,
    this.hover = false,
    this.tintColor,
    this.tintStrength = 0.0,
  });

  final String name;
  final String spriteAsset;
  final bool hover;
  final Color? tintColor;
  final double tintStrength;
}

const Map<int, List<_MinionArchetype>> _kZoneMinionPools =
    <int, List<_MinionArchetype>>{
  1: <_MinionArchetype>[
    _MinionArchetype(
      name: 'Kızılpençe Avcı',
      spriteAsset: 'assets/dungeon/mob_dire_wolf.png',
      tintColor: Color(0xFFFB7185),
      tintStrength: 0.12,
    ),
    _MinionArchetype(
      name: 'Zehirli Ağ Örücü',
      spriteAsset: 'assets/dungeon/mob_venom_spider.png',
    ),
    _MinionArchetype(
      name: 'Yağmacı Goblin İzci',
      spriteAsset: 'assets/dungeon/mob_goblin_warlord.png',
      tintColor: Color(0xFFFBBF24),
      tintStrength: 0.10,
    ),
    _MinionArchetype(
      name: 'Fosforlu Spor Yaratığı',
      spriteAsset: 'assets/dungeon/mob_spore_behemoth.png',
    ),
    _MinionArchetype(
      name: 'Dikenli Kök Bekçisi',
      spriteAsset: 'assets/dungeon/mob_cursed_treant.png',
    ),
    _MinionArchetype(
      name: 'Bataklık Kuzgun Cadısı',
      spriteAsset: 'assets/dungeon/mob_swamp_witch.png',
      hover: true,
    ),
  ],
  2: <_MinionArchetype>[
    _MinionArchetype(
      name: 'Kuvars Nöbetçi',
      spriteAsset: 'assets/dungeon/mob_crystal_golem.png',
    ),
    _MinionArchetype(
      name: 'Uçurum Gargoyle',
      spriteAsset: 'assets/dungeon/mob_chasm_gargoyle.png',
      hover: true,
    ),
    _MinionArchetype(
      name: 'Girdap Yılanı',
      spriteAsset: 'assets/dungeon/mob_abyss_wyrm.png',
      hover: true,
    ),
    _MinionArchetype(
      name: 'Derin Mağara Devi',
      spriteAsset: 'assets/dungeon/mob_spore_behemoth.png',
      tintColor: Color(0xFF38BDF8),
      tintStrength: 0.16,
    ),
  ],
  3: <_MinionArchetype>[
    _MinionArchetype(
      name: 'Altın Kıskaç Akrep',
      spriteAsset: 'assets/dungeon/mob_giant_scorpion.png',
    ),
    _MinionArchetype(
      name: 'Lanetli Mumya Muhafız',
      spriteAsset: 'assets/dungeon/mob_cursed_pharaoh.png',
    ),
    _MinionArchetype(
      name: 'Alev Cini',
      spriteAsset: 'assets/dungeon/mob_fire_djinn.png',
      hover: true,
    ),
    _MinionArchetype(
      name: 'Tapınak Sfenksi',
      spriteAsset: 'assets/dungeon/mob_anubis_sphinx.png',
    ),
    _MinionArchetype(
      name: 'Güneş Taşı Golemi',
      spriteAsset: 'assets/dungeon/mob_solar_colossus.png',
    ),
  ],
  4: <_MinionArchetype>[
    _MinionArchetype(
      name: 'Fırtına Grifonu',
      spriteAsset: 'assets/dungeon/mob_storm_griffin.png',
      hover: true,
    ),
    _MinionArchetype(
      name: 'Buzul Dev Savaşçı',
      spriteAsset: 'assets/dungeon/mob_frost_titan.png',
    ),
    _MinionArchetype(
      name: 'Yıldırım Muhafızı',
      spriteAsset: 'assets/dungeon/mob_thunder_lord.png',
    ),
    _MinionArchetype(
      name: 'Zirve Gargoyle',
      spriteAsset: 'assets/dungeon/mob_chasm_gargoyle.png',
      hover: true,
      tintColor: Color(0xFF7DD3FC),
      tintStrength: 0.16,
    ),
  ],
  5: <_MinionArchetype>[
    _MinionArchetype(
      name: 'Kemik Ruhban',
      spriteAsset: 'assets/dungeon/mob_bone_lich.png',
      hover: true,
    ),
    _MinionArchetype(
      name: 'Kanlı Kont Muhafızı',
      spriteAsset: 'assets/dungeon/mob_blood_vampire.png',
    ),
    _MinionArchetype(
      name: 'Cehennem İblisi',
      spriteAsset: 'assets/dungeon/mob_infernal_demon.png',
    ),
    _MinionArchetype(
      name: 'Obsidyen Gargoyle',
      spriteAsset: 'assets/dungeon/mob_chasm_gargoyle.png',
      hover: true,
      tintColor: Color(0xFFEF4444),
      tintStrength: 0.18,
    ),
  ],
  6: <_MinionArchetype>[
    _MinionArchetype(
      name: 'Düşmüş Serafim',
      spriteAsset: 'assets/dungeon/mob_fallen_seraph.png',
      hover: true,
    ),
    _MinionArchetype(
      name: 'Gökyüzü Grifonu',
      spriteAsset: 'assets/dungeon/mob_storm_griffin.png',
      hover: true,
      tintColor: Color(0xFFFDE047),
      tintStrength: 0.14,
    ),
    _MinionArchetype(
      name: 'Zaman Arkonu',
      spriteAsset: 'assets/dungeon/mob_chrono_archon.png',
      hover: true,
    ),
    _MinionArchetype(
      name: 'Genç Ejder Muhafız',
      spriteAsset: 'assets/dungeon/mob_elder_dragon.png',
      hover: true,
    ),
  ],
  7: <_MinionArchetype>[
    _MinionArchetype(
      name: 'Hiçlik Varlığı',
      spriteAsset: 'assets/dungeon/mob_chaos_entity.png',
      hover: true,
    ),
    _MinionArchetype(
      name: 'Kader Arkonu',
      spriteAsset: 'assets/dungeon/mob_chrono_archon.png',
      hover: true,
    ),
    _MinionArchetype(
      name: 'Kaos İblisi',
      spriteAsset: 'assets/dungeon/mob_infernal_demon.png',
      tintColor: Color(0xFFC084FC),
      tintStrength: 0.18,
    ),
    _MinionArchetype(
      name: 'Kadim Hiçlik Ejderi',
      spriteAsset: 'assets/dungeon/mob_elder_dragon.png',
      hover: true,
      tintColor: Color(0xFFA855F7),
      tintStrength: 0.16,
    ),
  ],
};

/// Brood/kin pack variants keyed by leader `enemySpriteAsset` so creature lairs
/// (e.g. Spider Nest, Wolf Den, Goblin Camp, Scorpion Valley) spawn lore-authentic
/// packmates instead of mismatched species.
const Map<String, List<_MinionArchetype>> _kSpeciesBroodPools =
    <String, List<_MinionArchetype>>{
  'assets/dungeon/mob_dire_wolf.png': <_MinionArchetype>[
    _MinionArchetype(
      name: 'Kızılpençe Avcı',
      spriteAsset: 'assets/dungeon/mob_dire_wolf.png',
      tintColor: Color(0xFFFB7185),
      tintStrength: 0.13,
    ),
    _MinionArchetype(
      name: 'Bozyele Pusucu',
      spriteAsset: 'assets/dungeon/mob_dire_wolf.png',
      tintColor: Color(0xFF93C5FD),
      tintStrength: 0.16,
    ),
    _MinionArchetype(
      name: 'Gölgediş İzcisi',
      spriteAsset: 'assets/dungeon/mob_dire_wolf.png',
      tintColor: Color(0xFF34D399),
      tintStrength: 0.14,
    ),
  ],
  'assets/dungeon/mob_venom_spider.png': <_MinionArchetype>[
    _MinionArchetype(
      name: 'Zehirli Ağ Örücü',
      spriteAsset: 'assets/dungeon/mob_venom_spider.png',
      tintColor: Color(0xFFA3E635),
      tintStrength: 0.12,
    ),
    _MinionArchetype(
      name: 'İpekkoza Pusucu',
      spriteAsset: 'assets/dungeon/mob_venom_spider.png',
      tintColor: Color(0xFFFBBF24),
      tintStrength: 0.18,
    ),
    _MinionArchetype(
      name: 'Karadul Yavrusu',
      spriteAsset: 'assets/dungeon/mob_venom_spider.png',
      tintColor: Color(0xFFC084FC),
      tintStrength: 0.16,
    ),
  ],
  'assets/dungeon/mob_goblin_warlord.png': <_MinionArchetype>[
    _MinionArchetype(
      name: 'Yağmacı Goblin İzci',
      spriteAsset: 'assets/dungeon/mob_goblin_warlord.png',
      tintColor: Color(0xFFFBBF24),
      tintStrength: 0.12,
    ),
    _MinionArchetype(
      name: 'Kemikkalkan Savaşçı',
      spriteAsset: 'assets/dungeon/mob_goblin_warlord.png',
      tintColor: Color(0xFFFB923C),
      tintStrength: 0.16,
    ),
    _MinionArchetype(
      name: 'Kızılbıçak Akıncı',
      spriteAsset: 'assets/dungeon/mob_goblin_warlord.png',
      tintColor: Color(0xFFF87171),
      tintStrength: 0.15,
    ),
  ],
  'assets/dungeon/mob_spore_behemoth.png': <_MinionArchetype>[
    _MinionArchetype(
      name: 'Fosforlu Spor Yaratığı',
      spriteAsset: 'assets/dungeon/mob_spore_behemoth.png',
      tintColor: Color(0xFF22D3EE),
      tintStrength: 0.14,
    ),
    _MinionArchetype(
      name: 'Miselyum Pusucusu',
      spriteAsset: 'assets/dungeon/mob_spore_behemoth.png',
      tintColor: Color(0xFFE879F9),
      tintStrength: 0.16,
    ),
    _MinionArchetype(
      name: 'Zehirli Küf Bekçisi',
      spriteAsset: 'assets/dungeon/mob_spore_behemoth.png',
      tintColor: Color(0xFF4ADE80),
      tintStrength: 0.14,
    ),
  ],
  'assets/dungeon/mob_cursed_treant.png': <_MinionArchetype>[
    _MinionArchetype(
      name: 'Dikenli Kök Bekçisi',
      spriteAsset: 'assets/dungeon/mob_cursed_treant.png',
      tintColor: Color(0xFF34D399),
      tintStrength: 0.12,
    ),
    _MinionArchetype(
      name: 'Külkabuk Sarmaşık',
      spriteAsset: 'assets/dungeon/mob_cursed_treant.png',
      tintColor: Color(0xFFFBBF24),
      tintStrength: 0.16,
    ),
    _MinionArchetype(
      name: 'Çürük Dal Muhafızı',
      spriteAsset: 'assets/dungeon/mob_cursed_treant.png',
      tintColor: Color(0xFF2DD4BF),
      tintStrength: 0.15,
    ),
  ],
  'assets/dungeon/mob_swamp_witch.png': <_MinionArchetype>[
    _MinionArchetype(
      name: 'Bataklık Kuzgun Cadısı',
      spriteAsset: 'assets/dungeon/mob_swamp_witch.png',
      hover: true,
      tintColor: Color(0xFF4ADE80),
      tintStrength: 0.12,
    ),
    _MinionArchetype(
      name: 'Sis Tılsımcısı',
      spriteAsset: 'assets/dungeon/mob_swamp_witch.png',
      hover: true,
      tintColor: Color(0xFFE879F9),
      tintStrength: 0.16,
    ),
    _MinionArchetype(
      name: 'Zehirli Ağ Örücü',
      spriteAsset: 'assets/dungeon/mob_venom_spider.png',
    ),
  ],
  'assets/dungeon/mob_giant_scorpion.png': <_MinionArchetype>[
    _MinionArchetype(
      name: 'Altın Kıskaç Akrep',
      spriteAsset: 'assets/dungeon/mob_giant_scorpion.png',
      tintColor: Color(0xFFFBBF24),
      tintStrength: 0.12,
    ),
    _MinionArchetype(
      name: 'Kumul İğnecisi',
      spriteAsset: 'assets/dungeon/mob_giant_scorpion.png',
      tintColor: Color(0xFF84CC16),
      tintStrength: 0.16,
    ),
    _MinionArchetype(
      name: 'Obsidyen Yavru Akrep',
      spriteAsset: 'assets/dungeon/mob_giant_scorpion.png',
      tintColor: Color(0xFFFB923C),
      tintStrength: 0.15,
    ),
  ],
};

bool _isNaturallyHoveringAsset(String asset) {
  return asset.contains('wyrm') ||
      asset.contains('gargoyle') ||
      asset.contains('djinn') ||
      asset.contains('griffin') ||
      asset.contains('lich') ||
      asset.contains('seraph') ||
      asset.contains('dragon') ||
      asset.contains('archon') ||
      asset.contains('chaos_entity') ||
      asset.contains('witch');
}

/// Deterministically builds a rich 3-to-5 monster pack for any dungeon (`#1`..`#65`).
/// Purely visual encounter choreography — does not alter server mechanics or stats.
/// When [maxMembers] is supplied (e.g. `3` on Low graphics tier), caps vanguard/flanker
/// count while always preserving the final Bespoke Pack Leader / Boss slot.
List<DungeonMobPackMember> resolveDungeonMobPack(
  DungeonBattleProfile profile, {
  int? maxMembers,
}) {
  final int dNum = profile.dungeonNumber;
  final int minionCount = profile.isBoss
      ? 4
      : (dNum <= 2 ? 2 : 3);
  final List<_MinionArchetype> pool =
      _kZoneMinionPools[profile.zone.clamp(1, 7)] ?? _kZoneMinionPools[1]!;
  final List<_MinionArchetype>? broodPool =
      _kSpeciesBroodPools[profile.enemySpriteAsset];

  // Formation templates: (xSpreadFactor, depthYOffset, scale, roleLabel, hpWeight)
  final List<(double, double, double, String, double)> minionSlots =
      switch (minionCount) {
    2 => const <(double, double, double, String, double)>[
        (-0.27, 14.0, 0.70, 'ÖNCÜ', 0.20),
        (-0.10, -22.0, 0.66, 'PUSUCU', 0.22),
      ],
    3 => const <(double, double, double, String, double)>[
        (-0.30, 14.0, 0.70, 'ÖNCÜ', 0.16),
        (-0.15, -24.0, 0.65, 'PUSUCU', 0.16),
        (0.00, 18.0, 0.74, 'MUHAFIZ', 0.20),
      ],
    _ => const <(double, double, double, String, double)>[
        (-0.31, 14.0, 0.70, 'ÖNCÜ', 0.13),
        (-0.18, -26.0, 0.65, 'PUSUCU', 0.13),
        (-0.04, 20.0, 0.74, 'AKINCI', 0.15),
        (0.16, -20.0, 0.78, 'ELİT MUHAFIZ', 0.17),
      ],
  };

  final List<DungeonMobPackMember> members = <DungeonMobPackMember>[];

  for (int i = 0; i < minionCount; i++) {
    final (
      double xSpread,
      double depthY,
      double scale,
      String role,
      double hpW,
    ) = minionSlots[i];

    // Creature dens/nests use brood kin across vanguard/flanker slots so species
    // lairs stay 100% lore-consistent; larger sanctums/bosses blend kin + zone elites.
    _MinionArchetype chosen;
    if (broodPool != null && (!profile.isBoss || i < 2)) {
      chosen = broodPool[i % broodPool.length];
    } else if (i == 0) {
      final Iterable<_MinionArchetype> sameSpecies = pool.where(
        (_MinionArchetype m) => m.spriteAsset == profile.enemySpriteAsset,
      );
      if (sameSpecies.isNotEmpty) {
        chosen = sameSpecies.first;
      } else {
        chosen = pool[(dNum + i) % pool.length];
      }
    } else {
      chosen = pool[(dNum * 3 + i * 2) % pool.length];
    }

    // Subtle hue differentiation so packmates feel distinct from the Pack Leader
    final Color? minionTint = chosen.tintColor ??
        (chosen.spriteAsset == profile.enemySpriteAsset
            ? profile.secondaryColor
            : null);
    final double minionTintStrength = chosen.tintColor != null
        ? chosen.tintStrength
        : (chosen.spriteAsset == profile.enemySpriteAsset ? 0.14 : 0.0);

    members.add(
      DungeonMobPackMember(
        slotIndex: i,
        name: chosen.name,
        roleLabel: role,
        spriteAsset: chosen.spriteAsset,
        isLeader: false,
        isBoss: false,
        scale: scale,
        xSpreadFactor: xSpread,
        depthYOffset: depthY,
        strideFreq: 1.08 + (i * 0.17),
        phaseSeed: ((dNum * 19 + i * 37) % 100) / 100.0,
        hover: chosen.hover || _isNaturallyHoveringAsset(chosen.spriteAsset),
        hpWeight: hpW,
        tintColor: minionTint,
        tintStrength: minionTintStrength,
      ),
    );
  }

  // Final slot is always the Dungeon's Bespoke Pack Leader / Boss!
  final double leaderHpWeight = switch (minionCount) {
    2 => 0.58,
    3 => 0.48,
    _ => 0.42,
  };
  final double leaderXSpread = switch (minionCount) {
    2 => 0.09,
    3 => 0.12,
    _ => 0.08,
  };

  members.add(
    DungeonMobPackMember(
      slotIndex: minionCount,
      name: profile.enemyName,
      roleLabel: profile.isBoss ? 'BOSS' : 'SÜRÜ LİDERİ',
      spriteAsset: profile.enemySpriteAsset,
      isLeader: true,
      isBoss: profile.isBoss,
      scale: (profile.enemyScale * (profile.isBoss ? 1.14 : 1.04))
          .clamp(0.96, 1.32),
      xSpreadFactor: leaderXSpread,
      depthYOffset: -2.0,
      strideFreq: profile.isBoss ? 0.88 : 0.96,
      phaseSeed: ((dNum * 13) % 100) / 100.0,
      hover: profile.enemyHover ||
          _isNaturallyHoveringAsset(profile.enemySpriteAsset),
      hpWeight: leaderHpWeight,
      tintColor: profile.enemyColorTint,
      tintStrength: profile.enemyTintStrength,
    ),
  );

  if (maxMembers != null && maxMembers >= 1 && members.length > maxMembers) {
    final List<DungeonMobPackMember> trimmed = <DungeonMobPackMember>[
      ...members.take(maxMembers - 1),
      members.last,
    ];
    double rawWeightSum = 0.0;
    for (final DungeonMobPackMember m in trimmed) {
      rawWeightSum += m.hpWeight;
    }
    final double normDenom = rawWeightSum > 0 ? rawWeightSum : 1.0;
    return List<DungeonMobPackMember>.generate(trimmed.length, (int idx) {
      final DungeonMobPackMember src = trimmed[idx];
      return DungeonMobPackMember(
        slotIndex: idx,
        name: src.name,
        roleLabel: src.roleLabel,
        spriteAsset: src.spriteAsset,
        isLeader: src.isLeader,
        isBoss: src.isBoss,
        scale: src.scale,
        xSpreadFactor: src.xSpreadFactor,
        depthYOffset: src.depthYOffset,
        strideFreq: src.strideFreq,
        phaseSeed: src.phaseSeed,
        hover: src.hover,
        hpWeight: src.hpWeight / normDenom,
        tintColor: src.tintColor,
        tintStrength: src.tintStrength,
      );
    });
  }

  return members;
}

// =============================================================================
// 60 FPS Segmented 2.5D Fighter & Monster Skeletal Rig Widget
// =============================================================================

/// Renders a Hero or Monster PNG through a real-time 60 FPS segmented 2.5D skeletal rig:
/// - Independent left/right lower limbs (boots, paws, claws, talons) with sinusoidal
///   pendulum strides, knee lift, and depth shading when walking/charging!
/// - Articulated upper body/thorax/wings/weapon with breathing expansion, stalk lean,
///   wind-up coil, explosive slash lunge, hit recoil, and crisp specular flash!
/// - Blazing soul-ember disintegration when `deathProgress > 0`!
class DungeonSkeletalFighter extends StatefulWidget {
  const DungeonSkeletalFighter({
    super.key,
    required this.assetPath,
    this.fallbackAssetPath,
    required this.facingRight,
    required this.walkPhase,
    required this.strideIntensity,
    required this.idlePhase,
    required this.attackSlashProgress,
    required this.hitRecoil,
    required this.specularFlash,
    required this.accentColor,
    required this.secondaryColor,
    this.hover = false,
    this.tintColor,
    this.tintStrength = 0.0,
    this.deathProgress = 0.0,
    this.warmHitBias = false,
    this.afterimageAlpha = 0.0,
  });

  final String assetPath;
  final String? fallbackAssetPath;
  final bool facingRight;

  /// Continuous 60Hz radian phase (`0 .. 2*pi*N`) driving limb pendulums.
  final double walkPhase;

  /// `0.0` = planted guard stance, `0.35..0.65` = prowling patrol, `1.0..1.4` = full sprint/charge!
  final double strideIntensity;

  /// `0..1` ambient breathing phase.
  final double idlePhase;

  /// `0..1` active melee/magic swing progression (`0` when not swinging).
  final double attackSlashProgress;

  /// `0..1` physical stagger whiplash when taking a hit.
  final double hitRecoil;

  /// `0..1` incandescent specular flash on hit.
  final double specularFlash;

  final Color accentColor;
  final Color secondaryColor;
  final bool hover;
  final Color? tintColor;
  final double tintStrength;

  /// `0.0` = alive, `0.01..1.0` = shattering into soul-embers!
  final double deathProgress;
  final bool warmHitBias;
  final double afterimageAlpha;

  @override
  State<DungeonSkeletalFighter> createState() => _DungeonSkeletalFighterState();
}

class _DungeonSkeletalFighterState extends State<DungeonSkeletalFighter> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _decodedImage;
  String? _resolvedAsset;
  int? _resolvedCacheWidth = -1;
  bool _triedFallback = false;

  @override
  void initState() {
    super.initState();
    GraphicsQualityService.instance.addListener(_onGraphicsChanged);
  }

  void _onGraphicsChanged() {
    if (!mounted) return;
    final int? targetW =
        GraphicsQualityService.instance.profile.dungeonSpriteCacheWidth;
    if (targetW != _resolvedCacheWidth && _resolvedAsset != null) {
      _resolveImage(_resolvedAsset!, force: true);
    } else {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage(widget.assetPath);
  }

  @override
  void didUpdateWidget(covariant DungeonSkeletalFighter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _triedFallback = false;
      _resolveImage(widget.assetPath, force: true);
    }
  }

  void _resolveImage(String path, {bool force = false}) {
    final int? targetW =
        GraphicsQualityService.instance.profile.dungeonSpriteCacheWidth;
    if (!force &&
        _resolvedAsset == path &&
        _resolvedCacheWidth == targetW &&
        _decodedImage != null) {
      return;
    }
    _unsubscribe();
    _resolvedAsset = path;
    _resolvedCacheWidth = targetW;

    final ImageProvider<Object> provider =
        ResizeImage.resizeIfNeeded(targetW, null, AssetImage(path));
    final ImageStream newStream =
        provider.resolve(createLocalImageConfiguration(context));
    _stream = newStream;
    _listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        if (!mounted) return;
        if (_decodedImage != info.image) {
          setState(() {
            _decodedImage = info.image;
          });
        }
      },
      onError: (Object _, StackTrace? _) {
        if (!mounted) return;
        if (!_triedFallback &&
            widget.fallbackAssetPath != null &&
            widget.fallbackAssetPath != path) {
          _triedFallback = true;
          _resolveImage(widget.fallbackAssetPath!, force: true);
        }
      },
    );
    newStream.addListener(_listener!);
  }

  void _unsubscribe() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    GraphicsQualityService.instance.removeListener(_onGraphicsChanged);
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.deathProgress >= 1.0) {
      return const SizedBox.shrink();
    }

    final GraphicsProfile gfx = GraphicsQualityService.instance.profile;
    final ui.Image? img = _decodedImage;
    if (img == null) {
      // Instant zero-latency frame-0 fallback while image stream attaches
      return Image.asset(
        widget.assetPath,
        cacheWidth: gfx.dungeonSpriteCacheWidth,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        filterQuality: gfx.filterQuality,
        errorBuilder: (_, _, _) {
          if (widget.fallbackAssetPath != null) {
            return Image.asset(
              widget.fallbackAssetPath!,
              cacheWidth: gfx.dungeonSpriteCacheWidth,
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              filterQuality: gfx.filterQuality,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            );
          }
          return const SizedBox.shrink();
        },
      );
    }

    return CustomPaint(
      painter: _DungeonSegmentedRigPainter(
        image: img,
        facingRight: widget.facingRight,
        walkPhase: widget.walkPhase,
        strideIntensity: widget.strideIntensity,
        idlePhase: widget.idlePhase,
        attackSlashProgress: widget.attackSlashProgress,
        hitRecoil: widget.hitRecoil,
        specularFlash: widget.specularFlash,
        accentColor: widget.accentColor,
        secondaryColor: widget.secondaryColor,
        hover: widget.hover,
        tintColor: widget.tintColor,
        tintStrength: widget.tintStrength,
        deathProgress: widget.deathProgress,
        warmHitBias: widget.warmHitBias,
        afterimageAlpha: widget.afterimageAlpha,
      ),
      size: Size.infinite,
    );
  }
}

/// Direct canvas entry point for rendering a Hero or Monster PNG via the
/// seamless 60 FPS connected 8x8 skeletal mesh rig (also used by visual tests).
void paintDungeonConnectedMeshFighter({
  required Canvas canvas,
  required Size size,
  required ui.Image image,
  required bool facingRight,
  required double walkPhase,
  required double strideIntensity,
  required double idlePhase,
  required Color accentColor,
  required Color secondaryColor,
  double attackSlashProgress = 0.0,
  double hitRecoil = 0.0,
  double specularFlash = 0.0,
  bool hover = false,
  Color? tintColor,
  double tintStrength = 0.0,
  double deathProgress = 0.0,
  bool warmHitBias = false,
  double afterimageAlpha = 0.0,
}) {
  _DungeonSegmentedRigPainter(
    image: image,
    facingRight: facingRight,
    walkPhase: walkPhase,
    strideIntensity: strideIntensity,
    idlePhase: idlePhase,
    attackSlashProgress: attackSlashProgress,
    hitRecoil: hitRecoil,
    specularFlash: specularFlash,
    accentColor: accentColor,
    secondaryColor: secondaryColor,
    hover: hover,
    tintColor: tintColor,
    tintStrength: tintStrength,
    deathProgress: deathProgress,
    warmHitBias: warmHitBias,
    afterimageAlpha: afterimageAlpha,
  ).paint(canvas, size);
}

class _DungeonSegmentedRigPainter extends CustomPainter {
  const _DungeonSegmentedRigPainter({
    required this.image,
    required this.facingRight,
    required this.walkPhase,
    required this.strideIntensity,
    required this.idlePhase,
    required this.attackSlashProgress,
    required this.hitRecoil,
    required this.specularFlash,
    required this.accentColor,
    required this.secondaryColor,
    required this.hover,
    required this.tintColor,
    required this.tintStrength,
    required this.deathProgress,
    required this.warmHitBias,
    required this.afterimageAlpha,
  });

  final ui.Image image;
  final bool facingRight;
  final double walkPhase;
  final double strideIntensity;
  final double idlePhase;
  final double attackSlashProgress;
  final double hitRecoil;
  final double specularFlash;
  final Color accentColor;
  final Color secondaryColor;
  final bool hover;
  final Color? tintColor;
  final double tintStrength;
  final double deathProgress;
  final bool warmHitBias;
  final double afterimageAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || deathProgress >= 1.0) return;

    final double imgW = image.width.toDouble();
    final double imgH = image.height.toDouble();
    if (imgW <= 0 || imgH <= 0) return;

    // Fit sprite proportionally anchored to bottomCenter inside `size`
    final double aspect = imgW / imgH;
    double dstH = size.height;
    double dstW = dstH * aspect;
    if (dstW > size.width) {
      dstW = size.width;
      dstH = dstW / aspect;
    }
    final double leftX = (size.width - dstW) * 0.5;
    final double topY = size.height - dstH;
    final double cx = size.width * 0.5;
    final double groundY = size.height;

    final double moveAmp = strideIntensity.clamp(0.0, 1.45);
    final double strideSin = math.sin(walkPhase);
    final double strideCos = math.cos(walkPhase);
    final double breath = math.sin(idlePhase * math.pi * 2.0);
    final double breathCos = math.cos(idlePhase * math.pi * 2.0);

    // Forward direction in sprite space (`+1` for right-facing Hero, `-1` for left-facing Monsters)
    final double fwd = facingRight ? 1.0 : -1.0;

    // 1. Vertical bounce / wing-hover surge
    double bodyBobY;
    if (hover) {
      bodyBobY = math.sin(walkPhase) * dstH * (0.026 + 0.016 * moveAmp);
    } else if (moveAmp > 0.04) {
      // Crisp 60Hz double-step foot-plant cadence (2 grounded steps per 2*pi cycle)
      bodyBobY = -strideSin.abs() * (dstH * 0.034 * moveAmp) +
          math.sin(walkPhase * 2.0) * (dstH * 0.006 * moveAmp);
    } else {
      bodyBobY = -breath.abs() * (dstH * 0.010);
    }

    // 2. Upper-body lean, melee swing whip & recoil (applied smoothly across connected mesh)
    double upperLeanX = (moveAmp > 0.04)
        ? (fwd * dstW * (0.036 * moveAmp - strideSin * 0.016 * moveAmp))
        : (fwd * breathCos * dstW * 0.009);
    double upperWhipY = 0.0;

    if (attackSlashProgress > 0.001 && attackSlashProgress < 0.999) {
      final double a = attackSlashProgress.clamp(0.0, 1.0);
      if (a < 0.26) {
        final double u = Curves.easeOutCubic.transform(a / 0.26);
        upperLeanX += -fwd * dstW * 0.088 * u;
        upperWhipY += dstH * 0.028 * u;
      } else if (a < 0.64) {
        final double u = Curves.easeOutExpo.transform((a - 0.26) / 0.38);
        upperLeanX += fwd * dstW * (-0.088 + 0.240 * u);
        upperWhipY +=
            dstH * (0.028 * (1.0 - u) - 0.032 * math.sin(u * math.pi));
      } else {
        final double inv =
            1.0 - Curves.easeInOutCubic.transform((a - 0.64) / 0.36);
        upperLeanX += fwd * dstW * 0.152 * inv;
      }
    }

    if (hitRecoil > 0.001) {
      final double r = hitRecoil.clamp(0.0, 1.0);
      upperLeanX += -fwd * dstW * 0.095 * r;
      upperWhipY += dstH * 0.022 * r;
    }

    // 3. Soul-Shatter Death Collapse (`deathProgress: 0..1`)
    final double deathT = deathProgress.clamp(0.0, 1.0);
    final double masterAlpha = deathT > 0.0
        ? (1.0 - Curves.easeInQuad.transform(deathT)).clamp(0.0, 1.0)
        : 1.0;

    if (deathT > 0.0) {
      bodyBobY += dstH * 0.15 * Curves.easeInCubic.transform(deathT);
      upperLeanX += -fwd * dstW * 0.14 * deathT;
    }

    final double totalFlash =
        math.max(specularFlash, deathT > 0.0 ? (1.0 - deathT) * 0.85 : 0.0)
            .clamp(0.0, 1.0);
    final GraphicsProfile gfx = GraphicsQualityService.instance.profile;

    // 4. Optional dash/crit spectral motion-trail afterimage behind fast lunging fighter
    if (gfx.enableSpriteCrossDissolveAndGhost &&
        afterimageAlpha > 0.01 &&
        deathT <= 0.0) {
      final double ghostAlpha = (afterimageAlpha * 0.36).clamp(0.0, 0.22);
      final double ar = accentColor.r;
      final double ag = accentColor.g;
      final double ab = accentColor.b;
      final Rect fullSrc = Rect.fromLTWH(0, 0, imgW, imgH);
      for (final (double distFactor, double alphaScale) in const <(double, double)>[
        (0.21, 0.48),
        (0.11, 1.00),
      ]) {
        final double passAlpha = ghostAlpha * alphaScale;
        if (passAlpha < 0.015) continue;
        final Rect ghostDst = Rect.fromLTWH(
          leftX - fwd * dstW * distFactor,
          topY + bodyBobY + 2.0,
          dstW,
          dstH,
        );
        canvas.drawImageRect(
          image,
          fullSrc,
          ghostDst,
          Paint()
            ..filterQuality = gfx.filterQuality
            ..blendMode = BlendMode.plus
            ..colorFilter = ColorFilter.matrix(<double>[
              0.25 + 0.85 * ar, 0.20 * ar, 0.10 * ar, 0, 0,
              0.15 * ag, 0.25 + 0.85 * ag, 0.15 * ag, 0, 0,
              0.15 * ab, 0.20 * ab, 0.25 + 0.85 * ab, 0, 0,
              0, 0, 0, passAlpha, 0,
            ]),
        );
      }
    }

    // 5. 60 FPS Grounded Footstep Dust Puffs on Dungeon Flagstones
    if (!gfx.isLow && !hover && moveAmp > 0.25 && deathT <= 0.0) {
      _paintDungeonFootstepDust(
        canvas: canvas,
        leftX: leftX,
        dstW: dstW,
        groundY: groundY,
        fwd: fwd,
        walkPhase: walkPhase,
        moveAmp: moveAmp,
      );
    }

    // 6. Fast Single-Quad Blit on Low Tier vs Seamless 8x8 Connected Mesh on Medium+
    if (gfx.useFastSpriteQuad) {
      final Rect srcRect = Rect.fromLTWH(0, 0, imgW, imgH);
      final Rect dstRect = Rect.fromLTWH(
        leftX + upperLeanX * 0.48,
        topY + bodyBobY + upperWhipY * 0.5,
        dstW,
        dstH,
      );
      canvas.drawImageRect(
        image,
        srcRect,
        dstRect,
        _buildSpritePaint(
          alpha: masterAlpha,
          flash: totalFlash,
          darkenBackLimb: false,
          filterQuality: gfx.filterQuality,
        ),
      );
    } else {
      const int vCount = (_kDungeonMeshCols + 1) * (_kDungeonMeshRows + 1);
      final Float32List positions = Float32List(vCount * 2);
      final Float32List texCoords = Float32List(vCount * 2);

      int idx = 0;
      for (int r = 0; r <= _kDungeonMeshRows; r++) {
        final double v = r / _kDungeonMeshRows;
        final double wUpper = 1.0 - _meshSmoothstep(0.30, 0.90, v);
        final double wWing = 1.0 - _meshSmoothstep(0.14, 0.64, v);
        final double wTail = _meshSmoothstep(0.45, 1.0, v);
        final double wFoot = _meshSmoothstep(0.54, 1.0, v);
        final double ribWave = math.sin(v * math.pi) * breath;

        for (int c = 0; c <= _kDungeonMeshCols; c++) {
          final double u = c / _kDungeonMeshCols;
          // Smooth C1 left-vs-right stance weight: -1 at left edge, 0 at center, +1 at right edge
          final double side = math.sin((u - 0.5) * math.pi);
          final double trailingMask = facingRight ? (1.0 - u) : u;

          double dx = upperLeanX * wUpper + (side * dstW * 0.013 * ribWave);
          double dy = bodyBobY + upperWhipY * wUpper;

          if (hover) {
            // Wingbeat span flap + serpentine lower tail undulation at 60Hz
            final double flapAmp = 0.030 + 0.022 * moveAmp;
            dx += side * strideSin * dstW * flapAmp * wWing;
            dy += -side.abs() * strideCos * dstH * (flapAmp * 0.95) * wWing;
            dx += math.sin(walkPhase - v * 3.0) * dstW * 0.026 * wTail;
          } else if (moveAmp > 0.03) {
            // Connected elliptical foot/paw stride: alternating scissor + lift/plant!
            dx += -side * strideSin * dstW * 0.076 * moveAmp * wFoot;
            final double leftLift =
                math.max(0.0, strideCos) * math.max(0.0, -side);
            final double rightLift =
                math.max(0.0, -strideCos) * math.max(0.0, side);
            dy += -(leftLift + rightLift) * dstH * 0.080 * moveAmp * wFoot;
          }

          // Subtle dungeon wind draft along trailing cape / coat / fur / tail
          dy += math.sin(idlePhase * math.pi * 4.0 + v * 5.0) *
              dstH *
              0.011 *
              trailingMask *
              _meshSmoothstep(0.20, 0.86, v) *
              (1.0 - wFoot * 0.7);

          positions[idx] = leftX + u * dstW + dx;
          positions[idx + 1] = topY + v * dstH + dy;
          texCoords[idx] = u * imgW;
          texCoords[idx + 1] = v * imgH;
          idx += 2;
        }
      }

      final ui.Vertices vertices = ui.Vertices.raw(
        ui.VertexMode.triangles,
        positions,
        textureCoordinates: texCoords,
        indices: _kDungeonMeshIndices,
      );

      final Paint meshPaint = _buildSpritePaint(
        alpha: masterAlpha,
        flash: totalFlash,
        darkenBackLimb: false,
        filterQuality: gfx.filterQuality,
      )..shader = _shaderForDungeonImage(image);

      canvas.drawVertices(vertices, BlendMode.dst, meshPaint);
    }

    // Soul-ember shatter VFX when a pack mob is executed!
    if (deathT > 0.01 && deathT < 0.99) {
      _paintSoulShatterEmbers(
        canvas: canvas,
        cx: cx,
        groundY: groundY,
        spriteH: dstH,
        t: deathT,
        gfx: gfx,
      );
    }
  }

  void _paintDungeonFootstepDust({
    required Canvas canvas,
    required double leftX,
    required double dstW,
    required double groundY,
    required double fwd,
    required double walkPhase,
    required double moveAmp,
  }) {
    const double pi = math.pi;
    final double norm = ((walkPhase % (pi * 2.0)) + pi * 2.0) % (pi * 2.0);
    final Paint p = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 2; i++) {
      final double stepT = (((norm / pi) + i) % 1.0).clamp(0.0, 1.0);
      final double alpha =
          (1.0 - stepT) * 0.24 * moveAmp.clamp(0.0, 1.2);
      if (alpha <= 0.02) continue;
      final double originX = leftX + dstW * (0.50 - fwd * 0.08);
      final double puffX = originX - fwd * (stepT * dstW * 0.22 + i * 4.0);
      final double puffY = (groundY - 4.0) - math.sin(stepT * pi) * 5.0;
      final double r = 2.8 + stepT * 4.6;
      p.color = accentColor.withValues(alpha: alpha * 0.45);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(puffX, puffY),
          width: r * 2.2,
          height: r * 1.1,
        ),
        p,
      );
    }
  }

  Paint _buildSpritePaint({
    required double alpha,
    required double flash,
    required bool darkenBackLimb,
    FilterQuality filterQuality = FilterQuality.medium,
  }) {
    final Paint p = Paint()
      ..filterQuality = filterQuality
      ..isAntiAlias = filterQuality != FilterQuality.none;

    final double baseGain = darkenBackLimb ? 0.86 : 1.0;
    final double gain = baseGain + 0.38 * flash;

    // Subtle species tint blend into RGB gains if configured
    double rMul = gain;
    double gMul = gain;
    double bMul = gain;
    if (tintColor != null && tintStrength > 0.0) {
      final double ts = tintStrength.clamp(0.0, 0.45);
      rMul *= (1.0 - ts) + ts * (tintColor!.r * 1.35);
      gMul *= (1.0 - ts) + ts * (tintColor!.g * 1.35);
      bMul *= (1.0 - ts) + ts * (tintColor!.b * 1.35);
    }

    final double addR = (warmHitBias ? 92.0 : 84.0) * flash;
    final double addG = (warmHitBias ? 42.0 : 72.0) * flash;
    final double addB = (warmHitBias ? 36.0 : 56.0) * flash;

    if (alpha < 0.999 ||
        flash > 0.005 ||
        darkenBackLimb ||
        (tintColor != null && tintStrength > 0.0)) {
      p.colorFilter = ColorFilter.matrix(<double>[
        rMul, 0, 0, 0, addR,
        0, gMul, 0, 0, addG,
        0, 0, bMul, 0, addB,
        0, 0, 0, alpha.clamp(0.0, 1.0), 0,
      ]);
    }
    return p;
  }

  void _paintSoulShatterEmbers({
    required Canvas canvas,
    required double cx,
    required double groundY,
    required double spriteH,
    required double t,
    required GraphicsProfile gfx,
  }) {
    final double fade = math.sin(t * math.pi).clamp(0.0, 1.0);
    // Expanding ground soul-ring
    final Rect ringRect = Rect.fromCenter(
      center: Offset(cx, groundY - 8),
      width: spriteH * (0.45 + t * 0.85),
      height: 18 + t * 22,
    );
    canvas.drawOval(
      ringRect,
      Paint()
        ..color = accentColor.withValues(alpha: 0.55 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );

    final int emberCount = gfx.isLow ? 6 : 18;
    for (int i = 0; i < emberCount; i++) {
      final double seed = ((i * 137) % 100) / 100.0;
      final double angle = (seed * 2.0 - 1.0) * 1.35;
      final double speed = 0.55 + ((i * 53) % 100) / 100.0 * 0.75;
      final double spreadX = math.sin(angle * 3.1 + i) * spriteH * 0.42 * t;
      final double riseY =
          (groundY - spriteH * (0.18 + seed * 0.55)) - (spriteH * 0.65 * speed * t);
      final Color c = i % 3 == 0 ? secondaryColor : accentColor;
      final double r = (3.6 - t * 2.2).clamp(1.0, 4.0);

      if (gfx.enableHeavyShadows) {
        canvas.drawCircle(
          Offset(cx + spreadX, riseY),
          r * 2.1,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = c.withValues(alpha: 0.42 * fade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
        );
      } else {
        canvas.drawCircle(
          Offset(cx + spreadX, riseY),
          r * 1.4,
          Paint()..color = c.withValues(alpha: 0.55 * fade),
        );
      }
      canvas.drawCircle(
        Offset(cx + spreadX, riseY),
        r * 0.75,
        Paint()..color = Colors.white.withValues(alpha: 0.88 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DungeonSegmentedRigPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.walkPhase != walkPhase ||
        oldDelegate.strideIntensity != strideIntensity ||
        oldDelegate.idlePhase != idlePhase ||
        oldDelegate.attackSlashProgress != attackSlashProgress ||
        oldDelegate.hitRecoil != hitRecoil ||
        oldDelegate.specularFlash != specularFlash ||
        oldDelegate.deathProgress != deathProgress ||
        oldDelegate.afterimageAlpha != afterimageAlpha ||
        oldDelegate.facingRight != facingRight;
  }
}

// =============================================================================
// Multi-Plane 2.5D Chamber Depth, Torchlight God-Rays & Pack Floor Painter
// =============================================================================

class DungeonPackShadowAnchor {
  const DungeonPackShadowAnchor({
    required this.x,
    required this.y,
    required this.width,
    required this.alpha,
    required this.isLeader,
  });

  final double x;
  final double y;
  final double width;
  final double alpha;
  final bool isLeader;
}

/// Transforms flat arena backgrounds into a 3D-feeling dark-fantasy chamber:
/// 1. Diagonal flickering torch/sanctum volumetric light shafts from upper arches.
/// 2. Perspective-foreshortened dungeon flagstone floor seams & glowing arcane duel ring.
/// 3. Individual grounded ambient + core contact shadows under the Hero and EVERY pack mob!
class DungeonChamberDepthPainter extends CustomPainter {
  const DungeonChamberDepthPainter({
    required this.ambientProgress,
    required this.locomotionProgress,
    required this.primary,
    required this.secondary,
    required this.isBoss,
    required this.heroX,
    required this.groundY,
    required this.packShadows,
    required this.combatIntensity,
  });

  final double ambientProgress;
  final double locomotionProgress;
  final Color primary;
  final Color secondary;
  final bool isBoss;
  final double heroX;
  final double groundY;
  final List<DungeonPackShadowAnchor> packShadows;
  final double combatIntensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final GraphicsProfile gfx = GraphicsQualityService.instance.profile;
    final double w = size.width;
    final double h = size.height;
    final double pulse = 0.76 + 0.24 * math.sin(ambientProgress * math.pi * 2);
    final double torchFlicker =
        0.84 + 0.16 * math.sin(locomotionProgress * math.pi * 4);

    // 1. Volumetric Overhead Sanctum / Torchlight God-Rays (Medium+)
    if (!gfx.isLow) {
      _paintLightShaft(
        canvas: canvas,
        topX: w * 0.24,
        bottomX: w * 0.36 + math.sin(ambientProgress * math.pi * 2) * 18,
        topWidth: w * 0.10,
        bottomWidth: w * 0.28,
        endY: groundY + 26,
        color: const Color(0xFFFFB347),
        alpha: 0.075 * torchFlicker,
      );
      _paintLightShaft(
        canvas: canvas,
        topX: w * 0.74,
        bottomX: w * 0.64 - math.cos(ambientProgress * math.pi * 2) * 18,
        topWidth: w * 0.12,
        bottomWidth: w * 0.32,
        endY: groundY + 30,
        color: primary,
        alpha: (isBoss ? 0.105 : 0.080) * pulse,
      );
    }

    // 2. 2.5D Perspective Stone Floor Depth Deck & Ancient Battle Sigil
    final double horizonY = groundY - 46.0;
    final Rect floorDeck = Rect.fromLTRB(0, horizonY, w, h);
    canvas.drawRect(
      floorDeck,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.transparent,
            Colors.black.withValues(alpha: 0.28),
            Colors.black.withValues(alpha: 0.56),
          ],
          stops: const <double>[0.0, 0.38, 1.0],
        ).createShader(floorDeck),
    );

    if (!gfx.isLow) {
      // Perspective stone flagstone radial seams converging toward chamber vanishing point
      final Offset vanish = Offset(w * 0.5, horizonY - 90.0);
      final Paint seamPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.24)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      for (int i = -4; i <= 4; i++) {
        final double bx = w * 0.5 + i * (w * 0.16);
        const double tStart = 0.62;
        final Offset p0 = Offset(
          ui.lerpDouble(vanish.dx, bx, tStart)!,
          ui.lerpDouble(vanish.dy, h, tStart)!,
        );
        canvas.drawLine(p0, Offset(bx, h), seamPaint);
      }
    }

    // Glowing foreshortened sanctum battle circle on the chamber flagstones
    final double centerArenaX = w * 0.52;
    final Rect runeOuter = Rect.fromCenter(
      center: Offset(centerArenaX, groundY + 4),
      width: math.min(w * 0.76, 620.0),
      height: 64.0,
    );
    if (!gfx.isLow) {
      canvas.drawOval(
        runeOuter,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              primary.withValues(
                alpha: (isBoss ? 0.22 : 0.13) *
                    pulse *
                    (0.85 + 0.3 * combatIntensity),
              ),
              secondary.withValues(alpha: 0.06 * pulse),
              Colors.transparent,
            ],
            stops: const <double>[0.0, 0.58, 1.0],
          ).createShader(runeOuter),
      );
    }
    canvas.drawOval(
      runeOuter.deflate(8),
      Paint()
        ..color = primary.withValues(alpha: (isBoss ? 0.26 : 0.16) * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );

    // Low drifting ground mist ribbons across the stone floor (High/Ultra only)
    if (gfx.enableWeatherAndAtmosphere) {
      for (int i = 0; i < 3; i++) {
        final double drift =
            ((ambientProgress * (0.35 + i * 0.12) + i * 0.33) % 1.0);
        final double mx = (drift * 1.4 - 0.2) * w;
        final double my = groundY - 12.0 + i * 16.0;
        final Rect mist = Rect.fromCenter(
          center: Offset(mx, my),
          width: w * 0.48,
          height: 36.0,
        );
        canvas.drawOval(
          mist,
          Paint()
            ..shader = RadialGradient(
              colors: <Color>[
                primary.withValues(alpha: 0.09 * pulse),
                Colors.transparent,
              ],
            ).createShader(mist),
        );
      }
    }

    // 3. Hero Grounded Contact Shadow + Emerald Rim Bounce
    _drawGroundedShadow(
      canvas: canvas,
      center: Offset(heroX, groundY),
      width: 142.0,
      height: 28.0,
      rimColor: const Color(0xFF34D399),
      rimAlpha: 0.16 * pulse,
      shadowOpacity: 1.0,
      enableBlur: gfx.enableHeavyShadows,
    );

    // 4. Every Living Pack Mob's Grounded Contact Shadow + Threat Rim
    for (final DungeonPackShadowAnchor mob in packShadows) {
      if (mob.alpha <= 0.02) continue;
      _drawGroundedShadow(
        canvas: canvas,
        center: Offset(mob.x, mob.y),
        width: mob.width,
        height: mob.width * 0.21,
        rimColor: mob.isLeader && isBoss ? const Color(0xFFFFD700) : primary,
        rimAlpha: (mob.isLeader ? 0.24 : 0.13) * pulse * mob.alpha,
        shadowOpacity: mob.alpha,
        enableBlur: gfx.enableHeavyShadows,
      );
    }
  }

  void _paintLightShaft({
    required Canvas canvas,
    required double topX,
    required double bottomX,
    required double topWidth,
    required double bottomWidth,
    required double endY,
    required Color color,
    required double alpha,
  }) {
    final Path shaft = Path()
      ..moveTo(topX - topWidth * 0.5, -10)
      ..lineTo(topX + topWidth * 0.5, -10)
      ..lineTo(bottomX + bottomWidth * 0.5, endY)
      ..lineTo(bottomX - bottomWidth * 0.5, endY)
      ..close();

    final Rect bounds = Rect.fromLTRB(0, -10, math.max(topX, bottomX) + bottomWidth, endY);
    canvas.drawPath(
      shaft,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            color.withValues(alpha: alpha),
            color.withValues(alpha: alpha * 0.45),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.55, 1.0],
        ).createShader(bounds),
    );
  }

  void _drawGroundedShadow({
    required Canvas canvas,
    required Offset center,
    required double width,
    required double height,
    required Color rimColor,
    required double rimAlpha,
    required double shadowOpacity,
    required bool enableBlur,
  }) {
    if (enableBlur) {
      final Rect glowRect = Rect.fromCenter(
        center: Offset(center.dx, center.dy + 2),
        width: width * 1.28,
        height: height * 1.50,
      );
      canvas.drawOval(
        glowRect,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              rimColor.withValues(alpha: rimAlpha),
              Colors.transparent,
            ],
          ).createShader(glowRect),
      );
    }

    final Paint widePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.56 * shadowOpacity);
    if (enableBlur) {
      widePaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    }
    final Rect wideShadow =
        Rect.fromCenter(center: center, width: width, height: height);
    canvas.drawOval(wideShadow, widePaint);

    final Paint corePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.80 * shadowOpacity);
    if (enableBlur) {
      corePaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5);
    }
    final Rect coreShadow = Rect.fromCenter(
      center: Offset(center.dx, center.dy - 1),
      width: width * 0.62,
      height: height * 0.46,
    );
    canvas.drawOval(coreShadow, corePaint);
  }

  @override
  bool shouldRepaint(covariant DungeonChamberDepthPainter oldDelegate) => true;
}
