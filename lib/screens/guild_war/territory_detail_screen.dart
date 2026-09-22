import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_screen_background.dart';
import '../../models/dungeon_siege_model.dart';
import '../../models/guild_war_model.dart';
import '../../providers/guild_provider.dart';
import '../../providers/guild_war_provider.dart';
import '../../providers/guild_vault_provider.dart';
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
  late final GuildWarNotifier _guildWar;
  Map<String, dynamic>? _attackPlan;
  Map<String, dynamic>? _garrison;
  bool _planBusy = false;
  bool _garrisonBusy = false;

  @override
  void initState() {
    super.initState();
    _guildWar = ref.read(guildWarProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  @override
  void dispose() {
    _guildWar.clearTerritoryDetail();
    super.dispose();
  }

  Future<void> _load() async {
    await _guildWar.loadTerritoryDetail(widget.territoryId);
    final Map<String, dynamic>? plan = await _guildWar.loadAttackPlan(widget.territoryId);
    final Map<String, dynamic>? garrison =
        await _guildWar.loadTerritoryGarrisonStatus(widget.territoryId);
    unawaited(ref.read(guildVaultProvider.notifier).load(silent: true));
    if (!mounted) return;
    setState(() {
      _attackPlan = plan;
      _garrison = garrison;
    });
  }

  Future<void> _attack(TerritoryData territory) async {
    await context.push('${AppRoutes.guildWarTerritory}/${territory.id}/attack');
    if (mounted) await _load();
  }

  Future<void> _addDefense(TerritoryData territory) async {
    final profile = ref.read(playerProvider).profile;
    final int? gems = await showGuildWarDefenseSheet(
      context,
      minDefenseGems: territory.minDefenseGems,
      playerGems: profile?.gems,
    );
    if (gems == null || gems <= 0) return;
    final String? error = await _guildWar.addDefense(territory.id, gems);
    if (!mounted) return;
    if (error != null) {
      AppMessenger.showError(context, error);
    } else {
      AppMessenger.showSuccess(context, '🛡 Savunma eklendi!');
      await _load();
    }
  }

  Future<void> _joinGarrison(TerritoryData territory) async {
    setState(() => _garrisonBusy = true);
    final (:error, :message) = await _guildWar.joinGarrison(territory.id);
    if (!mounted) return;
    setState(() => _garrisonBusy = false);
    if (error != null) {
      AppMessenger.showError(context, error);
      return;
    }
    AppMessenger.showSuccess(context, message ?? 'Nöbete yazıldın!');
    await _load();
  }

  Future<void> _leaveGarrison() async {
    setState(() => _garrisonBusy = true);
    final (:error, :message) = await _guildWar.leaveGarrison();
    if (!mounted) return;
    setState(() => _garrisonBusy = false);
    if (error != null) {
      AppMessenger.showError(context, error);
      return;
    }
    AppMessenger.showSuccess(context, message ?? 'Nöbetten ayrıldın.');
    await _load();
  }

  List<Widget> _garrisonOwnerActions(TerritoryData t) {
    final bool iAmHere = _garrison?['i_am_here'] == true;
    final Map<String, dynamic>? myPost = _garrison?['my_post'] is Map
        ? Map<String, dynamic>.from(_garrison!['my_post'] as Map)
        : null;
    final bool onDutyElsewhere = !iAmHere && myPost != null;
    final String elsewhereName = myPost?['territory_name']?.toString() ?? 'başka bölge';

    if (iAmHere) {
      return <Widget>[
        WarOutlineButton(
          label: _garrisonBusy ? '…' : 'Nöbette — ayrıl',
          icon: Icons.shield_rounded,
          onPressed: _garrisonBusy ? null : _leaveGarrison,
        ),
      ];
    }
    if (onDutyElsewhere) {
      return <Widget>[
        WarOutlineButton(
          label: _garrisonBusy ? '…' : 'Nöbeti buraya taşı ($elsewhereName →)',
          icon: Icons.swap_horiz_rounded,
          onPressed: _garrisonBusy ? null : () => _joinGarrison(t),
        ),
        const SizedBox(height: 8),
        WarOutlineButton(
          label: _garrisonBusy ? '…' : 'Nöbetten ayrıl',
          icon: Icons.logout_rounded,
          onPressed: _garrisonBusy ? null : _leaveGarrison,
        ),
      ];
    }
    return <Widget>[
      WarOutlineButton(
        label: _garrisonBusy ? '…' : 'Nöbete yazıl (garnizon)',
        icon: Icons.shield_moon_rounded,
        onPressed: _garrisonBusy ? null : () => _joinGarrison(t),
      ),
    ];
  }

  Future<void> _openAttackPlan(TerritoryData territory) async {
    setState(() => _planBusy = true);
    final (:error, :message) = await _guildWar.openAttackPlan(territory.id);
    if (!mounted) return;
    setState(() => _planBusy = false);
    if (error != null) {
      AppMessenger.showError(context, error);
      return;
    }
    AppMessenger.showSuccess(
      context,
      message ?? 'Saldırı planı açıldı — üyeler destek verebilir.',
    );
    await _load();
  }

  Future<void> _pledgeSupport() async {
    final String? planId = _attackPlan?['plan_id']?.toString();
    if (planId == null || planId.isEmpty) {
      AppMessenger.showError(context, 'Açık plan yok.');
      return;
    }
    setState(() => _planBusy = true);
    final String? error = await _guildWar.pledgeAttackSupport(planId);
    if (!mounted) return;
    setState(() => _planBusy = false);
    if (error != null) {
      AppMessenger.showError(context, error);
      return;
    }
    AppMessenger.showSuccess(context, 'Takviye verildi!');
    await _load();
  }

  Future<void> _addAttackGems() async {
    final String? planId = _attackPlan?['plan_id']?.toString();
    if (planId == null || planId.isEmpty) {
      AppMessenger.showError(context, 'Açık plan yok.');
      return;
    }
    final profile = ref.read(playerProvider).profile;
    final int? gems = await showGuildWarAttackGemSheet(
      context,
      playerGems: profile?.gems,
    );
    if (gems == null || gems <= 0) return;
    setState(() => _planBusy = true);
    final (:error, :message) = await _guildWar.addAttackGems(planId, gems);
    if (!mounted) return;
    setState(() => _planBusy = false);
    if (error != null) {
      AppMessenger.showError(context, error);
      return;
    }
    AppMessenger.showSuccess(context, message ?? 'Elmas saldırı desteği eklendi!');
    try {
      await ref.read(playerProvider.notifier).loadProfile();
    } catch (_) {}
    await _load();
  }

  Widget _buildAttackPlanCard({required bool isOwner}) {
    final Map<String, dynamic>? plan = _attackPlan;
    final bool open = plan != null && plan['open'] == true;
    if (isOwner) return const SizedBox.shrink();

    if (!open) {
      return WarNeonCard(
        accent: WarPalette.titanium,
        child: const Text(
          'Açık saldırı planı yok. Lider “Saldırı planı aç”; üyeler güç + elmas (1💎=+10) destekler, sonra lider saldırır (maliyet 10M kasadan). Süre yok.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      );
    }

    final List<dynamic> supporters = plan['supporters'] is List
        ? plan['supporters'] as List
        : const <dynamic>[];
    final int supportSum = (plan['support_sum'] is num) ? (plan['support_sum'] as num).toInt() : 0;
    final int gemBoost =
        (plan['gem_attack_boost'] is num) ? (plan['gem_attack_boost'] as num).toInt() : 0;
    final int estimated = (plan['estimated_attack_power'] is num)
        ? (plan['estimated_attack_power'] as num).toInt()
        : supportSum + gemBoost;
    final bool iPledged = plan['i_pledged'] == true;
    final bool isLeader = plan['is_leader'] == true;

    return WarNeonCard(
      accent: WarPalette.ruby,
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '⚔ Açık saldırı planı',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tahmini atk: $estimated'
            ' (güç $supportSum'
            '${gemBoost > 0 ? ' + elmas $gemBoost' : ''})',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            supporters.isEmpty
                ? 'Henüz güç takviyesi yok.'
                : 'Takviye (${supporters.length}): ${supporters.map((dynamic s) {
                    if (s is! Map) return '?';
                    final Map<String, dynamic> m = Map<String, dynamic>.from(s);
                    return '${m['username'] ?? '?'}(${m['power'] ?? 0})';
                  }).join(', ')}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 10),
          if (!isLeader)
            WarOutlineButton(
              label: iPledged ? 'Takviye verildi ✓' : 'Takviye ver (güç)',
              icon: Icons.fitness_center_rounded,
              onPressed: (_planBusy || iPledged) ? null : _pledgeSupport,
            )
          else
            const Text(
              'Lider: üyeler güç + elmas desteklesin, sonra Saldır.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          const SizedBox(height: 8),
          WarOutlineButton(
            label: _planBusy ? '…' : 'Elmas saldırı desteği (1💎=+10)',
            icon: Icons.diamond_rounded,
            onPressed: _planBusy ? null : _addAttackGems,
          ),
        ],
      ),
    );
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
    final liveVault = ref.watch(guildVaultProvider);
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
    final int displayVaultGold = liveVault.hydrated
        ? liveVault.vaultGold
        : (t?.vaultSummary?.vaultGold ?? liveVault.vaultGold);

    Future<void> logout() async => performLogout(ref);

    return GuildWarSubScreenScaffold(
      title: '🗺 Bölge Detay',
      onLogout: logout,
      currentRoute: AppRoutes.guildWar,
      body: Stack(
        children: <Widget>[
          if (loading && t == null)
            const Center(child: CircularProgressIndicator(color: WarPalette.gold))
          else if (t == null && isCurrentTerritory && warState.error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('⚠️', style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 10),
                    Text(
                      warState.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded,
                          size: 16, color: WarPalette.gold),
                      label: const Text('Tekrar Dene',
                          style: TextStyle(color: WarPalette.gold)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: WarPalette.gold.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
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
                      if (t.vaultSummary != null || liveVault.hydrated) ...<Widget>[
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
                                      'Kasa: ${displayVaultGold}g',
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
                                    if (t.tradeIncome > 0)
                                      Text(
                                        'Ticaret ${t.tradeIncome}g/gün (~${(t.tradeIncome / 24).round()}g/saat) kasada birikir. Günde 6-7 rastgele eşya (common hariç).',
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
                          color: WarPalette.navy,
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
                                          : WarPalette.ruby)
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
                                            : WarPalette.coral,
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
                      _buildAttackPlanCard(isOwner: isOwner),
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
                          _StatTile(label: 'Ticaret Geliri', value: '${t.tradeIncome}/gün', icon: '💰'),
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
                              'Savunma = garnizon Σ power + elmas + hat×200. '
                              '1 üye → 1 bölge nöbet. Elmas her an; kayıp → elmas sıfır. '
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
                            const SizedBox(height: AppSpacing.sm),
                            _GarrisonStatusBlock(
                              garrison: _garrison,
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (isOwner) ...<Widget>[
                            ..._garrisonOwnerActions(t),
                            const SizedBox(height: 8),
                            WarDefenseButton(onPressed: () => _addDefense(t)),
                          ] else ...<Widget>[
                            if (_attackPlan?['open'] != true)
                              WarOutlineButton(
                                label: _planBusy ? '…' : 'Saldırı planı aç (lider)',
                                icon: Icons.flag_rounded,
                                onPressed: (combatLocked || _planBusy)
                                    ? null
                                    : () => _openAttackPlan(t),
                              )
                            else
                              WarOutlineButton(
                                label: 'Plan açık — yeniden açılamaz',
                                icon: Icons.lock_rounded,
                                onPressed: null,
                              ),
                            const SizedBox(height: 8),
                            if (_attackPlan?['open'] == true && _attackPlan?['is_leader'] != true)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: WarOutlineButton(
                                  label: _attackPlan?['i_pledged'] == true
                                      ? 'Takviye verildi ✓'
                                      : 'Takviye ver',
                                  icon: Icons.fitness_center_rounded,
                                  onPressed: (_planBusy || _attackPlan?['i_pledged'] == true)
                                      ? null
                                      : _pledgeSupport,
                                ),
                              ),
                            WarAttackButton(
                              onPressed: combatLocked ? null : () => _attack(t),
                            ),
                          ],
                        ],
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

class _GarrisonStatusBlock extends StatelessWidget {
  const _GarrisonStatusBlock({
    required this.garrison,
  });

  final Map<String, dynamic>? garrison;

  @override
  Widget build(BuildContext context) {
    if (garrison == null) {
      return const Text(
        'Garnizon yükleniyor…',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
      );
    }

    final int count = (garrison!['garrison_count'] as num?)?.toInt() ?? 0;
    final int gPower = (garrison!['garrison_power'] as num?)?.toInt() ?? 0;
    final int effective = (garrison!['effective_defense'] as num?)?.toInt() ?? 0;
    final int base = (garrison!['base_defense_power'] as num?)?.toInt() ?? 0;
    final int gem = (garrison!['gem_defense_boost'] as num?)?.toInt() ?? 0;
    final int line = (garrison!['defense_line_level'] as num?)?.toInt() ?? 0;
    final bool iAmHere = garrison!['i_am_here'] == true;
    final Map<String, dynamic>? myPost = garrison!['my_post'] is Map
        ? Map<String, dynamic>.from(garrison!['my_post'] as Map)
        : null;
    final List<Map<String, dynamic>> members = (garrison!['members'] is List)
        ? (garrison!['members'] as List)
            .whereType<Map>()
            .map((Map e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    final String dutyLine;
    if (iAmHere) {
      dutyLine = 'Sen: bu bölgede nöbette — gücün savunmaya ekli.';
    } else if (myPost != null) {
      dutyLine =
          'Sen: ${myPost['territory_name'] ?? 'başka bölge'} nöbetindesin (1 üye → 1 bölge).';
    } else {
      dutyLine = 'Sen: nöbette değilsin.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          dutyLine,
          style: TextStyle(
            color: iAmHere ? WarPalette.neon : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          count == 0
              ? 'Garnizon boş → base savunma ($base) kullanılır.'
              : 'Garnizon $count kişi · Σ power $gPower · gem $gem · hat Lv$line → etkili $effective',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
        ),
        if (members.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            members
                .map(
                  (Map<String, dynamic> r) =>
                      '${r['is_me'] == true ? '★' : ''}${r['username'] ?? '?'}(${r['power'] ?? 0})',
                )
                .join(', '),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ],
    );
  }
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
