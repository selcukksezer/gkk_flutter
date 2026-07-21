import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../models/guild_model.dart';
import '../guild_helpers.dart';

class GuildNoGuildView extends StatelessWidget {
  const GuildNoGuildView({
    super.key,
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
    required this.onRefresh,
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
  final Future<void> Function() onRefresh;

  bool get _hasSearchQuery => searchController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const Text(
              'Lonca',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Henüz bir loncaya üye değilsin.',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: context.l10n.lonca_ara,
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
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: isSearching ? null : onSearch,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
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
            if (isSearching && searchResults.isEmpty) ...<Widget>[
              const SizedBox(height: 12),
              const Text(
                'Aranıyor…',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ],
            if (isMutating) ...<Widget>[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: 16),
            if (searchResults.isNotEmpty && _hasSearchQuery) ...<Widget>[
              const Text(
                'Sonuçlar',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white54),
              ),
              const SizedBox(height: 8),
              ...searchResults.map(
                (GuildData guild) => GuildResultTile(
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
                  Icon(Icons.recommend_rounded, size: 16, color: Color(0xFF4B6FFF)),
                  SizedBox(width: 6),
                  Text(
                    'Önerilen Loncalar',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white54),
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
                (GuildData guild) => GuildResultTile(
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
            OutlinedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.l10n.lonca_kur),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF4B6FFF)),
                foregroundColor: const Color(0xFF4B6FFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GuildResultTile extends StatelessWidget {
  const GuildResultTile({
    super.key,
    required this.guild,
    required this.myPower,
    required this.onJoin,
  });

  final GuildData guild;
  final int myPower;
  final Future<void> Function(String) onJoin;

  bool get _powerTooLow => guild.minJoinPower > 0 && myPower < guild.minJoinPower;

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
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: <Widget>[
                    _guildInfoChip('Sv. ${guild.level}'),
                    _guildInfoChip('Anıt ${guild.monumentLevel}'),
                    _guildInfoChip('${guild.memberCount}/${guild.maxMembers} üye'),
                    _guildInfoChip('${formatGuildCompact(guild.totalPower)} güç'),
                    if (guild.minJoinPower > 0)
                      _guildInfoChip('Min. ${formatGuildCompact(guild.minJoinPower)}'),
                  ],
                ),
                if (_powerTooLow)
                  Text(
                    'Gücün yetersiz ($myPower / ${guild.minJoinPower})',
                    style: TextStyle(fontSize: 10, color: Colors.orange.shade300),
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
            child: Text(context.l10n.kat_l),
          ),
        ],
      ),
    );
  }

  static Widget _guildInfoChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: Colors.white70),
      ),
    );
  }
}
