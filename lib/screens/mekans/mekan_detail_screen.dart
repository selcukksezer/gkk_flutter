import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_screen_background.dart';
import '../../components/common/item_icon_view.dart';
import '../../models/mekan_model.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/mekan_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import 'widgets/mekan_design.dart';
import 'widgets/mekan_scaffold.dart';
import 'widgets/mekan_theme.dart';

class MekanDetailScreen extends ConsumerStatefulWidget {
  const MekanDetailScreen({super.key, required this.mekanId});
  final String mekanId;

  @override
  ConsumerState<MekanDetailScreen> createState() => _MekanDetailScreenState();
}

class _MekanDetailScreenState extends ConsumerState<MekanDetailScreen> {
  Mekan? _mekan;
  List<MekanStockEntry> _stock = <MekanStockEntry>[];
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!mounted) return;
    setState(() => silent ? _refreshing = true : _loading = true);
    try {
      final MekanRepository repo = ref.read(mekanRepositoryProvider);
      final Mekan? m = await repo.fetchMekan(widget.mekanId);
      final List<MekanStockEntry> s =
          m == null ? <MekanStockEntry>[] : await repo.fetchStock(widget.mekanId, onlyAvailable: true);
      if (mounted) {
        setState(() {
          _mekan = m;
          _stock = s;
          _loading = false;
          _refreshing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _openBuySheet(MekanStockEntry item) async {
    final Mekan? mekan = _mekan;
    if (mekan == null) return;
    if (!mekan.isOpen || mekan.raidClosed) {
      AppMessenger.showError(context, 'Mekan kapali');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BuySheet(
        item: item,
        happyHour: mekan.happyHourActive,
        onConfirm: (int qty) => _buy(item, qty),
      ),
    );
  }

  Future<void> _buy(MekanStockEntry item, int qty) async {
    final profile = ref.read(playerProvider).profile;
    if (profile == null) return;
    final double mult = (_mekan?.happyHourActive ?? false) ? 0.8 : 1.0;
    final int cost = (item.sellPrice * qty * mult).floor();
    if (profile.gold < cost) {
      AppMessenger.showError(context, 'Yetersiz altin');
      return;
    }
    await ref.read(inventoryProvider.notifier).loadInventory(silent: true);
    final addCheck = ref.read(inventoryProvider.notifier).canAddItem(itemId: item.itemId, quantity: qty);
    if (!addCheck.canAdd) {
      if (mounted) AppMessenger.show(context, addCheck.reason ?? 'Envanter dolu');
      return;
    }

    try {
      final Map<String, dynamic> res =
          await ref.read(mekanRepositoryProvider).buy(mekanId: widget.mekanId, itemId: item.itemId, quantity: qty);
      await ref.read(playerProvider.notifier).loadProfile();
      await ref.read(inventoryProvider.notifier).loadInventory(silent: true);
      if (mounted) {
        if (res['police_raid'] == true) {
          AppMessenger.showError(context, 'POLIS BASKINI! Mekan 48 saat kapatildi.');
        } else {
          AppMessenger.showSuccess(context, res['happy_hour'] == true ? 'Satin alindi (Happy Hour!)' : 'Satin alindi');
        }
        await _load(silent: true);
      }
    } catch (e) {
      if (mounted) AppMessenger.showError(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(playerProvider).profile;
    final Mekan? mekan = _mekan;
    final bool isOwner = profile?.authId == mekan?.ownerId;
    final String? typeKey = mekan?.typeKey;
    final Color accent = MekanPalette.accent(typeKey);

    return MekanSubScaffold(
      title: mekan?.name ?? 'Mekan',
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: MekanPalette.aqua))
          : mekan == null
              ? MekanEmpty(
                  icon: Icons.search_off_rounded,
                  title: 'Mekan bulunamadi',
                  message: 'Bu mekan kaldirilmis olabilir.',
                  accent: MekanPalette.ruby,
                  action: NeonButton(
                    label: 'Listeye Don',
                    onPressed: () => context.go(AppRoutes.mekans),
                    expand: false,
                  ),
                )
              : Stack(
                  children: <Widget>[
                    RefreshIndicator(
                      color: accent,
                      backgroundColor: MekanPalette.navy,
                      onRefresh: () => _load(silent: true),
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: <Widget>[
                          SliverToBoxAdapter(child: _header(mekan, accent, isOwner, typeKey)),
                          if (mekan.happyHourActive)
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                              sliver: SliverToBoxAdapter(
                                child: HappyHourBanner(until: DateTime.parse(mekan.happyHourUntil!)),
                              ),
                            ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                            sliver: SliverToBoxAdapter(
                              child: NeonSectionHeader(
                                title: 'Vitrin',
                                subtitle: mekan.isOpen ? '${_stock.length} urun satista' : 'Mekan kapali',
                                accent: accent,
                              ),
                            ),
                          ),
                          if (_stock.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: MekanEmpty(
                                icon: Icons.inventory_2_outlined,
                                title: 'Vitrin bos',
                                message: 'Bu mekanda su an satilik urun yok.',
                                accent: accent,
                              ),
                            )
                          else
                            SliverPadding(
                              padding: GameScrollLayout.fromLTRB(context, left: 14, top: 0, right: 14),
                              sliver: SliverGrid(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.72,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (BuildContext context, int i) {
                                    final MekanStockEntry s = _stock[i];
                                    final bool canBuy = !isOwner && mekan.isOpen && !mekan.raidClosed;
                                    return LootStockCard(
                                      name: s.name,
                                      itemId: s.itemId,
                                      icon: s.icon,
                                      rarity: s.rarity,
                                      quantity: s.quantity,
                                      price: mekan.happyHourActive ? (s.sellPrice * 0.8).floor() : s.sellPrice,
                                      isHanOnly: s.isHanOnly,
                                      contraband: s.itemId == 'han_item_berserk' || s.itemId == 'han_item_shadow_brew',
                                      discounted: mekan.happyHourActive,
                                      onTap: canBuy ? () => _openBuySheet(s) : null,
                                      trailing: canBuy
                                          ? NeonButton(
                                              label: 'Satin Al',
                                              accent: MekanPalette.gold,
                                              onPressed: () => _openBuySheet(s),
                                            )
                                          : null,
                                    );
                                  },
                                  childCount: _stock.length,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_refreshing)
                      const Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: MekanPalette.aqua),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _header(Mekan mekan, Color accent, bool isOwner, String? typeKey) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: NeonPanel(
        accent: accent,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                MekanTypeBadge(typeKey: typeKey, size: 60),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        mekan.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: MekanPalette.textHi, height: 1.1),
                      ),
                      const SizedBox(height: 2),
                      Text(mekanTypeLabelKey(typeKey),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent)),
                    ],
                  ),
                ),
                MekanStatusPill(isOpen: mekan.isOpen && !mekan.raidClosed),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                GlowChip(icon: Icons.military_tech_rounded, label: 'Seviye ${mekan.level}', color: accent),
                GlowChip(icon: Icons.star_rounded, label: '${mekan.fame} sohret', color: MekanPalette.gold),
                if (mekan.suspicion > 40)
                  GlowChip(
                    icon: Icons.visibility_rounded,
                    label: 'Suphe ${mekan.suspicion}',
                    color: mekan.suspicion > 60 ? MekanPalette.ruby : MekanPalette.solar,
                  ),
              ],
            ),
            if (mekan.raidClosed) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MekanPalette.ruby.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MekanPalette.ruby.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.local_police_rounded, color: MekanPalette.ruby, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Polis baskini nedeniyle gecici olarak kapali.',
                          style: TextStyle(fontSize: 12.5, color: MekanPalette.textHi, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (isOwner)
              NeonButton(
                label: 'Mekani Yonet',
                icon: Icons.tune_rounded,
                accent: accent,
                onPressed: () => context.go(AppRoutes.myMekan),
              )
            else if (mekanSupportsPvp(typeKey) && mekan.isOpen)
              NeonButton(
                label: 'PvP Arena',
                icon: Icons.sports_mma_rounded,
                accent: MekanPalette.ruby,
                onPressed: () => context.go('/mekans/${mekan.id}/arena'),
              ),
          ],
        ),
      ),
    );
  }
}

class _BuySheet extends StatefulWidget {
  const _BuySheet({required this.item, required this.happyHour, required this.onConfirm});
  final MekanStockEntry item;
  final bool happyHour;
  final Future<void> Function(int qty) onConfirm;

  @override
  State<_BuySheet> createState() => _BuySheetState();
}

class _BuySheetState extends State<_BuySheet> {
  int _qty = 1;
  bool _busy = false;

  int get _unit => widget.happyHour ? (widget.item.sellPrice * 0.8).floor() : widget.item.sellPrice;
  int get _total => _unit * _qty;

  @override
  Widget build(BuildContext context) {
    final int max = widget.item.quantity;
    return Container(
      padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.viewInsetsOf(context).bottom + 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[MekanPalette.surfaceHi, MekanPalette.void_],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: MekanPalette.aqua, width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(width: 44, height: 4, decoration: BoxDecoration(color: MekanPalette.textLow, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[BoxShadow(color: MekanPalette.aqua.withValues(alpha: 0.3), blurRadius: 16)],
                ),
                child: ItemIconView(iconValue: widget.item.icon, itemId: widget.item.itemId, size: 52, fallback: '🧪'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(widget.item.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: MekanPalette.textHi)),
                    Text('Stok: $max', style: const TextStyle(fontSize: 12, color: MekanPalette.textMid)),
                  ],
                ),
              ),
              GoldPriceBadge(amount: _unit, discounted: widget.happyHour),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _stepBtn(Icons.remove_rounded, () => setState(() => _qty = (_qty - 1).clamp(1, max))),
              SizedBox(
                width: 80,
                child: Text('$_qty',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: MekanPalette.textHi)),
              ),
              _stepBtn(Icons.add_rounded, () => setState(() => _qty = (_qty + 1).clamp(1, max))),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text('Toplam', style: TextStyle(fontSize: 14, color: MekanPalette.textMid, fontWeight: FontWeight.w700)),
              GoldPriceBadge(amount: _total, discounted: widget.happyHour),
            ],
          ),
          const SizedBox(height: 16),
          NeonButton(
            label: 'Satin Al',
            icon: Icons.shopping_bag_rounded,
            accent: MekanPalette.gold,
            busy: _busy,
            onPressed: () async {
              setState(() => _busy = true);
              await widget.onConfirm(_qty);
              if (mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: MekanPalette.aqua.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MekanPalette.aqua.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, color: MekanPalette.aqua, size: 24),
      ),
    );
  }
}
