import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../components/layout/game_screen_background.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// Metadata definition for AAA Forge sound effects and audio triggers.
@immutable
class EnhanceSoundCueMetadata {
  const EnhanceSoundCueMetadata({
    required this.id,
    required this.assetPath,
    this.defaultVolume = 1.0,
    this.pitchVariance = 0.0,
    this.description = '',
  });

  final String id;
  final String assetPath;
  final double defaultVolume;
  final double pitchVariance;
  final String description;
}

/// Sound cue catalog for the enhancement forge system.
abstract final class EnhanceSoundCues {
  static const EnhanceSoundCueMetadata anvilStrike = EnhanceSoundCueMetadata(
    id: 'forge_strike',
    assetPath: 'audio/sfx/forge_strike.mp3',
    defaultVolume: 1.0,
    pitchVariance: 0.04,
    description: 'Heavy metallic hammer impact on celestial anvil',
  );

  static const EnhanceSoundCueMetadata chargeLoop = EnhanceSoundCueMetadata(
    id: 'forge_charge',
    assetPath: 'audio/sfx/forge_charge.mp3',
    defaultVolume: 0.85,
    pitchVariance: 0.02,
    description: 'Anticipatory rising energy hum during hold-to-strike',
  );

  static const EnhanceSoundCueMetadata successFanfare = EnhanceSoundCueMetadata(
    id: 'forge_success',
    assetPath: 'audio/sfx/forge_success.mp3',
    defaultVolume: 1.0,
    description: 'Triumphant celestial chime upon upgrade success',
  );

  static const EnhanceSoundCueMetadata failureBreak = EnhanceSoundCueMetadata(
    id: 'forge_failure',
    assetPath: 'audio/sfx/forge_failure.mp3',
    defaultVolume: 0.9,
    description: 'Dull thud and spark hiss when upgrade fails or downgrades',
  );

  static const EnhanceSoundCueMetadata criticalDestroy = EnhanceSoundCueMetadata(
    id: 'forge_destroy',
    assetPath: 'audio/sfx/forge_destroyed.mp3',
    defaultVolume: 1.0,
    description: 'Catastrophic glass shatter and void implosion on item destruction',
  );

  static const EnhanceSoundCueMetadata socketInsert = EnhanceSoundCueMetadata(
    id: 'socket_insert',
    assetPath: 'audio/sfx/socket_insert.mp3',
    defaultVolume: 0.8,
    description: 'Snappy metallic latch sound when item/scroll/rune is seated',
  );

  static const EnhanceSoundCueMetadata socketRemove = EnhanceSoundCueMetadata(
    id: 'socket_remove',
    assetPath: 'audio/sfx/socket_remove.mp3',
    defaultVolume: 0.7,
    description: 'Soft mechanical release sound when a slot is cleared',
  );

  static const EnhanceSoundCueMetadata runeActivated = EnhanceSoundCueMetadata(
    id: 'rune_activated',
    assetPath: 'audio/sfx/rune_activated.mp3',
    defaultVolume: 0.85,
    description: 'Mystical resonant hum when bonus rune is chosen',
  );

  static const EnhanceSoundCueMetadata riskWarning = EnhanceSoundCueMetadata(
    id: 'risk_warning',
    assetPath: 'audio/sfx/risk_critical.mp3',
    defaultVolume: 0.75,
    description: 'Subtle ominous drone when selecting items at +6 or higher',
  );

  static const Map<String, EnhanceSoundCueMetadata> allCues = <String, EnhanceSoundCueMetadata>{
    'forge_strike': anvilStrike,
    'forge_charge': chargeLoop,
    'forge_success': successFanfare,
    'forge_failure': failureBreak,
    'forge_destroy': criticalDestroy,
    'socket_insert': socketInsert,
    'socket_remove': socketRemove,
    'rune_activated': runeActivated,
    'risk_warning': riskWarning,
  };
}

/// Precision tactile feedback engine for the Divine Forge.
abstract final class EnhanceHaptics {
  /// Subtle tactile tick on button or slot tap.
  static Future<void> tapSelection() async {
    await HapticFeedback.selectionClick();
  }

  /// Light tick used during hold-to-charge anticipation.
  static Future<void> chargeTick() async {
    await HapticFeedback.lightImpact();
  }

  /// Dynamic charge tick scaling frequency or intensity.
  static Future<void> chargePulse(double chargeRatio) async {
    if (chargeRatio > 0.7) {
      await HapticFeedback.mediumImpact();
    } else {
      await HapticFeedback.lightImpact();
    }
  }

  /// Heavy impact on hammer release / anvil hit.
  static Future<void> anvilStrike() async {
    await HapticFeedback.heavyImpact();
  }

  /// Celebratory triple-pulse fanfare for successful upgrades.
  static Future<void> successFanfare() async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 140));
    await HapticFeedback.lightImpact();
  }

  /// Double medium pulse for failure / downgrade.
  static Future<void> failureSigh() async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 110));
    await HapticFeedback.lightImpact();
  }

  /// Catastrophic shatter vibration when item is destroyed.
  static Future<void> breakCatastrophe() async {
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.vibrate();
  }

  /// Clean crisp click when item, scroll or charm snaps into socket.
  static Future<void> socketSnap() async {
    await HapticFeedback.mediumImpact();
  }

  /// Light release click when item is unslotted.
  static Future<void> slotClear() async {
    await HapticFeedback.lightImpact();
  }
}

/// Güçlendirme ekranı — /tasarim paleti + dot doku + ilahî aura.
abstract final class EnhDesign {
  static const LinearGradient goldCta = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFFD64A), AppColors.liquidGold, Color(0xFFE08A00)],
  );

  static const LinearGradient fuchsiaCta = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFF4D7A), AppColors.cyberFuchsia, Color(0xFFB01040)],
  );

  static const LinearGradient iridescentBorder = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFFFD54F),
      Color(0xFF00E5FF),
      Color(0xFFAB47BC),
      Color(0xFFFF5722),
      Color(0xFFFFD54F),
    ],
  );

  static BoxDecoration rarityGlow(Color color) => BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.4),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 18,
            spreadRadius: -4,
          ),
        ],
      );
}

/// Küçük etiket — seviye, risk, şans.
class EnhPill extends StatelessWidget {
  const EnhPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTextStyles.micro.copyWith(
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bölüm başlığı + opsiyonel sağ aksiyon.
class EnhSectionHeader extends StatelessWidget {
  const EnhSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: AppTextStyles.micro.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: AppColors.mutedTitanium,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: AppTextStyles.micro.copyWith(
                    fontSize: 9,
                    color: AppColors.mutedTitanium.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Küçük ikon buton — tablo popup tetikleyici.
class EnhIconChipButton extends StatefulWidget {
  const EnhIconChipButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = AppColors.liquidGold,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accent;

  @override
  State<EnhIconChipButton> createState() => _EnhIconChipButtonState();
}

class _EnhIconChipButtonState extends State<EnhIconChipButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        EnhanceHaptics.tapSelection();
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.darkObsidian.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(color: widget.accent.withValues(alpha: 0.4)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: widget.accent.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(widget.icon, size: 13, color: widget.accent),
              const SizedBox(width: AppSpacing.xs),
              Text(
                widget.label,
                style: AppTextStyles.micro.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: widget.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Altın gradient ana CTA.
class EnhGoldButton extends StatefulWidget {
  const EnhGoldButton({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.loading = false,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final bool loading;
  final IconData? icon;
  final bool expand;

  @override
  State<EnhGoldButton> createState() => _EnhGoldButtonState();
}

class _EnhGoldButtonState extends State<EnhGoldButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && !widget.loading && widget.onTap != null;

    final Widget child = AnimatedScale(
      scale: _pressed && active ? 0.97 : 1,
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          gradient: active ? EnhDesign.goldCta : null,
          color: active ? null : AppColors.darkObsidian.withValues(alpha: 0.5),
          border: Border.all(
            color: active
                ? AppColors.liquidGold.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: active
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.liquidGold.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
          children: <Widget>[
            if (widget.loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.carbonVoid),
                ),
              )
            else if (widget.icon != null) ...<Widget>[
              Icon(widget.icon, size: 16, color: AppColors.carbonVoid),
              const SizedBox(width: 6),
            ],
            Text(
              widget.label,
              style: AppTextStyles.dialogButton.copyWith(
                color: active ? AppColors.carbonVoid : AppColors.mutedTitanium,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );

    return GestureDetector(
      onTapDown: active
          ? (_) {
              setState(() => _pressed = true);
              EnhanceHaptics.tapSelection();
            }
          : null,
      onTapUp: active ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: active ? () => setState(() => _pressed = false) : null,
      onTap: active ? widget.onTap : null,
      child: widget.expand ? SizedBox(width: double.infinity, child: child) : child,
    );
  }
}

/// İkincil outline buton.
class EnhGhostButton extends StatelessWidget {
  const EnhGhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Ink(
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            color: AppColors.darkObsidian.withValues(alpha: 0.55),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.dialogButtonMuted.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Staggered giriş animasyonu.
class EnhFadeSlide extends StatefulWidget {
  const EnhFadeSlide({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  State<EnhFadeSlide> createState() => _EnhFadeSlideState();
}

class _EnhFadeSlideState extends State<EnhFadeSlide> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future<void>.delayed(Duration(milliseconds: 40 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

/// Blur popup kabuğu — envanter popup stili.
Future<T?> showEnhBlurDialog<T>({
  required BuildContext context,
  required Widget child,
  Color accent = AppColors.liquidGold,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'dialog',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (BuildContext ctx, Animation<double> anim, Animation<double> secondary) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (BuildContext ctx, Animation<double> anim, Animation<double> secondary, Widget? _) {
      final double scale = Curves.easeOutBack.transform(anim.value);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: FadeTransition(
          opacity: anim,
          child: GestureDetector(
            onTap: () => Navigator.of(ctx).pop(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              color: AppColors.carbonVoid.withValues(alpha: 0.62),
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: () {},
                child: Transform.scale(
                  scale: scale,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.xl),
                    child: DottedPanel(
                      borderColor: accent.withValues(alpha: 0.42),
                      borderRadius: AppSpacing.radiusLg + 2,
                      padding: const EdgeInsets.all(AppSpacing.md + 2),
                      child: child,
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

// ============================================================================
// 2027 AION 2 DIVINE FORGE MODERNIZATION TOKENS & COMPONENTS
// ============================================================================

abstract final class AionForgeTokens {
  static const Color obsidianVoid = Color(0xFF090D15);
  static const Color pedestalDark = Color(0xFF0F1523);
  static const Color pedestalCard = Color(0xFF131A2D);
  static const Color celestialGold = Color(0xFFFFD54F);
  static const Color divineBrass = Color(0xFFB08D4A);
  static const Color radiantAether = Color(0xFF00E5FF);
  static const Color arcaneViolet = Color(0xFFAB47BC);
  static const Color moltenFlame = Color(0xFFFF5722);
  static const Color emeraldSafe = Color(0xFF00E676);
  static const Color amberWarning = Color(0xFFFFB300);
  static const Color crimsonBreak = Color(0xFFFF1744);

  // Iridescent and ethereal luxury palette
  static const Color iridescentCyan = Color(0xFF00F5D4);
  static const Color iridescentPink = Color(0xFFFF007F);
  static const Color iridescentPurple = Color(0xFF7B2CBF);
  static const Color celestialSilver = Color(0xFFE2E8F0);

  static const List<Color> iridescentPalette = <Color>[
    celestialGold,
    radiantAether,
    arcaneViolet,
    iridescentPink,
    iridescentCyan,
    celestialGold,
  ];

  static const SweepGradient iridescentSweep = SweepGradient(
    colors: iridescentPalette,
    stops: <double>[0.0, 0.25, 0.5, 0.75, 0.9, 1.0],
  );

  static const LinearGradient iridescentLinear = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFFFE082),
      Color(0xFF80DEEA),
      Color(0xFFCE93D8),
      Color(0xFFFFAB91),
      Color(0xFFFFE082),
    ],
  );

  static const LinearGradient celestialBorderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFFFD54F),
      Color(0xFFB08D4A),
      Color(0xFF00E5FF),
      Color(0xFFFFD54F),
    ],
  );

  static const LinearGradient divinePedestalGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Color(0xFF161E30),
      Color(0xFF0B0F19),
    ],
  );

  static const LinearGradient hammerGoldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFFFEA79),
      Color(0xFFFFC107),
      Color(0xFFFF8F00),
      Color(0xFFE65100),
    ],
  );

  static const LinearGradient chargingHeatGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[
      Color(0xFFFF9100),
      Color(0xFFFF3D00),
      Color(0xFFFF1744),
    ],
  );

  // Timing tokens for synchronized AAA feel
  static const Duration pedestalRotationDuration = Duration(seconds: 14);
  static const Duration forgeMinEnhanceDuration = Duration(seconds: 6);
  static const Duration forgeResultHoldDuration = Duration(seconds: 4);
  static const Duration strikeChargeMaxDuration = Duration(milliseconds: 650);
}

/// Shimmering iridescent border custom painter with corner highlights.
class IridescentBorderPainter extends CustomPainter {
  const IridescentBorderPainter({
    this.rotation = 0.0,
    this.strokeWidth = 1.6,
    this.borderRadius = 12.0,
    this.glowOpacity = 0.4,
    this.glowBlur = 8.0,
  });

  final double rotation;
  final double strokeWidth;
  final double borderRadius;
  final double glowOpacity;
  final double glowBlur;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final Rect rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(borderRadius),
    );

    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: math.pi * 2,
        colors: AionForgeTokens.iridescentPalette,
        transform: GradientRotation(rotation * math.pi * 2),
      ).createShader(rect);

    if (glowOpacity > 0.01) {
      final Paint glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 2.2
        ..color = AionForgeTokens.radiantAether.withValues(alpha: glowOpacity.clamp(0.0, 1.0))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowBlur);
      canvas.drawRRect(rrect, glowPaint);
    }

    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant IridescentBorderPainter oldDelegate) =>
      oldDelegate.rotation != rotation ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.glowOpacity != glowOpacity ||
      oldDelegate.glowBlur != glowBlur;
}

/// Container with a dynamic iridescent border and deep obsidian core.
class IridescentBorderContainer extends StatelessWidget {
  const IridescentBorderContainer({
    super.key,
    required this.child,
    this.rotation = 0.0,
    this.strokeWidth = 1.6,
    this.borderRadius = AppSpacing.radiusMd,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.backgroundColor = AionForgeTokens.pedestalDark,
    this.glowOpacity = 0.35,
  });

  final Widget child;
  final double rotation;
  final double strokeWidth;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final double glowOpacity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: IridescentBorderPainter(
        rotation: rotation,
        strokeWidth: strokeWidth,
        borderRadius: borderRadius,
        glowOpacity: glowOpacity,
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: child,
      ),
    );
  }
}

/// Ethereal breathing radial pulse aura for high-tier forge items.
class AionForgePulseAura extends StatelessWidget {
  const AionForgePulseAura({
    super.key,
    required this.pulse,
    required this.child,
    this.auraColor = AionForgeTokens.radiantAether,
    this.maxRadiusFactor = 1.4,
  });

  final double pulse; // 0..1
  final Widget child;
  final Color auraColor;
  final double maxRadiusFactor;

  @override
  Widget build(BuildContext context) {
    final double scale = 1.0 + (pulse * 0.12);
    final double opacity = (0.2 + 0.3 * (1.0 - pulse)).clamp(0.0, 1.0);

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Transform.scale(
          scale: scale * maxRadiusFactor,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  auraColor.withValues(alpha: opacity),
                  auraColor.withValues(alpha: opacity * 0.4),
                  Colors.transparent,
                ],
                stops: const <double>[0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Luxury holographic / iridescent badge for enhancement levels and rare attributes.
class IridescentBadge extends StatelessWidget {
  const IridescentBadge({
    super.key,
    required this.text,
    this.icon,
    this.textColor = AionForgeTokens.celestialGold,
    this.height = 20.0,
  });

  final String text;
  final IconData? icon;
  final Color textColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xE6080D1A),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
        border: Border.all(
          color: textColor.withValues(alpha: 0.75),
          width: 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: textColor.withValues(alpha: 0.3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 10, color: textColor),
            const SizedBox(width: AppSpacing.xs / 2),
          ],
          Text(
            text,
            style: AppTextStyles.micro.copyWith(
              fontWeight: FontWeight.w900,
              color: textColor,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Aion 2 Örs Kaidesi Rünik Çember Çizicisi.
/// Eşmerkezli kadim halkalar, 4 ana yön rünleri ve dönen ışık akımları.
class RunicPedestalPainter extends CustomPainter {
  const RunicPedestalPainter({
    required this.rotation,
    required this.pulse,
    this.primaryColor = AionForgeTokens.radiantAether,
    this.accentColor = AionForgeTokens.celestialGold,
  });

  final double rotation; // 0..1
  final double pulse; // 0..1
  final Color primaryColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2 - 4;
    if (radius <= 0) return;

    // 1. Dış İnce Rünik Ray
    final Paint trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = primaryColor.withValues(alpha: 0.25);
    canvas.drawCircle(center, radius, trackPaint);

    // 2. İç Geometrik Rün Halkası (Çentikli / Ark)
    final double innerRadius = radius * 0.76;
    final Paint innerTrackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = accentColor.withValues(alpha: 0.35);
    canvas.drawCircle(center, innerRadius, innerTrackPaint);

    // 3. Dönen Rün Arkları (Arc Sweeps)
    final double angleOffset = rotation * math.pi * 2;
    final Paint arcGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = primaryColor.withValues(alpha: (0.4 + 0.3 * pulse).clamp(0.0, 1.0))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final Paint arcCorePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = primaryColor.withValues(alpha: 0.9);

    const int arcCount = 3;
    for (int i = 0; i < arcCount; i++) {
      final double startAngle = angleOffset + (i * math.pi * 2 / arcCount);
      const double sweepAngle = math.pi * 0.35;
      final Rect arcRect = Rect.fromCircle(center: center, radius: radius * 0.88);
      canvas.drawArc(arcRect, startAngle, sweepAngle, false, arcGlowPaint);
      canvas.drawArc(arcRect, startAngle, sweepAngle, false, arcCorePaint);
    }

    // 4. 4 Ana Yön Nabız Noktaları / Rün Taşları
    for (int i = 0; i < 4; i++) {
      final double a = (i * math.pi / 2) + (rotation * 0.2);
      final Offset runePos = Offset(
        center.dx + radius * 0.96 * math.cos(a),
        center.dy + radius * 0.96 * math.sin(a),
      );

      final double nodePulse = 0.5 + 0.5 * math.sin(pulse * math.pi * 2 + i * 1.2);
      final Paint nodeGlow = Paint()
        ..color = accentColor.withValues(alpha: (0.5 * nodePulse).clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(runePos, 3.8 * (0.8 + 0.4 * nodePulse), nodeGlow);
      canvas.drawCircle(runePos, 2.0, Paint()..color = Colors.white);
    }

    // 5. Merkez Eterik Zemin Parıltısı
    final double coreGlowR = radius * 0.55;
    final Paint coreGlow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          primaryColor.withValues(alpha: (0.28 * pulse).clamp(0.0, 0.6)),
          accentColor.withValues(alpha: (0.12 * pulse).clamp(0.0, 0.4)),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: coreGlowR));
    canvas.drawCircle(center, coreGlowR, coreGlow);
  }

  @override
  bool shouldRepaint(covariant RunicPedestalPainter oldDelegate) =>
      oldDelegate.rotation != rotation ||
      oldDelegate.pulse != pulse ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.accentColor != accentColor;
}

/// Aion 2 Divine Anvil Pedestal Widget.
/// Merkezde seçili eşyayı kadim rünler, dikey eterik ışık huzmesi ve
/// havada asılı kalma (levitation) nefesi ile sergiler.
class AionForgePedestal extends StatelessWidget {
  const AionForgePedestal({
    super.key,
    required this.rotation,
    required this.pulse,
    required this.child,
    this.accentColor = AionForgeTokens.celestialGold,
    this.primaryRuneColor = AionForgeTokens.radiantAether,
    this.size = 104,
    this.badgeText,
    this.badgeColor,
    this.onTap,
    this.onClear,
    this.isEnhancing = false,
  });

  final double rotation;
  final double pulse;
  final Widget? child;
  final Color accentColor;
  final Color primaryRuneColor;
  final double size;
  final String? badgeText;
  final Color? badgeColor;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final bool isEnhancing;

  @override
  Widget build(BuildContext context) {
    final double levitationY = isEnhancing
        ? math.sin(pulse * math.pi * 4) * 3.5
        : math.sin(pulse * math.pi * 2) * 2.0;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: <Widget>[
          // 1. Zemin Rünik Çember Kaidesi
          SizedBox(
            width: size + 36,
            height: size + 36,
            child: CustomPaint(
              painter: RunicPedestalPainter(
                rotation: rotation,
                pulse: pulse,
                primaryColor: primaryRuneColor,
                accentColor: accentColor,
              ),
            ),
          ),

          // 2. Dikey Eterik Işık Sütunu (Divine Light Beam)
          Positioned(
            bottom: size * 0.28,
            child: Container(
              width: size * 0.65,
              height: size * 0.85,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: <Color>[
                    primaryRuneColor.withValues(alpha: (0.22 * pulse).clamp(0.0, 0.45)),
                    primaryRuneColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // 3. Havada Asılı Eşya Soketi Platformu
          Transform.translate(
            offset: Offset(0, levitationY),
            child: GestureDetector(
              onTap: () {
                EnhanceHaptics.tapSelection();
                onTap?.call();
              },
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  gradient: AionForgeTokens.divinePedestalGradient,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(
                    color: accentColor.withValues(alpha: child != null ? 0.85 : 0.45),
                    width: child != null ? 1.8 : 1.2,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: accentColor.withValues(alpha: child != null ? 0.32 : 0.12),
                      blurRadius: 16,
                      spreadRadius: child != null ? 1 : -2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg - 2),
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      if (child != null)
                        child!
                      else
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(
                              Icons.add_circle_outline_rounded,
                              size: 26,
                              color: accentColor.withValues(alpha: 0.65),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'EŞYA SEÇ',
                              style: AppTextStyles.micro.copyWith(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: accentColor.withValues(alpha: 0.85),
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

          // 4. Seviye Rozeti (+N)
          if (badgeText != null)
            Positioned(
              left: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xE6080D1A),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                  border: Border.all(
                    color: (badgeColor ?? AionForgeTokens.celestialGold).withValues(alpha: 0.8),
                    width: 1,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: (badgeColor ?? AionForgeTokens.celestialGold).withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  badgeText!,
                  style: AppTextStyles.micro.copyWith(
                    fontWeight: FontWeight.w900,
                    color: badgeColor ?? AionForgeTokens.celestialGold,
                    height: 1,
                  ),
                ),
              ),
            ),

          // 5. Temizle Butonu
          if (onClear != null)
            Positioned(
              right: 2,
              top: 2,
              child: GestureDetector(
                onTap: () {
                  EnhanceHaptics.slotClear();
                  onClear?.call();
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AionForgeTokens.obsidianVoid,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.close, size: 11, color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Aion 2 Risk-o-Meter Gauge Çizicisi.
/// 240 derecelik renk geçişli ark, güvenlik bölgeleri, ibre ve parıltı.
class RiskMeterGaugePainter extends CustomPainter {
  const RiskMeterGaugePainter({
    required this.progress, // 0..1 (başarı şansı)
    required this.dangerPhase, // 0: safe, 1: downgrade, 2: destroy
    this.pulse = 1.0,
  });

  final double progress;
  final int dangerPhase;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height * 0.58);
    final double radius = math.min(size.width / 2, size.height * 0.72) - 8;
    if (radius <= 0) return;

    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    const double startAngle = math.pi * 0.75; // 135 derece
    const double totalSweep = math.pi * 1.50; // 270 derecelik yay

    // 1. Zemin Arkı (Koyu ray)
    final Paint trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawArc(rect, startAngle, totalSweep, false, trackPaint);

    // 2. Risk Bölgeleri Eşik Göstergeleri (Arka Plan Dilimleri)
    final Paint zonePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Güvenli bölge yayı (Yeşil)
    zonePaint.color = AionForgeTokens.emeraldSafe.withValues(alpha: 0.25);
    canvas.drawArc(rect, startAngle, totalSweep * 0.40, false, zonePaint);

    // Düşme riski yayı (Sarı)
    zonePaint.color = AionForgeTokens.amberWarning.withValues(alpha: 0.25);
    canvas.drawArc(rect, startAngle + totalSweep * 0.40, totalSweep * 0.30, false, zonePaint);

    // Kırılma riski yayı (Kırmızı)
    zonePaint.color = AionForgeTokens.crimsonBreak.withValues(alpha: 0.25);
    canvas.drawArc(rect, startAngle + totalSweep * 0.70, totalSweep * 0.30, false, zonePaint);

    // 3. Aktif Başarı Şansı Arkı
    final double activeSweep = totalSweep * progress.clamp(0.0, 1.0);
    if (activeSweep > 0.01) {
      Color arcColor;
      switch (dangerPhase) {
        case 0:
          arcColor = AionForgeTokens.emeraldSafe;
          break;
        case 1:
          arcColor = AionForgeTokens.amberWarning;
          break;
        case 2:
        default:
          arcColor = AionForgeTokens.crimsonBreak;
          break;
      }

      final Paint glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0
        ..strokeCap = StrokeCap.round
        ..color = arcColor.withValues(alpha: (0.45 * pulse).clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
      canvas.drawArc(rect, startAngle, activeSweep, false, glowPaint);

      final Paint activePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + totalSweep,
          colors: <Color>[
            arcColor.withValues(alpha: 0.6),
            arcColor,
            Colors.white,
          ],
        ).createShader(rect);
      canvas.drawArc(rect, startAngle, activeSweep, false, activePaint);

      // İbre / Uç Parlama Noktası
      final double endA = startAngle + activeSweep;
      final Offset tipPos = Offset(
        center.dx + radius * math.cos(endA),
        center.dy + radius * math.sin(endA),
      );

      canvas.drawCircle(
        tipPos,
        5.5,
        Paint()
          ..color = Colors.white
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(tipPos, 2.8, Paint()..color = arcColor);
    }
  }

  @override
  bool shouldRepaint(covariant RiskMeterGaugePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.dangerPhase != dangerPhase ||
      oldDelegate.pulse != pulse;
}

/// Aion 2 Modern Risk-o-Meter Gauge Widget.
/// Başarı şansını, seviye eşiklerini, düşme ve kırılma riskini tek bakışta gösterir.
class RiskMeterGauge extends StatelessWidget {
  const RiskMeterGauge({
    super.key,
    required this.successChance, // 0..100
    required this.currentLevel,
    this.pulse = 1.0,
  });

  final int successChance;
  final int currentLevel;
  final double pulse;

  int get dangerPhase {
    if (currentLevel >= 6) return 2; // Catastrophic break risk
    if (currentLevel >= 4) return 1; // Downgrade risk
    return 0; // Safe zone
  }

  String get dangerTitle {
    switch (dangerPhase) {
      case 0:
        return 'GÜVENLİ BÖLGE';
      case 1:
        return 'SEVİYE DÜŞME RİSKİ';
      case 2:
      default:
        return 'YOK OLMA TEHLİKESİ';
    }
  }

  Color get dangerColor {
    switch (dangerPhase) {
      case 0:
        return AionForgeTokens.emeraldSafe;
      case 1:
        return AionForgeTokens.amberWarning;
      case 2:
      default:
        return AionForgeTokens.crimsonBreak;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int failureChance = (100 - successChance).clamp(0, 100);
    final int downgradeChance = dangerPhase == 1 ? failureChance : 0;
    final int breakChance = dangerPhase == 2 ? failureChance : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md - 2, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AionForgeTokens.pedestalDark.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: dangerColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Ark Gösterge Alanı + Merkez Metin
          SizedBox(
            height: 82,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: RiskMeterGaugePainter(
                      progress: successChance / 100.0,
                      dangerPhase: dangerPhase,
                      pulse: pulse,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '%$successChance',
                      style: AppTextStyles.h1.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: dangerColor,
                        letterSpacing: 0.5,
                        height: 1.0,
                        shadows: <Shadow>[
                          Shadow(
                            color: dangerColor.withValues(alpha: 0.6),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm - 2, vertical: 2),
                      decoration: BoxDecoration(
                        color: dangerColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusXs - 2),
                      ),
                      child: Text(
                        dangerTitle,
                        style: AppTextStyles.micro.copyWith(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: dangerColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Risk Dağılım Hapları (Exact Odds Breakdown)
          Row(
            children: <Widget>[
              Expanded(
                child: _breakdownPill(
                  label: 'BAŞARI',
                  value: '%$successChance',
                  color: AionForgeTokens.emeraldSafe,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _breakdownPill(
                  label: 'DÜŞME',
                  value: '%$downgradeChance',
                  color: AionForgeTokens.amberWarning,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _breakdownPill(
                  label: 'KIRILMA',
                  value: '%$breakChance',
                  color: AionForgeTokens.crimsonBreak,
                  isCritical: breakChance > 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _breakdownPill({
    required String label,
    required String value,
    required Color color,
    bool isCritical = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isCritical ? 0.22 : 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
        border: Border.all(
          color: color.withValues(alpha: isCritical ? 0.65 : 0.25),
        ),
      ),
      child: Column(
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          Text(
            label,
            style: AppTextStyles.micro.copyWith(
              fontSize: 7.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppColors.mutedTitanium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Aion 2 Soket Konteyneri (Stones, Supplemental Charms, Protection Charms).
class ForgeSlotContainer extends StatelessWidget {
  const ForgeSlotContainer({
    super.key,
    required this.label,
    required this.icon,
    this.child,
    this.accentColor = AionForgeTokens.divineBrass,
    this.badgeText,
    this.onTap,
    this.onClear,
    this.size = 54,
    this.slotKey,
  });

  final String label;
  final IconData icon;
  final Widget? child;
  final Color accentColor;
  final String? badgeText;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final double size;
  final Key? slotKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            GestureDetector(
              key: slotKey,
              onTap: onTap != null
                  ? () {
                      EnhanceHaptics.tapSelection();
                      onTap!();
                    }
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AionForgeTokens.pedestalDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accentColor.withValues(alpha: child != null ? 0.85 : 0.35),
                    width: child != null ? 1.6 : 1.0,
                  ),
                  boxShadow: child != null
                      ? <BoxShadow>[
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.25),
                            blurRadius: 8,
                            spreadRadius: -1,
                          ),
                        ]
                      : null,
                ),
                child: child ??
                    Center(
                      child: Icon(
                        icon,
                        size: 20,
                        color: accentColor.withValues(alpha: 0.45),
                      ),
                    ),
              ),
            ),

            // Temizleme Butonu
            if (onClear != null)
              Positioned(
                right: -4,
                top: -4,
                child: GestureDetector(
                  onTap: () {
                    EnhanceHaptics.slotClear();
                    onClear!();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: AionForgeTokens.obsidianVoid,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.close, size: 9, color: Colors.white70),
                  ),
                ),
              ),

            // Miktar / Rozet
            if (badgeText != null)
              Positioned(
                left: 2,
                bottom: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xE6080D1A),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXs / 2),
                  ),
                  child: Text(
                    badgeText!,
                    style: AppTextStyles.micro.copyWith(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w900,
                      color: accentColor,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: AppTextStyles.micro.copyWith(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            color: AppColors.mutedTitanium,
          ),
        ),
      ],
    );
  }
}

/// Aion 2 Dramatik Çekiç Vuruşu Butonu (Divine Forge Strike Button).
/// Bas-çek (Tap-to-Strike) veya Basılı Tut (Hold-to-Hammer) anticipasyon animasyonu,
/// yükselen haptik ve parlayan erimiş çekirdek.
class DivineForgeStrikeButton extends StatefulWidget {
  const DivineForgeStrikeButton({
    super.key,
    required this.onTrigger,
    this.enabled = true,
    this.loading = false,
    this.label = 'GÜÇLENDİR',
    this.costText,
  });

  final VoidCallback? onTrigger;
  final bool enabled;
  final bool loading;
  final String label;
  final String? costText;

  @override
  State<DivineForgeStrikeButton> createState() => _DivineForgeStrikeButtonState();
}

class _DivineForgeStrikeButtonState extends State<DivineForgeStrikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _chargeCtrl;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _chargeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed && _isHolding) {
          _triggerStrike();
        }
      });
  }

  @override
  void dispose() {
    _chargeCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (!widget.enabled || widget.loading || widget.onTrigger == null) return;
    setState(() => _isHolding = true);
    EnhanceHaptics.chargePulse(0.15);
    _chargeCtrl.forward(from: 0.0);
  }

  void _onTapUp(TapUpDetails _) {
    if (!_isHolding) return;
    // Eğer hızlı tıklandıysa veya yarıdan fazla basıldıysa doğrudan vur
    if (_chargeCtrl.value < 1.0) {
      _triggerStrike();
    }
  }

  void _onTapCancel() {
    if (!_isHolding) return;
    setState(() => _isHolding = false);
    _chargeCtrl.reverse();
  }

  void _triggerStrike() {
    setState(() => _isHolding = false);
    _chargeCtrl.reset();
    EnhanceHaptics.anvilStrike();
    widget.onTrigger?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && !widget.loading && widget.onTrigger != null;

    return AnimatedBuilder(
      animation: _chargeCtrl,
      builder: (BuildContext context, Widget? child) {
        final double charge = _chargeCtrl.value;

        return GestureDetector(
          onTapDown: active ? _onTapDown : null,
          onTapUp: active ? _onTapUp : null,
          onTapCancel: active ? _onTapCancel : null,
          child: AnimatedScale(
            scale: _isHolding ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                gradient: active
                    ? (charge > 0.05
                        ? AionForgeTokens.chargingHeatGradient
                        : AionForgeTokens.hammerGoldGradient)
                    : null,
                color: active ? null : const Color(0xFF141926),
                border: Border.all(
                  color: active
                      ? (charge > 0.05
                          ? const Color(0xFFFF5722)
                          : AionForgeTokens.celestialGold.withValues(alpha: 0.8))
                      : Colors.white.withValues(alpha: 0.08),
                  width: charge > 0.05 ? 1.8 : 1.2,
                ),
                boxShadow: active
                    ? <BoxShadow>[
                        BoxShadow(
                          color: (charge > 0.05
                                  ? const Color(0xFFFF5722)
                                  : AionForgeTokens.celestialGold)
                              .withValues(alpha: (0.35 + 0.35 * charge).clamp(0.0, 0.9)),
                          blurRadius: 14 + 10 * charge,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  // Şarj Dolum Çubuğu
                  if (charge > 0)
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: charge,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                    ),

                  // İçerik (İkon + Metin + Maliyet)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      if (widget.loading) ...<Widget>[
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.carbonVoid,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ] else ...<Widget>[
                        Transform.rotate(
                          angle: -0.2 * charge,
                          child: Icon(
                            Icons.auto_fix_high_rounded,
                            size: 19,
                            color: active ? AppColors.carbonVoid : AppColors.mutedTitanium,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.loading
                                ? 'GÜÇLENDİRİLİYOR...'
                                : (_isHolding ? 'ÇEKİÇ VURULUYOR!' : widget.label),
                            style: AppTextStyles.dialogButton.copyWith(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: active
                                  ? AppColors.carbonVoid
                                  : AppColors.mutedTitanium,
                              height: 1.1,
                            ),
                          ),
                          if (widget.costText != null && !widget.loading)
                            Text(
                              widget.costText!,
                              style: AppTextStyles.micro.copyWith(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: active
                                    ? const Color(0xFF3E2723)
                                    : AppColors.mutedTitanium.withValues(alpha: 0.7),
                                height: 1.1,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
