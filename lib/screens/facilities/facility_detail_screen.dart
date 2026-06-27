import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../theme/app_colors.dart';
import '../../models/facility_model.dart';
import '../../providers/facilities_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import 'widgets/facilities_ui.dart';
import 'widgets/facility_detail_design.dart';
import 'widgets/facilities_dialogs.dart';
import '../../utils/logout_helper.dart';

class FacilityDetailScreen extends ConsumerStatefulWidget {
  const FacilityDetailScreen({
    super.key,
    required this.type,
  });

  final String type;

  @override
  ConsumerState<FacilityDetailScreen> createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends ConsumerState<FacilityDetailScreen> {
  static const int _productionDurationSeconds = 120;

  String _activeTab = 'overview';
  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  Timer? _productionPollTimer;
  String? _productionPollKey;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(facilitiesProvider.notifier).loadFacilities();
      ref.read(playerProvider.notifier).loadProfile();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _productionPollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final facilitiesState = ref.watch(facilitiesProvider);
    final playerState = ref.watch(playerProvider);
    final profile = playerState.profile;
    final bool isBusy = facilitiesState.isMutating;

    final bool inPrison = _isFuture(profile?.prisonUntil);
    final int energy = profile?.energy ?? 0;
    final int gold = profile?.gold ?? 0;

    PlayerFacility? facility;
    for (final row in facilitiesState.facilities) {
      if (row.facilityType == widget.type) {
        facility = row;
        break;
      }
    }

    final _FacilityMeta? meta = _facilityMeta[widget.type];

    final String? productionStartedAt = facility?.productionStartedAt;
    final DateTime? startedAt = productionStartedAt == null || productionStartedAt.isEmpty
        ? null
        : DateTime.tryParse(productionStartedAt);
    final DateTime? targetAt = startedAt?.add(const Duration(seconds: _productionDurationSeconds));
    final bool productionRunning = targetAt != null && _now.isBefore(targetAt);
    final bool productionReady = targetAt != null && !productionRunning;
    final bool hasProductionRecord = productionStartedAt != null && productionStartedAt.isNotEmpty;

    _syncProductionPolling(productionStartedAt, productionRunning);

    final int level = facility?.level ?? 1;

    final _LiveProductionSnapshot liveSnapshot = _buildLiveProductionSnapshot(
      facilityType: widget.type,
      level: level,
      productionStartedAt: productionStartedAt,
      now: _now,
    );

    final bool useLivePreview = hasProductionRecord;
    final int liveCount = useLivePreview
        ? liveSnapshot.totalProduced
        : _sumQueueQuantity(facility?.facilityQueue ?? const <FacilityQueueItem>[]);
    final int collectRequestCount = useLivePreview ? liveSnapshot.baseProduced : liveCount;

    final int upgradeCost = _getUpgradeCost(widget.type, level);
    final bool canUpgrade = !hasProductionRecord && (facility?.level ?? 1) < 10 && gold >= upgradeCost;

    Future<void> logout() async {
      await performLogout(ref);
}

    return GameSubScreenScaffold(
      title: meta?.name ?? widget.type,
      onLogout: logout,
      fallbackRoute: AppRoutes.facilities,
      bottomNavRoute: AppRoutes.facilities,
      body: facilitiesScreenShell(
        child: ListView(
          padding: FacilitiesUi.scrollPadding(context),
          children: <Widget>[
            if (facilitiesState.status == FacilitiesStatus.loading && facility == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: AppColors.liquidGold, strokeWidth: 2),
                ),
              )
            else if (facility == null)
              FacEmptyState(
                icon: meta?.icon ?? '🏭',
                title: meta?.name ?? 'Tesis bulunamadı',
                subtitle: meta == null
                    ? '"${widget.type}" tanınmıyor.'
                    : 'Henüz açılmamış — listeden kilidi aç.',
              )
            else ...<Widget>[
              FacDetailHero(
                icon: meta?.icon ?? '🏭',
                name: meta?.name ?? widget.type,
                description: meta?.description ?? '',
                level: facility.level,
                isProducing: hasProductionRecord,
              ),
              facilitiesSegmentTabs(
                activeId: _activeTab,
                onChanged: (String tab) => setState(() => _activeTab = tab),
                tabs: const <FacilitiesTabOption>[
                  (id: 'overview', label: 'Genel'),
                  (id: 'queue', label: 'Depo'),
                ],
              ),
              if (_activeTab == 'overview')
                ..._buildOverviewTab(
                  meta: meta,
                  facility: facility,
                  inPrison: inPrison,
                  energy: energy,
                  upgradeCost: upgradeCost,
                  canUpgrade: canUpgrade,
                  hasProductionRecord: hasProductionRecord,
                  productionRunning: productionRunning,
                  targetAt: targetAt,
                  liveSnapshot: liveSnapshot,
                  isBusy: isBusy,
                )
              else
                ..._buildQueueTab(
                  facility: facility,
                  inPrison: inPrison,
                  energy: energy,
                  productionRunning: productionRunning,
                  productionReady: productionReady,
                  targetAt: targetAt,
                  liveCount: liveCount,
                  collectRequestCount: collectRequestCount,
                  useLivePreview: useLivePreview,
                  liveSnapshot: liveSnapshot,
                  productionStartedAt: productionStartedAt,
                  isBusy: isBusy,
                ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOverviewTab({
    required _FacilityMeta? meta,
    required PlayerFacility facility,
    required bool inPrison,
    required int energy,
    required int upgradeCost,
    required bool canUpgrade,
    required bool hasProductionRecord,
    required bool productionRunning,
    required DateTime? targetAt,
    required _LiveProductionSnapshot liveSnapshot,
    required bool isBusy,
  }) {
    final List<String> previewLabels = liveSnapshot.items
        .map((item) => '${_resourceNameByRarity(widget.type, item.rarity)} ×${item.quantity}')
        .toList();

    return <Widget>[
      FacProductionBanner(
        isRunning: productionRunning,
        remainingLabel: _formatRemaining(targetAt),
        previewItems: previewLabels,
        startEnabled: !inPrison && energy >= 50 && !isBusy,
        startLabel: energy < 50 ? '50⚡ gerekli' : '⚡ Üretimi Başlat',
        onStart: () async {
          final bool ok = await ref.read(facilitiesProvider.notifier).startProduction(
                facilityId: facility.id,
              );
          if (!mounted) return;
          AppMessenger.show(
            context,
            ok ? 'Üretim başlatıldı!' : (ref.read(facilitiesProvider).errorMessage ?? 'Üretim başlatılamadı'),
          );
          if (ok) {
            ref.read(playerProvider.notifier).loadProfile();
          }
        },
      ),
      const SizedBox(height: FacilitiesUi.gap),
      DottedPanel(
        padding: FacilitiesUi.panelPadding,
        borderRadius: 12,
        borderColor: AppColors.liquidGold.withValues(alpha: 0.2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            facilitiesSectionTitle('Kaynak Havuzu', trailing: 'Lv.${facility.level}'),
            const SizedBox(height: FacilitiesUi.gapSm),
            GameFixedGrid(
              crossAxisCount: 3,
              spacing: 4,
              itemCount: meta?.resources.length ?? 0,
              itemBuilder: (BuildContext context, int index) {
                final String name = meta!.resources[index];
                final String rarity = index < _resourceRarities.length ? _resourceRarities[index] : 'common';
                final Map<String, int> weights = _getRarityWeightsAtLevel(facility.level);
                final int total = weights.values.fold<int>(0, (int sum, int v) => sum + v);
                final int unlockLevel = _rarityUnlockLevels[rarity] ?? 1;
                final bool isUnlocked = facility.level >= unlockLevel;
                final double percent = total > 0 ? ((weights[rarity] ?? 0) / total) * 100 : 0;

                return FacResourceCell(
                  emoji: _rarityEmoji(rarity),
                  name: name,
                  percentLabel: isUnlocked ? '${percent.toStringAsFixed(0)}%' : '🔒 Lv.$unlockLevel',
                  accentColor: facRarityAccent(rarity),
                  locked: !isUnlocked,
                );
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: FacilitiesUi.gap),
      _RaritySimulatorAccordion(currentLevel: facility.level),
      const SizedBox(height: FacilitiesUi.gap),
      FacUpgradeStrip(
        summary: facility.level >= 10
            ? 'Maksimum seviye'
            : 'Lv.${facility.level + 1} • ${_formatGold(upgradeCost)} altın',
        buttonLabel: 'Yükselt',
        enabled: canUpgrade && !inPrison && !isBusy,
        onUpgrade: () => _showUpgradeDialog(
          facility.id,
          meta?.name ?? widget.type,
          facility.level,
          upgradeCost,
        ),
      ),
      if (hasProductionRecord)
        const Padding(
          padding: EdgeInsets.only(top: FacilitiesUi.gapSm),
          child: Text(
            'Yükseltme için önce üretimi bitirin.',
            style: TextStyle(fontSize: 9, color: AppColors.warningSolar),
          ),
        ),
    ];
  }

  List<Widget> _buildQueueTab({
    required PlayerFacility facility,
    required bool inPrison,
    required int energy,
    required bool productionRunning,
    required bool productionReady,
    required DateTime? targetAt,
    required int liveCount,
    required int collectRequestCount,
    required bool useLivePreview,
    required _LiveProductionSnapshot liveSnapshot,
    required String? productionStartedAt,
    required bool isBusy,
  }) {
    final Color statusColor = productionRunning
        ? AppColors.toxicNeon
        : (productionReady ? AppColors.warningSolar : AppColors.mutedTitanium);
    final String statusLabel = productionRunning
        ? 'Üretim sürüyor'
        : (productionReady ? 'Toplama hazır' : 'Depo boş');

    final List<FacilityQueueItem> queueItems = useLivePreview
        ? liveSnapshot.items
            .map(
              (item) => FacilityQueueItem(
                id: item.rarity,
                quantity: item.quantity,
                rarity: item.rarity,
                startedAt: '',
                completesAt: '',
                isCompleted: productionReady,
              ),
            )
            .toList()
        : facility.facilityQueue;

    return <Widget>[
      FacGridBanner(
        borderColor: statusColor.withValues(alpha: 0.35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusLabel,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ),
                if (productionRunning)
                  Text(
                    _formatRemaining(targetAt),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: statusColor),
                  )
                else
                  Text(
                    '$liveCount',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: statusColor),
                  ),
              ],
            ),
            const SizedBox(height: FacilitiesUi.gap),
            if (liveCount <= 0 && !productionRunning)
              const Text('Üretim başlatınca depo dolacak.', style: TextStyle(fontSize: 10, color: AppColors.mutedTitanium))
            else if (liveCount <= 0)
              const Text('İşçiler üretiyor…', style: TextStyle(fontSize: 10, color: AppColors.mutedTitanium))
            else
              ...queueItems.map(
                (FacilityQueueItem item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: FacDepotRow(
                    label: '${_resourceNameByRarity(widget.type, item.rarity)} • ${_rarityLabel(item.rarity)}',
                    quantity: item.quantity,
                    accentColor: facRarityAccent(item.rarity),
                  ),
                ),
              ),
            const SizedBox(height: FacilitiesUi.gap),
            if (productionReady && liveCount > 0)
              FacGoldButton(
                label: 'Topla ($liveCount)',
                accentColor: AppColors.toxicNeon,
                onPressed: (inPrison || isBusy)
                    ? null
                    : () async {
                        final int seed = _hashString(productionStartedAt ?? '');
                        final Map<String, dynamic>? result =
                            await ref.read(facilitiesProvider.notifier).collectResourcesV2(
                                  facilityId: facility.id,
                                  seed: seed,
                                  totalCount: collectRequestCount > 0 ? collectRequestCount : liveCount,
                                );
                        if (!mounted) return;
                        if (result == null) {
                          AppMessenger.showError(
                            context,
                            ref.read(facilitiesProvider).errorMessage ?? 'Toplama başarısız',
                          );
                          return;
                        }

                        final bool admitted = result['admission_occurred'] == true;
                        final int count = (result['count'] as num?)?.toInt() ?? liveCount;

                        if (admitted) {
                          final String prisonReason = (result['prison_reason'] ?? 'Bilinmiyor').toString();
                          AppMessenger.show(context, '⚠️ Hapse düştünüz! Gerekçe: $prisonReason');
                        } else {
                          AppMessenger.show(context, '✅ Toplandı: $count kaynak');
                        }

                        ref.read(playerProvider.notifier).loadProfile();
                        ref.read(inventoryProvider.notifier).loadInventory(silent: true);
                      },
              )
            else if (productionRunning)
              FacGoldButton(
                label: 'Bekleyin: ${_formatRemaining(targetAt)}',
                onPressed: null,
              )
            else
              FacGoldButton(
                label: energy < 50 ? '50⚡ gerekli' : '⚡ Üretimi Başlat',
                onPressed: (inPrison || energy < 50 || isBusy)
                    ? null
                    : () async {
                        final bool ok = await ref.read(facilitiesProvider.notifier).startProduction(
                              facilityId: facility.id,
                            );
                        if (!mounted) return;
                        AppMessenger.show(
                          context,
                          ok ? 'Üretim başlatıldı!' : (ref.read(facilitiesProvider).errorMessage ?? 'Üretim başlatılamadı'),
                        );
                        if (ok) {
                          ref.read(playerProvider.notifier).loadProfile();
                        }
                      },
              ),
          ],
        ),
      ),
    ];
  }

  void _syncProductionPolling(String? productionStartedAt, bool productionRunning) {
    final String nextKey = productionRunning && productionStartedAt != null ? productionStartedAt : '';
    if (_productionPollKey == nextKey) return;

    _productionPollKey = nextKey;
    _productionPollTimer?.cancel();

    if (!productionRunning || productionStartedAt == null) {
      _productionPollTimer = null;
      return;
    }

    _productionPollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      ref.read(facilitiesProvider.notifier).loadFacilities();
      ref.read(playerProvider.notifier).loadProfile();
    });
  }

  Future<void> _showUpgradeDialog(String facilityId, String name, int currentLevel, int upgradeCost) async {
    final bool confirm = await showFacUpgradeDialog(
      context,
      facilityName: name,
      targetLevel: currentLevel + 1,
      formattedCost: _formatGold(upgradeCost),
    );

    if (!confirm) return;

    final bool ok = await ref.read(facilitiesProvider.notifier).upgradeFacility(facilityId: facilityId);
    if (!mounted) return;

    AppMessenger.show(
      context,
      ok
          ? '$name yükseltildi!'
          : (ref.read(facilitiesProvider).errorMessage ?? 'Yükseltme başarısız'),
    );
    ref.read(playerProvider.notifier).loadProfile();
  }
}

class _FacilityMeta {
  const _FacilityMeta({
    required this.name,
    required this.icon,
    required this.description,
    required this.baseRate,
    required this.baseUpgradeCost,
    required this.multiplier,
    required this.resources,
  });

  final String name;
  final String icon;
  final String description;
  final double baseRate;
  final int baseUpgradeCost;
  final double multiplier;
  final List<String> resources;
}

const Map<String, _FacilityMeta> _facilityMeta = <String, _FacilityMeta>{
  'mining': _FacilityMeta(
    name: 'Maden Ocağı',
    icon: '⛏️',
    description: 'Demir, bakır, altın ve gümüş cevheri çıkarır',
    baseRate: 10,
    baseUpgradeCost: 100000,
    multiplier: 1.5,
    resources: <String>['Ham Demir', 'Saf Bakır', 'Gümüş Damarı', 'Asil Altın', 'Mithril', 'Saf Celestium'],
  ),
  'quarry': _FacilityMeta(
    name: 'Taş Ocağı',
    icon: '🪨',
    description: 'Granit, mermer ve kristal çıkarır',
    baseRate: 8,
    baseUpgradeCost: 120000,
    multiplier: 1.5,
    resources: <String>['Sıradan Taş', 'Katı Granit', 'Beyaz Mermer', 'Kara Obsidyen', 'Adamantit Parçası', 'Ebedi Taş'],
  ),
  'lumber_mill': _FacilityMeta(
    name: 'Kereste Fabrikası',
    icon: '🪵',
    description: 'Meşe, çam ve bambu odunu üretir',
    baseRate: 12,
    baseUpgradeCost: 150000,
    multiplier: 1.5,
    resources: <String>['Meşe Kerestesi', 'Çam Kerestesi', 'Abanoz', 'Ejder Ağacı', 'Dünya Ağacı Dalı', 'Yggdrasil Dalı'],
  ),
  'clay_pit': _FacilityMeta(
    name: 'Kil Ocağı',
    icon: '🏺',
    description: 'Seramik kili ve tuğla malzemesi çıkarır',
    baseRate: 15,
    baseUpgradeCost: 180000,
    multiplier: 1.5,
    resources: <String>['Sıradan Kil', 'Seramik Kili', 'Altın Kil', 'Ejder Kili', 'Elementel Kil', 'İlkel Kil'],
  ),
  'sand_quarry': _FacilityMeta(
    name: 'Kum Ocağı',
    icon: '🏖️',
    description: 'Cam kumu ve kristal kumu toplar',
    baseRate: 20,
    baseUpgradeCost: 200000,
    multiplier: 1.5,
    resources: <String>['Sıradan Kum', 'Cam Kumu', 'Kristal Kum', 'Altın Kum', 'Yıldız Kumu', 'Zaman Kumu'],
  ),
  'farming': _FacilityMeta(
    name: 'Çiftlik',
    icon: '🌾',
    description: 'Buğday, sebze ve pamuk yetiştirir',
    baseRate: 18,
    baseUpgradeCost: 250000,
    multiplier: 1.5,
    resources: <String>['Sıradan Buğday', 'Güçlü Arpa', 'Altın Pamuk', 'Ejder Meyvesi', 'Yaşam Tohumu', 'Ebedi Bitki'],
  ),
  'herb_garden': _FacilityMeta(
    name: 'Ot Bahçesi',
    icon: '🌿',
    description: 'Şifalı otlar ve nadir bitkiler yetiştirir',
    baseRate: 10,
    baseUpgradeCost: 300000,
    multiplier: 1.5,
    resources: <String>['Şifalı Ot', 'Zehirli Ot', 'Ay Çiçeği', 'Ejder Kökü', 'Ölümsüzlük Otu', 'Hayat Özü'],
  ),
  'ranch': _FacilityMeta(
    name: 'Hayvancılık',
    icon: '🐄',
    description: 'Deri, kemik ve yün üretir',
    baseRate: 12,
    baseUpgradeCost: 350000,
    multiplier: 1.5,
    resources: <String>['Sıradan Deri', 'Güçlü Yün', 'Canavar Boynuzu', 'Wyvern Derisi', 'Unicorn Tırnağı', 'Anka Kanı'],
  ),
  'apiary': _FacilityMeta(
    name: 'Arıcılık',
    icon: '🐝',
    description: 'Bal, balmumu ve arı zehiri toplar',
    baseRate: 8,
    baseUpgradeCost: 400000,
    multiplier: 1.5,
    resources: <String>['Orman Balı', 'Saf Balmumu', 'Kraliyet Jelesi', 'Arı Zehiri Özü', 'Altın Bal', 'İlahi Ambrosia'],
  ),
  'mushroom_farm': _FacilityMeta(
    name: 'Mantar Çiftliği',
    icon: '🍄',
    description: 'Şifalı ve zehirli mantarlar yetiştirir',
    baseRate: 10,
    baseUpgradeCost: 500000,
    multiplier: 1.5,
    resources: <String>['Şifalı Mantar', 'Parlayan Mantar', 'Zehirli Mantar', 'Kristal Mantar', 'Zaman Mantarı', 'İlkel Mantar'],
  ),
  'rune_mine': _FacilityMeta(
    name: 'Rune Madeni',
    icon: '🔮',
    description: 'Ham rune taşları ve büyülü kristaller çıkarır',
    baseRate: 5,
    baseUpgradeCost: 600000,
    multiplier: 1.6,
    resources: <String>['Ham Rune Taşı', 'Büyü Kristali', 'Enerji Parçası', 'Rune Çekirdeği', 'Gizemli Kalp', 'Rune Özü'],
  ),
  'holy_spring': _FacilityMeta(
    name: 'Kutsal Kaynak',
    icon: '⛲',
    description: 'Kutsal su ve mana kristalleri üretir',
    baseRate: 6,
    baseUpgradeCost: 700000,
    multiplier: 1.6,
    resources: <String>['Kutsal Su', 'Mana Kristali', 'Arındırma Suyu', 'Melek Gözyaşı', 'Yaşam Kaynağı', 'Ebedi Su'],
  ),
  'shadow_pit': _FacilityMeta(
    name: 'Gölge Çukuru',
    icon: '🕳️',
    description: 'Karanlık esans ve gölge kristalleri toplar',
    baseRate: 4,
    baseUpgradeCost: 800000,
    multiplier: 1.6,
    resources: <String>['Gölge Tozu', 'Gölge Kristali', 'Karanlık Esansı', 'Gölge Kalbi', 'Uçurum Çekirdeği', 'Ebedi Boşluk'],
  ),
  'elemental_forge': _FacilityMeta(
    name: 'Elementel Ocak',
    icon: '🔥',
    description: 'Ateş, buz ve yıldırım esansı üretir',
    baseRate: 5,
    baseUpgradeCost: 1000000,
    multiplier: 1.6,
    resources: <String>['Ateş Kıvılcımı', 'Buz Parçası', 'Yıldırım Çekirdeği', 'Toprak Kalbi', 'Saf Element', 'Beşinci Element'],
  ),
  'time_well': _FacilityMeta(
    name: 'Zaman Kuyusu',
    icon: '⏳',
    description: 'Zaman kristali ve hızlandırma tozu üretir',
    baseRate: 3,
    baseUpgradeCost: 1200000,
    multiplier: 1.7,
    resources: <String>['Zaman Tozu', 'Saat Parçası', 'Zaman Kristali', 'Kronos Esansı', 'Ebedi An', 'Sonsuz Zaman'],
  ),
};

int _getUpgradeCost(String type, int currentLevel) {
  final _FacilityMeta? meta = _facilityMeta[type];
  if (meta == null) return 0;

  final double cost = meta.baseUpgradeCost * _pow(meta.multiplier, currentLevel - 1);
  return cost.floor();
}

double _pow(double base, int exponent) {
  if (exponent <= 0) return 1;
  double result = 1;
  for (int i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}

int _sumQueueQuantity(List<FacilityQueueItem> items) {
  int total = 0;
  for (final item in items) {
    total += item.quantity;
  }
  return total;
}

String _formatRemaining(DateTime? targetAt) {
  if (targetAt == null) return '00:00';
  final int remaining = targetAt.difference(DateTime.now()).inSeconds;
  if (remaining <= 0) return '✅';

  final int mins = remaining ~/ 60;
  final int secs = remaining % 60;
  return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}

int _hashString(String value) {
  int hash = 0;
  for (int i = 0; i < value.length; i++) {
    hash = ((hash << 5) - hash) + value.codeUnitAt(i);
    hash &= 0x7fffffff;
  }
  return hash.abs();
}

String _rarityLabel(String rarity) {
  switch (rarity) {
    case 'common':
      return '⚪ Yaygın';
    case 'uncommon':
      return '🟢 Sıradışı';
    case 'rare':
      return '🔵 Nadir';
    case 'epic':
      return '🟣 Epik';
    case 'legendary':
      return '🟡 Efsanevi';
    case 'mythic':
      return '🌈 Mitik';
    default:
      return rarity;
  }
}

String _rarityTitle(String rarity) {
  switch (rarity) {
    case 'common':
      return 'Yaygın';
    case 'uncommon':
      return 'Sıradışı';
    case 'rare':
      return 'Nadir';
    case 'epic':
      return 'Epik';
    case 'legendary':
      return 'Efsanevi';
    case 'mythic':
      return 'Mitik';
    default:
      return rarity;
  }
}

String _rarityEmoji(String rarity) {
  switch (rarity) {
    case 'common':
      return '⚪';
    case 'uncommon':
      return '🟢';
    case 'rare':
      return '🔵';
    case 'epic':
      return '🟣';
    case 'legendary':
      return '🟡';
    case 'mythic':
      return '🌈';
    default:
      return '⚪';
  }
}

Map<String, int> _getRarityWeightsAtLevel(int level) {
  if (level <= 1) return _dropRatesByLevel[1]!;
  if (level >= 10) return _dropRatesByLevel[10]!;
  return _dropRatesByLevel[level] ?? _dropRatesByLevel[1]!;
}

const List<String> _resourceRarities = <String>['common', 'uncommon', 'rare', 'epic', 'legendary', 'mythic'];

const Map<String, int> _rarityUnlockLevels = <String, int>{
  'common': 1,
  'uncommon': 3,
  'rare': 5,
  'epic': 7,
  'legendary': 9,
  'mythic': 10,
};

const Map<int, Map<String, int>> _dropRatesByLevel = <int, Map<String, int>>{
  1: <String, int>{'common': 100, 'uncommon': 0, 'rare': 0, 'epic': 0, 'legendary': 0, 'mythic': 0},
  2: <String, int>{'common': 90, 'uncommon': 10, 'rare': 0, 'epic': 0, 'legendary': 0, 'mythic': 0},
  3: <String, int>{'common': 70, 'uncommon': 25, 'rare': 5, 'epic': 0, 'legendary': 0, 'mythic': 0},
  4: <String, int>{'common': 55, 'uncommon': 30, 'rare': 13, 'epic': 2, 'legendary': 0, 'mythic': 0},
  5: <String, int>{'common': 40, 'uncommon': 30, 'rare': 20, 'epic': 8, 'legendary': 2, 'mythic': 0},
  6: <String, int>{'common': 30, 'uncommon': 28, 'rare': 22, 'epic': 14, 'legendary': 5, 'mythic': 1},
  7: <String, int>{'common': 22, 'uncommon': 25, 'rare': 23, 'epic': 18, 'legendary': 9, 'mythic': 3},
  8: <String, int>{'common': 15, 'uncommon': 22, 'rare': 24, 'epic': 22, 'legendary': 12, 'mythic': 5},
  9: <String, int>{'common': 10, 'uncommon': 18, 'rare': 24, 'epic': 24, 'legendary': 16, 'mythic': 8},
  10: <String, int>{'common': 5, 'uncommon': 14, 'rare': 22, 'epic': 26, 'legendary': 20, 'mythic': 13},
};

class _LiveResourceItem {
  const _LiveResourceItem({required this.rarity, required this.quantity});

  final String rarity;
  final int quantity;
}

class _LiveProductionSnapshot {
  const _LiveProductionSnapshot({
    required this.baseProduced,
    required this.totalProduced,
    required this.items,
  });

  final int baseProduced;
  final int totalProduced;
  final List<_LiveResourceItem> items;
}

_LiveProductionSnapshot _buildLiveProductionSnapshot({
  required String facilityType,
  required int level,
  required String? productionStartedAt,
  required DateTime now,
}) {
  if (productionStartedAt == null || productionStartedAt.isEmpty) {
    return const _LiveProductionSnapshot(baseProduced: 0, totalProduced: 0, items: <_LiveResourceItem>[]);
  }

  final DateTime? started = DateTime.tryParse(productionStartedAt);
  if (started == null) {
    return const _LiveProductionSnapshot(baseProduced: 0, totalProduced: 0, items: <_LiveResourceItem>[]);
  }

  final _FacilityMeta? meta = _facilityMeta[facilityType];
  final double baseRate = meta?.baseRate ?? 10;

  final int elapsedMs = now.millisecondsSinceEpoch - started.millisecondsSinceEpoch;
  final int durationMs = _productionDurationSecondsGlobal * 1000;
  final int clampedElapsedMs = elapsedMs.clamp(0, durationMs);
  final double elapsedSeconds = clampedElapsedMs / 1000;
  final double effectiveElapsedSeconds = elapsedSeconds >= 115 ? _productionDurationSecondsGlobal.toDouble() : elapsedSeconds;

  final double baseCalc = (effectiveElapsedSeconds / 3600.0) * (baseRate * level * 10);
  final int baseProduced = baseCalc.round();

  final int seed = _hashString(productionStartedAt).abs() % 2147483647;
  int jitterStep = 0;
  int totalProduced = baseProduced;

  if (baseProduced >= 20) {
    jitterStep = (seed % 11) - 5;
    totalProduced = (baseProduced * (1 + jitterStep / 100)).round();
    totalProduced = totalProduced.clamp(0, baseProduced + (baseProduced * 0.1).ceil());
  }

  if (totalProduced <= 0) {
    return _LiveProductionSnapshot(baseProduced: baseProduced, totalProduced: 0, items: const <_LiveResourceItem>[]);
  }

  final Map<String, int> weights = _getRarityWeightsAtLevel(level);
  final int sum = weights.values.fold<int>(0, (int s, int v) => s + v);
  if (sum <= 0) {
    return _LiveProductionSnapshot(baseProduced: baseProduced, totalProduced: totalProduced, items: const <_LiveResourceItem>[]);
  }

  final Map<String, int> counts = <String, int>{
    'common': 0,
    'uncommon': 0,
    'rare': 0,
    'epic': 0,
    'legendary': 0,
    'mythic': 0,
  };

  for (int i = 0; i < totalProduced; i++) {
    final int roll = ((_hashString('$productionStartedAt-$i') % sum) + sum) % sum;
    int cursor = 0;
    for (final String rarity in _resourceRarities) {
      cursor += weights[rarity] ?? 0;
      if (roll < cursor) {
        counts[rarity] = (counts[rarity] ?? 0) + 1;
        break;
      }
    }
  }

  final List<_LiveResourceItem> items = <_LiveResourceItem>[];
  for (int i = _resourceRarities.length - 1; i >= 0; i--) {
    final String rarity = _resourceRarities[i];
    final int quantity = counts[rarity] ?? 0;
    if (quantity > 0) {
      items.add(_LiveResourceItem(rarity: rarity, quantity: quantity));
    }
  }

  return _LiveProductionSnapshot(
    baseProduced: baseProduced,
    totalProduced: totalProduced,
    items: items,
  );
}

const int _productionDurationSecondsGlobal = 120;

String _resourceNameByRarity(String facilityType, String rarity) {
  final _FacilityMeta? meta = _facilityMeta[facilityType];
  if (meta == null) return rarity;

  final int idx = _resourceRarities.indexOf(rarity.toLowerCase());
  if (idx < 0 || idx >= meta.resources.length) return rarity;
  return meta.resources[idx];
}

bool _isFuture(String? iso) {
  if (iso == null || iso.isEmpty) return false;
  final DateTime? parsed = DateTime.tryParse(iso);
  if (parsed == null) return false;
  return parsed.isAfter(DateTime.now());
}

String _formatGold(int value) => NumberFormat.decimalPattern('tr_TR').format(value);

class _RaritySimulatorAccordion extends StatefulWidget {
  const _RaritySimulatorAccordion({required this.currentLevel});

  final int currentLevel;

  @override
  State<_RaritySimulatorAccordion> createState() => _RaritySimulatorAccordionState();
}

class _RaritySimulatorAccordionState extends State<_RaritySimulatorAccordion> {
  late final Set<int> _expandedLevels;

  @override
  void initState() {
    super.initState();
    _expandedLevels = <int>{widget.currentLevel};
  }

  void _toggleLevel(int level) {
    setState(() {
      if (_expandedLevels.contains(level)) {
        _expandedLevels.remove(level);
      } else {
        _expandedLevels.add(level);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DottedPanel(
      padding: FacilitiesUi.panelPadding,
      borderRadius: 12,
      borderColor: AppColors.cyberFuchsia.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          facilitiesSectionTitle('Drop Simülasyonu', trailing: 'Lv.1–10'),
          const SizedBox(height: FacilitiesUi.gapSm),
          ...List<Widget>.generate(10, (int idx) {
            final int rarityLevel = idx + 1;
            final bool isCurrent = rarityLevel == widget.currentLevel;
            final bool isExpanded = _expandedLevels.contains(rarityLevel);
            final Map<String, int> weights = _getRarityWeightsAtLevel(rarityLevel);
            final int total = weights.values.fold<int>(0, (int sum, int v) => sum + v);

            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCurrent
                        ? AppColors.liquidGold.withValues(alpha: 0.45)
                        : AppColors.mutedTitanium.withValues(alpha: 0.18),
                  ),
                  color: isCurrent
                      ? AppColors.liquidGold.withValues(alpha: 0.08)
                      : AppColors.darkObsidian.withValues(alpha: 0.45),
                ),
                child: Column(
                  children: <Widget>[
                    InkWell(
                      onTap: () => _toggleLevel(rarityLevel),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        child: Row(
                          children: <Widget>[
                            Text(
                              'Lv.$rarityLevel',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (isCurrent) ...<Widget>[
                              const SizedBox(width: 8),
                              Text(
                                'Mevcut Seviye',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.liquidGold.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                            const Spacer(),
                            Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              size: 18,
                              color: AppColors.mutedTitanium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isExpanded)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _resourceRarities.map((String rarity) {
                            final double pct = total > 0 ? ((weights[rarity] ?? 0) / total) * 100 : 0;
                            final int decimals =
                                (rarity == 'common' || rarity == 'uncommon' || rarity == 'rare') ? 0 : 1;

                            return Container(
                              width: (MediaQuery.of(context).size.width - 84) / 2,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.mutedTitanium.withValues(alpha: 0.2),
                                ),
                                color: AppColors.carbonVoid.withValues(alpha: 0.55),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Text(
                                        _rarityTitle(rarity),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.mutedTitanium,
                                        ),
                                      ),
                                      Text(
                                        '${pct.toStringAsFixed(decimals)}%',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: (pct.clamp(0, 100)) / 100,
                                    minHeight: 4,
                                    backgroundColor: AppColors.darkObsidian,
                                    color: facRarityAccent(rarity),
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
          }),
        ],
      ),
    );
  }
}
