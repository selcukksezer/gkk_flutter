import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../models/guild_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/guild_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
String _roleLabel(GuildRole role) {
  switch (role) {
    case GuildRole.leader:
      return 'Lider';
    case GuildRole.officer:
      return 'Subay';
    case GuildRole.member:
      return 'Üye';
  }
}

String _roleEmoji(GuildRole role) {
  switch (role) {
    case GuildRole.leader:
      return '👑';
    case GuildRole.officer:
      return '⭐';
    case GuildRole.member:
      return '🛡️';
  }
}

int _roleSortOrder(GuildRole role) {
  switch (role) {
    case GuildRole.leader:
      return 0;
    case GuildRole.officer:
      return 1;
    case GuildRole.member:
      return 2;
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class GuildScreen extends ConsumerStatefulWidget {
  const GuildScreen({super.key});

  @override
  ConsumerState<GuildScreen> createState() => _GuildScreenState();
}

class _GuildScreenState extends ConsumerState<GuildScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _createNameController = TextEditingController();
  final TextEditingController _createDescController = TextEditingController();
  bool _memberActionLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(playerProvider.notifier).loadProfile();
      await ref.read(guildProvider.notifier).loadGuild();
      if (!ref.read(guildProvider).hasValidGuild) {
        await ref.read(guildProvider.notifier).loadRecommendedGuilds();
      }
    });
  }

  void _onSearchQueryChanged() {
    if (_searchController.text.trim().isEmpty) {
      ref.read(guildProvider.notifier).clearSearchResults();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchQueryChanged);
    _searchController.dispose();
    _createNameController.dispose();
    _createDescController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    AppMessenger.show(context, msg);
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    await ref.read(guildProvider.notifier).searchGuilds(query);
  }

  Future<void> _joinGuild(String guildId) async {
    final ok = await ref.read(guildProvider.notifier).joinGuild(guildId);
    if (!ok) {
      final err = ref.read(guildProvider).error;
      if (err != null) _showSnack(err);
      return;
    }
    _showSnack('Loncaya katıldınız!');
  }

  Future<void> _leaveGuild() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Loncadan Ayrıl'),
        content: const Text('Loncadan ayrılmak istediğinize emin misiniz?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ayrıl'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final ok = await ref.read(guildProvider.notifier).leaveGuild();
    if (!ok) {
      final err = ref.read(guildProvider).error;
      if (err != null) _showSnack(err);
      return;
    }
    _showSnack('Loncadan ayrıldınız.');
  }

  Future<void> _disbandGuild() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Loncayı Dağıt'),
        content: const Text(
          'Loncayı dağıtmak tüm üyeleri çıkarır ve anıt ilerlemesini siler. Emin misiniz?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Dağıt'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final ok = await ref.read(guildProvider.notifier).disbandGuild();
    if (!ok) {
      final err = ref.read(guildProvider).error;
      if (err != null) _showSnack(err);
      return;
    }
    _showSnack('Lonca dağıtıldı.');
  }

  Future<void> _showCreateDialog() async {
    _createNameController.clear();
    _createDescController.clear();
    const int createCost = 10000000;
    final int playerGold = ref.read(playerProvider).profile?.gold ?? 0;
    final bool canAfford = playerGold >= createCost;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lonca Kur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: canAfford
                    ? const Color(0x334B6FFF)
                    : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: canAfford
                      ? const Color(0xFF4B6FFF)
                      : Colors.red.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                canAfford
                    ? 'Maliyet: 10.000.000 altın (bakiyeniz: ${_formatGold(playerGold)})'
                    : 'Yetersiz altın: 10.000.000 gerekli (bakiyeniz: ${_formatGold(playerGold)})',
                style: TextStyle(
                  fontSize: 12,
                  color: canAfford ? const Color(0xFF8BAEFF) : Colors.redAccent,
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _createNameController,
              decoration: const InputDecoration(labelText: 'Lonca Adı'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _createDescController,
              decoration: const InputDecoration(labelText: 'Açıklama'),
              maxLines: 2,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: canAfford
                ? () async {
                    final name = _createNameController.text.trim();
                    if (name.isEmpty) return;
                    Navigator.of(ctx).pop();
                    final ok = await ref
                        .read(guildProvider.notifier)
                        .createGuild(
                          name: name,
                          description: _createDescController.text.trim(),
                        );
                    if (!ok) {
                      final err = ref.read(guildProvider).error;
                      if (err != null) _showSnack(err);
                      return;
                    }
                    _showSnack('Lonca kuruldu!');
                  }
                : null,
            child: const Text('Kur (10M Altın)'),
          ),
        ],
      ),
    );
  }

  String _formatGold(int gold) {
    if (gold >= 1000000) {
      return '${(gold / 1000000).toStringAsFixed(gold % 1000000 == 0 ? 0 : 1)}M';
    }
    if (gold >= 1000) {
      return '${(gold / 1000).toStringAsFixed(gold % 1000 == 0 ? 0 : 1)}K';
    }
    return gold.toString();
  }

  Future<void> _showMinJoinPowerDialog(int current) async {
    final TextEditingController controller =
        TextEditingController(text: current > 0 ? '$current' : '');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Katılım Güç Limiti'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '0 = limit yok. Yeni üyeler bu gücün altındaysa katılamaz.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minimum güç',
                suffixText: 'güç',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () async {
              final int? value = int.tryParse(controller.text.trim());
              if (value == null || value < 0) {
                _showSnack('Geçerli bir sayı girin (0 veya üzeri).');
                return;
              }
              Navigator.of(ctx).pop();
              final ok =
                  await ref.read(guildProvider.notifier).setMinJoinPower(value);
              if (!ok) {
                final err = ref.read(guildProvider).error;
                if (err != null) _showSnack(err);
                return;
              }
              _showSnack(
                value == 0
                    ? 'Güç limiti kaldırıldı.'
                    : 'Katılım güç limiti $value olarak ayarlandı.',
              );
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _showMemberActions({
    required GuildMemberData member,
    required GuildRole myRole,
    required String myPlayerId,
  }) async {
    if (member.playerId == myPlayerId) return;
    if (myRole == GuildRole.member) return;

    final bool canPromote = myRole == GuildRole.leader &&
        member.role == GuildRole.member;
    final bool canDemote = myRole == GuildRole.leader &&
        member.role == GuildRole.officer;
    final bool canKick = myRole == GuildRole.leader ||
        (myRole == GuildRole.officer && member.role == GuildRole.member);

    if (!canPromote && !canDemote && !canKick) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              title: Text(
                '${_roleEmoji(member.role)} ${member.username} — ${_roleLabel(member.role)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            if (canPromote)
              ListTile(
                leading: const Icon(Icons.arrow_upward_rounded, color: Colors.green),
                title: const Text('Subay Yap'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _memberAction(
                    memberId: member.playerId,
                    rpcName: 'promote_guild_member',
                    successMsg: '${member.username} subay yapıldı.',
                  );
                },
              ),
            if (canDemote)
              ListTile(
                leading: const Icon(Icons.arrow_downward_rounded, color: Colors.orange),
                title: const Text('Üye Yap'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _memberAction(
                    memberId: member.playerId,
                    rpcName: 'demote_guild_member',
                    successMsg: '${member.username} üye yapıldı.',
                  );
                },
              ),
            if (canKick)
              ListTile(
                leading: const Icon(Icons.person_remove_rounded, color: Colors.red),
                title: const Text('Loncadan At'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _memberAction(
                    memberId: member.playerId,
                    rpcName: 'kick_guild_member',
                    successMsg: '${member.username} loncadan atıldı.',
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _memberAction({
    required String memberId,
    required String rpcName,
    required String successMsg,
  }) async {
    setState(() => _memberActionLoading = true);
    try {
      final dynamic response = await SupabaseService.client.rpc(
        rpcName,
        params: <String, dynamic>{'p_member_id': memberId},
      );
      final GuildRpcResult result = GuildRpcResult.fromResponse(response);
      if (!result.success) {
        _showSnack(result.error ?? 'İşlem başarısız.');
        return;
      }
      await ref.read(guildProvider.notifier).loadGuild();
      _showSnack(successMsg);
    } catch (e) {
      _showSnack('İşlem başarısız: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _memberActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final guildState = ref.watch(guildProvider);
    final playerState = ref.watch(playerProvider);

    Future<void> onLogout() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(guildProvider.notifier).clear();
      ref.read(playerProvider.notifier).clear();
    }

    final String myPlayerId = playerState.profile?.id ?? '';
    final String myAuthId = playerState.profile?.authId ?? '';
    final GuildRole myRole = guildState.hasValidGuild
        ? _myRole(guildState.guild!, myPlayerId, myAuthId)
        : GuildRole.member;

    return Scaffold(
      appBar: GameTopBar(title: 'Lonca', onLogout: onLogout),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(currentRoute: AppRoutes.guild, onLogout: onLogout),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)],
          ),
        ),
        child: guildState.isLoading && !guildState.hasValidGuild
            ? const Center(child: CircularProgressIndicator())
            : !guildState.hasValidGuild
                ? _NoGuildView(
                    searchController: _searchController,
                    searchResults: guildState.searchResults,
                    recommendedGuilds: guildState.recommendedGuilds,
                    myPower: playerState.profile?.power ?? 0,
                    isSearching: guildState.isSearching,
                    isLoadingRecommended: guildState.isLoadingRecommended,
                    isMutating: guildState.isMutating,
                    error: guildState.error,
                    onSearch: _search,
                    onJoin: _joinGuild,
                    onCreate: _showCreateDialog,
                  )
                : _GuildView(
                    guild: guildState.guild!,
                    myPlayerId: myPlayerId,
                    myRole: myRole,
                    memberActionLoading: _memberActionLoading,
                    onMemberTap: (member) => _showMemberActions(
                      member: member,
                      myRole: myRole,
                      myPlayerId: myPlayerId,
                    ),
                    onLeave: myRole == GuildRole.leader ? _disbandGuild : _leaveGuild,
                    leaveLabel: myRole == GuildRole.leader ? 'Dağıt' : 'Çık',
                    onGuildWar: () => context.go(AppRoutes.guildWar),
                    onMonument: () => context.go(AppRoutes.guildMonument),
                    onEditMinJoinPower: myRole == GuildRole.leader
                        ? () => _showMinJoinPowerDialog(
                              guildState.guild!.minJoinPower,
                            )
                        : null,
                  ),
      ),
    );
  }

  GuildRole _myRole(GuildData guild, String playerId, String authId) {
    if (guild.members != null) {
      for (final m in guild.members!) {
        if (m.playerId == playerId) return m.role;
      }
    }
    if (authId.isNotEmpty && guild.leaderId == authId) {
      return GuildRole.leader;
    }
    final String? profileRole = ref.read(playerProvider).profile?.guildRole;
    if (profileRole == 'leader') return GuildRole.leader;
    if (profileRole == 'officer' || profileRole == 'commander') {
      return GuildRole.officer;
    }
    return GuildRole.member;
  }
}

// ---------------------------------------------------------------------------
// No-guild view
// ---------------------------------------------------------------------------
class _NoGuildView extends StatelessWidget {
  const _NoGuildView({
    required this.searchController,
    required this.searchResults,
    required this.recommendedGuilds,
    required this.myPower,
    required this.isSearching,
    required this.isLoadingRecommended,
    required this.isMutating,
    this.error,
    required this.onSearch,
    required this.onJoin,
    required this.onCreate,
  });

  final TextEditingController searchController;
  final List<GuildData> searchResults;
  final List<GuildData> recommendedGuilds;
  final int myPower;
  final bool isSearching;
  final bool isLoadingRecommended;
  final bool isMutating;
  final String? error;
  final VoidCallback onSearch;
  final Future<void> Function(String) onJoin;
  final VoidCallback onCreate;

  bool get _hasSearchQuery => searchController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text(
            'Lonca',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Henüz bir loncaya üye değilsiniz.',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 20),
          // Search bar
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Lonca ara...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => onSearch(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: isSearching ? null : onSearch,
                child: isSearching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Ara'),
              ),
            ],
          ),
          if (isMutating) ...<Widget>[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: 16),
          if (searchResults.isNotEmpty && _hasSearchQuery) ...<Widget>[
            const Text(
              'Sonuçlar',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white54),
            ),
            const SizedBox(height: 8),
            ...searchResults.map(
              (guild) => _GuildResultTile(
                guild: guild,
                myPower: myPower,
                onJoin: onJoin,
              ),
            ),
            const SizedBox(height: 16),
          ] else if (_hasSearchQuery && !isSearching) ...<Widget>[
            const Text(
              'Aramanızla eşleşen lonca bulunamadı.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 16),
          ] else if (isLoadingRecommended) ...<Widget>[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ] else if (recommendedGuilds.isNotEmpty) ...<Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.recommend_rounded,
                    size: 16, color: Color(0xFF4B6FFF)),
                SizedBox(width: 6),
                Text(
                  'Önerilen Loncalar',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Katılabileceğiniz, yer açık loncalar',
              style: TextStyle(fontSize: 11, color: Colors.white38),
            ),
            const SizedBox(height: 8),
            ...recommendedGuilds.map(
              (guild) => _GuildResultTile(
                guild: guild,
                myPower: myPower,
                onJoin: onJoin,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          // Create guild button
          OutlinedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Lonca Kur'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF4B6FFF)),
              foregroundColor: const Color(0xFF4B6FFF),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuildResultTile extends StatelessWidget {
  const _GuildResultTile({
    required this.guild,
    required this.myPower,
    required this.onJoin,
  });

  final GuildData guild;
  final int myPower;
  final Future<void> Function(String) onJoin;

  bool get _powerTooLow =>
      guild.minJoinPower > 0 && myPower < guild.minJoinPower;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  guild.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Lv.${guild.level} · Anıt Lv.${guild.monumentLevel} · ${guild.memberCount}/${guild.maxMembers} üye · ${guild.totalPower} güç'
                  '${guild.minJoinPower > 0 ? ' · Min ${guild.minJoinPower} güç' : ''}',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
                if (_powerTooLow)
                  Text(
                    'Gücünüz yetersiz ($myPower / ${guild.minJoinPower})',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange.shade300,
                    ),
                  ),
              ],
            ),
          ),
          FilledButton(
            onPressed: _powerTooLow ? null : () => onJoin(guild.guildId),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4B6FFF),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Katıl'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Guild view (member of a guild)
// ---------------------------------------------------------------------------
class _GuildView extends StatelessWidget {
  const _GuildView({
    required this.guild,
    required this.myPlayerId,
    required this.myRole,
    required this.memberActionLoading,
    required this.onMemberTap,
    required this.onLeave,
    required this.leaveLabel,
    required this.onGuildWar,
    required this.onMonument,
    this.onEditMinJoinPower,
  });

  final GuildData guild;
  final String myPlayerId;
  final GuildRole myRole;
  final bool memberActionLoading;
  final Future<void> Function(GuildMemberData) onMemberTap;
  final VoidCallback onLeave;
  final String leaveLabel;
  final VoidCallback onGuildWar;
  final VoidCallback onMonument;
  final VoidCallback? onEditMinJoinPower;

  @override
  Widget build(BuildContext context) {
    final List<GuildMemberData> sortedMembers = guild.members == null
        ? <GuildMemberData>[]
        : List<GuildMemberData>.from(guild.members!)
      ..sort((a, b) => _roleSortOrder(a.role).compareTo(_roleSortOrder(b.role)));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // ── Guild info header ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x334B6FFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.groups_rounded, color: Color(0xFF4B6FFF), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        guild.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4B6FFF).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Lv. ${guild.level}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF4B6FFF),
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: <Widget>[
                    _StatChip(
                        icon: Icons.people_rounded,
                        label: '${guild.memberCount}/${guild.maxMembers} Üye'),
                    _StatChip(
                        icon: Icons.bolt_rounded,
                        label: '${guild.totalPower} Güç'),
                    _StatChip(
                        icon: Icons.account_balance_outlined,
                        label: 'Anıt Lv.${guild.monumentLevel}'),
                    _StatChip(
                        icon: Icons.paid_rounded,
                        label: '${guild.monumentGoldPool} 🪙 Havuz'),
                    _StatChip(
                        icon: Icons.shield_rounded,
                        label: guild.minJoinPower > 0
                            ? 'Min ${guild.minJoinPower} güç'
                            : 'Güç limiti yok'),
                  ],
                ),
                if (onEditMinJoinPower != null) ...<Widget>[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onEditMinJoinPower,
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('Katılım Güç Limiti'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF4B6FFF)),
                      foregroundColor: const Color(0xFF8BAEFF),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Action buttons ──────────────────────────────────────────────
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGuildWar,
                  icon: const Icon(Icons.flag_rounded, size: 16),
                  label: const Text('Lonca Savaşı'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onMonument,
                  icon: const Icon(Icons.account_balance_rounded, size: 16),
                  label: const Text('Anıt'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onLeave,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  foregroundColor: Colors.red,
                ),
                child: Text(leaveLabel),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Members list ────────────────────────────────────────────────
          Row(
            children: <Widget>[
              const Text(
                'Üyeler',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              if (memberActionLoading) ...<Widget>[
                const SizedBox(width: 10),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (sortedMembers.isEmpty)
            Text(
              guild.loadError ?? 'Henüz üye kaydı yok.',
              style: const TextStyle(color: Colors.white38),
            )
          else
            ...sortedMembers.map(
              (member) => _MemberTile(
                member: member,
                isMe: member.playerId == myPlayerId,
                canAct: myRole != GuildRole.member &&
                    member.playerId != myPlayerId,
                onTap: () => onMemberTap(member),
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isMe,
    required this.canAct,
    required this.onTap,
  });

  final GuildMemberData member;
  final bool isMe;
  final bool canAct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool online = member.isOnline == true;
    return GestureDetector(
      onTap: canAct ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? const Color(0xFF4B6FFF).withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMe ? const Color(0x334B6FFF) : Colors.white12,
          ),
        ),
        child: Row(
          children: <Widget>[
            // Online dot
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: online ? Colors.green : Colors.white24,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        _roleEmoji(member.role),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        member.username,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isMe
                              ? const Color(0xFF8BAEFF)
                              : Colors.white,
                        ),
                      ),
                      if (isMe)
                        const Text(
                          ' (Ben)',
                          style: TextStyle(fontSize: 11, color: Colors.white38),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Lv.${member.level} · ${_roleLabel(member.role)} · ${member.power} güç',
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ],
              ),
            ),
            if (canAct)
              const Icon(Icons.more_vert_rounded, size: 16, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------
class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 13, color: Colors.white54),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }
}
