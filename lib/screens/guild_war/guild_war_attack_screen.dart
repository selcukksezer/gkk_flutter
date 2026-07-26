import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/layout/game_screen_background.dart';
import '../../components/common/app_messenger.dart';
import '../../core/utils/combat_restriction.dart';
import '../../models/guild_war_model.dart';
import '../../providers/guild_war_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/logout_helper.dart';
import 'widgets/defense_power_bar.dart';
import 'widgets/guild_war_design.dart';
import 'widgets/guild_war_sub_screen_scaffold.dart';
import 'widgets/territory_guild_duel_panel.dart';

class GuildWarAttackScreen extends ConsumerStatefulWidget {
  const GuildWarAttackScreen({super.key, required this.territoryId});

  final String territoryId;

  @override
  ConsumerState<GuildWarAttackScreen> createState() => _GuildWarAttackScreenState();
}

class _GuildWarAttackScreenState extends ConsumerState<GuildWarAttackScreen> {
  TerritoryAttackPreview? _preview;
  bool _loading = true;
  bool _attacking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final TerritoryAttackPreview? p =
        await ref.read(guildWarProvider.notifier).loadAttackPreview(widget.territoryId);
    if (!mounted) return;
    setState(() {
      _preview = p;
      _loading = false;
    });
  }

  Future<void> _attack() async {
    final profile = ref.read(playerProvider).profile;
    final String? combatBlock = combatRestrictionMessage(
      hospitalUntil: profile?.hospitalUntil,
      prisonUntil: profile?.prisonUntil,
    );
    if (combatBlock != null) {
      AppMessenger.showError(context, combatBlock);
      return;
    }
    if (_preview != null && !_preview!.canAfford) {
      AppMessenger.showError(context, 'Lonca kasasında yeterli altın yok.');
      return;
    }

    setState(() => _attacking = true);
    final GuildWarAttackResult? result =
        await ref.read(guildWarProvider.notifier).attackTerritory(widget.territoryId);
    if (!mounted) return;
    setState(() => _attacking = false);

    if (result == null) return;
    if (result.error != null) {
      AppMessenger.showError(context, result.error!);
      await _load();
      return;
    }
    await context.push(AppRoutes.guildWarBattleResult, extra: result);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final TerritoryAttackPreview? p = _preview;

    return GuildWarSubScreenScaffold(
      title: '⚔ Lonca Saldırısı',
      onLogout: () async => performLogout(ref),
      currentRoute: AppRoutes.guildWar,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: WarPalette.gold))
          : p == null || p.error != null
              ? Center(child: Text(p?.error ?? 'Önizleme yüklenemedi'))
              : ListView(
                  padding: GameScrollLayout.pagePadding(context),
                  children: <Widget>[
                    Text(
                      p.territoryName,
                      style: GoogleFonts.urbanist(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: WarPalette.gold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.base),
                    TerritoryGuildDuelPanel(
                      attacker: p.attackerGuild,
                      defender: p.defenderGuild,
                    ),
                    const SizedBox(height: AppSpacing.base),
                    WarNeonCard(
                      accent: WarPalette.coral,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _row('Saldırı maliyeti', '${p.attackGoldCost} 🪙'),
                          _row('Günlük gelir', '${p.tradeIncome} 🪙'),
                          if (p.roiDays != null) _row('ROI', '~${p.roiDays} gün'),
                          _row('Kasa', '${p.vaultGold} 🪙'),
                          _row('Tahmini şans', '%${p.winChancePct.toStringAsFixed(1)}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.base),
                    DefensePowerBar(
                      current: p.attackPower,
                      max: p.attackPower + p.defensePower,
                      height: 14,
                      showLabel: false,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _attacking || !p.canAfford ? null : _attack,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WarPalette.ruby,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          _attacking
                              ? 'Saldırılıyor…'
                              : p.canAfford
                                  ? 'Saldır (${p.attackGoldCost}g)'
                                  : 'Kasa yetersiz',
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
