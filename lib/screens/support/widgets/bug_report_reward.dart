import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import 'support_design.dart';

/// Onaylı bug / öneri elmas ödül aralığı (staff onayı sonrası).
abstract final class BugReportReward {
  static const int minGems = 100;
  static const int maxGems = 5000;

  static String get rangeLabel => '$minGems–$maxGems';
}

/// Yanında gösterilen elmas aralığı rozeti.
class BugReportGemRangeBadge extends StatelessWidget {
  const BugReportGemRangeBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.accentBlue.withValues(alpha: 0.28),
            SettingsPalette.gold.withValues(alpha: 0.22),
          ],
        ),
        border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.45)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.accentBlue.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.diamond_rounded,
            size: compact ? 14 : 16,
            color: AppColors.accentBlue,
          ),
          const SizedBox(width: 4),
          Text(
            BugReportReward.rangeLabel,
            style: AppTextStyles.captionBold.copyWith(
              color: SettingsPalette.gold,
              fontSize: compact ? 11 : 12,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ödül bilgilendirme — ayarlar satırı veya bug ekranı.
Future<void> showBugReportRewardInfoDialog(
  BuildContext context, {
  VoidCallback? onContinue,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Bug ödül bilgisi',
    barrierColor: AppColors.carbonVoid.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (
      BuildContext ctx,
      Animation<double> anim,
      Animation<double> secondary,
      Widget? child,
    ) {
      final double scale = Curves.easeOutBack.transform(anim.value);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: FadeTransition(
          opacity: anim,
          child: Transform.scale(
            scale: scale,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _BugReportRewardInfoBody(onContinue: onContinue),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _BugReportRewardInfoBody extends StatelessWidget {
  const _BugReportRewardInfoBody({this.onContinue});

  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SettingsGlassCard(
        accent: AppColors.accentBlue,
        glow: true,
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.accentBlue.withValues(alpha: 0.18),
                    border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.35)),
                  ),
                  child: const Icon(Icons.diamond_rounded, color: AppColors.accentBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Elmas ödülü',
                        style: AppTextStyles.bodyBold.copyWith(color: SettingsPalette.textHi),
                      ),
                      const SizedBox(height: 4),
                      const BugReportGemRangeBadge(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Bildirdiğin bug veya önerin staff tarafından onaylanırsa '
              '${BugReportReward.minGems} ile ${BugReportReward.maxGems} elmas arasında ödül alabilirsin.',
              style: supportBodyStyle,
            ),
            const SizedBox(height: 10),
            Text(
              'Ödül miktarı raporun ciddiyetine göre belirlenir; onay garantisi yoktur. '
              'App Store / Play Store yorumu karşılığı ödül talep edilemez.',
              style: supportCaptionStyle.copyWith(height: 1.45),
            ),
            const SizedBox(height: 16),
            SettingsPrimaryButton(
              label: onContinue == null ? 'Anladım' : 'Bug / öneri bildir',
              icon: onContinue == null ? Icons.check_rounded : Icons.bug_report_outlined,
              onPressed: () {
                Navigator.pop(context);
                onContinue?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Ayarlar → destek satırı.
class BugReportSettingsRow extends StatelessWidget {
  const BugReportSettingsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPressable(
      onTap: () => showBugReportRewardInfoDialog(
        context,
        onContinue: () => context.push(AppRoutes.bugReport),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            const Icon(Icons.bug_report_outlined, size: 18, color: SettingsPalette.textMid),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Bug bildir yada öneride bulun',
                style: AppTextStyles.body.copyWith(color: SettingsPalette.textHi),
              ),
            ),
            const BugReportGemRangeBadge(compact: true),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: SettingsPalette.textMid, size: 18),
          ],
        ),
      ),
    );
  }
}
