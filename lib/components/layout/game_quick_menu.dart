import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/player_model.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../common/profile_avatar.dart';

/// Premium palette — quick menu only (does not affect global chrome).
abstract final class _QuickMenuTheme {
  /// Matte vignette background — muted teal-gray center, charcoal edges.
  static const Color bgHighlight = Color(0xFF232D31);
  static const Color bgMid = Color(0xFF1A2428);
  static const Color bgDeep = Color(0xFF0D1112);
  static const Color bgEdge = Color(0xFF0A0C0D);

  static const Color panelBorder = Color(0x40232D31);
  static const Color gold = Color(0xFFF5C842);
}

abstract final class _MenuAssets {
  static const String base = 'assets/menuitems/';
}

enum GameMenuAction { navigate, chat, logout, none }

class GameMenuItem {
  const GameMenuItem({
    required this.label,
    required this.icon,
    this.assetPath,
    this.route,
    this.action = GameMenuAction.navigate,
    this.accentColor,
  });

  final String label;
  final IconData icon;
  final String? assetPath;
  final String? route;
  final GameMenuAction action;
  final Color? accentColor;
}

/// All quick-menu destinations (4-column grid).
const List<GameMenuItem> kGameMenuItems = <GameMenuItem>[
  GameMenuItem(
    label: 'Ana Sayfa',
    icon: Icons.home_rounded,
    assetPath: '${_MenuAssets.base}anasayfa.png',
    route: AppRoutes.home,
  ),
  GameMenuItem(
    label: 'Envanter',
    icon: Icons.inventory_2_rounded,
    assetPath: '${_MenuAssets.base}envanter.png',
    route: AppRoutes.inventory,
  ),
  GameMenuItem(
    label: 'Karakter',
    icon: Icons.person_outline_rounded,
    assetPath: '${_MenuAssets.base}karakter.png',
    route: AppRoutes.character,
  ),
  GameMenuItem(
    label: 'Zindan',
    icon: Icons.shield_moon_outlined,
    assetPath: '${_MenuAssets.base}zindan.png',
    route: AppRoutes.dungeon,
  ),
  GameMenuItem(
    label: 'PvP',
    icon: Icons.sports_kabaddi_rounded,
    assetPath: '${_MenuAssets.base}pvp.png',
    route: AppRoutes.pvp,
  ),
  GameMenuItem(
    label: 'Sıralama',
    icon: Icons.leaderboard_rounded,
    assetPath: '${_MenuAssets.base}siralama.png',
    route: AppRoutes.leaderboard,
  ),
  GameMenuItem(
    label: 'Battle Pass',
    icon: Icons.ac_unit_rounded,
    assetPath: '${_MenuAssets.base}battlepass.png',
    route: AppRoutes.season,
  ),
  GameMenuItem(
    label: 'Lonca',
    icon: Icons.groups_outlined,
    assetPath: '${_MenuAssets.base}lonca.png',
    route: AppRoutes.guild,
  ),
  GameMenuItem(
    label: 'Lonca Savaşı',
    icon: Icons.flag_outlined,
    assetPath: '${_MenuAssets.base}loncasavasi.png',
    route: AppRoutes.guildWar,
  ),
  GameMenuItem(
    label: 'Anıt',
    icon: Icons.account_balance_outlined,
    assetPath: '${_MenuAssets.base}anit.png',
    route: AppRoutes.guildMonument,
  ),
  GameMenuItem(
    label: 'Kasa Acma',
    icon: Icons.casino_outlined,
    assetPath: '${_MenuAssets.base}kasaacma.png',
    route: AppRoutes.loot,
  ),
  GameMenuItem(
    label: 'Pazar',
    icon: Icons.storefront_outlined,
    assetPath: '${_MenuAssets.base}pazar.png',
    route: AppRoutes.market,
  ),
  GameMenuItem(
    label: 'Mağaza',
    icon: Icons.shopping_bag_outlined,
    assetPath: '${_MenuAssets.base}magaza.png',
    route: AppRoutes.shop,
  ),
  GameMenuItem(
    label: 'Banka',
    icon: Icons.account_balance_wallet_outlined,
    assetPath: '${_MenuAssets.base}banka.png',
    route: AppRoutes.bank,
  ),
  GameMenuItem(
    label: 'Ticaret',
    icon: Icons.swap_horiz_rounded,
    assetPath: '${_MenuAssets.base}ticaret.png',
    route: AppRoutes.trade,
  ),
  GameMenuItem(
    label: 'Zanaat',
    icon: Icons.handyman_outlined,
    assetPath: '${_MenuAssets.base}zanaat.png',
    route: AppRoutes.crafting,
  ),
  GameMenuItem(
    label: 'Item Upgrade',
    icon: Icons.auto_fix_high_outlined,
    assetPath: '${_MenuAssets.base}itemupgrade.png',
    route: AppRoutes.enhancement,
  ),
  GameMenuItem(
    label: 'Tesisler',
    icon: Icons.factory_outlined,
    assetPath: '${_MenuAssets.base}tesis.png',
    route: AppRoutes.facilities,
  ),
  GameMenuItem(
    label: 'Mekanlar',
    icon: Icons.location_city_outlined,
    assetPath: '${_MenuAssets.base}mekan.png',
    route: AppRoutes.mekans,
  ),
  GameMenuItem(
    label: 'Görevler',
    icon: Icons.task_alt_rounded,
    assetPath: '${_MenuAssets.base}gorev.png',
    route: AppRoutes.quests,
  ),
  GameMenuItem(
    label: 'Hastane',
    icon: Icons.local_hospital_outlined,
    assetPath: '${_MenuAssets.base}hastane.png',
    route: AppRoutes.hospital,
  ),
  GameMenuItem(
    label: 'Hapishane',
    icon: Icons.gavel_rounded,
    assetPath: '${_MenuAssets.base}hapishane.png',
    route: AppRoutes.prison,
  ),
  GameMenuItem(
    label: 'Sohbet',
    icon: Icons.chat_outlined,
    assetPath: '${_MenuAssets.base}sohbet.png',
    route: AppRoutes.chat,
    action: GameMenuAction.chat,
  ),
  GameMenuItem(
    label: 'Ayarlar',
    icon: Icons.settings_outlined,
    assetPath: '${_MenuAssets.base}ayarlar.png',
    route: AppRoutes.settings,
  ),
  GameMenuItem(
    label: 'Çıkış Yap',
    icon: Icons.logout_rounded,
    assetPath: '${_MenuAssets.base}cikis.png',
    action: GameMenuAction.logout,
    accentColor: AppColors.danger,
  ),
  GameMenuItem(label: '', icon: Icons.circle, action: GameMenuAction.none),
  GameMenuItem(label: '', icon: Icons.circle, action: GameMenuAction.none),
  GameMenuItem(label: '', icon: Icons.circle, action: GameMenuAction.none),
];

/// Labels for smoke tests — non-empty menu entries only.
List<String> get kGameMenuLabels => kGameMenuItems
    .where(
      (GameMenuItem i) => i.action != GameMenuAction.none && i.label.isNotEmpty,
    )
    .map((GameMenuItem i) => i.label)
    .toList();

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
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Menü',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (BuildContext ctx, _, __) {
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

class _GameQuickMenuPanel extends ConsumerWidget {
  const _GameQuickMenuPanel({this.onLogout, required this.onOpenChat});

  final Future<void> Function()? onLogout;
  final void Function(BuildContext context) onOpenChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(playerProvider).profile;
    final String displayName = profile == null
        ? 'Oyuncu'
        : ((profile.displayName ?? profile.username).trim().isEmpty
              ? profile.username
              : (profile.displayName ?? profile.username));
    final int level = profile?.level ?? 1;
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.55;
    final double bottomInset = _panelBottomInset(context);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: _QuickMenuTheme.bgEdge.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: bottomInset,
            child: Container(
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: _QuickMenuTheme.bgHighlight.withValues(alpha: 0.18),
                    blurRadius: 28,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: _QuickMenuTheme.bgEdge.withValues(alpha: 0.65),
                    blurRadius: 36,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topCenter,
                        radius: 1.35,
                        colors: <Color>[
                          _QuickMenuTheme.bgHighlight.withValues(alpha: 0.96),
                          _QuickMenuTheme.bgMid.withValues(alpha: 0.98),
                          _QuickMenuTheme.bgDeep,
                          _QuickMenuTheme.bgEdge,
                        ],
                        stops: const <double>[0.0, 0.38, 0.72, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
                      border: Border.all(
                        color: _QuickMenuTheme.panelBorder,
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const SizedBox(height: 5),
                        Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _QuickMenuTheme.bgHighlight.withValues(
                              alpha: 0.45,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                          child: _MenuProfileStrip(
                            displayName: displayName,
                            level: level,
                            profile: profile,
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                            child: _MenuGrid(
                              onLogout: onLogout,
                              onOpenChat: onOpenChat,
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
        ],
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            _QuickMenuTheme.bgHighlight.withValues(alpha: 0.55),
            _QuickMenuTheme.bgDeep.withValues(alpha: 0.35),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: _QuickMenuTheme.bgHighlight.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: <Widget>[
          ProfileAvatar(
            size: 40,
            avatarUrl: profile?.avatarUrl,
            backgroundColor: _QuickMenuTheme.gold.withValues(alpha: 0.2),
            glowFrame: profile?.avatarFrame == 'glow',
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
                  ),
                ),
                if (profile?.username.isNotEmpty ?? false)
                  Text(
                    '@${profile!.username}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              color: _QuickMenuTheme.gold.withValues(alpha: 0.12),
              border: Border.all(
                color: _QuickMenuTheme.gold.withValues(alpha: 0.4),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _QuickMenuTheme.gold.withValues(alpha: 0.15),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Text(
              'Lv.$level',
              style: AppTextStyles.captionBold.copyWith(
                color: _QuickMenuTheme.gold,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({this.onLogout, required this.onOpenChat});

  final Future<void> Function()? onLogout;
  final void Function(BuildContext context) onOpenChat;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 8,
        childAspectRatio: 0.78,
      ),
      itemCount: kGameMenuItems.length,
      itemBuilder: (BuildContext context, int index) {
        final GameMenuItem item = kGameMenuItems[index];
        if (item.action == GameMenuAction.none) {
          return const SizedBox.shrink();
        }
        return _MenuTile(item: item, onTap: () => _handleTap(context, item));
      },
    );
  }

  Future<void> _handleTap(BuildContext context, GameMenuItem item) async {
    Navigator.of(context).pop();
    switch (item.action) {
      case GameMenuAction.chat:
        onOpenChat(context);
      case GameMenuAction.logout:
        if (onLogout != null) {
          await onLogout!();
        }
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
    return Semantics(
      button: true,
      label: widget.item.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _pressed ? 0.88 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _MenuIcon(item: widget.item),
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
                        ? <Shadow>[
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
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
class _MenuIcon extends StatelessWidget {
  const _MenuIcon({required this.item});

  final GameMenuItem item;

  static const double _size = 64;

  /// Unified soft drop shadow — same for every menu icon.
  static const double _shadowOpacity = 0.30;
  static const double _shadowBlur = 8.0;
  static const double _shadowOffsetY = 4.0;

  @override
  Widget build(BuildContext context) {
    final bool isLogout = item.action == GameMenuAction.logout;

    if (item.assetPath == null) {
      return Icon(
        item.icon,
        size: 36,
        color: isLogout ? AppColors.danger : Colors.white,
        shadows: const <Shadow>[
          Shadow(
            color: Color(0x99000000),
            blurRadius: _shadowBlur,
            offset: Offset(0, _shadowOffsetY),
          ),
        ],
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
