import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../l10n/l10n.dart';
import '../../models/mekan_model.dart';
import '../../components/common/item_icon_view.dart';
import '../../components/layout/game_screen_background.dart';
import '../../providers/mekan_provider.dart';
import '../../routing/app_router.dart';
import 'widgets/mekan_3d_viewport.dart';
import 'widgets/mekan_design.dart';
import 'widgets/mekan_scaffold.dart';
import 'widgets/mekan_theme.dart';

class MekansScreen extends ConsumerStatefulWidget {
  const MekansScreen({super.key});

  @override
  ConsumerState<MekansScreen> createState() => _MekansScreenState();
}

class _MekansScreenState extends ConsumerState<MekansScreen> {
  late final Mekan3DViewportController _viewportController;
  List<Mekan> _mekans = <Mekan>[];
  List<MekanLeaderboardRow> _leaderboard = <MekanLeaderboardRow>[];
  Map<String, List<MekanStockPeek>> _stockPreviews =
      <String, List<MekanStockPeek>>{};
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _viewportController = Mekan3DViewportController(initialLocationType: _filter);
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TutorialTriggers.onRouteEnter(ref, AppRoutes.mekans);
    });
  }

  @override
  void dispose() {
    _viewportController.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = true}) async {
    if (!mounted) return;
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _offset = 0;
        _hasMore = true;
      });
    }
    try {
      final MekanRepository repo = ref.read(mekanRepositoryProvider);
      final int pageSize = MekanRepository.defaultPageSize;
      final List<Mekan> page = await repo.fetchAllMekans(
        limit: pageSize,
        offset: reset ? 0 : _offset,
      );
      if (!mounted) return;
      List<MekanLeaderboardRow> lb = _leaderboard;
      if (reset) {
        try {
          lb = await repo.fetchFameLeaderboard(limit: 10);
        } catch (_) {
          // leaderboard RPC optional; ignore if not yet applied
        }
      }
      if (!mounted) return;
      final List<Mekan> merged = reset ? page : <Mekan>[..._mekans, ...page];
      Map<String, List<MekanStockPeek>> previews = _stockPreviews;
      if (page.isNotEmpty) {
        try {
          final Map<String, List<MekanStockPeek>> newPreviews =
              await repo.fetchStockPreviews(page.map((Mekan m) => m.id).toList(growable: false));
          previews = reset
              ? newPreviews
              : <String, List<MekanStockPeek>>{...previews, ...newPreviews};
        } catch (_) {
          // önizleme opsiyonel
        }
      }
      if (mounted) {
        setState(() {
          _mekans = merged;
          _leaderboard = lb;
          _stockPreviews = previews;
          _offset = merged.length;
          _hasMore = page.length >= pageSize;
          _loading = false;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    await _load(reset: false);
  }

  List<Mekan> get _filtered =>
      _filter == 'all' ? _mekans : _mekans.where((Mekan m) => m.typeKey == _filter).toList();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.listen<int>(mekanHubRefreshProvider, (int? prev, int next) {
      if (prev != null && next != prev) {
        _load();
      }
    });

    final int openCount = _mekans.where((Mekan m) => m.isOpen).length;

    return MekanHubScaffold(
      title: l10n.mekanlar,
      body: RefreshIndicator(
        color: MekanPalette.aqua,
        backgroundColor: MekanPalette.navy,
        onRefresh: () => _load(reset: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Mekan3DViewport(
                controller: _viewportController,
                selectedLocationType: _filter,
                onLocationSelected: (String loc) {
                  setState(() {
                    _filter = loc;
                    _viewportController.focusOnLocation(loc);
                  });
                },
                onEnterDungeon: (String locationId, String difficulty) {
                  if (locationId == 'dovus_kulubu') {
                    final Mekan? arenaMekan = _mekans.cast<Mekan?>().firstWhere(
                      (Mekan? m) => m != null && m.typeKey == 'dovus_kulubu',
                      orElse: () => _mekans.isNotEmpty ? _mekans.first : null,
                    );
                    if (arenaMekan != null) {
                      context.go(AppRoutes.mekanArena(arenaMekan.id));
                      return;
                    }
                  }
                  context.go(AppRoutes.dungeon);
                },
              ),
            ),
            SliverToBoxAdapter(child: _hero(openCount)),
            SliverToBoxAdapter(child: _ctaRow()),
            if (_leaderboard.isNotEmpty) SliverToBoxAdapter(child: _leaderboardSection()),
            SliverToBoxAdapter(child: _filterBar()),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: MekanPalette.aqua,
                  ),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: MekanEmpty(
                  icon: Icons.cloud_off_rounded,
                  title: l10n.mekan_bulunamadi,
                  message: _error!,
                  accent: MekanPalette.ruby,
                  action: NeonButton(
                    label: l10n.commonRetry,
                    icon: Icons.refresh_rounded,
                    onPressed: () => _load(reset: true),
                    expand: false,
                  ),
                ),
              )
            else if (_mekans.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: MekanEmpty(
                  icon: Icons.storefront_rounded,
                  title: l10n.mekan_yok,
                  message: l10n.mekan_ac_iksir_sat_sohret_kazan_arenada_dovus_kaca,
                  action: NeonButton(
                    label: l10n.mekan_ac,
                    icon: Icons.add_business_rounded,
                    onPressed: () => context.go(AppRoutes.mekanCreate),
                    expand: false,
                  ),
                ),
              )
            else if (_filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: MekanEmpty(
                  icon: Icons.filter_alt_off_rounded,
                  title: 'Bu Kategoride Mekan Yok',
                  message: 'Seçili kategoriye ait açık veya kayıtlı mekan bulunamadı. Diğer kategorileri keşfedebilirsin.',
                  accent: MekanPalette.aqua,
                  action: NeonButton(
                    label: 'Tüm Mekanları Göster',
                    icon: Icons.explore_rounded,
                    onPressed: () {
                      setState(() {
                        _filter = 'all';
                        _viewportController.focusOnLocation('all');
                      });
                    },
                    expand: false,
                  ),
                ),
              )
            else ...<Widget>[
              SliverPadding(
                padding: GameScrollLayout.fromLTRB(context, left: 14, top: 4, right: 14),
                sliver: SliverList.separated(
                  itemCount: _filtered.length,
                  separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int i) {
                    final Mekan m = _filtered[i];
                    final Widget card = _MekanRowCard(
                      mekan: m,
                      stockPeek: mekanHubVitrinPeek(
                        m,
                        _stockPreviews[m.id] ?? const <MekanStockPeek>[],
                      ),
                      onTap: () {
                        TutorialTriggers.onAnchorTap(
                          ref,
                          TutorialAnchorId.mekansList,
                        );
                        context.go(AppRoutes.mekanDetail(m.id));
                      },
                    );
                    if (i != 0) return card;
                    return TutorialAnchorScope(
                      id: TutorialAnchorId.mekansList,
                      child: card,
                    );
                  },
                ),
              ),
              if (_hasMore && _filter == 'all')
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
                    child: NeonButton(
                      label: _loadingMore ? 'Yükleniyor...' : 'Daha Fazla Yükle',
                      icon: Icons.expand_more_rounded,
                      busy: _loadingMore,
                      onPressed: _loadingMore ? null : _loadMore,
                      expand: true,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hero(int openCount) {
    final int partyCount = _mekans.where((Mekan m) => m.happyHourActive).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: NeonPanel(
        accent: MekanPalette.aqua,
        padding: const EdgeInsets.all(18),
        radius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: MekanPalette.fuchsia.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: MekanPalette.fuchsia.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: MekanPalette.fuchsia,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'CANLI EKONOMİ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: MekanPalette.fuchsia,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Icon(Icons.bolt_rounded, color: MekanPalette.gold, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'GECE HAYATI',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: MekanPalette.textHi,
                letterSpacing: 0.5,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Kulübe gir, takıl, partiye katıl. Vibe topla, menüden içecek al, arenada dövüş.',
              style: TextStyle(
                fontSize: 13,
                color: MekanPalette.textMid,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                GlowChip(
                  icon: Icons.storefront_rounded,
                  label: '${_mekans.length} Mekan',
                  color: MekanPalette.aqua,
                ),
                GlowChip(
                  icon: Icons.circle,
                  label: '$openCount Açık',
                  color: MekanPalette.neon,
                ),
                if (partyCount > 0)
                  GlowChip(
                    icon: Icons.celebration_rounded,
                    label: '$partyCount Parti Canlı',
                    color: MekanPalette.coral,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ctaRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TutorialAnchorScope(
              id: TutorialAnchorId.mekansMyCta,
              child: NeonButton(
                label: 'Benim Mekanım',
                icon: Icons.shield_moon_rounded,
                filled: false,
                accent: MekanPalette.aqua,
                onPressed: () {
                  TutorialTriggers.onAnchorTap(
                    ref,
                    TutorialAnchorId.mekansMyCta,
                  );
                  context.go(AppRoutes.myMekan);
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: NeonButton(
              label: 'Mekan Aç',
              icon: Icons.add_business_rounded,
              accent: MekanPalette.gold,
              onPressed: () => context.go(AppRoutes.mekanCreate),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaderboardSection() {
    final List<MekanLeaderboardRow> top = _leaderboard.take(5).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const NeonSectionHeader(
            title: 'Şöhret Sıralaması',
            subtitle: 'En ünlü mekanlar',
            accent: MekanPalette.gold,
          ),
          const SizedBox(height: 10),
          NeonPanel(
            accent: MekanPalette.gold,
            padding: const EdgeInsets.symmetric(vertical: 4),
            radius: 18,
            child: Column(
              children: <Widget>[
                for (int i = 0; i < top.length; i++) ...<Widget>[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  _LeaderRow(
                    row: top[i],
                    onTap: () => context.go(AppRoutes.mekanDetail(top[i].id)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    const List<(String key, String label, IconData icon)> opts = <(String, String, IconData)>[
      ('all', 'Tümü', Icons.explore_rounded),
      ('bar', 'Bar', Icons.local_bar_rounded),
      ('kahvehane', 'Kahve', Icons.coffee_rounded),
      ('dovus_kulubu', 'Dövüş', Icons.sports_mma_rounded),
      ('luks_lounge', 'Lüks', Icons.diamond_rounded),
      ('yeralti', 'Yeraltı', Icons.dark_mode_rounded),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 0, 12),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: opts.length,
          padding: const EdgeInsets.only(right: 14),
          separatorBuilder: (BuildContext context, int index) => const SizedBox(width: 8),
          itemBuilder: (BuildContext context, int i) {
            final (String key, String label, IconData icon) = opts[i];
            final bool sel = _filter == key;
            final Color accent = key == 'all' ? MekanPalette.aqua : MekanPalette.accent(key);
            return PressableScale(
              onTap: () {
                setState(() {
                  _filter = key;
                  _viewportController.focusOnLocation(key);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel
                      ? accent.withValues(alpha: 0.22)
                      : MekanPalette.surfaceHi.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: sel ? accent : Colors.white.withValues(alpha: 0.12),
                    width: sel ? 1.3 : 1.0,
                  ),
                  boxShadow: sel
                      ? <BoxShadow>[
                          BoxShadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 10,
                            spreadRadius: -1,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(icon, size: 14, color: sel ? accent : MekanPalette.textLow),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: sel ? accent : MekanPalette.textMid,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({required this.row, required this.onTap});
  final MekanLeaderboardRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = MekanPalette.accent(row.typeKey);
    final bool podium = row.rank <= 3;
    final Color rankColor = switch (row.rank) {
      1 => MekanPalette.gold,
      2 => const Color(0xFFC0C7D4),
      3 => MekanPalette.coral,
      _ => MekanPalette.textLow,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: accent.withValues(alpha: 0.15),
        highlightColor: accent.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: podium
                    ? BoxDecoration(
                        color: rankColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: rankColor.withValues(alpha: 0.55),
                          width: 1.1,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: rankColor.withValues(alpha: 0.25),
                            blurRadius: 8,
                          ),
                        ],
                      )
                    : null,
                child: Text(
                  '#${row.rank}',
                  style: TextStyle(
                    fontSize: podium ? 14 : 12.5,
                    fontWeight: FontWeight.w900,
                    color: rankColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              MekanTypeBadge(typeKey: row.typeKey, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: MekanPalette.textHi,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${mekanTypeLabelKey(row.typeKey)} • ${row.ownerName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: MekanPalette.textLow,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.star_rounded, size: 14, color: MekanPalette.gold),
                      const SizedBox(width: 3),
                      Text(
                        formatMekanGold(row.fame),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: MekanPalette.gold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Lv ${row.level}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MekanRowCard extends StatelessWidget {
  const _MekanRowCard({
    required this.mekan,
    required this.stockPeek,
    required this.onTap,
  });
  final Mekan mekan;
  final List<MekanStockPeek> stockPeek;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = MekanPalette.accent(mekan.typeKey);
    final bool hasPvp = mekanSupportsPvp(mekan.typeKey);

    return PressableScale(
      onTap: onTap,
      child: NeonPanel(
        accent: accent,
        padding: const EdgeInsets.all(14),
        radius: 18,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            MekanTypeBadge(typeKey: mekan.typeKey, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          mekan.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: MekanPalette.textHi,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      MekanStatusPill(isOpen: mekan.isOpen),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: <Widget>[
                      Text(
                        mekanTypeLabelKey(mekan.typeKey),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                      if (hasPvp) ...<Widget>[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: MekanPalette.ruby.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: MekanPalette.ruby.withValues(alpha: 0.45),
                              width: 0.8,
                            ),
                          ),
                          child: const Text(
                            'ARENA',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: MekanPalette.ruby,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      GlowChip(
                        icon: Icons.military_tech_rounded,
                        label: 'Lv ${mekan.level}',
                        color: accent,
                      ),
                      GlowChip(
                        icon: Icons.star_rounded,
                        label: formatMekanGold(mekan.fame),
                        color: MekanPalette.gold,
                      ),
                      if (mekan.happyHourActive)
                        GlowChip(
                          icon: Icons.celebration_rounded,
                          label: context.l10n.party_live,
                          color: MekanPalette.coral,
                        ),
                    ],
                  ),
                  if (stockPeek.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        const Text(
                          'VİTRİN',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: MekanPalette.textLow,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: stockPeek.take(6).map((MekanStockPeek s) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: MekanPalette.void_.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.14),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: ItemIconView(
                                      iconValue: s.icon,
                                      itemId: s.itemId,
                                      size: 20,
                                      fallback: '🧪',
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.chevron_right_rounded,
                color: accent.withValues(alpha: 0.8),
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
