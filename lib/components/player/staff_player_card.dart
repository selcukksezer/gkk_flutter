import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/services/app_haptics.dart';
import '../../models/staff_model.dart';
import '../../screens/staff/widgets/staff_design.dart';
import '../../screens/support/widgets/support_design.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'staff_badge.dart';

/// 2027 Aion 2 Obsidian-Glass & Staff Telemetry Color Tokens.
abstract final class _AionTokens {
  static const Color celestialGold = Color(0xFFE5C158);
  static const Color etherCyan = Color(0xFF00E5FF);
  static const Color obsidianDeep = Color(0xFF07090E);
  static const Color obsidianMid = Color(0xFF0B0F17);
  static const Color obsidianSurface = Color(0xFF0F141F);
  static const Color obsidianElevated = Color(0xFF141C2E);
  static const Color obsidianBorder = Color(0xFF1E293B);
  static const Color rubyAccent = Color(0xFFFF3366);
  static const Color emeraldAccent = Color(0xFF00E676);
  static const Color coralAccent = Color(0xFFFF6D00);
  static const Color fuchsiaAccent = Color(0xFFE040FB);

  static const double glassBlurSigma = 16.0;
  static const double cardRadius = 16.0;
  static const double chipRadius = 10.0;
}

/// 2027 Aion 2 Obsidian-Glass Player Dossier & Staff Telemetry Console (V2 Polish).
///
/// Features:
/// - Layered frosted obsidian glass (0xFF07090E - 0xFF0F141F) with BackdropFilter sigma 16
/// - VIP & Military Rank luminescence in Celestial Gold (#E5C158) and Ether Cyan (#00E5FF)
/// - Comprehensive player telemetry (Vitals, Economy, Combat, Cargo, Activity)
/// - Safe responsive scaling (FittedBox) preventing narrow-screen overflows
/// - Tactile haptic feedback on all moderator actions and interactive triggers
/// - Semantic action button differentiation (release vs penalty) with AppHaptics
/// - Full SafeArea and MediaQuery insets protection
class StaffPlayerCard extends StatelessWidget {
  const StaffPlayerCard({
    super.key,
    required this.player,
    this.loading = false,
    this.onExtendHospital,
    this.onShortenHospital,
    this.onReleaseHospital,
    this.onExtendPrison,
    this.onShortenPrison,
    this.onReleasePrison,
    this.onReleaseTradeBan,
    this.onUnban,
    this.onReleaseChatMute,
  });

  final StaffPlayerDetail player;
  final bool loading;
  final VoidCallback? onExtendHospital;
  final VoidCallback? onShortenHospital;
  final VoidCallback? onReleaseHospital;
  final VoidCallback? onExtendPrison;
  final VoidCallback? onShortenPrison;
  final VoidCallback? onReleasePrison;
  final VoidCallback? onReleaseTradeBan;
  final VoidCallback? onUnban;
  final VoidCallback? onReleaseChatMute;

  static final DateFormat _dateFmt = DateFormat('dd.MM.yyyy HH:mm');
  static final NumberFormat _numFmt = NumberFormat('#,###', 'tr_TR');

  String _fmt(num? value) => value == null ? '—' : _numFmt.format(value);

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    return _dateFmt.format(dt.toLocal());
  }

  String _fmtDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '—';
    final int d = seconds ~/ 86400;
    final int h = (seconds % 86400) ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    if (d > 0) return '${d}g ${h}s';
    if (h > 0) return '${h}s ${m}dk';
    return '${m}dk';
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    AppHaptics.light();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('$label panoya kopyalandı: $text'),
        duration: const Duration(seconds: 2),
        backgroundColor: _AionTokens.obsidianElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _resolvePvpTier(int rating) {
    if (rating >= 2400) return 'Archon (İlahi)';
    if (rating >= 2000) return 'Gladyatör (5★)';
    if (rating >= 1800) return 'Elit (4★)';
    if (rating >= 1600) return 'Centurion (3★)';
    if (rating >= 1400) return 'Muhafız (2★)';
    if (rating >= 1200) return 'Savaşçı (1★)';
    return 'Acemi';
  }

  IconData _resolveClassIcon(String? characterClass) {
    switch (characterClass?.toLowerCase()) {
      case 'warrior':
      case 'savasci':
        return Icons.sports_martial_arts_rounded;
      case 'alchemist':
      case 'simyaci':
        return Icons.science_rounded;
      case 'shadow':
      case 'golge':
        return Icons.visibility_off_rounded;
      default:
        return Icons.shield_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  color: _AionTokens.celestialGold,
                  strokeWidth: 2.6,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'OYUNCU DOSYASI YÜKLENİYOR...',
                style: GoogleFonts.cinzel(
                  color: _AionTokens.celestialGold,
                  letterSpacing: 1.4,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final double viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      bottom: true,
      minimum: EdgeInsets.only(bottom: math.max(16.0, bottomInset + viewInsetsBottom)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── Dossier Main Header Card ──
          _buildDossierHeader(context),
          const SizedBox(height: 14),

          // ── Vitals & Bio-Telemetry ──
          _buildSectionHeader(
            title: 'HAYATİ TELEMETRİ',
            icon: Icons.favorite_rounded,
            accent: _AionTokens.rubyAccent,
          ),
          const SizedBox(height: 8),
          _buildVitalsCard(),
          const SizedBox(height: 14),

          // ── Economy Telemetry ──
          _buildSectionHeader(
            title: 'EKONOMİK VARLIKLAR',
            icon: Icons.account_balance_wallet_rounded,
            accent: _AionTokens.celestialGold,
          ),
          const SizedBox(height: 8),
          _buildEconomyRow(),
          const SizedBox(height: 14),

          // ── Combat & Military Telemetry ──
          _buildSectionHeader(
            title: 'MUHAREBE & ASKERİ SİCİL',
            icon: Icons.military_tech_rounded,
            accent: _AionTokens.etherCyan,
          ),
          const SizedBox(height: 8),
          _buildCombatTelemetry(),
          const SizedBox(height: 14),

          // ── Guild & Cargo Telemetry ──
          _buildSectionHeader(
            title: 'LONCA & KARGO DEPOSU',
            icon: Icons.inventory_2_rounded,
            accent: _AionTokens.fuchsiaAccent,
          ),
          const SizedBox(height: 8),
          _buildGuildAndCargoCard(),
          const SizedBox(height: 14),

          // ── Activity & Security Telemetry ──
          _buildSectionHeader(
            title: 'SİSTEM & AKTİVİTE KAYDI',
            icon: Icons.history_toggle_off_rounded,
            accent: SettingsPalette.titanium,
          ),
          const SizedBox(height: 8),
          _buildActivityCard(context),

          // ── Active Sanctions & Quick Moderator Actions ──
          if (player.inHospital ||
              player.inPrison ||
              player.isAccountBanned ||
              player.isTradeBanned ||
              player.isChatMuted) ...<Widget>[
            const SizedBox(height: 16),
            _buildSectionHeader(
              title: 'AKTİF KISITLAR — HIZLI MÜDAHALE',
              icon: Icons.gavel_rounded,
              accent: _AionTokens.rubyAccent,
            ),
            const SizedBox(height: 8),
            _buildActiveSanctionsDeck(context),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Header Component with VIP / Staff Heraldry & Luminescence
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildDossierHeader(BuildContext context) {
    final bool isOnline = player.isOnline;
    final int level = player.level ?? 1;
    final int power = player.power ?? 0;

    return _AionObsidianGlassCard(
      accent: _AionTokens.etherCyan,
      glow: true,
      hasRunicCorners: true,
      hasDotGrid: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Identity & Crest Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Avatar Crest Hexagon Frame
              Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[
                          _AionTokens.etherCyan.withValues(alpha: 0.3),
                          _AionTokens.obsidianElevated,
                        ],
                      ),
                      border: Border.all(
                        color: _AionTokens.etherCyan.withValues(alpha: 0.75),
                        width: 1.8,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: _AionTokens.etherCyan.withValues(alpha: 0.38),
                          blurRadius: 16,
                          spreadRadius: 1.5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        _resolveClassIcon(player.characterClass),
                        color: _AionTokens.etherCyan,
                        size: 30,
                      ),
                    ),
                  ),
                  // Online/Offline status beacon
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline
                            ? _AionTokens.emeraldAccent
                            : SettingsPalette.titanium.withValues(alpha: 0.5),
                        border: Border.all(
                          color: _AionTokens.obsidianDeep,
                          width: 2.5,
                        ),
                        boxShadow: isOnline
                            ? <BoxShadow>[
                                BoxShadow(
                                  color: _AionTokens.emeraldAccent.withValues(alpha: 0.85),
                                  blurRadius: 9,
                                  spreadRadius: 1.5,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Name, Handle, Class, Power
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            player.displayName ?? player.username,
                            style: GoogleFonts.cinzel(
                              color: SettingsPalette.textHi,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (player.isProtectedAdmin)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: _AionTokens.celestialGold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _AionTokens.celestialGold.withValues(alpha: 0.85),
                                width: 1.0,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: _AionTokens.celestialGold.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.shield_rounded,
                                  size: 11,
                                  color: _AionTokens.celestialGold,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'KORUMALI',
                                  style: AppTextStyles.captionBold.copyWith(
                                    color: _AionTokens.celestialGold,
                                    fontSize: 8.5,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: () => _copyToClipboard(context, player.username, 'Kullanıcı adı'),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '@${player.username}',
                            style: supportCaptionStyle.copyWith(
                              color: _AionTokens.etherCyan.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.copy_rounded,
                            size: 11,
                            color: _AionTokens.etherCyan.withValues(alpha: 0.65),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '#${player.authId.length > 8 ? player.authId.substring(0, 8) : player.authId}',
                            style: supportCaptionStyle.copyWith(
                              color: SettingsPalette.titanium.withValues(alpha: 0.65),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Level, Class & Combat Power Bar
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _AionTokens.celestialGold.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _AionTokens.celestialGold.withValues(alpha: 0.65),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'LV.$level',
                            style: AppTextStyles.captionBold.copyWith(
                              color: _AionTokens.celestialGold,
                              fontSize: 10,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _AionTokens.obsidianElevated,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _AionTokens.obsidianBorder,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            player.classLabelTr,
                            style: AppTextStyles.caption.copyWith(
                              color: SettingsPalette.textHi,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                _AionTokens.celestialGold.withValues(alpha: 0.28),
                                _AionTokens.obsidianMid,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _AionTokens.celestialGold.withValues(alpha: 0.75),
                              width: 1,
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: _AionTokens.celestialGold.withValues(alpha: 0.22),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.flash_on_rounded,
                                size: 12,
                                color: _AionTokens.celestialGold,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'GÜÇ ${_fmt(power)}',
                                style: AppTextStyles.captionBold.copyWith(
                                  color: _AionTokens.celestialGold,
                                  fontSize: 10.5,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const _AionRunicDivider(accent: _AionTokens.etherCyan),
          const SizedBox(height: 10),

          // Heraldry Badges & VIP Tier Luminescence
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              // VIP Tier Luminescence Badge
              _AionVipLuminescenceBadge(
                level: level,
                power: power,
                kingBadge: player.kingBadge,
                staffBadge: player.staffBadge,
              ),

              if (player.staffBadge != null)
                StaffBadge(badge: player.staffBadge, compact: true),
              if (player.kingBadge != null)
                StaffBadge(badge: player.kingBadge, compact: true),

              // Status Pills
              if (isOnline)
                const _AionStatusIndicator(
                  label: 'ÇEVRİMİÇİ',
                  color: _AionTokens.emeraldAccent,
                  isPulsing: true,
                )
              else
                _AionStatusIndicator(
                  label: 'ÇEVRİMDIŞI',
                  color: SettingsPalette.titanium.withValues(alpha: 0.75),
                ),

              if (player.isAccountBanned)
                const _AionStatusIndicator(
                  label: 'BANLI',
                  color: _AionTokens.rubyAccent,
                ),
              if (player.inHospital)
                const _AionStatusIndicator(
                  label: 'HASTANE',
                  color: _AionTokens.coralAccent,
                ),
              if (player.inPrison)
                const _AionStatusIndicator(
                  label: 'HAPİSHANE',
                  color: _AionTokens.rubyAccent,
                ),
              if (player.isTradeBanned)
                _AionStatusIndicator(
                  label: 'TİCARET YASAĞI',
                  color: _AionTokens.celestialGold.withValues(alpha: 0.9),
                ),
              if (player.isChatMuted)
                const _AionStatusIndicator(
                  label: 'CHAT SUSTURMA',
                  color: _AionTokens.fuchsiaAccent,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Vitals & Bio-Telemetry
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildVitalsCard() {
    final int health = player.health ?? 0;
    final int maxHealth = math.max(1, player.maxHealth ?? 100);
    final double healthPercent = (health / maxHealth).clamp(0.0, 1.0);

    final int energy = player.energy ?? 0;
    final int maxEnergy = math.max(1, player.maxEnergy ?? 100);
    final double energyPercent = (energy / maxEnergy).clamp(0.0, 1.0);

    return _AionObsidianGlassCard(
      accent: _AionTokens.rubyAccent,
      padding: const EdgeInsets.all(14),
      hasDotGrid: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildMeterBar(
            label: 'CAN (HP)',
            current: health,
            max: maxHealth,
            percent: healthPercent,
            icon: Icons.favorite_rounded,
            primaryColor: _AionTokens.rubyAccent,
            secondaryColor: const Color(0xFFFF5252),
          ),
          const SizedBox(height: 12),
          _buildMeterBar(
            label: 'ENERJİ (STA)',
            current: energy,
            max: maxEnergy,
            percent: energyPercent,
            icon: Icons.bolt_rounded,
            primaryColor: _AionTokens.coralAccent,
            secondaryColor: _AionTokens.celestialGold,
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _buildCompactMetricPill(
                  label: 'DENEYİM (XP)',
                  value: _fmt(player.xp),
                  icon: Icons.auto_awesome_rounded,
                  accent: _AionTokens.etherCyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactMetricPill(
                  label: 'STAT PUANI',
                  value: _fmt(player.statPoints),
                  icon: Icons.add_circle_outline_rounded,
                  accent: _AionTokens.celestialGold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeterBar({
    required String label,
    required int current,
    required int max,
    required double percent,
    required IconData icon,
    required Color primaryColor,
    required Color secondaryColor,
  }) {
    final String pctString = (percent * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 13, color: primaryColor),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: AppTextStyles.captionBold.copyWith(
                    color: SettingsPalette.textHi,
                    fontSize: 10.5,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '${_numFmt.format(current)} / ${_numFmt.format(max)} ($pctString%)',
                  style: AppTextStyles.caption.copyWith(
                    color: primaryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: _AionTokens.obsidianDeep,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
          child: Stack(
            children: <Widget>[
              FractionallySizedBox(
                widthFactor: percent,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: <Color>[primaryColor, secondaryColor],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.55),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Economy Telemetry
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildEconomyRow() {
    return Row(
      children: <Widget>[
        Expanded(
          child: _AionTelemetryBadge(
            label: 'ALTIN (GOLD)',
            value: _fmt(player.gold),
            icon: Icons.monetization_on_rounded,
            accent: _AionTokens.celestialGold,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _AionTelemetryBadge(
            label: 'ELMAS (GEMS)',
            value: _fmt(player.gems),
            icon: Icons.diamond_rounded,
            accent: _AionTokens.fuchsiaAccent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _AionTelemetryBadge(
            label: 'İTİBAR (REP)',
            value: _fmt(player.reputation),
            icon: Icons.military_tech_rounded,
            accent: _AionTokens.etherCyan,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Combat & Military Telemetry
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildCombatTelemetry() {
    final int wins = player.pvpWins ?? 0;
    final int losses = player.pvpLosses ?? 0;
    final int totalMatches = wins + losses;
    final double winRate = totalMatches > 0 ? (wins / totalMatches) * 100 : 0.0;
    final int rating = player.pvpRating ?? 1000;
    final String tierName = _resolvePvpTier(rating);

    return Column(
      children: <Widget>[
        // Primary Attributes
        Row(
          children: <Widget>[
            Expanded(
              child: _AionTelemetryBadge(
                label: 'SALDIRI',
                value: _fmt(player.attack),
                icon: Icons.colorize_rounded,
                accent: _AionTokens.rubyAccent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AionTelemetryBadge(
                label: 'SAVUNMA',
                value: _fmt(player.defense),
                icon: Icons.shield_rounded,
                accent: _AionTokens.etherCyan,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AionTelemetryBadge(
                label: 'ŞANS',
                value: _fmt(player.luck),
                icon: Icons.casino_rounded,
                accent: _AionTokens.emeraldAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // PvP Warfare Summary Card
        _AionObsidianGlassCard(
          accent: _AionTokens.etherCyan,
          padding: const EdgeInsets.all(12),
          hasDotGrid: true,
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _AionTokens.etherCyan.withValues(alpha: 0.16),
                  border: Border.all(
                    color: _AionTokens.etherCyan.withValues(alpha: 0.55),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: _AionTokens.etherCyan.withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.sports_kabaddi_rounded,
                  color: _AionTokens.etherCyan,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'PVP REKABET DERECE',
                          style: supportCaptionStyle.copyWith(
                            fontSize: 9.5,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              'K/D: ${wins}G / ${losses}M (%${winRate.toStringAsFixed(1)})',
                              style: AppTextStyles.captionBold.copyWith(
                                color: _AionTokens.celestialGold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            tierName,
                            style: AppTextStyles.bodyBold.copyWith(
                              color: SettingsPalette.textHi,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'MMR $rating',
                          style: AppTextStyles.captionBold.copyWith(
                            color: _AionTokens.etherCyan,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Guild & Cargo Telemetry
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildGuildAndCargoCard() {
    final int usedSlots = player.inventorySlotsUsed ?? 0;
    final int capSlots = math.max(1, player.inventoryCapacity);
    final double capacityPercent = (usedSlots / capSlots).clamp(0.0, 1.0);
    final int addiction = player.addictionLevel ?? 0;
    final int tolerance = player.tolerance ?? 0;

    return _AionObsidianGlassCard(
      accent: _AionTokens.fuchsiaAccent,
      padding: const EdgeInsets.all(14),
      hasDotGrid: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Guild Section
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: _AionTokens.fuchsiaAccent.withValues(alpha: 0.16),
                  border: Border.all(
                    color: _AionTokens.fuchsiaAccent.withValues(alpha: 0.45),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: _AionTokens.fuchsiaAccent.withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: _AionTokens.fuchsiaAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'LONCA ÜYELİĞİ',
                      style: supportCaptionStyle.copyWith(
                        fontSize: 9,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      player.guildName != null
                          ? '${player.guildName}${player.guildRole != null ? ' · ${player.guildRole}' : ''}'
                          : 'Bağımsız (Lonca Yok)',
                      style: AppTextStyles.bodyBold.copyWith(
                        color: player.guildName != null
                            ? SettingsPalette.textHi
                            : SettingsPalette.titanium,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _AionRunicDivider(accent: _AionTokens.fuchsiaAccent),
          const SizedBox(height: 10),

          // Inventory Utilization Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Kargo Doluluk: $usedSlots / $capSlots slot (${(capacityPercent * 100).toStringAsFixed(0)}%)',
                    style: supportCaptionStyle.copyWith(fontSize: 10.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${player.inventoryItemRows ?? 0} Satır',
                style: AppTextStyles.captionBold.copyWith(
                  color: _AionTokens.etherCyan,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: capacityPercent,
              minHeight: 5,
              backgroundColor: _AionTokens.obsidianDeep,
              valueColor: AlwaysStoppedAnimation<Color>(
                capacityPercent > 0.9
                    ? _AionTokens.rubyAccent
                    : capacityPercent > 0.7
                        ? _AionTokens.coralAccent
                        : _AionTokens.fuchsiaAccent,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Addiction & Tolerance Indices with Toxic Hazard Indicators
          Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: _AionTokens.obsidianDeep,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: addiction > 60
                          ? _AionTokens.rubyAccent.withValues(alpha: 0.7)
                          : addiction > 30
                              ? _AionTokens.coralAccent.withValues(alpha: 0.5)
                              : _AionTokens.obsidianBorder,
                      width: addiction > 60 ? 1.1 : 0.8,
                    ),
                    boxShadow: addiction > 60
                        ? <BoxShadow>[
                            BoxShadow(
                              color: _AionTokens.rubyAccent.withValues(alpha: 0.25),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (addiction > 60)
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 11,
                              color: _AionTokens.rubyAccent,
                            )
                          else
                            const SizedBox.shrink(),
                          if (addiction > 60) const SizedBox(width: 3),
                          Text('Bağımlılık:', style: supportCaptionStyle.copyWith(fontSize: 10)),
                        ],
                      ),
                      Text(
                        '$addiction',
                        style: AppTextStyles.captionBold.copyWith(
                          color: addiction > 60
                              ? _AionTokens.rubyAccent
                              : addiction > 30
                                  ? _AionTokens.coralAccent
                                  : SettingsPalette.textHi,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: _AionTokens.obsidianDeep,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: tolerance > 60
                          ? _AionTokens.celestialGold.withValues(alpha: 0.7)
                          : _AionTokens.obsidianBorder,
                      width: tolerance > 60 ? 1.1 : 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text('Tolerans:', style: supportCaptionStyle.copyWith(fontSize: 10)),
                      Text(
                        '$tolerance',
                        style: AppTextStyles.captionBold.copyWith(
                          color: tolerance > 60
                              ? _AionTokens.celestialGold
                              : SettingsPalette.textHi,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Activity & Security Telemetry
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildActivityCard(BuildContext context) {
    return _AionObsidianGlassCard(
      accent: SettingsPalette.titanium,
      padding: const EdgeInsets.all(14),
      hasDotGrid: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildActivityRow(
            icon: Icons.login_rounded,
            label: 'Son Giriş',
            value: _fmtDate(player.lastLoginAt),
          ),
          const SizedBox(height: 6),
          _buildActivityRow(
            icon: Icons.sensors_rounded,
            label: 'Son Aktif',
            value: _fmtDate(player.lastActiveAt),
          ),
          const SizedBox(height: 6),
          _buildActivityRow(
            icon: Icons.calendar_month_rounded,
            label: 'Kayıt Tarihi',
            value: _fmtDate(player.createdAt),
          ),
          const SizedBox(height: 6),
          _buildActivityRow(
            icon: Icons.hourglass_bottom_rounded,
            label: 'Toplam Oyun Süresi',
            value: _fmtDuration(player.totalPlaytimeSeconds),
          ),
          if (player.email != null && player.email!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            const _AionRunicDivider(accent: SettingsPalette.titanium),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _copyToClipboard(context, player.email!, 'E-posta'),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.alternate_email_rounded,
                      size: 13,
                      color: _AionTokens.etherCyan.withValues(alpha: 0.75),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'E-posta: ',
                      style: supportCaptionStyle.copyWith(fontSize: 11),
                    ),
                    Expanded(
                      child: Text(
                        player.email!,
                        style: AppTextStyles.captionBold.copyWith(
                          color: _AionTokens.etherCyan,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.copy_rounded,
                      size: 12,
                      color: _AionTokens.etherCyan.withValues(alpha: 0.55),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: <Widget>[
        Icon(
          icon,
          size: 13,
          color: SettingsPalette.titanium.withValues(alpha: 0.75),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: supportCaptionStyle.copyWith(fontSize: 11),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.captionBold.copyWith(
              color: SettingsPalette.textHi,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Active Sanctions & Quick Moderator Actions
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildActiveSanctionsDeck(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (player.inHospital)
          _AionModeratorActionBanner(
            title: 'HASTANE TEDAVİSİNDE',
            subtitle: 'Bitiş: ${_fmtDate(player.hospitalUntil)}'
                '${player.hospitalReason != null ? '\nSebep: ${player.hospitalReason}' : ''}',
            accent: _AionTokens.coralAccent,
            icon: Icons.local_hospital_rounded,
            actions: <({String label, IconData icon, VoidCallback? onTap, bool isRelease, bool isPenalty})>[
              (
                label: '+ Süre',
                icon: Icons.more_time_rounded,
                onTap: onExtendHospital,
                isRelease: false,
                isPenalty: true,
              ),
              (
                label: '- Süre',
                icon: Icons.history_rounded,
                onTap: onShortenHospital,
                isRelease: false,
                isPenalty: false,
              ),
              (
                label: 'Taburcu Et',
                icon: Icons.exit_to_app_rounded,
                onTap: onReleaseHospital,
                isRelease: true,
                isPenalty: false,
              ),
            ],
          ),
        if (player.inPrison)
          _AionModeratorActionBanner(
            title: 'HAPİSHANEDE MAHKUM',
            subtitle: 'Bitiş: ${_fmtDate(player.prisonUntil)}'
                '${player.prisonReason != null ? '\nSuç: ${player.prisonReason}' : ''}',
            accent: _AionTokens.rubyAccent,
            icon: Icons.gavel_rounded,
            actions: <({String label, IconData icon, VoidCallback? onTap, bool isRelease, bool isPenalty})>[
              (
                label: '+ Ceza',
                icon: Icons.add_circle_outline_rounded,
                onTap: onExtendPrison,
                isRelease: false,
                isPenalty: true,
              ),
              (
                label: '- İndirim',
                icon: Icons.remove_circle_outline_rounded,
                onTap: onShortenPrison,
                isRelease: false,
                isPenalty: false,
              ),
              (
                label: 'Tahliye Et',
                icon: Icons.lock_open_rounded,
                onTap: onReleasePrison,
                isRelease: true,
                isPenalty: false,
              ),
            ],
          ),
        if (player.isAccountBanned)
          _AionModeratorActionBanner(
            title: 'HESAP KALICI/SÜRELİ YASAKLI',
            subtitle: 'Bitiş: ${player.bannedUntil == null ? 'Kalıcı Yasak (Perma)' : _fmtDate(player.bannedUntil)}'
                '${player.banReason != null ? '\nİhlal: ${player.banReason}' : ''}',
            accent: _AionTokens.rubyAccent,
            icon: Icons.block_rounded,
            actions: <({String label, IconData icon, VoidCallback? onTap, bool isRelease, bool isPenalty})>[
              (
                label: 'Banı Kaldır',
                icon: Icons.check_circle_outline_rounded,
                onTap: onUnban,
                isRelease: true,
                isPenalty: false,
              ),
            ],
          ),
        if (player.isTradeBanned)
          _AionModeratorActionBanner(
            title: 'TİCARET & PAZAR YASAĞI',
            subtitle: 'Bitiş: ${_fmtDate(player.tradeBannedUntil)}',
            accent: _AionTokens.celestialGold,
            icon: Icons.remove_shopping_cart_rounded,
            actions: <({String label, IconData icon, VoidCallback? onTap, bool isRelease, bool isPenalty})>[
              (
                label: 'Yasağı Kaldır',
                icon: Icons.shopping_bag_outlined,
                onTap: onReleaseTradeBan,
                isRelease: true,
                isPenalty: false,
              ),
            ],
          ),
        if (player.isChatMuted)
          _AionModeratorActionBanner(
            title: 'CHAT & İLETİŞİM SUSTURMA',
            subtitle: 'Bitiş: ${_fmtDate(player.chatMutedUntil)}',
            accent: _AionTokens.fuchsiaAccent,
            icon: Icons.volume_off_rounded,
            actions: <({String label, IconData icon, VoidCallback? onTap, bool isRelease, bool isPenalty})>[
              (
                label: 'Susturmayı Aç',
                icon: Icons.volume_up_rounded,
                onTap: onReleaseChatMute,
                isRelease: true,
                isPenalty: false,
              ),
            ],
          ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Shared Section Header Builder
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color accent,
  }) {
    return Row(
      children: <Widget>[
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.65),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Icon(icon, size: 13, color: accent),
        const SizedBox(width: 5),
        Text(
          title,
          style: AppTextStyles.captionBold.copyWith(
            color: accent,
            fontSize: 10,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactMetricPill({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _AionTokens.obsidianDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accent.withValues(alpha: 0.35),
          width: 0.9,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: supportCaptionStyle.copyWith(fontSize: 8.5, letterSpacing: 0.6),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: AppTextStyles.bodyBold.copyWith(
                      color: SettingsPalette.textHi,
                      fontSize: 12,
                    ),
                    maxLines: 1,
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

// ────────────────────────────────────────────────────────────────────────────
// 2027 Aion 2 Obsidian-Glass Card Container with Specular Rim & Blur Sigma 16
// ────────────────────────────────────────────────────────────────────────────

class _AionObsidianGlassCard extends StatelessWidget {
  const _AionObsidianGlassCard({
    required this.child,
    this.accent = _AionTokens.celestialGold,
    this.padding = const EdgeInsets.all(14),
    this.glow = false,
    this.hasRunicCorners = false,
    this.hasDotGrid = false,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final bool glow;
  final bool hasRunicCorners;
  final bool hasDotGrid;

  @override
  Widget build(BuildContext context) {
    final double adaptiveBlur = StaffDesign.adaptiveBlur(
      context,
      defaultSigma: _AionTokens.glassBlurSigma,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_AionTokens.cardRadius),
        boxShadow: glow
            ? <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.18),
                  blurRadius: 22,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_AionTokens.cardRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: adaptiveBlur,
            sigmaY: adaptiveBlur,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_AionTokens.cardRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  accent.withValues(alpha: 0.08),
                  _AionTokens.obsidianSurface.withValues(alpha: 0.90),
                  _AionTokens.obsidianDeep.withValues(alpha: 0.96),
                ],
              ),
              border: Border.all(
                color: accent.withValues(alpha: 0.38),
                width: 1.1,
              ),
            ),
            child: Stack(
              children: <Widget>[
                if (hasDotGrid)
                  const Positioned.fill(
                    child: CustomPaint(
                      painter: _AionDotMatrixPainter(
                        spacing: 14,
                        dotOpacity: 0.045,
                      ),
                    ),
                  ),

                // Specular top rim reflection
                Positioned(
                  top: 0,
                  left: 12,
                  right: 12,
                  height: 1.3,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.transparent,
                          accent.withValues(alpha: 0.5),
                          Colors.white.withValues(alpha: 0.75),
                          accent.withValues(alpha: 0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                if (hasRunicCorners)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _AionRunicCornerPainter(accent: accent),
                    ),
                  ),

                Padding(
                  padding: padding,
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Telemetry Stat Metric Badge with Overflow Protection
// ────────────────────────────────────────────────────────────────────────────

class _AionTelemetryBadge extends StatelessWidget {
  const _AionTelemetryBadge({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_AionTokens.chipRadius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            accent.withValues(alpha: 0.12),
            _AionTokens.obsidianDeep.withValues(alpha: 0.85),
          ],
        ),
        border: Border.all(
          color: accent.withValues(alpha: 0.35),
          width: 0.9,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 11, color: accent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: supportCaptionStyle.copyWith(
                    fontSize: 8.5,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: AppTextStyles.bodyBold.copyWith(
                color: accent == _AionTokens.celestialGold
                    ? _AionTokens.celestialGold
                    : SettingsPalette.textHi,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// VIP Tier Luminescence Badge (Celestial Gold + Ether Cyan)
// ────────────────────────────────────────────────────────────────────────────

class _AionVipLuminescenceBadge extends StatelessWidget {
  const _AionVipLuminescenceBadge({
    required this.level,
    required this.power,
    this.kingBadge,
    this.staffBadge,
  });

  final int level;
  final int power;
  final String? kingBadge;
  final String? staffBadge;

  ({String title, String rankCode, int stars}) _computeVipTier() {
    if (kingBadge != null) {
      return (title: 'CELESTIAL ARCHON', rankCode: 'VIP TIER VII', stars: 7);
    }
    if (staffBadge != null) {
      return (title: 'AION SENTINEL', rankCode: 'VIP TIER VI', stars: 6);
    }
    if (power >= 50000 || level >= 80) {
      return (title: 'MYTHIC ASCENDANT', rankCode: 'VIP TIER V', stars: 5);
    }
    if (power >= 25000 || level >= 60) {
      return (title: 'ETERNAL KNIGHT', rankCode: 'VIP TIER IV', stars: 4);
    }
    if (power >= 10000 || level >= 40) {
      return (title: 'IMPERIAL LEGATUS', rankCode: 'VIP TIER III', stars: 3);
    }
    if (power >= 3000 || level >= 20) {
      return (title: 'HONOR VANGUARD', rankCode: 'VIP TIER II', stars: 2);
    }
    return (title: 'AION CITIZEN', rankCode: 'VIP TIER I', stars: 1);
  }

  @override
  Widget build(BuildContext context) {
    final ({String rankCode, int stars, String title}) vip = _computeVipTier();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: <Color>[
            _AionTokens.celestialGold.withValues(alpha: 0.24),
            _AionTokens.etherCyan.withValues(alpha: 0.16),
            _AionTokens.obsidianDeep.withValues(alpha: 0.90),
          ],
        ),
        border: Border.all(
          color: _AionTokens.celestialGold.withValues(alpha: 0.8),
          width: 1.15,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _AionTokens.celestialGold.withValues(alpha: 0.28),
            blurRadius: 10,
            spreadRadius: 0.5,
          ),
          BoxShadow(
            color: _AionTokens.etherCyan.withValues(alpha: 0.20),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: <Color>[
                  _AionTokens.celestialGold,
                  _AionTokens.etherCyan,
                ],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _AionTokens.celestialGold.withValues(alpha: 0.7),
                  blurRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.stars_rounded,
              size: 11,
              color: _AionTokens.obsidianDeep,
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                vip.title,
                style: GoogleFonts.cinzel(
                  color: _AionTokens.celestialGold,
                  fontSize: 9.2,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w800,
                  shadows: <Shadow>[
                    Shadow(
                      color: _AionTokens.celestialGold.withValues(alpha: 0.65),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    vip.rankCode,
                    style: AppTextStyles.caption.copyWith(
                      color: _AionTokens.etherCyan,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(width: 4),
                  for (int i = 0; i < math.min(vip.stars, 5); i++)
                    const Icon(
                      Icons.star_rounded,
                      size: 8,
                      color: _AionTokens.celestialGold,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Status Indicator Pill
// ────────────────────────────────────────────────────────────────────────────

class _AionStatusIndicator extends StatelessWidget {
  const _AionStatusIndicator({
    required this.label,
    required this.color,
    this.isPulsing = false,
  });

  final String label;
  final Color color;
  final bool isPulsing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.55),
          width: 0.9,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: isPulsing
                  ? <BoxShadow>[
                      BoxShadow(
                        color: color.withValues(alpha: 0.85),
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.captionBold.copyWith(
              color: color,
              fontSize: 8.5,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Moderator Action Banner with Tactile Haptic Triggers & Semantic Colors
// ────────────────────────────────────────────────────────────────────────────

class _AionModeratorActionBanner extends StatelessWidget {
  const _AionModeratorActionBanner({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    this.actions = const <({
      String label,
      IconData icon,
      VoidCallback? onTap,
      bool isRelease,
      bool isPenalty,
    })>[],
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final List<({
    String label,
    IconData icon,
    VoidCallback? onTap,
    bool isRelease,
    bool isPenalty,
  })> actions;

  @override
  Widget build(BuildContext context) {
    final Iterable<({
      String label,
      IconData icon,
      VoidCallback? onTap,
      bool isRelease,
      bool isPenalty,
    })> visibleActions = actions.where((({
      String label,
      IconData icon,
      VoidCallback? onTap,
      bool isRelease,
      bool isPenalty,
    }) a) => a.onTap != null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _AionObsidianGlassCard(
        accent: accent,
        padding: const EdgeInsets.all(12),
        hasDotGrid: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.5),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: accent.withValues(alpha: 0.25),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: AppTextStyles.bodyBold.copyWith(
                          color: SettingsPalette.textHi,
                          fontSize: 12.5,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: supportCaptionStyle.copyWith(
                          color: SettingsPalette.textMid,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (visibleActions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  for (final ({
                    String label,
                    IconData icon,
                    VoidCallback? onTap,
                    bool isRelease,
                    bool isPenalty,
                  }) action in visibleActions)
                    _AionTactileButton(
                      label: action.label,
                      icon: action.icon,
                      accent: action.isRelease
                          ? _AionTokens.emeraldAccent
                          : action.isPenalty
                              ? _AionTokens.rubyAccent
                              : accent,
                      onTap: () {
                        if (action.isRelease) {
                          AppHaptics.success();
                        } else if (action.isPenalty) {
                          AppHaptics.heavy();
                        } else {
                          AppHaptics.medium();
                        }
                        action.onTap?.call();
                      },
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

// ────────────────────────────────────────────────────────────────────────────
// Tactile Glass Action Button with AppHaptics
// ────────────────────────────────────────────────────────────────────────────

class _AionTactileButton extends StatelessWidget {
  const _AionTactileButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: _AionTokens.obsidianDeep.withValues(alpha: 0.8),
          border: Border.all(
            color: accent.withValues(alpha: 0.65),
            width: 1.05,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: 0.16),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 13, color: accent),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTextStyles.captionBold.copyWith(
                color: accent,
                fontSize: 10.5,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Custom Painters: Dot Grid Matrix, Runic Divider & Corner Accents
// ────────────────────────────────────────────────────────────────────────────

class _AionDotMatrixPainter extends CustomPainter {
  const _AionDotMatrixPainter({
    this.spacing = 14.0,
    this.dotRadius = 0.65,
    this.dotOpacity = 0.045,
  });

  final double spacing;
  final double dotRadius;
  final double dotOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: dotOpacity)
      ..style = PaintingStyle.fill;

    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AionDotMatrixPainter oldDelegate) =>
      oldDelegate.spacing != spacing ||
      oldDelegate.dotRadius != dotRadius ||
      oldDelegate.dotOpacity != dotOpacity;
}

class _AionRunicDivider extends StatelessWidget {
  const _AionRunicDivider({this.accent = _AionTokens.etherCyan});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1.0,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Colors.transparent,
            accent.withValues(alpha: 0.35),
            accent.withValues(alpha: 0.7),
            accent.withValues(alpha: 0.35),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _AionRunicCornerPainter extends CustomPainter {
  const _AionRunicCornerPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = accent.withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double inset = 4.0;
    const double notch = 8.0;

    // Top-left
    canvas.drawLine(const Offset(inset, inset + notch), const Offset(inset, inset), paint);
    canvas.drawLine(const Offset(inset, inset), const Offset(inset + notch, inset), paint);

    // Top-right
    canvas.drawLine(Offset(size.width - inset - notch, inset), Offset(size.width - inset, inset), paint);
    canvas.drawLine(Offset(size.width - inset, inset), Offset(size.width - inset, inset + notch), paint);

    // Bottom-left
    canvas.drawLine(Offset(inset, size.height - inset - notch), Offset(inset, size.height - inset), paint);
    canvas.drawLine(Offset(inset, size.height - inset), Offset(inset + notch, size.height - inset), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width - inset - notch, size.height - inset), Offset(size.width - inset, size.height - inset), paint);
    canvas.drawLine(Offset(size.width - inset, size.height - inset), Offset(size.width - inset, size.height - inset - notch), paint);
  }

  @override
  bool shouldRepaint(covariant _AionRunicCornerPainter oldDelegate) =>
      oldDelegate.accent != accent;
}
