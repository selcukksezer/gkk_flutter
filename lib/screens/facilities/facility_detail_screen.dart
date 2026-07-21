import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../models/facility_model.dart';
import '../../models/facility_production_preview_model.dart';
import '../../providers/facilities_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../utils/logout_helper.dart';
import 'facility_detail_data.dart';
import 'widgets/facilities_ui.dart';
import 'widgets/facility_detail_design.dart';
import 'widgets/facility_detail_overview_tab.dart';

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
  late final ValueNotifier<DateTime> _nowListenable;
  Timer? _clockTimer;
  Timer? _productionPollTimer;
  String? _productionPollKey;

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
    for (final PlayerFacility row in facilities) {
      if (row.facilityType == widget.type) {
        return row;
      }
    }
    return null;
  }

  void _maybeLoadPreviewForCurrentFacility() {
    final PlayerFacility? facility = _findFacility(ref.read(facilitiesProvider).facilities);
    if (facility == null) return;
    final String? startedAt = facility.productionStartedAt;
    if (startedAt == null || startedAt.isEmpty) return;
    ref.read(facilitiesProvider.notifier).loadProductionPreview(facility.id);
  }

  @override
  Widget build(BuildContext context) {
    final facilitiesState = ref.watch(facilitiesProvider);
    final playerState = ref.watch(playerProvider);
    final profile = playerState.profile;
    final bool isBusy = facilitiesState.isMutating;

    final bool inPrison = facilityIsFutureIso(profile?.prisonUntil);
    final int energy = profile?.energy ?? 0;
    final int gold = profile?.gold ?? 0;

    final PlayerFacility? facility = _findFacility(facilitiesState.facilities);
    final FacilityMeta? meta = facilityMetaFor(widget.type);

    Future<void> logout() async {
      await performLogout(ref);
    }

    return GameSubScreenScaffold(
      title: meta?.name ?? widget.type,
      onLogout: logout,
      fallbackRoute: AppRoutes.facilities,
      bottomNavRoute: AppRoutes.facilities,
      body: facilitiesScreenShell(
        child: ValueListenableBuilder<DateTime>(
          valueListenable: _nowListenable,
          builder: (BuildContext context, DateTime now, Widget? _) {
            final String? productionStartedAt = facility?.productionStartedAt;
            final bool hasProductionRecord = productionStartedAt != null && productionStartedAt.isNotEmpty;
            final FacilityProductionPreview preview = facility == null
                ? FacilityProductionPreview.empty
                : facilitiesState.productionPreviews[facility.id] ?? FacilityProductionPreview.empty;

            final DateTime? startedAt = productionStartedAt == null || productionStartedAt.isEmpty
                ? null
                : DateTime.tryParse(productionStartedAt);
            final DateTime? targetAt =
                startedAt?.add(const Duration(seconds: kFacilityProductionDurationSeconds));

            final bool productionReady =
                hasProductionRecord && (preview.isReady || (targetAt != null && !now.isBefore(targetAt)));
            final bool productionRunning = hasProductionRecord && !productionReady;

            _syncProductionPolling(facility, productionStartedAt, productionRunning);

            final int level = facility?.level ?? 1;
            final int liveCount = hasProductionRecord
                ? preview.totalCount
                : sumFacilityQueueQuantity(facility?.facilityQueue ?? const <FacilityQueueItem>[]);

            final int upgradeCost = facilityUpgradeCost(widget.type, level);
            final bool canUpgrade = !hasProductionRecord && (facility?.level ?? 1) < 10 && gold >= upgradeCost;

            return ListView(
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
            );
          },
        ),
      ),
    );
  }

  void _syncProductionPolling(
    PlayerFacility? facility,
    String? productionStartedAt,
    bool productionRunning,
  ) {
    final String nextKey = productionRunning && productionStartedAt != null ? productionStartedAt : '';
    if (_productionPollKey == nextKey) return;

    _productionPollKey = nextKey;
    _productionPollTimer?.cancel();

    if (facility == null || !productionRunning || productionStartedAt == null) {
      _productionPollTimer = null;
      return;
    }

    final String facilityId = facility.id;
    ref.read(facilitiesProvider.notifier).loadProductionPreview(facilityId);

    _productionPollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      ref.read(facilitiesProvider.notifier).loadFacilities();
      ref.read(facilitiesProvider.notifier).loadProductionPreview(facilityId);
      ref.read(playerProvider.notifier).loadProfile();
    });
  }
}
