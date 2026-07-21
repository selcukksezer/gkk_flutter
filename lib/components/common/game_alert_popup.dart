import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../layout/game_screen_background.dart';

/// Accent variant for [GameAlertPopup].
enum GameAlertVariant { success, error, warning, info }

/// Tasarim-styled game alert card (error / success / warning / info).
///
/// Used by AppMessenger as a centered overlay — not a Material SnackBar.
class GameAlertPopup extends StatefulWidget {
  const GameAlertPopup({
    super.key,
    required this.message,
    required this.variant,
    this.title,
    this.primaryLabel = 'TAMAM',
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String message;
  final GameAlertVariant variant;
  final String? title;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  State<GameAlertPopup> createState() => _GameAlertPopupState();
}

class _GameAlertPopupState extends State<GameAlertPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _scale = CurvedAnimation(parent: _entry, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic);
    _entry.forward();
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  _AlertVisual get _visual {
    switch (widget.variant) {
      case GameAlertVariant.success:
        return const _AlertVisual(
          accent: AppColors.toxicNeon,
          icon: Icons.check_circle_rounded,
          defaultTitle: 'BAŞARILI',
        );
      case GameAlertVariant.error:
        return const _AlertVisual(
          accent: AppColors.mysticRuby,
          icon: Icons.error_rounded,
          defaultTitle: 'HATA',
        );
      case GameAlertVariant.warning:
        return const _AlertVisual(
          accent: AppColors.warningSolar,
          icon: Icons.warning_amber_rounded,
          defaultTitle: 'UYARI',
        );
      case GameAlertVariant.info:
        return const _AlertVisual(
          accent: AppColors.liquidGold,
          icon: Icons.info_rounded,
          defaultTitle: 'BİLGİ',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final _AlertVisual v = _visual;
    final String title = widget.title ?? v.defaultTitle;
    final Color primaryAccent = widget.variant == GameAlertVariant.error
        ? AppColors.cyberFuchsia
        : AppColors.liquidGold;

    return AnimatedBuilder(
      animation: _entry,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: _fade.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.86 + (0.14 * _scale.value.clamp(0.0, 1.2)),
            child: child,
          ),
        );
      },
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          AppColors.spaceNavy,
                          AppColors.carbonVoid,
                        ],
                      ),
                      border: Border.all(
                        color: v.accent.withValues(alpha: 0.55),
                        width: 1.2,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: v.accent.withValues(alpha: 0.28),
                          blurRadius: 28,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.55),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: <Widget>[
                        const Positioned.fill(
                          child: CustomPaint(
                            painter: DotGridPainter(
                              spacing: 18,
                              dotRadius: 1.0,
                              dotOpacity: 0.06,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  v.accent.withValues(alpha: 0.15),
                                  v.accent,
                                  v.accent.withValues(alpha: 0.15),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.darkObsidian,
                                  border: Border.all(
                                    color: v.accent.withValues(alpha: 0.65),
                                    width: 1.5,
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: v.accent.withValues(alpha: 0.35),
                                      blurRadius: 18,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Icon(v.icon, color: v.accent, size: 30),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.urbanist(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.4,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.message,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.urbanist(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 1.45,
                                  color: AppColors.mutedTitanium,
                                ),
                              ),
                              const SizedBox(height: 22),
                              if (widget.secondaryLabel != null) ...<Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: _AlertButton(
                                        label: widget.secondaryLabel!,
                                        filled: false,
                                        accent: AppColors.mutedTitanium,
                                        onTap: widget.onSecondary ??
                                            widget.onPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _AlertButton(
                                        label: widget.primaryLabel,
                                        filled: true,
                                        accent: primaryAccent,
                                        onTap: widget.onPrimary,
                                        pressed: _pressed,
                                        onHighlight: (bool v) =>
                                            setState(() => _pressed = v),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else
                                _AlertButton(
                                  label: widget.primaryLabel,
                                  filled: true,
                                  accent: primaryAccent,
                                  onTap: widget.onPrimary,
                                  pressed: _pressed,
                                  onHighlight: (bool v) =>
                                      setState(() => _pressed = v),
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
          ),
        ),
      ),
    );
  }
}

class _AlertVisual {
  const _AlertVisual({
    required this.accent,
    required this.icon,
    required this.defaultTitle,
  });

  final Color accent;
  final IconData icon;
  final String defaultTitle;
}

class _AlertButton extends StatelessWidget {
  const _AlertButton({
    required this.label,
    required this.filled,
    required this.accent,
    this.onTap,
    this.pressed = false,
    this.onHighlight,
  });

  final String label;
  final bool filled;
  final Color accent;
  final VoidCallback? onTap;
  final bool pressed;
  final ValueChanged<bool>? onHighlight;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onHighlight?.call(true),
      onTapUp: (_) => onHighlight?.call(false),
      onTapCancel: () => onHighlight?.call(false),
      onTap: onTap,
      child: AnimatedScale(
        scale: pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: filled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      accent,
                      Color.lerp(accent, Colors.black, 0.22)!,
                    ],
                  )
                : null,
            color: filled ? null : AppColors.darkObsidian,
            border: filled
                ? null
                : Border.all(color: accent.withValues(alpha: 0.45)),
            boxShadow: filled
                ? <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.urbanist(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: filled ? AppColors.carbonVoid : accent,
            ),
          ),
        ),
      ),
    );
  }
}
