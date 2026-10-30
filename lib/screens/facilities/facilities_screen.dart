import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_chrome.dart';
import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_controller.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../core/utils/character_class_abilities.dart';
import '../../models/facility_model.dart';
import '../../models/player_model.dart';
import '../../providers/facilities_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../utils/logout_helper.dart';
import 'facility_detail_data.dart';
import 'widgets/facilities_dialogs.dart';
import 'widgets/facilities_hub_design.dart';
import 'widgets/facilities_ui.dart';
import 'widgets/facility_3d_hub_showcase.dart';
import 'widgets/facility_hub_cards.dart';

/// Durum Filtresi Seçenekleri
enum FacilityStatusFilter {
  all('Tümü', null),
  unlocked('Açık', AppColors.toxicNeon),
  producing('Üretimde', AppColors.accentCyan),
  canUnlock('Açılabilir', AppColors.liquidGold),
  locked('Kilitli', AppColors.mutedTitanium);

  const FacilityStatusFilter(this.label, this.color);
  final String label;
  final Color? color;
}

/// Aion-2 Tesisler Ana Ekranı — 2027 AAA Mobile Dark Fantasy Standards.
class FacilitiesScreen extends ConsumerStatefulWidget {
  const FacilitiesScreen({super.key});

  @override
  ConsumerState<FacilitiesScreen> createState() => _FacilitiesScreenState();
}

class _FacilitiesScreenState extends ConsumerState<FacilitiesScreen> {
  String _selectedCategory = 'all';
  FacilityStatusFilter _selectedStatus = FacilityStatusFilter.all;
  String _previewFacilityType = 'tahil_ambari';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playerProvider.notifier).loadProfile();
      ref.read(facilitiesProvider.notifier).loadFacilities();
    });
  }

  double _calculateFacilityRate(String type, int level) {
    final FacilityMeta? meta = facilityMetaFor(type);
    final double base = meta?.baseRate ?? 10.0;
    return base * (1 + (level - 1) * 0.2);
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final facilitiesState = ref.watch(facilitiesProvider);
    final profile = playerState.profile;
    final int level = profile?.level ?? 1;
    final int gold = profile?.gold ?? 0;
    final double gems = profile?.gems ?? 0;
    final int globalSuspicion = effectiveSuspicionLevel(profile);
    final int bribeGemCost = bribeGemCostForClass(profile?.characterClass);
    final int suspicionCap =
        profile?.characterClass == CharacterClass.shadow ? 80 : 100;
    final bool inPrison = _isFuture(profile?.prisonUntil);
    final String prisonReason =
        (profile?.prisonReason == null || profile!.prisonReason!.trim().isEmpty)
            ? 'Bilinmiyor'
            : profile.prisonReason!;

    final Map<String, PlayerFacility> unlockedByType = <String, PlayerFacility>{
      for (final facility in facilitiesState.facilities)
        facility.facilityType: facility,
    };

    final List<_TierGroup> tiers = const <_TierGroup>[
      _TierGroup(
        tier: 1,
        label: 'Kademe 1 — Başlangıç Tesisleri',
        facilities: _basicFacilities,
      ),
      _TierGroup(
        tier: 2,
        label: 'Kademe 2 — Gelişmiş Tesisler',
        facilities: _organicFacilities,
      ),
      _TierGroup(
        tier: 3,
        label: 'Kademe 3 — İleri ve Mistik Tesisler',
        facilities: _mysticalFacilities,
      ),
    ];

    // Toplam istatistikler ve gelir hesaplaması
    double totalRevenueRate = 0.0;
    int producingCount = 0;
    int readyCollectCount = 0;

    for (final facility in unlockedByType.values) {
      totalRevenueRate += _calculateFacilityRate(
        facility.facilityType,
        facility.level,
      );
      if (facility.productionStartedAt != null &&
          facility.productionStartedAt!.isNotEmpty) {
        producingCount++;
      }
      final int completed =
          facility.facilityQueue.where((q) => q.isCompleted).length;
      if (completed > 0) {
        readyCollectCount += completed;
      }
    }

    // Kademe filtresi uygulama
    final List<_TierGroup> filteredTiers = tiers.where((_TierGroup group) {
      if (_selectedCategory == 'tier_1' && group.tier != 1) return false;
      if (_selectedCategory == 'tier_2' && group.tier != 2) return false;
      if (_selectedCategory == 'tier_3' && group.tier != 3) return false;
      return true;
    }).toList();

    return Scaffold(
      appBar: GameTopBar(
        title: 'Tesisler',
        onLogout: () async {
          await performLogout(ref);
        },
      ),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.facilities,
        onLogout: () async {
          await performLogout(ref);
        },
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: facilitiesScreenShell(
          child: switch (facilitiesState.status) {
            FacilitiesStatus.initial || FacilitiesStatus.loading => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(
                    color: AppColors.liquidGold,
                    strokeWidth: 2,
                  ),
                ),
              ),
            FacilitiesStatus.error => facilitiesErrorPanel(
                message:
                    facilitiesState.errorMessage ?? 'Tesisler yüklenemedi',
                onRetry: () =>
                    ref.read(facilitiesProvider.notifier).loadFacilities(),
              ),
            FacilitiesStatus.ready => RefreshIndicator(
                color: AppColors.liquidGold,
                backgroundColor: AppColors.carbonVoid,
                onRefresh: () async {
                  await Future.wait(<Future<void>>[
                    ref.read(playerProvider.notifier).loadProfile(),
                    ref.read(facilitiesProvider.notifier).loadFacilities(),
                  ]);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: FacilitiesUi.scrollPadding(context),
                  children: <Widget>[
                    if (inPrison) FacPrisonBanner(reason: prisonReason),
                    FacSuspicionPanel(
                      activeCount: unlockedByType.length,
                      globalSuspicion: globalSuspicion,
                      suspicionCap: suspicionCap,
                      bribeGemCost: bribeGemCost,
                      bribeDisabled: gems < bribeGemCost ||
                          inPrison ||
                          globalSuspicion <= 0,
                      onBribe: () => _handleBribe(
                        facilitiesState,
                        gems,
                        bribeGemCost,
                      ),
                    ),
                    Facility3dHubShowcase(
                      selectedType: _previewFacilityType,
                      unlockedByType: unlockedByType,
                      onFacilitySelected: (String type) {
                        setState(() => _previewFacilityType = type);
                      },
                      onInspectTap: () {
                        context.go(AppRoutes.facilityDetail(_previewFacilityType));
                      },
                    ),
                    const SizedBox(height: FacilitiesUi.gap),
                    _buildRevenueHeroCard(
                      unlockedCount: unlockedByType.length,
                      totalCount: 15,
                      totalRevenueRate: totalRevenueRate,
                      producingCount: producingCount,
                      readyCollectCount: readyCollectCount,
                    ),
                    if (readyCollectCount > 0)
                      _buildReadyNotice(readyCollectCount),
                    _buildFilterBar(),
                    ..._buildTierSections(
                      tiers: filteredTiers,
                      level: level,
                      gold: gold,
                      inPrison: inPrison,
                      unlockedByType: unlockedByType,
                    ),
                  ],
                ),
              ),
          },
        ),
      ),
    );
  }

  Widget _buildRevenueHeroCard({
    required int unlockedCount,
    required int totalCount,
    required double totalRevenueRate,
    required int producingCount,
    required int readyCollectCount,
  }) {
    final double progress = totalCount > 0
        ? (unlockedCount / totalCount).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: FacilitiesUi.gap),
      child: FacGlassPanel(
        borderColor: AppColors.liquidGold.withValues(alpha: 0.35),
        glowColor: AppColors.liquidGold.withValues(alpha: 0.12),
        padding: const EdgeInsets.all(14),
        borderRadius: FacilitiesUi.radiusLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: FacHubDesign.goldGradient,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.liquidGold.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text('🏛️', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'TESİS GELİR & YÖNETİM MERKEZİ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pasif Kaynak & Malzeme Üretimi',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.liquidGold.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: AppColors.liquidGold.withValues(alpha: 0.14),
                    border: Border.all(
                      color: AppColors.liquidGold.withValues(alpha: 0.4),
                      width: 0.9,
                    ),
                  ),
                  child: Text(
                    '$unlockedCount / $totalCount AÇIK',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.liquidGold,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _buildMetricTile(
                    label: 'TAHMİNİ GELİR',
                    value: '+${totalRevenueRate.toStringAsFixed(0)} /dk',
                    icon: '⚡',
                    color: AppColors.toxicNeon,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    label: 'AKTİF ÜRETİM',
                    value: '$producingCount Tesis',
                    icon: '⚙️',
                    color: AppColors.accentCyan,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    label: 'HAZIR TESLİMAT',
                    value: readyCollectCount > 0
                        ? '$readyCollectCount Adet'
                        : 'Bekleniyor',
                    icon: '📦',
                    color: readyCollectCount > 0
                        ? AppColors.liquidGold
                        : AppColors.mutedTitanium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'İmparatorluk Tesis Kapasitesi',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mutedTitanium.withValues(alpha: 0.9),
                      ),
                    ),
                    Text(
                      '%${(progress * 100).toInt()}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.liquidGold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Stack(
                  children: <Widget>[
                    Container(
                      height: 5,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: AppColors.darkObsidian.withValues(alpha: 0.8),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: FacHubDesign.goldGradient,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color:
                                  AppColors.liquidGold.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FacilitiesUi.radiusSm),
        color: AppColors.bgDeep.withValues(alpha: 0.65),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(icon, style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mutedTitanium.withValues(alpha: 0.85),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyNotice(int readyCollectCount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FacilitiesUi.gapSm),
      child: FacGlassPanel(
        borderColor: AppColors.toxicNeon.withValues(alpha: 0.5),
        glowColor: AppColors.toxicNeon.withValues(alpha: 0.2),
        backgroundColor: const Color(0x990A1A12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        borderRadius: FacilitiesUi.radiusMd,
        child: Row(
          children: <Widget>[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.toxicNeon.withValues(alpha: 0.18),
                border: Border.all(
                  color: AppColors.toxicNeon.withValues(alpha: 0.5),
                ),
              ),
              alignment: Alignment.center,
              child: const Text('🎁', style: TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$readyCollectCount tesiste toplanabilir kaynak hazır! İlgili tesise dokunarak envanterine aktar.',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: FacilitiesUi.gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          facilitiesSegmentTabs(
            activeId: _selectedCategory,
            tabs: const <FacilitiesTabOption>[
              (id: 'all', label: 'Tümü'),
              (id: 'tier_1', label: 'Kademe 1'),
              (id: 'tier_2', label: 'Kademe 2'),
              (id: 'tier_3', label: 'Kademe 3'),
            ],
            onChanged: (String id) {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategory = id);
            },
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: FacilityStatusFilter.values
                  .map((FacilityStatusFilter filter) {
                final bool isSelected = _selectedStatus == filter;
                final Color chipColor = filter.color ?? AppColors.liquidGold;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedStatus = filter);
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: isSelected
                              ? chipColor.withValues(alpha: 0.18)
                              : AppColors.bgDeep.withValues(alpha: 0.5),
                          border: Border.all(
                            color: isSelected
                                ? chipColor
                                : AppColors.mutedTitanium
                                    .withValues(alpha: 0.25),
                            width: isSelected ? 1.2 : 0.8,
                          ),
                          boxShadow: isSelected
                              ? <BoxShadow>[
                                  BoxShadow(
                                    color: chipColor.withValues(alpha: 0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (filter.color != null) ...<Widget>[
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? chipColor
                                      : AppColors.mutedTitanium,
                                ),
                              ),
                              const SizedBox(width: 5),
                            ],
                            Text(
                              filter.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                                color: isSelected
                                    ? chipColor
                                    : AppColors.mutedTitanium,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilterState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: FacGlassPanel(
        borderColor: AppColors.mutedTitanium.withValues(alpha: 0.3),
        glowColor: AppColors.liquidGold.withValues(alpha: 0.08),
        padding: const EdgeInsets.all(20),
        borderRadius: FacilitiesUi.radiusLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.spaceNavy.withValues(alpha: 0.6),
                border: Border.all(
                  color: AppColors.mutedTitanium.withValues(alpha: 0.3),
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.filter_list_off_rounded,
                color: AppColors.mutedTitanium,
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Seçili Filtrede Tesis Bulunamadı',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Seçtiğiniz kademe veya durum kriterine uyan tesis yok.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                color: AppColors.mutedTitanium,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedCategory = 'all';
                  _selectedStatus = FacilityStatusFilter.all;
                });
              },
              icon: const Icon(
                Icons.refresh_rounded,
                size: 16,
                color: AppColors.liquidGold,
              ),
              label: const Text(
                'Filtreleri Temizle',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.liquidGold,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                backgroundColor: AppColors.liquidGold.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: AppColors.liquidGold.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTierSections({
    required List<_TierGroup> tiers,
    required int level,
    required int gold,
    required bool inPrison,
    required Map<String, PlayerFacility> unlockedByType,
  }) {
    final List<Widget> sections = <Widget>[];
    int totalVisibleCards = 0;

    for (int i = 0; i < tiers.length; i++) {
      final _TierGroup group = tiers[i];
      final Widget? tierWidget = _buildTierSection(
        tierGroup: group,
        level: level,
        gold: gold,
        inPrison: inPrison,
        unlockedByType: unlockedByType,
        animationStartIndex: i * 5,
        onCountVisible: (int count) => totalVisibleCards += count,
      );
      if (tierWidget != null) {
        sections.add(tierWidget);
      }
    }

    if (totalVisibleCards == 0) {
      sections.add(_buildEmptyFilterState());
    }

    return sections;
  }

  Widget? _buildTierSection({
    required _TierGroup tierGroup,
    required int level,
    required int gold,
    required bool inPrison,
    required Map<String, PlayerFacility> unlockedByType,
    required int animationStartIndex,
    required void Function(int count) onCountVisible,
  }) {
    final Color accent = facTierAccent(tierGroup.tier);

    final List<_FacilityCardData> sortedFacilities =
        List<_FacilityCardData>.from(tierGroup.facilities)
          ..sort((_FacilityCardData a, _FacilityCardData b) {
            final bool aUnlocked = unlockedByType.containsKey(a.type);
            final bool bUnlocked = unlockedByType.containsKey(b.type);
            if (aUnlocked != bUnlocked) {
              return aUnlocked ? -1 : 1;
            }
            final bool aCanUnlock = !aUnlocked &&
                level >= a.unlockLevel &&
                gold >= a.unlockCost;
            final bool bCanUnlock = !bUnlocked &&
                level >= b.unlockLevel &&
                gold >= b.unlockCost;
            if (aCanUnlock != bCanUnlock) {
              return aCanUnlock ? -1 : 1;
            }
            return 0;
          });

    final int unlockedInTier = tierGroup.facilities
        .where((f) => unlockedByType.containsKey(f.type))
        .length;

    // Durum filtresine göre filtreleme
    final List<_FacilityCardData> matchingFacilities =
        sortedFacilities.where((_FacilityCardData facility) {
      final PlayerFacility? playerFacility = unlockedByType[facility.type];
      final bool isUnlocked = playerFacility != null;
      final bool canUnlock = !isUnlocked &&
          level >= facility.unlockLevel &&
          gold >= facility.unlockCost;
      final bool isProducing = isUnlocked &&
          playerFacility.productionStartedAt != null &&
          playerFacility.productionStartedAt!.isNotEmpty;

      switch (_selectedStatus) {
        case FacilityStatusFilter.all:
          return true;
        case FacilityStatusFilter.unlocked:
          return isUnlocked;
        case FacilityStatusFilter.producing:
          return isProducing;
        case FacilityStatusFilter.canUnlock:
          return canUnlock;
        case FacilityStatusFilter.locked:
          return !isUnlocked && !canUnlock;
      }
    }).toList();

    onCountVisible(matchingFacilities.length);

    if (matchingFacilities.isEmpty) {
      return null;
    }

    final bool facilitiesCollectCoach =
        ref.watch(tutorialProvider).activeStep?.id == 'facilities_collect';

    final List<Widget Function(int index)> cardBuilders =
        <Widget Function(int index)>[];

    for (int i = 0; i < matchingFacilities.length; i++) {
      final _FacilityCardData facility = matchingFacilities[i];
      final int animIndex = animationStartIndex + i;
      final bool isTutorialCard =
          facilitiesCollectCoach && tierGroup.tier == 1 && i == 0;

      cardBuilders.add((int _) {
        final PlayerFacility? playerFacility = unlockedByType[facility.type];
        final bool isUnlocked = playerFacility != null;
        final bool canUnlock = !isUnlocked &&
            level >= facility.unlockLevel &&
            gold >= facility.unlockCost;
        final String footer = _facilityFooter(
          facility: facility,
          playerFacility: playerFacility,
          level: level,
          gold: gold,
          canUnlock: canUnlock,
        );

        Widget card = FacHubFacilityCard(
          animationIndex: animIndex,
          icon: facility.icon,
          name: facility.name,
          isUnlocked: isUnlocked,
          canUnlock: canUnlock,
          footer: footer,
          accentColor: accent,
          onTap: () {
            if (facilitiesCollectCoach && !isTutorialCard) {
              ref.read(tutorialProvider.notifier).registerWrongTap();
              return;
            }
            if (isTutorialCard) {
              unawaited(
                TutorialTriggers.onAnchorTap(
                  ref,
                  TutorialAnchorId.facilitiesHubCard,
                ),
              );
            }
            unawaited(
              _onFacilityTap(
                facility: facility,
                isUnlocked: isUnlocked,
                canUnlock: canUnlock,
                inPrison: inPrison,
                level: level,
                gold: gold,
              ),
            );
          },
        );

        if (isTutorialCard) {
          card = TutorialAnchorScope(
            id: TutorialAnchorId.facilitiesHubCard,
            child: card,
          );
        }
        return card;
      });
    }

    return FacTierSection(
      tier: tierGroup.tier,
      title: tierGroup.label,
      trailing: '$unlockedInTier/${tierGroup.facilities.length} Açık',
      accentColor: accent,
      children: facBuildFacilityCardRows(cardBuilder: cardBuilders),
    );
  }

  String _facilityFooter({
    required _FacilityCardData facility,
    required PlayerFacility? playerFacility,
    required int level,
    required int gold,
    required bool canUnlock,
  }) {
    if (playerFacility != null) {
      final double rate = _calculateFacilityRate(
        facility.type,
        playerFacility.level,
      );
      final int readyItems = playerFacility.facilityQueue
          .where((q) => q.isCompleted)
          .length;
      final bool isProducing = playerFacility.productionStartedAt != null &&
          playerFacility.productionStartedAt!.isNotEmpty;

      if (readyItems > 0) {
        return 'Lv. ${playerFacility.level} • 🎁 $readyItems Hazır (+${rate.toInt()}/dk)';
      } else if (isProducing) {
        return 'Lv. ${playerFacility.level} • ⚡ Üretimde (+${rate.toInt()}/dk)';
      } else {
        return 'Lv. ${playerFacility.level} • 💤 Boşta • +${rate.toInt()}/dk';
      }
    }

    if (canUnlock) {
      return 'Dokun ve Aç • ${_formatGold(facility.unlockCost)} Altın';
    }

    if (level < facility.unlockLevel) {
      return 'Seviye ${facility.unlockLevel} gerekli (Mevcut: Lv. $level)';
    }

    if (gold < facility.unlockCost) {
      return '${_formatGold(facility.unlockCost)} altın gerekli';
    }

    return 'Lv. ${facility.unlockLevel} • ${_formatGold(facility.unlockCost)} Altın';
  }

  Future<void> _onFacilityTap({
    required _FacilityCardData facility,
    required bool isUnlocked,
    required bool canUnlock,
    required bool inPrison,
    required int level,
    required int gold,
  }) async {
    if (inPrison) {
      if (!mounted) return;
      AppMessenger.show(
        context,
        'Cezaevindeyken tesislere erişilemez. Kefalet ödeyerek serbest kalabilirsiniz.',
      );
      return;
    }

    if (isUnlocked) {
      if (!mounted) return;
      context.push('${AppRoutes.facilities}/${facility.type}');
      return;
    }

    if (canUnlock) {
      final bool confirm = await showFacUnlockDialog(
        context,
        facilityName: facility.name,
        facilityIcon: facility.icon,
        formattedCost: _formatGold(facility.unlockCost),
      );

      if (!confirm) return;

      final bool ok = await ref
          .read(facilitiesProvider.notifier)
          .unlockFacility(facilityType: facility.type);
      if (!mounted) return;
      AppMessenger.show(
        context,
        ok
            ? '${facility.name} kilidi başarıyla açıldı!'
            : (ref.read(facilitiesProvider).errorMessage ?? 'Tesis açılamadı'),
      );
      return;
    }

    if (level < facility.unlockLevel) {
      if (!mounted) return;
      AppMessenger.show(
        context,
        'Bu tesis için Seviye ${facility.unlockLevel} gerekli (Mevcut: Lv. $level)',
      );
      return;
    }

    if (gold < facility.unlockCost) {
      if (!mounted) return;
      AppMessenger.show(
        context,
        'Kilidi açmak için ${_formatGold(facility.unlockCost)} altın gerekli',
      );
      return;
    }
  }

  Future<void> _handleBribe(
    FacilitiesState facilitiesState,
    num gems,
    int bribeGemCost,
  ) async {
    final profile = ref.read(playerProvider).profile;
    final int globalSuspicion = effectiveSuspicionLevel(profile);
    if (globalSuspicion <= 0) {
      if (!mounted) return;
      AppMessenger.show(context, 'Şüphe %0 iken rüşvet verilemez');
      return;
    }

    if (gems < bribeGemCost) {
      if (!mounted) return;
      AppMessenger.show(
        context,
        'Rüşvet için $bribeGemCost Gem gerekli',
      );
      return;
    }

    final PlayerFacility? bribeTarget = ref
        .read(facilitiesProvider.notifier)
        .pickBribeTarget();
    if (bribeTarget == null) {
      if (!mounted) return;
      AppMessenger.show(context, 'Rüşvet için açık tesis bulunamadı');
      return;
    }

    final bool confirm = await showFacBribeDialog(
      context,
      facilityType: bribeTarget.facilityType,
      gemAmount: bribeGemCost,
    );

    if (!confirm) return;

    final bool ok = await ref
        .read(facilitiesProvider.notifier)
        .bribeOfficials(
          facilityType: bribeTarget.facilityType,
          gemAmount: bribeGemCost,
        );
    if (!mounted) return;

    if (ok) {
      ref.read(playerProvider.notifier).loadProfile();
      ref.read(facilitiesProvider.notifier).loadFacilities();
    }

    AppMessenger.show(
      context,
      ok
          ? 'Rüşvet verildi, genel şüphe seviyesi düşürüldü!'
          : (ref.read(facilitiesProvider).errorMessage ?? 'Rüşvet başarısız'),
    );
  }
}

class _TierGroup {
  const _TierGroup({
    required this.tier,
    required this.label,
    required this.facilities,
  });

  final int tier;
  final String label;
  final List<_FacilityCardData> facilities;
}

class _FacilityCardData {
  const _FacilityCardData({
    required this.type,
    required this.name,
    required this.icon,
    required this.unlockLevel,
    required this.unlockCost,
  });

  final String type;
  final String name;
  final String icon;
  final int unlockLevel;
  final int unlockCost;
}

const List<_FacilityCardData> _basicFacilities = <_FacilityCardData>[
  _FacilityCardData(
    type: 'mining',
    name: 'Maden Ocağı',
    icon: '⛏️',
    unlockLevel: 1,
    unlockCost: 50000,
  ),
  _FacilityCardData(
    type: 'quarry',
    name: 'Taş Ocağı',
    icon: '🪨',
    unlockLevel: 2,
    unlockCost: 80000,
  ),
  _FacilityCardData(
    type: 'lumber_mill',
    name: 'Kereste Fabrikası',
    icon: '🪵',
    unlockLevel: 3,
    unlockCost: 100000,
  ),
  _FacilityCardData(
    type: 'clay_pit',
    name: 'Kil Ocağı',
    icon: '🏺',
    unlockLevel: 4,
    unlockCost: 120000,
  ),
  _FacilityCardData(
    type: 'sand_quarry',
    name: 'Kum Ocağı',
    icon: '🏖️',
    unlockLevel: 5,
    unlockCost: 150000,
  ),
];

const List<_FacilityCardData> _organicFacilities = <_FacilityCardData>[
  _FacilityCardData(
    type: 'farming',
    name: 'Çiftlik',
    icon: '🌾',
    unlockLevel: 6,
    unlockCost: 200000,
  ),
  _FacilityCardData(
    type: 'herb_garden',
    name: 'Ot Bahçesi',
    icon: '🌿',
    unlockLevel: 7,
    unlockCost: 250000,
  ),
  _FacilityCardData(
    type: 'ranch',
    name: 'Hayvancılık',
    icon: '🐄',
    unlockLevel: 8,
    unlockCost: 300000,
  ),
  _FacilityCardData(
    type: 'apiary',
    name: 'Arıcılık',
    icon: '🐝',
    unlockLevel: 9,
    unlockCost: 350000,
  ),
  _FacilityCardData(
    type: 'mushroom_farm',
    name: 'Mantar Çiftliği',
    icon: '🍄',
    unlockLevel: 10,
    unlockCost: 400000,
  ),
];

const List<_FacilityCardData> _mysticalFacilities = <_FacilityCardData>[
  _FacilityCardData(
    type: 'rune_mine',
    name: 'Rune Madeni',
    icon: '🔮',
    unlockLevel: 15,
    unlockCost: 500000,
  ),
  _FacilityCardData(
    type: 'holy_spring',
    name: 'Kutsal Kaynak',
    icon: '⛲',
    unlockLevel: 20,
    unlockCost: 600000,
  ),
  _FacilityCardData(
    type: 'shadow_pit',
    name: 'Gölge Çukuru',
    icon: '🕸️',
    unlockLevel: 25,
    unlockCost: 700000,
  ),
  _FacilityCardData(
    type: 'elemental_forge',
    name: 'Elementel Ocak',
    icon: '🔥',
    unlockLevel: 30,
    unlockCost: 800000,
  ),
  _FacilityCardData(
    type: 'time_well',
    name: 'Zaman Kuyusu',
    icon: '⌛',
    unlockLevel: 40,
    unlockCost: 1000000,
  ),
];

bool _isFuture(String? iso) {
  if (iso == null || iso.isEmpty) return false;
  final DateTime? parsed = DateTime.tryParse(iso);
  if (parsed == null) return false;
  return parsed.isAfter(DateTime.now());
}

String _formatGold(int value) =>
    NumberFormat.decimalPattern('tr_TR').format(value);
