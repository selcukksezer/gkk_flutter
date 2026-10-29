import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mekan_design.dart';
import 'mekan_theme.dart';

/// Production Aion-2 AAA V3 elevated art card for Mekan type selection.
/// Features atmospheric scene backdrops, luminous rarity frames,
/// frosted glass banner ribbons, high-detail type badges, and tactile spring scaling.
class MekanTypeArtCard extends StatefulWidget {
  const MekanTypeArtCard({
    super.key,
    required this.info,
    required this.selected,
    required this.locked,
    required this.affordable,
    required this.levelOk,
    required this.onTap,
    this.onLockedTap,
  });

  final MekanTypeInfo info;
  final bool selected;
  final bool locked;
  final bool affordable;
  final bool levelOk;
  final VoidCallback? onTap;
  final VoidCallback? onLockedTap;

  @override
  State<MekanTypeArtCard> createState() => _MekanTypeArtCardState();
}

class _MekanTypeArtCardState extends State<MekanTypeArtCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  static String _backdropForType(String typeKey) {
    switch (typeKey) {
      case 'bar':
        return 'assets/images/backgrounds/asmodae/bg_pandaemonium_capital.png';
      case 'kahvehane':
        return 'assets/images/backgrounds/asmodae/bg_beluslan_frozen_sea.png';
      case 'dovus_kulubu':
        return 'assets/images/backgrounds/dungeons/bg_empyrean_arena.png';
      case 'luks_lounge':
        return 'assets/images/backgrounds/dungeons/bg_abyss_core_warzone.png';
      case 'yeralti':
        return 'assets/images/backgrounds/dungeons/bg_beshmundir_crypt.png';
      default:
        return 'assets/images/backgrounds/asmodae/bg_asmodae_skybox.png';
    }
  }

  static String _tierLabelForType(String typeKey) {
    switch (typeKey) {
      case 'bar':
        return 'TİCARİ • TIER I';
      case 'kahvehane':
        return 'SOSYAL • TIER II';
      case 'dovus_kulubu':
        return 'GLADYATÖR • TIER III';
      case 'luks_lounge':
        return 'VIP ELITE • TIER IV';
      case 'yeralti':
        return 'KARABORSA • TIER V';
      default:
        return 'MEKAN';
    }
  }

  static String _perkDescriptionForType(String typeKey) {
    switch (typeKey) {
      case 'bar':
        return 'İksir Ticareti • Sosyal Ortam';
      case 'kahvehane':
        return 'Buff İksirleri • Toksin Arınma';
      case 'dovus_kulubu':
        return 'PvP Bahisleri • Gladyatör Şanı';
      case 'luks_lounge':
        return 'VIP Müşteri Portföyü • Yüksek Gelir';
      case 'yeralti':
        return 'Kaçak İksir Pazarı • Zirve Kâr';
      default:
        return 'Özel Mekan İşletmesi';
    }
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    if (widget.locked) {
      widget.onLockedTap?.call();
    } else {
      widget.onTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = MekanPalette.accent(widget.info.type);
    final String backdropAsset = _backdropForType(widget.info.type);
    final String tierLabel = _tierLabelForType(widget.info.type);
    final String perkDesc = _perkDescriptionForType(widget.info.type);
    final bool hasPvp = mekanSupportsPvp(widget.info.type);

    final Color borderColor = widget.selected
        ? accent
        : _isHovered
            ? accent.withValues(alpha: 0.70)
            : widget.locked
                ? MekanPalette.ruby.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.14);

    final double borderWidth = widget.selected ? 2.0 : (_isHovered ? 1.5 : 1.2);

    final List<BoxShadow> cardShadows = widget.selected
        ? <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: 0.42),
              blurRadius: 26,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.60),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ]
        : _isHovered
            ? <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.28),
                  blurRadius: 18,
                  spreadRadius: -1,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.50),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ];

    final double currentScale = _isPressed ? 0.975 : (_isHovered ? 1.018 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: _handleTap,
        child: AnimatedScale(
          scale: currentScale,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: cardShadows,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: MekanPalette.void_.withValues(alpha: 0.92),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Color(0xEE1E2740),
                        Color(0xF0121826),
                        Color(0xFA080B12),
                      ],
                      stops: <double>[0.0, 0.45, 1.0],
                    ),
                  ),
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.25,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _buildHeroBackdrop(
                          context,
                          accent: accent,
                          backdropAsset: backdropAsset,
                          tierLabel: tierLabel,
                          hasPvp: hasPvp,
                        ),
                        _buildInfoSection(
                          context,
                          accent: accent,
                          perkDesc: perkDesc,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBackdrop(
    BuildContext context, {
    required Color accent,
    required String backdropAsset,
    required String tierLabel,
    required bool hasPvp,
  }) {
    return SizedBox(
      height: 116,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Atmospheric Scene Image Backdrop
          Image.asset(
            backdropAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      accent.withValues(alpha: 0.40),
                      MekanPalette.navy,
                      MekanPalette.void_,
                    ],
                  ),
                ),
              );
            },
          ),

          // Multi-Stage Atmospheric Scrim
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.60),
                  MekanPalette.void_.withValues(alpha: 0.96),
                ],
                stops: const <double>[0.0, 0.55, 1.0],
              ),
            ),
          ),

          // Radial Accent Bloom in Corner
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    accent.withValues(alpha: widget.selected ? 0.32 : 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Large Ambient Type Watermark Icon
          Positioned(
            right: -8,
            top: -8,
            child: Icon(
              MekanPalette.typeIcon(widget.info.type),
              size: 104,
              color: accent.withValues(alpha: 0.14),
            ),
          ),

          // Top Rim Specular Highlight
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Colors.transparent,
                    accent.withValues(alpha: 0.65),
                    Colors.white.withValues(alpha: 0.50),
                    accent.withValues(alpha: 0.65),
                    Colors.transparent,
                  ],
                  stops: const <double>[0.0, 0.25, 0.50, 0.75, 1.0],
                ),
              ),
            ),
          ),

          // Foreground Content: Header Ribbons & Hero Identity
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                // Top Row: Tier Ribbon & Status Badge
                Row(
                  children: <Widget>[
                    // Tier Ribbon
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: accent.withValues(alpha: 0.16),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.50),
                          width: 0.9,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: accent.withValues(alpha: 0.22),
                            blurRadius: 8,
                            spreadRadius: -1,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.diamond_outlined, size: 11, color: accent),
                          const SizedBox(width: 4),
                          Text(
                            tierLabel,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: accent,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),

                    // Selection / Locked Status Pill
                    if (widget.selected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            colors: <Color>[
                              accent.withValues(alpha: 0.35),
                              accent.withValues(alpha: 0.15),
                            ],
                          ),
                          border: Border.all(color: accent, width: 1.1),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: accent.withValues(alpha: 0.45),
                              blurRadius: 10,
                              spreadRadius: -1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.check_circle_rounded, size: 12, color: accent),
                            const SizedBox(width: 4),
                            Text(
                              'SEÇİLDİ',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: accent,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (widget.locked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: MekanPalette.ruby.withValues(alpha: 0.16),
                          border: Border.all(
                            color: MekanPalette.ruby.withValues(alpha: 0.50),
                            width: 0.9,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.lock_rounded, size: 11, color: MekanPalette.ruby),
                            SizedBox(width: 4),
                            Text(
                              'KİLİTLİ',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: MekanPalette.ruby,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: Colors.white.withValues(alpha: 0.08),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 0.9,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              'SEÇ',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: MekanPalette.textMid,
                                letterSpacing: 0.4,
                              ),
                            ),
                            SizedBox(width: 3),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 9,
                              color: MekanPalette.textMid,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // Hero Identity Row: Art Crest Badge & Title
                Row(
                  children: <Widget>[
                    _buildArtCrestBadge(accent: accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            widget.info.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: MekanPalette.textHi,
                              letterSpacing: 0.2,
                              shadows: <Shadow>[
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 8,
                                  offset: Offset(0, 1.5),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (hasPvp)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: MekanPalette.ruby.withValues(alpha: 0.18),
                                border: Border.all(
                                  color: MekanPalette.ruby.withValues(alpha: 0.45),
                                  width: 0.8,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.sports_mma_rounded,
                                    size: 11,
                                    color: MekanPalette.ruby,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'PvP Arena Destekli',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: MekanPalette.ruby,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            const Text(
                              'Standart Ticaret',
                              style: TextStyle(
                                fontSize: 11,
                                color: MekanPalette.textMid,
                                fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildArtCrestBadge({required Color accent}) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accent.withValues(alpha: 0.42),
            MekanPalette.navy.withValues(alpha: 0.88),
            accent.withValues(alpha: 0.15),
          ],
        ),
        border: Border.all(
          color: accent.withValues(alpha: widget.selected ? 0.85 : 0.45),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: widget.selected ? 0.36 : 0.18),
            blurRadius: 14,
            spreadRadius: -1,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.50),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        MekanPalette.typeIcon(widget.info.type),
        color: accent,
        size: 27,
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context, {
    required Color accent,
    required String perkDesc,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 13),
      decoration: BoxDecoration(
        color: MekanPalette.surface.withValues(alpha: 0.65),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Description
          Text(
            widget.info.description,
            style: const TextStyle(
              fontSize: 12.5,
              color: MekanPalette.textMid,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),

          // Perk Specialty Tag
          Padding(
            padding: const EdgeInsets.only(top: 7, bottom: 10),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 13,
                  color: accent.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    perkDesc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent.withValues(alpha: 0.90),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Requirement & Action Chips Row
          Row(
            children: <Widget>[
              GlowChip(
                icon: Icons.paid_rounded,
                label: '${formatMekanGold(widget.info.cost)} Altın',
                color: widget.affordable ? MekanPalette.gold : MekanPalette.ruby,
              ),
              const SizedBox(width: 8),
              GlowChip(
                icon: Icons.military_tech_rounded,
                label: 'Sv ${widget.info.reqLevel}',
                color: widget.levelOk ? MekanPalette.neon : MekanPalette.ruby,
              ),
              const Spacer(),
              if (!widget.locked)
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (widget.selected ? accent : MekanPalette.textLow)
                        .withValues(alpha: 0.14),
                    border: Border.all(
                      color: (widget.selected ? accent : MekanPalette.textLow)
                          .withValues(alpha: 0.35),
                      width: 0.9,
                    ),
                  ),
                  child: Icon(
                    widget.selected
                        ? Icons.check_rounded
                        : Icons.chevron_right_rounded,
                    size: 15,
                    color: widget.selected ? accent : MekanPalette.textMid,
                  ),
                ),
            ],
          ),

          // Locked Advisory Banner
          if (widget.locked) ...<Widget>[
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: MekanPalette.ruby.withValues(alpha: 0.12),
                border: Border.all(
                  color: MekanPalette.ruby.withValues(alpha: 0.40),
                  width: 0.9,
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: MekanPalette.ruby,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      !widget.levelOk && !widget.affordable
                          ? 'Gereksinim: Sv ${widget.info.reqLevel} ve ${formatMekanGold(widget.info.cost)} Altın'
                          : !widget.levelOk
                              ? 'Seviye Yetersiz: Sv ${widget.info.reqLevel} gerekli'
                              : 'Altın Yetersiz: ${formatMekanGold(widget.info.cost)} Altın gerekli',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: MekanPalette.ruby,
                        letterSpacing: 0.15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

