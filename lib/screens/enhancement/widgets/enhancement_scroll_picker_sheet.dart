import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../models/inventory_model.dart';
import '../../../models/item_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';

/// Büyüleme taşı ve parşömen meta verisi (Aion 2 AAA Game Studio standardı).
class _ScrollMetadata {
  const _ScrollMetadata({
    required this.stoneLevel,
    required this.multiplierText,
    required this.bonusDescription,
    required this.categoryLabel,
    required this.accentColor,
    required this.glowColor,
    required this.isSupplement,
    required this.isAncient,
    required this.tierLabel,
    required this.tierLevel,
    required this.protectionProbability,
    required this.protectionLabel,
    required this.protectionDetail,
  });

  final String stoneLevel;
  final String multiplierText;
  final String bonusDescription;
  final String categoryLabel;
  final Color accentColor;
  final Color glowColor;
  final bool isSupplement;
  final bool isAncient;
  final String tierLabel;
  final int tierLevel; // 1 to 5
  final double protectionProbability; // 0.0 - 1.0
  final String protectionLabel;
  final String protectionDetail;
}

_ScrollMetadata _resolveScrollMetadata(InventoryItem item) {
  final String id = item.itemId.toLowerCase();
  final String name = item.name.toLowerCase();

  // 1. Kadim Koruma / Aegis Parşömeni (Ancient Protection Scroll)
  if (id.contains('ancient_protection') ||
      id.contains('kadim_koruma') ||
      name.contains('kadim koruma') ||
      name.contains('ancient protection') ||
      id.contains('aegis') ||
      name.contains('aegis')) {
    return const _ScrollMetadata(
      stoneLevel: 'KADİM L100+',
      multiplierText: '2.50× Kadim Çarpan',
      bonusDescription: 'Mutlak Koruma: Başarısızlıkta kademe düşüşü ve kırılma engellenir (+60% Şans)',
      categoryLabel: 'Kadim Koruma Parşömeni',
      accentColor: AppColors.liquidGold,
      glowColor: AppColors.goldGlow,
      isSupplement: true,
      isAncient: true,
      tierLabel: 'TIER V · KADİM AEGIS',
      tierLevel: 5,
      protectionProbability: 1.0,
      protectionLabel: '%100 Tam Koruma',
      protectionDetail: 'Seviye düşüşü ve eşya kaybı tamamen engellenir',
    );
  }

  // 2. Kadim Büyüleme Parşömeni / Taşı (Ancient Scroll / Primordial Aether)
  if (id.contains('ancient') ||
      name.contains('ancient') ||
      id.contains('kadim') ||
      name.contains('kadim') ||
      id.contains('primordial')) {
    return const _ScrollMetadata(
      stoneLevel: 'KADİM L95+',
      multiplierText: '2.20× Kadim Çarpan',
      bonusDescription: 'Kadim Aether Rezonansı · Üst Düzey Başarı Oranı (+45% Şans)',
      categoryLabel: 'Kadim Büyüleme Parşömeni',
      accentColor: AppColors.gold,
      glowColor: AppColors.goldGlow,
      isSupplement: false,
      isAncient: true,
      tierLabel: 'TIER V · KADİM REZONANS',
      tierLevel: 5,
      protectionProbability: 0.85,
      protectionLabel: '%85 Kadim Koruma',
      protectionDetail: 'Yüksek rezonansla seviye kaybı riski %85 azaltılır',
    );
  }

  // 3. Felicitous / Kutsama Parşömeni (Felicitous Scroll)
  if (id.contains('felicitous') || name.contains('felicitous') || name.contains('kutsama')) {
    return const _ScrollMetadata(
      stoneLevel: 'L100+',
      multiplierText: '2.00× Kutsama Çarpanı',
      bonusDescription: '+50% Başarı Şansı · Seviye Düşmeme Koruması',
      categoryLabel: 'Kutsama Parşömeni (Felicitous)',
      accentColor: AppColors.warningSolar,
      glowColor: AppColors.warningGlow,
      isSupplement: true,
      isAncient: false,
      tierLabel: 'TIER IV · EFSANEVİ KUTSAMA',
      tierLevel: 4,
      protectionProbability: 1.0,
      protectionLabel: '%100 Seviye Koruma',
      protectionDetail: 'Başarısızlıkta seviye gerilemesi kesinlikle engellenir',
    );
  }

  // 4. Pristine / Kusursuz Destekleyici (Pristine Supplement)
  if (id.contains('pristine') || name.contains('pristine') || name.contains('kusursuz')) {
    return const _ScrollMetadata(
      stoneLevel: 'L90~99',
      multiplierText: '1.75× Çarpan',
      bonusDescription: '+35% Başarı Şansı · Yüksek Kararlılık Rezonansı',
      categoryLabel: 'Kusursuz Destekleyici (Pristine)',
      accentColor: AppColors.accentPurple,
      glowColor: AppColors.accentPurpleGlow,
      isSupplement: true,
      isAncient: false,
      tierLabel: 'TIER IV · PRISTINE DESTEK',
      tierLevel: 4,
      protectionProbability: 0.75,
      protectionLabel: '%75 Kararlılık Koruması',
      protectionDetail: 'Yüksek aether kararlılığı ile gerileme riskini %75 düşürür',
    );
  }

  // 5. Supplement / Aether Destekleyicisi (Catalyst / Supplement)
  if (id.contains('supplement') || name.contains('destek') || id.contains('catalyst')) {
    return const _ScrollMetadata(
      stoneLevel: 'L75~85',
      multiplierText: '1.40× Çarpan',
      bonusDescription: '+20% Başarı Şansı · Temel Aether Akışı',
      categoryLabel: 'Aether Destekleyicisi',
      accentColor: AppColors.accentCyan,
      glowColor: AppColors.accentCyanGlow,
      isSupplement: true,
      isAncient: false,
      tierLabel: 'TIER III · AETHER DESTEK',
      tierLevel: 3,
      protectionProbability: 0.40,
      protectionLabel: '%40 Aether Koruması',
      protectionDetail: 'Orta seviye aether bariyeri sağlar',
    );
  }

  // 6. Seviyeli Taşlar (L1 - L100)
  final RegExp lMatch = RegExp(r'[lL](\d+)');
  final Match? match = lMatch.firstMatch(id) ?? lMatch.firstMatch(name);
  if (match != null) {
    final int level = int.tryParse(match.group(1) ?? '50') ?? 50;
    if (level >= 90) {
      return _ScrollMetadata(
        stoneLevel: 'L$level',
        multiplierText: '1.60× Çarpan',
        bonusDescription: 'Kadim Seviye Taş · Yüksek Başarı Oranı (+30% Şans)',
        categoryLabel: 'Kadim Büyüleme Taşı',
        accentColor: AppColors.coralFlare,
        glowColor: AppColors.warningGlow,
        isSupplement: false,
        isAncient: true,
        tierLabel: 'TIER V · KADİM TAŞ',
        tierLevel: 5,
        protectionProbability: 0.60,
        protectionLabel: '%60 Koruma Oranı',
        protectionDetail: 'Kadim cevher yapısı ile gerileme riskini %60 önler',
      );
    } else if (level >= 70) {
      return _ScrollMetadata(
        stoneLevel: 'L$level',
        multiplierText: '1.35× Çarpan',
        bonusDescription: 'Usta Seviye Taş · Dengeli Rezonans (+20% Şans)',
        categoryLabel: 'Usta Büyüleme Taşı',
        accentColor: AppColors.accentBlue,
        glowColor: AppColors.accentBlueGlow,
        isSupplement: false,
        isAncient: false,
        tierLabel: 'TIER IV · USTA TAŞ',
        tierLevel: 4,
        protectionProbability: 0.40,
        protectionLabel: '%40 Koruma Oranı',
        protectionDetail: 'Usta dereceli rezonans ile %40 koruma sağlar',
      );
    } else if (level >= 40) {
      return _ScrollMetadata(
        stoneLevel: 'L$level',
        multiplierText: '1.20× Çarpan',
        bonusDescription: 'Orta Seviye Taş · Standart Güçlendirme (+10% Şans)',
        categoryLabel: 'Büyüleme Taşı',
        accentColor: AppColors.accentCyan,
        glowColor: AppColors.accentCyanGlow,
        isSupplement: false,
        isAncient: false,
        tierLabel: 'TIER III · UZMAN TAŞ',
        tierLevel: 3,
        protectionProbability: 0.25,
        protectionLabel: '%25 Koruma Oranı',
        protectionDetail: 'Standart kristal kararlılığı sağlar',
      );
    } else {
      return _ScrollMetadata(
        stoneLevel: 'L$level',
        multiplierText: '1.05× Çarpan',
        bonusDescription: 'Temel Seviye Taş · Giriş Düzeyi',
        categoryLabel: 'Çırak Büyüleme Taşı',
        accentColor: AppColors.mutedTitanium,
        glowColor: AppColors.borderDefault,
        isSupplement: false,
        isAncient: false,
        tierLabel: 'TIER I-II · ÇIRAK TAŞ',
        tierLevel: 2,
        protectionProbability: 0.10,
        protectionLabel: '%10 Koruma Oranı',
        protectionDetail: 'Temel düzey rezonans taş',
      );
    }
  }

  // 7. Rarity bazlı varsayılanlar
  switch (item.rarity) {
    case Rarity.mythic:
      return const _ScrollMetadata(
        stoneLevel: 'L100',
        multiplierText: '1.80× Kadim Çarpan',
        bonusDescription: 'Ebedi Büyü Gücü · Maksimum Rezonans (+40% Şans)',
        categoryLabel: 'Ebedi Büyüleme Taşı',
        accentColor: AppColors.rarityMythic,
        glowColor: AppColors.dangerGlow,
        isSupplement: false,
        isAncient: true,
        tierLabel: 'TIER V · EBEDİ MİTİK',
        tierLevel: 5,
        protectionProbability: 0.70,
        protectionLabel: '%70 Mitik Koruma',
        protectionDetail: 'Mitik güç kalkanı seviye kaybını %70 oranında soğurur',
      );
    case Rarity.legendary:
      return const _ScrollMetadata(
        stoneLevel: 'L90',
        multiplierText: '1.50× Çarpan',
        bonusDescription: 'Efsanevi Enerji · Yüksek Başarı (+25% Şans)',
        categoryLabel: 'Efsanevi Büyüleme Taşı',
        accentColor: AppColors.rarityLegendary,
        glowColor: AppColors.warningGlow,
        isSupplement: false,
        isAncient: false,
        tierLabel: 'TIER IV · EFSANEVİ',
        tierLevel: 4,
        protectionProbability: 0.50,
        protectionLabel: '%50 Efsanevi Koruma',
        protectionDetail: 'Efsanevi rezonans seviye kaybı riskini yarı yarıya azaltır',
      );
    case Rarity.epic:
      return const _ScrollMetadata(
        stoneLevel: 'L75',
        multiplierText: '1.30× Çarpan',
        bonusDescription: 'Kahraman Rezonansı · Güçlü Akış (+18% Şans)',
        categoryLabel: 'Kahraman Taşı',
        accentColor: AppColors.rarityEpic,
        glowColor: AppColors.accentPurpleGlow,
        isSupplement: false,
        isAncient: false,
        tierLabel: 'TIER III · EPİK KAHRAMAN',
        tierLevel: 3,
        protectionProbability: 0.35,
        protectionLabel: '%35 Epik Koruma',
        protectionDetail: 'Epik aether kalkanı kısmi koruma temin eder',
      );
    case Rarity.rare:
      return const _ScrollMetadata(
        stoneLevel: 'L60',
        multiplierText: '1.20× Çarpan',
        bonusDescription: 'Nadir Aether Taşı (+12% Şans)',
        categoryLabel: 'Nadir Taş',
        accentColor: AppColors.rarityRare,
        glowColor: AppColors.accentBlueGlow,
        isSupplement: false,
        isAncient: false,
        tierLabel: 'TIER II · NADİR',
        tierLevel: 2,
        protectionProbability: 0.20,
        protectionLabel: '%20 Nadir Koruma',
        protectionDetail: 'Hafif aether sönümleme koruması',
      );
    case Rarity.uncommon:
      return const _ScrollMetadata(
        stoneLevel: 'L40',
        multiplierText: '1.10× Çarpan',
        bonusDescription: 'Gelişmiş Büyüleme Taşı (+8% Şans)',
        categoryLabel: 'Gelişmiş Taş',
        accentColor: AppColors.rarityUncommon,
        glowColor: AppColors.successGlow,
        isSupplement: false,
        isAncient: false,
        tierLabel: 'TIER II · GELİŞMİŞ',
        tierLevel: 2,
        protectionProbability: 0.15,
        protectionLabel: '%15 Temel Koruma',
        protectionDetail: 'Düşük seviyeli sönümleme',
      );
    case Rarity.common:
      return const _ScrollMetadata(
        stoneLevel: 'L20',
        multiplierText: '1.05× Çarpan',
        bonusDescription: 'Temel Büyüleme Parşömeni (+5% Şans)',
        categoryLabel: 'Temel Parşömen',
        accentColor: AppColors.rarityCommon,
        glowColor: AppColors.borderDefault,
        isSupplement: false,
        isAncient: false,
        tierLabel: 'TIER I · ÇIRAK',
        tierLevel: 1,
        protectionProbability: 0.05,
        protectionLabel: '%5 Giriş Koruması',
        protectionDetail: 'Minimum düzey koruma',
      );
  }
}

/// Envanterdeki parşömenlerden seçim. `null` = iptal, seçilen [InventoryItem] row.
Future<InventoryItem?> showEnhancementScrollPickerSheet({
  required BuildContext context,
  required List<InventoryItem> ownedScrolls,
  required String? requiredScrollId,
  InventoryItem? selectedScroll,
}) {
  Iterable<InventoryItem> filtered = ownedScrolls.where(
    (InventoryItem item) =>
        (item.itemType == ItemType.scroll ||
            item.itemId.contains('scroll') ||
            item.itemId.contains('stone')) &&
        item.quantity > 0,
  );
  if (requiredScrollId != null && requiredScrollId.isNotEmpty) {
    filtered = filtered.where((InventoryItem item) => item.itemId == requiredScrollId);
  }
  final List<InventoryItem> scrolls = filtered.toList(growable: false)
    ..sort((InventoryItem a, InventoryItem b) => a.name.compareTo(b.name));

  return showModalBottomSheet<InventoryItem>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    elevation: 24,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXxl)),
    ),
    builder: (BuildContext context) {
      return _Aion2ScrollPickerSheetBody(
        scrolls: scrolls,
        requiredScrollId: requiredScrollId,
        selectedScroll: selectedScroll,
      );
    },
  );
}

class _Aion2ScrollPickerSheetBody extends StatefulWidget {
  const _Aion2ScrollPickerSheetBody({
    required this.scrolls,
    required this.requiredScrollId,
    required this.selectedScroll,
  });

  final List<InventoryItem> scrolls;
  final String? requiredScrollId;
  final InventoryItem? selectedScroll;

  @override
  State<_Aion2ScrollPickerSheetBody> createState() =>
      _Aion2ScrollPickerSheetBodyState();
}

class _Aion2ScrollPickerSheetBodyState
    extends State<_Aion2ScrollPickerSheetBody> {
  int _activeFilterIndex = 0;
  static const List<String> _filters = <String>[
    'Tümü',
    'Kadim & Kutsama',
    'Büyüleme Taşları',
    'Destekleyiciler',
  ];

  List<InventoryItem> _applyFilter() {
    if (_activeFilterIndex == 0) return widget.scrolls;
    return widget.scrolls.where((InventoryItem item) {
      final _ScrollMetadata meta = _resolveScrollMetadata(item);
      switch (_activeFilterIndex) {
        case 1:
          return meta.isAncient || meta.protectionProbability >= 0.70;
        case 2:
          return !meta.isSupplement;
        case 3:
          return meta.isSupplement;
        default:
          return true;
      }
    }).toList(growable: false);
  }

  void _selectAndClose(InventoryItem scroll) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(scroll);
  }

  @override
  Widget build(BuildContext context) {
    final List<InventoryItem> displayedScrolls = _applyFilter();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.84,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgDeep,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXxl),
        ),
        border: Border.all(
          color: AppColors.liquidGold.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0xFF050810),
            blurRadius: 36,
            spreadRadius: 8,
            offset: Offset(0, -6),
          ),
          BoxShadow(
            color: AppColors.goldGlow,
            blurRadius: 24,
            spreadRadius: -4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(
                  top: AppSpacing.sm + 2,
                  bottom: AppSpacing.sm,
                ),
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[AppColors.liquidGold, AppColors.coralFlare],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.liquidGold.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),

            // Header Section
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.base,
                AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  // Icon frame with golden glow
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      gradient: const RadialGradient(
                        colors: <Color>[Color(0xFF3B2A10), Color(0xFF141926)],
                        radius: 0.9,
                      ),
                      border: Border.all(
                        color: AppColors.liquidGold.withValues(alpha: 0.65),
                        width: 1.2,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.liquidGold.withValues(alpha: 0.35),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('📜', style: TextStyle(fontSize: 19)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.requiredScrollId != null
                              ? 'Gerekli Büyüleme Parşömeni'
                              : 'Büyüleme Parşömeni & Taşları',
                          style: AppTextStyles.h3.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.requiredScrollId != null
                              ? 'Uyumlu Eşya: ${widget.requiredScrollId}'
                              : 'Kadim Parşömenler, L1-L100 Taşlar ve Destekleyiciler',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: widget.requiredScrollId != null
                                ? AppColors.liquidGold
                                : AppColors.mutedTitanium,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + 2,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B14),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: AppColors.liquidGold.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '${widget.scrolls.length} Parşömen',
                      style: AppTextStyles.micro.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.liquidGold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.mutedTitanium,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Kapat',
                  ),
                ],
              ),
            ),

            // Filter Tabs (if items exist)
            if (widget.scrolls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base,
                  0,
                  AppSpacing.base,
                  AppSpacing.sm + 2,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List<Widget>.generate(_filters.length, (int index) {
                      final bool isSelected = _activeFilterIndex == index;
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _activeFilterIndex = index);
                          },
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md + 2,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF332915)
                                  : AppColors.bgSurface,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.liquidGold
                                    : AppColors.borderDefault.withValues(alpha: 0.6),
                                width: isSelected ? 1.4 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? <BoxShadow>[
                                      BoxShadow(
                                        color: AppColors.liquidGold.withValues(alpha: 0.25),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              _filters[index],
                              style: AppTextStyles.label.copyWith(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? AppColors.liquidGold
                                    : AppColors.mutedTitanium,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),

            const Divider(height: 1, thickness: 1, color: AppColors.borderFaint),

            // Body List
            Flexible(
              child: widget.scrolls.isEmpty
                  ? _ScrollEmptyState(requiredScrollId: widget.requiredScrollId)
                  : displayedScrolls.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                          child: Center(
                            child: Text(
                              'Bu filtrede parşömen veya taş bulunmuyor.',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.mutedTitanium,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.base,
                            AppSpacing.md,
                            AppSpacing.base,
                            AppSpacing.base,
                          ),
                          shrinkWrap: true,
                          itemCount: displayedScrolls.length,
                          separatorBuilder: (BuildContext context, int index) =>
                              const SizedBox(height: AppSpacing.md),
                          itemBuilder: (BuildContext context, int index) {
                            final InventoryItem scroll = displayedScrolls[index];
                            final _ScrollMetadata meta =
                                _resolveScrollMetadata(scroll);
                            final bool isSelected =
                                widget.selectedScroll?.rowId == scroll.rowId;

                            return _ScrollModernCard(
                              scroll: scroll,
                              metadata: meta,
                              isSelected: isSelected,
                              onTap: () => _selectAndClose(scroll),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aion 2 standardında Büyüleme Parşömeni ve Taş Kartı.
class _ScrollModernCard extends StatelessWidget {
  const _ScrollModernCard({
    required this.scroll,
    required this.metadata,
    required this.isSelected,
    required this.onTap,
  });

  final InventoryItem scroll;
  final _ScrollMetadata metadata;
  final bool isSelected;
  final VoidCallback onTap;

  Color _resolveProtectionColor(double prob) {
    if (prob >= 1.0) return AppColors.liquidGold;
    if (prob >= 0.70) return AppColors.success;
    if (prob >= 0.40) return AppColors.accentCyan;
    if (prob >= 0.20) return AppColors.accentBlue;
    return AppColors.mutedTitanium;
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = metadata.accentColor;
    final Color protectionColor = _resolveProtectionColor(metadata.protectionProbability);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF1E1A12)
                : const Color(0xFF0F1524),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: isSelected
                  ? AppColors.liquidGold
                  : metadata.isAncient
                      ? AppColors.liquidGold.withValues(alpha: 0.55)
                      : accent.withValues(alpha: 0.32),
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: (isSelected
                        ? AppColors.liquidGold
                        : metadata.isAncient
                            ? const Color(0xFFFFB800)
                            : accent)
                    .withValues(
                  alpha: isSelected
                      ? 0.38
                      : metadata.isAncient
                          ? 0.20
                          : 0.08,
                ),
                blurRadius: isSelected
                    ? 18
                    : metadata.isAncient
                        ? 14
                        : 8,
                spreadRadius: isSelected ? 1 : 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Top Row: Icon Frame + Info + Checkmark
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Glowing Icon Frame with Stone Level Badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          gradient: RadialGradient(
                            colors: <Color>[
                              accent.withValues(alpha: 0.38),
                              const Color(0xFF0C101A),
                            ],
                            radius: 0.85,
                          ),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.75),
                            width: 1.5,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: accent.withValues(alpha: 0.45),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Center(
                          child: ItemIconView(
                            iconValue: scroll.icon,
                            itemId: scroll.itemId,
                            itemType: scroll.itemType,
                            size: 34,
                            expand: true,
                            fallback: metadata.isAncient
                                ? '🔱'
                                : metadata.isSupplement
                                    ? '✨'
                                    : '📜',
                          ),
                        ),
                      ),
                      // Stone Level Tag
                      Positioned(
                        bottom: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B0F19),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                            border: Border.all(
                              color: accent,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            metadata.stoneLevel,
                            style: AppTextStyles.micro.copyWith(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: accent,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                      // Ancient Glyph Emblem (if Ancient)
                      if (metadata.isAncient)
                        Positioned(
                          top: -5,
                          left: -5,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF2A1C06),
                              border: Border.all(
                                color: AppColors.liquidGold,
                                width: 1,
                              ),
                              boxShadow: const <BoxShadow>[
                                BoxShadow(
                                  color: AppColors.goldGlow,
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              size: 10,
                              color: AppColors.liquidGold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Category Chip & Tier Badge & Quantity
                        Row(
                          children: <Widget>[
                            // Category Chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.45),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                metadata.categoryLabel.toUpperCase(),
                                style: AppTextStyles.micro.copyWith(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Quantity Pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF281F0E),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                border: Border.all(
                                  color: AppColors.liquidGold.withValues(alpha: 0.6),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '×${scroll.quantity}',
                                style: AppTextStyles.micro.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.liquidGold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Title
                        Text(
                          scroll.name,
                          style: AppTextStyles.titleBold.copyWith(
                            fontSize: 13.5,
                            color: isSelected
                                ? AppColors.liquidGold
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),

                        // Bonus Description
                        Text(
                          metadata.bonusDescription,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            color: AppColors.mutedTitanium,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: AppSpacing.sm),

                  // Radio checkmark indicator
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppColors.liquidGold : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.liquidGold
                              : AppColors.borderBright.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                        boxShadow: isSelected
                            ? const <BoxShadow>[
                                BoxShadow(
                                  color: AppColors.goldGlow,
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 14, color: Colors.black)
                          : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Protection Probability Indicator Bar & Shield
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 2,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgDeep.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(
                    color: protectionColor.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          metadata.protectionProbability >= 1.0
                              ? Icons.verified_user_rounded
                              : Icons.shield_rounded,
                          size: 13,
                          color: protectionColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'KORUMA GÜVENCESİ: ',
                          style: AppTextStyles.micro.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mutedTitanium,
                          ),
                        ),
                        Text(
                          metadata.protectionLabel,
                          style: AppTextStyles.micro.copyWith(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: protectionColor,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          metadata.protectionProbability >= 1.0
                              ? 'Kaybetme Riski Yok'
                              : 'Kısmi Koruma',
                          style: AppTextStyles.micro.copyWith(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            color: protectionColor.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      child: Stack(
                        children: <Widget>[
                          Container(
                            height: 4,
                            width: double.infinity,
                            color: AppColors.borderFaint,
                          ),
                          FractionallySizedBox(
                            widthFactor: metadata.protectionProbability.clamp(0.08, 1.0),
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: <Color>[
                                    protectionColor.withValues(alpha: 0.6),
                                    protectionColor,
                                  ],
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: protectionColor.withValues(alpha: 0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Badges: Multiplier & Tier Indicator & Supplement Type
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  // Multiplier Bonus Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          AppColors.liquidGold.withValues(alpha: 0.22),
                          AppColors.liquidGold.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                      border: Border.all(
                        color: AppColors.liquidGold.withValues(alpha: 0.45),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.bolt_rounded,
                          size: 13,
                          color: AppColors.liquidGold,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          metadata.multiplierText,
                          style: AppTextStyles.micro.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppColors.liquidGold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tier Indicator Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.55),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          metadata.isAncient
                              ? Icons.workspace_premium_rounded
                              : metadata.isSupplement
                                  ? Icons.auto_awesome_rounded
                                  : Icons.diamond_outlined,
                          size: 12,
                          color: accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          metadata.tierLabel,
                          style: AppTextStyles.micro.copyWith(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Rarity Kademe Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                      border: Border.all(
                        color: AppColors.borderDefault,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '${scroll.rarity.name.toUpperCase()} KADEME',
                      style: AppTextStyles.micro.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
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
}

/// Uygun parşömen bulunamadığında gösterilen şık Aion 2 boş durum paneli.
class _ScrollEmptyState extends StatelessWidget {
  const _ScrollEmptyState({
    required this.requiredScrollId,
  });

  final String? requiredScrollId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxl,
        horizontal: AppSpacing.base,
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.bgSurface,
              border: Border.all(
                color: AppColors.liquidGold.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: AppColors.goldGlow,
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.auto_stories_rounded,
                size: 32,
                color: AppColors.liquidGold,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Envanterde Uygun Parşömen Yok',
            style: AppTextStyles.h3.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              requiredScrollId != null
                  ? 'Bu eşya için "$requiredScrollId" gerekiyor. Zindan ganimetlerinden, Kadim Sandıklardan veya Pazar yerinden temin edebilirsin.'
                  : 'Güçlendirme yapabilmek için büyüleme taşı, kadim parşömen veya aether destekleyicisine ihtiyacın var.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11.5,
                color: AppColors.mutedTitanium,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.liquidGold, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: 10,
              ),
            ),
            child: Text(
              'Geri Dön',
              style: AppTextStyles.captionBold.copyWith(
                fontSize: 12,
                color: AppColors.liquidGold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
