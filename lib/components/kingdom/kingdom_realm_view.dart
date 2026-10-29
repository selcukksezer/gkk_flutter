import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/guild_war_model.dart';
import '../../providers/kingdom_market_blessing_provider.dart';
import '../../theme/app_colors.dart';
import 'kingdom_crest_icons.dart';
import 'kingdom_glass_card.dart';
import 'kingdom_market_blessing_banner.dart';
import 'kingdom_overview_card.dart';
import 'kingdom_realm_3d_viewport.dart';
import 'kingdom_territory_realm_controller.dart';

/// Master Kingdom Realm View component combining:
/// - 3D Realm Viewport with real .glb castle/citadel & territory models
/// - Kingdom stats & treasury tracking (Gold & Gems balances)
/// - Tax collection trigger & King gifts
/// - Territory dominance and siege status
/// - King market blessing banner & voting triggers
class KingdomRealmView extends ConsumerStatefulWidget {
  const KingdomRealmView({
    super.key,
    this.reignKingName = 'Aethelgard Hükümdarı',
    this.reignGuildName = 'Valhalla',
    this.goldBalance = 2450000,
    this.gemsBalance = 1580,
    this.dailyTaxRevenue = 420000,
    this.controlledTerritories = 4,
    this.totalTerritories = 6,
    this.isKing = false,
    this.territories,
    this.onTaxCollect,
    this.onSendGift,
    this.onInspectTerritory,
    this.onViewTerritoryMap,
    this.onVoteInElection,
    this.locationLabel,
    this.viewportHeight = 320.0,
  });

  final String reignKingName;
  final String reignGuildName;
  final num goldBalance;
  final num gemsBalance;
  final num dailyTaxRevenue;
  final int controlledTerritories;
  final int totalTerritories;
  final bool isKing;
  final List<TerritoryData>? territories;
  final VoidCallback? onTaxCollect;
  final void Function(String recipient, int amount, String note)? onSendGift;
  final void Function(RealmTerritoryNode node)? onInspectTerritory;
  final VoidCallback? onViewTerritoryMap;
  final VoidCallback? onVoteInElection;
  final String? locationLabel;
  final double viewportHeight;

  @override
  ConsumerState<KingdomRealmView> createState() => _KingdomRealmViewState();
}

class _KingdomRealmViewState extends ConsumerState<KingdomRealmView> {
  late final KingdomTerritoryRealmController _realmController;
  bool _collectingTax = false;

  @override
  void initState() {
    super.initState();
    _realmController = KingdomTerritoryRealmController();
  }

  @override
  void dispose() {
    _realmController.dispose();
    super.dispose();
  }

  Future<void> _handleCollectTax() async {
    if (_collectingTax) return;
    setState(() => _collectingTax = true);

    try {
      widget.onTaxCollect?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.liquidGold, width: 0.8),
            ),
            content: Row(
              children: <Widget>[
                const Text('🪙', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kraliyet vergisi toplandı: +${_formatNum(widget.dailyTaxRevenue)} Altın kasaya aktarıldı.',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _collectingTax = false);
    }
  }

  String _formatNum(num val) {
    final String raw = val.round().toString();
    final StringBuffer buf = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buf.write('.');
      buf.write(raw[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Top Realm Status Header
        _buildRealmHeaderBar(),

        const SizedBox(height: 10),

        // Hero 3D Realm Viewport with Castle, Bastions, and Treasury Modes
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.liquidGold.withValues(alpha: 0.35),
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.liquidGold.withValues(alpha: 0.12),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: KingdomRealm3DViewport(
              controller: _realmController,
              height: widget.viewportHeight,
              territories: widget.territories,
              onInspectTerritory: widget.onInspectTerritory,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Active King Market Blessing Banner (Preserves state from provider)
        KingdomMarketBlessingBanner(
          locationLabel: widget.locationLabel,
          margin: const EdgeInsets.only(bottom: 12),
        ),

        // Quick Action Command Strip (Tax Collection, Manage, Map)
        _buildQuickActionBar(),

        const SizedBox(height: 12),

        // Treasury Stats Card
        KingdomTreasuryCard(
          goldBalance: widget.goldBalance,
          gemBalance: widget.gemsBalance,
          dailyTaxRevenue: widget.dailyTaxRevenue,
          isKing: widget.isKing,
          canGift: widget.isKing,
          onGiftSend: () => _showGiftDialog(context),
          onViewLedger: () => _realmController.setMode(KingdomRealmMode.treasury),
        ),

        const SizedBox(height: 12),

        // Territory Control Card
        KingdomTerritoryCard(
          realmName: 'Aethelgard Hükümranlığı',
          controlledProvinces: widget.controlledTerritories,
          totalProvinces: widget.totalTerritories,
          defenseLevel: 5,
          taxYieldMultiplier: 1.35,
          isUnderSiege: false,
          onManage: () => _realmController.setMode(KingdomRealmMode.territory),
          onViewMap: widget.onViewTerritoryMap,
        ),
      ],
    );
  }

  Widget _buildRealmHeaderBar() {
    return Row(
      children: <Widget>[
        const KingdomCrestIcon(
          type: KingdomCrestType.crown,
          size: 36,
          showGlow: true,
          animatedPulse: true,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'AETHELGARD KRALLIK REJİMİ',
                style: TextStyle(
                  color: AppColors.liquidGold,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                'Hükümdar: ${widget.reignKingName} [${widget.reignGuildName}]',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Day/Dusk time badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.4)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('🏰', style: TextStyle(fontSize: 11)),
              SizedBox(width: 4),
              Text(
                '3D Hükümranlık',
                style: TextStyle(
                  color: AppColors.liquidGold,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionBar() {
    return Row(
      children: <Widget>[
        // Tax collection button
        Expanded(
          flex: 5,
          child: FilledButton.icon(
            onPressed: _collectingTax ? null : _handleCollectTax,
            icon: _collectingTax
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.monetization_on_rounded, size: 16),
            label: Text(
              _collectingTax ? 'Toplanıyor...' : 'Vergiyi Kasaya Aktar',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.liquidGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Switch to 3D Continental Map View
        Expanded(
          flex: 4,
          child: OutlinedButton.icon(
            onPressed: () => _realmController.setMode(KingdomRealmMode.territory),
            icon: const Icon(Icons.public_rounded, size: 16),
            label: const Text(
              '3D Harita',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentCyan,
              side: BorderSide(color: AppColors.accentCyan.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  void _showGiftDialog(BuildContext context) {
    final TextEditingController userCtrl = TextEditingController();
    final TextEditingController amtCtrl = TextEditingController(text: '10000');
    final TextEditingController noteCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.liquidGold, width: 0.8),
          ),
          title: const Row(
            children: <Widget>[
              Text('👑', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text('Kral Hediyesi Gönder', style: TextStyle(color: AppColors.liquidGold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: userCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Oyuncu Adı',
                  labelStyle: TextStyle(color: Colors.white60),
                  prefixIcon: Icon(Icons.person_outline, color: AppColors.liquidGold, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amtCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Altın Miktarı',
                  labelStyle: TextStyle(color: Colors.white60),
                  prefixIcon: Icon(Icons.monetization_on_outlined, color: AppColors.liquidGold, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Hediye Notu (Opsiyonel)',
                  labelStyle: TextStyle(color: Colors.white60),
                  prefixIcon: Icon(Icons.note_alt_outlined, color: AppColors.liquidGold, size: 18),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal', style: TextStyle(color: Colors.white60)),
            ),
            FilledButton(
              onPressed: () {
                final String username = userCtrl.text.trim();
                final int amount = int.tryParse(amtCtrl.text.trim()) ?? 0;
                final String note = noteCtrl.text.trim();
                Navigator.pop(ctx);
                if (username.isNotEmpty && amount > 0) {
                  widget.onSendGift?.call(username, amount, note);
                }
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.liquidGold),
              child: const Text('Gönder', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
  }
}
