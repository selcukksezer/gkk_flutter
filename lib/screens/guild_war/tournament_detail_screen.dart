import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/gkk_card.dart';
import '../../models/guild_war_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/guild_war_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
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

    Future<void> logout() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    }

    return GuildWarSubScreenScaffold(
      title: '🏆 Turnuva Detay',
      onLogout: logout,
      currentRoute: AppRoutes.guildWar,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF090D14), Color(0xFF101722)],
          ),
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
                            GkkCard(
                              borderGlow: t.isActive,
                              accentColor: AppColors.gold,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('🏆 Ödül: ${t.prizePool}', style: const TextStyle(color: AppColors.gold)),
                                  Text('👥 ${t.guildCount} Lonca', style: const TextStyle(color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.base),
                            const Text(
                              'Katılımcılar',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            ..._participants.map(
                              (p) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: GkkCard(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.shield_outlined, color: AppColors.gold, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          p.guildName,
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
                            ),
                            if (_participants.length >= 2) ...[
                              const SizedBox(height: AppSpacing.base),
                              const Text(
                                'Eşleşmeler',
                                style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              ...List.generate(
                                _participants.length ~/ 2,
                                (i) {
                                  final a = _participants[i * 2];
                                  final b = _participants[i * 2 + 1];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                    child: GkkCard(
                                      child: Row(
                                        children: [
                                          Expanded(child: Text(a.guildName, style: const TextStyle(color: AppColors.textPrimary))),
                                          const Text(' VS ', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
                                          Expanded(child: Text(b.guildName, textAlign: TextAlign.end, style: const TextStyle(color: AppColors.textPrimary))),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (t.isActive && guildId != null)
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.base),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _join,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.gold,
                                  foregroundColor: AppColors.bgDeep,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text('Turnuvaya Katıl'),
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
