import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_screen_background.dart';
import '../../models/guild_war_model.dart';
import '../../providers/guild_war_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/logout_helper.dart';
import 'guild_war_defense_sheet.dart';
import 'widgets/attack_log_tile.dart';
import 'widgets/defense_power_bar.dart';
import 'widgets/guild_war_design.dart';
import 'widgets/guild_war_empty_state.dart';
import 'widgets/guild_war_sub_screen_scaffold.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';

class TerritoryDetailScreen extends ConsumerStatefulWidget {
  const TerritoryDetailScreen({super.key, required this.territoryId});

  final String territoryId;

  @override
  ConsumerState<TerritoryDetailScreen> createState() => _TerritoryDetailScreenState();
}

class _TerritoryDetailScreenState extends ConsumerState<TerritoryDetailScreen> {
  TerritoryDetail? _detail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final detail =
        await ref.read(guildWarProvider.notifier).loadTerritoryDetail(widget.territoryId);
    if (mounted) {
      setState(() {
        _detail = detail;
        _loading = false;
      });
    }
  }

  Future<void> _attack(TerritoryData territory) async {
    final bool? confirmed = await WarDialog.confirm(
      context: context,
      title: '⚔ Saldır',
      message: '${territory.name} bölgesine saldırmak istiyor musunuz?',
      confirmLabel: 'Saldır',
      accent: WarPalette.ruby,
    );
    if (confirmed != true) return;

    final result = await ref.read(guildWarProvider.notifier).attackTerritory(territory.id);
    if (!mounted || result == null) return;
    if (result.error != null) {
      AppMessenger.showError(context, result.error!);
      return;
    }
    if (!mounted) return;
    context.push(AppRoutes.guildWarBattleResult, extra: result).then((_) => _load());
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
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final guildId = ref.watch(playerProvider).profile?.guildId;
    final t = _detail?.territory;
    final isOwner = t != null && t.ownerGuildId == guildId;

    Future<void> logout() async => performLogout(ref);

    return GuildWarSubScreenScaffold(
      title: '🗺 Bölge Detay',
      onLogout: logout,
      currentRoute: AppRoutes.guildWar,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: WarPalette.gold))
          : t == null
              ? GuildWarEmptyState(
                  icon: '🗺',
                  title: 'Bölge bulunamadı',
                  subtitle:
                      'Bu bölge haritada artık yok veya veri yüklenemedi. Lonca Savaşı merkezinden haritaya dönebilirsin.',
                  actionLabel: 'Lonca Savaşı\'na Dön',
                  onAction: () => context.go(AppRoutes.guildWar),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: GameScrollLayout.pagePadding(context),
                        children: [
                          WarHeroBanner(
                            accent: t.isUnclaimed ? WarPalette.coral : WarPalette.fuchsia,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  t.name,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  t.isUnclaimed ? '🏰 Sahipsiz bölge' : '🏰 ${t.ownerGuildName}',
                                  style: const TextStyle(color: WarPalette.titanium),
                                ),
                              ],
                            ),
                          ),
                          GameGridColumns(
                            crossAxisCount: 2,
                            children: [
                              _StatTile(label: 'Savunma', value: '${t.defensePower}', icon: '🛡'),
                              _StatTile(label: 'Trade Geliri', value: '${t.tradeIncome}/gün', icon: '💰'),
                              _StatTile(label: 'Ödül', value: t.reward, icon: '🎁'),
                              _StatTile(label: 'Savunma Hattı', value: 'Sv.${t.defenseLineLevel}', icon: '🏗'),
                            ],
                          ),
                          WarNeonCard(
                            accent: WarPalette.neon,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '🏰 ${t.isUnclaimed ? 'Sahipsiz' : t.ownerGuildName}',
                                  style: const TextStyle(color: WarPalette.titanium),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                DefensePowerBar(
                                  current: t.defensePower,
                                  max: t.baseDefensePower,
                                  height: 10,
                                ),
                              ],
                            ),
                          ),
                          if (_detail!.recentAttacks.isNotEmpty) ...[
                            const WarSectionHeader(title: 'Son Saldırılar', accent: WarPalette.ruby),
                            for (int i = 0; i < _detail!.recentAttacks.length; i++)
                              WarFadeSlide(
                                index: i,
                                child: AttackLogTile(
                                  log: _detail!.recentAttacks[i],
                                  myGuildId: guildId,
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    if (guildId != null)
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.base),
                          child: isOwner
                              ? WarDefenseButton(onPressed: () => _addDefense(t))
                              : WarAttackButton(onPressed: () => _attack(t)),
                        ),
                      ),
                  ],
                ),
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
          Text(label, style: const TextStyle(color: WarPalette.titanium, fontSize: 10)),
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
