import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/engine/adaptive_quality_scaler.dart';
import '../../core/engine/zero_jank_preloader.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/character_class_select.dart';
import '../../providers/player_provider.dart';
import '../settings/graphics_settings_provider.dart';
import '../settings/graphics_settings_service.dart';
import 'widgets/aion_luxury_button.dart';
import 'widgets/aion_sky_particles.dart';
import 'widgets/auth_design.dart';
import 'widgets/character_elemental_aura.dart';
import 'widgets/character_slot_selector.dart';
import 'widgets/character_stats_badge.dart';
import 'widgets/first_dungeon_cta.dart';

class _CharacterClassOption {
  const _CharacterClassOption({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.titleLine,
    required this.traitSummary,
    required this.accentColor,
    required this.imageAsset,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String titleLine;
  final String traitSummary;
  final Color accentColor;
  final String imageAsset;
}

class CharacterSelectScreen extends ConsumerStatefulWidget {
  const CharacterSelectScreen({super.key});

  @override
  ConsumerState<CharacterSelectScreen> createState() => _CharacterSelectScreenState();
}

class _CharacterSelectScreenState extends ConsumerState<CharacterSelectScreen>
    with TickerProviderStateMixin {
  bool _loadingClasses = true;
  bool _submitting = false;
  String? _selectedClassId;
  String? _error;
  int _selectedSlotIndex = 0;

  // Turntable Viewport State
  double _turntableAngle = 0.0;
  double _turntableTilt = 0.0;
  bool _autoOrbit = false;
  int _lastHapticSector = 0;

  late final AnimationController _ambientController;
  late final Animation<double> _ambientAnimation;
  late final AnimationController _orbitController;
  late final AnimationController _turntableResetController;
  Animation<double>? _resetAnimation;

  List<_CharacterClassOption> _classes = const <_CharacterClassOption>[
    _CharacterClassOption(
      id: 'warrior',
      name: 'Savaşçı',
      description: 'Yüksek savunma ve güç.',
      icon: Icons.shield_outlined,
      titleLine: 'Frontline Dominator',
      traitSummary: 'STR / DEF / AGG',
      accentColor: Color(0xFFD8A63C),
      imageAsset: 'assets/characters/savasci.png',
    ),
    _CharacterClassOption(
      id: 'alchemist',
      name: 'Simyacı',
      description: 'İksir ve destek odaklı denge.',
      icon: Icons.auto_fix_high_outlined,
      titleLine: 'Arcane Field Engineer',
      traitSummary: 'INT / CTRL / SUP',
      accentColor: Color(0xFF63D1C5),
      imageAsset: 'assets/characters/simyaci.png',
    ),
    _CharacterClassOption(
      id: 'shadow',
      name: 'Gölge',
      description: 'Yüksek hasar ve çeviklik.',
      icon: Icons.gps_fixed_outlined,
      titleLine: 'Precision Elimination',
      traitSummary: 'DEX / SPD / BURST',
      accentColor: Color(0xFF8E93FF),
      imageAsset: 'assets/characters/golge.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _ambientAnimation = CurvedAnimation(
      parent: _ambientController,
      curve: Curves.easeInOut,
    );

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..addListener(() {
        if (_autoOrbit && mounted) {
          setState(() {
            _turntableAngle = (_turntableAngle + 0.008) % (2 * math.pi);
          });
        }
      })
      ..repeat();

    _turntableResetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    _loadClasses();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warmupAssets();
    });
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _orbitController.dispose();
    _turntableResetController.dispose();
    super.dispose();
  }

  /// ZeroJankPreloader asset warmup: pre-caches high-res character artwork
  /// in background time-slices with critical HUD priority.
  Future<void> _warmupAssets() async {
    final ZeroJankPreloader preloader = ZeroJankPreloader.instance;
    for (final _CharacterClassOption cls in _classes) {
      await preloader.preloadAtomic<bool>(
        id: 'char_select_warmup_${cls.id}',
        priority: PreloadPriority.criticalHud,
        loader: () async {
          if (mounted) {
            final ImageProvider provider = AssetImage(cls.imageAsset);
            await precacheImage(provider, context).catchError((_) {});
          }
          return true;
        },
      );
    }
  }

  void _resetTurntable() {
    HapticFeedback.lightImpact();
    _resetAnimation = Tween<double>(
      begin: _turntableAngle,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _turntableResetController,
      curve: Curves.easeOutCubic,
    ))..addListener(() {
        setState(() {
          _turntableAngle = _resetAnimation!.value;
          _turntableTilt = 0.0;
        });
      });
    _turntableResetController.forward(from: 0.0);
  }

  void _nudgeTurntable(double deltaRad) {
    HapticFeedback.selectionClick();
    setState(() {
      _turntableAngle += deltaRad;
    });
    ref.read(graphicsSettingsProvider.notifier).recordFrameTelemetry(16.6);
  }

  void _toggleAutoOrbit() {
    HapticFeedback.selectionClick();
    setState(() {
      _autoOrbit = !_autoOrbit;
    });
  }

  Future<void> _loadClasses() async {
    setState(() {
      _loadingClasses = true;
      _error = null;
    });

    try {
      final dynamic response = await SupabaseService.client.rpc('get_character_classes');
      if (response is! Map<String, dynamic>) {
        return;
      }

      final bool success = response['success'] == true;
      final List<dynamic>? classes = response['classes'] as List<dynamic>?;
      if (!success || classes == null || classes.isEmpty) {
        return;
      }

      final Map<String, IconData> iconMap = <String, IconData>{
        'warrior': Icons.shield_outlined,
        'alchemist': Icons.auto_fix_high_outlined,
        'shadow': Icons.gps_fixed_outlined,
      };

      final Map<String, ({String titleLine, String traitSummary, Color accentColor, String imageAsset})> presentationMap =
          <String, ({String titleLine, String traitSummary, Color accentColor, String imageAsset})>{
        'warrior': (
          titleLine: 'Frontline Dominator',
          traitSummary: 'STR / DEF / AGG',
          accentColor: const Color(0xFFD8A63C),
          imageAsset: 'assets/characters/savasci.png',
        ),
        'alchemist': (
          titleLine: 'Arcane Field Engineer',
          traitSummary: 'INT / CTRL / SUP',
          accentColor: const Color(0xFF63D1C5),
          imageAsset: 'assets/characters/simyaci.png',
        ),
        'shadow': (
          titleLine: 'Precision Elimination',
          traitSummary: 'DEX / SPD / BURST',
          accentColor: const Color(0xFF8E93FF),
          imageAsset: 'assets/characters/golge.png',
        ),
      };

      final List<_CharacterClassOption> parsed = classes
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> cls) {
        final String id = (cls['id'] as String?) ?? '';
        final presentation = presentationMap[id] ??
            (
              titleLine: 'Adaptive Specialist',
              traitSummary: 'BAL / FLEX / CORE',
              accentColor: const Color(0xFFD8A63C),
              imageAsset: 'assets/characters/savasci.png',
            );
        return _CharacterClassOption(
          id: id,
          name: (cls['name_tr'] as String?) ?? id,
          description: (cls['description_tr'] as String?) ?? '',
          icon: iconMap[id] ?? Icons.person_outline,
          titleLine: presentation.titleLine,
          traitSummary: presentation.traitSummary,
          accentColor: presentation.accentColor,
          imageAsset: presentation.imageAsset,
        );
      }).where((cls) => cls.id.isNotEmpty).toList();

      if (parsed.isNotEmpty) {
        _classes = parsed;
        _selectedClassId ??= parsed.first.id;
        _warmupAssets();
      }
    } catch (_) {
      _error = 'Sınıf listesi yüklenemedi.';
    } finally {
      if (mounted) {
        setState(() {
          _loadingClasses = false;
        });
      }
    }
  }

  Future<void> _selectClass() async {
    if (_selectedClassId == null || _submitting) {
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final String selectedClass = _selectedClassId!;
      final dynamic response = await SupabaseService.client.rpc(
        'select_character_class',
        params: <String, dynamic>{'p_class_id': selectedClass},
      );
      final CharacterClassSelectOutcome outcome =
          CharacterClassSelect.interpretResponse(response);

      switch (outcome) {
        case CharacterClassSelectOutcome.success:
          await ref.read(playerProvider.notifier).loadProfile();
          if (mounted) {
            await presentFirstDungeonCta(context);
          }
        case CharacterClassSelectOutcome.alreadySelected:
          await ref.read(playerProvider.notifier).loadProfile();
          if (mounted) {
            context.go('/home');
          }
        case CharacterClassSelectOutcome.failed:
          final String? serverError = response is Map
              ? response['error']?.toString()
              : null;
          throw Exception(serverError ?? 'select_character_class failed');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Sınıf seçimi başarısız oldu. Lütfen tekrar deneyin.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  _CharacterClassOption get _activeClass {
    return _classes.firstWhere(
      (cls) => cls.id == _selectedClassId,
      orElse: () => _classes.first,
    );
  }

  void _handleClassChanged(String classId) {
    if (_submitting) {
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _selectedClassId = classId;
      _turntableAngle = 0.0;
      _turntableTilt = 0.0;
    });
    ref.read(graphicsSettingsProvider.notifier).recordFrameTelemetry(16.6);
  }

  @override
  Widget build(BuildContext context) {
    final _CharacterClassOption activeClass = _activeClass;
    final ElementalAffinity affinity = ElementalAffinity.forClass(activeClass.id);
    final CharacterClassStats stats = CharacterClassStats.forClass(activeClass.id);

    // Adaptive Quality Scaler & Zero Jank Preloader integration
    final GraphicsConfigData graphicsConfig = ref.watch(graphicsSettingsProvider);
    final HardwareTier hardwareTier = graphicsConfig.tier.toHardwareTier();
    final ScalerTelemetry telemetry = ref.watch(scalerTelemetryProvider);

    final double blurSigma = switch (hardwareTier) {
      HardwareTier.eco => 0.0,
      HardwareTier.low => 4.0,
      HardwareTier.mid => 10.0,
      HardwareTier.high || HardwareTier.ultra => 16.0,
    };

    return Scaffold(
      backgroundColor: const Color(0xFF07080B),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // ── 1. Cosmic Celestial Particle & Aura Background ──────────────────
          Positioned.fill(
            child: AionSkyParticlesBackground(
              showRays: hardwareTier != HardwareTier.eco,
              primaryAura: affinity.primaryColor.withValues(alpha: 0.18),
              secondaryAura: affinity.secondaryColor.withValues(alpha: 0.10),
              accentEmissive: affinity.primaryColor,
              child: const SizedBox.expand(),
            ),
          ),

          // ── 2. Deep Ambient Radial Gradient ─────────────────────────────────
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.22),
                  radius: 1.15,
                  colors: <Color>[
                    affinity.primaryColor.withValues(alpha: 0.16),
                    affinity.secondaryColor.withValues(alpha: 0.06),
                    const Color(0xFF07080B),
                  ],
                  stops: const <double>[0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // ── 3. Vignette Top / Bottom Occlusion ──────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.60),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.88),
                  ],
                  stops: const <double>[0.0, 0.40, 1.0],
                ),
              ),
            ),
          ),

          // ── 4. Mobile SafeArea Content ──────────────────────────────────────
          SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxWidth < 380;
                final bool disableAnimations =
                    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    compact ? 12 : 18,
                    12,
                    compact ? 12 : 18,
                    16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // 1. Top Realm & Live Scaler Telemetry Header
                      _buildRealmHeader(affinity, hardwareTier, telemetry),
                      const SizedBox(height: 10),

                      // 2. Character Slot Selector
                      CharacterSlotSelector(
                        selectedSlotIndex: _selectedSlotIndex,
                        accentColor: affinity.primaryColor,
                        onSlotSelected: (int index) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedSlotIndex = index;
                          });
                        },
                      ),
                      const SizedBox(height: 14),

                      // 3. Central Character Hero Turntable Stage with Luxury Pedestal
                      SizedBox(
                        height: compact ? 270 : 325,
                        width: double.infinity,
                        child: _buildCharacterStage(
                          activeClass,
                          affinity,
                          compact,
                          disableAnimations,
                          hardwareTier,
                          blurSigma,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 4. Class Selection Horizontal Glass Cards
                      _buildClassCardsCarousel(activeClass, compact, blurSigma),
                      const SizedBox(height: 12),

                      // 5. Tactical Stats & Attributes Badge
                      CharacterStatsBadge(
                        stats: stats,
                        affinity: affinity,
                      ),
                      const SizedBox(height: 14),

                      // 6. Enter Game CTA Luxury Button
                      AionLuxuryButton(
                        label: 'Dünyaya Adım At',
                        subtitle: 'Aion-2 Realm // Maceraya Başla',
                        primaryColor: affinity.primaryColor,
                        secondaryColor: affinity.secondaryColor,
                        isLoading: _submitting,
                        disableAnimations: disableAnimations,
                        onPressed: (_loadingClasses || _selectedClassId == null)
                            ? null
                            : _selectClass,
                      ),

                      // Loading or Error Indicators
                      if (_loadingClasses) ...<Widget>[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            minHeight: 2.5,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(affinity.primaryColor),
                          ),
                        ),
                      ],
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.45)),
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: GoogleFonts.urbanist(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _loadClasses,
                                child: Text(
                                  'Tekrar Dene',
                                  style: GoogleFonts.urbanist(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
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
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealmHeader(
    ElementalAffinity affinity,
    HardwareTier hardwareTier,
    ScalerTelemetry telemetry,
  ) {
    return Row(
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF00E676),
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0xFF00E676),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'REALM: ELYSEA-01 // ONLINE',
          style: GoogleFonts.urbanist(
            color: const Color(0xFFB0BAC9),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        const Spacer(),
        // Adaptive Quality Scaler Hardware Tier Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.speed_rounded,
                size: 11,
                color: telemetry.rollingFps >= 50
                    ? const Color(0xFF00E676)
                    : const Color(0xFFFFB300),
              ),
              const SizedBox(width: 4),
              Text(
                '${hardwareTier.name.toUpperCase()} // ${telemetry.rollingFps.toStringAsFixed(0)} FPS',
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFFE2E8F0),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Elemental Affinity Pill Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: affinity.primaryColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: affinity.primaryColor.withValues(alpha: 0.38)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(affinity.insigniaIcon, size: 12, color: affinity.primaryColor),
              const SizedBox(width: 4),
              Text(
                affinity.name.toUpperCase(),
                style: GoogleFonts.urbanist(
                  color: affinity.primaryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCharacterStage(
    _CharacterClassOption activeClass,
    ElementalAffinity affinity,
    bool compact,
    bool disableAnimations,
    HardwareTier hardwareTier,
    double blurSigma,
  ) {
    return AnimatedSwitcher(
      duration: disableAnimations ? Duration.zero : const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey<String>(activeClass.id),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: affinity.primaryColor.withValues(alpha: 0.40),
            width: 1.4,
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              affinity.primaryColor.withValues(alpha: 0.20),
              const Color(0xFF0F1218),
              const Color(0xFF07080B),
            ],
            stops: const <double>[0.0, 0.45, 1.0],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: affinity.primaryColor.withValues(
                alpha: hardwareTier == HardwareTier.eco ? 0.05 : 0.18,
              ),
              blurRadius: hardwareTier == HardwareTier.eco ? 8 : 28,
              spreadRadius: 1,
            ),
            const BoxShadow(
              color: Colors.black87,
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // 1. Animated Elemental Aura (Rings, Corona, Embers)
              Positioned.fill(
                child: CharacterElementalAura(
                  affinity: affinity,
                  disableAnimations: disableAnimations,
                ),
              ),

              // 2. Luxury 3D Character Selection Pedestal Dais
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: disableAnimations ? kAlwaysCompleteAnimation : _ambientAnimation,
                  builder: (BuildContext context, Widget? child) {
                    return CustomPaint(
                      painter: _LuxuryPedestalPainter(
                        affinity: affinity,
                        turntableAngle: _turntableAngle,
                        pulse: disableAnimations ? 0.5 : _ambientAnimation.value,
                        hardwareTier: hardwareTier,
                      ),
                    );
                  },
                ),
              ),

              // 3. Interactive Character Sprite with 3D Turntable Perspective & Gesture Hooks
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) {
                    setState(() {
                      _autoOrbit = false;
                    });
                  },
                  onHorizontalDragUpdate: (DragUpdateDetails details) {
                    final double startMs = DateTime.now().microsecondsSinceEpoch / 1000.0;
                    setState(() {
                      _turntableAngle += details.primaryDelta! * 0.015;
                      _turntableTilt = (_turntableTilt + details.delta.dy * 0.003).clamp(-0.12, 0.12);
                    });
                    final int sector = (_turntableAngle / (math.pi / 4)).floor();
                    if (sector != _lastHapticSector) {
                      HapticFeedback.selectionClick();
                      _lastHapticSector = sector;
                    }
                    final double endMs = DateTime.now().microsecondsSinceEpoch / 1000.0;
                    ref.read(graphicsSettingsProvider.notifier).recordFrameTelemetry(
                      (endMs - startMs + 16.0).clamp(1.0, 33.3),
                    );
                  },
                  onDoubleTap: _resetTurntable,
                  child: AnimatedBuilder(
                    animation: disableAnimations ? kAlwaysCompleteAnimation : _ambientAnimation,
                    builder: (BuildContext context, Widget? child) {
                      final double floatOffset = disableAnimations
                          ? 0
                          : math.sin(_ambientAnimation.value * math.pi) * 4;

                      final Matrix4 matrix = Matrix4.identity();
                      if (hardwareTier != HardwareTier.eco) {
                        matrix.setEntry(3, 2, 0.0012);
                      }
                      matrix.rotateY(_turntableAngle);
                      matrix.rotateX(_turntableTilt);

                      return Transform(
                        alignment: Alignment.center,
                        transform: matrix,
                        child: Transform.translate(
                          offset: Offset(0, floatOffset - 10),
                          child: child,
                        ),
                      );
                    },
                    child: ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: <double>[0.0, 0.65, 0.90, 1.0],
                          colors: <Color>[
                            Colors.white,
                            Colors.white,
                            Color(0xCCFFFFFF),
                            Color(0x00FFFFFF),
                          ],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: Image.asset(
                        activeClass.imageAsset,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                          return Center(
                            child: Icon(
                              activeClass.icon,
                              size: compact ? 90 : 120,
                              color: activeClass.accentColor.withValues(alpha: 0.85),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Class Insignia Badge in Top Left
              Positioned(
                top: 14,
                left: 14,
                child: ClassInsigniaBadge(
                  affinity: affinity,
                  icon: activeClass.icon,
                  size: 46,
                ),
              ),

              // 5. Turntable 360° Angle & Reset HUD Capsule in Top Right
              Positioned(
                top: 14,
                right: 14,
                child: _buildTurntableAngleBadge(affinity, blurSigma),
              ),

              // 6. Turntable Quick-Step Nudge & Auto-Orbit Controls in Bottom Right
              Positioned(
                bottom: 48,
                right: 14,
                child: _buildTurntableQuickControls(affinity, blurSigma),
              ),

              // 7. Class Name & Title Overlay in Bottom Center
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: _buildCharacterTitleOverlay(activeClass, affinity),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTurntableAngleBadge(ElementalAffinity affinity, double blurSigma) {
    final int degrees = (((_turntableAngle * 180 / math.pi) % 360 + 360) % 360).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1017).withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: affinity.primaryColor.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.threesixty_rounded,
                size: 13,
                color: affinity.primaryColor,
              ),
              const SizedBox(width: 4),
              Text(
                '$degrees°',
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (degrees != 0) ...<Widget>[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _resetTurntable,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: affinity.primaryColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sync_rounded,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTurntableQuickControls(ElementalAffinity affinity, double blurSigma) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1017).withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Step Left -45°
              GestureDetector(
                onTap: () => _nudgeTurntable(-math.pi / 4),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.rotate_left_rounded, size: 14, color: Colors.white70),
                ),
              ),
              const SizedBox(width: 4),
              // Auto Orbit Toggle
              GestureDetector(
                onTap: _toggleAutoOrbit,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: _autoOrbit
                        ? affinity.primaryColor.withValues(alpha: 0.28)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _autoOrbit
                          ? affinity.primaryColor.withValues(alpha: 0.6)
                          : Colors.transparent,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        _autoOrbit ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        size: 12,
                        color: _autoOrbit ? affinity.primaryColor : Colors.white60,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'ORBIT',
                        style: GoogleFonts.urbanist(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: _autoOrbit ? affinity.primaryColor : Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Step Right +45°
              GestureDetector(
                onTap: () => _nudgeTurntable(math.pi / 4),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.rotate_right_rounded, size: 14, color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCharacterTitleOverlay(
    _CharacterClassOption activeClass,
    ElementalAffinity affinity,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          activeClass.name.toUpperCase(),
          style: GoogleFonts.urbanist(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            shadows: const <Shadow>[
              Shadow(
                color: Colors.black,
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          activeClass.titleLine,
          style: GoogleFonts.urbanist(
            color: affinity.primaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            shadows: const <Shadow>[
              Shadow(
                color: Colors.black,
                blurRadius: 6,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: affinity.primaryColor.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Text(
            activeClass.traitSummary,
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white70,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClassCardsCarousel(
    _CharacterClassOption activeClass,
    bool compact,
    double blurSigma,
  ) {
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _classes.length,
        separatorBuilder: (BuildContext context, int index) => const SizedBox(width: 10),
        itemBuilder: (BuildContext context, int index) {
          final _CharacterClassOption cls = _classes[index];
          final bool isSelected = cls.id == _selectedClassId;
          final ElementalAffinity cardAffinity = ElementalAffinity.forClass(cls.id);

          return GestureDetector(
            onTap: _submitting ? null : () => _handleClassChanged(cls.id),
            child: AnimatedScale(
              scale: isSelected ? 1.02 : 0.98,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: compact ? 135 : 152,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          isSelected
                              ? cardAffinity.primaryColor.withValues(alpha: 0.28)
                              : const Color(0xFF141720).withValues(alpha: 0.88),
                          const Color(0xFF0A0C10).withValues(alpha: 0.95),
                        ],
                      ),
                      border: Border.all(
                        color: isSelected
                            ? cardAffinity.primaryColor
                            : Colors.white.withValues(alpha: 0.12),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? <BoxShadow>[
                              BoxShadow(
                                color: cardAffinity.primaryColor.withValues(alpha: 0.35),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        // Top subtle specular highlight
                        Positioned(
                          top: 0,
                          left: 12,
                          right: 12,
                          child: Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  Colors.transparent,
                                  (isSelected ? cardAffinity.primaryColor : Colors.white).withValues(alpha: 0.45),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Background character thumbnail
                        Positioned.fill(
                          child: ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[Colors.white, Color(0x66FFFFFF), Colors.transparent],
                                stops: <double>[0.0, 0.45, 1.0],
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.dstIn,
                            child: Image.asset(
                              cls.imageAsset,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                                return Center(
                                  child: Icon(cls.icon, color: cls.accentColor, size: 36),
                                );
                              },
                            ),
                          ),
                        ),
                        // Dark Gradient Vignette
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.45),
                                  Colors.black.withValues(alpha: 0.94),
                                ],
                                stops: const <double>[0.0, 0.40, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // Card Content
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 8,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Icon(
                                    cls.icon,
                                    color: isSelected ? cardAffinity.primaryColor : Colors.white70,
                                    size: 16,
                                  ),
                                  const Spacer(),
                                  if (isSelected)
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: cardAffinity.primaryColor,
                                        shape: BoxShape.circle,
                                        boxShadow: <BoxShadow>[
                                          BoxShadow(
                                            color: cardAffinity.primaryColor,
                                            blurRadius: 5,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                cls.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.urbanist(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                cardAffinity.name,
                                maxLines: 1,
                                style: GoogleFonts.urbanist(
                                  color: isSelected ? cardAffinity.primaryColor : Colors.white38,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

/// Custom painter for the Luxury Character Selection Pedestal Dais.
///
/// Features:
/// - Ground contact occlusion shadow (scaled by [HardwareTier]).
/// - Multi-tier beveled metallic obsidian dais.
/// - Inscribed Aion runes rotating with [turntableAngle].
/// - Dynamic specular rim highlight shifting with rotation angle.
/// - Central uplight projector casting elemental glow upwards onto character.
class _LuxuryPedestalPainter extends CustomPainter {
  const _LuxuryPedestalPainter({
    required this.affinity,
    required this.turntableAngle,
    required this.pulse,
    required this.hardwareTier,
  });

  final ElementalAffinity affinity;
  final double turntableAngle;
  final double pulse;
  final HardwareTier hardwareTier;

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double baseY = size.height * 0.86;
    final double daisWidth = size.width * 0.82;
    final double daisHeight = size.height * 0.16;

    // 1. Soft Floor Occlusion Shadow
    if (hardwareTier != HardwareTier.eco) {
      final Rect shadowRect = Rect.fromCenter(
        center: Offset(centerX, baseY + 8),
        width: daisWidth * 1.08,
        height: daisHeight * 1.15,
      );
      final Paint shadowPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(centerX, baseY + 8),
          daisWidth * 0.55,
          <Color>[
            Colors.black.withValues(alpha: 0.85),
            Colors.black.withValues(alpha: 0.35),
            Colors.transparent,
          ],
          <double>[0.0, 0.6, 1.0],
        );
      canvas.drawOval(shadowRect, shadowPaint);
    }

    // 2. Pedestal Outer Tier (Lower Bevel)
    final Rect outerBevelRect = Rect.fromCenter(
      center: Offset(centerX, baseY + 4),
      width: daisWidth,
      height: daisHeight,
    );
    final Paint outerBevelPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(centerX - daisWidth / 2, baseY),
        Offset(centerX + daisWidth / 2, baseY + 4),
        <Color>[
          affinity.primaryColor.withValues(alpha: 0.35),
          const Color(0xFF151922),
          const Color(0xFF090B0F),
          affinity.secondaryColor.withValues(alpha: 0.25),
        ],
        <double>[0.0, 0.3, 0.7, 1.0],
      );
    canvas.drawOval(outerBevelRect, outerBevelPaint);

    // 3. Pedestal Top Surface Dais (Obsidian Metallic Platform)
    final Rect daisTopRect = Rect.fromCenter(
      center: Offset(centerX, baseY),
      width: daisWidth * 0.94,
      height: daisHeight * 0.88,
    );
    final Paint daisTopPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(centerX, baseY),
        daisWidth * 0.48,
        <Color>[
          affinity.primaryColor.withValues(alpha: 0.22 + 0.12 * pulse),
          const Color(0xFF141923),
          const Color(0xFF080A0E),
        ],
        <double>[0.0, 0.45, 1.0],
      );
    canvas.drawOval(daisTopRect, daisTopPaint);

    // 4. Luminous Pedestal Rim Border with Dynamic Specular Reflection
    final Paint rimBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = ui.Gradient.sweep(
        Offset(centerX, baseY),
        <Color>[
          affinity.primaryColor.withValues(alpha: 0.2),
          affinity.primaryColor.withValues(alpha: 0.9),
          Colors.white.withValues(alpha: 0.85),
          affinity.primaryColor.withValues(alpha: 0.9),
          affinity.primaryColor.withValues(alpha: 0.2),
        ],
        <double>[0.0, 0.25, 0.5, 0.75, 1.0],
        TileMode.clamp,
        turntableAngle,
        turntableAngle + math.pi * 2,
      );
    canvas.drawOval(daisTopRect, rimBorderPaint);

    // 5. Inscribed Ancient Runes on Pedestal Surface
    final Paint runePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = affinity.primaryColor.withValues(alpha: 0.45 + 0.30 * pulse);

    final Rect innerRuneRect = Rect.fromCenter(
      center: Offset(centerX, baseY),
      width: daisWidth * 0.72,
      height: daisHeight * 0.65,
    );
    canvas.drawOval(innerRuneRect, runePaint);

    // Cardinal rune nodes along the ring
    const int runeNodeCount = 8;
    for (int i = 0; i < runeNodeCount; i++) {
      final double angle = turntableAngle + (i * 2 * math.pi / runeNodeCount);
      final double rx = centerX + math.cos(angle) * (daisWidth * 0.36);
      final double ry = baseY + math.sin(angle) * (daisHeight * 0.325);

      final Paint nodePaint = Paint()
        ..color = (i % 2 == 0 ? affinity.primaryColor : affinity.secondaryColor)
            .withValues(alpha: 0.7 + 0.3 * pulse)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(rx, ry), i % 2 == 0 ? 2.2 : 1.5, nodePaint);
    }

    // 6. Central Uplight Projector
    if (hardwareTier != HardwareTier.eco) {
      final Rect uplightRect = Rect.fromCenter(
        center: Offset(centerX, baseY - 6),
        width: daisWidth * 0.45,
        height: daisHeight * 0.5,
      );
      final Paint uplightPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(centerX, baseY - 6),
          daisWidth * 0.25,
          <Color>[
            affinity.primaryColor.withValues(alpha: 0.40 + 0.20 * pulse),
            affinity.secondaryColor.withValues(alpha: 0.12),
            Colors.transparent,
          ],
          <double>[0.0, 0.5, 1.0],
        );
      canvas.drawOval(uplightRect, uplightPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LuxuryPedestalPainter oldDelegate) {
    return oldDelegate.turntableAngle != turntableAngle ||
        oldDelegate.pulse != pulse ||
        oldDelegate.affinity != affinity ||
        oldDelegate.hardwareTier != hardwareTier;
  }
}
