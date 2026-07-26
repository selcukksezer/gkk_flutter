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
import 'widgets/mekan_design.dart';
import 'widgets/mekan_scaffold.dart';
import 'widgets/mekan_theme.dart';

class MekansScreen extends ConsumerStatefulWidget {
  const MekansScreen({super.key});

  @override
  ConsumerState<MekansScreen> createState() => _MekansScreenState();
}

class _MekansScreenState extends ConsumerState<MekansScreen> {
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
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TutorialTriggers.onRouteEnter(ref, AppRoutes.mekans);
    });
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
      List<MekanLeaderboardRow> lb = _leaderboard;
      if (reset) {
        try {
          lb = await repo.fetchFameLeaderboard(limit: 10);
        } catch (_) {
          // leaderboard RPC optional; ignore if not yet applied
        }
      }
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
            SliverToBoxAdapter(child: _hero(openCount)),
            SliverToBoxAdapter(child: _ctaRow()),
            if (_leaderboard.isNotEmpty) SliverToBoxAdapter(child: _leaderboardSection()),
            SliverToBoxAdapter(child: _filterBar()),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: MekanPalette.aqua)),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: MekanEmpty(
                  icon: Icons.cloud_off_rounded,
                  title: l10n.mekan_bulunamadi,
                  message: _error!,
                  accent: MekanPalette.ruby,
                  action: NeonButton(label: l10n.commonRetry, icon: Icons.refresh_rounded, onPressed: () => _load(reset: true), expand: false),
                ),
              )
            else if (_filtered.isEmpty)
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
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                    child: NeonButton(
                      label: _loadingMore ? '...' : 'Daha fazla yükle',
                      icon: Icons.expand_more_rounded,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: NeonPanel(
        accent: MekanPalette.aqua,
        padding: const EdgeInsets.all(18),
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
                    border: Border.all(color: MekanPalette.fuchsia.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    'CANLI EKONOMI',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: MekanPalette.fuchsia, letterSpacing: 1.2),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.bolt_rounded, color: MekanPalette.gold, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'HAN TICARET AGI',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: MekanPalette.textHi, letterSpacing: 0.5, height: 1.05),
            ),
            const SizedBox(height: 6),
            const Text(
              'Mekan ac, iksir sat, sohret kazan. Arenada dovus, kacak ticaretle imparatorluk kur.',
              style: TextStyle(fontSize: 13, color: MekanPalette.textMid, height: 1.4),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                GlowChip(icon: Icons.storefront_rounded, label: '${_mekans.length} mekan', color: MekanPalette.aqua),
                const SizedBox(width: 8),
                GlowChip(icon: Icons.circle, label: '$openCount acik', color: MekanPalette.neon),
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
      child: TutorialAnchorScope(
        id: TutorialAnchorId.mekansMyCta,
        child: Row(
          children: <Widget>[
            Expanded(
              child: NeonButton(
                label: 'Benim Mekanim',
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
            const SizedBox(width: 10),
            Expanded(
              child: NeonButton(
                label: 'Mekan Ac',
                icon: Icons.add_business_rounded,
                accent: MekanPalette.gold,
                onPressed: () => context.go(AppRoutes.mekanCreate),
              ),
            ),
          ],
        ),
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
          const NeonSectionHeader(title: 'Sohret Siralamasi', subtitle: 'En unlu mekanlar', accent: MekanPalette.gold),
          const SizedBox(height: 10),
          NeonPanel(
            accent: MekanPalette.gold,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < top.length; i++) ...<Widget>[
                  if (i > 0) Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                  _LeaderRow(row: top[i], onTap: () => context.go('/mekans/${top[i].id}')),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    const List<List<String>> opts = <List<String>>[
      <String>['all', 'Tumu'],
      <String>['bar', 'Bar'],
      <String>['kahvehane', 'Kahve'],
      <String>['dovus_kulubu', 'Dovus'],
      <String>['luks_lounge', 'Lux'],
      <String>['yeralti', 'Yeralti'],
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 0, 12),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: opts.length,
          padding: const EdgeInsets.only(right: 14),
          separatorBuilder: (BuildContext context, int index) => const SizedBox(width: 8),
          itemBuilder: (BuildContext context, int i) {
            final String key = opts[i][0];
            final bool sel = _filter == key;
            final Color accent = key == 'all' ? MekanPalette.aqua : MekanPalette.accent(key);
            return PressableScale(
              onTap: () => setState(() => _filter = key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel ? accent.withValues(alpha: 0.18) : MekanPalette.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: sel ? accent : Colors.white.withValues(alpha: 0.08), width: 1.2),
                ),
                child: Text(
                  opts[i][1],
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: sel ? accent : MekanPalette.textMid,
                  ),
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 28,
              child: Text(
                '#${row.rank}',
                style: TextStyle(fontSize: podium ? 16 : 13, fontWeight: FontWeight.w900, color: rankColor),
              ),
            ),
            const SizedBox(width: 8),
            MekanTypeBadge(typeKey: row.typeKey, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: MekanPalette.textHi),
                  ),
                  Text(
                    '${mekanTypeLabelKey(row.typeKey)} - ${row.ownerName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: MekanPalette.textLow, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.star_rounded, size: 14, color: MekanPalette.gold),
                    const SizedBox(width: 3),
                    Text('${row.fame}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: MekanPalette.gold)),
                  ],
                ),
                Text('Lv ${row.level}', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: accent)),
              ],
            ),
          ],
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
    return PressableScale(
      onTap: onTap,
      child: NeonPanel(
        accent: accent,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            MekanTypeBadge(typeKey: mekan.typeKey, size: 54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    mekan.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: MekanPalette.textHi),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mekanTypeLabelKey(mekan.typeKey),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      GlowChip(icon: Icons.military_tech_rounded, label: 'Lv ${mekan.level}', color: accent),
                      const SizedBox(width: 6),
                      GlowChip(icon: Icons.star_rounded, label: '${mekan.fame}', color: MekanPalette.gold),
                    ],
                  ),
                  if (stockPeek.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        const Text(
                          'VİTRİN',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: MekanPalette.textLow,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ...stockPeek.map((MekanStockPeek s) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Container(
                                width: 26,
                                height: 26,
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: MekanPalette.void_
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: Colors.white
                                        .withValues(alpha: 0.12),
                                  ),
                                ),
                                child: ItemIconView(
                                  iconValue: s.icon,
                                  itemId: s.itemId,
                                  size: 20,
                                  fallback: '🧪',
                                ),
                              ),
                            )),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                MekanStatusPill(isOpen: mekan.isOpen),
                const SizedBox(height: 12),
                Icon(Icons.chevron_right_rounded, color: accent, size: 22),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
