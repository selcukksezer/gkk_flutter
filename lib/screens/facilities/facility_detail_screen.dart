import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_chrome.dart';
import '../../models/facility_model.dart';
import '../../models/facility_production_preview_model.dart';
import '../../providers/facilities_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../utils/logout_helper.dart';
import 'facility_detail_data.dart';
import 'widgets/facilities_dialogs.dart';
import 'widgets/facilities_ui.dart';
import 'widgets/facility_detail_design.dart';
import 'widgets/facility_detail_overview_tab.dart';
import 'widgets/facility_3d_viewport.dart';

/// Aion-2 Tesis Detay Ekranı — 2027 AAA Mobile Dark Fantasy & Glassmorphism.
class FacilityDetailScreen extends ConsumerStatefulWidget {
  const FacilityDetailScreen({
    super.key,
    required this.type,
  });

  final String type;

  @override
  ConsumerState<FacilityDetailScreen> createState() =>
      _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends ConsumerState<FacilityDetailScreen> {
  late final ValueNotifier<DateTime> _nowListenable;
  Timer? _clockTimer;
  Timer? _productionPollTimer;
  String? _productionPollKey;
  bool _wasProductionRunning = false;
  int? _lastObservedLevel;

  @override
  void initState() {
    super.initState();
    _nowListenable = ValueNotifier<DateTime>(DateTime.now());
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _nowListenable.value = DateTime.now();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(facilitiesProvider.notifier).loadFacilities();
      await ref.read(playerProvider.notifier).loadProfile();
      _maybeLoadPreviewForCurrentFacility();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _productionPollTimer?.cancel();
    _nowListenable.dispose();
    super.dispose();
  }

  PlayerFacility? _findFacility(List<PlayerFacility> facilities) {
    if (facilities.isEmpty) return null;
    for (final PlayerFacility row in facilities) {
      if (row.facilityType == widget.type) {
        return row;
      }
    }
    return null;
  }

  void _maybeLoadPreviewForCurrentFacility() {
    final PlayerFacility? facility =
        _findFacility(ref.read(facilitiesProvider).facilities);
    if (facility == null) return;
    final String? startedAt = facility.productionStartedAt;
    if (startedAt == null || startedAt.isEmpty) return;
    ref.read(facilitiesProvider.notifier).loadProductionPreview(facility.id);
  }

  Future<void> _handleUpgradeAction({
    required BuildContext context,
    required String facilityId,
    required String name,
    required int currentLevel,
    required int upgradeCost,
  }) async {
    HapticFeedback.mediumImpact();
    final bool confirm = await showFacUpgradeDialog(
      context,
      facilityName: name,
      targetLevel: currentLevel + 1,
      formattedCost: formatFacilityGold(upgradeCost),
    );

    if (!confirm || !context.mounted) return;

    final bool ok = await ref
        .read(facilitiesProvider.notifier)
        .upgradeFacility(facilityId: facilityId);
    if (!context.mounted) return;

    if (ok) {
      HapticFeedback.heavyImpact();
      AppMessenger.show(
        context,
        '$name başarıyla Seviye ${currentLevel + 1}\'e yükseltildi!',
        type: AppMessageType.success,
      );
      ref.read(playerProvider.notifier).loadProfile();
    } else {
      HapticFeedback.vibrate();
      final String error =
          ref.read(facilitiesProvider).errorMessage ?? 'Yükseltme başarısız';
      AppMessenger.show(
        context,
        error,
        type: AppMessageType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to facilities provider state changes for toasts and feedback
    ref.listen<FacilitiesState>(facilitiesProvider, (previous, next) {
      if (!mounted) return;

      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        HapticFeedback.vibrate();
        AppMessenger.show(
          context,
          next.errorMessage!,
          type: AppMessageType.error,
        );
      }

      if (previous != null) {
        final prevFac = _findFacility(previous.facilities);
        final nextFac = _findFacility(next.facilities);
        if (prevFac != null && nextFac != null && nextFac.level > prevFac.level) {
          if (_lastObservedLevel != nextFac.level) {
            _lastObservedLevel = nextFac.level;
            HapticFeedback.heavyImpact();
          }
        }
      }
    });

    final facilitiesState = ref.watch(facilitiesProvider);
    final playerState = ref.watch(playerProvider);
    final profile = playerState.profile;
    final bool isBusy = facilitiesState.isMutating;

    final bool inPrison = facilityIsFutureIso(profile?.prisonUntil);
    final int energy = profile?.energy ?? 0;
    final int gold = profile?.gold ?? 0;

    final PlayerFacility? facility = _findFacility(facilitiesState.facilities);
    final FacilityMeta meta = facilityMetaFor(widget.type) ??
        FacilityMeta(
          name: widget.type,
          icon: '🏭',
          description: 'Tesis üretim ve geliştirme merkezi',
          baseRate: 10,
          baseUpgradeCost: 100000,
          multiplier: 1.5,
          resources: const <String>[],
        );

    // Responsive layout calculations
    final media = MediaQuery.sizeOf(context);
    final double screenWidth = media.width;
    final bool isCompact = screenWidth < 360;
    final bool isTablet = screenWidth >= 600;
    final double viewportHeight =
        isCompact ? 220.0 : (media.height < 700 ? 240.0 : 280.0);
    final EdgeInsets contentPadding = isCompact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 12)
        : (isTablet
            ? const EdgeInsets.symmetric(horizontal: 24, vertical: 18)
            : FacilitiesUi.scrollPadding(context));

    Future<void> logout() async {
      await performLogout(ref);
    }

    return GameSubScreenScaffold(
      title: meta.name,
      onLogout: logout,
      fallbackRoute: AppRoutes.facilities,
      bottomNavRoute: AppRoutes.facilities,
      body: SafeArea(
        top: false,
        bottom: true,
        child: facilitiesScreenShell(
          child: ValueListenableBuilder<DateTime>(
            valueListenable: _nowListenable,
            builder: (BuildContext context, DateTime now, Widget? _) {
              final String? rawStartedAt = facility?.productionStartedAt?.trim();
              final bool hasProductionRecord =
                  rawStartedAt != null && rawStartedAt.isNotEmpty;
              final FacilityProductionPreview preview = facility == null
                  ? FacilityProductionPreview.empty
                  : facilitiesState.productionPreviews[facility.id] ??
                      FacilityProductionPreview.empty;

              final DateTime? startedAt = hasProductionRecord
                  ? DateTime.tryParse(rawStartedAt)
                  : null;
              final DateTime? targetAt = startedAt?.add(
                const Duration(seconds: kFacilityProductionDurationSeconds),
              );

              final bool productionReady = hasProductionRecord &&
                  (preview.isReady ||
                      (targetAt != null && !now.isBefore(targetAt)));
              final bool productionRunning =
                  hasProductionRecord && !productionReady;

              // Automatic transition detection: auto-refresh preview when production completes
              if (_wasProductionRunning && productionReady && facility != null) {
                _wasProductionRunning = false;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  ref.read(facilitiesProvider.notifier).loadFacilities();
                  ref
                      .read(facilitiesProvider.notifier)
                      .loadProductionPreview(facility.id);
                });
              } else if (productionRunning) {
                _wasProductionRunning = true;
              }

              _syncProductionPolling(
                facility,
                rawStartedAt,
                productionRunning,
              );

              final int level = facility?.level ?? 1;
              final int liveCount = hasProductionRecord
                  ? preview.totalCount
                  : sumFacilityQueueQuantity(
                      facility?.facilityQueue ?? const <FacilityQueueItem>[],
                    );

              final int upgradeCost = facilityUpgradeCost(widget.type, level);
              final bool canUpgrade = !hasProductionRecord &&
                  level < 10 &&
                  gold >= upgradeCost;

              final int remainingSeconds = targetAt == null
                  ? 0
                  : targetAt
                      .difference(now)
                      .inSeconds
                      .clamp(0, kFacilityProductionDurationSeconds);
              final double productionProgress = targetAt == null ||
                      kFacilityProductionDurationSeconds == 0
                  ? 0.0
                  : (1.0 - (remainingSeconds / kFacilityProductionDurationSeconds))
                      .clamp(0.0, 1.0);

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: RefreshIndicator(
                    color: AppColors.liquidGold,
                    backgroundColor: AppColors.bgDeep,
                    onRefresh: () async {
                      await Future.wait(<Future<void>>[
                        ref.read(facilitiesProvider.notifier).loadFacilities(),
                        ref.read(playerProvider.notifier).loadProfile(),
                      ]);
                      _maybeLoadPreviewForCurrentFacility();
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: contentPadding,
                      children: <Widget>[
                        if (facilitiesState.status == FacilitiesStatus.loading &&
                            facility == null)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  CircularProgressIndicator(
                                    color: AppColors.liquidGold,
                                    strokeWidth: 2.2,
                                  ),
                                  SizedBox(height: 14),
                                  Text(
                                    'Tesis Verileri Yükleniyor...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.mutedTitanium,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (facility == null)
                          FacGlassPanel(
                            padding: const EdgeInsets.all(20),
                            borderColor:
                                AppColors.mysticRuby.withValues(alpha: 0.45),
                            glowColor:
                                AppColors.mysticRuby.withValues(alpha: 0.15),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  meta.icon,
                                  style: const TextStyle(fontSize: 40),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  meta.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Bu tesis henüz açılmamış veya verilerine ulaşılamadı. Ana listeden kilidini açabilir veya sayfayı yenileyebilirsiniz.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.mutedTitanium,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 38,
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      ref
                                          .read(facilitiesProvider.notifier)
                                          .loadFacilities();
                                    },
                                    icon: const Icon(Icons.refresh_rounded,
                                        size: 16),
                                    label: const Text('Yeniden Dene'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.liquidGold,
                                      foregroundColor: AppColors.carbonVoid,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...<Widget>[
                          // 3D Viewport with responsive height
                          Facility3dViewport(
                            facilityType: widget.type,
                            level: facility.level,
                            isProducing: hasProductionRecord,
                            height: viewportHeight,
                            interactive: true,
                            autoRotate: true,
                            showControls: true,
                          ),
                          const SizedBox(height: 12),
                          // Hero Card
                          FacDetailHero(
                            icon: meta.icon,
                            name: meta.name,
                            description: meta.description,
                            level: facility.level,
                            isProducing: hasProductionRecord,
                          ),
                          const SizedBox(height: 10),
                          // Facility Stats HUD
                          _FacilityStatsHud(
                            meta: meta,
                            facility: facility,
                            liveCount: liveCount,
                          ),
                          if (hasProductionRecord) ...<Widget>[
                            const SizedBox(height: 10),
                            // Real-time Live Production HUD Banner
                            _FacilityLiveProductionHud(
                              isRunning: productionRunning,
                              isReady: productionReady,
                              remainingLabel: formatFacilityRemaining(targetAt,
                                  now: now),
                              remainingSeconds: remainingSeconds,
                              progress: productionProgress,
                              liveCount: liveCount,
                            ),
                          ],
                          const SizedBox(height: 10),
                          // Dedicated Upgrade Status & Feedback Banner
                          _FacilityUpgradeFeedbackBanner(
                            facility: facility,
                            meta: meta,
                            gold: gold,
                            upgradeCost: upgradeCost,
                            canUpgrade: canUpgrade,
                            inPrison: inPrison,
                            hasProductionRecord: hasProductionRecord,
                            isBusy: isBusy,
                            onUpgrade: () => _handleUpgradeAction(
                              context: context,
                              facilityId: facility.id,
                              name: meta.name,
                              currentLevel: facility.level,
                              upgradeCost: upgradeCost,
                            ),
                          ),
                          const SizedBox(height: FacilitiesUi.gap),
                          // Existing Overview Tab Deck (Resource Pool, Simulator & Depot)
                          FacDetailOverviewTab(
                            facilityType: widget.type,
                            meta: meta,
                            facility: facility,
                            inPrison: inPrison,
                            energy: energy,
                            upgradeCost: upgradeCost,
                            canUpgrade: canUpgrade,
                            hasProductionRecord: hasProductionRecord,
                            productionRunning: productionRunning,
                            productionReady: productionReady,
                            targetAt: targetAt,
                            liveCount: liveCount,
                            preview: preview,
                            isBusy: isBusy,
                            now: now,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _syncProductionPolling(
    PlayerFacility? facility,
    String? productionStartedAt,
    bool productionRunning,
  ) {
    final String nextKey = productionRunning && productionStartedAt != null
        ? productionStartedAt
        : '';
    if (_productionPollKey == nextKey) return;

    _productionPollKey = nextKey;
    _productionPollTimer?.cancel();

    if (facility == null || !productionRunning || productionStartedAt == null) {
      _productionPollTimer = null;
      return;
    }

    final String facilityId = facility.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(facilitiesProvider.notifier).loadProductionPreview(facilityId);
    });

    _productionPollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      ref.read(facilitiesProvider.notifier).loadFacilities();
      ref.read(facilitiesProvider.notifier).loadProductionPreview(facilityId);
      ref.read(playerProvider.notifier).loadProfile();
    });
  }
}

/// Aion-2 Tesis İstatistikleri HUD Paneli — Seviye çubuğu ve 4 temel gösterge.
class _FacilityStatsHud extends StatelessWidget {
  const _FacilityStatsHud({
    required this.meta,
    required this.facility,
    required this.liveCount,
  });

  final FacilityMeta meta;
  final PlayerFacility facility;
  final int liveCount;

  static String _highestRarityAtLevel(int level) {
    if (level >= 10) return 'mythic';
    if (level >= 9) return 'legendary';
    if (level >= 7) return 'epic';
    if (level >= 5) return 'rare';
    if (level >= 3) return 'uncommon';
    return 'common';
  }

  static double _calculateCycleRate(FacilityMeta meta, int level) {
    return meta.baseRate * (1 + (level - 1) * meta.multiplier);
  }

  @override
  Widget build(BuildContext context) {
    final int level = facility.level;
    final double levelProgress = (level / 10.0).clamp(0.0, 1.0);
    final double cycleRate = _calculateCycleRate(meta, level);
    final String highestRarity = _highestRarityAtLevel(level);
    final String rarityTitle = facilityRarityTitle(highestRarity);
    final String rarityEmoji = facilityRarityEmoji(highestRarity);
    final Color rarityColor = facRarityAccent(highestRarity);

    return FacGlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: FacilitiesUi.radiusMd,
      borderColor: AppColors.liquidGold.withValues(alpha: 0.28),
      glowColor: AppColors.liquidGold.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Level & Progress Gauge
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: AppColors.liquidGold.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppColors.liquidGold.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  'SEVİYE $level / 10',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.liquidGold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: levelProgress,
                    minHeight: 6,
                    backgroundColor: AppColors.darkObsidian,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.liquidGold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                level >= 10
                    ? '👑 AZAMİ'
                    : '+%${((meta.multiplier - 1.0) * 100).round()} Üretim',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color:
                      level >= 10 ? AppColors.liquidGold : AppColors.toxicNeon,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 4-Metric Grid
          Row(
            children: <Widget>[
              Expanded(
                child: _QuickStatCell(
                  icon: Icons.bolt_rounded,
                  accentColor: AppColors.liquidGold,
                  label: 'ÜRETİM HIZI',
                  value: '+${cycleRate.toStringAsFixed(1)}',
                  unit: '/ döngü',
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: _QuickStatCell(
                  icon: Icons.timer_outlined,
                  accentColor: AppColors.accentCyan,
                  label: 'DÖNGÜ SÜRESİ',
                  value: '2 dk',
                  unit: '120 sn',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: _QuickStatCell(
                  customEmoji: rarityEmoji,
                  accentColor: rarityColor,
                  label: 'AZAMİ NADİRLİK',
                  value: rarityTitle,
                  unit: 'Kademe',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickStatCell(
                  icon: Icons.inventory_2_outlined,
                  accentColor: liveCount > 0
                      ? AppColors.toxicNeon
                      : AppColors.mutedTitanium,
                  label: 'DEPODAKİ ÜRÜN',
                  value: '$liveCount',
                  unit: 'adet',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tekil istatistik kutusu — Frosted glass hücre.
class _QuickStatCell extends StatelessWidget {
  const _QuickStatCell({
    this.icon,
    this.customEmoji,
    required this.accentColor,
    required this.label,
    required this.value,
    this.unit,
  });

  final IconData? icon;
  final String? customEmoji;
  final Color accentColor;
  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FacilitiesUi.radiusSm),
        color: AppColors.bgCard.withValues(alpha: 0.7),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.28),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (customEmoji != null)
                Text(customEmoji!, style: const TextStyle(fontSize: 12))
              else if (icon != null)
                Icon(icon, size: 13, color: accentColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.mutedTitanium,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: accentColor,
                  letterSpacing: 0.2,
                ),
              ),
              if (unit != null) ...<Widget>[
                const SizedBox(width: 4),
                Text(
                  unit!,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedTitanium,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Canlı Üretim Geri Sayım ve Durum HUD Paneli.
class _FacilityLiveProductionHud extends StatelessWidget {
  const _FacilityLiveProductionHud({
    required this.isRunning,
    required this.isReady,
    required this.remainingLabel,
    required this.remainingSeconds,
    required this.progress,
    required this.liveCount,
  });

  final bool isRunning;
  final bool isReady;
  final String remainingLabel;
  final int remainingSeconds;
  final double progress;
  final int liveCount;

  @override
  Widget build(BuildContext context) {
    if (isReady) {
      return FacGlassPanel(
        padding: const EdgeInsets.all(12),
        borderRadius: FacilitiesUi.radiusMd,
        borderColor: AppColors.liquidGold.withValues(alpha: 0.6),
        glowColor: AppColors.liquidGold.withValues(alpha: 0.2),
        backgroundColor: const Color(0xCC1A1608),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.liquidGold.withValues(alpha: 0.2),
                border: Border.all(
                  color: AppColors.liquidGold,
                  width: 1.2,
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.liquidGold,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'ÜRETİM TAMAMLANDI!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.liquidGold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$liveCount ürün depoya aktarıldı. Aşağıdaki Depo panelinden toplayabilirsiniz.',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (isRunning) {
      final int percent = (progress * 100).toInt().clamp(0, 100);
      return FacGlassPanel(
        padding: const EdgeInsets.all(12),
        borderRadius: FacilitiesUi.radiusMd,
        borderColor: AppColors.toxicNeon.withValues(alpha: 0.55),
        glowColor: AppColors.toxicNeon.withValues(alpha: 0.18),
        backgroundColor: const Color(0xCC071B12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.toxicNeon,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.toxicNeon,
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'ÜRETİM SÜRÜYOR',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.toxicNeon,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: AppColors.carbonVoid.withValues(alpha: 0.6),
                    border: Border.all(
                      color: AppColors.toxicNeon.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    remainingLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.8,
                      fontFeatures: <ui.FontFeature>[
                        ui.FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: AppColors.darkObsidian,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.toxicNeon,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  '%$percent tamamlandı',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedTitanium,
                  ),
                ),
                Text(
                  '$remainingSeconds sn kaldı',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.toxicNeon,
                    fontFeatures: <ui.FontFeature>[
                      ui.FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Tesis Yükseltme Geri Bildirim ve Durum Paneli.
class _FacilityUpgradeFeedbackBanner extends StatelessWidget {
  const _FacilityUpgradeFeedbackBanner({
    required this.facility,
    required this.meta,
    required this.gold,
    required this.upgradeCost,
    required this.canUpgrade,
    required this.inPrison,
    required this.hasProductionRecord,
    required this.isBusy,
    required this.onUpgrade,
  });

  final PlayerFacility facility;
  final FacilityMeta meta;
  final int gold;
  final int upgradeCost;
  final bool canUpgrade;
  final bool inPrison;
  final bool hasProductionRecord;
  final bool isBusy;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final int level = facility.level;
    final bool isMax = level >= 10;

    if (isMax) {
      return FacGlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        borderRadius: FacilitiesUi.radiusMd,
        borderColor: AppColors.liquidGold.withValues(alpha: 0.4),
        glowColor: AppColors.liquidGold.withValues(alpha: 0.12),
        child: const Row(
          children: <Widget>[
            Text('👑', style: TextStyle(fontSize: 18)),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'AZAMİ SEVİYE (Lv.10)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.liquidGold,
                      letterSpacing: 0.4,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tesis en üst seviyeye ulaştı. Tüm mitik kaynaklar açık.',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: AppColors.mutedTitanium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final bool hasEnoughGold = gold >= upgradeCost;
    final int missingGold = upgradeCost - gold;
    final bool buttonEnabled = canUpgrade && !inPrison && !isBusy;

    return FacGlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: FacilitiesUi.radiusMd,
      borderColor: buttonEnabled
          ? AppColors.coralFlare.withValues(alpha: 0.45)
          : AppColors.darkObsidian,
      glowColor: buttonEnabled
          ? AppColors.coralFlare.withValues(alpha: 0.12)
          : Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.upgrade_rounded,
                color: AppColors.coralFlare,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'YÜKSELTME: Lv.$level ➔ Lv.${level + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: hasEnoughGold
                      ? AppColors.toxicNeon.withValues(alpha: 0.12)
                      : AppColors.mysticRuby.withValues(alpha: 0.12),
                  border: Border.all(
                    color: hasEnoughGold
                        ? AppColors.toxicNeon.withValues(alpha: 0.4)
                        : AppColors.mysticRuby.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '💰 ${formatFacilityGold(upgradeCost)}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: hasEnoughGold
                        ? AppColors.liquidGold
                        : AppColors.mysticRuby,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Status notices
          if (inPrison)
            _buildStatusNotice(
              icon: Icons.gavel_rounded,
              color: AppColors.mysticRuby,
              text: 'Mahkumiyet süresince tesis yükseltmesi yapılamaz.',
            )
          else if (hasProductionRecord)
            _buildStatusNotice(
              icon: Icons.lock_clock_rounded,
              color: AppColors.warningSolar,
              text: 'Devam eden üretim tamamlanmadan tesis yükseltilemez.',
            )
          else if (!hasEnoughGold)
            _buildStatusNotice(
              icon: Icons.info_outline_rounded,
              color: AppColors.mysticRuby,
              text:
                  'Yetersiz Altın — Eksik: ${formatFacilityGold(missingGold)} Altın (Mevcut: ${formatFacilityGold(gold)})',
            )
          else
            _buildStatusNotice(
              icon: Icons.check_circle_outline_rounded,
              color: AppColors.toxicNeon,
              text: 'Yükseltme gereksinimleri karşılandı. Yükseltmeye hazır!',
            ),
          const SizedBox(height: 10),
          // Upgrade Action Button
          SizedBox(
            height: 38,
            child: FilledButton(
              onPressed: buttonEnabled ? onUpgrade : null,
              style: FilledButton.styleFrom(
                backgroundColor: buttonEnabled
                    ? AppColors.coralFlare
                    : AppColors.bgSurface.withValues(alpha: 0.6),
                foregroundColor: buttonEnabled
                    ? AppColors.textPrimary
                    : AppColors.mutedTitanium,
                disabledBackgroundColor:
                    AppColors.bgSurface.withValues(alpha: 0.6),
                disabledForegroundColor: AppColors.mutedTitanium,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: buttonEnabled
                        ? AppColors.coralFlare.withValues(alpha: 0.6)
                        : AppColors.borderFaint,
                  ),
                ),
                elevation: buttonEnabled ? 3 : 0,
                shadowColor: AppColors.coralFlare.withValues(alpha: 0.4),
              ),
              child: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textPrimary,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.arrow_upward_rounded,
                          size: 16,
                          color: buttonEnabled
                              ? AppColors.textPrimary
                              : AppColors.mutedTitanium,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Lv.${level + 1}\'e Yükselt (${formatFacilityGold(upgradeCost)} Altın)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                            color: buttonEnabled
                                ? AppColors.textPrimary
                                : AppColors.mutedTitanium,
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

  Widget _buildStatusNotice({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.08),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
