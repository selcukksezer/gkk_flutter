import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_screen_background.dart';
import '../../models/dungeon_siege_model.dart';
import '../../models/guild_war_model.dart';
import '../../providers/guild_provider.dart';
import '../../providers/guild_war_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../core/utils/combat_restriction.dart';
import '../../utils/logout_helper.dart';
import 'guild_war_defense_sheet.dart';
import 'widgets/attack_log_tile.dart';
import 'widgets/defense_power_bar.dart';
import 'widgets/guild_war_design.dart';
import 'widgets/guild_war_sub_screen_scaffold.dart';
import 'widgets/territory_guild_duel_panel.dart';
import 'widgets/territory_detail_ui.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';

class TerritoryDetailScreen extends ConsumerStatefulWidget {
  const TerritoryDetailScreen({super.key, required this.territoryId});

  final String territoryId;

  @override
  ConsumerState<TerritoryDetailScreen> createState() => _TerritoryDetailScreenState();
}

class _TerritoryDetailScreenState extends ConsumerState<TerritoryDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    ref.read(guildWarProvider.notifier).clearTerritoryDetail();
    super.dispose();
  }

  Future<void> _load() async {
    await ref.read(guildWarProvider.notifier).loadTerritoryDetail(widget.territoryId);
  }

  Future<void> _attack(TerritoryData territory) async {
    await context.push('${AppRoutes.guildWarTerritory}/${territory.id}/attack');
    if (mounted) await _load();
  }

  Future<void> _addDefense(TerritoryData territory) async {
    final profile = ref.read(playerProvider).profile;
    final GuildWarDefenseRequest? req = await showGuildWarDefenseSheet(
      context,
      minDefenseGems: territory.minDefenseGems,
      vaultGold: territory.vaultSummary?.vaultGold,
      playerGems: profile?.gems,
    );
    if (req == null || req.amount <= 0) return;
    final String? error = req.mode == GuildWarDefenseMode.gems
        ? await ref.read(guildWarProvider.notifier).addDefense(territory.id, req.amount)
        : await ref.read(guildWarProvider.notifier).addDefenseGold(territory.id, req.amount);
    if (!mounted) return;
    if (error != null) {
      AppMessenger.showError(context, error);
    } else {
      AppMessenger.showSuccess(context, '🛡 Savunma eklendi!');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final GuildWarState warState = ref.watch(guildWarProvider);
    final bool isCurrentTerritory = warState.activeTerritoryId == widget.territoryId;
    final TerritoryDetail? detail =
        isCurrentTerritory ? warState.territoryDetail : null;
    final bool loading = isCurrentTerritory && warState.isTerritoryDetailLoading;
    final profile = ref.watch(playerProvider).profile;
    final guildState = ref.watch(guildProvider);
    final guildId = profile?.guildId;
    final String? myGuildName = guildState.guild?.name ?? profile?.guildName;
    final bool combatLocked = isCombatRestricted(
      hospitalUntil: profile?.hospitalUntil,
      prisonUntil: profile?.prisonUntil,
    );
    final t = detail?.territory;
    final isOwner = t != null && !t.isUnclaimed && t.ownerGuildId == guildId;
    final String ownerLabel = t == null ? '' : _territoryOwnerLabel(t);
    final List<TerritoryData> territories = warState.territories;
    final Color heroAccent =
        t == null ? WarPalette.coral : (t.isUnclaimed ? WarPalette.coral : WarPalette.fuchsia);

    Future<void> logout() async => performLogout(ref);

    return GuildWarSubScreenScaffold(
      title: '🗺 Bölge Detay',
      onLogout: logout,
      currentRoute: AppRoutes.guildWar,
      body: Stack(
        children: <Widget>[
          if (loading && t == null)
            const Center(child: CircularProgressIndicator(color: WarPalette.gold))
          else if (t == null)
            TerritoryNotFoundPanel(
              territoryId: widget.territoryId,
              onBack: () => context.go(AppRoutes.guildWar),
            )
          else
            Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: GameScrollLayout.pagePadding(context),
                    children: [
                      TerritoryDetailHero(
                        territory: t,
                        ownerLabel: ownerLabel,
                        mapIcon: territoryMapIconFor(t.id, territories),
                        mapCoordinate: territoryMapCoordinateFor(t.id, territories),
                        accent: heroAccent,
                        isOwner: isOwner,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TerritoryGuildDuelPanel(
                        attacker: GuildWarGuildBrief(
                          id: guildId ?? '',
                          name: myGuildName ?? 'Loncan',
                        ),
                        defender: GuildWarGuildBrief(
                          id: t.ownerGuildId ?? '',
                          name: t.ownerGuildName ?? 'Sahipsiz',
                          tag: t.ownerGuildTag,
                        ),
                      ),
                      if (t.vaultSummary != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        WarNeonCard(
                          accent: WarPalette.gold,
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Kasa: ${t.vaultSummary!.vaultGold}g · Biriken: ${t.vaultSummary!.vaultGoldPending}g',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (t.attackGoldCost > 0)
                                      Text(
                                        'Saldırı maliyeti: ${t.attackGoldCost}g',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.go(AppRoutes.guildVault),
                                child: const Text('Kasa'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (t.siegeDungeonId != null && t.siegeDungeonId!.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        Material(
                          color: const Color(0xFF1F1315),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: () {
                              context.push(
                                '${AppRoutes.dungeonSiegeHub}?dungeon_id=${Uri.encodeComponent(t.siegeDungeonId!)}',
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: (t.hasActiveSiegeSession
                                          ? WarPalette.neon
                                          : const Color(0xFFEF4444))
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Text(
                                    t.hasActiveSiegeSession ? '🔥' : '⚔',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      t.hasActiveSiegeSession
                                          ? 'Kuşatma canlı: ${t.siegeDungeonName ?? t.siegeDungeonId}'
                                          : 'Kuşatma: ${t.siegeDungeonName ?? t.siegeDungeonId} · owner slot +%25''e kadar',
                                      style: TextStyle(
                                        color: t.hasActiveSiegeSession
                                            ? WarPalette.neon
                                            : const Color(0xFFFCA5A5),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ] else if (t.zoneNumber == null) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        WarNeonCard(
                          accent: WarPalette.titanium,
                          child: const Text(
                            'Bu bölge için kuşatma eşlemesi yok.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.base),
                      TerritoryAttackSummaryHeader(
                        attacks: detail!.recentAttacks,
                        myGuildId: guildId,
                      ),
                      if (detail.recentAttacks.isNotEmpty) const SizedBox(height: AppSpacing.base),
                      GameGridColumns(
                        crossAxisCount: 2,
                        children: [
                          _StatTile(label: 'Savunma', value: '${t.displayDefensePower}', icon: '🛡'),
                          if (t.gemDefenseBoost > 0)
                            _StatTile(label: 'Elmas', value: '+${t.gemDefenseBoost}', icon: '💎'),
                          _StatTile(label: 'Trade Geliri', value: '${t.tradeIncome}/gün', icon: '💰'),
                          _StatTile(label: 'Ödül', value: t.reward.isEmpty ? '—' : t.reward, icon: '🎁'),
                          _StatTile(
                            label: 'Savunma Hattı',
                            value: 'Sv.${t.defenseLineLevel}',
                            icon: '🏗',
                          ),
                        ],
                      ),
                      WarNeonCard(
                        accent: WarPalette.neon,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Savunma gücü',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Elmas savunması prime time''da eklenir; prime bitince sıfırlanır. '
                              'Owner lonca kuşatma slotları +${(DungeonSiegeConfig.territoryDefenseSiegeBonusPct(t.displayDefensePower) * 100).round()}% alır (max %25).',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            DefensePowerBar(
                              current: t.displayDefensePower,
                              max: t.displayDefensePower > t.baseDefensePower
                                  ? t.displayDefensePower
                                  : t.baseDefensePower,
                              height: 10,
                            ),
                          ],
                        ),
                      ),
                      if (detail.recentAttacks.isNotEmpty) ...[
                        const WarSectionHeader(title: 'Saldırı Geçmişi', accent: WarPalette.ruby),
                        for (int i = 0; i < detail.recentAttacks.length; i++)
                          WarFadeSlide(
                            index: i,
                            child: AttackLogTile(
                              log: detail.recentAttacks[i],
                              myGuildId: guildId,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                if (guildId == null)
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.base),
                      child: WarOutlineButton(
                        label: 'Lonca üyeliği gerekli',
                        icon: Icons.groups_rounded,
                        onPressed: () => context.go(AppRoutes.guild),
                      ),
                    ),
                  )
                else
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.base),
                      child: isOwner
                          ? WarDefenseButton(onPressed: () => _addDefense(t))
                          : WarAttackButton(
                              onPressed: combatLocked ? null : () => _attack(t),
                            ),
                    ),
                  ),
              ],
            ),
          if (loading && t != null)
            const Positioned(
              top: AppSpacing.sm,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: WarPalette.gold,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _territoryOwnerLabel(TerritoryData territory) {
  if (territory.isUnclaimed) return 'Sahipsiz bölge';
  final String? name = territory.ownerGuildName?.trim();
  if (name == null || name.isEmpty) return 'Sahipsiz bölge';
  return name;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return WarNeonCard(
      accent: WarPalette.gold,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
