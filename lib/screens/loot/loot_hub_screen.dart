import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../components/common/inline_error_retry.dart';
import '../../components/common/item_icon_view.dart';
import 'loot_chest_theme.dart';
import 'loot_chest_widgets.dart';
import '../../components/layout/game_chrome.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import '../../l10n/l10n.dart';

class _LootBoxView {
  const _LootBoxView({
    required this.id,
    required this.name,
    required this.description,
    required this.currencyType,
    required this.price,
    required this.dropCount,
    required this.jackpotRate,
    required this.rewardMultiplier,
    required this.artAsset,
  });

  final String id;
  final String name;
  final String description;
  final String currencyType;
  final int price;
  final int dropCount;
  final double jackpotRate;
  final double rewardMultiplier;
  final String artAsset;

  factory _LootBoxView.fromMap(Map<String, dynamic> map) {
    return _LootBoxView(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Kasa',
      description: map['description']?.toString() ?? '',
      currencyType: map['currency_type']?.toString() ?? 'gold',
      price: _toInt(map['price']),
      dropCount: _toInt(map['drop_count']),
      jackpotRate: _toDouble(map['jackpot_rate']),
      rewardMultiplier: _toDouble(map['reward_multiplier'], fallback: 1.0),
      artAsset: map['art_asset']?.toString() ?? '',
    );
  }
}

class _LootDropView {
  const _LootDropView({
    required this.itemId,
    required this.itemName,
    required this.icon,
    required this.rarity,
    required this.dropRate,
    required this.minQuantity,
    required this.maxQuantity,
  });

  final String itemId;
  final String itemName;
  final String icon;
  final String rarity;
  final double dropRate;
  final int minQuantity;
  final int maxQuantity;

  factory _LootDropView.fromMap(Map<String, dynamic> map) {
    return _LootDropView(
      itemId: map['item_id']?.toString() ?? '',
      itemName: map['item_name']?.toString() ?? 'Item',
      icon: map['icon']?.toString() ?? '',
      rarity: map['rarity']?.toString() ?? 'common',
      dropRate: _toDouble(map['drop_rate']),
      minQuantity: _toInt(map['min_quantity'], fallback: 1),
      maxQuantity: _toInt(map['max_quantity'], fallback: 1),
    );
  }
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _toDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

List<Map<String, dynamic>> _rowsFromRpc(dynamic payload) {
  final dynamic rows = payload is Map<String, dynamic>
      ? (payload['data'] ?? const <dynamic>[])
      : payload;

  if (rows is! List) return <Map<String, dynamic>>[];

  return rows
      .whereType<Map>()
      .map((Map row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}

String _compactNum(int value) {
  if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B';
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}

Color _rarityColor(String rarity) {
  switch (rarity.toLowerCase()) {
    case 'uncommon':
      return const Color(0xFF22C55E);
    case 'rare':
      return const Color(0xFF3B82F6);
    case 'epic':
      return const Color(0xFFA855F7);
    case 'legendary':
      return const Color(0xFFF59E0B);
    case 'mythic':
      return const Color(0xFFEF4444);
    default:
      return const Color(0xFF94A3B8);
  }
}

IconData _currencyIcon(String currency) {
  return currency == 'gems' ? Icons.diamond : Icons.paid;
}

Color _currencyColor(String currency) {
  return currency == 'gems' ? const Color(0xFF22D3EE) : const Color(0xFFFBBF24);
}

Widget _lootOpenInfoChip(String label, String value, LootChestTheme theme) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      color: Colors.black.withValues(alpha: 0.28),
      border: Border.all(color: theme.borderColor.withValues(alpha: 0.5)),
    ),
    child: RichText(
      text: TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '$label: ',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: theme.accentColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class LootHubScreen extends ConsumerStatefulWidget {
  const LootHubScreen({super.key});

  @override
  ConsumerState<LootHubScreen> createState() => _LootHubScreenState();
}

class _LootHubScreenState extends ConsumerState<LootHubScreen> {
  bool _loading = true;
  String? _error;

  List<_LootBoxView> _boxes = <_LootBoxView>[];

  final Map<String, List<_LootDropView>> _boxDrops =
      <String, List<_LootDropView>>{};

  final Set<String> _loadingDropIds = <String>{};

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

      final List<_LootBoxView> boxes = _rowsFromRpc(raw)
          .map(_LootBoxView.fromMap)
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

      final List<_LootDropView> rows = _rowsFromRpc(
        raw,
      ).map(_LootDropView.fromMap).toList(growable: false);

      if (!mounted) return;
      setState(() {
        _boxDrops[boxId] = rows;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _boxDrops[boxId] = <_LootDropView>[];
      });
    } finally {
      if (mounted) {
        setState(() => _loadingDropIds.remove(boxId));
      }
    }
  }

  Future<void> _openBox(_LootBoxView box) async {
    if (_openingBoxId != null) return;

    setState(() => _openingBoxId = box.id);
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'open_loot_box',
        params: <String, dynamic>{'p_box_id': box.id},
      );

      final Map<String, dynamic> data = raw is Map
          ? Map<String, dynamic>.from(raw as Map)
          : <String, dynamic>{'success': false, 'message': 'Gecersiz yanit'};

      final bool success = data['success'] == true;
      final String message = data['message']?.toString() ?? '';

      if (!mounted) return;

      if (!success) {
        AppMessenger.showError(context, message.isEmpty ? 'Kasa acma basarisiz.' : message);
      } else {
        if (!_boxDrops.containsKey(box.id)) {
          await _loadBoxDrops(box.id);
        }

        List<_LootDropView> drops = _boxDrops[box.id] ?? <_LootDropView>[];
        int targetIndex = _findTargetBoxDropIndex(data, drops);

        if (targetIndex < 0) {
          final _LootDropView? payloadDrop = _lootDropFromRewardPayload(data);
          if (payloadDrop != null) {
            drops = <_LootDropView>[payloadDrop, ...drops];
            targetIndex = 0;
          }
        }

        if (targetIndex < 0) {
          targetIndex = 0;
        }

        await _showLootBoxOpenFullscreen(
          box: box,
          boxIndex: _boxes.indexOf(box),
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

  int _findTargetBoxDropIndex(
    Map<String, dynamic> payload,
    List<_LootDropView> drops,
  ) {
    if (drops.isEmpty) return -1;

    final Map<String, dynamic> reward = payload['reward'] is Map
        ? Map<String, dynamic>.from(payload['reward'] as Map)
        : <String, dynamic>{};

    final String resultItemId = reward['item_id']?.toString() ?? '';
    final String resultName = (reward['name']?.toString() ?? '').toLowerCase();

    int index = drops.indexWhere(
      (d) => resultItemId.isNotEmpty && d.itemId == resultItemId,
    );
    if (index >= 0) return index;

    index = drops.indexWhere((d) => d.itemName.toLowerCase() == resultName);
    if (index >= 0) return index;

    index = drops.indexWhere(
      (d) =>
          resultName.isNotEmpty &&
          d.itemName.toLowerCase().contains(resultName),
    );
    return index >= 0 ? index : -1;
  }

  _LootDropView? _lootDropFromRewardPayload(Map<String, dynamic> payload) {
    final Map<String, dynamic> reward = payload['reward'] is Map
        ? Map<String, dynamic>.from(payload['reward'] as Map)
        : <String, dynamic>{};

    final String itemId = reward['item_id']?.toString() ?? '';
    if (itemId.isEmpty) return null;

    final int qty = _toInt(
      reward['quantity'],
      fallback: _toInt(reward['amount'], fallback: 1),
    );

    final String fallbackName = reward['name']?.toString() ?? 'Reward';

    return _LootDropView(
      itemId: itemId,
      itemName: fallbackName,
      icon: reward['icon']?.toString() ?? '',
      rarity: reward['rarity']?.toString() ?? 'common',
      dropRate: 0,
      minQuantity: qty,
      maxQuantity: qty,
    );
  }

  Future<void> _showLootBoxOpenFullscreen({
    required _LootBoxView box,
    required int boxIndex,
    required List<_LootDropView> drops,
    required int targetIndex,
    required Map<String, dynamic> resultPayload,
  }) async {
    if (!mounted) return;

    final List<_LootDropView> normalizedDrops = drops.isEmpty
        ? <_LootDropView>[
            const _LootDropView(
              itemId: 'unknown',
              itemName: 'Surpriz Odul',
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
              return _LootBoxOpenFullscreenPage(
                box: box,
                theme: resolveLootChestTheme(
                  boxIndex,
                  artAsset: box.artAsset,
                ),
                displayName: boxIndex < kLootChestThemes.length
                    ? resolveLootChestTheme(boxIndex, artAsset: box.artAsset)
                          .displayName
                    : box.name,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GameTopBar(
        title: context.l10n.kasa_acma,
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
          ref.read(inventoryProvider.notifier).clear();
        },
      ),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(

        currentRoute: AppRoutes.shop,

        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
          ref.read(inventoryProvider.notifier).clear();
        },

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
            : _buildBoxesTab(),
      ),
    );
  }

  Widget _buildBoxesTab() {
    if (_boxes.isEmpty) {
      return const Center(
        child: Text(
          'Supabase tarafinda aktif kasa bulunamadi.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
        itemCount: _boxes.length,
        itemBuilder: (_, int index) {
          final _LootBoxView box = _boxes[index];
          final bool opening = _openingBoxId == box.id;
          final List<_LootDropView> drops =
              _boxDrops[box.id] ?? <_LootDropView>[];
          final LootChestTheme theme = resolveLootChestTheme(
            index,
            artAsset: box.artAsset,
          );
          final String title = index < kLootChestThemes.length
              ? theme.displayName
              : box.name;
          final String subtitle = index < kLootChestThemes.length
              ? (theme.shortDescription.isNotEmpty
                    ? theme.shortDescription
                    : box.description)
              : box.description;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                LootChestBanner(
                  theme: theme,
                  title: title,
                  subtitle: subtitle,
                  priceLabel: _compactNum(box.price),
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
                              _miniInfo('Drop', '${box.dropCount} item'),
                              const SizedBox(width: 6),
                              _miniInfo(
                                'Nadir',
                                '%${box.jackpotRate.toStringAsFixed(2)}',
                              ),
                              const SizedBox(width: 6),
                              _miniInfo(
                                'Carpan',
                                'x${box.rewardMultiplier.toStringAsFixed(2)}',
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
                            opening ? 'Aciliyor...' : 'Kasa Ac',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                      color: theme.borderColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Text(
                            'Drop Preview',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => _loadBoxDrops(box.id),
                            child: Text(
                              _loadingDropIds.contains(box.id)
                                  ? 'Yukleniyor...'
                                  : drops.isEmpty
                                  ? 'Goster'
                                  : 'Yenile',
                            ),
                          ),
                        ],
                      ),
                      if (drops.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: drops.take(12).map((d) {
                            final Color rarity = _rarityColor(d.rarity);
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              d.itemName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
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
                        )
                      else if (_loadingDropIds.contains(box.id))
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(minHeight: 2),
                        )
                      else
                        Text(
                          'Drop listesini görmek için Goster\'a dokun.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _miniInfo(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: RichText(
        text: TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LootBoxOpenFullscreenPage extends StatefulWidget {
  const _LootBoxOpenFullscreenPage({
    required this.box,
    required this.theme,
    required this.displayName,
    required this.drops,
    required this.targetIndex,
    required this.resultPayload,
  });

  final _LootBoxView box;
  final LootChestTheme theme;
  final String displayName;
  final List<_LootDropView> drops;
  final int targetIndex;
  final Map<String, dynamic> resultPayload;

  @override
  State<_LootBoxOpenFullscreenPage> createState() =>
      _LootBoxOpenFullscreenPageState();
}

class _LootBoxOpenFullscreenPageState extends State<_LootBoxOpenFullscreenPage>
    with SingleTickerProviderStateMixin {
  static const double _itemWidth = 138;
  static const double _itemGap = 12;
  static const int _reelSize = 56;
  static const int _targetReelIndex = 42;
  static const int _totalSpinMs = 9000;
  static const int _finalSixItemsMs = 5000;

  late final AnimationController _controller;
  late final List<_LootDropView> _reelItems;
  late final math.Random _rng;

  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _rng = math.Random(DateTime.now().microsecondsSinceEpoch);

    final List<_LootDropView> source = widget.drops;
    final int target = widget.targetIndex.clamp(0, source.length - 1);

    _reelItems = _buildRandomizedReel(source, target);

    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: _totalSpinMs),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _finished = true);
          }
        });

    _controller.forward();
  }

  List<_LootDropView> _buildRandomizedReel(
    List<_LootDropView> source,
    int target,
  ) {
    final List<_LootDropView> reel = List<_LootDropView>.generate(
      _reelSize,
      (_) => source[_rng.nextInt(source.length)],
      growable: false,
    );

    final _LootDropView targetDrop = source[target];
    reel[_targetReelIndex] = targetDrop;

    final List<_LootDropView> premiumEquipmentPool = source
        .where(
          (d) =>
              d.itemId != targetDrop.itemId &&
              _isLegendaryPlus(d) &&
              _isEquipmentDrop(d),
        )
        .toList(growable: false);

    final List<_LootDropView> equipmentFallbackPool = source
        .where((d) => d.itemId != targetDrop.itemId && _isEquipmentDrop(d))
        .toList(growable: false);

    final List<int> neighborPositions = <int>[
      _targetReelIndex - 1,
      _targetReelIndex + 1,
      _targetReelIndex - 2,
      _targetReelIndex + 2,
      _targetReelIndex - 3,
      _targetReelIndex + 3,
    ];

    for (final int pos in neighborPositions) {
      if (pos < 0 || pos >= reel.length) continue;
      if (premiumEquipmentPool.isNotEmpty) {
        reel[pos] =
            premiumEquipmentPool[_rng.nextInt(premiumEquipmentPool.length)];
      } else if (equipmentFallbackPool.isNotEmpty) {
        reel[pos] =
            equipmentFallbackPool[_rng.nextInt(equipmentFallbackPool.length)];
      }
    }

    if (premiumEquipmentPool.length >= 2) {
      reel[_targetReelIndex - 1] =
          premiumEquipmentPool[_rng.nextInt(premiumEquipmentPool.length)];

      _LootDropView right =
          premiumEquipmentPool[_rng.nextInt(premiumEquipmentPool.length)];
      int guard = 0;
      while (right.itemId == reel[_targetReelIndex - 1].itemId && guard < 8) {
        right = premiumEquipmentPool[_rng.nextInt(premiumEquipmentPool.length)];
        guard++;
      }
      reel[_targetReelIndex + 1] = right;
    }

    return reel;
  }

  bool _isLegendaryPlus(_LootDropView drop) {
    final String rarity = drop.rarity.toLowerCase();
    return rarity == 'legendary' || rarity == 'mythic';
  }

  bool _isEquipmentDrop(_LootDropView drop) {
    final String itemId = drop.itemId.toLowerCase();
    if (itemId.startsWith('wpn_') ||
        itemId.startsWith('head_') ||
        itemId.startsWith('chest_') ||
        itemId.startsWith('legs_') ||
        itemId.startsWith('boots_') ||
        itemId.startsWith('gloves_') ||
        itemId.startsWith('ring_') ||
        itemId.startsWith('neck_')) {
      return true;
    }

    final String name = drop.itemName.toLowerCase();
    return name.contains('sword') ||
        name.contains('axe') ||
        name.contains('bow') ||
        name.contains('dagger') ||
        name.contains('staff') ||
        name.contains('spear') ||
        name.contains('mace') ||
        name.contains('hammer') ||
        name.contains('wand') ||
        name.contains('armor') ||
        name.contains('ring') ||
        name.contains('necklace') ||
        name.contains('amulet') ||
        name.contains('pendant') ||
        name.contains('choker') ||
        name.contains('robe') ||
        name.contains('mail') ||
        name.contains('plate') ||
        name.contains('helm') ||
        name.contains('hood') ||
        name.contains('gloves') ||
        name.contains('greaves') ||
        name.contains('tunic') ||
        name.contains('gown') ||
        name.contains('trousers') ||
        name.contains('pants') ||
        name.contains('boots');
  }

  double _spinProgress(double t, double targetOffset, double itemExtent) {
    if (targetOffset <= 0) return 1;

    // 3 phases:
    // 1) accelerate, 2) cruise, 3) decelerate over last 6 items.
    // Final phase is fixed to ~5 seconds.
    final double finalWindow = math.min(targetOffset, itemExtent * 6);
    final double preFinalDistance = math.max(0, targetOffset - finalWindow);
    final double accelDistance = preFinalDistance * 0.18;
    final double cruiseDistance = preFinalDistance - accelDistance;

    final double finalPhasePortion = (_finalSixItemsMs / _totalSpinMs).clamp(
      0.1,
      0.9,
    );
    final double prePhasePortion = 1 - finalPhasePortion;
    final double accelTime = prePhasePortion * 0.35;
    final double cruiseTime = prePhasePortion - accelTime;
    final double decelStart = prePhasePortion;

    double covered;
    if (t <= accelTime) {
      final double p = Curves.easeInCubic.transform(t / accelTime);
      covered = accelDistance * p;
    } else if (t <= decelStart) {
      final double p = (t - accelTime) / cruiseTime;
      covered = accelDistance + (cruiseDistance * p);
    } else {
      final double u = ((t - decelStart) / (1 - decelStart)).clamp(0, 1);

      // Match the decel segment's initial velocity to cruise velocity
      // to avoid the mid-spin "pause" feeling.
      final double cruiseVelocity = cruiseDistance / cruiseTime;
      final double m0Raw = (cruiseVelocity * (1 - decelStart)) / finalWindow;
      final double m0 = m0Raw.clamp(0.2, 2.8);

      // Cubic Hermite: h(0)=0, h(1)=1, h'(0)=m0, h'(1)=0
      final double a = m0 - 2;
      final double b = 3 - (2 * m0);
      final double c = m0;
      final double h = ((a * u * u * u) + (b * u * u) + (c * u)).clamp(0, 1);

      covered = preFinalDistance + (finalWindow * h);
    }

    return (covered / targetOffset).clamp(0, 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> reward = widget.resultPayload['reward'] is Map
        ? Map<String, dynamic>.from(widget.resultPayload['reward'] as Map)
        : <String, dynamic>{};

    final String resultName = reward['name']?.toString() ?? 'Odul';
    final String resultItemId = reward['item_id']?.toString() ?? '';
    final int qty = _toInt(
      reward['quantity'],
      fallback: _toInt(reward['amount'], fallback: 1),
    );

    final LootChestTheme theme = widget.theme;

    return Scaffold(
      backgroundColor: theme.fullscreenBgEnd,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                theme.fullscreenBgStart,
                theme.fullscreenBgEnd,
              ],
            ),
          ),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 10, 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.displayName,
                            style: GoogleFonts.urbanist(
                              textStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _finished
                                ? 'Kasa acildi. Odulun hazir.'
                                : 'Drop bandi donuyor...',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _finished
                          ? () => Navigator.of(context).pop()
                          : null,
                      icon: const Icon(Icons.close),
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 150,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: <Widget>[
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: RadialGradient(
                            center: const Alignment(0.5, 0.2),
                            radius: 1.2,
                            colors: <Color>[
                              theme.radialCenter.withValues(alpha: 0.55),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Image.asset(
                      theme.assetPath,
                      height: 170,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    _lootOpenInfoChip(
                      'Drop',
                      '${widget.box.dropCount} item',
                      theme,
                    ),
                    _lootOpenInfoChip(
                      'Nadir',
                      '%${widget.box.jackpotRate.toStringAsFixed(2)}',
                      theme,
                    ),
                    _lootOpenInfoChip(
                      'Carpan',
                      'x${widget.box.rewardMultiplier.toStringAsFixed(2)}',
                      theme,
                    ),
                    _lootOpenInfoChip(
                      widget.box.currencyType == 'gems' ? 'Elmas' : 'Altin',
                      _compactNum(widget.box.price),
                      theme,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double viewportWidth = constraints.maxWidth - 28;
                    final double itemExtent = _itemWidth + _itemGap;
                    final double stripWidth = _reelItems.length * itemExtent;
                    final double rawTargetOffset =
                        (_targetReelIndex * itemExtent) -
                        ((viewportWidth - _itemWidth) / 2);
                    final double maxOffset = math.max(
                      0,
                      (_reelItems.length * itemExtent) - viewportWidth,
                    );
                    final double targetOffset = rawTargetOffset.clamp(
                      0,
                      maxOffset,
                    );

                    final Widget reelStrip = RepaintBoundary(
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth: stripWidth,
                        maxWidth: stripWidth,
                        child: SizedBox(
                          width: stripWidth,
                          height: 200,
                          child: Row(
                            children: List<Widget>.generate(_reelItems.length, (
                              int index,
                            ) {
                              final bool hit =
                                  index == _targetReelIndex && _finished;
                              return Padding(
                                padding: const EdgeInsets.only(right: _itemGap),
                                child: _LootReelCard(
                                  drop: _reelItems[index],
                                  width: _itemWidth,
                                  highlighted: hit,
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    );

                    return Column(
                      children: <Widget>[
                        const SizedBox(height: 8),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          padding: const EdgeInsets.fromLTRB(10, 18, 10, 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                const Color(0xFF0F1C3E).withValues(alpha: 0.95),
                                const Color(0xFF050B1A).withValues(alpha: 0.98),
                              ],
                            ),
                            border: Border.all(
                              color: theme.accentColor.withValues(alpha: 0.28),
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: theme.accentColor.withValues(alpha: 0.18),
                                blurRadius: 32,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              SizedBox(
                                width: viewportWidth,
                                height: 214,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Stack(
                                    children: <Widget>[
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: <Color>[
                                                Colors.white.withValues(
                                                  alpha: 0.04,
                                                ),
                                                Colors.transparent,
                                                Colors.white.withValues(
                                                  alpha: 0.03,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      AnimatedBuilder(
                                        animation: _controller,
                                        child: reelStrip,
                                        builder:
                                            (
                                              BuildContext context,
                                              Widget? child,
                                            ) {
                                              final double eased =
                                                  _spinProgress(
                                                    _controller.value,
                                                    targetOffset,
                                                    itemExtent,
                                                  );
                                              final double currentOffset =
                                                  targetOffset * eased;
                                              return Transform.translate(
                                                offset: Offset(
                                                  -currentOffset,
                                                  0,
                                                ),
                                                child: child,
                                              );
                                            },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                width: 6,
                                height: 224,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: <Color>[
                                      const Color(0xFFFFD166),
                                      const Color(0xFFFFA726),
                                      const Color(0xFFFFD166),
                                    ],
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: const Color(
                                        0xFFFFB300,
                                      ).withValues(alpha: 0.60),
                                      blurRadius: 18,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 0,
                                child: Icon(
                                  Icons.arrow_drop_down,
                                  color: const Color(0xFFFFD166),
                                  size: 38,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                child: Icon(
                                  Icons.arrow_drop_up,
                                  color: const Color(0xFFFFD166),
                                  size: 38,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white.withValues(alpha: 0.05),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white.withValues(alpha: 0.05),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.16),
                                  ),
                                ),
                                child: ItemIconView(
                                  iconValue: _finished
                                      ? reward['icon']?.toString() ?? ''
                                      : '',
                                  itemId: _finished && resultItemId.isNotEmpty
                                      ? resultItemId
                                      : null,
                                  size: 56,
                                  expand: true,
                                  fallback: '◻',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      _finished
                                          ? 'Kazandin'
                                          : 'Son iteme kilitleniyor',
                                      style: TextStyle(
                                        color: _finished
                                            ? const Color(0xFF22C55E)
                                            : Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _finished ? '$resultName  x$qty' : '???',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _finished
                                  ? () => Navigator.of(context).pop()
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.accentColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                _finished ? 'Odulu Al' : 'Aciliyor...',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

class _LootReelCard extends StatelessWidget {
  const _LootReelCard({
    required this.drop,
    required this.width,
    required this.highlighted,
  });

  final _LootDropView drop;
  final double width;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final Color rarity = _rarityColor(drop.rarity);

    return Container(
      width: width,
      height: 200,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            rarity.withValues(alpha: highlighted ? 0.40 : 0.24),
            const Color(0xFF0B1328),
          ],
        ),
        border: Border.all(
          color: rarity.withValues(alpha: highlighted ? 0.96 : 0.60),
          width: highlighted ? 1.8 : 1.1,
        ),
        boxShadow: highlighted
            ? <BoxShadow>[
                BoxShadow(
                  color: rarity.withValues(alpha: 0.45),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Align(
            alignment: Alignment.topRight,
            child: Text(
              drop.rarity.toUpperCase(),
              style: TextStyle(
                color: rarity.withValues(alpha: 0.92),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Center(
              child: ItemIconView(
                iconValue: drop.icon,
                itemId: drop.itemId,
                size: 74,
                expand: true,
                fallback: '◻',
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            drop.itemName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '%${drop.dropRate.toStringAsFixed(2)}  x${drop.minQuantity}-${drop.maxQuantity}',
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
