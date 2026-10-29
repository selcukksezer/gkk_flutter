import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../social_shaders.dart';
import '../theme/social_theme_tokens.dart';
import 'celestial_banner_painter.dart';

/// Reusable 2027 Aion 2 Mobile banner widget with dynamic celestial shader animation.
///
/// Easily placed across Guild, Quests, Season Pass, Leaderboard, and Reputation screens.
/// Supports both Impeller/RuntimeEffect GPU shader execution (`celestial_banner.frag`)
/// and seamless analytical CPU CustomPaint fallback.
class CelestialBannerWidget extends StatefulWidget {
  const CelestialBannerWidget({
    super.key,
    this.child,
    this.title,
    this.subtitle,
    this.badgeText,
    this.leading,
    this.trailing,
    this.height,
    this.width,
    this.borderRadius = 16.0,
    this.primaryEnergyColor = SocialThemeTokens.aetherCyan,
    this.secondaryEnergyColor = SocialThemeTokens.daevaPrismViolet,
    this.goldShimmerColor = SocialThemeTokens.celestialGold,
    this.energyIntensity = 1.0,
    this.showBorderShimmer = true,
    this.showCornerFiligree = true,
    this.showFloatingMotes = true,
    this.isSwallowtail = false,
    this.animationDuration = const Duration(seconds: 4),
    this.controller,
    this.time,
    this.customShader,
    this.enableShader = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
    this.margin,
    this.onTap,
  });

  /// Factory for Guild Screen top prestige header.
  factory CelestialBannerWidget.guildHeader({
    Key? key,
    required String guildName,
    required String levelText,
    String? motto,
    Widget? emblem,
    VoidCallback? onTap,
    double? height,
    AnimationController? controller,
    bool enableShader = true,
  }) {
    return CelestialBannerWidget(
      key: key,
      height: height ?? 110.0,
      title: guildName,
      subtitle: motto ?? 'United Under the Aegis of Aion',
      badgeText: levelText,
      leading: emblem,
      primaryEnergyColor: SocialThemeTokens.elyosGold,
      secondaryEnergyColor: SocialThemeTokens.aetherCyan,
      goldShimmerColor: SocialThemeTokens.celestialGold,
      controller: controller,
      enableShader: enableShader,
      onTap: onTap,
    );
  }

  /// Factory for Season Pass milestone header.
  factory CelestialBannerWidget.seasonPassMilestone({
    Key? key,
    required String seasonTitle,
    required String tierText,
    String? daysRemaining,
    Widget? rewardIllustration,
    VoidCallback? onTap,
    double? height,
    AnimationController? controller,
    bool enableShader = true,
  }) {
    return CelestialBannerWidget(
      key: key,
      height: height ?? 120.0,
      title: seasonTitle,
      subtitle: daysRemaining != null ? '$tierText • $daysRemaining' : tierText,
      badgeText: 'SEASON PASS',
      trailing: rewardIllustration,
      primaryEnergyColor: SocialThemeTokens.daevaPrismViolet,
      secondaryEnergyColor: SocialThemeTokens.aetherCyan,
      goldShimmerColor: SocialThemeTokens.celestialGold,
      controller: controller,
      enableShader: enableShader,
      onTap: onTap,
    );
  }

  /// Factory for Quests reward notification banner.
  factory CelestialBannerWidget.questClaim({
    Key? key,
    required String questTitle,
    required String rewardDescription,
    Widget? rewardIcon,
    VoidCallback? onClaim,
    double? height,
    AnimationController? controller,
    bool enableShader = true,
  }) {
    return CelestialBannerWidget(
      key: key,
      height: height ?? 96.0,
      title: questTitle,
      subtitle: rewardDescription,
      badgeText: 'CLAIM READY',
      leading: rewardIcon,
      primaryEnergyColor: SocialThemeTokens.aetherCyan,
      secondaryEnergyColor: SocialThemeTokens.celestialGold,
      controller: controller,
      enableShader: enableShader,
      onTap: onClaim,
    );
  }

  /// Factory for Leaderboard top-rank podium banner.
  factory CelestialBannerWidget.leaderboardPodium({
    Key? key,
    required String rankTitle,
    required String playerName,
    required String scoreText,
    Widget? rankBadge,
    VoidCallback? onTap,
    double? height,
    AnimationController? controller,
    bool enableShader = true,
  }) {
    return CelestialBannerWidget(
      key: key,
      height: height ?? 100.0,
      title: playerName,
      subtitle: scoreText,
      badgeText: rankTitle,
      leading: rankBadge,
      primaryEnergyColor: SocialThemeTokens.celestialGold,
      secondaryEnergyColor: SocialThemeTokens.balaurFlame,
      controller: controller,
      enableShader: enableShader,
      onTap: onTap,
    );
  }

  /// Factory for Reputation faction allegiance banner.
  factory CelestialBannerWidget.reputationFaction({
    Key? key,
    required String factionName,
    required String standingTier,
    String? progressText,
    Widget? crest,
    VoidCallback? onTap,
    double? height,
    AnimationController? controller,
    bool enableShader = true,
  }) {
    return CelestialBannerWidget(
      key: key,
      height: height ?? 108.0,
      title: factionName,
      subtitle: progressText != null ? '$standingTier • $progressText' : standingTier,
      badgeText: 'FACTION REPUTATION',
      leading: crest,
      primaryEnergyColor: SocialThemeTokens.asmodianViolet,
      secondaryEnergyColor: SocialThemeTokens.aetherCyan,
      controller: controller,
      enableShader: enableShader,
      onTap: onTap,
    );
  }

  final Widget? child;
  final String? title;
  final String? subtitle;
  final String? badgeText;
  final Widget? leading;
  final Widget? trailing;

  final double? height;
  final double? width;
  final double borderRadius;
  final Color primaryEnergyColor;
  final Color secondaryEnergyColor;
  final Color goldShimmerColor;
  final double energyIntensity;
  final bool showBorderShimmer;
  final bool showCornerFiligree;
  final bool showFloatingMotes;
  final bool isSwallowtail;
  final Duration animationDuration;

  /// Optional external animation controller for synchronized ticker forwarding.
  final AnimationController? controller;

  /// Optional continuous elapsed time in seconds passed directly into the shader.
  final double? time;

  /// Optional custom precompiled fragment shader instance.
  final ui.FragmentShader? customShader;

  /// Whether GPU fragment shader is requested (defaults to true; falls back to CPU if unavailable).
  final bool enableShader;

  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  State<CelestialBannerWidget> createState() => _CelestialBannerWidgetState();
}

class _CelestialBannerWidgetState extends State<CelestialBannerWidget>
    with SingleTickerProviderStateMixin {
  AnimationController? _internalController;
  ui.FragmentShader? _shader;

  AnimationController get _effectiveController =>
      widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = AnimationController(
        vsync: this,
        duration: widget.animationDuration,
      )..repeat();
    }
    _initShader();
  }

  void _initShader() {
    if (!widget.enableShader) {
      _shader = null;
      return;
    }
    if (widget.customShader != null) {
      _shader = widget.customShader;
      return;
    }

    final cache = SocialShaderCache.instance;
    if (cache.isInitialized) {
      _shader = cache.createCelestialBannerShader();
    } else {
      cache.init().then((supported) {
        if (mounted && supported && widget.enableShader && widget.customShader == null) {
          setState(() {
            _shader = cache.createCelestialBannerShader();
          });
        }
      }).catchError((_) {
        // Fallback gracefully: CPU analytical painter handles rendering seamlessly
      });
    }
  }

  @override
  void didUpdateWidget(covariant CelestialBannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Synchronize controller lifecycle
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller == null && widget.controller != null) {
        _internalController?.dispose();
        _internalController = null;
      } else if (oldWidget.controller != null && widget.controller == null) {
        _internalController = AnimationController(
          vsync: this,
          duration: widget.animationDuration,
        )..repeat();
      }
    } else if (widget.controller == null &&
        oldWidget.animationDuration != widget.animationDuration) {
      _internalController?.duration = widget.animationDuration;
    }

    // Synchronize shader lifecycle
    if (oldWidget.customShader != widget.customShader ||
        oldWidget.enableShader != widget.enableShader) {
      if (widget.customShader != null) {
        _shader = widget.customShader;
      } else if (!widget.enableShader) {
        _shader = null;
      } else {
        _initShader();
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
    final Widget content = widget.child ?? _buildDefaultContent();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Guard against unbounded horizontal flex crashes (Row / ListView horizontal)
        final double? resolvedWidth = widget.width ??
            (constraints.hasBoundedWidth ? constraints.maxWidth : 320.0);
        final double minH = widget.height ?? 64.0;
        final double? maxH = widget.height;

        final banner = AnimatedBuilder(
          animation: _effectiveController,
          builder: (context, child) {
            final double currentProgress = _effectiveController.value;
            final double activeTime = widget.time ??
                (currentProgress * (widget.animationDuration.inMilliseconds / 1000.0));

            return CustomPaint(
              painter: CelestialBannerPainter(
                progress: currentProgress,
                shader: _shader,
                time: activeTime,
                primaryEnergyColor: widget.primaryEnergyColor,
                secondaryEnergyColor: widget.secondaryEnergyColor,
                goldShimmerColor: widget.goldShimmerColor,
                energyIntensity: widget.energyIntensity,
                borderRadius: widget.borderRadius,
                showBorderShimmer: widget.showBorderShimmer,
                showCornerFiligree: widget.showCornerFiligree,
                showFloatingMotes: widget.showFloatingMotes,
                isSwallowtail: widget.isSwallowtail,
              ),
              child: child,
            );
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: resolvedWidth ?? 0.0,
              maxWidth: resolvedWidth ?? double.infinity,
              minHeight: minH,
              maxHeight: maxH ?? double.infinity,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: Container(
                padding: widget.padding,
                child: content,
              ),
            ),
          ),
        );

        Widget result = banner;
        if (widget.margin != null) {
          result = Padding(padding: widget.margin!, child: result);
        }

        if (widget.onTap != null) {
          result = Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              onTap: widget.onTap,
              splashColor: widget.primaryEnergyColor.withValues(alpha: 0.15),
              highlightColor: widget.goldShimmerColor.withValues(alpha: 0.08),
              child: result,
            ),
          );
        }

        return result;
      },
    );
  }

  Widget _buildDefaultContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.leading != null) ...[
          widget.leading!,
          const SizedBox(width: 14.0),
        ],
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.badgeText != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: widget.goldShimmerColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4.0),
                    border: Border.all(
                      color: widget.goldShimmerColor.withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    widget.badgeText!,
                    style: TextStyle(
                      color: widget.goldShimmerColor,
                      fontSize: 10.0,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 4.0),
              ],
              if (widget.title != null)
                Text(
                  widget.title!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 4.0,
                        offset: Offset(0, 1.5),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 2.0),
                Text(
                  widget.subtitle!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.0,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (widget.trailing != null) ...[
          const SizedBox(width: 12.0),
          widget.trailing!,
        ],
      ],
    );
  }
}
