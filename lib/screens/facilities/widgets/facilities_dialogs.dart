import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:motor/motor.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import 'facilities_ui.dart';
import 'facility_detail_design.dart';

/// Aion-2 Frosted Glass Confirmation Dialog — V3 Luxury Studio Elevation.
///
/// Features:
/// - Frosted glass backdrop filter (sigmaX: 18, sigmaY: 18)
/// - Luminous modal header frames with fantasy crest & dismissive close icon
/// - Specular top-edge luminous rim reflection & ambient fantasy glow
/// - Confirmation button with gold gradient sheen & tactile micro-bounce
/// - Safe context navigation guards & haptic feedback orchestration
Future<bool?> showFacConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? icon,
  String confirmLabel = 'Onayla',
  String cancelLabel = 'Vazgeç',
  Color accentColor = AppColors.liquidGold,
  String? highlight,
  String? subtitle,
  String? badgeText,
  bool isDestructive = false,
  Widget? customContent,
}) {
  if (!context.mounted) return Future<bool?>.value(null);

  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.76),
    barrierDismissible: true,
    builder: (BuildContext dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: _FacConfirmDialogBody(
          title: title,
          message: message,
          icon: icon,
          confirmLabel: confirmLabel,
          cancelLabel: cancelLabel,
          accentColor: isDestructive ? AppColors.mysticRuby : accentColor,
          highlight: highlight,
          subtitle: subtitle,
          badgeText: badgeText,
          isDestructive: isDestructive,
          customContent: customContent,
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
    this.subtitle,
    this.badgeText,
    this.isDestructive = false,
    this.customContent,
  });

  final String title;
  final String message;
  final String? icon;
  final String confirmLabel;
  final String cancelLabel;
  final Color accentColor;
  final String? highlight;
  final String? subtitle;
  final String? badgeText;
  final bool isDestructive;
  final Widget? customContent;

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

  void _handleCancel() {
    HapticFeedback.lightImpact();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(false);
    }
  }

  void _handleConfirm() {
    HapticFeedback.mediumImpact();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleMotionBuilder(
      value: _entered ? 1.0 : 0.0,
      motion: const Motion.smoothSpring(duration: Duration(milliseconds: 380)),
      builder: (BuildContext context, double t, Widget? child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.90 + (0.10 * t),
            child: child,
          ),
        );
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 345),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(FacilitiesUi.radiusLg),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(FacilitiesUi.radiusLg),
                border: Border.all(
                  color: widget.accentColor.withValues(alpha: 0.45),
                  width: 1.3,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    AppColors.bgCardElevated.withValues(alpha: 0.94),
                    AppColors.bgDeep.withValues(alpha: 0.97),
                    AppColors.carbonVoid,
                  ],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.26),
                    blurRadius: 24,
                    spreadRadius: -3,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: <Widget>[
                  // Luminous ambient top light sheen
                  Positioned(
                    top: 0,
                    left: 20,
                    right: 20,
                    height: 1.5,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Colors.transparent,
                            widget.accentColor.withValues(alpha: 0.75),
                            Colors.white.withValues(alpha: 0.8),
                            widget.accentColor.withValues(alpha: 0.75),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Background subtle radial fantasy aura
                  Positioned(
                    top: -40,
                    right: -30,
                    width: 140,
                    height: 140,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: <Color>[
                              widget.accentColor.withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Main dialog content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        // Header Bar Frame
                        _FacDialogHeader(
                          title: widget.title,
                          icon: widget.icon,
                          accentColor: widget.accentColor,
                          badgeText: widget.badgeText,
                          onClose: _handleCancel,
                        ),
                        const SizedBox(height: 12),
                        // Message / Highlight / Subtitle
                        _FacConfirmMessage(
                          message: widget.message,
                          highlight: widget.highlight,
                          accentColor: widget.accentColor,
                          subtitle: widget.subtitle,
                        ),
                        if (widget.customContent != null) ...<Widget>[
                          const SizedBox(height: 10),
                          widget.customContent!,
                        ],
                        const SizedBox(height: 16),
                        // Button Action Bar
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: FacDialogCancelButton(
                                label: widget.cancelLabel,
                                onPressed: _handleCancel,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FacGoldSheenButton(
                                label: widget.confirmLabel,
                                height: 40,
                                accentColor: widget.accentColor,
                                isDestructive: widget.isDestructive,
                                onPressed: _handleConfirm,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FacDialogHeader extends StatelessWidget {
  const _FacDialogHeader({
    required this.title,
    required this.accentColor,
    required this.onClose,
    this.icon,
    this.badgeText,
  });

  final String title;
  final Color accentColor;
  final VoidCallback onClose;
  final String? icon;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Top status pill badge and close button
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(FacilitiesUi.radiusPill),
                color: accentColor.withValues(alpha: 0.12),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.auto_awesome,
                    size: 9.5,
                    color: accentColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    (badgeText ?? 'TESİS PROTOKOLÜ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(FacilitiesUi.radiusPill),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.darkObsidian.withValues(alpha: 0.4),
                    border: Border.all(
                      color: AppColors.mutedTitanium.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: AppColors.mutedTitanium,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Medallion + Title
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      accentColor.withValues(alpha: 0.25),
                      AppColors.darkObsidian.withValues(alpha: 0.6),
                      AppColors.carbonVoid.withValues(alpha: 0.9),
                    ],
                  ),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.55),
                    width: 1.3,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  icon!,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.15,
                      color: accentColor,
                      shadows: <Shadow>[
                        Shadow(
                          color: accentColor.withValues(alpha: 0.45),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Luminous decorative underline
                  Container(
                    height: 1.2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          accentColor.withValues(alpha: 0.6),
                          accentColor.withValues(alpha: 0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FacConfirmMessage extends StatelessWidget {
  const _FacConfirmMessage({
    required this.message,
    required this.accentColor,
    this.highlight,
    this.subtitle,
  });

  final String message;
  final Color accentColor;
  final String? highlight;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    Widget messageContent;

    if (highlight == null || !message.contains(highlight!)) {
      messageContent = Text(
        message,
        style: const TextStyle(
          fontSize: 12.5,
          height: 1.4,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      );
    } else {
      final List<String> parts = message.split(highlight!);
      messageContent = RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          children: <InlineSpan>[
            TextSpan(text: parts.first),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: accentColor.withValues(alpha: 0.18),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.55),
                    width: 0.9,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.15),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  highlight!,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            if (parts.length > 1)
              TextSpan(text: parts.sublist(1).join(highlight!)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        messageContent,
        if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.3,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}

/// Aion-2 Tactile Sheen Button — Multi-stop gold gradient + specular sheen streak + haptics.
class FacGoldSheenButton extends StatefulWidget {
  const FacGoldSheenButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 38,
    this.accentColor,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final Color? accentColor;
  final bool isDestructive;

  @override
  State<FacGoldSheenButton> createState() => _FacGoldSheenButtonState();
}

class _FacGoldSheenButtonState extends State<FacGoldSheenButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    final Color baseColor = widget.isDestructive
        ? AppColors.mysticRuby
        : (widget.accentColor ?? AppColors.liquidGold);

    final List<Color> gradientColors = widget.isDestructive
        ? <Color>[
            AppColors.mysticRuby,
            AppColors.coralFlare,
            AppColors.mysticRuby.withValues(alpha: 0.9),
          ]
        : <Color>[
            baseColor,
            AppColors.warningSolar,
            AppColors.goldLight.withValues(alpha: 0.96),
            baseColor,
          ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.mediumImpact();
                widget.onPressed!();
              }
            : null,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        borderRadius: BorderRadius.circular(FacilitiesUi.radiusMd),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Ink(
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FacilitiesUi.radiusMd),
              gradient: enabled
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                    )
                  : null,
              color: enabled
                  ? null
                  : AppColors.darkObsidian.withValues(alpha: 0.5),
              border: Border.all(
                color: enabled
                    ? baseColor.withValues(alpha: 0.75)
                    : AppColors.mutedTitanium.withValues(alpha: 0.25),
                width: 1.2,
              ),
              boxShadow: enabled
                  ? <BoxShadow>[
                      BoxShadow(
                        color: baseColor.withValues(alpha: 0.38),
                        blurRadius: 14,
                        spreadRadius: -2,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // Angled Specular Sheen Stripe
                if (enabled)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(FacilitiesUi.radiusMd),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-1.0, -1.0),
                          end: Alignment(1.0, 1.0),
                          stops: <double>[0.0, 0.42, 0.52, 0.62, 1.0],
                          colors: <Color>[
                            Colors.transparent,
                            Colors.transparent,
                            Color(0x38FFFFFF),
                            Colors.transparent,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                // Button Label
                Center(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                      color: enabled
                          ? (widget.isDestructive
                              ? Colors.white
                              : AppColors.bgDeep)
                          : AppColors.mutedTitanium,
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

/// Aion-2 Frosted Glass Cancel Button — Tactile response + Muted titanium border.
class FacDialogCancelButton extends StatefulWidget {
  const FacDialogCancelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 38,
  });

  final String label;
  final VoidCallback onPressed;
  final double height;

  @override
  State<FacDialogCancelButton> createState() => _FacDialogCancelButtonState();
}

class _FacDialogCancelButtonState extends State<FacDialogCancelButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onPressed();
        },
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        borderRadius: BorderRadius.circular(FacilitiesUi.radiusMd),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Ink(
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FacilitiesUi.radiusMd),
              color: AppColors.bgDeep.withValues(alpha: 0.8),
              border: Border.all(
                color: AppColors.mutedTitanium.withValues(alpha: 0.3),
                width: 1.0,
              ),
            ),
            child: Center(
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.mutedTitanium,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Backward compatibility alias for _FacCancelButton
class _FacCancelButton extends StatelessWidget {
  const _FacCancelButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FacDialogCancelButton(
      label: label,
      onPressed: onPressed,
    );
  }
}

/// Tesis kilidi açma onayı — Safe context navigation guard + Luminous badge.
Future<bool> showFacUnlockDialog(
  BuildContext context, {
  required String facilityName,
  required String facilityIcon,
  required String formattedCost,
}) async {
  if (!context.mounted) return false;
  final bool? result = await showFacConfirmDialog(
    context,
    title: context.l10n.tesis_a_2,
    badgeText: 'KİLİT AÇMA PROTOKOLÜ',
    icon: facilityIcon,
    message: '$facilityName açmak için $formattedCost altın harcanacak. Onaylıyor musun?',
    highlight: formattedCost,
    confirmLabel: 'Aç',
    accentColor: AppColors.liquidGold,
  );
  if (!context.mounted) return false;
  return result ?? false;
}

/// Rüşvet onayı — Safe context navigation guard + Cyber fuchsia accent.
Future<bool> showFacBribeDialog(
  BuildContext context, {
  required String facilityType,
  required int gemAmount,
}) async {
  if (!context.mounted) return false;
  final bool? result = await showFacConfirmDialog(
    context,
    title: context.l10n.r_vet_2,
    badgeText: 'ŞÜPHE AZALTMA PROTOKOLÜ',
    icon: '💎',
    message: '$gemAmount Gem ile şüphe indirimi uygulanacak ($facilityType). Devam edilsin mi?',
    highlight: '$gemAmount Gem',
    accentColor: AppColors.cyberFuchsia,
    confirmLabel: 'Ver',
  );
  if (!context.mounted) return false;
  return result ?? false;
}

/// Yükseltme onayı — Safe context navigation guard + Coral flare glow.
Future<bool> showFacUpgradeDialog(
  BuildContext context, {
  required String facilityName,
  required int targetLevel,
  required String formattedCost,
}) async {
  if (!context.mounted) return false;
  final bool? result = await showFacConfirmDialog(
    context,
    title: context.l10n.y_kselt,
    badgeText: 'KAPASİTE YÜKSELTME',
    icon: '⬆️',
    message: '$facilityName → Lv.$targetLevel seviyesine yükseltmek için $formattedCost altın harcanacak.',
    highlight: formattedCost,
    accentColor: AppColors.coralFlare,
    confirmLabel: 'Yükselt',
  );
  if (!context.mounted) return false;
  return result ?? false;
}

/// Tehlikeli / Yıkım / Sıfırlama işlemi onayı.
Future<bool> showFacDangerConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? icon,
  String confirmLabel = 'Onayla',
  String cancelLabel = 'Vazgeç',
  String? highlight,
  String? subtitle,
}) async {
  if (!context.mounted) return false;
  final bool? result = await showFacConfirmDialog(
    context,
    title: title,
    badgeText: 'KRİTİK UYARI',
    icon: icon ?? '⚠️',
    message: message,
    highlight: highlight,
    subtitle: subtitle ?? 'Bu işlem geri alınamaz.',
    confirmLabel: confirmLabel,
    cancelLabel: cancelLabel,
    isDestructive: true,
    accentColor: AppColors.mysticRuby,
  );
  if (!context.mounted) return false;
  return result ?? false;
}

/// Displays an Aion-2 Frosted Glass Toast Notification with luminous accent border.
void showFacToast(
  BuildContext context, {
  required String message,
  String? subtitle,
  Color accentColor = AppColors.liquidGold,
  IconData icon = Icons.info_outline_rounded,
  Duration duration = const Duration(seconds: 3),
}) {
  if (!context.mounted) return;

  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.removeCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      padding: EdgeInsets.zero,
      duration: duration,
      content: ClipRRect(
        borderRadius: BorderRadius.circular(FacilitiesUi.radiusMd),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FacilitiesUi.radiusMd),
              color: AppColors.bgDeep.withValues(alpha: 0.92),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.55),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withValues(alpha: 0.16),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.45),
                      width: 1.0,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 17, color: accentColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        message,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Clean error toast with ruby accent and heavy haptic feedback.
void showFacErrorToast(
  BuildContext context, {
  required String message,
  String? subtitle,
}) {
  HapticFeedback.heavyImpact();
  showFacToast(
    context,
    message: message,
    subtitle: subtitle,
    accentColor: AppColors.mysticRuby,
    icon: Icons.error_outline_rounded,
  );
}

/// Clean success toast with toxic neon emerald accent and light haptic feedback.
void showFacSuccessToast(
  BuildContext context, {
  required String message,
  String? subtitle,
}) {
  HapticFeedback.lightImpact();
  showFacToast(
    context,
    message: message,
    subtitle: subtitle,
    accentColor: AppColors.toxicNeon,
    icon: Icons.check_circle_outline_rounded,
  );
}

/// Clean info toast with liquid gold accent and selection click haptics.
void showFacInfoToast(
  BuildContext context, {
  required String message,
  String? subtitle,
}) {
  HapticFeedback.selectionClick();
  showFacToast(
    context,
    message: message,
    subtitle: subtitle,
    accentColor: AppColors.liquidGold,
    icon: Icons.info_outline_rounded,
  );
}
