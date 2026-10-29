import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import 'kingdom_crest_icons.dart';
import 'kingdom_glass_card.dart';

// =============================================================================
// 2027 AION 2 OBSIDIAN-GLASS & LUMINESCENCE DESIGN TOKENS
// =============================================================================

abstract final class _Aion2Tokens {
  /// Ether cyan luminescence (#00E5FF)
  static const Color etherCyan = Color(0xFF00E5FF);

  /// Celestial liquid gold luminescence (#E5C158)
  static const Color celestialGold = Color(0xFFE5C158);

  /// Deep obsidian base backdrop
  static const Color obsidianBase = Color(0xFF06090B);

  /// Obsidian glass surface
  static const Color obsidianSurface = Color(0xFF0E151A);

  /// Obsidian translucent card tint
  static const Color obsidianCard = Color(0xFF121B21);

  /// Deep shadow obsidian
  static const Color obsidianDeepShadow = Color(0xFF080C17);

  /// Warning / Siege status red
  static const Color warningRed = Color(0xFFEF4444);

  /// Sovereign defense emerald
  static const Color defenseEmerald = Color(0xFF10B981);

  /// Royal high council purple
  static const Color royalPurple = Color(0xFFA78BFA);

  /// 2027 Aion 2 Obsidian-glass backdrop gradient with deep luminous depth
  static const LinearGradient obsidianGlassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xDD06090B),
      Color(0xCC0E151A),
      Color(0xE6080C17),
    ],
    stops: <double>[0.0, 0.55, 1.0],
  );

  /// Multi-stop ether cyan & celestial gold luminous border gradient
  static const LinearGradient cyanGoldBorderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xF000E5FF),
      Color(0x99E5C158),
      Color(0x3300E5FF),
      Color(0x26FFFFFF),
    ],
    stops: <double>[0.0, 0.40, 0.75, 1.0],
  );

  /// Multi-stop celestial gold & ether cyan luminous border gradient
  static const LinearGradient goldCyanBorderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xF5E5C158),
      Color(0x9900E5FF),
      Color(0x44E5C158),
      Color(0x26FFFFFF),
    ],
    stops: <double>[0.0, 0.40, 0.75, 1.0],
  );

  /// Siege alert border gradient
  static const LinearGradient siegeBorderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xF0EF4444),
      Color(0x99991B1B),
      Color(0x26FFFFFF),
    ],
  );

  /// Legion war border gradient
  static const LinearGradient armyBorderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xF0F87171),
      Color(0x99991B1B),
      Color(0x26FFFFFF),
    ],
  );

  /// Royal diplomacy border gradient
  static const LinearGradient diplomacyBorderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xF0A78BFA),
      Color(0x995B21B6),
      Color(0x26FFFFFF),
    ],
  );
}

// Top-level number formatter with thousand separators
String _formatNumber(num val) {
  final s = val.round().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

// =============================================================================
// 1. MASTER KINGDOM OVERVIEW CARD (2027 AION 2 OBSIDIAN-GLASS)
// =============================================================================

/// 2027 Aion 2 Master Obsidian-Glass Kingdom Overview Card.
///
/// Features:
/// - Obsidian frosted glass container with multi-layer BackdropFilter blur.
/// - Ether cyan (#00E5FF) and celestial gold (#E5C158) luminescent badges and glowing borders.
/// - Real-time realm power level, sovereign authority, dominion level, and treasury reserves.
/// - HapticFeedback on button taps and card interactions.
/// - Adaptive layout with zero-overflow defensive constraints for 390x844 mobile viewports.
class KingdomOverviewCard extends StatelessWidget {
  const KingdomOverviewCard({
    super.key,
    this.realmName = 'Aethelgard Hükümranlığı',
    this.reigningKing = 'Lord Kaelen',
    this.reigningGuild = 'Gök Muhafızları',
    this.powerLevel = 88500,
    this.dominionLevel = 15,
    this.goldBalance = 15200000,
    this.gemBalance = 5600,
    this.dailyTaxRevenue = 720000,
    this.controlledProvinces = 7,
    this.totalProvinces = 9,
    this.defenseLevel = 5,
    this.activeSoldiers = 12400,
    this.readinessRating = 94,
    this.taxYieldMultiplier = 1.35,
    this.isUnderSiege = false,
    this.onTap,
    this.onManage,
    this.onViewMap,
    this.onViewTreasury,
    this.onInspectArmy,
  });

  final String realmName;
  final String reigningKing;
  final String reigningGuild;
  final int powerLevel;
  final int dominionLevel;
  final num goldBalance;
  final num gemBalance;
  final num dailyTaxRevenue;
  final int controlledProvinces;
  final int totalProvinces;
  final int defenseLevel;
  final int activeSoldiers;
  final int readinessRating;
  final double taxYieldMultiplier;
  final bool isUnderSiege;
  final VoidCallback? onTap;
  final VoidCallback? onManage;
  final VoidCallback? onViewMap;
  final VoidCallback? onViewTreasury;
  final VoidCallback? onInspectArmy;

  @override
  Widget build(BuildContext context) {
    final double territoryRatio = totalProvinces > 0
        ? (controlledProvinces / totalProvinces).clamp(0.0, 1.0)
        : 0.0;

    return KingdomGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      blurSigma: 16.0,
      accentGlowColor: isUnderSiege
          ? _Aion2Tokens.warningRed
          : _Aion2Tokens.etherCyan,
      backgroundGradient: _Aion2Tokens.obsidianGlassGradient,
      borderGradient: isUnderSiege
          ? _Aion2Tokens.siegeBorderGradient
          : _Aion2Tokens.cyanGoldBorderGradient,
      onTap: onTap != null
          ? () {
              HapticFeedback.selectionClick();
              onTap!();
            }
          : null,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Header Row: Sovereign Crest, Realm Title & Status Pill
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const KingdomCrestIcon(
                  type: KingdomCrestType.crown,
                  size: 46,
                  showGlow: true,
                  animatedPulse: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              realmName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _StatusPill(
                            label: isUnderSiege ? 'KUŞATMA' : 'HÂKİMİYET',
                            color: isUnderSiege
                                ? _Aion2Tokens.warningRed
                                : _Aion2Tokens.etherCyan,
                            pulse: isUnderSiege,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              '$reigningKing [$reigningGuild]',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _LuminescentBadge(
                            icon: Icons.shield_rounded,
                            text: 'Kademe $dominionLevel',
                            color: _Aion2Tokens.celestialGold,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Power Level & Dominion Progress Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _Aion2Tokens.obsidianCard.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _Aion2Tokens.etherCyan.withValues(alpha: 0.35),
                  width: 1.0,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: _Aion2Tokens.etherCyan.withValues(alpha: 0.12),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _Aion2Tokens.etherCyan.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _Aion2Tokens.etherCyan.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: _Aion2Tokens.etherCyan,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text(
                              'KRALLIK KUDRETİ',
                              style: TextStyle(
                                color: _Aion2Tokens.etherCyan,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              '${_formatNumber(powerLevel)} GP',
                              style: const TextStyle(
                                color: _Aion2Tokens.celestialGold,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: territoryRatio,
                            minHeight: 5,
                            backgroundColor: const Color(0xFF1E293B),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isUnderSiege
                                  ? _Aion2Tokens.warningRed
                                  : _Aion2Tokens.etherCyan,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Bento Realm Metrics (2x2 Grid)
            Row(
              children: <Widget>[
                Expanded(
                  child: _MetricBadge(
                    label: 'Bölge Kontrolü',
                    value: '$controlledProvinces / $totalProvinces Eyalet',
                    icon: Icons.public_rounded,
                    color: _Aion2Tokens.etherCyan,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricBadge(
                    label: 'Hazine Rezervi',
                    value: '${_formatNumber(goldBalance)} 🪙',
                    icon: Icons.monetization_on_rounded,
                    color: _Aion2Tokens.celestialGold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MetricBadge(
                    label: 'Aktif Lejyon',
                    value: '${_formatNumber(activeSoldiers)} Savaşçı',
                    icon: Icons.shield_moon_outlined,
                    color: _Aion2Tokens.etherCyan,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricBadge(
                    label: 'Savunma & Vergi',
                    value:
                        'Kademe $defenseLevel (x${taxYieldMultiplier.toStringAsFixed(2)})',
                    icon: Icons.trending_up_rounded,
                    color: _Aion2Tokens.celestialGold,
                  ),
                ),
              ],
            ),

            // Command Action Buttons
            if (onManage != null ||
                onViewMap != null ||
                onViewTreasury != null ||
                onInspectArmy != null) ...<Widget>[
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  if (onViewMap != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onViewMap!();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _Aion2Tokens.etherCyan,
                          side: BorderSide(
                            color:
                                _Aion2Tokens.etherCyan.withValues(alpha: 0.45),
                            width: 1.0,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Haritayı Aç',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  if (onViewMap != null && onManage != null)
                    const SizedBox(width: 8),
                  if (onManage != null)
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          onManage!();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _Aion2Tokens.etherCyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Krallığı Yönet',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  if (onManage == null && onViewTreasury != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onViewTreasury!();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _Aion2Tokens.celestialGold,
                          side: BorderSide(
                            color: _Aion2Tokens.celestialGold
                                .withValues(alpha: 0.5),
                            width: 1.0,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Hazine Defteri',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 2. BENTO TERRITORY MANAGEMENT CARD
// =============================================================================

/// Bento-style 2027 Aion 2 territory management card.
class KingdomTerritoryCard extends StatelessWidget {
  const KingdomTerritoryCard({
    super.key,
    this.realmName = 'Aethelgard Krallığı',
    this.controlledProvinces = 7,
    this.totalProvinces = 9,
    this.defenseLevel = 4,
    this.taxYieldMultiplier = 1.25,
    this.isUnderSiege = false,
    this.onManage,
    this.onViewMap,
  });

  final String realmName;
  final int controlledProvinces;
  final int totalProvinces;
  final int defenseLevel;
  final double taxYieldMultiplier;
  final bool isUnderSiege;
  final VoidCallback? onManage;
  final VoidCallback? onViewMap;

  @override
  Widget build(BuildContext context) {
    final territoryRatio = totalProvinces > 0
        ? (controlledProvinces / totalProvinces).clamp(0.0, 1.0)
        : 0.0;

    return KingdomGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      blurSigma: 16.0,
      accentGlowColor: isUnderSiege
          ? _Aion2Tokens.warningRed
          : _Aion2Tokens.etherCyan,
      backgroundGradient: _Aion2Tokens.obsidianGlassGradient,
      borderGradient: isUnderSiege
          ? _Aion2Tokens.siegeBorderGradient
          : _Aion2Tokens.cyanGoldBorderGradient,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const KingdomCrestIcon(
                  type: KingdomCrestType.territory,
                  size: 44,
                  showGlow: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              realmName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _StatusPill(
                            label: isUnderSiege ? 'KUŞATMA' : 'HÂKİMİYET',
                            color: isUnderSiege
                                ? _Aion2Tokens.warningRed
                                : _Aion2Tokens.defenseEmerald,
                            pulse: isUnderSiege,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bölge Kontrolü: $controlledProvinces / $totalProvinces Eyalet',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Progress bar for territory dominance
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: territoryRatio,
                minHeight: 6,
                backgroundColor: const Color(0xFF1E293B),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isUnderSiege
                      ? const Color(0xFFF59E0B)
                      : _Aion2Tokens.etherCyan,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Stats row
            Row(
              children: <Widget>[
                Expanded(
                  child: _MetricBadge(
                    label: 'Savunma Kademesi',
                    value: 'Kademe $defenseLevel',
                    icon: Icons.shield_moon_outlined,
                    color: _Aion2Tokens.etherCyan,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricBadge(
                    label: 'Vergi Çarpanı',
                    value: 'x${taxYieldMultiplier.toStringAsFixed(2)}',
                    icon: Icons.trending_up_rounded,
                    color: _Aion2Tokens.celestialGold,
                  ),
                ),
              ],
            ),
            if (onManage != null || onViewMap != null) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  if (onViewMap != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onViewMap!();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _Aion2Tokens.etherCyan,
                          side: BorderSide(
                            color:
                                _Aion2Tokens.etherCyan.withValues(alpha: 0.45),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Haritayı Aç',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (onViewMap != null && onManage != null)
                    const SizedBox(width: 8),
                  if (onManage != null)
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          onManage!();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Eyaleti Yönet',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 3. BENTO TREASURY CARD
// =============================================================================

/// Bento-style 2027 Aion 2 treasury card.
class KingdomTreasuryCard extends StatelessWidget {
  const KingdomTreasuryCard({
    super.key,
    required this.goldBalance,
    required this.gemBalance,
    this.dailyTaxRevenue = 450000,
    this.isKing = false,
    this.canGift = false,
    this.onGiftSend,
    this.onViewLedger,
  });

  final num goldBalance;
  final num gemBalance;
  final num dailyTaxRevenue;
  final bool isKing;
  final bool canGift;
  final VoidCallback? onGiftSend;
  final VoidCallback? onViewLedger;

  @override
  Widget build(BuildContext context) {
    return KingdomGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      blurSigma: 16.0,
      accentGlowColor: _Aion2Tokens.celestialGold,
      backgroundGradient: _Aion2Tokens.obsidianGlassGradient,
      borderGradient: _Aion2Tokens.goldCyanBorderGradient,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const KingdomCrestIcon(
                  type: KingdomCrestType.treasury,
                  size: 44,
                  showGlow: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Flexible(
                            child: Text(
                              'KRALİYET HAZİNESİ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _Aion2Tokens.celestialGold,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          if (isKing) ...<Widget>[
                            const SizedBox(width: 6),
                            const _StatusPill(
                              label: 'KASA YETKİLİSİ',
                              color: _Aion2Tokens.celestialGold,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Günlük Vergi Geliri: +${_formatNumber(dailyTaxRevenue)} 🪙',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Balances
            Row(
              children: <Widget>[
                Expanded(
                  child: _BalanceBox(
                    icon: Icons.monetization_on_rounded,
                    label: 'Altın Rezervi',
                    amount: '${_formatNumber(goldBalance)} 🪙',
                    color: _Aion2Tokens.celestialGold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _BalanceBox(
                    icon: Icons.diamond_rounded,
                    label: 'Elmas Rezervi',
                    amount: '${_formatNumber(gemBalance)} 💎',
                    color: _Aion2Tokens.etherCyan,
                  ),
                ),
              ],
            ),
            if (onGiftSend != null || onViewLedger != null) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  if (onViewLedger != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onViewLedger!();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _Aion2Tokens.celestialGold,
                          side: BorderSide(
                            color: _Aion2Tokens.celestialGold
                                .withValues(alpha: 0.45),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Kasa Defteri',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (onViewLedger != null && onGiftSend != null && canGift)
                    const SizedBox(width: 8),
                  if (onGiftSend != null && canGift)
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          onGiftSend!();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _Aion2Tokens.celestialGold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Hediye Gönder',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 4. BENTO ARMY & GARRISON CARD
// =============================================================================

/// Bento-style 2027 Aion 2 army & garrison card.
class KingdomArmyCard extends StatelessWidget {
  const KingdomArmyCard({
    super.key,
    this.legionName = 'Gök Muhafızları Alayı',
    this.activeSoldiers = 12400,
    this.readinessRating = 94,
    this.warDefenseBonusPct = 15,
    this.onInspect,
  });

  final String legionName;
  final int activeSoldiers;
  final int readinessRating;
  final int warDefenseBonusPct;
  final VoidCallback? onInspect;

  @override
  Widget build(BuildContext context) {
    return KingdomGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      blurSigma: 16.0,
      accentGlowColor: const Color(0xFFF87171),
      backgroundGradient: _Aion2Tokens.obsidianGlassGradient,
      borderGradient: _Aion2Tokens.armyBorderGradient,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const KingdomCrestIcon(
                  type: KingdomCrestType.army,
                  size: 44,
                  showGlow: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              legionName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _StatusPill(
                            label: '%$readinessRating HAZIR',
                            color: const Color(0xFFEF4444),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Aktif Lejyon: ${_formatNumber(activeSoldiers)} Savaşçı',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Metric badges
            Row(
              children: <Widget>[
                Expanded(
                  child: _MetricBadge(
                    label: 'Savaş Hazırlığı',
                    value: '%$readinessRating',
                    icon: Icons.bolt_rounded,
                    color: _Aion2Tokens.etherCyan,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricBadge(
                    label: 'Savunma Takviyesi',
                    value: '+$warDefenseBonusPct%',
                    icon: Icons.shield_rounded,
                    color: _Aion2Tokens.defenseEmerald,
                  ),
                ),
              ],
            ),
            if (onInspect != null) ...<Widget>[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onInspect!();
                  },
                  icon: const Icon(Icons.military_tech_rounded, size: 16),
                  label: const Text(
                    'Garnizonu Teftiş Et',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 5. BENTO DIPLOMACY & ROYAL ELECTION CARD
// =============================================================================

/// Bento-style 2027 Aion 2 diplomacy & royal election card.
class KingdomDiplomacyCard extends StatelessWidget {
  const KingdomDiplomacyCard({
    super.key,
    required this.kingName,
    required this.guildName,
    this.month = 'Kasım 2026',
    this.isElectionActive = false,
    this.countdownLabel,
    this.canVote = false,
    this.alreadyVoted = false,
    this.onVote,
    this.onViewCouncil,
  });

  final String kingName;
  final String guildName;
  final String month;
  final bool isElectionActive;
  final String? countdownLabel;
  final bool canVote;
  final bool alreadyVoted;
  final VoidCallback? onVote;
  final VoidCallback? onViewCouncil;

  @override
  Widget build(BuildContext context) {
    return KingdomGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      blurSigma: 16.0,
      accentGlowColor: _Aion2Tokens.royalPurple,
      backgroundGradient: _Aion2Tokens.obsidianGlassGradient,
      borderGradient: _Aion2Tokens.diplomacyBorderGradient,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const KingdomCrestIcon(
                  type: KingdomCrestType.diplomacy,
                  size: 44,
                  showGlow: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              isElectionActive
                                  ? 'KRALLIK SEÇİMİ'
                                  : 'HÜKÜMDAR KONSEYİ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _Aion2Tokens.royalPurple,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          if (countdownLabel != null) ...<Widget>[
                            const SizedBox(width: 6),
                            _StatusPill(
                              label: countdownLabel!,
                              color: _Aion2Tokens.royalPurple,
                              pulse: isElectionActive,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dönem: $month',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Reigning King & Guild Container
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _Aion2Tokens.obsidianCard.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _Aion2Tokens.royalPurple.withValues(alpha: 0.35),
                  width: 1.0,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: _Aion2Tokens.royalPurple.withValues(alpha: 0.12),
                    blurRadius: 8,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  const Text('👑', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          kingName.isNotEmpty ? kingName : 'Taht Sahipsiz',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          guildName.isNotEmpty
                              ? 'Hükümran Lonca: $guildName'
                              : 'Aktif seçim bekleniyor',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (onVote != null || onViewCouncil != null) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  if (onViewCouncil != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onViewCouncil!();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _Aion2Tokens.royalPurple,
                          side: BorderSide(
                            color: _Aion2Tokens.royalPurple
                                .withValues(alpha: 0.45),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Meclis Kaydı',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (onViewCouncil != null &&
                      onVote != null &&
                      isElectionActive)
                    const SizedBox(width: 8),
                  if (onVote != null && isElectionActive)
                    Expanded(
                      child: FilledButton(
                        onPressed: (canVote && !alreadyVoted)
                            ? () {
                                HapticFeedback.heavyImpact();
                                onVote!();
                              }
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFF4C1D95).withValues(alpha: 0.4),
                          disabledForegroundColor: Colors.white38,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          alreadyVoted ? 'Oy Verildi' : 'Oy Kullan',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SHARED UI HELPERS (AION 2 OBSIDIAN & LUMINESCENCE)
// =============================================================================

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    this.pulse = false,
  });

  final String label;
  final Color color;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 0.8),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: pulse ? 0.35 : 0.18),
            blurRadius: pulse ? 6 : 3,
            spreadRadius: pulse ? 0.5 : 0.0,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _LuminescentBadge extends StatelessWidget {
  const _LuminescentBadge({
    required this.text,
    required this.color,
    this.icon,
  });

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.8),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.20),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _Aion2Tokens.obsidianCard.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.28),
          width: 0.9,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceBox extends StatelessWidget {
  const _BalanceBox({
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _Aion2Tokens.obsidianCard.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.9),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.14),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  amount,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
