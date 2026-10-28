import 'package:flutter/material.dart';
import '../routing/app_router.dart';

enum MoradonAtmosphereChoice {
  auto,
  twilight,
  nightMarket,
  siegeStorm,
  bloodMoon,
}

enum MoradonAtmospherePhase {
  twilight,
  nightMarket,
  siegeStorm,
  bloodMoon,
}

enum MoradonWeaponVisual {
  none,
  illusionSabre,
  twilightFang,
  imperialHalberd,
  crimsonAxe,
  aetherStaff,
}

enum MoradonPetVisual {
  none,
  solarPhoenix,
  shadowRaven,
  arcaneWisp,
  royalGriffin,
}

enum MoradonMountVisual {
  none,
  crimsonBolt,
  shadowMane;

  bool get isMounted => this != MoradonMountVisual.none;

  double get speedMultiplier => isMounted ? 1.34 : 1.0;

  String get labelTr => switch (this) {
        MoradonMountVisual.none => 'Yaya',
        MoradonMountVisual.crimsonBolt => 'Kızıl Yıldırım',
        MoradonMountVisual.shadowMane => 'Gölge Yele',
      };

  String get assetPath => switch (this) {
        MoradonMountVisual.none => '',
        MoradonMountVisual.crimsonBolt =>
          'assets/moradon/steed_crimson_bolt.png',
        MoradonMountVisual.shadowMane =>
          'assets/moradon/steed_shadow_mane.png',
      };

  Color get accentColor => switch (this) {
        MoradonMountVisual.none => const Color(0xFF94A3B8),
        MoradonMountVisual.crimsonBolt => const Color(0xFFF97316),
        MoradonMountVisual.shadowMane => const Color(0xFF38BDF8),
      };
}

class MoradonEmoteBubble {
  final String id;
  final String emoji;
  final String labelTr;
  final Color accentColor;
  final DateTime createdAt;
  final DateTime expiresAt;

  const MoradonEmoteBubble({
    required this.id,
    required this.emoji,
    required this.labelTr,
    required this.accentColor,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

const List<({String id, String emoji, String labelTr, Color accent})>
    kMoradonQuickEmotes =
    <({String id, String emoji, String labelTr, Color accent})>[
  (
    id: 'victory',
    emoji: '⚔️',
    labelTr: 'ZAFER BİZİM!',
    accent: Color(0xFFFBBF24),
  ),
  (
    id: 'sovereign',
    emoji: '👑',
    labelTr: 'BAŞKENT HÜKÜMDARI!',
    accent: Color(0xFFFDE047),
  ),
  (
    id: 'challenge',
    emoji: '🔥',
    labelTr: 'DÜELLOYA GEL!',
    accent: Color(0xFFF97316),
  ),
  (
    id: 'prestige',
    emoji: '💎',
    labelTr: '+10 PRESTİJ ŞOV!',
    accent: Color(0xFF38BDF8),
  ),
];

class MoradonWorldBossState {
  final bool isActive;
  final String name;
  final String title;
  final double x;
  final double y;
  final int currentHp;
  final int maxHp;
  final int myContribution;
  final String mvpUsername;
  final DateTime? lastHitAt;
  final DateTime? defeatedAt;

  const MoradonWorldBossState({
    this.isActive = false,
    this.name = 'Kadim Yıkım Tiranı',
    this.title = 'Meydan Dünya Boss Baskını',
    this.x = 3345.0,
    this.y = 2685.0,
    this.currentHp = 250000,
    this.maxHp = 250000,
    this.myContribution = 0,
    this.mvpUsername = 'Gölge Sancak',
    this.lastHitAt,
    this.defeatedAt,
  });

  double get hpRatio =>
      maxHp <= 0 ? 0.0 : (currentHp / maxHp).clamp(0.0, 1.0);

  bool get isDefeated => currentHp <= 0;

  MoradonWorldBossState copyWith({
    bool? isActive,
    String? name,
    String? title,
    double? x,
    double? y,
    int? currentHp,
    int? maxHp,
    int? myContribution,
    String? mvpUsername,
    DateTime? lastHitAt,
    DateTime? defeatedAt,
    bool clearDefeatedAt = false,
  }) {
    return MoradonWorldBossState(
      isActive: isActive ?? this.isActive,
      name: name ?? this.name,
      title: title ?? this.title,
      x: x ?? this.x,
      y: y ?? this.y,
      currentHp: currentHp ?? this.currentHp,
      maxHp: maxHp ?? this.maxHp,
      myContribution: myContribution ?? this.myContribution,
      mvpUsername: mvpUsername ?? this.mvpUsername,
      lastHitAt: lastHitAt ?? this.lastHitAt,
      defeatedAt:
          clearDefeatedAt ? null : (defeatedAt ?? this.defeatedAt),
    );
  }
}

/// Live shard/channel directory entry for 10,000+ CCU horizontal scaling.
class MoradonChannelInfo {
  final int channelId;
  final int onlineCount;
  final int capacity;
  final String status; // 'normal' | 'crowded' | 'full'

  const MoradonChannelInfo({
    required this.channelId,
    required this.onlineCount,
    this.capacity = 200,
    this.status = 'normal',
  });

  String get label => 'Moradon-$channelId';

  double get loadRatio =>
      capacity > 0 ? (onlineCount / capacity).clamp(0.0, 1.0) : 0.0;

  String get statusLabelTr {
    if (status == 'full' || onlineCount >= 180) return 'Dolu';
    if (status == 'crowded' || onlineCount >= 110) return 'Yoğun';
    return 'Akıcı';
  }

  Color get statusColor {
    if (status == 'full' || onlineCount >= 180) return const Color(0xFFEF4444);
    if (status == 'crowded' || onlineCount >= 110) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFF4ADE80);
  }

  factory MoradonChannelInfo.fromJson(Map<String, dynamic> json) {
    return MoradonChannelInfo(
      channelId: (json['channel_id'] as num?)?.toInt() ?? 1,
      onlineCount: (json['online_count'] as num?)?.toInt() ?? 0,
      capacity: (json['capacity'] as num?)?.toInt() ?? 200,
      status: (json['status'] ?? 'normal').toString(),
    );
  }
}

/// Named MMO districts across the 6400 x 3600 Mega-Capital with 1-tap Fast-Travel points.
class MoradonDistrictZone {
  final String id;
  final String name;
  final String subtitle;
  final String emoji;
  final double centerX;
  final double centerY;
  final double fastTravelX;
  final double fastTravelY;
  final Color accentColor;

  const MoradonDistrictZone({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.emoji,
    required this.centerX,
    required this.centerY,
    required this.fastTravelX,
    required this.fastTravelY,
    required this.accentColor,
  });
}

const List<MoradonDistrictZone> kMoradonDistricts = <MoradonDistrictZone>[
  MoradonDistrictZone(
    id: 'pantheon_plaza',
    name: 'Merkez Pantheon',
    subtitle: 'Obsidyen Çeşme & Talim Meydanı',
    emoji: '👑',
    centerX: 3200,
    centerY: 2130,
    fastTravelX: 3200,
    fastTravelY: 2625,
    accentColor: Color(0xFFFBBF24),
  ),
  MoradonDistrictZone(
    id: 'northern_bastion',
    name: 'Kuzey Zindan Geçidi',
    subtitle: '7 Zindan Bölgesi & Kuşatma Kapısı',
    emoji: '🌀',
    centerX: 3200,
    centerY: 880,
    fastTravelX: 3200,
    fastTravelY: 1160,
    accentColor: Color(0xFF38BDF8),
  ),
  MoradonDistrictZone(
    id: 'western_forge',
    name: 'Batı Cehennem Ocağı',
    subtitle: '+10 Magma Ocağı & Zanaat',
    emoji: '🔥',
    centerX: 1340,
    centerY: 1960,
    fastTravelX: 1560,
    fastTravelY: 2010,
    accentColor: Color(0xFFF97316),
  ),
  MoradonDistrictZone(
    id: 'royal_treasury',
    name: 'Kraliyet Mahzeni',
    subtitle: 'Gotik Banka Kasası & Tesisler',
    emoji: '🏦',
    centerX: 1680,
    centerY: 1290,
    fastTravelX: 1940,
    fastTravelY: 1440,
    accentColor: Color(0xFF60A5FA),
  ),
  MoradonDistrictZone(
    id: 'grand_bazaar_district',
    name: 'Doğu Zindan Kemeri',
    subtitle: 'Karanlık Kemer Pazarı & Tezgahlar',
    emoji: '⚖️',
    centerX: 5060,
    centerY: 1960,
    fastTravelX: 4800,
    fastTravelY: 1980,
    accentColor: Color(0xFF34D399),
  ),
  MoradonDistrictZone(
    id: 'war_colosseum',
    name: 'Kızıl Savaş Kapısı',
    subtitle: 'Bahisli PvP & Lonca Savaşları',
    emoji: '⚔️',
    centerX: 4760,
    centerY: 1120,
    fastTravelX: 4550,
    fastTravelY: 1300,
    accentColor: Color(0xFFF87171),
  ),
  MoradonDistrictZone(
    id: 'southern_tavern',
    name: 'Gotik Han & Hipodrom',
    subtitle: 'Gece Salonu, At Yarışı & Kasa Açma',
    emoji: '🐎',
    centerX: 4880,
    centerY: 2860,
    fastTravelX: 4480,
    fastTravelY: 2820,
    accentColor: Color(0xFFE879F9),
  ),
  MoradonDistrictZone(
    id: 'guard_barracks',
    name: 'Zindan Muhafız Kulesi',
    subtitle: 'Görevler, Kodex, Hastane & Cezaevi',
    emoji: '🛡️',
    centerX: 1960,
    centerY: 2780,
    fastTravelX: 2210,
    fastTravelY: 2810,
    accentColor: Color(0xFFC084FC),
  ),
];

MoradonDistrictZone resolveMoradonDistrict(double x, double y) {
  MoradonDistrictZone best = kMoradonDistricts.first;
  double bestDistSq = double.infinity;
  for (final MoradonDistrictZone z in kMoradonDistricts) {
    final double dx = x - z.centerX;
    final double dy = y - z.centerY;
    final double dSq = dx * dx + dy * dy;
    if (dSq < bestDistSq) {
      bestDistSq = dSq;
      best = z;
    }
  }
  return best;
}

/// O(1) cell-bucketed Spatial Hash Grid for 60 FPS camera frustum culling
/// when hundreds of entities populate the 6400 x 3600 Mega-Capital.
class MoradonSpatialGrid<T> {
  final double worldWidth;
  final double worldHeight;
  final double cellSize;
  late final int _cols;
  late final int _rows;
  late final List<List<T>?> _buckets;

  MoradonSpatialGrid({
    required this.worldWidth,
    required this.worldHeight,
    this.cellSize = 400.0,
  }) {
    _cols = (worldWidth / cellSize).ceil().clamp(1, 256);
    _rows = (worldHeight / cellSize).ceil().clamp(1, 256);
    _buckets = List<List<T>?>.filled(_cols * _rows, null);
  }

  void insert(double x, double y, T item) {
    final int cx = (x / cellSize).floor().clamp(0, _cols - 1);
    final int cy = (y / cellSize).floor().clamp(0, _rows - 1);
    final int idx = cy * _cols + cx;
    (_buckets[idx] ??= <T>[]).add(item);
  }

  List<T> queryRect(Rect worldRect) {
    final int minCx = (worldRect.left / cellSize).floor().clamp(0, _cols - 1);
    final int maxCx = (worldRect.right / cellSize).floor().clamp(0, _cols - 1);
    final int minCy = (worldRect.top / cellSize).floor().clamp(0, _rows - 1);
    final int maxCy = (worldRect.bottom / cellSize).floor().clamp(0, _rows - 1);
    final List<T> out = <T>[];
    for (int cy = minCy; cy <= maxCy; cy++) {
      final int rowBase = cy * _cols;
      for (int cx = minCx; cx <= maxCx; cx++) {
        final List<T>? bucket = _buckets[rowBase + cx];
        if (bucket != null) {
          out.addAll(bucket);
        }
      }
    }
    return out;
  }
}

class MoradonCelebrationEvent {
  final String id;
  final String username;
  final String itemName;
  final int enhancementLevel; // 8..10 for forge, 0 for legendary crate drop
  final String originNpcId;
  final DateTime startedAt;
  final DateTime expiresAt;

  const MoradonCelebrationEvent({
    required this.id,
    required this.username,
    required this.itemName,
    required this.enhancementLevel,
    required this.originNpcId,
    required this.startedAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isCrateDrop => enhancementLevel <= 0;
}

class MoradonPatrolGuard {
  final String id;
  final String name;
  final String title;
  final int totalPower;
  final List<Offset> waypoints;
  final int targetWaypointIndex;
  final double x;
  final double y;
  final bool facingRight;
  final bool facingBack;
  final double walkPhase;

  const MoradonPatrolGuard({
    required this.id,
    required this.name,
    required this.title,
    this.totalPower = 45000,
    required this.waypoints,
    required this.targetWaypointIndex,
    required this.x,
    required this.y,
    this.facingRight = true,
    this.facingBack = false,
    this.walkPhase = 0.0,
  });

  MoradonPatrolGuard copyWith({
    int? totalPower,
    int? targetWaypointIndex,
    double? x,
    double? y,
    bool? facingRight,
    bool? facingBack,
    double? walkPhase,
  }) {
    return MoradonPatrolGuard(
      id: id,
      name: name,
      title: title,
      totalPower: totalPower ?? this.totalPower,
      waypoints: waypoints,
      targetWaypointIndex: targetWaypointIndex ?? this.targetWaypointIndex,
      x: x ?? this.x,
      y: y ?? this.y,
      facingRight: facingRight ?? this.facingRight,
      facingBack: facingBack ?? this.facingBack,
      walkPhase: walkPhase ?? this.walkPhase,
    );
  }
}

class MoradonRacehorseProp {
  final String id;
  final String name;
  final String pedigree;
  final String assetPath;
  final double x;
  final double y;
  final bool facingRight;
  final Color accentColor;

  const MoradonRacehorseProp({
    required this.id,
    required this.name,
    required this.pedigree,
    required this.assetPath,
    required this.x,
    required this.y,
    required this.facingRight,
    required this.accentColor,
  });
}

const List<MoradonRacehorseProp> kTavernRacehorses = <MoradonRacehorseProp>[
  MoradonRacehorseProp(
    id: 'steed_shadow_mane',
    name: 'Gölge Yelesi',
    pedigree: 'Han Hipodrom Favorisi',
    assetPath: 'assets/moradon/steed_shadow_mane.png',
    x: 4180,
    y: 2680,
    facingRight: true,
    accentColor: Color(0xFFC084FC),
  ),
  MoradonRacehorseProp(
    id: 'steed_crimson_bolt',
    name: 'Kızıl Yıldırım',
    pedigree: 'Kraliyet Koşu Şampiyonu',
    assetPath: 'assets/moradon/steed_crimson_bolt.png',
    x: 4380,
    y: 2460,
    facingRight: false,
    accentColor: Color(0xFFF59E0B),
  ),
];

/// Tall 2.5D Blender-rendered architectural landmarks sorted by Y-depth so players physically walk behind them.
class MoradonOcclusionProp {
  final String id;
  final String assetPath;
  final double x;
  final double y; // Ground base Y (used for Y-depth sorting)
  final double width;
  final double height;
  final Color? lightColor;
  final Offset? lightOffset;

  const MoradonOcclusionProp({
    required this.id,
    required this.assetPath,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.lightColor,
    this.lightOffset,
  });
}

const List<MoradonOcclusionProp> kCitadelOcclusionProps =
    <MoradonOcclusionProp>[
  // 1. Northern Chained Dungeon Gate Avenue — Twin Gothic Gargoyle Banner Pillars
  MoradonOcclusionProp(
    id: 'occ_north_banner_l',
    assetPath: 'assets/moradon/prop_gothic_banner_pillar.png',
    x: 2820.0,
    y: 1340.0,
    width: 116.0,
    height: 322.0,
    lightColor: Color(0xFFFB923C),
    lightOffset: Offset(0, -190),
  ),
  MoradonOcclusionProp(
    id: 'occ_north_banner_r',
    assetPath: 'assets/moradon/prop_gothic_banner_pillar.png',
    x: 3580.0,
    y: 1340.0,
    width: 116.0,
    height: 322.0,
    lightColor: Color(0xFFFB923C),
    lightOffset: Offset(0, -190),
  ),

  // 2. Central Obsidian Fountain Courtyard — 4 Y-Sorted Gothic Lantern Colonnade Pillars
  MoradonOcclusionProp(
    id: 'occ_plaza_lantern_nw',
    assetPath: 'assets/moradon/prop_gothic_lantern_pillar.png',
    x: 2580.0,
    y: 1820.0,
    width: 96.0,
    height: 356.0,
    lightColor: Color(0xFFFBBF24),
    lightOffset: Offset(0, -245),
  ),
  MoradonOcclusionProp(
    id: 'occ_plaza_lantern_ne',
    assetPath: 'assets/moradon/prop_gothic_lantern_pillar.png',
    x: 3820.0,
    y: 1820.0,
    width: 96.0,
    height: 356.0,
    lightColor: Color(0xFFFBBF24),
    lightOffset: Offset(0, -245),
  ),
  MoradonOcclusionProp(
    id: 'occ_plaza_lantern_sw',
    assetPath: 'assets/moradon/prop_gothic_lantern_pillar.png',
    x: 2580.0,
    y: 2360.0,
    width: 96.0,
    height: 356.0,
    lightColor: Color(0xFFFBBF24),
    lightOffset: Offset(0, -245),
  ),
  MoradonOcclusionProp(
    id: 'occ_plaza_lantern_se',
    assetPath: 'assets/moradon/prop_gothic_lantern_pillar.png',
    x: 3820.0,
    y: 2360.0,
    width: 96.0,
    height: 356.0,
    lightColor: Color(0xFFFBBF24),
    lightOffset: Offset(0, -245),
  ),

  // 3. West Hellfire Forge & East Dark-Stone Bazaar Avenue Banner Pillars
  MoradonOcclusionProp(
    id: 'occ_west_avenue_banner',
    assetPath: 'assets/moradon/prop_gothic_banner_pillar.png',
    x: 1980.0,
    y: 2040.0,
    width: 116.0,
    height: 322.0,
    lightColor: Color(0xFFFB923C),
    lightOffset: Offset(0, -190),
  ),
  MoradonOcclusionProp(
    id: 'occ_east_avenue_banner',
    assetPath: 'assets/moradon/prop_gothic_banner_pillar.png',
    x: 4420.0,
    y: 2040.0,
    width: 116.0,
    height: 322.0,
    lightColor: Color(0xFFFB923C),
    lightOffset: Offset(0, -190),
  ),
];

class MoradonNpcAction {
  final String label;
  final String subtitle;
  final String emoji;
  final String route;

  const MoradonNpcAction({
    required this.label,
    required this.subtitle,
    required this.emoji,
    required this.route,
  });
}

class MoradonNpcDefinition {
  final String id;
  final String name;
  final String title;
  final String badgeEmoji;
  final String quote;
  final double x;
  final double y;
  final double interactionRadius;
  final String assetPath;
  final double spriteSize;
  final double? spriteHeight;
  final bool isArchitecturalZone;
  final double labelOffsetY;
  final bool facingRight;
  final Color accentColor;
  final List<MoradonNpcAction> actions;

  const MoradonNpcDefinition({
    required this.id,
    required this.name,
    required this.title,
    this.badgeEmoji = '✦',
    required this.quote,
    required this.x,
    required this.y,
    this.interactionRadius = 235.0,
    required this.assetPath,
    this.spriteSize = 86.0,
    this.spriteHeight = 118.0,
    this.isArchitecturalZone = false,
    this.labelOffsetY = 0.0,
    this.facingRight = true,
    required this.accentColor,
    required this.actions,
  });
}

class MoradonPlayerPresence {
  final String userId;
  final String username;
  final String characterClass;
  final String? guildName;
  final String? cosmeticTitle;
  final int level;
  final int totalPower;
  final double x;
  final double y;
  final double targetX;
  final double targetY;
  final bool facingRight;
  final bool facingBack;
  final double walkPhase;
  final bool isMerchant;
  final String? merchantTitle;
  final int weaponGlowLevel;
  final MoradonWeaponVisual weaponVisual;
  final String? weaponLabel;
  final MoradonPetVisual petVisual;
  final bool isAmbientBot;
  final double attackProgress;
  final int comboStage;

  const MoradonPlayerPresence({
    required this.userId,
    required this.username,
    required this.characterClass,
    this.guildName,
    this.cosmeticTitle,
    this.level = 1,
    this.totalPower = 100,
    required this.x,
    required this.y,
    required this.targetX,
    required this.targetY,
    this.facingRight = true,
    this.facingBack = false,
    this.walkPhase = 0.0,
    this.isMerchant = false,
    this.merchantTitle,
    this.weaponGlowLevel = 7,
    this.weaponVisual = MoradonWeaponVisual.none,
    this.weaponLabel,
    this.petVisual = MoradonPetVisual.none,
    this.isAmbientBot = false,
    this.attackProgress = 0.0,
    this.comboStage = 0,
  });

  MoradonPlayerPresence copyWith({
    String? username,
    String? characterClass,
    String? guildName,
    String? cosmeticTitle,
    int? level,
    int? totalPower,
    double? x,
    double? y,
    double? targetX,
    double? targetY,
    bool? facingRight,
    bool? facingBack,
    double? walkPhase,
    bool? isMerchant,
    String? merchantTitle,
    int? weaponGlowLevel,
    MoradonWeaponVisual? weaponVisual,
    String? weaponLabel,
    MoradonPetVisual? petVisual,
    double? attackProgress,
    int? comboStage,
  }) {
    return MoradonPlayerPresence(
      userId: userId,
      username: username ?? this.username,
      characterClass: characterClass ?? this.characterClass,
      guildName: guildName ?? this.guildName,
      cosmeticTitle: cosmeticTitle ?? this.cosmeticTitle,
      level: level ?? this.level,
      totalPower: totalPower ?? this.totalPower,
      x: x ?? this.x,
      y: y ?? this.y,
      targetX: targetX ?? this.targetX,
      targetY: targetY ?? this.targetY,
      facingRight: facingRight ?? this.facingRight,
      facingBack: facingBack ?? this.facingBack,
      walkPhase: walkPhase ?? this.walkPhase,
      isMerchant: isMerchant ?? this.isMerchant,
      merchantTitle: merchantTitle ?? this.merchantTitle,
      weaponGlowLevel: weaponGlowLevel ?? this.weaponGlowLevel,
      weaponVisual: weaponVisual ?? this.weaponVisual,
      weaponLabel: weaponLabel ?? this.weaponLabel,
      petVisual: petVisual ?? this.petVisual,
      isAmbientBot: isAmbientBot,
      attackProgress: attackProgress ?? this.attackProgress,
      comboStage: comboStage ?? this.comboStage,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'user_id': userId,
      'username': username,
      'character_class': characterClass,
      'guild_name': guildName,
      'cosmetic_title': cosmeticTitle,
      'level': level,
      'total_power': totalPower,
      'x': x.round(),
      'y': y.round(),
      'facing_right': facingRight,
      'facing_back': facingBack,
      'is_merchant': isMerchant,
      'merchant_title': merchantTitle,
      'weapon_glow_level': weaponGlowLevel,
      'weapon_visual': weaponVisual.name,
      'weapon_label': weaponLabel,
      'pet_visual': petVisual.name,
    };
  }

  factory MoradonPlayerPresence.fromJson(Map<String, dynamic> json) {
    final double px = (json['x'] as num?)?.toDouble() ?? 3200.0;
    final double py = (json['y'] as num?)?.toDouble() ?? 2360.0;
    final String wRaw = (json['weapon_visual'] ?? '').toString();
    final String pRaw = (json['pet_visual'] ?? '').toString();
    MoradonWeaponVisual wVis = MoradonWeaponVisual.none;
    for (final MoradonWeaponVisual v in MoradonWeaponVisual.values) {
      if (v.name == wRaw) {
        wVis = v;
        break;
      }
    }
    MoradonPetVisual pVis = MoradonPetVisual.none;
    for (final MoradonPetVisual v in MoradonPetVisual.values) {
      if (v.name == pRaw) {
        pVis = v;
        break;
      }
    }
    return MoradonPlayerPresence(
      userId: (json['user_id'] ?? '').toString(),
      username: (json['username'] ?? 'Gezgin').toString(),
      characterClass: (json['character_class'] ?? 'savasci').toString(),
      guildName: json['guild_name'] as String?,
      cosmeticTitle: json['cosmetic_title'] as String?,
      level: (json['level'] as num?)?.toInt() ?? 1,
      totalPower: (json['total_power'] as num?)?.toInt() ?? 100,
      x: px,
      y: py,
      targetX: px,
      targetY: py,
      facingRight: json['facing_right'] as bool? ?? true,
      facingBack: json['facing_back'] as bool? ?? false,
      isMerchant: json['is_merchant'] as bool? ?? false,
      merchantTitle: json['merchant_title'] as String?,
      weaponGlowLevel: (json['weapon_glow_level'] as num?)?.toInt() ?? 7,
      weaponVisual: wVis,
      weaponLabel: json['weapon_label'] as String?,
      petVisual: pVis,
      isAmbientBot: false,
    );
  }
}

class MoradonChatBubble {
  final String userId;
  final String username;
  final String message;
  final DateTime expiresAt;

  const MoradonChatBubble({
    required this.userId,
    required this.username,
    required this.message,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Gölge Krallığı Mega-Başkent Meydanı yapıları ve NPC'leri (Blender 5.0 16:9 Dünya: 6400 x 3600).
const List<MoradonNpcDefinition> kMoradonNpcs = <MoradonNpcDefinition>[
  MoradonNpcDefinition(
    id: 'monument_center',
    name: 'Gölge Krallığı Anıtı',
    title: 'Pantheon & Lonca Anıtı',
    badgeEmoji: '👑',
    quote:
        'Başkent avlusuna hoş geldin savaşçı! Adını Pantheon taşlarına kazımaya hazır mısın?',
    x: 3200,
    y: 2130,
    interactionRadius: 620,
    isArchitecturalZone: true,
    labelOffsetY: 360,
    spriteSize: 1040,
    spriteHeight: 1044,
    assetPath: 'assets/moradon/monument_center.png',
    accentColor: Color(0xFFFBBF24),
    actions: <MoradonNpcAction>[
      MoradonNpcAction(
        emoji: '🏆',
        label: 'Pantheon Sıralaması',
        subtitle: 'En güçlü savaşçıları ve loncaları gör',
        route: AppRoutes.leaderboard,
      ),
      MoradonNpcAction(
        emoji: '👑',
        label: 'Savaş Geçidi & Sezon',
        subtitle: 'BPP ilerlemesi, L20 rozeti ve sezon ödülleri',
        route: AppRoutes.season,
      ),
      MoradonNpcAction(
        emoji: '🎖️',
        label: 'İtibar & Fraksiyonlar',
        subtitle: 'Krallık itibar kademelerini ve ödüllerini incele',
        route: AppRoutes.reputation,
      ),
      MoradonNpcAction(
        emoji: '🏛️',
        label: 'Lonca Anıtı',
        subtitle: 'Kaynak bağışla ve kutsal anıtı yükselt',
        route: AppRoutes.guildMonument,
      ),
    ],
  ),
  MoradonNpcDefinition(
    id: 'magic_anvil',
    name: 'Baş Demirci Kaelen',
    title: 'Cehennem Ocağı & Zanaat',
    badgeEmoji: '🔥',
    quote:
        'Ocağımda nice +9 Imperial Halberd ve Twilight Fang dövüldü... Yüksek Sınıf Parşömen ve Kutsal Rune hazırsa yaklaş!',
    x: 1340,
    y: 1960,
    interactionRadius: 270,
    spriteSize: 84,
    spriteHeight: 120,
    facingRight: true,
    assetPath: 'assets/moradon/npc_master_kaelen.png',
    accentColor: Color(0xFFF97316),
    actions: <MoradonNpcAction>[
      MoradonNpcAction(
        emoji: '🔥',
        label: 'Eşya Yükseltme (+Basma)',
        subtitle: 'Parşömen ve Rune kullanarak +10\'a yükselt',
        route: AppRoutes.enhancement,
      ),
      MoradonNpcAction(
        emoji: '⚒️',
        label: 'Üretim Atölyesi (Zanaat)',
        subtitle: 'Tesis cevherlerini birleştirip nadir teçhizat üret',
        route: AppRoutes.crafting,
      ),
    ],
  ),
  MoradonNpcDefinition(
    id: 'teleport_gate',
    name: 'Zindan & Kuşatma Geçidi',
    title: '7 Bölge Sefer Kapısı',
    badgeEmoji: '🌀',
    quote:
        'Gölgeli Orman\'dan Fırtına Dağı ve Kırık Gökyüzü\'ne uzanan 7 zindan bölgesi ardımda bekliyor.',
    x: 3200,
    y: 940,
    interactionRadius: 360,
    isArchitecturalZone: true,
    labelOffsetY: 130,
    spriteSize: 420,
    spriteHeight: 130,
    assetPath: '',
    accentColor: Color(0xFF38BDF8),
    actions: <MoradonNpcAction>[
      MoradonNpcAction(
        emoji: '🏰',
        label: 'Zindan Seferleri',
        subtitle: 'Gölgeli Orman\'dan Efsanevi Tehlikeler\'e loot topla',
        route: AppRoutes.dungeon,
      ),
      MoradonNpcAction(
        emoji: '⚔️',
        label: 'Zindan Kuşatması',
        subtitle: 'Prime saatlerde slot tut ve hakimiyet kur',
        route: AppRoutes.dungeonSiegeHub,
      ),
    ],
  ),
  MoradonNpcDefinition(
    id: 'inn_hostess',
    name: 'Kasa Muhafızı Mira',
    title: 'Kraliyet Bankası & Tesis Ağı',
    badgeEmoji: '🏦',
    quote:
        'Altınlarını, Saf Celestium cevherlerini ve efsanevi teçhizatını kasada güvenle sakla.',
    x: 1680,
    y: 1290,
    interactionRadius: 265,
    spriteSize: 82,
    spriteHeight: 118,
    facingRight: true,
    assetPath: 'assets/moradon/npc_master_mira.png',
    accentColor: Color(0xFF60A5FA),
    actions: <MoradonNpcAction>[
      MoradonNpcAction(
        emoji: '🏦',
        label: 'Kraliyet Bankası',
        subtitle: 'Altın ve eşya kasası işlemlerini yönet',
        route: AppRoutes.bank,
      ),
      MoradonNpcAction(
        emoji: '🎒',
        label: 'Envanter & Teçhizat',
        subtitle: 'Kuşandığın silah, zırh ve iksirleri düzenle',
        route: AppRoutes.inventory,
      ),
      MoradonNpcAction(
        emoji: '🏭',
        label: 'Üretim Tesisleri',
        subtitle: 'Maden, taş ocağı ve pasif kaynak hattını yönet',
        route: AppRoutes.facilities,
      ),
    ],
  ),
  MoradonNpcDefinition(
    id: 'grand_bazaar',
    name: 'Baş Tüccar Veyron',
    title: 'Oyuncu Pazarı & Gece Pazarı',
    badgeEmoji: '⚖️',
    quote:
        'Gölge Ekonomisinde her eşyanın bir bedeli vardır! Pazar ilanlarını gez, takas yap veya 20:00 Gece Pazarını yakala.',
    x: 5060,
    y: 1960,
    interactionRadius: 270,
    spriteSize: 78,
    spriteHeight: 118,
    facingRight: false,
    assetPath: 'assets/moradon/npc_master_veyron.png',
    accentColor: Color(0xFF34D399),
    actions: <MoradonNpcAction>[
      MoradonNpcAction(
        emoji: '⚖️',
        label: 'Oyuncu Pazarı',
        subtitle: 'Diğer oyuncuların satışa çıkardığı eşyalar',
        route: AppRoutes.market,
      ),
      MoradonNpcAction(
        emoji: '🤝',
        label: 'Oyuncuyla Takas (Ticaret)',
        subtitle: 'Birebir güvenli eşya ve altın takası',
        route: AppRoutes.trade,
      ),
      MoradonNpcAction(
        emoji: '🌙',
        label: 'Mağaza & Gece Pazarı',
        subtitle: 'Enerji iksiri, parşömen ve 20:00–22:00 özel teklifler',
        route: AppRoutes.shop,
      ),
    ],
  ),
  MoradonNpcDefinition(
    id: 'arena_clan',
    name: 'Savaş Lordu Draven',
    title: 'Bahisli Arena & Lonca Savaşı',
    badgeEmoji: '⚔️',
    quote:
        'Nemesis rakibin dışarıda bekliyor! Bahisli Arena\'da çarpış veya loncanla bölge saldırısına katıl.',
    x: 4760,
    y: 1120,
    interactionRadius: 270,
    spriteSize: 96,
    spriteHeight: 122,
    facingRight: false,
    assetPath: 'assets/moradon/npc_master_draven.png',
    accentColor: Color(0xFFF87171),
    actions: <MoradonNpcAction>[
      MoradonNpcAction(
        emoji: '🗡️',
        label: 'PvP & Bahisli Arena',
        subtitle: 'Düello at, Nemesis intikamı al ve havuzu kazan',
        route: AppRoutes.pvp,
      ),
      MoradonNpcAction(
        emoji: '🛡️',
        label: 'Lonca Merkezi & Klinik',
        subtitle: 'Loncana katıl, kasa ve Lonca Kliniğini yönet',
        route: AppRoutes.guild,
      ),
      MoradonNpcAction(
        emoji: '🔥',
        label: 'Lonca Savaşı & Turnuva',
        subtitle: 'Bölge haritası, savunma hattı ve haftalık turnuva',
        route: AppRoutes.guildWar,
      ),
    ],
  ),
  MoradonNpcDefinition(
    id: 'guard_captain',
    name: 'Muhafız Komutanı Alaric',
    title: 'Görevler, Kodex & Asayiş',
    badgeEmoji: '📜',
    quote:
        'Günlük görevlerini tamamla, Kodex koleksiyonunu büyüt; yaralanırsan Hastane, şüphe artarsa Cezaevi kapısı yakın!',
    x: 1960,
    y: 2780,
    interactionRadius: 265,
    spriteSize: 74,
    spriteHeight: 120,
    facingRight: true,
    assetPath: 'assets/moradon/npc_master_alaric.png',
    accentColor: Color(0xFFC084FC),
    actions: <MoradonNpcAction>[
      MoradonNpcAction(
        emoji: '📜',
        label: 'Görevler',
        subtitle: 'Günlük ve haftalık hedefleri tamamla, ödül al',
        route: AppRoutes.quests,
      ),
      MoradonNpcAction(
        emoji: '📖',
        label: 'Eşya & Canavar Kodexi',
        subtitle: 'Keşif kilometre taşlarını ve kalıcı bonusları topla',
        route: AppRoutes.codex,
      ),
      MoradonNpcAction(
        emoji: '🏥',
        label: 'Hastane & Tedavi',
        subtitle: 'Doktor ziyareti yap ve yaralılık cezasını kaldır',
        route: AppRoutes.hospital,
      ),
      MoradonNpcAction(
        emoji: '⛓️',
        label: 'Cezaevi & Kefalet',
        subtitle: 'Kefalet öde, gardiyan ikna et veya firar dene',
        route: AppRoutes.prison,
      ),
    ],
  ),
  MoradonNpcDefinition(
    id: 'entertainment_gate',
    name: 'Han Efendisi Cassian',
    title: 'Han Ticaret Ağı & At Yarışı',
    badgeEmoji: '🎲',
    quote:
        'Mekanlarda enerji doldur, Han vitrininde Vinum Vigor sat, canlı At Yarışında bahsini katla veya Kasa Aç!',
    x: 4710,
    y: 2820,
    interactionRadius: 265,
    spriteSize: 76,
    spriteHeight: 118,
    facingRight: false,
    assetPath: 'assets/moradon/npc_master_cassian.png',
    accentColor: Color(0xFFE879F9),
    actions: <MoradonNpcAction>[
      MoradonNpcAction(
        emoji: '🍸',
        label: 'Mekanlar & Gece Salonu',
        subtitle: 'Han işlet, partiye katıl ve güvenli enerji doldur',
        route: AppRoutes.mekans,
      ),
      MoradonNpcAction(
        emoji: '🐎',
        label: 'Canlı At Yarışı',
        subtitle: 'Favori atına bahis koy ve yarışı canlı izle',
        route: AppRoutes.horseRace,
      ),
      MoradonNpcAction(
        emoji: '🎁',
        label: 'Kasa Açma (Loot)',
        subtitle: 'Efsanevi silah ve zırh kasalarını çevir',
        route: AppRoutes.loot,
      ),
    ],
  ),
];

/// Interactive Royal Training Dummy (`Kraliyet Talim Kuklası`) placed in Moradon sparring zones.
class MoradonTrainingDummy {
  final String id;
  final String name;
  final String subtitle;
  final double x;
  final double y;
  final Color accentColor;

  const MoradonTrainingDummy({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.x,
    required this.y,
    required this.accentColor,
  });
}

const List<MoradonTrainingDummy> kMoradonTrainingDummies =
    <MoradonTrainingDummy>[
  MoradonTrainingDummy(
    id: 'dummy_plaza_west',
    name: 'Kraliyet Talim Kuklası',
    subtitle: 'Merkez Meydan Silah Talimi',
    x: 2740,
    y: 2675,
    accentColor: Color(0xFFFBBF24),
  ),
  MoradonTrainingDummy(
    id: 'dummy_plaza_east',
    name: 'Zırhlı Hedef Kuklası',
    subtitle: 'Kritik Kombo Testi',
    x: 3660,
    y: 2675,
    accentColor: Color(0xFFFB923C),
  ),
  MoradonTrainingDummy(
    id: 'dummy_colosseum',
    name: 'Gladyatör Kuklası',
    subtitle: 'Savaş Kapısı Antrenmanı',
    x: 4250,
    y: 1240,
    accentColor: Color(0xFFF87171),
  ),
  MoradonTrainingDummy(
    id: 'dummy_barracks',
    name: 'Muhafız Talim Kuklası',
    subtitle: 'Muhafız Kulesi Avlusu',
    x: 2240,
    y: 2610,
    accentColor: Color(0xFFC084FC),
  ),
];

/// Live strike feedback event spawned when player attacks in Moradon.
class MoradonStrikeFeedback {
  final int seq;
  final int damage;
  final bool isCritical;
  final int comboStreak;
  final double worldX;
  final double worldY;
  final String? hitDummyId;
  final DateTime createdAt;

  const MoradonStrikeFeedback({
    required this.seq,
    required this.damage,
    required this.isCritical,
    required this.comboStreak,
    required this.worldX,
    required this.worldY,
    this.hitDummyId,
    required this.createdAt,
  });

  double ageSeconds(DateTime now) =>
      now.difference(createdAt).inMilliseconds / 1000.0;

  bool get isExpired => ageSeconds(DateTime.now()) > 1.15;
}

({String grade, Color color}) resolveMoradonStyleRank(int streak) {
  if (streak >= 12) {
    return (grade: 'EFSANEVİ', color: const Color(0xFFF43F5E));
  }
  if (streak >= 8) {
    return (grade: 'SS', color: const Color(0xFFFBBF24));
  }
  if (streak >= 5) {
    return (grade: 'S', color: const Color(0xFFFB923C));
  }
  if (streak >= 3) {
    return (grade: 'A', color: const Color(0xFF38BDF8));
  }
  if (streak >= 2) {
    return (grade: 'B', color: const Color(0xFF4ADE80));
  }
  return (grade: 'C', color: const Color(0xFFE2E8F0));
}

