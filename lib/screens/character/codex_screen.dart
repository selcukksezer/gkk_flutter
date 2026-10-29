import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/app_messenger.dart';
import '../../components/common/item_icon_view.dart';
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
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import 'widgets/codex_design.dart';

class CodexScreen extends ConsumerStatefulWidget {
  const CodexScreen({
    super.key,
    this.initialCategory = 'sets',
    this.autoClaim = false,
  });

  final String initialCategory;
  final bool autoClaim;

  @override
  ConsumerState<CodexScreen> createState() => _CodexScreenState();
}

class _CodexScreenState extends ConsumerState<CodexScreen> {
  CodexDashboard? _dashboard;
  final Map<String, List<CodexEntry>> _rawEntries = <String, List<CodexEntry>>{};
  final Map<String, bool> _truncated = <String, bool>{};
  bool _loading = true;
  bool _claiming = false;
  String? _error;
  late int _categoryIndex;
  String _rarityFilter = 'all';
  String _searchQuery = '';
  bool _isGridView = true;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _milestoneScroll = ScrollController();

  static const int _pageLimit = 200;

  static final List<(String type, String label, IconData icon)> _tabs =
      <(String, String, IconData)>[
    ('sets', 'Setler', Icons.shield_moon_rounded),
    ('weapons', 'Silah', Icons.colorize_rounded),
    ('armor', 'Zırh', Icons.shield_rounded),
    ('accessories', 'Aksesuar', Icons.diamond_rounded),
    ('monster_lore', 'Canavar', Icons.whatshot_rounded),
    ('all', 'Tümü', Icons.auto_stories_rounded),
  ];

  @override
  void initState() {
    super.initState();
    final String initial = switch (widget.initialCategory) {
      'item' => 'weapons',
      'boss' || 'dungeon' => 'monster_lore',
      _ => widget.initialCategory,
    };
    final int idx = _tabs.indexWhere((t) => t.$1 == initial);
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
      for (final String type in const <String>['item', 'boss', 'dungeon']) {
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
          _rawEntries[type] = list;
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
    final CodexDashboard dash = _effectiveDashboard;
    if (!_milestoneScroll.hasClients) return;
    final int idx =
        dash.milestones.indexWhere((CodexMilestone m) => m.claimable);
    if (idx < 0) return;
    const double cardW = 66 + 7;
    final double target = (idx * cardW) - 24;
    _milestoneScroll.animateTo(
      target.clamp(0.0, _milestoneScroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _claimNextMilestone() async {
    final int pending = _effectiveDashboard.claimableMilestones;
    if (pending <= 0 || _claiming) return;

    setState(() => _claiming = true);
    HapticFeedback.mediumImpact();
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

        final StringBuffer rewardDesc = StringBuffer('$count Aşama Tamamlandı');
        if (gold > 0 || gems > 0) {
          rewardDesc.write(' (+');
          if (gold > 0) rewardDesc.write('${_fmtNumber(gold)} Altın');
          if (gold > 0 && gems > 0) rewardDesc.write(', ');
          if (gems > 0) rewardDesc.write('$gems Elmas');
          rewardDesc.write(')');
        }

        CodexStatUnlockedToast.show(
          context,
          title: 'Cephanelik Ödülü Alındı!',
          message: rewardDesc.toString(),
          accentColor: AppColors.liquidGold,
        );

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

  static String _fmtNumber(int val) {
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(0)}K';
    return '$val';
  }

  Future<void> _doLogout() async {
    await ref.read(authProvider.notifier).logout();
    ref.read(playerProvider.notifier).clear();
  }

  Color _rarityColor(String? rarity) => AppColors.forRarity(rarity ?? 'common');

  bool _isWeapon(CodexEntry e) {
    if (e.entryType != 'item') return false;
    final String z = (e.zone ?? '').toLowerCase();
    final String k = e.entryKey.toLowerCase();
    final String n = e.displayName.toLowerCase();
    return z == 'weapon' ||
        k.contains('sword') ||
        k.contains('bow') ||
        k.contains('dagger') ||
        k.contains('staff') ||
        k.contains('orb') ||
        k.contains('greatsword') ||
        n.contains('kılıç') ||
        n.contains('yay') ||
        n.contains('hançer') ||
        n.contains('asa') ||
        n.contains('küre');
  }

  bool _isArmor(CodexEntry e) {
    if (e.entryType != 'item') return false;
    final String z = (e.zone ?? '').toLowerCase();
    final String k = e.entryKey.toLowerCase();
    final String n = e.displayName.toLowerCase();
    return z == 'armor' ||
        k.contains('plate') ||
        k.contains('cuirass') ||
        k.contains('shield') ||
        k.contains('boots') ||
        k.contains('greaves') ||
        k.contains('helm') ||
        k.contains('hauberk') ||
        k.contains('spaulders') ||
        n.contains('zırh') ||
        n.contains('kalkan') ||
        n.contains('göğüslük') ||
        n.contains('çizme') ||
        n.contains('omuzluk') ||
        n.contains('dizlik');
  }

  bool _isAccessory(CodexEntry e) {
    if (e.entryType != 'item') return false;
    final String z = (e.zone ?? '').toLowerCase();
    final String k = e.entryKey.toLowerCase();
    final String n = e.displayName.toLowerCase();
    return z == 'accessory' ||
        k.contains('ring') ||
        k.contains('necklace') ||
        k.contains('wing') ||
        k.contains('earring') ||
        k.contains('belt') ||
        k.contains('relic') ||
        n.contains('kanat') ||
        n.contains('yüzük') ||
        n.contains('kolye') ||
        n.contains('kemer') ||
        n.contains('yadigar');
  }

  bool _isMonsterLore(CodexEntry e) =>
      e.entryType == 'boss' || e.entryType == 'dungeon';

  List<CodexEntry> get _allEntries {
    final List<CodexEntry> all = <CodexEntry>[];
    for (final List<CodexEntry> list in _rawEntries.values) {
      all.addAll(list);
    }
    return all;
  }

  List<CodexEntry> get _discoveredEntries =>
      _allEntries.where((CodexEntry e) => e.isDiscovered).toList(growable: false);

  CodexDashboard get _effectiveDashboard {
    if (_dashboard != null) return _dashboard!;
    final List<CodexEntry> all = _allEntries;
    final int discovered = _discoveredEntries.length;
    return CodexDashboard(
      discovered: discovered,
      total: all.length,
      newEntries24h: 0,
      claimableMilestones: 0,
      luckBonus: 0,
      milestones: const <CodexMilestone>[],
    );
  }

  (String type, String label, IconData icon) get _activeTab =>
      _tabs[_categoryIndex];

  List<CodexEntry> get _activeEntries {
    final String tab = _activeTab.$1;
    final List<CodexEntry> items = _rawEntries['item'] ?? const <CodexEntry>[];
    return switch (tab) {
      'weapons' => items.where(_isWeapon).toList(growable: false),
      'armor' => items.where(_isArmor).toList(growable: false),
      'accessories' => items.where(_isAccessory).toList(growable: false),
      'monster_lore' => _allEntries.where(_isMonsterLore).toList(growable: false),
      'all' => _allEntries,
      _ => items,
    };
  }

  Map<String, (int, int)> get _categoryCounts {
    final Map<String, (int, int)> out = <String, (int, int)>{};

    // Sets count
    int unlockedSetPieces = 0;
    for (final CodexGearSet s in CodexGearSet.allSets) {
      unlockedSetPieces += s.discoveredPiecesCount(_discoveredEntries);
    }
    out['sets'] = (unlockedSetPieces, 16);

    // Weapons
    final List<CodexEntry> items = _rawEntries['item'] ?? const <CodexEntry>[];
    final List<CodexEntry> weapons = items.where(_isWeapon).toList(growable: false);
    out['weapons'] = (
      weapons.where((CodexEntry e) => e.isDiscovered).length,
      weapons.length,
    );

    // Armor
    final List<CodexEntry> armor = items.where(_isArmor).toList(growable: false);
    out['armor'] = (
      armor.where((CodexEntry e) => e.isDiscovered).length,
      armor.length,
    );

    // Accessories
    final List<CodexEntry> acc = items.where(_isAccessory).toList(growable: false);
    out['accessories'] = (
      acc.where((CodexEntry e) => e.isDiscovered).length,
      acc.length,
    );

    // Monster Lore
    final List<CodexEntry> bosses = _rawEntries['boss'] ?? const <CodexEntry>[];
    final List<CodexEntry> dungeons =
        _rawEntries['dungeon'] ?? const <CodexEntry>[];
    final List<CodexEntry> monsters = <CodexEntry>[...bosses, ...dungeons];
    out['monster_lore'] = (
      monsters.where((CodexEntry e) => e.isDiscovered).length,
      monsters.length,
    );

    // All
    final List<CodexEntry> all = _allEntries;
    out['all'] = (
      all.where((CodexEntry e) => e.isDiscovered).length,
      all.length,
    );

    return out;
  }

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

  List<(String, String, int)> get _rarityOptions {
    final List<CodexEntry> all = _activeEntries;
    int count(bool Function(CodexEntry) pred) => all.where(pred).length;
    return <(String, String, int)>[
      ('all', 'Tümü', all.length),
      (
        'legendary',
        'Efsanevi / Mitik',
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

  String? _getSetAffiliation(CodexEntry entry) {
    for (final CodexGearSet s in CodexGearSet.allSets) {
      if (s.isPieceDiscovered(
        CodexGearSetPiece(
          id: entry.entryKey,
          name: entry.displayName,
          slot: 'Cephanelik',
          category: entry.entryType,
          rarity: entry.rarity ?? 'legendary',
          lore: '',
          hintLocation: '',
          stats: const <String, String>{},
          iconData: Icons.shield_rounded,
        ),
        <CodexEntry>[entry],
      )) {
        return s.name;
      }
    }
    return null;
  }

  void _onEntryTap(CodexEntry entry) {
    HapticFeedback.selectionClick();
    if (entry.isDiscovered) {
      final String? setAffiliation = _getSetAffiliation(entry);
      CodexEntryDetailSheet.show(
        context,
        entry: entry,
        rarityColor: _rarityColor(entry.rarity),
        setAffiliation: setAffiliation != null ? '$setAffiliation Parçası' : null,
      );
      return;
    }

    _showLockedClueModal(entry);
  }

  void _showLockedClueModal(CodexEntry entry) {
    HapticFeedback.lightImpact();
    final Color rarityColor = _rarityColor(entry.rarity);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Kilitli Kayıt',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (BuildContext ctx, _, _) {
        return _CodexLockedClueDialog(
          entry: entry,
          rarityColor: rarityColor,
        );
      },
      transitionBuilder: (
        BuildContext context,
        Animation<double> anim,
        Animation<double> secondaryAnim,
        Widget child,
      ) {
        final CurvedAnimation curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  void _onInspectSetPiece(CodexGearSetPiece piece, CodexGearSet set) {
    HapticFeedback.selectionClick();
    final bool isDiscovered =
        set.isPieceDiscovered(piece, _discoveredEntries);

    final CodexEntry virtualEntry = CodexEntry(
      entryType: piece.category,
      entryKey: piece.id,
      displayName: piece.name,
      rarity: piece.rarity,
      zone: piece.hintLocation,
      isDiscovered: isDiscovered,
      discoveredAt: isDiscovered ? DateTime.now() : null,
    );

    CodexEntryDetailSheet.show(
      context,
      entry: virtualEntry,
      rarityColor: _rarityColor(piece.rarity),
      customLore: piece.lore,
      setAffiliation: '${set.name} [${piece.slot}]',
      statAttributes: piece.stats,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: GameTopBar(title: 'Kodex & Cephanelik', onLogout: _doLogout),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.character,
        onLogout: _doLogout,
      ),
      body: GameScreenBackground(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.liquidGold),
              )
            : _error != null
                ? Center(
                    child: Padding(
                      padding: AppSpacing.pagePadding,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.menu_book_rounded,
                            size: 40,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyBold.copyWith(
                              color: AppColors.mysticRuby,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.base),
                          FilledButton.icon(
                            onPressed: _loadAll,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.liquidGold,
                              foregroundColor: AppColors.carbonVoid,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.md,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMd,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(
                              'Tekrar Dene',
                              style: AppTextStyles.dialogButton,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: AppColors.liquidGold,
                    backgroundColor: AppColors.bgSurface,
                    onRefresh: _loadAll,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: GameScrollLayout.withClearance(
                        context,
                        const EdgeInsets.only(bottom: AppSpacing.xxxl),
                      ),
                      children: <Widget>[
                        CodexVaultHero(
                          dashboard: _effectiveDashboard,
                          claiming: _claiming,
                          onClaim: _claimNextMilestone,
                          milestoneScrollController: _milestoneScroll,
                          discoveredEntries: _discoveredEntries,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        CodexCategoryBar(
                          tabs: _tabs,
                          selectedIndex: _categoryIndex,
                          counts: _categoryCounts,
                          onChanged: (int i) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _categoryIndex = i;
                              _rarityFilter = 'all';
                              _searchQuery = '';
                              _searchCtrl.clear();
                            });
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        CodexSearchField(
                          controller: _searchCtrl,
                          onChanged: (String v) {
                            setState(() => _searchQuery = v);
                          },
                        ),
                        if (_activeTab.$1 != 'sets') ...<Widget>[
                          const SizedBox(height: AppSpacing.xs),
                          CodexRarityFilter(
                            options: _rarityOptions,
                            selected: _rarityFilter,
                            onChanged: (String key) {
                              HapticFeedback.selectionClick();
                              setState(() => _rarityFilter = key);
                            },
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        ..._buildSectionContent(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.xs,
        AppSpacing.base,
        0,
      ),
      child: Row(
        children: <Widget>[
          Text(
            title,
            style: AppTextStyles.label.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          Text(
            subtitle,
            style: AppTextStyles.micro.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // View Mode Switcher
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isGridView = !_isGridView);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs - 1,
              ),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                border: Border.all(
                  color: AppColors.borderDefault,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    _isGridView
                        ? Icons.view_agenda_rounded
                        : Icons.grid_view_rounded,
                    size: 13,
                    color: AppColors.liquidGold,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isGridView ? 'Liste' : 'Izgara',
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.liquidGold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSectionContent() {
    final (String type, String label, IconData icon) = _activeTab;

    // Sets Tab
    if (type == 'sets') {
      final List<CodexGearSet> sets = _searchQuery.trim().isEmpty
          ? CodexGearSet.allSets
          : CodexGearSet.allSets.where((CodexGearSet s) {
              final String q = _searchQuery.trim().toLowerCase();
              return s.name.toLowerCase().contains(q) ||
                  s.subtitle.toLowerCase().contains(q) ||
                  s.pieces.any(
                    (CodexGearSetPiece p) =>
                        p.name.toLowerCase().contains(q) ||
                        p.slot.toLowerCase().contains(q),
                  );
            }).toList(growable: false);

      if (sets.isEmpty) {
        return <Widget>[
          const SizedBox(height: AppSpacing.xl),
          const CodexEmptyState(
            label: 'Aramaya uygun Aion 2 seti bulunamadı',
            icon: Icons.search_off_rounded,
          ),
        ];
      }

      return <Widget>[
        CodexGearSetShowcase(
          sets: sets,
          discoveredEntries: _discoveredEntries,
          onInspectPiece: _onInspectSetPiece,
        ),
      ];
    }

    final List<CodexEntry> entries = _filteredEntries;
    final List<CodexEntry> all = _activeEntries;
    final int discovered =
        all.where((CodexEntry e) => e.isDiscovered).length;
    final bool truncated = _truncated[type] == true;

    if (all.isEmpty) {
      return <Widget>[
        const SizedBox(height: AppSpacing.xl),
        CodexEmptyState(
          label: 'Henüz $label kaydı yok',
          icon: icon,
        ),
      ];
    }

    if (entries.isEmpty) {
      return <Widget>[
        _buildSectionHeader(
          title: '${label.toUpperCase()} KOLEKSİYONU',
          subtitle: '$discovered / ${all.length} keşfedildi',
        ),
        const SizedBox(height: AppSpacing.xl),
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
      _buildSectionHeader(
        title: '${label.toUpperCase()} KOLEKSİYONU',
        subtitle:
            '$discovered / ${all.length} keşfedildi · ${entries.length} gösteriliyor',
      ),
      if (truncated)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            AppSpacing.xs,
            AppSpacing.base,
            0,
          ),
          child: Text(
            'Liste kısaltıldı — sonraki sürümde sayfalama eklenecek.',
            style: AppTextStyles.micro.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ),
      const SizedBox(height: AppSpacing.sm),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: _isGridView
            ? GameFixedGrid(
                crossAxisCount: 3,
                spacing: AppSpacing.sm,
                itemCount: entries.length,
                itemBuilder: (BuildContext context, int index) {
                  final CodexEntry entry = entries[index];
                  final String? setName = _getSetAffiliation(entry);
                  return CodexStagger(
                    index: _categoryIndex * 40 + index,
                    child: AspectRatio(
                      aspectRatio: 0.88,
                      child: _CodexEntryGridTile(
                        entry: entry,
                        rarityColor: _rarityColor(entry.rarity),
                        setName: setName,
                        onTap: () => _onEntryTap(entry),
                      ),
                    ),
                  );
                },
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (BuildContext context, int index) {
                  final CodexEntry entry = entries[index];
                  final String? setName = _getSetAffiliation(entry);
                  return CodexStagger(
                    index: _categoryIndex * 40 + index,
                    child: _CodexEntryLoreTile(
                      entry: entry,
                      rarityColor: _rarityColor(entry.rarity),
                      setName: setName,
                      onTap: () => _onEntryTap(entry),
                    ),
                  );
                },
              ),
      ),
    ];
  }
}

// ─── Entry Grid Tile (AAA Rarity Framing & Glow) ──────────────────────────────

class _CodexEntryGridTile extends StatelessWidget {
  const _CodexEntryGridTile({
    required this.entry,
    required this.rarityColor,
    required this.onTap,
    this.setName,
  });

  final CodexEntry entry;
  final Color rarityColor;
  final VoidCallback onTap;
  final String? setName;

  @override
  Widget build(BuildContext context) {
    final bool discovered = entry.isDiscovered;
    final Color glowColor = discovered ? rarityColor : AppColors.cyberFuchsia;
    final String hint = entry.hintLabel;
    final bool isMythicOrLegendary =
        entry.rarity == 'mythic' || entry.rarity == 'legendary';

    return CodexPressable(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.bgSurface.withValues(alpha: 0.95),
                AppColors.bgDeep.withValues(alpha: 0.98),
              ],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: discovered
                  ? (isMythicOrLegendary
                      ? rarityColor.withValues(alpha: 0.75)
                      : rarityColor.withValues(alpha: 0.5))
                  : AppColors.borderDefault.withValues(alpha: 0.3),
              width: discovered && isMythicOrLegendary ? 1.4 : 1.0,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: glowColor.withValues(alpha: discovered ? 0.2 : 0.05),
                blurRadius: discovered ? 10 : 4,
                spreadRadius: discovered && isMythicOrLegendary ? 1 : 0,
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              const Positioned.fill(
                child: CustomPaint(
                  painter: DotGridPainter(spacing: 12, dotOpacity: 0.04),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xs + 2),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            hint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.micro.copyWith(
                              fontSize: 8,
                              color: discovered
                                  ? AppColors.liquidGold
                                  : AppColors.cyberFuchsia.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                        if (setName != null) ...<Widget>[
                          const SizedBox(width: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.liquidGold.withValues(alpha: 0.16),
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusXs),
                              border: Border.all(
                                color: AppColors.liquidGold
                                    .withValues(alpha: 0.45),
                                width: 0.6,
                              ),
                            ),
                            child: Text(
                              'SET',
                              style: AppTextStyles.micro.copyWith(
                                fontSize: 6.5,
                                color: AppColors.liquidGold,
                              ),
                            ),
                          ),
                        ] else if (discovered) ...<Widget>[
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 9,
                            color: rarityColor,
                          ),
                        ],
                      ],
                    ),
                    Expanded(
                      child: Center(
                        child: discovered && entry.entryType == 'item'
                            ? ItemIconView(
                                itemId: entry.entryKey,
                                iconValue: '',
                                size: 34,
                              )
                            : _CodexEntryTileOrb(
                                discovered: discovered,
                                accent: discovered
                                    ? rarityColor
                                    : AppColors.cyberFuchsia,
                                size: 34,
                                entryType: entry.entryType,
                              ),
                      ),
                    ),
                    Text(
                      discovered ? entry.displayName : '???',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.captionBold.copyWith(
                        fontSize: 10,
                        height: 1.15,
                        color: discovered
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      discovered
                          ? codexRarityLabel(entry.rarity).toUpperCase()
                          : 'KİLİTLİ',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.micro.copyWith(
                        fontSize: 8,
                        letterSpacing: 0.5,
                        color: discovered
                            ? rarityColor
                            : AppColors.cyberFuchsia.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Entry Lore List Tile (Expansive Codex Lore View) ─────────────────────────

class _CodexEntryLoreTile extends StatelessWidget {
  const _CodexEntryLoreTile({
    required this.entry,
    required this.rarityColor,
    required this.onTap,
    this.setName,
  });

  final CodexEntry entry;
  final Color rarityColor;
  final VoidCallback onTap;
  final String? setName;

  @override
  Widget build(BuildContext context) {
    final bool discovered = entry.isDiscovered;
    final Color glowColor = discovered ? rarityColor : AppColors.cyberFuchsia;
    final String rarityName = codexRarityLabel(entry.rarity);

    return CodexPressable(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.bgSurface.withValues(alpha: 0.94),
                AppColors.bgDeep.withValues(alpha: 0.98),
              ],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: discovered
                  ? rarityColor.withValues(alpha: 0.45)
                  : AppColors.borderDefault.withValues(alpha: 0.35),
              width: 1.0,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: glowColor.withValues(alpha: discovered ? 0.14 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              // Leading Icon / Orb
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  color: AppColors.carbonVoid.withValues(alpha: 0.6),
                  border: Border.all(
                    color: discovered
                        ? rarityColor.withValues(alpha: 0.6)
                        : AppColors.borderDefault.withValues(alpha: 0.4),
                  ),
                ),
                child: Center(
                  child: discovered && entry.entryType == 'item'
                      ? ItemIconView(
                          itemId: entry.entryKey,
                          iconValue: '',
                          size: 32,
                        )
                      : _CodexEntryTileOrb(
                          discovered: discovered,
                          accent: discovered
                              ? rarityColor
                              : AppColors.cyberFuchsia,
                          size: 30,
                          entryType: entry.entryType,
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Body
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            discovered ? entry.displayName : 'Gizemli Kayıt',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.titleBold.copyWith(
                              fontSize: 13,
                              color: discovered
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (setName != null) ...<Widget>[
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.liquidGold.withValues(alpha: 0.15),
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusXs),
                              border: Border.all(
                                color: AppColors.liquidGold
                                    .withValues(alpha: 0.45),
                                width: 0.6,
                              ),
                            ),
                            child: Text(
                              setName!,
                              style: AppTextStyles.micro.copyWith(
                                fontSize: 8,
                                color: AppColors.liquidGold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: discovered
                                ? rarityColor.withValues(alpha: 0.14)
                                : AppColors.cyberFuchsia.withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusXs),
                            border: Border.all(
                              color: discovered
                                  ? rarityColor.withValues(alpha: 0.4)
                                  : AppColors.cyberFuchsia
                                      .withValues(alpha: 0.35),
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            discovered
                                ? (rarityName.isEmpty ? 'KAYIT' : rarityName)
                                : 'KİLİTLİ',
                            style: AppTextStyles.micro.copyWith(
                              fontSize: 8,
                              color: discovered
                                  ? rarityColor
                                  : AppColors.cyberFuchsia,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs + 2),
                        const Icon(
                          Icons.place_rounded,
                          size: 11,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            entry.hintLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.micro.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Action Trailing
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: discovered
                      ? AppColors.liquidGold.withValues(alpha: 0.15)
                      : AppColors.bgCardElevated,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(
                    color: discovered
                        ? AppColors.liquidGold.withValues(alpha: 0.45)
                        : AppColors.borderDefault,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      discovered ? 'İncele' : 'İpucu',
                      style: AppTextStyles.micro.copyWith(
                        color: discovered
                            ? AppColors.liquidGold
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: discovered
                          ? AppColors.liquidGold
                          : AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Entry Tile Orb Icon ─────────────────────────────────────────────────────

class _CodexEntryTileOrb extends StatelessWidget {
  const _CodexEntryTileOrb({
    required this.discovered,
    required this.accent,
    this.size = 34,
    this.entryType = 'item',
  });

  final bool discovered;
  final Color accent;
  final double size;
  final String entryType;

  IconData get _icon {
    if (!discovered) return Icons.lock_outline_rounded;
    return switch (entryType) {
      'boss' => Icons.whatshot_rounded,
      'dungeon' => Icons.castle_rounded,
      _ => Icons.auto_stories_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final double inner = size * 0.84;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (discovered)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          Container(
            width: inner,
            height: inner,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  accent.withValues(alpha: discovered ? 0.35 : 0.12),
                  AppColors.bgDeep.withValues(alpha: 0.6),
                ],
              ),
              border: Border.all(
                color: accent.withValues(alpha: discovered ? 0.7 : 0.3),
                width: 1.2,
              ),
            ),
            child: Icon(
              _icon,
              color: discovered
                  ? accent
                  : AppColors.textTertiary,
              size: size * 0.44,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Locked Entry Clue Dialog Modal ──────────────────────────────────────────

class _CodexLockedClueDialog extends StatelessWidget {
  const _CodexLockedClueDialog({
    required this.entry,
    required this.rarityColor,
  });

  final CodexEntry entry;
  final Color rarityColor;

  @override
  Widget build(BuildContext context) {
    final String typeLabel = switch (entry.entryType) {
      'boss' => 'Boss',
      'dungeon' => 'Zindan',
      _ => 'Eşya',
    };
    final String rarity = codexRarityLabel(entry.rarity);

    return Material(
      color: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 360),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        AppColors.bgSurface.withValues(alpha: 0.96),
                        AppColors.bgDeep.withValues(alpha: 0.98),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
                    border: Border.all(
                      color: AppColors.accentCyan.withValues(alpha: 0.5),
                      width: 1.4,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.accentCyan.withValues(alpha: 0.25),
                        blurRadius: 28,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: <Widget>[
                      const Positioned.fill(
                        child: CustomPaint(
                          painter:
                              DotGridPainter(spacing: 12, dotOpacity: 0.05),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            // Top Bar
                            Row(
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: AppSpacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentCyan
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusXs,
                                    ),
                                    border: Border.all(
                                      color: AppColors.accentCyan
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    'GİZLİ ARŞİV KAYDI · ${typeLabel.toUpperCase()}',
                                    style: AppTextStyles.micro.copyWith(
                                      color: AppColors.accentCyan,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  color: AppColors.textSecondary,
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            // Mystery Lock Emblem
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: <Color>[
                                    AppColors.accentCyan
                                        .withValues(alpha: 0.35),
                                    AppColors.bgSurface.withValues(alpha: 0.5),
                                    Colors.transparent,
                                  ],
                                ),
                                border: Border.all(
                                  color: AppColors.accentCyan
                                      .withValues(alpha: 0.75),
                                  width: 1.5,
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: AppColors.accentCyan
                                        .withValues(alpha: 0.3),
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.lock_clock_rounded,
                                size: 30,
                                color: AppColors.accentCyan,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Henüz Keşfedilmedi',
                              style: AppTextStyles.h2.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Tahmini Seviye: ${rarity.isEmpty ? "Gizemli" : rarity}',
                              style: AppTextStyles.caption.copyWith(
                                color: rarityColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.base),
                            // Discovery Clue Box
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.darkObsidian
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMd,
                                ),
                                border: Border.all(
                                  color: AppColors.borderDefault,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      const Icon(
                                        Icons.explore_rounded,
                                        size: 15,
                                        color: AppColors.liquidGold,
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Text(
                                        'KEŞİF İPUCU & BÖLGE',
                                        style: AppTextStyles.micro.copyWith(
                                          color: AppColors.liquidGold,
                                          letterSpacing: 0.9,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xs + 2),
                                  Text(
                                    entry.showsZonePin
                                        ? '${entry.hintLabel} bölgesinde saklı kadim bir cephanelik sırrı. İlgili bölgedeki zindanları keşfederek veya bossları yenerek bu kaydın kilidini açabilirsin.'
                                        : '${entry.hintLabel} kategorisinde henüz mühürlü bir arşiv. Seviye atladıkça ve yeni bölgelere seyahat ettikçe gün yüzüne çıkacaktır.',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondary,
                                      fontStyle: FontStyle.italic,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            // Confirm Button
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.liquidGold,
                                  foregroundColor: AppColors.carbonVoid,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.md,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMd,
                                    ),
                                  ),
                                ),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.of(context).pop();
                                },
                                child: Text(
                                  'ANLADIM',
                                  style: AppTextStyles.dialogButton,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
