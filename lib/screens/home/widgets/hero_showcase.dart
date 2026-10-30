import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../core/engine/adaptive_quality_scaler.dart';
import '../../../core/services/app_foreground_service.dart';
import '../../../models/inventory_model.dart';
import '../../../models/player_model.dart';
import '../../../providers/inventory_provider.dart';
import '../../../theme/app_colors.dart';
import '../../settings/graphics_settings_service.dart';
import 'home_stat_badge.dart';
import 'hub_3d_viewport.dart';

/// 2027 AAA Studio V3 Hero Showcase Widget.
///
/// Features:
/// - Frosted obsidian glassmorphism equipment slots with specular highlights.
/// - AdaptiveQualityScaler integration (adjusting blur sigma dynamically).
/// - Multi-tier elliptical 3D pedestal dais with orbital runic glyphs.
/// - Dynamic volumetric back-glow with class-specific chromatic radiance.
/// - Interactive inspect shockwaves with tactile haptic feedback.
/// - Luxury MMORPG hero crest displaying level, class title, and cosmetic honors.
class HeroShowcase extends StatefulWidget {
  final PlayerProfile profile;
  final InventoryState inventoryState;
  final int totalPower;
  final int reputation;
  final void Function(String slotLabel, InventoryItem? item)? onSlotTap;
  final VoidCallback? onHeroTap;

  const HeroShowcase({
    super.key,
    required this.profile,
    required this.inventoryState,
    required this.totalPower,
    required this.reputation,
    this.onSlotTap,
    this.onHeroTap,
  });

  @override
  State<HeroShowcase> createState() => _HeroShowcaseState();
}

class _HeroShowcaseState extends State<HeroShowcase>
    with TickerProviderStateMixin, LifecycleAnimationPause {
  late AnimationController _breathingController;
  late AnimationController _pulseController;

  @override
  AnimationController? get lifecycleAnimationController => _breathingController;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (AppForegroundService.instance.isForeground) {
      _breathingController.repeat(reverse: true);
    }
    attachLifecycleAnimationPause();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    detachLifecycleAnimationPause();
    _pulseController.dispose();
    _breathingController.dispose();
    super.dispose();
  }

  void _handleHeroTap() {
    HapticFeedback.lightImpact();
    _pulseController.forward(from: 0.0);
    widget.onHeroTap?.call();
  }

  static const List<({String key, String label, IconData icon, String watermarkAsset})> _equipSlots = [
    (key: 'weapon', label: 'Silah', icon: Icons.sports_martial_arts_rounded, watermarkAsset: 'assets/images/icons/weapons/weapon_sun_blade.png'),
    (key: 'head', label: 'Kask', icon: Icons.shield_moon_outlined, watermarkAsset: 'assets/images/icons/armor/armor_abyssal_dread_helm.png'),
    (key: 'chest', label: 'Zırh', icon: Icons.shield_outlined, watermarkAsset: 'assets/images/icons/armor/armor_empyrean_plate_chest.png'),
    (key: 'gloves', label: 'Eldiven', icon: Icons.back_hand_outlined, watermarkAsset: 'assets/images/icons/armor/armor_draconic_gauntlets.png'),
    (key: 'legs', label: 'Bacak', icon: Icons.accessibility_new_rounded, watermarkAsset: 'assets/images/icons/armor/armor_paladin_greaves.png'),
    (key: 'boots', label: 'Bot', icon: Icons.hiking_outlined, watermarkAsset: 'assets/images/icons/armor/armor_boots_of_wind.png'),
    (key: 'necklace', label: 'Aksesuar', icon: Icons.diamond_outlined, watermarkAsset: 'assets/images/icons/armor/armor_tiamat_blood_necklace.png'),
    (key: 'ring', label: 'Yüzük', icon: Icons.circle_outlined, watermarkAsset: 'assets/images/icons/armor/armor_godstone_ring.png'),
  ];

  Color _resolveAuraPrimary(CharacterClass? characterClass) {
    switch (characterClass) {
      case CharacterClass.warrior:
      case null:
        return const Color(0xFF00B4FF);
      case CharacterClass.shadow:
        return const Color(0xFFA855F7);
      case CharacterClass.alchemist:
        return const Color(0xFFFFB800);
    }
  }

  Color _resolveAuraSecondary(CharacterClass? characterClass) {
    switch (characterClass) {
      case CharacterClass.warrior:
      case null:
        return const Color(0xFF4A80D4);
      case CharacterClass.shadow:
        return const Color(0xFF6366F1);
      case CharacterClass.alchemist:
        return const Color(0xFFE52E2E);
    }
  }

  String _resolveClassTitle(CharacterClass? characterClass) {
    switch (characterClass) {
      case CharacterClass.warrior:
      case null:
        return 'SAVAŞÇI';
      case CharacterClass.shadow:
        return 'GÖLGE';
      case CharacterClass.alchemist:
        return 'SİMYACI';
    }
  }

  IconData _resolveClassIcon(CharacterClass? characterClass) {
    switch (characterClass) {
      case CharacterClass.warrior:
      case null:
        return Icons.military_tech_rounded;
      case CharacterClass.shadow:
        return Icons.nights_stay_rounded;
      case CharacterClass.alchemist:
        return Icons.science_rounded;
    }
  }

  double _resolveBlurSigma() {
    try {
      final HardwareTier tier =
          GraphicsSettingsService.instance.scaler.currentTier;
      if (tier == HardwareTier.eco || tier == HardwareTier.low) {
        return 5.0;
      }
    } catch (_) {
      // Graceful fallback for tests/unwired service
    }
    return 12.0;
  }


  @override
  Widget build(BuildContext context) {
    final List<({String key, String label, IconData icon, String watermarkAsset})> leftSlots =
        _equipSlots.sublist(0, 4);
    final List<({String key, String label, IconData icon, String watermarkAsset})> rightSlots =
        _equipSlots.sublist(4, 8);
    final double blurSigma = _resolveBlurSigma();

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Responsive height adapted for 390x844 base while safely capping extremes
          final double maxWidth = constraints.maxWidth;
          final double showcaseHeight = (maxWidth * 1.05).clamp(320.0, 440.0);

          // Dynamic slot scale for 390x844 layout standard (no vertical collision)
          final double slotSize = (showcaseHeight * 0.126).clamp(46.0, 54.0);
          final double slotSpacing = (showcaseHeight * 0.016).clamp(5.0, 8.0);
          final double totalSlotsHeight = (slotSize * 4) + (slotSpacing * 3);
          final double slotTop =
              ((showcaseHeight - totalSlotsHeight) * 0.44).clamp(56.0, 68.0);

          // Pedestal & aura bounds
          final double daisWidth = (showcaseHeight * 0.74).clamp(240.0, 320.0);
          final double auraSize = (showcaseHeight * 0.70).clamp(220.0, 290.0);
          final Color auraPrimary = _resolveAuraPrimary(widget.profile.characterClass);
          final Color auraSecondary = _resolveAuraSecondary(widget.profile.characterClass);

          return SizedBox(
            height: showcaseHeight,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // ── 3D Pedestal Dais & Volumetric Back-Glow ──
                Positioned(
                  bottom: 22,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_breathingController, _pulseController]),
                    builder: (context, child) {
                      return CustomPaint(
                        size: Size(daisWidth, 52),
                        painter: _HeroDaisPainter(
                          breathingValue: _breathingController.value,
                          inspectPulse: _pulseController.value,
                          accentColor: auraPrimary,
                          secondaryColor: auraSecondary,
                        ),
                      );
                    },
                  ),
                ),
                // ── Dynamic Volumetric Radiance Aura ──
                AnimatedBuilder(
                  animation: Listenable.merge([_breathingController, _pulseController]),
                  builder: (context, child) {
                    final double auraScale = 1.0 +
                        (_breathingController.value * 0.06) +
                        (_pulseController.value * 0.10);
                    final double auraAlpha =
                        (0.22 + (_pulseController.value * 0.16)).clamp(0.0, 1.0);

                    return Transform.scale(
                      scale: auraScale,
                      child: Container(
                        width: auraSize,
                        height: auraSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              auraPrimary.withValues(alpha: auraAlpha),
                              auraSecondary.withValues(alpha: auraAlpha * 0.45),
                              Colors.transparent,
                            ],
                            stops: const [0.12, 0.52, 1.0],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // ── 3D Hero Viewport (Khronos .glb or High-Res Fallback) ──
                AnimatedBuilder(
                  animation: Listenable.merge([_breathingController, _pulseController]),
                  builder: (context, child) {
                    String imageAsset = 'assets/renders/characters/Knight_beauty.png';
                    if (widget.profile.characterClass == CharacterClass.shadow) {
                      imageAsset = 'assets/renders/characters/Soldier_beauty.png';
                    } else if (widget.profile.characterClass == CharacterClass.alchemist) {
                      imageAsset = 'assets/renders/characters/Mage_beauty.png';
                    }

                    final double pulseScale =
                        1.0 + (_pulseController.value * 0.04);

                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _handleHeroTap,
                      child: Transform.scale(
                        scale: pulseScale,
                        child: Hero3dGlbViewport(
                          characterClass: widget.profile.characterClass,
                          breathingValue: _breathingController.value,
                          height: showcaseHeight * 0.78,
                          fallbackAsset: imageAsset,
                        ),
                      ),
                    );
                  },
                ),
                // ── Left Equipment Slots ──
                Positioned(
                  left: 8,
                  top: slotTop,
                  child: Column(
                    children: leftSlots.map((slot) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: slotSpacing),
                        child: _buildEquipSlot(
                          equipped: widget.inventoryState.equippedItems[slot.key],
                          fallbackIcon: slot.icon,
                          watermarkAsset: slot.watermarkAsset,
                          type: slot.label,
                          size: slotSize,
                          blurSigma: blurSigma,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // ── Right Equipment Slots ──
                Positioned(
                  right: 8,
                  top: slotTop,
                  child: Column(
                    children: rightSlots.map((slot) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: slotSpacing),
                        child: _buildEquipSlot(
                          equipped: widget.inventoryState.equippedItems[slot.key],
                          fallbackIcon: slot.icon,
                          watermarkAsset: slot.watermarkAsset,
                          type: slot.label,
                          size: slotSize,
                          blurSigma: blurSigma,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // ── Aion 2 Hero Crest & Level Badge ──
                Positioned(
                  bottom: 12,
                  child: _buildHeroCrest(widget.profile, blurSigma),
                ),
                // ── Top Neon Stat Badges ──
                Positioned(
                  top: 6,
                  left: 8,
                  child: HomeStatBadge.power(
                    value: _compact(widget.totalPower),
                    compact: true,
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 8,
                  child: HomeStatBadge.reputation(
                    reputation: widget.reputation,
                    compact: true,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _compact(int value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    }
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }

  Widget _buildHeroCrest(PlayerProfile profile, double blurSigma) {
    const Color gold = AppColors.liquidGold;
    final String classTitle = _resolveClassTitle(profile.characterClass);
    final IconData classIcon = _resolveClassIcon(profile.characterClass);
    final String? cosmeticTitle = profile.cosmeticTitle ?? profile.title;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  AppColors.spaceNavy.withValues(alpha: 0.94),
                  AppColors.carbonVoid.withValues(alpha: 0.98),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: gold.withValues(alpha: 0.70),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: gold.withValues(alpha: 0.28),
                  blurRadius: 14,
                  spreadRadius: -1,
                  offset: const Offset(0, 2),
                ),
                const BoxShadow(
                  color: Colors.black87,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Specular top highlight line
                Positioned(
                  top: 0,
                  left: 10,
                  right: 10,
                  height: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        classIcon,
                        size: 15,
                        color: gold,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        classTitle,
                        style: GoogleFonts.urbanist(
                          color: gold,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                          shadows: <Shadow>[
                            Shadow(
                              color: gold.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5.0),
                        child: Text(
                          '·',
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        'LVL ${profile.level}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.urbanist(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          shadows: const <Shadow>[
                            Shadow(color: Colors.black87, blurRadius: 4),
                          ],
                        ),
                      ),
                      if (cosmeticTitle != null && cosmeticTitle.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: gold.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            cosmeticTitle,
                            style: GoogleFonts.urbanist(
                              color: gold,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEquipSlot({
    required InventoryItem? equipped,
    required IconData fallbackIcon,
    required String watermarkAsset,
    required String type,
    required double size,
    required double blurSigma,
  }) {
    return _EquipSlotCard(
      equipped: equipped,
      fallbackIcon: fallbackIcon,
      watermarkAsset: watermarkAsset,
      type: type,
      size: size,
      blurSigma: blurSigma,
      onTap: () {
        if (equipped == null) {
          HapticFeedback.selectionClick();
        } else {
          HapticFeedback.lightImpact();
        }
        widget.onSlotTap?.call(type, equipped);
      },
    );
  }
}

/// 2027 AAA Frosted Glassmorphism Equipment Slot with interactive touch bounce.
class _EquipSlotCard extends StatefulWidget {
  const _EquipSlotCard({
    required this.equipped,
    required this.fallbackIcon,
    required this.watermarkAsset,
    required this.type,
    required this.size,
    required this.blurSigma,
    required this.onTap,
  });

  final InventoryItem? equipped;
  final IconData fallbackIcon;
  final String watermarkAsset;
  final String type;
  final double size;
  final double blurSigma;
  final VoidCallback onTap;

  @override
  State<_EquipSlotCard> createState() => _EquipSlotCardState();
}

class _EquipSlotCardState extends State<_EquipSlotCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final InventoryItem? equipped = widget.equipped;
    final bool isEmpty = equipped == null;
    final Color rarityColor = isEmpty
        ? const Color(0x4D60A5FA)
        : AppColors.forRarity(equipped.rarity.name);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: widget.blurSigma,
              sigmaY: widget.blurSigma,
            ),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isEmpty
                      ? <Color>[
                          const Color(0xCC0D1424),
                          const Color(0xD9060A14),
                        ]
                      : <Color>[
                          const Color(0xDD141D2E),
                          const Color(0xF0080E1A),
                        ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isEmpty
                      ? const Color(0x3360A5FA)
                      : rarityColor.withValues(alpha: 0.85),
                  width: isEmpty ? 1.0 : 1.4,
                ),
                boxShadow: <BoxShadow>[
                  if (!isEmpty)
                    BoxShadow(
                      color: rarityColor.withValues(alpha: 0.38),
                      blurRadius: 12,
                      spreadRadius: -1,
                    ),
                  const BoxShadow(
                    color: Colors.black87,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Specular top highlight reflection
                  Positioned(
                    top: 0,
                    left: 4,
                    right: 4,
                    height: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Colors.transparent,
                            Colors.white.withValues(alpha: isEmpty ? 0.16 : 0.28),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (isEmpty)
                    Center(
                      child: Image.asset(
                        widget.watermarkAsset,
                        width: (widget.size * 0.65).clamp(24.0, 32.0),
                        height: (widget.size * 0.65).clamp(24.0, 32.0),
                        fit: BoxFit.contain,
                        color: const Color(0x608A9BBE),
                        colorBlendMode: BlendMode.srcIn,
                        errorBuilder: (_, __, ___) => Icon(
                          widget.fallbackIcon,
                          size: (widget.size * 0.44).clamp(18.0, 22.0),
                          color: const Color(0x738A9BBE),
                        ),
                      ),
                    )
                  else ...[
                    Positioned.fill(
                      child: Tooltip(
                        message: '${widget.type}: ${equipped.name}',
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: ItemIconView(
                              iconValue: equipped.icon,
                              itemId: equipped.itemId,
                              itemType: equipped.itemType,
                              size: widget.size - 8,
                              expand: true,
                              fallback: '◻',
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (equipped.enhancementLevel > 0)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4.5,
                            vertical: 1.2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.carbonVoid.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.liquidGold.withValues(alpha: 0.85),
                              width: 0.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.7),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            '+${equipped.enhancementLevel}',
                            style: GoogleFonts.urbanist(
                              color: AppColors.liquidGold,
                              fontSize: 9.0,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CustomPainter rendering an elliptical 3D pedestal dais at hero's feet (Aion-2 mobile standard).
class _HeroDaisPainter extends CustomPainter {
  const _HeroDaisPainter({
    required this.breathingValue,
    this.inspectPulse = 0.0,
    this.accentColor = const Color(0xFF00B4FF),
    this.secondaryColor = const Color(0xFF4A80D4),
  });

  final double breathingValue;
  final double inspectPulse;
  final Color accentColor;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.5;
    final double cy = size.height * 0.55;
    final double rx = size.width * 0.46;
    final double ry = size.height * 0.38;

    // Layer 1: Soft ambient floor shadow
    final Paint ambientShadow = Paint()
      ..color = const Color(0x99000000)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 16.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + 10),
        width: rx * 2.2,
        height: ry * 2.05,
      ),
      ambientShadow,
    );

    // Layer 2: Deep contact occlusion shadow
    final Paint contactShadow = Paint()
      ..color = const Color(0xDD000000)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + 5),
        width: rx * 1.9,
        height: ry * 1.7,
      ),
      contactShadow,
    );

    // Dais stone base bevel with multi-tone metallic linear gradient
    final Paint stoneBasePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx, cy - ry),
        Offset(cx, cy + ry),
        <Color>[
          const Color(0xFF2E3D5C),
          const Color(0xFF182236),
          const Color(0xFF0C121E),
        ],
        <double>[0.0, 0.48, 1.0],
      );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      stoneBasePaint,
    );

    // Specular metallic highlight curve on the top rim
    final Paint specularRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = ui.Gradient.linear(
        Offset(cx - rx, cy - ry),
        Offset(cx + rx, cy - ry),
        <Color>[
          Colors.transparent,
          Colors.white.withValues(alpha: 0.30),
          accentColor.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.30),
          Colors.transparent,
        ],
        const <double>[0.0, 0.25, 0.5, 0.75, 1.0],
      );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy - 0.5),
        width: rx * 1.98,
        height: ry * 1.98,
      ),
      specularRimPaint,
    );

    // Outer luminous energy boundary rim with breathing pulse
    final double outerRimAlpha =
        ((0.45 + breathingValue * 0.35) + (inspectPulse * 0.35)).clamp(0.0, 1.0);
    final Paint outerRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 + (inspectPulse * 0.8)
      ..color = accentColor.withValues(alpha: outerRimAlpha);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      outerRimPaint,
    );

    // Middle runic circuit ring
    final Paint runicRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = accentColor.withValues(
        alpha: (0.30 + breathingValue * 0.25).clamp(0.0, 1.0),
      );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 1.72, height: ry * 1.72),
      runicRingPaint,
    );

    // Inner transmutation core disc with multi-stop sweep gradient
    final Paint innerCorePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = ui.Gradient.sweep(
        Offset(cx, cy),
        <Color>[
          accentColor.withValues(alpha: 0.15),
          secondaryColor.withValues(
            alpha: (0.55 + breathingValue * 0.35).clamp(0.0, 1.0),
          ),
          accentColor.withValues(alpha: 0.85),
          secondaryColor.withValues(alpha: 0.25),
          accentColor.withValues(alpha: 0.15),
        ],
        const <double>[0.0, 0.25, 0.5, 0.75, 1.0],
      );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 1.44, height: ry * 1.44),
      innerCorePaint,
    );

    // Dynamic rotating arcane glyph tick marks along dais perimeter
    final double rotationOffset = (breathingValue * 0.35) * (math.pi / 4);
    final Paint tickPaint = Paint()
      ..color = AppColors.liquidGold.withValues(
        alpha: (0.38 + breathingValue * 0.32).clamp(0.0, 1.0),
      )
      ..strokeWidth = 1.3;

    const int numTicks = 12;
    for (int i = 0; i < numTicks; i++) {
      final double angle = rotationOffset + (i * 2 * math.pi) / numTicks;
      final double cosA = math.cos(angle);
      final double sinA = math.sin(angle);
      final Offset p1 = Offset(cx + rx * 0.86 * cosA, cy + ry * 0.86 * sinA);
      final Offset p2 = Offset(cx + rx * 0.98 * cosA, cy + ry * 0.98 * sinA);
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Inspect shockwave ripple on tap
    if (inspectPulse > 0.001) {
      // Primary expanding shockwave
      final double rippleScale1 = 1.0 + (inspectPulse * 0.42);
      final double rippleAlpha1 = ((1.0 - inspectPulse) * 0.75).clamp(0.0, 1.0);
      final Paint ripplePaint1 = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * (1.0 - inspectPulse)
        ..color = accentColor.withValues(alpha: rippleAlpha1);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: rx * 2 * rippleScale1,
          height: ry * 2 * rippleScale1,
        ),
        ripplePaint1,
      );

      // Secondary trailing harmonic ripple
      if (inspectPulse > 0.12) {
        final double harmonicProg = (inspectPulse - 0.12) / 0.88;
        final double rippleScale2 = 1.0 + (harmonicProg * 0.28);
        final double rippleAlpha2 = ((1.0 - harmonicProg) * 0.48).clamp(0.0, 1.0);
        final Paint ripplePaint2 = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 * (1.0 - harmonicProg)
          ..color = secondaryColor.withValues(alpha: rippleAlpha2);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: rx * 1.6 * rippleScale2,
            height: ry * 1.6 * rippleScale2,
          ),
          ripplePaint2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeroDaisPainter oldDelegate) =>
      oldDelegate.breathingValue != breathingValue ||
      oldDelegate.inspectPulse != inspectPulse ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.secondaryColor != secondaryColor;
}

