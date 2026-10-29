import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/pvp/colosseum_arena_lighting.dart';
import '../../../components/pvp/pvp_gladiator_3d_view.dart';
import '../../../core/vfx/ground_decal_system.dart';
import '../../../theme/app_spacing.dart';

/// Dark fantasy arena theme preset for PvP Colosseum battles.
class ArenaThemeInfo {
  const ArenaThemeInfo({
    required this.name,
    required this.subtitle,
    required this.accentColor,
    required this.icon,
    required this.minRating,
    this.lightingTheme,
    this.hazardTitle = 'Arena Koşulları',
    this.hazardModifier = 'Standart Düello',
    this.gladiatorClass = GladiatorClass.knight,
    this.weapon = GladiatorWeapon.claymore,
  });

  final String name;
  final String subtitle;
  final Color accentColor;
  final IconData icon;
  final int minRating;
  final ArenaLightingTheme? lightingTheme;
  final String hazardTitle;
  final String hazardModifier;
  final GladiatorClass gladiatorClass;
  final GladiatorWeapon weapon;

  /// Resolves the authentic Colosseum lighting preset for this arena.
  ArenaLightingTheme get effectiveLightingTheme {
    if (lightingTheme != null) return lightingTheme!;
    if (accentColor == const Color(0xFFFF1744)) {
      return ArenaLightingTheme.abyssalEclipse();
    } else if (accentColor == const Color(0xFFFFD54F)) {
      return ArenaLightingTheme.sanctumCelestial();
    } else if (accentColor == const Color(0xFF00E5FF)) {
      return ArenaLightingTheme.obsidianChasm();
    } else if (accentColor == const Color(0xFFFF9100) || accentColor == const Color(0xFFFFB300)) {
      return ArenaLightingTheme.dawnGladiator();
    }
    return ArenaLightingTheme(
      name: name,
      sunAzimuth: -0.65,
      sunElevation: 1.0,
      sunIntensity: 0.92,
      sunColor: accentColor,
      ambientColor: const Color(0xFF101322),
      crystalColor: accentColor,
      shadowColor: const Color(0xFF070912),
    );
  }
}

/// Predefined dark fantasy arenas with unique lighting, hazard modifiers, and gladiator archetypes.
const List<ArenaThemeInfo> defaultArenaThemes = <ArenaThemeInfo>[
  ArenaThemeInfo(
    name: 'Uçurum Gladyatör Arenası',
    subtitle: 'Karanlık enerji fırtınası · Çift rep çarpanı',
    hazardTitle: 'Abis Çöküşü',
    hazardModifier: '+15% Kaos & Gölge Hasarı',
    accentColor: Color(0xFFFF1744),
    icon: Icons.shield_rounded,
    minRating: 1000,
    gladiatorClass: GladiatorClass.barbarian,
    weapon: GladiatorWeapon.battleaxe,
  ),
  ArenaThemeInfo(
    name: 'Sanctum Göksel Meydanı',
    subtitle: 'Işık hanedanı tapınak arenası · Yüksek bahis',
    hazardTitle: 'Kutsal Şavk',
    hazardModifier: '+10% Zırh & %5 Kritik Şans',
    accentColor: Color(0xFFFFD54F),
    icon: Icons.wb_sunny_rounded,
    minRating: 1250,
    gladiatorClass: GladiatorClass.knight,
    weapon: GladiatorWeapon.claymore,
  ),
  ArenaThemeInfo(
    name: 'Obsidiyen Çukur Koloseumu',
    subtitle: 'Yeraltı dövüş çukuru · Ölüm maçı kuralları',
    hazardTitle: 'Obsidiyen Çatlağı',
    hazardModifier: 'Saniyede %1.5 Saf Hasar Alanı',
    accentColor: Color(0xFF00E5FF),
    icon: Icons.flash_on_rounded,
    minRating: 1500,
    gladiatorClass: GladiatorClass.mage,
    weapon: GladiatorWeapon.darkSword,
  ),
  ArenaThemeInfo(
    name: 'Şafak Gladyatör Koloseumu',
    subtitle: 'Altın şafak arenası · Hızlı düello & rütbe puanı',
    hazardTitle: 'Şafak Öfkesi',
    hazardModifier: 'İlk 15 Saniye +20% Saldırı Hızı',
    accentColor: Color(0xFFFF9100),
    icon: Icons.local_fire_department_rounded,
    minRating: 1750,
    gladiatorClass: GladiatorClass.soldier,
    weapon: GladiatorWeapon.goldenSword,
  ),
];

/// Cinematic CustomPainter for mobile arena viewports.
/// Renders:
/// - Colosseum walls, sky, godrays & shadows
/// - Authentic ground decal projections (cracks, scorch marks, slash gouges)
/// - Concentric celestial/abyssal rune projections with 3D light pillars
/// - Pulsing hazard barrier ring with sinusoidal electric arcs
/// - Floating basalt monoliths with multi-faceted 3D shading
/// - Interactive strike ripples & combat lighting flashes
class ArenaBattlefieldPainter extends CustomPainter {
  ArenaBattlefieldPainter({
    required this.animationProgress,
    required this.accentColor,
    this.lightingTheme,
    this.cameraPitch = 0.0,
    this.cameraYaw = 0.0,
    this.combatFlashIntensity = 0.0,
    this.shockwaveProgress = 0.0,
    this.shockwaveCenter = Offset.zero,
    this.externalDecals = const <DecalInstance>[],
  });

  final double animationProgress;
  final Color accentColor;
  final ArenaLightingTheme? lightingTheme;
  final double cameraPitch;
  final double cameraYaw;
  final double combatFlashIntensity;
  final double shockwaveProgress;
  final Offset shockwaveCenter;
  final List<DecalInstance> externalDecals;

  ArenaLightingTheme get _resolvedTheme {
    if (lightingTheme != null) return lightingTheme!;
    if (accentColor == const Color(0xFFFF1744)) {
      return ArenaLightingTheme.abyssalEclipse();
    } else if (accentColor == const Color(0xFFFFD54F)) {
      return ArenaLightingTheme.sanctumCelestial();
    } else if (accentColor == const Color(0xFF00E5FF)) {
      return ArenaLightingTheme.obsidianChasm();
    } else if (accentColor == const Color(0xFFFF9100) || accentColor == const Color(0xFFFFB300)) {
      return ArenaLightingTheme.dawnGladiator();
    }
    return ArenaLightingTheme(
      name: 'Dynamic Colosseum',
      sunAzimuth: -0.65,
      sunElevation: 1.0,
      sunIntensity: 0.90,
      sunColor: accentColor,
      ambientColor: const Color(0xFF101322),
      crystalColor: accentColor,
      shadowColor: const Color(0xFF070912),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    if (w <= 0 || h <= 0) return;

    final double cx = w * 0.5 + cameraYaw * 12.0;
    final double cy = h * 0.58 + cameraPitch * 8.0;

    final ArenaLightingTheme theme = _resolvedTheme;

    // 1. Dynamic Colosseum Floor, Walls, Aether Crystals, and Godrays via Engine
    final List<GladiatorShadowSlot> slots = <GladiatorShadowSlot>[
      GladiatorShadowSlot(
        position: const Offset(0.32, 0.62),
        height: 68.0,
        width: 28.0,
        lungeOffset: Offset(
          math.sin(animationProgress * 2 * math.pi) * 3.5,
          math.cos(animationProgress * 2 * math.pi) * 1.8,
        ),
      ),
      GladiatorShadowSlot(
        position: const Offset(0.68, 0.62),
        height: 72.0,
        width: 30.0,
        lungeOffset: Offset(
          -math.sin(animationProgress * 2 * math.pi) * 3.0,
          -math.cos(animationProgress * 2 * math.pi) * 1.8,
        ),
      ),
    ];

    final ColosseumArenaPainter engine = ColosseumArenaPainter(
      animationProgress: animationProgress,
      theme: theme,
      gladiatorSlots: slots,
      showColosseumWalls: true,
      showCrystals: true,
      showGodrays: true,
      showShadows: true,
      combatFlashIntensity: combatFlashIntensity,
    );
    engine.paint(canvas, size);

    // 2. Arena Floor Ground Decals Projection Layer (cracks, scorch craters, slash gouges)
    _paintGroundDecals(canvas, size, cx, cy, theme);

    // 3. Interactive Tap Shockwave Ripple (if active)
    if (shockwaveProgress > 0.0 && shockwaveProgress < 1.0) {
      _paintShockwaveRipple(canvas, size, cx, cy);
    }

    // 4. Arena Ring Boundary Glow & Hazard Forcefield Barrier
    _paintArenaRingBoundary(canvas, size, cx, cy);

    // 5. Inscribed Celestial / Abyssal Runic Projections & Ascending Beams
    _paintRunicProjections(canvas, size, cx, cy);

    // 6. Floating Shattered Monolith Basalt Stones with 3D Facets & Runes
    _paintFloatingMonoliths(canvas, size, cx, cy);

    // 7. Gladiator Figures Facing Off in Combat Stance
    _paintGladiatorFigures(canvas, size, slots, theme, cx, cy);

    // 8. Dynamic Combat Lighting Flash & Radial Ambient Vignette
    _paintAmbientLightingJuice(canvas, size, cx, cy);
  }

  // ── GROUND DECALS RENDERING ────────────────────────────────────────────────
  void _paintGroundDecals(Canvas canvas, Size size, double cx, double cy, ArenaLightingTheme theme) {
    final double floorWidth = size.width * 0.88;
    final double floorHeight = size.height * 0.54;

    // Floor perspective foreshortening helper
    Offset toFloorPoint(double nx, double nz) {
      final double depthScale = 1.0 + nz * 0.16;
      final double px = cx + nx * (floorWidth * 0.5) * depthScale;
      final double py = cy + nz * (floorHeight * 0.5);
      return Offset(px, py);
    }

    // A. Central Spell Scorch Crater (battle clash impact)
    final Offset scorchCenter = toFloorPoint(0.0, 0.05);
    final double scorchRx = floorWidth * 0.22;
    final double scorchRy = floorHeight * 0.18;

    final Paint scorchPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xFF090A0E).withValues(alpha: 0.85),
          const Color(0xFF141720).withValues(alpha: 0.65),
          accentColor.withValues(alpha: 0.25),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 0.85, 1.0],
      ).createShader(Rect.fromCenter(center: scorchCenter, width: scorchRx * 2, height: scorchRy * 2));

    canvas.drawOval(
      Rect.fromCenter(center: scorchCenter, width: scorchRx * 2, height: scorchRy * 2),
      scorchPaint,
    );

    // Radiating molten veins in the scorch core
    final Paint veinPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.5 + 0.25 * math.sin(animationProgress * 3 * math.pi))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int i = 0; i < 6; i++) {
      final double angle = (i * math.pi / 3.0) + (animationProgress * 0.2);
      final double len = scorchRx * (0.45 + 0.15 * math.sin(i * 1.7));
      final Path crack = Path()..moveTo(scorchCenter.dx, scorchCenter.dy);
      final double midX = scorchCenter.dx + math.cos(angle + 0.15) * (len * 0.55);
      final double midY = scorchCenter.dy + math.sin(angle + 0.15) * (len * 0.45 * 0.6);
      final double endX = scorchCenter.dx + math.cos(angle) * len;
      final double endY = scorchCenter.dy + math.sin(angle) * (len * 0.6);
      crack.quadraticBezierTo(midX, midY, endX, endY);
      canvas.drawPath(crack, veinPaint);
    }

    // B. Left Challenger Slash Gouge (trench cut into stone)
    final Offset gougePos = toFloorPoint(-0.35, 0.10);
    final double gougeRx = floorWidth * 0.08;
    final double gougeRy = floorHeight * 0.035;

    canvas.save();
    canvas.translate(gougePos.dx, gougePos.dy);
    canvas.rotate(-0.45);

    final Paint gougePaint = Paint()
      ..color = const Color(0xFF0D101A).withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: gougeRx * 2, height: gougeRy * 2),
        Radius.circular(gougeRy),
      ),
      gougePaint,
    );

    final Paint sparkEdge = Paint()
      ..color = theme.sunColor.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawLine(Offset(-gougeRx * 0.7, 0), Offset(gougeRx * 0.7, 0), sparkEdge);
    canvas.restore();

    // C. Right Defender Cracked Earth Fissures
    final Offset crackPos = toFloorPoint(0.36, 0.08);
    final Paint earthCrack = Paint()
      ..color = const Color(0xFF1A1F2E).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    for (int j = 0; j < 5; j++) {
      final double ca = j * 2 * math.pi / 5.0;
      final double clen = floorWidth * 0.055;
      final double ex = crackPos.dx + math.cos(ca) * clen;
      final double ey = crackPos.dy + math.sin(ca) * clen * 0.55;
      canvas.drawLine(crackPos, Offset(ex, ey), earthCrack);
    }

    // D. External decals from GroundDecalSystem if registered
    for (final DecalInstance d in externalDecals) {
      if (d.currentOpacity <= 0.001) continue;
      final Offset pos = toFloorPoint(d.position.x * 0.5, d.position.z * 0.5);
      final double rx = d.halfExtents.x * 14.0;
      final double ry = d.halfExtents.y * 14.0 * 0.55;

      final Paint extPaint = Paint()
        ..color = d.color.withValues(alpha: (d.color.a * d.currentOpacity).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;
      canvas.drawOval(Rect.fromCenter(center: pos, width: rx * 2, height: ry * 2), extPaint);
    }
  }

  // ── SHOCKWAVE RIPPLE ────────────────────────────────────────────────────────
  void _paintShockwaveRipple(Canvas canvas, Size size, double cx, double cy) {
    final double radius = size.width * 0.42 * shockwaveProgress;
    final double alpha = (1.0 - shockwaveProgress).clamp(0.0, 1.0);

    final Paint wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * (1.0 - shockwaveProgress * 0.6)
      ..color = accentColor.withValues(alpha: alpha * 0.75);

    // Perspective foreshortened shockwave oval
    final Rect waveRect = Rect.fromCenter(
      center: shockwaveCenter != Offset.zero ? shockwaveCenter : Offset(cx, cy),
      width: radius * 2.0,
      height: radius * 1.15,
    );
    canvas.drawOval(waveRect, wavePaint);

    final Paint innerGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: alpha * 0.9);
    canvas.drawOval(
      Rect.fromCenter(
        center: shockwaveCenter != Offset.zero ? shockwaveCenter : Offset(cx, cy),
        width: radius * 1.7,
        height: radius * 0.98,
      ),
      innerGlow,
    );
  }

  // ── ARENA RING BOUNDARY GLOW & HAZARD FORCEFIELD ────────────────────────────
  void _paintArenaRingBoundary(Canvas canvas, Size size, double cx, double cy) {
    final double w = size.width;
    final double h = size.height;
    final double rx = w * 0.44;
    final double ry = h * 0.27;

    final Rect boundaryRect = Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2);

    // 1. Soft atmospheric hazard aura (outer diffuse glow)
    final Paint auraPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0
      ..color = accentColor.withValues(alpha: 0.08);
    canvas.drawOval(boundaryRect, auraPaint);

    // 2. Focused barrier glow
    final Paint ringGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = accentColor.withValues(alpha: 0.26);
    canvas.drawOval(boundaryRect, ringGlow);

    // 3. Crisp neon filament
    final Paint coreBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Color.lerp(Colors.white, accentColor, 0.4)!.withValues(alpha: 0.85);
    canvas.drawOval(boundaryRect, coreBorder);

    // 4. Sinusoidal electric plasma arcing along the perimeter ring
    final int arcSegments = 64;
    final Path electricArc = Path();
    for (int i = 0; i <= arcSegments; i++) {
      final double theta = i * 2 * math.pi / arcSegments;
      final double noise = math.sin(theta * 12.0 + animationProgress * 6 * math.pi) * 2.5;
      final double px = cx + (rx + noise) * math.cos(theta);
      final double py = cy + (ry + noise * 0.6) * math.sin(theta);
      if (i == 0) {
        electricArc.moveTo(px, py);
      } else {
        electricArc.lineTo(px, py);
      }
    }

    final Paint arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = accentColor.withValues(alpha: 0.45 + 0.25 * math.sin(animationProgress * 4 * math.pi));
    canvas.drawPath(electricArc, arcPaint);

    // 5. Eight perimeter aether crystal pylons
    final int pylonCount = 8;
    final Paint pylonPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    final Paint pylonGlow = Paint()
      ..color = accentColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    for (int i = 0; i < pylonCount; i++) {
      final double pAngle = i * 2 * math.pi / pylonCount;
      final double px = cx + rx * math.cos(pAngle);
      final double py = cy + ry * math.sin(pAngle);

      canvas.drawCircle(Offset(px, py), 2.8, pylonPaint);
      canvas.drawCircle(Offset(px, py), 4.8, pylonGlow);
    }
  }

  // ── INSCRIBED RUNIC PROJECTIONS ─────────────────────────────────────────────
  void _paintRunicProjections(Canvas canvas, Size size, double cx, double cy) {
    final double w = size.width;
    final double h = size.height;

    final double runeRadiusX = w * 0.26;
    final double runeRadiusY = h * 0.16;

    // 1. Dual Inscribed Circles with Runic Gap
    final Paint runeRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = accentColor.withValues(alpha: 0.65);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: runeRadiusX * 2, height: runeRadiusY * 2),
      runeRingPaint,
    );

    final Paint innerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = accentColor.withValues(alpha: 0.40);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: runeRadiusX * 1.5, height: runeRadiusY * 1.5),
      innerRingPaint,
    );

    // 2. Rotating Astrological & Arcane Glyph Nodes
    final int glyphCount = 8;
    final double rotation = animationProgress * 2 * math.pi;

    final Paint glyphPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    final Paint chordPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final List<Offset> glyphOffsets = <Offset>[];

    for (int i = 0; i < glyphCount; i++) {
      final double angle = (i * 2 * math.pi / glyphCount) + rotation;
      final double gx = cx + math.cos(angle) * runeRadiusX;
      final double gy = cy + math.sin(angle) * runeRadiusY;
      final Offset gPos = Offset(gx, gy);
      glyphOffsets.add(gPos);

      // Node point with aura
      canvas.drawCircle(gPos, 2.2, glyphPaint);
      canvas.drawCircle(
        gPos,
        4.0,
        Paint()
          ..color = accentColor.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    // Connect opposing glyphs via mystical constellation chords
    for (int i = 0; i < 4; i++) {
      canvas.drawLine(glyphOffsets[i], glyphOffsets[i + 4], chordPaint);
    }

    // 3. Concentric Inscribed Octagram / Star Polygon in the Center
    final double starRadiusX = runeRadiusX * 0.45;
    final double starRadiusY = runeRadiusY * 0.45;
    final Path starPath = Path();
    for (int i = 0; i < 8; i++) {
      final double r = i.isEven ? 1.0 : 0.55;
      final double a = (i * math.pi / 4.0) - rotation;
      final double sx = cx + math.cos(a) * starRadiusX * r;
      final double sy = cy + math.sin(a) * starRadiusY * r;
      if (i == 0) starPath.moveTo(sx, sy); else starPath.lineTo(sx, sy);
    }
    starPath.close();

    final Paint starPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = accentColor.withValues(alpha: 0.55);
    canvas.drawPath(starPath, starPaint);

    // 4. Volumetric Upright Rune Light Shafts (Ascending into sky from 4 cardinal nodes)
    for (int k = 0; k < 4; k++) {
      final Offset node = glyphOffsets[k * 2];
      final double beamHeight = h * 0.35;

      final Paint beamPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[
            accentColor.withValues(alpha: 0.38),
            accentColor.withValues(alpha: 0.12),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(node.dx - 4, node.dy - beamHeight, 8, beamHeight));

      final Path beamPath = Path()
        ..moveTo(node.dx - 3, node.dy)
        ..lineTo(node.dx + 3, node.dy)
        ..lineTo(node.dx + 1.5, node.dy - beamHeight)
        ..lineTo(node.dx - 1.5, node.dy - beamHeight)
        ..close();
      canvas.drawPath(beamPath, beamPaint);
    }
  }

  // ── FLOATING BASALT MONOLITHS ───────────────────────────────────────────────
  void _paintFloatingMonoliths(Canvas canvas, Size size, double cx, double cy) {
    final double w = size.width;
    final double h = size.height;

    final List<Offset> stoneCenters = <Offset>[
      Offset(w * 0.12, h * (0.35 + 0.035 * math.sin(animationProgress * 2 * math.pi))),
      Offset(w * 0.88, h * (0.32 + 0.035 * math.cos(animationProgress * 2 * math.pi))),
      Offset(w * 0.20, h * (0.76 + 0.025 * math.cos((animationProgress + 0.5) * 2 * math.pi))),
      Offset(w * 0.80, h * (0.73 + 0.025 * math.sin((animationProgress + 0.5) * 2 * math.pi))),
    ];

    for (int i = 0; i < stoneCenters.length; i++) {
      final Offset sc = stoneCenters[i];

      // Cast ground shadow beneath floating monolith
      final double groundY = cy + (sc.dy - cy) * 0.8 + 25.0;
      final Paint shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(sc.dx, groundY), width: 22.0, height: 8.0),
        shadowPaint,
      );

      // Faceted basalt stone polygon
      final Path stone = Path();
      stone.moveTo(sc.dx, sc.dy - 15);
      stone.lineTo(sc.dx + 13, sc.dy - 4);
      stone.lineTo(sc.dx + 9, sc.dy + 13);
      stone.lineTo(sc.dx - 9, sc.dy + 15);
      stone.lineTo(sc.dx - 13, sc.dy - 2);
      stone.close();

      // Base stone fill
      final Paint stonePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const <Color>[
            Color(0xFF282F48),
            Color(0xFF141825),
            Color(0xFF0C0F17),
          ],
        ).createShader(Rect.fromCenter(center: sc, width: 26, height: 30));
      canvas.drawPath(stone, stonePaint);

      // Glowing rune border
      final Paint stoneBorder = Paint()
        ..color = accentColor.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawPath(stone, stoneBorder);

      // Inscribed glowing glyph inside stone
      final Paint innerGlyph = Paint()
        ..color = accentColor.withValues(alpha: 0.75)
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(sc.dx - 4, sc.dy - 3), Offset(sc.dx + 4, sc.dy + 3), innerGlyph);
      canvas.drawLine(Offset(sc.dx, sc.dy - 6), Offset(sc.dx, sc.dy + 6), innerGlyph);
    }
  }

  // ── GLADIATOR COMBAT FIGURES ────────────────────────────────────────────────
  void _paintGladiatorFigures(
    Canvas canvas,
    Size size,
    List<GladiatorShadowSlot> slots,
    ArenaLightingTheme theme,
    double cx,
    double cy,
  ) {
    final double w = size.width;
    final double h = size.height;

    for (int i = 0; i < slots.length; i++) {
      final GladiatorShadowSlot slot = slots[i];
      final double gx = slot.position.dx * w + slot.lungeOffset.dx + cameraYaw * 8.0;
      final double gy = slot.position.dy * h + slot.lungeOffset.dy + cameraPitch * 5.0;
      final bool isChallenger = i == 0;

      final Color armorColor = isChallenger
          ? const Color(0xFFE53935)
          : const Color(0xFF1E88E5);

      // Body silhouette shader
      final Paint gladiatorPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white,
            armorColor,
            const Color(0xFF0F1420),
          ],
          stops: const <double>[0.0, 0.45, 1.0],
        ).createShader(Rect.fromLTWH(gx - 12, gy - slot.height, 24, slot.height));

      // Torso & dynamic battle cape
      final Path torso = Path();
      torso.moveTo(gx, gy - slot.height * 0.72);
      torso.lineTo(gx + (isChallenger ? 9 : -9), gy - slot.height * 0.45);
      torso.lineTo(gx + (isChallenger ? 6 : -6), gy - 4);
      torso.lineTo(gx - (isChallenger ? 6 : -6), gy - 4);
      torso.lineTo(gx - (isChallenger ? 9 : -9), gy - slot.height * 0.45);
      torso.close();
      canvas.drawPath(torso, gladiatorPaint);

      // Helmet & crest highlight
      canvas.drawCircle(
        Offset(gx, gy - slot.height * 0.85),
        6.5,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );

      // Weapon blade glowing with theme sun reflection
      final double weaponTipX = gx + (isChallenger ? 18 : -18);
      final double weaponTipY = gy - slot.height * 0.58;
      final Paint weaponPaint = Paint()
        ..color = theme.sunColor
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(gx + (isChallenger ? 5 : -5), gy - slot.height * 0.45),
        Offset(weaponTipX, weaponTipY),
        weaponPaint,
      );

      // Rim light highlight reacting to sun
      final Paint rimHighlight = Paint()
        ..color = theme.sunColor.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(Offset(gx, gy - slot.height * 0.85), 6.5, rimHighlight);
    }
  }

  // ── AMBIENT LIGHTING JUICE & VIGNETTE ───────────────────────────────────────
  void _paintAmbientLightingJuice(Canvas canvas, Size size, double cx, double cy) {
    final double w = size.width;
    final double h = size.height;

    // Floor aether mist layer
    final Paint mistPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          accentColor.withValues(alpha: 0.12),
          accentColor.withValues(alpha: 0.04),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.55, 1.0],
      ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: w * 0.95, height: h * 0.65));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.4, w, h * 0.6), mistPaint);

    // Dynamic combat lighting flash on impact
    if (combatFlashIntensity > 0.001) {
      final Paint flashPaint = Paint()
        ..color = Colors.white.withValues(alpha: (combatFlashIntensity * 0.4).clamp(0.0, 0.4));
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), flashPaint);
    }

    // Top-to-bottom cinematic vignette
    final Paint vignettePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.black.withValues(alpha: 0.5),
          Colors.transparent,
          Colors.transparent,
          Colors.black.withValues(alpha: 0.65),
        ],
        stops: const <double>[0.0, 0.25, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), vignettePaint);
  }

  @override
  bool shouldRepaint(covariant ArenaBattlefieldPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.lightingTheme != lightingTheme ||
        oldDelegate.cameraPitch != cameraPitch ||
        oldDelegate.cameraYaw != cameraYaw ||
        oldDelegate.combatFlashIntensity != combatFlashIntensity ||
        oldDelegate.shockwaveProgress != shockwaveProgress ||
        oldDelegate.shockwaveCenter != shockwaveCenter ||
        oldDelegate.externalDecals.length != externalDecals.length;
  }
}

/// Mobile Portrait & Landscape Arena Map Viewport widget.
/// Offers full 3D camera pan/tilt interaction, ground decals, battle ambient lighting,
/// animated rune projections, arena ring hazard glow, and gladiator hero stance preview.
class ArenaMapViewport extends StatefulWidget {
  const ArenaMapViewport({
    super.key,
    this.currentRating = 1000,
    this.onEnterArena,
    this.onChallengeQuickDuel,
  });

  final int currentRating;
  final VoidCallback? onEnterArena;
  final VoidCallback? onChallengeQuickDuel;

  @override
  State<ArenaMapViewport> createState() => _ArenaMapViewportState();
}

class _ArenaMapViewportState extends State<ArenaMapViewport>
    with TickerProviderStateMixin {
  late AnimationController _anim;
  late AnimationController _flashAnim;
  late AnimationController _shockwaveAnim;

  int _activeArenaIndex = 0;
  GladiatorStance _heroStance = GladiatorStance.combatReady;

  // Interactive 3D camera angles
  double _cameraYaw = 0.0;
  double _cameraPitch = 0.0;
  Offset _lastTapPosition = Offset.zero;

  // Ground Decal System for battle impact marks
  late GroundDecalSystem _decalSystem;

  @override
  void initState() {
    super.initState();
    _decalSystem = GroundDecalSystem(maxDecals: 24);

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _flashAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _shockwaveAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _seedInitialDecals();
  }

  void _seedInitialDecals() {
    // Seed atmospheric arena marks
    _decalSystem.spawnScorchMark(
      position: const Vector3D(0.0, 0.0, 0.0),
      radius: 2.2,
      depth: 1.0,
      lifetime: 0.0, // persistent
    );
    _decalSystem.spawnSlashGouge(
      position: const Vector3D(-1.2, 0.0, 0.5),
      strikeDirection: const Vector3D(1.0, 0.0, -0.6),
      length: 2.4,
      lifetime: 0.0,
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    _flashAnim.dispose();
    _shockwaveAnim.dispose();
    super.dispose();
  }

  void _onArenaTap(TapUpDetails details, Size size) {
    HapticFeedback.mediumImpact();
    setState(() {
      _lastTapPosition = details.localPosition;
      // Cycle gladiator stance to attack on tap
      _heroStance = GladiatorStance.attacking;
    });

    _flashAnim.forward(from: 0.0);
    _shockwaveAnim.forward(from: 0.0);

    // Normalized floor coordinates (-1.0 to 1.0)
    final double nx = ((details.localPosition.dx / size.width) - 0.5) * 2.0;
    final double nz = ((details.localPosition.dy / size.height) - 0.58) * 2.5;

    // Spawn a ground decal at tapped point
    if (_activeArenaIndex.isEven) {
      _decalSystem.spawnScorchMark(
        position: Vector3D(nx * 3.0, 0.0, nz * 3.0),
        radius: 1.6,
        lifetime: 8.0,
        fadeDuration: 2.5,
      );
    } else {
      _decalSystem.spawnCrackedEarth(
        position: Vector3D(nx * 3.0, 0.0, nz * 3.0),
        radius: 2.0,
        lifetime: 9.0,
        fadeDuration: 3.0,
      );
    }

    // Reset gladiator back to combat ready after attack lunge
    Future<void>.delayed(const Duration(milliseconds: 750), () {
      if (mounted) {
        setState(() {
          _heroStance = GladiatorStance.combatReady;
        });
      }
    });
  }

  void _resetCamera() {
    HapticFeedback.selectionClick();
    setState(() {
      _cameraYaw = 0.0;
      _cameraPitch = 0.0;
    });
  }

  void _cycleStance() {
    HapticFeedback.lightImpact();
    setState(() {
      switch (_heroStance) {
        case GladiatorStance.idle:
          _heroStance = GladiatorStance.combatReady;
          break;
        case GladiatorStance.combatReady:
          _heroStance = GladiatorStance.attacking;
          break;
        case GladiatorStance.attacking:
          _heroStance = GladiatorStance.victory;
          break;
        case GladiatorStance.victory:
        case GladiatorStance.hitReact:
        case GladiatorStance.defeated:
          _heroStance = GladiatorStance.combatReady;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isLandscape = constraints.maxWidth > 520;
        final ArenaThemeInfo currentArena = defaultArenaThemes[_activeArenaIndex];

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: currentArena.accentColor.withValues(alpha: 0.40),
              width: 1.4,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.75),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: currentArena.accentColor.withValues(alpha: 0.12),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: isLandscape
              ? _buildLandscapeViewport(currentArena)
              : _buildPortraitViewport(currentArena),
        );
      },
    );
  }

  Widget _buildPortraitViewport(ArenaThemeInfo currentArena) {
    return Column(
      children: <Widget>[
        // Visual Arena Map Canvas (210px depth height)
        SizedBox(
          height: 210,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Size canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

              return GestureDetector(
                onTapUp: (TapUpDetails details) => _onArenaTap(details, canvasSize),
                onPanUpdate: (DragUpdateDetails details) {
                  setState(() {
                    _cameraYaw = (_cameraYaw + details.delta.dx * 0.08).clamp(-1.5, 1.5);
                    _cameraPitch = (_cameraPitch - details.delta.dy * 0.06).clamp(-1.0, 1.0);
                  });
                },
                child: Stack(
                  children: <Widget>[
                    // Animated Custom Canvas Painter with 3D Perspective
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: Listenable.merge(<Listenable>[_anim, _flashAnim, _shockwaveAnim]),
                        builder: (BuildContext context, Widget? child) {
                          final double flash = (1.0 - _flashAnim.value) * 0.7;
                          return CustomPaint(
                            painter: ArenaBattlefieldPainter(
                              animationProgress: _anim.value,
                              accentColor: currentArena.accentColor,
                              lightingTheme: currentArena.effectiveLightingTheme,
                              cameraPitch: _cameraPitch,
                              cameraYaw: _cameraYaw,
                              combatFlashIntensity: flash,
                              shockwaveProgress: _shockwaveAnim.value,
                              shockwaveCenter: _lastTapPosition,
                              externalDecals: _decalSystem.activeDecals.toList(),
                            ),
                          );
                        },
                      ),
                    ),

                    // Center 3D Gladiator Hero on Colosseum Duel Platform
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: PvpGladiator3dView(
                          gladiatorClass: currentArena.gladiatorClass,
                          weapon: currentArena.weapon,
                          stance: _heroStance,
                          accentColor: currentArena.accentColor,
                          facingRight: true,
                          size: const Size(130, 150),
                          interactiveRotation: true,
                        ),
                      ),
                    ),

                    // Top Header Overlay: Arena Name & Rating Badges
                    Positioned(
                      top: 10,
                      left: 12,
                      right: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          // Left: Arena Name Badge
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.70),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: currentArena.accentColor.withValues(alpha: 0.7),
                                  width: 0.9,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(currentArena.icon, size: 14, color: currentArena.accentColor),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      currentArena.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: currentArena.accentColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Right: Rating & Stance Indicator
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              GestureDetector(
                                onTap: _cycleStance,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.70),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: currentArena.accentColor.withValues(alpha: 0.5),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const Icon(Icons.touch_app_rounded, size: 12, color: Colors.white70),
                                      const SizedBox(width: 4),
                                      Text(
                                        _heroStance == GladiatorStance.attacking
                                            ? 'Saldırı!'
                                            : _heroStance == GladiatorStance.victory
                                                ? 'Zafer'
                                                : 'Duruş',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.70),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.6), width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Icon(Icons.military_tech_rounded, size: 12, color: Colors.amber),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${widget.currentRating}',
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
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

                    // Camera Reset Button (visible when tilted)
                    if (_cameraYaw.abs() > 0.1 || _cameraPitch.abs() > 0.1)
                      Positioned(
                        bottom: 24,
                        right: 12,
                        child: GestureDetector(
                          onTap: _resetCamera,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white38, width: 0.8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(Icons.refresh_rounded, size: 11, color: Colors.white70),
                                SizedBox(width: 4),
                                Text(
                                  'Kamera',
                                  style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Bottom Carousel Selector Dots
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List<Widget>.generate(
                          defaultArenaThemes.length,
                          (int index) => GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _activeArenaIndex = index);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: _activeArenaIndex == index ? 18 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _activeArenaIndex == index
                                    ? currentArena.accentColor
                                    : Colors.white30,
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: _activeArenaIndex == index
                                    ? <BoxShadow>[
                                        BoxShadow(
                                          color: currentArena.accentColor.withValues(alpha: 0.8),
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : null,
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
        ),

        // Arena Footer: Subtitle, Environmental Hazard & Quick Action
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: const Color(0xFF0F131E),
          child: Row(
            children: <Widget>[
              // Left: Subtitle & Hazard preview
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      currentArena.subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        Icon(Icons.warning_amber_rounded, size: 11, color: currentArena.accentColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${currentArena.hazardTitle}: ${currentArena.hazardModifier}',
                            style: TextStyle(
                              color: currentArena.accentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Right: Enter Arena CTA
              if (widget.onEnterArena != null)
                InkWell(
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    widget.onEnterArena!();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: currentArena.accentColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: currentArena.accentColor,
                        width: 1.1,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: currentArena.accentColor.withValues(alpha: 0.25),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Arenaya Gir',
                          style: TextStyle(
                            color: currentArena.accentColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: currentArena.accentColor,
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

  Widget _buildLandscapeViewport(ArenaThemeInfo currentArena) {
    return SizedBox(
      height: 195,
      child: Row(
        children: <Widget>[
          // Left: Panoramic Canvas (flex 3)
          Expanded(
            flex: 3,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Size canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

                return GestureDetector(
                  onTapUp: (TapUpDetails details) => _onArenaTap(details, canvasSize),
                  onPanUpdate: (DragUpdateDetails details) {
                    setState(() {
                      _cameraYaw = (_cameraYaw + details.delta.dx * 0.08).clamp(-1.5, 1.5);
                      _cameraPitch = (_cameraPitch - details.delta.dy * 0.06).clamp(-1.0, 1.0);
                    });
                  },
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: Listenable.merge(<Listenable>[_anim, _flashAnim, _shockwaveAnim]),
                          builder: (BuildContext context, Widget? child) {
                            final double flash = (1.0 - _flashAnim.value) * 0.7;
                            return CustomPaint(
                              painter: ArenaBattlefieldPainter(
                                animationProgress: _anim.value,
                                accentColor: currentArena.accentColor,
                                lightingTheme: currentArena.effectiveLightingTheme,
                                cameraPitch: _cameraPitch,
                                cameraYaw: _cameraYaw,
                                combatFlashIntensity: flash,
                                shockwaveProgress: _shockwaveAnim.value,
                                shockwaveCenter: _lastTapPosition,
                                externalDecals: _decalSystem.activeDecals.toList(),
                              ),
                            );
                          },
                        ),
                      ),

                      // Single Center 3D Gladiator Hero on Colosseum Duel Platform
                      Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: PvpGladiator3dView(
                            gladiatorClass: currentArena.gladiatorClass,
                            weapon: currentArena.weapon,
                            stance: _heroStance,
                            accentColor: currentArena.accentColor,
                            facingRight: true,
                            size: const Size(120, 140),
                            interactiveRotation: true,
                          ),
                        ),
                      ),

                      // Header Name Badge
                      Positioned(
                        top: 10,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: currentArena.accentColor.withValues(alpha: 0.65),
                              width: 0.9,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(currentArena.icon, size: 13, color: currentArena.accentColor),
                              const SizedBox(width: 5),
                              Text(
                                currentArena.name,
                                style: TextStyle(
                                  color: currentArena.accentColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Camera reset button
                      if (_cameraYaw.abs() > 0.1 || _cameraPitch.abs() > 0.1)
                        Positioned(
                          bottom: 10,
                          right: 12,
                          child: GestureDetector(
                            onTap: _resetCamera,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.70),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white38, width: 0.8),
                              ),
                              child: const Icon(Icons.refresh_rounded, size: 12, color: Colors.white70),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Right: Tactical Details & Mobile Action (flex 2)
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF0F131E),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(currentArena.icon, size: 14, color: currentArena.accentColor),
                              const SizedBox(width: 5),
                              const Text(
                                'ARENA MODU',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 0.8),
                            ),
                            child: Text(
                              '${widget.currentRating}',
                              style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currentArena.subtitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Hazard card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: currentArena.accentColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: currentArena.accentColor.withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.warning_amber_rounded, size: 11, color: currentArena.accentColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${currentArena.hazardTitle}: ${currentArena.hazardModifier}',
                                style: TextStyle(
                                  color: currentArena.accentColor,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Enter Button
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        widget.onEnterArena?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentArena.accentColor,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'Arenaya Gir',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
