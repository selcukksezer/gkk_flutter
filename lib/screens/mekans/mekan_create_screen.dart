import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../providers/mekan_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import 'widgets/mekan_design.dart';
import 'widgets/mekan_scaffold.dart';
import 'widgets/mekan_theme.dart';
import '../../l10n/l10n.dart';

class MekanCreateScreen extends ConsumerStatefulWidget {
  const MekanCreateScreen({super.key});

  @override
  ConsumerState<MekanCreateScreen> createState() => _MekanCreateScreenState();
}

class _MekanCreateScreenState extends ConsumerState<MekanCreateScreen> {
  final TextEditingController _name = TextEditingController();
  String? _selectedType;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final String? type = _selectedType;
    if (type == null) {
      AppMessenger.show(context, 'Once bir tur sec');
      return;
    }
    if (_name.text.trim().isEmpty) {
      AppMessenger.show(context, 'Mekan adi gerekli');
      return;
    }
    final MekanTypeInfo info = MekanTypeInfo.all.firstWhere((MekanTypeInfo t) => t.type == type);
    final profile = ref.read(playerProvider).profile;
    if (profile == null) return;
    if (profile.level < info.reqLevel) {
      AppMessenger.show(context, 'Level ${info.reqLevel} gerekli');
      return;
    }
    if (profile.gold < info.cost) {
      AppMessenger.showError(context, 'Yetersiz altin (${formatMekanGold(info.cost)})');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(mekanRepositoryProvider).createMekan(type: type, name: _name.text.trim());
      await ref.read(playerProvider.notifier).loadProfile();
      if (mounted) {
        AppMessenger.showSuccess(context, 'Mekan acildi!');
        context.go(AppRoutes.myMekan);
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showError(context, '$e');
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(playerProvider).profile;
    final int gold = profile?.gold ?? 0;
    final int level = profile?.level ?? 0;
    final MekanTypeInfo? selected =
        _selectedType == null ? null : MekanTypeInfo.all.firstWhere((MekanTypeInfo t) => t.type == _selectedType);
    final bool canCreate = selected != null &&
        _name.text.trim().isNotEmpty &&
        level >= selected.reqLevel &&
        gold >= selected.cost;

    return MekanSubScaffold(
      title: context.l10n.mekan_ac,
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              children: <Widget>[
                NeonPanel(
                  accent: MekanPalette.gold,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('IMPARATORLUGUNU KUR',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: MekanPalette.textHi, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      const Text('Bir tur sec, adini koy ve han ticaretine basla.',
                          style: TextStyle(fontSize: 12.5, color: MekanPalette.textMid)),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          GlowChip(icon: Icons.paid_rounded, label: formatMekanGold(gold), color: MekanPalette.gold),
                          const SizedBox(width: 8),
                          GlowChip(icon: Icons.military_tech_rounded, label: 'Lv $level', color: MekanPalette.aqua),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _name,
                        maxLength: 30,
                        style: const TextStyle(color: MekanPalette.textHi, fontWeight: FontWeight.w700),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Mekan adi',
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
                NeonSectionHeader(title: context.l10n.mekan_turu, subtitle: context.l10n.her_tur_farkli_kapasite_ve_pvp_yetenegi_sunar, accent: MekanPalette.gold),
                const SizedBox(height: 12),
                ...MekanTypeInfo.all.map((MekanTypeInfo info) {
                  final bool locked = level < info.reqLevel || gold < info.cost;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TypeArtCard(
                      info: info,
                      selected: _selectedType == info.type,
                      locked: locked,
                      affordable: gold >= info.cost,
                      levelOk: level >= info.reqLevel,
                      onTap: locked ? null : () => setState(() => _selectedType = info.type),
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
            child: NeonButton(
              label: selected == null ? 'Tur Sec' : 'Mekani Ac - ${formatMekanGold(selected.cost)}',
              icon: Icons.storefront_rounded,
              accent: MekanPalette.gold,
              busy: _busy,
              onPressed: canCreate ? _create : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeArtCard extends StatelessWidget {
  const _TypeArtCard({
    required this.info,
    required this.selected,
    required this.locked,
    required this.affordable,
    required this.levelOk,
    required this.onTap,
  });

  final MekanTypeInfo info;
  final bool selected;
  final bool locked;
  final bool affordable;
  final bool levelOk;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = MekanPalette.accent(info.type);
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? accent : Colors.white.withValues(alpha: 0.08),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? <BoxShadow>[BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 18)]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: <Widget>[
            // Art header band.
            Container(
              height: 78,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[accent.withValues(alpha: 0.38), MekanPalette.navy],
                ),
              ),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    right: -10,
                    top: -10,
                    child: Icon(MekanPalette.typeIcon(info.type), size: 96, color: accent.withValues(alpha: 0.20)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: <Widget>[
                        MekanTypeBadge(typeKey: info.type, size: 50),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text(info.name,
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: MekanPalette.textHi)),
                              if (mekanSupportsPvp(info.type))
                                const Text('PvP Arena destekli',
                                    style: TextStyle(fontSize: 11, color: MekanPalette.textMid, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        if (selected)
                          Icon(Icons.check_circle_rounded, color: accent, size: 26)
                        else if (locked)
                          const Icon(Icons.lock_rounded, color: MekanPalette.textLow, size: 22),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              color: MekanPalette.surface.withValues(alpha: 0.6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(info.description,
                      style: const TextStyle(fontSize: 12.5, color: MekanPalette.textMid, height: 1.35)),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      GlowChip(
                        icon: Icons.paid_rounded,
                        label: formatMekanGold(info.cost),
                        color: affordable ? MekanPalette.gold : MekanPalette.ruby,
                      ),
                      const SizedBox(width: 8),
                      GlowChip(
                        icon: Icons.military_tech_rounded,
                        label: 'Lv ${info.reqLevel}',
                        color: levelOk ? MekanPalette.neon : MekanPalette.ruby,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
