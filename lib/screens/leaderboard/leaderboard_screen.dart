import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../l10n/l10n.dart';
import '../../models/leaderboard_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leaderboard_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import 'widgets/leaderboard_design.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  List<LeaderboardEntry> _filtered = <LeaderboardEntry>[];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
    );
    _searchCtrl.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(leaderboardProvider.notifier).load();
      if (mounted) {
        _animCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchDebounce = null;
    _searchCtrl
      ..removeListener(_onSearchChanged)
      ..dispose();
    _scrollController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final String trimmed = _searchCtrl.text.trim();
    if (trimmed.isEmpty) {
      if (_searchQuery.isNotEmpty && mounted) {
        setState(() {
          _searchQuery = '';
          _filtered = const <LeaderboardEntry>[];
        });
      }
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        _applyFilter();
      }
    });
  }

  void _applyFilter() {
    if (!mounted) return;
    final LeaderboardState boardState = ref.read(leaderboardProvider);
    final String query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filtered = const <LeaderboardEntry>[];
        return;
      }
      _filtered = boardState.entries.where((LeaderboardEntry entry) {
        return entry.username.toLowerCase().contains(query) ||
            (entry.guild?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  void _scrollToMyRank(List<LeaderboardEntry> listEntries, String? username) {
    if (username == null || !_scrollController.hasClients) return;
    final int idx = listEntries.indexWhere(
      (LeaderboardEntry e) =>
          e.username.toLowerCase() == username.toLowerCase(),
    );
    if (idx >= 0) {
      final double targetOffset = 460.0 + (idx * 84.0);
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LeaderboardState>(leaderboardProvider, (
      LeaderboardState? previous,
      LeaderboardState next,
    ) {
      if (previous?.entries != next.entries) {
        if (_searchQuery.isNotEmpty && mounted) {
          _applyFilter();
        }
      }
    });

    final LeaderboardState boardState = ref.watch(leaderboardProvider);
    final int safeCategoryIndex = (boardState.categoryIndex >= 0 &&
            boardState.categoryIndex < leaderboardCategories.length)
        ? boardState.categoryIndex
        : 0;
    final LeaderboardCategory activeCategory =
        leaderboardCategories[safeCategoryIndex];
    final String? username = ref.watch(playerProvider).profile?.username;
    final int playerLevel = ref.watch(playerProvider).profile?.level ?? 1;
    final bool isLoading =
        boardState.status == LeaderboardStatus.loading &&
        boardState.entries.isEmpty;

    return Scaffold(
      appBar: GameTopBar(
        title: context.l10n.s_ralama,
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.leaderboard,
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      body: GameScreenBackground(
        showAmbientGlow: true,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : boardState.status == LeaderboardStatus.error &&
                    boardState.entries.isEmpty
                ? LeaderboardErrorPanel(
                    message: boardState.errorMessage ?? 'Sıralama yüklenemedi',
                    onRetry: () =>
                        ref.read(leaderboardProvider.notifier).refresh(),
                  )
                : _buildContent(
                    context,
                    boardState,
                    activeCategory,
                    safeCategoryIndex,
                    username,
                    playerLevel,
                  ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    LeaderboardState boardState,
    LeaderboardCategory activeCategory,
    int safeCategoryIndex,
    String? username,
    int playerLevel,
  ) {
    final LeaderboardNotifier notifier = ref.read(leaderboardProvider.notifier);
    final bool searchActive = _searchQuery.isNotEmpty;
    final List<LeaderboardEntry> currentEntries =
        searchActive ? _filtered : boardState.entries;

    final bool showPodium = !searchActive && currentEntries.length >= 3;
    final List<LeaderboardEntry> podiumEntries = showPodium
        ? currentEntries.take(3).toList(growable: false)
        : const <LeaderboardEntry>[];
    final List<LeaderboardEntry> listEntries = showPodium
        ? currentEntries.skip(3).toList(growable: false)
        : currentEntries;

    // Height of sticky "My Rank" footer card + safe area clearance
    final double stickyBottomClearance =
        gameBottomBarClearance(context) + 76 + AppSpacing.base;

    return Stack(
      children: <Widget>[
        // Main scrollable leaderboard feed
        RefreshIndicator(
          color: AppColors.liquidGold,
          onRefresh: notifier.refresh,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: CustomScrollView(
              controller: _scrollController,
              cacheExtent: 400,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: <Widget>[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.base,
                    AppSpacing.sm,
                    AppSpacing.base,
                    0,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(<Widget>[
                      // 2027 Aion 2 Animated Header Banner with Celestial Champion Rays Shader
                      LeaderboardAnimatedHeaderBanner(
                        category: activeCategory,
                        weekly: boardState.weekly,
                        totalEntries: boardState.entries.length,
                        isLoading:
                            boardState.status == LeaderboardStatus.loading,
                        onRefresh: notifier.refresh,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      // Category Selection Pills
                      LeaderboardCategoryStrip(
                        selectedIndex: safeCategoryIndex,
                        enabled: boardState.status != LeaderboardStatus.loading,
                        onSelected: (int index) {
                          if (FocusScope.of(context).hasFocus) {
                            FocusScope.of(context).unfocus();
                          }
                          notifier.selectCategory(index);
                          if (_scrollController.hasClients) {
                            _scrollController.animateTo(
                              0.0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                            );
                          }
                          _animCtrl.forward(from: 0.0);
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // All-Time vs Weekly Filter Toggle
                      LeaderboardTimeSegment(
                        allTimeLabel: context.l10n.t_m_zamanlar,
                        weeklyLabel: context.l10n.haftal_k,
                        weekly: boardState.weekly,
                        enabled: boardState.status != LeaderboardStatus.loading,
                        onAllTime: () => notifier.setWeekly(false),
                        onWeekly: () => notifier.setWeekly(true),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Search Bar for Player or Guild Name
                      LeaderboardSearchField(
                        controller: _searchCtrl,
                        hintText: context.l10n.oyuncu_veya_lonca_ara,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // Top-3 Podium Visualization with Animated Champion Auras & Metallic Emblems
                      if (showPodium)
                        LeaderboardHeroPodium(
                          entries: podiumEntries,
                          categoryKey: boardState.categoryKey,
                          dimmed: false,
                        ),
                      if (listEntries.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        LeaderboardSectionLabel(
                          title: searchActive
                              ? 'Arama Sonuçları'
                              : (showPodium ? 'Sıralama Listesi' : 'Tüm Oyuncular'),
                          subtitle: searchActive
                              ? '${listEntries.length} sonuç'
                              : '${listEntries.length} oyuncu',
                        ),
                      ],
                    ]),
                  ),
                ),
                // Empty Search State
                if (listEntries.isEmpty && searchActive)
                  SliverToBoxAdapter(
                    child: LeaderboardEmptySearch(query: _searchQuery),
                  )
                else if (listEntries.isEmpty &&
                    !searchActive &&
                    boardState.status != LeaderboardStatus.loading)
                  _EmptyLeaderboardSliver(
                    categoryName: activeCategory.label,
                    onRefresh: notifier.refresh,
                  )
                else
                  // Iridescent Rank Cards
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.base,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                          final LeaderboardEntry entry = listEntries[index];
                          final bool isSelf = username != null &&
                              entry.username.toLowerCase() ==
                                  username.toLowerCase();
                          return LeaderboardRankRow(
                            entry: entry,
                            categoryKey: boardState.categoryKey,
                            highlight: isSelf,
                          );
                        },
                        childCount: listEntries.length,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                      ),
                    ),
                  ),
                // Bottom Clearance Sliver to allow complete scroll past Sticky Footer
                SliverPadding(
                  padding: EdgeInsets.only(bottom: stickyBottomClearance),
                ),
              ],
            ),
          ),
        ),
        // Sticky "My Rank" Footer Card adhering to 390x844 SafeArea
        GestureDetector(
          onTap: () => _scrollToMyRank(listEntries, username),
          child: LeaderboardStickyPlayerFooter(
            username: username ?? 'Sen',
            subtitle: context.l10n.senin_s_ralaman,
            valueLabel: boardState.playerValue != null
                ? LeaderboardValueFormatter.format(
                    boardState.playerValue!,
                    boardState.categoryKey,
                  )
                : LeaderboardValueFormatter.unknown,
            rankLabel: boardState.playerRank != null
                ? '#${boardState.playerRank}'
                : LeaderboardValueFormatter.unknown,
            categoryKey: boardState.categoryKey,
            playerLevel: playerLevel,
          ),
        ),
      ],
    );
  }
}

class _EmptyLeaderboardSliver extends StatelessWidget {
  const _EmptyLeaderboardSliver({
    required this.categoryName,
    required this.onRefresh,
  });

  final String categoryName;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: 32,
        ),
        child: LeaderboardGlassPanel(
          accent: AppColors.liquidGold,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.military_tech_outlined,
                size: 48,
                color: AppColors.liquidGold.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 12),
              Text(
                '$categoryName Sıralaması Henüz Boş',
                style: AppTextStyles.h3.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'Bu sıralamada ilk yerini alan sen ol!',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.liquidGold,
                  side: BorderSide(
                    color: AppColors.liquidGold.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Yenile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

