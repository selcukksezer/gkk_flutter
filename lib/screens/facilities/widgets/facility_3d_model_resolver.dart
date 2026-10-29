import 'dart:io' as io;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../core/assets/mesh_asset_registry.dart';
import '../../../theme/app_colors.dart';

// =============================================================================
// FACILITY 3D MODEL SPECIFICATION & ASSET REGISTRY
// Maps all 15 game facilities + fantasy archetypes (Forge, Barracks, Treasury,
// Alchemy Lab, Sanctum, Crypt, Time Well) to real high-fidelity .glb models.
// Zero primitive blockouts — only authentic CC0 PBR 3D meshes with full geometry.
// =============================================================================

/// Architectural structure metadata for a facility's 3D .glb representation.
class Facility3dStructureSpec {
  const Facility3dStructureSpec({
    required this.facilityType,
    required this.structureTitle,
    required this.archetype,
    required this.primaryGlbPath,
    required this.fallbackGlbPaths,
    required this.tier,
    required this.accentColor,
    required this.emissiveColor,
    required this.runicGlyph,
    required this.modelScale,
    required this.verticalOffset,
    required this.cameraDistance,
    required this.architecturalDescription,
  });

  /// Facility type key matching `PlayerFacility.facilityType` and `kFacilityMetaByType`.
  final String facilityType;

  /// Cinematic architectural title (e.g. "Gothic Obsidian Foundry").
  final String structureTitle;

  /// Fantasy archetype category (e.g. "forge", "barracks", "treasury", "alchemy").
  final String archetype;

  /// Primary real .glb model asset path.
  final String primaryGlbPath;

  /// Candidate list of real .glb models in case primary is absent.
  final List<String> fallbackGlbPaths;

  /// Facility tier (1, 2, or 3).
  final int tier;

  /// Primary theme accent color.
  final Color accentColor;

  /// Glowing runic / crystal emission color.
  final Color emissiveColor;

  /// Ancient runic glyph symbol for the pedestal dais.
  final String runicGlyph;

  /// Default model scale factor for viewport camera framing.
  final double modelScale;

  /// Vertical Y-offset adjustment for centering geometry.
  final double verticalOffset;

  /// Camera target distance.
  final double cameraDistance;

  /// Lore and architectural description of the 3D structure.
  final String architecturalDescription;
}

/// Catalog mapping every facility to real .glb models.
class Facility3dCatalog {
  Facility3dCatalog._();

  static const Map<String, Facility3dStructureSpec> _specs = <String, Facility3dStructureSpec>{
    // -------------------------------------------------------------------------
    // TIER 1 — Başlangıç Yapıları
    // -------------------------------------------------------------------------
    'mining': Facility3dStructureSpec(
      facilityType: 'mining',
      structureTitle: 'Demir Madeni Giriş Tahkimatı',
      archetype: 'barracks_mine',
      primaryGlbPath: 'assets/models/props/Portcullis_HeavyIron.glb',
      fallbackGlbPaths: <String>[
        'assets/models/props/Portcullis_HeavyIron_LOD0.glb',
        'assets/models/environment/Column_Broken.glb',
        'assets/models/props/Flagstones_CrackedTile.glb',
      ],
      tier: 1,
      accentColor: AppColors.liquidGold,
      emissiveColor: Color(0xFFFFB300),
      runicGlyph: 'ᚠ', // Fehu - Wealth & Ore
      modelScale: 1.15,
      verticalOffset: -0.15,
      cameraDistance: 3.6,
      architecturalDescription:
          'Ağır dövme demir maden şaftı parmaklığı ve taş tahkimat kirişleri.',
    ),
    'quarry': Facility3dStructureSpec(
      facilityType: 'quarry',
      structureTitle: 'Granit Taş Ocağı Blokları',
      archetype: 'masonry',
      primaryGlbPath: 'assets/models/props/Flagstones_CrackedTile.glb',
      fallbackGlbPaths: <String>[
        'assets/models/props/Flagstones_CrackedTile_LOD0.glb',
        'assets/models/environment/Column_Broken.glb',
        'assets/models/props/GothicArch_Lancet.glb',
      ],
      tier: 1,
      accentColor: AppColors.mutedTitanium,
      emissiveColor: Color(0xFFB0BEC5),
      runicGlyph: 'ᚢ', // Uruz - Strength of Stone
      modelScale: 1.25,
      verticalOffset: -0.10,
      cameraDistance: 3.8,
      architecturalDescription:
          'Kırılmış PBR granit ve bazalt taş blokları, kadim taş yontma kaidesi.',
    ),
    'lumber_mill': Facility3dStructureSpec(
      facilityType: 'lumber_mill',
      structureTitle: 'Orman Kereste Atölyesi & Hızar',
      archetype: 'workshop',
      primaryGlbPath: 'assets/models/weapons/Axe_Double.glb',
      fallbackGlbPaths: <String>[
        'assets/models/weapons/Claymore.glb',
        'assets/models/props/Portcullis_HeavyIron.glb',
      ],
      tier: 1,
      accentColor: Color(0xFF8D6E63),
      emissiveColor: Color(0xFFA1887F),
      runicGlyph: 'ᚦ', // Thurisaz - Force & Chopping
      modelScale: 1.35,
      verticalOffset: 0.05,
      cameraDistance: 3.5,
      architecturalDescription:
          'Ağır çelik ormancı baltası ve dev meşe kütüklerini yontan odun atölyesi.',
    ),
    'clay_pit': Facility3dStructureSpec(
      facilityType: 'clay_pit',
      structureTitle: 'Hazine ve Seramik Kil Kasası',
      archetype: 'treasury',
      primaryGlbPath: 'assets/models/environment/Chest.glb',
      fallbackGlbPaths: <String>[
        'assets/models/environment/Chest_gold.glb',
        'assets/models/props/StoneAltar_Ritual.glb',
      ],
      tier: 1,
      accentColor: Color(0xFFD7CCC8),
      emissiveColor: Color(0xFFFFCC80),
      runicGlyph: 'ᚨ', // Ansuz - Crafting Wisdom
      modelScale: 1.20,
      verticalOffset: -0.05,
      cameraDistance: 3.4,
      architecturalDescription:
          'Seramik kil ve tuğla madenlerinin saklandığı demir takviyeli depolama sandığı.',
    ),
    'sand_quarry': Facility3dStructureSpec(
      facilityType: 'sand_quarry',
      structureTitle: 'Kristal Kum Sütunu & Havuzu',
      archetype: 'reservoir',
      primaryGlbPath: 'assets/models/environment/Column_Broken.glb',
      fallbackGlbPaths: <String>[
        'assets/models/environment/column-large.glb',
        'assets/models/props/Flagstones_CrackedTile.glb',
      ],
      tier: 1,
      accentColor: Color(0xFFFFE082),
      emissiveColor: Color(0xFFFFF59D),
      runicGlyph: 'ᚱ', // Raido - Flow of Sand & Journey
      modelScale: 1.20,
      verticalOffset: -0.20,
      cameraDistance: 3.7,
      architecturalDescription:
          'Eski cam kumu ve kuvars tortularının toplandığı çatlak mermer kolon sütunu.',
    ),

    // -------------------------------------------------------------------------
    // TIER 2 — Gelişmiş / Organik Yapılar
    // -------------------------------------------------------------------------
    'farming': Facility3dStructureSpec(
      facilityType: 'farming',
      structureTitle: 'Kutsal Hasat Kovanı & Tahıl Ambarı',
      archetype: 'granary',
      primaryGlbPath: 'assets/models/environment/altar-stone.glb',
      fallbackGlbPaths: <String>[
        'assets/models/props/StoneAltar_Ritual.glb',
        'assets/models/props/Flagstones_CrackedTile.glb',
      ],
      tier: 2,
      accentColor: AppColors.toxicNeon,
      emissiveColor: Color(0xFF76FF03),
      runicGlyph: 'ᛃ', // Jera - Harvest & Plenty
      modelScale: 1.10,
      verticalOffset: -0.10,
      cameraDistance: 3.6,
      architecturalDescription:
          'Altın buğday ve ejder meyvesi verimini artıran bereket sunak taşı.',
    ),
    'herb_garden': Facility3dStructureSpec(
      facilityType: 'herb_garden',
      structureTitle: 'Simya & Şifalı Bitki Serası',
      archetype: 'alchemy',
      primaryGlbPath: 'assets/models/props/StoneAltar_Ritual.glb',
      fallbackGlbPaths: <String>[
        'assets/models/props/StoneAltar_Ritual_LOD0.glb',
        'assets/models/environment/altar-stone.glb',
      ],
      tier: 2,
      accentColor: Color(0xFF69F0AE),
      emissiveColor: Color(0xFF00E676),
      runicGlyph: 'ᛁ', // Isa - Preservation
      modelScale: 1.15,
      verticalOffset: -0.15,
      cameraDistance: 3.5,
      architecturalDescription:
          'Nadir ay çiçeği ve ejder köklerinin damıtıldığı runik simya kürsüsü.',
    ),
    'ranch': Facility3dStructureSpec(
      facilityType: 'ranch',
      structureTitle: 'Süvari & Garnizon Hayvan Barınağı',
      archetype: 'barracks_stable',
      primaryGlbPath: 'assets/models/characters/Soldier.glb',
      fallbackGlbPaths: <String>[
        'assets/models/props/Portcullis_HeavyIron.glb',
        'assets/models/environment/crypt-large.glb',
      ],
      tier: 2,
      accentColor: Color(0xFF81C784),
      emissiveColor: Color(0xFFA5D6A7),
      runicGlyph: 'ᛖ', // Ehwaz - Steed & Beast
      modelScale: 1.10,
      verticalOffset: -0.25,
      cameraDistance: 3.8,
      architecturalDescription:
          'Savaş atları ve canavar derisi işleme garnizon muhafız nöbet kulesi.',
    ),
    'apiary': Facility3dStructureSpec(
      facilityType: 'apiary',
      structureTitle: 'Altın Bal Kovanı & Arılık Sunağı',
      archetype: 'apiary_vault',
      primaryGlbPath: 'assets/models/environment/fire-basket.glb',
      fallbackGlbPaths: <String>[
        'assets/models/props/Brazier_IronEmbers.glb',
        'assets/models/environment/Chest_gold.glb',
      ],
      tier: 2,
      accentColor: Color(0xFFFFD54F),
      emissiveColor: Color(0xFFFFE082),
      runicGlyph: 'ᚲ', // Kaun - Warmth of Amber
      modelScale: 1.20,
      verticalOffset: -0.10,
      cameraDistance: 3.5,
      architecturalDescription:
          'Kraliyet arı sütü ve ambrosia özünün damıtıldığı dövme altın tütsülük.',
    ),
    'mushroom_farm': Facility3dStructureSpec(
      facilityType: 'mushroom_farm',
      structureTitle: 'Karanlık Spor Mağarası & Mantarlık',
      archetype: 'crypt_cellar',
      primaryGlbPath: 'assets/models/props/Gargoyle_DarkStone.glb',
      fallbackGlbPaths: <String>[
        'assets/models/props/Gargoyle_DarkStone_LOD0.glb',
        'assets/models/environment/crypt-large.glb',
      ],
      tier: 2,
      accentColor: Color(0xFFBA68C8),
      emissiveColor: Color(0xFFCE93D8),
      runicGlyph: 'ᛈ', // Perthro - Hidden Growth
      modelScale: 1.15,
      verticalOffset: -0.15,
      cameraDistance: 3.6,
      architecturalDescription:
          'Karanlık taş gargoyle heykeliyle korunan parlayan mantar yetiştirme mahzeni.',
    ),

    // -------------------------------------------------------------------------
    // TIER 3 — İleri / Mistisizm & Kadim Harikalar
    // -------------------------------------------------------------------------
    'rune_mine': Facility3dStructureSpec(
      facilityType: 'rune_mine',
      structureTitle: 'Kadim Rün Madeni & Büyü Reaktörü',
      archetype: 'alchemy_arcane',
      primaryGlbPath: 'assets/models/props/StoneAltar_Ritual.glb',
      fallbackGlbPaths: <String>[
        'assets/models/props/StoneAltar_Ritual_LOD0.glb',
        'assets/models/environment/altar-stone.glb',
        'assets/models/aion2/aion2_gothic_dungeon_pillar.glb',
      ],
      tier: 3,
      accentColor: AppColors.accentCyan,
      emissiveColor: Color(0xFF00E5FF),
      runicGlyph: '🔮', // Arcane Rune Matrix
      modelScale: 1.25,
      verticalOffset: -0.15,
      cameraDistance: 3.5,
      architecturalDescription:
          'Ham runik kristalleri ve büyü çekirdeklerini eriten mistik rünik sunak.',
    ),
    'holy_spring': Facility3dStructureSpec(
      facilityType: 'holy_spring',
      structureTitle: 'Kutsal Şifa Kolonadı & Çeşmesi',
      archetype: 'sanctuary',
      primaryGlbPath: 'assets/models/props/GothicArch_Lancet.glb',
      fallbackGlbPaths: <String>[
        'assets/models/props/GothicArch_Lancet_LOD0.glb',
        'assets/models/environment/column-large.glb',
      ],
      tier: 3,
      accentColor: Color(0xFF40C4FF),
      emissiveColor: Color(0xFF80D8FF),
      runicGlyph: '⛲', // Holy Spring
      modelScale: 1.05,
      verticalOffset: -0.25,
      cameraDistance: 3.9,
      architecturalDescription:
          'Gotik sivri kemerli kutsal su tapınağı ve mana pınarı mimarisi.',
    ),
    'shadow_pit': Facility3dStructureSpec(
      facilityType: 'shadow_pit',
      structureTitle: 'Uçurum Gölge Mahzeni & Katakomp',
      archetype: 'catacombs',
      primaryGlbPath: 'assets/models/environment/crypt-large.glb',
      fallbackGlbPaths: <String>[
        'assets/models/props/Gargoyle_DarkStone.glb',
        'assets/models/props/Portcullis_HeavyIron.glb',
      ],
      tier: 3,
      accentColor: Color(0xFFD500F9),
      emissiveColor: Color(0xFFE040FB),
      runicGlyph: '🕳️', // Void Abyss
      modelScale: 0.95,
      verticalOffset: -0.20,
      cameraDistance: 4.1,
      architecturalDescription:
          'Karanlık esans ve gölge kristallerini toplayan devasa antik taş katakomp.',
    ),
    'elemental_forge': Facility3dStructureSpec(
      facilityType: 'elemental_forge',
      structureTitle: 'Kozmik Elementel Ocak & Demir Ocağı',
      archetype: 'forge',
      primaryGlbPath: 'assets/models/props/Brazier_IronEmbers.glb',
      fallbackGlbPaths: <String>[
        'assets/models/props/Brazier_IronEmbers_LOD0.glb',
        'assets/models/environment/fire-basket.glb',
        'assets/models/weapons/DamagedHelmet.glb',
      ],
      tier: 3,
      accentColor: AppColors.mysticRuby,
      emissiveColor: Color(0xFFFF3D00),
      runicGlyph: '🔥', // Primordial Fire
      modelScale: 1.30,
      verticalOffset: -0.10,
      cameraDistance: 3.5,
      architecturalDescription:
          'Kızgın demir kömürleri, akkor ateş ve efsanevi zırh döven element ocağı.',
    ),
    'time_well': Facility3dStructureSpec(
      facilityType: 'time_well',
      structureTitle: 'Kronos Zaman Dikilitaşı & Monolit',
      archetype: 'chrono_monolith',
      primaryGlbPath: 'assets/models/environment/pillar-obelisk.glb',
      fallbackGlbPaths: <String>[
        'assets/models/aion2/aion2_gothic_dungeon_pillar.glb',
        'assets/models/environment/column-large.glb',
      ],
      tier: 3,
      accentColor: Color(0xFFFFD700),
      emissiveColor: Color(0xFFFFEA00),
      runicGlyph: '⏳', // Eternal Time
      modelScale: 1.15,
      verticalOffset: -0.25,
      cameraDistance: 3.8,
      architecturalDescription:
          'Sonsuz zaman kumunu ve kronos esansını çeken göksel obelisk dikilitaşı.',
    ),

    // -------------------------------------------------------------------------
    // EKSTRA FANTEZİ ARŞETİPLERİ (Garnizon/Kışla, Hazine Dairesi, vb.)
    // -------------------------------------------------------------------------
    'barracks': Facility3dStructureSpec(
      facilityType: 'barracks',
      structureTitle: 'İmparatorluk Garnizon Kışlası',
      archetype: 'barracks',
      primaryGlbPath: 'assets/models/props/Portcullis_HeavyIron.glb',
      fallbackGlbPaths: <String>[
        'assets/models/characters/Soldier.glb',
        'assets/models/props/GothicArch_Lancet.glb',
      ],
      tier: 2,
      accentColor: AppColors.liquidGold,
      emissiveColor: Color(0xFFFFAB00),
      runicGlyph: 'ᛏ', // Tiwaz - Warrior Honor
      modelScale: 1.20,
      verticalOffset: -0.15,
      cameraDistance: 3.7,
      architecturalDescription:
          'Ağır demir parmaklıklı kale kapısı ve muhafız birliği talimgah kışlası.',
    ),
    'treasury': Facility3dStructureSpec(
      facilityType: 'treasury',
      structureTitle: 'Krallık Yüksek Hazine Kasası',
      archetype: 'treasury',
      primaryGlbPath: 'assets/models/environment/Chest_gold.glb',
      fallbackGlbPaths: <String>[
        'assets/models/environment/Chest.glb',
        'assets/models/props/StoneAltar_Ritual.glb',
      ],
      tier: 3,
      accentColor: AppColors.liquidGold,
      emissiveColor: Color(0xFFFFD700),
      runicGlyph: 'ᚠ', // Fehu - Golden Wealth
      modelScale: 1.25,
      verticalOffset: -0.10,
      cameraDistance: 3.4,
      architecturalDescription:
          'Saf altın varaklı, mücevher ve celestium rezervlerini koruyan kraliyet sandığı.',
    ),
    'forge': Facility3dStructureSpec(
      facilityType: 'forge',
      structureTitle: 'Kadim Demirci Ocağı',
      archetype: 'forge',
      primaryGlbPath: 'assets/models/props/Brazier_IronEmbers.glb',
      fallbackGlbPaths: <String>[
        'assets/models/weapons/DamagedHelmet.glb',
        'assets/models/environment/fire-basket.glb',
      ],
      tier: 2,
      accentColor: AppColors.mysticRuby,
      emissiveColor: Color(0xFFFF5722),
      runicGlyph: '🔥',
      modelScale: 1.30,
      verticalOffset: -0.10,
      cameraDistance: 3.5,
      architecturalDescription:
          'Döküm demir mangal, akkor korlar ve dövme silah ocak ünitesi.',
    ),
    'alchemy': Facility3dStructureSpec(
      facilityType: 'alchemy',
      structureTitle: 'Gizemli Simyager Laboratuvarı',
      archetype: 'alchemy',
      primaryGlbPath: 'assets/models/props/StoneAltar_Ritual.glb',
      fallbackGlbPaths: <String>[
        'assets/models/environment/altar-stone.glb',
      ],
      tier: 2,
      accentColor: AppColors.accentCyan,
      emissiveColor: Color(0xFF18FFFF),
      runicGlyph: '🔮',
      modelScale: 1.20,
      verticalOffset: -0.15,
      cameraDistance: 3.5,
      architecturalDescription:
          'Mistik iksirler ve rünik esansların damıtıldığı runik simya sunağı.',
    ),
  };

  /// Retrieves the 3D specification for a facility type, falling back to a default if unknown.
  static Facility3dStructureSpec getSpec(String facilityType) {
    final Facility3dStructureSpec? spec = _specs[facilityType];
    if (spec != null) return spec;

    // Default structure specification for unknown or custom facility
    return Facility3dStructureSpec(
      facilityType: facilityType,
      structureTitle: 'Kadim Mimari Yapı',
      archetype: 'generic_sanctum',
      primaryGlbPath: 'assets/models/props/GothicArch_Lancet.glb',
      fallbackGlbPaths: const <String>[
        'assets/models/props/StoneAltar_Ritual.glb',
        'assets/models/environment/Column_Broken.glb',
      ],
      tier: 1,
      accentColor: AppColors.liquidGold,
      emissiveColor: Color(0xFFFFB300),
      runicGlyph: '🏛️',
      modelScale: 1.10,
      verticalOffset: -0.15,
      cameraDistance: 3.7,
      architecturalDescription: 'Görkemli gotik taş sütunlu fantezi yapısı.',
    );
  }

  /// List of all mapped facility types.
  static List<String> get allFacilityTypes => _specs.keys.toList();
}

/// Global mesh loader and in-memory cache for facility 3D models.
class FacilityModelMeshLoader {
  FacilityModelMeshLoader._();

  static final FacilityModelMeshLoader instance = FacilityModelMeshLoader._();

  final Map<String, ParsedModelMesh> _meshCache = <String, ParsedModelMesh>{};
  final Map<String, Future<ParsedModelMesh?>> _inflightLoads =
      <String, Future<ParsedModelMesh?>>{};

  /// Loads the 3D model for a facility specification.
  /// Tries filesystem first (for test/CLI execution), then rootBundle asset bundle,
  /// followed by fallbacks. Caches result in memory for zero stutter on repeat access.
  Future<ParsedModelMesh?> loadFacilityMesh(Facility3dStructureSpec spec) async {
    final String cacheKey = spec.facilityType;
    if (_meshCache.containsKey(cacheKey)) {
      return _meshCache[cacheKey];
    }

    if (_inflightLoads.containsKey(cacheKey)) {
      return _inflightLoads[cacheKey];
    }

    final Future<ParsedModelMesh?> future = _performLoad(spec);
    _inflightLoads[cacheKey] = future;

    try {
      final ParsedModelMesh? mesh = await future;
      if (mesh != null) {
        _meshCache[cacheKey] = mesh;
      }
      return mesh;
    } finally {
      _inflightLoads.remove(cacheKey);
    }
  }

  Future<ParsedModelMesh?> _performLoad(Facility3dStructureSpec spec) async {
    final List<String> candidatePaths = <String>[
      spec.primaryGlbPath,
      ...spec.fallbackGlbPaths,
      'assets/models/props/StoneAltar_Ritual.glb',
      'assets/models/props/GothicArch_Lancet.glb',
      'assets/models/props/Portcullis_HeavyIron.glb',
      'assets/models/props/Brazier_IronEmbers.glb',
    ];

    for (final String path in candidatePaths) {
      final ParsedModelMesh? parsed = await _loadMeshFromPath(path);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  Future<ParsedModelMesh?> _loadMeshFromPath(String path) async {
    // 1. Try reading directly from filesystem (vital for tests, CLI, or desktop)
    try {
      final io.File file = io.File(path);
      if (file.existsSync()) {
        final Uint8List bytes = await file.readAsBytes();
        if (bytes.length >= 12) {
          return MeshAssetRegistry.instance.parser.parse(
            bytes: bytes,
            modelId: path,
            sourcePath: path,
          );
        }
      }
    } catch (_) {
      // Continue to asset bundle
    }

    // 2. Try loading via rootBundle
    try {
      final ByteData bd = await rootBundle.load(path);
      final Uint8List bytes = bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
      if (bytes.length >= 12) {
        return MeshAssetRegistry.instance.parser.parse(
          bytes: bytes,
          modelId: path,
          sourcePath: path,
        );
      }
    } catch (_) {
      // Continue to next candidate
    }

    return null;
  }

  /// Manually clears cached models to free memory.
  void clearCache() {
    _meshCache.clear();
  }
}
