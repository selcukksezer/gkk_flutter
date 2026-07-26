import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/keyboard_dismiss.dart';
import '../../../models/staff_model.dart';
import '../../../repositories/staff_repository.dart';
import '../../support/widgets/support_design.dart';
import 'staff_design.dart';

/// LiveOps / staff formları — eşya adıyla ara, listeden seç.
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
    return SettingsGlassCard(
      accent: SettingsPalette.obsidian,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(label, style: supportCaptionStyle),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item?.name ?? hint,
                      style: supportBodyStyle.copyWith(
                        color: item == null ? SettingsPalette.textMid : SettingsPalette.textHi,
                        fontWeight: item == null ? FontWeight.w500 : FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item != null)
                      Text(item.id, style: supportCaptionStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (item != null)
                IconButton(
                  tooltip: 'Temizle',
                  onPressed: () => onChanged(null),
                  icon: Icon(Icons.close_rounded, color: SettingsPalette.ruby, size: 20),
                ),
              StaffActionButton(
                label: item == null ? 'Seç' : 'Değiştir',
                outlined: true,
                onPressed: () => _openPicker(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
    _debounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_load(_search.text.trim()));
    });
  }

  Future<void> _load(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _repo.searchItems(query, limit: 80);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = result.error;
      _items = result.items;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double maxH = MediaQuery.sizeOf(context).height * 0.72;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SettingsSectionHeader(
            icon: Icons.inventory_2_outlined,
            title: 'Eşya seç',
            subtitle: 'İsim veya ID ile ara',
            accent: SettingsPalette.fuchsia,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _search,
            style: supportBodyStyle,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => dismissKeyboard(context),
            decoration: supportInputDecoration(label: 'Ara', hint: 'kılıç, potion, item_id…'),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: SettingsPalette.fuchsia)),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: supportCaptionStyle.copyWith(color: SettingsPalette.ruby)),
            )
          else
            Expanded(
              child: ListView.separated(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (BuildContext context, int index) {
                  final StaffItemCatalogEntry entry = _items[index];
                  final bool selected = widget.initialSelection?.id == entry.id;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        dismissKeyboard(context);
                        Navigator.of(context).pop(entry);
                      },
                      child: SettingsGlassCard(
                        accent: selected ? SettingsPalette.neon : SettingsPalette.obsidian,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    entry.name,
                                    style: supportBodyStyle.copyWith(fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${entry.id}${entry.rarity != null ? ' · ${entry.rarity}' : ''}',
                                    style: supportCaptionStyle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              Icon(Icons.check_circle_rounded, color: SettingsPalette.neon, size: 20),
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
