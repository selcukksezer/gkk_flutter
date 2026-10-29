import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/app_messenger.dart';
import '../../components/common/inline_error_retry.dart';
import '../../components/common/item_icon_view.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/services/supabase_service.dart';
import '../../l10n/l10n.dart';
import '../../models/player_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import 'loot_box_open_page.dart';
import 'loot_chest_theme.dart';
import 'loot_chest_widgets.dart';
import 'loot_models.dart';

IconData _currencyIcon(String currency) {
  return currency == 'gems' ? Icons.diamond_rounded : Icons.paid_rounded;
}

Color _currencyColor(String currency) {
  return currency == 'gems' ? AppColors.accentCyan : AppColors.gold;
}

class LootHubScreen extends ConsumerStatefulWidget {
  const LootHubScreen({super.key});

  @override
  ConsumerState<LootHubScreen> createState() => _LootHubScreenState();
}

class _LootHubScreenState extends ConsumerState<LootHubScreen> {
  bool _loading = true;
  String? _error;

  List<LootBoxView> _boxes = <LootBoxView>[];

  final Map<String, List<LootDropView>> _boxDrops =
      <String, List<LootDropView>>{};

  final Set<String> _loadingDropIds = <String>{};
  final Set<String> _expandedPreviewIds = <String>{};
  final Map<String, String> _dropPreviewFilter = <String, String>{};

  String? _openingBoxId;
  int _openingBatchProgress = 0;
  int _openingBatchTotal = 1;

  // Daily Free Summon Timers: boxId -> next available time
  final Map<String, DateTime> _nextFreeSummonTimes = <String, DateTime>{};
  Timer? _countdownTimer;

  // Tier Filter State: 0 = All, 1 = Eternal, 2 = Fabled, 3 = Heroic, 4 = Rare, 5 = Common
  int _selectedTierIndex = 0;

  static const List<String> _tierFilterLabels = <String>[
    'Tümü',
    'Ebedi',
    'Efsanevi',
    'Kahramanlık',
    'Nadir',
    'Sıradan',
  ];

  static const List<LootChestTier?> _tierFilterTiers = <LootChestTier?>[
    null,
    LootChestTier.eternal,
    LootChestTier.fabled,
    LootChestTier.heroic,
    LootChestTier.rare,
    LootChestTier.common,
  ];

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAll();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  LootChestTheme _getThemeForBox(LootBoxView box) {
    final int themeIndex = lootThemeIndexForBox(box);
    return resolveLootChestTheme(
      boxId: box.id,
      artAsset: box.artAsset,
      themeIndex: themeIndex,
      themeId: box.themeId,
    );
  }

  List<LootBoxView> get _filteredBoxes {
    if (_selectedTierIndex == 0) return _boxes;
    final LootChestTier? targetTier = _tierFilterTiers[_selectedTierIndex];
    if (targetTier == null) return _boxes;
    return _boxes
        .where((LootBoxView b) => _getThemeForBox(b).tier == targetTier)
        .toList(growable: false);
  }

  int _countForTier(LootChestTier? tier) {
    if (tier == null) return _boxes.length;
    return _boxes.where((LootBoxView b) => _getThemeForBox(b).tier == tier).length;
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'get_loot_boxes_with_stats',
      );

      final List<LootBoxView> boxes = parseLootRpcRows(raw)
          .map(LootBoxView.fromMap)
          .where((b) => b.id.isNotEmpty)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _boxes = boxes;
        _loading = false;
        // Seed free summon: first box is ready immediately if not set
        if (boxes.isNotEmpty && _nextFreeSummonTimes.isEmpty) {
          _nextFreeSummonTimes[boxes.first.id] = DateTime.now();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFacingErrorMessage(e, fallback: 'Kasalar yüklenemedi.');
      });
    }
  }

  Future<void> _loadBoxDrops(String boxId) async {
    if (boxId.isEmpty ||
        _loadingDropIds.contains(boxId) ||
        _boxDrops.containsKey(boxId)) {
      return;
    }

    setState(() => _loadingDropIds.add(boxId));
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'get_loot_box_drops',
        params: <String, dynamic>{'p_box_id': boxId},
      );

      final List<LootDropView> rows = parseLootRpcRows(raw)
          .map(LootDropView.fromMap)
          .toList(growable: true)
        ..sort(compareLootDropsForPreview);

      if (!mounted) return;
      setState(() {
        _boxDrops[boxId] = rows;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _boxDrops[boxId] = <LootDropView>[];
      });
    } finally {
      if (mounted) {
        setState(() => _loadingDropIds.remove(boxId));
      }
    }
  }

  void _toggleDropPreview(String boxId) {
    if (_expandedPreviewIds.contains(boxId)) {
      setState(() => _expandedPreviewIds.remove(boxId));
      return;
    }

    setState(() => _expandedPreviewIds.add(boxId));
    _loadBoxDrops(boxId);
  }

  bool _isFreeSummonAvailable(String boxId) {
    final DateTime? next = _nextFreeSummonTimes[boxId];
    if (next == null) return false;
    return DateTime.now().isAfter(next);
  }

  String _formatCountdown(DateTime target) {
    final Duration diff = target.difference(DateTime.now());
    if (diff.isNegative) return '00:00:00';
    final int hours = diff.inHours;
    final int minutes = diff.inMinutes % 60;
    final int seconds = diff.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _openBox(
    LootBoxView box, {
    bool is10x = false,
    bool isFree = false,
  }) async {
    if (_openingBoxId != null) return;

    final PlayerProfile? player = ref.read(playerProvider).profile;
    final int openCount = is10x ? 10 : 1;
    // 10x provides a 10% discount (pay for 9)
    final int totalCost = isFree
        ? 0
        : (is10x ? (box.price * 9) : box.price);

    if (player != null && !isFree) {
      if (box.currencyType == 'gems' && player.gems < totalCost) {
        AppMessenger.showError(
          context,
          'Yetersiz elmas. Gerekli: $totalCost, Mevcut: ${player.gems}',
        );
        return;
      } else if (box.currencyType == 'gold' && player.gold < totalCost) {
        AppMessenger.showError(
          context,
          'Yetersiz altın. Gerekli: $totalCost, Mevcut: ${player.gold}',
        );
        return;
      }
    }

    setState(() {
      _openingBoxId = box.id;
      _openingBatchProgress = 0;
      _openingBatchTotal = openCount;
    });

    HapticFeedback.mediumImpact();

    try {
      final List<Map<String, dynamic>> collectedRewards =
          <Map<String, dynamic>>[];
      Map<String, dynamic>? lastSuccessfulPayload;

      // Ensure drop metadata is cached for mapping
      if (!_boxDrops.containsKey(box.id)) {
        await _loadBoxDrops(box.id);
      }
      List<LootDropView> drops = _boxDrops[box.id] ?? <LootDropView>[];

      for (int i = 0; i < openCount; i++) {
        final dynamic raw = await SupabaseService.client.rpc(
          'open_loot_box',
          params: <String, dynamic>{'p_box_id': box.id},
        );

        final Map<String, dynamic> data = raw is Map<String, dynamic>
            ? raw
            : raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{'success': false, 'message': 'Geçersiz yanıt'};

        final bool success = data['success'] == true;
        if (!success) {
          final String msg = data['message']?.toString() ?? '';
          if (collectedRewards.isEmpty) {
            if (mounted) {
              AppMessenger.showError(
                context,
                msg.isEmpty ? 'Kasa açma başarısız.' : msg,
              );
            }
            return;
          }
          break;
        }

        lastSuccessfulPayload = data;
        if (data['reward'] is Map) {
          collectedRewards.add(
            Map<String, dynamic>.from(data['reward'] as Map),
          );
        }

        if (mounted) {
          setState(() => _openingBatchProgress = i + 1);
        }
      }

      if (!mounted || collectedRewards.isEmpty || lastSuccessfulPayload == null) {
        return;
      }

      // If free summon used, schedule next for 24 hours later
      if (isFree) {
        _nextFreeSummonTimes[box.id] =
            DateTime.now().add(const Duration(hours: 24));
      }

      // Determine best chase reward for the reel highlight
      int bestDropIndex = -1;
      int highestRarityScore = -1;

      for (int i = 0; i < collectedRewards.length; i++) {
        final Map<String, dynamic> r = collectedRewards[i];
        final String rarity =
            (r['rarity']?.toString() ?? 'common').toLowerCase();
        int score = 0;
        if (rarity == 'mythic') {
          score = 5;
        } else if (rarity == 'legendary') {
          score = 4;
        } else if (rarity == 'epic') {
          score = 3;
        } else if (rarity == 'rare') {
          score = 2;
        } else if (rarity == 'uncommon') {
          score = 1;
        }

        if (score > highestRarityScore) {
          highestRarityScore = score;
          final int idx = drops.indexWhere((d) => d.itemId == r['item_id']);
          if (idx >= 0) bestDropIndex = idx;
        }
      }

      if (bestDropIndex < 0) {
        bestDropIndex = findLootTargetDropIndex(lastSuccessfulPayload, drops);
      }

      if (bestDropIndex < 0) {
        final LootDropView? payloadDrop =
            lootDropFromRewardPayload(lastSuccessfulPayload);
        if (payloadDrop != null) {
          drops = <LootDropView>[payloadDrop, ...drops];
          bestDropIndex = 0;
        } else {
          bestDropIndex = 0;
        }
      }

      final int themeIndex = lootThemeIndexForBox(box);
      final LootChestTheme theme = resolveLootChestTheme(
        boxId: box.id,
        artAsset: box.artAsset,
        themeIndex: themeIndex,
        themeId: box.themeId,
      );

      await _showLootBoxOpenFullscreen(
        box: box,
        theme: theme,
        displayName: lootBoxDisplayName(
          box: box,
          theme: theme,
          themeIndex: themeIndex,
        ),
        drops: drops,
        targetIndex: bestDropIndex,
        resultPayload: lastSuccessfulPayload,
        multiRewards: collectedRewards.length > 1 ? collectedRewards : null,
      );

      await Future.wait<void>(<Future<void>>[
        ref.read(playerProvider.notifier).loadProfile(),
        ref.read(inventoryProvider.notifier).loadInventory(silent: true),
      ]);
    } catch (e) {
      if (!mounted) return;
      AppMessenger.showError(
        context,
        userFacingErrorMessage(e, fallback: 'Kasa açılırken hata oluştu.'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingBoxId = null;
          _openingBatchProgress = 0;
        });
      }
    }
  }

  Future<void> _showLootBoxOpenFullscreen({
    required LootBoxView box,
    required LootChestTheme theme,
    required String displayName,
    required List<LootDropView> drops,
    required int targetIndex,
    required Map<String, dynamic> resultPayload,
    List<Map<String, dynamic>>? multiRewards,
  }) async {
    if (!mounted) return;

    final List<LootDropView> normalizedDrops = drops.isEmpty
        ? <LootDropView>[
            const LootDropView(
              itemId: 'unknown',
              itemName: 'Sürpriz Ödül',
              icon: '',
              rarity: 'common',
              dropRate: 100,
              minQuantity: 1,
              maxQuantity: 1,
            ),
          ]
        : drops;

    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        pageBuilder: (
          BuildContext context,
          Animation<double> primaryAnimation,
          Animation<double> secondaryAnimation,
        ) {
          return LootBoxOpenPage(
            box: box,
            theme: theme,
            displayName: displayName,
            drops: normalizedDrops,
            targetIndex: targetIndex.clamp(0, normalizedDrops.length - 1),
            resultPayload: resultPayload,
            multiRewards: multiRewards,
          );
        },
        transitionsBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Map<String, double> _calculateRarityDistribution(List<LootDropView> drops) {
    final Map<String, double> totals = <String, double>{
      'mythic': 0.0,
      'legendary': 0.0,
      'epic': 0.0,
      'rare': 0.0,
      'uncommon': 0.0,
      'common': 0.0,
    };
    for (final LootDropView drop in drops) {
      final String r = drop.rarity.toLowerCase();
      if (totals.containsKey(r)) {
        totals[r] = (totals[r] ?? 0.0) + drop.dropRate;
      } else {
        totals['common'] = (totals['common'] ?? 0.0) + drop.dropRate;
      }
    }
    return totals;
  }

  void _showDropRatesModal(
    BuildContext context,
    LootBoxView box,
    List<LootDropView> drops,
    LootChestTheme theme,
  ) {
    HapticFeedback.selectionClick();
    final Map<String, double> rarityDist = _calculateRarityDistribution(drops);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      elevation: 24,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (BuildContext ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXl),
            ),
            border: Border.all(
              color: AppColors.borderBright.withValues(alpha: 0.6),
              width: 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.bgDeep,
                blurRadius: 32,
                spreadRadius: 8,
                offset: const Offset(0, -6),
              ),
              BoxShadow(
                color: theme.glowColor.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Drag Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(
                      top: AppSpacing.md,
                      bottom: AppSpacing.sm,
                    ),
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          theme.accentColor,
                          AppColors.goldLight,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: theme.accentColor.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),

                // Modal Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xs,
                    AppSpacing.base,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.accentColor.withValues(alpha: 0.15),
                          border: Border.all(
                            color: theme.accentColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Icon(
                          Icons.query_stats_rounded,
                          color: theme.accentColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Düşme Oranları & Şeffaflık',
                              style: AppTextStyles.h3.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              box.name,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),

                // Rarity Probability Breakdown Pills
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base,
                    vertical: AppSpacing.xs,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        _rarityProbPill('Ebedi', rarityDist['mythic'] ?? 0.0, AppColors.rarityMythic),
                        _rarityProbPill('Efsanevi', rarityDist['legendary'] ?? 0.0, AppColors.rarityLegendary),
                        _rarityProbPill('Epik', rarityDist['epic'] ?? 0.0, AppColors.rarityEpic),
                        _rarityProbPill('Nadir', rarityDist['rare'] ?? 0.0, AppColors.rarityRare),
                        _rarityProbPill('Sıradan', (rarityDist['uncommon'] ?? 0.0) + (rarityDist['common'] ?? 0.0), AppColors.rarityCommon),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                // Pity System Rule Banner
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      color: AppColors.liquidGold.withValues(alpha: 0.10),
                      border: Border.all(
                        color: AppColors.liquidGold.withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(
                          Icons.military_tech_rounded,
                          color: AppColors.liquidGold,
                          size: 26,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'GARANTİ ŞANS (PITY) VE ADALET PROTOKOLÜ',
                                style: AppTextStyles.label.copyWith(
                                  color: AppColors.liquidGold,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '• Her 10 çekilişte en az 1 adet Epik veya üstü eşya garantilidir.\n• 50 çekilişte Efsanevi çıkmazsa sonraki çekiliş %100 Efsanevidir.\n• Bütün olasılıklar bağımsız sunucu RNG algoritması tarafından denetlenir.',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1, color: AppColors.borderFaint),

                // Rarity Breakdown Table
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.base,
                      AppSpacing.sm,
                      AppSpacing.base,
                      AppSpacing.lg,
                    ),
                    children: drops.isEmpty
                        ? <Widget>[
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.xxl),
                              child: Center(
                                child: Text(
                                  'Bu kasa için detaylı eşya listesi yükleniyor...',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ),
                            ),
                          ]
                        : drops.map((LootDropView d) {
                            final Color rarityColor = AppColors.forRarity(d.rarity);
                            return Container(
                              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.bgCard.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                border: Border.all(
                                  color: rarityColor.withValues(alpha: 0.28),
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  ItemIconView(
                                    iconValue: d.icon,
                                    itemId: d.itemId,
                                    size: 28,
                                    expand: false,
                                    fallback: '◻',
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Row(
                                          children: <Widget>[
                                            if (d.isFeatured)
                                              Container(
                                                margin: const EdgeInsets.only(right: 6),
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 5,
                                                  vertical: 1.5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.liquidGold.withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: AppColors.liquidGold.withValues(alpha: 0.6),
                                                  ),
                                                ),
                                                child: Text(
                                                  'CHASE',
                                                  style: AppTextStyles.micro.copyWith(
                                                    color: AppColors.liquidGold,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            Expanded(
                                              child: Text(
                                                d.itemName,
                                                style: AppTextStyles.captionBold.copyWith(
                                                  color: rarityColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '${d.rarity.toUpperCase()} · Miktar: x${d.minQuantity}-${d.maxQuantity}',
                                          style: AppTextStyles.micro.copyWith(
                                            color: AppColors.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.bgDeep.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppColors.borderDefault,
                                      ),
                                    ),
                                    child: Text(
                                      '%${d.dropRate.toStringAsFixed(2)}',
                                      style: AppTextStyles.captionBold.copyWith(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _rarityProbPill(String label, double prob, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$label: %${prob.toStringAsFixed(1)}',
            style: AppTextStyles.micro.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    ref.read(playerProvider.notifier).clear();
    ref.read(inventoryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PlayerProfile? player = ref.watch(playerProvider).profile;

    return Scaffold(
      appBar: GameTopBar(
        title: l10n.kasa_acma,
        onLogout: _logout,
      ),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.loot,
        onLogout: _logout,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              AppColors.bgDeep,
              AppColors.carbonVoid,
            ],
          ),
        ),
        child: Column(
          children: <Widget>[
            // Glowing Luxury Header Section
            _buildGlowingHeader(),

            // Live Currency Quick Deck (Gold & Gems HUD)
            if (player != null) _buildCurrencyDeck(player),

            // Tier Category Carousels & Filter Tabs
            _buildTierSelector(),

            // Main Boxes Content
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    )
                  : _error != null
                  ? InlineErrorRetry(message: _error!, onRetry: _loadAll)
                  : _buildBoxesTab(l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlowingHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.xs,
        AppSpacing.base,
        AppSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.bgCardElevated.withValues(alpha: 0.95),
            AppColors.bgSurface.withValues(alpha: 0.90),
          ],
        ),
        border: Border.all(
          color: AppColors.borderBright.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.accentBlueGlow,
            blurRadius: 18,
            spreadRadius: -4,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              gradient: const RadialGradient(
                colors: <Color>[
                  Color(0xFF3B2A10),
                  Color(0xFF141926),
                ],
                radius: 0.9,
              ),
              border: Border.all(
                color: AppColors.liquidGold.withValues(alpha: 0.7),
                width: 1.4,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.liquidGold.withValues(alpha: 0.35),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.auto_awesome,
                color: AppColors.goldLight,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'KADİM GANİMET SALONU',
                      style: AppTextStyles.titleBold.copyWith(
                        color: AppColors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        'PITY AKTİF',
                        style: AppTextStyles.micro.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '10x Çekilişlerde %10 indirim ve garantili Epik+ ekipman şansı.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyDeck(PlayerProfile player) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm,
      ),
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.xs,
        AppSpacing.base,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        color: AppColors.bgSurface.withValues(alpha: 0.8),
        border: Border.all(
          color: AppColors.borderDefault.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.account_balance_wallet_rounded,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Bakiye:',
            style: AppTextStyles.label.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          // Gold Pill
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.bgDeep.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.paid_rounded,
                  size: 14,
                  color: AppColors.gold,
                ),
                const SizedBox(width: 4),
                Text(
                  lootCompactNum(player.gold),
                  style: AppTextStyles.captionBold.copyWith(
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Gems Pill
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.bgDeep.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(
                color: AppColors.accentCyan.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.diamond_rounded,
                  size: 14,
                  color: AppColors.accentCyan,
                ),
                const SizedBox(width: 4),
                Text(
                  lootCompactNum(player.gems.toInt()),
                  style: AppTextStyles.captionBold.copyWith(
                    color: AppColors.accentCyan,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierSelector() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        itemCount: _tierFilterLabels.length,
        itemBuilder: (BuildContext context, int index) {
          final bool isSelected = _selectedTierIndex == index;
          final LootChestTier? tier = _tierFilterTiers[index];
          final int count = _countForTier(tier);
          final Color accent = tier?.accentColor ?? AppColors.gold;

          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTierIndex = index);
              },
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accent.withValues(alpha: 0.18)
                      : AppColors.bgSurface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                    color: isSelected
                        ? accent
                        : AppColors.borderDefault.withValues(alpha: 0.5),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? <BoxShadow>[
                          BoxShadow(
                            color: accent.withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      _tierFilterLabels[index],
                      style: AppTextStyles.captionBold.copyWith(
                        color: isSelected ? accent : AppColors.textSecondary,
                      ),
                    ),
                    if (count > 0) ...<Widget>[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accent.withValues(alpha: 0.35)
                              : AppColors.bgCardElevated,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '$count',
                          style: AppTextStyles.micro.copyWith(
                            color: isSelected ? Colors.white : AppColors.textTertiary,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBoxesTab(AppLocalizations l10n) {
    final List<LootBoxView> displayedBoxes = _filteredBoxes;

    if (displayedBoxes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _selectedTierIndex == 0
                    ? l10n.supabase_tarafinda_aktif_kasa_bulunamadi
                    : 'Bu kademede henüz aktif kasa bulunmamaktadır.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.bgSurface,
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: GameScrollLayout.withClearance(
          context,
          const EdgeInsets.fromLTRB(
            AppSpacing.base,
            AppSpacing.xs,
            AppSpacing.base,
            AppSpacing.xl,
          ),
        ),
        itemCount: displayedBoxes.length,
        itemBuilder: (_, int index) {
          final LootBoxView box = displayedBoxes[index];
          final bool opening = _openingBoxId == box.id;
          final List<LootDropView> drops =
              _boxDrops[box.id] ?? <LootDropView>[];
          final int themeIndex = lootThemeIndexForBox(box);
          final LootChestTheme theme = resolveLootChestTheme(
            boxId: box.id,
            artAsset: box.artAsset,
            themeIndex: themeIndex,
            themeId: box.themeId,
          );
          final String title = lootBoxDisplayName(
            box: box,
            theme: theme,
            themeIndex: themeIndex,
          );
          final String subtitle = lootBoxSubtitle(
            box: box,
            theme: theme,
            themeIndex: themeIndex,
          );

          final bool freeAvailable = _isFreeSummonAvailable(box.id);
          final DateTime? nextFree = _nextFreeSummonTimes[box.id];
          final int multiPrice = (box.price * 9); // 10% discount for 10x

          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                LootChestBanner(
                  theme: theme,
                  title: title,
                  subtitle: subtitle,
                  priceLabel: lootCompactNum(box.price),
                  priceIcon: _currencyIcon(box.currencyType),
                  priceColor: _currencyColor(box.currencyType),
                  height: 285,
                  footer: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Tier / Jackpot Chips & Transparency Trigger
                      Row(
                        children: <Widget>[
                          _compactChip('D:${box.dropCount}'),
                          const SizedBox(width: AppSpacing.xs),
                          _compactChip(
                            'N:${lootJackpotPercentLabel(box.jackpotRate)}',
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _compactChip(
                            'x${box.rewardMultiplier.toStringAsFixed(1)}',
                          ),
                          const Spacer(),
                          // Transparency modal trigger
                          InkWell(
                            onTap: () {
                              if (!_boxDrops.containsKey(box.id)) {
                                _loadBoxDrops(box.id);
                              }
                              _showDropRatesModal(
                                context,
                                box,
                                _boxDrops[box.id] ?? <LootDropView>[],
                                theme,
                              );
                            },
                            borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.bgSurface.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                                border: Border.all(
                                  color: AppColors.borderBright.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.query_stats_rounded,
                                    size: 12,
                                    color: AppColors.goldLight,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Oranlar & Şeffaflık',
                                    style: AppTextStyles.micro.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Daily Free Summon Status
                      if (nextFree != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: freeAvailable
                                ? AppColors.success.withValues(alpha: 0.20)
                                : AppColors.bgDeep.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                            border: Border.all(
                              color: freeAvailable
                                  ? AppColors.success
                                  : AppColors.borderDefault,
                              width: 1.1,
                            ),
                            boxShadow: freeAvailable
                                ? const <BoxShadow>[
                                    BoxShadow(
                                      color: AppColors.successGlow,
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                freeAvailable
                                    ? Icons.stars_rounded
                                    : Icons.timer_outlined,
                                size: 13,
                                color: freeAvailable
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                freeAvailable
                                    ? 'GÜNLÜK ÜCRETSİZ ÇEKİLİŞ HAZIR!'
                                    : 'Sonraki Ücretsiz: ${_formatCountdown(nextFree)}',
                                style: AppTextStyles.micro.copyWith(
                                  color: freeAvailable
                                      ? AppColors.success
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Dual Gacha Action Buttons: 1x & 10x
                      Row(
                        children: <Widget>[
                          // 1x Open Button (or Free Summon)
                          Expanded(
                            child: FilledButton(
                              onPressed: opening
                                  ? null
                                  : () => _openBox(
                                        box,
                                        isFree: freeAvailable,
                                      ),
                              style: FilledButton.styleFrom(
                                backgroundColor: freeAvailable
                                    ? AppColors.success
                                    : theme.accentColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                minimumSize: const Size(0, 42),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                ),
                              ),
                              child: opening && _openingBatchTotal == 1
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: <Widget>[
                                        Icon(
                                          freeAvailable
                                              ? Icons.card_giftcard_rounded
                                              : _currencyIcon(box.currencyType),
                                          size: 15,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          freeAvailable
                                              ? 'ÜCRETSİZ 1x'
                                              : '1x Kasa Aç (${lootCompactNum(box.price)})',
                                          style: AppTextStyles.captionBold.copyWith(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),

                          // 10x Open Button
                          Expanded(
                            child: OutlinedButton(
                              onPressed: opening
                                  ? null
                                  : () => _openBox(box, is10x: true),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: theme.accentColor,
                                  width: 1.5,
                                ),
                                backgroundColor: theme.accentColor.withValues(alpha: 0.16),
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                minimumSize: const Size(0, 42),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                ),
                              ),
                              child: opening && _openingBatchTotal == 10
                                  ? Text(
                                      'Açılıyor ($_openingBatchProgress/10)',
                                      style: AppTextStyles.captionBold.copyWith(
                                        color: Colors.white,
                                      ),
                                    )
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Text(
                                          '10x KASA AÇ',
                                          style: AppTextStyles.captionBold.copyWith(
                                            letterSpacing: 0.4,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          '${lootCompactNum(multiPrice)} (%10 İndirim)',
                                          style: AppTextStyles.micro.copyWith(
                                            color: _currencyColor(box.currencyType),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildDropPreviewPanel(
                  l10n: l10n,
                  box: box,
                  theme: theme,
                  drops: drops,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDropPreviewPanel({
    required AppLocalizations l10n,
    required LootBoxView box,
    required LootChestTheme theme,
    required List<LootDropView> drops,
  }) {
    final bool expanded = _expandedPreviewIds.contains(box.id);
    final bool loading = _loadingDropIds.contains(box.id);
    final String currentFilter = _dropPreviewFilter[box.id] ?? 'all';

    List<LootDropView> filteredDrops = drops;
    if (currentFilter == 'chase') {
      filteredDrops = drops.where((d) => d.isFeatured).toList();
    } else if (currentFilter == 'epic') {
      filteredDrops = drops
          .where((d) =>
              d.rarity.toLowerCase() == 'epic' ||
              d.rarity.toLowerCase() == 'legendary' ||
              d.rarity.toLowerCase() == 'mythic')
          .toList();
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        expanded ? AppSpacing.sm : AppSpacing.xs,
        AppSpacing.sm,
        expanded ? AppSpacing.md : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        color: AppColors.bgSurface.withValues(alpha: 0.7),
        border: Border.all(
          color: theme.borderColor.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: 34,
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.inventory_2_outlined,
                  size: 15,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${l10n.drop_preview} (${drops.length})',
                  style: AppTextStyles.captionBold.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (expanded && drops.isNotEmpty && !loading)
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    ),
                    onPressed: () => _loadBoxDrops(box.id),
                    child: Text(
                      l10n.yenile,
                      style: AppTextStyles.captionBold.copyWith(
                        color: theme.accentColor,
                      ),
                    ),
                  ),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  ),
                  onPressed: loading && !expanded
                      ? null
                      : () => _toggleDropPreview(box.id),
                  child: Text(
                    loading
                        ? l10n.loot_yukleniyor
                        : expanded
                        ? l10n.loot_gizle
                        : l10n.loot_goster,
                    style: AppTextStyles.captionBold.copyWith(
                      color: AppColors.goldLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (expanded) ...<Widget>[
            // Sub-filters inside expanded drop view
            if (drops.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: <Widget>[
                    _previewFilterChip(
                      boxId: box.id,
                      filterKey: 'all',
                      label: 'Tümü (${drops.length})',
                      active: currentFilter == 'all',
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _previewFilterChip(
                      boxId: box.id,
                      filterKey: 'chase',
                      label: 'Chase (${drops.where((d) => d.isFeatured).length})',
                      active: currentFilter == 'chase',
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _previewFilterChip(
                      boxId: box.id,
                      filterKey: 'epic',
                      label: 'Epik+ (${drops.where((d) => d.rarity == 'epic' || d.rarity == 'legendary' || d.rarity == 'mythic').length})',
                      active: currentFilter == 'epic',
                    ),
                  ],
                ),
              ),

            if (loading)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.xs),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.gold,
                ),
              )
            else if (filteredDrops.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  'Bu filtreye uygun eşya bulunmuyor.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              )
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: filteredDrops.take(16).map((LootDropView d) {
                  final Color rarity = AppColors.forRarity(d.rarity);
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => LootDropPreviewDialog.show(
                        context,
                        LootDropPreviewData(
                          itemId: d.itemId,
                          itemName: d.itemName,
                          icon: d.icon,
                          rarity: d.rarity,
                          dropRate: d.dropRate,
                          minQuantity: d.minQuantity,
                          maxQuantity: d.maxQuantity,
                          rarityColor: rarity,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      child: Container(
                        width: 165,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.bgDeep.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          border: Border.all(
                            color: rarity.withValues(alpha: 0.45),
                            width: 1.1,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: rarity.withValues(alpha: 0.15),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Row(
                          children: <Widget>[
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: ItemIconView(
                                iconValue: d.icon,
                                itemId: d.itemId,
                                size: 26,
                                expand: true,
                                fallback: '◻',
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      if (d.isFeatured)
                                        Container(
                                          margin: const EdgeInsets.only(right: 4),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 3,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.liquidGold
                                                .withValues(alpha: 0.25),
                                            borderRadius:
                                                BorderRadius.circular(3),
                                            border: Border.all(
                                              color: AppColors.liquidGold
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                          child: Text(
                                            'CHASE',
                                            style: AppTextStyles.micro.copyWith(
                                              color: AppColors.liquidGold,
                                              fontSize: 7.5,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      Expanded(
                                        child: Text(
                                          d.itemName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.captionBold.copyWith(
                                            color: d.isFeatured
                                                ? AppColors.liquidGold
                                                : rarity,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '%${d.dropRate.toStringAsFixed(2)} · x${d.minQuantity}-${d.maxQuantity}',
                                    style: AppTextStyles.micro.copyWith(
                                      color: AppColors.textSecondary,
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
                }).toList(growable: false),
              ),
          ],
        ],
      ),
    );
  }

  Widget _previewFilterChip({
    required String boxId,
    required String filterKey,
    required String label,
    required bool active,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _dropPreviewFilter[boxId] = filterKey);
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: active
              ? AppColors.gold.withValues(alpha: 0.2)
              : AppColors.bgDeep.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: active
                ? AppColors.gold
                : AppColors.borderDefault.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.micro.copyWith(
            color: active ? AppColors.gold : AppColors.textSecondary,
            fontSize: 9.5,
          ),
        ),
      ),
    );
  }

  Widget _compactChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
        color: AppColors.bgDeep.withValues(alpha: 0.6),
        border: Border.all(
          color: AppColors.borderDefault.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        text,
        style: AppTextStyles.micro.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
