import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/common/reward_magnet_overlay.dart';
import '../../../models/facility_model.dart';
import '../../../models/facility_production_preview_model.dart';
import '../../../providers/facilities_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../theme/app_colors.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import '../facility_detail_data.dart';
import 'facilities_ui.dart';
import 'facility_detail_design.dart';

class FacDetailDepotPanel extends ConsumerWidget {
  const FacDetailDepotPanel({
    super.key,
    required this.facilityType,
    required this.facility,
    required this.inPrison,
    required this.productionRunning,
    required this.productionReady,
    required this.targetAt,
    required this.liveCount,
    required this.preview,
    required this.hasProductionRecord,
    required this.isBusy,
    required this.now,
  });

  final String facilityType;
  final PlayerFacility facility;
  final bool inPrison;
  final bool productionRunning;
  final bool productionReady;
  final DateTime? targetAt;
  final int liveCount;
  final FacilityProductionPreview preview;
  final bool hasProductionRecord;
  final bool isBusy;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color statusColor = productionRunning
        ? AppColors.toxicNeon
        : (productionReady ? AppColors.warningSolar : AppColors.mutedTitanium);
    final String statusLabel = productionRunning
        ? 'Üretim sürüyor'
        : (productionReady ? 'Toplama hazır' : 'Depo');

    final List<FacilityQueueItem> queueItems = hasProductionRecord
        ? preview.toQueueItems(completed: productionReady)
        : facility.facilityQueue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        facilitiesSectionTitle('Depo'),
        const SizedBox(height: FacilitiesUi.gapSm),
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
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (productionRunning)
                    Text(
                      formatFacilityRemaining(targetAt, now: now),
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
              if (liveCount <= 0 && productionRunning)
                const Text(
                  'İşçiler üretiyor…',
                  style: TextStyle(fontSize: 10, color: AppColors.mutedTitanium),
                )
              else if (liveCount <= 0)
                const Text(
                  'Kaynaklar birikiyor…',
                  style: TextStyle(fontSize: 10, color: AppColors.mutedTitanium),
                )
              else
                ...queueItems.map(
                  (FacilityQueueItem item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: FacDepotRow(
                      label:
                          '${facilityResourceNameByRarity(facilityType, item.rarity)} • ${facilityRarityLabel(item.rarity)}',
                      quantity: item.quantity,
                      accentColor: facRarityAccent(item.rarity),
                    ),
                  ),
                ),
              if (productionReady && liveCount > 0) ...<Widget>[
                const SizedBox(height: FacilitiesUi.gap),
                FacGoldButton(
                  label: 'Topla ($liveCount)',
                  accentColor: AppColors.toxicNeon,
                  onPressed: (inPrison || isBusy)
                      ? null
                      : () async {
                          final Map<String, dynamic>? result =
                              await ref.read(facilitiesProvider.notifier).collectResourcesV2(
                                    facilityId: facility.id,
                                    expectedCount: liveCount,
                                  );
                          if (!context.mounted) return;
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
                            final String prisonReason =
                                (result['prison_reason'] ?? 'Bilinmiyor').toString();
                            AppMessenger.show(context, '⚠️ Hapse düştün! Gerekçe: $prisonReason');
                          } else {
                            RewardMagnetOverlay.burstToTopWallet(
                              context,
                              kind: RewardMagnetKind.gold,
                              label: '+$count Kaynak Toplandı!',
                            );
                            AppMessenger.show(context, '✅ Toplandı: $count kaynak');
                          }

                          ref.read(playerProvider.notifier).loadProfile();
                          ref.read(inventoryProvider.notifier).loadInventory(silent: true);
                        },
                ),
              ] else if (productionRunning) ...<Widget>[
                const SizedBox(height: FacilitiesUi.gap),
                FacGoldButton(
                  label: 'Bekleyin: ${formatFacilityRemaining(targetAt, now: now)}',
                  onPressed: null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
