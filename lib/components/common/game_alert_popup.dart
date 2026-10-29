import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Accent variant for [GameAlertPopup].
enum GameAlertVariant { success, error, warning, info }

/// 2027 Aion 2 Obsidian-Glass & Luminescence Design Tokens
abstract final class _Aion2AlertTokens {
  /// Ether cyan info/success glow (#00E5FF)
  static const Color etherCyan = Color(0xFF00E5FF);

  /// Celestial gold warning/urgent halo (#E5C158)
  static const Color celestialGold = Color(0xFFE5C158);

  /// Urgent crimson core for critical error states
  static const Color urgentCrimson = Color(0xFFFF2A55);

  /// High-contrast obsidian glass surfaces
  static const Color obsidianVoid = Color(0xFF05080E);
  static const Color obsidianDeep = Color(0xFF090D16);
  static const Color obsidianSurface = Color(0xFF101726);

  /// Specular rim highlight
  static const Color borderSubtle = Color(0x333B4D70);
}

/// 2027 Aion 2 obsidian-glass game alert card (error / success / warning / info).
///
/// Features high-contrast obsidian glass backdrop, ether cyan / celestial gold
/// luminescence halos, SafeArea alignment, and tactile haptic feedback.
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

  @override
  void initState() {
    super.initState();
    // Tactile haptic pulse on alert trigger/display
    HapticFeedback.mediumImpact();

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

  void _handlePrimary() {
    HapticFeedback.lightImpact();
    widget.onPrimary?.call();
  }

  void _handleSecondary() {
    HapticFeedback.lightImpact();
    (widget.onSecondary ?? widget.onPrimary)?.call();
  }

  _AlertVisual get _visual {
    switch (widget.variant) {
      case GameAlertVariant.success:
        return const _AlertVisual(
          accent: _Aion2AlertTokens.etherCyan,
          haloColor: _Aion2AlertTokens.etherCyan,
          icon: Icons.check_circle_rounded,
          defaultTitle: 'BAŞARILI',
        );
      case GameAlertVariant.error:
        return const _AlertVisual(
          accent: _Aion2AlertTokens.urgentCrimson,
          haloColor: _Aion2AlertTokens.celestialGold,
          icon: Icons.error_rounded,
          defaultTitle: 'HATA',
        );
      case GameAlertVariant.warning:
        return const _AlertVisual(
          accent: _Aion2AlertTokens.celestialGold,
          haloColor: _Aion2AlertTokens.celestialGold,
          icon: Icons.warning_amber_rounded,
          defaultTitle: 'UYARI',
        );
      case GameAlertVariant.info:
        return const _AlertVisual(
          accent: _Aion2AlertTokens.etherCyan,
          haloColor: _Aion2AlertTokens.etherCyan,
          icon: Icons.info_rounded,
          defaultTitle: 'BİLGİ',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final _AlertVisual v = _visual;
    final String title = widget.title ?? v.defaultTitle;
    final Color primaryAccent = switch (widget.variant) {
      GameAlertVariant.success => _Aion2AlertTokens.etherCyan,
      GameAlertVariant.info => _Aion2AlertTokens.etherCyan,
      GameAlertVariant.warning => _Aion2AlertTokens.celestialGold,
      GameAlertVariant.error => _Aion2AlertTokens.urgentCrimson,
    };

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
        child: SafeArea(
          top: true,
          bottom: true,
          minimum: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 348),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Color(0xFA0D1524),
                          Color(0xF5080E18),
                          Color(0xFA05080E),
                        ],
                        stops: <double>[0.0, 0.55, 1.0],
                      ),
                      border: Border.all(
                        color: v.haloColor.withValues(alpha: 0.55),
                        width: 1.4,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: v.haloColor.withValues(alpha: 0.32),
                          blurRadius: 36,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.75),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                        BoxShadow(
                          color: v.accent.withValues(alpha: 0.12),
                          blurRadius: 14,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: <Widget>[
                        // Specular glass sheen overlay
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                gradient: LinearGradient(
                                  begin: const Alignment(-0.85, -1.0),
                                  end: const Alignment(0.85, 0.7),
                                  colors: <Color>[
                                    Colors.white.withValues(alpha: 0.08),
                                    Colors.white.withValues(alpha: 0.02),
                                    Colors.transparent,
                                  ],
                                  stops: const <double>[0.0, 0.35, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Top luminous luminescence beam
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  v.haloColor.withValues(alpha: 0.0),
                                  v.haloColor.withValues(alpha: 0.8),
                                  v.accent,
                                  v.haloColor.withValues(alpha: 0.8),
                                  v.haloColor.withValues(alpha: 0.0),
                                ],
                                stops: const <double>[0.0, 0.25, 0.5, 0.75, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // Main content
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              // Icon container / orb
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const RadialGradient(
                                    center: Alignment.center,
                                    radius: 0.8,
                                    colors: <Color>[
                                      Color(0xFF141F32),
                                      Color(0xFF070B13),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: v.accent.withValues(alpha: 0.75),
                                    width: 1.6,
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: v.haloColor.withValues(alpha: 0.40),
                                      blurRadius: 22,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Icon(v.icon, color: v.accent, size: 32),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.dialogTitle.copyWith(
                                  letterSpacing: 2.2,
                                  shadows: <Shadow>[
                                    Shadow(
                                      color: v.haloColor.withValues(alpha: 0.45),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.message,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.dialogBody.copyWith(
                                  fontSize: 14,
                                  height: 1.45,
                                  color: const Color(0xFFC0CEE0),
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
                                        onTap: _handleSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _AlertButton(
                                        label: widget.primaryLabel,
                                        filled: true,
                                        accent: primaryAccent,
                                        onTap: _handlePrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else
                                _AlertButton(
                                  label: widget.primaryLabel,
                                  filled: true,
                                  accent: primaryAccent,
                                  onTap: _handlePrimary,
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
    required this.haloColor,
    required this.icon,
    required this.defaultTitle,
  });

  final Color accent;
  final Color haloColor;
  final IconData icon;
  final String defaultTitle;
}

class _AlertButton extends StatefulWidget {
  const _AlertButton({
    required this.label,
    required this.filled,
    required this.accent,
    this.onTap,
  });

  final String label;
  final bool filled;
  final Color accent;
  final VoidCallback? onTap;

  @override
  State<_AlertButton> createState() => _AlertButtonState();
}

class _AlertButtonState extends State<_AlertButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: widget.filled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      widget.accent,
                      Color.lerp(widget.accent, Colors.black, 0.25)!,
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0x33101826),
                      Color(0x1A080E18),
                    ],
                  ),
            border: Border.all(
              color: widget.filled
                  ? Colors.white.withValues(alpha: 0.35)
                  : widget.accent.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: widget.filled
                ? <BoxShadow>[
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.40),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (widget.filled
                    ? AppTextStyles.dialogButton
                    : AppTextStyles.dialogButtonMuted)
                .copyWith(
              letterSpacing: 1.4,
              color: widget.filled
                  ? _Aion2AlertTokens.obsidianVoid
                  : widget.accent,
            ),
          ),
        ),
      ),
    );
  }
}
