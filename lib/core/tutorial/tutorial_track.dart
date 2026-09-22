import 'dart:ui' show Color;

import 'tutorial_step.dart';

/// Known tutorial track identifiers.
abstract final class TutorialTrackId {
  static const String onboarding = 'onboarding';
  static const String dungeon = 'dungeon';
  static const String inventory = 'inventory';
  static const String character = 'character';
  static const String enhancement = 'enhancement';
  static const String bank = 'bank';
  static const String market = 'market';
  static const String shop = 'shop';
  static const String season = 'season';
  static const String quests = 'quests';
  static const String craft = 'craft';
  static const String guild = 'guild';
  static const String pvp = 'pvp';
  static const String siege = 'siege';
  static const String dailyChain = 'daily_chain';
  static const String retentionIntro = 'retention_intro';
  static const String horseRace = 'horse_race';
  static const String mekans = 'mekans';
  static const String nightMarket = 'night_market';
  static const String facilities = 'facilities';
  static const String trade = 'trade';
  static const String hospital = 'hospital';
  static const String prison = 'prison';

  /// Core path: home → dungeon → enhance → equip → character → season → hospital → prison.
  static const List<String> coreTracks = <String>[
    onboarding,
    dungeon,
    inventory,
    enhancement,
    character,
    season,
    hospital,
    prison,
  ];

  static const List<String> dailyChainStepIds = <String>[
    'daily_d1_dungeon',
    'daily_d2_inventory',
    'daily_d3_craft',
    'daily_d4_guild',
    'daily_d5_pvp',
    'daily_d6_market',
    'daily_d7_siege',
  ];
}

/// Stable anchor ids for spotlight targeting.
abstract final class TutorialAnchorId {
  static const String hudEnergy = 'hud.energy';
  static const String hudGold = 'hud.gold';
  static const String hudGems = 'hud.gems';
  static const String navHomeTab = 'nav.home_tab';
  static const String navInventoryTab = 'nav.inventory_tab';
  static const String navDungeonTab = 'nav.dungeon_tab';
  static const String navCharacterTab = 'nav.character_tab';
  static const String navMenuTab = 'nav.menu_tab';
  static const String navMenuEnhancement = 'nav.menu_enhancement';
  static const String navMenuSeason = 'nav.menu_season';
  static const String navMenuQuests = 'nav.menu_quests';
  static const String navMenuShop = 'nav.menu_shop';
  static const String navMenuCraft = 'nav.menu_craft';
  static const String navMenuBank = 'nav.menu_bank';
  static const String navMenuMarket = 'nav.menu_market';
  static const String navMenuGuild = 'nav.menu_guild';
  static const String navMenuPvp = 'nav.menu_pvp';
  static const String navMenuFacilities = 'nav.menu_facilities';
  static const String navMenuTrade = 'nav.menu_trade';
  static const String navMenuHospital = 'nav.menu_hospital';
  static const String navMenuPrison = 'nav.menu_prison';
  static const String navBottomBar = 'nav.bottom_bar';
  static const String homePromo = 'home.promo';
  static const String homeHero = 'home.hero';
  static const String homeHotspot = 'home.hotspot';
  static const String homeCamp = 'home.camp';
  static const String homePantheon = 'home.pantheon';
  static const String dungeonZone0 = 'dungeon.zone_0';
  static const String dungeonZone1Tab = 'dungeon.zone_1_tab';
  static const String dungeonEnterBtn = 'dungeon.enter_btn';
  static const String dungeonConfirmOk = 'dungeon.confirm_ok';
  static const String dungeonAttackBtn = 'dungeon.attack_btn';
  static const String inventoryFirstWeapon = 'inventory.first_weapon';
  static const String inventoryEquipBtn = 'inventory.equip_btn';
  static const String characterPowerStat = 'character.power_stat';
  static const String characterStatPanel = 'character.stat_panel';
  static const String characterClassAbilities = 'character.class_abilities';
  static const String enhanceItemSlot = 'enhance.item_slot';
  static const String enhanceInventoryWeapon = 'enhance.inventory_weapon';
  static const String enhanceForgeBtn = 'enhance.forge_btn';
  static const String bankInventoryItem = 'bank.inventory_item';
  static const String bankDepositBtn = 'bank.deposit_btn';
  static const String craftRecipeFirst = 'craft.recipe_first';
  static const String craftStartBtn = 'craft.start_btn';
  static const String shopNightTabBar = 'shop.night_tab_bar';
  static const String hudHealth = 'hud.health';
  static const String facilitiesHubCard = 'facilities.hub_card';
  static const String tradeSearchField = 'trade.search_field';
  static const String hospitalHealBtn = 'hospital.heal_btn';
  static const String prisonBailBtn = 'prison.bail_btn';
  static const String hospitalAdTimerBtn = 'hospital.ad_timer_btn';
  static const String prisonAdTimerBtn = 'prison.ad_timer_btn';
  static const String marketBrowseTab = 'market.browse_tab';
  static const String shopPotionRow = 'shop.potion_row';
  static const String shopNightTab = 'shop.night_tab';
  static const String shopNightOffer = 'shop.night_offer';
  static const String seasonHeader = 'season.header';
  static const String seasonBppBar = 'season.bpp_bar';
  static const String seasonQuestsTab = 'season.quests_tab';
  static const String seasonL20Reward = 'season.l20_reward_row';
  static const String questsClaimBtn = 'quests.claim_btn';
  static const String characterCodexTile = 'character.codex_tile';
  static const String pvpNemesisPanel = 'pvp.nemesis_panel';
  static const String pvpFindMatch = 'pvp.find_match';
  static const String guildHeader = 'guild.header';
  static const String guildJoinBtn = 'guild.join_btn';
  static const String siegeHubPanel = 'siege.hub_panel';
  static const String horseBetPanel = 'horse.bet_panel';
  static const String horsePlaceBetBtn = 'horse.place_bet_btn';
  static const String horseHorseGrid = 'horse.horse_grid';
  static const String mekansList = 'mekans.list';
  static const String mekansMyCta = 'mekans.my_cta';
  static const String mekansArenaCta = 'mekans.arena_cta';
}

/// Track başına görsel kimlik — kart madalyonu, etiket ve accent rengi.
class TutorialTrackMeta {
  const TutorialTrackMeta(this.emoji, this.label, this.accent);

  final String emoji;
  final String label;
  final Color accent;

  static const Color _gold = Color(0xFFFFB800);
  static const Color _cyan = Color(0xFF22D3EE);
  static const Color _ruby = Color(0xFFE01E5A);
  static const Color _green = Color(0xFF4ADE80);
  static const Color _purple = Color(0xFFC084FC);
  static const Color _orange = Color(0xFFFB923C);

  static const Map<String, TutorialTrackMeta> _byTrack =
      <String, TutorialTrackMeta>{
    TutorialTrackId.onboarding: TutorialTrackMeta('🏕️', 'Başlangıç', _gold),
    TutorialTrackId.dungeon: TutorialTrackMeta('🏰', 'Zindan', _ruby),
    TutorialTrackId.inventory: TutorialTrackMeta('🎒', 'Envanter', _cyan),
    TutorialTrackId.character: TutorialTrackMeta('🧙', 'Karakter', _purple),
    TutorialTrackId.enhancement:
        TutorialTrackMeta('⚒️', 'Geliştirme', _orange),
    TutorialTrackId.bank: TutorialTrackMeta('🏦', 'Banka', _green),
    TutorialTrackId.market: TutorialTrackMeta('💰', 'Pazar', _green),
    TutorialTrackId.shop: TutorialTrackMeta('🛒', 'Mağaza', _cyan),
    TutorialTrackId.season: TutorialTrackMeta('🎖️', 'Sezon', _gold),
    TutorialTrackId.quests: TutorialTrackMeta('📋', 'Görevler', _purple),
    TutorialTrackId.craft: TutorialTrackMeta('🔨', 'Üretim', _orange),
    TutorialTrackId.guild: TutorialTrackMeta('🛡️', 'Lonca', _cyan),
    TutorialTrackId.pvp: TutorialTrackMeta('⚔️', 'Arena', _ruby),
    TutorialTrackId.siege: TutorialTrackMeta('🏯', 'Kuşatma', _ruby),
    TutorialTrackId.dailyChain:
        TutorialTrackMeta('📅', 'Günlük Rehber', _green),
    TutorialTrackId.retentionIntro:
        TutorialTrackMeta('✨', 'Keşifler', _purple),
    TutorialTrackId.horseRace: TutorialTrackMeta('🐎', 'At Yarışı', _gold),
    TutorialTrackId.mekans: TutorialTrackMeta('🍺', 'Mekanlar', _orange),
    TutorialTrackId.nightMarket:
        TutorialTrackMeta('🌙', 'Gece Pazarı', _purple),
    TutorialTrackId.facilities: TutorialTrackMeta('🏭', 'Tesisler', _orange),
    TutorialTrackId.trade: TutorialTrackMeta('🤝', 'Ticaret', _green),
    TutorialTrackId.hospital: TutorialTrackMeta('🏥', 'Sağlık', _ruby),
    TutorialTrackId.prison: TutorialTrackMeta('⛓️', 'Hapishane', _orange),
  };

  static TutorialTrackMeta forTrack(String trackId) {
    return _byTrack[trackId] ??
        const TutorialTrackMeta('✨', 'Rehber', _gold);
  }
}

enum TutorialMode {
  narrative,
  spotlightTap,
  waitEvent,
  highlightOnly,
}

enum TutorialCompletion {
  onManualDismiss,
  onTapAnchor,
  onGameEvent,
}

/// Game events that can complete a tutorial step.
abstract final class TutorialGameEvent {
  static const String dungeonWin = 'dungeon_win';
  static const String equipSuccess = 'equip_success';
  static const String enhancementAttempt = 'enhancement_attempt';
  static const String bankDeposit = 'bank_deposit';
}

class TutorialStepV2 {
  const TutorialStepV2({
    required this.id,
    required this.trackId,
    required this.title,
    required this.body,
    this.mode = TutorialMode.spotlightTap,
    this.anchorId,
    this.completion = TutorialCompletion.onTapAnchor,
    this.gameEvent,
    this.primaryLabel,
    this.allowedRoutes = const <String>[],
    this.requiresPrior = const <String>[],
    this.navigateToRoute,
    this.autoNavigateWhenPaused = false,
    this.allowsBackgroundInteraction = false,
  });

  final String id;
  final String trackId;
  final String title;
  final String body;
  final TutorialMode mode;
  final String? anchorId;
  final TutorialCompletion completion;
  final String? gameEvent;
  final String? primaryLabel;
  final List<String> allowedRoutes;
  final List<String> requiresPrior;
  final String? navigateToRoute;
  final bool autoNavigateWhenPaused;

  /// When true, narrative overlay dim ignores pointer events so the page can
  /// scroll while the bottom coach card stays tappable.
  final bool allowsBackgroundInteraction;

  bool get needsAnchor =>
      mode == TutorialMode.spotlightTap || mode == TutorialMode.highlightOnly;

  /// Spotlight/highlight target must be tapped — no Devam / Sonra on card.
  bool get requiresTargetTap =>
      completion == TutorialCompletion.onTapAnchor &&
      (mode == TutorialMode.spotlightTap ||
          mode == TutorialMode.highlightOnly);

  /// Bottom-nav tab must be tapped.
  bool get requiresNavTap =>
      requiresTargetTap &&
      anchorId != null &&
      anchorId!.startsWith('nav.');

  /// Coach shows Devam/Sonra only for narrative / manual-dismiss steps.
  bool get showsManualCta =>
      mode == TutorialMode.narrative ||
      completion == TutorialCompletion.onManualDismiss;

  /// Waiting for a game event — never show Devam.
  bool get waitsForGameEvent =>
      completion == TutorialCompletion.onGameEvent ||
      mode == TutorialMode.waitEvent;

  String? get preferredRoute {
    if (navigateToRoute != null && navigateToRoute!.isNotEmpty) {
      return navigateToRoute;
    }
    if (allowedRoutes.isNotEmpty) return allowedRoutes.first;
    return null;
  }
}

class TutorialTrack {
  const TutorialTrack({
    required this.id,
    required this.steps,
    this.triggerRoute,
  });

  final String id;
  final List<TutorialStepV2> steps;
  final String? triggerRoute;
}

/// Route → track mapping for first-visit tutorials.
abstract final class TutorialRouteTracks {
  static String? trackForRoute(String route) {
    if (route == TutorialRoutes.home) return TutorialTrackId.onboarding;
    if (route == TutorialRoutes.dungeonSiegeHub ||
        route.startsWith('${TutorialRoutes.dungeonSiegeHub}/')) {
      return TutorialTrackId.siege;
    }
    if (route == TutorialRoutes.dungeon ||
        route.startsWith(TutorialRoutes.dungeon)) {
      return TutorialTrackId.dungeon;
    }
    if (route == TutorialRoutes.inventory) return TutorialTrackId.inventory;
    if (route == TutorialRoutes.character) return TutorialTrackId.character;
    if (route == TutorialRoutes.enhancement) return TutorialTrackId.enhancement;
    if (route == TutorialRoutes.bank) return TutorialTrackId.bank;
    if (route == TutorialRoutes.market) return TutorialTrackId.market;
    if (route == TutorialRoutes.shop) return TutorialTrackId.shop;
    if (route == TutorialRoutes.season) return TutorialTrackId.season;
    if (route == TutorialRoutes.quests) return TutorialTrackId.quests;
    if (route == TutorialRoutes.crafting) return TutorialTrackId.craft;
    if (route == TutorialRoutes.guild ||
        route.startsWith('${TutorialRoutes.guild}/')) {
      return TutorialTrackId.guild;
    }
    if (route == TutorialRoutes.pvp) return TutorialTrackId.pvp;
    if (route == TutorialRoutes.guildWar ||
        route.startsWith('${TutorialRoutes.guildWar}/')) {
      return TutorialTrackId.siege;
    }
    if (route == TutorialRoutes.horseRace) return TutorialTrackId.horseRace;
    if (route == TutorialRoutes.mekans ||
        route.startsWith('${TutorialRoutes.mekans}/') ||
        route == TutorialRoutes.myMekan) {
      return TutorialTrackId.mekans;
    }
    if (route == TutorialRoutes.facilities) return TutorialTrackId.facilities;
    if (route == TutorialRoutes.trade) return TutorialTrackId.trade;
    if (route == TutorialRoutes.hospital) return TutorialTrackId.hospital;
    if (route == TutorialRoutes.prison) return TutorialTrackId.prison;
    return null;
  }
}
