import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../models/facility_model.dart';
import '../../../models/facility_production_preview_model.dart';
import '../../../providers/facilities_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../theme/app_colors.dart';
import '../facility_detail_data.dart';
import 'facilities_dialogs.dart';
import 'facilities_ui.dart';
import 'facility_detail_depot_panel.dart';
import 'facility_detail_design.dart';
import 'facility_rarity_simulator.dart';

/// Aion-2 Tesis Detay Genel Bakış Sekmesi (V3 Elevated).
///
/// Lüks Frosted Glass tasarım sistemi, çok katmanlı stat grid, parçacık
/// parıltılı (particle shimmer) kademe gelişim çubuğu, hanedanlık kademe
/// nişanı (tier insignia) ve kutlama animasyonlu yükseltme mekanizması.
class FacDetailOverviewTab extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<FacDetailOverviewTab> createState() =>
      _FacDetailOverviewTabState();
}

class _FacDetailOverviewTabState extends ConsumerState<FacDetailOverviewTab>
    with TickerProviderStateMixin {
  /// Parçacık ve ışıma taraması (particle shimmer sweep) animasyon denetleyicisi.
  late final AnimationController _shimmerController;

  /// Yükseltme kutlama patlaması (celebration burst) animasyon denetleyicisi.
  late final AnimationController _celebrationController;

  /// Çift tıklama ve asenkron yarış durumlarını önleyen yerel işlem bayrağı.
  bool _isActionInProgress = false;

  /// Kutlama görsel efektinin aktif olup olmadığı.
  bool _showCelebration = false;

  bool get _canStartProduction =>
      !widget.hasProductionRecord &&
      !widget.inPrison &&
      widget.energy >= 50 &&
      !widget.isBusy &&
      !_isActionInProgress;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _celebrationController.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _showCelebration = false);
      }
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  void _triggerCelebration() {
    if (!mounted) return;
    setState(() => _showCelebration = true);
    _celebrationController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final List<String> previewLabels = widget.preview.items
        .map((FacilityProductionItem item) =>
            '${facilityResourceNameByRarity(widget.facilityType, item.rarity)} ×${item.quantity}')
        .toList();

    final _FacilityTierInfo tierInfo =
        _FacilityTierInfo.fromLevel(widget.facility.level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 1. Üretim Durum Paneli (Production Banner)
        if (!widget.hasProductionRecord)
          FacProductionBanner(
            isRunning: false,
            remainingLabel:
                formatFacilityRemaining(widget.targetAt, now: widget.now),
            previewItems: previewLabels,
            startEnabled: _canStartProduction,
            startLabel: widget.energy < 50
                ? '50⚡ Enerji Gerekli'
                : (_isActionInProgress ? 'Başlatılıyor...' : '⚡ Üretimi Başlat'),
            onStart: _canStartProduction ? () => _startProduction(context) : null,
          )
        else
          FacProductionBanner(
            isRunning: true,
            remainingLabel: widget.productionReady
                ? 'Toplamaya Hazır'
                : formatFacilityRemaining(widget.targetAt, now: widget.now),
            previewItems: previewLabels,
            startEnabled: false,
            startLabel: '',
            onStart: null,
          ),

        const SizedBox(height: FacilitiesUi.gapSm),

        // 2. Overview Stat Grid — 4x Bento Kartları
        _FacilityOverviewStatGrid(
          meta: widget.meta,
          facility: widget.facility,
          liveCount: widget.liveCount,
          hasProductionRecord: widget.hasProductionRecord,
          productionReady: widget.productionReady,
          tierInfo: tierInfo,
        ),

        const SizedBox(height: FacilitiesUi.gapSm),

        // 3. Tesis Hanedanlık Kademe Nişanı (Tier Insignia)
        _FacilityTierInsignia(
          tierInfo: tierInfo,
          facilityLevel: widget.facility.level,
        ),

        const SizedBox(height: FacilitiesUi.gapSm),

        // 4. Parçacık Parıltılı Kademe Gelişim Çubuğu (Upgrade Progress Bar with Particle Shimmer)
        _UpgradeProgressBarWithShimmer(
          level: widget.facility.level,
          shimmerAnimation: _shimmerController,
          tierColor: tierInfo.accentColor,
        ),

        // 5. Devam Eden Üretim Depo Paneli (Varsa)
        if (widget.hasProductionRecord) ...<Widget>[
          const SizedBox(height: FacilitiesUi.gapSm),
          FacDetailDepotPanel(
            facilityType: widget.facilityType,
            facility: widget.facility,
            inPrison: widget.inPrison,
            productionRunning: widget.productionRunning,
            productionReady: widget.productionReady,
            targetAt: widget.targetAt,
            liveCount: widget.liveCount,
            preview: widget.preview,
            hasProductionRecord: widget.hasProductionRecord,
            isBusy: widget.isBusy,
            now: widget.now,
          ),
        ],

        const SizedBox(height: FacilitiesUi.gap),

        // 6. Frosted Glass Resource Pool (Kaynak Havuzu)
        FacGlassPanel(
          padding: const EdgeInsets.all(12),
          borderRadius: FacilitiesUi.radiusMd,
          borderColor: AppColors.liquidGold.withValues(alpha: 0.28),
          glowColor: AppColors.liquidGold.withValues(alpha: 0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              facilitiesSectionTitle(
                'Kaynak Havuzu',
                trailing: 'Lv.${widget.facility.level}',
              ),
              const SizedBox(height: FacilitiesUi.gapSm),
              GameFixedGrid(
                crossAxisCount: 3,
                spacing: 6,
                itemCount: widget.meta?.resources.length ?? 0,
                itemBuilder: (BuildContext context, int index) {
                  final String name = widget.meta!.resources[index];
                  final String rarity = index < kFacilityResourceRarities.length
                      ? kFacilityResourceRarities[index]
                      : 'common';
                  final Map<String, int> weights =
                      facilityRarityWeightsAtLevel(widget.facility.level);
                  final int total = weights.values
                      .fold<int>(0, (int sum, int v) => sum + v);
                  final int unlockLevel =
                      kFacilityRarityUnlockLevels[rarity] ?? 1;
                  final bool isUnlocked = widget.facility.level >= unlockLevel;
                  final double percent = total > 0
                      ? ((weights[rarity] ?? 0) / total) * 100
                      : 0;

                  return FacResourceCell(
                    emoji: facilityRarityEmoji(rarity),
                    name: name,
                    percentLabel: isUnlocked
                        ? '%${percent.toStringAsFixed(0)}'
                        : '🔒 Lv.$unlockLevel',
                    accentColor: facRarityAccent(rarity),
                    locked: !isUnlocked,
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: FacilitiesUi.gap),

        // 7. Nadir Seviye Simülatörü Akordeonu
        FacRaritySimulatorAccordion(currentLevel: widget.facility.level),

        const SizedBox(height: FacilitiesUi.gap),

        // 8. Kutlama Butonlu Yükseltme Güvertesi (Level Up Celebration Deck)
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            _CelebrationUpgradeDeck(
              facilityLevel: widget.facility.level,
              upgradeCost: widget.upgradeCost,
              canUpgrade: widget.canUpgrade,
              inPrison: widget.inPrison,
              isBusy: widget.isBusy || _isActionInProgress,
              hasProductionRecord: widget.hasProductionRecord,
              tierInfo: tierInfo,
              onUpgrade: () => _showUpgradeDialog(
                context,
                facilityId: widget.facility.id,
                name: widget.meta?.name ?? widget.facilityType,
                currentLevel: widget.facility.level,
                upgradeCost: widget.upgradeCost,
              ),
            ),
            if (_showCelebration)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _celebrationController,
                    builder: (BuildContext context, Widget? child) {
                      return CustomPaint(
                        painter: _CelebrationBurstPainter(
                          progress: _celebrationController.value,
                          accentColor: tierInfo.accentColor,
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),

        // 9. Üretim Kilidi Bilgilendirme Çubuğu
        if (widget.hasProductionRecord)
          Padding(
            padding: const EdgeInsets.only(top: FacilitiesUi.gapSm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppColors.warningSolar.withValues(alpha: 0.1),
                border: Border.all(
                  color: AppColors.warningSolar.withValues(alpha: 0.32),
                  width: 0.8,
                ),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: AppColors.warningSolar,
                  ),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Tesis yükseltmesi yapabilmek için devam eden üretimi tamamlayıp depodan toplayın.',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warningSolar,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Güvenli asenkron üretim başlatma mekanizması.
  Future<void> _startProduction(BuildContext context) async {
    if (!_canStartProduction) return;

    setState(() => _isActionInProgress = true);
    HapticFeedback.lightImpact();

    try {
      final bool ok =
          await ref.read(facilitiesProvider.notifier).startProduction(
                facilityId: widget.facility.id,
              );

      if (!mounted || !context.mounted) return;

      AppMessenger.show(
        context,
        ok
            ? '⚡ Üretim başarıyla başlatıldı!'
            : (ref.read(facilitiesProvider).errorMessage ??
                'Üretim başlatılamadı'),
      );

      if (ok) {
        await ref.read(playerProvider.notifier).loadProfile();
      }
    } finally {
      if (mounted) {
        setState(() => _isActionInProgress = false);
      }
    }
  }

  /// Güvenli asenkron kademe yükseltme ve kutlama mekanizması.
  Future<void> _showUpgradeDialog(
    BuildContext context, {
    required String facilityId,
    required String name,
    required int currentLevel,
    required int upgradeCost,
  }) async {
    if (_isActionInProgress) return;

    setState(() => _isActionInProgress = true);
    HapticFeedback.selectionClick();

    try {
      final bool confirm = await showFacUpgradeDialog(
        context,
        facilityName: name,
        targetLevel: currentLevel + 1,
        formattedCost: formatFacilityGold(upgradeCost),
      );

      if (!confirm || !mounted || !context.mounted) return;

      final bool ok = await ref
          .read(facilitiesProvider.notifier)
          .upgradeFacility(facilityId: facilityId);

      if (!mounted || !context.mounted) return;

      if (ok) {
        _triggerCelebration();
        HapticFeedback.heavyImpact();
        AppMessenger.show(
          context,
          '🎉 $name başarıyla Lv.${currentLevel + 1} seviyesine yükseltildi!',
        );
        await ref.read(playerProvider.notifier).loadProfile();
      } else {
        AppMessenger.show(
          context,
          ref.read(facilitiesProvider).errorMessage ??
              'Yükseltme işlemi tamamlanamadı',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActionInProgress = false);
      }
    }
  }
}

// =============================================================================
// SUB-WIDGETS & DESIGN FOUNDATIONS
// =============================================================================

/// Tesis kademe (Tier) modelleme ve meta-özellikleri.
class _FacilityTierInfo {
  const _FacilityTierInfo({
    required this.tierNumber,
    required this.romanNumeral,
    required this.title,
    required this.accentColor,
    required this.glowColor,
    required this.icon,
    required this.perkDescription,
    required this.nextMilestoneLabel,
  });

  final int tierNumber;
  final String romanNumeral;
  final String title;
  final Color accentColor;
  final Color glowColor;
  final IconData icon;
  final String perkDescription;
  final String nextMilestoneLabel;

  factory _FacilityTierInfo.fromLevel(int level) {
    if (level <= 2) {
      return const _FacilityTierInfo(
        tierNumber: 1,
        romanNumeral: 'I',
        title: 'Bronz Çırak',
        accentColor: Color(0xFFD49B6A),
        glowColor: Color(0x33D49B6A),
        icon: Icons.shield_outlined,
        perkDescription: 'Temel verimlilik ve standart hammadde toplama sahası.',
        nextMilestoneLabel: 'Sonraki Kademe: Lv.3 (Gümüş Zanaatkar)',
      );
    } else if (level <= 4) {
      return const _FacilityTierInfo(
        tierNumber: 2,
        romanNumeral: 'II',
        title: 'Gümüş Zanaatkar',
        accentColor: Color(0xFF64D2FF),
        glowColor: Color(0x3364D2FF),
        icon: Icons.military_tech_outlined,
        perkDescription:
            'Sıradışı kaynak damarları açıldı (+%15 Üretim Verimi).',
        nextMilestoneLabel: 'Sonraki Kademe: Lv.5 (Altın Muhafız)',
      );
    } else if (level <= 6) {
      return const _FacilityTierInfo(
        tierNumber: 3,
        romanNumeral: 'III',
        title: 'Altın Muhafız',
        accentColor: AppColors.liquidGold,
        glowColor: Color(0x33F5C842),
        icon: Icons.workspace_premium_outlined,
        perkDescription:
            'Nadir maden damarları ve cevherler çıkarılabilir (+%30 Verim).',
        nextMilestoneLabel: 'Sonraki Kademe: Lv.7 (Obsidyen Lordu)',
      );
    } else if (level <= 8) {
      return const _FacilityTierInfo(
        tierNumber: 4,
        romanNumeral: 'IV',
        title: 'Obsidyen Lordu',
        accentColor: AppColors.cyberFuchsia,
        glowColor: Color(0x33F82B8C),
        icon: Icons.diamond_outlined,
        perkDescription:
            'Epik esanslar ve kristal cevherleri aktif edildi (+%50 Verim).',
        nextMilestoneLabel: 'Sonraki Kademe: Lv.9 (Mitik Hükümdar)',
      );
    } else {
      return const _FacilityTierInfo(
        tierNumber: 5,
        romanNumeral: 'V',
        title: 'Mitik Hükümdar',
        accentColor: AppColors.coralFlare,
        glowColor: Color(0x33FF5A36),
        icon: Icons.auto_awesome_rounded,
        perkDescription:
            'Azami kademe: Efsanevi & Mitik hazine damarları açık (+%80 Verim)!',
        nextMilestoneLabel: '👑 Azami Hükümdar Kademesine Ulaşıldı',
      );
    }
  }
}

/// Aion-2 4x Bento İstatistik Kartları Izgarası.
class _FacilityOverviewStatGrid extends StatelessWidget {
  const _FacilityOverviewStatGrid({
    required this.meta,
    required this.facility,
    required this.liveCount,
    required this.hasProductionRecord,
    required this.productionReady,
    required this.tierInfo,
  });

  final FacilityMeta? meta;
  final PlayerFacility facility;
  final int liveCount;
  final bool hasProductionRecord;
  final bool productionReady;
  final _FacilityTierInfo tierInfo;

  @override
  Widget build(BuildContext context) {
    final double baseRate = meta?.baseRate ?? 10.0;
    final double currentRate = baseRate * (1.0 + (facility.level - 1) * 0.25);

    return GameFixedGrid(
      crossAxisCount: 2,
      spacing: 8,
      itemCount: 4,
      itemBuilder: (BuildContext context, int index) {
        switch (index) {
          case 0:
            return _StatBentoCard(
              title: 'Üretim Hızı',
              value: '${currentRate.toStringAsFixed(1)} /dk',
              subtitle: 'Temel Çıkarım Debisi',
              icon: Icons.speed_rounded,
              accentColor: AppColors.toxicNeon,
            );
          case 1:
            return _StatBentoCard(
              title: 'Depo Envanteri',
              value: '$liveCount Eşya',
              subtitle: hasProductionRecord
                  ? (productionReady ? 'Toplanmaya Hazır' : 'Üretim Devam Ediyor')
                  : 'Boşta / Bekliyor',
              icon: Icons.inventory_2_outlined,
              accentColor: productionReady
                  ? AppColors.toxicNeon
                  : (hasProductionRecord
                      ? AppColors.accentCyan
                      : AppColors.mutedTitanium),
            );
          case 2:
            final bool highRisk = facility.suspicion > 50;
            final bool midRisk = facility.suspicion > 25;
            final Color riskColor = highRisk
                ? AppColors.coralFlare
                : (midRisk ? AppColors.warningSolar : AppColors.toxicNeon);
            return _StatBentoCard(
              title: 'Şüphe Derecesi',
              value: '%${facility.suspicion}',
              subtitle: highRisk
                  ? '⚠️ Yüksek Risk'
                  : (midRisk ? 'Orta Gözetim' : 'Güvenli Bölge'),
              icon: Icons.visibility_outlined,
              accentColor: riskColor,
            );
          case 3:
          default:
            return _StatBentoCard(
              title: 'Kademe Seviyesi',
              value: 'Tier ${tierInfo.romanNumeral}',
              subtitle: 'Lv.${facility.level} • ${tierInfo.title}',
              icon: tierInfo.icon,
              accentColor: tierInfo.accentColor,
            );
        }
      },
    );
  }
}

/// Tekil Bento İstatistik Kartı.
class _StatBentoCard extends StatelessWidget {
  const _StatBentoCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FacilitiesUi.radiusMd),
        color: AppColors.bgDeep.withValues(alpha: 0.75),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.32),
          width: 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.mutedTitanium,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: 0.2,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: accentColor.withValues(alpha: 0.9),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Tesis Hanedanlık Kademe Nişanı (Tier Insignia).
class _FacilityTierInsignia extends StatelessWidget {
  const _FacilityTierInsignia({
    required this.tierInfo,
    required this.facilityLevel,
  });

  final _FacilityTierInfo tierInfo;
  final int facilityLevel;

  @override
  Widget build(BuildContext context) {
    return FacGlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: FacilitiesUi.radiusMd,
      borderColor: tierInfo.accentColor.withValues(alpha: 0.42),
      glowColor: tierInfo.glowColor,
      child: Row(
        children: <Widget>[
          // Regal Ornate Medallion
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  tierInfo.accentColor.withValues(alpha: 0.28),
                  AppColors.darkObsidian.withValues(alpha: 0.70),
                ],
              ),
              border: Border.all(
                color: tierInfo.accentColor.withValues(alpha: 0.65),
                width: 1.5,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: tierInfo.accentColor.withValues(alpha: 0.30),
                  blurRadius: 10,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              tierInfo.icon,
              size: 22,
              color: tierInfo.accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'KADEME ${tierInfo.romanNumeral} • ${tierInfo.title.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: tierInfo.accentColor,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(FacilitiesUi.radiusPill),
                        color: tierInfo.accentColor.withValues(alpha: 0.15),
                        border: Border.all(
                          color: tierInfo.accentColor.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'Lv.$facilityLevel',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: tierInfo.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  tierInfo.perkDescription,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.mutedTitanium,
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
}

/// Parçacık Parıltılı Kademe Gelişim Çubuğu.
class _UpgradeProgressBarWithShimmer extends StatelessWidget {
  const _UpgradeProgressBarWithShimmer({
    required this.level,
    required this.shimmerAnimation,
    required this.tierColor,
  });

  final int level;
  final Animation<double> shimmerAnimation;
  final Color tierColor;

  @override
  Widget build(BuildContext context) {
    final double progress = (level / 10.0).clamp(0.0, 1.0);

    return FacGlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: FacilitiesUi.radiusMd,
      borderColor: tierColor.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'TESİS GELİŞİM DERECESİ',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Lv.$level / 10 (%${(progress * 100).toInt()})',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: tierColor,
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Animated Canvas Shimmer Progress Bar
          AnimatedBuilder(
            animation: shimmerAnimation,
            builder: (BuildContext context, Widget? child) {
              return CustomPaint(
                size: const Size(double.infinity, 12),
                painter: _ParticleShimmerBarPainter(
                  progress: progress,
                  shimmerValue: shimmerAnimation.value,
                  accentColor: tierColor,
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          // Milestone tick markers
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Lv.1 Çırak',
                  style: TextStyle(fontSize: 8.5, color: AppColors.mutedTitanium)),
              Text('Lv.3 Sıradışı',
                  style: TextStyle(fontSize: 8.5, color: AppColors.mutedTitanium)),
              Text('Lv.5 Nadir',
                  style: TextStyle(fontSize: 8.5, color: AppColors.mutedTitanium)),
              Text('Lv.7 Epik',
                  style: TextStyle(fontSize: 8.5, color: AppColors.mutedTitanium)),
              Text('Lv.9 Efsanevi',
                  style: TextStyle(fontSize: 8.5, color: AppColors.mutedTitanium)),
              Text('Lv.10 Mitik',
                  style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.liquidGold)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Parçacık parıltılı gelişim çubuğu CustomPainter'ı.
class _ParticleShimmerBarPainter extends CustomPainter {
  const _ParticleShimmerBarPainter({
    required this.progress,
    required this.shimmerValue,
    required this.accentColor,
  });

  final double progress;
  final double shimmerValue;
  final Color accentColor;

  static const List<double> _particleSeeds = <double>[
    0.10, 0.25, 0.42, 0.55, 0.68, 0.82, 0.91, 0.33
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final RRect trackRRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height * 0.5),
    );

    // 1. Koyu arka plan rayı
    final Paint trackPaint = Paint()
      ..color = AppColors.carbonVoid.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(trackRRect, trackPaint);

    final Paint trackBorder = Paint()
      ..color = accentColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    canvas.drawRRect(trackRRect, trackBorder);

    if (progress <= 0.0) return;

    // 2. Dolu ilerleme alanı (Clip ile kavis koruma)
    final double filledWidth = size.width * progress;
    final RRect filledRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, filledWidth, size.height),
      Radius.circular(size.height * 0.5),
    );

    canvas.save();
    canvas.clipRRect(filledRRect);

    // Ana degrade dolgu
    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          accentColor.withValues(alpha: 0.65),
          accentColor,
          AppColors.liquidGold,
        ],
      ).createShader(Rect.fromLTWH(0, 0, filledWidth, size.height));
    canvas.drawPaint(fillPaint);

    // Parıltı taraması (Shimmer Light Sweep)
    final double sweepX = -80 + (filledWidth + 160) * shimmerValue;
    final Paint shimmerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          Colors.transparent,
          Colors.white.withValues(alpha: 0.55),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(sweepX, 0, 70, size.height));
    canvas.drawRect(Rect.fromLTWH(sweepX, 0, 70, size.height), shimmerPaint);

    // Yüzen Parçacık Kıvılcımları (Sparkling Particle Glints)
    if (filledWidth < 6.0) {
      canvas.restore();
      return;
    }

    final Paint sparkPaint = Paint()..color = Colors.white;
    for (int i = 0; i < _particleSeeds.length; i++) {
      final double seed = _particleSeeds[i];
      final double pX = (seed * filledWidth +
              math.sin((shimmerValue * 2 * math.pi) + (i * 0.8)) * 14)
          .clamp(2.0, filledWidth - 2.0);
      final double pY = (size.height * 0.5) +
          math.cos((shimmerValue * 2 * math.pi) + (i * 1.1)) *
              (size.height * 0.28);
      final double radius = 0.8 + ((i % 3) * 0.4);

      canvas.drawCircle(Offset(pX, pY), radius, sparkPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ParticleShimmerBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.shimmerValue != shimmerValue ||
        oldDelegate.accentColor != accentColor;
  }
}

/// Kutlama Butonlu Yükseltme Güvertesi (Level Up Celebration Deck).
class _CelebrationUpgradeDeck extends StatelessWidget {
  const _CelebrationUpgradeDeck({
    required this.facilityLevel,
    required this.upgradeCost,
    required this.canUpgrade,
    required this.inPrison,
    required this.isBusy,
    required this.hasProductionRecord,
    required this.tierInfo,
    required this.onUpgrade,
  });

  final int facilityLevel;
  final int upgradeCost;
  final bool canUpgrade;
  final bool inPrison;
  final bool isBusy;
  final bool hasProductionRecord;
  final _FacilityTierInfo tierInfo;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final bool isMaxLevel = facilityLevel >= 10;
    final bool isActionable =
        canUpgrade && !inPrison && !isBusy && !hasProductionRecord;

    String buttonLabel;
    if (isMaxLevel) {
      buttonLabel = '🏆 AZAMİ SEVİYE (Lv.10)';
    } else if (hasProductionRecord) {
      buttonLabel = '⏳ Üretim Bitmeli';
    } else if (inPrison) {
      buttonLabel = '⚖️ Hapiste Yapılamaz';
    } else if (!canUpgrade) {
      buttonLabel = '💰 Yetersiz Altın';
    } else {
      buttonLabel = '⬆️ Lv.${facilityLevel + 1} Yükselt';
    }

    final String summary = isMaxLevel
        ? 'Tesis Azami Zirve Gücünde (Lv.10 Mitik Hükümdar)'
        : 'Gelecek Seviye: Lv.${facilityLevel + 1} • ${formatFacilityGold(upgradeCost)} 💰 Altın';

    return FacGridBanner(
      borderColor: isActionable
          ? tierInfo.accentColor.withValues(alpha: 0.6)
          : AppColors.mutedTitanium.withValues(alpha: 0.3),
      glowColor: isActionable
          ? tierInfo.glowColor
          : Colors.transparent,
      gradientColors: <Color>[
        isActionable
            ? tierInfo.accentColor.withValues(alpha: 0.16)
            : const Color(0xCC1A1A1A),
        AppColors.bgDeep.withValues(alpha: 0.92),
        AppColors.carbonVoid,
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActionable
                      ? tierInfo.accentColor.withValues(alpha: 0.20)
                      : AppColors.darkObsidian.withValues(alpha: 0.6),
                  border: Border.all(
                    color: isActionable
                        ? tierInfo.accentColor.withValues(alpha: 0.55)
                        : AppColors.mutedTitanium.withValues(alpha: 0.3),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  isMaxLevel ? '👑' : '⬆️',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      summary,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tierInfo.nextMilestoneLabel,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: isActionable
                            ? tierInfo.accentColor
                            : AppColors.mutedTitanium,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isMaxLevel)
                SizedBox(
                  width: 115,
                  child: FacGoldButton(
                    label: buttonLabel,
                    height: 36,
                    accentColor: isActionable
                        ? tierInfo.accentColor
                        : AppColors.mutedTitanium,
                    onPressed: isActionable ? onUpgrade : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Yükseltme Başarısı Kutlama Parçacık Patlaması (Celebration Burst Painter).
class _CelebrationBurstPainter extends CustomPainter {
  const _CelebrationBurstPainter({
    required this.progress,
    required this.accentColor,
  });

  final double progress;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final Offset center = Offset(size.width * 0.88, size.height * 0.5);
    final double maxRadius = 55.0 * progress;
    final double opacity = (1.0 - progress).clamp(0.0, 1.0);

    const int rayCount = 12;
    for (int i = 0; i < rayCount; i++) {
      final double angle = (i * (2 * math.pi / rayCount)) + (progress * 0.6);
      final double distance = maxRadius * (0.6 + ((i % 3) * 0.2));
      final Offset sparkPos = center +
          Offset(math.cos(angle) * distance, math.sin(angle) * distance);

      final Color sparkColor = (i % 2 == 0) ? accentColor : AppColors.liquidGold;
      final Paint p = Paint()
        ..color = sparkColor.withValues(alpha: opacity * 0.85)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(sparkPos, 2.2 * (1.0 - progress * 0.5), p);
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationBurstPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accentColor != accentColor;
  }
}

