import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/daily_reward/daily_reward_dialog.dart';
import '../../models/comeback_summary_model.dart';
import '../../providers/comeback_summary_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'comeback_models.dart';
import 'comeback_rewards_portal.dart';

// 2027 Aion 2 Obsidian-Glass & Luminescence Design Tokens
const Color _kCelestialGold = Color(0xFFE5C158);
const Color _kCelestialGoldLight = Color(0xFFFFF2B2);
const Color _kEtherCyan = Color(0xFF00E5FF);
const Color _kEtherCyanGlow = Color(0x3300E5FF);
const Color _kObsidianVoid = Color(0xFF050709);
const Color _kObsidianGlassDark = Color(0xF00A0E18);
const Color _kObsidianGlassMedium = Color(0xF2101726);
const Color _kObsidianCard = Color(0xFF0E151A);
const Color _kObsidianBorder = Color(0x3800E5FF);
const Color _kObsidianGoldBorder = Color(0x66E5C158);

/// Geri dönüş modalı — oturum başına bir kez.
/// 2027 Aion 2 Mobile Standard Returning Warrior Comeback Rewards Portal.
Future<void> showComebackSummaryDialog(
  BuildContext context,
  WidgetRef ref, {
  bool barrierDismissible = true,
}) async {
  // Tactile entry feedback on modal launch
  await HapticFeedback.mediumImpact();

  final ComebackSummaryState state = ref.read(comebackSummaryProvider);
  if (state.summary == null && !state.isLoading) {
    await ref.read(comebackSummaryProvider.notifier).load();
  }
  if (!context.mounted) return;

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Geri Dönüş Özeti',
    barrierColor: _kObsidianVoid.withValues(alpha: 0.72),
    useRootNavigator: true,
    transitionDuration: const Duration(milliseconds: 360),
    pageBuilder: (BuildContext ctx, _, _) => const ComebackSummaryDialog(),
    transitionBuilder: (
      BuildContext ctx,
      Animation<double> anim,
      _,
      Widget child,
    ) {
      final Animation<Offset> slide = Tween<Offset>(
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
      );
      final Animation<double> scale = Tween<double>(
        begin: 0.94,
        end: 1.0,
      ).animate(
        CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
      );
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: slide,
            child: ScaleTransition(
              scale: scale,
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

/// Backwards compatibility alias for the dialog panel.
typedef _ComebackSummaryPanel = ComebackSummaryDialog;

/// 2027 Aion 2 Obsidian-Glass Returning Warrior Comeback Summary Dialog.
class ComebackSummaryDialog extends ConsumerStatefulWidget {
  const ComebackSummaryDialog({
    super.key,
    this.summary,
    this.onClose,
    this.onActionItemTap,
    this.onClaimGift,
    this.useCompactDialog = false,
  });

  final ComebackSummary? summary;
  final VoidCallback? onClose;
  final void Function(ComebackSummaryItem item)? onActionItemTap;
  final VoidCallback? onClaimGift;
  final bool useCompactDialog;

  @override
  ConsumerState<ComebackSummaryDialog> createState() =>
      _ComebackSummaryDialogState();
}

class _ComebackSummaryDialogState
    extends ConsumerState<ComebackSummaryDialog> {
  Future<void> _handleItemTap(ComebackSummaryItem item) async {
    await HapticFeedback.mediumImpact();
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

  void _handleClose() {
    HapticFeedback.mediumImpact();
    ref.read(comebackSummaryProvider.notifier).markShownThisSession();
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _handleClaimGift() {
    HapticFeedback.mediumImpact();
    ref.read(comebackSummaryProvider.notifier).markShownThisSession();
    widget.onClaimGift?.call();
  }

  @override
  Widget build(BuildContext context) {
    final ComebackSummaryState state = ref.watch(comebackSummaryProvider);
    final ComebackSummary? summary = widget.summary ?? state.summary;

    if (state.isLoading && summary == null) {
      return _buildLoadingDialog(context);
    }

    if (summary == null) {
      return _buildErrorDialog(context, state);
    }

    if (widget.useCompactDialog) {
      return _buildCompactSummaryDialog(context, summary);
    }

    // Modern 2027 Aion 2 Mobile Returning Warrior Portal presentation
    return ComebackRewardsPortal(
      summary: summary,
      onClose: _handleClose,
      onActionItemTap: (ComebackSummaryItem item) {
        if (widget.onActionItemTap != null) {
          HapticFeedback.mediumImpact();
          widget.onActionItemTap!(item);
        } else {
          _handleItemTap(item);
        }
      },
      onClaimGift: _handleClaimGift,
      onClaimMilestone: (ComebackMilestoneTier tier) {
        HapticFeedback.mediumImpact();
        ref.read(comebackSummaryProvider.notifier).markShownThisSession();
      },
    );
  }

  Widget _buildLoadingDialog(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        _kObsidianGlassDark,
                        _kObsidianGlassMedium,
                        _kObsidianVoid,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                    border: Border.all(
                      color: _kObsidianGoldBorder,
                      width: 1.4,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: _kCelestialGold.withValues(alpha: 0.22),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: _kEtherCyan.withValues(alpha: 0.16),
                        blurRadius: 24,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const _CelebrationBanner(
                        title: 'KADİM KUTSAMALAR HAZIRLANIYOR',
                        subtitle: 'Geri dönen savaşçının ödülleri taranıyor...',
                        badgeText: '2027 AION 2',
                        icon: Icons.auto_awesome_rounded,
                      ),
                      const SizedBox(height: 24),
                      Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: _kEtherCyan.withValues(alpha: 0.35),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            width: 46,
                            height: 46,
                            child: CircularProgressIndicator(
                              strokeWidth: 3.2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(_kCelestialGold),
                              backgroundColor: Color(0x3300E5FF),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Savaşçının dönüş ganimetleri taranıyor...',
                        style: GoogleFonts.urbanist(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorDialog(BuildContext context, ComebackSummaryState state) {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        _kObsidianGlassDark,
                        _kObsidianGlassMedium,
                        _kObsidianVoid,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                    border: Border.all(
                      color: _kCelestialGold.withValues(alpha: 0.45),
                      width: 1.4,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: _kEtherCyan.withValues(alpha: 0.16),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: _kCelestialGold.withValues(alpha: 0.18),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const _CelebrationBanner(
                        title: 'GERİ DÖNÜŞ BİLGİSİ',
                        subtitle: 'Atreia sunucusu ile bağlantı kuruluyor',
                        badgeText: 'BİLDİRİM',
                        icon: Icons.shield_outlined,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        state.error ??
                            'Geri dönüş özeti yüklenemedi. Lütfen ağ bağlantını kontrol et.',
                        style: GoogleFonts.urbanist(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                Navigator.of(context).pop();
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: AppColors.mutedTitanium.withValues(alpha: 0.35),
                                ),
                                foregroundColor: AppColors.textSecondary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                'Kapat',
                                style: GoogleFonts.urbanist(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                await HapticFeedback.mediumImpact();
                                await ref.read(comebackSummaryProvider.notifier).load();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _kCelestialGold,
                                foregroundColor: _kObsidianVoid,
                                elevation: 4,
                                shadowColor: _kCelestialGold.withValues(alpha: 0.45),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                'Tekrar Dene',
                                style: GoogleFonts.urbanist(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactSummaryDialog(BuildContext context, ComebackSummary summary) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final EdgeInsets safeInsets = MediaQuery.paddingOf(context);
    final double maxDialogHeight = screenSize.height * 0.88;

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 440,
              maxHeight: maxDialogHeight,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        _kObsidianGlassDark,
                        _kObsidianGlassMedium,
                        _kObsidianVoid,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                    border: Border.all(
                      color: _kObsidianGoldBorder,
                      width: 1.4,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: _kCelestialGold.withValues(alpha: 0.22),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: _kEtherCyan.withValues(alpha: 0.16),
                        blurRadius: 24,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Top header with close button
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 14, 8),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: <Color>[_kCelestialGold, _kCelestialGoldLight],
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: _kCelestialGold.withValues(alpha: 0.4),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.wb_twilight_rounded,
                                color: _kObsidianVoid,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Geri Dönen Savaşçı',
                                    style: GoogleFonts.urbanist(
                                      color: AppColors.textPrimary,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  Text(
                                    'Aion 2 Özel Karşılama Portalı',
                                    style: GoogleFonts.urbanist(
                                      color: _kCelestialGold,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _handleClose,
                              icon: const Icon(Icons.close_rounded, color: AppColors.mutedTitanium),
                              tooltip: 'Kapat',
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            safeInsets.bottom > 0 ? safeInsets.bottom : 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              const SizedBox(height: 8),
                              _CelebrationBanner(
                                title: 'KADİM SAVAŞÇI GERİ DÖNÜŞÜ',
                                subtitle: '${(summary.offlineHours / 24).floor().clamp(1, 99)} gündür Atreia\'dan uzaktaydın. Kadim ödüller seni bekliyor!',
                                badgeText: 'ÖDÜLLER HAZIR',
                                icon: Icons.military_tech_rounded,
                              ),
                              const SizedBox(height: 14),
                              if (summary.items.isNotEmpty) ...<Widget>[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Text(
                                      'YOKLUĞUNDA GERÇEKLEŞENLER',
                                      style: GoogleFonts.urbanist(
                                        color: AppColors.mutedTitanium,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _kEtherCyan.withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _kEtherCyan.withValues(alpha: 0.5),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        '${summary.items.length} Bekleyen',
                                        style: GoogleFonts.urbanist(
                                          color: _kEtherCyan,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: summary.items.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (BuildContext context, int index) {
                                    final ComebackSummaryItem item = summary.items[index];
                                    return _CompactActionTile(
                                      item: item,
                                      onTap: () => _handleItemTap(item),
                                    );
                                  },
                                ),
                              ],
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _handleClose,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _kCelestialGold,
                                    foregroundColor: _kObsidianVoid,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 6,
                                    shadowColor: _kCelestialGold.withValues(alpha: 0.45),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      const Icon(Icons.play_arrow_rounded, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Atreia\'ya Dönüş Yap',
                                        style: GoogleFonts.urbanist(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CelebrationBanner extends StatelessWidget {
  const _CelebrationBanner({
    required this.title,
    required this.subtitle,
    this.badgeText,
    this.icon = Icons.auto_awesome_rounded,
  });

  final String title;
  final String subtitle;
  final String? badgeText;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            _kCelestialGold.withValues(alpha: 0.20),
            _kObsidianCard.withValues(alpha: 0.75),
            _kEtherCyan.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: _kCelestialGold.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _kCelestialGold.withValues(alpha: 0.18),
            blurRadius: 16,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: _kEtherCyan.withValues(alpha: 0.12),
            blurRadius: 12,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[_kCelestialGold, _kCelestialGoldLight],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _kCelestialGold.withValues(alpha: 0.45),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(icon, color: _kObsidianVoid, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: GoogleFonts.urbanist(
                    color: _kCelestialGoldLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.urbanist(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          if (badgeText != null) ...<Widget>[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _kEtherCyan.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _kEtherCyan.withValues(alpha: 0.65),
                  width: 1.0,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: _kEtherCyan.withValues(alpha: 0.28),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                badgeText!,
                style: GoogleFonts.urbanist(
                  color: _kEtherCyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactActionTile extends StatelessWidget {
  const _CompactActionTile({
    required this.item,
    required this.onTap,
  });

  final ComebackSummaryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = item.kind.accentColor;

    return Container(
      decoration: BoxDecoration(
        color: _kObsidianCard.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: accent.withValues(alpha: 0.35),
          width: 0.9,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accent.withValues(alpha: 0.4)),
                  ),
                  child: Icon(item.kind.icon, color: accent, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.title,
                        style: GoogleFonts.urbanist(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.mutedTitanium,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _kEtherCyan.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _kEtherCyan.withValues(alpha: 0.55),
                      width: 0.9,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: _kEtherCyan.withValues(alpha: 0.22),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Text(
                    item.ctaLabel,
                    style: GoogleFonts.urbanist(
                      color: _kEtherCyan,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
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
}
