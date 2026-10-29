import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/tutorial/tutorial_anchor.dart';
import '../../../core/tutorial/tutorial_track.dart';
import '../../../l10n/l10n.dart';
import '../../../models/guild_model.dart';
import '../guild_helpers.dart';
import 'guild_design.dart';
import 'guild_emblem_banner.dart';

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
    final List<GuildData> list = (_hasSearchQuery && searchResults.isNotEmpty)
        ? searchResults
        : (!_hasSearchQuery ? recommendedGuilds : const <GuildData>[]);

    return SafeArea(
      child: RefreshIndicator(
        color: GuildPalette.gold,
        backgroundColor: GuildPalette.navy,
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          children: <Widget>[
            TutorialAnchorScope(
              id: TutorialAnchorId.guildHeader,
              child: GuildGlassCard(
                accent: GuildPalette.fuchsia,
                glow: true,
                padding: EdgeInsets.zero,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                        child: Image.asset(
                          'assets/images/backgrounds/elysea/bg_sanctum_citadel.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: <Color>[
                                const Color(0xFF090E1A).withValues(alpha: 0.94),
                                const Color(0xFF0C1322).withValues(alpha: 0.88),
                                const Color(0xFF0F1A2E).withValues(alpha: 0.72),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: GuildPalette.fuchsia.withValues(alpha: 0.55),
                            ),
                            color: GuildPalette.fuchsia.withValues(alpha: 0.14),
                          ),
                          child: Text(
                            'LONCA AĞI',
                            style: GoogleFonts.urbanist(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              color: GuildPalette.fuchsia,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: GuildPalette.iridescentCyan.withValues(alpha: 0.14),
                            border: Border.all(
                              color: GuildPalette.iridescentCyan.withValues(alpha: 0.45),
                            ),
                          ),
                          child: const Text(
                            'AION 2 ÇAĞI',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: GuildPalette.iridescentCyan,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            const GuildCelestialEmblem(
                              level: 1,
                              monogram: '',
                              size: 64,
                              showGlow: true,
                            ),
                            Center(
                              child: Image.asset(
                                'assets/renders/weapons/Shield_Celtic_Golden_beauty.png',
                                width: 38,
                                height: 38,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Image.asset(
                                  'assets/images/icons/armor/armor_crown_of_light.png',
                                  width: 34,
                                  height: 34,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'LONCANI BUL',
                                style: GoogleFonts.urbanist(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                  color: GuildPalette.textHi,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Lonca güçlerini birleştir, anıtını yükselt, kasadan pay al ve fetihlere katıl.',
                                style: GoogleFonts.urbanist(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: GuildPalette.titanium,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        GuildStatPill(
                          icon: Icons.bolt_rounded,
                          label: 'Gücün ${formatGuildCompact(myPower)}',
                          accent: GuildPalette.gold,
                          filled: true,
                        ),
                        GuildStatPill(
                          icon: Icons.groups_rounded,
                          label: '${recommendedGuilds.length} önerilen lonca',
                          accent: GuildPalette.neon,
                          filled: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: GuildPressable(
                    onTap: onCreate,
                    child: TutorialAnchorScope(
                      id: TutorialAnchorId.guildJoinBtn,
                      child: Container(
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: GuildPalette.goldGrad,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: GuildPalette.gold.withValues(alpha: 0.35),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Icon(Icons.add_rounded, color: Color(0xFF1A1200), size: 20),
                            const SizedBox(width: 6),
                            Text(
                              context.l10n.lonca_kur.toUpperCase(),
                              style: GoogleFonts.urbanist(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                                color: const Color(0xFF1A1200),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GuildPressable(
                    onTap: isSearching ? null : onSearch,
                    enabled: !isSearching,
                    child: Container(
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: GuildPalette.surfaceHi,
                        border: Border.all(
                          color: GuildPalette.fuchsia.withValues(alpha: 0.45),
                          width: 1.2,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: GuildPalette.fuchsia.withValues(alpha: 0.16),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: isSearching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: GuildPalette.fuchsia,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const Icon(
                                  Icons.search_rounded,
                                  color: GuildPalette.fuchsia,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'ARA',
                                  style: GoogleFonts.urbanist(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                    color: GuildPalette.fuchsia,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GuildGlassCard(
              accent: GuildPalette.gold,
              glow: false,
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: TextField(
                controller: searchController,
                textInputAction: TextInputAction.search,
                style: GoogleFonts.urbanist(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: GuildPalette.textHi,
                ),
                cursorColor: GuildPalette.gold,
                decoration: InputDecoration(
                  hintText: context.l10n.lonca_ara,
                  hintStyle: GoogleFonts.urbanist(
                    fontSize: 13,
                    color: GuildPalette.titanium.withValues(alpha: 0.75),
                  ),
                  prefixIcon: const Icon(
                    Icons.travel_explore_rounded,
                    color: GuildPalette.gold,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onSubmitted: (_) => onSearch(),
              ),
            ),
            if (isMutating) ...<Widget>[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: const LinearProgressIndicator(
                  minHeight: 3,
                  color: GuildPalette.gold,
                  backgroundColor: GuildPalette.obsidian,
                ),
              ),
            ],
            if (error != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                error!,
                style: GoogleFonts.urbanist(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: GuildPalette.ruby,
                ),
              ),
            ],
            const SizedBox(height: 18),
            GuildSectionTitle(
              title: _hasSearchQuery ? 'ARAMA SONUÇLARI' : 'ÖNERİLEN LONCALAR',
              subtitle: _hasSearchQuery
                  ? 'Sorguna uyan loncalar'
                  : 'Katılabileceğin, yer açık loncalar',
              accent: _hasSearchQuery ? GuildPalette.fuchsia : GuildPalette.gold,
            ),
            const SizedBox(height: 12),
            if (isSearching && searchResults.isEmpty)
              _GuildEmptyState(
                icon: Icons.hourglass_top_rounded,
                label: 'Aranıyor…',
                accent: GuildPalette.fuchsia,
              )
            else if (isLoadingRecommended && !_hasSearchQuery)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: GuildPalette.gold,
                  ),
                ),
              )
            else if (_hasSearchQuery && !isSearching && searchResults.isEmpty)
              const _GuildEmptyState(
                icon: Icons.search_off_rounded,
                label: 'Eşleşen lonca bulunamadı',
                accent: GuildPalette.titanium,
              )
            else if (list.isEmpty)
              const _GuildEmptyState(
                icon: Icons.groups_outlined,
                label: 'Öneri bulunamadı',
                accent: GuildPalette.titanium,
              )
            else
              ...List<Widget>.generate(list.length, (int i) {
                return TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: Duration(milliseconds: 200 + (i * 40).clamp(0, 320)),
                  curve: Curves.easeOutCubic,
                  builder: (BuildContext context, double t, Widget? child) {
                    return Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - t)),
                        child: child,
                      ),
                    );
                  },
                  child: GuildResultTile(
                    guild: list[i],
                    myPower: myPower,
                    onJoin: onJoin,
                    rank: i + 1,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _GuildEmptyState extends StatelessWidget {
  const _GuildEmptyState({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GuildGlassCard(
      accent: accent,
      glow: false,
      child: Row(
        children: <Widget>[
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.urbanist(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: GuildPalette.titanium,
            ),
          ),
        ],
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
    this.rank,
  });

  final GuildData guild;
  final int myPower;
  final Future<void> Function(String) onJoin;
  final int? rank;

  bool get _powerTooLow => guild.minJoinPower > 0 && myPower < guild.minJoinPower;
  bool get _full => guild.memberCount >= guild.maxMembers && guild.maxMembers > 0;

  Color get _accent {
    if (_powerTooLow || _full) return GuildPalette.titanium;
    if ((rank ?? 99) <= 3) return GuildPalette.gold;
    return GuildPalette.fuchsia;
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = _accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GuildGlassCard(
        accent: accent,
        glow: !(_powerTooLow || _full),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            if (rank != null) ...<Widget>[
              SizedBox(
                width: 30,
                child: Text(
                  '#$rank',
                  style: GoogleFonts.urbanist(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
              ),
            ],
            // Emblem preview
            GuildCelestialEmblem(
              level: guild.level,
              monogram: guild.name.isNotEmpty ? guild.name.characters.first.toUpperCase() : '⚔️',
              size: 46,
              showGlow: !(_powerTooLow || _full),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    guild.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.urbanist(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: GuildPalette.textHi,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: <Widget>[
                      GuildStatPill(
                        icon: Icons.military_tech_rounded,
                        label: 'Sv.${guild.level}',
                        accent: GuildPalette.gold,
                      ),
                      GuildStatPill(
                        icon: Icons.account_balance_rounded,
                        label: 'Anıt ${guild.monumentLevel}',
                        accent: GuildPalette.coral,
                      ),
                      GuildStatPill(
                        icon: Icons.groups_rounded,
                        label: '${guild.memberCount}/${guild.maxMembers}',
                        accent: GuildPalette.neon,
                      ),
                      GuildStatPill(
                        icon: Icons.flash_on_rounded,
                        label: formatGuildCompact(guild.totalPower),
                        accent: GuildPalette.fuchsia,
                      ),
                    ],
                  ),
                  if (_powerTooLow) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      'Güç yetersiz · ${formatGuildCompact(myPower)} / ${formatGuildCompact(guild.minJoinPower)}',
                      style: GoogleFonts.urbanist(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: GuildPalette.solar,
                      ),
                    ),
                  ] else if (_full) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      'Lonca dolu',
                      style: GoogleFonts.urbanist(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: GuildPalette.titanium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            GuildPressable(
              enabled: !_powerTooLow && !_full,
              onTap: (_powerTooLow || _full) ? null : () => onJoin(guild.guildId),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: (_powerTooLow || _full)
                      ? null
                      : GuildPalette.goldGrad,
                  color: (_powerTooLow || _full) ? GuildPalette.obsidian : null,
                  border: Border.all(
                    color: (_powerTooLow || _full)
                        ? GuildPalette.titanium.withValues(alpha: 0.35)
                        : GuildPalette.gold.withValues(alpha: 0.7),
                  ),
                  boxShadow: (_powerTooLow || _full)
                      ? null
                      : <BoxShadow>[
                          BoxShadow(
                            color: GuildPalette.gold.withValues(alpha: 0.28),
                            blurRadius: 10,
                          ),
                        ],
                ),
                child: Text(
                  context.l10n.kat_l.toUpperCase(),
                  style: GoogleFonts.urbanist(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    color: (_powerTooLow || _full)
                        ? GuildPalette.titanium
                        : const Color(0xFF1A1200),
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
