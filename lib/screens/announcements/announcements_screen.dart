import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../components/layout/ticker_design.dart';
import '../../models/live_ticker_model.dart';
import '../../providers/live_ticker_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/logout_helper.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  static const List<_TickerFilter> _filters = <_TickerFilter>[
    _TickerFilter('all', 'Tümü'),
    _TickerFilter('guild_war', 'Lonca'),
    _TickerFilter('dungeon_clear', 'Boss'),
    _TickerFilter('siege_win', 'Kuşatma'),
    _TickerFilter('siege_live', 'Canlı'),
    _TickerFilter('enhance_success', '+8'),
    _TickerFilter('loot_rare', 'Nadir'),
    _TickerFilter('night_market', 'Gece'),
    _TickerFilter('king_blessing', 'Kral'),
    _TickerFilter('king_gift', 'Hediye'),
    _TickerFilter('staff_broadcast', 'Duyuru'),
    _TickerFilter('player_ban', 'Ban'),
  ];

  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(liveTickerProvider.notifier).loadArchive();
    });
  }

  Future<void> _refresh() async {
    await ref.read(liveTickerProvider.notifier).loadArchive();
  }

  List<LiveTickerItem> _visible(LiveTickerState state) {
    final List<LiveTickerItem> all = state.feedArchive;
    if (_filter == 'all') return all;
    return all.where((LiveTickerItem e) => e.type == _filter).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final LiveTickerState ticker = ref.watch(liveTickerProvider);
    final List<LiveTickerItem> items = _visible(ticker);

    return Scaffold(
      backgroundColor: AppColors.carbonVoid,
      appBar: GameTopBar(
        title: 'Kamp Duyuruları',
        onLogout: () => performLogout(ref),
      ),
      body: GameScreenBackground(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: TickerPalette.gold,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.base,
                    AppSpacing.sm,
                    AppSpacing.base,
                    AppSpacing.sm,
                  ),
                  child: Text(
                    'Boss temizleri, lonca saldırıları, kral indirimleri ve moderasyon duyuruları.',
                    style: const TextStyle(
                      color: TickerPalette.textMid,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                    itemCount: _filters.length,
                    separatorBuilder: (_, _i) => const SizedBox(width: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final _TickerFilter f = _filters[index];
                      return TickerTypeChip(
                        label: f.label,
                        selected: _filter == f.key,
                        accent: LiveTickerVisual.forType(
                          f.key == 'all' ? 'ambient' : f.key,
                        ).accent,
                        onTap: () => setState(() => _filter = f.key),
                      );
                    },
                  ),
                ),
              ),
              if (ticker.archiveLoading && items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: TickerPalette.gold),
                  ),
                )
              else if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        ticker.error ?? '🌌 Henüz duyuru yok.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: TickerPalette.textMid),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.base,
                    AppSpacing.base,
                    AppSpacing.base,
                    AppSpacing.xl,
                  ),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _i) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final LiveTickerItem item = items[index];
                      return TickerBentoCard(
                        text: item.text,
                        visual: item.visual,
                        createdAt: item.createdAt,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TickerFilter {
  const _TickerFilter(this.key, this.label);

  final String key;
  final String label;
}
