import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/errors/user_facing_error.dart';
import '../../l10n/l10n.dart';
import '../../providers/mekan_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import 'widgets/mekan_design.dart';
import 'widgets/mekan_scaffold.dart';
import 'widgets/mekan_theme.dart';
import 'widgets/mekan_type_art_card.dart';

class MekanCreateScreen extends ConsumerStatefulWidget {
  const MekanCreateScreen({super.key});

  @override
  ConsumerState<MekanCreateScreen> createState() => _MekanCreateScreenState();
}

class _MekanCreateScreenState extends ConsumerState<MekanCreateScreen> {
  final TextEditingController _name = TextEditingController();
  String? _selectedType;
  bool _busy = false;
  List<MekanTypeInfo> _types = MekanTypeInfo.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTypeCatalog());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadTypeCatalog() async {
    try {
      final List<MekanTypeCatalogRow> rows =
          await ref.read(mekanRepositoryProvider).fetchTypeCatalog();
      if (!mounted || rows.isEmpty) return;
      setState(() => _types = _mergeTypeCatalog(rows));
    } catch (_) {
      // RPC yoksa veya hata olursa yerel fallback kullan.
    }
  }

  List<MekanTypeInfo> _mergeTypeCatalog(List<MekanTypeCatalogRow> rows) {
    final Map<String, MekanTypeCatalogRow> byType = <String, MekanTypeCatalogRow>{
      for (final MekanTypeCatalogRow row in rows) row.type: row,
    };
    return MekanTypeInfo.all
        .map((MekanTypeInfo base) {
          final MekanTypeCatalogRow? row = byType[base.type];
          if (row == null) return base;
          return MekanTypeInfo(
            type: base.type,
            name: base.name,
            description: base.description,
            cost: row.cost,
            reqLevel: row.reqLevel,
          );
        })
        .toList();
  }

  MekanTypeInfo? _infoFor(String? type) {
    if (type == null) return null;
    for (final MekanTypeInfo info in _types) {
      if (info.type == type) return info;
    }
    return null;
  }

  void _showLockedReason(MekanTypeInfo info, int level, int gold) {
    final List<String> missing = <String>[];
    if (level < info.reqLevel) {
      missing.add('Sv ${info.reqLevel} gerekli (sen: Sv $level)');
    }
    if (gold < info.cost) {
      missing.add('${formatMekanGold(info.cost)} altın gerekli');
    }
    AppMessenger.show(
      context,
      missing.isEmpty ? '${info.name} şu an kilitli.' : missing.join(' · '),
    );
  }

  Future<void> _create() async {
    final String? type = _selectedType;
    if (type == null) {
      AppMessenger.show(context, 'Önce bir tür seç');
      return;
    }
    if (_name.text.trim().isEmpty) {
      AppMessenger.show(context, 'Mekan adı gerekli');
      return;
    }
    final MekanTypeInfo? info = _infoFor(type);
    if (info == null) return;
    final profile = ref.read(playerProvider).profile;
    if (profile == null) return;
    if (profile.level < info.reqLevel) {
      AppMessenger.show(context, 'Sv ${info.reqLevel} gerekli');
      return;
    }
    if (profile.gold < info.cost) {
      AppMessenger.showError(context, 'Yetersiz altın (${formatMekanGold(info.cost)})');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(mekanRepositoryProvider).createMekan(type: type, name: _name.text.trim());
      await ref.read(playerProvider.notifier).loadProfile();
      ref.read(mekanHubRefreshProvider.notifier).touch();
      if (mounted) {
        AppMessenger.showSuccess(context, 'Mekan açıldı!');
        context.go(AppRoutes.myMekan);
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showError(
          context,
          userFacingErrorMessage(e, fallback: 'Mekan açılamadı.'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(playerProvider).profile;
    final int gold = profile?.gold ?? 0;
    final int level = profile?.level ?? 0;
    final MekanTypeInfo? selected = _infoFor(_selectedType);
    final bool canCreate = selected != null &&
        _name.text.trim().isNotEmpty &&
        level >= selected.reqLevel &&
        gold >= selected.cost;
    final bool hasAffordableType =
        _types.any((MekanTypeInfo t) => level >= t.reqLevel && gold >= t.cost);
    final MekanTypeInfo starter = _types.first;

    return MekanSubScaffold(
      title: context.l10n.mekan_ac,
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: GameScrollLayout.fromLTRB(
                context,
                left: 14,
                top: 14,
                right: 14,
                bottomExtra: kGameChatFabSize + 12,
              ),
              children: <Widget>[
                NeonPanel(
                  accent: MekanPalette.gold,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'İMPARATORLUĞUNU KUR',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: MekanPalette.textHi,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Bir tür seç, adını koy ve han ticaretine başla.',
                        style: TextStyle(fontSize: 12.5, color: MekanPalette.textMid),
                      ),
                      const SizedBox(height: 14),
                      GlowChip(icon: Icons.military_tech_rounded, label: 'Sv $level', color: MekanPalette.aqua),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _name,
                        maxLength: 30,
                        style: const TextStyle(color: MekanPalette.textHi, fontWeight: FontWeight.w700),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Mekan adı',
                          hintText: context.l10n.orn_golge_han_bar,
                          labelStyle: const TextStyle(color: MekanPalette.textMid),
                          hintStyle: const TextStyle(color: MekanPalette.textLow),
                          counterStyle: const TextStyle(color: MekanPalette.textLow),
                          prefixIcon: const Icon(Icons.edit_rounded, size: 18, color: MekanPalette.textMid),
                          filled: true,
                          fillColor: MekanPalette.void_.withValues(alpha: 0.4),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: MekanPalette.gold, width: 1.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                NeonSectionHeader(
                  title: context.l10n.mekan_turu,
                  subtitle: context.l10n.her_tur_farkli_kapasite_ve_pvp_yetenegi_sunar,
                  accent: MekanPalette.gold,
                ),
                const SizedBox(height: 12),
                ..._types.map((MekanTypeInfo info) {
                  final bool locked = level < info.reqLevel || gold < info.cost;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: MekanTypeArtCard(
                      info: info,
                      selected: _selectedType == info.type,
                      locked: locked,
                      affordable: gold >= info.cost,
                      levelOk: level >= info.reqLevel,
                      onTap: () => setState(() => _selectedType = info.type),
                      onLockedTap: () => _showLockedReason(info, level, gold),
                    ),
                  );
                }),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.paddingOf(context).bottom + 10),
            decoration: const BoxDecoration(
              color: MekanPalette.void_,
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (!hasAffordableType)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'En ucuz tür ${starter.name}: Sv ${starter.reqLevel} ve ${formatMekanGold(starter.cost)} altın gerekir.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11.5, color: MekanPalette.textMid, height: 1.3),
                    ),
                  ),
                NeonButton(
                  label: selected == null ? 'Tür Seç' : 'Mekanı Aç — ${formatMekanGold(selected.cost)}',
                  icon: Icons.storefront_rounded,
                  accent: MekanPalette.gold,
                  busy: _busy,
                  onPressed: canCreate ? _create : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
