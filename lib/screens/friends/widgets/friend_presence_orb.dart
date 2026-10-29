import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Presence status for 2027 Aion 2 Mobile social system (V3 AAA Cyber-Fantasy).
enum FriendPresenceStatus {
  online,
  inDungeon,
  inPvP,
  inParty,
  away,
  offline;

  /// Parses presence status from online flag and activity string.
  static FriendPresenceStatus fromOnline({
    required bool isOnline,
    String? activity,
  }) {
    if (!isOnline) return FriendPresenceStatus.offline;
    final String act = (activity ?? '').toLowerCase();
    if (act.contains('pvp') ||
        act.contains('arena') ||
        act.contains('düello') ||
        act.contains('duello') ||
        act.contains('savaş') ||
        act.contains('savas') ||
        act.contains('war') ||
        act.contains('battleground')) {
      return FriendPresenceStatus.inPvP;
    }
    if (act.contains('zindan') ||
        act.contains('dungeon') ||
        act.contains('boss') ||
        act.contains('raid') ||
        act.contains('inisyasyon')) {
      return FriendPresenceStatus.inDungeon;
    }
    if (act.contains('parti') ||
        act.contains('party') ||
        act.contains('grup') ||
        act.contains('team')) {
      return FriendPresenceStatus.inParty;
    }
    if (act.contains('away') ||
        act.contains('afk') ||
        act.contains('boşta') ||
        act.contains('bosta') ||
        act.contains('idle')) {
      return FriendPresenceStatus.away;
    }
    return FriendPresenceStatus.online;
  }

  /// Primary core color corresponding to AAA Cyber-Fantasy luxury theme.
  Color get primaryColor {
    switch (this) {
      case FriendPresenceStatus.online:
        return const Color(0xFF10B981); // Celestial Emerald
      case FriendPresenceStatus.inDungeon:
        return const Color(0xFF06B6D4); // Cyber Azure / Cyan
      case FriendPresenceStatus.inPvP:
        return const Color(0xFFEF4444); // Radiant Blood-Ruby Crimson
      case FriendPresenceStatus.inParty:
        return const Color(0xFF8B5CF6); // Mystic Amethyst Violet
      case FriendPresenceStatus.away:
        return const Color(0xFFF59E0B); // Solar Amber
      case FriendPresenceStatus.offline:
        return const Color(0xFF64748B); // Matte Titanium Slate
    }
  }

  /// High-radiance glow color for ambient halo & expanding energy ripple.
  Color get glowColor {
    switch (this) {
      case FriendPresenceStatus.online:
        return const Color(0xFF00E676); // High-radiance Emerald
      case FriendPresenceStatus.inDungeon:
        return const Color(0xFF00E5FF); // Neon Cyan Azure
      case FriendPresenceStatus.inPvP:
        return const Color(0xFFFF2A55); // Crimson Ruby Neon
      case FriendPresenceStatus.inParty:
        return const Color(0xFFA855F7); // Royal Purple Glow
      case FriendPresenceStatus.away:
        return const Color(0xFFFBBF24); // Warm Amber Glow
      case FriendPresenceStatus.offline:
        return const Color(0x00000000); // Inactive Dormant
    }
  }

  /// Highlight sheen color for 3D sphere gradient glint.
  Color get highlightColor {
    switch (this) {
      case FriendPresenceStatus.online:
        return const Color(0xFFA7F3D0); // Celestial Mint
      case FriendPresenceStatus.inDungeon:
        return const Color(0xFFA5F3FC); // Glacial White-Cyan
      case FriendPresenceStatus.inPvP:
        return const Color(0xFFFECDD3); // Rose Ruby Specular
      case FriendPresenceStatus.inParty:
        return const Color(0xFFDDD6FE); // Arcane Lilac
      case FriendPresenceStatus.away:
        return const Color(0xFFFEF3C7); // Pale Solar Gold
      case FriendPresenceStatus.offline:
        return const Color(0xFF94A3B8); // Brushed Silver-Titanium
    }
  }

  /// Deep ambient shadow color for 3D sphere volume depth.
  Color get darkColor {
    switch (this) {
      case FriendPresenceStatus.online:
        return const Color(0xFF047857); // Deep Forest Emerald
      case FriendPresenceStatus.inDungeon:
        return const Color(0xFF0369A1); // Deep Abyssal Azure
      case FriendPresenceStatus.inPvP:
        return const Color(0xFF991B1B); // Deep Imperial Ruby
      case FriendPresenceStatus.inParty:
        return const Color(0xFF5B21B6); // Deep Cosmic Shadow
      case FriendPresenceStatus.away:
        return const Color(0xFFB45309); // Deep Bronze Amber
      case FriendPresenceStatus.offline:
        return const Color(0xFF334155); // Forged Dark Titanium
    }
  }

  /// List of gradient colors from highlight to primary to dark shade.
  List<Color> get gradientColors => <Color>[
        highlightColor,
        primaryColor,
        darkColor,
      ];

  /// Localized Turkish presence label.
  String get label {
    switch (this) {
      case FriendPresenceStatus.online:
        return 'Çevrimiçi';
      case FriendPresenceStatus.inDungeon:
        return 'Zindanda';
      case FriendPresenceStatus.inPvP:
        return 'PvP / Arenada';
      case FriendPresenceStatus.inParty:
        return 'Partide';
      case FriendPresenceStatus.away:
        return 'Boşta';
      case FriendPresenceStatus.offline:
        return 'Çevrimdışı';
    }
  }

  /// Associated status icon for badges and micro-indicators.
  IconData get icon {
    switch (this) {
      case FriendPresenceStatus.online:
        return Icons.circle;
      case FriendPresenceStatus.inDungeon:
        return Icons.local_fire_department_rounded;
      case FriendPresenceStatus.inPvP:
        return Icons.sports_martial_arts_rounded;
      case FriendPresenceStatus.inParty:
        return Icons.groups_rounded;
      case FriendPresenceStatus.away:
        return Icons.hourglass_empty_rounded;
      case FriendPresenceStatus.offline:
        return Icons.circle_outlined;
    }
  }

  /// Whether the user is considered online.
  bool get isOnline => this != FriendPresenceStatus.offline;

  /// Whether this presence status features an active pulsating aura.
  bool get hasPulsingAura => this != FriendPresenceStatus.offline;
}

/// 2027 Aion 2 Mobile V3 AAA Pulsing Presence Orb with breathing ambient aura,
/// multi-stop radial specular core, and zero-jank RepaintBoundary isolation.
class FriendPresenceOrb extends StatefulWidget {
  const FriendPresenceOrb({
    super.key,
    required this.status,
    this.size = 14.0,
    this.showAura = true,
    this.showCoreGleam = true,
    this.tooltip,
    this.onTap,
  });

  final FriendPresenceStatus status;
  final double size;
  final bool showAura;
  final bool showCoreGleam;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  State<FriendPresenceOrb> createState() => _FriendPresenceOrbState();
}

class _FriendPresenceOrbState extends State<FriendPresenceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _rippleScaleAnimation;
  late final Animation<double> _rippleAlphaAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _rippleScaleAnimation = Tween<double>(begin: 1.0, end: 2.15).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeOutCubic,
      ),
    );

    _rippleAlphaAnimation = Tween<double>(begin: 0.65, end: 0.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeOutCubic,
      ),
    );

    if (widget.status.hasPulsingAura) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(FriendPresenceOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.status.hasPulsingAura) {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
      }
    } else {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FriendPresenceStatus status = widget.status;
    final bool isOffline = !status.hasPulsingAura;
    final double size = widget.size;

    final Widget coreOrb = _buildCoreOrb(status, size);

    Widget orbContent;
    if (isOffline || !widget.showAura) {
      orbContent = SizedBox(
        width: size,
        height: size,
        child: Center(child: coreOrb),
      );
    } else {
      orbContent = RepaintBoundary(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: <Widget>[
              // Pulsing Aura & Ripple Layers
              AnimatedBuilder(
                animation: _pulseController,
                builder: (BuildContext context, Widget? child) {
                  final double t = _pulseController.value;
                  // Smooth sinusoidal breathing factor (0.0 to 1.0)
                  final double breath = (math.sin(t * 2.0 * math.pi) + 1.0) / 2.0;
                  final double rippleScale = _rippleScaleAnimation.value;
                  final double rippleAlpha = _rippleAlphaAnimation.value;
                  final Color glowColor = status.glowColor;

                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      // Outer expanding ripple wave
                      Transform.scale(
                        scale: rippleScale,
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: glowColor.withValues(
                              alpha: rippleAlpha * 0.25,
                            ),
                            border: Border.all(
                              color: glowColor.withValues(
                                alpha: rippleAlpha * 0.50,
                              ),
                              width: math.max(0.75, size * 0.08),
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: glowColor.withValues(
                                  alpha: rippleAlpha * 0.35,
                                ),
                                blurRadius: size * 0.40,
                                spreadRadius: 0.5,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Inner soft breathing ambient aura
                      Container(
                        width: size * (1.15 + breath * 0.20),
                        height: size * (1.15 + breath * 0.20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: glowColor.withValues(
                                alpha: 0.30 + breath * 0.35,
                              ),
                              blurRadius: size * 0.75,
                              spreadRadius: size * 0.18,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              // Solid Core Gem Orb
              coreOrb,
            ],
          ),
        ),
      );
    }

    if (widget.tooltip != null) {
      orbContent = Tooltip(
        message: widget.tooltip!,
        child: orbContent,
      );
    }

    if (widget.onTap != null) {
      orbContent = GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: orbContent,
      );
    }

    return orbContent;
  }

  Widget _buildCoreOrb(FriendPresenceStatus status, double size) {
    final bool isOffline = !status.hasPulsingAura;
    final Color primary = status.primaryColor;
    final Color highlight = status.highlightColor;
    final Color dark = status.darkColor;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Multi-stop radial gradient for 3D sphere volume
        gradient: isOffline
            ? RadialGradient(
                center: const Alignment(-0.35, -0.40),
                radius: 0.85,
                colors: <Color>[
                  highlight.withValues(alpha: 0.85),
                  primary,
                  dark,
                ],
                stops: const <double>[0.0, 0.45, 1.0],
              )
            : RadialGradient(
                center: const Alignment(-0.35, -0.40),
                radius: 0.90,
                colors: <Color>[
                  highlight,
                  primary,
                  dark,
                ],
                stops: const <double>[0.0, 0.50, 1.0],
              ),
        border: Border.all(
          color: isOffline
              ? const Color(0xFF1E293B)
              : const Color(0xFF070B14),
          width: math.max(1.5, size * 0.14),
        ),
        boxShadow: <BoxShadow>[
          // Dark rim drop shadow for visual separation against avatars
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 3.0,
            spreadRadius: 0.5,
          ),
          if (!isOffline)
            BoxShadow(
              color: status.glowColor.withValues(alpha: 0.60),
              blurRadius: math.max(4.0, size * 0.45),
              spreadRadius: 0.5,
            ),
        ],
      ),
      child: widget.showCoreGleam
          ? Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // Micro specular glint reflection on top-left of the glass gem
                Positioned(
                  top: math.max(1.5, size * 0.18),
                  left: math.max(1.5, size * 0.20),
                  child: Container(
                    width: math.max(2.0, size * 0.24),
                    height: math.max(1.5, size * 0.15),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: isOffline ? 0.35 : 0.75,
                      ),
                      borderRadius: BorderRadius.all(
                        Radius.elliptical(
                          math.max(2.0, size * 0.24),
                          math.max(1.5, size * 0.15),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : null,
    );
  }
}

/// Convenience companion badge displaying a FriendPresenceOrb and its label.
class FriendPresenceBadge extends StatelessWidget {
  const FriendPresenceBadge({
    super.key,
    required this.status,
    this.orbSize = 10.0,
    this.textStyle,
    this.showAura = true,
  });

  final FriendPresenceStatus status;
  final double orbSize;
  final TextStyle? textStyle;
  final bool showAura;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: const Color(0xFF090D1A).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: status.primaryColor.withValues(alpha: 0.30),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FriendPresenceOrb(
            status: status,
            size: orbSize,
            showAura: showAura,
          ),
          const SizedBox(width: 6.0),
          Text(
            status.label,
            style: textStyle ??
                TextStyle(
                  color: status.isOnline
                      ? Colors.white
                      : const Color(0xFF94A3B8),
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
          ),
        ],
      ),
    );
  }
}
