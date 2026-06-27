class DailyRewardGrant {
  const DailyRewardGrant({
    required this.cycleDay,
    required this.displayLabel,
    required this.isMilestone,
    required this.gold,
    required this.gems,
    required this.xp,
    required this.energy,
    this.itemId,
    this.itemName,
    required this.itemQuantity,
  });

  final int cycleDay;
  final String displayLabel;
  final bool isMilestone;
  final int gold;
  final int gems;
  final int xp;
  final int energy;
  final String? itemId;
  final String? itemName;
  final int itemQuantity;

  factory DailyRewardGrant.fromJson(Map<String, dynamic> json) {
    return DailyRewardGrant(
      cycleDay: (json['cycle_day'] as num).toInt(),
      displayLabel: json['display_label'] as String? ?? '',
      isMilestone: json['is_milestone'] as bool? ?? false,
      gold: (json['gold'] as num?)?.toInt() ?? 0,
      gems: (json['gems'] as num?)?.toInt() ?? 0,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      energy: (json['energy'] as num?)?.toInt() ?? 0,
      itemId: json['item_id'] as String?,
      itemName: json['item_name'] as String?,
      itemQuantity: (json['item_quantity'] as num?)?.toInt() ?? 0,
    );
  }

  bool get hasItem => itemId != null && itemQuantity > 0;
}

enum DailyRewardDayStatus { completed, today, locked }

class DailyRewardCalendarDay {
  const DailyRewardCalendarDay({
    required this.cycleDay,
    required this.status,
    required this.reward,
  });

  final int cycleDay;
  final DailyRewardDayStatus status;
  final DailyRewardGrant reward;

  factory DailyRewardCalendarDay.fromJson(Map<String, dynamic> json) {
    final String rawStatus = json['status'] as String? ?? 'locked';
    return DailyRewardCalendarDay(
      cycleDay: (json['cycle_day'] as num).toInt(),
      status: switch (rawStatus) {
        'completed' => DailyRewardDayStatus.completed,
        'today' => DailyRewardDayStatus.today,
        _ => DailyRewardDayStatus.locked,
      },
      reward: DailyRewardGrant.fromJson(
        Map<String, dynamic>.from(json['reward'] as Map),
      ),
    );
  }
}

class DailyRewardStatus {
  const DailyRewardStatus({
    required this.canClaim,
    required this.cycleDay,
    required this.cycleLength,
    required this.streakLength,
    required this.claimedToday,
    required this.todayReward,
    required this.weekCalendar,
    this.nextResetAt,
    this.timezone = 'UTC',
  });

  final bool canClaim;
  final int cycleDay;
  final int cycleLength;
  final int streakLength;
  final bool claimedToday;
  final DailyRewardGrant todayReward;
  final List<DailyRewardCalendarDay> weekCalendar;
  final DateTime? nextResetAt;
  final String timezone;

  factory DailyRewardStatus.fromJson(Map<String, dynamic> json) {
    final List<dynamic> calendar = json['week_calendar'] as List<dynamic>? ?? <dynamic>[];
    final int calendarLen = calendar.length;
    return DailyRewardStatus(
      canClaim: json['can_claim'] as bool? ?? false,
      cycleDay: (json['cycle_day'] as num?)?.toInt() ?? 1,
      cycleLength: (json['cycle_length'] as num?)?.toInt() ??
          (calendarLen > 0 ? calendarLen : 20),
      streakLength: (json['streak_length'] as num?)?.toInt() ?? 0,
      claimedToday: json['claimed_today'] as bool? ?? false,
      todayReward: DailyRewardGrant.fromJson(
        Map<String, dynamic>.from(json['today_reward'] as Map),
      ),
      weekCalendar: calendar
          .map(
            (dynamic e) => DailyRewardCalendarDay.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      nextResetAt: json['next_reset_at'] != null
          ? DateTime.parse(json['next_reset_at'] as String)
          : null,
      timezone: json['timezone'] as String? ?? 'UTC',
    );
  }
}

class DailyRewardClaimResult {
  const DailyRewardClaimResult({
    required this.success,
    this.message,
    this.error,
    this.cycleDay,
    this.streakLength,
    this.rewardsGranted,
    this.newBalances,
  });

  final bool success;
  final String? message;
  final String? error;
  final int? cycleDay;
  final int? streakLength;
  final DailyRewardGrant? rewardsGranted;
  final Map<String, int>? newBalances;

  factory DailyRewardClaimResult.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? balances = json['new_balances'] as Map<String, dynamic>?;
    return DailyRewardClaimResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      error: json['error'] as String?,
      cycleDay: (json['cycle_day'] as num?)?.toInt(),
      streakLength: (json['streak_length'] as num?)?.toInt(),
      rewardsGranted: json['rewards_granted'] != null
          ? DailyRewardGrant.fromJson(
              Map<String, dynamic>.from(json['rewards_granted'] as Map),
            )
          : null,
      newBalances: balances?.map(
        (String k, dynamic v) => MapEntry(k, (v as num).toInt()),
      ),
    );
  }
}
