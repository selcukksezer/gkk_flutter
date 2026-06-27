import 'package:flutter/material.dart';

import '../../../components/common/gkk_progress_bar.dart';
import '../../../components/layout/game_screen_background.dart';
import '../../../repositories/guild_monument_repository.dart';
import '../../../models/guild_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';

/// Shared tasarim-aligned surfaces for Lonca Anıtı screens.
abstract final class MonumentUi {
  static EdgeInsets pagePadding(BuildContext context) => GameScrollLayout.pagePadding(context);

  static Widget get sectionSpacer => GameScrollLayout.sectionSpacer;
  static Widget get itemSpacer => GameScrollLayout.itemSpacer;
  static Widget get titleSpacer => GameScrollLayout.titleSpacer;
}

Widget monumentScreenShell({required Widget child}) {
  return GameScreenBackground(child: child);
}

Widget monumentPanel({
  required Widget child,
  Color? borderColor,
  EdgeInsetsGeometry? padding,
}) {
  return DottedPanel(
    padding: padding ?? const EdgeInsets.all(AppSpacing.md),
    borderRadius: AppSpacing.radiusLg,
    borderColor: borderColor ?? AppColors.liquidGold.withValues(alpha: 0.22),
    child: child,
  );
}

Widget monumentSectionTitle(String title, {Color accent = AppColors.liquidGold}) {
  return Row(
    children: <Widget>[
      Container(
        width: 4,
        height: 22,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(4),
          boxShadow: <BoxShadow>[BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 6)],
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: AppTextStyles.h3.copyWith(fontSize: 15),
        ),
      ),
    ],
  );
}

Widget monumentEmptyState({
  required String title,
  required String message,
  required Widget primaryAction,
  Widget? secondaryAction,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: monumentPanel(
        borderColor: AppColors.cyberFuchsia.withValues(alpha: 0.35),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cyberFuchsia.withValues(alpha: 0.10),
                border: Border.all(color: AppColors.cyberFuchsia.withValues(alpha: 0.45)),
                boxShadow: <BoxShadow>[
                  BoxShadow(color: AppColors.cyberFuchsia.withValues(alpha: 0.22), blurRadius: 18),
                ],
              ),
              child: const Text('🏛️', style: TextStyle(fontSize: 38)),
            ),
            const SizedBox(height: AppSpacing.base),
            Text(title, textAlign: TextAlign.center, style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.mutedTitanium, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(width: double.infinity, child: primaryAction),
            if (secondaryAction != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              secondaryAction,
            ],
          ],
        ),
      ),
    ),
  );
}

Widget monumentErrorState({required VoidCallback onRetry}) {
  return monumentEmptyState(
    title: 'Anıt yüklenemedi',
    message: 'Veriler şu an alınamadı. Bağlantını kontrol edip tekrar dene.',
    primaryAction: monumentGoldButton(label: 'Tekrar Dene', onPressed: onRetry),
  );
}

Widget monumentGoldButton({
  required String label,
  required VoidCallback? onPressed,
  bool expand = true,
  IconData? icon,
}) {
  final Widget child = icon == null
      ? FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.liquidGold,
            disabledBackgroundColor: AppColors.darkObsidian,
            foregroundColor: AppColors.carbonVoid,
            disabledForegroundColor: AppColors.mutedTitanium,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          ),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        )
      : FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.liquidGold,
            disabledBackgroundColor: AppColors.darkObsidian,
            foregroundColor: AppColors.carbonVoid,
            disabledForegroundColor: AppColors.mutedTitanium,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          ),
          icon: Icon(icon, size: 18),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        );
  return expand ? SizedBox(width: double.infinity, child: child) : child;
}

Widget monumentAccentButton({
  required String label,
  required VoidCallback? onPressed,
  Color accent = AppColors.cyberFuchsia,
}) {
  return SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: accent.withValues(alpha: 0.55)),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
    ),
  );
}

String _monumentCompactNum(int n) {
  if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1)}B';
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

/// Kompakt seviye ilerlemesi — tek bar + eksik kaynak özeti.
Widget monumentUpgradeProgressCompact({required MonumentUpgradeProgress progress}) {
  final Color accent = progress.isReady ? AppColors.toxicNeon : AppColors.warningSolar;
  final List<MonumentResourceProgress> pending = progress.resources
      .where((MonumentResourceProgress r) => r.required > 0 && r.progress < 1.0)
      .toList();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Row(
        children: <Widget>[
          Text(
            'Lv.${progress.nextLevel - 1} → ${progress.nextLevel}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.mutedTitanium,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            progress.isReady ? 'Yükseltme hazır' : '%${progress.filledPercent}',
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      GkkProgressBar(
        value: progress.overallProgress,
        color: accent,
        height: 6,
        glow: false,
      ),
      if (pending.isNotEmpty) ...<Widget>[
        const SizedBox(height: 5),
        Text(
          pending.map(_monumentCompactResourceLabel).join(' · '),
          style: AppTextStyles.caption.copyWith(
            color: AppColors.mutedTitanium,
            fontSize: 10,
            height: 1.3,
          ),
        ),
      ],
      if (progress.blueprintRequired && !progress.blueprintComplete) ...<Widget>[
        const SizedBox(height: 4),
        Text(
          'Blueprint: ${progress.blueprintType}',
          style: AppTextStyles.caption.copyWith(color: AppColors.toxicNeon, fontSize: 10),
        ),
      ],
    ],
  );
}

String _monumentCompactResourceLabel(MonumentResourceProgress resource) {
  final String current = resource.kind == MonumentResourceKind.gold
      ? _monumentCompactNum(resource.current)
      : '${resource.current}';
  final String required = resource.kind == MonumentResourceKind.gold
      ? _monumentCompactNum(resource.required)
      : '${resource.required}';
  return '${resource.kind.shortLabel} $current/$required';
}

/// @deprecated Use [monumentUpgradeProgressCompact] — kept for donate screen if needed.
Widget monumentUpgradeProgressPanel({
  required int currentLevel,
  required MonumentUpgradeProgress progress,
}) => monumentUpgradeProgressCompact(progress: progress);

Widget monumentMemberResourceRow({
  required MonumentResourceKind kind,
  required MonumentMyStats stats,
  required VoidCallback? onDonateMax,
  Color accent = AppColors.liquidGold,
}) {
  final int donated = stats.donatedTotal(kind);
  final int today = stats.donatedToday(kind);
  final int owned = stats.owned(kind);
  final int canDonate = stats.maxDonatable(kind);
  final int dailyMax = kind.dailyMax;

  return monumentPanel(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    borderColor: accent.withValues(alpha: 0.28),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                kind.shortLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Toplam bağış: $donated',
                style: AppTextStyles.caption.copyWith(color: AppColors.mutedTitanium),
              ),
              Text(
                'Bugün: $today/$dailyMax',
                style: AppTextStyles.caption.copyWith(color: AppColors.mutedTitanium),
              ),
              Text(
                kind == MonumentResourceKind.gold ? 'Elinde: $owned altın' : 'Elinde: $owned',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: owned > 0 ? AppColors.toxicNeon : AppColors.mysticRuby,
                ),
              ),
            ],
          ),
        ),
        if (canDonate > 0)
          TextButton(
            onPressed: onDonateMax,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.liquidGold,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Bağışla\n$canDonate',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, height: 1.2),
            ),
          )
        else
          Text(
            owned <= 0 ? 'Stok yok' : 'Limit doldu',
            style: AppTextStyles.caption.copyWith(color: AppColors.mysticRuby),
          ),
      ],
    ),
  );
}

Widget monumentResourceTile({
  required String label,
  required String shortLabel,
  required int value,
  Color valueColor = AppColors.textPrimary,
}) {
  return Tooltip(
    message: label,
    child: monumentPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderColor: AppColors.mutedTitanium.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            shortLabel,
            style: const TextStyle(fontSize: 10, color: AppColors.mutedTitanium),
          ),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: valueColor,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget monumentBonusRow({
  required int level,
  required String title,
  required String effect,
  required bool unlocked,
}) {
  return monumentPanel(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    borderColor: unlocked
        ? AppColors.toxicNeon.withValues(alpha: 0.35)
        : AppColors.darkObsidian.withValues(alpha: 0.8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: unlocked
                ? AppColors.toxicNeon.withValues(alpha: 0.12)
                : AppColors.darkObsidian.withValues(alpha: 0.6),
            border: Border.all(
              color: unlocked
                  ? AppColors.toxicNeon.withValues(alpha: 0.45)
                  : AppColors.mutedTitanium.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            'Lv$level',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: unlocked ? AppColors.toxicNeon : AppColors.mutedTitanium,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: unlocked ? AppColors.textPrimary : AppColors.mutedTitanium,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                effect,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: unlocked ? AppColors.toxicNeon : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        Icon(
          unlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
          size: 16,
          color: unlocked ? AppColors.toxicNeon : AppColors.mutedTitanium,
        ),
      ],
    ),
  );
}

