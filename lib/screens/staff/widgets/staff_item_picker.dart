import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/keyboard_dismiss.dart';
import '../../../models/staff_model.dart';
import '../../../repositories/staff_repository.dart';
import '../../../theme/app_text_styles.dart';
import '../../support/widgets/support_design.dart';
import 'staff_design.dart';

/// Rarity color and metadata helper for Aion 2 standard item styling.
abstract final class StaffItemRarity {
  static Color colorFor(String? rarity) {
    if (rarity == null) return SettingsPalette.titanium;
    final String r = rarity.toLowerCase().trim();
    if (r.contains('mythic') || r.contains('celestial') || r.contains('divine') || r.contains('ilah')) {
      return const Color(0xFFFF1744); // Crimson Ruby
    }
    if (r.contains('legend') || r.contains('ancient') || r.contains('efsane')) {
      return const Color(0xFFFFB300); // Radiant Sun Gold
    }
    if (r.contains('epic') || r.contains('destan') || r.contains('heroic')) {
      return const Color(0xFFD500F9); // Arcane Purple
    }
    if (r.contains('rare') || r.contains('nadir') || r.contains('superior')) {
      return const Color(0xFF00B0FF); // Azure Sapphire
    }
    if (r.contains('uncommon') || r.contains('seckin') || r.contains('fine')) {
      return const Color(0xFF00E676); // Emerald Green
    }
    return const Color(0xFF94A3B8); // Titanium Slate
  }

  static String labelFor(String? rarity) {
    if (rarity == null || rarity.trim().isEmpty) return 'SIRADAN';
    final String r = rarity.toLowerCase().trim();
    if (r.contains('mythic') || r.contains('celestial') || r.contains('divine') || r.contains('ilah')) {
      return 'İLAHİ';
    }
    if (r.contains('legend') || r.contains('ancient') || r.contains('efsane')) {
      return 'EFSANEVİ';
    }
    if (r.contains('epic') || r.contains('destan') || r.contains('heroic')) {
      return 'DESTANSI';
    }
    if (r.contains('rare') || r.contains('nadir') || r.contains('superior')) {
      return 'NADİR';
    }
    if (r.contains('uncommon') || r.contains('seckin') || r.contains('fine')) {
      return 'SEÇKİN';
    }
    return rarity.toUpperCase();
  }

  static IconData iconForType(String? itemType) {
    if (itemType == null) return Icons.inventory_2_outlined;
    final String t = itemType.toLowerCase().trim();
    if (t.contains('weapon') || t.contains('silah') || t.contains('sword') || t.contains('kilic') || t.contains('blade') || t.contains('bow')) {
      return Icons.colorize_rounded;
    }
    if (t.contains('armor') || t.contains('zirh') || t.contains('helmet') || t.contains('chest') || t.contains('shield') || t.contains('kalkan')) {
      return Icons.shield_rounded;
    }
    if (t.contains('potion') || t.contains('iksir') || t.contains('consumable') || t.contains('flask')) {
      return Icons.science_outlined;
    }
    if (t.contains('gem') || t.contains('elmas') || t.contains('jewel') || t.contains('crystal')) {
      return Icons.diamond_outlined;
    }
    if (t.contains('scroll') || t.contains('parchment') || t.contains('kagit') || t.contains('book')) {
      return Icons.menu_book_rounded;
    }
    if (t.contains('ring') || t.contains('necklace') || t.contains('taki') || t.contains('amulet')) {
      return Icons.all_inclusive_rounded;
    }
    return Icons.auto_awesome_rounded;
  }
}

/// LiveOps / staff formları — eşya adıyla ara, listeden seç.
/// Aion 2 standardı ile rarity parlama kenarlıkları ve cam panel kartı içerir.
class StaffItemPickerField extends StatelessWidget {
  const StaffItemPickerField({
    super.key,
    this.selected,
    required this.onChanged,
    this.label = 'Eşya',
    this.hint = 'Eşya seç…',
  });

  final StaffItemCatalogEntry? selected;
  final ValueChanged<StaffItemCatalogEntry?> onChanged;
  final String label;
  final String hint;

  Future<void> _openPicker(BuildContext context) async {
    dismissKeyboard(context);
    final StaffItemCatalogEntry? picked = await showStaffItemPickerSheet(
      context: context,
      initialSelection: selected,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final StaffItemCatalogEntry? item = selected;
    final Color rarityColor = StaffItemRarity.colorFor(item?.rarity);
    final String rarityName = StaffItemRarity.labelFor(item?.rarity);
    final IconData typeIcon = StaffItemRarity.iconForType(item?.itemType);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            item != null ? rarityColor.withValues(alpha: 0.16) : SettingsPalette.obsidian.withValues(alpha: 0.55),
            SettingsPalette.navy.withValues(alpha: 0.75),
            SettingsPalette.void_.withValues(alpha: 0.90),
          ],
        ),
        border: Border.all(
          color: item != null ? rarityColor.withValues(alpha: 0.65) : SettingsPalette.titanium.withValues(alpha: 0.28),
          width: item != null ? 1.5 : 1.0,
        ),
        boxShadow: item != null
            ? <BoxShadow>[
                BoxShadow(
                  color: rarityColor.withValues(alpha: 0.22),
                  blurRadius: 14,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                item != null ? typeIcon : Icons.inventory_2_outlined,
                size: 14,
                color: item != null ? rarityColor : SettingsPalette.titanium,
              ),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: AppTextStyles.captionBold.copyWith(
                  color: item != null ? rarityColor : SettingsPalette.titanium,
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (item != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: rarityColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: rarityColor.withValues(alpha: 0.55)),
                  ),
                  child: Text(
                    rarityName,
                    style: AppTextStyles.captionBold.copyWith(
                      color: rarityColor,
                      fontSize: 9,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (item == null)
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: SettingsPalette.obsidian.withValues(alpha: 0.6),
                    border: Border.all(
                      color: SettingsPalette.titanium.withValues(alpha: 0.3),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: SettingsPalette.titanium,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hint,
                    style: supportBodyStyle.copyWith(
                      color: SettingsPalette.textMid,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                StaffActionButton(
                  label: 'Katalogdan Seç',
                  accent: SettingsPalette.gold,
                  outlined: true,
                  onPressed: () => _openPicker(context),
                ),
              ],
            )
          else
            Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        rarityColor.withValues(alpha: 0.35),
                        SettingsPalette.obsidian,
                      ],
                    ),
                    border: Border.all(
                      color: rarityColor.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: rarityColor.withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(typeIcon, color: rarityColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.name,
                        style: AppTextStyles.bodyBold.copyWith(
                          color: SettingsPalette.textHi,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: <Widget>[
                          Text(
                            item.id,
                            style: supportCaptionStyle.copyWith(
                              fontFamily: 'Courier',
                              fontSize: 10,
                              color: SettingsPalette.titanium,
                            ),
                          ),
                          if (item.itemType != null) ...<Widget>[
                            Text(' · ', style: supportCaptionStyle),
                            Text(
                              item.itemType!,
                              style: supportCaptionStyle.copyWith(fontSize: 10),
                            ),
                          ],
                          if (item.isStackable) ...<Widget>[
                            Text(' · ', style: supportCaptionStyle),
                            Text(
                              'Maks: ${item.maxStack}',
                              style: supportCaptionStyle.copyWith(
                                color: SettingsPalette.gold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Seçimi Temizle',
                  onPressed: () => onChanged(null),
                  style: IconButton.styleFrom(
                    backgroundColor: SettingsPalette.ruby.withValues(alpha: 0.15),
                    side: BorderSide(color: SettingsPalette.ruby.withValues(alpha: 0.4)),
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                  ),
                  icon: Icon(Icons.close_rounded, color: SettingsPalette.ruby, size: 18),
                ),
                const SizedBox(width: 6),
                StaffActionButton(
                  label: 'Değiştir',
                  outlined: true,
                  accent: rarityColor,
                  onPressed: () => _openPicker(context),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Aion 2 standardında modal bottom sheet içinde zengin eşya arama ve seçici.
Future<StaffItemCatalogEntry?> showStaffItemPickerSheet({
  required BuildContext context,
  StaffItemCatalogEntry? initialSelection,
}) {
  return showStaffBottomSheet<StaffItemCatalogEntry>(
    context: context,
    accent: SettingsPalette.fuchsia,
    child: _StaffItemPickerSheet(initialSelection: initialSelection),
  );
}

class _StaffItemPickerSheet extends StatefulWidget {
  const _StaffItemPickerSheet({this.initialSelection});

  final StaffItemCatalogEntry? initialSelection;

  @override
  State<_StaffItemPickerSheet> createState() => _StaffItemPickerSheetState();
}

class _StaffItemPickerSheetState extends State<_StaffItemPickerSheet> {
  final StaffRepository _repo = StaffRepository();
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  bool _loading = true;
  String? _error;
  List<StaffItemCatalogEntry> _items = <StaffItemCatalogEntry>[];
  String? _selectedRarityFilter;

  static const List<String?> _rarityFilterOptions = <String?>[
    null,
    'mythic',
    'legendary',
    'epic',
    'rare',
    'uncommon',
    'common',
  ];

  static const Map<String?, String> _rarityFilterLabels = <String?, String>{
    null: 'Tümü',
    'mythic': 'İlahi',
    'legendary': 'Efsanevi',
    'epic': 'Destansı',
    'rare': 'Nadir',
    'uncommon': 'Seçkin',
    'common': 'Sıradan',
  };

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchChanged);
    unawaited(_load(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_load(_search.text.trim()));
    });
  }

  Future<void> _load(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _repo.searchItems(query, limit: 100);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = result.error;
      _items = result.items;
    });
  }

  List<StaffItemCatalogEntry> get _filteredItems {
    if (_selectedRarityFilter == null) return _items;
    final String target = _selectedRarityFilter!.toLowerCase();
    return _items.where((StaffItemCatalogEntry e) {
      final String? r = e.rarity?.toLowerCase();
      if (r == null) return false;
      return r.contains(target);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final double maxH = MediaQuery.sizeOf(context).height * 0.78;
    final List<StaffItemCatalogEntry> visibleItems = _filteredItems;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: <Color>[
                      SettingsPalette.fuchsia.withValues(alpha: 0.35),
                      SettingsPalette.obsidian,
                    ],
                  ),
                  border: Border.all(color: SettingsPalette.fuchsia.withValues(alpha: 0.6)),
                ),
                child: const Icon(Icons.inventory_2_rounded, color: SettingsPalette.fuchsia, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'EŞYA KATALOĞU',
                      style: AppTextStyles.h3.copyWith(
                        color: SettingsPalette.textHi,
                        fontSize: 16,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      'Rarity parlamalı tahsis ve ödül eşya seçimi',
                      style: supportCaptionStyle.copyWith(color: SettingsPalette.textMid, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            style: supportBodyStyle,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => dismissKeyboard(context),
            decoration: supportInputDecoration(
              label: 'İsim veya ID ile ara',
              hint: 'kılıç, ejderha, pot, item_01…',
            ).copyWith(
              prefixIcon: Icon(Icons.search_rounded, color: SettingsPalette.fuchsia.withValues(alpha: 0.8), size: 20),
              suffixIcon: _search.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _search.clear();
                        dismissKeyboard(context);
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _rarityFilterOptions.map((String? opt) {
                final bool isSel = _selectedRarityFilter == opt;
                final Color chipAccent = opt != null ? StaffItemRarity.colorFor(opt) : SettingsPalette.gold;
                final String label = _rarityFilterLabels[opt] ?? opt!;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(label),
                    selected: isSel,
                    showCheckmark: false,
                    selectedColor: chipAccent.withValues(alpha: 0.25),
                    backgroundColor: SettingsPalette.obsidian.withValues(alpha: 0.55),
                    side: BorderSide(
                      color: isSel ? chipAccent.withValues(alpha: 0.8) : SettingsPalette.titanium.withValues(alpha: 0.25),
                      width: isSel ? 1.4 : 1.0,
                    ),
                    labelStyle: TextStyle(
                      color: isSel ? chipAccent : SettingsPalette.textMid,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 11,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedRarityFilter = opt;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: <Widget>[
                Text(
                  '${visibleItems.length} eşya listelendi',
                  style: supportCaptionStyle.copyWith(
                    color: SettingsPalette.titanium,
                    fontSize: 11,
                  ),
                ),
                if (_selectedRarityFilter != null) ...<Widget>[
                  Text(' · ', style: supportCaptionStyle),
                  Text(
                    'Filtre: ${_rarityFilterLabels[_selectedRarityFilter]}',
                    style: supportCaptionStyle.copyWith(
                      color: StaffItemRarity.colorFor(_selectedRarityFilter),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(color: SettingsPalette.fuchsia),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  _error!,
                  style: supportCaptionStyle.copyWith(color: SettingsPalette.ruby),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (visibleItems.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.search_off_rounded,
                      size: 40,
                      color: SettingsPalette.titanium.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Eşleşen eşya bulunamadı.',
                      style: supportBodyStyle.copyWith(color: SettingsPalette.textMid),
                    ),
                    if (_selectedRarityFilter != null || _search.text.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Filtreleri Temizle'),
                        style: TextButton.styleFrom(foregroundColor: SettingsPalette.gold),
                        onPressed: () {
                          setState(() {
                            _selectedRarityFilter = null;
                            _search.clear();
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: visibleItems.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (BuildContext context, int index) {
                  final StaffItemCatalogEntry entry = visibleItems[index];
                  final bool selected = widget.initialSelection?.id == entry.id;
                  final Color rarityColor = StaffItemRarity.colorFor(entry.rarity);
                  final String rarityLabel = StaffItemRarity.labelFor(entry.rarity);
                  final IconData typeIcon = StaffItemRarity.iconForType(entry.itemType);

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        dismissKeyboard(context);
                        Navigator.of(context).pop(entry);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              rarityColor.withValues(alpha: selected ? 0.28 : 0.12),
                              SettingsPalette.navy.withValues(alpha: 0.70),
                              SettingsPalette.void_.withValues(alpha: 0.88),
                            ],
                          ),
                          border: Border.all(
                            color: selected
                                ? SettingsPalette.neon
                                : rarityColor.withValues(alpha: 0.55),
                            width: selected ? 1.8 : 1.2,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: (selected ? SettingsPalette.neon : rarityColor)
                                  .withValues(alpha: selected ? 0.35 : 0.16),
                              blurRadius: selected ? 12 : 8,
                              spreadRadius: selected ? 1 : 0,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: <Color>[
                                    rarityColor.withValues(alpha: 0.35),
                                    SettingsPalette.obsidian,
                                  ],
                                ),
                                border: Border.all(
                                  color: rarityColor.withValues(alpha: 0.7),
                                  width: 1.2,
                                ),
                              ),
                              child: Icon(typeIcon, color: rarityColor, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    entry.name,
                                    style: AppTextStyles.bodyBold.copyWith(
                                      color: SettingsPalette.textHi,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: <Widget>[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: rarityColor.withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: rarityColor.withValues(alpha: 0.55)),
                                        ),
                                        child: Text(
                                          rarityLabel,
                                          style: AppTextStyles.captionBold.copyWith(
                                            color: rarityColor,
                                            fontSize: 8.5,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        entry.id,
                                        style: supportCaptionStyle.copyWith(
                                          fontFamily: 'Courier',
                                          fontSize: 9.5,
                                          color: SettingsPalette.titanium,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: SettingsPalette.neon.withValues(alpha: 0.2),
                                  border: Border.all(color: SettingsPalette.neon),
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: SettingsPalette.neon,
                                  size: 16,
                                ),
                              )
                            else
                              Icon(
                                Icons.chevron_right_rounded,
                                color: SettingsPalette.titanium.withValues(alpha: 0.4),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
