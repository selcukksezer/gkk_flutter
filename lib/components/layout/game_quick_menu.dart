import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/player_model.dart';
import '../../core/tutorial/tutorial_quick_menu.dart';
import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_anchor_registry.dart';
import '../../core/tutorial/tutorial_controller.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../providers/daily_reward_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/staff_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../layout/game_screen_background.dart';
import '../common/profile_avatar.dart';
import '../daily_reward/daily_reward_dialog.dart';
import '../../l10n/l10n.dart';

/// 2027 Aion 2 Obsidian-Glass & Luminescence Design System for Quick Menu.
abstract final class _QuickMenuTheme {
  // Obsidian dark glass surface hierarchy
  static const Color obsidianVoid = Color(0xFF07090E); // Deepest void base
  static const Color obsidianDeep = Color(0xFF0B0E14); // Mid-depth glass body
  static const Color obsidianSurface = Color(0xFF101522); // Top glass reflection

  // Luminescence accents
  static const Color celestialGold = Color(0xFFE5C158); // Celestial gold (#E5C158)
  static const Color etherCyan = Color(0xFF00E5FF); // Ether cyan (#00E5FF)
  static const Color etherCyanMuted = Color(0x6600E5FF);

  // Surface border & glow constants
  static const Color panelBorderGold = Color(0x40E5C158);
  static const Color panelBorderCyan = Color(0x3300E5FF);

  // Backward compatibility tokens
  static const Color bgHighlight = obsidianSurface;
  static const Color bgMid = obsidianDeep;
  static const Color bgDeep = obsidianVoid;
  static const Color bgEdge = Color(0xFF040609);

  static const Color panelBorder = Color(0x40E5C158);
  static const Color gold = celestialGold;
  static const Color cyan = etherCyan;
}

abstract final class _MenuAssets {
  static const String base = 'assets/menuitems/';
}

enum GameMenuAction { navigate, chat, logout, dailyReward, none }

class GameMenuItem {
  const GameMenuItem({
    required this.label,
    required this.icon,
    this.assetPath,
    this.route,
    this.action = GameMenuAction.navigate,
    this.accentColor,
    this.showBadge = false,
  });

  final String label;
  final IconData icon;
  final String? assetPath;
  final String? route;
  final GameMenuAction action;
  final Color? accentColor;
  final bool showBadge;
}

/// All quick-menu destinations (4-column grid). Labels from [l10n].
List<GameMenuItem> buildGameMenuItems(AppLocalizations l10n) => <GameMenuItem>[
  GameMenuItem(label: l10n.navHome, icon: Icons.home_rounded, assetPath: '${_MenuAssets.base}anasayfa.png', route: AppRoutes.home),
  GameMenuItem(label: l10n.navInventory, icon: Icons.inventory_2_rounded, assetPath: '${_MenuAssets.base}envanter.png', route: AppRoutes.inventory),
  GameMenuItem(label: l10n.navCharacter, icon: Icons.person_outline_rounded, assetPath: '${_MenuAssets.base}karakter.png', route: AppRoutes.character),
  GameMenuItem(label: l10n.navDungeon, icon: Icons.shield_moon_outlined, assetPath: '${_MenuAssets.base}zindan.png', route: AppRoutes.dungeon),
  GameMenuItem(label: l10n.routePvp, icon: Icons.sports_kabaddi_rounded, assetPath: '${_MenuAssets.base}pvp.png', route: AppRoutes.pvp),
  GameMenuItem(label: l10n.routeLeaderboard, icon: Icons.leaderboard_rounded, assetPath: '${_MenuAssets.base}siralama.png', route: AppRoutes.leaderboard),
  GameMenuItem(label: l10n.routeSeason, icon: Icons.ac_unit_rounded, assetPath: '${_MenuAssets.base}battlepass.png', route: AppRoutes.season),
  GameMenuItem(label: l10n.routeGuild, icon: Icons.groups_outlined, assetPath: '${_MenuAssets.base}lonca.png', route: AppRoutes.guild),
  GameMenuItem(label: l10n.routeGuildWar, icon: Icons.flag_outlined, assetPath: '${_MenuAssets.base}loncasavasi.png', route: AppRoutes.guildWar),
  GameMenuItem(label: l10n.menuMonument, icon: Icons.account_balance_outlined, assetPath: '${_MenuAssets.base}anit.png', route: AppRoutes.guildMonument),
  GameMenuItem(label: l10n.menuLoot, icon: Icons.casino_outlined, assetPath: '${_MenuAssets.base}kasaacma.png', route: AppRoutes.loot),
  GameMenuItem(label: l10n.routeMarket, icon: Icons.storefront_outlined, assetPath: '${_MenuAssets.base}pazar.png', route: AppRoutes.market),
  GameMenuItem(label: l10n.routeShop, icon: Icons.shopping_bag_outlined, assetPath: '${_MenuAssets.base}magaza.png', route: AppRoutes.shop),
  GameMenuItem(label: l10n.routeBank, icon: Icons.account_balance_wallet_outlined, assetPath: '${_MenuAssets.base}banka.png', route: AppRoutes.bank),
  GameMenuItem(label: l10n.routeTrade, icon: Icons.swap_horiz_rounded, assetPath: '${_MenuAssets.base}ticaret.png', route: AppRoutes.trade),
  GameMenuItem(label: l10n.routeCrafting, icon: Icons.handyman_outlined, assetPath: '${_MenuAssets.base}zanaat.png', route: AppRoutes.crafting),
  GameMenuItem(label: l10n.menuItemUpgrade, icon: Icons.auto_fix_high_outlined, assetPath: '${_MenuAssets.base}itemupgrade.png', route: AppRoutes.enhancement),
  GameMenuItem(label: l10n.routeFacilities, icon: Icons.factory_outlined, assetPath: '${_MenuAssets.base}tesis.png', route: AppRoutes.facilities),
  GameMenuItem(label: l10n.menuMekans, icon: Icons.location_city_outlined, assetPath: '${_MenuAssets.base}mekan.png', route: AppRoutes.mekans),
  GameMenuItem(label: l10n.menuQuests, icon: Icons.task_alt_rounded, assetPath: '${_MenuAssets.base}gorev.png', route: AppRoutes.quests),
  GameMenuItem(label: l10n.routeReputation, icon: Icons.handshake_outlined, route: AppRoutes.reputation),
  GameMenuItem(label: l10n.menuDailyReward, icon: Icons.card_giftcard_rounded, action: GameMenuAction.dailyReward, accentColor: _QuickMenuTheme.celestialGold),
  GameMenuItem(label: l10n.menuHospital, icon: Icons.local_hospital_outlined, assetPath: '${_MenuAssets.base}hastane.png', route: AppRoutes.hospital),
  GameMenuItem(label: l10n.menuPrison, icon: Icons.gavel_rounded, assetPath: '${_MenuAssets.base}hapishane.png', route: AppRoutes.prison),
  GameMenuItem(label: 'Arkadaşlar', icon: Icons.people_alt_outlined, route: AppRoutes.friends),
  GameMenuItem(label: l10n.menuChat, icon: Icons.chat_outlined, assetPath: '${_MenuAssets.base}sohbet.png', route: AppRoutes.chat, action: GameMenuAction.chat),
  GameMenuItem(label: l10n.menuSettings, icon: Icons.settings_outlined, assetPath: '${_MenuAssets.base}ayarlar.png', route: AppRoutes.settings),
  GameMenuItem(label: l10n.menuLogout, icon: Icons.logout_rounded, assetPath: '${_MenuAssets.base}cikis.png', action: GameMenuAction.logout, accentColor: AppColors.danger),
  GameMenuItem(label: l10n.routeHorseRace, icon: Icons.sports_motorsports_rounded, route: AppRoutes.horseRace, accentColor: _QuickMenuTheme.celestialGold),
  const GameMenuItem(label: '', icon: Icons.circle, action: GameMenuAction.none),
  const GameMenuItem(label: '', icon: Icons.circle, action: GameMenuAction.none),
];

List<String> kGameMenuLabelsTr() {
  final AppLocalizations l10n = lookupAppLocalizations(const Locale('tr'));
  return buildGameMenuItems(l10n)
      .where((GameMenuItem i) => i.action != GameMenuAction.none && i.label.isNotEmpty)
      .map((GameMenuItem i) => i.label)
      .toList(growable: false);
}

List<String> get kGameMenuLabels => kGameMenuLabelsTr();

double _panelBottomInset(BuildContext context) {
  const double safeMin = 10;
  const double stackHeight = 134;
  final double bottom = MediaQuery.paddingOf(context).bottom;
  return (bottom > safeMin ? bottom : safeMin) + stackHeight;
}

Future<void> showGameQuickMenu(
  BuildContext context, {
  Future<void> Function()? onLogout,
  required void Function(BuildContext context) onOpenChat,
}) {
  HapticFeedback.lightImpact();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.l10n.menuBarrier,
    barrierColor: Colors.black.withValues(alpha: 0.58),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (
      BuildContext ctx,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return _GameQuickMenuPanel(onLogout: onLogout, onOpenChat: onOpenChat);
    },
    transitionBuilder:
        (BuildContext ctx, Animation<double> anim, _, Widget child) {
          final Animation<Offset> slide = Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(position: slide, child: child),
          );
        },
  );
}

class _GameQuickMenuPanel extends ConsumerStatefulWidget {
  const _GameQuickMenuPanel({this.onLogout, required this.onOpenChat});

  final Future<void> Function()? onLogout;
  final void Function(BuildContext context) onOpenChat;

  @override
  ConsumerState<_GameQuickMenuPanel> createState() => _GameQuickMenuPanelState();
}

class _GameQuickMenuPanelState extends ConsumerState<_GameQuickMenuPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dailyRewardProvider.notifier).loadStatus();
      TutorialAnchorRegistry.instance.scheduleRefresh();
    });
    // After slide-in (~280ms) remeasure — first frame often mid-transition
    // → spotlight hole painted too low on menu tiles.
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      TutorialAnchorRegistry.instance.scheduleRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(playerProvider).profile;
    final bool canClaimDaily =
        ref.watch(dailyRewardProvider).status?.canClaim ?? false;
    final String displayName = profile == null
        ? context.l10n.playerDefault
        : ((profile.displayName ?? profile.username).trim().isEmpty
              ? profile.username
              : (profile.displayName ?? profile.username));
    final int level = profile?.level ?? 1;

    // Robust SafeArea & responsive bounds calculation
    final MediaQueryData media = MediaQuery.of(context);
    final EdgeInsets padding = media.padding;
    final double screenHeight = media.size.height;
    final double bottomInset = _panelBottomInset(context);

    // Ensure menu does not encroach on top notch / status bar / dynamic island
    final double topSafeLimit = padding.top + 18.0;
    final double maxUsableHeight = screenHeight - bottomInset - topSafeLimit;
    final double maxHeight = maxUsableHeight.clamp(240.0, screenHeight * 0.58);

    // Horizontal margins respecting device cutouts / bezels
    final double horizontalMargin = math.max(12.0, math.max(padding.left, padding.right) + 8.0);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: <Widget>[
          // Obsidian ethereal blurred backdrop
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop();
              },
              behavior: HitTestBehavior.opaque,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: _QuickMenuTheme.obsidianVoid.withValues(alpha: 0.52),
                ),
              ),
            ),
          ),
          // Floating 2027 Aion 2 Obsidian-Glass Card
          Positioned(
            left: horizontalMargin,
            right: horizontalMargin,
            bottom: bottomInset,
            child: Container(
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
                boxShadow: <BoxShadow>[
                  // Celestial Gold top crest luminescence
                  BoxShadow(
                    color: _QuickMenuTheme.celestialGold.withValues(alpha: 0.12),
                    blurRadius: 28,
                    spreadRadius: -1,
                    offset: const Offset(0, -3),
                  ),
                  // Ether Cyan ambient mana aura
                  BoxShadow(
                    color: _QuickMenuTheme.etherCyan.withValues(alpha: 0.09),
                    blurRadius: 32,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                  // Deep obsidian occlusion shadow
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.72),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
                child: BackdropFilter(
                  // 2027 Aion 2 standard sigmaX: 16, sigmaY: 16
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Color(0xF0101522), // Obsidian Surface Highlight
                          Color(0xF50B0E14), // Obsidian Deep Core
                          Color(0xFA07090E), // Obsidian Void Base
                        ],
                        stops: <double>[0.0, 0.45, 1.0],
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusXxl)),
                    ),
                    child: CustomPaint(
                      foregroundPainter: const _Aion2LuminousBorderPainter(
                        borderRadius: AppSpacing.radiusXxl,
                        borderWidth: 1.2,
                      ),
                      child: SafeArea(
                        top: false,
                        bottom: false,
                        left: true,
                        right: true,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const SizedBox(height: 8),
                            // Handle pill with celestial gold and ether cyan gradient luminescence
                            Center(
                              child: Container(
                                width: 38,
                                height: 4,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: <Color>[
                                      Color(0x6600E5FF),
                                      _QuickMenuTheme.celestialGold,
                                      Color(0x6600E5FF),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: _QuickMenuTheme.celestialGold.withValues(alpha: 0.35),
                                      blurRadius: 6,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                              child: _MenuProfileStrip(
                                displayName: displayName,
                                level: level,
                                profile: profile,
                              ),
                            ),
                            Flexible(
                              child: NotificationListener<ScrollNotification>(
                                onNotification: (ScrollNotification n) {
                                  if (n is ScrollUpdateNotification ||
                                      n is ScrollEndNotification) {
                                    TutorialAnchorRegistry.instance
                                        .scheduleRefresh();
                                  }
                                  return false;
                                },
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
                                  child: _MenuGrid(
                                    onLogout: widget.onLogout,
                                    onOpenChat: widget.onOpenChat,
                                    canClaimDaily: canClaimDaily,
                                  ),
                                ),
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
          ),
        ],
      ),
    );
  }
}

/// Custom painter rendering 2027 Aion 2 dual-luminescence border:
/// Celestial gold (#E5C158) + Ether cyan (#00E5FF) with top specular crystalline sheen.
class _Aion2LuminousBorderPainter extends CustomPainter {
  const _Aion2LuminousBorderPainter({
    required this.borderRadius,
    this.borderWidth = 1.2,
  });

  final double borderRadius;
  final double borderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Rect rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(
      rect.deflate(borderWidth / 2),
      Radius.circular(borderRadius),
    );

    // Multi-stop Celestial Gold & Ether Cyan luminescence border gradient
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0x8CE5C158), // Celestial gold luminescence crest
          Color(0x6600E5FF), // Ether cyan luminescence shoulder
          Color(0x26101522), // Obsidian glass body blend
          Color(0x40E5C158), // Celestial gold subtle rim
        ],
        stops: <double>[0.0, 0.32, 0.70, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, borderPaint);

    // Specular crystalline glare line along top edge
    final Paint specularPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = const LinearGradient(
        colors: <Color>[
          Colors.transparent,
          Color(0x80FFFFFF),
          Color(0xB3E5C158),
          Color(0x8000E5FF),
          Colors.transparent,
        ],
        stops: <double>[0.05, 0.30, 0.50, 0.70, 0.95],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 2));

    final Path topPath = Path()
      ..moveTo(borderRadius, borderWidth / 2)
      ..lineTo(size.width - borderRadius, borderWidth / 2);

    canvas.drawPath(topPath, specularPaint);
  }

  @override
  bool shouldRepaint(covariant _Aion2LuminousBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.borderWidth != borderWidth;
  }
}

class _MenuProfileStrip extends StatelessWidget {
  const _MenuProfileStrip({
    required this.displayName,
    required this.level,
    required this.profile,
  });

  final String displayName;
  final int level;
  final PlayerProfile? profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            _QuickMenuTheme.obsidianSurface.withValues(alpha: 0.82),
            _QuickMenuTheme.obsidianDeep.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: _QuickMenuTheme.celestialGold.withValues(alpha: 0.28),
          width: 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _QuickMenuTheme.celestialGold.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: _QuickMenuTheme.etherCyan.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          ProfileAvatar(
            size: 40,
            avatarUrl: profile?.avatarUrl,
            backgroundColor: _QuickMenuTheme.celestialGold.withValues(alpha: 0.18),
            glowFrame: profile?.avatarFrame == 'glow',
            codexFrame: profile?.avatarFrame == 'codex',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleBold.copyWith(
                    fontSize: 14,
                    color: Colors.white,
                    letterSpacing: 0.2,
                    shadows: const <Shadow>[
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                if (profile?.username.isNotEmpty ?? false)
                  Text(
                    '@${profile!.username}',
                    style: AppTextStyles.caption.copyWith(
                      color: _QuickMenuTheme.etherCyan.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              gradient: LinearGradient(
                colors: <Color>[
                  _QuickMenuTheme.celestialGold.withValues(alpha: 0.22),
                  _QuickMenuTheme.etherCyan.withValues(alpha: 0.10),
                ],
              ),
              border: Border.all(
                color: _QuickMenuTheme.celestialGold.withValues(alpha: 0.55),
                width: 1.0,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _QuickMenuTheme.celestialGold.withValues(alpha: 0.22),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Text(
              'Lv.$level',
              style: AppTextStyles.captionBold.copyWith(
                color: _QuickMenuTheme.celestialGold,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuGrid extends ConsumerWidget {
  const _MenuGrid({
    this.onLogout,
    required this.onOpenChat,
    required this.canClaimDaily,
  });

  final Future<void> Function()? onLogout;
  final void Function(BuildContext context) onOpenChat;
  final bool canClaimDaily;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isStaff = ref.watch(staffProvider).profile.isStaff;
    final List<GameMenuItem> menuItems = <GameMenuItem>[
      ...buildGameMenuItems(context.l10n),
      if (isStaff)
        const GameMenuItem(
          label: 'Staff',
          icon: Icons.admin_panel_settings,
          route: AppRoutes.staffHub,
          accentColor: _QuickMenuTheme.celestialGold,
        ),
    ];
    return GameFixedGrid(
      crossAxisCount: 4,
      spacing: 8,
      itemCount: menuItems.length,
      itemBuilder: (BuildContext context, int index) {
        final GameMenuItem item = menuItems[index];
        if (item.action == GameMenuAction.none) {
          return const SizedBox.shrink();
        }
        Widget tile = _MenuTile(
          item: item.action == GameMenuAction.dailyReward
              ? GameMenuItem(
                  label: item.label,
                  icon: item.icon,
                  assetPath: item.assetPath,
                  action: item.action,
                  accentColor: item.accentColor,
                  showBadge: canClaimDaily,
                )
              : item,
          onTap: () => _handleTap(context, ref, item),
        );
        final String? menuAnchor = TutorialQuickMenuAnchors.anchorForRoute(
          item.route,
        );
        if (menuAnchor != null) {
          tile = TutorialAnchorScope(id: menuAnchor, child: tile);
        }
        return tile;
      },
    );
  }

  Future<void> _handleTap(
    BuildContext context,
    WidgetRef ref,
    GameMenuItem item,
  ) async {
    final TutorialController tutorialCtrl = ref.read(tutorialProvider.notifier);
    final TutorialStepV2? activeStep = ref.read(tutorialProvider).activeStep;
    final String? requiredAnchor = activeStep?.anchorId;
    if (TutorialQuickMenuAnchors.isMenuItemAnchor(requiredAnchor)) {
      final String? tappedAnchor = TutorialQuickMenuAnchors.anchorForRoute(
        item.route,
      );
      if (tappedAnchor != requiredAnchor) {
        HapticFeedback.mediumImpact();
        tutorialCtrl.registerWrongTap();
        return;
      }
      await tutorialCtrl.onAnchorTap(requiredAnchor!);
      if (!context.mounted) return;
    }

    if (item.action == GameMenuAction.navigate) {
      final String? route = item.route;
      if (route != null && tutorialCtrl.blocksNavigation(route)) {
        HapticFeedback.mediumImpact();
        tutorialCtrl.registerWrongTap();
        return;
      }
    }

    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    switch (item.action) {
      case GameMenuAction.chat:
        onOpenChat(context);
      case GameMenuAction.logout:
        if (onLogout != null) {
          await onLogout!();
        }
      case GameMenuAction.dailyReward:
        await showDailyRewardDialog(context, ref, viewOnly: false);
      case GameMenuAction.navigate:
        final String? route = item.route;
        if (route == null) return;
        if (route == AppRoutes.home) {
          context.go(route);
        } else {
          context.push(route);
        }
      case GameMenuAction.none:
        break;
    }
  }
}

class _MenuTile extends StatefulWidget {
  const _MenuTile({required this.item, required this.onTap});

  final GameMenuItem item;
  final VoidCallback onTap;

  @override
  State<_MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<_MenuTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool hasAccent = widget.item.accentColor != null;
    final Color effectiveAccent = widget.item.accentColor ?? Colors.white;

    return Semantics(
      button: true,
      label: widget.item.label,
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          setState(() => _pressed = true);
        },
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _pressed ? 0.85 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: <Widget>[
                    // Subtle luminescence underglow on press or for accented items
                    if (_pressed || hasAccent)
                      Positioned(
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: (_pressed
                                        ? _QuickMenuTheme.etherCyan
                                        : effectiveAccent)
                                    .withValues(alpha: _pressed ? 0.28 : 0.16),
                                blurRadius: _pressed ? 16 : 12,
                                spreadRadius: _pressed ? 2 : 0,
                              ),
                            ],
                          ),
                        ),
                      ),
                    _MenuIcon(item: widget.item),
                    if (widget.item.showBadge)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: <Color>[
                                Color(0xFFFF5252),
                                AppColors.danger,
                              ],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x80FF1744),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  widget.item.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.micro.copyWith(
                    color: widget.item.accentColor ?? Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    letterSpacing: 0.1,
                    shadows: widget.item.accentColor == null
                        ? const <Shadow>[
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : <Shadow>[
                            Shadow(
                              color: widget.item.accentColor!.withValues(alpha: 0.5),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
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

/// Bare asset — PNG already has gold frame; no extra socket/shadow layers.
/// Non-asset icons are embedded in an obsidian glass circular bezel with ethereal luminescence.
class _MenuIcon extends StatelessWidget {
  const _MenuIcon({required this.item});

  final GameMenuItem item;

  static const double _size = 64;

  /// Unified soft drop shadow — same for every menu icon.
  static const double _shadowOpacity = 0.32;
  static const double _shadowBlur = 8.0;
  static const double _shadowOffsetY = 4.0;

  @override
  Widget build(BuildContext context) {
    final bool isLogout = item.action == GameMenuAction.logout;

    if (item.assetPath == null) {
      final Color iconColor = isLogout
          ? AppColors.danger
          : (item.accentColor ?? _QuickMenuTheme.etherCyan);

      return Container(
        width: 50,
        height: 50,
        margin: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              _QuickMenuTheme.obsidianSurface.withValues(alpha: 0.95),
              _QuickMenuTheme.obsidianVoid.withValues(alpha: 0.95),
            ],
          ),
          border: Border.all(
            color: iconColor.withValues(alpha: 0.40),
            width: 1.2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: iconColor.withValues(alpha: 0.20),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
            const BoxShadow(
              color: Colors.black54,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            item.icon,
            size: 26,
            color: iconColor,
            shadows: <Shadow>[
              Shadow(
                color: iconColor.withValues(alpha: 0.6),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          Transform.translate(
            offset: const Offset(0, _shadowOffsetY),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: _shadowBlur,
                sigmaY: _shadowBlur,
              ),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: _shadowOpacity),
                  BlendMode.srcIn,
                ),
                child: Image.asset(
                  item.assetPath!,
                  width: _size,
                  height: _size,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                  errorBuilder: (_, Object error, StackTrace? stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          Image.asset(
            item.assetPath!,
            width: _size,
            height: _size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            errorBuilder: (_, Object error, StackTrace? stackTrace) => Icon(
              item.icon,
              size: 36,
              color: isLogout ? AppColors.danger : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
