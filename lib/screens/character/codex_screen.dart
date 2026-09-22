import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/services/retention_analytics.dart';
import '../../core/services/supabase_service.dart';
import '../../models/codex_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import 'widgets/codex_design.dart';

class CodexScreen extends ConsumerStatefulWidget {
  const CodexScreen({
    super.key,
    this.initialCategory = 'item',
    this.autoClaim = false,
  });

  final String initialCategory;
  final bool autoClaim;

  @override
  ConsumerState<CodexScreen> createState() => _CodexScreenState();
}

class _CodexScreenState extends ConsumerState<CodexScreen> {
  CodexDashboard? _dashboard;
  final Map<String, List<CodexEntry>> _entries = <String, List<CodexEntry>>{};
  final Map<String, bool> _truncated = <String, bool>{};
  bool _loading = true;
  bool _claiming = false;
  String? _error;
  late int _categoryIndex;
  String _rarityFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _milestoneScroll = ScrollController();

  static const int _pageLimit = 200;

  static final List<(String type, String label, IconData icon)> _tabs =
      <(String, String, IconData)>[
    ('item', 'Eşya', Icons.inventory_2_rounded),
    ('boss', 'Boss', Icons.whatshot_rounded),
    ('dungeon', 'Zindan', Icons.castle_rounded),
  ];

  @override
  void initState() {
    super.initState();
    final int idx = _tabs.indexWhere((t) => t.$1 == widget.initialCategory);
    _categoryIndex = idx >= 0 ? idx : 0;
    _loadAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _milestoneScroll.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dynamic dashRaw =
          await SupabaseService.client.rpc('get_codex_dashboard');
      if (dashRaw is Map && dashRaw['success'] == true) {
        _dashboard =
            CodexDashboard.fromJson(Map<String, dynamic>.from(dashRaw));
      }
      for (final (String type, _, _) in _tabs) {
        final dynamic raw = await SupabaseService.client.rpc(
          'get_codex_entries',
          params: <String, dynamic>{
            'p_type': type,
            'p_offset': 0,
            'p_limit': _pageLimit,
          },
        );
        if (raw is Map && raw['success'] == true) {
          final List<dynamic> rows =
              raw['entries'] is List ? raw['entries'] as List : const <dynamic>[];
          final List<CodexEntry> list = rows
              .whereType<Map>()
              .map(
                (dynamic r) =>
                    CodexEntry.fromJson(Map<String, dynamic>.from(r)),
              )
              .toList(growable: false);
          _entries[type] = list;
          final int? total = (raw['total'] as num?)?.toInt();
          _truncated[type] =
              total != null ? list.length < total : list.length >= _pageLimit;
        }
      }
      if (!mounted) return;
      setState(() => _loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToClaimableMilestone();
      });
      if (widget.autoClaim && (_dashboard?.claimableMilestones ?? 0) > 0) {
        await _claimNextMilestone();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = userFacingErrorMessage(e);
        });
      }
    }
  }

  void _scrollToClaimableMilestone() {
    final CodexDashboard? dash = _dashboard;
    if (dash == null || !_milestoneScroll.hasClients) return;
    final int idx =
        dash.milestones.indexWhere((CodexMilestone m) => m.claimable);
    if (idx < 0) return;
    const double cardW = 64 + 7;
    final double target = (idx * cardW) - 24;
    _milestoneScroll.animateTo(
      target.clamp(0.0, _milestoneScroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _claimNextMilestone() async {
    final int pending = _dashboard?.claimableMilestones ?? 0;
    if (pending <= 0 || _claiming) return;

    setState(() => _claiming = true);
    try {
      final dynamic res =
          await SupabaseService.client.rpc('claim_all_codex_milestones');
      if (!mounted) return;
      if (res is Map && res['success'] == true) {
        final int gold = (res['reward_gold'] as num?)?.toInt() ?? 0;
        final int gems = (res['reward_gems'] as num?)?.toInt() ?? 0;
        final int count = (res['claimed_count'] as num?)?.toInt() ?? pending;
        RetentionAnalytics.codexClaimAll(
          claimedCount: count,
          gold: gold,
          gems: gems,
        );
        final StringBuffer msg = StringBuffer('$count ödül alındı');
        if (gold > 0 || gems > 0) {
          msg.write(' (+');
          if (gold > 0) msg.write('$gold altın');
          if (gold > 0 && gems > 0) msg.write(', ');
          if (gems > 0) msg.write('$gems elmas');
          msg.write(')');
        }
        AppMessenger.showSuccess(context, msg.toString());
        await ref.read(playerProvider.notifier).loadProfile();
        await _loadAll();
      } else {
        AppMessenger.showError(
          context,
          (res is Map ? res['error']?.toString() : null) ?? 'Ödül alınamadı.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showError(context, userFacingErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  Future<void> _doLogout() async {
    await ref.read(authProvider.notifier).logout();
    ref.read(playerProvider.notifier).clear();
  }

  Color _rarityColor(String? rarity) => AppColors.forRarity(rarity ?? 'common');

  void _onEntryTap(CodexEntry entry) {
    if (entry.isDiscovered) {
      CodexEntryDetailSheet.show(
        context,
        entry: entry,
        rarityColor: _rarityColor(entry.rarity),
      );
      return;
    }
    AppMessenger.showInfo(
      context,
      entry.showsZonePin
          ? '${entry.hintLabel} bölgesinde keşfedilebilir.'
          : '${entry.hintLabel} kategorisinde gizli kayıt.',
    );
  }

  (String type, String label, IconData icon) get _activeTab =>
      _tabs[_categoryIndex];

  List<CodexEntry> get _activeEntries =>
      _entries[_activeTab.$1] ?? const <CodexEntry>[];

  List<CodexEntry> get _filteredEntries {
    final List<CodexEntry> all = _activeEntries;
    final String q = _searchQuery.trim().toLowerCase();
    Iterable<CodexEntry> base = switch (_rarityFilter) {
      'legendary' => all.where(
          (CodexEntry e) =>
              e.isDiscovered &&
              (e.rarity == 'legendary' || e.rarity == 'mythic'),
        ),
      'epic' => all.where(
          (CodexEntry e) => e.isDiscovered && e.rarity == 'epic',
        ),
      'rare' => all.where(
          (CodexEntry e) => e.isDiscovered && e.rarity == 'rare',
        ),
      'common' => all.where(
          (CodexEntry e) =>
              e.isDiscovered &&
              (e.rarity == 'common' ||
                  e.rarity == 'uncommon' ||
                  e.rarity == null ||
                  e.rarity!.isEmpty),
        ),
      'hidden' => all.where((CodexEntry e) => !e.isDiscovered),
      _ => all,
    };
    if (q.isNotEmpty) {
      base = base.where((CodexEntry e) {
        if (!e.isDiscovered) {
          return e.hintLabel.toLowerCase().contains(q) ||
              e.entryKey.toLowerCase().contains(q);
        }
        return e.displayName.toLowerCase().contains(q) ||
            e.hintLabel.toLowerCase().contains(q) ||
            e.entryKey.toLowerCase().contains(q);
      });
    }
    return base.toList(growable: false);
  }

  Map<String, (int, int)> get _categoryCounts {
    final Map<String, (int, int)> out = <String, (int, int)>{};
    for (final (String type, _, _) in _tabs) {
      final List<CodexEntry> list = _entries[type] ?? const <CodexEntry>[];
      final int d = list.where((CodexEntry e) => e.isDiscovered).length;
      out[type] = (d, list.length);
    }
    return out;
  }

  List<(String, String, int)> get _rarityOptions {
    final List<CodexEntry> all = _activeEntries;
    int count(bool Function(CodexEntry) pred) => all.where(pred).length;
    return <(String, String, int)>[
      ('all', 'Tümü', all.length),
      (
        'legendary',
        'Efsanevi',
        count(
          (CodexEntry e) =>
              e.isDiscovered &&
              (e.rarity == 'legendary' || e.rarity == 'mythic'),
        ),
      ),
      (
        'epic',
        'Destansı',
        count((CodexEntry e) => e.isDiscovered && e.rarity == 'epic'),
      ),
      (
        'rare',
        'Nadir',
        count((CodexEntry e) => e.isDiscovered && e.rarity == 'rare'),
      ),
      (
        'common',
        'Yaygın',
        count(
          (CodexEntry e) =>
              e.isDiscovered &&
              (e.rarity == 'common' ||
                  e.rarity == 'uncommon' ||
                  e.rarity == null ||
                  e.rarity!.isEmpty),
        ),
      ),
      (
        'hidden',
        'Gizli',
        count((CodexEntry e) => !e.isDiscovered),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CodexPalette.void_,
      appBar: GameTopBar(title: 'Kodex', onLogout: _doLogout),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.character,
        onLogout: _doLogout,
      ),
      body: GameScreenBackground(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: CodexPalette.gold),
              )
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.menu_book_rounded,
                            size: 40,
                            color: CodexPalette.titanium,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.mysticRuby,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _loadAll,
                            style: FilledButton.styleFrom(
                              backgroundColor: CodexPalette.gold,
                              foregroundColor: CodexPalette.void_,
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text(
                              'Tekrar Dene',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: CodexPalette.gold,
                    backgroundColor: CodexPalette.navy,
                    onRefresh: _loadAll,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: GameScrollLayout.withClearance(
                        context,
                        const EdgeInsets.only(bottom: 40),
                      ),
                      children: <Widget>[
                        if (_dashboard != null)
                          CodexVaultHero(
                            dashboard: _dashboard!,
                            claiming: _claiming,
                            onClaim: _claimNextMilestone,
                            milestoneScrollController: _milestoneScroll,
                          ),
                        const SizedBox(height: 6),
                        CodexCategoryBar(
                          tabs: _tabs,
                          selectedIndex: _categoryIndex,
                          counts: _categoryCounts,
                          onChanged: (int i) {
                            setState(() {
                              _categoryIndex = i;
                              _rarityFilter = 'all';
                              _searchQuery = '';
                              _searchCtrl.clear();
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        CodexSearchField(
                          controller: _searchCtrl,
                          onChanged: (String v) {
                            setState(() => _searchQuery = v);
                          },
                        ),
                        const SizedBox(height: 6),
                        CodexRarityFilter(
                          options: _rarityOptions,
                          selected: _rarityFilter,
                          onChanged: (String key) {
                            setState(() => _rarityFilter = key);
                          },
                        ),
                        const SizedBox(height: 8),
                        ..._buildGridSection(),
                      ],
                    ),
                  ),
      ),
    );
  }

  List<Widget> _buildGridSection() {
    final (String type, String label, IconData icon) = _activeTab;
    final List<CodexEntry> entries = _filteredEntries;
    final List<CodexEntry> all = _activeEntries;
    final int discovered =
        all.where((CodexEntry e) => e.isDiscovered).length;
    final bool truncated = _truncated[type] == true;

    if (all.isEmpty) {
      return <Widget>[
        const SizedBox(height: 24),
        CodexEmptyState(
          label: 'Henüz $label kaydı yok',
          icon: icon,
        ),
      ];
    }

    if (entries.isEmpty) {
      return <Widget>[
        CodexSectionHeader(
          title: '${label.toUpperCase()} KOLEKSİYONU',
          subtitle: '$discovered / ${all.length} keşfedildi',
        ),
        const SizedBox(height: 24),
        CodexEmptyState(
          label: _searchQuery.trim().isNotEmpty
              ? 'Arama sonucu yok'
              : 'Bu filtrede kayıt yok',
          icon: _searchQuery.trim().isNotEmpty
              ? Icons.search_off_rounded
              : Icons.filter_alt_off_rounded,
        ),
      ];
    }

    return <Widget>[
      CodexSectionHeader(
        title: '${label.toUpperCase()} KOLEKSİYONU',
        subtitle:
            '$discovered / ${all.length} keşfedildi · ${entries.length} gösteriliyor',
      ),
      if (truncated)
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 4, 14, 0),
          child: Text(
            'Liste kısaltıldı — sonraki sürümde sayfalama eklenecek.',
            style: TextStyle(
              color: CodexPalette.titanium,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: GameFixedGrid(
          crossAxisCount: 3,
          spacing: 8,
          itemCount: entries.length,
          itemBuilder: (BuildContext context, int index) {
            final CodexEntry entry = entries[index];
            return CodexStagger(
              index: _categoryIndex * 40 + index,
              child: AspectRatio(
                aspectRatio: 0.92,
                child: CodexEntryCard(
                  entry: entry,
                  rarityColor: _rarityColor(entry.rarity),
                  onTap: () => _onEntryTap(entry),
                ),
              ),
            );
          },
        ),
      ),
    ];
  }
}
