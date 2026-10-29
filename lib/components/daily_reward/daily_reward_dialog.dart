import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/daily_reward_model.dart';
import '../../providers/daily_reward_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../common/app_messenger.dart';
import '../common/item_icon_view.dart';
import 'chest_unlock_vfx.dart';
import 'daily_calendar_grid.dart';
import 'daily_reward_vfx_models.dart';
import 'reward_item_modal.dart';

/// 2027 Aion 2 Obsidian-Glass & Celestial/Ether Design Tokens
abstract final class _DailyRewardTheme {
  static const Color celestialGold = Color(0xFFE5C158);
  static const Color etherCyan = Color(0xFF00E5FF);
  static const Color gold = Color(0xFFE5C158);
  static const Color epic = Color(0xFF9B5CF6);
  static const Color obsidianBase = Color(0xFF06090B);
  static const Color obsidianSurface = Color(0xFF0E151A);
  static const Color obsidianCard = Color(0xFF121B21);
  static const Color panelBorder = Color(0x3800E5FF);
  static const Color panelBorderSubtle = Color(0x2E2C3D45);
  static const Color borderGold = Color(0x66E5C158);
  static const Color bgMid = Color(0xFF0D1418);
  static const Color bgDeep = Color(0xFF050709);
}

/// Public function to launch the Daily Reward Dialog.
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
    barrierColor: Colors.black.withValues(alpha: 0.65),
    useRootNavigator: true,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (BuildContext ctx, _, __) {
      return _DailyRewardPanel(viewOnly: viewOnly);
    },
    transitionBuilder:
        (BuildContext ctx, Animation<double> anim, _, Widget child) {
      final Animation<Offset> slide = Tween<Offset>(
        begin: const Offset(0, 0.05),
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
  ChestUnlockPhase _chestPhase = ChestUnlockPhase.idle;
  bool _showRewardModal = false;
  DailyRewardCalendarDay? _inspectedDay;
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

  /// Dismisses dialog with selectionClick haptic feedback.
  void _dismissDialog() {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
  }

  /// Triggers the full animated unlock sequence:
  /// Shaking anticipation -> burst rays & particles -> lid opens -> floating reward modal.
  Future<void> _startUnlockSequence() async {
    if (_chestPhase != ChestUnlockPhase.idle) return;
    HapticFeedback.mediumImpact();

    setState(() => _chestPhase = ChestUnlockPhase.anticipating);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    HapticFeedback.mediumImpact();
    setState(() => _chestPhase = ChestUnlockPhase.bursting);
  }

  void _onUnlockSequenceComplete() {
    setState(() {
      _chestPhase = ChestUnlockPhase.opened;
      _showRewardModal = true;
    });
  }

  Future<void> _handleClaim() async {
    HapticFeedback.mediumImpact();
    final bool ok = await ref.read(dailyRewardProvider.notifier).claim();
    if (!mounted) return;

    if (!ok) {
      final String? error = ref.read(dailyRewardProvider).error;
      if (error != null) {
        AppMessenger.showError(context, error);
      }
      setState(() {
        _showRewardModal = false;
        _chestPhase = ChestUnlockPhase.idle;
      });
      return;
    }

    HapticFeedback.mediumImpact();
    final String? warning = ref.read(dailyRewardProvider).lastClaimWarning;
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);

    setState(() {
      _showRewardModal = false;
      _chestPhase = ChestUnlockPhase.opened;
    });

    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (overlay != null && overlay.mounted) {
      final BuildContext overlayContext = overlay.context;
      if (warning != null && warning.isNotEmpty) {
        AppMessenger.show(overlayContext, warning);
      } else {
        AppMessenger.showSuccess(
          overlayContext,
          'Günün hazinesi envanterine eklendi!',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final DailyRewardState rewardState = ref.watch(dailyRewardProvider);
    final DailyRewardStatus? status = rewardState.status;
    final Size screenSize = MediaQuery.sizeOf(context);
    final double maxHeight = screenSize.height * 0.90;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: <Widget>[
          // Obsidian frosted glass modal portal barrier
          Positioned.fill(
            child: GestureDetector(
              onTap: rewardState.claimInProgress || _showRewardModal
                  ? null
                  : _dismissDialog,
              behavior: HitTestBehavior.opaque,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.2),
                      radius: 1.3,
                      colors: <Color>[
                        Colors.black.withValues(alpha: 0.65),
                        const Color(0xFF04070A).withValues(alpha: 0.88),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Modal content wrapped in robust SafeArea
          SafeArea(
            maintainBottomViewPadding: true,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 420,
                    maxHeight: maxHeight,
                  ),
                  child: _buildPanel(context, rewardState, status),
                ),
              ),
            ),
          ),

          // Floating claim reward modal overlay wrapped in SafeArea
          if (_showRewardModal && status != null)
            Positioned.fill(
              child: SafeArea(
                maintainBottomViewPadding: true,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.70),
                  child: RewardItemModal(
                    grant: status.todayReward,
                    isClaiming: rewardState.claimInProgress,
                    onCollect: _handleClaim,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEnergyLine({double height = 1.5, double opacity = 1.0}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Colors.transparent,
            _DailyRewardTheme.etherCyan.withValues(alpha: 0.20 * opacity),
            _DailyRewardTheme.etherCyan.withValues(alpha: 0.85 * opacity),
            _DailyRewardTheme.celestialGold.withValues(alpha: 0.95 * opacity),
            _DailyRewardTheme.etherCyan.withValues(alpha: 0.85 * opacity),
            _DailyRewardTheme.etherCyan.withValues(alpha: 0.20 * opacity),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.18, 0.44, 0.5, 0.56, 0.82, 1.0],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _DailyRewardTheme.etherCyan.withValues(alpha: 0.45 * opacity),
            blurRadius: 6,
            spreadRadius: 0.5,
          ),
          BoxShadow(
            color: _DailyRewardTheme.celestialGold.withValues(alpha: 0.35 * opacity),
            blurRadius: 10,
            spreadRadius: 0.5,
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
          height: 260,
          child: Center(
            child: CircularProgressIndicator(
              color: _DailyRewardTheme.celestialGold,
            ),
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
              rewardState.error ?? 'Günlük ödül durumu yüklenemedi.',
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _dismissDialog,
              style: FilledButton.styleFrom(
                backgroundColor: _DailyRewardTheme.celestialGold,
                foregroundColor: Colors.black,
              ),
              child: const Text('Kapat'),
            ),
          ],
        ),
      );
    }

    final DailyRewardGrant today = status.todayReward;
    final bool canClaim = status.canClaim && !widget.viewOnly;
    final DailyRewardRarity rarity = DailyRewardRarity.fromGrant(today);

    return _glassShell(
      highlight: today.isMilestone || canClaim,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildHeader(status),
          const SizedBox(height: 8),
          _buildEnergyLine(),
          const SizedBox(height: 8),

          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: ChestUnlockVfxWidget(
                      phase: _chestPhase,
                      canClaim: canClaim,
                      rarity: rarity,
                      size: 150,
                      onTapUnlock: _startUnlockSequence,
                      onSequenceComplete: _onUnlockSequenceComplete,
                    ),
                  ),
                  const SizedBox(height: 6),

                  _buildGrantHighlightCard(
                    _inspectedDay != null ? _inspectedDay!.reward : today,
                    isInspecting: _inspectedDay != null,
                    canClaim: canClaim,
                  ),
                  const SizedBox(height: 12),

                  DailyCalendarGrid(
                    status: status,
                    selectedDay: _inspectedDay?.cycleDay ?? status.cycleDay,
                    onDaySelected: (DailyRewardCalendarDay day) {
                      HapticFeedback.selectionClick();
                      setState(() => _inspectedDay = day);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildEnergyLine(height: 1.0, opacity: 0.6),
          const SizedBox(height: 10),

          if (canClaim)
            FilledButton(
              onPressed: rewardState.claimInProgress ||
                      _chestPhase == ChestUnlockPhase.anticipating ||
                      _chestPhase == ChestUnlockPhase.bursting
                  ? null
                  : _startUnlockSequence,
              style: FilledButton.styleFrom(
                backgroundColor: rarity.primaryColor,
                foregroundColor: const Color(0xFF070B0E),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  side: BorderSide(
                    color: _DailyRewardTheme.etherCyan.withValues(alpha: 0.7),
                    width: 1.0,
                  ),
                ),
                elevation: 8,
                shadowColor: rarity.glowColor,
              ),
              child: rewardState.claimInProgress
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF070B0E),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Text('🎁', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          'Gün ${status.cycleDay} Sandığını Aç',
                          style: GoogleFonts.urbanist(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
            )
          else
            OutlinedButton(
              onPressed: _dismissDialog,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(
                  color: _DailyRewardTheme.panelBorderSubtle,
                ),
                backgroundColor:
                    _DailyRewardTheme.obsidianBase.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
              child: Text(
                status.claimedToday
                    ? 'Günün ödülü alındı • Yarın tekrar gel'
                    : 'Kapat',
                style: GoogleFonts.urbanist(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(height: 6),

          const Text(
            'Gün sıfırlanması: UTC 00:00 • Kaçırılan günlerde seri sıfırlanır',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textTertiary, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _glassShell({required Widget child, bool highlight = false}) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (BuildContext context, Widget? _) {
        final double pulse = _pulseCtrl.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
                border: Border.all(
                  color: highlight
                      ? Color.lerp(
                          _DailyRewardTheme.celestialGold.withValues(alpha: 0.55),
                          _DailyRewardTheme.celestialGold.withValues(alpha: 0.90),
                          pulse,
                        )!
                      : _DailyRewardTheme.panelBorder,
                  width: highlight ? 1.6 : 1.2,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    _DailyRewardTheme.obsidianSurface.withValues(alpha: 0.94),
                    _DailyRewardTheme.obsidianBase.withValues(alpha: 0.97),
                    const Color(0xFF040608).withValues(alpha: 0.99),
                  ],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.75),
                    blurRadius: 36,
                    spreadRadius: 4,
                    offset: const Offset(0, 14),
                  ),
                  if (highlight)
                    BoxShadow(
                      color: _DailyRewardTheme.celestialGold.withValues(
                        alpha: 0.16 + (pulse * 0.14),
                      ),
                      blurRadius: 28 + (pulse * 8),
                      spreadRadius: 1 + (pulse * 2),
                    ),
                  BoxShadow(
                    color: _DailyRewardTheme.etherCyan.withValues(
                      alpha: 0.10 + (pulse * 0.08),
                    ),
                    blurRadius: 22,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Stack(
                children: <Widget>[
                  // Celestial gold radiance burst background
                  Positioned(
                    top: -40,
                    left: 0,
                    right: 0,
                    height: 280,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: <Color>[
                              _DailyRewardTheme.celestialGold.withValues(
                                alpha: highlight ? (0.22 + pulse * 0.10) : 0.12,
                              ),
                              _DailyRewardTheme.etherCyan.withValues(
                                alpha: 0.06 + (pulse * 0.04),
                              ),
                              Colors.transparent,
                            ],
                            stops: const <double>[0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Top ether cyan energy line on portal rim
                  Positioned(
                    top: 0,
                    left: 32,
                    right: 32,
                    child: IgnorePointer(
                      child: Container(
                        height: 1.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              Colors.transparent,
                              _DailyRewardTheme.etherCyan.withValues(alpha: 0.3),
                              _DailyRewardTheme.etherCyan.withValues(alpha: 0.9),
                              _DailyRewardTheme.celestialGold,
                              _DailyRewardTheme.etherCyan.withValues(alpha: 0.9),
                              _DailyRewardTheme.etherCyan.withValues(alpha: 0.3),
                              Colors.transparent,
                            ],
                            stops: const <double>[
                              0.0,
                              0.2,
                              0.45,
                              0.5,
                              0.55,
                              0.8,
                              1.0,
                            ],
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: _DailyRewardTheme.etherCyan.withValues(
                                alpha: 0.5,
                              ),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(DailyRewardStatus status) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: <Widget>[
                  Text(
                    'Günlük Ödül Yolu',
                    style: GoogleFonts.urbanist(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: _DailyRewardTheme.celestialGold.withValues(
                        alpha: 0.16,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _DailyRewardTheme.celestialGold.withValues(
                          alpha: 0.45,
                        ),
                        width: 0.8,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: _DailyRewardTheme.celestialGold.withValues(
                            alpha: 0.2,
                          ),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Text(
                      '28 GÜNLÜK',
                      style: GoogleFonts.urbanist(
                        color: _DailyRewardTheme.celestialGold,
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Döngü Günü: ${status.cycleDay} / ${status.cycleLength}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        if (status.streakLength > 0 || status.canClaim)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1408).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _DailyRewardTheme.celestialGold.withValues(alpha: 0.6),
                width: 1.0,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _DailyRewardTheme.celestialGold.withValues(
                    alpha: 0.25,
                  ),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('🔥', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  status.canClaim
                      ? '${status.streakLength + 1} Gün'
                      : '${status.streakLength} Gün',
                  style: GoogleFonts.urbanist(
                    color: _DailyRewardTheme.celestialGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(width: 8),

        IconButton(
          onPressed: _dismissDialog,
          icon: const Icon(Icons.close_rounded, size: 20),
          color: AppColors.textSecondary,
          tooltip: 'Kapat',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildGrantHighlightCard(
    DailyRewardGrant grant, {
    required bool isInspecting,
    required bool canClaim,
  }) {
    final DailyRewardRarity rarity = DailyRewardRarity.fromGrant(grant);
    final Color accent = rarity.primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _DailyRewardTheme.obsidianCard.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isInspecting || canClaim
              ? accent.withValues(alpha: 0.65)
              : _DailyRewardTheme.panelBorderSubtle,
          width: 1.2,
        ),
        boxShadow: (isInspecting || canClaim)
            ? <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.16),
                  blurRadius: 12,
                  spreadRadius: 1,
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
                isInspecting ? 'Gün ${grant.cycleDay} Ödülü' : 'Bugünün Ödülü',
                style: GoogleFonts.urbanist(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                grant.displayLabel,
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (grant.isMilestone)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.45),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    grant.cycleDay == 28 ? 'EFSANEVİ' : 'MİLESTONE',
                    style: GoogleFonts.urbanist(
                      color: accent,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              if (grant.gold > 0)
                _chip(
                  '🪙',
                  '${_formatNum(grant.gold)} Altın',
                  _DailyRewardTheme.celestialGold,
                ),
              if (grant.gems > 0)
                _chip('💎', '${grant.gems} Elmas', _DailyRewardTheme.etherCyan),
              if (grant.xp > 0)
                _chip('⭐', '${_formatNum(grant.xp)} XP', AppColors.liquidGold),
              if (grant.energy > 0)
                _chip(
                  '⚡',
                  '${grant.energy} Enerji',
                  _DailyRewardTheme.etherCyan,
                ),
              if (grant.hasItem) _itemChip(grant, accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String emoji, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemChip(DailyRewardGrant grant, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.40)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ItemIconView(
            iconValue: grant.itemId ?? '',
            itemId: grant.itemId,
            size: 14,
            fallback: '📦',
          ),
          const SizedBox(width: 5),
          Text(
            '${grant.itemName ?? grant.itemId} x${grant.itemQuantity}',
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
