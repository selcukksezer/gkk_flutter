import 'package:flutter/material.dart';
import 'package:motor/motor.dart';

import '../../../theme/app_colors.dart';
import 'facility_detail_design.dart';
import '../../../l10n/l10n.dart';

/// Envanter popup stili onay diyaloğu — kare grid, kompakt, motor spring.
Future<bool?> showFacConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? icon,
  String confirmLabel = 'Onayla',
  String cancelLabel = 'Vazgeç',
  Color accentColor = AppColors.liquidGold,
  String? highlight,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (BuildContext dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
        child: _FacConfirmDialogBody(
          title: title,
          message: message,
          icon: icon,
          confirmLabel: confirmLabel,
          cancelLabel: cancelLabel,
          accentColor: accentColor,
          highlight: highlight,
        ),
      );
    },
  );
}

class _FacConfirmDialogBody extends StatefulWidget {
  const _FacConfirmDialogBody({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.accentColor,
    this.icon,
    this.highlight,
  });

  final String title;
  final String message;
  final String? icon;
  final String confirmLabel;
  final String cancelLabel;
  final Color accentColor;
  final String? highlight;

  @override
  State<_FacConfirmDialogBody> createState() => _FacConfirmDialogBodyState();
}

class _FacConfirmDialogBodyState extends State<_FacConfirmDialogBody> {
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _entered = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleMotionBuilder(
      value: _entered ? 1.0 : 0.0,
      motion: const Motion.smoothSpring(duration: Duration(milliseconds: 380)),
      builder: (BuildContext context, double t, Widget? child) {
        return Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.scale(
            scale: 0.92 + (0.08 * t),
            child: child,
          ),
        );
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: FacGridBanner(
          borderColor: widget.accentColor.withValues(alpha: 0.38),
          gradientColors: const <Color>[
            AppColors.carbonVoid,
            AppColors.spaceNavy,
            AppColors.carbonVoid,
          ],
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (widget.icon != null) ...<Widget>[
                    Text(widget.icon!, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.title.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            color: widget.accentColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _FacConfirmMessage(
                          message: widget.message,
                          highlight: widget.highlight,
                          accentColor: widget.accentColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _FacCancelButton(
                      label: widget.cancelLabel,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FacGoldButton(
                      label: widget.confirmLabel,
                      height: 36,
                      accentColor: widget.accentColor,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FacConfirmMessage extends StatelessWidget {
  const _FacConfirmMessage({
    required this.message,
    required this.accentColor,
    this.highlight,
  });

  final String message;
  final Color accentColor;
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    if (highlight == null || !message.contains(highlight!)) {
      return Text(
        message,
        style: const TextStyle(
          fontSize: 12,
          height: 1.35,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    final List<String> parts = message.split(highlight!);
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 12,
          height: 1.35,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        children: <InlineSpan>[
          TextSpan(text: parts.first),
          TextSpan(
            text: highlight,
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (parts.length > 1) TextSpan(text: parts.sublist(1).join(highlight!)),
        ],
      ),
    );
  }
}

class _FacCancelButton extends StatelessWidget {
  const _FacCancelButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: AppColors.darkObsidian.withValues(alpha: 0.7),
            border: Border.all(color: AppColors.mutedTitanium.withValues(alpha: 0.28)),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.mutedTitanium,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tesis kilidi açma onayı.
Future<bool> showFacUnlockDialog(
  BuildContext context, {
  required String facilityName,
  required String facilityIcon,
  required String formattedCost,
}) async {
  final bool? result = await showFacConfirmDialog(
    context,
    title: context.l10n.tesis_a_2,
    icon: facilityIcon,
    message: '$facilityName açmak için $formattedCost altın harcanacak. Onaylıyor musun?',
    highlight: formattedCost,
    confirmLabel: 'Aç',
  );
  return result ?? false;
}

/// Rüşvet onayı.
Future<bool> showFacBribeDialog(BuildContext context, {required String facilityType}) async {
  final bool? result = await showFacConfirmDialog(
    context,
    title: context.l10n.r_vet_2,
    icon: '💎',
    message: '5 Gem ile şüphe indirimi uygulanacak ($facilityType). Devam?',
    highlight: '5 Gem',
    accentColor: AppColors.cyberFuchsia,
    confirmLabel: 'Ver',
  );
  return result ?? false;
}

/// Yükseltme onayı.
Future<bool> showFacUpgradeDialog(
  BuildContext context, {
  required String facilityName,
  required int targetLevel,
  required String formattedCost,
}) async {
  final bool? result = await showFacConfirmDialog(
    context,
    title: context.l10n.y_kselt,
    icon: '⬆️',
    message: '$facilityName → Lv.$targetLevel için $formattedCost altın harcanacak.',
    highlight: formattedCost,
    accentColor: AppColors.coralFlare,
    confirmLabel: 'Yükselt',
  );
  return result ?? false;
}
