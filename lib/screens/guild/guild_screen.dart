import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../l10n/l10n.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../core/utils/provider_scheduling.dart';
import '../../models/guild_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/guild_provider.dart';
import '../../core/staff/staff_player_entry.dart';
import '../../providers/player_provider.dart';
import '../../providers/staff_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import 'widgets/guild_dialogs.dart';
import 'widgets/guild_member_view.dart';
import 'widgets/guild_no_guild_view.dart';

class GuildScreen extends ConsumerStatefulWidget {
  const GuildScreen({super.key});

  @override
  ConsumerState<GuildScreen> createState() => _GuildScreenState();
}

class _GuildScreenState extends ConsumerState<GuildScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _createNameController = TextEditingController();
  final TextEditingController _createDescController = TextEditingController();
  bool _memberActionLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchQueryChanged);
    deferProviderUpdate(() async {
      await ref.read(playerProvider.notifier).loadProfile();
      await ref.read(guildProvider.notifier).loadGuild();
      if (!ref.read(guildProvider).hasValidGuild) {
        await ref.read(guildProvider.notifier).loadRecommendedGuilds();
      }
      if (mounted) {
        await TutorialTriggers.onRouteEnter(ref, AppRoutes.guild);
      }
    });
  }

  void _onSearchQueryChanged() {
    if (_searchController.text.trim().isEmpty) {
      ref.read(guildProvider.notifier).clearSearchResults();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchQueryChanged);
    _searchController.dispose();
    _createNameController.dispose();
    _createDescController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    AppMessenger.show(context, msg);
  }

  Future<void> _search() async {
    final String query = _searchController.text.trim();
    if (query.isEmpty) return;
    await ref.read(guildProvider.notifier).searchGuilds(query);
  }

  Future<void> _refreshGuild() async {
    await ref.read(playerProvider.notifier).loadProfile();
    await ref.read(guildProvider.notifier).loadGuild();
    if (!ref.read(guildProvider).hasValidGuild) {
      await ref.read(guildProvider.notifier).loadRecommendedGuilds();
    }
  }

  Future<void> _joinGuild(String guildId) async {
    final bool ok = await ref.read(guildProvider.notifier).joinGuild(guildId);
    if (!ok) {
      final String? err = ref.read(guildProvider).error;
      if (err != null) _showSnack(err);
      return;
    }
    _showSnack('Loncaya katıldın!');
  }

  Future<void> _leaveGuild() async {
    final bool? confirm = await showGuildLeaveConfirmDialog(context);
    if (confirm != true) return;

    final bool ok = await ref.read(guildProvider.notifier).leaveGuild();
    if (!ok) {
      final String? err = ref.read(guildProvider).error;
      if (err != null) _showSnack(err);
      return;
    }
    _showSnack('Loncadan ayrıldın.');
  }

  Future<void> _disbandGuild() async {
    final bool? confirm = await showGuildDisbandConfirmDialog(context);
    if (confirm != true) return;

    final bool ok = await ref.read(guildProvider.notifier).disbandGuild();
    if (!ok) {
      final String? err = ref.read(guildProvider).error;
      if (err != null) _showSnack(err);
      return;
    }
    _showSnack('Lonca dağıtıldı.');
  }

  Future<void> _showCreateDialog() async {
    _createNameController.clear();
    _createDescController.clear();
    final int playerGold = ref.read(playerProvider).profile?.gold ?? 0;

    final int createCost = ref.read(guildConfigProvider).createCostGold;

    await showGuildCreateDialog(
      context: context,
      ref: ref,
      nameController: _createNameController,
      descController: _createDescController,
      playerGold: playerGold,
      createCost: createCost,
      onMessage: _showSnack,
    );
  }

  Future<void> _showMinJoinPowerDialog(int current) async {
    await showGuildMinJoinPowerDialog(
      context: context,
      ref: ref,
      current: current,
      onMessage: _showSnack,
    );
  }

  Future<void> _showMemberActions({
    required GuildMemberData member,
    required GuildRole myRole,
    required String myPlayerId,
  }) async {
    await showGuildMemberActionsSheet(
      context: context,
      member: member,
      myRole: myRole,
      myPlayerId: myPlayerId,
      onMemberAction: _memberAction,
    );
  }

  Future<void> _memberAction({
    required String memberId,
    required String action,
    required String successMsg,
  }) async {
    setState(() => _memberActionLoading = true);
    try {
      final bool ok = await ref.read(guildProvider.notifier).updateMember(
            memberId: memberId,
            action: action,
          );
      if (!ok) {
        _showSnack(ref.read(guildProvider).error ?? 'İşlem başarısız.');
        return;
      }
      if (action == 'transfer_guild_leadership') {
        await ref.read(playerProvider.notifier).loadProfile();
      }
      _showSnack(successMsg);
    } catch (e) {
      _showSnack('İşlem başarısız: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _memberActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final GuildState guildState = ref.watch(guildProvider);
    final PlayerState playerState = ref.watch(playerProvider);

    Future<void> onLogout() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(guildProvider.notifier).clear();
      ref.read(playerProvider.notifier).clear();
    }

    final String myPlayerId = playerState.profile?.id ?? '';
    final GuildRole myRole =
        guildState.hasValidGuild ? ref.watch(myGuildRoleProvider) : GuildRole.member;
    final bool canStaffPlayer =
        canOpenStaffPlayerActions(ref.watch(staffProvider).profile);

    return Scaffold(
      appBar: GameTopBar(title: context.l10n.routeGuild, onLogout: onLogout),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(currentRoute: AppRoutes.guild, onLogout: onLogout),
      body: GameScreenBackground(
        child: guildState.isLoading && !guildState.hasValidGuild
            ? const Center(child: CircularProgressIndicator(color: AppColors.liquidGold))
            : !guildState.hasValidGuild
                ? GuildNoGuildView(
                    searchController: _searchController,
                    searchResults: guildState.searchResults,
                    recommendedGuilds: guildState.recommendedGuilds,
                    myPower: playerState.profile?.power ?? 0,
                    isSearching: guildState.isSearching,
                    isLoadingRecommended: guildState.isLoadingRecommended,
                    isMutating: guildState.isMutating,
                    error: guildState.error,
                    onSearch: _search,
                    onJoin: _joinGuild,
                    onCreate: _showCreateDialog,
                    onRefresh: _refreshGuild,
                  )
                : GuildMemberView(
                    guild: guildState.guild!,
                    myPlayerId: myPlayerId,
                    myRole: myRole,
                    memberActionLoading: _memberActionLoading,
                    onMemberTap: (GuildMemberData member) => _showMemberActions(
                      member: member,
                      myRole: myRole,
                      myPlayerId: myPlayerId,
                    ),
                    onStaffMemberAction: canStaffPlayer
                        ? (GuildMemberData member) {
                            if (member.userId == null || member.userId!.isEmpty) return;
                            unawaited(openStaffPlayerActions(
                              context,
                              ref,
                              authId: member.userId!,
                              username: member.username,
                              staffBadge: member.staffBadge,
                            ));
                          }
                        : null,
                    onLeave: myRole == GuildRole.leader ? _disbandGuild : _leaveGuild,
                    leaveLabel: myRole == GuildRole.leader ? 'Dağıt' : 'Çık',
                    onGuildWar: () => context.go(AppRoutes.guildWar),
                    onMonument: () => context.go(AppRoutes.guildMonument),
                    onVault: () => context.go(AppRoutes.guildVault),
                    onRefresh: _refreshGuild,
                    onEditMinJoinPower: myRole == GuildRole.leader
                        ? () => _showMinJoinPowerDialog(guildState.guild!.minJoinPower)
                        : null,
                  ),
      ),
    );
  }
}
