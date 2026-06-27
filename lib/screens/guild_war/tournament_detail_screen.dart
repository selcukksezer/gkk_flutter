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
import 'widgets/guild_war_design.dart';
import 'widgets/guild_war_empty_state.dart';
import 'widgets/guild_war_sub_screen_scaffold.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';

class TournamentDetailScreen extends ConsumerStatefulWidget {
  const TournamentDetailScreen({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  ConsumerState<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends ConsumerState<TournamentDetailScreen> {
  List<GuildWarParticipant> _participants = [];
  GuildWarTournament? _tournament;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final existing = ref.read(guildWarProvider).tournaments;
    if (existing.isEmpty) {
      await ref.read(guildWarProvider.notifier).loadAll();
    }

    final tournaments = ref.read(guildWarProvider).tournaments;
    _tournament = tournaments.where((t) => t.id == widget.tournamentId).firstOrNull;
    _participants =
        await ref.read(guildWarProvider.notifier).loadParticipants(widget.tournamentId);

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _join() async {
    final error =
        await ref.read(guildWarProvider.notifier).joinTournament(widget.tournamentId);
    if (!mounted) return;
    if (error != null) {
      AppMessenger.showError(context, error);
    } else {
      AppMessenger.showSuccess(context, '✅ Turnuvaya katıldınız!');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _tournament;
    final guildId = ref.watch(playerProvider).profile?.guildId;

    Future<void> logout() async => performLogout(ref);

    return GuildWarSubScreenScaffold(
      title: '🏆 Turnuva Detay',
      onLogout: logout,
      currentRoute: AppRoutes.guildWar,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: WarPalette.gold))
          : t == null
              ? GuildWarEmptyState(
                  icon: '🏆',
                  title: 'Turnuva bulunamadı',
                  subtitle:
                      'Bu turnuva silinmiş veya artık mevcut değil. Lonca Savaşı merkezinden aktif turnuvalara bakabilirsin.',
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
                            accent: t.isActive ? WarPalette.gold : WarPalette.titanium,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  t.name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '🏆 Ödül: ${t.prizePool}',
                                  style: const TextStyle(color: WarPalette.gold),
                                ),
                                Text(
                                  '👥 ${t.guildCount} Lonca',
                                  style: const TextStyle(color: WarPalette.titanium),
                                ),
                              ],
                            ),
                          ),
                          const WarSectionHeader(title: 'Katılımcılar'),
                          for (int i = 0; i < _participants.length; i++)
                            WarFadeSlide(
                              index: i,
                              child: WarNeonCard(
                                accent: WarPalette.gold,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    const Icon(Icons.shield_outlined, color: WarPalette.gold, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _participants[i].guildName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (_participants.length >= 2) ...[
                            const WarSectionHeader(title: 'Eşleşmeler', accent: WarPalette.fuchsia),
                            for (int i = 0; i < _participants.length ~/ 2; i++)
                              WarFadeSlide(
                                index: i,
                                child: WarNeonCard(
                                  accent: WarPalette.fuchsia,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _participants[i * 2].guildName,
                                          style: const TextStyle(color: AppColors.textPrimary),
                                        ),
                                      ),
                                      const Text(
                                        ' VS ',
                                        style: TextStyle(
                                          color: WarPalette.ruby,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          _participants[i * 2 + 1].guildName,
                                          textAlign: TextAlign.end,
                                          style: const TextStyle(color: AppColors.textPrimary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    if (t.isActive && guildId != null)
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.base),
                          child: WarGoldButton(
                            label: 'Turnuvaya Katıl',
                            onPressed: _join,
                            expand: true,
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
