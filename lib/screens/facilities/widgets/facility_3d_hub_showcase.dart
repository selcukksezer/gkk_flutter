import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/facility_model.dart';
import '../../../theme/app_colors.dart';
import 'facilities_ui.dart';
import 'facility_3d_model_resolver.dart';
import 'facility_3d_viewport.dart';

// =============================================================================
// FACILITIES 3D HUB HERO SHOWCASE (AION 2 FANTASY CITADEL STANDARD — V3)
// Master 3D turntable hero stage for the Facilities Hub screen.
// Features authentic realm skybox backdrop (Elysea / Asmodae / Abyss),
// animated luminous concentric runic pedestal ring, camera angle HUD controls,
// smooth rotation controller with zero-leak lifecycle, category-filtered
// carousel chips, and luxury frosted glass inspection bento card.
// =============================================================================

/// Realm atmospheric backdrop theme for the 3D facility stage.
enum RealmTheme {
  elysea(
    title: 'Elysea Sanctum',
    subtitle: 'Kutsal Işık Kalesi',
    imagePath: 'assets/images/backgrounds/elysea/bg_sanctum_citadel.png',
    secondaryPath: 'assets/images/backgrounds/elysea/bg_elysea_skybox.png',
    accentColor: Color(0xFFFFD700),
    icon: '☀️',
  ),
  asmodae(
    title: 'Asmodae Pandaemonium',
    subtitle: 'Karanlık Başkent',
    imagePath: 'assets/images/backgrounds/asmodae/bg_pandaemonium_capital.png',
    secondaryPath: 'assets/images/backgrounds/asmodae/bg_asmodae_skybox.png',
    accentColor: Color(0xFFCE93D8),
    icon: '🌙',
  ),
  abyss(
    title: 'Abyss Çekirdeği',
    subtitle: 'Uçurum Savaş Alanı',
    imagePath: 'assets/images/backgrounds/dungeons/bg_abyss_core_warzone.png',
    secondaryPath: 'assets/images/backgrounds/asmodae/bg_morheim_volcano.png',
    accentColor: Color(0xFF00E5FF),
    icon: '⚡',
  );

  const RealmTheme({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.secondaryPath,
    required this.accentColor,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String imagePath;
  final String secondaryPath;
  final Color accentColor;
  final String icon;
}

/// Camera perspective preset modes for the 3D stage.
enum CameraAnglePreset {
  orbit(label: '360° Orbit', icon: Icons.sync),
  frontal(label: 'Ön Cephe', icon: Icons.view_in_ar),
  isometric(label: 'İzometrik', icon: Icons.architecture),
  highAngle(label: 'Kuşbakışı', icon: Icons.filter_hdr);

  const CameraAnglePreset({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
}

class Facility3dHubShowcase extends StatefulWidget {
  const Facility3dHubShowcase({
    super.key,
    required this.selectedType,
    required this.unlockedByType,
    required this.onFacilitySelected,
    this.onInspectTap,
  });

  /// The currently focused facility type key in the 3D viewport.
  final String selectedType;

  /// Map of player's currently unlocked facilities.
  final Map<String, PlayerFacility> unlockedByType;

  /// Callback when user selects another facility to preview in 3D.
  final ValueChanged<String> onFacilitySelected;

  /// Callback when user taps the inspection action button.
  final VoidCallback? onInspectTap;

  static const List<String> featuredFacilities = <String>[
    'mining',
    'quarry',
    'lumber_mill',
    'clay_pit',
    'sand_quarry',
    'farming',
    'herb_garden',
    'ranch',
    'apiary',
    'mushroom_farm',
    'rune_mine',
    'holy_spring',
    'shadow_pit',
    'elemental_forge',
    'time_well',
  ];

  @override
  State<Facility3dHubShowcase> createState() => _Facility3dHubShowcaseState();
}

class _Facility3dHubShowcaseState extends State<Facility3dHubShowcase>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turntableAnimController;
  late final ScrollController _chipScrollController;

  RealmTheme _selectedRealm = RealmTheme.elysea;
  bool _userOverrodeRealm = false;

  CameraAnglePreset _cameraPreset = CameraAnglePreset.orbit;
  bool _isAutoRotating = true;
  bool _isSpeed2x = false;
  int _cameraResetCount = 0;

  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _turntableAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    _chipScrollController = ScrollController();
    _syncRealmWithFacility(widget.selectedType, force: true);
  }

  @override
  void didUpdateWidget(covariant Facility3dHubShowcase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedType != widget.selectedType) {
      if (!_userOverrodeRealm) {
        _syncRealmWithFacility(widget.selectedType);
      }
      _scrollToSelectedChip();
    }
  }

  @override
  void dispose() {
    _turntableAnimController.dispose();
    _chipScrollController.dispose();
    super.dispose();
  }

  void _syncRealmWithFacility(String type, {bool force = false}) {
    if (!force && _userOverrodeRealm) return;
    final Facility3dStructureSpec spec = Facility3dCatalog.getSpec(type);
    if (spec.tier == 3) {
      if (spec.facilityType == 'shadow_pit' || spec.facilityType == 'elemental_forge') {
        _selectedRealm = RealmTheme.asmodae;
      } else if (spec.facilityType == 'time_well') {
        _selectedRealm = RealmTheme.abyss;
      } else {
        _selectedRealm = RealmTheme.elysea;
      }
    } else if (spec.tier == 2 && spec.facilityType == 'mushroom_farm') {
      _selectedRealm = RealmTheme.asmodae;
    } else {
      _selectedRealm = RealmTheme.elysea;
    }
  }

  void _scrollToSelectedChip() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chipScrollController.hasClients) return;
      final List<String> visibleList = _filteredFacilities;
      final int index = visibleList.indexOf(widget.selectedType);
      if (index >= 0) {
        final double target = (index * 110.0) - 30.0;
        _chipScrollController.animateTo(
          target.clamp(0.0, _chipScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  List<String> get _filteredFacilities {
    return switch (_selectedCategory) {
      'tier1' => Facility3dHubShowcase.featuredFacilities
          .where((k) => Facility3dCatalog.getSpec(k).tier == 1)
          .toList(),
      'tier2' => Facility3dHubShowcase.featuredFacilities
          .where((k) => Facility3dCatalog.getSpec(k).tier == 2)
          .toList(),
      'tier3' => Facility3dHubShowcase.featuredFacilities
          .where((k) => Facility3dCatalog.getSpec(k).tier == 3)
          .toList(),
      _ => Facility3dHubShowcase.featuredFacilities,
    };
  }

  void _setCameraPreset(CameraAnglePreset preset) {
    HapticFeedback.selectionClick();
    setState(() {
      _cameraPreset = preset;
      _cameraResetCount++;
    });
  }

  void _toggleAutoRotate() {
    HapticFeedback.selectionClick();
    setState(() {
      _isAutoRotating = !_isAutoRotating;
    });
  }

  void _toggleSpeed() {
    HapticFeedback.selectionClick();
    setState(() {
      _isSpeed2x = !_isSpeed2x;
      _turntableAnimController.duration = Duration(seconds: _isSpeed2x ? 8 : 16);
      if (_turntableAnimController.isAnimating) {
        _turntableAnimController.repeat();
      }
    });
  }

  void _cycleRealm() {
    HapticFeedback.lightImpact();
    setState(() {
      _userOverrodeRealm = true;
      _selectedRealm = switch (_selectedRealm) {
        RealmTheme.elysea => RealmTheme.asmodae,
        RealmTheme.asmodae => RealmTheme.abyss,
        RealmTheme.abyss => RealmTheme.elysea,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final PlayerFacility? currentFacility = widget.unlockedByType[widget.selectedType];
    final bool isUnlocked = currentFacility != null;
    final int level = currentFacility?.level ?? 1;
    final bool isProducing = currentFacility?.productionStartedAt != null &&
        currentFacility!.productionStartedAt!.isNotEmpty;

    final Facility3dStructureSpec spec = Facility3dCatalog.getSpec(widget.selectedType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 1. Primary 3D Real-time Turntable Hero Stage
        _buildTurntableHeroStage(
          context: context,
          spec: spec,
          isUnlocked: isUnlocked,
          level: level,
          isProducing: isProducing,
        ),
        const SizedBox(height: 10),

        // 2. Category Filter Pill Row
        _buildCategoryFilters(spec),
        const SizedBox(height: 8),

        // 3. Quick Facility Selection Chip Carousel
        _buildFacilityCarousel(),
        const SizedBox(height: 10),

        // 4. Inspection Action / Status Lore Banner
        _buildInspectionBanner(
          context: context,
          spec: spec,
          isUnlocked: isUnlocked,
          level: level,
          isProducing: isProducing,
        ),
      ],
    );
  }

  Widget _buildTurntableHeroStage({
    required BuildContext context,
    required Facility3dStructureSpec spec,
    required bool isUnlocked,
    required int level,
    required bool isProducing,
  }) {
    const double stageHeight = 310.0;

    return Container(
      height: stageHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: spec.accentColor.withValues(alpha: 0.45),
          width: 1.4,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: spec.accentColor.withValues(alpha: 0.18),
            blurRadius: 22,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.70),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // Layer 0: Real Fantasy Realm Backdrop Image with breathing zoom
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _turntableAnimController,
                builder: (BuildContext ctx, Widget? child) {
                  final double scale = 1.02 +
                      (math.sin(_turntableAnimController.value * 2 * math.pi) * 0.02);
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: Image.asset(
                  _selectedRealm.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (BuildContext ctx, Object err, StackTrace? stack) {
                    return Image.asset(
                      _selectedRealm.secondaryPath,
                      fit: BoxFit.cover,
                      errorBuilder: (BuildContext _, Object __, StackTrace? ___) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                AppColors.carbonVoid,
                                AppColors.spaceNavy,
                                AppColors.carbonVoid,
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            // Layer 1: Radial Vignette Scrim for High-Contrast Turntable Focus
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.05,
                    colors: <Color>[
                      Colors.transparent,
                      AppColors.carbonVoid.withValues(alpha: 0.50),
                      AppColors.carbonVoid.withValues(alpha: 0.88),
                    ],
                    stops: const <double>[0.35, 0.75, 1.0],
                  ),
                ),
              ),
            ),

            // Layer 2: Luminous Concentric Pedestal Ring (CustomPainted beneath model)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              height: 120,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _turntableAnimController,
                  builder: (BuildContext ctx, Widget? child) {
                    return CustomPaint(
                      size: const Size(double.infinity, 120),
                      painter: _LuminousPedestalRingPainter(
                        spec: spec,
                        rotationProgress: _turntableAnimController.value,
                        level: level,
                        isProducing: isProducing,
                      ),
                    );
                  },
                ),
              ),
            ),

            // Layer 3: Interactive 3D Real-time Turntable Viewport
            Positioned.fill(
              child: Facility3dViewport(
                key: ValueKey<String>(
                  '${widget.selectedType}_${_cameraPreset.name}_$_cameraResetCount',
                ),
                facilityType: widget.selectedType,
                level: level,
                isProducing: isProducing,
                height: stageHeight,
                interactive: true,
                autoRotate: _isAutoRotating,
                showControls: false,
                onTap: () {
                  if (isUnlocked) {
                    widget.onInspectTap?.call();
                  }
                },
              ),
            ),

            // Layer 4: Floating Atmospheric Motes (IgnorePointer)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _turntableAnimController,
                  builder: (BuildContext ctx, Widget? child) {
                    return CustomPaint(
                      painter: _ShowcaseMotesPainter(
                        accentColor: spec.accentColor,
                        emissiveColor: spec.emissiveColor,
                        progress: _turntableAnimController.value,
                      ),
                    );
                  },
                ),
              ),
            ),

            // Layer 5: Top Stage Header (Archetype Badge & Realm Switcher)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                children: <Widget>[
                  // Structure Title & Glyph Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: AppColors.carbonVoid.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: spec.accentColor.withValues(alpha: 0.55),
                        width: 1.1,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: spec.accentColor.withValues(alpha: 0.20),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          spec.runicGlyph,
                          style: TextStyle(
                            fontSize: 13,
                            color: spec.emissiveColor,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          spec.structureTitle,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                          decoration: BoxDecoration(
                            color: spec.accentColor.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'T${spec.tier}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: spec.accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Realm Switcher Pill
                  _buildRealmSwitcherPill(),
                ],
              ),
            ),

            // Layer 6: Bottom Stage HUD (Status indicator & Camera Toolbar)
            Positioned(
              bottom: 8,
              left: 10,
              right: 10,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  // Status badge pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: AppColors.carbonVoid.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isUnlocked
                            ? (isProducing ? AppColors.toxicNeon : spec.accentColor)
                                .withValues(alpha: 0.45)
                            : AppColors.mutedTitanium.withValues(alpha: 0.3),
                        width: 0.9,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isUnlocked
                                ? (isProducing ? AppColors.toxicNeon : spec.accentColor)
                                : AppColors.mutedTitanium,
                            boxShadow: isUnlocked && isProducing
                                ? <BoxShadow>[
                                    BoxShadow(
                                      color: AppColors.toxicNeon.withValues(alpha: 0.8),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isUnlocked
                              ? (isProducing ? 'ÜRETİM AKTİF' : 'BEKLEMEDE')
                              : 'KİLİTLİ',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isUnlocked
                                ? (isProducing ? AppColors.toxicNeon : spec.accentColor)
                                : AppColors.mutedTitanium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Camera angle & turntable controls
                  _buildCameraToolbar(context, spec),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealmSwitcherPill() {
    return InkWell(
      onTap: _cycleRealm,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.carbonVoid.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedRealm.accentColor.withValues(alpha: 0.45),
            width: 0.9,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: _selectedRealm.accentColor.withValues(alpha: 0.20),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(_selectedRealm.icon, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
            Text(
              _selectedRealm.title.split(' ').first,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _selectedRealm.accentColor,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.swap_horiz,
              size: 13,
              color: _selectedRealm.accentColor.withValues(alpha: 0.85),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraToolbar(BuildContext context, Facility3dStructureSpec spec) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.carbonVoid.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: spec.accentColor.withValues(alpha: 0.40),
          width: 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Preset Buttons
          for (final CameraAnglePreset preset in CameraAnglePreset.values)
            _CameraPresetButton(
              preset: preset,
              isSelected: _cameraPreset == preset,
              accentColor: spec.accentColor,
              onTap: () => _setCameraPreset(preset),
            ),
          Container(
            width: 1,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: AppColors.mutedTitanium.withValues(alpha: 0.3),
          ),
          // Auto-rotate toggle
          _ToolbarIconButton(
            icon: _isAutoRotating ? Icons.pause_circle_outline : Icons.play_circle_outline,
            tooltip: _isAutoRotating ? 'Döndürmeyi Durdur' : 'Otomatik Döndür',
            isActive: _isAutoRotating,
            activeColor: spec.emissiveColor,
            onTap: _toggleAutoRotate,
          ),
          // Speed 1x / 2x toggle
          _ToolbarIconButton(
            icon: _isSpeed2x ? Icons.speed : Icons.shutter_speed,
            tooltip: _isSpeed2x ? 'Hız: 2x (Hızlı)' : 'Hız: 1x (Normal)',
            isActive: _isSpeed2x,
            activeColor: AppColors.liquidGold,
            onTap: _toggleSpeed,
          ),
          // Reset Camera View
          _ToolbarIconButton(
            icon: Icons.restart_alt,
            tooltip: 'Kamerayı Sıfırla',
            isActive: false,
            activeColor: AppColors.textPrimary,
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _cameraPreset = CameraAnglePreset.orbit;
                _cameraResetCount++;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters(Facility3dStructureSpec spec) {
    const List<({String key, String label})> categories = <({String key, String label})>[
      (key: 'all', label: 'Tümü (15)'),
      (key: 'tier1', label: 'Tier I Temel (5)'),
      (key: 'tier2', label: 'Tier II Doğal (5)'),
      (key: 'tier3', label: 'Tier III Mistik (5)'),
    ];

    return SizedBox(
      height: 26,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (BuildContext _, int index) => const SizedBox(width: 6),
        itemBuilder: (BuildContext context, int index) {
          final ({String key, String label}) cat = categories[index];
          final bool isSelected = _selectedCategory == cat.key;
          return InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategory = cat.key);
            },
            borderRadius: BorderRadius.circular(13),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? spec.accentColor.withValues(alpha: 0.20)
                    : AppColors.darkObsidian.withValues(alpha: 0.50),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: isSelected
                      ? spec.accentColor
                      : AppColors.mutedTitanium.withValues(alpha: 0.20),
                  width: isSelected ? 1.2 : 0.8,
                ),
              ),
              child: Center(
                child: Text(
                  cat.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? AppColors.textPrimary : AppColors.mutedTitanium,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFacilityCarousel() {
    final List<String> items = _filteredFacilities;

    return SizedBox(
      height: 42,
      child: ListView.separated(
        controller: _chipScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (BuildContext _, int index) => const SizedBox(width: 6),
        itemBuilder: (BuildContext context, int index) {
          final String type = items[index];
          final Facility3dStructureSpec chipSpec = Facility3dCatalog.getSpec(type);
          final bool isSelected = type == widget.selectedType;
          final PlayerFacility? pf = widget.unlockedByType[type];
          final bool isUnlocked = pf != null;
          final int level = pf?.level ?? 1;
          final bool isProducing = pf?.productionStartedAt != null &&
              pf!.productionStartedAt!.isNotEmpty;

          return _FacilitySelectorChip(
            spec: chipSpec,
            isSelected: isSelected,
            isUnlocked: isUnlocked,
            isProducing: isProducing,
            level: level,
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onFacilitySelected(type);
            },
          );
        },
      ),
    );
  }

  Widget _buildInspectionBanner({
    required BuildContext context,
    required Facility3dStructureSpec spec,
    required bool isUnlocked,
    required int level,
    required bool isProducing,
  }) {
    return FacGlassPanel(
      borderRadius: FacilitiesUi.radiusMd,
      borderColor: isUnlocked
          ? spec.accentColor.withValues(alpha: 0.45)
          : AppColors.mutedTitanium.withValues(alpha: 0.25),
      glowColor: isUnlocked ? spec.accentColor.withValues(alpha: 0.15) : null,
      backgroundColor: AppColors.bgDeep.withValues(alpha: 0.88),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: InkWell(
        onTap: isUnlocked ? widget.onInspectTap : null,
        borderRadius: BorderRadius.circular(FacilitiesUi.radiusMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // Left: Animated runic medallion
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    spec.accentColor.withValues(alpha: 0.30),
                    spec.accentColor.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(
                  color: isUnlocked ? spec.emissiveColor : AppColors.mutedTitanium,
                  width: 1.2,
                ),
                boxShadow: isUnlocked
                    ? <BoxShadow>[
                        BoxShadow(
                          color: spec.accentColor.withValues(alpha: 0.35),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                spec.runicGlyph,
                style: TextStyle(
                  fontSize: 18,
                  color: isUnlocked ? spec.emissiveColor : AppColors.mutedTitanium,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Center: Title, Tier/Status badge, and architectural lore
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          spec.structureTitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: isUnlocked ? AppColors.textPrimary : AppColors.mutedTitanium,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isUnlocked
                              ? (isProducing
                                  ? AppColors.toxicNeon.withValues(alpha: 0.18)
                                  : spec.accentColor.withValues(alpha: 0.18))
                              : AppColors.mutedTitanium.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isUnlocked
                                ? (isProducing
                                    ? AppColors.toxicNeon.withValues(alpha: 0.6)
                                    : spec.accentColor.withValues(alpha: 0.5))
                                : AppColors.mutedTitanium.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          isUnlocked
                              ? (isProducing ? 'ÜRETİM AKTİF' : 'Lv.$level • T${spec.tier}')
                              : 'KİLİTLİ',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isUnlocked
                                ? (isProducing ? AppColors.toxicNeon : spec.accentColor)
                                : AppColors.mutedTitanium,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isUnlocked
                        ? spec.architecturalDescription
                        : 'Kilidi açmak ve 3D yapıyı inşa etmek için alt kartına dokun.',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedTitanium,
                      height: 1.25,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Right: Action button
            if (isUnlocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      spec.accentColor.withValues(alpha: 0.25),
                      spec.accentColor.withValues(alpha: 0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: spec.accentColor.withValues(alpha: 0.6),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'İNCELE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: spec.accentColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: spec.accentColor,
                    ),
                  ],
                ),
              )
            else
              const Icon(
                Icons.lock_outline,
                size: 16,
                color: AppColors.mutedTitanium,
              ),
          ],
        ),
      ),
    );
  }
}


class _FacilitySelectorChip extends StatelessWidget {
  const _FacilitySelectorChip({
    required this.spec,
    required this.isSelected,
    required this.isUnlocked,
    required this.isProducing,
    required this.level,
    required this.onTap,
  });

  final Facility3dStructureSpec spec;
  final bool isSelected;
  final bool isUnlocked;
  final bool isProducing;
  final int level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color borderCol = isSelected
        ? spec.accentColor
        : (isUnlocked
            ? AppColors.liquidGold.withValues(alpha: 0.35)
            : AppColors.mutedTitanium.withValues(alpha: 0.20));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? spec.accentColor.withValues(alpha: 0.24)
              : AppColors.darkObsidian.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderCol,
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow: isSelected
              ? <BoxShadow>[
                  BoxShadow(
                    color: spec.accentColor.withValues(alpha: 0.32),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Runic glyph badge
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? spec.accentColor.withValues(alpha: 0.28)
                    : AppColors.carbonVoid.withValues(alpha: 0.60),
                border: Border.all(
                  color: isSelected
                      ? spec.emissiveColor
                      : AppColors.mutedTitanium.withValues(alpha: 0.3),
                  width: 0.8,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                spec.runicGlyph,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? spec.emissiveColor : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Title & Level
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  spec.structureTitle.split(' ').first,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    color: isSelected ? AppColors.textPrimary : AppColors.mutedTitanium,
                  ),
                ),
                Text(
                  isUnlocked ? 'Lv.$level • T${spec.tier}' : 'Kilitli • T${spec.tier}',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: isUnlocked
                        ? spec.accentColor
                        : AppColors.mutedTitanium.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            if (isProducing) ...<Widget>[
              const SizedBox(width: 5),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.toxicNeon,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.toxicNeon.withValues(alpha: 0.8),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ] else if (!isUnlocked) ...<Widget>[
              const SizedBox(width: 4),
              const Icon(
                Icons.lock,
                size: 10,
                color: AppColors.mutedTitanium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CameraPresetButton extends StatelessWidget {
  const _CameraPresetButton({
    required this.preset,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  final CameraAnglePreset preset;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(color: accentColor.withValues(alpha: 0.8), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              preset.icon,
              size: 12,
              color: isSelected ? accentColor : AppColors.mutedTitanium,
            ),
            const SizedBox(width: 3),
            Text(
              preset.label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? AppColors.textPrimary : AppColors.mutedTitanium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 15,
            color: isActive ? activeColor : AppColors.mutedTitanium,
          ),
        ),
      ),
    );
  }
}

/// Custom painter rendering the concentric glowing runic pedestal dais beneath the 3D structure.
class _LuminousPedestalRingPainter extends CustomPainter {
  const _LuminousPedestalRingPainter({
    required this.spec,
    required this.rotationProgress,
    required this.level,
    required this.isProducing,
  });

  final Facility3dStructureSpec spec;
  final double rotationProgress;
  final int level;
  final bool isProducing;

  static const List<String> _runes = <String>[
    'ᚠ', 'ᚢ', 'ᚦ', 'ᚨ', 'ᚱ', 'ᚲ', 'ᚷ', 'ᚹ', 'ᚺ', 'ᚾ', 'ᛁ', 'ᛃ',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height * 0.72);
    final double radiusX = size.width * 0.38;
    final double radiusY = size.height * 0.34;

    // 1. Core ambient glowing disc
    final Paint coreGlowPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radiusX,
        <Color>[
          spec.emissiveColor.withValues(alpha: isProducing ? 0.35 : 0.20),
          spec.accentColor.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        <double>[0.0, 0.65, 1.0],
      );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radiusX * 2.2, height: radiusY * 2.2),
      coreGlowPaint,
    );

    // 2. Outer luminous ring with blur
    final Paint outerGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
      ..color = spec.emissiveColor.withValues(
        alpha: 0.55 + (0.25 * math.sin(rotationProgress * 2 * math.pi)),
      );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radiusX * 2.0, height: radiusY * 2.0),
      outerGlowPaint,
    );

    // 3. Crisp inner and outer concentric ellipse strokes
    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = spec.accentColor.withValues(alpha: 0.45);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radiusX * 2.0, height: radiusY * 2.0),
      ringPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radiusX * 1.5, height: radiusY * 1.5),
      ringPaint..color = spec.accentColor.withValues(alpha: 0.30),
    );

    // 4. Rotating energy arcs
    final Paint arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = spec.emissiveColor.withValues(alpha: 0.85);
    final double baseAngle = rotationProgress * 2 * math.pi;
    final Rect arcRect = Rect.fromCenter(
      center: center,
      width: radiusX * 1.75,
      height: radiusY * 1.75,
    );
    canvas.drawArc(arcRect, baseAngle, math.pi * 0.4, false, arcPaint);
    canvas.drawArc(arcRect, baseAngle + math.pi, math.pi * 0.4, false, arcPaint);

    // 5. Rotating runic glyphs along the outer ring
    for (int i = 0; i < _runes.length; i++) {
      final double angle = baseAngle + (i * 2 * math.pi / _runes.length);
      final double px = center.dx + (radiusX * 0.88 * math.cos(angle));
      final double py = center.dy + (radiusY * 0.88 * math.sin(angle));

      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: _runes[i],
          style: TextStyle(
            color: spec.emissiveColor.withValues(alpha: 0.70),
            fontSize: 9.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(px - (tp.width / 2), py - (tp.height / 2)));
    }

    // 6. Cardinal crosshairs
    final Paint markerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = spec.emissiveColor.withValues(alpha: 0.90);
    const List<double> cardinalAngles = <double>[0, math.pi * 0.5, math.pi, math.pi * 1.5];
    for (final double ca in cardinalAngles) {
      final double mx = center.dx + (radiusX * math.cos(ca));
      final double my = center.dy + (radiusY * math.sin(ca));
      canvas.drawCircle(Offset(mx, my), 2.2, markerPaint);
    }

    // 7. Dynamic production pulse wave expanding outward
    if (isProducing) {
      final double pulseProgress = (rotationProgress * 3) % 1.0;
      final double pulseRadiusX = radiusX * (1.0 + (pulseProgress * 0.35));
      final double pulseRadiusY = radiusY * (1.0 + (pulseProgress * 0.35));
      final Paint pulsePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * (1.0 - pulseProgress)
        ..color = AppColors.liquidGold.withValues(
          alpha: 0.65 * (1.0 - pulseProgress),
        );
      canvas.drawOval(
        Rect.fromCenter(center: center, width: pulseRadiusX * 2, height: pulseRadiusY * 2),
        pulsePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LuminousPedestalRingPainter oldDelegate) {
    return oldDelegate.rotationProgress != rotationProgress ||
        oldDelegate.spec.facilityType != spec.facilityType ||
        oldDelegate.isProducing != isProducing ||
        oldDelegate.level != level;
  }
}

/// Floating ambient arcane motes for atmospheric fantasy depth.
class _ShowcaseMotesPainter extends CustomPainter {
  const _ShowcaseMotesPainter({
    required this.accentColor,
    required this.emissiveColor,
    required this.progress,
  });

  final Color accentColor;
  final Color emissiveColor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint motePaint = Paint()..style = PaintingStyle.fill;
    const int count = 14;

    for (int i = 0; i < count; i++) {
      final double seed = (i * 0.73) % 1.0;
      final double speed = 0.5 + (seed * 0.5);
      final double moteProgress = (progress * speed + seed) % 1.0;

      final double y = size.height * (1.0 - moteProgress);
      final double drift =
          math.sin((moteProgress * 2 * math.pi) + (i * 1.1)) * (14.0 * seed);
      final double x =
          (size.width * 0.15) + (size.width * 0.70 * ((seed * 13.0) % 1.0)) + drift;

      final double alpha = (math.sin(moteProgress * math.pi) * 0.65).clamp(0.0, 1.0);
      final double radius = 1.2 + (seed * 1.8);

      motePaint.color = (i.isEven ? emissiveColor : accentColor).withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, motePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ShowcaseMotesPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.emissiveColor != emissiveColor;
  }
}

