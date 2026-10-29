import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import 'staff_badge.dart';

/// 2027 Aion 2 Mobile Next-Gen Obsidian-Glass Floating Nameplate & Identity Label.
///
/// Features:
/// - Frosted obsidian glass backing with specular highlight rims and blur
/// - Guild crest and title integration with Celestial Gold (#E5C158) / Ether Cyan (#00E5FF) luminescence
/// - High-legibility typography with dual drop shadow for clear visibility against 3D game worlds
/// - Device SafeArea and MediaQuery insets protection
/// - Tactile HapticFeedback on nameplate tap / inspect with micro-press physics
/// - Semantics & accessibility integration
/// - 100% backward-compatible API preserving all existing constructor params & business logic
class PlayerNameLabel extends StatefulWidget {
  const PlayerNameLabel({
    super.key,
    required this.username,
    this.displayName,
    this.staffBadge,
    this.kingBadge,
    this.titlePrefix,
    this.style,
    this.showUsername = true,
    this.compactBadge = false,
    this.isOnline,
    this.enableGlow = true,
    this.onTap,
    this.onLongPress,
    // 2027 Aion 2 Obsidian-Glass & Guild Additions
    this.guildName,
    this.guildRole,
    this.guildCrest,
    this.guildCrestIcon,
    this.level,
    this.floatingPlate = false,
    this.showBacking = true,
    this.enableBlur,
    this.enableSafeArea,
    this.luminescenceColor,
    this.onInspect,
    this.padding,
    this.maxWidth,
  });

  /// Dedicated named constructor for overhead 3D world floating nameplates.
  const PlayerNameLabel.floating({
    super.key,
    required this.username,
    this.displayName,
    this.staffBadge,
    this.kingBadge,
    this.titlePrefix,
    this.style,
    this.showUsername = true,
    this.compactBadge = false,
    this.isOnline,
    this.enableGlow = true,
    this.onTap,
    this.onLongPress,
    this.guildName,
    this.guildRole,
    this.guildCrest,
    this.guildCrestIcon,
    this.level,
    this.floatingPlate = true,
    this.showBacking = true,
    this.enableBlur = true,
    this.enableSafeArea = true,
    this.luminescenceColor,
    this.onInspect,
    this.padding,
    this.maxWidth = 320.0,
  });

  // ──────────────────────────── Design Tokens ──────────────────────────────
  /// Aion 2 Celestial Gold Luminescence (#E5C158)
  static const Color celestialGold = Color(0xFFE5C158);

  /// Aion 2 Ether Cyan Luminescence (#00E5FF)
  static const Color etherCyan = Color(0xFF00E5FF);

  /// Deep obsidian glass void base
  static const Color obsidianVoid = Color(0xFF07090E);

  /// Translucent frosted obsidian glass body
  static const Color obsidianGlass = Color(0xCC090D16);

  /// Elevated obsidian highlight surface
  static const Color obsidianSurface = Color(0xFF141B2A);

  /// Obsidian glass border specular rim
  static const Color obsidianBorder = Color(0x335B8FFF);

  // ──────────────────────────── Properties ──────────────────────────────────
  final String username;
  final String? displayName;
  final String? staffBadge;
  final String? kingBadge;
  final String? titlePrefix;
  final TextStyle? style;
  final bool showUsername;
  final bool compactBadge;
  final bool? isOnline;
  final bool enableGlow;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  // Next-Gen Aion 2 features
  final String? guildName;
  final String? guildRole;
  final Widget? guildCrest;
  final IconData? guildCrestIcon;
  final int? level;
  final bool floatingPlate;
  final bool showBacking;
  final bool? enableBlur;
  final bool? enableSafeArea;
  final Color? luminescenceColor;
  final VoidCallback? onInspect;
  final EdgeInsetsGeometry? padding;
  final double? maxWidth;

  @override
  State<PlayerNameLabel> createState() => _PlayerNameLabelState();
}

class _PlayerNameLabelState extends State<PlayerNameLabel> {
  bool _pressed = false;

  String get _primary {
    if (widget.displayName != null && widget.displayName!.trim().isNotEmpty) {
      return widget.displayName!.trim();
    }
    return widget.username;
  }

  /// Calculates dynamic luminescence color harmonized with Celestial Gold & Ether Cyan.
  Color get _luminescenceColor {
    if (widget.luminescenceColor != null) {
      return widget.luminescenceColor!;
    }
    final String? k = widget.kingBadge?.toLowerCase();
    final String? s = widget.staffBadge?.toLowerCase();

    if (k != null && (k.contains('king') || k.contains('kral') || k.contains('sovereign'))) {
      return PlayerNameLabel.celestialGold;
    }
    if (s != null) {
      if (s.contains('admin')) {
        return const Color(0xFFFFD700);
      }
      if (s.contains('gm') || s.contains('gamemaster')) {
        return AppColors.toxicNeon;
      }
      if (s.contains('general') || s.contains('abyss')) {
        return const Color(0xFFFF1744);
      }
      if (s.contains('vip')) {
        return const Color(0xFFE040FB);
      }
    }
    if (widget.guildName != null && widget.guildName!.isNotEmpty) {
      return PlayerNameLabel.etherCyan;
    }
    return PlayerNameLabel.celestialGold;
  }

  Color? get _prestigeGlowColor {
    if (!widget.enableGlow) return null;
    final String? k = widget.kingBadge?.toLowerCase();
    final String? s = widget.staffBadge?.toLowerCase();
    if (k != null && (k.contains('king') || k.contains('kral'))) {
      return PlayerNameLabel.celestialGold.withValues(alpha: 0.65);
    }
    if (s != null) {
      if (s.contains('admin')) {
        return const Color(0xFFFFD700).withValues(alpha: 0.6);
      }
      if (s.contains('gm')) {
        return AppColors.toxicNeon.withValues(alpha: 0.55);
      }
      if (s.contains('general')) {
        return const Color(0xFFFF1744).withValues(alpha: 0.6);
      }
      if (s.contains('vip')) {
        return const Color(0xFFE040FB).withValues(alpha: 0.6);
      }
    }
    return null;
  }

  /// High-legibility shadows guaranteeing visibility against bright skies and dark dungeons.
  List<Shadow> _buildHighLegibilityShadows(Color? glow) {
    return <Shadow>[
      // Deep ambient drop shadow for 3D world separation
      const Shadow(
        color: Color(0xDD000000),
        offset: Offset(0, 1.8),
        blurRadius: 3.5,
      ),
      // Sharp occlusion rim for edge definition
      const Shadow(
        color: Color(0xFF030508),
        offset: Offset(0, 0.6),
        blurRadius: 1.0,
      ),
      // Luminescence halo
      if (glow != null && widget.enableGlow) ...<Shadow>[
        Shadow(
          color: glow,
          blurRadius: 8.0,
        ),
        Shadow(
          color: glow.withValues(alpha: 0.35),
          blurRadius: 16.0,
        ),
      ],
    ];
  }

  Widget _buildGuildCrest(Color lumColor) {
    if (widget.guildCrest != null) {
      return Padding(
        padding: const EdgeInsets.only(right: 4.5),
        child: widget.guildCrest!,
      );
    }
    if (widget.guildCrestIcon != null) {
      return Padding(
        padding: const EdgeInsets.only(right: 4.5),
        child: Icon(
          widget.guildCrestIcon,
          size: widget.compactBadge ? 11 : 13,
          color: lumColor,
        ),
      );
    }
    // Procedural Aion 2 Guild Crest Emblem
    return Padding(
      padding: const EdgeInsets.only(right: 4.5),
      child: CustomPaint(
        size: Size(widget.compactBadge ? 11 : 13, widget.compactBadge ? 11 : 13),
        painter: _AionGuildCrestPainter(
          primaryColor: lumColor,
          glowColor: PlayerNameLabel.etherCyan,
        ),
      ),
    );
  }

  Widget _buildLevelBadge(Color lumColor) {
    if (widget.level == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(right: 4.5),
      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 0.8),
      decoration: BoxDecoration(
        color: const Color(0xE6080C16),
        borderRadius: BorderRadius.circular(3.5),
        border: Border.all(
          color: PlayerNameLabel.celestialGold.withValues(alpha: 0.75),
          width: 0.75,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: PlayerNameLabel.celestialGold.withValues(alpha: 0.25),
            blurRadius: 3.5,
          ),
          const BoxShadow(
            color: Color(0x80000000),
            offset: Offset(0, 1),
            blurRadius: 1.5,
          ),
        ],
      ),
      child: Text(
        'Lv.${widget.level}',
        style: GoogleFonts.cinzel(
          fontSize: widget.compactBadge ? 8.5 : 9.5,
          fontWeight: FontWeight.w800,
          color: PlayerNameLabel.celestialGold,
          letterSpacing: 0.2,
          shadows: const <Shadow>[
            Shadow(
              color: Color(0xCC000000),
              offset: Offset(0, 1),
              blurRadius: 1.5,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineIndicator() {
    if (widget.isOnline == null) return const SizedBox.shrink();
    final bool online = widget.isOnline!;
    return Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.only(right: 5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: online
            ? AppColors.toxicNeon
            : AppColors.mutedTitanium.withValues(alpha: 0.4),
        boxShadow: online
            ? <BoxShadow>[
                BoxShadow(
                  color: AppColors.toxicNeon.withValues(alpha: 0.85),
                  blurRadius: 4.5,
                  spreadRadius: 1.0,
                ),
                BoxShadow(
                  color: PlayerNameLabel.etherCyan.withValues(alpha: 0.45),
                  blurRadius: 8.0,
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildTitleBadge(Color lumColor) {
    if (widget.titlePrefix == null || widget.titlePrefix!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(right: 5),
      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.2),
      decoration: BoxDecoration(
        color: const Color(0xE6101626),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: lumColor.withValues(alpha: 0.65),
          width: 0.85,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: lumColor.withValues(alpha: 0.25),
            blurRadius: 4.0,
            spreadRadius: 0.2,
          ),
          const BoxShadow(
            color: Color(0x80000000),
            offset: Offset(0, 1),
            blurRadius: 2.0,
          ),
        ],
      ),
      child: Text(
        widget.titlePrefix!,
        style: GoogleFonts.cinzel(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: lumColor == PlayerNameLabel.celestialGold
              ? const Color(0xFFFDE68A)
              : const Color(0xFF90CAF9),
          shadows: const <Shadow>[
            Shadow(
              color: Color(0xCC000000),
              offset: Offset(0, 1),
              blurRadius: 1.5,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuildBadge(Color lumColor) {
    if (widget.guildName == null || widget.guildName!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildGuildCrest(lumColor),
          Text(
            '<${widget.guildName}>',
            style: GoogleFonts.cinzel(
              fontSize: widget.compactBadge ? 9.5 : 10.5,
              fontWeight: FontWeight.w700,
              color: PlayerNameLabel.etherCyan,
              letterSpacing: 0.3,
              shadows: <Shadow>[
                Shadow(
                  color: PlayerNameLabel.etherCyan.withValues(alpha: 0.55),
                  blurRadius: 6,
                ),
                const Shadow(
                  color: Color(0xDD000000),
                  offset: Offset(0, 1.2),
                  blurRadius: 2.5,
                ),
              ],
            ),
          ),
          if (widget.guildRole != null && widget.guildRole!.isNotEmpty) ...<Widget>[
            Text(
              ' • ${widget.guildRole}',
              style: GoogleFonts.cinzel(
                fontSize: widget.compactBadge ? 8.5 : 9.5,
                fontWeight: FontWeight.w600,
                color: PlayerNameLabel.celestialGold.withValues(alpha: 0.85),
                letterSpacing: 0.2,
                shadows: const <Shadow>[
                  Shadow(
                    color: Color(0xAA000000),
                    offset: Offset(0, 1),
                    blurRadius: 1.5,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainWrap({
    required TextStyle finalStyle,
    required TextStyle baseStyle,
    required Color lumColor,
  }) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        // Online status beacon
        if (widget.isOnline != null) _buildOnlineIndicator(),

        // Guild Crest & Name (inline mode)
        if (!widget.floatingPlate &&
            widget.guildName != null &&
            widget.guildName!.isNotEmpty)
          _buildGuildBadge(lumColor),

        // Daeva Level
        if (widget.level != null) _buildLevelBadge(lumColor),

        // Title Prefix
        if (widget.titlePrefix != null && widget.titlePrefix!.isNotEmpty)
          _buildTitleBadge(lumColor),

        // Primary Name with high-legibility shadows
        Text(
          _primary,
          style: finalStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        // Badges
        StaffBadge(badge: widget.staffBadge, compact: widget.compactBadge),
        StaffBadge(badge: widget.kingBadge, compact: widget.compactBadge),

        // Username handle
        if (widget.showUsername &&
            widget.displayName != null &&
            widget.displayName!.trim().isNotEmpty)
          Text(
            ' @${widget.username}',
            style: baseStyle.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: (baseStyle.fontSize ?? 14) - 1,
              color: baseStyle.color?.withValues(alpha: 0.65),
              shadows: const <Shadow>[
                Shadow(
                  color: Color(0xAA000000),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFloatingPlateLayout({
    required TextStyle finalStyle,
    required TextStyle baseStyle,
    required Color lumColor,
  }) {
    final bool hasTopTier = (widget.guildName != null && widget.guildName!.isNotEmpty) ||
        (widget.titlePrefix != null && widget.titlePrefix!.isNotEmpty) ||
        widget.level != null;

    if (!hasTopTier) {
      return _buildMainWrap(
        finalStyle: finalStyle,
        baseStyle: baseStyle,
        lumColor: lumColor,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // Tier 1: Guild & Title & Level Banner
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: <Widget>[
            if (widget.guildName != null && widget.guildName!.isNotEmpty)
              _buildGuildBadge(lumColor),
            if (widget.level != null) _buildLevelBadge(lumColor),
            if (widget.titlePrefix != null && widget.titlePrefix!.isNotEmpty)
              _buildTitleBadge(lumColor),
          ],
        ),
        const SizedBox(height: 2.5),
        // Tier 2: Player Identity & Badges
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: <Widget>[
            if (widget.isOnline != null) _buildOnlineIndicator(),
            Text(
              _primary,
              style: finalStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            StaffBadge(badge: widget.staffBadge, compact: widget.compactBadge),
            StaffBadge(badge: widget.kingBadge, compact: widget.compactBadge),
            if (widget.showUsername &&
                widget.displayName != null &&
                widget.displayName!.trim().isNotEmpty)
              Text(
                ' @${widget.username}',
                style: baseStyle.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: (baseStyle.fontSize ?? 14) - 1,
                  color: baseStyle.color?.withValues(alpha: 0.65),
                  shadows: const <Shadow>[
                    Shadow(
                      color: Color(0xAA000000),
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  String get _accessibilityLabel {
    final StringBuffer sb = StringBuffer();
    if (widget.level != null) sb.write('Level ${widget.level}, ');
    if (widget.titlePrefix != null && widget.titlePrefix!.isNotEmpty) {
      sb.write('${widget.titlePrefix}, ');
    }
    sb.write(_primary);
    if (widget.guildName != null && widget.guildName!.isNotEmpty) {
      sb.write(', Guild ${widget.guildName}');
    }
    if (widget.isOnline != null) {
      sb.write(widget.isOnline! ? ', Online' : ', Offline');
    }
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle base = widget.style ??
        GoogleFonts.cinzel(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: widget.floatingPlate ? 13 : 14,
          letterSpacing: 0.35,
        );

    final Color? glow = _prestigeGlowColor;
    final Color lumColor = _luminescenceColor;

    // Build high-legibility shadows for 3D world contrast
    final TextStyle finalStyle = base.copyWith(
      shadows: _buildHighLegibilityShadows(glow),
    );

    // Build content layout based on floating or inline mode
    Widget content = widget.floatingPlate
        ? _buildFloatingPlateLayout(
            finalStyle: finalStyle,
            baseStyle: base,
            lumColor: lumColor,
          )
        : _buildMainWrap(
            finalStyle: finalStyle,
            baseStyle: base,
            lumColor: lumColor,
          );

    if (widget.maxWidth != null) {
      content = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth!),
        child: content,
      );
    }

    // Apply frosted obsidian-glass backing
    Widget wrapped = content;
    if (widget.showBacking) {
      final double radius = widget.floatingPlate ? 9.0 : (widget.compactBadge ? 6.0 : 7.5);
      final EdgeInsets defaultPadding = widget.floatingPlate
          ? const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0)
          : EdgeInsets.symmetric(
              horizontal: widget.compactBadge ? 6.0 : 8.0,
              vertical: widget.compactBadge ? 2.0 : 3.5,
            );

      final bool useBlur = widget.enableBlur ?? widget.floatingPlate;

      final Widget glassContainer = Container(
        padding: widget.padding ?? defaultPadding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              PlayerNameLabel.obsidianSurface.withValues(
                alpha: widget.floatingPlate ? 0.88 : 0.72,
              ),
              PlayerNameLabel.obsidianVoid.withValues(
                alpha: widget.floatingPlate ? 0.94 : 0.82,
              ),
            ],
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: lumColor.withValues(
              alpha: _pressed
                  ? 0.75
                  : (widget.floatingPlate ? 0.45 : 0.25),
            ),
            width: 0.85,
          ),
          boxShadow: <BoxShadow>[
            // 3D Ambient occlusion shadow
            BoxShadow(
              color: Colors.black.withValues(
                alpha: widget.floatingPlate ? 0.65 : 0.35,
              ),
              blurRadius: widget.floatingPlate ? 12.0 : 6.0,
              offset: const Offset(0, 2.5),
            ),
            // Luminous rim halo
            if (widget.enableGlow)
              BoxShadow(
                color: lumColor.withValues(
                  alpha: widget.floatingPlate ? 0.18 : 0.08,
                ),
                blurRadius: 10.0,
                spreadRadius: 0.5,
              ),
          ],
        ),
        child: content,
      );

      wrapped = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: useBlur
            ? BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: widget.floatingPlate ? 8.0 : 5.0,
                  sigmaY: widget.floatingPlate ? 8.0 : 5.0,
                ),
                child: glassContainer,
              )
            : glassContainer,
      );
    }

    // Apply SafeArea / MediaQuery insets protection
    final bool protectSafeArea =
        widget.enableSafeArea ?? widget.floatingPlate;
    if (protectSafeArea) {
      wrapped = SafeArea(
        top: widget.floatingPlate,
        bottom: false,
        maintainBottomViewPadding: true,
        child: wrapped,
      );
    }

    // Accessibility Semantics
    wrapped = Semantics(
      label: _accessibilityLabel,
      button: widget.onTap != null || widget.onInspect != null,
      child: wrapped,
    );

    // Gesture interaction with tactile HapticFeedback
    final bool isInteractive =
        widget.onTap != null || widget.onLongPress != null || widget.onInspect != null;

    if (!isInteractive) return wrapped;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap?.call();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        if (widget.onInspect != null) {
          widget.onInspect!.call();
        } else {
          widget.onLongPress?.call();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.965 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeInOutSine,
        child: wrapped,
      ),
    );
  }
}

/// Procedural Aion 2 Vector Guild Crest Painter.
class _AionGuildCrestPainter extends CustomPainter {
  const _AionGuildCrestPainter({
    required this.primaryColor,
    required this.glowColor,
  });

  final Color primaryColor;
  final Color glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Shield contour
    final Path crestPath = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.95, h * 0.22)
      ..lineTo(w * 0.82, h * 0.72)
      ..lineTo(w * 0.5, h)
      ..lineTo(w * 0.18, h * 0.72)
      ..lineTo(w * 0.05, h * 0.22)
      ..close();

    // Semi-translucent obsidian shield body
    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          primaryColor.withValues(alpha: 0.35),
          const Color(0xFF07090E).withValues(alpha: 0.85),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(crestPath, fillPaint);

    // Luminous metallic border
    final Paint strokePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    canvas.drawPath(crestPath, strokePaint);

    // Inner radiant star diamond
    final Path innerDiamond = Path()
      ..moveTo(w * 0.5, h * 0.25)
      ..lineTo(w * 0.68, h * 0.5)
      ..lineTo(w * 0.5, h * 0.75)
      ..lineTo(w * 0.32, h * 0.5)
      ..close();

    final Paint starPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawPath(innerDiamond, starPaint);
  }

  @override
  bool shouldRepaint(covariant _AionGuildCrestPainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.glowColor != glowColor;
}
