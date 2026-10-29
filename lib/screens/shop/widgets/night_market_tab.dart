import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../components/common/app_messenger.dart';
import '../../../components/common/item_icon_view.dart';
import '../../../components/common/gkk_tab_page_shell.dart';
import '../../../components/kingdom/kingdom_market_blessing_banner.dart';
import '../../../components/layout/game_screen_background.dart';
import '../../../core/services/retention_analytics.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/tutorial/tutorial_anchor.dart';
import '../../../core/tutorial/tutorial_track.dart';
import '../../../models/kingdom_market_blessing_model.dart';
import '../../../models/night_market_model.dart';
import '../../../providers/kingdom_market_blessing_provider.dart';
import '../../../qa/qa_flags.dart';
import '../../../theme/app_colors.dart';
import '../../market/widgets/market_item_pedestal.dart';

class NightMarketTab extends ConsumerStatefulWidget {
  /// 2027 Aion 2 Dark-Glass Night Market Tab
  const NightMarketTab({
    super.key,
    required this.onPurchased,
  });

  final VoidCallback onPurchased;

  @override
  ConsumerState<NightMarketTab> createState() => _NightMarketTabState();
}

class _NightMarketTabState extends ConsumerState<NightMarketTab>
    with SingleTickerProviderStateMixin {
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
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.liquidGold,
          strokeWidth: 2.5,
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.liquidGold,
      backgroundColor: AppColors.bgDeep,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: GameScrollLayout.fromLTRB(
          context,
          left: 14,
          top: 6,
          right: 14,
          bottomExtra: 48,
        ),
        children: <Widget>[
          _buildTimerBanner(),
          const SizedBox(height: 10),
          const KingdomMarketBlessingBanner(locationLabel: 'Gece Pazarı'),
          if (_status.shadowBonus) ...<Widget>[
            const SizedBox(height: 10),
            _buildShadowBonusBanner(),
          ],
          const SizedBox(height: 14),
          if (!_status.active)
            _buildClosedState()
          else
            ..._status.offers.asMap().entries.map(
              (MapEntry<int, NightMarketOffer> entry) {
                final KingdomMarketBlessingStatus blessing =
                    ref.watch(kingdomMarketBlessingProvider);
                final int originalBasePrice = entry.value.baseGemPrice > 0
                    ? entry.value.baseGemPrice
                    : entry.value.gemPrice;
                final Widget card = GkkTabStaggerItem(
                  index: entry.key,
                  child: _NightMarketOfferCard(
                    offer: entry.value,
                    active: _status.active,
                    buyingId: _buyingId,
                    displayGemPrice: blessing.applyDiscount(
                      entry.value.gemPrice,
                      'gems',
                    ),
                    baseGemPrice: originalBasePrice,
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

  /// Obsidian Shadow Glass Banner when player possesses shadow alignment bonus.
  Widget _buildShadowBonusBanner() {
    return _NightMarketObsidianPanel(
      borderColor: AppColors.accentPurple.withValues(alpha: 0.6),
      glowColor: AppColors.accentPurpleGlow,
      borderRadius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accentPurple.withValues(alpha: 0.18),
              border: Border.all(
                color: AppColors.accentPurple.withValues(alpha: 0.5),
              ),
            ),
            child: const Icon(
              Icons.nightlight_round,
              color: AppColors.accentPurple,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'GÖLGE AYRICALIĞI',
                      style: GoogleFonts.urbanist(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: AppColors.accentPurple,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.accentPurple.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '%5 İNDİRİM',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Gölge sınıfı bonusu ile +1 ek pazar stoğu aktif.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 2027 Aion 2 Altar of the Night — Ornate dark-fantasy resting state.
  Widget _buildClosedState() {
    return AnimatedBuilder(
      animation: _closedPulseCtrl,
      builder: (BuildContext context, Widget? child) {
        final double pulse = _closedPulseCtrl.value;
        final double glowAlpha = 0.25 + pulse * 0.35;

        return _NightMarketObsidianPanel(
          borderColor: AppColors.liquidGold.withValues(alpha: glowAlpha * 0.7),
          glowColor: AppColors.liquidGold.withValues(alpha: glowAlpha * 0.3),
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Concentric Pulsing Moon Altar Portal
              Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  // Outer runic ring
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.liquidGold.withValues(alpha: 0.12 + pulse * 0.18),
                        width: 1.5,
                      ),
                    ),
                  ),
                  // Middle aura
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[
                          AppColors.accentPurple.withValues(alpha: 0.22 + pulse * 0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  // Inner Talisman
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          AppColors.darkObsidian,
                          AppColors.carbonVoid,
                        ],
                      ),
                      border: Border.all(
                        color: AppColors.warningSolar.withValues(alpha: 0.5 + pulse * 0.5),
                        width: 1.5,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.warningSolar.withValues(alpha: 0.2 + pulse * 0.2),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.nights_stay_rounded,
                      color: AppColors.warningSolar.withValues(alpha: 0.7 + pulse * 0.3),
                      size: 32,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Gece Pazarı Uyuyor',
                textAlign: TextAlign.center,
                style: GoogleFonts.cinzel(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),

              // Mysterious Lore Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Gölgeler diyarının kadim tüccarları yalnızca alacakaranlık çöktüğünde tezgah açar.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.urbanist(
                    color: AppColors.mutedTitanium,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Schedule Pill (Responsive & Centered)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppColors.spaceNavy.withValues(alpha: 0.8),
                  border: Border.all(
                    color: AppColors.liquidGold.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.liquidGold.withValues(alpha: 0.15),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.schedule_rounded,
                      color: AppColors.liquidGold,
                      size: 15,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _nextOpenLabel(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.urbanist(
                          color: AppColors.liquidGold,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Feature Highlights — Overflow safe Wrap
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: const <Widget>[
                  _ClosedFeaturePill(label: '✦ Efsanevi Eşyalar'),
                  _ClosedFeaturePill(label: '✦ %50\'ye Varan İndirim'),
                  _ClosedFeaturePill(label: '✦ Gizli Stok'),
                ],
              ),
              const SizedBox(height: 16),

              // Info Callout Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppColors.bgDeep.withValues(alpha: 0.75),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: const Text(
                  'Gem ile sınırlı stoklu nadide teklifler sunulur.\nAçılış saatinde hazır olun.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.mutedTitanium,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 2027 Aion 2 Header Banner with animated living particles, celestial talisman,
  /// live status badge, and responsive countdown timer completely safe from overflow.
  Widget _buildTimerBanner() {
    final bool active = _status.active;
    final Color primaryAccent = active ? AppColors.warningSolar : AppColors.mutedTitanium;
    final Color secondaryGlow = active ? AppColors.accentCyan : AppColors.accentPurple;

    return _NightMarketObsidianPanel(
      borderColor: active
          ? AppColors.liquidGold.withValues(alpha: 0.55)
          : AppColors.mutedTitanium.withValues(alpha: 0.3),
      glowColor: active
          ? AppColors.liquidGold.withValues(alpha: 0.25)
          : Colors.transparent,
      borderRadius: 14,
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: <Widget>[
          // Living celestial particles in banner background
          const Positioned.fill(
            child: IgnorePointer(
              child: _NightSkyParticles(),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Lunar Talisman Seal
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      active ? AppColors.spaceNavy : AppColors.bgSurface,
                      AppColors.carbonVoid,
                    ],
                  ),
                  border: Border.all(
                    color: primaryAccent.withValues(alpha: 0.7),
                    width: 1.4,
                  ),
                  boxShadow: <BoxShadow>[
                    if (active)
                      BoxShadow(
                        color: secondaryGlow.withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    active ? Icons.nights_stay_rounded : Icons.schedule_rounded,
                    color: primaryAccent,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title and Countdown Row (Zero Overflow guaranteed by FittedBox/Expanded)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Top line: Header Title + Status Pill
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            'GECE PAZARI',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.urbanist(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: active
                                ? AppColors.toxicNeon.withValues(alpha: 0.16)
                                : AppColors.mutedTitanium.withValues(alpha: 0.15),
                            border: Border.all(
                              color: active
                                  ? AppColors.toxicNeon.withValues(alpha: 0.6)
                                  : AppColors.mutedTitanium.withValues(alpha: 0.4),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: active ? AppColors.toxicNeon : AppColors.mutedTitanium,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                active ? 'AÇIK' : 'UYKUDA',
                                style: TextStyle(
                                  color: active ? AppColors.toxicNeon : AppColors.mutedTitanium,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Bottom line: Formatted Countdown or Schedule
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            active ? Icons.timer_outlined : Icons.calendar_today_outlined,
                            size: 13,
                            color: active ? AppColors.accentCyan : AppColors.mutedTitanium,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            active
                                ? 'Kapanış: ${_formatCountdown(_status.secondsLeft)}'
                                : _nextOpenLabel(),
                            style: TextStyle(
                              color: active ? AppColors.accentCyan : Colors.white70,
                              fontSize: 12,
                              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Feature badge for closed altar state.
class _ClosedFeaturePill extends StatelessWidget {
  const _ClosedFeaturePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: AppColors.carbonVoid.withValues(alpha: 0.6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.mutedTitanium,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 2027 Aion 2 Dark-Glass Night Market Offer Card.
/// Complete with frosted obsidian backdrop, rarity-coded luminous borders, corner discount tags,
/// zero-overflow micro-typography, animated low-stock pulse, and tactile buy action.
class _NightMarketOfferCard extends StatefulWidget {
  const _NightMarketOfferCard({
    required this.offer,
    required this.active,
    required this.buyingId,
    required this.onBuy,
    required this.displayGemPrice,
    required this.baseGemPrice,
  });

  final NightMarketOffer offer;
  final bool active;
  final String? buyingId;
  final VoidCallback onBuy;
  final int displayGemPrice;
  final int baseGemPrice;

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

  /// Interactive 3D Item Inspection Sheet with MarketItemPedestal.
  void _openItemInspectionSheet(
    BuildContext context, {
    required int effectiveBase,
    required bool hasDiscount,
    required int discountPct,
    required bool canBuy,
    required bool soldOut,
  }) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
            decoration: BoxDecoration(
              color: AppColors.bgDeep.withValues(alpha: 0.94),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: AppColors.liquidGold.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.carbonVoid.withValues(alpha: 0.8),
                  blurRadius: 30,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                // Handle bar
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),

                // Header with Rarity Pill & Close
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.forRarity(widget.offer.rarity ?? 'rare')
                            .withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.forRarity(widget.offer.rarity ?? 'rare')
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        (widget.offer.rarity ?? 'rare').toUpperCase(),
                        style: TextStyle(
                          color: AppColors.forRarity(widget.offer.rarity ?? 'rare'),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.mutedTitanium, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 3D Item Pedestal with Live Rotation & Light Beam
                MarketItemPedestal(
                  rarity: widget.offer.rarity ?? 'rare',
                  iconValue: widget.offer.icon ?? '',
                  itemId: widget.offer.itemId,
                  itemName: widget.offer.itemName,
                  size: 140,
                  interactive: true,
                  autoRotate: true,
                  showLightBeam: true,
                  showRunicRings: true,
                ),
                const SizedBox(height: 12),

                // Item Name
                Text(
                  widget.offer.itemName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.urbanist(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),

                // Stock status
                Text(
                  soldOut
                      ? 'Tükendi'
                      : 'Kalan Kişisel Stok: ${widget.offer.remaining}/${widget.offer.stockPerPlayer}',
                  style: TextStyle(
                    color: soldOut
                        ? AppColors.mysticRuby
                        : _lowStock
                            ? AppColors.warningSolar
                            : AppColors.mutedTitanium,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),

                // Price Breakdown Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.spaceNavy.withValues(alpha: 0.6),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'FİYAT',
                            style: TextStyle(
                              color: AppColors.mutedTitanium,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: <Widget>[
                              if (hasDiscount) ...<Widget>[
                                Text(
                                  '💎 $effectiveBase',
                                  style: TextStyle(
                                    color: AppColors.mutedTitanium.withValues(alpha: 0.7),
                                    fontSize: 12,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                '💎 ${widget.displayGemPrice}',
                                style: const TextStyle(
                                  color: AppColors.liquidGold,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (hasDiscount && discountPct > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: <Color>[AppColors.cyberFuchsia, AppColors.coralFlare],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: AppColors.cyberFuchsia.withValues(alpha: 0.4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Text(
                            '-%$discountPct İNDİRİM',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Full-width purchase button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: canBuy
                        ? () {
                            Navigator.of(ctx).pop();
                            widget.onBuy();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canBuy ? AppColors.cyberFuchsia : AppColors.darkObsidian,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: canBuy
                              ? AppColors.liquidGold.withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      elevation: canBuy ? 6 : 0,
                    ),
                    child: Text(
                      soldOut ? 'Tükendi' : 'Hemen Satın Al',
                      style: TextStyle(
                        color: canBuy ? Colors.white : AppColors.mutedTitanium,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
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

  @override
  Widget build(BuildContext context) {
    final NightMarketOffer offer = widget.offer;
    final Color rarityColor = AppColors.forRarity(offer.rarity ?? 'rare');
    final bool canBuy =
        widget.active && offer.remaining > 0 && widget.buyingId == null;
    final bool soldOut = offer.remaining <= 0;

    // Accurate discount calculation
    final int effectiveBase = offer.baseGemPrice > 0
        ? offer.baseGemPrice
        : (widget.baseGemPrice > widget.displayGemPrice
            ? widget.baseGemPrice
            : offer.gemPrice);
    final bool hasDiscount = effectiveBase > widget.displayGemPrice;
    final int discountPct = hasDiscount && effectiveBase > 0
        ? (((effectiveBase - widget.displayGemPrice) / effectiveBase) * 100).round()
        : 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (BuildContext context, Widget? _) {
          final double pulseAlpha = _lowStock ? 0.35 + _pulseCtrl.value * 0.45 : 0.4;
          final Color borderColor = soldOut
              ? AppColors.mutedTitanium.withValues(alpha: 0.22)
              : rarityColor.withValues(alpha: pulseAlpha);

          return _NightMarketObsidianPanel(
            borderColor: borderColor,
            glowColor: soldOut
                ? Colors.transparent
                : rarityColor.withValues(alpha: _lowStock ? 0.25 : 0.12),
            borderRadius: 14,
            padding: const EdgeInsets.all(10),
            onTap: () => _openItemInspectionSheet(
              context,
              effectiveBase: effectiveBase,
              hasDiscount: hasDiscount,
              discountPct: discountPct,
              canBuy: canBuy,
              soldOut: soldOut,
            ),
            child: Row(
              children: <Widget>[
                // 1. Left: Pedestal Slot with ItemIconView & Discount Ribbon
                _OfferPedestalSlot(
                  itemId: offer.itemId,
                  icon: offer.icon ?? '',
                  rarityColor: rarityColor,
                  discountPct: hasDiscount ? discountPct : 0,
                  soldOut: soldOut,
                ),
                const SizedBox(width: 10),

                // 2. Center: Item Details (Zero Overflow via FittedBox + Expanded)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Line 1: Item Name
                      Text(
                        offer.itemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: soldOut ? AppColors.mutedTitanium : Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 3),

                      // Line 2: Rarity & Stock row (FittedBox scales down on narrow viewports)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            // Micro Rarity Tag
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: rarityColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: rarityColor.withValues(alpha: 0.45),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                (offer.rarity ?? 'rare').toUpperCase(),
                                style: TextStyle(
                                  color: rarityColor,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Low Stock Indicator
                            if (_lowStock && !soldOut) ...<Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.mysticRuby.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppColors.mysticRuby.withValues(
                                      alpha: 0.5 + _pulseCtrl.value * 0.4,
                                    ),
                                    width: 0.8,
                                  ),
                                ),
                                child: const Text(
                                  'AZ STOK',
                                  style: TextStyle(
                                    color: AppColors.mysticRuby,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],

                            // Stock count
                            Text(
                              soldOut
                                  ? 'Tükendi'
                                  : 'Stok: ${offer.remaining}/${offer.stockPerPlayer}',
                              style: TextStyle(
                                color: soldOut
                                    ? AppColors.mysticRuby
                                    : _lowStock
                                        ? AppColors.warningSolar
                                        : AppColors.mutedTitanium,
                                fontSize: 10.5,
                                fontWeight: _lowStock ? FontWeight.w800 : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Line 3: Pricing Row (FittedBox scales down cleanly)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (hasDiscount) ...<Widget>[
                              Text(
                                '💎 $effectiveBase',
                                style: TextStyle(
                                  color: AppColors.mutedTitanium.withValues(alpha: 0.7),
                                  fontSize: 11,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '💎 ${widget.displayGemPrice}',
                                style: const TextStyle(
                                  color: AppColors.liquidGold,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Text('👑', style: TextStyle(fontSize: 11)),
                            ] else ...<Widget>[
                              Text(
                                '💎 ${widget.displayGemPrice}',
                                style: const TextStyle(
                                  color: AppColors.accentCyan,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Right: Tactile Responsive Buy Button
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: canBuy ? (_) => setState(() => _pressed = true) : null,
                  onTapUp: canBuy ? (_) => setState(() => _pressed = false) : null,
                  onTapCancel: canBuy ? () => setState(() => _pressed = false) : null,
                  onTap: canBuy ? widget.onBuy : null,
                  child: AnimatedScale(
                    scale: _pressed && canBuy ? 0.93 : 1.0,
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.easeOutCubic,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 64,
                        maxWidth: 78,
                        minHeight: 38,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: canBuy
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: <Color>[
                                    AppColors.cyberFuchsia,
                                    Color(0xFFB5179E),
                                  ],
                                )
                              : null,
                          color: canBuy
                              ? null
                              : AppColors.darkObsidian.withValues(alpha: 0.5),
                          border: Border.all(
                            color: canBuy
                                ? AppColors.liquidGold.withValues(alpha: 0.55)
                                : Colors.white.withValues(alpha: 0.08),
                            width: 1.1,
                          ),
                          boxShadow: <BoxShadow>[
                            if (canBuy)
                              BoxShadow(
                                color: AppColors.cyberFuchsia.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                          ],
                        ),
                        child: Center(
                          child: widget.buyingId == offer.offerId
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    soldOut ? 'Tükendi' : 'Al',
                                    style: TextStyle(
                                      color: canBuy ? Colors.white : AppColors.mutedTitanium,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
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

/// Runic item pedestal slot with luminous border and corner discount ribbon.
class _OfferPedestalSlot extends StatelessWidget {
  const _OfferPedestalSlot({
    required this.itemId,
    required this.icon,
    required this.rarityColor,
    required this.discountPct,
    required this.soldOut,
  });

  final String itemId;
  final String icon;
  final Color rarityColor;
  final int discountPct;
  final bool soldOut;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        // Outer Pedestal Frame
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.spaceNavy.withValues(alpha: 0.95),
                AppColors.carbonVoid,
              ],
            ),
            border: Border.all(
              color: soldOut
                  ? AppColors.mutedTitanium.withValues(alpha: 0.25)
                  : rarityColor.withValues(alpha: 0.65),
              width: 1.2,
            ),
            boxShadow: <BoxShadow>[
              if (!soldOut)
                BoxShadow(
                  color: rarityColor.withValues(alpha: 0.22),
                  blurRadius: 8,
                ),
            ],
          ),
          child: Center(
            child: Opacity(
              opacity: soldOut ? 0.45 : 1.0,
              child: ItemIconView(
                itemId: itemId,
                iconValue: icon,
                size: 44,
              ),
            ),
          ),
        ),

        // Corner Discount Ribbon
        if (discountPct > 0 && !soldOut)
          Positioned(
            top: -5,
            right: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[AppColors.cyberFuchsia, AppColors.coralFlare],
                ),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 0.6,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.cyberFuchsia.withValues(alpha: 0.5),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Text(
                '-%$discountPct',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 2027 Aion 2 Obsidian Dark-Glass Panel Container.
/// Translucent obsidian glass, metallic filigree corners, and dot-mesh depth.
class _NightMarketObsidianPanel extends StatelessWidget {
  const _NightMarketObsidianPanel({
    required this.child,
    this.borderColor,
    this.glowColor,
    this.borderRadius = 14,
    this.padding,
    this.onTap,
  });

  final Widget child;
  final Color? borderColor;
  final Color? glowColor;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color border = borderColor ?? AppColors.liquidGold.withValues(alpha: 0.2);
    final Color glow = glowColor ?? Colors.transparent;

    final Widget panel = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border, width: 1.1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.carbonVoid.withValues(alpha: 0.7),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          if (glow != Colors.transparent)
            BoxShadow(
              color: glow,
              blurRadius: 12,
            ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF141926),
            AppColors.carbonVoid,
            Color(0xFF04060B),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: <Widget>[
            // Dot mesh layer
            const Positioned.fill(
              child: CustomPaint(
                painter: DotGridPainter(spacing: 12, dotOpacity: 0.045),
              ),
            ),
            // Corner filigree flourishes
            Positioned.fill(
              child: CustomPaint(
                painter: _FiligreeCornerPainter(color: border.withValues(alpha: 0.45)),
              ),
            ),
            // Content
            Padding(
              padding: padding ?? const EdgeInsets.all(12),
              child: child,
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return panel;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(borderRadius),
      splashColor: AppColors.liquidGold.withValues(alpha: 0.08),
      highlightColor: Colors.transparent,
      child: panel,
    );
  }
}

/// Ornate corner filigree painter for high-fantasy metallic aesthetics.
class _FiligreeCornerPainter extends CustomPainter {
  const _FiligreeCornerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double tick = 6.0;

    // Top-left
    canvas.drawLine(const Offset(3, 3), const Offset(3 + tick, 3), paint);
    canvas.drawLine(const Offset(3, 3), const Offset(3, 3 + tick), paint);

    // Top-right
    canvas.drawLine(Offset(size.width - 3, 3), Offset(size.width - 3 - tick, 3), paint);
    canvas.drawLine(Offset(size.width - 3, 3), Offset(size.width - 3, 3 + tick), paint);

    // Bottom-left
    canvas.drawLine(Offset(3, size.height - 3), Offset(3 + tick, size.height - 3), paint);
    canvas.drawLine(Offset(3, size.height - 3), Offset(3, size.height - 3 - tick), paint);

    // Bottom-right
    canvas.drawLine(
      Offset(size.width - 3, size.height - 3),
      Offset(size.width - 3 - tick, size.height - 3),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 3, size.height - 3),
      Offset(size.width - 3, size.height - 3 - tick),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _FiligreeCornerPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// Living celestial particle field — gentle floating motes for night market atmosphere.
class _NightSkyParticles extends StatefulWidget {
  const _NightSkyParticles();

  @override
  State<_NightSkyParticles> createState() => _NightSkyParticlesState();
}

class _NightSkyParticlesState extends State<_NightSkyParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (BuildContext context, Widget? _) {
        return CustomPaint(
          painter: _NightSkyParticlePainter(progress: _ctrl.value),
        );
      },
    );
  }
}

class _NightSkyParticlePainter extends CustomPainter {
  const _NightSkyParticlePainter({required this.progress});

  final double progress;

  static const List<Offset> _anchors = <Offset>[
    Offset(0.12, 0.35),
    Offset(0.28, 0.75),
    Offset(0.45, 0.20),
    Offset(0.62, 0.85),
    Offset(0.78, 0.30),
    Offset(0.90, 0.65),
    Offset(0.35, 0.50),
    Offset(0.85, 0.15),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Paint goldPaint = Paint()
      ..color = AppColors.liquidGold.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final Paint cyanPaint = Paint()
      ..color = AppColors.accentCyan.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < _anchors.length; i++) {
      final Offset anchor = _anchors[i];
      final double phase = (progress + (i * 0.125)) % 1.0;
      final double dy = (anchor.dy - (phase * 0.3)) % 1.0;
      final double dx = (anchor.dx + (math.sin(phase * math.pi * 2) * 0.04)) % 1.0;
      final double radius = 1.0 + (i % 3) * 0.6;
      final Paint paint = i.isEven ? goldPaint : cyanPaint;

      canvas.drawCircle(Offset(dx * size.width, dy * size.height), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NightSkyParticlePainter oldDelegate) =>
      progress != oldDelegate.progress;
}
