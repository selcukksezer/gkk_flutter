import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../providers/live_ticker_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/logout_helper.dart';
import 'models/announcement_models.dart';
import 'services/announcements_repository.dart';
import 'widgets/announcement_card.dart';
import 'widgets/hero_banner_carousel.dart';

/// 2027 Aion 2 Mobile Standard Announcements & Events Portal.
///
/// Features:
/// - Hero banner carousel with animated gradient borders and page indicator.
/// - Rich patch notes / event details markdown/styled content viewer.
/// - Active event countdown timer pill with pulsing status indicator.
/// - One-tap "Claim Event Gift" button with reward claim feedback.
/// - Responsive mobile safe area (390x844) with obsidian frosted glass styling.
/// - Multi-tier HapticFeedback on tabs, back navigation, and refresh actions.
/// - Preserved announcement data fetching and read-tracking logic.
class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  static const List<_FilterTab> _filterTabs = <_FilterTab>[
    _FilterTab(key: 'all', label: 'Tümü', icon: Icons.all_inclusive_rounded),
    _FilterTab(key: 'unread', label: 'Okunmamış', icon: Icons.mark_email_unread_rounded),
    _FilterTab(key: 'event', label: 'Etkinlikler', icon: Icons.sports_kabaddi_rounded),
    _FilterTab(key: 'patchNotes', label: 'Yama Notları', icon: Icons.auto_stories_rounded),
    _FilterTab(key: 'server', label: 'Canlı Sunucu', icon: Icons.sensors_rounded),
  ];

  String _filter = 'all';
  bool _isManualRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(liveTickerProvider.notifier).loadArchive();
      ref.read(announcementsRepositoryProvider).init();
    });
  }

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    setState(() => _isManualRefreshing = true);
    try {
      await ref.read(liveTickerProvider.notifier).loadArchive();
      await ref.read(announcementsRepositoryProvider).init();
      HapticFeedback.selectionClick();
    } finally {
      if (mounted) {
        setState(() => _isManualRefreshing = false);
      }
    }
  }

  void _goBack(BuildContext context) {
    HapticFeedback.lightImpact();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final LiveTickerState ticker = ref.watch(liveTickerProvider);
    final AnnouncementsRepository repo = ref.watch(announcementsRepositoryProvider);

    final List<AnnouncementItem> allItems = repo.getMergedAnnouncements(
      tickerArchive: ticker.feedArchive,
      filter: _filter,
    );

    final List<AnnouncementItem> heroBanners = repo.getMergedAnnouncements(
      tickerArchive: ticker.feedArchive,
      filter: 'all',
    ).where((AnnouncementItem item) => item.isHeroBanner).toList();

    final int unreadCount = repo.getUnreadCount(repo.getMergedAnnouncements(
      tickerArchive: ticker.feedArchive,
      filter: 'all',
    ));

    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isCompact = screenWidth < 390;
    final double horizPad = isCompact ? 12.0 : AppSpacing.base;
    final double bottomClearance = gameBottomBarClearance(context) + AppSpacing.md;

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          _goBack(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.carbonVoid,
        appBar: GameTopBar(
          title: 'Duyurular & Etkinlikler',
          onLogout: () => performLogout(ref),
        ),
        extendBody: true,
        bottomNavigationBar: GameBottomBar(
          currentRoute: AppRoutes.announcements,
          onLogout: () => performLogout(ref),
        ),
        body: GameScreenBackground(
          child: SafeArea(
            top: false,
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  children: <Widget>[
                    // 1. Obsidian Frosted Glass Utility / Navigation Bar
                    _buildTopUtilityBar(
                      context: context,
                      unreadCount: unreadCount,
                      allItems: allItems,
                      isRefreshing: _isManualRefreshing,
                      horizPad: horizPad,
                      isCompact: isCompact,
                    ),

                    // 2. Smooth Scrollable Content View
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refresh,
                        color: AppColors.liquidGold,
                        backgroundColor: AppColors.spaceNavy,
                        displacement: 28,
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          slivers: <Widget>[
                            const SliverToBoxAdapter(
                              child: SizedBox(height: AppSpacing.xs),
                            ),

                            // Hero Banner Carousel
                            if (heroBanners.isNotEmpty) ...<Widget>[
                              SliverToBoxAdapter(
                                child: HeroBannerCarousel(banners: heroBanners),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: AppSpacing.sm),
                              ),
                            ],

                            // Filter Navigation Chips
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height: 38,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: horizPad,
                                  ),
                                  itemCount: _filterTabs.length,
                                  separatorBuilder: (_, int index) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (BuildContext context, int index) {
                                    final _FilterTab tab = _filterTabs[index];
                                    final bool isSelected = _filter == tab.key;
                                    return _buildFilterChip(
                                      tab: tab,
                                      isSelected: isSelected,
                                      unreadCount: unreadCount,
                                      onTap: () {
                                        setState(() => _filter = tab.key);
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),

                            const SliverToBoxAdapter(
                              child: SizedBox(height: AppSpacing.sm),
                            ),

                            // Section Header with Luminous Gold Accent
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: horizPad,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x550A0F1D),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.liquidGold
                                          .withValues(alpha: 0.18),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Container(
                                        width: 3,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: AppColors.liquidGold,
                                          borderRadius: BorderRadius.circular(2),
                                          boxShadow: <BoxShadow>[
                                            BoxShadow(
                                              color: AppColors.liquidGold
                                                  .withValues(alpha: 0.6),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _getSectionTitle(_filter),
                                        style: const TextStyle(
                                          color: AppColors.liquidGold,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.spaceNavy
                                              .withValues(alpha: 0.6),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.white12,
                                          ),
                                        ),
                                        child: Text(
                                          '${allItems.length} Bildirim',
                                          style: const TextStyle(
                                            color: AppColors.mutedTitanium,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SliverToBoxAdapter(
                              child: SizedBox(height: AppSpacing.sm),
                            ),

                            // Loading State
                            if (ticker.archiveLoading && allItems.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    bottom: bottomClearance,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.liquidGold,
                                    ),
                                  ),
                                ),
                              )
                            // Empty State
                            else if (allItems.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    bottom: bottomClearance,
                                  ),
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(
                                        AppSpacing.xl,
                                      ),
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          maxWidth: 340,
                                        ),
                                        padding: const EdgeInsets.all(
                                          AppSpacing.xl,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xCC0D1424),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: AppColors.liquidGold
                                                .withValues(alpha: 0.25),
                                          ),
                                          boxShadow: <BoxShadow>[
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 16,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            Container(
                                              width: 68,
                                              height: 68,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AppColors.spaceNavy
                                                    .withValues(alpha: 0.8),
                                                border: Border.all(
                                                  color: AppColors.liquidGold
                                                      .withValues(alpha: 0.4),
                                                  width: 1.5,
                                                ),
                                                boxShadow: <BoxShadow>[
                                                  BoxShadow(
                                                    color: AppColors.liquidGold
                                                        .withValues(alpha: 0.2),
                                                    blurRadius: 16,
                                                  ),
                                                ],
                                              ),
                                              alignment: Alignment.center,
                                              child: const Text(
                                                '🌌',
                                                style: TextStyle(fontSize: 30),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              _filter == 'unread'
                                                  ? 'Tüm Bildirimler Okundu'
                                                  : 'Henüz Bildirim Yok',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: AppColors.liquidGold,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              ticker.error ??
                                                  (_filter == 'unread'
                                                      ? 'Harika! Okunmamış duyuru veya etkinlik kalmadı.'
                                                      : 'Bu kategoride şu anda listelenecek bir duyuru bulunmuyor.'),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 12.5,
                                                height: 1.4,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            OutlinedButton.icon(
                                              onPressed: _refresh,
                                              icon: const Icon(
                                                Icons.refresh_rounded,
                                                size: 16,
                                              ),
                                              label: const Text('Akışı Yenile'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    AppColors.liquidGold,
                                                side: BorderSide(
                                                  color: AppColors.liquidGold
                                                      .withValues(alpha: 0.6),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 18,
                                                  vertical: 10,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            // List of Modern Announcement Cards
                            else
                              SliverPadding(
                                padding: EdgeInsets.fromLTRB(
                                  horizPad,
                                  0,
                                  horizPad,
                                  bottomClearance,
                                ),
                                sliver: SliverList.separated(
                                  itemCount: allItems.length,
                                  separatorBuilder: (_, int index) =>
                                      const SizedBox(height: 10),
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    final AnnouncementItem item = allItems[index];
                                    return AnnouncementCard(
                                      key: ValueKey<String>(
                                        'announcement_${item.id}',
                                      ),
                                      item: item,
                                    );
                                  },
                                ),
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
        ),
      ),
    );
  }

  /// Top Utility & Navigation Bar in Obsidian Frosted Glass with Celestial Gold Trims.
  Widget _buildTopUtilityBar({
    required BuildContext context,
    required int unreadCount,
    required List<AnnouncementItem> allItems,
    required bool isRefreshing,
    required double horizPad,
    required bool isCompact,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(horizPad, AppSpacing.xs, horizPad, AppSpacing.xs),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 10 : 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xCC0D1322),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.liquidGold.withValues(alpha: 0.3),
                width: 1.0,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: AppColors.liquidGold.withValues(alpha: 0.08),
                  blurRadius: 12,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                // Back Button with Haptic feedback
                _buildBackButton(context, isCompact),
                const Spacer(),
                // Mark All Read Button
                if (unreadCount > 0) ...<Widget>[
                  _buildMarkAllAsReadButton(allItems, isCompact),
                  const SizedBox(width: 8),
                ],
                // Quick Refresh Button
                _buildQuickRefreshButton(isRefreshing),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context, bool isCompact) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _goBack(context),
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 8 : 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: AppColors.spaceNavy.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.liquidGold.withValues(alpha: 0.45),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 13,
                color: AppColors.liquidGold,
              ),
              const SizedBox(width: 5),
              Text(
                'Geri',
                style: TextStyle(
                  color: AppColors.liquidGold,
                  fontSize: isCompact ? 11.5 : 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarkAllAsReadButton(
    List<AnnouncementItem> allItems,
    bool isCompact,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          HapticFeedback.mediumImpact();
          final List<String> allIds = allItems.map((e) => e.id).toList();
          await ref
              .read(announcementsControllerProvider.notifier)
              .markAllAsRead(allIds);
          if (mounted) setState(() {});
        },
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 8 : 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: AppColors.accentCyan.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.accentCyan.withValues(alpha: 0.5),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.done_all_rounded,
                size: 14,
                color: AppColors.accentCyan,
              ),
              const SizedBox(width: 5),
              Text(
                'Tümünü Oku',
                style: TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: isCompact ? 11 : 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickRefreshButton(bool isRefreshing) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isRefreshing ? null : _refresh,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.spaceNavy.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.liquidGold.withValues(alpha: 0.3),
              width: 1.0,
            ),
          ),
          child: isRefreshing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.liquidGold,
                  ),
                )
              : const Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: AppColors.liquidGold,
                ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required _FilterTab tab,
    required bool isSelected,
    required int unreadCount,
    required VoidCallback onTap,
  }) {
    final String label = tab.key == 'unread' && unreadCount > 0
        ? '${tab.label} ($unreadCount)'
        : tab.label;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.liquidGold.withValues(alpha: 0.18)
                : const Color(0x77101626),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.liquidGold.withValues(alpha: 0.8)
                  : Colors.white12,
              width: isSelected ? 1.2 : 1.0,
            ),
            boxShadow: isSelected
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.liquidGold.withValues(alpha: 0.22),
                      blurRadius: 10,
                      spreadRadius: -1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                tab.icon,
                size: 14,
                color: isSelected
                    ? AppColors.liquidGold
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getSectionTitle(String filter) {
    switch (filter) {
      case 'unread':
        return 'OKUNMAMIŞ BİLDİRİMLER';
      case 'event':
        return 'ÖZEL ETKİNLİKLER & ÖDÜLLER';
      case 'patchNotes':
        return 'GÜNCELLEME VE YAMA NOTLARI';
      case 'server':
        return 'CANLI SUNUCU YAYINI';
      case 'all':
      default:
        return 'GÜNCEL AKIŞ & BİLDİRİMLER';
    }
  }
}

class _FilterTab {
  const _FilterTab({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}
