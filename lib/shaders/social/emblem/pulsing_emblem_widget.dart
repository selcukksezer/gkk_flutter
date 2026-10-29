import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/social_theme_tokens.dart';
import 'pulsing_emblem_painter.dart';

/// Predefined sizes for the social emblem widget.
enum PulsingEmblemSize {
  compact(36.0),
  standard(56.0),
  large(84.0),
  hero(128.0);

  const PulsingEmblemSize(this.dimension);
  final double dimension;
}

/// Reusable 2027 Aion 2 Mobile pulsing emblem widget adapter.
///
/// Features smooth continuous aura breathing, orbiting radiance particles,
/// and heraldic crest vector rendering with robust ticker forwarding,
/// size constraints, and fallback painter support.
class PulsingEmblemWidget extends StatefulWidget {
  const PulsingEmblemWidget({
    super.key,
    this.faction = EmblemFaction.elyos,
    this.sizePreset = PulsingEmblemSize.standard,
    this.customSize,
    this.primaryColor,
    this.coreColor,
    this.auraIntensity = 1.0,
    this.showOrbitingParticles = true,
    this.showRadiantRays = true,
    this.showInnerGlow = true,
    this.tierBadgeText,
    this.animationDuration = const Duration(seconds: 3),
    this.controller,
    this.progressAnimation,
    this.fallbackPainter,
    this.onTap,
  });

  /// Factory for Guild Legion crest.
  factory PulsingEmblemWidget.guild({
    Key? key,
    PulsingEmblemSize size = PulsingEmblemSize.standard,
    double? customSize,
    String? levelText,
    Color? primaryColor,
    Color? coreColor,
    double auraIntensity = 1.0,
    bool showOrbitingParticles = true,
    bool showRadiantRays = true,
    bool showInnerGlow = true,
    Duration animationDuration = const Duration(seconds: 3),
    AnimationController? controller,
    Animation<double>? progressAnimation,
    CustomPainter? fallbackPainter,
    VoidCallback? onTap,
  }) {
    return PulsingEmblemWidget(
      key: key,
      faction: EmblemFaction.guildShield,
      sizePreset: size,
      customSize: customSize,
      primaryColor: primaryColor ?? SocialThemeTokens.celestialGold,
      coreColor: coreColor ?? SocialThemeTokens.celestialGoldLight,
      auraIntensity: auraIntensity,
      showOrbitingParticles: showOrbitingParticles,
      showRadiantRays: showRadiantRays,
      showInnerGlow: showInnerGlow,
      animationDuration: animationDuration,
      controller: controller,
      progressAnimation: progressAnimation,
      fallbackPainter: fallbackPainter,
      tierBadgeText: levelText,
      onTap: onTap,
    );
  }

  /// Factory for Elyos Celestial faction crest.
  factory PulsingEmblemWidget.elyos({
    Key? key,
    PulsingEmblemSize size = PulsingEmblemSize.standard,
    double? customSize,
    String? rankText,
    Color? primaryColor,
    Color? coreColor,
    double auraIntensity = 1.0,
    bool showOrbitingParticles = true,
    bool showRadiantRays = true,
    bool showInnerGlow = true,
    Duration animationDuration = const Duration(seconds: 3),
    AnimationController? controller,
    Animation<double>? progressAnimation,
    CustomPainter? fallbackPainter,
    VoidCallback? onTap,
  }) {
    return PulsingEmblemWidget(
      key: key,
      faction: EmblemFaction.elyos,
      sizePreset: size,
      customSize: customSize,
      primaryColor: primaryColor ?? SocialThemeTokens.elyosGold,
      coreColor: coreColor ?? SocialThemeTokens.elyosRadiance,
      auraIntensity: auraIntensity,
      showOrbitingParticles: showOrbitingParticles,
      showRadiantRays: showRadiantRays,
      showInnerGlow: showInnerGlow,
      animationDuration: animationDuration,
      controller: controller,
      progressAnimation: progressAnimation,
      fallbackPainter: fallbackPainter,
      tierBadgeText: rankText,
      onTap: onTap,
    );
  }

  /// Factory for Asmodian Shadow Legion crest.
  factory PulsingEmblemWidget.asmodian({
    Key? key,
    PulsingEmblemSize size = PulsingEmblemSize.standard,
    double? customSize,
    String? rankText,
    Color? primaryColor,
    Color? coreColor,
    double auraIntensity = 1.0,
    bool showOrbitingParticles = true,
    bool showRadiantRays = true,
    bool showInnerGlow = true,
    Duration animationDuration = const Duration(seconds: 3),
    AnimationController? controller,
    Animation<double>? progressAnimation,
    CustomPainter? fallbackPainter,
    VoidCallback? onTap,
  }) {
    return PulsingEmblemWidget(
      key: key,
      faction: EmblemFaction.asmodian,
      sizePreset: size,
      customSize: customSize,
      primaryColor: primaryColor ?? SocialThemeTokens.asmodianViolet,
      coreColor: coreColor ?? SocialThemeTokens.asmodianCrimson,
      auraIntensity: auraIntensity,
      showOrbitingParticles: showOrbitingParticles,
      showRadiantRays: showRadiantRays,
      showInnerGlow: showInnerGlow,
      animationDuration: animationDuration,
      controller: controller,
      progressAnimation: progressAnimation,
      fallbackPainter: fallbackPainter,
      tierBadgeText: rankText,
      onTap: onTap,
    );
  }

  /// Factory for Balaur Dragonic crest.
  factory PulsingEmblemWidget.balaur({
    Key? key,
    PulsingEmblemSize size = PulsingEmblemSize.standard,
    double? customSize,
    String? rankText,
    Color? primaryColor,
    Color? coreColor,
    double auraIntensity = 1.0,
    bool showOrbitingParticles = true,
    bool showRadiantRays = true,
    bool showInnerGlow = true,
    Duration animationDuration = const Duration(seconds: 3),
    AnimationController? controller,
    Animation<double>? progressAnimation,
    CustomPainter? fallbackPainter,
    VoidCallback? onTap,
  }) {
    return PulsingEmblemWidget(
      key: key,
      faction: EmblemFaction.balaur,
      sizePreset: size,
      customSize: customSize,
      primaryColor: primaryColor ?? SocialThemeTokens.balaurFlame,
      coreColor: coreColor ?? SocialThemeTokens.balaurRuby,
      auraIntensity: auraIntensity,
      showOrbitingParticles: showOrbitingParticles,
      showRadiantRays: showRadiantRays,
      showInnerGlow: showInnerGlow,
      animationDuration: animationDuration,
      controller: controller,
      progressAnimation: progressAnimation,
      fallbackPainter: fallbackPainter,
      tierBadgeText: rankText,
      onTap: onTap,
    );
  }

  /// Factory for Daeva Ascendant sovereign star crest.
  factory PulsingEmblemWidget.daeva({
    Key? key,
    PulsingEmblemSize size = PulsingEmblemSize.standard,
    double? customSize,
    String? tierText,
    Color? primaryColor,
    Color? coreColor,
    double auraIntensity = 1.0,
    bool showOrbitingParticles = true,
    bool showRadiantRays = true,
    bool showInnerGlow = true,
    Duration animationDuration = const Duration(seconds: 3),
    AnimationController? controller,
    Animation<double>? progressAnimation,
    CustomPainter? fallbackPainter,
    VoidCallback? onTap,
  }) {
    return PulsingEmblemWidget(
      key: key,
      faction: EmblemFaction.daeva,
      sizePreset: size,
      customSize: customSize,
      primaryColor: primaryColor ?? SocialThemeTokens.aetherCyan,
      coreColor: coreColor ?? SocialThemeTokens.daevaPrismWhite,
      auraIntensity: auraIntensity,
      showOrbitingParticles: showOrbitingParticles,
      showRadiantRays: showRadiantRays,
      showInnerGlow: showInnerGlow,
      animationDuration: animationDuration,
      controller: controller,
      progressAnimation: progressAnimation,
      fallbackPainter: fallbackPainter,
      tierBadgeText: tierText,
      onTap: onTap,
    );
  }

  final EmblemFaction faction;
  final PulsingEmblemSize sizePreset;
  final double? customSize;
  final Color? primaryColor;
  final Color? coreColor;
  final double auraIntensity;
  final bool showOrbitingParticles;
  final bool showRadiantRays;
  final bool showInnerGlow;
  final String? tierBadgeText;
  final Duration animationDuration;
  final AnimationController? controller;
  final Animation<double>? progressAnimation;
  final CustomPainter? fallbackPainter;
  final VoidCallback? onTap;

  double get dimension => customSize ?? sizePreset.dimension;

  @override
  State<PulsingEmblemWidget> createState() => _PulsingEmblemWidgetState();
}

class _PulsingEmblemWidgetState extends State<PulsingEmblemWidget>
    with SingleTickerProviderStateMixin {
  AnimationController? _internalController;

  Animation<double> get _activeAnimation {
    if (widget.controller != null) {
      return widget.controller!;
    }
    if (widget.progressAnimation != null) {
      return widget.progressAnimation!;
    }
    return _internalController!;
  }

  bool get _needsInternalController =>
      widget.controller == null && widget.progressAnimation == null;

  @override
  void initState() {
    super.initState();
    if (_needsInternalController) {
      _initInternalController();
    }
  }

  void _initInternalController() {
    _internalController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant PulsingEmblemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_needsInternalController) {
      if (_internalController == null) {
        _initInternalController();
      } else if (oldWidget.animationDuration != widget.animationDuration) {
        _internalController!.duration = widget.animationDuration;
        if (!_internalController!.isAnimating) {
          _internalController!.repeat();
        }
      }
    } else {
      if (_internalController != null) {
        _internalController!.dispose();
        _internalController = null;
      }
    }
  }

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double rawDim = widget.dimension;
    if (rawDim <= 0.0) {
      return const SizedBox.shrink();
    }
    final double dim = rawDim.clamp(12.0, 4096.0);
    final bool hasBadge = widget.tierBadgeText != null && widget.tierBadgeText!.trim().isNotEmpty;
    final double totalHeight = dim + (hasBadge ? 12.0 : 0.0);

    final Animation<double> animation = _activeAnimation;

    Widget emblem = AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final double progress = animation.value;
        return CustomPaint(
          size: Size(dim, dim),
          painter: widget.fallbackPainter ??
              PulsingEmblemPainter(
                progress: progress,
                faction: widget.faction,
                customPrimaryColor: widget.primaryColor,
                customCoreColor: widget.coreColor,
                auraIntensity: widget.auraIntensity,
                showOrbitingParticles: widget.showOrbitingParticles,
                showRadiantRays: widget.showRadiantRays,
                showInnerGlow: widget.showInnerGlow,
              ),
        );
      },
    );

    if (hasBadge) {
      emblem = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          emblem,
          Positioned(
            bottom: -2.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.5),
              decoration: BoxDecoration(
                color: SocialThemeTokens.abyssVoid,
                borderRadius: BorderRadius.circular(4.0),
                border: Border.all(
                  color: SocialThemeTokens.celestialGold.withValues(alpha: 0.8),
                  width: 0.8,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 4.0,
                    offset: Offset(0, 1.5),
                  ),
                ],
              ),
              child: Text(
                widget.tierBadgeText!,
                style: const TextStyle(
                  color: SocialThemeTokens.celestialGoldLight,
                  fontSize: 9.0,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (widget.onTap != null) {
      emblem = GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: emblem,
      );
    }

    return Semantics(
      label: '${widget.faction.displayName} Emblem',
      button: widget.onTap != null,
      child: ConstrainedBox(
        constraints: BoxConstraints.tightFor(
          width: dim,
          height: totalHeight,
        ),
        child: Center(child: emblem),
      ),
    );
  }
}
