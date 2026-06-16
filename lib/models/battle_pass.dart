class BpSeason {
  final String id;
  final int seasonNumber;
  final DateTime startAt;
  final DateTime endAt;
  final bool isActive;
  final String? description;

  const BpSeason({
    required this.id,
    required this.seasonNumber,
    required this.startAt,
    required this.endAt,
    required this.isActive,
    this.description,
  });

  factory BpSeason.fromJson(Map<String, dynamic> json) {
    return BpSeason(
      id: json['id'] as String,
      seasonNumber: json['season_number'] as int,
      startAt: DateTime.parse(json['start_at'] as String),
      endAt: DateTime.parse(json['end_at'] as String),
      isActive: json['is_active'] as bool,
      description: json['description'] as String?,
    );
  }
}

class BpPlayerStatus {
  final String playerId;
  final String seasonId;
  final int currentLevel;
  final int currentBpp;
  final int dailyGrindBppPool;
  final int dailyPvpBppPool;
  final bool hasVip;
  final List<int> claimedNormal;
  final List<int> claimedVip;
  final DateTime updatedAt;

  const BpPlayerStatus({
    required this.playerId,
    required this.seasonId,
    required this.currentLevel,
    required this.currentBpp,
    required this.dailyGrindBppPool,
    required this.dailyPvpBppPool,
    required this.hasVip,
    required this.claimedNormal,
    required this.claimedVip,
    required this.updatedAt,
  });

  factory BpPlayerStatus.fromJson(Map<String, dynamic> json) {
    return BpPlayerStatus(
      playerId: json['player_id'] as String,
      seasonId: json['season_id'] as String,
      currentLevel: json['current_level'] as int,
      currentBpp: json['current_bpp'] as int,
      dailyGrindBppPool: json['daily_grind_bpp_pool'] as int? ?? 0,
      dailyPvpBppPool: json['daily_pvp_bpp_pool'] as int? ?? 0,
      hasVip: json['has_vip'] as bool? ?? false,
      claimedNormal: List<int>.from(json['claimed_normal'] ?? []),
      claimedVip: List<int>.from(json['claimed_vip'] ?? []),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class BpQuestTemplate {
  final String id;
  final String description;
  final String questType;
  final String targetSystem;
  final int targetCount;
  final int bppReward;

  const BpQuestTemplate({
    required this.id,
    required this.description,
    required this.questType,
    required this.targetSystem,
    required this.targetCount,
    required this.bppReward,
  });

  factory BpQuestTemplate.fromJson(Map<String, dynamic> json) {
    return BpQuestTemplate(
      id: json['id'] as String,
      description: json['description'] as String,
      questType: json['quest_type'] as String,
      targetSystem: json['target_system'] as String,
      targetCount: json['target_count'] as int,
      bppReward: json['bpp_reward'] as int,
    );
  }
}

class BpPlayerQuest {
  final String id;
  final String playerId;
  final String seasonId;
  final String templateId;
  final int currentProgress;
  final bool isCompleted;
  final bool rewardClaimed;
  final DateTime updatedAt;
  final BpQuestTemplate? template;

  const BpPlayerQuest({
    required this.id,
    required this.playerId,
    required this.seasonId,
    required this.templateId,
    required this.currentProgress,
    required this.isCompleted,
    required this.rewardClaimed,
    required this.updatedAt,
    this.template,
  });

  factory BpPlayerQuest.fromJson(Map<String, dynamic> json) {
    return BpPlayerQuest(
      id: json['id'] as String,
      playerId: json['player_id'] as String,
      seasonId: json['season_id'] as String,
      templateId: json['template_id'] as String,
      currentProgress: json['current_progress'] as int,
      isCompleted: json['is_completed'] as bool,
      rewardClaimed: json['reward_claimed'] as bool? ?? false,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      template: json['template'] != null ? BpQuestTemplate.fromJson(json['template']) : null,
    );
  }
}

class BpLevelReward {
  final int level;
  final String? normalRewardItemId;
  final int normalRewardQuantity;
  final int normalRewardGold;
  final String? vipRewardItemId;
  final int vipRewardQuantity;
  final int vipRewardGold;
  final String? description;
  final Map<String, dynamic>? normalRewardItem;
  final Map<String, dynamic>? vipRewardItem;

  const BpLevelReward({
    required this.level,
    this.normalRewardItemId,
    required this.normalRewardQuantity,
    required this.normalRewardGold,
    this.vipRewardItemId,
    required this.vipRewardQuantity,
    required this.vipRewardGold,
    this.description,
    this.normalRewardItem,
    this.vipRewardItem,
  });

  factory BpLevelReward.fromJson(Map<String, dynamic> json) {
    return BpLevelReward(
      level: json['level'] as int,
      normalRewardItemId: json['normal_reward_item_id'] as String?,
      normalRewardQuantity: json['normal_reward_quantity'] as int,
      normalRewardGold: json['normal_reward_gold'] as int,
      vipRewardItemId: json['vip_reward_item_id'] as String?,
      vipRewardQuantity: json['vip_reward_quantity'] as int,
      vipRewardGold: json['vip_reward_gold'] as int,
      description: json['description'] as String?,
      normalRewardItem: json['normal_reward_item'] as Map<String, dynamic>?,
      vipRewardItem: json['vip_reward_item'] as Map<String, dynamic>?,
    );
  }
}
