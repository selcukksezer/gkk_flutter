import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/utils/power_formula.dart';
import '../../models/dungeon_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dungeon_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import 'dungeon_zone_data.dart';
import 'widgets/dungeon_card.dart';
import 'widgets/dungeon_confirm_entry_dialog.dart';
import 'widgets/dungeon_loot_dialog.dart';
import 'widgets/dungeon_restriction_strip.dart';
import 'widgets/dungeon_state_widgets.dart';
import 'widgets/dungeon_zone_tab_bar.dart';
import 'widgets/featured_cave_dungeon_card.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import '../../l10n/l10n.dart';

class DungeonScreen extends ConsumerStatefulWidget {
  const DungeonScreen({super.key});

  @override
  ConsumerState<DungeonScreen> createState() => _DungeonScreenState();
}

class _DungeonScreenState extends ConsumerState<DungeonScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  int get _selectedZone => _tabController.index == 0
      ? 0
      : kDungeonZones[_tabController.index - 1].number;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: kDungeonZones.length + 1, vsync: this);
    _tabController.addListener(() {
      if (mounted && !_tabController.indexIsChanging) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(playerProvider.notifier).loadProfile();
      await ref.read(inventoryProvider.notifier).loadInventory(silent: true);
      await ref.read(dungeonProvider.notifier).loadDungeons();
      if (!mounted) return;
      await TutorialTriggers.onRouteEnter(ref, AppRoutes.dungeon);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTime? _parseRestrictionUntil(String? raw) {
    if (raw == null) return null;
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final DateTime? parsed = DateTime.tryParse(trimmed) ??
        DateTime.tryParse(trimmed.replaceFirst(' ', 'T'));
    if (parsed == null) return null;

    if (parsed.isUtc) return parsed.toLocal();

    final bool hasTimezone = RegExp(
      r'(Z|[+\-]\d{2}:?\d{2})$',
      caseSensitive: false,
    ).hasMatch(trimmed);

    if (!hasTimezone) {
      return DateTime.utc(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
        parsed.millisecond,
        parsed.microsecond,
      ).toLocal();
    }

    return parsed.toLocal();
  }

  bool _isRestricted(String? untilRaw) {
    final DateTime? until = _parseRestrictionUntil(untilRaw);
    if (until == null) return false;
    return until.isAfter(DateTime.now());
  }

  Future<void> _enterDungeon(DungeonData dungeon) async {
    final player = ref.read(playerProvider).profile;
    if (player == null) {
      _showSnack('Oyuncu bilgisi yüklenemedi.');
      return;
    }
    if (_isRestricted(player.hospitalUntil)) {
      _showSnack('Hastanedeyken zindana giriş yapılamaz.');
      return;
    }
    if (_isRestricted(player.prisonUntil)) {
      _showSnack('Hapisteyken zindana giriş yapılamaz.');
      return;
    }
    if (player.energy < dungeon.energyCost) {
      _showSnack('Enerji yetersiz.');
      return;
    }

    final int req = dungeon.powerRequirement ?? (dungeon.requiredLevel * 500);
    final PowerBreakdown powerBreakdown = calculateTotalPower(
      player: player,
      equippedItems: ref.read(inventoryProvider).equippedItems.values,
    );
    final int successPct = (calculateDungeonSuccessRate(
          playerTotalPower: powerBreakdown.totalPower,
          dungeonPowerRequirement: req,
          playerLuck: player.luck ?? 0,
          reputation: player.reputation ?? 0,
          characterClass: player.characterClass,
        ) *
        100)
        .round();
    final double hospitalRisk = calculateHospitalRiskPct(
      dungeonNumber: parseDungeonNumber(dungeon.dungeonId),
      successRate: successPct / 100.0,
      playerLuck: player.luck ?? 0,
    );
    final double farmPreview = calculateDungeonRewardMultiplier(
      playerLevel: player.level,
      dungeonPowerRequirement: req,
      successRate: successPct / 100.0,
      isFirstClear: !(dungeon.playerStats?.hasFirstClear ?? false),
    );

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => DungeonConfirmEntryDialog(
        dungeon: dungeon,
        hospitalRiskPct: hospitalRisk,
        rewardMultiplierPreview: farmPreview,
        onConfirmTap: () => TutorialTriggers.onAnchorTap(
          ref,
          TutorialAnchorId.dungeonConfirmOk,
        ),
      ),
    );
    if (confirm != true || !mounted) return;

    final int zone = zoneForDungeon(dungeon);
    await context.push(
      '${AppRoutes.dungeonBattle}?'
      'dungeon_id=${Uri.encodeComponent(dungeon.dungeonId)}&'
      'dungeon_name=${Uri.encodeComponent(dungeon.name)}&'
      'zone=$zone&'
      'energy_cost=${dungeon.energyCost}&'
      'auto=1',
    );
    if (!mounted) return;
    await ref.read(playerProvider.notifier).loadProfile();
    await ref.read(dungeonProvider.notifier).loadDungeons();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    AppMessenger.show(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final dungeonState = ref.watch(dungeonProvider);
    final playerState = ref.watch(playerProvider);
    final inventoryState = ref.watch(inventoryProvider);
    final profile = playerState.profile;

    final bool inHospital = _isRestricted(profile?.hospitalUntil);
    final bool inPrison = _isRestricted(profile?.prisonUntil);
    final bool isRestricted = inHospital || inPrison;

    final PowerBreakdown? powerBreakdown = profile != null
        ? calculateTotalPower(
            player: profile,
            equippedItems: inventoryState.equippedItems.values,
          )
        : null;
    final int playerTotalPower = powerBreakdown?.totalPower ?? 0;

    final List<DungeonData> filtered = _selectedZone == 0
        ? dungeonState.dungeons
        : dungeonState.dungeons
            .where((DungeonData d) => zoneForDungeon(d) == _selectedZone)
            .toList();

    final DungeonZone? currentZone = zoneDataFor(_selectedZone);

    return Scaffold(
      backgroundColor: AppColors.carbonVoid,
      appBar: GameTopBar(
        title: context.l10n.zindan,
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.dungeon,
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    AppColors.carbonVoid,
                    currentZone != null
                        ? Color.fromRGBO(
                            (currentZone.color.r * 255).round(),
                            (currentZone.color.g * 255).round(),
                            (currentZone.color.b * 255).round(),
                            0.04,
                          )
                        : const Color(0xFF0C1020),
                    AppColors.carbonVoid,
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: <Widget>[
              if (inHospital)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: DungeonRestrictionMiniStrip(
                    hospitalUntil: profile?.hospitalUntil,
                    parseUntil: _parseRestrictionUntil,
                    onGoHospital: () => context.go(AppRoutes.hospital),
                    title: 'Hastanedesin',
                    actionLabel: 'Hastaneye Git',
                    icon: Icons.local_hospital,
                    accent: const Color(0xFFEF4444),
                  ),
                ),
              if (inPrison)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: DungeonRestrictionMiniStrip(
                    hospitalUntil: profile?.prisonUntil,
                    parseUntil: _parseRestrictionUntil,
                    onGoHospital: () => context.go(AppRoutes.prison),
                    title: 'Cezaevindesin',
                    actionLabel: 'Cezaevine Git',
                    icon: Icons.gavel_rounded,
                    accent: AppColors.warningSolar,
                    availableLabel: 'Serbest kalabilirsin',
                  ),
                ),
              DungeonZoneTabBar(
                controller: _tabController,
                dungeons: dungeonState.dungeons,
                zoneFor: zoneForDungeon,
              ),
              if (currentZone != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: DungeonZoneBanner(zone: currentZone, dungeonCount: filtered.length),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: dungeonState.status == DungeonStatus.loading
                    ? const DungeonLoadingShimmer()
                    : dungeonState.status == DungeonStatus.error
                        ? DungeonErrorState(
                            message: dungeonState.errorMessage,
                            onRetry: () => ref.read(dungeonProvider.notifier).loadDungeons(),
                          )
                        : filtered.isEmpty
                            ? const DungeonEmptyState()
                            : RefreshIndicator(
                                onRefresh: () => ref.read(dungeonProvider.notifier).loadDungeons(),
                                child: ListView.builder(
                                  padding: GameScrollLayout.withClearance(
                                    context,
                                    const EdgeInsets.fromLTRB(14, 0, 14, 24),
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (BuildContext ctx, int i) {
                                    final DungeonData d = filtered[i];
                                    final int zoneNum = zoneForDungeon(d);
                                    final DungeonZone? zData = zoneDataFor(zoneNum);
                                    final bool canEnter = !isRestricted &&
                                        profile != null &&
                                        profile.energy >= d.energyCost;
                                    final int req = d.powerRequirement ?? (d.requiredLevel * 500);
                                    final int successPct;
                                    String? debugText;
                                    if (profile != null && powerBreakdown != null) {
                                      successPct = (calculateDungeonSuccessRate(
                                            playerTotalPower: playerTotalPower,
                                            dungeonPowerRequirement: req,
                                            playerLuck: profile.luck ?? 0,
                                            reputation: profile.reputation ?? 0,
                                            characterClass: profile.characterClass,
                                          ) *
                                          100)
                                          .round();
                                      debugText = kDebugMode
                                          ? 'pwr:$playerTotalPower eq:${powerBreakdown.equipmentPower} req:$req'
                                          : null;
                                    } else {
                                      successPct = 5;
                                      debugText = kDebugMode ? 'no profile' : null;
                                    }

                                    if (isFeaturedCaveDungeon(d)) {
                                      final theme = featuredCaveThemeFor(d)!;
                                      return FeaturedCaveDungeonCard(
                                        dungeon: d,
                                        theme: theme,
                                        zoneIcon: zData?.icon ?? Icons.park,
                                        zoneLabel: (zData?.name.split(' ').first ?? 'ZINDAN')
                                            .toUpperCase(),
                                        zoneColor: zData?.color ?? const Color(0xFF4ADE80),
                                        canEnter: canEnter,
                                        inHospital: inHospital,
                                        inPrison: inPrison,
                                        entering: dungeonState.entering,
                                        successPercent: successPct,
                                        energyCost: d.energyCost,
                                        minGold: d.minGold,
                                        maxGold: d.maxGold,
                                        powerRequirement: req,
                                        playerPower: playerTotalPower,
                                        debugText: debugText,
                                        onEnter: () => _enterDungeon(d),
                                        onLoot: () => showDialog<void>(
                                          context: context,
                                          builder: (_) => DungeonLootDialog(dungeon: d, zone: zData),
                                        ),
                                      );
                                    }

                                    return DungeonCard(
                                      dungeon: d,
                                      zone: zData,
                                      canEnter: canEnter,
                                      inHospital: inHospital,
                                      inPrison: inPrison,
                                      entering: dungeonState.entering,
                                      successPercent: successPct,
                                      playerPower: playerTotalPower,
                                      powerRequirement: req,
                                      debugText: debugText,
                                      useTutorialAnchors: i == 0,
                                      onCardTap: i == 0
                                          ? () => TutorialTriggers.onAnchorTap(
                                                ref,
                                                TutorialAnchorId.dungeonZone0,
                                              )
                                          : null,
                                      onEnter: () async {
                                        await TutorialTriggers.onAnchorTap(
                                          ref,
                                          TutorialAnchorId.dungeonEnterBtn,
                                        );
                                        await _enterDungeon(d);
                                      },
                                      onLoot: () => showDialog<void>(
                                        context: context,
                                        builder: (_) => DungeonLootDialog(dungeon: d, zone: zData),
                                      ),
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
