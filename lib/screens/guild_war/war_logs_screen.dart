import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/guild_war_model.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bool hasCachedLogs = ref.read(guildWarProvider).attackLogs.isNotEmpty;
      _load(showLoading: !hasCachedLogs);
    });
  }

  Future<void> _load({bool showLoading = true}) async {
    await ref.read(guildWarProvider.notifier).loadAttackLogs(showLoading: showLoading);
  }

  @override
  Widget build(BuildContext context) {
    final GuildWarState warState = ref.watch(guildWarProvider);
    final String? guildId = ref.watch(playerProvider).profile?.guildId;
    final bool hasGuild = guildId != null;
    final List<GuildWarAttackLog> filtered = warState.filteredAttackLogs(guildId);
    final GuildWarAttackLogFilter filter = warState.attackLogFilter;
    final bool isLoading = warState.isLoading;

    if (!hasGuild && filter != GuildWarAttackLogFilter.all) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(guildWarProvider.notifier).setAttackLogFilter(GuildWarAttackLogFilter.all);
      });
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
                for (final (GuildWarAttackLogFilter value, String label, Color accent)
                    in <(GuildWarAttackLogFilter, String, Color)>[
                  (GuildWarAttackLogFilter.all, 'Tümü', WarPalette.gold),
                  (GuildWarAttackLogFilter.win, 'Kazandık', WarPalette.neon),
                  (GuildWarAttackLogFilter.loss, 'Kaybettik', WarPalette.ruby),
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: WarFilterChip(
                        label: label,
                        selected: filter == value,
                        accent: accent,
                        enabled: value == GuildWarAttackLogFilter.all || hasGuild,
                        onTap: () => ref.read(guildWarProvider.notifier).setAttackLogFilter(value),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: <Widget>[
                if (isLoading && filtered.isEmpty)
                  const Center(child: CircularProgressIndicator(color: WarPalette.gold))
                else if (filtered.isEmpty)
                  const Center(
                    child: WarEmptyTab(
                      icon: '📜',
                      message: 'Bu filtrede savaş kaydı yok.',
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      return RefreshIndicator(
                        color: WarPalette.gold,
                        backgroundColor: WarPalette.navy,
                            onRefresh: () => _load(showLoading: true),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                AppSpacing.base,
                                AppSpacing.base,
                                AppSpacing.base,
                                warBottomInset(context),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  for (final GuildWarAttackLog log in filtered)
                                    AttackLogTile(
                                      log: log,
                                      myGuildId: guildId,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                if (isLoading && filtered.isNotEmpty)
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
          ),
        ],
      ),
    );
  }
}
