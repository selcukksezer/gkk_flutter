import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../components/layout/game_chrome.dart';
import '../../theme/app_colors.dart';
import '../../models/facility_model.dart';
import '../../models/player_model.dart';
import '../../providers/facilities_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import 'widgets/facilities_hub_design.dart';
import 'widgets/facilities_ui.dart';
import 'widgets/facility_hub_cards.dart';
import 'widgets/facilities_dialogs.dart';
import '../../utils/logout_helper.dart';
import '../../core/utils/character_class_abilities.dart';

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

    final List<_TierGroup> tiers = <_TierGroup>[
      _TierGroup(
        tier: 1,
        label: '🏚️ Kademe 1 — Başlangıç',
        facilities: _basicFacilities,
      ),
      _TierGroup(
        tier: 2,
        label: '🏗️ Kademe 2 — Gelişmiş',
        facilities: _organicFacilities,
      ),
      _TierGroup(
        tier: 3,
        label: '🏰 Kademe 3 — İleri',
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
                  context,
                  facilitiesState,
                  gems,
                  bribeGemCost,
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

    final List<Widget Function(int index)> cardBuilders =
        <Widget Function(int index)>[];
    for (int i = 0; i < sortedFacilities.length; i++) {
      final _FacilityCardData facility = sortedFacilities[i];
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
            : _lockedFacilityFooter(
                facility: facility,
                level: level,
                gold: gold,
                canUnlock: canUnlock,
              );

        return FacHubFacilityCard(
          animationIndex: animIndex,
          icon: facility.icon,
          name: facility.name,
          isUnlocked: isUnlocked,
          canUnlock: canUnlock,
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
      trailing: '${tierGroup.facilities.length} tesis',
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
    int bribeGemCost,
  ) async {
    final profile = ref.read(playerProvider).profile;
    final int globalSuspicion = effectiveSuspicionLevel(profile);
    if (globalSuspicion <= 0) {
      AppMessenger.show(context, 'Şüphe 0 iken rüşvet verilemez');
      return;
    }

    if (gems < bribeGemCost) {
      AppMessenger.show(
        context,
        'Rüşvet için $bribeGemCost gem gerekli',
      );
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
      this.context,
      ok
          ? 'Rüşvet verildi, genel şüphe güncellendi!'
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

String _lockedFacilityFooter({
  required _FacilityCardData facility,
  required int level,
  required int gold,
  required bool canUnlock,
}) {
  if (canUnlock) {
    return 'Dokun ve aç • ${_formatGold(facility.unlockCost)} altın';
  }
  if (level < facility.unlockLevel) {
    return 'Seviye ${facility.unlockLevel} gerekli (sen: Lv.$level)';
  }
  if (gold < facility.unlockCost) {
    return '${_formatGold(facility.unlockCost)} altın gerekli';
  }
  return 'Lv.${facility.unlockLevel} • ${_formatGold(facility.unlockCost)} altın';
}

bool _isFuture(String? iso) {
  if (iso == null || iso.isEmpty) return false;
  final DateTime? parsed = DateTime.tryParse(iso);
  if (parsed == null) return false;
  return parsed.isAfter(DateTime.now());
}

String _formatGold(int value) =>
    NumberFormat.decimalPattern('tr_TR').format(value);
