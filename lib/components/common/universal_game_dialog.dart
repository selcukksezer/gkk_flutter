import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Evrensel oyun diyalogu — blur, dot pattern, Liquid Gold onay, Obsidian iptal.
abstract final class UniversalGameDialog {
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Vazgeç',
    Color accent = AppColors.liquidGold,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: title,
      barrierColor: AppColors.carbonVoid.withValues(alpha: 0.52),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (BuildContext ctx, Animation<double> anim, Animation<double> secondary) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: _DialogShell(
                    accent: accent,
                    title: title,
                    message: message,
                    confirmLabel: confirmLabel,
                    cancelLabel: cancelLabel,
                    onConfirm: () => Navigator.pop(ctx, true),
                    onCancel: () => Navigator.pop(ctx, false),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Tek butonlu bilgi diyalogu.
  static Future<void> showInfo(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Tamam',
    Widget? body,
    Color accent = AppColors.liquidGold,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: title,
      barrierColor: AppColors.carbonVoid.withValues(alpha: 0.52),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (BuildContext ctx, Animation<double> anim, Animation<double> secondary) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: _DialogShell(
                    accent: accent,
                    title: title,
                    message: message,
                    confirmLabel: confirmLabel,
                    body: body,
                    onConfirm: () => Navigator.pop(ctx),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Coklu secenek diyalogu (orn. kutu acma odeme).
  static Future<T?> showChoice<T>(
    BuildContext context, {
    required String title,
    required String message,
    required List<UniversalDialogChoice<T>> choices,
    String cancelLabel = 'Vazgeç',
    Color accent = AppColors.liquidGold,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: title,
      barrierColor: AppColors.carbonVoid.withValues(alpha: 0.52),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (BuildContext ctx, Animation<double> anim, Animation<double> secondary) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: UniversalDialogPanel(
                    borderColor: accent.withValues(alpha: 0.45),
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          message,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: AppColors.mutedTitanium,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...choices.map(
                          (UniversalDialogChoice<T> choice) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: choice.isPrimary
                                ? _GoldButton(
                                    label: choice.label,
                                    onPressed: () => Navigator.pop(ctx, choice.value),
                                  )
                                : _ObsidianButton(
                                    label: choice.label,
                                    onPressed: () => Navigator.pop(ctx, choice.value),
                                  ),
                          ),
                        ),
                        _ObsidianButton(
                          label: cancelLabel,
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class UniversalDialogChoice<T> {
  const UniversalDialogChoice({
    required this.label,
    required this.value,
    this.isPrimary = true,
  });

  final String label;
  final T value;
  final bool isPrimary;
}

class _DialogShell extends StatelessWidget {
  const _DialogShell({
    required this.accent,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirm,
    this.cancelLabel,
    this.onCancel,
    this.body,
  });

  final Color accent;
  final String title;
  final String message;
  final String confirmLabel;
  final String? cancelLabel;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    return UniversalDialogPanel(
      borderColor: accent.withValues(alpha: 0.45),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          if (body != null)
            body!
          else if (message.isNotEmpty)
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.mutedTitanium,
              ),
            ),
          const SizedBox(height: 16),
          if (cancelLabel != null && onCancel != null)
            Row(
              children: <Widget>[
                Expanded(
                  child: _ObsidianButton(
                    label: cancelLabel!,
                    onPressed: onCancel,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _GoldButton(
                    label: confirmLabel,
                    onPressed: onConfirm,
                  ),
                ),
              ],
            )
          else
            _GoldButton(label: confirmLabel, onPressed: onConfirm),
        ],
      ),
    );
  }
}

class UniversalDialogPanel extends StatelessWidget {
  const UniversalDialogPanel({
    super.key,
    required this.child,
    required this.borderColor,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final Color borderColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.spaceNavy.withValues(alpha: 0.97),
            AppColors.carbonVoid.withValues(alpha: 0.99),
          ],
        ),
        border: Border.all(color: borderColor),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: borderColor.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: CustomPaint(painter: _DotPainter(spacing: 13, opacity: 0.07)),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  const _DotPainter({required this.spacing, required this.opacity});

  final double spacing;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = AppColors.mutedTitanium.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotPainter oldDelegate) =>
      spacing != oldDelegate.spacing || opacity != oldDelegate.opacity;
}

class _GoldButton extends StatelessWidget {
  const _GoldButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppColors.liquidGoldGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.liquidGold.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.carbonVoid,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ObsidianButton extends StatelessWidget {
  const _ObsidianButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.darkObsidian,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.mutedTitanium.withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.mutedTitanium,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
