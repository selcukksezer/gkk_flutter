import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../core/utils/provider_scheduling.dart';
import '../../components/common/profile_avatar.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/common/gkk_tab_page_shell.dart';
import '../../components/layout/game_screen_background.dart';
import '../../l10n/l10n.dart';
import '../../core/services/retention_analytics.dart';
import '../../core/services/supabase_service.dart';
import '../../models/player_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/pvp_provider.dart';
import '../../models/nemesis_model.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import 'widgets/nemesis_rival_panel.dart';

class OnlinePlayer {
  const OnlinePlayer({
    required this.authId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.level,
    required this.power,
    required this.pvpRating,
  });

  final String authId;
  final String username;
  final String displayName;
  final String avatarUrl;
  final int level;
  final int power;
  final int pvpRating;

  factory OnlinePlayer.fromJson(Map<String, dynamic> json) {
    final String username = (json['username'] ?? '').toString();
    return OnlinePlayer(
      authId: (json['auth_id'] ?? '').toString(),
      username: username,
      displayName: (json['display_name'] ?? '').toString().isNotEmpty
          ? (json['display_name'] ?? '').toString()
          : username,
      avatarUrl: (json['avatar_url'] ?? '').toString(),
      level: (json['level'] as num?)?.toInt() ?? 1,
      power: (json['power'] as num?)?.toInt() ?? 0,
      pvpRating: (json['pvp_rating'] as num?)?.toInt() ?? 1000,
    );
  }
}

class PvpScreen extends ConsumerStatefulWidget {
  const PvpScreen({super.key, this.revengeTargetId});

  final String? revengeTargetId;

  @override
  ConsumerState<PvpScreen> createState() => _PvpScreenState();
}

class _PvpScreenState extends ConsumerState<PvpScreen> {
  List<OnlinePlayer> _onlinePlayers = const <OnlinePlayer>[];
  bool _loadingOnline = false;
  String? _invitingId;
  NemesisRival _nemesis = NemesisRival.none;
  bool _dismissLoading = false;
  bool _revengeHandled = false;

  @override
  void initState() {
    super.initState();
    deferProviderUpdate(() {
      ref.read(playerProvider.notifier).loadProfile();
      ref.read(pvpDashboardProvider.notifier).load();
    });
    _loadOnlinePlayers();
    _loadNemesis();
  }

  @override
  void activate() {
    super.activate();
    deferProviderUpdate(() {
      ref.read(playerProvider.notifier).loadProfile();
      ref.read(pvpDashboardProvider.notifier).load();
    });
  }

  Future<void> _loadNemesis() async {
    try {
      final dynamic res = await SupabaseService.client.rpc('get_nemesis_rival');
      if (!mounted || res is! Map) return;
      setState(() => _nemesis = NemesisRival.fromJson(Map<String, dynamic>.from(res)));
      _maybeOpenRevengeInvite();
    } catch (_) {}
  }

  Future<void> _dismissNemesisBanner() async {
    setState(() => _dismissLoading = true);
    try {
      await SupabaseService.client.rpc('dismiss_nemesis_banner');
      await _loadNemesis();
    } finally {
      if (mounted) setState(() => _dismissLoading = false);
    }
  }

  void _maybeOpenRevengeInvite() {
    if (_revengeHandled) return;
    final String? targetId = widget.revengeTargetId;
    if (targetId == null || targetId.isEmpty) return;
    _revengeHandled = true;

    OnlinePlayer? target;
    for (final OnlinePlayer p in _onlinePlayers) {
      if (p.authId == targetId) {
        target = p;
        break;
      }
    }

    target ??= OnlinePlayer(
      authId: targetId,
      username: _nemesis.rivalUsername ?? 'Rakip',
      displayName: _nemesis.rivalUsername ?? 'Rakip',
      avatarUrl: '',
      level: _nemesis.level,
      power: _nemesis.power,
      pvpRating: _nemesis.pvpRating,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sendDuelInvite(target!);
    });
  }

  Future<void> _sendRevengeInvite(String rivalId) async {
    RetentionAnalytics.nemesisRevengeInvite(rivalId: rivalId);
    OnlinePlayer? target;
    for (final OnlinePlayer p in _onlinePlayers) {
      if (p.authId == rivalId) {
        target = p;
        break;
      }
    }
    target ??= OnlinePlayer(
      authId: rivalId,
      username: _nemesis.rivalUsername ?? 'Rakip',
      displayName: _nemesis.rivalUsername ?? 'Rakip',
      avatarUrl: '',
      level: _nemesis.level,
      power: _nemesis.power,
      pvpRating: _nemesis.pvpRating,
    );
    await _sendDuelInvite(target);
  }

  Future<void> _loadOnlinePlayers() async {
    if (_loadingOnline) return;
    setState(() => _loadingOnline = true);
    try {
      final dynamic res = await SupabaseService.client
          .rpc('get_online_players', params: <String, dynamic>{'p_limit': 30});
      if (!mounted) return;
      setState(() {
        _loadingOnline = false;
        if (res is List) {
          _onlinePlayers = res
              .whereType<Map>()
              .map((Map e) => OnlinePlayer.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false);
        }
      });
      _maybeOpenRevengeInvite();
    } catch (_) {
      if (mounted) setState(() => _loadingOnline = false);
    }
  }

  Future<void> _sendDuelInvite(OnlinePlayer player) async {
    final int? wager = await _askWager(player);
    if (wager == null || !mounted) return;

    setState(() => _invitingId = player.authId);
    try {
      final dynamic res = await SupabaseService.client.rpc(
        'send_pvp_invite',
        params: <String, dynamic>{
          'p_target': player.authId,
          'p_wager': wager,
        },
      );
      if (!mounted) return;
      if (res is Map && res['success'] == true) {
        AppMessenger.show(
          context,
          '⚔️ ${player.displayName} oyuncusuna düello daveti gönderildi!',
        );
      } else {
        AppMessenger.showError(
          context,
          (res is Map ? res['error']?.toString() : null) ??
              'Davet gönderilemedi.',
        );
      }
    } catch (_) {
      if (mounted) AppMessenger.showError(context, 'Davet gönderilemedi.');
    } finally {
      if (mounted) setState(() => _invitingId = null);
    }
  }

  Future<int?> _askWager(OnlinePlayer player) async {
    final TextEditingController ctrl = TextEditingController(text: '0');
    final int? result = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141B2A),
        title: Text(
          '⚔️ ${player.displayName} ile Düello',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Bahis miktarı (0 = bahissiz dostluk maçı):',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.amber),
              decoration: InputDecoration(
                prefixText: '🪙 ',
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Kazanan havuzu alır (%5 arena vergisi düşülür).',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              final int wager = int.tryParse(ctrl.text.trim()) ?? 0;
              Navigator.of(ctx).pop(wager < 0 ? 0 : wager);
            },
            child: const Text('Davet Gönder'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  bool _isRestricted(String? until) {
    if (until == null || until.isEmpty) return false;
    final dt = DateTime.tryParse(until);
    return dt != null && dt.isAfter(DateTime.now());
  }

  String _timeAgo(String? createdAt) {
    if (createdAt == null || createdAt.isEmpty) return '';
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}g önce';
    if (diff.inHours > 0) return '${diff.inHours}s önce';
    if (diff.inMinutes > 0) return '${diff.inMinutes}dk önce';
    return 'az önce';
  }

  String _mekanTypeLabel(String type) {
    switch (type) {
      case 'dovus_kulubu':
        return 'Dövüş Kulübü';
      case 'luks_lounge':
        return 'Lüks Lounge';
      case 'yeralti':
        return 'Yeraltı';
      default:
        return type;
    }
  }

  Future<void> _refresh() async {
    await Future.wait<void>([
      ref.read(playerProvider.notifier).loadProfile(),
      ref.read(pvpDashboardProvider.notifier).load(),
      _loadOnlinePlayers(),
      _loadNemesis(),
    ]);
  }

  Future<void> _doLogout() async {
    await ref.read(authProvider.notifier).logout();
    ref.read(playerProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(playerProvider).profile;
    final dashboard = ref.watch(pvpDashboardProvider);
    final pvpRating = profile?.pvpRating ?? 1000;
    final pvpWins = profile?.pvpWins ?? 0;
    final pvpLosses = profile?.pvpLosses ?? 0;
    final energy = profile?.energy ?? 0;
    final isHospitalized = _isRestricted(profile?.hospitalUntil);
    final isImprisoned = _isRestricted(profile?.prisonUntil);

    final currentUserId = SupabaseService.isInitialized
        ? SupabaseService.client.auth.currentUser?.id ?? ''
        : '';

    final total = pvpWins + pvpLosses;
    final winRate = total > 0 ? (pvpWins / total * 100).toStringAsFixed(1) : '0.0';

    return Scaffold(
      appBar: GameTopBar(title: context.l10n.routePvp, onLogout: _doLogout),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(currentRoute: AppRoutes.pvp, onLogout: _doLogout),
      body: GameScreenBackground(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: GameScrollLayout.withClearance(
              context,
              const EdgeInsets.fromLTRB(16, 16, 16, 24),
            ),
            children: <Widget>[
              if (_nemesis.hasRival) ...<Widget>[
                TutorialAnchorScope(
                  id: TutorialAnchorId.pvpNemesisPanel,
                  child: NemesisRivalPanel(
                    rival: _nemesis,
                    dismissLoading: _dismissLoading,
                    onDismiss: _dismissNemesisBanner,
                    onRevenge: (String rivalId) {
                      unawaited(
                        TutorialTriggers.onAnchorTap(
                          ref,
                          TutorialAnchorId.pvpNemesisPanel,
                        ),
                      );
                      _sendRevengeInvite(rivalId);
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const GkkTabSectionTitle('PvP İstatistikleri', accent: AppColors.liquidGold),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        _StatChip(label: context.l10n.rating, value: '$pvpRating', color: Colors.amber),
                        const SizedBox(width: 10),
                        _StatChip(
                            label: context.l10n.kazanma_oran, value: '$winRate%', color: Colors.greenAccent),
                        const SizedBox(width: 10),
                        _StatChip(
                            label: context.l10n.enerji_2, value: '$energy', color: const Color(0xFF00D7D7)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        _StatChip(
                            label: context.l10n.galibiyet, value: '$pvpWins', color: Colors.greenAccent),
                        const SizedBox(width: 10),
                        _StatChip(
                            label: context.l10n.ma_lubiyet, value: '$pvpLosses', color: Colors.redAccent),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go(AppRoutes.pvpHistory),
                      icon: const Icon(Icons.history_rounded, size: 16),
                      label: Text(context.l10n.ge_mi_i_a),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        foregroundColor: Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go(AppRoutes.pvpTournament),
                      icon: const Icon(Icons.emoji_events_rounded, size: 16),
                      label: Text(context.l10n.turnuva),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.amber),
                        foregroundColor: Colors.amber,
                      ),
                    ),
                  ),
                ],
              ),
              if (isHospitalized) ...<Widget>[
                const SizedBox(height: 12),
                _warningBanner(
                  icon: Icons.local_hospital_rounded,
                  message:
                      'Hastanede tedavi görüyorsunuz. PvP için serbest olmanız gerekiyor.',
                  color: Colors.redAccent,
                ),
              ],
              if (isImprisoned) ...<Widget>[
                const SizedBox(height: 12),
                _warningBanner(
                  icon: Icons.gavel_rounded,
                  message:
                      'Hapishanede bulunuyorsunuz. PvP için serbest olmanız gerekiyor.',
                  color: Colors.orangeAccent,
                ),
              ],
              const SizedBox(height: 20),
              const GkkTabSectionTitle('Online Oyuncular', accent: AppColors.toxicNeon),
              Row(
                children: <Widget>[
                  const Spacer(),
                  IconButton(
                    onPressed: _loadingOnline ? null : _loadOnlinePlayers,
                    icon: const Icon(Icons.refresh_rounded,
                        color: Colors.white54, size: 20),
                    tooltip: 'Yenile',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (_loadingOnline && _onlinePlayers.isEmpty)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ))
              else if (_onlinePlayers.isEmpty)
                _emptyStateCard(
                  message: 'Şu anda online oyuncu yok.',
                  ctaLabel: 'Arenaya git',
                  onPressed: () => _goToFirstArena(dashboard.arenas),
                )
              else
                ..._onlinePlayers.asMap().entries.map((MapEntry<int, OnlinePlayer> entry) {
                  final OnlinePlayer p = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GkkTabStaggerItem(
                      index: entry.key,
                      child: _OnlinePlayerCard(
                        player: p,
                        inviting: _invitingId == p.authId,
                        onInvite: (isHospitalized || isImprisoned)
                            ? null
                            : () => _sendDuelInvite(p),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 20),
              const GkkTabSectionTitle('Açık Arenalar', accent: AppColors.coralFlare),
              const SizedBox(height: 10),
              if (dashboard.isLoading)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ))
              else if (dashboard.error != null)
                _errorCard('Arenalar yüklenemedi: ${dashboard.error}')
              else if (dashboard.arenas.isEmpty)
                _emptyStateCard(
                  message: 'Şu anda açık arena yok.',
                  ctaLabel: 'Mekanları keşfet',
                  onPressed: () => context.go(AppRoutes.mekans),
                )
              else
                ...dashboard.arenas.asMap().entries.map((MapEntry<int, dynamic> entry) {
                  final arena = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GkkTabStaggerItem(
                      index: entry.key,
                      child: _ArenaCard(
                        arenaName: arena.name,
                        mekanTypeLabel: _mekanTypeLabel(arena.mekanType),
                        onTap: () {
                          if (isHospitalized || isImprisoned) {
                            AppMessenger.showError(context, isHospitalized
                                    ? '🏥 Hastanedeyken arenaya giremezsiniz!'
                                    : '👮 Cezaevindeyken arenaya giremezsiniz!');
                            return;
                          }
                          context.go('/mekans/${arena.id}/arena');
                        },
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 20),
              const GkkTabSectionTitle('Son Maçlar', accent: AppColors.cyberFuchsia),
              const SizedBox(height: 10),
              if (!dashboard.isLoading && dashboard.recentMatches.isEmpty)
                _emptyStateCard(
                  message: 'Henüz maç yok.',
                  ctaLabel: 'İlk düellonu başlat',
                  onPressed: () => _goToFirstArena(dashboard.arenas),
                )
              else
                ...dashboard.recentMatches.map((match) {
                  final isAttacker = match.attackerId == currentUserId;
                  final won = match.winnerId == currentUserId;
                  final opponentName = isAttacker
                      ? (match.defenderUsername ?? 'Rakip')
                      : (match.attackerUsername ?? 'Rakip');
                  final repChange = won ? match.repChangeWinner : match.repChangeLoser;
                  final goldStolen = won ? match.goldStolen : -match.goldStolen;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MatchCard(
                      opponentName: opponentName,
                      isAttacker: isAttacker,
                      won: won,
                      isArena: match.matchSource == 'arena',
                      timeAgo: _timeAgo(match.createdAt),
                      hpRemaining: match.attackerHpRemaining,
                      goldStolen: goldStolen,
                      repChange: repChange,
                      isCritical: match.isCritical,
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return GkkTabListCard(child: child);
  }

  Widget _warningBanner(
      {required IconData icon, required String message, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 13))),
        ],
      ),
    );
  }

  void _goToFirstArena(List<PvpArena> arenas) {
    final PlayerProfile? profile = ref.read(playerProvider).profile;
    final bool hospitalized = _isRestricted(profile?.hospitalUntil);
    final bool imprisoned = _isRestricted(profile?.prisonUntil);
    if (hospitalized || imprisoned) {
      AppMessenger.showError(
        context,
        hospitalized
            ? '🏥 Hastanedeyken arenaya giremezsiniz!'
            : '👮 Cezaevindeyken arenaya giremezsiniz!',
      );
      return;
    }
    if (arenas.isEmpty) {
      context.go(AppRoutes.mekans);
      return;
    }
    context.go(AppRoutes.mekanArena(arenas.first.id));
  }

  Widget _emptyStateCard({
    required String message,
    required String ctaLabel,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: <Widget>[
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.sports_mma_rounded, size: 18),
            label: Text(ctaLabel),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.red.withValues(alpha: 0.08),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Text(message, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: color.withValues(alpha: 0.10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: <Widget>[
            Text(value,
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _OnlinePlayerCard extends StatelessWidget {
  const _OnlinePlayerCard({
    required this.player,
    required this.inviting,
    required this.onInvite,
  });

  final OnlinePlayer player;
  final bool inviting;
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: <Widget>[
          Stack(
            children: <Widget>[
              ProfileAvatar(size: 40, avatarUrl: player.avatarUrl),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF10131D), width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  player.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'Lv ${player.level}  ⚡${player.power}  🏆${player.pvpRating}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: inviting ? null : onInvite,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
            child: Text(inviting ? '...' : '⚔️ Düello'),
          ),
        ],
      ),
    );
  }
}

class _ArenaCard extends StatelessWidget {
  const _ArenaCard({
    required this.arenaName,
    required this.mekanTypeLabel,
    required this.onTap,
  });

  final String arenaName;
  final String mekanTypeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.sports_kabaddi_rounded, color: Colors.redAccent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(arenaName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(mekanTypeLabel,
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            child: Text(context.l10n.arenaya_git),
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.opponentName,
    required this.isAttacker,
    required this.won,
    required this.isArena,
    required this.timeAgo,
    required this.hpRemaining,
    required this.goldStolen,
    required this.repChange,
    required this.isCritical,
  });

  final String opponentName;
  final bool isAttacker;
  final bool won;
  final bool isArena;
  final String timeAgo;
  final int hpRemaining;
  final int goldStolen;
  final int repChange;
  final bool isCritical;

  @override
  Widget build(BuildContext context) {
    final resultColor = won ? Colors.greenAccent : Colors.redAccent;
    final resultText = won ? 'Kazandın' : 'Kaybettin';
    final roleText = isAttacker ? 'Saldırı' : 'Savunma';
    final goldSign = goldStolen >= 0 ? '+' : '';
    final repSign = repChange >= 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isAttacker
                      ? Colors.redAccent.withValues(alpha: 0.2)
                      : Colors.blueAccent.withValues(alpha: 0.2),
                ),
                child: Text(roleText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isAttacker ? Colors.redAccent : Colors.blueAccent,
                    )),
              ),
              if (isArena) ...<Widget>[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.amber.withValues(alpha: 0.15),
                  ),
                  child: const Text('Arena',
                      style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w700, color: Colors.amber)),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: Text(opponentName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
              Text(timeAgo, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(width: 8),
              Text(resultText,
                  style: TextStyle(fontWeight: FontWeight.w700, color: resultColor)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _MatchStat(
                  icon: Icons.favorite_rounded,
                  label: 'HP',
                  value: '$hpRemaining',
                  color: Colors.redAccent),
              const SizedBox(width: 16),
              _MatchStat(
                icon: Icons.paid_rounded,
                label: context.l10n.alt_n,
                value: '$goldSign$goldStolen',
                color: goldStolen >= 0 ? Colors.amber : Colors.red,
              ),
              const SizedBox(width: 16),
              _MatchStat(
                icon: Icons.star_rounded,
                label: context.l10n.i_tibar,
                value: '$repSign$repChange',
                color: repChange >= 0 ? Colors.greenAccent : Colors.redAccent,
              ),
            ],
          ),
          if (isCritical) ...<Widget>[
            const SizedBox(height: 8),
            const Text('⚡ Kritik zafer kaydı',
                style: TextStyle(
                    color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

class _MatchStat extends StatelessWidget {
  const _MatchStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
      ],
    );
  }
}
