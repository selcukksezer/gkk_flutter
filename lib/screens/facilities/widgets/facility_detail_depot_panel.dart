import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/layout/game_screen_background.dart';
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

/// Aion-2 V3 Depo Paneli — High-Tech Depot Inventory Slots, Gold Capacity Meter,
/// Quick Transfer Actions with Tactile Feedback, Glowing Rarity Frames, Slide Animations, Zero Leaks.
class FacDetailDepotPanel extends ConsumerStatefulWidget {
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
  ConsumerState<FacDetailDepotPanel> createState() => _FacDetailDepotPanelState();
}

enum _DepotViewMode { slots, grid }

class _FacDetailDepotPanelState extends ConsumerState<FacDetailDepotPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  bool _isTransferring = false;
  _DepotViewMode _viewMode = _DepotViewMode.slots;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  int get _maxCapacity => 30 + (widget.facility.level * 20);

  double get _fillRatio {
    final int maxCap = _maxCapacity;
    if (maxCap <= 0) return 0.0;
    return (widget.liveCount / maxCap).clamp(0.0, 1.0);
  }

  Future<void> _handleCollectResources() async {
    if (widget.inPrison || widget.isBusy || _isTransferring || widget.liveCount <= 0) {
      return;
    }

    setState(() {
      _isTransferring = true;
    });
    HapticFeedback.heavyImpact();

    try {
      final Map<String, dynamic>? result = await ref
          .read(facilitiesProvider.notifier)
          .collectResourcesV2(
            facilityId: widget.facility.id,
            expectedCount: widget.liveCount,
          );

      if (!mounted) return;

      if (result == null) {
        AppMessenger.showError(
          context,
          ref.read(facilitiesProvider).errorMessage ?? 'Depo aktarımı başarısız oldu.',
        );
        return;
      }

      final bool admitted = result['admission_occurred'] == true;
      final int count = (result['count'] as num?)?.toInt() ?? widget.liveCount;

      if (admitted) {
        final String prisonReason =
            (result['prison_reason'] ?? 'Bilinmiyor').toString();
        AppMessenger.show(
          context,
          '⚠️ Muhafızlar fark etti! Hapse düştün: $prisonReason',
        );
      } else {
        HapticFeedback.mediumImpact();
        AppMessenger.show(
          context,
          '✅ Aktarım Başarılı: $count adet hammadde envantere aktarıldı!',
        );
      }

      ref.read(playerProvider.notifier).loadProfile();
      ref.read(inventoryProvider.notifier).loadInventory(silent: true);
    } finally {
      if (mounted) {
        setState(() {
          _isTransferring = false;
        });
      }
    }
  }

  void _showResourceDetails(FacilityQueueItem item) {
    HapticFeedback.selectionClick();
    final String resName =
        facilityResourceNameByRarity(widget.facilityType, item.rarity);
    final String rarityTitle = facilityRarityTitle(item.rarity);
    final String emoji = facilityRarityEmoji(item.rarity);
    final Color rarityColor = facRarityAccent(item.rarity);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.bgDeep.withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(
                color: rarityColor.withValues(alpha: 0.6),
                width: 1.5,
              ),
              left: BorderSide(
                color: rarityColor.withValues(alpha: 0.3),
                width: 1.0,
              ),
              right: BorderSide(
                color: rarityColor.withValues(alpha: 0.3),
                width: 1.0,
              ),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: rarityColor.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.mutedTitanium.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[
                            rarityColor.withValues(alpha: 0.35),
                            AppColors.carbonVoid.withValues(alpha: 0.8),
                          ],
                        ),
                        border: Border.all(
                          color: rarityColor.withValues(alpha: 0.7),
                          width: 1.5,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: rarityColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            resName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: rarityColor.withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: rarityColor.withValues(alpha: 0.4),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  rarityTitle.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: rarityColor,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Depoda: ${item.quantity} Adet',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.liquidGold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: AppColors.carbonVoid.withValues(alpha: 0.6),
                    border: Border.all(
                      color: AppColors.borderDefault.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: AppColors.accentCyan,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bu hammadde tesis deposunda güvenle muhafaza ediliyor. Toplandığında doğrudan çanta envanterinize işlenecektir.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FacGoldButton(
                  label: 'Kapat',
                  height: 38,
                  accentColor: rarityColor,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGoldCapacityMeter(Color statusColor) {
    final double ratio = _fillRatio;
    final int maxCap = _maxCapacity;
    final int current = widget.liveCount;
    final bool isHigh = ratio >= 0.85;

    final Color meterColor = isHigh
        ? AppColors.coralFlare
        : (ratio >= 0.5 ? AppColors.warningSolar : AppColors.liquidGold);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FacilitiesUi.radiusMd),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.bgCardElevated.withValues(alpha: 0.7),
            AppColors.bgDeep.withValues(alpha: 0.85),
            AppColors.carbonVoid.withValues(alpha: 0.92),
          ],
        ),
        border: Border.all(
          color: AppColors.liquidGold.withValues(alpha: 0.32),
          width: 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.liquidGold.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: <Color>[
                          AppColors.liquidGold,
                          AppColors.goldDim,
                        ],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.liquidGold.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      size: 13,
                      color: AppColors.carbonVoid,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'DEPO KAPASİTE GÖSTERGESİ',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: meterColor.withValues(alpha: 0.14),
                  border: Border.all(
                    color: meterColor.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '$current / $maxCap',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: meterColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Luminous Progress Meter Bar
          Stack(
            children: <Widget>[
              Container(
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: AppColors.darkObsidian.withValues(alpha: 0.5),
                  border: Border.all(
                    color: AppColors.liquidGold.withValues(alpha: 0.2),
                    width: 0.8,
                  ),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: ratio),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (
                  BuildContext context,
                  double animatedRatio,
                  Widget? child,
                ) {
                  return FractionallySizedBox(
                    widthFactor: animatedRatio.clamp(0.01, 1.0),
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        gradient: LinearGradient(
                          colors: <Color>[
                            meterColor.withValues(alpha: 0.85),
                            meterColor,
                            AppColors.goldLight,
                          ],
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: meterColor.withValues(alpha: 0.55),
                            blurRadius: 8,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // Sci-fi tick marks at 25%, 50%, 75%
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    _buildTickMark(),
                    _buildTickMark(),
                    _buildTickMark(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Doluluk Oranı: %${(ratio * 100).toInt()}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
              Row(
                children: <Widget>[
                  Icon(
                    isHigh ? Icons.warning_amber_rounded : Icons.shield_rounded,
                    size: 11,
                    color: isHigh ? AppColors.coralFlare : AppColors.toxicNeon,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isHigh ? 'KAPASİTE SINIRINDA' : 'GÜVENLİ DEPOLAMA',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: isHigh ? AppColors.coralFlare : AppColors.toxicNeon,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTickMark() {
    return Container(
      width: 1.2,
      height: 8,
      color: AppColors.carbonVoid.withValues(alpha: 0.7),
    );
  }

  Widget _buildSlotCard(FacilityQueueItem item, int index) {
    final Color rarityAccent = facRarityAccent(item.rarity);
    final String resName =
        facilityResourceNameByRarity(widget.facilityType, item.rarity);
    final String rarityTitle = facilityRarityTitle(item.rarity);
    final String emoji = facilityRarityEmoji(item.rarity);
    final String slotNumber = (index + 1).toString().padLeft(2, '0');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showResourceDetails(item),
        borderRadius: BorderRadius.circular(10),
        splashColor: rarityAccent.withValues(alpha: 0.15),
        highlightColor: rarityAccent.withValues(alpha: 0.08),
        child: Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.bgDeep.withValues(alpha: 0.88),
                AppColors.carbonVoid.withValues(alpha: 0.94),
              ],
            ),
            border: Border.all(
              color: rarityAccent.withValues(alpha: 0.45),
              width: 1.1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: rarityAccent.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              // Sci-fi compartment indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: rarityAccent.withValues(alpha: 0.1),
                  border: Border.all(
                    color: rarityAccent.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '#$slotNumber',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: rarityAccent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Glowing Item Rarity Medallion
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      rarityAccent.withValues(alpha: 0.28),
                      AppColors.carbonVoid.withValues(alpha: 0.6),
                    ],
                  ),
                  border: Border.all(
                    color: rarityAccent.withValues(alpha: 0.55),
                    width: 1.1,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: rarityAccent.withValues(alpha: 0.25),
                      blurRadius: 6,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(width: 10),
              // Item Name and Rarity Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      resName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: rarityAccent,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rarityTitle,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: rarityAccent,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '• ${widget.productionReady ? "Hazır" : "Depoda"}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Glowing Quantity Counter Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    colors: <Color>[
                      rarityAccent.withValues(alpha: 0.2),
                      rarityAccent.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(
                    color: rarityAccent.withValues(alpha: 0.45),
                    width: 0.9,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: rarityAccent.withValues(alpha: 0.15),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '×${item.quantity}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: rarityAccent,
                        letterSpacing: 0.3,
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

  Widget _buildSlotGridTile(FacilityQueueItem item, int index) {
    final Color rarityAccent = facRarityAccent(item.rarity);
    final String resName =
        facilityResourceNameByRarity(widget.facilityType, item.rarity);
    final String rarityTitle = facilityRarityTitle(item.rarity);
    final String emoji = facilityRarityEmoji(item.rarity);
    final String slotNumber = (index + 1).toString().padLeft(2, '0');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showResourceDetails(item),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.bgDeep.withValues(alpha: 0.9),
                AppColors.carbonVoid.withValues(alpha: 0.96),
              ],
            ),
            border: Border.all(
              color: rarityAccent.withValues(alpha: 0.45),
              width: 1.1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: rarityAccent.withValues(alpha: 0.14),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    '#$slotNumber',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w900,
                      color: rarityAccent,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: rarityAccent.withValues(alpha: 0.15),
                    ),
                    child: Text(
                      '×${item.quantity}',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: rarityAccent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      rarityAccent.withValues(alpha: 0.3),
                      AppColors.carbonVoid.withValues(alpha: 0.7),
                    ],
                  ),
                  border: Border.all(
                    color: rarityAccent.withValues(alpha: 0.5),
                    width: 1.0,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              const SizedBox(height: 4),
              Column(
                children: <Widget>[
                  Text(
                    resName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    rarityTitle,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: rarityAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewModeToggle({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final Color activeColor = AppColors.liquidGold;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: isSelected
                ? activeColor.withValues(alpha: 0.18)
                : AppColors.darkObsidian.withValues(alpha: 0.4),
            border: Border.all(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.6)
                  : AppColors.mutedTitanium.withValues(alpha: 0.2),
              width: 0.8,
            ),
          ),
          child: Icon(
            icon,
            size: 13,
            color: isSelected ? activeColor : AppColors.mutedTitanium,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(Color statusColor) {
    if (widget.productionReady && widget.liveCount > 0) {
      return Column(
        children: <Widget>[
          const SizedBox(height: FacilitiesUi.gapSm),
          FacGoldButton(
            label: _isTransferring
                ? 'Envantere Aktarılıyor...'
                : '⚡ Hızlı Topla & Envantere Aktar (${widget.liveCount})',
            height: 42,
            accentColor: AppColors.toxicNeon,
            onPressed: (widget.inPrison || widget.isBusy || _isTransferring)
                ? null
                : _handleCollectResources,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.touch_app_rounded,
                size: 11,
                color: AppColors.mutedTitanium,
              ),
              const SizedBox(width: 4),
              Text(
                'Ayrıntılı bilgi için bölme kartlarına dokunabilirsiniz.',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedTitanium.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (widget.productionRunning) {
      return Column(
        children: <Widget>[
          const SizedBox(height: FacilitiesUi.gapSm),
          FacGoldButton(
            label:
                '⏳ Üretim Sürüyor: ${formatFacilityRemaining(widget.targetAt, now: widget.now)}',
            height: 40,
            onPressed: null,
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor = widget.productionRunning
        ? AppColors.toxicNeon
        : (widget.productionReady
            ? AppColors.warningSolar
            : AppColors.mutedTitanium);

    final String statusLabel = widget.productionRunning
        ? 'Üretim Sürüyor'
        : (widget.productionReady ? 'Toplanmaya Hazır' : 'Depo');

    final List<FacilityQueueItem> queueItems = widget.hasProductionRecord
        ? widget.preview.toQueueItems(completed: widget.productionReady)
        : widget.facility.facilityQueue;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Section Header with View Mode Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                facilitiesSectionTitle(
                  'Tesis Deposu',
                  trailing: '${widget.liveCount} Eşya',
                ),
                if (queueItems.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _buildViewModeToggle(
                        icon: Icons.view_agenda_rounded,
                        isSelected: _viewMode == _DepotViewMode.slots,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _viewMode = _DepotViewMode.slots);
                        },
                      ),
                      const SizedBox(width: 5),
                      _buildViewModeToggle(
                        icon: Icons.grid_view_rounded,
                        isSelected: _viewMode == _DepotViewMode.grid,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _viewMode = _DepotViewMode.grid);
                        },
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: FacilitiesUi.gapSm),

            // Gold Capacity Meter
            _buildGoldCapacityMeter(statusColor),
            const SizedBox(height: FacilitiesUi.gapSm),

            // Main Frosted Glass Inventory Deck
            FacGridBanner(
              borderColor: statusColor.withValues(alpha: 0.4),
              glowColor: statusColor.withValues(alpha: 0.14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Status Banner Bar
                  Row(
                    children: <Widget>[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: statusColor.withValues(alpha: 0.6),
                              blurRadius: 8,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          statusLabel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: statusColor,
                          ),
                        ),
                      ),
                      if (widget.productionRunning)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: statusColor.withValues(alpha: 0.12),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            formatFacilityRemaining(widget.targetAt, now: widget.now),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                              letterSpacing: 0.2,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: statusColor.withValues(alpha: 0.12),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'Toplam: ${widget.liveCount}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: FacilitiesUi.gap),

                  // Slot Content / Empty / In-Progress States
                  if (widget.liveCount <= 0 && widget.productionRunning)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: AppColors.bgDeep.withValues(alpha: 0.6),
                        border: Border.all(
                          color: AppColors.toxicNeon.withValues(alpha: 0.25),
                          width: 0.9,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              color: AppColors.toxicNeon,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Text(
                                  'Otomatik Üretim Hattı Devrede',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'İşçiler kaynak çıkarıyor. Tamamlandığında doğrudan depoya aktarılacaktır.',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.mutedTitanium.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (widget.liveCount <= 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: AppColors.bgDeep.withValues(alpha: 0.5),
                        border: Border.all(
                          color: AppColors.borderDefault.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        children: <Widget>[
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 28,
                            color: AppColors.mutedTitanium.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Depoda henüz hammadde bulunmuyor.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Genel Bakış sekmesinden üretimi başlatabilirsiniz.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.mutedTitanium.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_viewMode == _DepotViewMode.grid)
                    GameFixedGrid(
                      crossAxisCount: 3,
                      spacing: 6,
                      itemCount: queueItems.length,
                      itemBuilder: (BuildContext context, int index) {
                        return _buildSlotGridTile(queueItems[index], index);
                      },
                    )
                  else
                    ...List<Widget>.generate(
                      queueItems.length,
                      (int index) => _buildSlotCard(queueItems[index], index),
                    ),

                  // Action Buttons
                  _buildActionButtons(statusColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
