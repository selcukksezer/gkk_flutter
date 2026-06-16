import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/guild_war_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'widgets/attack_log_tile.dart';
import 'widgets/guild_war_sub_screen_scaffold.dart';

class WarLogsScreen extends ConsumerStatefulWidget {
  const WarLogsScreen({super.key});

  @override
  ConsumerState<WarLogsScreen> createState() => _WarLogsScreenState();
}

class _WarLogsScreenState extends ConsumerState<WarLogsScreen> {
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await ref.read(guildWarProvider.notifier).loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(guildWarProvider).attackLogs;
    final guildId = ref.watch(playerProvider).profile?.guildId;
    final isLoading = ref.watch(guildWarProvider).isLoading;

    var filtered = logs;
    if (_filter == 'win') {
      filtered = logs.where((l) => l.attackerGuildId == guildId && l.success).toList();
    } else if (_filter == 'loss') {
      filtered = logs.where((l) => l.defenderGuildId == guildId && !l.success).toList();
    }

    Future<void> logout() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    }

    return GuildWarSubScreenScaffold(
      title: '📜 Savaş Kayıtları',
      onLogout: logout,
      currentRoute: AppRoutes.guildWarLogs,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF090D14), Color(0xFF101722)],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md, AppSpacing.base, 0),
              child: Row(
                children: [
                  for (final f in [
                    ('all', 'Tümü'),
                    ('win', 'Kazandık'),
                    ('loss', 'Kaybettik'),
                  ])
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _filter = f.$1),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _filter == f.$1
                                ? AppColors.gold.withValues(alpha: 0.18)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            border: Border.all(
                              color: _filter == f.$1 ? AppColors.gold : AppColors.borderDefault,
                            ),
                          ),
                          child: Text(
                            f.$2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _filter == f.$1 ? AppColors.gold : AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                  : RefreshIndicator(
                      color: AppColors.gold,
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.base),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => AttackLogTile(
                          log: filtered[i],
                          myGuildId: guildId,
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
