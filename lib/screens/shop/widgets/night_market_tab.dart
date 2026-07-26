import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../components/common/app_messenger.dart';
import '../../../components/common/item_icon_view.dart';
import '../../../components/common/gkk_tab_page_shell.dart';
import '../../../components/layout/game_screen_background.dart';
import '../../../core/services/retention_analytics.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/tutorial/tutorial_anchor.dart';
import '../../../core/tutorial/tutorial_track.dart';
import '../../../models/night_market_model.dart';
import '../../../qa/qa_flags.dart';
import '../../../theme/app_colors.dart';

class NightMarketTab extends StatefulWidget {
  const NightMarketTab({
    super.key,
    required this.onPurchased,
  });

  final VoidCallback onPurchased;

  @override
  State<NightMarketTab> createState() => _NightMarketTabState();
}

class _NightMarketTabState extends State<NightMarketTab> with SingleTickerProviderStateMixin {
  NightMarketStatus _status = NightMarketStatus.closed;
  bool _loading = true;
  String? _buyingId;
  Timer? _tickTimer;
  late final AnimationController _closedPulseCtrl;

  @override
  void initState() {
    super.initState();
    _closedPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _bootstrap();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_status.active) return;
      setState(() {
        _status = NightMarketStatus(
          active: _status.active,
          startsAt: _status.startsAt,
          endsAt: _status.endsAt,
          secondsLeft: (_status.secondsLeft - 1).clamp(0, 999999),
          shadowBonus: _status.shadowBonus,
          shadowDiscountPct: _status.shadowDiscountPct,
          offers: _status.offers,
        );
      });
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _closedPulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (QaFlags.forceNightMarketOpen) {
      try {
        await SupabaseService.client.rpc(
          'qa_force_night_market',
          params: <String, dynamic>{'p_open': true},
        );
      } catch (_) {
        // QA flag optional — normal schedule still applies.
      }
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dynamic raw = await SupabaseService.client.rpc('get_night_market_status');
      if (!mounted) return;
      if (raw is Map && raw['success'] == true) {
        setState(() {
          _status = NightMarketStatus.fromJson(Map<String, dynamic>.from(raw));
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatCountdown(int seconds) {
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    final int s = seconds % 60;
    if (h > 0) return '${h}s ${m}dk ${s}sn';
    if (m > 0) return '${m}dk ${s}sn';
    return '${s}sn';
  }

  String _nextOpenLabel() {
    final DateTime? startsAt = _status.startsAt;
    if (startsAt == null) return 'Her gün 20:00–22:00 (TR)';
    final DateTime local = startsAt.toLocal();
    final DateTime now = DateTime.now();
    final bool today = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final String dayLabel = today ? 'Bugün' : 'Yarın';
    final String time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$dayLabel $time\'de açılır';
  }

  Future<void> _buy(NightMarketOffer offer, int qty) async {
    if (_buyingId != null) return;
    setState(() => _buyingId = offer.offerId);
    try {
      final dynamic res = await SupabaseService.client.rpc(
        'buy_night_market_item',
        params: <String, dynamic>{
          'p_offer_id': offer.offerId,
          'p_quantity': qty,
        },
      );
      if (!mounted) return;
      if (res is Map && res['success'] == true) {
        RetentionAnalytics.nightMarketBuy(
          offerId: offer.offerId,
          itemName: offer.itemName,
          qty: qty,
        );
        AppMessenger.show(context, '🌙 ${offer.itemName} satın alındı!');
        widget.onPurchased();
        await _load();
      } else {
        AppMessenger.showError(
          context,
          (res is Map ? res['error']?.toString() : null) ?? 'Satın alma başarısız.',
        );
      }
    } catch (_) {
      if (mounted) AppMessenger.showError(context, 'Satın alma başarısız.');
    } finally {
      if (mounted) setState(() => _buyingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      color: AppColors.cyberFuchsia,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: GameScrollLayout.fromLTRB(
          context,
          left: 14,
          top: 4,
          right: 14,
          bottomExtra: 48,
        ),
        children: <Widget>[
          _buildTimerBanner(),
          if (_status.shadowBonus) ...<Widget>[
            const SizedBox(height: 10),
            DottedPanel(
              borderColor: AppColors.accentPurpleGlow,
              child: const Row(
                children: <Widget>[
                  Icon(Icons.nightlight_round, color: AppColors.accentPurple, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Gölge sınıfı: %5 gem indirimi +1 stok',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (!_status.active)
            _buildClosedState()
          else
            ..._status.offers.asMap().entries.map(
              (MapEntry<int, NightMarketOffer> entry) {
                final Widget card = GkkTabStaggerItem(
                  index: entry.key,
                  child: _NightMarketOfferCard(
                    offer: entry.value,
                    active: _status.active,
                    buyingId: _buyingId,
                    onBuy: () => _buy(entry.value, 1),
                  ),
                );
                if (entry.key != 0) return card;
                return TutorialAnchorScope(
                  id: TutorialAnchorId.shopNightOffer,
                  child: card,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildClosedState() {
    return AnimatedBuilder(
      animation: _closedPulseCtrl,
      builder: (BuildContext context, Widget? child) {
        final double pulse = 0.35 + _closedPulseCtrl.value * 0.25;
        return SizedBox(
          width: double.infinity,
          child: DottedPanel(
            borderColor: AppColors.warningSolar.withValues(alpha: pulse),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.nights_stay_rounded,
                  color: AppColors.warningSolar.withValues(alpha: 0.5 + pulse * 0.5),
                  size: 52,
                ),
                const SizedBox(height: 12),
                Text(
                  'Gece Pazarı uyuyor',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.urbanist(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _nextOpenLabel(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.warningSolar,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: AppColors.warningSolar.withValues(alpha: 0.1),
                    border: Border.all(
                      color: AppColors.warningSolar.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text(
                    'Gem ile sınırlı stoklu gizli teklifler.\nAçılışta bildirim al.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.mutedTitanium,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimerBanner() {
    final Color accent =
        _status.active ? AppColors.warningSolar : AppColors.mutedTitanium;
    return SizedBox(
      width: double.infinity,
      child: DottedPanel(
        borderColor: accent.withValues(alpha: 0.45),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              _status.active ? Icons.nights_stay_rounded : Icons.schedule_rounded,
              color: accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _status.active ? 'GECE PAZARI AÇIK' : 'Sonraki pazar',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.urbanist(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: accent,
                    ),
                  ),
                  Text(
                    _status.active
                        ? 'Kapanış: ${_formatCountdown(_status.secondsLeft)}'
                        : _nextOpenLabel(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
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

class _NightMarketOfferCard extends StatefulWidget {
  const _NightMarketOfferCard({
    required this.offer,
    required this.active,
    required this.buyingId,
    required this.onBuy,
  });

  final NightMarketOffer offer;
  final bool active;
  final String? buyingId;
  final VoidCallback onBuy;

  @override
  State<_NightMarketOfferCard> createState() => _NightMarketOfferCardState();
}

class _NightMarketOfferCardState extends State<_NightMarketOfferCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  bool _pressed = false;

  bool get _lowStock =>
      widget.offer.remaining > 0 &&
      widget.offer.remaining <= (widget.offer.stockPerPlayer <= 1 ? 1 : 2);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (_lowStock) _pulseCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _NightMarketOfferCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_lowStock && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!_lowStock && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final NightMarketOffer offer = widget.offer;
    final Color glow = AppColors.forRarity(offer.rarity ?? 'rare');
    final bool canBuy =
        widget.active && offer.remaining > 0 && widget.buyingId == null;
    final bool soldOut = offer.remaining <= 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (BuildContext context, Widget? _) {
          final double pulseAlpha = _lowStock ? 0.35 + _pulseCtrl.value * 0.35 : 0.4;
          return DottedPanel(
            borderColor: soldOut
                ? AppColors.mutedTitanium.withValues(alpha: 0.25)
                : glow.withValues(alpha: pulseAlpha),
            child: Row(
              children: <Widget>[
                ItemIconView(
                  itemId: offer.itemId,
                  iconValue: offer.icon ?? '',
                  size: 52,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        offer.itemName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        children: <Widget>[
                          if (_lowStock && !soldOut)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.mysticRuby.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: AppColors.mysticRuby.withValues(
                                    alpha: 0.45 + _pulseCtrl.value * 0.35,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'AZ STOK',
                                style: TextStyle(
                                  color: AppColors.mysticRuby,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          Text(
                            'Stok: ${offer.remaining}/${offer.stockPerPlayer}',
                            style: TextStyle(
                              color: soldOut
                                  ? AppColors.mysticRuby
                                  : _lowStock
                                      ? AppColors.warningSolar
                                      : AppColors.mutedTitanium,
                              fontSize: 11,
                              fontWeight:
                                  _lowStock ? FontWeight.w700 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '💎 ${offer.gemPrice}',
                        style: const TextStyle(
                          color: AppColors.accentCyan,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTapDown: canBuy ? (_) => setState(() => _pressed = true) : null,
                  onTapUp: canBuy ? (_) => setState(() => _pressed = false) : null,
                  onTapCancel: canBuy ? () => setState(() => _pressed = false) : null,
                  onTap: canBuy ? widget.onBuy : null,
                  child: AnimatedScale(
                    scale: _pressed && canBuy ? 0.94 : 1,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOutCubic,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: canBuy
                            ? LinearGradient(
                                colors: <Color>[
                                  AppColors.cyberFuchsia,
                                  AppColors.cyberFuchsia.withValues(alpha: 0.75),
                                ],
                              )
                            : null,
                        color: canBuy ? null : AppColors.darkObsidian.withValues(alpha: 0.55),
                        border: Border.all(
                          color: canBuy
                              ? AppColors.cyberFuchsia.withValues(alpha: 0.55)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        widget.buyingId == offer.offerId
                            ? '...'
                            : soldOut
                                ? 'Bitti'
                                : 'Al',
                        style: TextStyle(
                          color: canBuy ? Colors.white : AppColors.mutedTitanium,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
