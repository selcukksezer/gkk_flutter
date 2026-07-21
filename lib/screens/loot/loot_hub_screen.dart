import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/inline_error_retry.dart';
import '../../components/common/item_icon_view.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/services/supabase_service.dart';
import '../../l10n/l10n.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import 'loot_box_open_page.dart';
import 'loot_chest_theme.dart';
import 'loot_chest_widgets.dart';
import 'loot_models.dart';

IconData _currencyIcon(String currency) {
  return currency == 'gems' ? Icons.diamond : Icons.paid;
}

Color _currencyColor(String currency) {
  return currency == 'gems' ? const Color(0xFF22D3EE) : const Color(0xFFFBBF24);
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

  String? _openingBoxId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAll();
    });
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

  Future<void> _openBox(LootBoxView box) async {
    if (_openingBoxId != null) return;

    setState(() => _openingBoxId = box.id);
    try {
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
      final String message = data['message']?.toString() ?? '';

      if (!mounted) return;

      if (!success) {
        AppMessenger.showError(
          context,
          message.isEmpty ? 'Kasa açma başarısız.' : message,
        );
      } else {
        if (!_boxDrops.containsKey(box.id)) {
          await _loadBoxDrops(box.id);
        }

        List<LootDropView> drops = _boxDrops[box.id] ?? <LootDropView>[];
        int targetIndex = findLootTargetDropIndex(data, drops);

        if (targetIndex < 0) {
          final LootDropView? payloadDrop = lootDropFromRewardPayload(data);
          if (payloadDrop != null) {
            drops = <LootDropView>[payloadDrop, ...drops];
            targetIndex = 0;
          }
        }

        if (targetIndex < 0) {
          targetIndex = 0;
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
          targetIndex: targetIndex,
          resultPayload: data,
        );

        await Future.wait<void>(<Future<void>>[
          ref.read(playerProvider.notifier).loadProfile(),
          ref.read(inventoryProvider.notifier).loadInventory(silent: true),
        ]);
      }
    } catch (e) {
      if (!mounted) return;
      AppMessenger.showError(
        context,
        userFacingErrorMessage(e, fallback: 'Kasa açılırken hata oluştu.'),
      );
    } finally {
      if (mounted) setState(() => _openingBoxId = null);
    }
  }

  Future<void> _showLootBoxOpenFullscreen({
    required LootBoxView box,
    required LootChestTheme theme,
    required String displayName,
    required List<LootDropView> drops,
    required int targetIndex,
    required Map<String, dynamic> resultPayload,
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
        pageBuilder:
            (
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
              );
            },
        transitionsBuilder:
            (
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

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    ref.read(playerProvider.notifier).clear();
    ref.read(inventoryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

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
            colors: <Color>[Color(0xFF070B14), Color(0xFF030509)],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? InlineErrorRetry(message: _error!, onRetry: _loadAll)
            : _buildBoxesTab(l10n),
      ),
    );
  }

  Widget _buildBoxesTab(AppLocalizations l10n) {
    if (_boxes.isEmpty) {
      return Center(
        child: Text(
          l10n.supabase_tarafinda_aktif_kasa_bulunamadi,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: GameScrollLayout.withClearance(
          context,
          const EdgeInsets.fromLTRB(14, 8, 14, 20),
        ),
        itemCount: _boxes.length,
        itemBuilder: (_, int index) {
          final LootBoxView box = _boxes[index];
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

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
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
                  footer: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(
                        height: 28,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: <Widget>[
                              _compactChip('D:${box.dropCount}'),
                              const SizedBox(width: 6),
                              _compactChip(
                                'N:${lootJackpotPercentLabel(box.jackpotRate)}',
                              ),
                              const SizedBox(width: 6),
                              _compactChip(
                                'x${box.rewardMultiplier.toStringAsFixed(1)}',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: opening ? null : () => _openBox(box),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: opening
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.lock_open, size: 16),
                          label: Text(
                            opening ? l10n.loot_aciliyor : l10n.loot_kasa_ac,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
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

    return Container(
      padding: EdgeInsets.fromLTRB(
        10,
        expanded ? 8 : 4,
        6,
        expanded ? 10 : 4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: theme.borderColor.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: 32,
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.inventory_2_outlined,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.drop_preview,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (expanded && drops.isNotEmpty && !loading)
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () => _loadBoxDrops(box.id),
                    child: Text(l10n.yenile),
                  ),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
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
                  ),
                ),
              ],
            ),
          ),
          if (expanded) ...<Widget>[
            if (loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: LinearProgressIndicator(minHeight: 2),
              )
            else if (drops.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  l10n.loot_drop_list_empty,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: drops.take(12).map((LootDropView d) {
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
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 160,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: rarity.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: rarity.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            SizedBox(
                              width: 26,
                              height: 26,
                              child: ItemIconView(
                                iconValue: d.icon,
                                itemId: d.itemId,
                                size: 24,
                                expand: true,
                                fallback: '◻',
                              ),
                            ),
                            const SizedBox(width: 6),
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
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.liquidGold
                                                .withValues(alpha: 0.22),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                              color: AppColors.liquidGold
                                                  .withValues(alpha: 0.55),
                                            ),
                                          ),
                                          child: const Text(
                                            'CHASE',
                                            style: TextStyle(
                                              color: AppColors.liquidGold,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ),
                                      Expanded(
                                        child: Text(
                                          d.itemName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: d.isFeatured
                                                ? AppColors.liquidGold
                                                : Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '%${d.dropRate.toStringAsFixed(2)}  x${d.minQuantity}-${d.maxQuantity}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
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

  Widget _compactChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
