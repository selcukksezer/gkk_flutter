import '../../models/quest_model.dart';

/// Quest category filter options for UI and logic.
enum QuestCategory { all, daily, weekly, main }

/// Result of validating whether a quest reward can be claimed.
class ClaimValidationResult {
  const ClaimValidationResult({
    required this.canClaim,
    this.failureReason,
  });

  final bool canClaim;
  final String? failureReason;

  static const ClaimValidationResult success = ClaimValidationResult(canClaim: true);
}

/// Core business logic engine for Quests.
///
/// Encapsulates:
/// - Category filtering
/// - Priority & progress-based sorting
/// - Objective completion verification
/// - Daily reset and expiration calculation
/// - Reward formatting and claim validation
/// - Season quest completion tracking
abstract final class QuestLogic {
  /// Filters quests by category according to gkk_flutter core business rules:
  /// - [QuestCategory.all]: all quests.
  /// - [QuestCategory.daily]: Season daily quests or quests with ID 'q_d*' or difficulty easy/medium.
  /// - [QuestCategory.weekly]: Season weekly quests or quests with ID 'q_w*' or difficulty hard.
  /// - [QuestCategory.main]: Non-season elite or dungeon quests.
  static List<QuestData> filterByCategory(
    List<QuestData> quests,
    QuestCategory category,
  ) {
    if (category == QuestCategory.all) return quests;

    return switch (category) {
      QuestCategory.daily => quests.where((q) {
          if (q.isSeasonQuest) return q.questType == 'daily';
          return q.questId.startsWith('q_d') ||
              q.difficulty == QuestDifficulty.easy ||
              q.difficulty == QuestDifficulty.medium;
        }).toList(),
      QuestCategory.weekly => quests.where((q) {
          if (q.isSeasonQuest) return q.questType == 'weekly';
          return q.questId.startsWith('q_w') ||
              q.difficulty == QuestDifficulty.hard;
        }).toList(),
      QuestCategory.main => quests.where((q) {
          if (q.isSeasonQuest) return false;
          return q.difficulty == QuestDifficulty.elite ||
              q.difficulty == QuestDifficulty.dungeon;
        }).toList(),
      QuestCategory.all => quests,
    };
  }

  /// Sorts quests by status rank, then by progress percentage descending.
  /// Rank order:
  /// 0: Completed (ready for claim / done)
  /// 1: Active
  /// 2: Available, Failed, etc.
  static List<QuestData> sortQuests(List<QuestData> quests) {
    final list = List<QuestData>.from(quests);
    list.sort((a, b) {
      int rank(QuestData q) {
        if (q.status == QuestStatus.completed) return 0;
        if (q.status == QuestStatus.active) return 1;
        return 2;
      }

      final cmp = rank(a).compareTo(rank(b));
      if (cmp != 0) return cmp;

      final aPct = calculateProgressFraction(a);
      final bPct = calculateProgressFraction(b);
      return bPct.compareTo(aPct);
    });
    return list;
  }

  /// Calculates progress fraction between 0.0 and 1.0.
  static double calculateProgressFraction(QuestData quest) {
    if (quest.progressMax <= 0) return 0.0;
    return (quest.progress / quest.progressMax).clamp(0.0, 1.0);
  }

  /// Calculates aggregate completion rate across a list of quests (0.0 to 1.0).
  /// Completed quests contribute 1.0; other quests contribute their clamped progress fraction.
  static double calculateOverallCompletionRate(List<QuestData> quests) {
    if (quests.isEmpty) return 0.0;
    double sum = 0.0;
    for (final q in quests) {
      if (q.status == QuestStatus.completed) {
        sum += 1.0;
        continue;
      }
      if (q.progressMax <= 0) continue;
      sum += (q.progress / q.progressMax).clamp(0.0, 1.0);
    }
    return sum / quests.length;
  }

  /// Counts quests that are either already completed or active with 100% progress.
  static int countCompletedOrReady(List<QuestData> quests) {
    return quests.where((QuestData q) {
      if (q.status == QuestStatus.completed) return true;
      return q.status == QuestStatus.active &&
          q.progressMax > 0 &&
          q.progress >= q.progressMax;
    }).length;
  }

  /// Checks if quest objective is achieved.
  static bool isObjectiveCompleted(QuestData quest) {
    if (quest.status == QuestStatus.completed) return true;
    return quest.progressMax > 0 && quest.progress >= quest.progressMax;
  }

  /// Checks if quest needs player action (claim reward or complete active quest).
  static bool needsAction(QuestData quest) {
    if (quest.status == QuestStatus.completed) return true;
    return quest.status == QuestStatus.active &&
        quest.progressMax > 0 &&
        quest.progress >= quest.progressMax;
  }

  /// Formats time remaining until [expiresAt], or null if no expiration.
  static String? formatTimeRemaining(String? expiresAt, {DateTime? now}) {
    if (expiresAt == null || expiresAt.isEmpty) return null;
    final dt = DateTime.tryParse(expiresAt);
    if (dt == null) return null;

    final current = now ?? DateTime.now();
    final diff = dt.difference(current);

    if (diff.isNegative) return 'Süresi doldu';
    if (diff.inDays > 0) return '${diff.inDays}g ${diff.inHours % 24}s';
    if (diff.inHours > 0) return '${diff.inHours}s ${diff.inMinutes % 60}dk';
    return '${diff.inMinutes}dk kaldı';
  }

  /// Computes the next daily reset timestamp (default UTC 00:00).
  static DateTime getNextDailyResetUtc({DateTime? now, int resetHourUtc = 0}) {
    final current = (now ?? DateTime.now()).toUtc();
    final todayReset = DateTime.utc(
      current.year,
      current.month,
      current.day,
      resetHourUtc,
    );
    if (current.isBefore(todayReset)) {
      return todayReset;
    }
    return todayReset.add(const Duration(days: 1));
  }

  /// Formats remaining time until the next daily reset.
  static String formatDailyResetCountdown({DateTime? now, int resetHourUtc = 0}) {
    final current = (now ?? DateTime.now()).toUtc();
    final reset = getNextDailyResetUtc(now: current, resetHourUtc: resetHourUtc);
    final diff = reset.difference(current);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    return '${hours}s ${minutes}dk';
  }

  /// Validates whether a quest is eligible for reward claiming.
  static ClaimValidationResult validateClaim(QuestData quest) {
    if (quest.questId.trim().isEmpty) {
      return const ClaimValidationResult(
        canClaim: false,
        failureReason: 'Geçersiz görev ID',
      );
    }
    if (quest.status != QuestStatus.completed) {
      if (quest.status == QuestStatus.active &&
          quest.progressMax > 0 &&
          quest.progress >= quest.progressMax) {
        return const ClaimValidationResult(
          canClaim: false,
          failureReason: 'Görev henüz tamamlanmadı (önce tamamla)',
        );
      }
      return const ClaimValidationResult(
        canClaim: false,
        failureReason: 'Görev tamamlanmadı',
      );
    }
    return ClaimValidationResult.success;
  }

  /// Formats reward summary parts (e.g. ['🪙100', '✨50 XP', '💎5']).
  static List<String> formatRewardParts(QuestData quest) {
    return <String>[
      if (quest.goldReward > 0) '🪙${quest.goldReward}',
      if (quest.xpReward > 0) '✨${quest.xpReward} XP',
      if (quest.gemReward > 0) '💎${quest.gemReward}',
    ];
  }

  /// Formats human-readable reward claim snackbar message.
  static String formatClaimMessage(QuestData quest) {
    final parts = formatRewardParts(quest);
    if (parts.isEmpty) return '🎁 Ödül alındı!';
    return '🎁 Ödül alındı: ${parts.join(' + ')}';
  }

  /// Detects newly completed season quests that haven't been tracked yet.
  /// Returns the first new key for redirection, or null.
  static String? detectNewCompletedSeasonQuest(
    List<QuestData> quests,
    Set<String> knownCompletedSeasonQuests,
  ) {
    for (final quest in quests) {
      if (!quest.isSeasonQuest || quest.status != QuestStatus.completed) {
        continue;
      }
      final key = quest.bpPlayerQuestId ?? quest.questId;
      if (!knownCompletedSeasonQuests.contains(key)) {
        return key;
      }
    }
    return null;
  }
}
