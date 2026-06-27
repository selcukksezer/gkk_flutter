import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/guild_war_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_spacing.dart';
import '../../utils/logout_helper.dart';
import 'widgets/attack_log_tile.dart';
import 'widgets/guild_war_design.dart';
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

    Future<void> logout() async => performLogout(ref);

    return GuildWarSubScreenScaffold(
      title: '📜 Savaş Kayıtları',
      onLogout: logout,
      currentRoute: AppRoutes.guildWarLogs,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
            child: const WarSectionHeader(
              title: 'Savaş Günlüğü',
              subtitle: 'Son saldırı kayıtları',
              accent: WarPalette.ruby,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
            child: Row(
              children: <Widget>[
                for (final (String key, String label, Color accent) in <(String, String, Color)>[
                  ('all', 'Tümü', WarPalette.gold),
                  ('win', 'Kazandık', WarPalette.neon),
                  ('loss', 'Kaybettik', WarPalette.ruby),
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: WarFilterChip(
                        label: label,
                        selected: _filter == key,
                        accent: accent,
                        onTap: () => setState(() => _filter = key),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: WarPalette.gold))
                : filtered.isEmpty
                    ? const Center(
                        child: WarEmptyTab(
                          icon: '📜',
                          message: 'Bu filtrede savaş kaydı yok.',
                        ),
                      )
                    : RefreshIndicator(
                        color: WarPalette.gold,
                        backgroundColor: WarPalette.navy,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.base,
                            AppSpacing.base,
                            AppSpacing.base,
                            warBottomInset(context),
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (_, int i) => AttackLogTile(
                            log: filtered[i],
                            myGuildId: guildId,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
