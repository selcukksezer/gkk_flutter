import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../models/inventory_model.dart';
import '../../../models/item_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';

typedef EnhancementRuneType = String;

/// Aion 2 standardında Manastone / Godstone katalog girdisi.
class EnhancementRuneCatalogEntry {
  const EnhancementRuneCatalogEntry({
    required this.label,
    required this.description,
    this.statBoost = '+5% Başarı Şansı',
    this.socketOdds = '95% Yuva Uyumu',
    this.glowColor = AppColors.accentCyan,
    this.secondaryGlow = AppColors.accentBlue,
    this.rarity = 'Normal',
    this.category = 'Temel Manastone',
    this.iconSymbol = '💠',
    this.protectionLevel = 0,
    this.multiplierBonus = 1.05,
    this.loreDescription = 'Atreia aether kristallerinden yontulmuş temel rezonans taşı.',
    this.successBonusPercent = 5,
    this.shatterProtection = 'Korumasız',
    this.downgradeProtection = 'Düşüş Riski Var',
  });

  final String label;
  final String description;
  final String statBoost;
  final String socketOdds;
  final Color glowColor;
  final Color secondaryGlow;
  final String rarity;
  final String category;
  final String iconSymbol;
  final int protectionLevel; // 0: yok, 1: kısmi koruma, 2: tam koruma
  final double multiplierBonus;
  final String loreDescription;
  final int successBonusPercent;
  final String shatterProtection;
  final String downgradeProtection;
}

const Map<EnhancementRuneType, EnhancementRuneCatalogEntry> kEnhancementRuneCatalog =
    <EnhancementRuneType, EnhancementRuneCatalogEntry>{
  'basic': EnhancementRuneCatalogEntry(
    label: 'Temel Manastone',
    description: '+5% başarı şansı ve rezonans akışı',
    statBoost: '+5% Başarı',
    socketOdds: '95% Yuva Uyumu',
    glowColor: AppColors.accentCyan,
    secondaryGlow: AppColors.accentBlue,
    rarity: 'Normal',
    category: 'Manastone',
    iconSymbol: '💠',
    multiplierBonus: 1.05,
    loreDescription: 'Yeni başlayan askerler için dengeli Aether kristali.',
    successBonusPercent: 5,
    shatterProtection: 'Korumasız',
    downgradeProtection: 'Düşüş Riski Var',
  ),
  'advanced': EnhancementRuneCatalogEntry(
    label: 'Gelişmiş Manastone',
    description: '+10% başarı şansı, kararlı enerji',
    statBoost: '+10% Başarı',
    socketOdds: '88% Yuva Uyumu',
    glowColor: AppColors.accentTeal,
    secondaryGlow: Color(0xFF0B6E4F),
    rarity: 'Nadir',
    category: 'Kusursuz Manastone',
    iconSymbol: '💎',
    multiplierBonus: 1.10,
    loreDescription: 'Faceted Aether yapısıyla büyü akışını hızlandırır.',
    successBonusPercent: 10,
    shatterProtection: 'Korumasız',
    downgradeProtection: 'Düşüş Riski Var',
  ),
  'superior': EnhancementRuneCatalogEntry(
    label: 'Üstün Aether Rünü',
    description: '+15% başarı şansı, yıkım riski yarıya iner',
    statBoost: '+15% Başarı · Yarı Yıkım Riski',
    socketOdds: '82% Yuva Uyumu',
    glowColor: AppColors.accentPurple,
    secondaryGlow: Color(0xFF7209B7),
    rarity: 'Kahraman',
    category: 'Üstün Rün',
    iconSymbol: '🔮',
    protectionLevel: 1,
    multiplierBonus: 1.15,
    loreDescription: 'Abyss çatlaklarından toplanan saf mor kristal.',
    successBonusPercent: 15,
    shatterProtection: '%50 Azaltılmış Risk',
    downgradeProtection: 'Düşüş Riski Var',
  ),
  'legendary': EnhancementRuneCatalogEntry(
    label: 'Efsanevi Tanrı Taşı (Godstone)',
    description: '+25% başarı şansı, yıkım riski %75 azalır',
    statBoost: '+25% Başarı · %75 Yıkım Koruması',
    socketOdds: '76% Yuva Uyumu',
    glowColor: AppColors.gold,
    secondaryGlow: AppColors.liquidGold,
    rarity: 'Efsanevi',
    category: 'Kadim Godstone',
    iconSymbol: '⚡',
    protectionLevel: 1,
    multiplierBonus: 1.25,
    loreDescription: 'Antik Daeva savaşçılarının kutsadığı efsanevi cevher.',
    successBonusPercent: 25,
    shatterProtection: '%75 Yıkım Kalkanı',
    downgradeProtection: 'Düşüş Riski Var',
  ),
  'protection': EnhancementRuneCatalogEntry(
    label: 'Aegis Koruma Mührü',
    description: 'Başarısızlık halinde eşya kesinlikle parçalanmaz',
    statBoost: 'Tam Yıkım Koruması (Anti-Shatter)',
    socketOdds: '100% Mühür',
    glowColor: AppColors.danger,
    secondaryGlow: Color(0xFF990022),
    rarity: 'Kutsal',
    category: 'Aegis Koruma',
    iconSymbol: '🛡️',
    protectionLevel: 2,
    multiplierBonus: 1.00,
    loreDescription: 'Eşyanın ruhunu parçalanmaya karşı mühürleyen ilahi kalkan.',
    successBonusPercent: 0,
    shatterProtection: '🛡️ %100 Anti-Shatter',
    downgradeProtection: 'Düşüş Riski Var',
  ),
  'blessed': EnhancementRuneCatalogEntry(
    label: 'Kutsal Işık Godstone',
    description: '+20% başarı şansı, başarısızlıkta seviye düşmez',
    statBoost: '+20% Başarı · Seviye Koruma (Anti-Downgrade)',
    socketOdds: '90% Yuva Uyumu',
    glowColor: AppColors.goldLight,
    secondaryGlow: AppColors.liquidGold,
    rarity: 'Ebedi',
    category: 'Kutsal Godstone',
    iconSymbol: '✨',
    protectionLevel: 1,
    multiplierBonus: 1.20,
    loreDescription: 'Serafim ışığıyla bezenmiş en saf cennet cevheri.',
    successBonusPercent: 20,
    shatterProtection: 'Korumasız',
    downgradeProtection: '✨ %100 Seviye Sabit',
  ),
};

EnhancementRuneType enhancementRuneTypeFromItemId(String itemId) =>
    itemId.replaceFirst('rune_', '');

String enhancementRuneLabel(EnhancementRuneType type) {
  if (type == 'none') return 'Rune kullanma';
  return kEnhancementRuneCatalog[type]?.label ?? type;
}

String? enhancementRuneDescription(EnhancementRuneType type) =>
    kEnhancementRuneCatalog[type]?.description;

EnhancementRuneCatalogEntry _catalogEntryFor(
  EnhancementRuneType type, [
  InventoryItem? item,
]) {
  final EnhancementRuneCatalogEntry? existing = kEnhancementRuneCatalog[type];
  if (existing != null) return existing;

  final String name = item?.name ?? type;
  final String desc = item?.description ?? 'Kadim Aether kalıntısı.';
  final Color rarityColor = item != null
      ? AppColors.forRarity(item.rarity.name)
      : AppColors.accentBlue;

  return EnhancementRuneCatalogEntry(
    label: name,
    description: desc,
    statBoost: '+5% Başarı Bonusu',
    socketOdds: '85% Yuva Uyumu',
    glowColor: rarityColor,
    secondaryGlow: rarityColor.withValues(alpha: 0.6),
    rarity: item?.rarity.name.toUpperCase() ?? 'NADİR',
    category: 'Kadim Rün',
    iconSymbol: '💠',
    loreDescription: desc,
    successBonusPercent: 5,
    shatterProtection: 'Korumasız',
    downgradeProtection: 'Düşüş Riski Var',
  );
}

/// Envanterdeki rune item'larından seçim listesi açar. `none` veya rune type döner.
Future<EnhancementRuneType?> showEnhancementRunePickerSheet({
  required BuildContext context,
  required List<InventoryItem> ownedRunes,
  required EnhancementRuneType selectedRune,
}) {
  final List<InventoryItem> runes = ownedRunes
      .where((InventoryItem item) =>
          item.itemType == ItemType.rune || item.itemId.startsWith('rune_'))
      .where((InventoryItem item) => item.quantity > 0)
      .toList(growable: false)
    ..sort((InventoryItem a, InventoryItem b) => a.name.compareTo(b.name));

  return showModalBottomSheet<EnhancementRuneType>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    elevation: 24,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusXxl),
      ),
    ),
    builder: (BuildContext context) {
      return _Aion2RunePickerSheetBody(
        runes: runes,
        selectedRune: selectedRune,
      );
    },
  );
}

class _Aion2RunePickerSheetBody extends StatefulWidget {
  const _Aion2RunePickerSheetBody({
    required this.runes,
    required this.selectedRune,
  });

  final List<InventoryItem> runes;
  final EnhancementRuneType selectedRune;

  @override
  State<_Aion2RunePickerSheetBody> createState() =>
      _Aion2RunePickerSheetBodyState();
}

class _Aion2RunePickerSheetBodyState extends State<_Aion2RunePickerSheetBody> {
  late EnhancementRuneType _previewRune;
  int _selectedFilterIndex = 0;
  bool _isGridView = false;

  static const List<String> _filters = <String>[
    'Tümü',
    'Manastone',
    'Godstone',
    'Koruma',
  ];

  @override
  void initState() {
    super.initState();
    _previewRune = widget.selectedRune;
  }

  InventoryItem? _findItemForType(EnhancementRuneType type) {
    if (type == 'none') return null;
    for (final InventoryItem item in widget.runes) {
      if (enhancementRuneTypeFromItemId(item.itemId) == type) {
        return item;
      }
    }
    return null;
  }

  List<InventoryItem> _filteredRunes() {
    if (_selectedFilterIndex == 0) return widget.runes;
    return widget.runes.where((InventoryItem item) {
      final EnhancementRuneType type =
          enhancementRuneTypeFromItemId(item.itemId);
      final EnhancementRuneCatalogEntry? entry = kEnhancementRuneCatalog[type];
      final String cat = entry?.category.toLowerCase() ?? '';
      final String label = entry?.label.toLowerCase() ?? item.name.toLowerCase();

      switch (_selectedFilterIndex) {
        case 1:
          return cat.contains('manastone') ||
              label.contains('manastone') ||
              type == 'basic' ||
              type == 'advanced';
        case 2:
          return cat.contains('godstone') ||
              label.contains('godstone') ||
              type == 'legendary' ||
              type == 'blessed';
        case 3:
          return cat.contains('koruma') ||
              label.contains('koruma') ||
              type == 'protection' ||
              type == 'superior';
        default:
          return true;
      }
    }).toList(growable: false);
  }

  void _onRuneTapped(EnhancementRuneType type) {
    HapticFeedback.selectionClick();
    setState(() {
      _previewRune = type;
    });
  }

  void _confirmAndClose(EnhancementRuneType type) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(type);
  }

  @override
  Widget build(BuildContext context) {
    final List<InventoryItem> displayedRunes = _filteredRunes();
    final InventoryItem? activeItem = _findItemForType(_previewRune);
    final EnhancementRuneCatalogEntry? activeEntry = _previewRune != 'none'
        ? _catalogEntryFor(_previewRune, activeItem)
        : null;

    final double screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.88,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgDeep,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXxl),
        ),
        border: Border.all(
          color: activeEntry != null
              ? activeEntry.glowColor.withValues(alpha: 0.45)
              : AppColors.borderBright.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          const BoxShadow(
            color: Color(0xFF030509),
            blurRadius: 36,
            spreadRadius: 8,
            offset: Offset(0, -8),
          ),
          BoxShadow(
            color: (activeEntry?.glowColor ?? AppColors.accentBlue)
                .withValues(alpha: 0.22),
            blurRadius: 28,
            spreadRadius: -4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── Fluid Drag Handle ──
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      activeEntry?.glowColor ?? AppColors.accentBlue,
                      AppColors.liquidGold,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: (activeEntry?.glowColor ?? AppColors.accentBlue)
                          .withValues(alpha: 0.45),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),

            // ── Header Section ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.base,
                AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      gradient: RadialGradient(
                        colors: <Color>[
                          (activeEntry?.glowColor ?? AppColors.accentPurple)
                              .withValues(alpha: 0.35),
                          AppColors.bgSurface,
                        ],
                        radius: 0.9,
                      ),
                      border: Border.all(
                        color: (activeEntry?.glowColor ?? AppColors.accentPurple)
                            .withValues(alpha: 0.7),
                        width: 1.2,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: (activeEntry?.glowColor ?? AppColors.accentPurple)
                              .withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        activeEntry?.iconSymbol ?? '🔮',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Manastone & Godstone Yuvası',
                          style: AppTextStyles.titleBold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Aion 2 Soketleme & Rezonans Katalizörleri',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.mutedTitanium,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + 2,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: AppColors.borderBright.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '${widget.runes.length} Rün',
                      style: AppTextStyles.micro.copyWith(
                        color: AppColors.accentBlue,
                        fontWeight: FontWeight.w800,
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

            // ── Live Rune Socket Preview Pedestal ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.xs,
              ),
              child: _RuneSocketPreviewPedestal(
                selectedType: _previewRune,
                entry: activeEntry,
                selectedItem: activeItem,
                onClear: () => _onRuneTapped('none'),
              ),
            ),

            // ── Stat Buffs Comparison Section ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.base,
                AppSpacing.xs,
                AppSpacing.base,
                AppSpacing.sm,
              ),
              child: _RuneStatBuffsComparisonPanel(entry: activeEntry),
            ),

            // ── Filter Chips Bar & Grid/List View Toggle ──
            if (widget.runes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base,
                  0,
                  AppSpacing.base,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List<Widget>.generate(_filters.length, (int index) {
                            final bool isSelected = _selectedFilterIndex == index;
                            return Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.sm),
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedFilterIndex = index);
                                },
                                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.xs + 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.bgCardElevated
                                        : AppColors.bgSurface,
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusFull,
                                    ),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.accentBlue
                                          : AppColors.borderFaint,
                                      width: isSelected ? 1.4 : 1.0,
                                    ),
                                    boxShadow: isSelected
                                        ? <BoxShadow>[
                                            BoxShadow(
                                              color: AppColors.accentBlue
                                                  .withValues(alpha: 0.28),
                                              blurRadius: 8,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    _filters[index],
                                    style: AppTextStyles.label.copyWith(
                                      color: isSelected
                                          ? AppColors.textPrimary
                                          : AppColors.mutedTitanium,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),

                    // Grid / List View Mode Toggle
                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _isGridView = !_isGridView);
                      },
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xs + 2),
                        decoration: BoxDecoration(
                          color: AppColors.bgCard,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          border: Border.all(color: AppColors.borderBright),
                        ),
                        child: Icon(
                          _isGridView
                              ? Icons.view_agenda_rounded
                              : Icons.grid_view_rounded,
                          size: 18,
                          color: AppColors.accentBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.borderFaint,
            ),

            // ── Scrollable Rune Picker Body ──
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base,
                  AppSpacing.sm,
                  AppSpacing.base,
                  AppSpacing.md,
                ),
                shrinkWrap: true,
                children: <Widget>[
                  // Neutral "Rune kullanma" option tile
                  _RuneNoneOptionTile(
                    selected: _previewRune == 'none',
                    onTap: () => _onRuneTapped('none'),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  if (displayedRunes.isEmpty && widget.runes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Center(
                        child: Text(
                          'Bu kategoride rün bulunamadı.',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.mutedTitanium,
                          ),
                        ),
                      ),
                    )
                  else if (widget.runes.isEmpty)
                    _RuneEmptyInventoryState(
                      onContinueWithoutRune: () => _confirmAndClose('none'),
                    )
                  else if (_isGridView)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedRunes.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: AppSpacing.sm,
                        mainAxisSpacing: AppSpacing.sm,
                        childAspectRatio: 0.94,
                      ),
                      itemBuilder: (BuildContext context, int index) {
                        final InventoryItem item = displayedRunes[index];
                        final EnhancementRuneType type =
                            enhancementRuneTypeFromItemId(item.itemId);
                        final EnhancementRuneCatalogEntry entry =
                            _catalogEntryFor(type, item);
                        final bool isSelected = _previewRune == type;

                        return _RuneGridCard(
                          item: item,
                          entry: entry,
                          type: type,
                          selected: isSelected,
                          onTap: () => _onRuneTapped(type),
                          onDoubleTap: () => _confirmAndClose(type),
                        );
                      },
                    )
                  else
                    ...displayedRunes.map((InventoryItem item) {
                      final EnhancementRuneType type =
                          enhancementRuneTypeFromItemId(item.itemId);
                      final EnhancementRuneCatalogEntry entry =
                          _catalogEntryFor(type, item);
                      final bool isSelected = _previewRune == type;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _RuneModernCard(
                          item: item,
                          entry: entry,
                          type: type,
                          selected: isSelected,
                          onTap: () => _onRuneTapped(type),
                          onDoubleTap: () => _confirmAndClose(type),
                        );
                      },
                    ),
                ],
              ),
            ),

            // ── Bottom Fixed Action Bar ──
            _RunePickerActionBar(
              previewRune: _previewRune,
              activeEntry: activeEntry,
              onConfirm: () => _confirmAndClose(_previewRune),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// RUNE SOCKET PREVIEW PEDESTAL (CANLI SOKET VE PEDESTAL ÖNİZLEME)
// ════════════════════════════════════════════════════════════════════════════

class _RuneSocketPreviewPedestal extends StatelessWidget {
  const _RuneSocketPreviewPedestal({
    required this.selectedType,
    required this.entry,
    required this.selectedItem,
    required this.onClear,
  });

  final EnhancementRuneType selectedType;
  final EnhancementRuneCatalogEntry? entry;
  final InventoryItem? selectedItem;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final bool isSocketed = selectedType != 'none' && entry != null;
    final Color glow = entry?.glowColor ?? AppColors.accentBlue;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isSocketed
              ? glow.withValues(alpha: 0.55)
              : AppColors.borderDefault,
          width: isSocketed ? 1.4 : 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isSocketed
                ? glow.withValues(alpha: 0.25)
                : AppColors.accentBlueGlow.withValues(alpha: 0.08),
            blurRadius: isSocketed ? 18 : 8,
            spreadRadius: -2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          // Aetheric Socket Ring
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Pulsing outer halo
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      isSocketed
                          ? glow.withValues(alpha: 0.4)
                          : AppColors.borderFaint.withValues(alpha: 0.4),
                      AppColors.bgDeep,
                    ],
                  ),
                  border: Border.all(
                    color: isSocketed
                        ? glow
                        : AppColors.borderBright.withValues(alpha: 0.6),
                    width: isSocketed ? 2.0 : 1.2,
                  ),
                ),
              ),

              if (isSocketed)
                ItemIconView(
                  iconValue: selectedItem?.icon ?? '',
                  itemId: selectedItem?.itemId ?? 'rune_$selectedType',
                  itemType: selectedItem?.itemType ?? ItemType.rune,
                  size: 34,
                  expand: false,
                  fallback: entry!.iconSymbol,
                )
              else
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 24,
                  color: AppColors.mutedTitanium.withValues(alpha: 0.6),
                ),
            ],
          ),

          const SizedBox(width: AppSpacing.md),

          // Socket Status & Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs + 2,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSocketed
                            ? glow.withValues(alpha: 0.18)
                            : AppColors.bgCardElevated,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                        border: Border.all(
                          color: isSocketed
                              ? glow.withValues(alpha: 0.5)
                              : AppColors.borderFaint,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        isSocketed
                            ? '${entry!.rarity.toUpperCase()} · ${entry!.category.toUpperCase()}'
                            : 'SOKET BOŞ',
                        style: AppTextStyles.micro.copyWith(
                          color: isSocketed ? glow : AppColors.mutedTitanium,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  isSocketed ? entry!.label : 'Rün / Manastone Seçilmedi',
                  style: AppTextStyles.titleBold.copyWith(
                    color: isSocketed
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isSocketed
                      ? entry!.statBoost
                      : 'Katalizör olmadan standart başarı ve kırılma riskleri geçerlidir.',
                  style: AppTextStyles.caption.copyWith(
                    color: isSocketed ? glow : AppColors.mutedTitanium,
                    fontWeight: isSocketed ? FontWeight.w700 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Unequip / Clear button
          if (isSocketed)
            IconButton(
              onPressed: onClear,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: AppColors.danger,
              ),
              tooltip: 'Yuvayı Boşalt',
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// STAT BUFFS COMPARISON PANEL (STAT GELİŞTİRME KIYASI)
// ════════════════════════════════════════════════════════════════════════════

class _RuneStatBuffsComparisonPanel extends StatelessWidget {
  const _RuneStatBuffsComparisonPanel({required this.entry});

  final EnhancementRuneCatalogEntry? entry;

  @override
  Widget build(BuildContext context) {
    final bool hasRune = entry != null;
    final int boostPercent = entry?.successBonusPercent ?? 0;
    final int protLevel = entry?.protectionLevel ?? 0;
    final bool hasAntiDowngrade =
        entry != null && entry!.downgradeProtection.contains('100');

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderFaint),
      ),
      child: Row(
        children: <Widget>[
          // Success Boost Tile
          Expanded(
            child: _StatComparisonTile(
              title: 'BAŞARI BONUSU',
              value: boostPercent > 0 ? '+$boostPercent%' : '0%',
              subtitle: hasRune && boostPercent > 0 ? 'Rezonans' : 'Temel',
              icon: Icons.trending_up_rounded,
              accentColor: boostPercent > 0
                  ? AppColors.accentCyan
                  : AppColors.textTertiary,
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: AppColors.borderDefault,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          ),
          // Shatter Protection Tile
          Expanded(
            child: _StatComparisonTile(
              title: 'YIKIM KORUMA',
              value: protLevel == 2
                  ? 'TAM KORUMA'
                  : (protLevel == 1 ? '%50 AZALTIM' : 'KORUMASIZ'),
              subtitle: protLevel > 0 ? 'Anti-Shatter' : 'Yüksek Risk',
              icon: Icons.shield_rounded,
              accentColor: protLevel == 2
                  ? AppColors.success
                  : (protLevel == 1
                      ? AppColors.accentPurple
                      : AppColors.danger),
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: AppColors.borderDefault,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          ),
          // Level Protection Tile
          Expanded(
            child: _StatComparisonTile(
              title: 'SEVİYE DÜŞÜŞÜ',
              value: hasAntiDowngrade ? 'KİLİTLİ' : 'RİSKLİ',
              subtitle: hasAntiDowngrade ? 'Düşüş Yok' : 'Düşebilir',
              icon: Icons.auto_awesome_rounded,
              accentColor: hasAntiDowngrade
                  ? AppColors.gold
                  : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatComparisonTile extends StatelessWidget {
  const _StatComparisonTile({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 12, color: accentColor),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                title,
                style: AppTextStyles.micro.copyWith(
                  fontSize: 9,
                  color: AppColors.mutedTitanium,
                  letterSpacing: 0.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.label.copyWith(
            fontWeight: FontWeight.w900,
            color: accentColor,
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          subtitle,
          style: AppTextStyles.micro.copyWith(
            fontSize: 9,
            color: AppColors.textTertiary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// RUNE GRID CARD (AAA 2-SÜTUNLU IZGARA KARTI)
// ════════════════════════════════════════════════════════════════════════════

class _RuneGridCard extends StatelessWidget {
  const _RuneGridCard({
    required this.item,
    required this.entry,
    required this.type,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final InventoryItem item;
  final EnhancementRuneCatalogEntry entry;
  final EnhancementRuneType type;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final Color glow = entry.glowColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.bgCardElevated
                : AppColors.bgSurface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: selected ? glow : glow.withValues(alpha: 0.25),
              width: selected ? 1.8 : 1.0,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: glow.withValues(alpha: selected ? 0.38 : 0.08),
                blurRadius: selected ? 16 : 6,
                spreadRadius: selected ? 1 : 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Top Bar: Rarity pill & Quantity Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: glow.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                      border: Border.all(
                        color: glow.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      entry.rarity.toUpperCase(),
                      style: AppTextStyles.micro.copyWith(
                        fontSize: 8.5,
                        color: glow,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF281F0E),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                      border: Border.all(
                        color: AppColors.liquidGold.withValues(alpha: 0.6),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '×${item.quantity}',
                      style: AppTextStyles.micro.copyWith(
                        color: AppColors.liquidGold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Center: Glowing Rune Icon Socket
              Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    gradient: RadialGradient(
                      colors: <Color>[
                        glow.withValues(alpha: 0.4),
                        AppColors.bgDeep,
                      ],
                      radius: 0.85,
                    ),
                    border: Border.all(
                      color: glow.withValues(alpha: 0.7),
                      width: 1.2,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: glow.withValues(alpha: 0.35),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Center(
                    child: ItemIconView(
                      iconValue: item.icon,
                      itemId: item.itemId,
                      itemType: item.itemType,
                      size: 28,
                      expand: true,
                      fallback: entry.iconSymbol,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Label
              Text(
                entry.label,
                textAlign: TextAlign.center,
                style: AppTextStyles.captionBold.copyWith(
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 3),

              // Stat Boost Pill
              Container(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                decoration: BoxDecoration(
                  color: glow.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                  border: Border.all(
                    color: glow.withValues(alpha: 0.3),
                    width: 0.6,
                  ),
                ),
                child: Text(
                  entry.statBoost,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.micro.copyWith(
                    fontSize: 9,
                    color: glow,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// RUNE MODERN LIST CARD (DETAYLI LİSTE KARTI)
// ════════════════════════════════════════════════════════════════════════════

class _RuneModernCard extends StatelessWidget {
  const _RuneModernCard({
    required this.item,
    required this.entry,
    required this.type,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final InventoryItem item;
  final EnhancementRuneCatalogEntry entry;
  final EnhancementRuneType type;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final Color glow = entry.glowColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.bgCardElevated
                : AppColors.bgSurface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: selected ? glow : glow.withValues(alpha: 0.25),
              width: selected ? 1.6 : 1.0,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: glow.withValues(alpha: selected ? 0.35 : 0.08),
                blurRadius: selected ? 16 : 8,
                spreadRadius: selected ? 1 : 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Glowing Icon Frame
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      gradient: RadialGradient(
                        colors: <Color>[
                          glow.withValues(alpha: 0.35),
                          AppColors.bgDeep,
                        ],
                        radius: 0.85,
                      ),
                      border: Border.all(
                        color: glow.withValues(alpha: 0.7),
                        width: 1.5,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: glow.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Center(
                      child: ItemIconView(
                        iconValue: item.icon,
                        itemId: item.itemId,
                        itemType: item.itemType,
                        size: 32,
                        expand: true,
                        fallback: entry.iconSymbol,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // Info Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            // Category & Rarity Chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: glow.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                                border: Border.all(
                                  color: glow.withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '${entry.rarity.toUpperCase()} · ${entry.category.toUpperCase()}',
                                style: AppTextStyles.micro.copyWith(
                                  color: glow,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Quantity Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
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
                                '×${item.quantity}',
                                style: AppTextStyles.captionBold.copyWith(
                                  color: AppColors.liquidGold,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Title
                        Text(
                          entry.label,
                          style: AppTextStyles.titleBold,
                        ),
                        const SizedBox(height: 2),

                        // Description
                        Text(
                          entry.description,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.mutedTitanium,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: AppSpacing.sm),

                  // Radio selection indicator
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? glow : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? glow
                              : AppColors.borderBright.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check, size: 14, color: AppColors.carbonVoid)
                          : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm + 2),

              // Badges Row: Stat Boost & Socket Odds
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  // Stat Boost Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          glow.withValues(alpha: 0.22),
                          glow.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                      border: Border.all(
                        color: glow.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          entry.protectionLevel > 0
                              ? Icons.shield_rounded
                              : Icons.trending_up_rounded,
                          size: 13,
                          color: glow,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          entry.statBoost,
                          style: AppTextStyles.label.copyWith(
                            color: glow,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Socket Success Odds Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                      border: Border.all(
                        color: AppColors.borderBright.withValues(alpha: 0.6),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.radar_rounded,
                          size: 13,
                          color: AppColors.accentBlue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          entry.socketOdds,
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

// ════════════════════════════════════════════════════════════════════════════
// NEUTRAL "RÜN KULLANMA" SEÇENEĞİ KARTI
// ════════════════════════════════════════════════════════════════════════════

class _RuneNoneOptionTile extends StatelessWidget {
  const _RuneNoneOptionTile({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.bgCardElevated
                : AppColors.bgSurface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: selected
                  ? AppColors.accentBlue
                  : AppColors.borderFaint,
              width: selected ? 1.5 : 1.0,
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.accentBlue.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.bgDeep,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: const Center(
                  child: Text(
                    '—',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedTitanium,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Rune Kullanma (Standart Yükseltme)',
                      style: AppTextStyles.titleBold,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ek bonus veya koruma olmadan standart risklerle güçlendir.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.mutedTitanium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.accentBlue : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? AppColors.accentBlue
                        : AppColors.borderBright,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// BOTTOM CONFIRMATION ACTION BAR (ALT SABİT ONAY BAR)
// ════════════════════════════════════════════════════════════════════════════

class _RunePickerActionBar extends StatelessWidget {
  const _RunePickerActionBar({
    required this.previewRune,
    required this.activeEntry,
    required this.onConfirm,
  });

  final EnhancementRuneType previewRune;
  final EnhancementRuneCatalogEntry? activeEntry;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final bool isRune = previewRune != 'none' && activeEntry != null;
    final Color buttonColor = activeEntry?.glowColor ?? AppColors.accentBlue;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.sm,
        AppSpacing.base,
        AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgDeep,
        border: Border(
          top: BorderSide(color: AppColors.borderFaint),
        ),
      ),
      child: SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: isRune ? buttonColor : AppColors.bgCardElevated,
            foregroundColor: isRune ? AppColors.carbonVoid : AppColors.textPrimary,
            elevation: isRune ? 8 : 2,
            shadowColor: isRune ? buttonColor.withValues(alpha: 0.5) : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              side: BorderSide(
                color: isRune
                    ? buttonColor
                    : AppColors.borderBright.withValues(alpha: 0.6),
                width: 1.2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                isRune ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                size: 18,
                color: isRune ? AppColors.carbonVoid : AppColors.textPrimary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                isRune
                    ? '${activeEntry!.label.toUpperCase()} YUVAYA YERLEŞTİR'
                    : 'RÜNSÜZ DEVAM ET',
                style: AppTextStyles.dialogButton.copyWith(
                  color: isRune ? AppColors.carbonVoid : AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// EMPTY INVENTORY STATE (BOŞ ENVANTER PANELİ)
// ════════════════════════════════════════════════════════════════════════════

class _RuneEmptyInventoryState extends StatelessWidget {
  const _RuneEmptyInventoryState({
    required this.onContinueWithoutRune,
  });

  final VoidCallback onContinueWithoutRune;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xl,
        horizontal: AppSpacing.sm,
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
                color: AppColors.accentBlue.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: AppColors.accentBlueGlow,
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.auto_awesome_outlined,
                size: 32,
                color: AppColors.accentBlue,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Envanterinde Manastone / Rün Yok',
            style: AppTextStyles.titleBold,
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              'Zindan bosslarından veya Han Tüccarından temin edebilirsin. Rune kullanmadan da güçlendirme işlemine devam edebilirsin.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.mutedTitanium,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          OutlinedButton(
            onPressed: onContinueWithoutRune,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.accentBlue, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm + 2,
              ),
            ),
            child: Text(
              'Rune Olmadan Devam Et',
              style: AppTextStyles.label.copyWith(
                color: AppColors.accentBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
