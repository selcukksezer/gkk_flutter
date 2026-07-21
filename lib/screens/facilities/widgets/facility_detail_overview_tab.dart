import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../models/facility_model.dart';
import '../../../models/facility_production_preview_model.dart';
import '../../../providers/facilities_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../theme/app_colors.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import '../facility_detail_data.dart';
import 'facilities_dialogs.dart';
import 'facilities_ui.dart';
import 'facility_detail_depot_panel.dart';
import 'facility_detail_design.dart';
import 'facility_rarity_simulator.dart';

class FacDetailOverviewTab extends ConsumerWidget {
  const FacDetailOverviewTab({
    super.key,
    required this.facilityType,
    required this.meta,
    required this.facility,
    required this.inPrison,
    required this.energy,
    required this.upgradeCost,
    required this.canUpgrade,
    required this.hasProductionRecord,
    required this.productionRunning,
    required this.productionReady,
    required this.targetAt,
    required this.liveCount,
    required this.preview,
    required this.isBusy,
    required this.now,
  });

  final String facilityType;
  final FacilityMeta? meta;
  final PlayerFacility facility;
  final bool inPrison;
  final int energy;
  final int upgradeCost;
  final bool canUpgrade;
  final bool hasProductionRecord;
  final bool productionRunning;
  final bool productionReady;
  final DateTime? targetAt;
  final int liveCount;
  final FacilityProductionPreview preview;
  final bool isBusy;
  final DateTime now;

  bool get _canStartProduction =>
      !hasProductionRecord && !inPrison && energy >= 50 && !isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<String> previewLabels = preview.items
        .map((item) => '${facilityResourceNameByRarity(facilityType, item.rarity)} ×${item.quantity}')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!hasProductionRecord)
          FacProductionBanner(
            isRunning: false,
            remainingLabel: formatFacilityRemaining(targetAt, now: now),
            previewItems: previewLabels,
            startEnabled: _canStartProduction,
            startLabel: energy < 50 ? '50⚡ gerekli' : '⚡ Üretimi Başlat',
            onStart: () => _startProduction(context, ref),
          )
        else
          FacProductionBanner(
            isRunning: true,
            remainingLabel: productionReady
                ? 'Toplamaya hazır'
                : formatFacilityRemaining(targetAt, now: now),
            previewItems: previewLabels,
            startEnabled: false,
            startLabel: '',
            onStart: null,
          ),
        if (hasProductionRecord) ...<Widget>[
          const SizedBox(height: FacilitiesUi.gap),
          FacDetailDepotPanel(
            facilityType: facilityType,
            facility: facility,
            inPrison: inPrison,
            productionRunning: productionRunning,
            productionReady: productionReady,
            targetAt: targetAt,
            liveCount: liveCount,
            preview: preview,
            hasProductionRecord: hasProductionRecord,
            isBusy: isBusy,
            now: now,
          ),
        ],
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
                  final String rarity =
                      index < kFacilityResourceRarities.length ? kFacilityResourceRarities[index] : 'common';
                  final Map<String, int> weights = facilityRarityWeightsAtLevel(facility.level);
                  final int total = weights.values.fold<int>(0, (int sum, int v) => sum + v);
                  final int unlockLevel = kFacilityRarityUnlockLevels[rarity] ?? 1;
                  final bool isUnlocked = facility.level >= unlockLevel;
                  final double percent = total > 0 ? ((weights[rarity] ?? 0) / total) * 100 : 0;

                  return FacResourceCell(
                    emoji: facilityRarityEmoji(rarity),
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
        FacRaritySimulatorAccordion(currentLevel: facility.level),
        const SizedBox(height: FacilitiesUi.gap),
        FacUpgradeStrip(
          summary: facility.level >= 10
              ? 'Maksimum seviye'
              : 'Lv.${facility.level + 1} • ${formatFacilityGold(upgradeCost)} altın',
          buttonLabel: 'Yükselt',
          enabled: canUpgrade && !inPrison && !isBusy,
          onUpgrade: () => _showUpgradeDialog(
            context,
            ref,
            facilityId: facility.id,
            name: meta?.name ?? facilityType,
            currentLevel: facility.level,
            upgradeCost: upgradeCost,
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
      ],
    );
  }

  Future<void> _startProduction(BuildContext context, WidgetRef ref) async {
    if (!_canStartProduction) return;

    final bool ok = await ref.read(facilitiesProvider.notifier).startProduction(
          facilityId: facility.id,
        );
    if (!context.mounted) return;
    AppMessenger.show(
      context,
      ok ? 'Üretim başlatıldı!' : (ref.read(facilitiesProvider).errorMessage ?? 'Üretim başlatılamadı'),
    );
    if (ok) {
      ref.read(playerProvider.notifier).loadProfile();
    }
  }

  Future<void> _showUpgradeDialog(
    BuildContext context,
    WidgetRef ref, {
    required String facilityId,
    required String name,
    required int currentLevel,
    required int upgradeCost,
  }) async {
    final bool confirm = await showFacUpgradeDialog(
      context,
      facilityName: name,
      targetLevel: currentLevel + 1,
      formattedCost: formatFacilityGold(upgradeCost),
    );

    if (!confirm) return;

    final bool ok = await ref.read(facilitiesProvider.notifier).upgradeFacility(facilityId: facilityId);
    if (!context.mounted) return;

    AppMessenger.show(
      context,
      ok ? '$name yükseltildi!' : (ref.read(facilitiesProvider).errorMessage ?? 'Yükseltme başarısız'),
    );
    ref.read(playerProvider.notifier).loadProfile();
  }
}
