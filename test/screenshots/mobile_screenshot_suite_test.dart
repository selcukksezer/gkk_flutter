import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:gkk_flutter/core/tutorial/tutorial_controller.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_persistence.dart';
import 'package:gkk_flutter/l10n/l10n.dart';
import 'package:gkk_flutter/models/auth_model.dart';
import 'package:gkk_flutter/models/comeback_summary_model.dart';
import 'package:gkk_flutter/models/crafting_model.dart';
import 'package:gkk_flutter/models/daily_reward_model.dart';
import 'package:gkk_flutter/models/dungeon_model.dart';
import 'package:gkk_flutter/models/dungeon_siege_model.dart';
import 'package:gkk_flutter/models/guild_model.dart';
import 'package:gkk_flutter/models/guild_vault_model.dart';
import 'package:gkk_flutter/models/guild_war_model.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/item_model.dart';
import 'package:gkk_flutter/models/kingdom_market_blessing_model.dart';
import 'package:gkk_flutter/models/market_model.dart';
import 'package:gkk_flutter/models/player_badge_model.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/models/staff_model.dart';
import 'package:gkk_flutter/providers/auth_provider.dart';
import 'package:gkk_flutter/providers/box_opening_provider.dart';
import 'package:gkk_flutter/providers/comeback_summary_provider.dart';
import 'package:gkk_flutter/providers/crafting_provider.dart';
import 'package:gkk_flutter/providers/daily_reward_provider.dart';
import 'package:gkk_flutter/providers/dungeon_provider.dart';
import 'package:gkk_flutter/providers/dungeon_siege_provider.dart';
import 'package:gkk_flutter/providers/guild_provider.dart';
import 'package:gkk_flutter/providers/guild_vault_provider.dart';
import 'package:gkk_flutter/providers/guild_war_provider.dart';
import 'package:gkk_flutter/providers/inventory_provider.dart';
import 'package:gkk_flutter/providers/kingdom_market_blessing_provider.dart';
import 'package:gkk_flutter/providers/market_provider.dart';
import 'package:gkk_flutter/providers/player_badges_provider.dart';
import 'package:gkk_flutter/providers/player_inbox_provider.dart';
import 'package:gkk_flutter/providers/player_provider.dart';
import 'package:gkk_flutter/providers/pvp_invite_provider.dart';
import 'package:gkk_flutter/providers/pvp_provider.dart';
import 'package:gkk_flutter/providers/staff_provider.dart';
import 'package:gkk_flutter/routing/app_router.dart';
import 'package:gkk_flutter/screens/bank/bank_screen.dart';
import 'package:gkk_flutter/screens/character/character_screen.dart';
import 'package:gkk_flutter/screens/crafting/crafting_screen.dart';
import 'package:gkk_flutter/screens/dungeon/dungeon_battle_screen.dart';
import 'package:gkk_flutter/screens/enhancement/enhancement_screen.dart';
import 'package:gkk_flutter/screens/guild/guild_screen.dart';
import 'package:gkk_flutter/screens/guild_war/guild_war_hub_screen.dart';
import 'package:gkk_flutter/screens/home/home_screen.dart';
import 'package:gkk_flutter/screens/inventory/inventory_screen.dart';
import 'package:gkk_flutter/screens/market/market_screen.dart';
import 'package:gkk_flutter/screens/pvp/pvp_screen.dart';
import 'package:gkk_flutter/screens/shop/shop_screen.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

/// Authentic mobile viewport specifications (iPhone 14 / modern standard mobile).
const double kMobileWidth = 390.0;
const double kMobileHeight = 844.0;
const double kDevicePixelRatio = 2.0; // 780x1688 crisp mobile golden render
const EdgeInsets kMobileSafeArea = EdgeInsets.only(top: 47.0, bottom: 34.0);

const String kOutputDir = 'reports/screenshots/mobile_goldens';

/// Utility to capture widget to PNG file on disk.
Future<File> captureWidgetToPng({
  required WidgetTester tester,
  required GlobalKey repaintKey,
  required String filename,
  List<String> additionalAliases = const <String>[],
}) async {
  final Directory dir = Directory(kOutputDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  File? savedFile;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: kDevicePixelRatio);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode image to PNG for $filename');
    }

    final Uint8List pngBytes = byteData.buffer.asUint8List();
    final File file = File('$kOutputDir/$filename');
    await file.writeAsBytes(pngBytes, flush: true);
    for (final String alias in additionalAliases) {
      final File aliasFile = File('$kOutputDir/$alias');
      await aliasFile.writeAsBytes(pngBytes, flush: true);
    }
    savedFile = file;
  });

  return savedFile!;
}

// ─────────────────────────────────────────────────────────────────────────────
// GENUINE PRODUCTION TEST DATA & FACTORIES
// ─────────────────────────────────────────────────────────────────────────────

InventoryItem _createTestItem({
  required String rowId,
  required String itemId,
  required String name,
  required Rarity rarity,
  ItemType itemType = ItemType.weapon,
  EquipSlot equipSlot = EquipSlot.weapon,
  int slotPosition = 0,
  bool isEquipped = false,
  String equippedSlot = '',
  int enhancementLevel = 0,
  int quantity = 1,
  int attack = 100,
  int defense = 50,
  int health = 0,
  int power = 150,
  int vendorSellPrice = 500,
  int requiredLevel = 1,
}) {
  return InventoryItem(
    rowId: rowId,
    itemId: itemId,
    quantity: quantity,
    slotPosition: slotPosition,
    isEquipped: isEquipped,
    equippedSlot: equippedSlot.isNotEmpty
        ? equippedSlot
        : (isEquipped ? equipSlot.name : ''),
    enhancementLevel: enhancementLevel,
    isFavorite: false,
    pendingSync: false,
    name: name,
    description: 'Aion 2 Dark Fantasy Item',
    icon: 'assets/images/icons/default.png',
    itemType: itemType,
    rarity: rarity,
    basePrice: vendorSellPrice * 2,
    vendorSellPrice: vendorSellPrice,
    attack: attack,
    defense: defense,
    health: health,
    power: power,
    luck: 0,
    mana: 0,
    equipSlot: equipSlot,
    weaponType: itemType == ItemType.weapon ? WeaponType.sword : WeaponType.none,
    armorType: itemType == ItemType.armor ? ArmorType.plate : ArmorType.none,
    requiredLevel: requiredLevel,
    canEnhance: true,
    maxEnhancement: 10,
    isStackable: itemType == ItemType.material || itemType == ItemType.potion,
    maxStack: 99,
    isTradeable: true,
    potionType: PotionType.none,
    energyRestore: 0,
    healthRestore: 0,
    toleranceIncrease: 0,
  );
}

final InventoryItem kDefaultWeapon = _createTestItem(
  rowId: 'wpn_hero_blade',
  itemId: 'wpn_draco_sword',
  name: 'Kadim Ejder Kılıcı',
  rarity: Rarity.mythic,
  equipSlot: EquipSlot.weapon,
  isEquipped: true,
  equippedSlot: 'weapon',
  enhancementLevel: 10,
  attack: 520,
  power: 650,
  vendorSellPrice: 50000,
  requiredLevel: 70,
);

final InventoryItem kDefaultChest = _createTestItem(
  rowId: 'arm_hero_chest',
  itemId: 'arm_draco_plate',
  name: 'Draco Plaka Zırhı',
  rarity: Rarity.legendary,
  itemType: ItemType.armor,
  equipSlot: EquipSlot.chest,
  isEquipped: true,
  equippedSlot: 'chest',
  enhancementLevel: 8,
  defense: 380,
  health: 1200,
  power: 480,
  vendorSellPrice: 35000,
  requiredLevel: 68,
);

final InventoryItem kDefaultHead = _createTestItem(
  rowId: 'hlm_hero_head',
  itemId: 'hlm_draco_crest',
  name: 'Kızıl Ejder Miğferi',
  rarity: Rarity.epic,
  itemType: ItemType.armor,
  equipSlot: EquipSlot.head,
  isEquipped: true,
  equippedSlot: 'head',
  enhancementLevel: 7,
  defense: 210,
  health: 600,
  power: 320,
  vendorSellPrice: 20000,
  requiredLevel: 65,
);

final InventoryItem kDefaultPotion = _createTestItem(
  rowId: 'pot_greater_heal',
  itemId: 'pot_heal_03',
  name: 'Büyük İksir',
  rarity: Rarity.rare,
  itemType: ItemType.potion,
  equipSlot: EquipSlot.none,
  slotPosition: 0,
  quantity: 5,
  vendorSellPrice: 800,
);

final InventoryItem kDefaultMaterial = _createTestItem(
  rowId: 'mat_dragon_scale',
  itemId: 'mat_scale_01',
  name: 'Ejder Pulu',
  rarity: Rarity.legendary,
  itemType: ItemType.material,
  equipSlot: EquipSlot.none,
  slotPosition: 1,
  quantity: 12,
  vendorSellPrice: 2500,
);

final PlayerProfile kDefaultProfile = PlayerProfile(
  id: 'usr_screenshot_mobile',
  authId: 'auth_screenshot_mobile',
  username: 'Kaelen',
  email: 'kaelen@aion2.mobile',
  displayName: 'Kaelen',
  avatarUrl: null,
  avatarFrame: null,
  level: 75,
  xp: 125000,
  gold: 1450000,
  gems: 3850.0,
  energy: 100,
  maxEnergy: 100,
  attack: 1420,
  defense: 1180,
  health: 28500,
  maxHealth: 28500,
  power: 142500,
  isOnline: true,
  isBanned: false,
  tutorialCompleted: true,
  guildId: 'guild_draco',
  guildRole: 'commander',
  guildName: 'Ejder [LNC]',
  title: 'Kadim Ejder Şövalyesi',
  cosmeticTitle: 'Kadim Ejder',
  characterClass: CharacterClass.warrior,
  referralCode: null,
  referredBy: null,
  pvpRating: 2450,
  pvpWins: 182,
  pvpLosses: 34,
  addictionLevel: 0,
  tolerance: 0,
  nightlifeTickets: 0,
  nightlifeVibe: 0,
  lastPotionUsedAt: null,
  warriorBloodlustUntil: null,
  hospitalUntil: null,
  hospitalReason: null,
  hospitalLifetimeCount: 0,
  prisonUntil: null,
  prisonReason: null,
  globalSuspicionLevel: 0,
  lastBribeAt: null,
  lastLoginAt: '2026-10-29T00:00:00Z',
  lastLogin: '2026-10-29T00:00:00Z',
  createdAt: '2026-01-01T00:00:00Z',
  updatedAt: '2026-10-29T00:00:00Z',
  reputation: 9800,
  endurance: 150,
  agility: 120,
  intelligence: 90,
  luck: 45,
  equipBonusLuck: 10,
  statPoints: 0,
  craftingQueueSlots: 3,
  healthLastUpdated: null,
);

final PlayerState kDefaultPlayerState = PlayerState(
  status: PlayerStatus.ready,
  profile: kDefaultProfile,
);

final InventoryState kDefaultInventoryState = InventoryState(
  status: InventoryStatus.ready,
  items: <InventoryItem>[kDefaultPotion, kDefaultMaterial],
  equippedItems: <String, InventoryItem?>{
    'weapon': kDefaultWeapon,
    'chest': kDefaultChest,
    'head': kDefaultHead,
  },
);

final PvpDashboardState kDefaultPvpDashboardState = PvpDashboardState(
  isLoading: false,
  arenas: const <PvpArena>[
    PvpArena(id: 'arena_1', name: 'Kolezyum Meydanı', mekanType: 'dovus_kulubu'),
    PvpArena(id: 'arena_2', name: 'Gölge Çukuru', mekanType: 'yeralti'),
    PvpArena(id: 'arena_3', name: 'Lüks Gladyatör Salonu', mekanType: 'luks_lounge'),
  ],
  recentMatches: const <PvpRecentMatch>[
    PvpRecentMatch(
      id: 'match_1',
      attackerId: 'usr_screenshot_mobile',
      defenderId: 'usr_rival_1',
      winnerId: 'usr_screenshot_mobile',
      goldStolen: 12500,
      repChangeWinner: 25,
      repChangeLoser: -15,
      isCritical: true,
      attackerHpRemaining: 18200,
      createdAt: '2026-10-29T04:10:00Z',
      attackerUsername: 'Kaelen',
      defenderUsername: 'GölgeLordu',
    ),
    PvpRecentMatch(
      id: 'match_2',
      attackerId: 'usr_rival_2',
      defenderId: 'usr_screenshot_mobile',
      winnerId: 'usr_screenshot_mobile',
      goldStolen: 8400,
      repChangeWinner: 18,
      repChangeLoser: -10,
      isCritical: false,
      attackerHpRemaining: 9500,
      createdAt: '2026-10-29T03:30:00Z',
      attackerUsername: 'Valkyrie',
      defenderUsername: 'Kaelen',
    ),
  ],
);

final DungeonState kDefaultDungeonState = DungeonState(
  status: DungeonStatus.ready,
  dungeons: const <DungeonData>[
    DungeonData(
      id: 'dungeon_volcano_03',
      dungeonId: 'dungeon_volcano_03',
      name: 'Lav Zindanı',
      description: 'Aion 2 Abyssal Lav Mağarası',
      difficulty: 'hard',
      requiredLevel: 65,
      maxPlayers: 1,
      energyCost: 15,
      minGold: 2000,
      maxGold: 8500,
      lootTable: <String>['Efsanevi Kılıç', 'Kutsal Zırh'],
      isGroup: false,
      powerRequirement: 120000,
      zone: 3,
      isBoss: true,
    ),
  ],
);

const GuildData kDefaultGuild = GuildData(
  guildId: 'guild_draco',
  name: 'Ejder [LNC]',
  description: 'Aion 2 Dark Fantasy Topluluğu',
  level: 10,
  leaderId: 'usr_screenshot_mobile',
  memberCount: 28,
  maxMembers: 50,
  totalPower: 2850000,
  monumentLevel: 5,
  monumentStructural: 100,
  monumentMystical: 100,
  monumentCritical: 100,
  monumentGoldPool: 5000000,
  vaultGold: 5000000,
  minJoinPower: 50000,
  members: <GuildMemberData>[
    GuildMemberData(
      playerId: 'usr_screenshot_mobile',
      username: 'Kaelen',
      level: 75,
      role: GuildRole.leader,
      power: 142500,
      isOnline: true,
    ),
  ],
);

final GuildState kDefaultGuildState = GuildState(
  guild: kDefaultGuild,
  searchResults: const <GuildData>[kDefaultGuild],
  recommendedGuilds: const <GuildData>[kDefaultGuild],
  isLoading: false,
  isSearching: false,
  isLoadingRecommended: false,
  isMutating: false,
);

final GuildWarState kDefaultGuildWarState = GuildWarState(
  season: const GuildWarSeason(season: 3, week: 2),
  tournaments: const <GuildWarTournament>[
    GuildWarTournament(
      id: 'tourn_draco_cup',
      name: 'Draco Şampiyonlar Turnuvası',
      status: 'active',
      guildCount: 16,
      prizePool: '10.000.000 Altın',
    ),
  ],
  territories: const <TerritoryData>[
    TerritoryData(
      id: 'territory_draco_citadel',
      name: 'Kadim Ejder Kalesi',
      ownerGuildId: 'guild_draco',
      ownerGuildName: 'Ejder [LNC]',
      defensePower: 2850000,
      baseDefensePower: 2000000,
      reward: '500.000 Altın / Gün',
      tradeIncome: 25000,
    ),
  ],
  rankings: const <GuildWarRanking>[
    GuildWarRanking(
      rank: 1,
      guildName: 'Ejder [LNC]',
      guildId: 'guild_draco',
      points: 12500,
      prestige: 850,
      wins: 24,
      losses: 2,
    ),
  ],
  attackLogs: const <GuildWarAttackLog>[],
  isLoading: false,
);

// ─────────────────────────────────────────────────────────────────────────────
// AUTHENTIC TEST NOTIFIERS FOR OFFLINE / TEST ISOLATION
// ─────────────────────────────────────────────────────────────────────────────

class _FakePlayerNotifier extends PlayerNotifier {
  _FakePlayerNotifier(this._state);
  final PlayerState _state;

  @override
  PlayerState build() => _state;

  @override
  Future<void> loadProfile() async {}

  @override
  void clear() {}
}

class _FakeInventoryNotifier extends InventoryNotifier {
  _FakeInventoryNotifier(this._state);
  final InventoryState _state;

  @override
  InventoryState build() => _state;

  @override
  Future<void> loadInventory({bool silent = false}) async {}
}

class _FakePvpDashboardNotifier extends PvpDashboardNotifier {
  _FakePvpDashboardNotifier(this._state);
  final PvpDashboardState _state;

  @override
  PvpDashboardState build() => _state;

  @override
  Future<void> load({int matchLimit = 8}) async {}
}

class _FakePvpInviteNotifier extends PvpInviteNotifier {
  @override
  PvpInviteState build() => const PvpInviteState();
}

class _FakeDungeonNotifier extends DungeonNotifier {
  _FakeDungeonNotifier(this._state);
  final DungeonState _state;

  @override
  DungeonState build() => _state;

  @override
  Future<void> loadDungeons({bool silent = false}) async {}
}

class _FakeStaffNotifier extends StaffNotifier {
  @override
  StaffState build() => const StaffState(profile: StaffProfile.none);

  @override
  Future<void> load({bool silent = false}) async {}
}

class _FakePlayerInboxNotifier extends PlayerInboxNotifier {
  @override
  List<PlayerInboxItem> build() => const <PlayerInboxItem>[];

  @override
  Future<void> refresh() async {}
}

class _FakeComebackSummaryNotifier extends ComebackSummaryNotifier {
  @override
  ComebackSummaryState build() =>
      const ComebackSummaryState(shownThisSession: true);

  @override
  Future<void> load() async {}
}

class _FakeDailyRewardNotifier extends DailyRewardNotifier {
  @override
  DailyRewardState build() =>
      const DailyRewardState(autoPromptedThisSession: true);

  @override
  Future<void> loadStatus() async {}
}

class _FakePlayerBadgesNotifier extends PlayerBadgesNotifier {
  @override
  PlayerBadgesState build() => const PlayerBadgesState();

  @override
  Future<void> load() async {}
}

class _FakeTutorialController extends TutorialController {
  @override
  TutorialState build() => const TutorialState(
        loaded: true,
        progress: TutorialProgressState(
          version: 2,
          completedTracks: <String>{'onboarding', 'dungeon', 'season'},
          stepsByTrack: <String, Set<String>>{},
          skippedAll: true,
        ),
      );
}

class _FakeBoxOpeningNotifier extends BoxOpeningNotifier {
  @override
  List<BoxOpening> build() => const <BoxOpening>[];
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        status: AuthStatus.authenticated,
        session: AuthSession(
          accessToken: 'fake_test_jwt',
          refreshToken: 'fake_test_refresh',
          expiresAt: 9999999999,
        ),
        user: AuthUser(
          id: 'auth_screenshot_mobile',
          email: 'kaelen@aion2.mobile',
        ),
      );

  @override
  Future<void> loadSession() async {}
}

class _FakeGuildNotifier extends GuildNotifier {
  _FakeGuildNotifier(this._state);
  final GuildState _state;

  @override
  GuildState build() => _state;

  @override
  Future<void> loadGuild() async {}

  @override
  Future<void> loadRecommendedGuilds() async {}
}

class _FakeGuildWarNotifier extends GuildWarNotifier {
  _FakeGuildWarNotifier(this._state);
  final GuildWarState _state;

  @override
  GuildWarState build() => _state;

  @override
  Future<void> loadAll() async {}

  @override
  Future<LiveGuildWarClash?> loadLiveClash({String? guildId}) async => null;
}

class _FakeGuildVaultNotifier extends GuildVaultNotifier {
  @override
  GuildVaultState build() => const GuildVaultState(
        vaultGold: 5000000,
        hydrated: true,
        canCollect: true,
      );

  @override
  Future<void> load({bool silent = false}) async {}
}

class _FakeDungeonSiegeNotifier extends DungeonSiegeNotifier {
  @override
  DungeonSiegeState build() => DungeonSiegeState.initial();

  @override
  Future<void> loadHub({bool includeNotifications = true, bool silent = false}) async {}

  @override
  Future<void> loadStatus({String? dungeonId, bool silent = false}) async {}
}

class _FakeKingdomMarketBlessingNotifier extends KingdomMarketBlessingNotifier {
  @override
  KingdomMarketBlessingStatus build() => KingdomMarketBlessingStatus.inactive();

  @override
  Future<void> load() async {}
}

class _FakeCraftingNotifier extends CraftingNotifier {
  @override
  CraftingState build() => const CraftingState(
        recipes: <CraftRecipe>[
          CraftRecipe(
            id: 'recipe_sword_01',
            recipeId: 'recipe_sword_01',
            name: 'Kadim Ejder Kılıcı Yapımı',
            description: 'Aion 2 Draco Kılıç Dövme Reçetesi',
            recipeType: 'weapon',
            itemType: 'weapon',
            outputItemId: 'wpn_draco_sword',
            outputQuantity: 1,
            outputRarity: 'mythic',
            requiredLevel: 60,
            requiredFacilityLevel: 1,
            productionTimeSeconds: 120,
            successRate: 95,
            ingredients: <CraftIngredient>[
              CraftIngredient(
                itemId: 'mat_scale_01',
                itemName: 'Ejder Pulu',
                quantity: 5,
              ),
            ],
            gemCost: 0,
            goldCost: 5000,
          ),
        ],
        queue: <CraftQueueItem>[],
        isLoading: false,
        isCrafting: false,
        isCancelling: false,
        selectedBatchCount: 1,
        selectedTab: 'tumu',
      );

  @override
  Future<void> loadRecipes(int playerLevel) async {}

  @override
  Future<void> loadQueue() async {}
}

class _FakeMarketNotifier extends MarketNotifier {
  @override
  MarketState build() => const MarketState(
        status: MarketStatus.ready,
        tickers: <MarketTicker>[
          MarketTicker(
            itemId: 'mat_scale_01',
            itemName: 'Ejder Pulu',
            itemType: 'material',
            rarity: 'legendary',
            isStackable: true,
            lowestPrice: 2400,
            volume: 340,
            priceChange: 500,
            maxAvailableQty: 50,
          ),
        ],
        myOrders: <MarketOrder>[],
        tickersLoaded: true,
        myOrdersLoaded: true,
      );

  @override
  Future<void> loadTickers({bool reset = false}) async {}

  @override
  Future<void> loadMyOrders() async {}
}

List<Override> _createDefaultTestOverrides() {
  return <Override>[
    playerProvider.overrideWith(() => _FakePlayerNotifier(kDefaultPlayerState)),
    inventoryProvider.overrideWith(() => _FakeInventoryNotifier(kDefaultInventoryState)),
    pvpDashboardProvider.overrideWith(() => _FakePvpDashboardNotifier(kDefaultPvpDashboardState)),
    pvpInviteProvider.overrideWith(() => _FakePvpInviteNotifier()),
    dungeonProvider.overrideWith(() => _FakeDungeonNotifier(kDefaultDungeonState)),
    staffProvider.overrideWith(() => _FakeStaffNotifier()),
    playerInboxProvider.overrideWith(() => _FakePlayerInboxNotifier()),
    comebackSummaryProvider.overrideWith(() => _FakeComebackSummaryNotifier()),
    dailyRewardProvider.overrideWith(() => _FakeDailyRewardNotifier()),
    playerBadgesProvider.overrideWith(() => _FakePlayerBadgesNotifier()),
    tutorialProvider.overrideWith(() => _FakeTutorialController()),
    boxOpeningProvider.overrideWith(() => _FakeBoxOpeningNotifier()),
    authProvider.overrideWith(() => _FakeAuthNotifier()),
    guildProvider.overrideWith(() => _FakeGuildNotifier(kDefaultGuildState)),
    guildWarProvider.overrideWith(() => _FakeGuildWarNotifier(kDefaultGuildWarState)),
    guildVaultProvider.overrideWith(() => _FakeGuildVaultNotifier()),
    dungeonSiegeProvider.overrideWith(() => _FakeDungeonSiegeNotifier()),
    kingdomMarketBlessingProvider.overrideWith(() => _FakeKingdomMarketBlessingNotifier()),
    craftingProvider.overrideWith(() => _FakeCraftingNotifier()),
    marketProvider.overrideWith(() => _FakeMarketNotifier()),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE SCREEN TEST HARNESS (390x844 VIEWPORT + AUTHENTIC SAFE AREA + GOROUTER)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildMobileTestHarness({
  required GlobalKey repaintKey,
  required Widget child,
  String initialLocation = AppRoutes.home,
  List<Override> overrides = const <Override>[],
}) {
  final GoRouter testRouter = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: initialLocation.split('?').first,
        builder: (BuildContext context, GoRouterState state) => child,
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (BuildContext context, GoRouterState state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.characterSelect,
        builder: (BuildContext context, GoRouterState state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.character,
        builder: (BuildContext context, GoRouterState state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.inventory,
        builder: (BuildContext context, GoRouterState state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.dungeon,
        builder: (BuildContext context, GoRouterState state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.dungeonBattle,
        builder: (BuildContext context, GoRouterState state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.pvp,
        builder: (BuildContext context, GoRouterState state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.pvpHistory,
        builder: (BuildContext context, GoRouterState state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.hospital,
        builder: (BuildContext context, GoRouterState state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.shop,
        builder: (BuildContext context, GoRouterState state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.enhancement,
        builder: (BuildContext context, GoRouterState state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.guild,
        builder: (BuildContext context, GoRouterState state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.guildWar,
        builder: (BuildContext context, GoRouterState state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.crafting,
        builder: (BuildContext context, GoRouterState state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.market,
        builder: (BuildContext context, GoRouterState state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.bank,
        builder: (BuildContext context, GoRouterState state) => const SizedBox.shrink(),
      ),
    ],
  );

  return ProviderScope(
    overrides: <Override>[
      ..._createDefaultTestOverrides(),
      ...overrides,
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: testRouter,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('tr'),
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.bgDeep,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.gold,
          secondary: AppColors.accentBlue,
          surface: AppColors.bgSurface,
        ),
      ),
      builder: (BuildContext context, Widget? routerChild) {
        return MediaQuery(
          data: const MediaQueryData(
            size: Size(kMobileWidth, kMobileHeight),
            devicePixelRatio: kDevicePixelRatio,
            padding: kMobileSafeArea,
            viewPadding: kMobileSafeArea,
          ),
          child: RepaintBoundary(
            key: repaintKey,
            child: SizedBox(
              width: kMobileWidth,
              height: kMobileHeight,
              child: routerChild,
            ),
          ),
        );
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN REAL SCREEN SCREENSHOT & GOLDEN TEST SUITE
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Automated Flutter Golden & Mobile Screenshot Capture Suite (Real Production Screens)', () {
    setUpAll(() {
      final Directory dir = Directory(kOutputDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
    });

    testWidgets('Screen 1: Real HomeScreen renders and captures cleanly', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          initialLocation: AppRoutes.home,
          child: const HomeScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '01_main_hub_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));

      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 2: Real DungeonBattleScreen renders and captures cleanly', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const String dungeonRoute =
          '${AppRoutes.dungeonBattle}?dungeon_id=dungeon_volcano_03&dungeon_name=Lav+Zindan%C4%B1&zone=3&energy_cost=15';

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          initialLocation: dungeonRoute,
          child: const DungeonBattleScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '02_dungeon_combat_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));

      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 3: Real CharacterScreen renders and captures cleanly', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          initialLocation: AppRoutes.character,
          child: const CharacterScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '03_character_equipment_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));

      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 4: Real InventoryScreen renders and captures cleanly', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          initialLocation: AppRoutes.inventory,
          child: const InventoryScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '04_inventory_crafting_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));

      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 5: Real PvpScreen renders and captures cleanly', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          initialLocation: AppRoutes.pvp,
          child: const PvpScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '05_pvp_battlefield_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));

      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 6: Real ShopScreen renders and captures cleanly', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          initialLocation: AppRoutes.shop,
          child: const ShopScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '06_shop_merchant_mobile.png',
        additionalAliases: const <String>['11_shop_merchant_mobile.png'],
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));

      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 7: Real EnhancementScreen renders and captures cleanly', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          initialLocation: AppRoutes.enhancement,
          child: const EnhancementScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '07_enhancement_anvil_mobile.png',
        additionalAliases: const <String>['17_blacksmith_forge_mobile.png'],
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));

      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 8: Real GuildWarHubScreen renders and captures cleanly', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          initialLocation: AppRoutes.guildWar,
          child: const GuildWarHubScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '08_guild_war_siege_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));

      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 9: Real GuildScreen renders and captures cleanly', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          initialLocation: AppRoutes.guild,
          child: const GuildScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '09_guild_hall_mobile.png',
        additionalAliases: const <String>['10_guild_hall_mobile.png'],
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));

      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 10: Real CraftingScreen renders and captures cleanly', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          initialLocation: AppRoutes.crafting,
          child: const CraftingScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '10_crafting_workshop_mobile.png',
        additionalAliases: const <String>['15_crafting_workshop_mobile.png'],
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));

      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 11: Real MarketScreen renders and captures cleanly', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          initialLocation: AppRoutes.market,
          child: const MarketScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '11_market_trade_mobile.png',
        additionalAliases: const <String>['18_trade_market_mobile.png'],
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));

      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 12: Real BankScreen renders and captures cleanly', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          initialLocation: AppRoutes.bank,
          child: const BankScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '12_bank_vault_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));

      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });
  });
}
