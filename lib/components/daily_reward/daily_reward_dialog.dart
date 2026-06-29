import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/daily_reward_model.dart';
import '../../providers/daily_reward_provider.dart';
import '../../screens/dungeon/dungeon_result_widgets.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../common/app_messenger.dart';
import '../layout/game_screen_background.dart';

abstract final class _DailyRewardTheme {
  static const Color gold = Color(0xFFF5C842);
  static const Color epic = Color(0xFF9B5CF6);
  static const Color panelBorder = Color(0x40232D31);
  static const Color bgMid = Color(0xFF1A2428);
  static const Color bgDeep = Color(0xFF0D1112);
}

Future<void> showDailyRewardDialog(
  BuildContext context,
  WidgetRef ref, {
  bool viewOnly = false,
}) async {
  final DailyRewardState state = ref.read(dailyRewardProvider);
  if (state.status == null && !state.isLoading) {
    await ref.read(dailyRewardProvider.notifier).loadStatus();
  }

  if (!context.mounted) return;

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Günlük Ödül',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (BuildContext ctx, _, __) {
      return _DailyRewardPanel(viewOnly: viewOnly);
    },
    transitionBuilder:
        (BuildContext ctx, Animation<double> anim, _, Widget child) {
          final Animation<Offset> slide = Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(position: slide, child: child),
          );
        },
  );
}

class _DailyRewardPanel extends ConsumerStatefulWidget {
  const _DailyRewardPanel({this.viewOnly = false});

  final bool viewOnly;

  @override
  ConsumerState<_DailyRewardPanel> createState() => _DailyRewardPanelState();
}

class _DailyRewardPanelState extends ConsumerState<_DailyRewardPanel>
    with SingleTickerProviderStateMixin {
  bool _celebrating = false;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleClaim() async {
    final bool ok = await ref.read(dailyRewardProvider.notifier).claim();
    if (!mounted) return;

    if (ok) {
      setState(() => _celebrating = true);
      AppMessenger.showSuccess(context, 'Günlük ödül alındı!');
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final String? error = ref.read(dailyRewardProvider).error;
    if (error != null) {
      AppMessenger.showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DailyRewardState rewardState = ref.watch(dailyRewardProvider);
    final DailyRewardStatus? status = rewardState.status;
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              onTap: rewardState.claimInProgress
                  ? null
                  : () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(color: Colors.black.withValues(alpha: 0.5)),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 440,
                  maxHeight: maxHeight,
                ),
                child: _buildPanel(context, rewardState, status),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(
    BuildContext context,
    DailyRewardState rewardState,
    DailyRewardStatus? status,
  ) {
    if (rewardState.isLoading && status == null) {
      return _glassShell(
        child: const SizedBox(
          height: 240,
          child: Center(
            child: CircularProgressIndicator(color: _DailyRewardTheme.gold),
          ),
        ),
      );
    }

    if (status == null) {
      return _glassShell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              rewardState.error ?? 'Günlük ödül yüklenemedi.',
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat'),
            ),
          ],
        ),
      );
    }

    final DailyRewardGrant today = status.todayReward;
    final bool canClaim = status.canClaim && !widget.viewOnly;

    return _glassShell(
      highlight: today.isMilestone,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildHeader(status),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildRewardGrid(status),
                  const SizedBox(height: 14),
                  _celebrating
                      ? AnimatedResultCard(
                          child: _buildTodayCard(today, highlight: true),
                        )
                      : _buildTodayCard(today, highlight: status.canClaim),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (canClaim)
            FilledButton(
              onPressed: rewardState.claimInProgress ? null : _handleClaim,
              style: FilledButton.styleFrom(
                backgroundColor: _DailyRewardTheme.gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
              child: rewardState.claimInProgress
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Text(
                      'Gün ${status.cycleDay} Ödülünü Al',
                      style: GoogleFonts.exo2(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
            )
          else
            OutlinedButton(
              onPressed: rewardState.claimInProgress
                  ? null
                  : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(
                  color: AppColors.borderDefault.withValues(alpha: 0.6),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                status.claimedToday
                    ? 'Yarın tekrar gel — Gün ${status.cycleDay >= status.cycleLength ? 1 : status.cycleDay + 1}'
                    : 'Kapat',
                style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Gün sıfırlanması: UTC 00:00 • 1 gün kaçırırsan Gün 1',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textTertiary, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _glassShell({required Widget child, bool highlight = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
            border: Border.all(
              color: highlight
                  ? _DailyRewardTheme.gold.withValues(alpha: 0.55)
                  : _DailyRewardTheme.panelBorder,
              width: highlight ? 1.5 : 1,
            ),
            gradient: RadialGradient(
              center: const Alignment(0, -0.4),
              radius: 1.4,
              colors: <Color>[
                _DailyRewardTheme.bgMid.withValues(alpha: 0.94),
                _DailyRewardTheme.bgDeep.withValues(alpha: 0.97),
              ],
            ),
            boxShadow: highlight
                ? <BoxShadow>[
                    BoxShadow(
                      color: _DailyRewardTheme.gold.withValues(alpha: 0.2),
                      blurRadius: 24,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildHeader(DailyRewardStatus status) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '20 Günlük Ödül Yolu',
                style: GoogleFonts.exo2(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gün ${status.cycleDay} / ${status.cycleLength}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        if (status.streakLength > 0 || status.canClaim)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF3D2208).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _DailyRewardTheme.gold.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('🔥', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  status.canClaim
                      ? '${status.streakLength + 1} gün'
                      : '${status.streakLength} gün',
                  style: GoogleFonts.exo2(
                    color: _DailyRewardTheme.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRewardGrid(DailyRewardStatus status) {
    return GameFixedGrid(
      crossAxisCount: 4,
      spacing: 8,
      itemCount: status.weekCalendar.length,
      itemBuilder: (BuildContext context, int index) {
        return AspectRatio(
          aspectRatio: 1,
          child: _buildGridCell(status.weekCalendar[index]),
        );
      },
    );
  }

  Widget _buildGridCell(DailyRewardCalendarDay day) {
    final bool isToday = day.status == DailyRewardDayStatus.today;
    final bool isCompleted = day.status == DailyRewardDayStatus.completed;
    final bool isLocked = day.status == DailyRewardDayStatus.locked;
    final DailyRewardGrant reward = day.reward;
    final bool isEpic = reward.isMilestone;
    final Color accent = isEpic
        ? _DailyRewardTheme.epic
        : _DailyRewardTheme.gold;

    Color borderColor = AppColors.borderFaint;
    Color bgColor = AppColors.bgSurface.withValues(
      alpha: isLocked ? 0.35 : 0.65,
    );

    if (isCompleted) {
      borderColor = AppColors.success.withValues(alpha: 0.55);
      bgColor = AppColors.success.withValues(alpha: 0.14);
    } else if (isToday) {
      borderColor = accent.withValues(alpha: 0.85);
      bgColor = accent.withValues(alpha: 0.16);
    } else if (isEpic) {
      borderColor = accent.withValues(alpha: 0.45);
    }

    final Widget dayNumber = isToday
        ? ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(
              CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
            ),
            child: Text(
              '${day.cycleDay}',
              style: GoogleFonts.exo2(
                color: accent,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          )
        : Text(
            '${day.cycleDay}',
            style: GoogleFonts.exo2(
              color: isCompleted
                  ? AppColors.success
                  : (isEpic ? accent : AppColors.textSecondary),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: isToday || isEpic ? 1.6 : 1,
        ),
        boxShadow: isToday || (isEpic && !isLocked)
            ? <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: isToday ? 0.28 : 0.14),
                  blurRadius: isToday ? 12 : 6,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    dayNumber,
                    const Spacer(),
                    if (isCompleted)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: AppColors.success,
                      )
                    else if (isLocked)
                      Icon(
                        Icons.lock_rounded,
                        size: 11,
                        color: AppColors.textTertiary,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Center(
                    child: _rewardPreviewIcon(
                      reward,
                      dimmed: isLocked && !isEpic,
                    ),
                  ),
                ),
                Text(
                  _rewardShortLabel(reward),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isLocked
                        ? AppColors.textTertiary
                        : (isToday
                              ? AppColors.textPrimary
                              : AppColors.textSecondary),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          if (isEpic)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.85),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(11),
                    bottomLeft: Radius.circular(6),
                  ),
                ),
                child: Text(
                  day.cycleDay == 20 ? 'EFS' : '★',
                  style: GoogleFonts.exo2(
                    color: Colors.white,
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          if (isLocked)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: isEpic ? 0.18 : 0.32),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _rewardPreviewIcon(DailyRewardGrant reward, {required bool dimmed}) {
    final String emoji = _primaryEmoji(reward);
    return Text(
      emoji,
      style: TextStyle(
        fontSize: reward.isMilestone ? 22 : 18,
        color: dimmed ? Colors.white.withValues(alpha: 0.55) : null,
      ),
    );
  }

  String _primaryEmoji(DailyRewardGrant reward) {
    if (reward.hasItem) return '📦';
    if (reward.gems >= 10) return '💎';
    if (reward.gems > 0) return '💠';
    if (reward.gold >= 20000) return '🪙';
    if (reward.energy > 0) return '⚡';
    return '🪙';
  }

  String _rewardShortLabel(DailyRewardGrant reward) {
    if (reward.gems > 0 && reward.gold > 0) {
      return '${_fmt(reward.gold)} + ${reward.gems}💎';
    }
    if (reward.gems > 0) return '${reward.gems} Elmas';
    if (reward.gold > 0) return '${_fmt(reward.gold)} Altın';
    if (reward.hasItem) return 'x${reward.itemQuantity} Eşya';
    if (reward.energy > 0) return '${reward.energy} Enerji';
    return reward.displayLabel;
  }

  Widget _buildTodayCard(DailyRewardGrant grant, {required bool highlight}) {
    final Color accent = grant.isMilestone
        ? _DailyRewardTheme.epic
        : _DailyRewardTheme.gold;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: highlight
              ? accent.withValues(alpha: 0.55)
              : AppColors.borderDefault,
          width: highlight ? 1.5 : 1,
        ),
        boxShadow: highlight
            ? <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.15),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Bugünün Ödülü',
                style: GoogleFonts.exo2(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                grant.displayLabel,
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (grant.isMilestone) ...<Widget>[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    grant.cycleDay == 20 ? 'EFSANE' : 'BONUS',
                    style: GoogleFonts.exo2(
                      color: accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (grant.gold > 0)
                _rewardChip('🪙', '${_fmt(grant.gold)} Altın', AppColors.gold),
              if (grant.gems > 0)
                _rewardChip('💎', '${grant.gems} Elmas', AppColors.accentBlue),
              if (grant.xp > 0)
                _rewardChip('⭐', '${_fmt(grant.xp)} XP', AppColors.liquidGold),
              if (grant.energy > 0)
                _rewardChip(
                  '⚡',
                  '${grant.energy} Enerji',
                  AppColors.accentCyan,
                ),
              if (grant.hasItem)
                _rewardChip(
                  '📦',
                  '${grant.itemName ?? grant.itemId} x${grant.itemQuantity}',
                  AppColors.textSecondary,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rewardChip(String emoji, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
