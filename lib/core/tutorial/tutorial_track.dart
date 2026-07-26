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

  /// Core path: home → dungeon → equip → character → enhance (+ season CTA).
  static const List<String> coreTracks = <String>[
    onboarding,
    dungeon,
    inventory,
    character,
    enhancement,
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
  static const String homePromo = 'home.promo';
  static const String homeHero = 'home.hero';
  static const String homeHotspot = 'home.hotspot';
  static const String homeCamp = 'home.camp';
  static const String homePantheon = 'home.pantheon';
  static const String dungeonZone0 = 'dungeon.zone_0';
  static const String dungeonEnterBtn = 'dungeon.enter_btn';
  static const String dungeonConfirmOk = 'dungeon.confirm_ok';
  static const String dungeonAttackBtn = 'dungeon.attack_btn';
  static const String inventoryFirstWeapon = 'inventory.first_weapon';
  static const String inventoryEquipBtn = 'inventory.equip_btn';
  static const String characterPowerStat = 'character.power_stat';
  static const String characterStatPanel = 'character.stat_panel';
  static const String enhanceItemSlot = 'enhance.item_slot';
  static const String enhanceForgeBtn = 'enhance.forge_btn';
  static const String bankDepositBtn = 'bank.deposit_btn';
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
  static const String craftRecipeList = 'craft.recipe_list';
  static const String craftStartBtn = 'craft.start_btn';
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

  bool get needsAnchor =>
      mode == TutorialMode.spotlightTap || mode == TutorialMode.highlightOnly;

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
    return null;
  }
}
