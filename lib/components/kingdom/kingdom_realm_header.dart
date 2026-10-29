import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../theme/app_colors.dart';
import 'kingdom_crest_icons.dart';

/// High-res 2027 Aion 2 obsidian-glass fantasy kingdom realm header banner.
///
/// Features:
/// - Frosted obsidian-glass container with multi-layered [BackdropFilter] blur
/// - Custom vector celestial twilight citadel painting with aurora ribbons and starlight
/// - Celestial Gold (#E5C158) reigning monarch crest aura and luminescent title typography
/// - Ether Cyan (#00E5FF) accent dots & glowing dominion status pill
/// - Tactile [HapticFeedback] on header action and blessing taps
/// - Responsive [SafeArea] top-padding support for device notch & Dynamic Island
class KingdomRealmHeader extends StatelessWidget {
  const KingdomRealmHeader({
    super.key,
    this.realmTitle = 'Aethelgard Hükümranlığı',
    this.reigningKing = 'Aethelgard Kralı',
    this.reigningGuild = 'Gök Muhafızları',
    this.dominionLevel = 12,
    this.activeBlessingSummary,
    this.onTapHeader,
    this.onTapBlessing,
    this.height = 180.0,
    this.useSafeArea = false,
    this.blurSigma = 16.0,
    this.margin,
  });

  final String realmTitle;
  final String reigningKing;
  final String reigningGuild;
  final int dominionLevel;
  final String? activeBlessingSummary;
  final VoidCallback? onTapHeader;
  final VoidCallback? onTapBlessing;
  final double height;
  final bool useSafeArea;
  final double blurSigma;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final topPadding = useSafeArea ? MediaQuery.paddingOf(context).top : 0.0;
    final effectiveHeight = height + topPadding;
    final effectiveMargin = margin ??
        (useSafeArea
            ? const EdgeInsets.fromLTRB(16, 0, 16, 8)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 8));

    final VoidCallback? effectiveOnTap = onTapHeader == null
        ? null
        : () {
            try {
              HapticFeedback.lightImpact();
            } catch (_) {}
            onTapHeader!();
          };

    final VoidCallback? effectiveBlessingTap = onTapBlessing == null
        ? null
        : () {
            try {
              HapticFeedback.selectionClick();
            } catch (_) {}
            onTapBlessing!();
          };

    return GestureDetector(
      onTap: effectiveOnTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: effectiveHeight,
        margin: effectiveMargin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
              blurRadius: 22,
              spreadRadius: -2,
            ),
            BoxShadow(
              color: const Color(0xFFE5C158).withValues(alpha: 0.10),
              blurRadius: 14,
              spreadRadius: -4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // Layer 1: Celestial Twilight Citadel Vector Painting
                const CustomPaint(
                  painter: _CelestialRealmArtworkPainter(),
                ),

                // Layer 2: Obsidian glass vignette gradient overlay for depth & contrast
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Color(0x66060913),
                        Color(0x990A1024),
                        Color(0xF0050811),
                      ],
                      stops: <double>[0.0, 0.45, 1.0],
                    ),
                  ),
                ),

                // Layer 3: Luminous Border Frame with Specular Rim Highlight
                const CustomPaint(
                  painter: _HeaderLuminousBorderPainter(
                    borderRadius: 22,
                    borderGradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Color(0xCC00E5FF),
                        Color(0x99FFFFFF),
                        Color(0xCCE5C158),
                        Color(0x2600E5FF),
                      ],
                      stops: <double>[0.0, 0.3, 0.7, 1.0],
                    ),
                    borderWidth: 1.2,
                  ),
                ),

                // Layer 4: Content Layout
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16 + topPadding, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      // Top Row: Dominion Level & Active Blessing
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          // Dominion Rank Status Pill with Ether Cyan Glow
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xCC06101E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.65),
                                width: 1.1,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.28),
                                  blurRadius: 10,
                                  spreadRadius: 0.5,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF00E5FF),
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: const Color(0xFF00E5FF).withValues(alpha: 0.9),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Icon(
                                  Icons.star_rounded,
                                  size: 13,
                                  color: Color(0xFF00E5FF),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'HÂKİMİYET LV.$dominionLevel',
                                  style: const TextStyle(
                                    color: Color(0xFF00E5FF),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                    shadows: <Shadow>[
                                      Shadow(
                                        color: Color(0x9900E5FF),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Active Blessing Pill if present
                          if (activeBlessingSummary != null && activeBlessingSummary!.isNotEmpty)
                            Flexible(
                              child: GestureDetector(
                                onTap: effectiveBlessingTap,
                                child: Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xCC181307),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFE5C158).withValues(alpha: 0.75),
                                      width: 1.1,
                                    ),
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: const Color(0xFFE5C158).withValues(alpha: 0.35),
                                        blurRadius: 10,
                                        spreadRadius: 0.5,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFFE5C158),
                                          boxShadow: <BoxShadow>[
                                            BoxShadow(
                                              color: const Color(0xFFE5C158).withValues(alpha: 0.9),
                                              blurRadius: 6,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      const Icon(
                                        Icons.auto_awesome,
                                        size: 12,
                                        color: Color(0xFFE5C158),
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          activeBlessingSummary!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFFE5C158),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.3,
                                            shadows: <Shadow>[
                                              Shadow(
                                                color: Color(0x80E5C158),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),

                      // Bottom Row: Reigning Monarch Crest & Glowing Title Typography
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          // Monarch Crown Crest Badge with Celestial Gold Aura
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                colors: <Color>[
                                  Color(0xFF2B200E),
                                  Color(0xFF141926),
                                  Color(0xFF070B14),
                                ],
                                stops: <double>[0.0, 0.55, 1.0],
                              ),
                              border: Border.all(
                                color: const Color(0xFFE5C158),
                                width: 1.6,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: const Color(0xFFE5C158).withValues(alpha: 0.50),
                                  blurRadius: 16,
                                  spreadRadius: 1.5,
                                ),
                                BoxShadow(
                                  color: const Color(0xFFE5C158).withValues(alpha: 0.22),
                                  blurRadius: 28,
                                  spreadRadius: 4,
                                ),
                                BoxShadow(
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.20),
                                  blurRadius: 10,
                                  spreadRadius: -2,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: KingdomCrestIcon(
                                type: KingdomCrestType.crown,
                                size: 34,
                                primaryColor: Color(0xFFE5C158),
                                secondaryColor: Color(0xFFFFF2B2),
                                showGlow: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Realm & King Text with Luminescent Typography
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  realmTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFFBFDFF),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    shadows: <Shadow>[
                                      Shadow(
                                        color: Color(0xFFE5C158),
                                        blurRadius: 14,
                                      ),
                                      Shadow(
                                        color: Color(0x9900E5FF),
                                        blurRadius: 6,
                                      ),
                                      Shadow(
                                        color: Color(0xEE000000),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: <Widget>[
                                    Flexible(
                                      child: Text(
                                        reigningKing,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFFE5C158),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                          shadows: <Shadow>[
                                            Shadow(
                                              color: Color(0x80E5C158),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (reigningGuild.isNotEmpty) ...<Widget>[
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 3.5,
                                        height: 3.5,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFF00E5FF),
                                          boxShadow: <BoxShadow>[
                                            BoxShadow(
                                              color: const Color(0xFF00E5FF).withValues(alpha: 0.9),
                                              blurRadius: 4,
                                              spreadRadius: 0.5,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          reigningGuild,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.75),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (effectiveOnTap != null) ...<Widget>[
                            const SizedBox(width: 8),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0x59080E1B),
                                border: Border.all(
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                                  width: 1,
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: Color(0xFF00E5FF),
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}

/// Custom painter to draw high-definition luminous border gradients
/// with specular rim illumination for the obsidian-glass header.
class _HeaderLuminousBorderPainter extends CustomPainter {
  const _HeaderLuminousBorderPainter({
    required this.borderRadius,
    required this.borderGradient,
    this.borderWidth = 1.2,
  });

  final double borderRadius;
  final Gradient borderGradient;
  final double borderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(borderWidth / 2),
      Radius.circular(borderRadius - borderWidth / 2),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..shader = borderGradient.createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _HeaderLuminousBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.borderGradient != borderGradient;
  }
}

/// Custom painter for the twilight fantasy celestial background artwork.
class _CelestialRealmArtworkPainter extends CustomPainter {
  const _CelestialRealmArtworkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Deep cosmic twilight sky gradient
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF050813), // Deep obsidian void
          Color(0xFF0E1632), // Twilight sapphire
          Color(0xFF1B1233), // Aurora purple
          Color(0xFF080C1A), // Deep horizon
        ],
        stops: <double>[0.0, 0.4, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    // Aurora Borealis luminous ribbons with Ether Cyan and Celestial Gold accents
    final auroraPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        center: const Alignment(0.2, -0.4),
        radius: 0.9,
        colors: <Color>[
          const Color(0x4D00E5FF), // Ether Cyan luminous glow
          const Color(0x309B5CF6), // Mystic purple aurora
          const Color(0x1CE5C158), // Celestial Gold stardust shimmer
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), auroraPaint);

    // Glowing Star Clusters (deterministic pseudo-random positions with gold & cyan starlight)
    final starPaint = Paint();
    const starCount = 38;
    for (int i = 0; i < starCount; i++) {
      final sx = ((i * 37 + 13) % 100) / 100.0 * w;
      final sy = ((i * 59 + 7) % 70) / 100.0 * h;
      final radius = (i % 6 == 0) ? 1.8 : ((i % 3 == 0) ? 1.2 : 0.75);
      final alpha = 0.4 + (((i * 23) % 60) / 100.0);
      final Color starColor;
      if (i % 7 == 0) {
        starColor = const Color(0xFFE5C158); // Celestial gold star
      } else if (i % 5 == 0) {
        starColor = const Color(0xFF00E5FF); // Ether cyan star
      } else {
        starColor = Colors.white;
      }
      starPaint.color = starColor.withValues(alpha: alpha);
      canvas.drawCircle(Offset(sx, sy), radius, starPaint);
    }

    // Distant Floating Citadel Mountain Spires (Silhouette with rim illumination)
    final mountainsPath = Path();
    mountainsPath.moveTo(0, h);
    mountainsPath.lineTo(0, h * 0.65);
    mountainsPath.lineTo(w * 0.15, h * 0.52);
    mountainsPath.lineTo(w * 0.28, h * 0.60);
    mountainsPath.lineTo(w * 0.42, h * 0.42); // Central floating peak
    mountainsPath.lineTo(w * 0.48, h * 0.46);
    mountainsPath.lineTo(w * 0.62, h * 0.35); // Citadel tower spire
    mountainsPath.lineTo(w * 0.65, h * 0.38);
    mountainsPath.lineTo(w * 0.78, h * 0.55);
    mountainsPath.lineTo(w * 0.90, h * 0.48);
    mountainsPath.lineTo(w, h * 0.62);
    mountainsPath.lineTo(w, h);
    mountainsPath.close();

    final mountainPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0xFF1A2338).withValues(alpha: 0.75),
          const Color(0xFF0B101E).withValues(alpha: 0.98),
        ],
      ).createShader(Rect.fromLTWH(0, h * 0.35, w, h * 0.65));
    canvas.drawPath(mountainsPath, mountainPaint);

    // Mountain Rim Starlight Highlight with Ether Cyan & Celestial Gold illumination
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          Colors.transparent,
          const Color(0xFF00E5FF).withValues(alpha: 0.75), // Ether Cyan rim
          const Color(0xFFFFF2B2).withValues(alpha: 0.90), // Specular gold highlight
          const Color(0xFFE5C158).withValues(alpha: 0.70), // Celestial Gold rim
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.3, 0.55, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(mountainsPath, rimPaint);

    // Floating Citadel Spires on Peak (w * 0.62, h * 0.35)
    final spirePath = Path();
    spirePath.moveTo(w * 0.61, h * 0.36);
    spirePath.lineTo(w * 0.62, h * 0.28); // Scepter tower tip
    spirePath.lineTo(w * 0.63, h * 0.36);
    spirePath.close();

    final spirePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF00E5FF); // Ether Cyan spire
    canvas.drawPath(spirePath, spirePaint);

    // Scepter Tower Beacon Gem Glow with Celestial Gold Core & Ether Cyan Aura
    final beaconAuraPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.45);
    canvas.drawCircle(Offset(w * 0.62, h * 0.28), 5.5, beaconAuraPaint);

    final beaconPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFE5C158); // Celestial gold beacon core
    canvas.drawCircle(Offset(w * 0.62, h * 0.28), 2.5, beaconPaint);

    final beaconGlintPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    canvas.drawCircle(Offset(w * 0.62, h * 0.28), 1.2, beaconGlintPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
