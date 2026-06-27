import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../models/guild_war_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/guild_war_provider.dart';
import '../../providers/guild_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'widgets/guild_war_season_header.dart';
import 'widgets/guild_war_skeleton.dart';
import 'widgets/guild_war_tab_bar.dart';
import 'widgets/kingdom_election_panel.dart';
import 'widgets/ranking_podium.dart';
import 'widgets/territory_card.dart';
import 'widgets/territory_map_view.dart';
import 'widgets/tournament_card.dart';
import 'guild_war_defense_sheet.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';

class GuildWarHubScreen extends ConsumerStatefulWidget {
  const GuildWarHubScreen({super.key});

  @override
  ConsumerState<GuildWarHubScreen> createState() => _GuildWarHubScreenState();
}

class _GuildWarHubScreenState extends ConsumerState<GuildWarHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _territoryMapView = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(guildProvider.notifier).loadGuild();
      ref.read(guildWarProvider.notifier).loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await ref.read(guildWarProvider.notifier).loadAll();
  }

  int? _myRank(List<GuildWarRanking> rankings, String? guildName) {
    if (guildName == null) return null;
    for (final r in rankings) {
      if (r.guildName == guildName) return r.rank;
    }
    return null;
  }

  int? _myPoints(List<GuildWarRanking> rankings, String? guildName) {
    if (guildName == null) return null;
    for (final r in rankings) {
      if (r.guildName == guildName) return r.points;
    }
    return null;
  }

  Future<void> _joinTournament(String id) async {
    final error = await ref.read(guildWarProvider.notifier).joinTournament(id);
    if (!mounted) return;
    if (error != null) {
      AppMessenger.showError(context, error);
    } else {
      AppMessenger.showSuccess(context, '✅ Turnuvaya kaydoldunuz!');
    }
  }

  Future<void> _attackTerritory(TerritoryData territory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('⚔ Bölge Saldırısı'),
        content: Text('${territory.name} bölgesine saldırmak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Saldır!'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await ref.read(guildWarProvider.notifier).attackTerritory(territory.id);
    if (!mounted || result == null) return;

    if (result.error != null) {
      AppMessenger.showError(context, result.error!);
      return;
    }

    context.push(AppRoutes.guildWarBattleResult, extra: result).then((_) => _refresh());
  }

  Future<void> _addDefense(TerritoryData territory) async {
    final gems = await showGuildWarDefenseSheet(context);
    if (gems == null || gems <= 0) return;

    final error = await ref.read(guildWarProvider.notifier).addDefense(territory.id, gems);
    if (!mounted) return;
    if (error != null) {
      AppMessenger.showError(context, error);
    } else {
      AppMessenger.showSuccess(context, '🛡 Savunma eklendi!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final warState = ref.watch(guildWarProvider);
    final profile = ref.watch(playerProvider).profile;
    final guildState = ref.watch(guildProvider);
    final guildId = guildState.guild?.guildId ?? profile?.guildId;
    final guildName = guildState.guild?.name ?? profile?.guildName;

    Future<void> logout() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(guildProvider.notifier).clear();
      ref.read(playerProvider.notifier).clear();
    }

    return Scaffold(
      appBar: GameTopBar(title: '⚔ Lonca Savaşı', onLogout: logout),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(currentRoute: AppRoutes.guildWar, onLogout: logout),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF090D14), Color(0xFF101722), Color(0xFF090D14)],
          ),
        ),
        child: warState.isLoading
            ? const GuildWarSkeleton()
            : NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverOverlapAbsorber(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GuildWarSeasonHeader(
                            season: warState.season,
                            myRank: _myRank(warState.rankings, guildName),
                            myPoints: _myPoints(warState.rankings, guildName),
                          ),
                          if (guildId == null)
                            Container(
                              margin: const EdgeInsets.fromLTRB(
                                AppSpacing.base,
                                AppSpacing.sm,
                                AppSpacing.base,
                                0,
                              ),
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                              ),
                              child: TextButton(
                                onPressed: () => context.go(AppRoutes.guild),
                                child: const Text('Lonca Bul'),
                              ),
                            ),
                          GuildWarTabBar(
                            controller: _tabController,
                            tabs: const ['🏅 Sıralama', '🏆 Turnuva', '🗺 Bölge', '👑 Krallık'],
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.base,
                              AppSpacing.sm,
                              AppSpacing.base,
                              AppSpacing.sm,
                            ),
                            child: OutlinedButton.icon(
                              onPressed: () => context.push(AppRoutes.guildWarLogs),
                              icon: const Icon(Icons.history, size: 16),
                              label: const Text('Savaş Kayıtları', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: const BorderSide(color: AppColors.borderDefault),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _scrollTab(
                      child: RankingPodium(
                        rankings: warState.rankings,
                        highlightGuildName: guildName,
                      ),
                    ),
                    _scrollTab(
                      child: _buildTournamentsList(warState.tournaments, guildId),
                    ),
                    _scrollTab(
                      child: _buildTerritoriesContent(warState.territories, guildId),
                    ),
                    _scrollTab(child: const KingdomElectionPanel()),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _scrollTab({required Widget child}) {
    return Builder(
      builder: (context) => RefreshIndicator(
        color: AppColors.gold,
        onRefresh: _refresh,
        child: CustomScrollView(
          key: PageStorageKey<Object>(child.runtimeType),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
              sliver: SliverToBoxAdapter(child: child),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ),
      ),
    );
  }

  Widget _buildTournamentsList(List<GuildWarTournament> tournaments, String? guildId) {
    return Column(
      children: [
        for (final t in tournaments) ...[
          TournamentCard(
            tournament: t,
            onJoin: guildId != null && t.isActive ? () => _joinTournament(t.id) : null,
            onDetail: () => context.push('${AppRoutes.guildWar}/tournament/${t.id}'),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _buildTerritoriesContent(List<TerritoryData> territories, String? guildId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _ViewToggle(
              label: 'Harita',
              selected: _territoryMapView,
              onTap: () => setState(() => _territoryMapView = true),
            ),
            const SizedBox(width: 8),
            _ViewToggle(
              label: 'Liste',
              selected: !_territoryMapView,
              onTap: () => setState(() => _territoryMapView = false),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_territoryMapView)
          SizedBox(
            height: 420,
            child: TerritoryMapView(
              territories: territories,
              playerGuildId: guildId,
              onTerritoryTap: (t) => context.push('${AppRoutes.guildWar}/territory/${t.id}'),
            ),
          )
        else
          Column(
            children: [
              for (final t in territories) ...[
                Builder(
                  builder: (context) {
                    final isOwner = t.ownerGuildId == guildId;
                    return TerritoryCard(
                      territory: t,
                      isOwner: isOwner,
                      onTap: () => context.push('${AppRoutes.guildWar}/territory/${t.id}'),
                      onAttack: !isOwner && guildId != null ? () => _attackTerritory(t) : null,
                      onAddDefense: isOwner ? () => _addDefense(t) : null,
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
      ],
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.borderDefault,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.gold : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
