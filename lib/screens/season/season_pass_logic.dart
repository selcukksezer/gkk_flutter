import '../../core/constants/economy_constants.dart';
import '../../models/battle_pass.dart';

/// Core Business Logic and Validation Engine for Season Pass.
/// Safeguards level calculation, XP threshold scaling, VIP status,
/// reward claim eligibility, daily caps, and quest progression.
class SeasonPassLogic {
  SeasonPassLogic._();

  /// Default XP required per season pass level.
  static const int xpPerLevel = 1000;

  /// Daily Dungeon (Grind) BPP cap.
  static const int dailyGrindBppCap = 300;

  /// Daily PvP BPP cap.
  static const int dailyPvpBppCap = 200;

  /// Default VIP pass gem cost from EconomyConstants.
  static const int defaultVipGemCost = EconomyConstants.battlePassVipGemCost;

  // ─── Level & XP Calculations ──────────────────────────────────────────────

  /// Calculates the XP earned within the current level (0..999).
  static int calculateXpInCurrentLevel(int currentBpp) {
    if (currentBpp <= 0) return 0;
    return currentBpp % xpPerLevel;
  }

  /// Calculates normalized progress (0.0 .. 1.0) towards the next level.
  static double calculateLevelProgress(int currentBpp) {
    if (currentBpp <= 0) return 0.0;
    final int inLevel = currentBpp % xpPerLevel;
    return (inLevel / xpPerLevel.toDouble()).clamp(0.0, 1.0);
  }

  /// Calculates total BPP required to reach a specific level starting from 0.
  static int totalBppForLevel(int targetLevel) {
    if (targetLevel <= 0) return 0;
    return targetLevel * xpPerLevel;
  }

  /// Computes remaining BPP needed to reach the next level.
  static int bppNeededForNextLevel(int currentBpp) {
    if (currentBpp < 0) return xpPerLevel;
    final int currentInLevel = currentBpp % xpPerLevel;
    return xpPerLevel - currentInLevel;
  }

  /// Checks if daily grind (dungeon) pool reached or exceeded the cap.
  static bool isDailyGrindCapped(int pool) {
    return pool >= dailyGrindBppCap;
  }

  /// Checks if daily PvP pool reached or exceeded the cap.
  static bool isDailyPvpCapped(int pool) {
    return pool >= dailyPvpBppCap;
  }

  /// Calculates remaining daily grind BPP allowance.
  static int remainingDailyGrindAllowance(int pool) {
    if (pool >= dailyGrindBppCap) return 0;
    if (pool < 0) return dailyGrindBppCap;
    return dailyGrindBppCap - pool;
  }

  /// Calculates remaining daily PvP BPP allowance.
  static int remainingDailyPvpAllowance(int pool) {
    if (pool >= dailyPvpBppCap) return 0;
    if (pool < 0) return dailyPvpBppCap;
    return dailyPvpBppCap - pool;
  }

  // ─── Reward Claim Tracking & Eligibility ─────────────────────────────────

  /// Evaluates whether a specific level has been reached by the player.
  /// Reward levels must be > 0 and <= currentLevel.
  static bool isLevelReached({
    required int currentLevel,
    required int rewardLevel,
  }) {
    return rewardLevel > 0 && currentLevel >= rewardLevel;
  }

  /// Evaluates whether the free track reward for a given level can be claimed.
  static bool isFreeRewardClaimable({
    required int currentLevel,
    required int rewardLevel,
    required List<int> claimedNormal,
  }) {
    if (!isLevelReached(currentLevel: currentLevel, rewardLevel: rewardLevel)) {
      return false;
    }
    return !claimedNormal.contains(rewardLevel);
  }

  /// Evaluates whether the VIP track reward for a given level can be claimed.
  static bool isVipRewardClaimable({
    required int currentLevel,
    required int rewardLevel,
    required bool hasVip,
    required List<int> claimedVip,
  }) {
    if (!hasVip) return false;
    if (!isLevelReached(currentLevel: currentLevel, rewardLevel: rewardLevel)) {
      return false;
    }
    return !claimedVip.contains(rewardLevel);
  }

  /// Checks if a VIP reward is locked specifically due to missing VIP upgrade,
  /// even though the level has already been reached.
  static bool isVipRewardLocked({
    required int currentLevel,
    required int rewardLevel,
    required bool hasVip,
  }) {
    return !hasVip &&
        isLevelReached(currentLevel: currentLevel, rewardLevel: rewardLevel);
  }

  /// Returns total number of pending claimable rewards (free + VIP).
  static int countClaimableRewards({
    required BpPlayerStatus? status,
    required List<BpLevelReward> rewards,
  }) {
    if (status == null || rewards.isEmpty) return 0;
    final int currentLevel = status.currentLevel;
    final bool hasVip = status.hasVip;
    final Set<int> normalSet = status.claimedNormal.toSet();
    final Set<int> vipSet = status.claimedVip.toSet();

    int count = 0;
    for (final reward in rewards) {
      if (!isLevelReached(currentLevel: currentLevel, rewardLevel: reward.level)) {
        continue;
      }
      if (!normalSet.contains(reward.level)) {
        count++;
      }
      if (hasVip && !vipSet.contains(reward.level)) {
        count++;
      }
    }
    return count;
  }

  // ─── VIP Pass Upgrade Validation ──────────────────────────────────────────

  /// Validates whether the player has enough gems to purchase the VIP pass.
  static bool canAffordVipPass({
    required int playerGems,
    int cost = defaultVipGemCost,
  }) {
    return playerGems >= cost;
  }

  /// Calculates missing gems if player cannot afford VIP pass.
  static int missingGemsForVip({
    required int playerGems,
    int cost = defaultVipGemCost,
  }) {
    if (playerGems >= cost) return 0;
    return cost - playerGems;
  }

  // ─── Quest Progression & Sorting ──────────────────────────────────────────

  /// Calculates normalized quest progress (0.0 .. 1.0).
  static double calculateQuestProgress({
    required int currentProgress,
    required int targetCount,
  }) {
    if (targetCount <= 0) return 0.0;
    if (currentProgress <= 0) return 0.0;
    return (currentProgress / targetCount.toDouble()).clamp(0.0, 1.0);
  }

  /// Determines whether a quest reward is ready to be claimed.
  static bool isQuestClaimable({
    required bool isCompleted,
    required bool rewardClaimed,
  }) {
    return isCompleted && !rewardClaimed;
  }

  /// Sorts player quests by priority:
  /// 1. Ready to claim (`isCompleted && !rewardClaimed`)
  /// 2. In progress (`!isCompleted`)
  /// 3. Completed and already claimed (`isCompleted && rewardClaimed`)
  /// Secondary sort: higher progress first.
  static List<BpPlayerQuest> sortQuests(List<BpPlayerQuest> quests) {
    final List<BpPlayerQuest> sorted = List<BpPlayerQuest>.from(quests);
    sorted.sort((BpPlayerQuest a, BpPlayerQuest b) {
      int rank(BpPlayerQuest q) {
        if (q.isCompleted && !q.rewardClaimed) return 0;
        if (!q.isCompleted) return 1;
        return 2;
      }

      final int rankCmp = rank(a).compareTo(rank(b));
      if (rankCmp != 0) return rankCmp;
      return b.currentProgress.compareTo(a.currentProgress);
    });
    return sorted;
  }

  // ─── Milestone Levels ─────────────────────────────────────────────────────

  /// Checks if the given level is a key milestone level (5, 10, 15, 20).
  static bool isMilestoneLevel(int level) {
    return level == 5 || level == 10 || level == 15 || level == 20;
  }
}
