import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';

/// Authority, military rank, and prestige badge tiers for Aion 2 Mobile.
enum StaffBadgeType {
  admin,
  gm,
  king,
  vip,
  abyssGeneral,
  commander,
  centurion,
  legatus,
}

/// 2027 Aion 2 Obsidian-Glass Celestial Divinity Staff & Rank Badge.
///
/// Implements 2027 Aion 2 design standard:
/// - Deep obsidian crystalline glass pill background
/// - Dual-stop celestial gold (#E5C158, #FFA000) gradient border with dynamic glint
/// - Radiant particle aura with Ether Cyan (#00E5FF) pulse and orbiting starlight motes
/// - Sculpted celestial Archon/Daeva wing accents
/// - High-definition cinzel typography with metallic gold luster
/// - Full SafeArea / MediaQuery insets protection
/// - Tactile HapticFeedback and interactive press scale
class StaffBadge extends StatefulWidget {
  const StaffBadge({
    super.key,
    required this.badge,
    this.compact = false,
    this.showAura = true,
    this.onTap,
    this.showWings = true,
    this.showLoreOnTap = true,
  });

  final String? badge;
  final bool compact;
  final bool showAura;
  final VoidCallback? onTap;
  final bool showWings;
  final bool showLoreOnTap;

  @override
  State<StaffBadge> createState() => _StaffBadgeState();
}

class _StaffBadgeState extends State<StaffBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  StaffBadgeType? get _type {
    final String? raw = widget.badge;
    if (raw == null) return null;
    final String b = raw.trim().toLowerCase();
    if (b.isEmpty) return null;

    if (b == 'admin' || b.contains('admin')) return StaffBadgeType.admin;
    if (b == 'gm' || b.contains('gamemaster')) return StaffBadgeType.gm;
    if (b == 'king' || b.contains('sovereign') || b.contains('kral')) {
      return StaffBadgeType.king;
    }
    if (b == 'vip') return StaffBadgeType.vip;
    if (b.contains('general') || b == 'abyss_general') {
      return StaffBadgeType.abyssGeneral;
    }
    if (b.contains('commander') || b == 'komutan') {
      return StaffBadgeType.commander;
    }
    if (b.contains('centurion') || b == 'yuzbasi') {
      return StaffBadgeType.centurion;
    }
    if (b.contains('legatus') || b.contains('legion')) {
      return StaffBadgeType.legatus;
    }
    return null;
  }

  _BadgeStyle _resolveStyle(StaffBadgeType type) {
    switch (type) {
      case StaffBadgeType.king:
        return const _BadgeStyle(
          label: 'KING',
          loreTitle: 'Egemen Kral',
          subtitle: 'Atreia Yüce Hükümdarı',
          description:
              'Krallık tacı ve mutlak egemenlik yetkisine sahip hükümdar. Krallık hazinesi ve garnizonları onun emrindedir.',
          privilege: 'Mutlak Egemenlik & Kraliyet Bildirisi',
          primary: Color(0xFFFFD700),
          secondary: Color(0xFFFFA000),
          celestialGold: Color(0xFFE5C158),
          etherCyan: Color(0xFF00E5FF),
          glow: Color(0x77FFB800),
          darkBg: Color(0xF20F0B04),
          borderColor: Color(0xFFFFD54F),
          powerRating: 9999,
          stars: 5,
        );
      case StaffBadgeType.admin:
        return const _BadgeStyle(
          label: 'ADMIN',
          loreTitle: 'Sistem Yöneticisi',
          subtitle: 'Aion Yüce Muhafızı',
          description:
              'Atreia sunucusu, zaman çizelgesi ve çekirdek sistemlerin mutlak koruyucusu ve kurucusudur.',
          privilege: 'Kök Sistem Erişimi & Dünya Müdahalesi',
          primary: Color(0xFFFFE082),
          secondary: Color(0xFFFFA000),
          celestialGold: Color(0xFFE5C158),
          etherCyan: Color(0xFF00E5FF),
          glow: Color(0x77FFC107),
          darkBg: Color(0xF2080C14),
          borderColor: Color(0xFFFFE082),
          powerRating: 9900,
          stars: 5,
        );
      case StaffBadgeType.gm:
        return const _BadgeStyle(
          label: 'GM',
          loreTitle: 'Oyun Yöneticisi',
          subtitle: 'Kadim Gözcü & Hakem',
          description:
              'Oyuncuları koruyan, adaleti sağlayan, etkinlikleri düzenleyen ve Atreia dengesini gözeten Game Master.',
          privilege: 'Gözetim, Etkinlik & Anında Müdahale',
          primary: Color(0xFF00FF88),
          secondary: Color(0xFF00E5FF),
          celestialGold: Color(0xFFE5C158),
          etherCyan: Color(0xFF00E5FF),
          glow: Color(0x7700E5FF),
          darkBg: Color(0xF204120D),
          borderColor: Color(0xFF00E5FF),
          powerRating: 9500,
          stars: 4,
        );
      case StaffBadgeType.vip:
        return const _BadgeStyle(
          label: 'VIP',
          loreTitle: 'Seçkin Şövalye',
          subtitle: 'Astral Şafak Lordu',
          description:
              'Aion seçkinler meclisi asil Daeva unvanı. Özel binekler, astral kanatlar ve ayrıcalıklı tüccar erişimi taşır.',
          privilege: 'Özel Ticaret Podyumu & Astral Kanatlar',
          primary: Color(0xFFE040FB),
          secondary: Color(0xFF7C4DFF),
          celestialGold: Color(0xFFE5C158),
          etherCyan: Color(0xFF00E5FF),
          glow: Color(0x66E040FB),
          darkBg: Color(0xF2120619),
          borderColor: Color(0xFFEA80FC),
          powerRating: 8800,
          stars: 3,
        );
      case StaffBadgeType.abyssGeneral:
        return const _BadgeStyle(
          label: 'GENERAL',
          loreTitle: 'Abyss Baş Generali',
          subtitle: '5★ Uçurum Mareşali',
          description:
              'Abyss savaş meydanlarının en yüksek rütbeli muzaffer komutanı. Kuşatma lejyonlarına doğrudan hükmeder.',
          privilege: 'Abyss Kale Kuşatması Komutanlığı',
          primary: Color(0xFFFF2A55),
          secondary: Color(0xFFFFD700),
          celestialGold: Color(0xFFE5C158),
          etherCyan: Color(0xFF00E5FF),
          glow: Color(0x77FF1744),
          darkBg: Color(0xF2170409),
          borderColor: Color(0xFFFF5252),
          powerRating: 9200,
          stars: 5,
        );
      case StaffBadgeType.commander:
        return const _BadgeStyle(
          label: 'KOMUTAN',
          loreTitle: 'Abyss Komutanı',
          subtitle: '4★ Cephe Kumandanı',
          description:
              'Bölge savunmasını ve taktik baskınlarını koordine eden deneyimli yüksek subay.',
          privilege: 'Taktik Harp Bildirisi & Birlik Sevk',
          primary: Color(0xFFFF6D00),
          secondary: Color(0xFFFFD54F),
          celestialGold: Color(0xFFE5C158),
          etherCyan: Color(0xFF00E5FF),
          glow: Color(0x66FF6D00),
          darkBg: Color(0xF2140803),
          borderColor: Color(0xFFFF9100),
          powerRating: 8400,
          stars: 4,
        );
      case StaffBadgeType.centurion:
        return const _BadgeStyle(
          label: 'CENTURION',
          loreTitle: 'Abyss Yüzbaşısı',
          subtitle: '3★ Lejyon Muhafızı',
          description:
              'Öncü piyade ve akıncı birliklerini sıcak hatta cesaretle yöneten yüzbaşı.',
          privilege: 'Öncü Akın Emri & Cephe Takviyesi',
          primary: Color(0xFF00B0FF),
          secondary: Color(0xFF80D8FF),
          celestialGold: Color(0xFFE5C158),
          etherCyan: Color(0xFF00E5FF),
          glow: Color(0x6600B0FF),
          darkBg: Color(0xF2050E1A),
          borderColor: Color(0xFF40C4FF),
          powerRating: 7600,
          stars: 3,
        );
      case StaffBadgeType.legatus:
        return const _BadgeStyle(
          label: 'LEGATUS',
          loreTitle: 'Lejyon Sancaktarı',
          subtitle: 'Kadim Ejder Muhafızı',
          description:
              'Lejyon sancağını onurla taşıyan diplomatik ve askeri temsilci.',
          privilege: 'Lejyon İttifak Protokolü & Sancak Gücü',
          primary: Color(0xFFAB47BC),
          secondary: Color(0xFFFFD54F),
          celestialGold: Color(0xFFE5C158),
          etherCyan: Color(0xFF00E5FF),
          glow: Color(0x66AB47BC),
          darkBg: Color(0xF2100617),
          borderColor: Color(0xFFCE93D8),
          powerRating: 7200,
          stars: 2,
        );
    }
  }

  void _handleTap(BuildContext context, _BadgeStyle style) {
    HapticFeedback.selectionClick();
    if (widget.onTap != null) {
      widget.onTap!();
    } else if (widget.showLoreOnTap) {
      _showLoreModal(context, style);
    }
  }

  void _showLoreModal(BuildContext context, _BadgeStyle style) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        final EdgeInsets safePadding =
            MediaQuery.maybePaddingOf(ctx) ?? EdgeInsets.zero;
        final EdgeInsets viewInsets =
            MediaQuery.maybeViewInsetsOf(ctx) ?? EdgeInsets.zero;

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: safePadding.top + 20,
            bottom: math.max(safePadding.bottom, viewInsets.bottom) + 16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xF5090C16),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: style.celestialGold.withValues(alpha: 0.65),
                        width: 1.5,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: style.glow.withValues(alpha: 0.45),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: style.etherCyan.withValues(alpha: 0.25),
                          blurRadius: 20,
                        ),
                        const BoxShadow(
                          color: Colors.black87,
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: style.darkBg,
                                border: Border.all(
                                  color: style.celestialGold,
                                  width: 1.8,
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: style.glow,
                                    blurRadius: 14,
                                    spreadRadius: 1,
                                  ),
                                  BoxShadow(
                                    color: style.etherCyan.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: CustomPaint(
                                  size: const Size(30, 24),
                                  painter: _StaffCrestPainter(
                                    type: _type!,
                                    primaryColor: style.primary,
                                    secondaryColor: style.secondary,
                                    celestialGold: style.celestialGold,
                                    etherCyan: style.etherCyan,
                                    pulse: 1.0,
                                    drawWings: true,
                                    compact: false,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    style.loreTitle,
                                    style: GoogleFonts.cinzel(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                      color: style.celestialGold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    style.subtitle,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: style.etherCyan,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close, color: Colors.white70),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                Navigator.of(ctx).pop();
                              },
                            ),
                          ],
                        ),
                        const Divider(
                          color: Color(0x33E5C158),
                          height: 26,
                          thickness: 1,
                        ),
                        Text(
                          style.description,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: const Color(0xFFD3DEEE),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x40141D30),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: style.celestialGold.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.verified_user_rounded,
                                size: 16,
                                color: style.celestialGold,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  style.privilege,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Row(
                              children: List<Widget>.generate(
                                5,
                                (int i) => Icon(
                                  Icons.star_rounded,
                                  size: 20,
                                  color: i < style.stars
                                      ? style.celestialGold
                                      : Colors.white12,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: style.etherCyan.withValues(alpha: 0.5),
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                'DİVİNİTY: ${style.powerRating}',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: style.etherCyan,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final StaffBadgeType? type = _type;
    if (type == null) return const SizedBox.shrink();

    final _BadgeStyle style = _resolveStyle(type);
    final bool compact = widget.compact;

    return Semantics(
      label: 'Yetkili Rozeti: ${style.loreTitle} (${style.label})',
      button: true,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (BuildContext context, Widget? child) {
          final double pulse = _pulseAnimation.value;
          final double glowAlpha =
              widget.showAura ? (0.30 + 0.25 * pulse) : 0.15;
          final double etherGlintAlpha = 0.45 + 0.55 * pulse;

          return Tooltip(
            message: '${style.loreTitle} — ${style.subtitle}',
            waitDuration: const Duration(milliseconds: 250),
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapUp: (_) {
                setState(() => _isPressed = false);
                _handleTap(context, style);
              },
              onTapCancel: () => setState(() => _isPressed = false),
              behavior: HitTestBehavior.opaque,
              child: AnimatedScale(
                scale: _isPressed ? 0.94 : 1.0,
                duration: const Duration(milliseconds: 110),
                curve: Curves.easeOutCubic,
                child: Container(
                  margin: EdgeInsets.only(
                    left: compact ? 3.0 : 5.0,
                    right: compact ? 2.5 : 4.5,
                  ),
                  child: CustomPaint(
                    painter: _ObsidianGlassPillPainter(
                      style: style,
                      pulse: pulse,
                      showAura: widget.showAura,
                      glowAlpha: glowAlpha,
                      etherGlintAlpha: etherGlintAlpha,
                      compact: compact,
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 7.0 : 10.5,
                        vertical: compact ? 2.2 : 3.8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          CustomPaint(
                            size: Size(
                              compact ? 16.0 : 22.0,
                              compact ? 13.0 : 17.0,
                            ),
                            painter: _StaffCrestPainter(
                              type: type,
                              primaryColor: style.primary,
                              secondaryColor: style.secondary,
                              celestialGold: style.celestialGold,
                              etherCyan: style.etherCyan,
                              pulse: pulse,
                              drawWings: widget.showWings,
                              compact: compact,
                            ),
                          ),
                          SizedBox(width: compact ? 3.5 : 5.5),
                          ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Colors.white,
                                  style.celestialGold,
                                  style.secondary,
                                ],
                                stops: const <double>[0.0, 0.42, 1.0],
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.srcIn,
                            child: Text(
                              style.label,
                              style: GoogleFonts.cinzel(
                                fontSize: compact ? 9.2 : 11.2,
                                fontWeight: FontWeight.w900,
                                letterSpacing: compact ? 0.75 : 1.15,
                                height: 1.02,
                                shadows: <Shadow>[
                                  Shadow(
                                    color: style.glow,
                                    blurRadius: compact ? 4 : 6,
                                  ),
                                  const Shadow(
                                    color: Colors.black,
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (!compact) ...<Widget>[
                            const SizedBox(width: 5.0),
                            Container(
                              width: 3.5,
                              height: 3.5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: style.etherCyan.withValues(
                                  alpha: 0.6 + 0.4 * pulse,
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: style.etherCyan,
                                    blurRadius: 4,
                                    spreadRadius: 0.6,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BadgeStyle {
  const _BadgeStyle({
    required this.label,
    required this.loreTitle,
    required this.subtitle,
    required this.description,
    required this.privilege,
    required this.primary,
    required this.secondary,
    required this.celestialGold,
    required this.etherCyan,
    required this.glow,
    required this.darkBg,
    required this.borderColor,
    required this.powerRating,
    required this.stars,
  });

  final String label;
  final String loreTitle;
  final String subtitle;
  final String description;
  final String privilege;
  final Color primary;
  final Color secondary;
  final Color celestialGold;
  final Color etherCyan;
  final Color glow;
  final Color darkBg;
  final Color borderColor;
  final int powerRating;
  final int stars;
}

/// Custom painter rendering 2027 Obsidian-Glass Pill body, multi-stop celestial gold
/// & Ether Cyan border, specular crystal bevel, and radiant celestial starlight motes.
class _ObsidianGlassPillPainter extends CustomPainter {
  const _ObsidianGlassPillPainter({
    required this.style,
    required this.pulse,
    required this.showAura,
    required this.glowAlpha,
    required this.etherGlintAlpha,
    required this.compact,
  });

  final _BadgeStyle style;
  final double pulse;
  final bool showAura;
  final double glowAlpha;
  final double etherGlintAlpha;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = compact ? 8.5 : 12.0;
    final RRect rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    // 1. Radiant Aura Bloom
    if (showAura) {
      final Paint glowPaint = Paint()
        ..color = style.glow.withValues(alpha: glowAlpha * 0.48)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          compact ? 5.5 + 3.0 * pulse : 9.0 + 5.0 * pulse,
        );
      canvas.drawRRect(rrect.inflate(compact ? 1.0 : 2.0), glowPaint);

      // Ether Cyan radiant energy pulse
      final Paint cyanPulsePaint = Paint()
        ..color = style.etherCyan.withValues(alpha: glowAlpha * 0.38)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          compact ? 2.5 + 2.0 * pulse : 4.5 + 3.0 * pulse,
        );
      canvas.drawRRect(rrect.inflate(0.5), cyanPulsePaint);

      // Radiant Particle Motes (Floating Starlight Sparks)
      _drawRadiantParticles(canvas, size, rrect);
    }

    // 2. Obsidian Ambient Drop Shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawRRect(rrect.shift(const Offset(0, 2.0)), shadowPaint);

    // 3. Deep Obsidian Crystal Glass Base
    final Paint baseGlassPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          const Color(0xFF161F2E),
          style.darkBg,
          const Color(0xFF04070D),
        ],
        stops: const <double>[0.0, 0.52, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(rrect, baseGlassPaint);

    // 4. Specular Curved Glass Sheen (Top Half)
    final Rect topSheenRect =
        Rect.fromLTWH(0, 0, size.width, size.height * 0.52);
    final Path sheenPath = Path()
      ..addRRect(rrect)
      ..close();

    canvas.save();
    canvas.clipPath(sheenPath);
    final Paint sheenPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.32),
          Colors.white.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.42, 1.0],
      ).createShader(topSheenRect);
    canvas.drawRect(topSheenRect, sheenPaint);
    canvas.restore();

    // 5. Celestial Gold & Ether Cyan Border Glint
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? 1.0 : 1.3
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: <Color>[
          style.celestialGold,
          style.etherCyan.withValues(alpha: etherGlintAlpha),
          style.secondary,
          style.celestialGold,
          const Color(0xFFFFF2B2),
          style.celestialGold,
        ],
        stops: const <double>[0.0, 0.22, 0.5, 0.74, 0.88, 1.0],
        transform: GradientRotation(pulse * math.pi * 2),
      ).createShader(Offset.zero & size);
    canvas.drawRRect(rrect, borderPaint);

    // 6. Inner Crystal Bevel Highlight
    final RRect innerRRect = rrect.deflate(compact ? 0.7 : 0.9);
    final Paint innerBevelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = Colors.white.withValues(alpha: 0.12 + 0.10 * pulse);
    canvas.drawRRect(innerRRect, innerBevelPaint);
  }

  /// Celestial sparks and starlight motes orbiting the badge perimeter
  void _drawRadiantParticles(Canvas canvas, Size size, RRect rrect) {
    final double w = size.width;
    final double h = size.height;

    // Particle 1: Top-Right Ether Cyan diamond sparkle
    final double p1Phase = (pulse * 2 * math.pi);
    final Offset p1 = Offset(
      w * 0.88 + 2.0 * math.cos(p1Phase),
      -1.5 + 1.5 * math.sin(p1Phase),
    );
    _drawSpark(canvas, p1, compact ? 1.4 : 2.0, style.etherCyan, 0.8 * pulse);

    // Particle 2: Bottom-Left Celestial Gold diamond sparkle
    final Offset p2 = Offset(
      w * 0.12 - 2.0 * math.sin(p1Phase),
      h + 1.2 - 1.2 * math.cos(p1Phase),
    );
    _drawSpark(
      canvas,
      p2,
      compact ? 1.2 : 1.8,
      style.celestialGold,
      0.7 * (1.0 - pulse),
    );

    if (!compact) {
      // Particle 3: Top-Left floating cyan ember
      final Offset p3 =
          Offset(w * 0.25, -2.5 + 2.0 * math.sin(p1Phase + 1.0));
      _drawSpark(canvas, p3, 1.4, style.etherCyan, 0.6 * pulse);

      // Particle 4: Bottom-Right golden ember
      final Offset p4 =
          Offset(w * 0.75, h + 2.0 - 2.0 * math.cos(p1Phase + 1.0));
      _drawSpark(canvas, p4, 1.4, style.celestialGold, 0.65 * (1.0 - pulse));
    }
  }

  void _drawSpark(
    Canvas canvas,
    Offset pos,
    double radius,
    Color color,
    double alpha,
  ) {
    if (alpha <= 0.05) return;
    final Paint sparkPaint = Paint()
      ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;

    // Diamond 4-point sparkle
    final Path path = Path()
      ..moveTo(pos.dx, pos.dy - radius)
      ..lineTo(pos.dx + radius * 0.5, pos.dy)
      ..lineTo(pos.dx, pos.dy + radius)
      ..lineTo(pos.dx - radius * 0.5, pos.dy)
      ..close();
    canvas.drawPath(path, sparkPaint);

    final Paint glow = Paint()
      ..color = color.withValues(alpha: (alpha * 0.5).clamp(0.0, 1.0))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    canvas.drawCircle(pos, radius * 0.7, glow);
  }

  @override
  bool shouldRepaint(covariant _ObsidianGlassPillPainter oldDelegate) {
    return oldDelegate.pulse != pulse ||
        oldDelegate.style != style ||
        oldDelegate.showAura != showAura ||
        oldDelegate.compact != compact;
  }
}

/// Canvas renderer for 2027 Aion 2 high-fantasy military and staff crest heraldry,
/// including Archon/Daeva celestial wing accents and Ether Cyan runes.
class _StaffCrestPainter extends CustomPainter {
  const _StaffCrestPainter({
    required this.type,
    required this.primaryColor,
    required this.secondaryColor,
    required this.celestialGold,
    required this.etherCyan,
    required this.pulse,
    this.drawWings = true,
    this.compact = false,
  });

  final StaffBadgeType type;
  final Color primaryColor;
  final Color secondaryColor;
  final Color celestialGold;
  final Color etherCyan;
  final double pulse;
  final bool drawWings;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Wings frame the sides
    if (drawWings) {
      _drawCelestialWings(canvas, w, h);
    }

    // Heraldic crest occupies the center
    final double crestSize = compact ? h * 0.95 : h * 0.92;
    final Rect crestRect = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.5),
      width: crestSize,
      height: crestSize,
    );

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[primaryColor, secondaryColor],
      ).createShader(crestRect)
      ..style = PaintingStyle.fill;

    final Paint strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85 + 0.15 * pulse)
      ..strokeWidth = compact ? 0.8 : 1.0
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.translate(crestRect.left, crestRect.top);
    final double cw = crestRect.width;
    final double ch = crestRect.height;

    switch (type) {
      case StaffBadgeType.king:
        _drawCrown(canvas, cw, ch, fillPaint, strokePaint);
        break;
      case StaffBadgeType.admin:
        _drawWingedAegis(canvas, cw, ch, fillPaint, strokePaint);
        break;
      case StaffBadgeType.gm:
        _drawMysticEye(canvas, cw, ch, fillPaint, strokePaint);
        break;
      case StaffBadgeType.vip:
        _drawStarOfDawn(canvas, cw, ch, fillPaint, strokePaint);
        break;
      case StaffBadgeType.abyssGeneral:
        _drawAbyssGeneralStar(canvas, cw, ch, fillPaint, strokePaint);
        break;
      case StaffBadgeType.commander:
        _drawCrossedSwords(canvas, cw, ch, fillPaint, strokePaint);
        break;
      case StaffBadgeType.centurion:
        _drawLionShield(canvas, cw, ch, fillPaint, strokePaint);
        break;
      case StaffBadgeType.legatus:
        _drawDragonInsignia(canvas, cw, ch, fillPaint, strokePaint);
        break;
    }
    canvas.restore();
  }

  /// Celestial Daeva wing accents framing the heraldic insignia
  void _drawCelestialWings(Canvas canvas, double w, double h) {
    final Paint wingPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          celestialGold.withValues(alpha: 0.75 + 0.25 * pulse),
          etherCyan.withValues(alpha: 0.5),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? 0.75 : 0.95
      ..strokeCap = StrokeCap.round;

    // Left feather arch (flanking outward)
    final Path leftWing = Path()
      ..moveTo(w * 0.32, h * 0.72)
      ..quadraticBezierTo(w * 0.08, h * 0.52, w * 0.02, h * 0.22)
      ..quadraticBezierTo(w * 0.14, h * 0.38, w * 0.28, h * 0.44);
    canvas.drawPath(leftWing, wingPaint);

    // Left secondary feather tip
    final Path leftFeather = Path()
      ..moveTo(w * 0.24, h * 0.65)
      ..quadraticBezierTo(w * 0.06, h * 0.45, w * 0.05, h * 0.32);
    canvas.drawPath(leftFeather, wingPaint);

    // Right feather arch (flanking outward)
    final Path rightWing = Path()
      ..moveTo(w * 0.68, h * 0.72)
      ..quadraticBezierTo(w * 0.92, h * 0.52, w * 0.98, h * 0.22)
      ..quadraticBezierTo(w * 0.86, h * 0.38, w * 0.72, h * 0.44);
    canvas.drawPath(rightWing, wingPaint);

    // Right secondary feather tip
    final Path rightFeather = Path()
      ..moveTo(w * 0.76, h * 0.65)
      ..quadraticBezierTo(w * 0.94, h * 0.45, w * 0.95, h * 0.32);
    canvas.drawPath(rightFeather, wingPaint);
  }

  void _drawCrown(
    Canvas canvas,
    double w,
    double h,
    Paint fill,
    Paint stroke,
  ) {
    final Path path = Path()
      ..moveTo(w * 0.15, h * 0.82)
      ..lineTo(w * 0.85, h * 0.82)
      ..lineTo(w * 0.82, h * 0.42)
      ..lineTo(w * 0.65, h * 0.62)
      ..lineTo(w * 0.5, h * 0.18)
      ..lineTo(w * 0.35, h * 0.62)
      ..lineTo(w * 0.18, h * 0.42)
      ..close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);

    // Royal ruby gem with glowing halo
    final Offset rubyCenter = Offset(w * 0.5, h * 0.22);
    canvas.drawCircle(
      rubyCenter,
      w * 0.09,
      Paint()..color = const Color(0xFFFF2A55),
    );
    canvas.drawCircle(
      rubyCenter,
      w * 0.04,
      Paint()..color = Colors.white,
    );
  }

  void _drawWingedAegis(
    Canvas canvas,
    double w,
    double h,
    Paint fill,
    Paint stroke,
  ) {
    final Path shield = Path()
      ..moveTo(w * 0.22, h * 0.2)
      ..lineTo(w * 0.78, h * 0.2)
      ..lineTo(w * 0.74, h * 0.65)
      ..quadraticBezierTo(w * 0.5, h * 0.95, w * 0.5, h * 0.95)
      ..quadraticBezierTo(w * 0.26, h * 0.65, w * 0.22, h * 0.2)
      ..close();

    canvas.drawPath(shield, fill);
    canvas.drawPath(shield, stroke);

    // Thunderbolt divine rune
    final Path bolt = Path()
      ..moveTo(w * 0.55, h * 0.28)
      ..lineTo(w * 0.42, h * 0.52)
      ..lineTo(w * 0.58, h * 0.52)
      ..lineTo(w * 0.45, h * 0.82)
      ..lineTo(w * 0.49, h * 0.58)
      ..lineTo(w * 0.38, h * 0.58)
      ..close();

    canvas.drawPath(bolt, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.5),
      w * 0.06,
      Paint()..color = etherCyan,
    );
  }

  void _drawMysticEye(
    Canvas canvas,
    double w,
    double h,
    Paint fill,
    Paint stroke,
  ) {
    final Path eye = Path()
      ..moveTo(w * 0.12, h * 0.5)
      ..quadraticBezierTo(w * 0.5, h * 0.16, w * 0.88, h * 0.5)
      ..quadraticBezierTo(w * 0.5, h * 0.84, w * 0.12, h * 0.5)
      ..close();

    canvas.drawPath(eye, stroke);
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.25, fill);

    // Sacred pupil & ether iris
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.5),
      w * 0.14,
      Paint()..color = const Color(0xFF040A10),
    );
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.5),
      w * 0.06,
      Paint()..color = etherCyan,
    );
  }

  void _drawStarOfDawn(
    Canvas canvas,
    double w,
    double h,
    Paint fill,
    Paint stroke,
  ) {
    final Path star = Path();
    final double cx = w * 0.5;
    final double cy = h * 0.5;
    const int points = 8;
    final double rOuter = w * 0.48;
    final double rInner = w * 0.19;

    for (int i = 0; i < points * 2; i++) {
      final double r = (i % 2 == 0) ? rOuter : rInner;
      final double angle = (i * math.pi) / points - math.pi / 2;
      final double x = cx + r * math.cos(angle);
      final double y = cy + r * math.sin(angle);
      if (i == 0) {
        star.moveTo(x, y);
      } else {
        star.lineTo(x, y);
      }
    }
    star.close();

    canvas.drawPath(star, fill);
    canvas.drawPath(star, stroke);

    canvas.drawCircle(
      Offset(cx, cy),
      w * 0.09,
      Paint()..color = Colors.white,
    );
  }

  void _drawAbyssGeneralStar(
    Canvas canvas,
    double w,
    double h,
    Paint fill,
    Paint stroke,
  ) {
    final Path star = Path();
    final double cx = w * 0.5;
    final double cy = h * 0.5;
    const int points = 5;
    final double rOuter = w * 0.48;
    final double rInner = w * 0.22;

    for (int i = 0; i < points * 2; i++) {
      final double r = (i % 2 == 0) ? rOuter : rInner;
      final double angle = (i * math.pi) / points - math.pi / 2;
      final double x = cx + r * math.cos(angle);
      final double y = cy + r * math.sin(angle);
      if (i == 0) {
        star.moveTo(x, y);
      } else {
        star.lineTo(x, y);
      }
    }
    star.close();

    canvas.drawPath(star, fill);
    canvas.drawPath(star, stroke);

    // Abyss crimson core
    canvas.drawCircle(
      Offset(cx, cy),
      w * 0.14,
      Paint()..color = const Color(0xFFFF1744),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      w * 0.06,
      Paint()..color = Colors.white,
    );
  }

  void _drawCrossedSwords(
    Canvas canvas,
    double w,
    double h,
    Paint fill,
    Paint stroke,
  ) {
    final Paint blade = Paint()
      ..color = primaryColor
      ..strokeWidth = compact ? 1.2 : 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(w * 0.18, h * 0.82),
      Offset(w * 0.82, h * 0.18),
      blade,
    );
    canvas.drawLine(
      Offset(w * 0.82, h * 0.82),
      Offset(w * 0.18, h * 0.18),
      blade,
    );

    // Guard & pommel
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.5),
      w * 0.14,
      Paint()..color = secondaryColor,
    );
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.5),
      w * 0.06,
      Paint()..color = etherCyan,
    );
  }

  void _drawLionShield(
    Canvas canvas,
    double w,
    double h,
    Paint fill,
    Paint stroke,
  ) {
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.42, fill);
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.42, stroke);
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.5),
      w * 0.20,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.5),
      w * 0.08,
      Paint()..color = etherCyan,
    );
  }

  void _drawDragonInsignia(
    Canvas canvas,
    double w,
    double h,
    Paint fill,
    Paint stroke,
  ) {
    final Path dragon = Path()
      ..moveTo(w * 0.2, h * 0.8)
      ..quadraticBezierTo(w * 0.4, h * 0.6, w * 0.35, h * 0.3)
      ..lineTo(w * 0.65, h * 0.15)
      ..lineTo(w * 0.8, h * 0.4)
      ..quadraticBezierTo(w * 0.6, h * 0.5, w * 0.75, h * 0.85)
      ..close();

    canvas.drawPath(dragon, fill);
    canvas.drawPath(dragon, stroke);

    canvas.drawCircle(
      Offset(w * 0.52, h * 0.32),
      w * 0.06,
      Paint()..color = celestialGold,
    );
  }

  @override
  bool shouldRepaint(covariant _StaffCrestPainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.celestialGold != celestialGold ||
        oldDelegate.etherCyan != etherCyan ||
        oldDelegate.pulse != pulse ||
        oldDelegate.drawWings != drawWings ||
        oldDelegate.compact != compact;
  }
}
