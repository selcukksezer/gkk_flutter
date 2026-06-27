import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../components/layout/game_chrome.dart';
import '../../theme/app_colors.dart';
import '../../models/facility_model.dart';
import '../../providers/facilities_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import 'widgets/facilities_ui.dart';
import 'widgets/facility_hub_cards.dart';
import 'widgets/facilities_dialogs.dart';
import '../../utils/logout_helper.dart';

class FacilitiesScreen extends ConsumerStatefulWidget {
  const FacilitiesScreen({super.key});

  @override
  ConsumerState<FacilitiesScreen> createState() => _FacilitiesScreenState();
}

class _FacilitiesScreenState extends ConsumerState<FacilitiesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playerProvider.notifier).loadProfile();
      ref.read(facilitiesProvider.notifier).loadFacilities();
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final facilitiesState = ref.watch(facilitiesProvider);
    final profile = playerState.profile;
    final int level = profile?.level ?? 1;
    final int gold = profile?.gold ?? 0;
    final double gems = profile?.gems ?? 0;
    final int globalSuspicion = profile?.globalSuspicionLevel ?? 0;
    final bool inPrison = _isFuture(profile?.prisonUntil);
    final String prisonReason =
        (profile?.prisonReason == null || profile!.prisonReason!.trim().isEmpty)
        ? 'Bilinmiyor'
        : profile.prisonReason!;

    final Map<String, PlayerFacility> unlockedByType = <String, PlayerFacility>{
      for (final facility in facilitiesState.facilities)
        facility.facilityType: facility,
    };

    final List<_TierGroup> tiers = <_TierGroup>[
      _TierGroup(
        tier: 1,
        label: '🏚️ Tier 1 — Başlangıç',
        facilities: _basicFacilities,
      ),
      _TierGroup(
        tier: 2,
        label: '🏗️ Tier 2 — Gelişmiş',
        facilities: _organicFacilities,
      ),
      _TierGroup(
        tier: 3,
        label: '🏰 Tier 3 — İleri',
        facilities: _mysticalFacilities,
      ),
    ];

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
      body: facilitiesScreenShell(
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
            message: facilitiesState.errorMessage ?? 'Tesisler yüklenemedi',
            onRetry: () =>
                ref.read(facilitiesProvider.notifier).loadFacilities(),
          ),
          FacilitiesStatus.ready => ListView(
            padding: FacilitiesUi.scrollPadding(context),
            children: <Widget>[
              facilitiesPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                'Tesis Ağı',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${unlockedByType.length}/15 aktif • Lv.$level',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.mutedTitanium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        facilitiesStatChip('Altın', _formatGold(gold)),
                        const SizedBox(width: FacilitiesUi.gapSm),
                        facilitiesStatChip(
                          'Gem',
                          gems.toStringAsFixed(0),
                          valueColor: AppColors.liquidGold,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (inPrison)
                facilitiesPanel(
                  borderColor: AppColors.mysticRuby.withValues(alpha: 0.4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('👮', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Cezaevi — operasyonlar kilitli',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              prisonReason,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.mutedTitanium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              facilitiesPanel(
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            '🕵️ Şüphe',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '%$globalSuspicion',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _suspicionColor(globalSuspicion),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: FacilitiesUi.gapSm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: (globalSuspicion / 100).clamp(0, 1),
                        minHeight: 6,
                        backgroundColor: AppColors.darkObsidian,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _suspicionColor(globalSuspicion),
                        ),
                      ),
                    ),
                    const SizedBox(height: FacilitiesUi.gap),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            globalSuspicion <= 0
                                ? 'Şüphe yok'
                                : 'Baskın riski artar',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.mutedTitanium,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 30,
                          child: FilledButton(
                            onPressed:
                                (gems < 5 || inPrison || globalSuspicion <= 0)
                                ? null
                                : () => _handleBribe(
                                    context,
                                    facilitiesState,
                                    gems,
                                  ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.liquidGold,
                              foregroundColor: AppColors.carbonVoid,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                            child: const Text(
                              '💎 Rüşvet',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              ...() {
                int cardIndex = 0;
                return tiers.map((_TierGroup tierGroup) {
                  final Widget section = _buildTierSection(
                    context,
                    tierGroup: tierGroup,
                    level: level,
                    gold: gold,
                    inPrison: inPrison,
                    unlockedByType: unlockedByType,
                    animationStartIndex: cardIndex,
                  );
                  cardIndex += tierGroup.facilities.length;
                  return section;
                });
              }(),
            ],
          ),
        },
      ),
    );
  }

  Widget _buildTierSection(
    BuildContext context, {
    required _TierGroup tierGroup,
    required int level,
    required int gold,
    required bool inPrison,
    required Map<String, PlayerFacility> unlockedByType,
    required int animationStartIndex,
  }) {
    final Color accent = facTierAccent(tierGroup.tier);

    final List<Widget Function(int index)> cardBuilders =
        <Widget Function(int index)>[];
    for (int i = 0; i < tierGroup.facilities.length; i++) {
      final _FacilityCardData facility = tierGroup.facilities[i];
      final int animIndex = animationStartIndex + i;
      cardBuilders.add((int _) {
        final PlayerFacility? playerFacility = unlockedByType[facility.type];
        final bool isUnlocked = playerFacility != null;
        final bool canUnlock =
            !isUnlocked &&
            level >= facility.unlockLevel &&
            gold >= facility.unlockCost;
        final String footer = isUnlocked
            ? 'Lv.${playerFacility.level} • Kuyruk ${playerFacility.facilityQueue.length}'
            : 'Lv.${facility.unlockLevel} • ${_formatGold(facility.unlockCost)}g';

        return FacHubFacilityCard(
          animationIndex: animIndex,
          icon: facility.icon,
          name: facility.name,
          isUnlocked: isUnlocked,
          footer: footer,
          accentColor: accent,
          onTap: () => _onFacilityTap(
            context,
            facility: facility,
            isUnlocked: isUnlocked,
            canUnlock: canUnlock,
            inPrison: inPrison,
            level: level,
            gold: gold,
          ),
        );
      });
    }

    return FacTierSection(
      tier: tierGroup.tier,
      title: tierGroup.label,
      trailing: '${tierGroup.facilities.length} istasyon',
      accentColor: accent,
      children: facBuildFacilityCardRows(cardBuilder: cardBuilders),
    );
  }

  Future<void> _onFacilityTap(
    BuildContext context, {
    required _FacilityCardData facility,
    required bool isUnlocked,
    required bool canUnlock,
    required bool inPrison,
    required int level,
    required int gold,
  }) async {
    if (inPrison) {
      AppMessenger.show(
        context,
        'Cezaevindeyken detaylara erişilemez. Kefalet ödeyerek serbest kalabilirsiniz.',
      );
      return;
    }

    if (isUnlocked) {
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
            ? '${facility.name} açıldı!'
            : (ref.read(facilitiesProvider).errorMessage ?? 'Tesis açılamadı'),
      );
      return;
    }

    if (level < facility.unlockLevel) {
      AppMessenger.show(context, 'Seviye ${facility.unlockLevel} gerekli');
      return;
    }

    if (gold < facility.unlockCost) {
      AppMessenger.show(
        context,
        '${_formatGold(facility.unlockCost)} altın gerekli',
      );
      return;
    }
  }

  Future<void> _handleBribe(
    BuildContext context,
    FacilitiesState facilitiesState,
    num gems,
  ) async {
    final int globalSuspicion =
        ref.read(playerProvider).profile?.globalSuspicionLevel ?? 0;
    if (globalSuspicion <= 0) {
      AppMessenger.show(context, 'Şüphe 0 iken rüşvet verilemez');
      return;
    }

    if (gems < 5) {
      AppMessenger.show(context, 'Rüşvet için 5 gem gerekli');
      return;
    }

    final PlayerFacility? bribeTarget = ref
        .read(facilitiesProvider.notifier)
        .pickBribeTarget();
    if (bribeTarget == null) {
      AppMessenger.show(context, 'Rüşvet için açık tesis yok');
      return;
    }

    final bool confirm = await showFacBribeDialog(
      context,
      facilityType: bribeTarget.facilityType,
    );

    if (!confirm) return;

    final bool ok = await ref
        .read(facilitiesProvider.notifier)
        .bribeOfficials(facilityType: bribeTarget.facilityType, gemAmount: 5);
    if (!mounted) return;

    if (ok) {
      ref.read(playerProvider.notifier).loadProfile();
      ref.read(facilitiesProvider.notifier).loadFacilities();
    }

    AppMessenger.show(
      this.context,
      ok
          ? 'Rüşvet verildi, genel şüphe güncellendi!'
          : (ref.read(facilitiesProvider).errorMessage ?? 'Rüşvet başarısız'),
    );
  }
}

Color _suspicionColor(int value) {
  if (value >= 80) return AppColors.coralFlare;
  if (value >= 50) return AppColors.warningSolar;
  return AppColors.toxicNeon;
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
    icon: '🕳️',
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
    icon: '⏳',
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
