import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/staff/staff_player_entry.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../core/utils/provider_scheduling.dart';
import '../../l10n/l10n.dart';
import '../../models/guild_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/guild_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/staff_provider.dart';
import '../../routing/app_router.dart';
import 'widgets/guild_design.dart';
import 'widgets/guild_dialogs.dart';
import 'widgets/guild_emblem_banner.dart';
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
  Timer? _searchDebounceTimer;
  bool _memberActionLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchQueryChanged);
    deferProviderUpdate(() async {
      if (!mounted) return;
      await ref.read(playerProvider.notifier).loadProfile();
      if (!mounted) return;
      await ref.read(guildProvider.notifier).loadGuild();
      if (!mounted) return;
      if (!ref.read(guildProvider).hasValidGuild) {
        await ref.read(guildProvider.notifier).loadRecommendedGuilds();
      }
      if (mounted) {
        await TutorialTriggers.onRouteEnter(ref, AppRoutes.guild);
      }
    });
  }

  void _onSearchQueryChanged() {
    _searchDebounceTimer?.cancel();
    final String query = _searchController.text.trim();
    if (query.isEmpty) {
      ref.read(guildProvider.notifier).clearSearchResults();
    } else if (query.length >= 2) {
      _searchDebounceTimer = Timer(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        ref.read(guildProvider.notifier).searchGuilds(query);
      });
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
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
    if (query.isEmpty) {
      ref.read(guildProvider.notifier).clearSearchResults();
      return;
    }
    await ref.read(guildProvider.notifier).searchGuilds(query);
  }

  Future<void> _refreshGuild() async {
    if (!mounted) return;
    await ref.read(playerProvider.notifier).loadProfile();
    if (!mounted) return;
    await ref.read(guildProvider.notifier).loadGuild();
    if (!mounted) return;
    if (!ref.read(guildProvider).hasValidGuild) {
      await ref.read(guildProvider.notifier).loadRecommendedGuilds();
    }
  }

  Future<void> _joinGuild(String guildId) async {
    if (!mounted) return;
    final bool ok = await ref.read(guildProvider.notifier).joinGuild(guildId);
    if (!mounted) return;
    if (!ok) {
      final String? err = ref.read(guildProvider).error;
      if (err != null) _showSnack(err);
      return;
    }
    _showSnack('Loncaya katıldın!');
  }

  Future<void> _leaveGuild() async {
    final bool? confirm = await showGuildLeaveConfirmDialog(context);
    if (!mounted || confirm != true) return;

    final bool ok = await ref.read(guildProvider.notifier).leaveGuild();
    if (!mounted) return;
    if (!ok) {
      final String? err = ref.read(guildProvider).error;
      if (err != null) _showSnack(err);
      return;
    }
    _showSnack('Loncadan ayrıldın.');
  }

  Future<void> _disbandGuild() async {
    final bool? confirm = await showGuildDisbandConfirmDialog(context);
    if (!mounted || confirm != true) return;

    final bool ok = await ref.read(guildProvider.notifier).disbandGuild();
    if (!mounted) return;
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
    if (_memberActionLoading) return;
    setState(() => _memberActionLoading = true);
    try {
      final bool ok = await ref.read(guildProvider.notifier).updateMember(
            memberId: memberId,
            action: action,
          );
      if (!mounted) return;
      if (!ok) {
        _showSnack(ref.read(guildProvider).error ?? 'İşlem başarısız.');
        return;
      }
      if (action == 'transfer_guild_leadership') {
        await ref.read(playerProvider.notifier).loadProfile();
      }
      if (!mounted) return;
      _showSnack(successMsg);
    } catch (e) {
      if (!mounted) return;
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
      if (!mounted) return;
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
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: guildState.isLoading && !guildState.hasValidGuild
                  ? const _GuildCelestialLoading()
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
            if (_memberActionLoading)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.55),
                  child: Center(
                    child: GuildGlassCard(
                      accent: GuildPalette.gold,
                      glow: true,
                      glowOpacity: 0.32,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: GuildPalette.gold,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Lonca işlemi yapılıyor...',
                            style: GoogleFonts.urbanist(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: GuildPalette.textHi,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// AAA Luxury Aion 2 celestial glass loading indicator.
class _GuildCelestialLoading extends StatelessWidget {
  const _GuildCelestialLoading();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: GuildGlassCard(
            accent: GuildPalette.iridescentCyan,
            glow: true,
            glowOpacity: 0.25,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const GuildCelestialEmblem(
                  level: 1,
                  monogram: '🏰',
                  size: 68,
                  showGlow: true,
                ),
                const SizedBox(height: 20),
                Text(
                  'LONCA AĞI BAĞLANTISI',
                  style: GoogleFonts.urbanist(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                    color: GuildPalette.textHi,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Kadim lonca verileri senkronize ediliyor...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.urbanist(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: GuildPalette.titanium,
                  ),
                ),
                const SizedBox(height: 20),
                const SizedBox(
                  width: 140,
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      color: GuildPalette.gold,
                      backgroundColor: GuildPalette.obsidian,
                    ),
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
