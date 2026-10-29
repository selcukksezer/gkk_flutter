import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../components/common/inline_error_retry.dart';
import '../../components/common/item_icon_view.dart';
import '../../components/common/profile_avatar.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/services/presence_service.dart';
import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../l10n/l10n.dart';
import '../../models/mekan_model.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/mekan_detail_provider.dart';
import '../../providers/mekan_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import 'widgets/mekan_3d_viewport.dart';
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
  bool _refreshing = false;
  bool _nightlifeBusy = false;

  @override
  void initState() {
    super.initState();
    PresenceService.instance.setCurrentMekan(widget.mekanId);
  }

  @override
  void dispose() {
    PresenceService.instance.setCurrentMekan(null);
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    if (silent && mounted) setState(() => _refreshing = true);
    invalidateMekanDetail(ref, widget.mekanId);
    try {
      await ref.read(mekanDetailProvider(widget.mekanId).future);
    } catch (_) {
      // Handled by AsyncValue in UI
    }
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _openBuySheet(Mekan mekan, MekanStockEntry item, Color accent) async {
    if (!mekan.isOpen || mekan.raidClosed) {
      AppMessenger.showError(context, 'Mekan kapalı');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BuySheet(
        item: item,
        happyHour: mekan.happyHourActive,
        accent: accent,
        onConfirm: (int qty) => _buy(mekan, item, qty),
      ),
    );
  }

  Future<void> _refill(MekanStockEntry item) async {
    if (_nightlifeBusy) return;
    setState(() => _nightlifeBusy = true);
    try {
      final MekanRefillResult result = await ref.read(mekanRepositoryProvider).refill(
            mekanId: widget.mekanId,
            itemId: item.itemId,
          );
      if (!mounted) return;
      await ref.read(playerProvider.notifier).loadProfile();
      if (!mounted) return;
      await _showRefillResult(result);
      await _reload(silent: true);
    } catch (e) {
      if (mounted) {
        AppMessenger.showError(
          context,
          userFacingErrorMessage(e, fallback: context.l10n.nightlife_busy),
        );
      }
    } finally {
      if (mounted) setState(() => _nightlifeBusy = false);
    }
  }

  Future<void> _showRefillResult(MekanRefillResult result) async {
    final l10n = context.l10n;
    final Color accent = result.isOverdose ? MekanPalette.ruby : MekanPalette.neon;
    final String title = result.isOverdose ? l10n.nightlife_overdose : l10n.nightlife_refill_ok;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
            child: Container(
              padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.viewInsetsOf(ctx).bottom + 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[MekanPalette.surfaceHi, MekanPalette.void_],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: accent, width: 1.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(color: MekanPalette.textLow, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.nightlife_result,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: MekanPalette.textMid,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: accent),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.message,
                    style: const TextStyle(fontSize: 14, color: MekanPalette.textHi, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      GlowChip(
                        icon: Icons.bolt_rounded,
                        label: '${l10n.nightlife_energy_cost} ${result.energyBefore}→${result.energyAfter}',
                        color: MekanPalette.aqua,
                      ),
                      GlowChip(
                        icon: Icons.confirmation_number_rounded,
                        label: '${l10n.nightlife_tickets} ${result.ticketsLeft}',
                        color: MekanPalette.solar,
                      ),
                      GlowChip(
                        icon: Icons.monetization_on_rounded,
                        label: 'Gold -${result.goldPaid}',
                        color: MekanPalette.gold,
                      ),
                      GlowChip(
                        icon: Icons.medication_liquid_rounded,
                        label: '${l10n.nightlife_addiction} ${result.addictionLevel} · ${result.tolerance}%',
                        color: MekanPalette.fuchsia,
                      ),
                      if (result.odNextWarning)
                        GlowChip(
                          icon: Icons.warning_amber_rounded,
                          label: l10n.nightlife_od_warning,
                          color: MekanPalette.ruby,
                        ),
                    ],
                  ),
                  if (result.hospital) ...<Widget>[
                    const SizedBox(height: 14),
                    NeonButton(
                      label: l10n.nightlife_hospital_cta,
                      icon: Icons.local_hospital_rounded,
                      accent: MekanPalette.ruby,
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        context.go(AppRoutes.hospital);
                      },
                    ),
                  ] else ...<Widget>[
                    const SizedBox(height: 14),
                    NeonButton(
                      label: 'Tamam',
                      accent: accent,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openRefillSheet(Mekan mekan, List<MekanStockEntry> refillStock, Color accent) async {
    final l10n = context.l10n;
    if (refillStock.isEmpty) {
      AppMessenger.showError(context, l10n.nightlife_no_refill_stock);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.72),
              padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.viewInsetsOf(ctx).bottom + 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[MekanPalette.surfaceHi, MekanPalette.void_],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: accent, width: 1.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(color: MekanPalette.textLow, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.nightlife_buy_drink,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: MekanPalette.textHi),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.nightlife_enter_free,
                    style: const TextStyle(fontSize: 12, color: MekanPalette.textMid),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: refillStock.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int i) {
                        final MekanStockEntry s = refillStock[i];
                        final bool own = ref.read(playerProvider).profile?.authId == mekan.ownerId;
                        final String priceLabel = own
                            ? '1 ${l10n.nightlife_tickets}'
                            : '${s.sellPrice}g + 1 ${l10n.nightlife_tickets}';
                        return Container(
                          decoration: BoxDecoration(
                            color: MekanPalette.surface.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: accent.withValues(alpha: 0.35), width: 0.8),
                          ),
                          child: ListTile(
                            leading: ItemIconView(iconValue: s.icon, size: 36),
                            title: Text(s.name, style: const TextStyle(color: MekanPalette.textHi, fontWeight: FontWeight.w800)),
                            subtitle: Text(
                              'x${s.quantity} · $priceLabel',
                              style: const TextStyle(color: MekanPalette.textMid, fontSize: 12),
                            ),
                            trailing: NeonButton(
                              label: l10n.nightlife_refill,
                              accent: MekanPalette.neon,
                              expand: false,
                              busy: _nightlifeBusy,
                              onPressed: _nightlifeBusy
                                  ? null
                                  : () async {
                                      Navigator.of(ctx).pop();
                                      await _refill(s);
                                    },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmUpgrade(Mekan mekan) async {
    final int nextLevel = mekan.level + 1;
    final int cost = mekan.level * 2500000;
    final profile = ref.read(playerProvider).profile;
    final int currentGold = profile?.gold ?? 0;
    final bool canAfford = currentGold >= cost;

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: MekanPalette.surfaceHi,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: MekanPalette.gold, width: 1.2),
        ),
        title: const Row(
          children: <Widget>[
            Icon(Icons.upgrade_rounded, color: MekanPalette.gold, size: 24),
            SizedBox(width: 8),
            Text(
              'Mekanı Yükselt',
              style: TextStyle(color: MekanPalette.textHi, fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Seviye ${mekan.level} → Seviye $nextLevel',
              style: const TextStyle(color: MekanPalette.textHi, fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Yükseltme Ücreti: ${formatMekanGold(cost)} Altın',
              style: const TextStyle(color: MekanPalette.gold, fontWeight: FontWeight.w700),
            ),
            Text(
              'Mevcut Bakiyeniz: ${formatMekanGold(currentGold)} Altın',
              style: TextStyle(
                color: canAfford ? MekanPalette.textMid : MekanPalette.ruby,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Yükseltme Avantajları:\n• +100 Stok kapasitesi\n• Daha yüksek kâr marjı bonusu\n• +100 Şöhret puanı',
              style: TextStyle(color: MekanPalette.textMid, fontSize: 12.5, height: 1.4),
            ),
            if (!canAfford) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MekanPalette.ruby.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: MekanPalette.ruby.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.warning_amber_rounded, size: 16, color: MekanPalette.ruby),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Yetersiz altın! Yükseltme yapılamaz.',
                        style: TextStyle(color: MekanPalette.ruby, fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç', style: TextStyle(color: MekanPalette.textMid)),
          ),
          FilledButton(
            onPressed: canAfford ? () => Navigator.pop(ctx, true) : null,
            style: FilledButton.styleFrom(
              backgroundColor: MekanPalette.gold,
              foregroundColor: const Color(0xFF2A1E00),
            ),
            child: const Text('Yükselt', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      setState(() => _nightlifeBusy = true);
      try {
        await ref.read(mekanRepositoryProvider).upgrade(mekan.id);
        if (!mounted) return;
        await ref.read(playerProvider.notifier).loadProfile();
        if (!mounted) return;
        AppMessenger.showSuccess(context, 'Mekan Seviye $nextLevel\'e yükseltildi! 🎉');
        await _reload(silent: true);
      } catch (e) {
        if (mounted) {
          AppMessenger.showError(
            context,
            userFacingErrorMessage(e, fallback: 'Yükseltme başarısız oldu.'),
          );
        }
      } finally {
        if (mounted) setState(() => _nightlifeBusy = false);
      }
    }
  }

  Future<bool> _buy(Mekan mekan, MekanStockEntry item, int qty) async {
    final profile = ref.read(playerProvider).profile;
    if (profile == null) return false;
    final double mult = mekan.happyHourActive ? 0.8 : 1.0;
    final int cost = (item.sellPrice * qty * mult).floor();
    if (profile.gold < cost) {
      if (mounted) AppMessenger.showError(context, 'Yetersiz altın');
      return false;
    }

    final addCheck = ref.read(inventoryProvider.notifier).canAddItem(itemId: item.itemId, quantity: qty);
    if (!addCheck.canAdd) {
      if (mounted) AppMessenger.show(context, addCheck.reason ?? 'Envanter dolu');
      return false;
    }

    try {
      final Map<String, dynamic> res = await ref
          .read(mekanRepositoryProvider)
          .buy(mekanId: widget.mekanId, itemId: item.itemId, quantity: qty);
      if (!mounted) return false;
      await ref.read(playerProvider.notifier).loadProfile();
      if (!mounted) return false;
      await ref.read(inventoryProvider.notifier).loadInventory(silent: true);
      if (mounted) {
        if (res['police_raid'] == true) {
          AppMessenger.showError(context, 'Polis baskını! Mekan 48 saat kapatıldı.');
        } else {
          AppMessenger.showSuccess(
            context,
            res['happy_hour'] == true ? 'Satın alındı (Happy Hour!)' : 'Satın alındı',
          );
        }
        await _reload(silent: true);
      }
      return true;
    } catch (e) {
      if (mounted) {
        AppMessenger.showError(
          context,
          userFacingErrorMessage(e, fallback: 'Satın alma başarısız.'),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(playerProvider).profile;
    final AsyncValue<MekanDetailState> detailAsync = ref.watch(mekanDetailProvider(widget.mekanId));

    return MekanSubScaffold(
      title: detailAsync.maybeWhen(data: (MekanDetailState s) => s.mekan?.name ?? 'Mekan', orElse: () => 'Mekan'),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: MekanPalette.aqua)),
        error: (Object error, StackTrace _) => InlineErrorRetry(
          message: error.toString(),
          onRetry: () => invalidateMekanDetail(ref, widget.mekanId),
        ),
        data: (MekanDetailState detail) {
          final Mekan? mekan = detail.mekan;
          if (mekan == null) {
            return MekanEmpty(
              icon: Icons.search_off_rounded,
              title: 'Mekan bulunamadı',
              message: 'Bu mekan kaldırılmış olabilir.',
              accent: MekanPalette.ruby,
              action: NeonButton(
                label: 'Listeye Dön',
                onPressed: () => context.go(AppRoutes.mekans),
                expand: false,
              ),
            );
          }

          final bool isOwner = profile?.authId == mekan.ownerId;
          final String typeKey = mekan.typeKey;
          final Color accent = MekanPalette.accent(typeKey);
          final List<MekanStockEntry> vitrinStock = mekanVitrinStock(mekan, detail.stock);
          final List<MekanStockEntry> refillStock =
              vitrinStock.where((MekanStockEntry s) => s.canRefill).toList(growable: false);
          final String vitrinSubtitle = !mekan.isOpen || mekan.raidClosed
              ? (mekan.raidClosed ? 'Polis baskını — satış kapalı' : 'Mekan kapalı')
              : '${vitrinStock.length} ürün satışta';

          final DateTime? partyUntil = mekan.happyHourActive
              ? DateTime.tryParse(mekan.happyHourUntil ?? '')
              : null;

          return Stack(
            children: <Widget>[
              RefreshIndicator(
                color: accent,
                backgroundColor: MekanPalette.navy,
                onRefresh: () => _reload(silent: true),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      child: Mekan3DViewport(
                        selectedLocationType: typeKey,
                        height: 250,
                        showPoiPins: false,
                        showDungeonCard: true,
                        onEnterDungeon: (_, _) {
                          if (mekanSupportsPvp(typeKey)) {
                            context.go(AppRoutes.mekanArena(widget.mekanId));
                          } else {
                            context.go(AppRoutes.dungeon);
                          }
                        },
                      ),
                    ),
                    SliverToBoxAdapter(child: _header(mekan, accent, isOwner, typeKey)),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      sliver: SliverToBoxAdapter(
                        child: _upgradesPanel(mekan, accent, isOwner),
                      ),
                    ),
                    if (detail.presence.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                        sliver: SliverToBoxAdapter(
                          child: _presencePanel(detail.presence, accent),
                        ),
                      ),
                    if (mekan.happyHourActive && partyUntil != null)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                        sliver: SliverToBoxAdapter(
                          child: HappyHourBanner(
                            until: partyUntil,
                            title: context.l10n.party_live,
                            subtitle: context.l10n.party_live_subtitle,
                          ),
                        ),
                      ),
                    if (mekan.isOpen && !mekan.raidClosed)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                        sliver: SliverToBoxAdapter(
                          child: _nightlifePanel(mekan, accent, isOwner, refillStock),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                      sliver: SliverToBoxAdapter(
                        child: NeonSectionHeader(
                          title: 'Vitrin',
                          subtitle: vitrinSubtitle,
                          accent: accent,
                        ),
                      ),
                    ),
                    if (vitrinStock.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            14,
                            24,
                            14,
                            GameScrollLayout.bottomInset(context) + kGameChatFabSize + 24,
                          ),
                          child: MekanEmpty(
                            icon: Icons.inventory_2_outlined,
                            title: 'Vitrin boş',
                            message: !mekan.isOpen || mekan.raidClosed
                                ? 'Bu mekanda şu an satış yapılmıyor.'
                                : 'Bu mekanda şu an satılık ürün yok.',
                            accent: accent,
                            action: NeonButton(
                              label: 'Başka mekanlara göz at',
                              icon: Icons.explore_rounded,
                              accent: accent,
                              expand: false,
                              onPressed: () => context.go(AppRoutes.mekans),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: GameScrollLayout.fromLTRB(
                          context,
                          left: 14,
                          top: 0,
                          right: 14,
                          bottomExtra: kGameChatFabSize + 12,
                        ),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int i) {
                              final MekanStockEntry s = vitrinStock[i];
                              final bool canBuy = !isOwner && mekan.isOpen && !mekan.raidClosed;
                              final bool canRefillHere = s.canRefill && mekan.isOpen && !mekan.raidClosed;
                              return LootStockCard(
                                name: s.name,
                                itemId: s.itemId,
                                icon: s.icon,
                                rarity: s.rarity,
                                quantity: s.quantity,
                                price: mekan.happyHourActive ? (s.sellPrice * 0.8).floor() : s.sellPrice,
                                isHanOnly: s.isHanOnly,
                                contraband: mekanItemIsContraband(s.itemId),
                                discounted: mekan.happyHourActive,
                                onTap: canRefillHere
                                    ? () => _refill(s)
                                    : (canBuy ? () => _openBuySheet(mekan, s, accent) : null),
                                trailing: canRefillHere
                                    ? NeonButton(
                                        label: context.l10n.nightlife_refill,
                                        accent: MekanPalette.neon,
                                        onPressed: _nightlifeBusy ? null : () => _refill(s),
                                      )
                                    : canBuy
                                        ? NeonButton(
                                            label: 'Satın Al',
                                            accent: MekanPalette.gold,
                                            onPressed: () => _openBuySheet(mekan, s, accent),
                                          )
                                        : null,
                              );
                            },
                            childCount: vitrinStock.length,
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
          );
        },
      ),
    );
  }

  Widget _upgradesPanel(Mekan mekan, Color accent, bool isOwner) {
    const int maxLevel = 10;
    final bool isMaxed = mekan.level >= maxLevel;
    final int nextCost = mekan.level * 2500000;
    final double progress = (mekan.level / maxLevel).clamp(0.0, 1.0);

    String tierName;
    String tierPerk;
    if (mekan.level <= 2) {
      tierName = 'Başlangıç Hanı';
      tierPerk = 'Temel vitrin & menü servisi (100 kapasite)';
    } else if (mekan.level <= 5) {
      tierName = 'Popüler Mekan';
      tierPerk = 'Genişletilmiş kapasite, +%15 kâr marjı';
    } else if (mekan.level <= 9) {
      tierName = 'Elit Salon';
      tierPerk = 'VIP müşteri akışı, +%30 kâr bonusu, +500 şöhret';
    } else {
      tierName = 'Efsanevi Han İmparatorluğu';
      tierPerk = 'Maksimum kapasite & şehir çapında itibar';
    }

    return NeonPanel(
      accent: MekanPalette.gold,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: MekanPalette.gold,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: MekanPalette.gold.withValues(alpha: 0.6), blurRadius: 8),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'MEKAN KADEMESİ & GELİŞTİRME',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: MekanPalette.textHi,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              GlowChip(
                icon: Icons.military_tech_rounded,
                label: 'Lv ${mekan.level}/$maxLevel',
                color: isMaxed ? MekanPalette.solar : MekanPalette.gold,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Icon(Icons.workspace_premium_rounded, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                tierName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
              const Spacer(),
              Text(
                '%${(progress * 100).toInt()}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: MekanPalette.textMid,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: MekanPalette.obsidian,
              color: MekanPalette.gold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.check_circle_outline_rounded, size: 14, color: MekanPalette.neon),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tierPerk,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: MekanPalette.textMid,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (!isMaxed) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: MekanPalette.surfaceHi.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.arrow_upward_rounded, size: 14, color: MekanPalette.solar),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Seviye ${mekan.level + 1} gereksinimi: ${formatMekanGold(nextCost)} Altın',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: MekanPalette.textHi,
                      ),
                    ),
                  ),
                  const GlowChip(
                    icon: Icons.star_rounded,
                    label: '+100 Şöhret',
                    color: MekanPalette.gold,
                  ),
                ],
              ),
            ),
          ],
          if (isOwner && !isMaxed) ...<Widget>[
            const SizedBox(height: 12),
            NeonButton(
              label: 'Mekanı Yükselt (${formatMekanGold(nextCost)})',
              icon: Icons.upgrade_rounded,
              accent: MekanPalette.gold,
              busy: _nightlifeBusy,
              onPressed: _nightlifeBusy ? null : () => _confirmUpgrade(mekan),
            ),
          ] else if (isOwner && isMaxed) ...<Widget>[
            const SizedBox(height: 10),
            const Center(
              child: GlowChip(
                icon: Icons.emoji_events_rounded,
                label: 'Maksimum Seviyeye Ulaşıldı (Lv 10)',
                color: MekanPalette.solar,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _nightlifePanel(
    Mekan mekan,
    Color accent,
    bool isOwner,
    List<MekanStockEntry> refillStock,
  ) {
    final l10n = context.l10n;
    final bool partyOn = mekan.happyHourActive;
    final profile = ref.watch(playerProvider).profile;
    final int tickets = profile?.nightlifeTickets ?? 0;
    final int addiction = profile?.addictionLevel ?? 0;
    final int tol = profile?.tolerance ?? 0;
    return NeonPanel(
      accent: accent,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          NeonSectionHeader(
            title: l10n.nightlife_floor,
            subtitle: l10n.nightlife_floor_subtitle,
            accent: accent,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.nightlife_enter_free,
            style: const TextStyle(fontSize: 11.5, color: MekanPalette.textMid, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              GlowChip(
                icon: Icons.confirmation_number_rounded,
                label: '${l10n.nightlife_tickets} $tickets',
                color: MekanPalette.solar,
              ),
              GlowChip(
                icon: Icons.medication_liquid_rounded,
                label: '${l10n.nightlife_addiction} $addiction · $tol%',
                color: MekanPalette.fuchsia,
              ),
              if (isOwner)
                GlowChip(
                  icon: Icons.shield_rounded,
                  label: l10n.nightlife_own_safe,
                  color: MekanPalette.neon,
                ),
            ],
          ),
          const SizedBox(height: 12),
          NeonButton(
            label: l10n.nightlife_buy_drink,
            icon: Icons.local_bar_rounded,
            accent: MekanPalette.aqua,
            busy: _nightlifeBusy,
            onPressed: _nightlifeBusy ? null : () => _openRefillSheet(mekan, refillStock, accent),
          ),
          if (isOwner) ...<Widget>[
            const SizedBox(height: 10),
            NeonButton(
              label: partyOn ? l10n.party_live : l10n.start_party,
              icon: Icons.campaign_rounded,
              filled: false,
              accent: MekanPalette.coral,
              busy: _nightlifeBusy,
              onPressed: (_nightlifeBusy || partyOn)
                  ? null
                  : () async {
                      setState(() => _nightlifeBusy = true);
                      try {
                        await ref.read(mekanRepositoryProvider).startParty(mekanId: mekan.id);
                        if (!mounted) return;
                        await ref.read(playerProvider.notifier).loadProfile();
                        if (mounted) {
                          AppMessenger.showSuccess(context, l10n.party_live);
                          await _reload(silent: true);
                        }
                      } catch (e) {
                        if (mounted) {
                          AppMessenger.showError(
                            context,
                            userFacingErrorMessage(e, fallback: l10n.nightlife_busy),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _nightlifeBusy = false);
                      }
                    },
            ),
            if (!partyOn)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.nightlife_no_party,
                  style: const TextStyle(fontSize: 11.5, color: MekanPalette.textMid, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _presencePanel(List<Map<String, dynamic>> presence, Color accent) {
    final String who = context.l10n.who_is_here;
    return NeonPanel(
      accent: accent,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF35E08C),
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: const Color(0xFF35E08C).withValues(alpha: 0.8), blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${who.toUpperCase()} (${presence.length})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: accent,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: presence.length,
              separatorBuilder: (_, int i) => const SizedBox(width: 12),
              itemBuilder: (BuildContext context, int i) {
                final Map<String, dynamic> p = presence[i];
                final String name =
                    ((p['display_name'] ?? '').toString().isNotEmpty ? p['display_name'] : p['username'] ?? '?')
                        .toString();
                final String avatarUrl = (p['avatar_url'] ?? '').toString();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.2),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: accent.withValues(alpha: 0.25),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: ProfileAvatar(
                        size: 38,
                        avatarUrl: avatarUrl,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 60,
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: MekanPalette.textHi,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCounters(Mekan mekan, Color accent) {
    final bool hasPvp = mekanSupportsPvp(mekan.typeKey);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: MekanPalette.void_.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _StatColumn(
              icon: Icons.military_tech_rounded,
              label: 'Seviye',
              value: 'Lv ${mekan.level}',
              color: accent,
            ),
          ),
          _statDivider(),
          Expanded(
            child: _StatColumn(
              icon: Icons.star_rounded,
              label: 'Şöhret',
              value: '${mekan.fame}',
              color: MekanPalette.gold,
            ),
          ),
          _statDivider(),
          Expanded(
            child: _StatColumn(
              icon: Icons.shopping_bag_outlined,
              label: 'Satış',
              value: '${mekan.totalSales}',
              color: MekanPalette.aqua,
            ),
          ),
          _statDivider(),
          Expanded(
            child: _StatColumn(
              icon: Icons.paid_rounded,
              label: 'Hacim',
              value: formatMekanGold(mekan.totalRevenue),
              color: MekanPalette.solar,
            ),
          ),
          if (hasPvp) ...<Widget>[
            _statDivider(),
            Expanded(
              child: _StatColumn(
                icon: Icons.sports_mma_rounded,
                label: 'PvP',
                value: '${mekan.pvpMatchCount}',
                color: MekanPalette.ruby,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: Colors.white.withValues(alpha: 0.1),
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
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: MekanPalette.textHi,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mekanTypeLabelKey(typeKey),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent),
                      ),
                    ],
                  ),
                ),
                MekanStatusPill(isOpen: mekan.isOpen && !mekan.raidClosed),
              ],
            ),
            const SizedBox(height: 14),
            _statCounters(mekan, accent),
            if (mekan.suspicion > 0) ...<Widget>[
              const SizedBox(height: 12),
              SuspicionMeter(value: mekan.suspicion),
            ],
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
                      child: Text(
                        'Polis baskını nedeniyle geçici olarak kapalı.',
                        style: TextStyle(fontSize: 12.5, color: MekanPalette.textHi, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (isOwner)
              Row(
                children: <Widget>[
                  Expanded(
                    child: NeonButton(
                      label: 'Mekanı Yönet',
                      icon: Icons.tune_rounded,
                      accent: accent,
                      onPressed: () => context.go(AppRoutes.myMekan),
                    ),
                  ),
                  if (!mekan.raidClosed) ...<Widget>[
                    const SizedBox(width: 10),
                    Expanded(
                      child: NeonButton(
                        label: mekan.isOpen ? 'Kapat' : 'Aç',
                        icon: mekan.isOpen ? Icons.lock_rounded : Icons.lock_open_rounded,
                        filled: false,
                        accent: mekan.isOpen ? MekanPalette.ruby : MekanPalette.neon,
                        busy: _nightlifeBusy,
                        onPressed: _nightlifeBusy
                            ? null
                            : () async {
                                setState(() => _nightlifeBusy = true);
                                try {
                                  await ref.read(mekanRepositoryProvider).toggleStatus(
                                        mekanId: mekan.id,
                                        isOpen: !mekan.isOpen,
                                      );
                                  if (!mounted) return;
                                  AppMessenger.showSuccess(
                                    context,
                                    mekan.isOpen ? 'Mekan kapatıldı' : 'Mekan açıldı',
                                  );
                                  await _reload(silent: true);
                                } catch (e) {
                                  if (mounted) {
                                    AppMessenger.showError(
                                      context,
                                      userFacingErrorMessage(e, fallback: 'İşlem başarısız.'),
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => _nightlifeBusy = false);
                                }
                              },
                      ),
                    ),
                  ],
                ],
              )
            else if (mekanSupportsPvp(typeKey) && !mekan.raidClosed)
              TutorialAnchorScope(
                id: TutorialAnchorId.mekansArenaCta,
                child: NeonButton(
                  label: 'PvP Arena',
                  icon: Icons.sports_mma_rounded,
                  accent: MekanPalette.ruby,
                  onPressed: () {
                    TutorialTriggers.onAnchorTap(
                      ref,
                      TutorialAnchorId.mekansArenaCta,
                    );
                    context.go(AppRoutes.mekanArena(mekan.id));
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: MekanPalette.textHi,
            letterSpacing: 0.2,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: MekanPalette.textLow,
          ),
        ),
      ],
    );
  }
}

class _BuySheet extends ConsumerStatefulWidget {
  const _BuySheet({
    required this.item,
    required this.happyHour,
    required this.accent,
    required this.onConfirm,
  });

  final MekanStockEntry item;
  final bool happyHour;
  final Color accent;
  final Future<bool> Function(int qty) onConfirm;

  @override
  ConsumerState<_BuySheet> createState() => _BuySheetState();
}

class _BuySheetState extends ConsumerState<_BuySheet> {
  int _qty = 1;
  bool _busy = false;

  int get _unit => widget.happyHour ? (widget.item.sellPrice * 0.8).floor() : widget.item.sellPrice;
  int get _total => _unit * _qty;

  @override
  void initState() {
    super.initState();
    _qty = widget.item.quantity > 0 ? 1 : 0;
  }

  void _setQty(int val) {
    final int max = math.max(1, widget.item.quantity);
    setState(() {
      _qty = val.clamp(1, max);
    });
  }

  @override
  Widget build(BuildContext context) {
    final int max = math.max(0, widget.item.quantity);
    final profile = ref.watch(playerProvider).profile;
    final int gold = profile?.gold ?? 0;
    final bool canAfford = gold >= _total;
    final bool inStock = max > 0;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
        child: Container(
          padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.viewInsetsOf(context).bottom + 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[MekanPalette.surfaceHi, MekanPalette.void_],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: widget.accent, width: 1.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: MekanPalette.textLow, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(color: widget.accent.withValues(alpha: 0.35), blurRadius: 16),
                      ],
                    ),
                    child: ItemIconView(iconValue: widget.item.icon, itemId: widget.item.itemId, size: 52, fallback: '🧪'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.item.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: MekanPalette.textHi),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: <Widget>[
                            Text('Stok: $max', style: const TextStyle(fontSize: 12, color: MekanPalette.textMid)),
                            const SizedBox(width: 10),
                            Text(
                              'Bakiyeniz: ${formatMekanGold(gold)}g',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: canAfford ? MekanPalette.gold : MekanPalette.ruby,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GoldPriceBadge(amount: _unit, discounted: widget.happyHour),
                ],
              ),
              const SizedBox(height: 18),
              if (inStock) ...<Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    _stepBtn(Icons.remove_rounded, () => _setQty(_qty - 1)),
                    SizedBox(
                      width: 80,
                      child: Text(
                        '$_qty',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: MekanPalette.textHi),
                      ),
                    ),
                    _stepBtn(Icons.add_rounded, () => _setQty(_qty + 1)),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    _quickQtyChip('+1', () => _setQty(_qty + 1)),
                    if (max >= 5) _quickQtyChip('+5', () => _setQty(_qty + 5)),
                    if (max >= 10) _quickQtyChip('+10', () => _setQty(_qty + 10)),
                    _quickQtyChip('MAX ($max)', () => _setQty(max)),
                  ],
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Bu ürün tükendi!',
                    style: TextStyle(color: MekanPalette.ruby, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text('Toplam Tutar', style: TextStyle(fontSize: 14, color: MekanPalette.textMid, fontWeight: FontWeight.w700)),
                  GoldPriceBadge(amount: _total, discounted: widget.happyHour),
                ],
              ),
              if (!canAfford && inStock) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'Yetersiz altın! (${formatMekanGold(_total - gold)} eksik)',
                  style: const TextStyle(fontSize: 12, color: MekanPalette.ruby, fontWeight: FontWeight.w700),
                ),
              ],
              const SizedBox(height: 16),
              NeonButton(
                label: inStock ? (canAfford ? 'Satın Al' : 'Yetersiz Altın') : 'Tükendi',
                icon: Icons.shopping_bag_rounded,
                accent: canAfford && inStock ? MekanPalette.gold : MekanPalette.obsidian,
                busy: _busy,
                onPressed: (_busy || !canAfford || !inStock)
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        final bool ok = await widget.onConfirm(_qty);
                        if (!context.mounted) return;
                        setState(() => _busy = false);
                        if (ok) Navigator.of(context).pop();
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickQtyChip(String label, VoidCallback onTap) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: widget.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: widget.accent.withValues(alpha: 0.4), width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: widget.accent),
        ),
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
          color: widget.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.accent.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, color: widget.accent, size: 24),
      ),
    );
  }
}
