import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/leaderboard/champions_3d_podium.dart';
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
import 'widgets/leaderboard_design.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  List<LeaderboardEntry> _filtered = <LeaderboardEntry>[];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(leaderboardProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), _applyFilter);
  }

  void _applyFilter() {
    final LeaderboardState boardState = ref.read(leaderboardProvider);
    final String query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filtered = List<LeaderboardEntry>.from(boardState.entries);
        return;
      }
      _filtered = boardState.entries.where((LeaderboardEntry entry) {
        return entry.username.toLowerCase().contains(query) ||
            (entry.guild?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LeaderboardState>(leaderboardProvider, (
      LeaderboardState? previous,
      LeaderboardState next,
    ) {
      if (previous?.entries != next.entries) {
        _applyFilter();
      }
    });

    final LeaderboardState boardState = ref.watch(leaderboardProvider);
    final LeaderboardCategory activeCategory =
        leaderboardCategories[boardState.categoryIndex];
    final String? username = ref.watch(playerProvider).profile?.username;
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
                onRetry: () => ref.read(leaderboardProvider.notifier).refresh(),
              )
            : _buildContent(context, boardState, activeCategory, username),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    LeaderboardState boardState,
    LeaderboardCategory activeCategory,
    String? username,
  ) {
    final LeaderboardNotifier notifier = ref.read(leaderboardProvider.notifier);
    final bool searchActive = _searchQuery.isNotEmpty;
    final List<LeaderboardEntry> podiumEntries =
        _filtered.take(3).toList(growable: false);
    final List<LeaderboardEntry> listEntries = searchActive
        ? _filtered
        : _filtered.skip(podiumEntries.length).toList(growable: false);

    return RefreshIndicator(
      color: AppColors.liquidGold,
      onRefresh: notifier.refresh,
      child: CustomScrollView(
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
                LeaderboardHeaderStrip(
                  category: activeCategory,
                  weekly: boardState.weekly,
                  totalEntries: boardState.entries.length,
                  isLoading: boardState.status == LeaderboardStatus.loading,
                  onRefresh: notifier.refresh,
                ),
                const SizedBox(height: AppSpacing.sm),
                LeaderboardCategoryStrip(
                  selectedIndex: boardState.categoryIndex,
                  enabled: boardState.status != LeaderboardStatus.loading,
                  onSelected: notifier.selectCategory,
                ),
                const SizedBox(height: AppSpacing.sm),
                LeaderboardTimeSegment(
                  allTimeLabel: context.l10n.t_m_zamanlar,
                  weeklyLabel: context.l10n.haftal_k,
                  weekly: boardState.weekly,
                  enabled: boardState.status != LeaderboardStatus.loading,
                  onAllTime: () => notifier.setWeekly(false),
                  onWeekly: () => notifier.setWeekly(true),
                ),
                const SizedBox(height: AppSpacing.sm),
                LeaderboardSearchField(
                  controller: _searchCtrl,
                  hintText: context.l10n.oyuncu_veya_lonca_ara,
                ),
                const SizedBox(height: AppSpacing.md),
                if (podiumEntries.isNotEmpty)
                  Champions3dPodium(
                    entries: podiumEntries,
                    categoryKey: boardState.categoryKey,
                    dimmed: searchActive,
                  ),
                if (listEntries.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  LeaderboardSectionLabel(
                    title: searchActive ? 'Arama Sonuçları' : 'Sıralama Listesi',
                    subtitle: searchActive
                        ? '${listEntries.length} sonuç'
                        : '${listEntries.length} oyuncu',
                  ),
                ],
              ]),
            ),
          ),
          if (listEntries.isEmpty && searchActive)
            SliverToBoxAdapter(
              child: LeaderboardEmptySearch(query: _searchQuery),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    final LeaderboardEntry entry = listEntries[index];
                    final bool isSelf = username != null &&
                        entry.username.toLowerCase() == username.toLowerCase();
                    return LeaderboardRankRow(
                      entry: entry,
                      categoryKey: boardState.categoryKey,
                      highlight: isSelf,
                    );
                  },
                  childCount: listEntries.length,
                ),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.base,
              AppSpacing.md,
              AppSpacing.base,
              gameBottomBarClearance(context) + AppSpacing.base,
            ),
            sliver: SliverToBoxAdapter(
              child: LeaderboardPlayerCard(
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
