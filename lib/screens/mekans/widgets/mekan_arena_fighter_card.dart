import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../providers/mekan_provider.dart';
import 'mekan_design.dart';
import 'mekan_theme.dart';

/// Character archetype presets deterministically wired to real game character assets.
enum FighterArchetype {
  warrior(
    title: 'Gladyatör Savaşçı',
    assetPath: 'assets/characters/savasci.png',
    accentColor: MekanPalette.ruby,
    secondaryColor: MekanPalette.coral,
    icon: Icons.shield_rounded,
  ),
  shadow(
    title: 'Gölge Suikastçı',
    assetPath: 'assets/characters/golge.png',
    accentColor: MekanPalette.amethyst,
    secondaryColor: MekanPalette.fuchsia,
    icon: Icons.auto_awesome_rounded,
  ),
  alchemist(
    title: 'Arkana Simyacı',
    assetPath: 'assets/characters/simyaci.png',
    accentColor: MekanPalette.aqua,
    secondaryColor: MekanPalette.cyan,
    icon: Icons.local_fire_department_rounded,
  );

  const FighterArchetype({
    required this.title,
    required this.assetPath,
    required this.accentColor,
    required this.secondaryColor,
    required this.icon,
  });

  final String title;
  final String assetPath;
  final Color accentColor;
  final Color secondaryColor;
  final IconData icon;

  static FighterArchetype fromOpponent(ArenaOpponent opponent) {
    final String seed = '${opponent.authId}_${opponent.username}_${opponent.level}';
    final int hash = seed.hashCode.abs();
    return FighterArchetype.values[hash % FighterArchetype.values.length];
  }
}

/// Dynamic rank tier metadata for crest iconography, gradients, and threat evaluation.
class FighterRankTier {
  const FighterRankTier({
    required this.tierName,
    required this.crestColor,
    required this.crestIcon,
    required this.gradient,
    required this.threatLabel,
    required this.threatColor,
  });

  final String tierName;
  final Color crestColor;
  final IconData crestIcon;
  final LinearGradient gradient;
  final String threatLabel;
  final Color threatColor;

  static FighterRankTier evaluate(int rating, int power) {
    if (rating >= 1800 || power >= 3500) {
      return const FighterRankTier(
        tierName: 'Efsanevi Gladyatör',
        crestColor: MekanPalette.gold,
        crestIcon: Icons.military_tech_rounded,
        gradient: MekanPalette.goldGrad,
        threatLabel: 'ÖLÜMCÜL',
        threatColor: MekanPalette.ruby,
      );
    } else if (rating >= 1500 || power >= 2200) {
      return const FighterRankTier(
        tierName: 'Usta Dövüşçü',
        crestColor: MekanPalette.amethyst,
        crestIcon: Icons.workspace_premium_rounded,
        gradient: MekanPalette.amethystGrad,
        threatLabel: 'YÜKSEK',
        threatColor: MekanPalette.coral,
      );
    } else if (rating >= 1200 || power >= 1200) {
      return const FighterRankTier(
        tierName: 'Kıdemli Gladyatör',
        crestColor: MekanPalette.aqua,
        crestIcon: Icons.shield_rounded,
        gradient: MekanPalette.aquaGrad,
        threatLabel: 'DENGELİ',
        threatColor: MekanPalette.aqua,
      );
    } else {
      return const FighterRankTier(
        tierName: 'Meydan Okuyan',
        crestColor: MekanPalette.neon,
        crestIcon: Icons.sports_mma_rounded,
        gradient: MekanPalette.neonGrad,
        threatLabel: 'KOLAY',
        threatColor: MekanPalette.neon,
      );
    }
  }
}

/// Next-Gen Aion 2 Luxury Fighter Card for Mekan PvP Arena.
///
/// Features:
/// - Frosted glassmorphism container with backdrop blur & specular highlights.
/// - Holographic fighter portrait with scanline glint and chromatic edge aura.
/// - Dynamic character archetype asset wiring (`savasci.png`, `golge.png`, `simyaci.png`).
/// - Glowing power / combat threat progress bar with normalized gradient fill.
/// - Animated rank crest with subtle breathe/pulse effect (isolated in RepaintBoundary).
/// - Tactile scale & haptic response on interaction.
/// - Defensive null and empty value fallbacks for resilient production stability.
class MekanArenaFighterCard extends StatefulWidget {
  const MekanArenaFighterCard({
    super.key,
    required this.opponent,
    required this.enabled,
    required this.onFight,
    this.onTapCard,
    this.showPowerBar = true,
  });

  final ArenaOpponent opponent;
  final bool enabled;
  final VoidCallback onFight;
  final VoidCallback? onTapCard;
  final bool showPowerBar;

  @override
  State<MekanArenaFighterCard> createState() => _MekanArenaFighterCardState();
}

class _MekanArenaFighterCardState extends State<MekanArenaFighterCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breatheController;
  late final Animation<double> _breatheAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _breatheAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  String get _safeUsername {
    final String raw = widget.opponent.username.trim();
    return raw.isNotEmpty ? raw : 'Bilinmeyen Savaşçı';
  }

  int get _safeLevel {
    return widget.opponent.level > 0 ? widget.opponent.level : 1;
  }

  int get _safeRating {
    return widget.opponent.pvpRating > 0 ? widget.opponent.pvpRating : 1000;
  }

  int get _safePower {
    if (widget.opponent.power > 0) return widget.opponent.power;
    return (_safeLevel * 120) + (_safeRating ~/ 2);
  }

  bool get _isFightable => widget.enabled && widget.opponent.offerId.isNotEmpty;

  String _formatPower(int power) {
    if (power >= 1000000) return '${(power / 1000000).toStringAsFixed(1)}M';
    if (power >= 1000) return '${(power / 1000).toStringAsFixed(1)}K';
    return '$power';
  }

  void _triggerHaptic() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final FighterArchetype archetype = FighterArchetype.fromOpponent(widget.opponent);
    final FighterRankTier tier = FighterRankTier.evaluate(_safeRating, _safePower);
    final bool canFight = _isFightable;

    return Semantics(
      button: true,
      enabled: canFight,
      label: '$_safeUsername, Seviye $_safeLevel, Puan $_safeRating, Savaş Gücü $_safePower. Dövüş teklifi.',
      child: GestureDetector(
        onTapDown: canFight ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: canFight ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: canFight ? () => setState(() => _isPressed = false) : null,
        onTap: () {
          if (canFight) {
            _triggerHaptic();
            if (widget.onTapCard != null) {
              widget.onTapCard!();
            } else {
              widget.onFight();
            }
          }
        },
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MekanPalette.radiusLg),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: archetype.accentColor.withValues(
                    alpha: canFight ? (_isPressed ? 0.35 : 0.22) : 0.08,
                  ),
                  blurRadius: _isPressed ? 28 : 20,
                  offset: const Offset(0, 6),
                  spreadRadius: _isPressed ? 1 : -2,
                ),
                BoxShadow(
                  color: MekanPalette.void_.withValues(alpha: 0.85),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(MekanPalette.radiusLg),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: MekanPalette.blurMd,
                  sigmaY: MekanPalette.blurMd,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(MekanPalette.radiusLg),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        MekanPalette.surfaceHi.withValues(alpha: 0.88),
                        MekanPalette.navy.withValues(alpha: 0.92),
                        MekanPalette.void_.withValues(alpha: 0.96),
                      ],
                      stops: const <double>[0.0, 0.45, 1.0],
                    ),
                    border: Border.all(
                      color: canFight
                          ? archetype.accentColor.withValues(
                              alpha: _isPressed ? 0.85 : 0.45,
                            )
                          : Colors.white.withValues(alpha: 0.12),
                      width: _isPressed ? 1.6 : 1.2,
                    ),
                  ),
                  child: Stack(
                    children: <Widget>[
                      // Specular top highlight (polished crystal shine)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 28,
                        child: IgnorePointer(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: MekanPalette.specularHighlightGrad,
                            ),
                          ),
                        ),
                      ),
                      // Holographic corner bracket runes
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _AionCardHoloPainter(
                              accent: archetype.accentColor,
                              isActive: canFight,
                            ),
                          ),
                        ),
                      ),
                      // Card Content
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            // Top Row: Portrait + Details + CTA
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                _buildHolographicPortrait(archetype, tier),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildFighterDetails(archetype, tier),
                                ),
                                const SizedBox(width: 8),
                                _buildActionCTA(canFight, tier),
                              ],
                            ),
                            // Bottom Row: Power / Health Bar
                            if (widget.showPowerBar) ...<Widget>[
                              const SizedBox(height: 10),
                              _buildPowerBar(archetype, tier),
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
        ),
      ),
    );
  }

  Widget _buildHolographicPortrait(
    FighterArchetype archetype,
    FighterRankTier tier,
  ) {
    const double size = 56.0;
    final BorderRadius br = BorderRadius.circular(14);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _breatheAnimation,
        builder: (BuildContext context, Widget? child) {
          final double breathe = _breatheAnimation.value;
          return SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                // Glow Aura Behind Portrait
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: br,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: archetype.accentColor.withValues(
                            alpha: (0.35 * breathe).clamp(0.0, 1.0),
                          ),
                          blurRadius: 14 * breathe,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                ),
                // Portrait Glass Frame
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: br,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.85,
                          colors: <Color>[
                            archetype.accentColor.withValues(alpha: 0.28),
                            MekanPalette.navy.withValues(alpha: 0.85),
                            MekanPalette.void_,
                          ],
                        ),
                        border: Border.all(
                          color: archetype.accentColor.withValues(
                            alpha: (0.55 * breathe).clamp(0.0, 1.0),
                          ),
                          width: 1.4,
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          // Actual Character Image Asset with Fallback Monogram
                          Image.asset(
                            archetype.assetPath,
                            fit: BoxFit.cover,
                            errorBuilder: (
                              BuildContext ctx,
                              Object err,
                              StackTrace? stack,
                            ) {
                              return Center(
                                child: Text(
                                  _safeUsername.isNotEmpty
                                      ? _safeUsername[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: archetype.accentColor,
                                    shadows: <Shadow>[
                                      Shadow(
                                        color: archetype.accentColor.withValues(
                                          alpha: 0.8,
                                        ),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          // Holographic diagonal shimmer glint
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: <Color>[
                                    Colors.white.withValues(alpha: 0.18),
                                    Colors.transparent,
                                    archetype.secondaryColor.withValues(
                                      alpha: 0.12,
                                    ),
                                    Colors.transparent,
                                  ],
                                  stops: const <double>[0.0, 0.35, 0.65, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Rank Crest Badge Overlay (Bottom-Right)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: tier.gradient,
                      border: Border.all(
                        color: MekanPalette.void_,
                        width: 1.5,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: tier.crestColor.withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      tier.crestIcon,
                      size: 11,
                      color: const Color(0xFF1A1202),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFighterDetails(
    FighterArchetype archetype,
    FighterRankTier tier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Name & Class Icon Row
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                _safeUsername,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: MekanPalette.textHi,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        // Archetype / Title subtitle
        Row(
          children: <Widget>[
            Icon(archetype.icon, size: 12, color: archetype.accentColor),
            const SizedBox(width: 4),
            Text(
              archetype.title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: archetype.accentColor.withValues(alpha: 0.9),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Level Chip & Rating Chip
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildBadgeChip(
              icon: Icons.shield_rounded,
              label: 'Sv $_safeLevel',
              accent: MekanPalette.aqua,
            ),
            const SizedBox(width: 6),
            _buildBadgeChip(
              icon: Icons.emoji_events_rounded,
              label: '$_safeRating',
              accent: MekanPalette.gold,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBadgeChip({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent.withValues(alpha: 0.40),
          width: 0.9,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: accent),
          const SizedBox(width: 3.5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: accent,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCTA(bool canFight, FighterRankTier tier) {
    if (!canFight) {
      return Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: MekanPalette.obsidian.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.lock_outline_rounded,
              size: 14,
              color: MekanPalette.textLow,
            ),
            SizedBox(width: 5),
            Text(
              'Kilitli',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MekanPalette.textLow,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: MekanPalette.ruby.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 3),
            spreadRadius: -1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            _triggerHaptic();
            widget.onFight();
          },
          child: Ink(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: MekanPalette.rubyGrad,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.0,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.sports_mma_rounded,
                  size: 15,
                  color: Color(0xFF240004),
                ),
                SizedBox(width: 5),
                Text(
                  'Dövüş',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF240004),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPowerBar(
    FighterArchetype archetype,
    FighterRankTier tier,
  ) {
    // Relative power calculation (normalized against 4000 rating cap for visual progression)
    final double powerProgress = (_safePower / 4000.0).clamp(0.08, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: MekanPalette.void_.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 0.8,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Header info: Label + Numeric Value + Threat Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Icon(
                    Icons.bolt_rounded,
                    size: 12,
                    color: MekanPalette.solar,
                  ),
                  SizedBox(width: 3),
                  Text(
                    'SAVAŞ GÜCÜ',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: MekanPalette.textLow,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Row(
                children: <Widget>[
                  Text(
                    _formatPower(_safePower),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: MekanPalette.textHi,
                      fontFeatures: <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: tier.threatColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: tier.threatColor.withValues(alpha: 0.50),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      tier.threatLabel,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: tier.threatColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Glow Progress Bar Track
          SizedBox(
            height: 5,
            child: Stack(
              children: <Widget>[
                // Track Background
                Container(
                  decoration: BoxDecoration(
                    color: MekanPalette.obsidian.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                // Glowing Value Fill
                FractionallySizedBox(
                  widthFactor: powerProgress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          archetype.accentColor,
                          tier.crestColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: tier.crestColor.withValues(alpha: 0.55),
                          blurRadius: 6,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AionCardHoloPainter extends CustomPainter {
  const _AionCardHoloPainter({
    required this.accent,
    required this.isActive,
  });

  final Color accent;
  final bool isActive;

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    final Paint cornerPaint = Paint()
      ..color = accent.withValues(alpha: 0.22)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double arm = 7.0;

    // Top-left corner bracket
    canvas.drawLine(const Offset(4, 4), const Offset(4 + arm, 4), cornerPaint);
    canvas.drawLine(const Offset(4, 4), const Offset(4, 4 + arm), cornerPaint);

    // Top-right corner bracket
    canvas.drawLine(
      Offset(size.width - 4, 4),
      Offset(size.width - 4 - arm, 4),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width - 4, 4),
      Offset(size.width - 4, 4 + arm),
      cornerPaint,
    );

    // Bottom-left corner bracket
    canvas.drawLine(
      Offset(4, size.height - 4),
      Offset(4 + arm, size.height - 4),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(4, size.height - 4),
      Offset(4, size.height - 4 - arm),
      cornerPaint,
    );

    // Bottom-right corner bracket
    canvas.drawLine(
      Offset(size.width - 4, size.height - 4),
      Offset(size.width - 4 - arm, size.height - 4),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width - 4, size.height - 4),
      Offset(size.width - 4, size.height - 4 - arm),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AionCardHoloPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.isActive != isActive;
}

