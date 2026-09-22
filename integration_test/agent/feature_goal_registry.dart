/// Feature goals for AI live-play marathon (player action catalog 1:1).
library;

enum FeatureGoalDomain {
  auth,
  character,
  inventory,
  dungeon,
  siege,
  pvp,
  guild,
  monument,
  vault,
  guildWar,
  market,
  shop,
  season,
  quests,
  bank,
  trade,
  crafting,
  enhancement,
  facilities,
  mekans,
  horseRace,
  hospitalPrison,
  reputation,
  leaderboard,
  friends,
  chat,
  notifications,
  meta,
}

class FeatureGoal {
  const FeatureGoal({
    required this.id,
    required this.domain,
    this.needsPeer = false,
    this.mode = 'either',
    this.destructive = false,
  });

  final String id;
  final FeatureGoalDomain domain;
  final bool needsPeer;
  /// ui | headless | either
  final String mode;
  final bool destructive;
}

/// Full catalog — every player-facing action domain from the live-play plan.
class FeatureGoalRegistry {
  const FeatureGoalRegistry._();

  static const List<FeatureGoal> all = <FeatureGoal>[
    // Auth / meta
    FeatureGoal(id: 'legal_accept', domain: FeatureGoalDomain.auth),
    FeatureGoal(id: 'daily_reward_claim', domain: FeatureGoalDomain.meta),

    // Character
    FeatureGoal(id: 'character_allocate_stat', domain: FeatureGoalDomain.character),
    FeatureGoal(id: 'character_stats_view', domain: FeatureGoalDomain.character, mode: 'ui'),
    FeatureGoal(id: 'codex_dashboard', domain: FeatureGoalDomain.character, mode: 'ui'),

    // Inventory
    FeatureGoal(id: 'inventory_open', domain: FeatureGoalDomain.inventory),
    FeatureGoal(id: 'inventory_equip_item', domain: FeatureGoalDomain.inventory),
    FeatureGoal(id: 'inventory_item_detail', domain: FeatureGoalDomain.inventory, mode: 'ui'),
    FeatureGoal(id: 'inventory_sell_junk', domain: FeatureGoalDomain.inventory),
    FeatureGoal(id: 'inventory_open_box', domain: FeatureGoalDomain.inventory),

    // Dungeon
    FeatureGoal(id: 'dungeon_list_load', domain: FeatureGoalDomain.dungeon),
    FeatureGoal(id: 'dungeon_enter_confirm', domain: FeatureGoalDomain.dungeon),
    FeatureGoal(id: 'dungeon_attack_win', domain: FeatureGoalDomain.dungeon),
    FeatureGoal(id: 'dungeon_siege_hub_browse', domain: FeatureGoalDomain.siege),

    // PvP
    FeatureGoal(id: 'pvp_dashboard_load', domain: FeatureGoalDomain.pvp),
    FeatureGoal(id: 'pvp_history_view', domain: FeatureGoalDomain.pvp, mode: 'ui'),
    FeatureGoal(id: 'pvp_attack_target', domain: FeatureGoalDomain.pvp, needsPeer: true),

    // Guild
    FeatureGoal(id: 'guild_create_or_join', domain: FeatureGoalDomain.guild),
    FeatureGoal(id: 'guild_member_view', domain: FeatureGoalDomain.guild, mode: 'ui'),
    FeatureGoal(id: 'guild_monument_donate', domain: FeatureGoalDomain.monument),
    FeatureGoal(id: 'guild_monument_view', domain: FeatureGoalDomain.monument, mode: 'ui'),
    FeatureGoal(id: 'guild_vault_deposit', domain: FeatureGoalDomain.vault),
    FeatureGoal(id: 'guild_war_hub', domain: FeatureGoalDomain.guildWar),
    FeatureGoal(id: 'guild_war_attack', domain: FeatureGoalDomain.guildWar),
    FeatureGoal(id: 'guild_war_logs', domain: FeatureGoalDomain.guildWar, mode: 'ui'),

    // Market / shop
    FeatureGoal(id: 'market_browse', domain: FeatureGoalDomain.market),
    FeatureGoal(id: 'market_search', domain: FeatureGoalDomain.market),
    FeatureGoal(id: 'market_list_item', domain: FeatureGoalDomain.market),
    FeatureGoal(id: 'market_buy_listing', domain: FeatureGoalDomain.market, needsPeer: true),
    FeatureGoal(id: 'shop_buy_qa_gem_pack', domain: FeatureGoalDomain.shop),
    FeatureGoal(id: 'shop_night_market_buy', domain: FeatureGoalDomain.shop),

    // Season / quests / reputation
    FeatureGoal(id: 'season_bp_view', domain: FeatureGoalDomain.season, mode: 'ui'),
    FeatureGoal(id: 'quests_list', domain: FeatureGoalDomain.quests),
    FeatureGoal(id: 'quests_claim_reward', domain: FeatureGoalDomain.quests),
    FeatureGoal(id: 'reputation_overview', domain: FeatureGoalDomain.reputation),
    FeatureGoal(id: 'reputation_shop_buy', domain: FeatureGoalDomain.reputation),

    // Bank / trade / craft / enhance
    FeatureGoal(id: 'bank_deposit', domain: FeatureGoalDomain.bank),
    FeatureGoal(id: 'bank_withdraw', domain: FeatureGoalDomain.bank),
    FeatureGoal(id: 'trade_initiate', domain: FeatureGoalDomain.trade, needsPeer: true),
    FeatureGoal(id: 'trade_confirm', domain: FeatureGoalDomain.trade, needsPeer: true),
    FeatureGoal(id: 'crafting_start_queue', domain: FeatureGoalDomain.crafting),
    FeatureGoal(id: 'enhancement_forge', domain: FeatureGoalDomain.enhancement),
    FeatureGoal(id: 'enhancement_equip_upgraded', domain: FeatureGoalDomain.enhancement),

    // World
    FeatureGoal(id: 'facilities_view', domain: FeatureGoalDomain.facilities, mode: 'ui'),
    FeatureGoal(id: 'facilities_start_job', domain: FeatureGoalDomain.facilities),
    FeatureGoal(id: 'mekans_browse', domain: FeatureGoalDomain.mekans, mode: 'ui'),
    FeatureGoal(id: 'horse_race_bet', domain: FeatureGoalDomain.horseRace),
    FeatureGoal(id: 'hospital_heal', domain: FeatureGoalDomain.hospitalPrison),
    FeatureGoal(id: 'prison_escape_or_release', domain: FeatureGoalDomain.hospitalPrison),
    FeatureGoal(id: 'leaderboard_view', domain: FeatureGoalDomain.leaderboard, mode: 'ui'),

    // Social
    FeatureGoal(id: 'friends_send_request', domain: FeatureGoalDomain.friends, needsPeer: true),
    FeatureGoal(id: 'friends_accept', domain: FeatureGoalDomain.friends, needsPeer: true),
    FeatureGoal(id: 'chat_global_send', domain: FeatureGoalDomain.chat),
    FeatureGoal(id: 'chat_dm_send', domain: FeatureGoalDomain.chat, needsPeer: true),
    FeatureGoal(id: 'chat_dm_reply', domain: FeatureGoalDomain.chat, needsPeer: true),
    FeatureGoal(id: 'notifications_read', domain: FeatureGoalDomain.notifications, mode: 'ui'),
  ];

  static List<String> get allIds =>
      all.map((FeatureGoal g) => g.id).toList(growable: false);

  static List<FeatureGoal> byDomain(FeatureGoalDomain domain) =>
      all.where((FeatureGoal g) => g.domain == domain).toList();

  static FeatureGoal? byId(String id) {
    for (final FeatureGoal g in all) {
      if (g.id == id) return g;
    }
    return null;
  }
}
