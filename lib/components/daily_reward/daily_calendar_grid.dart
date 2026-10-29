import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/daily_reward_model.dart';
import '../../theme/app_colors.dart';
import '../common/item_icon_view.dart';
import 'daily_reward_vfx_models.dart';

abstract final class _DailyCalendarGridTheme {
  static const Color etherCyan = Color(0xFF00E5FF);
  static const Color celestialGold = Color(0xFFE5C158);
  static const Color goldPulse = Color(0xFFF5C842);
  static const Color obsidianBase = Color(0xFF070A0F);
  static const Color obsidianSurface = Color(0xFF0E141F);
  static const Color obsidianCard = Color(0xFF121B28);
  static const Color borderSubtle = Color(0x28384C66);
}

enum DailyCalendarViewMode {
  sevenDay,
  twentyEightDay,
}

/// Dynamic login reward calendar grid supporting 7-day sprint and 28-day
/// monthly layouts with claimed, available, and locked states.
class DailyCalendarGrid extends StatefulWidget {
  const DailyCalendarGrid({
    super.key,
    required this.status,
    required this.onDaySelected,
    this.selectedDay,
    this.initialViewMode = DailyCalendarViewMode.sevenDay,
  });

  final DailyRewardStatus status;
  final ValueChanged<DailyRewardCalendarDay> onDaySelected;
  final int? selectedDay;
  final DailyCalendarViewMode initialViewMode;

  @override
  State<DailyCalendarGrid> createState() => _DailyCalendarGridState();
}

class _DailyCalendarGridState extends State<DailyCalendarGrid>
    with SingleTickerProviderStateMixin {
  late DailyCalendarViewMode _viewMode;
  late final AnimationController _pulseCtrl;
  Timer? _countdownTimer;
  Duration _remainingResetTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialViewMode;

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _updateCountdown();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateCountdown(),
    );
  }

  @override
  void didUpdateWidget(covariant DailyCalendarGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status.nextResetAt != widget.status.nextResetAt) {
      _updateCountdown();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _updateCountdown() {
    final DateTime nowUtc = DateTime.now().toUtc();
    final DateTime resetTarget = widget.status.nextResetAt?.toUtc() ??
        DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day + 1);

    final Duration diff = resetTarget.difference(nowUtc);
    if (diff.isNegative) {
      _remainingResetTime = Duration.zero;
    } else {
      _remainingResetTime = diff;
    }
    if (mounted) setState(() {});
  }

  String _formatDuration(Duration d) {
    final int hours = d.inHours;
    final int minutes = d.inMinutes.remainder(60);
    final int seconds = d.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  List<DailyRewardCalendarDay> _generateCalendarDays() {
    final List<DailyRewardCalendarDay> baseList = widget.status.weekCalendar;
    final int targetCount = _viewMode == DailyCalendarViewMode.sevenDay ? 7 : 28;

    if (_viewMode == DailyCalendarViewMode.sevenDay) {
      final int curDay = widget.status.cycleDay;
      final int weekOffset = ((curDay - 1) ~/ 7) * 7;
      final List<DailyRewardCalendarDay> sevenDays = <DailyRewardCalendarDay>[];

      for (int i = 1; i <= 7; i++) {
        final int dayNum = weekOffset + i;
        final DailyRewardCalendarDay? existing = baseList.cast<DailyRewardCalendarDay?>().firstWhere(
              (DailyRewardCalendarDay? d) => d?.cycleDay == dayNum,
              orElse: () => null,
            );
        if (existing != null) {
          sevenDays.add(existing);
        } else {
          sevenDays.add(_synthesizeDay(dayNum));
        }
      }
      return sevenDays;
    }

    final List<DailyRewardCalendarDay> full28 = <DailyRewardCalendarDay>[];
    for (int dayNum = 1; dayNum <= targetCount; dayNum++) {
      final DailyRewardCalendarDay? existing = baseList.cast<DailyRewardCalendarDay?>().firstWhere(
            (DailyRewardCalendarDay? d) => d?.cycleDay == dayNum,
            orElse: () => null,
          );
      if (existing != null) {
        full28.add(existing);
      } else {
        full28.add(_synthesizeDay(dayNum));
      }
    }
    return full28;
  }

  DailyRewardCalendarDay _synthesizeDay(int dayNum) {
    final int curDay = widget.status.cycleDay;
    final DailyRewardDayStatus dayStatus;
    if (dayNum < curDay || (dayNum == curDay && widget.status.claimedToday)) {
      dayStatus = DailyRewardDayStatus.completed;
    } else if (dayNum == curDay && widget.status.canClaim) {
      dayStatus = DailyRewardDayStatus.today;
    } else {
      dayStatus = DailyRewardDayStatus.locked;
    }

    final bool isMilestone = dayNum % 7 == 0 || dayNum == 28;
    final DailyRewardGrant grant = DailyRewardGrant(
      cycleDay: dayNum,
      displayLabel: isMilestone ? 'Kilometre Sandığı' : 'Günlük Sandık',
      isMilestone: isMilestone,
      gold: 1500 * dayNum,
      gems: isMilestone ? 25 : (dayNum % 3 == 0 ? 5 : 0),
      xp: 200 * dayNum,
      energy: dayNum % 2 == 0 ? 10 : 0,
      itemId: isMilestone ? 'legendary_chest' : null,
      itemName: isMilestone ? 'Destansı Sandık' : null,
      itemQuantity: isMilestone ? 1 : 0,
    );

    return DailyRewardCalendarDay(
      cycleDay: dayNum,
      status: dayStatus,
      reward: grant,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<DailyRewardCalendarDay> days = _generateCalendarDays();
    final int crossAxisCount = _viewMode == DailyCalendarViewMode.sevenDay ? 4 : 7;
    final double childAspectRatio = _viewMode == DailyCalendarViewMode.sevenDay ? 0.92 : 0.82;

    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildHeaderBar(),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: childAspectRatio,
            ),
            itemBuilder: (BuildContext context, int index) {
              final DailyRewardCalendarDay day = days[index];
              final bool isSelected = widget.selectedDay == day.cycleDay;
              return _buildCalendarCell(day, isSelected);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                color: _DailyCalendarGridTheme.obsidianBase.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _DailyCalendarGridTheme.borderSubtle,
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _segmentButton(
                    label: '7 Günlük',
                    isSelected: _viewMode == DailyCalendarViewMode.sevenDay,
                    onTap: () => _handleModeSwitch(DailyCalendarViewMode.sevenDay),
                  ),
                  _segmentButton(
                    label: '28 Günlük',
                    isSelected: _viewMode == DailyCalendarViewMode.twentyEightDay,
                    onTap: () => _handleModeSwitch(DailyCalendarViewMode.twentyEightDay),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        Flexible(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _DailyCalendarGridTheme.obsidianSurface.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _DailyCalendarGridTheme.etherCyan.withValues(alpha: 0.40),
                    width: 1.0,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: _DailyCalendarGridTheme.etherCyan.withValues(alpha: 0.12),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.timer_outlined,
                      size: 13,
                      color: _DailyCalendarGridTheme.etherCyan,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _formatDuration(_remainingResetTime),
                      style: GoogleFonts.robotoMono(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _segmentButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6.5),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: <Color>[
                    Color(0xFFFFDF79),
                    _DailyCalendarGridTheme.celestialGold,
                  ],
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? <BoxShadow>[
                  BoxShadow(
                    color: _DailyCalendarGridTheme.celestialGold.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.urbanist(
            color: isSelected
                ? const Color(0xFF090D14)
                : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  void _handleModeSwitch(DailyCalendarViewMode mode) {
    if (_viewMode != mode) {
      HapticFeedback.lightImpact();
      setState(() => _viewMode = mode);
    }
  }

  void _handleDayTap(DailyRewardCalendarDay day) {
    HapticFeedback.selectionClick();
    widget.onDaySelected(day);
  }

  void _handleDayLongPress(DailyRewardCalendarDay day) {
    HapticFeedback.lightImpact();
    widget.onDaySelected(day);
  }

  Widget _buildCalendarCell(DailyRewardCalendarDay day, bool isSelected) {
    final bool isCompleted = day.status == DailyRewardDayStatus.completed;
    final bool isToday = day.status == DailyRewardDayStatus.today;
    final bool isLocked = day.status == DailyRewardDayStatus.locked;
    final DailyRewardGrant reward = day.reward;
    final DailyRewardRarity rarity = DailyRewardRarity.fromGrant(reward);
    final Color accent = rarity.primaryColor;

    if (isToday) {
      return AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (BuildContext context, Widget? _) {
          return _buildCellContainer(
            day: day,
            isSelected: isSelected,
            isCompleted: isCompleted,
            isToday: isToday,
            isLocked: isLocked,
            reward: reward,
            rarity: rarity,
            accent: accent,
            pulse: _pulseCtrl.value,
          );
        },
      );
    }

    return _buildCellContainer(
      day: day,
      isSelected: isSelected,
      isCompleted: isCompleted,
      isToday: isToday,
      isLocked: isLocked,
      reward: reward,
      rarity: rarity,
      accent: accent,
      pulse: 0.0,
    );
  }

  Widget _buildCellContainer({
    required DailyRewardCalendarDay day,
    required bool isSelected,
    required bool isCompleted,
    required bool isToday,
    required bool isLocked,
    required DailyRewardGrant reward,
    required DailyRewardRarity rarity,
    required Color accent,
    required double pulse,
  }) {
    Color borderColor = _DailyCalendarGridTheme.borderSubtle;
    double borderWidth = 1.0;
    Gradient bgGradient;
    List<BoxShadow>? shadows;

    if (isToday) {
      borderColor = Color.lerp(
        _DailyCalendarGridTheme.etherCyan,
        _DailyCalendarGridTheme.goldPulse,
        0.30 + (0.45 * pulse),
      )!;
      borderWidth = 1.8;
      bgGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          _DailyCalendarGridTheme.etherCyan.withValues(alpha: 0.16 + (0.10 * pulse)),
          const Color(0xFF131D2A).withValues(alpha: 0.90),
          const Color(0xFF090E17).withValues(alpha: 0.96),
        ],
      );
      shadows = <BoxShadow>[
        BoxShadow(
          color: _DailyCalendarGridTheme.etherCyan.withValues(alpha: 0.40 + (0.30 * pulse)),
          blurRadius: 10 + (6 * pulse),
          spreadRadius: 1 + (1.2 * pulse),
        ),
        BoxShadow(
          color: _DailyCalendarGridTheme.celestialGold.withValues(alpha: 0.25 + (0.25 * pulse)),
          blurRadius: 16 + (8 * pulse),
          spreadRadius: 0.5,
        ),
      ];
    } else if (isCompleted) {
      borderColor = _DailyCalendarGridTheme.celestialGold.withValues(alpha: 0.40);
      borderWidth = 1.0;
      bgGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          _DailyCalendarGridTheme.celestialGold.withValues(alpha: 0.10),
          const Color(0xFF101722).withValues(alpha: 0.85),
          const Color(0xFF080C12).withValues(alpha: 0.92),
        ],
      );
      shadows = <BoxShadow>[
        BoxShadow(
          color: _DailyCalendarGridTheme.celestialGold.withValues(alpha: 0.16),
          blurRadius: 6,
          spreadRadius: 0.5,
        ),
      ];
    } else if (reward.isMilestone) {
      borderColor = accent.withValues(alpha: 0.65);
      borderWidth = 1.2;
      bgGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          accent.withValues(alpha: 0.14),
          const Color(0xFF121A26).withValues(alpha: 0.88),
          const Color(0xFF080D14).withValues(alpha: 0.94),
        ],
      );
      shadows = <BoxShadow>[
        BoxShadow(
          color: accent.withValues(alpha: 0.25),
          blurRadius: 8,
          spreadRadius: 0.5,
        ),
      ];
    } else {
      // Unclaimed dark obsidian
      borderColor = _DailyCalendarGridTheme.borderSubtle;
      borderWidth = 1.0;
      bgGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          _DailyCalendarGridTheme.obsidianCard,
          _DailyCalendarGridTheme.obsidianSurface,
          _DailyCalendarGridTheme.obsidianBase,
        ],
      );
      shadows = null;
    }

    if (isSelected) {
      borderColor = Colors.white;
      borderWidth = 1.8;
      shadows = <BoxShadow>[
        BoxShadow(
          color: _DailyCalendarGridTheme.etherCyan.withValues(alpha: 0.70),
          blurRadius: 12,
          spreadRadius: 1.5,
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.45),
          blurRadius: 6,
        ),
      ];
    }

    final bool is7Day = _viewMode == DailyCalendarViewMode.sevenDay;

    return GestureDetector(
      onTap: () => _handleDayTap(day),
      onLongPress: () => _handleDayLongPress(day),
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            decoration: BoxDecoration(
              gradient: bgGradient,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: borderColor,
                width: borderWidth,
              ),
              boxShadow: shadows,
            ),
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            '${day.cycleDay}',
                            style: GoogleFonts.urbanist(
                              color: isToday
                                  ? _DailyCalendarGridTheme.etherCyan
                                  : (isCompleted
                                      ? _DailyCalendarGridTheme.celestialGold
                                      : (isLocked
                                          ? const Color(0xFF5D7196)
                                          : AppColors.textSecondary)),
                              fontWeight: FontWeight.w900,
                              fontSize: is7Day ? 11.5 : 10.0,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(
                              right: reward.isMilestone ? 14.0 : 0.0,
                            ),
                            child: _buildStateStatusBadge(
                              isCompleted: isCompleted,
                              isToday: isToday,
                              isLocked: isLocked,
                              pulse: pulse,
                            ),
                          ),
                        ],
                      ),

                      Expanded(
                        child: Center(
                          child: _buildRewardIcon(
                            reward,
                            dimmed: isLocked,
                            isToday: isToday,
                          ),
                        ),
                      ),

                      Text(
                        _getShortLabel(reward),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isToday
                              ? const Color(0xFFE0F7FA)
                              : (isCompleted
                                  ? _DailyCalendarGridTheme.celestialGold
                                  : (isLocked
                                      ? const Color(0xFF5D7196)
                                      : AppColors.textPrimary)),
                          fontSize: is7Day ? 9.0 : 8.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                if (reward.isMilestone)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _buildMilestoneRibbon(day, accent),
                  ),

                if (isCompleted)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStateStatusBadge({
    required bool isCompleted,
    required bool isToday,
    required bool isLocked,
    required double pulse,
  }) {
    if (isCompleted) {
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1E1708),
          border: Border.all(
            color: _DailyCalendarGridTheme.celestialGold,
            width: 1.0,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: _DailyCalendarGridTheme.celestialGold.withValues(alpha: 0.75),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 9,
          color: _DailyCalendarGridTheme.celestialGold,
        ),
      );
    }

    if (isToday) {
      return Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _DailyCalendarGridTheme.etherCyan,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: _DailyCalendarGridTheme.etherCyan.withValues(
                alpha: (0.75 + (0.20 * pulse)).clamp(0.0, 1.0),
              ),
              blurRadius: 5 + (2 * pulse),
              spreadRadius: 1 + (0.5 * pulse),
            ),
          ],
        ),
      );
    }

    if (isLocked) {
      return const Icon(
        Icons.lock_outline_rounded,
        size: 10,
        color: Color(0xFF536785),
      );
    }

    return const SizedBox(width: 8, height: 8);
  }

  Widget _buildMilestoneRibbon(DailyRewardCalendarDay day, Color accent) {
    if (day.cycleDay == 28) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[
              Color(0xFFFFDF79),
              _DailyCalendarGridTheme.celestialGold,
              Color(0xFFD49E24),
            ],
          ),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(9),
            bottomLeft: Radius.circular(5),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: _DailyCalendarGridTheme.celestialGold.withValues(alpha: 0.50),
              blurRadius: 6,
            ),
          ],
        ),
        child: const Text(
          '👑',
          style: TextStyle(fontSize: 7.5),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.90),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(9),
          bottomLeft: Radius.circular(5),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.45),
            blurRadius: 6,
          ),
        ],
      ),
      child: const Text(
        '★',
        style: TextStyle(
          fontSize: 7.5,
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildRewardIcon(
    DailyRewardGrant reward, {
    required bool dimmed,
    required bool isToday,
  }) {
    if (reward.hasItem && reward.itemId != null) {
      return Opacity(
        opacity: dimmed ? 0.45 : 1.0,
        child: ItemIconView(
          iconValue: reward.itemId!,
          itemId: reward.itemId,
          size: 26,
          fallback: '📦',
        ),
      );
    }

    String emoji = '🪙';
    if (reward.gems >= 20) {
      emoji = '💎';
    } else if (reward.gems > 0) {
      emoji = '💠';
    } else if (reward.gold >= 20000) {
      emoji = '🪙';
    } else if (reward.energy > 0) {
      emoji = '⚡';
    }

    return Text(
      emoji,
      style: TextStyle(
        fontSize: reward.isMilestone ? 22 : 18,
        color: dimmed ? Colors.white.withValues(alpha: 0.45) : null,
      ),
    );
  }

  String _getShortLabel(DailyRewardGrant reward) {
    if (reward.hasItem) {
      return reward.itemName ?? 'Eşya';
    }
    if (reward.gems > 0 && reward.gold > 0) {
      return '${reward.gems}💎';
    }
    if (reward.gems > 0) return '${reward.gems} 💎';
    if (reward.gold >= 1000) return '${(reward.gold / 1000).toStringAsFixed(0)}K';
    if (reward.gold > 0) return '${reward.gold}🪙';
    if (reward.energy > 0) return '${reward.energy}⚡';
    return reward.displayLabel;
  }
}
