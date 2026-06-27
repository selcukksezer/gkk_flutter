import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../providers/trade_invite_provider.dart';
import '../../routing/app_router.dart';
import '../../screens/trade/widgets/trade_theme.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../common/app_messenger.dart';
import '../../l10n/l10n.dart';

Future<bool> showTradeInviteDialog(
  BuildContext context, {
  required TradeInvite invite,
  required Future<Map<String, dynamic>> Function(bool accept, bool block) onRespond,
}) async {
  bool blockSender = false;
  bool responded = false;

  await showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: AppColors.carbonVoid.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (BuildContext ctx, Animation<double> a1, Animation<double> a2) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (BuildContext ctx, Animation<double> anim, Animation<double> _, Widget child) {
      final double t = Curves.easeOutBack.transform(anim.value.clamp(0.0, 1.0));
      return PopScope(
        canPop: false,
        child: Opacity(
          opacity: anim.value,
          child: Transform.scale(
            scale: 0.88 + (0.12 * t),
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setLocal) {
                return Center(
                  child: Material(
                    color: Colors.transparent,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: TradeNeonPanel(
                        accent: AppColors.cyberFuchsia,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const Text(
                              '🤝 Ticaret İsteği',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              '${invite.initiatorName} sizinle ticaret yapmak istiyor.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.mutedTitanium,
                                fontSize: 14,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: TradeSecondaryButton(
                                    label: context.l10n.reddet,
                                    onPressed: () async {
                                      responded = true;
                                      final Map<String, dynamic> res =
                                          await onRespond(false, blockSender);
                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                        if (res['success'] != true) {
                                          AppMessenger.showError(
                                            context,
                                            (res['error'] as String?) ?? 'Reddedilemedi',
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: TradePrimaryButton(
                                    label: context.l10n.kabul_et,
                                    color: AppColors.toxicNeon,
                                    onPressed: () async {
                                      responded = true;
                                      final Map<String, dynamic> res =
                                          await onRespond(true, false);
                                      if (!context.mounted) return;
                                      Navigator.of(context).pop();
                                      if (res['success'] == true) {
                                        context.push(AppRoutes.trade);
                                        AppMessenger.showSuccess(context, 'Ticaret başladı');
                                      } else {
                                        AppMessenger.showError(
                                          context,
                                          (res['error'] as String?) ?? 'Kabul edilemedi',
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            InkWell(
                              onTap: () => setLocal(() => blockSender = !blockSender),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: <Widget>[
                                    SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: Checkbox(
                                        value: blockSender,
                                        onChanged: (bool? v) =>
                                            setLocal(() => blockSender = v ?? false),
                                        activeColor: AppColors.liquidGold,
                                        side: const BorderSide(color: AppColors.mutedTitanium),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    const Expanded(
                                      child: Text(
                                        'Bu kişiden gelen ticaret isteklerini 4 saat engelle',
                                        style: TextStyle(
                                          color: AppColors.mutedTitanium,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );
  return responded;
}
