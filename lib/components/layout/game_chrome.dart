import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/supabase_service.dart';
import '../../core/utils/xp_formula.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../screens/chat/chat_screen.dart';
import '../common/profile_avatar.dart';
import 'game_quick_menu.dart';
import 'live_ticker.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GameTopBar
// ─────────────────────────────────────────────────────────────────────────────

class GameTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const GameTopBar({super.key, required this.title, this.onLogout});

  final String title;
  final Future<void> Function()? onLogout;

  @override
  Size get preferredSize => const Size.fromHeight(196);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final profile = playerState.profile;

    final String displayName = profile == null
        ? 'Oyuncu'
        : ((profile.displayName ?? profile.username).trim().isEmpty
              ? profile.username
              : (profile.displayName ?? profile.username));

    final String usernameStr = profile?.username ?? '';
    final int profileLevel = profile?.level ?? 1;
    final int gold = profile?.gold ?? 0;
    final double gems = profile?.gems ?? 0;
    final int energy = profile?.energy ?? 0;
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

    return SafeArea(
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: width,
              height: compact ? 126 : 134,
              margin: const EdgeInsets.only(top: 4),
              child: Stack(
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
                    child: ClipRect(
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
                            _buildStatLikeRightLeft(
                              _compact(gold),
                              Icons.paid_rounded,
                              Colors.orange,
                            ),
                            const SizedBox(height: 4),
                            _buildToleranceStat(tolerance),
                          ],
                        ),
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
                          _buildStatRight(
                            _formatGems(gems),
                            Icons.diamond_rounded,
                            Colors.blue,
                          ),
                          const SizedBox(height: 4),
                          _buildStatRight(
                            _compact(energy),
                            Icons.bolt,
                            Colors.yellow,
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ProfileAvatar(
                            size: 40,
                            avatarUrl: profile?.avatarUrl,
                            backgroundColor: Colors.red.withValues(alpha: 0.3),
                            glowFrame: profile?.avatarFrame == 'glow',
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: width * (compact ? 0.30 : 0.34),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hi, ${displayName.split(' ').first} ⚡',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (usernameStr.isNotEmpty)
                                  Text(
                                    '@$usernameStr',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: bgHeight - cutHeight + 8,
                    left: width * (compact ? 0.16 : 0.20),
                    right: width * (compact ? 0.16 : 0.20),
                    child: _buildStripedExpBar(
                      level,
                      xpPercent,
                      xpProgress.xpInLevel,
                      xpProgress.xpNeededInLevel,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          const LiveTicker(),
        ],
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

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double barWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(0.0, 52.0)
            : 52.0;

        return Column(
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
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.balance_rounded, color: color, size: 16),
                ],
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              width: barWidth,
              height: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: percent,
                  backgroundColor: const Color(0xFF1E2633),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 3,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatLikeRightLeft(String value, IconData icon, Color color) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 5),
          Icon(icon, color: color, size: 20),
        ],
      ),
    );
  }

  Widget _buildStatRight(String value, IconData icon, Color color) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 5),
          Icon(icon, color: color, size: 20),
        ],
      ),
    );
  }

  Widget _buildStripedExpBar(
    int level,
    double percent,
    int currentXp,
    int requiredXp,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 12,
          child: CustomPaint(
            painter: StripedProgressBarPainter(percent: percent),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'LEVEL $level',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$currentXp / $requiredXp',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class StripedProgressBarPainter extends CustomPainter {
  final double percent;
  StripedProgressBarPainter({required this.percent});

  @override
  void paint(Canvas canvas, Size size) {
    final trackRadius = const Radius.circular(6);

    // Background Track (the dark gray part)
    Paint trackPaint = Paint()
      ..color = const Color(0xFF1E2633)
      ..style = PaintingStyle.fill;

    // Border for the track
    Paint borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final trackRRect = RRect.fromRectAndRadius(Offset.zero & size, trackRadius);
    canvas.drawRRect(trackRRect, trackPaint);
    canvas.drawRRect(trackRRect, borderPaint);

    if (percent <= 0) return;

    final fillWidth = size.width * percent;
    final fillRect = Rect.fromLTWH(0, 0, fillWidth, size.height);
    final fillRRect = RRect.fromRectAndRadius(fillRect, trackRadius);

    // Gradient fill: Purple to Bright Green
    Paint fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFFADFF2F)],
      ).createShader(fillRect);

    canvas.save();
    canvas.clipRRect(fillRRect);
    canvas.drawRect(fillRect, fillPaint);

    // Diagonal Stripes (Görseldeki çizgili etki)
    Paint stripePaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (double i = -size.height; i < fillWidth; i += 10) {
      canvas.drawLine(
        Offset(i, size.height),
        Offset(i + size.height, 0),
        stripePaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TopBarShapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF161D27), Color(0xFF0A0F16)],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;

    Paint strokePaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    Path path = Path();
    double w = size.width;
    double h = size.height;
    double r = 20;
    double cutHeight = 35; // Kavisin yüksekliği

    // Üst köşeler (sol üstten sağ üste düz çizgi)
    path.moveTo(r, 0);
    path.lineTo(w - r, 0);
    path.quadraticBezierTo(w, 0, w, r); // Sağ üst köşe

    // Sağ kenar
    path.lineTo(w, h - r);
    path.quadraticBezierTo(w, h, w - r, h); // Sağ alt köşe

    // Kavis koordinatları
    double pR = w * 0.90; // Sağ panel kenarı (daha sağa alındı)
    double cR = w * 0.77; // Sağ kavis bitişi
    double cL = w * 0.23; // Sol kavis bitişi
    double pL = w * 0.10; // Sol panel kenarı (daha sola alındı)

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

    canvas.drawPath(path, paint);

    // Çapraz Çizgiler (Arkaplan dokusu)
    canvas.save();
    canvas.clipPath(path);
    Paint texturePaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (double i = -h; i < w; i += 8) {
      canvas.drawLine(Offset(i, h), Offset(i + h, 0), texturePaint);
    }
    canvas.restore();

    canvas.drawPath(path, strokePaint);
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
      color: AppColors.bgSurface.withValues(alpha: 0.95),
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: onBack,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.gold.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
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
          context.go(fallbackRoute!);
        }
      },
      child: Scaffold(
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
            Expanded(child: body),
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

/// [GameChatFab] vertical offset inside [GameBottomBar] stack.
const double kGameChatFabStackBottom = 70;

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

class GameBottomBar extends StatefulWidget {
  const GameBottomBar({
    super.key,
    required this.currentRoute,
    this.leadingOverlay,
    this.onLogout,
  });

  final String currentRoute;
  final Widget? leadingOverlay;
  final Future<void> Function()? onLogout;

  @override
  State<GameBottomBar> createState() => _GameBottomBarState();
}

class _GameBottomBarState extends State<GameBottomBar>
    with SingleTickerProviderStateMixin {
  static const int _menuTabIndex = 4;

  static const List<_BottomItem> _items = <_BottomItem>[
    _BottomItem(path: AppRoutes.home, label: 'Home', icon: Icons.home_rounded),
    _BottomItem(
      path: AppRoutes.inventory,
      label: 'Envanter',
      icon: Icons.inventory_2_rounded,
    ),
    _BottomItem(
      path: AppRoutes.dungeon,
      label: 'Zindan',
      icon: Icons.sports_martial_arts_rounded,
    ),
    _BottomItem(
      path: AppRoutes.character,
      label: 'Karakter',
      icon: Icons.person_rounded,
    ),
    _BottomItem(label: 'Menü', icon: Icons.apps_rounded, isMenuTrigger: true),
  ];

  late final AnimationController _indicatorCtrl;
  late Animation<double> _indicatorAnim;
  bool _menuOpen = false;

  int _activeIndex(String route) {
    if (_menuOpen) return _menuTabIndex;
    for (int i = 0; i < _items.length; i++) {
      final String? path = _items[i].path;
      if (path == null) continue;
      if (_matches(route, path)) return i;
    }
    return 0;
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
    setState(() => _menuOpen = true);
    _animateIndicatorTo(_menuTabIndex);
    await showGameQuickMenu(
      context,
      onLogout: widget.onLogout,
      onOpenChat: showChatModal,
    );
    if (!mounted) return;
    setState(() => _menuOpen = false);
    _animateIndicatorTo(_activeIndex(widget.currentRoute));
  }

  bool _matches(String current, String route) {
    if (current == route) return true;
    if (route == AppRoutes.home) return current == AppRoutes.home;
    return current.startsWith(route);
  }

  @override
  void initState() {
    super.initState();
    final int initial = _activeIndex(widget.currentRoute);
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
      final int newIdx = _activeIndex(widget.currentRoute);
      _animateIndicatorTo(newIdx);
    }
  }

  @override
  void dispose() {
    _indicatorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int activeIdx = _activeIndex(widget.currentRoute);

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: SizedBox(
          height: kGameBottomBarStackHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.chromeBg,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusXxl,
                        ),
                        border: Border.all(color: AppColors.chromeBorder),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double itemW =
                              constraints.maxWidth / _items.length;
                          return Stack(
                            children: <Widget>[
                              // Animated active indicator pill
                              AnimatedBuilder(
                                animation: _indicatorAnim,
                                builder: (context, _) {
                                  return Positioned(
                                    top: 8,
                                    left:
                                        _indicatorAnim.value * itemW +
                                        itemW * 0.15,
                                    width: itemW * 0.70,
                                    height: 36,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusMd,
                                        ),
                                        color: AppColors.accentBlue.withValues(
                                          alpha: 0.18,
                                        ),
                                        border: Border.all(
                                          color: AppColors.accentBlue
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // Tap targets + labels
                              Row(
                                children: List<Widget>.generate(_items.length, (
                                  i,
                                ) {
                                  final _BottomItem item = _items[i];
                                  final bool isActive = i == activeIdx;
                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        if (item.isMenuTrigger) {
                                          _openMenu();
                                          return;
                                        }
                                        final String path = item.path!;
                                        if (path == widget.currentRoute) {
                                          return;
                                        }
                                        if (path == AppRoutes.home) {
                                          context.go(path);
                                        } else {
                                          context.push(path);
                                        }
                                      },
                                      behavior: HitTestBehavior.opaque,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: <Widget>[
                                          AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            child: Icon(
                                              item.icon,
                                              size: isActive ? 22 : 20,
                                              color: isActive
                                                  ? AppColors.accentBlue
                                                  : AppColors.textTertiary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          AnimatedDefaultTextStyle(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            style: AppTextStyles.micro.copyWith(
                                              color: isActive
                                                  ? AppColors.accentBlue
                                                  : AppColors.textTertiary,
                                              fontWeight: isActive
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                              fontSize: 9,
                                            ),
                                            child: Text(item.label),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.leadingOverlay != null)
                Positioned(
                  left: 6,
                  bottom: kGameChatFabStackBottom,
                  child: widget.leadingOverlay!,
                ),
              const Positioned(
                right: 6,
                bottom: kGameChatFabStackBottom,
                child: GameChatFab(),
              ),
            ],
          ),
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

class _ResourceChip extends StatelessWidget {
  const _ResourceChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        color: color.withValues(alpha: 0.14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            value,
            style: AppTextStyles.micro.copyWith(
              color: AppColors.textPrimary,
              fontSize: 10,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

String _compact(int value) {
  final int abs = value.abs();
  if (abs >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (abs >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat modal & FAB
// ─────────────────────────────────────────────────────────────────────────────

/// Web FloatingChat'ın Flutter karşılığı — bottom sheet olarak açılır.
void showChatModal(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    enableDrag: true,
    builder: (BuildContext ctx) {
      return FractionallySizedBox(
        heightFactor: 0.94,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D1117),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: Color(0x1AFFFFFF)),
              left: BorderSide(color: Color(0x1AFFFFFF)),
              right: BorderSide(color: Color(0x1AFFFFFF)),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: const ChatScreen(asPanel: true),
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

class _GameChatFabState extends State<GameChatFab> {
  int _unreadCount = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _loadUnreadCount(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
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
      onTap: () {
        setState(() => _unreadCount = 0);
        showChatModal(context);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xF0141B26), Color(0xF0090D15)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.chat_bubble_rounded,
                  color: Color(0xFF7DD3FC),
                  size: 22,
                ),
                const SizedBox(height: 3),
                Text(
                  'Sohbet',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withValues(alpha: 0.7),
                    letterSpacing: 0.6,
                  ),
                ),
              ],
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
                    colors: <Color>[Color(0xFAF97316), Color(0xFAC2410C)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x70FBBF24)),
                ),
                child: Text(
                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFF0E0),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
