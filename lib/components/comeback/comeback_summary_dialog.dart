import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/common/universal_game_dialog.dart';
import '../../components/daily_reward/daily_reward_dialog.dart';
import '../../components/layout/game_screen_background.dart';
import '../../models/comeback_summary_model.dart';
import '../../providers/comeback_summary_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Geri dönüş modalı — oturum başına bir kez.
Future<void> showComebackSummaryDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final ComebackSummaryState state = ref.read(comebackSummaryProvider);
  if (state.summary == null && !state.isLoading) {
    await ref.read(comebackSummaryProvider.notifier).load();
  }
  if (!context.mounted) return;

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Geri Dönüş Özeti',
    barrierColor: AppColors.carbonVoid.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 340),
    pageBuilder: (BuildContext ctx, _, _) => const _ComebackSummaryPanel(),
    transitionBuilder: (
      BuildContext ctx,
      Animation<double> anim,
      _,
      Widget child,
    ) {
      final Animation<Offset> slide = Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
      );
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: FadeTransition(
          opacity: anim,
          child: SlideTransition(position: slide, child: child),
        ),
      );
    },
  );
}

class _ComebackSummaryPanel extends ConsumerStatefulWidget {
  const _ComebackSummaryPanel();

  @override
  ConsumerState<_ComebackSummaryPanel> createState() =>
      _ComebackSummaryPanelState();
}

class _ComebackSummaryPanelState extends ConsumerState<_ComebackSummaryPanel> {
  Future<void> _handleItemTap(ComebackSummaryItem item) async {
    if (!mounted) return;
    Navigator.of(context).pop();

    if (item.kind == ComebackItemKind.dailyReward) {
      await showDailyRewardDialog(context, ref, viewOnly: false);
      return;
    }

    if (item.route.isNotEmpty) {
      context.push(item.route);
    }
  }

  String _offlineLabel(double hours) {
    if (hours >= 24) {
      final int days = (hours / 24).floor();
      return '$days gün yoktun';
    }
    if (hours >= 1) {
      return '${hours.toStringAsFixed(1)} saat yoktun';
    }
    final int minutes = (hours * 60).round();
    // Heartbeat race / <1 dk → "0 dk yoktun" spam; gerçek süre yoksa nötr karşılama.
    if (minutes < 1) return 'Tekrar hoş geldin';
    return '$minutes dk yoktun';
  }

  @override
  Widget build(BuildContext context) {
    final ComebackSummaryState state = ref.watch(comebackSummaryProvider);
    final ComebackSummary? summary = state.summary;
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.86;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: AppColors.carbonVoid.withValues(alpha: 0.35),
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
                child: _buildBody(context, state, summary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ComebackSummaryState state,
    ComebackSummary? summary,
  ) {
    if (state.isLoading && summary == null) {
      return UniversalDialogPanel(
        borderColor: AppColors.liquidGold.withValues(alpha: 0.45),
        padding: const EdgeInsets.all(24),
        child: const SizedBox(
          height: 180,
          child: Center(
            child: CircularProgressIndicator(color: AppColors.liquidGold),
          ),
        ),
      );
    }

    if (summary == null) {
      return UniversalDialogPanel(
        borderColor: AppColors.mutedTitanium.withValues(alpha: 0.35),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              state.error ?? 'Özet yüklenemedi.',
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat'),
            ),
          ],
        ),
      );
    }

    return UniversalDialogPanel(
      borderColor: AppColors.liquidGold.withValues(alpha: 0.5),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildHeader(summary),
          const SizedBox(height: 12),
          if (summary.pendingCount > 0) ...<Widget>[
            _buildTotalPill(summary.pendingCount),
            const SizedBox(height: 10),
          ],
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < summary.items.length; i++)
                    _ComebackActionRow(
                      item: summary.items[i],
                      index: i,
                      onTap: () => _handleItemTap(summary.items[i]),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _DismissButton(onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }

  Widget _buildHeader(ComebackSummary summary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.liquidGold.withValues(alpha: 0.25),
                AppColors.cyberFuchsia.withValues(alpha: 0.18),
              ],
            ),
            border: Border.all(
              color: AppColors.liquidGold.withValues(alpha: 0.45),
            ),
          ),
          child: const Icon(
            Icons.wb_twilight_rounded,
            color: AppColors.liquidGold,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Geri Dönüş Özeti',
                style: GoogleFonts.urbanist(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _offlineLabel(summary.offlineHours),
                style: const TextStyle(
                  color: AppColors.mutedTitanium,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, color: AppColors.mutedTitanium),
        ),
      ],
    );
  }

  Widget _buildTotalPill(int count) {
    return DottedPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderColor: AppColors.liquidGold.withValues(alpha: 0.28),
      child: Row(
        children: <Widget>[
          const Icon(Icons.notifications_active_rounded, color: AppColors.liquidGold, size: 18),
          const SizedBox(width: 8),
          Text(
            'Toplam',
            style: GoogleFonts.urbanist(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            '$count bekleyen aksiyon',
            style: GoogleFonts.urbanist(
              color: AppColors.liquidGold,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComebackActionRow extends StatefulWidget {
  const _ComebackActionRow({
    required this.item,
    required this.index,
    required this.onTap,
  });

  final ComebackSummaryItem item;
  final int index;
  final VoidCallback onTap;

  @override
  State<_ComebackActionRow> createState() => _ComebackActionRowState();
}

class _ComebackActionRowState extends State<_ComebackActionRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fade = CurvedAnimation(
      parent: _entryCtrl,
      curve: Curves.easeOutCubic,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutBack),
    );
    Future<void>.delayed(
      Duration(milliseconds: 40 * widget.index),
      () {
        if (mounted) _entryCtrl.forward();
      },
    );
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.item.kind.accentColor;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.onTap,
            child: AnimatedScale(
              scale: _pressed ? 0.98 : 1,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              child: DottedPanel(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                borderColor: accent.withValues(alpha: 0.22),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: accent.withValues(alpha: 0.35)),
                      ),
                      child: Icon(widget.item.kind.icon, color: accent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.item.title,
                            style: GoogleFonts.urbanist(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.item.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.mutedTitanium,
                              fontSize: 11,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RowCta(label: widget.item.ctaLabel, accent: accent),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RowCta extends StatelessWidget {
  const _RowCta({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final bool isGold = accent == AppColors.liquidGold || accent == AppColors.warningSolar;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        gradient: isGold
            ? AppColors.liquidGoldGradient
            : LinearGradient(
                colors: <Color>[
                  accent.withValues(alpha: 0.85),
                  accent.withValues(alpha: 0.65),
                ],
              ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.urbanist(
          color: isGold ? AppColors.carbonVoid : Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _DismissButton extends StatelessWidget {
  const _DismissButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.mutedTitanium,
        side: BorderSide(color: AppColors.darkObsidian.withValues(alpha: 0.9)),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
      child: Text(
        'Tamam, anladım',
        style: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
      ),
    );
  }
}
