import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// 2027 Aion 2 Obsidian-Glass & Celestial/Ether Design Tokens
abstract final class _AionDialogTokens {
  static const Color celestialGold = Color(0xFFE5C158);
  static const Color etherCyan = Color(0xFF00E5FF);
  static const Color goldLight = Color(0xFFFDE68A);
  static const Color goldDim = Color(0xFFD4A72C);
  static const Color obsidianVoid = Color(0xFF05080C);
  static const Color obsidianSurface = Color(0xFF0E1622);
  static const Color obsidianCard = Color(0xFF141E2B);
  static const Color goldGlow = Color(0x55E5C158);
}

/// Evrensel oyun diyalogu — 2027 Aion 2 obsidian-glass, Celestial Gold & Ether Cyan luminescence.
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
      barrierColor: AppColors.carbonVoid.withValues(alpha: 0.68),
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
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: FadeTransition(
            opacity: anim,
            child: Transform.scale(
              scale: scale,
              child: SafeArea(
                maintainBottomViewPadding: true,
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
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
      barrierColor: AppColors.carbonVoid.withValues(alpha: 0.68),
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
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: FadeTransition(
            opacity: anim,
            child: Transform.scale(
              scale: scale,
              child: SafeArea(
                maintainBottomViewPadding: true,
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
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
      barrierColor: AppColors.carbonVoid.withValues(alpha: 0.68),
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
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: FadeTransition(
            opacity: anim,
            child: Transform.scale(
              scale: scale,
              child: SafeArea(
                maintainBottomViewPadding: true,
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: UniversalDialogPanel(
                        borderColor: accent.withValues(alpha: 0.55),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Container(
                                  width: 7,
                                  height: 7,
                                  transform: Matrix4.rotationZ(0.785398),
                                  decoration: BoxDecoration(
                                    color: _AionDialogTokens.celestialGold,
                                    boxShadow: const <BoxShadow>[
                                      BoxShadow(
                                        color: _AionDialogTokens.goldGlow,
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: AppTextStyles.dialogTitle.copyWith(
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.pop(ctx);
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(alpha: 0.05),
                                      border: Border.all(
                                        color: _AionDialogTokens.etherCyan.withValues(alpha: 0.25),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 15,
                                      color: AppColors.mutedTitanium,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const _CelestialHeaderDivider(),
                            if (message.isNotEmpty) ...<Widget>[
                              Text(
                                message,
                                style: AppTextStyles.dialogBody.copyWith(
                                  height: 1.48,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            ...choices.map(
                              (UniversalDialogChoice<T> choice) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
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
    final bool hasCancel = cancelLabel != null && onCancel != null;

    return UniversalDialogPanel(
      borderColor: accent.withValues(alpha: 0.55),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 7,
                height: 7,
                transform: Matrix4.rotationZ(0.785398),
                decoration: BoxDecoration(
                  color: _AionDialogTokens.celestialGold,
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: _AionDialogTokens.goldGlow,
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.dialogTitle.copyWith(
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (hasCancel) ...<Widget>[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onCancel!();
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: _AionDialogTokens.etherCyan.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: AppColors.mutedTitanium,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const _CelestialHeaderDivider(),
          if (body != null)
            body!
          else if (message.isNotEmpty)
            Text(
              message,
              style: AppTextStyles.dialogBody.copyWith(
                height: 1.48,
              ),
            ),
          const SizedBox(height: 18),
          if (hasCancel)
            Row(
              children: <Widget>[
                Expanded(
                  child: _ObsidianButton(
                    label: cancelLabel!,
                    onPressed: onCancel,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GoldButton(
                    label: confirmLabel,
                    onPressed: onConfirm,
                  ),
                ),
              ],
            )
          else
            _GoldButton(
              label: confirmLabel,
              onPressed: onConfirm,
            ),
        ],
      ),
    );
  }
}

/// Celestial Gold (#E5C158) header divider with Ether Cyan (#00E5FF) luminescence shimmer.
class _CelestialHeaderDivider extends StatelessWidget {
  const _CelestialHeaderDivider({
    this.primaryColor = _AionDialogTokens.celestialGold,
    this.luminescenceColor = _AionDialogTokens.etherCyan,
  });

  final Color primaryColor;
  final Color luminescenceColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2.0,
      margin: const EdgeInsets.only(top: 8.0, bottom: 12.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1.0),
        gradient: LinearGradient(
          colors: <Color>[
            primaryColor.withValues(alpha: 0.0),
            primaryColor.withValues(alpha: 0.95),
            luminescenceColor.withValues(alpha: 0.90),
            primaryColor.withValues(alpha: 0.95),
            primaryColor.withValues(alpha: 0.0),
          ],
          stops: const <double>[0.0, 0.20, 0.50, 0.80, 1.0],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.40),
            blurRadius: 6.0,
            spreadRadius: 0.5,
          ),
          BoxShadow(
            color: luminescenceColor.withValues(alpha: 0.30),
            blurRadius: 10.0,
          ),
        ],
      ),
    );
  }
}

/// Supreme obsidian glass modal panel with Ether Cyan (#00E5FF) perimeter luminescence.
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
    return DefaultTextStyle(
      style: AppTextStyles.dialogBody,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          // Supreme Obsidian Glass gradient
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xE80E1622),
              Color(0xF5060A0E),
              Color(0xFA030508),
            ],
            stops: <double>[0.0, 0.55, 1.0],
          ),
          border: Border.all(
            color: borderColor,
            width: 1.2,
          ),
          boxShadow: <BoxShadow>[
            // Ambient deep void drop shadow
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.72),
              blurRadius: 36,
              offset: const Offset(0, 16),
            ),
            // Ether Cyan (#00E5FF) perimeter luminescence — outer aura
            BoxShadow(
              color: _AionDialogTokens.etherCyan.withValues(alpha: 0.22),
              blurRadius: 28,
              spreadRadius: 1.0,
            ),
            // Ether Cyan (#00E5FF) perimeter luminescence — inner perimeter glow
            BoxShadow(
              color: _AionDialogTokens.etherCyan.withValues(alpha: 0.16),
              blurRadius: 10,
              spreadRadius: -0.5,
            ),
            // Accent perimeter glow (e.g. Celestial Gold or custom accent)
            BoxShadow(
              color: borderColor.withValues(alpha: 0.30),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                // Frosted obsidian glass specular reflection
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    _AionDialogTokens.etherCyan.withValues(alpha: 0.07),
                    Colors.transparent,
                    _AionDialogTokens.celestialGold.withValues(alpha: 0.03),
                  ],
                  stops: const <double>[0.0, 0.30, 1.0],
                ),
              ),
              child: SafeArea(
                minimum: EdgeInsets.zero,
                child: Padding(
                  padding: padding,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
        onTap: () {
          HapticFeedback.mediumImpact();
          onPressed();
        },
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                _AionDialogTokens.goldLight,
                _AionDialogTokens.celestialGold,
                _AionDialogTokens.goldDim,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFFF0B3).withValues(alpha: 0.65),
              width: 1.0,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _AionDialogTokens.celestialGold.withValues(alpha: 0.42),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: _AionDialogTokens.etherCyan.withValues(alpha: 0.20),
                blurRadius: 8,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.dialogButton.copyWith(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF070B10),
                letterSpacing: 0.3,
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
        onTap: onPressed == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPressed!();
              },
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFF1E2836),
                Color(0xFF111722),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF3B4D68).withValues(alpha: 0.55),
              width: 1.0,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: _AionDialogTokens.etherCyan.withValues(alpha: 0.08),
                blurRadius: 6,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.dialogButtonMuted.copyWith(
                color: const Color(0xFFB0C0D4),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
