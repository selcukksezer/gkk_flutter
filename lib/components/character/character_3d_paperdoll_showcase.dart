import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/graphics_quality_service.dart';
import '../../models/inventory_model.dart';
import '../../models/item_model.dart';
import '../../models/moradon_models.dart';
import '../../models/player_model.dart';
import '../../providers/inventory_provider.dart';
import '../../screens/home/moradon/character_skeletal_rig.dart';
import '../../theme/app_colors.dart';
import '../common/holo_foil_sheen.dart';
import '../common/item_icon_view.dart';

/// Live 3D Character Pedestal & Equipped Paperdoll Showcase for [CharacterScreen].
///
/// Reuses [GraphicsQualityService.loadSharedCharacterAtlases] so zero extra
/// RGBA textures are allocated, supports interactive 3D drag-tilt, 3-hit class
/// combo preview (`⚔️ Kombo`), and `+7/+8/+9/+10` prestige aura preview!
class Character3dPaperdollShowcase extends ConsumerStatefulWidget {
  const Character3dPaperdollShowcase({
    super.key = const Key('character_3d_paperdoll_showcase'),
    required this.profile,
  });

  final PlayerProfile? profile;

  @visibleForTesting
  static bool debugAnimateInTests = false;

  @override
  ConsumerState<Character3dPaperdollShowcase> createState() =>
      _Character3dPaperdollShowcaseState();
}

class _Character3dPaperdollShowcaseState
    extends ConsumerState<Character3dPaperdollShowcase>
    with TickerProviderStateMixin {
  Map<String, ui.Image> _atlases = const <String, ui.Image>{};
  AnimationController? _idleCtrl;
  AnimationController? _comboCtrl;
  int _comboStage = 0;
  int? _previewEnhancementOverride;
  double _yawRad = 0.0;
  bool _facingRight = true;

  static bool get _isTestBinding {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    GraphicsQualityService.instance.addListener(_onGfxChanged);
    _loadAtlases();
    _syncIdleTicker();
  }

  Future<void> _loadAtlases() async {
    final Map<String, ui.Image> loaded =
        await GraphicsQualityService.instance.loadSharedCharacterAtlases();
    if (mounted) {
      setState(() => _atlases = loaded);
    }
  }

  void _onGfxChanged() {
    _loadAtlases();
    _syncIdleTicker();
    if (mounted) setState(() {});
  }

  void _syncIdleTicker() {
    final bool shouldTick =
        !GraphicsQualityService.instance.profile.isLow &&
        (!_isTestBinding || Character3dPaperdollShowcase.debugAnimateInTests);
    if (shouldTick) {
      _idleCtrl ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2800),
      );
      if (!_idleCtrl!.isAnimating) {
        _idleCtrl!.repeat();
      }
    } else {
      _idleCtrl?.stop();
    }
  }

  void _triggerComboPreview() {
    _comboCtrl ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    setState(() {
      _comboStage = (_comboStage + 1) % 3;
    });
    _comboCtrl!.forward(from: 0.0);
  }

  @override
  void dispose() {
    GraphicsQualityService.instance.removeListener(_onGfxChanged);
    _idleCtrl?.dispose();
    _comboCtrl?.dispose();
    super.dispose();
  }

  String _resolveClassKey() => switch (widget.profile?.characterClass) {
        CharacterClass.shadow => 'golge',
        CharacterClass.alchemist => 'simyaci',
        _ => 'savasci',
      };

  MoradonWeaponVisual _resolveWeaponVisual(
    String classKey,
    InventoryItem? weapon,
  ) {
    if (weapon != null) {
      return switch (weapon.weaponType) {
        WeaponType.axe => MoradonWeaponVisual.crimsonAxe,
        WeaponType.staff => MoradonWeaponVisual.aetherStaff,
        WeaponType.dagger => MoradonWeaponVisual.twilightFang,
        WeaponType.sword => MoradonWeaponVisual.illusionSabre,
        _ => classKey == 'golge'
            ? MoradonWeaponVisual.twilightFang
            : (classKey == 'simyaci'
                  ? MoradonWeaponVisual.aetherStaff
                  : MoradonWeaponVisual.illusionSabre),
      };
    }
    return switch (classKey) {
      'golge' => MoradonWeaponVisual.twilightFang,
      'simyaci' => MoradonWeaponVisual.aetherStaff,
      _ => MoradonWeaponVisual.illusionSabre,
    };
  }

  Color _resolveGlowColor(int enhLevel, String classKey) {
    if (enhLevel >= 10) return const Color(0xFFEA580C);
    if (enhLevel >= 9) return const Color(0xFFF59E0B);
    if (enhLevel >= 8) return const Color(0xFFD97706);
    if (enhLevel >= 7) return const Color(0xFF93C5FD);
    return switch (classKey) {
      'golge' => const Color(0xFFB36BFF),
      'simyaci' => const Color(0xFF34D399),
      _ => AppColors.liquidGold,
    };
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, InventoryItem?> equipped =
        ref.watch(inventoryProvider).equippedItems;
    final GraphicsProfile gfx = GraphicsQualityService.instance.profile;
    final String classKey = _resolveClassKey();
    final ui.Image? atlas = _atlases[classKey];

    int realMaxEnh = 0;
    for (final InventoryItem? it in equipped.values) {
      if (it != null && it.enhancementLevel > realMaxEnh) {
        realMaxEnh = it.enhancementLevel;
      }
    }
    final int activeEnh = _previewEnhancementOverride ?? realMaxEnh;
    final Color glowColor = _resolveGlowColor(activeEnh, classKey);
    final MoradonWeaponVisual weaponVis = _resolveWeaponVisual(
      classKey,
      equipped['weapon'],
    );

    final Listenable mergedTick = Listenable.merge(<Listenable?>[
      _idleCtrl,
      _comboCtrl,
    ]);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF141B2D),
            Color(0xFF0B101D),
            Color(0xFF161224),
          ],
        ),
        border: Border.all(
          color: glowColor.withValues(alpha: activeEnh >= 7 ? 0.55 : 0.28),
          width: activeEnh >= 9 ? 1.5 : 1.0,
        ),
        boxShadow: gfx.enableHeavyShadows
            ? <BoxShadow>[
                BoxShadow(
                  color: glowColor.withValues(alpha: activeEnh >= 8 ? 0.20 : 0.08),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Header bar + Combo Strike Preview button
          Row(
            children: <Widget>[
              Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: glowColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  activeEnh >= 7
                      ? 'CANLI KARAKTER PODYUMU • +$activeEnh PRESTİJ AURA'
                      : 'CANLI KARAKTER PODYUMU • EKİPMAN VİTRİNİ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              InkWell(
                key: const Key('character_combo_preview_btn'),
                onTap: _triggerComboPreview,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: glowColor.withValues(alpha: 0.16),
                    border: Border.all(color: glowColor.withValues(alpha: 0.55)),
                  ),
                  child: const Text(
                    '⚔️ Kombo Önizle',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 3-Column Paperdoll Stage: Left Gear | 3D Hero Pedestal | Right Gear
          SizedBox(
            height: 204,
            child: Row(
              children: <Widget>[
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _buildSlotTile('head', 'Miğfer', '🪖', equipped['head']),
                    _buildSlotTile('chest', 'Zırh', '🛡️', equipped['chest']),
                    _buildSlotTile('gloves', 'Eldiven', '🧤', equipped['gloves']),
                  ],
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (DragUpdateDetails d) {
                      setState(() {
                        _yawRad = (_yawRad + d.delta.dx * 0.012).clamp(
                          -0.38,
                          0.38,
                        );
                        if (d.delta.dx.abs() > 1.8) {
                          _facingRight = d.delta.dx >= 0;
                        }
                      });
                    },
                    onDoubleTap: () {
                      setState(() {
                        _yawRad = 0.0;
                        _facingRight = !_facingRight;
                      });
                    },
                    child: AnimatedBuilder(
                      animation: mergedTick,
                      builder: (BuildContext context, _) {
                        final double idlePhase = _idleCtrl?.value ?? 0.25;
                        final double atkT =
                            (_comboCtrl != null && _comboCtrl!.isAnimating)
                                ? _comboCtrl!.value
                                : 0.0;
                        final Matrix4 tilt = Matrix4.identity();
                        if (gfx.enable3dPerspective && _yawRad.abs() > 0.002) {
                          tilt
                            ..setEntry(3, 2, 0.0014)
                            ..rotateY(_yawRad);
                        }
                        return Transform(
                          alignment: Alignment.center,
                          transform: tilt,
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _PedestalFloorPainter(
                                    glowColor: glowColor,
                                    enhLevel: activeEnh,
                                    phase: idlePhase,
                                    isLowTier: gfx.isLow,
                                  ),
                                ),
                              ),
                              if (atlas != null)
                                SizedBox(
                                  width: 152,
                                  height: 178,
                                  child: CustomPaint(
                                    key: const ValueKey<String>(
                                      'paperdoll_hero_rig_paint',
                                    ),
                                    painter: _PaperdollHeroRigPainter(
                                      atlas: atlas,
                                      classKey: classKey,
                                      facingRight: _facingRight,
                                      idlePhase: idlePhase,
                                      glowColor: glowColor,
                                      glowLevel: activeEnh,
                                      weaponVisual: weaponVis,
                                      attackProgress: atkT,
                                      comboStage: _comboStage,
                                    ),
                                  ),
                                )
                              else
                                Icon(
                                  Icons.shield_rounded,
                                  size: 64,
                                  color: glowColor.withValues(alpha: 0.65),
                                ),
                              Positioned(
                                bottom: 2,
                                child: Text(
                                  '↔ Sürükle / Çift Dokun Döndür',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.42),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _buildSlotTile('weapon', 'Silah', '⚔️', equipped['weapon']),
                    _buildSlotTile('legs', 'Pantolon', '🦵', equipped['legs']),
                    _buildSlotTile('boots', 'Çizme', '🥾', equipped['boots']),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Prestige Aura Preview Selector (Gerçek / +7 / +8 / +9 / +10)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                Text(
                  'Aura Görünümü:',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                _buildAuraChip(null, 'Kuşanılan (+$realMaxEnh)'),
                _buildAuraChip(7, '+7 Yıldız'),
                _buildAuraChip(8, '+8 Yıldırım'),
                _buildAuraChip(9, '+9 Kor Alev'),
                _buildAuraChip(10, '+10 Hükümdar'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuraChip(int? value, String label) {
    final bool selected = _previewEnhancementOverride == value;
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: InkWell(
        key: ValueKey<String>('paperdoll_aura_chip_${value ?? "real"}'),
        onTap: () => setState(() => _previewEnhancementOverride = value),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected
                ? AppColors.liquidGold.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: selected
                  ? AppColors.liquidGold
                  : Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.liquidGold : Colors.white70,
              fontSize: 10,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlotTile(
    String slotKey,
    String slotLabel,
    String emptyEmoji,
    InventoryItem? item,
  ) {
    final Rarity rarity = item?.rarity ?? Rarity.common;
    final int enh = item?.enhancementLevel ?? 0;
    final Color borderCol = item != null
        ? getRarityColor(rarity).withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.12);

    final Widget box = Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFF0E1422),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: borderCol,
          width: enh >= 8 ? 1.5 : 1.0,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (item != null)
            Padding(
              padding: const EdgeInsets.all(7),
              child: ItemIconView(
                iconValue: item.icon,
                itemId: item.itemId,
                itemType: item.itemType,
                size: 36,
              ),
            )
          else
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  emptyEmoji,
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                Text(
                  slotLabel,
                  style: TextStyle(
                    fontSize: 8.5,
                    color: Colors.white.withValues(alpha: 0.38),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          if (enh > 0)
            Positioned(
              top: 3,
              right: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: borderCol.withValues(alpha: 0.8),
                    width: 0.7,
                  ),
                ),
                child: Text(
                  '+$enh',
                  style: const TextStyle(
                    color: AppColors.liquidGold,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (item == null) return box;
    return HoloFoilRarityBox(
      rarity: rarity,
      enhancementLevel: enh,
      borderRadius: BorderRadius.circular(11),
      child: box,
    );
  }
}

class _PedestalFloorPainter extends CustomPainter {
  const _PedestalFloorPainter({
    required this.glowColor,
    required this.enhLevel,
    required this.phase,
    required this.isLowTier,
  });

  final Color glowColor;
  final int enhLevel;
  final double phase;
  final bool isLowTier;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.5;
    final double cy = size.height * 0.84;

    // Spotlight cone from ceiling onto character
    if (!isLowTier) {
      final Path cone = Path()
        ..moveTo(cx - 26, 0)
        ..lineTo(cx + 26, 0)
        ..lineTo(cx + 68, cy)
        ..lineTo(cx - 68, cy)
        ..close();
      canvas.drawPath(
        cone,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              glowColor.withValues(alpha: 0.14),
              glowColor.withValues(alpha: 0.04),
              Colors.transparent,
            ],
          ).createShader(Offset.zero & size),
      );
    }

    // Obsidian stone dais
    final Rect outerStone = Rect.fromCenter(
      center: Offset(cx, cy + 5),
      width: 136,
      height: 34,
    );
    canvas.drawOval(
      outerStone,
      Paint()..color = const Color(0xFF1A2236),
    );
    final Rect topStone = Rect.fromCenter(
      center: Offset(cx, cy),
      width: 128,
      height: 28,
    );
    canvas.drawOval(
      topStone,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            glowColor.withValues(alpha: enhLevel >= 7 ? 0.34 : 0.18),
            const Color(0xFF151C2E),
          ],
        ).createShader(topStone),
    );
    canvas.drawOval(
      topStone,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = glowColor.withValues(
          alpha: 0.45 + 0.15 * math.sin(phase * math.pi * 2),
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _PedestalFloorPainter oldDelegate) {
    return (oldDelegate.phase - phase).abs() > 0.008 ||
        oldDelegate.enhLevel != enhLevel ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.isLowTier != isLowTier;
  }
}

class _PaperdollHeroRigPainter extends CustomPainter {
  const _PaperdollHeroRigPainter({
    required this.atlas,
    required this.classKey,
    required this.facingRight,
    required this.idlePhase,
    required this.glowColor,
    required this.glowLevel,
    required this.weaponVisual,
    required this.attackProgress,
    required this.comboStage,
  });

  final ui.Image atlas;
  final String classKey;
  final bool facingRight;
  final double idlePhase;
  final Color glowColor;
  final int glowLevel;
  final MoradonWeaponVisual weaponVisual;
  final double attackProgress;
  final int comboStage;

  @override
  void paint(Canvas canvas, Size size) {
    paintSegmentedCharacterRig(
      canvas: canvas,
      size: size,
      atlas: atlas,
      classKey: classKey,
      facingRight: facingRight,
      facingBack: false,
      isMoving: false,
      walkPhase: 0.0,
      idlePhase: idlePhase,
      glowColor: glowColor,
      glowLevel: glowLevel,
      weaponVisual: weaponVisual,
      attackProgress: attackProgress,
      comboStage: comboStage,
    );
  }

  @override
  bool shouldRepaint(covariant _PaperdollHeroRigPainter oldDelegate) {
    return (oldDelegate.idlePhase - idlePhase).abs() > 0.004 ||
        (oldDelegate.attackProgress - attackProgress).abs() > 0.004 ||
        oldDelegate.glowLevel != glowLevel ||
        oldDelegate.facingRight != facingRight ||
        oldDelegate.atlas != atlas ||
        oldDelegate.comboStage != comboStage;
  }
}
