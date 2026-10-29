import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tutorial/tutorial_hud_anchor.dart';
import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_controller.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/services/app_foreground_service.dart';
import '../../core/utils/cosmetic_title.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/xp_formula.dart';
import '../../l10n/l10n.dart';
import '../../models/staff_model.dart';
import '../../providers/player_provider.dart';
import '../../providers/staff_provider.dart';
import '../../routing/app_router.dart';
import '../../core/utils/keyboard_dismiss.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../screens/chat/chat_screen.dart';
import '../common/profile_avatar.dart';
import '../common/cosmetic_title_badge.dart';
import '../common/top_bar_health_strip.dart';
import '../player/staff_badge.dart';
import 'game_quick_menu.dart';
import 'live_ticker.dart';
import '../notifications/notification_inbox_ui.dart';

/// 2027 Aion 2 Obsidian-Glass & Luminescence Design Tokens
abstract final class _AionChromeTheme {
  // Obsidian dark glass surface layers
  static const Color obsidianVoid = Color(0xFF07090E); // Deepest obsidian void
  static const Color obsidianBase = Color(0xFF0B0E14); // Core obsidian glass base
  static const Color obsidianElevated = Color(0xFF101522); // Highlight / elevated obsidian

  // Luminescence accents
  static const Color celestialGold = Color(0xFFE5C158); // Aion 2 celestial gold
  static const Color etherCyan = Color(0xFF00E5FF); // Aion 2 ether cyan
  static const Color goldGlow = Color(0x33E5C158); // 20% gold luminous blur
  static const Color cyanGlow = Color(0x3300E5FF); // 20% cyan ethereal aura

  static const double glassBlurSigma = 16.0;
}

// ─────────────────────────────────────────────────────────────────────────────
// GameTopBar
// ─────────────────────────────────────────────────────────────────────────────

class GameTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const GameTopBar({
    super.key,
    required this.title,
    this.onLogout,
    this.trailingActions,
  });

  final String title;
  final Future<void> Function()? onLogout;
  final List<Widget>? trailingActions;

  @override
  Size get preferredSize => const Size.fromHeight(196);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final playerState = ref.watch(playerProvider);
    final StaffProfile staffProfile = ref.watch(staffProvider).profile;
    final profile = playerState.profile;

    final String displayName = profile == null
        ? l10n.playerDefault
        : ((profile.displayName ?? profile.username).trim().isEmpty
              ? profile.username
              : (profile.displayName ?? profile.username));

    final String usernameStr = profile?.username ?? '';
    final int profileLevel = profile?.level ?? 1;
    final int gold = profile?.gold ?? 0;
    final double gems = profile?.gems ?? 0;
    final int energy = profile?.energy ?? 0;
    final int health = profile?.health ?? 0;
    final int maxHealth = profile?.maxHealth ?? 0;
    final int tolerance = profile?.tolerance ?? 0;

    final xpProgress = buildXpProgress(
      level: profileLevel,
      totalXp: profile?.xp ?? 0,
    );
    final int level = xpProgress.level;
    final double xpPercent = xpProgress.percent;

    final double screenWidth = MediaQuery.of(context).size.width;
    final double width = (screenWidth * 0.95).clamp(320.0, 520.0);
    final bool compact = screenWidth < 390;
    final double bgHeight = compact ? 104 : 112;
    final double cutHeight = 35;

    return Semantics(
      header: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: _AionChromeTheme.glassBlurSigma,
              sigmaY: _AionChromeTheme.glassBlurSigma,
            ),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0xF507090E),
                    Color(0xE60B0E14),
                    Color(0xD907090E),
                  ],
                ),
              ),
              child: Builder(
                builder: (context) {
                  final double topInset = MediaQuery.paddingOf(context).top;
                  // Robust modern notch & Dynamic Island avoidance:
                  // Ensure clearance so camera cutout and island pill do not overlap HUD elements.
                  final double topPad = topInset >= 44
                      ? topInset
                      : (topInset > 0
                          ? (topInset - 2).clamp(0.0, double.infinity)
                          : 4.0);
                  return Padding(
                    padding: EdgeInsets.only(top: topPad),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Container(
                            width: width,
                            // Tight to XP row — less dead space above ticker/bell.
                            height: bgHeight + 8,
                            margin: EdgeInsets.zero,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  height: bgHeight,
                                  child: CustomPaint(
                                    size: Size(width, bgHeight),
                                    painter: TopBarShapePainter(),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  left: 15,
                                  width: width * (compact ? 0.31 : 0.28),
                                  height: bgHeight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      top: 10,
                                      left: 8,
                                      right: 4,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        TutorialHudAnchorChip(
                                          anchorId: TutorialAnchorId.hudGold,
                                          child: _buildStatLikeRightLeft(
                                            _compact(gold),
                                            Icons.paid_rounded,
                                            _AionChromeTheme.celestialGold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        _buildToleranceStat(tolerance),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 15,
                                  width: width * (compact ? 0.31 : 0.28),
                                  height: bgHeight,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        TutorialHudAnchorChip(
                                          anchorId: TutorialAnchorId.hudGems,
                                          child: _buildStatRight(
                                            _formatGems(gems),
                                            Icons.diamond_rounded,
                                            _AionChromeTheme.etherCyan,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        TutorialHudAnchorChip(
                                          anchorId: TutorialAnchorId.hudEnergy,
                                          child: _buildStatRight(
                                            _compact(energy),
                                            Icons.bolt_rounded,
                                            AppColors.warningSolar,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  left: width * (compact ? 0.28 : 0.24),
                                  right: width * (compact ? 0.28 : 0.24),
                                  height: bgHeight - cutHeight + 5,
                                  child: Center(
                                    child: GestureDetector(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        context.go(AppRoutes.character);
                                      },
                                      behavior: HitTestBehavior.opaque,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ProfileAvatar(
                                            size: 40,
                                            avatarUrl: profile?.avatarUrl,
                                            backgroundColor: const Color(0xFF101522),
                                            glowFrame: profile?.avatarFrame == 'glow',
                                            codexFrame: profile?.avatarFrame == 'codex',
                                          ),
                                          const SizedBox(width: 8),
                                          ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth: width * (compact ? 0.30 : 0.34),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: <Widget>[
                                                    Flexible(
                                                      child: Text(
                                                        displayName,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 12,
                                                          shadows: <Shadow>[
                                                            Shadow(
                                                              color: _AionChromeTheme.goldGlow,
                                                              blurRadius: 6,
                                                            ),
                                                          ],
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    StaffBadge(badge: staffProfile.badge, compact: true),
                                                  ],
                                                ),
                                                if (usernameStr.isNotEmpty)
                                                  Text(
                                                    '@$usernameStr',
                                                    style: const TextStyle(
                                                      color: Color(0xFF8E9CAE),
                                                      fontSize: 10,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                if (hasCosmeticTitle(
                                                  profile?.cosmeticTitle,
                                                )) ...<Widget>[
                                                  const SizedBox(height: 2),
                                                  CosmeticTitleBadge(
                                                    titleKey: profile!.cosmeticTitle,
                                                    compact: true,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: bgHeight - cutHeight + 8,
                                  left: width * (compact ? 0.16 : 0.20),
                                  right: width * (compact ? 0.16 : 0.20),
                                  child: TutorialAnchorScope(
                                    id: TutorialAnchorId.hudHealth,
                                    onTutorialTap: () async {
                                      HapticFeedback.lightImpact();
                                      await ref
                                          .read(tutorialProvider.notifier)
                                          .onAnchorTap(TutorialAnchorId.hudHealth);
                                    },
                                    child: GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        context.go(AppRoutes.character);
                                      },
                                      behavior: HitTestBehavior.opaque,
                                      child: TopBarVitalsBars(
                                        level: level,
                                        xpPercent: xpPercent,
                                        currentXp: xpProgress.xpInLevel,
                                        requiredXp: xpProgress.xpNeededInLevel,
                                        health: health,
                                        maxHealth: maxHealth,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                          child: Row(
                            children: <Widget>[
                              const Expanded(child: LiveTicker()),
                              const NotificationBellButton(),
                              if (trailingActions != null) ...trailingActions!,
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _compact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toString();
  }

  String _formatGems(num value) {
    final double v = value.toDouble();
    final double abs = v.abs();
    if (abs >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (abs >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  Color _toleranceColor(int value) {
    if (value >= 60) return AppColors.danger;
    if (value >= 40) return AppColors.warning;
    return AppColors.success;
  }

  Widget _buildToleranceStat(int tolerance) {
    final Color color = _toleranceColor(tolerance);
    final double percent = tolerance.clamp(0, 100) / 100;

    return GestureDetector(
      onTap: () => HapticFeedback.selectionClick(),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double barWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth.clamp(0.0, 56.0)
              : 56.0;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: _AionChromeTheme.obsidianBase.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: color.withValues(alpha: 0.35),
                width: 0.8,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: color.withValues(alpha: 0.12),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$tolerance%',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.balance_rounded, color: color, size: 14),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  width: barWidth,
                  height: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: percent,
                      backgroundColor: const Color(0xFF101522),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 3,
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

  Widget _buildStatLikeRightLeft(String value, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => HapticFeedback.selectionClick(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: _AionChromeTheme.obsidianBase.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withValues(alpha: 0.38),
            width: 0.8,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: 0.16),
              blurRadius: 8,
            ),
            const BoxShadow(
              color: Color(0x33000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 0.3,
                  shadows: <Shadow>[
                    Shadow(
                      color: Color(0x66000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.20),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: color.withValues(alpha: 0.22),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRight(String value, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => HapticFeedback.selectionClick(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: _AionChromeTheme.obsidianBase.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withValues(alpha: 0.38),
            width: 0.8,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: 0.16),
              blurRadius: 8,
            ),
            const BoxShadow(
              color: Color(0x33000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 0.3,
                  shadows: <Shadow>[
                    Shadow(
                      color: Color(0x66000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.20),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: color.withValues(alpha: 0.22),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TopBarShapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    const double r = 20;
    const double cutHeight = 35; // Kavisin yüksekliği

    // 2027 Aion 2 Obsidian Dark Glass Gradient
    final Paint paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xF0101522), // Obsidian elevated glass
          Color(0xF50B0E14), // Obsidian glass base
          Color(0xFA07090E), // Obsidian dark void
        ],
        stops: <double>[0.0, 0.48, 1.0],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;

    // Dual luminescence outer border (Celestial Gold & Ether Cyan rim)
    final Paint strokePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0x66E5C158), // Celestial gold luminescence
          Color(0x33FFFFFF), // Specular crystalline edge
          Color(0x5500E5FF), // Ether cyan luminescence
          Color(0x1F00E5FF),
        ],
        stops: <double>[0.0, 0.35, 0.75, 1.0],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final Path path = Path();

    // Üst köşeler (sol üstten sağ üste düz çizgi)
    path.moveTo(r, 0);
    path.lineTo(w - r, 0);
    path.quadraticBezierTo(w, 0, w, r); // Sağ üst köşe

    // Sağ kenar
    path.lineTo(w, h - r);
    path.quadraticBezierTo(w, h, w - r, h); // Sağ alt köşe

    // Kavis koordinatları
    final double pR = w * 0.90; // Sağ panel kenarı
    final double cR = w * 0.77; // Sağ kavis bitişi
    final double cL = w * 0.23; // Sol kavis bitişi
    final double pL = w * 0.10; // Sol panel kenarı

    // Sağ alt köşeden orta kavisin sağına çizgi
    path.lineTo(pR, h);

    // Ortadan sağa yukarı kavis
    path.cubicTo(pR - 10, h, cR + 10, h - cutHeight, cR, h - cutHeight);

    // Ortadaki düzlük (Profilin alt kısmı)
    path.lineTo(cL, h - cutHeight);

    // Ortadan sola aşağı kavis
    path.cubicTo(cL - 10, h - cutHeight, pL + 10, h, pL, h);

    // Sol kavis başlangıcından sol alt köşeye
    path.lineTo(r, h);
    path.quadraticBezierTo(0, h, 0, h - r); // Sol alt köşe

    // Sol kenar
    path.lineTo(0, r);
    path.quadraticBezierTo(0, 0, r, 0); // Sol üst köşe
    path.close();

    // Ambient ether cyan outer glow
    final Paint glowPaint = Paint()
      ..color = const Color(0x2400E5FF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, glowPaint);

    canvas.drawPath(path, paint);

    // 2027 Aion 2 Dark-Fantasy HUD accents
    canvas.save();
    canvas.clipPath(path);

    // Fine horizontal datum grid lines with ether cyan luminescence
    final Paint gridLinePaint = Paint()
      ..color = const Color(0x1F00E5FF)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(12, h * 0.48), Offset(cL - 8, h * 0.48), gridLinePaint);
    canvas.drawLine(Offset(cR + 8, h * 0.48), Offset(w - 12, h * 0.48), gridLinePaint);

    // Micro grid ticks
    final Paint tickPaint = Paint()
      ..color = const Color(0x3300E5FF)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(32, h * 0.48 - 3), Offset(32, h * 0.48 + 3), tickPaint);
    canvas.drawLine(Offset(w - 32, h * 0.48 - 3), Offset(w - 32, h * 0.48 + 3), tickPaint);

    // Runic edge brackets with celestial gold luminescence
    final Paint accentBracketPaint = Paint()
      ..color = const Color(0x80E5C158)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(8, 8), Offset(8, 24), accentBracketPaint);
    canvas.drawLine(Offset(8, 8), Offset(24, 8), accentBracketPaint);
    canvas.drawLine(Offset(w - 8, 8), Offset(w - 8, 24), accentBracketPaint);
    canvas.drawLine(Offset(w - 8, 8), Offset(w - 24, 8), accentBracketPaint);

    // Ether cyan corner aura nodes
    final Paint cyanNodePaint = Paint()
      ..color = const Color(0xCC00E5FF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(8, 8), 1.8, cyanNodePaint);
    canvas.drawCircle(Offset(w - 8, 8), 1.8, cyanNodePaint);

    canvas.restore();

    canvas.drawPath(path, strokePaint);

    // Luminous top-edge celestial rim highlight (Celestial Gold + Ether Cyan)
    final Paint topRimPaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[
          Colors.transparent,
          Color(0x9900E5FF),
          Color(0xFFE5C158),
          Color(0x9900E5FF),
          Colors.transparent,
        ],
        stops: <double>[0.0, 0.25, 0.50, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(r, 0, w - 2 * r, 2.5))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(r, 0), Offset(w - r, 0), topRimPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// GameBackBar / GameSubScreenScaffold
// ─────────────────────────────────────────────────────────────────────────────

class GameBackBar extends StatelessWidget {
  const GameBackBar({super.key, required this.onBack, this.label = 'Geri'});

  final VoidCallback onBack;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _AionChromeTheme.glassBlurSigma,
            sigmaY: _AionChromeTheme.glassBlurSigma,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0xF007090E),
                  Color(0xE60B0E14),
                ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: _AionChromeTheme.celestialGold.withValues(alpha: 0.22),
                  width: 0.8,
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onBack();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: _AionChromeTheme.obsidianElevated.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          border: Border.all(
                            color: _AionChromeTheme.celestialGold.withValues(alpha: 0.45),
                            width: 1.0,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: _AionChromeTheme.celestialGold.withValues(alpha: 0.18),
                              blurRadius: 10,
                            ),
                            BoxShadow(
                              color: _AionChromeTheme.etherCyan.withValues(alpha: 0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 15,
                          color: _AionChromeTheme.celestialGold,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        label,
                        style: TextStyle(
                          color: _AionChromeTheme.celestialGold.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.3,
                          shadows: const <Shadow>[
                            Shadow(
                              color: _AionChromeTheme.goldGlow,
                              blurRadius: 8,
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
    );
  }
}

class GameSubScreenScaffold extends ConsumerWidget {
  const GameSubScreenScaffold({
    super.key,
    required this.title,
    required this.onLogout,
    required this.body,
    this.fallbackRoute,
    this.bottomNavRoute,
    this.floatingActionButton,
  });

  final String title;
  final Future<void> Function() onLogout;
  final Widget body;
  final String? fallbackRoute;
  final String? bottomNavRoute;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void goBack() {
      HapticFeedback.lightImpact();
      if (context.canPop()) {
        context.pop();
      } else if (fallbackRoute != null) {
        context.go(fallbackRoute!);
      }
    }

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (bool didPop, _) {
        if (!didPop && fallbackRoute != null) {
          HapticFeedback.lightImpact();
          context.go(fallbackRoute!);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF07090E),
        resizeToAvoidBottomInset: true,
        extendBody: bottomNavRoute != null,
        appBar: GameTopBar(title: title, onLogout: onLogout),
        bottomNavigationBar: bottomNavRoute != null
            ? GameBottomBar(currentRoute: bottomNavRoute!, onLogout: onLogout)
            : null,
        floatingActionButton: floatingActionButton,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            GameBackBar(onBack: goBack),
            Expanded(child: DismissKeyboard(child: body)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GameBottomBar  (animated active indicator)
// ─────────────────────────────────────────────────────────────────────────────

/// [GameChatFab] square size.
const double kGameChatFabSize = 64;

/// Main nav pill height inside [GameBottomBar].
const double kGameBottomNavPillHeight = 64;

/// Gap between [GameChatFab] bottom and nav pill top.
const double kGameChatFabNavGap = 10;

/// [GameChatFab] vertical offset inside [GameBottomBar] stack.
const double kGameChatFabStackBottom =
    kGameBottomNavPillHeight + kGameChatFabNavGap;

/// Fixed overlay height of [GameBottomBar] stack (fab offset + fab size).
const double kGameBottomBarStackHeight =
    kGameChatFabStackBottom + kGameChatFabSize;

/// Total vertical space [GameBottomBar] occupies above [gameBottomSafeInset].
const double kGameBottomBarOverlayHeight = kGameBottomBarStackHeight;

/// Horizontal inset for floating corner actions (SafeArea min 12 + positioned 6).
const double kGameFloatingFabInset = 18;

/// Right reserved width for [GameChatFab] (inset + fab + gap).
const double kGameChatFabReservedWidth = 82;

/// Matches [GameBottomBar] [SafeArea.minimum] bottom padding.
const double kGameBottomSafeMinimum = 10;

double gameBottomSafeInset(BuildContext context) {
  final double bottom = MediaQuery.paddingOf(context).bottom;
  return bottom > kGameBottomSafeMinimum ? bottom : kGameBottomSafeMinimum;
}

/// Offset from physical screen bottom to [GameChatFab] bottom edge.
double gameChatFabBottom(BuildContext context) {
  return gameBottomSafeInset(context) + kGameChatFabStackBottom;
}

/// Max width for rank panel between [StickyActionBar] fab and [GameChatFab].
double gameRankPanelMaxWidth(BuildContext context) {
  return MediaQuery.sizeOf(context).width -
      kGameFloatingFabInset -
      kGameChatFabReservedWidth -
      kGameChatFabSize;
}

/// Distance from physical screen bottom to top of [GameBottomBar] overlay.
double gameBottomBarClearance(BuildContext context) {
  return gameBottomSafeInset(context) + kGameBottomBarOverlayHeight;
}

class GameBottomBar extends ConsumerStatefulWidget {
  const GameBottomBar({
    super.key,
    required this.currentRoute,
    this.leadingOverlay,
    this.onLogout,
    this.navigationLocked = false,
  });

  final String currentRoute;
  final Widget? leadingOverlay;
  final Future<void> Function()? onLogout;
  final bool navigationLocked;

  @override
  ConsumerState<GameBottomBar> createState() => _GameBottomBarState();
}

class _GameBottomBarState extends ConsumerState<GameBottomBar>
    with SingleTickerProviderStateMixin {
  static const int _menuTabIndex = 4;

  static const List<({String? path, bool isMenuTrigger})> _itemSpecs =
      <({String? path, bool isMenuTrigger})>[
        (path: AppRoutes.home, isMenuTrigger: false),
        (path: AppRoutes.inventory, isMenuTrigger: false),
        (path: AppRoutes.dungeon, isMenuTrigger: false),
        (path: AppRoutes.character, isMenuTrigger: false),
        (path: null, isMenuTrigger: true),
      ];

  List<_BottomItem> _items(AppLocalizations l10n) => <_BottomItem>[
    _BottomItem(
      path: AppRoutes.home,
      label: l10n.navHome,
      icon: Icons.home_rounded,
    ),
    _BottomItem(
      path: AppRoutes.inventory,
      label: l10n.navInventory,
      icon: Icons.inventory_2_rounded,
    ),
    _BottomItem(
      path: AppRoutes.dungeon,
      label: l10n.navDungeon,
      icon: Icons.sports_martial_arts_rounded,
    ),
    _BottomItem(
      path: AppRoutes.character,
      label: l10n.navCharacter,
      icon: Icons.person_rounded,
    ),
    _BottomItem(
      label: l10n.navMenu,
      icon: Icons.apps_rounded,
      isMenuTrigger: true,
    ),
  ];

  late final AnimationController _indicatorCtrl;
  late Animation<double> _indicatorAnim;
  bool _menuOpen = false;

  /// Last bottom-bar tab the user selected; kept when navigating via quick menu.
  int _stickyTabIndex = 0;

  int? _matchedTabIndex(String route) {
    for (int i = 0; i < _itemSpecs.length; i++) {
      final String? path = _itemSpecs[i].path;
      if (path == null) continue;
      if (_matches(route, path)) return i;
    }
    return null;
  }

  int _displayIndex(String route) {
    if (_menuOpen) return _menuTabIndex;
    final int? matched = _matchedTabIndex(route);
    if (matched != null) return matched;
    if (route.startsWith(AppRoutes.guild)) return _menuTabIndex;
    return _stickyTabIndex;
  }

  void _animateIndicatorTo(int index) {
    _indicatorAnim =
        Tween<double>(
          begin: _indicatorAnim.value,
          end: index.toDouble(),
        ).animate(
          CurvedAnimation(parent: _indicatorCtrl, curve: Curves.easeOutCubic),
        );
    _indicatorCtrl
      ..reset()
      ..forward();
  }

  Future<void> _openMenu() async {
    HapticFeedback.mediumImpact();
    setState(() => _menuOpen = true);
    _animateIndicatorTo(_menuTabIndex);
    await showGameQuickMenu(
      context,
      onLogout: widget.onLogout,
      onOpenChat: showChatModal,
    );
    if (!mounted) return;
    setState(() => _menuOpen = false);
    _animateIndicatorTo(_displayIndex(widget.currentRoute));
  }

  bool _matches(String current, String route) {
    if (current == route) return true;
    if (route == AppRoutes.home) return current == AppRoutes.home;
    return current.startsWith(route);
  }

  @override
  void initState() {
    super.initState();
    _stickyTabIndex = _matchedTabIndex(widget.currentRoute) ?? 0;
    final int initial = _displayIndex(widget.currentRoute);
    _indicatorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _indicatorAnim =
        Tween<double>(
          begin: initial.toDouble(),
          end: initial.toDouble(),
        ).animate(
          CurvedAnimation(parent: _indicatorCtrl, curve: Curves.easeOutCubic),
        );
  }

  @override
  void didUpdateWidget(GameBottomBar old) {
    super.didUpdateWidget(old);
    if (old.currentRoute != widget.currentRoute && !_menuOpen) {
      final int? matched = _matchedTabIndex(widget.currentRoute);
      final int nextIndex =
          matched ??
          (widget.currentRoute.startsWith(AppRoutes.guild)
              ? _menuTabIndex
              : _stickyTabIndex);
      if (nextIndex != _stickyTabIndex || matched != null) {
        if (matched != null) _stickyTabIndex = matched;
        _animateIndicatorTo(_displayIndex(widget.currentRoute));
      }
    }
  }

  @override
  void dispose() {
    _indicatorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final List<_BottomItem> items = _items(l10n);
    final int activeIdx = _displayIndex(widget.currentRoute);
    final String? navTutorialAnchor =
        ref.watch(tutorialProvider).activeStep?.anchorId;
    final bool hideFabOverlays =
        navTutorialAnchor != null && navTutorialAnchor.startsWith('nav.');
    final Widget? leadingOverlay = widget.leadingOverlay;

    // No ColoredBox — transparent ColoredBox still hit-tests and swallows
    // taps in the FAB band under extendBody. Stack deferToChild → only
    // nav pill / FAB / leadingOverlay receive hits; empty band → body.
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: SizedBox(
        height: kGameBottomBarStackHeight,
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: <Widget>[
            // Soft fade only near nav pill — IgnorePointer so gradient
            // never steals hits from body or controls.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 88,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        const Color(0xFF07090E).withValues(alpha: 0),
                        const Color(0xFF07090E).withValues(alpha: 0.65),
                        const Color(0xFF07090E).withValues(alpha: 0.96),
                      ],
                      stops: const <double>[0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _AionChromeTheme.glassBlurSigma,
                    sigmaY: _AionChromeTheme.glassBlurSigma,
                  ),
                  child: TutorialAnchorScope(
                    id: TutorialAnchorId.navBottomBar,
                    child: Container(
                      height: kGameBottomNavPillHeight,
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Color(0xEB101522), // Obsidian elevated glass
                            Color(0xF50B0E14), // Obsidian dark glass base
                            Color(0xF807090E), // Obsidian void
                          ],
                          stops: <double>[0.0, 0.55, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusXxl,
                        ),
                        border: Border.all(
                          color: _AionChromeTheme.celestialGold.withValues(alpha: 0.42),
                          width: 1.2,
                        ),
                        boxShadow: <BoxShadow>[
                          const BoxShadow(
                            color: Color(0x9907090E),
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                          BoxShadow(
                            color: _AionChromeTheme.celestialGold.withValues(alpha: 0.16),
                            blurRadius: 16,
                            offset: const Offset(0, -1),
                          ),
                          BoxShadow(
                            color: _AionChromeTheme.etherCyan.withValues(alpha: 0.15),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double itemW =
                              constraints.maxWidth / items.length;
                          return Stack(
                            clipBehavior: Clip.hardEdge,
                            children: <Widget>[
                              // Animated active indicator — inset inside pill with dual luminescence.
                              AnimatedBuilder(
                                animation: _indicatorAnim,
                                builder: (context, _) {
                                  return Positioned(
                                    top: 7,
                                    bottom: 7,
                                    left:
                                        _indicatorAnim.value * itemW +
                                        itemW * 0.08,
                                    width: itemW * 0.84,
                                    child: IgnorePointer(
                                      child: ExcludeSemantics(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              AppSpacing.radiusMd,
                                            ),
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: <Color>[
                                                _AionChromeTheme.celestialGold.withValues(alpha: 0.32),
                                                _AionChromeTheme.etherCyan.withValues(alpha: 0.14),
                                              ],
                                            ),
                                            border: Border.all(
                                              color: _AionChromeTheme.celestialGold.withValues(alpha: 0.65),
                                              width: 1.2,
                                            ),
                                            boxShadow: <BoxShadow>[
                                              BoxShadow(
                                                color: _AionChromeTheme.celestialGold.withValues(alpha: 0.30),
                                                blurRadius: 12,
                                                spreadRadius: 0,
                                              ),
                                              BoxShadow(
                                                color: _AionChromeTheme.etherCyan.withValues(alpha: 0.18),
                                                blurRadius: 8,
                                                offset: const Offset(0, -1),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // Fill full pill height
                              Positioned.fill(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: List<Widget>.generate(items.length, (
                                    i,
                                  ) {
                                    final _BottomItem item = items[i];
                                    final bool isActive = i == activeIdx;
                                    final String? navAnchor = ref
                                        .read(tutorialProvider.notifier)
                                        .anchorForNavIndex(i);
                                    Widget tabCell = Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.max,
                                      children: <Widget>[
                                        Stack(
                                          alignment: Alignment.center,
                                          children: <Widget>[
                                            if (isActive)
                                              Positioned.fill(
                                                child: Center(
                                                  child: Container(
                                                    width: 32,
                                                    height: 32,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      gradient: RadialGradient(
                                                        colors: <Color>[
                                                          _AionChromeTheme.celestialGold.withValues(alpha: 0.32),
                                                          _AionChromeTheme.etherCyan.withValues(alpha: 0.12),
                                                          Colors.transparent,
                                                        ],
                                                        stops: const <double>[0.0, 0.60, 1.0],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            AnimatedScale(
                                              scale: isActive ? 1.10 : 1.0,
                                              duration: const Duration(
                                                milliseconds: 240,
                                              ),
                                              curve: Curves.easeOutCubic,
                                              child: Icon(
                                                item.icon,
                                                size: 22,
                                                color: isActive
                                                    ? _AionChromeTheme.celestialGold
                                                    : AppColors.mutedTitanium,
                                                shadows: isActive
                                                    ? <Shadow>[
                                                        Shadow(
                                                          color: _AionChromeTheme.celestialGold.withValues(alpha: 0.55),
                                                          blurRadius: 10,
                                                        ),
                                                        Shadow(
                                                          color: _AionChromeTheme.etherCyan.withValues(alpha: 0.35),
                                                          blurRadius: 6,
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: AppTextStyles.micro.copyWith(
                                            color: isActive
                                                ? AppColors.textPrimary
                                                : AppColors.mutedTitanium,
                                            fontWeight: isActive
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            fontSize: 9,
                                            height: 1.0,
                                            shadows: isActive
                                                ? <Shadow>[
                                                    Shadow(
                                                      color: Colors.black.withValues(alpha: 0.65),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 1),
                                                    ),
                                                    Shadow(
                                                      color: _AionChromeTheme.celestialGold.withValues(alpha: 0.30),
                                                      blurRadius: 4,
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                        ),
                                      ],
                                    );
                                    Widget tabButton = GestureDetector(
                                      onTap: () async {
                                        if (widget.navigationLocked) return;
                                        HapticFeedback.selectionClick();
                                        final TutorialController tutorialCtrl =
                                            ref.read(tutorialProvider.notifier);
                                        if (!tutorialCtrl.allowsNavTab(i)) {
                                          tutorialCtrl.registerWrongTap();
                                          return;
                                        }
                                        if (navAnchor != null) {
                                          await tutorialCtrl.onAnchorTap(
                                            navAnchor,
                                          );
                                        }
                                        if (!context.mounted) return;
                                        if (item.isMenuTrigger) {
                                          _openMenu();
                                          return;
                                        }
                                        setState(() => _stickyTabIndex = i);
                                        _animateIndicatorTo(i);
                                        final String path = item.path!;
                                        if (path == widget.currentRoute) {
                                          return;
                                        }
                                        context.go(path);
                                      },
                                      behavior: HitTestBehavior.opaque,
                                      child: tabCell,
                                    );
                                    if (navAnchor != null) {
                                      tabButton = TutorialAnchorScope(
                                        id: navAnchor,
                                        onTutorialTap: () async {
                                          if (widget.navigationLocked) return;
                                          HapticFeedback.selectionClick();
                                          final TutorialController tutorialCtrl =
                                              ref.read(
                                                tutorialProvider.notifier,
                                              );
                                          final String? required = ref
                                              .read(tutorialProvider)
                                              .activeStep
                                              ?.anchorId;
                                          if (required != navAnchor) return;
                                          if (!tutorialCtrl.allowsNavTab(i)) {
                                            tutorialCtrl.registerWrongTap();
                                            return;
                                          }
                                          await tutorialCtrl.onAnchorTap(
                                            navAnchor,
                                          );
                                          if (!context.mounted) return;
                                          if (item.isMenuTrigger) {
                                            await _openMenu();
                                            return;
                                          }
                                          setState(() => _stickyTabIndex = i);
                                          _animateIndicatorTo(i);
                                          final String path = item.path!;
                                          if (path != widget.currentRoute) {
                                            context.go(path);
                                          }
                                        },
                                        child: tabButton,
                                      );
                                    }
                                    return Expanded(
                                      key: ValueKey<String>('nav_tab_$i'),
                                      child: tabButton,
                                    );
                                  }),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (leadingOverlay != null && !hideFabOverlays)
              Positioned(
                left: 6,
                bottom: kGameChatFabStackBottom,
                child: leadingOverlay,
              ),
            if (!hideFabOverlays)
              const Positioned(
                right: 6,
                bottom: kGameChatFabStackBottom,
                child: GameChatFab(),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private helpers
// ─────────────────────────────────────────────────────────────────────────────

class _BottomItem {
  const _BottomItem({
    this.path,
    required this.label,
    required this.icon,
    this.isMenuTrigger = false,
  });

  final String? path;
  final String label;
  final IconData icon;
  final bool isMenuTrigger;
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat modal & FAB
// ─────────────────────────────────────────────────────────────────────────────

/// Web FloatingChat'ın Flutter karşılığı — bottom sheet olarak açılır.
Future<void> showChatModal(BuildContext context) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x9907090E),
    enableDrag: true,
    builder: (BuildContext ctx) {
      return FractionallySizedBox(
        heightFactor: 0.94,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: _AionChromeTheme.glassBlurSigma,
              sigmaY: _AionChromeTheme.glassBlurSigma,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xEB07090E),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(
                  color: _AionChromeTheme.celestialGold.withValues(alpha: 0.35),
                  width: 1.0,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: _AionChromeTheme.etherCyan.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: const ChatScreen(asPanel: true),
            ),
          ),
        ),
      );
    },
  );
}

/// Web FloatingChat butonunun Flutter karşılığı.
class GameChatFab extends StatefulWidget {
  const GameChatFab({super.key});

  @override
  State<GameChatFab> createState() => _GameChatFabState();
}

class _GameChatFabState extends State<GameChatFab> with WidgetsBindingObserver {
  int _unreadCount = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUnreadCount();
    _startPollTimer();
  }

  void _startPollTimer() {
    _pollTimer?.cancel();
    if (!AppForegroundService.instance.isForeground) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (AppForegroundService.instance.isForeground) {
        _loadUnreadCount();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPollTimer();
      _loadUnreadCount();
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final dynamic res = await SupabaseService.client.rpc(
        'get_dm_conversations',
      );
      final List<dynamic> rows = (res as List?) ?? const <dynamic>[];

      int total = 0;
      for (final dynamic row in rows) {
        if (row is Map) {
          total += ((row['unread_count'] as num?) ?? 0).toInt();
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _unreadCount = total.clamp(0, 99);
      });
    } catch (_) {
      // Fail silently; chat badge is non-critical UI info.
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        await showChatModal(context);
        await _loadUnreadCount();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _AionChromeTheme.glassBlurSigma,
                sigmaY: _AionChromeTheme.glassBlurSigma,
              ),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xEB101522),
                      Color(0xF20B0E14),
                      Color(0xF807090E),
                    ],
                  ),
                  border: Border.all(
                    color: _AionChromeTheme.etherCyan.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: _AionChromeTheme.etherCyan.withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: _AionChromeTheme.celestialGold.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, -1),
                    ),
                    const BoxShadow(
                      color: Color(0x9907090E),
                      blurRadius: 10,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const <Widget>[
                    Icon(
                      Icons.chat_bubble_rounded,
                      color: _AionChromeTheme.etherCyan,
                      size: 22,
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Sohbet',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: _AionChromeTheme.celestialGold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_unreadCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      _AionChromeTheme.celestialGold,
                      Color(0xFFD97706),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _AionChromeTheme.etherCyan.withValues(alpha: 0.85),
                    width: 1.0,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: _AionChromeTheme.etherCyan.withValues(alpha: 0.45),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF07090E),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
