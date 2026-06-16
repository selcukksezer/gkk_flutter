import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/gkk_card.dart';
import '../../models/guild_war_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/guild_war_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'guild_war_defense_sheet.dart';
import 'widgets/attack_log_tile.dart';
import 'widgets/defense_power_bar.dart';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('⚔ Saldır'),
        content: Text('${territory.name} bölgesine saldırmak istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Saldır'),
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

    Future<void> logout() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    }

    return GuildWarSubScreenScaffold(
      title: '🗺 Bölge Detay',
      onLogout: logout,
      currentRoute: AppRoutes.guildWar,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF090D14), Color(0xFF101722)]),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
            : t == null
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(AppSpacing.base),
                          children: [
                            Container(
                              height: 120,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.danger.withValues(alpha: 0.2),
                                    AppColors.bgCard,
                                  ],
                                ),
                                border: Border.all(color: AppColors.borderDefault),
                              ),
                              child: Text(
                                t.name,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.base),
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: AppSpacing.sm,
                              mainAxisSpacing: AppSpacing.sm,
                              childAspectRatio: 1.6,
                              children: [
                                _StatTile(label: 'Savunma', value: '${t.defensePower}', icon: '🛡'),
                                _StatTile(label: 'Trade Geliri', value: '${t.tradeIncome}/gün', icon: '💰'),
                                _StatTile(label: 'Ödül', value: t.reward, icon: '🎁'),
                                _StatTile(label: 'Savunma Hattı', value: 'Sv.${t.defenseLineLevel}', icon: '🏗'),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.base),
                            GkkCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '🏰 ${t.isUnclaimed ? 'Sahipsiz' : t.ownerGuildName}',
                                    style: const TextStyle(color: AppColors.textSecondary),
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
                              const SizedBox(height: AppSpacing.base),
                              const Text(
                                'Son Saldırılar',
                                style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              ..._detail!.recentAttacks.map(
                                (log) => AttackLogTile(log: log, myGuildId: guildId),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (guildId != null)
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.base),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isOwner ? () => _addDefense(t) : () => _attack(t),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isOwner ? AppColors.success : AppColors.danger,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text(isOwner ? 'Savunma Ekle' : 'Saldır'),
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

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return GkkCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10)),
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
