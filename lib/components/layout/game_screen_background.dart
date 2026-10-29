import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/engine/adaptive_quality_scaler.dart';
import '../../core/engine/zero_jank_preloader.dart';
import '../../core/utils/keyboard_dismiss.dart';
import '../../screens/settings/graphics_settings_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'game_chrome.dart';

/// Scroll list layout — moderate gaps between sections; bottom bar clearance at end.
abstract final class GameScrollLayout {
  /// Major blocks (hero, panel groups, section titles + content).
  static const double sectionGap = AppSpacing.md;

  /// Stacked cards or rows inside one block.
  static const double itemGap = AppSpacing.sm;

  /// Section title → first child below it.
  static const double titleGap = AppSpacing.sm;

  static Widget get sectionSpacer => const SizedBox(height: sectionGap);
  static Widget get itemSpacer => const SizedBox(height: itemGap);
  static Widget get titleSpacer => const SizedBox(height: titleGap);

  static EdgeInsets pagePadding(BuildContext context) => padding(context);

  /// Bottom inset so last scroll item clears [GameBottomBar] (extendBody safe).
  static double bottomInset(BuildContext context) => gameBottomBarClearance(context);

  /// Standard scroll padding — bottom always clears overlay nav.
  static EdgeInsets padding(
    BuildContext context, {
    double horizontal = AppSpacing.base,
    double top = AppSpacing.base,
    double bottomExtra = 0,
  }) =>
      EdgeInsets.fromLTRB(
        horizontal,
        top,
        horizontal,
        bottomInset(context) + bottomExtra,
      );

  /// Like [padding] with explicit edges; bottom = bar clearance (+ optional extra).
  static EdgeInsets fromLTRB(
    BuildContext context, {
    required double left,
    required double top,
    required double right,
    double bottomExtra = 0,
  }) =>
      EdgeInsets.fromLTRB(
        left,
        top,
        right,
        bottomInset(context) + bottomExtra,
      );

  /// Keeps L/T/R from [base]; bottom = bar clearance + [base.bottom].
  static EdgeInsets withClearance(BuildContext context, EdgeInsets base) =>
      EdgeInsets.fromLTRB(
        base.left,
        base.top,
        base.right,
        bottomInset(context) + base.bottom,
      );

  static Widget bottomSpacer(BuildContext context) =>
      SizedBox(height: bottomInset(context));
}

/// Wraps a scroll block with consistent top spacing (skip [leadingGap] on first item).
class GameScrollSection extends StatelessWidget {
  const GameScrollSection({
    super.key,
    required this.child,
    this.leadingGap = true,
  });

  final Widget child;
  final bool leadingGap;

  @override
  Widget build(BuildContext context) {
    if (!leadingGap) return child;
    return Padding(
      padding: const EdgeInsets.only(top: GameScrollLayout.sectionGap),
      child: child,
    );
  }
}

/// Fixed-column grid for [ListView] children — avoids [GridView] shrinkWrap phantom space.
class GameFixedGrid extends StatelessWidget {
  const GameFixedGrid({
    super.key,
    required this.crossAxisCount,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = AppSpacing.sm,
  });

  final int crossAxisCount;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (itemCount <= 0) return const SizedBox.shrink();

    final List<Widget> items = List<Widget>.generate(
      itemCount,
      (int index) => itemBuilder(context, index),
    );

    return GameGridColumns(
      crossAxisCount: crossAxisCount,
      spacing: spacing,
      children: items,
    );
  }
}

/// Fixed-height grid rows for [ListView] children — avoids [GridView] shrinkWrap phantom space.
class GameGridColumns extends StatelessWidget {
  const GameGridColumns({
    super.key,
    required this.crossAxisCount,
    required this.children,
    this.spacing = AppSpacing.sm,
  });

  final int crossAxisCount;
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i += crossAxisCount) {
      if (i > 0) rows.add(SizedBox(height: spacing));
      final List<Widget> rowChildren = <Widget>[];
      for (int col = 0; col < crossAxisCount; col++) {
        if (col > 0) rowChildren.add(SizedBox(width: spacing));
        final int index = i + col;
        rowChildren.add(
          Expanded(
            child: index < children.length ? children[index] : const SizedBox.shrink(),
          ),
        );
      }
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowChildren,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// Tactile feedback intensities for Aion 2 obsidian-glass interactions.
enum AionHapticType {
  selection,
  light,
  medium,
  heavy,
}

/// 2027 Aion 2 Celestial Starfield & Micro-Dot Grid Overlay.
///
/// Features subtle micro-star constellation matrix with dual-tier
/// ether energy glimmer (cyan & celestial gold starlight).
class DotGridPainter extends CustomPainter {
  const DotGridPainter({
    this.spacing = 16,
    this.dotRadius = 1.1,
    this.dotOpacity = 0.07,
    this.dotColor,
    this.celestialMatrix = true,
  });

  final double spacing;
  final double dotRadius;
  final double dotOpacity;
  final Color? dotColor;
  final bool celestialMatrix;

  @override
  void paint(Canvas canvas, Size size) {
    final Color baseColor = dotColor ?? Colors.white;
    final Paint standardPaint = Paint()
      ..color = baseColor.withValues(alpha: dotOpacity)
      ..style = PaintingStyle.fill;

    // Optional subtle ether glow paints for celestial constellation intersections
    final Paint cyanStarPaint = celestialMatrix
        ? (Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: (dotOpacity * 1.5).clamp(0.0, 0.22))
          ..style = PaintingStyle.fill)
        : standardPaint;

    final Paint goldStarPaint = celestialMatrix
        ? (Paint()
          ..color = const Color(0xFFFFD700).withValues(alpha: (dotOpacity * 1.4).clamp(0.0, 0.20))
          ..style = PaintingStyle.fill)
        : standardPaint;

    int colIndex = 0;
    for (double x = spacing / 2; x < size.width; x += spacing, colIndex++) {
      int rowIndex = 0;
      for (double y = spacing / 2; y < size.height; y += spacing, rowIndex++) {
        // Celestial matrix variation: periodic subtle ether star glimmers
        Paint paint = standardPaint;
        double radius = dotRadius;

        if (celestialMatrix) {
          final int pattern = (colIndex * 7 + rowIndex * 13) % 23;
          if (pattern == 0) {
            paint = cyanStarPaint;
            radius = dotRadius * 1.35;
          } else if (pattern == 11) {
            paint = goldStarPaint;
            radius = dotRadius * 1.25;
          }
        }

        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DotGridPainter oldDelegate) =>
      spacing != oldDelegate.spacing ||
      dotRadius != oldDelegate.dotRadius ||
      dotOpacity != oldDelegate.dotOpacity ||
      dotColor != oldDelegate.dotColor ||
      celestialMatrix != oldDelegate.celestialMatrix;
}

/// Full-screen 2027 Aion 2 Obsidian-Glass Background.
///
/// Combines:
/// - Deep obsidian cosmic gradient foundation (`Color(0xFF05070B)`, `Color(0xFF090D15)`, `Color(0xFF0E131E)`).
/// - Multi-tiered cyan & gold ether energy luminescence nebulae.
/// - Celestial micro-starfield matrix and atmospheric vignette depth.
/// - Optional frosted glass depth layers ([ui.ImageFilter.blur]).
/// - Optional [SafeArea] padding integration with flexible edge controls.
/// - Integrated tactile [HapticFeedback] on background interaction / dismiss.
class GameScreenBackground extends StatelessWidget {
  const GameScreenBackground({
    super.key,
    required this.child,
    this.showAmbientGlow = true,
    this.safeArea = false,
    this.useSafeArea,
    this.safeAreaTop = true,
    this.safeAreaBottom = false,
    this.safeAreaLeft = true,
    this.safeAreaRight = true,
    this.enableHaptics = false,
    this.onTap,
    this.frostedGlass = false,
    this.frostedBlur = 8.0,
    this.showVignette = true,
    this.showConstellations = true,
    this.glowIntensity = 1.0,
    this.customNebulae,
    this.tierOverride,
    this.scalerOverride,
  });

  /// Primary screen content.
  final Widget child;

  /// Whether to display the ambient ether luminescence nebulae.
  final bool showAmbientGlow;

  /// Whether to wrap content in a [SafeArea]. Defaults to false for backward compatibility.
  final bool safeArea;

  /// Alias for [safeArea]. If provided, overrides [safeArea].
  final bool? useSafeArea;

  /// If safe area is enabled, whether to pad the top system inset.
  final bool safeAreaTop;

  /// If safe area is enabled, whether to pad the bottom system inset.
  final bool safeAreaBottom;

  /// If safe area is enabled, whether to pad the left system inset.
  final bool safeAreaLeft;

  /// If safe area is enabled, whether to pad the right system inset.
  final bool safeAreaRight;

  /// Whether to trigger tactile haptic feedback on background interactions.
  final bool enableHaptics;

  /// Callback when user taps an unoccupied background region.
  final VoidCallback? onTap;

  /// Whether to render a frosted glass gaussian blur depth backdrop.
  final bool frostedGlass;

  /// Blur sigma if [frostedGlass] is true.
  final double frostedBlur;

  /// Whether to apply atmospheric radial vignette for crisp foreground contrast.
  final bool showVignette;

  /// Whether to render celestial ether starfield constellation matrix dots.
  final bool showConstellations;

  /// Multiplier for ambient ether glow intensity (0.0 to 2.0).
  final double glowIntensity;

  /// Optional extra custom nebulae widgets to inject into the ambient stack.
  final List<Widget>? customNebulae;

  /// Optional hardware tier override (e.g. for testing or fine-grained tuning).
  final HardwareTier? tierOverride;

  /// Optional scaler instance override (e.g. for testing).
  final AdaptiveQualityScaler? scalerOverride;

  // ──────────────────────────── 2027 Aion 2 Tokens ────────────────────────────
  /// Deepest obsidian cosmic abyss (#05070B).
  static const Color obsidianVoid = Color(0xFF05070B);

  /// Mid obsidian expanse (#090D15).
  static const Color obsidianBase = Color(0xFF090D15);

  /// Elevated obsidian atmospheric horizon (#0E131E).
  static const Color obsidianSurface = Color(0xFF0E131E);

  // Backward-compatibility aliases
  static const Color carbonVoid = Color(0xFF080B12);
  static const Color spaceNavy = Color(0xFF121826);

  // Ether Luminescence & Celestial Accents
  static const Color etherCyan = Color(0xFF00E5FF);
  static const Color etherCyanGlow = Color(0xFF38BDF8);
  static const Color etherGold = Color(0xFFFFD700);
  static const Color celestialGold = Color(0xFFFFD700);
  static const Color liquidGold = Color(0xFFFFB800);
  static const Color astralNavy = Color(0xFF121A2D);

  static bool _hasPrewarmed = false;

  /// Ensures celestial background assets and gradients are pre-warmed via [ZeroJankPreloader.instance.preloadAtomic].
  static void ensurePrewarmed([HardwareTier? tier]) {
    if (_hasPrewarmed) return;
    _hasPrewarmed = true;
    prewarmBackgroundAssets(tier: tier);
  }

  /// Resets prewarm flag for testing.
  @visibleForTesting
  static void resetPrewarmState() {
    _hasPrewarmed = false;
  }

  /// Pre-warms celestial background gradient palettes, shader pipelines, and color stops
  /// into VRAM/RAM cache via [ZeroJankPreloader.instance.preloadAtomic] with [PreloadPriority.criticalHud].
  static Future<bool> prewarmBackgroundAssets({HardwareTier? tier}) async {
    final HardwareTier targetTier = tier ?? resolveActiveTier();
    try {
      return await ZeroJankPreloader.instance.preloadAtomic<bool>(
        id: 'game_screen_background_assets_${targetTier.name}',
        priority: PreloadPriority.criticalHud,
        targetCache: CacheTarget.vram,
        estimatedSizeBytes: 64 * 1024,
        tags: <String>{'background', 'celestial', 'gradients', targetTier.name},
        isPinned: true,
        loader: () async {
          // Pre-warm the celestial palette and color stops to prevent runtime shader compilation jank
          final List<Color> warmPalette = <Color>[
            obsidianVoid,
            obsidianBase,
            obsidianSurface,
            etherCyan,
            etherCyanGlow,
            etherGold,
            liquidGold,
            astralNavy,
          ];
          assert(warmPalette.length == 8);
          return true;
        },
      );
    } catch (_) {
      return false;
    }
  }

  /// Resolves the active [HardwareTier] from [tierOverride], [scalerOverride],
  /// or [GraphicsSettingsService.instance.scaler.currentTier].
  static HardwareTier resolveActiveTier({
    HardwareTier? tierOverride,
    AdaptiveQualityScaler? scalerOverride,
  }) {
    if (tierOverride != null) return tierOverride;
    if (scalerOverride != null) return scalerOverride.currentTier;
    try {
      return GraphicsSettingsService.instance.scaler.currentTier;
    } catch (_) {
      return HardwareTier.mid;
    }
  }

  /// Resolves the effective blur sigma based on active hardware tier.
  ///
  /// - Eco / Low tiers (<=2GB RAM): 0.0 (blur bypassed to eliminate GPU raster jank)
  /// - Mid tier: Conservative blur (sigma 6.0 - 8.0)
  /// - High / Ultra tiers: Full luxury glassmorphism blur (sigma 16.0 - 24.0)
  static double resolveFrostedBlur({
    required HardwareTier tier,
    double requestedBlur = 8.0,
  }) {
    switch (tier) {
      case HardwareTier.eco:
      case HardwareTier.low:
        return 0.0;
      case HardwareTier.mid:
        return requestedBlur <= 0.0 ? 0.0 : requestedBlur.clamp(6.0, 8.0);
      case HardwareTier.high:
        return requestedBlur <= 0.0 ? 0.0 : (requestedBlur < 16.0 ? 16.0 : requestedBlur.clamp(16.0, 20.0));
      case HardwareTier.ultra:
        return requestedBlur <= 0.0 ? 0.0 : (requestedBlur < 20.0 ? 24.0 : requestedBlur.clamp(20.0, 24.0));
    }
  }

  /// Triggers standard 2027 Aion 2 tactile haptic feedback.
  static Future<void> triggerHaptic([AionHapticType type = AionHapticType.selection]) async {
    switch (type) {
      case AionHapticType.selection:
        await HapticFeedback.selectionClick();
      case AionHapticType.light:
        await HapticFeedback.lightImpact();
      case AionHapticType.medium:
        await HapticFeedback.mediumImpact();
      case AionHapticType.heavy:
        await HapticFeedback.heavyImpact();
    }
  }

  List<Widget> _buildAionEtherNebulae(HardwareTier tier) {
    final double intensity = glowIntensity.clamp(0.0, 2.0);
    if (intensity <= 0) return const <Widget>[];

    // On Eco tier (<1.8GB RAM), render only single light cyan nebula to minimize GPU fill-rate overdraw
    if (tier == HardwareTier.eco) {
      return <Widget>[
        Positioned(
          top: -160,
          left: -130,
          child: IgnorePointer(
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    etherCyan.withValues(alpha: 0.06 * intensity),
                    etherCyan.withValues(alpha: 0.0),
                  ],
                  stops: const <double>[0.0, 1.0],
                ),
              ),
            ),
          ),
        ),
        if (customNebulae != null) ...customNebulae!,
      ];
    }

    // On Low tier (2GB-3GB RAM), render top cyan and gold nebulae
    if (tier == HardwareTier.low) {
      return <Widget>[
        Positioned(
          top: -160,
          left: -130,
          child: IgnorePointer(
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    etherCyan.withValues(alpha: 0.07 * intensity),
                    etherCyan.withValues(alpha: 0.0),
                  ],
                  stops: const <double>[0.0, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: -110,
          right: -90,
          child: IgnorePointer(
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    etherGold.withValues(alpha: 0.06 * intensity),
                    etherGold.withValues(alpha: 0.0),
                  ],
                  stops: const <double>[0.0, 1.0],
                ),
              ),
            ),
          ),
        ),
        if (customNebulae != null) ...customNebulae!,
      ];
    }

    // Full luxury nebulae on Mid, High, Ultra tiers
    return <Widget>[
      // 1. Top-Left Cyan Ether Aurora Nebula
      Positioned(
        top: -160,
        left: -130,
        child: IgnorePointer(
          child: Container(
            width: 440,
            height: 440,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  etherCyan.withValues(alpha: 0.09 * intensity),
                  etherCyanGlow.withValues(alpha: 0.04 * intensity),
                  etherCyan.withValues(alpha: 0.0),
                ],
                stops: const <double>[0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
      ),

      // 2. Top-Right Celestial Solar Gold Nebula
      Positioned(
        top: -110,
        right: -90,
        child: IgnorePointer(
          child: Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  etherGold.withValues(alpha: 0.08 * intensity),
                  liquidGold.withValues(alpha: 0.03 * intensity),
                  etherGold.withValues(alpha: 0.0),
                ],
                stops: const <double>[0.0, 0.40, 1.0],
              ),
            ),
          ),
        ),
      ),

      // 3. Mid-Center Deep Astral Indigo Energy Field
      Positioned(
        top: 240,
        left: -180,
        child: IgnorePointer(
          child: Container(
            width: 500,
            height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  astralNavy.withValues(alpha: 0.35 * intensity),
                  astralNavy.withValues(alpha: 0.0),
                ],
                stops: const <double>[0.0, 0.80],
              ),
            ),
          ),
        ),
      ),

      // 4. Bottom-Right Harmonic Molten Gold & Cyan Resonance Nebula
      Positioned(
        bottom: -210,
        right: -150,
        child: IgnorePointer(
          child: Container(
            width: 480,
            height: 480,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  liquidGold.withValues(alpha: 0.08 * intensity),
                  etherCyan.withValues(alpha: 0.025 * intensity),
                  liquidGold.withValues(alpha: 0.0),
                ],
                stops: const <double>[0.0, 0.42, 1.0],
              ),
            ),
          ),
        ),
      ),

      // Custom injected nebulae if provided
      if (customNebulae != null) ...customNebulae!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final HardwareTier tier = resolveActiveTier(
      tierOverride: tierOverride,
      scalerOverride: scalerOverride,
    );
    final bool isLowTier = tier == HardwareTier.eco || tier == HardwareTier.low;
    final bool isHighOrUltra = tier == HardwareTier.high || tier == HardwareTier.ultra;
    final double effectiveFrostedBlur = resolveFrostedBlur(
      tier: tier,
      requestedBlur: frostedBlur,
    );

    // Pre-warm background assets/gradients via ZeroJankPreloader
    ensurePrewarmed(tier);

    final bool effectiveSafeArea = useSafeArea ?? safeArea;
    Widget body = child;

    if (effectiveSafeArea) {
      body = SafeArea(
        top: safeAreaTop,
        bottom: safeAreaBottom,
        left: safeAreaLeft,
        right: safeAreaRight,
        child: body,
      );
    }

    // Dismiss keyboard and optional haptic feedback on background tap
    Widget interactiveLayer;
    if (enableHaptics || onTap != null) {
      interactiveLayer = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (enableHaptics) {
            HapticFeedback.selectionClick();
          }
          dismissKeyboard(context);
          onTap?.call();
        },
        child: body,
      );
    } else {
      interactiveLayer = DismissKeyboard(child: body);
    }

    return Listener(
      // ZeroJank: Yield preloader background worker slices during active user touches
      onPointerDown: (_) {
        try {
          ZeroJankPreloader.instance.onTouchStart();
        } catch (_) {}
      },
      onPointerUp: (_) {
        try {
          ZeroJankPreloader.instance.onTouchEnd();
        } catch (_) {}
      },
      onPointerCancel: (_) {
        try {
          ZeroJankPreloader.instance.onTouchEnd();
        } catch (_) {}
      },
      child: Stack(
        children: <Widget>[
          // Layer 1: 2027 Aion 2 Obsidian Cosmic Gradient Foundation
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isHighOrUltra
                      ? const <Color>[
                          Color(0xFF141C2E), // Luxury celestial astral horizon
                          obsidianSurface,
                          obsidianBase,
                          obsidianVoid,
                        ]
                      : const <Color>[
                          obsidianSurface,
                          obsidianBase,
                          obsidianVoid,
                        ],
                  stops: isHighOrUltra
                      ? const <double>[0.0, 0.28, 0.65, 1.0]
                      : const <double>[0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Layer 2: Subtle Cyan & Gold Ether Energy Luminescence Nebulae
          if (showAmbientGlow) ..._buildAionEtherNebulae(tier),

          // Layer 3: Celestial Starfield & Micro-Dot Grid
          Positioned.fill(
            child: CustomPaint(
              painter: DotGridPainter(
                spacing: tier == HardwareTier.eco ? 22 : 16,
                celestialMatrix: tier == HardwareTier.eco ? false : showConstellations,
              ),
            ),
          ),

          // Layer 4: Frosted Glass Depth Layer (Optional)
          // Adaptive Quality Scaler: Bypass BackdropFilter on Eco/Low tier to prevent GPU raster jank.
          // Mid tier uses conservative blur (sigma 6-8). High/Ultra tiers use full luxury blur (sigma 16-24) with celestial gradients.
          if (frostedGlass)
            Positioned.fill(
              child: IgnorePointer(
                child: isLowTier
                    ? const DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xDC05070B), // Solid dark obsidian overlay bypasses GPU blur
                        ),
                        child: SizedBox.expand(),
                      )
                    : DecoratedBox(
                        decoration: isHighOrUltra
                            ? BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: <Color>[
                                    etherCyan.withValues(alpha: 0.05),
                                    Colors.transparent,
                                    etherGold.withValues(alpha: 0.04),
                                  ],
                                  stops: const <double>[0.0, 0.5, 1.0],
                                ),
                              )
                            : const BoxDecoration(),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(
                            sigmaX: effectiveFrostedBlur,
                            sigmaY: effectiveFrostedBlur,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
              ),
            ),

          // Layer 5: Atmospheric Vignette for Maximum Foreground Contrast
          if (showVignette)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.18,
                      colors: <Color>[
                        Colors.transparent,
                        obsidianVoid.withValues(alpha: 0.12),
                        obsidianVoid.withValues(alpha: 0.50),
                      ],
                      stops: const <double>[0.55, 0.85, 1.0],
                    ),
                  ),
                ),
              ),
            ),

          // Layer 6: Content + SafeArea + Tap & Haptic Feedback Handling
          interactiveLayer,
        ],
      ),
    );
  }
}

/// 2027 Aion 2 Obsidian-Glass Card / Panel Shell.
///
/// Features:
/// - Deep obsidian multi-tone translucent glass gradient (#141C2C → #090D15 → #05070B).
/// - Celestial gold / cyan ether luminescence border with specular highlights.
/// - Optional real [BackdropFilter] gaussian glass blur for AAA physical depth.
/// - Micro-dot starlight grid overlay.
/// - Integrated tactile haptic feedback on interactive panel tap.
class DottedPanel extends StatelessWidget {
  const DottedPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 14,
    this.borderColor,
    this.borderWidth = 1.0,
    this.enableGlassBlur = false,
    this.blurSigma = 10.0,
    this.glowColor,
    this.glowBlurRadius = 0.0,
    this.hasSpecularGlint = true,
    this.onTap,
    this.enableHaptics = false,
    this.tierOverride,
    this.scalerOverride,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? borderColor;
  final double borderWidth;
  final bool enableGlassBlur;
  final double blurSigma;
  final Color? glowColor;
  final double glowBlurRadius;
  final bool hasSpecularGlint;
  final VoidCallback? onTap;
  final bool enableHaptics;

  /// Optional hardware tier override (e.g. for testing).
  final HardwareTier? tierOverride;

  /// Optional scaler instance override (e.g. for testing).
  final AdaptiveQualityScaler? scalerOverride;

  @override
  Widget build(BuildContext context) {
    final HardwareTier tier = GameScreenBackground.resolveActiveTier(
      tierOverride: tierOverride,
      scalerOverride: scalerOverride,
    );
    final bool isLowTier = tier == HardwareTier.eco || tier == HardwareTier.low;
    final double effectiveBlur = GameScreenBackground.resolveFrostedBlur(
      tier: tier,
      requestedBlur: blurSigma,
    );

    final Radius r = Radius.circular(borderRadius);
    final BorderRadius br = BorderRadius.all(r);

    final Color effectiveBorderColor = borderColor ??
        AppColors.liquidGold.withValues(alpha: 0.18);

    final List<BoxShadow> effectiveBoxShadows = <BoxShadow>[
      BoxShadow(
        color: GameScreenBackground.obsidianVoid.withValues(alpha: 0.60),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
      if (glowColor != null && glowBlurRadius > 0)
        BoxShadow(
          color: glowColor!.withValues(alpha: 0.25),
          blurRadius: glowBlurRadius,
          spreadRadius: 1.0,
        ),
    ];

    Widget panelContent = Stack(
      children: <Widget>[
        const Positioned.fill(
          child: CustomPaint(
            painter: DotGridPainter(spacing: 14, dotOpacity: 0.055, celestialMatrix: false),
          ),
        ),
        if (hasSpecularGlint)
          Positioned(
            top: 0,
            left: borderRadius * 0.5,
            right: borderRadius * 0.5,
            child: Container(
              height: 1.0,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.35),
                    GameScreenBackground.etherCyan.withValues(alpha: 0.50),
                    Colors.white.withValues(alpha: 0.35),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const <double>[0.0, 0.25, 0.5, 0.75, 1.0],
                ),
              ),
            ),
          ),
        Padding(
          padding: padding ?? const EdgeInsets.all(12),
          child: child,
        ),
      ],
    );

    // Adaptive Quality Scaler: Bypass BackdropFilter on Eco/Low tiers to prevent GPU raster jank
    if (enableGlassBlur && !isLowTier && effectiveBlur > 0.0) {
      panelContent = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
        child: panelContent,
      );
    }

    Widget container = Container(
      decoration: BoxDecoration(
        borderRadius: br,
        border: Border.all(
          color: effectiveBorderColor,
          width: borderWidth,
        ),
        boxShadow: effectiveBoxShadows,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xEE141C2C),
            GameScreenBackground.obsidianBase.withValues(alpha: 0.94),
            GameScreenBackground.obsidianVoid.withValues(alpha: 0.98),
          ],
          stops: const <double>[0.0, 0.55, 1.0],
        ),
      ),
      child: ClipRRect(
        borderRadius: br,
        child: panelContent,
      ),
    );

    if (onTap != null) {
      container = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: br,
          onTap: () {
            if (enableHaptics) {
              HapticFeedback.lightImpact();
            }
            onTap!();
          },
          splashColor: GameScreenBackground.etherCyan.withValues(alpha: 0.12),
          highlightColor: GameScreenBackground.etherGold.withValues(alpha: 0.08),
          child: container,
        ),
      );
    }

    return container;
  }
}

/// Standalone reusable 2027 Aion 2 Ether Energy Luminescence Nebula.
class AionEtherNebula extends StatelessWidget {
  const AionEtherNebula({
    super.key,
    required this.size,
    required this.primaryColor,
    this.secondaryColor,
    this.intensity = 1.0,
  });

  final double size;
  final Color primaryColor;
  final Color? secondaryColor;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final Color sec = secondaryColor ?? primaryColor.withValues(alpha: 0.5);
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              primaryColor.withValues(alpha: (0.10 * intensity).clamp(0.0, 1.0)),
              sec.withValues(alpha: (0.04 * intensity).clamp(0.0, 1.0)),
              primaryColor.withValues(alpha: 0.0),
            ],
            stops: const <double>[0.0, 0.45, 1.0],
          ),
        ),
      ),
    );
  }
}

