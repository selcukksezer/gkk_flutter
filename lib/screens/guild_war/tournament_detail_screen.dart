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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    ref.read(guildWarProvider.notifier).clearTournamentDetail();
    super.dispose();
  }

  Future<void> _load() async {
    await ref.read(guildWarProvider.notifier).loadTournamentDetail(widget.tournamentId);
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

  bool _isParticipant(List<GuildWarParticipant> participants, String? guildId) {
    if (guildId == null) return false;
    return participants.any((GuildWarParticipant p) => p.guildId == guildId);
  }

  @override
  Widget build(BuildContext context) {
    final GuildWarState warState = ref.watch(guildWarProvider);
    final bool isCurrentTournament = warState.activeTournamentId == widget.tournamentId;
    final GuildWarTournament? t =
        isCurrentTournament ? warState.tournamentDetail : null;
    final List<GuildWarParticipant> participants =
        isCurrentTournament ? warState.tournamentParticipants : const [];
    final List<GuildWarTournamentRound> rounds =
        isCurrentTournament ? warState.tournamentRounds : const [];
    final bool loading = isCurrentTournament && warState.isTournamentDetailLoading;
    final guildId = ref.watch(playerProvider).profile?.guildId;
    final bool isParticipant = _isParticipant(participants, guildId);
    final bool showJoinCta = t != null && t.isActive && guildId != null && !isParticipant;

    Future<void> logout() async => performLogout(ref);

    return GuildWarSubScreenScaffold(
      title: '🏆 Turnuva Detay',
      onLogout: logout,
      currentRoute: AppRoutes.guildWar,
      body: Stack(
        children: <Widget>[
          if (loading && t == null)
            const Center(child: CircularProgressIndicator(color: WarPalette.gold))
          else if (t == null && isCurrentTournament && warState.error != null)
            GuildWarEmptyState(
              icon: '⚠️',
              title: 'Turnuva yüklenemedi',
              subtitle: warState.error!,
              actionLabel: 'Tekrar Dene',
              onAction: _load,
            )
          else if (t == null)
            GuildWarEmptyState(
              icon: '🏆',
              title: 'Turnuva bulunamadı',
              subtitle:
                  'Bu turnuva silinmiş veya artık mevcut değil. Lonca Savaşı merkezinden aktif turnuvalara bakabilirsin.',
              actionLabel: 'Lonca Savaşı\'na Dön',
              onAction: () => context.go(AppRoutes.guildWar),
            )
          else
            Column(
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
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    t.name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (isParticipant)
                                  const WarStatusPill(label: 'Katıldın', color: WarPalette.neon),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '🏆 Ödül: ${formatGuildWarPrizePool(t.prizePool)}',
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
                      if (participants.isEmpty)
                        GuildWarEmptyState(
                          icon: '👥',
                          title: 'Henüz katılımcı yok',
                          subtitle: t.isActive
                              ? 'İlk katılan lonca olmak için aşağıdaki butona dokun.'
                              : 'Bu turnuva kayıtları kapalı veya henüz başlamadı.',
                          actionLabel: showJoinCta ? 'Turnuvaya Katıl' : null,
                          onAction: showJoinCta ? _join : null,
                        )
                      else
                        for (int i = 0; i < participants.length; i++)
                          WarFadeSlide(
                            index: i,
                            child: WarNeonCard(
                              accent: participants[i].guildId == guildId
                                  ? WarPalette.neon
                                  : WarPalette.gold,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.shield_outlined, color: WarPalette.gold, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      participants[i].guildName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (participants[i].guildId == guildId)
                                    const WarStatusPill(label: 'Sen', color: WarPalette.neon),
                                ],
                              ),
                            ),
                          ),
                      if (t.isActive && rounds.isNotEmpty) ...[
                        for (final GuildWarTournamentRound round in rounds) ...[
                          WarSectionHeader(title: round.title, accent: WarPalette.fuchsia),
                          for (int i = 0; i < round.matches.length; i++)
                            WarFadeSlide(
                              index: i,
                              child: _TournamentMatchCard(
                                match: round.matches[i],
                                playerGuildId: guildId,
                              ),
                            ),
                        ],
                      ] else if (t.isActive && participants.length >= 2) ...[
                        const WarSectionHeader(title: 'Eşleşmeler', accent: WarPalette.fuchsia),
                        GuildWarEmptyState(
                          icon: '⚔',
                          title: 'Clash başlayınca burada canlı skor',
                          subtitle:
                              'Bracket seed sonrası 12 saatlik Clash pencereleri açılır. Üyeler PvP / zindan / rally ile katkı verir.',
                        ),
                      ] else if (!t.isActive && participants.length >= 2) ...[
                        const WarSectionHeader(title: 'Eşleşmeler', accent: WarPalette.fuchsia),
                        GuildWarEmptyState(
                          icon: '📋',
                          title: 'Kayıt devam ediyor',
                          subtitle: 'Eşleşmeler turnuva aktif olunca rank_score sıralamasına göre oluşturulur.',
                        ),
                      ],
                    ],
                  ),
                ),
                if (showJoinCta)
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

class _TournamentMatchCard extends StatelessWidget {
  const _TournamentMatchCard({
    required this.match,
    required this.playerGuildId,
  });

  final GuildWarTournamentMatch match;
  final String? playerGuildId;

  bool _isPlayerGuild(String? guildId) =>
      guildId != null && playerGuildId != null && guildId == playerGuildId;

  @override
  Widget build(BuildContext context) {
    final bool g1Winner = match.isCompleted && match.winnerGuildId == match.guild1Id;
    final bool g2Winner = match.isCompleted && match.winnerGuildId == match.guild2Id;

    return WarNeonCard(
      accent: WarPalette.fuchsia,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _GuildMatchRow(
                  name: match.guild1Name,
                  score: match.guild1Score,
                  isWinner: g1Winner,
                  isPlayer: _isPlayerGuild(match.guild1Id),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: WarPalette.ruby,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: _GuildMatchRow(
                  name: match.guild2Name,
                  score: match.guild2Score,
                  isWinner: g2Winner,
                  isPlayer: _isPlayerGuild(match.guild2Id),
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.center,
            child: WarStatusPill(
              label: match.isLive
                  ? 'CANLI CLASH'
                  : (match.isPending ? 'Bekliyor' : 'Tamamlandı'),
              color: match.isLive
                  ? WarPalette.ruby
                  : (match.isPending ? WarPalette.titanium : WarPalette.neon),
            ),
          ),
          if (match.isLive && match.windowEnd != null) ...[
            const SizedBox(height: 4),
            Text(
              'Bitiş: ${match.windowEnd!.toLocal()}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

class _GuildMatchRow extends StatelessWidget {
  const _GuildMatchRow({
    required this.name,
    required this.score,
    required this.isWinner,
    required this.isPlayer,
    this.alignEnd = false,
  });

  final String name;
  final int score;
  final bool isWinner;
  final bool isPlayer;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: TextStyle(
            color: isWinner ? WarPalette.gold : AppColors.textPrimary,
            fontWeight: isWinner || isPlayer ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        if (matchHasScore)
          Text(
            '$score',
            style: TextStyle(
              color: isWinner ? WarPalette.gold : WarPalette.titanium,
              fontSize: 12,
            ),
          ),
        if (isPlayer)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: WarStatusPill(label: 'Sen', color: WarPalette.neon),
          ),
      ],
    );
  }

  bool get matchHasScore => score > 0;
}
