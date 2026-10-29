import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// =============================================================================
// BOYUT SABİTLERİ (LAYOUT CONSTANTS)
// =============================================================================
const double kVictoryBgWidth  = 380.0;
const double kVictoryBgHeight = 380.0;

// =============================================================================
// ROZET SABİTLERİ (BADGE CONSTANTS)
// =============================================================================
const double kBadgePositionTop       = 160.0;
const double kBadgeStripeWidth       = 378.0;
const double kBadgeStripeHeight      = 78.0;
const double kBadgeWidth             = 49.0;
const double kBadgeHeight            = 51.0;
const double kBadgeGapBetween        = 12.0;
const double kBadgePaddingVertical   = 3.0;
const double kBadgePaddingHorizontal = 2.0;
const double kBadgeBorderRadius      = 6.0;
const double kBadgeBorderWidth       = 1.0;
const double kBadgeShadowBlur        = 4.0;
const double kBadgeShadowBlur2       = 1.0;
const double kBadgeIconFontSize      = 11.0;
const double kBadgeValueFontSize     = 10.0;
const double kBadgeLabelFontSize     = 6.0;
const double kBadgeSubFontSize       = 6.0;

// =============================================================================
// GLOW / IŞIK HÜZMESİ SABİTLERİ (RAY & GLOW CONSTANTS)
// =============================================================================

/// Hüzmelerin görüntü kenarlarından ne kadar dışarı uzandığı (px)
const double kRayOverflow = 80.0;

/// Glow overlay rengi (altın)
const Color kGlowColor = Color(0xFFFFD700);

/// Yumuşak aura blur yarıçapı
const double kAuraBlurRadius = 24.0;

/// Glow min/max opaklığı (pulse sırasında)
const double kGlowOpacityMin = 0.045;
const double kGlowOpacityMax = 0.105;

/// Hüzme sayısı
const int kRayCount = 18;

/// Hüzme min/max opaklığı
const double kRayOpacityMin = 0.04;
const double kRayOpacityMax = 0.22;

/// Hüzme yarı-açısı (rad) — büyütünce hüzmeler kalınlaşır
const double kRayHalfAngle = 0.045;

/// Hüzme başlangıç yarıçapı (ikon merkezinden)
const double kRayInnerRadiusFactor = 0.31;

/// Hüzme bitiş yarıçapı (ikon merkezinden)
const double kRayOuterRadiusFactor = 0.68;

/// Hüzmeler her döngüde ne kadar döner (2π'nin kesri)
const double kRayRotationFraction = 0.06;

/// Glow pulse süresi (ms)
const int kGlowPulseDurationMs = 2400;

/// Görüntü köşe yuvarlaklığı
const double kFrameInnerRadius = 6.0;

// =============================================================================
// SES & HAPTIC ZAMANLAMA ORKESTRASYONU (TRIUMPHANT SOUND & HAPTIC CUES)
// =============================================================================

/// Zafere eşlik eden sinematik ses/efekt tetikleyicileri
enum VictoryCueType {
  fanfareHerald,     // t=0ms: Giriş boru/orkestra fanfarı
  rankStampImpact,   // t=380ms: Damga vuruluş anı ve sarsıntı
  chestAuraIgnite,   // t=750ms: Sandık ışıma ve mistik aura rezonansı
  coinFountainSpray, // t=1100ms: Altın sikke patlaması ve fıskiye şıkırtısı
  expBarCharge,      // t=1500ms: Deneyim barı dolumu ve hızlanan enerji
  levelUpFlourish,   // t=2200ms: Seviye atlama kutlama patlaması
  victoryChimeDecay, // t=2800ms: Kristal tınlama ve sönüm
}

/// Zafer kutlama ses ve titreşim yöneticisi
class VictorySoundCueCoordinator {
  const VictorySoundCueCoordinator._();

  /// Her bir cue için dokunsal geri bildirim motoru
  static Future<void> triggerHaptic(VictoryCueType cue) async {
    switch (cue) {
      case VictoryCueType.fanfareHerald:
        await HapticFeedback.heavyImpact();
        break;
      case VictoryCueType.rankStampImpact:
        await HapticFeedback.heavyImpact();
        break;
      case VictoryCueType.chestAuraIgnite:
        await HapticFeedback.mediumImpact();
        break;
      case VictoryCueType.coinFountainSpray:
        await HapticFeedback.selectionClick();
        break;
      case VictoryCueType.expBarCharge:
        await HapticFeedback.lightImpact();
        break;
      case VictoryCueType.levelUpFlourish:
        await HapticFeedback.vibrate();
        break;
      case VictoryCueType.victoryChimeDecay:
        await HapticFeedback.lightImpact();
        break;
    }
  }

  /// Belirlenen zaman çizelgesine göre cue'ları otomatik tetikler
  static List<Timer> scheduleVictorySequence({
    required void Function(VictoryCueType cue)? onSoundCue,
    bool enableHaptics = true,
  }) {
    final timers = <Timer>[];
    final schedule = <VictoryCueType, int>{
      VictoryCueType.fanfareHerald: 0,
      VictoryCueType.rankStampImpact: 380,
      VictoryCueType.chestAuraIgnite: 720,
      VictoryCueType.coinFountainSpray: 1050,
      VictoryCueType.expBarCharge: 1450,
      VictoryCueType.levelUpFlourish: 2200,
      VictoryCueType.victoryChimeDecay: 2800,
    };

    schedule.forEach((cue, delayMs) {
      final timer = Timer(Duration(milliseconds: delayMs), () {
        if (enableHaptics) {
          triggerHaptic(cue);
        }
        onSoundCue?.call(cue);
      });
      timers.add(timer);
    });

    return timers;
  }
}

// =============================================================================
// DUNGEON RANK STAMP TIER (RATING FANFARE SYSTEM)
// =============================================================================

enum DungeonRankTier {
  sPlus,
  s,
  a,
  b,
  c;

  String get label {
    switch (this) {
      case DungeonRankTier.sPlus:
        return 'S+';
      case DungeonRankTier.s:
        return 'S';
      case DungeonRankTier.a:
        return 'A';
      case DungeonRankTier.b:
        return 'B';
      case DungeonRankTier.c:
        return 'C';
    }
  }

  Color get primaryColor {
    switch (this) {
      case DungeonRankTier.sPlus:
        return const Color(0xFFFFD700); // Divine Gold
      case DungeonRankTier.s:
        return const Color(0xFFF59E0B); // Radiant Amber
      case DungeonRankTier.a:
        return const Color(0xFFA855F7); // Royal Purple
      case DungeonRankTier.b:
        return const Color(0xFF38BDF8); // Astral Azure
      case DungeonRankTier.c:
        return const Color(0xFF94A3B8); // Knight Steel
    }
  }

  Color get secondaryColor {
    switch (this) {
      case DungeonRankTier.sPlus:
        return const Color(0xFFFF3366); // Celestial Crimson Core
      case DungeonRankTier.s:
        return const Color(0xFFEF4444); // Scarlet Flame
      case DungeonRankTier.a:
        return const Color(0xFF3B82F6); // Sapphire Blue
      case DungeonRankTier.b:
        return const Color(0xFF10B981); // Emerald Teal
      case DungeonRankTier.c:
        return const Color(0xFF64748B); // Slate Iron
    }
  }

  static DungeonRankTier fromString(String? raw) {
    if (raw == null) return DungeonRankTier.s;
    final clean = raw.trim().toUpperCase();
    if (clean == 'S+' || clean == 'SS') return DungeonRankTier.sPlus;
    if (clean == 'S') return DungeonRankTier.s;
    if (clean == 'A') return DungeonRankTier.a;
    if (clean == 'B') return DungeonRankTier.b;
    if (clean == 'C' || clean == 'D') return DungeonRankTier.c;
    return DungeonRankTier.s;
  }
}

// =============================================================================
// CHEST RARITY TIERS (LEGENDARY LOOT CHEST GLOW AURA)
// =============================================================================

enum ChestRarity {
  rare,
  epic,
  legendary,
  mythic;

  Color get primaryColor {
    switch (this) {
      case ChestRarity.rare:
        return const Color(0xFF38BDF8); // Frost Azure
      case ChestRarity.epic:
        return const Color(0xFFC084FC); // Arcane Purple
      case ChestRarity.legendary:
        return const Color(0xFFFFD700); // Imperial Gold
      case ChestRarity.mythic:
        return const Color(0xFFFF007A); // Celestial Prismatic Pink
    }
  }

  Color get secondaryColor {
    switch (this) {
      case ChestRarity.rare:
        return const Color(0xFF0284C7);
      case ChestRarity.epic:
        return const Color(0xFF7E22CE);
      case ChestRarity.legendary:
        return const Color(0xFFD97706);
      case ChestRarity.mythic:
        return const Color(0xFF9333EA);
    }
  }
}

// =============================================================================
// 1. GOLD COIN BURST & SHOWER SIMULATION (PARABOLIC PHYSICS & 3D FLIP)
// =============================================================================

class _CoinParticle {
  _CoinParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.rotation,
    required this.rotationSpeed,
    required this.flipAngle,
    required this.flipSpeed,
    required this.sparklePhase,
    required this.lifetime,
  }) : age = 0.0,
       isDead = false;

  double x;
  double y;
  double vx;
  double vy;
  double radius;
  double rotation;
  double rotationSpeed;
  double flipAngle;
  double flipSpeed;
  double sparklePhase;
  double lifetime;
  double age;
  bool isDead;

  void update(double dt) {
    age += dt;
    if (age >= lifetime) {
      isDead = true;
      return;
    }

    // Parabolik yerçekimi ivmesi
    vy += 620.0 * dt;
    x += vx * dt;
    y += vy * dt;

    // Hava sürtünmesi
    vx *= 0.985;

    // Dönüş ve 3B madeni para yüz taklası
    rotation += rotationSpeed * dt;
    flipAngle += flipSpeed * dt;
    sparklePhase += dt * 3.5;

    // Yerden hafif zıplama efekti
    if (y > 280.0 && vy > 0) {
      vy = -vy * 0.42;
      vx *= 0.8;
      y = 280.0;
    }
  }

  double get opacity {
    final progress = age / lifetime;
    if (progress < 0.15) return progress / 0.15;
    if (progress > 0.75) return (1.0 - progress) / 0.25;
    return 1.0;
  }
}

/// Altın sikke patlaması görsel bileşeni
class GoldCoinBurstOverlay extends StatefulWidget {
  const GoldCoinBurstOverlay({
    super.key,
    this.coinCount = 36,
    this.spawnCenter = const Offset(190.0, 195.0),
    this.autoStart = true,
  });

  final int coinCount;
  final Offset spawnCenter;
  final bool autoStart;

  @override
  State<GoldCoinBurstOverlay> createState() => GoldCoinBurstOverlayState();
}

class GoldCoinBurstOverlayState extends State<GoldCoinBurstOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final List<_CoinParticle> _coins = <_CoinParticle>[];
  final Random _rng = Random(42);
  DateTime? _lastTick;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onTick);

    if (widget.autoStart) {
      triggerBurst();
    }
  }

  void triggerBurst() {
    _coins.clear();
    for (int i = 0; i < widget.coinCount; i++) {
      final angle = -pi / 2 + (_rng.nextDouble() - 0.5) * 1.65;
      final speed = 220.0 + _rng.nextDouble() * 340.0;
      _coins.add(
        _CoinParticle(
          x: widget.spawnCenter.dx + (_rng.nextDouble() - 0.5) * 24.0,
          y: widget.spawnCenter.dy + (_rng.nextDouble() - 0.5) * 12.0,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          radius: 6.5 + _rng.nextDouble() * 5.0,
          rotation: _rng.nextDouble() * 2 * pi,
          rotationSpeed: (_rng.nextDouble() - 0.5) * 9.0,
          flipAngle: _rng.nextDouble() * 2 * pi,
          flipSpeed: 5.0 + _rng.nextDouble() * 9.0,
          sparklePhase: _rng.nextDouble() * 2 * pi,
          lifetime: 1.6 + _rng.nextDouble() * 0.9,
        ),
      );
    }
    _lastTick = DateTime.now();
    _ticker.repeat();
  }

  void _onTick() {
    final now = DateTime.now();
    final dt = _lastTick != null
        ? (now.difference(_lastTick!).inMicroseconds / 1000000.0).clamp(0.001, 0.05)
        : 0.016;
    _lastTick = now;

    for (final coin in _coins) {
      coin.update(dt);
    }
    _coins.removeWhere((c) => c.isDead);

    if (_coins.isEmpty) {
      _ticker.stop();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_coins.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _GoldCoinBurstPainter(coins: _coins),
      ),
    );
  }
}

class _GoldCoinBurstPainter extends CustomPainter {
  const _GoldCoinBurstPainter({required this.coins});

  final List<_CoinParticle> coins;

  @override
  void paint(Canvas canvas, Size size) {
    for (final coin in coins) {
      final double alpha = coin.opacity;
      if (alpha <= 0.01) continue;

      canvas.save();
      canvas.translate(coin.x, coin.y);
      canvas.rotate(coin.rotation);

      // 3B dikey yüz taklası (flip)
      final double scaleY = cos(coin.flipAngle).abs().clamp(0.08, 1.0);
      canvas.scale(1.0, scaleY);

      // Altın Sikke Gövdesi
      final Rect coinRect = Rect.fromCircle(
        center: Offset.zero,
        radius: coin.radius,
      );

      final rimPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFF078).withValues(alpha: alpha),
            const Color(0xFFF59E0B).withValues(alpha: alpha),
            const Color(0xFF92400E).withValues(alpha: alpha),
          ],
        ).createShader(coinRect);

      final innerPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFDE68A).withValues(alpha: alpha),
            const Color(0xFFD97706).withValues(alpha: alpha * 0.95),
            const Color(0xFF78350F).withValues(alpha: alpha * 0.9),
          ],
        ).createShader(coinRect);

      // Gölge
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: alpha * 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawCircle(const Offset(0, 1.8), coin.radius * 0.95, shadowPaint);

      // Dış kenar
      canvas.drawCircle(Offset.zero, coin.radius, rimPaint);
      // İç hazne
      canvas.drawCircle(Offset.zero, coin.radius * 0.78, innerPaint);

      // Merkez kabartma yıldız/sembol
      if (scaleY > 0.35) {
        final symbolPaint = Paint()
          ..color = const Color(0xFFFFFBEB).withValues(alpha: alpha * 0.85)
          ..style = PaintingStyle.fill;
        final double starR = coin.radius * 0.42;
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: starR * 0.9, height: starR * 0.3),
          symbolPaint,
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: starR * 0.3, height: starR * 0.9),
          symbolPaint,
        );
      }

      // Parıltı kıvılcımı (Glint Sparkle)
      final double glintSin = sin(coin.sparklePhase);
      if (glintSin > 0.7) {
        final double glintAlpha = ((glintSin - 0.7) / 0.3).clamp(0.0, 1.0) * alpha;
        final glintPaint = Paint()
          ..color = Colors.white.withValues(alpha: glintAlpha)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;

        final double glintLen = coin.radius * 1.4;
        canvas.drawLine(Offset(-glintLen, 0), Offset(glintLen, 0), glintPaint);
        canvas.drawLine(Offset(0, -glintLen), Offset(0, glintLen), glintPaint);

        canvas.drawCircle(
          Offset.zero,
          coin.radius * 0.35,
          Paint()..color = const Color(0xFFFFFBEB).withValues(alpha: glintAlpha * 0.9),
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _GoldCoinBurstPainter oldDelegate) => true;
}

// =============================================================================
// 2. SHIMMER SHADERS & PARTICLE SHOWERS (AURAS & LIGHT SPECULARITIES)
// =============================================================================

class _ShimmerStar {
  _ShimmerStar({
    required this.x,
    required this.y,
    required this.size,
    required this.baseAlpha,
    required this.phase,
    required this.speed,
    required this.driftX,
  });

  double x;
  double y;
  final double size;
  final double baseAlpha;
  double phase;
  final double speed;
  final double driftX;
}

/// Zafer arka planında süzülen ışıltı ve yıldız duşu
class ShimmerParticleShower extends StatefulWidget {
  const ShimmerParticleShower({
    super.key,
    this.particleCount = 28,
    this.primaryColor = const Color(0xFFFFE066),
  });

  final int particleCount;
  final Color primaryColor;

  @override
  State<ShimmerParticleShower> createState() => _ShimmerParticleShowerState();
}

class _ShimmerParticleShowerState extends State<ShimmerParticleShower>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  final List<_ShimmerStar> _stars = <_ShimmerStar>[];
  final Random _rng = Random(99);

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.particleCount; i++) {
      _stars.add(
        _ShimmerStar(
          x: _rng.nextDouble() * kVictoryBgWidth,
          y: _rng.nextDouble() * kVictoryBgHeight,
          size: 2.0 + _rng.nextDouble() * 5.0,
          baseAlpha: 0.25 + _rng.nextDouble() * 0.65,
          phase: _rng.nextDouble() * 2 * pi,
          speed: 12.0 + _rng.nextDouble() * 24.0,
          driftX: (_rng.nextDouble() - 0.5) * 8.0,
        ),
      );
    }
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(kVictoryBgWidth, kVictoryBgHeight),
          painter: _ShimmerShowerPainter(
            stars: _stars,
            progress: _animCtrl.value,
            color: widget.primaryColor,
          ),
        );
      },
    );
  }
}

class _ShimmerShowerPainter extends CustomPainter {
  const _ShimmerShowerPainter({
    required this.stars,
    required this.progress,
    required this.color,
  });

  final List<_ShimmerStar> stars;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in stars) {
      final double currentY = (s.y - progress * s.speed * 8.0) % size.height;
      final double currentX = (s.x + sin(progress * 2 * pi + s.phase) * s.driftX) % size.width;
      final double twinkle = (0.5 + 0.5 * sin(progress * 4 * pi + s.phase)).clamp(0.0, 1.0);
      final double alpha = (s.baseAlpha * twinkle).clamp(0.0, 1.0);

      final starPaint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      // 4 köşeli parlak elmas yıldız
      final path = Path()
        ..moveTo(currentX, currentY - s.size)
        ..quadraticBezierTo(currentX, currentY, currentX + s.size, currentY)
        ..quadraticBezierTo(currentX, currentY, currentX, currentY + s.size)
        ..quadraticBezierTo(currentX, currentY, currentX - s.size, currentY)
        ..quadraticBezierTo(currentX, currentY, currentX, currentY - s.size)
        ..close();

      canvas.drawPath(path, starPaint);

      // Merkez ışık noktası
      canvas.drawCircle(
        Offset(currentX, currentY),
        s.size * 0.35,
        Paint()..color = Colors.white.withValues(alpha: alpha * 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ShimmerShowerPainter oldDelegate) => true;
}

// =============================================================================
// 3. LEGENDARY LOOT CHEST GLOW AURA (VOLUMETRIC RAYS & SACRED RUNIC RINGS)
// =============================================================================

/// Efsanevi ganimet sandığı ışıma aurası
class LegendaryChestGlowAura extends StatefulWidget {
  const LegendaryChestGlowAura({
    super.key,
    required this.child,
    this.rarity = ChestRarity.legendary,
    this.auraRadius = 140.0,
    this.enableRays = true,
  });

  final Widget child;
  final ChestRarity rarity;
  final double auraRadius;
  final bool enableRays;

  @override
  State<LegendaryChestGlowAura> createState() => _LegendaryChestGlowAuraState();
}

class _LegendaryChestGlowAuraState extends State<LegendaryChestGlowAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final double pulse = _pulseCtrl.value;
        final Color pColor = widget.rarity.primaryColor;
        final Color sColor = widget.rarity.secondaryColor;

        return Stack(
          alignment: Alignment.center,
          children: [
            // 1. Mistik Dönen Rün Çemberleri ve Volumetrik Işınlar
            if (widget.enableRays)
              CustomPaint(
                size: Size(widget.auraRadius * 2, widget.auraRadius * 2),
                painter: _ChestRunicAuraPainter(
                  pulse: pulse,
                  primaryColor: pColor,
                  secondaryColor: sColor,
                ),
              ),

            // 2. Yumuşak Nefes Alan Aura Glow
            Container(
              width: widget.auraRadius * 1.5,
              height: widget.auraRadius * 1.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: pColor.withValues(alpha: 0.22 + pulse * 0.25),
                    blurRadius: 36.0 + pulse * 18.0,
                    spreadRadius: 4.0 + pulse * 8.0,
                  ),
                  BoxShadow(
                    color: sColor.withValues(alpha: 0.15 + pulse * 0.18),
                    blurRadius: 54.0,
                    spreadRadius: 2.0,
                  ),
                ],
              ),
            ),

            // 3. Sandık Bileşeni (Hafif dikey süzülme ile)
            Transform.translate(
              offset: Offset(0, -3.0 * sin(pulse * pi)),
              child: widget.child,
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _ChestRunicAuraPainter extends CustomPainter {
  const _ChestRunicAuraPainter({
    required this.pulse,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final double pulse;
  final Color primaryColor;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // A. Volumetrik 8 Köşeli Dönen Işın Çiçeği
    const int rayCount = 12;
    for (int i = 0; i < rayCount; i++) {
      final double angle = (i / rayCount) * 2 * pi + pulse * 0.35;
      final double rayLen = radius * (0.65 + 0.35 * sin(i * 1.5 + pulse * pi));
      final double rayAlpha = (0.08 + 0.16 * pulse).clamp(0.0, 1.0);

      final rayPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            primaryColor.withValues(alpha: rayAlpha),
            secondaryColor.withValues(alpha: rayAlpha * 0.4),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: rayLen));

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + cos(angle - 0.08) * rayLen,
          center.dy + sin(angle - 0.08) * rayLen,
        )
        ..lineTo(
          center.dx + cos(angle) * (rayLen * 1.2),
          center.dy + sin(angle) * (rayLen * 1.2),
        )
        ..lineTo(
          center.dx + cos(angle + 0.08) * rayLen,
          center.dy + sin(angle + 0.08) * rayLen,
        )
        ..close();

      canvas.drawPath(path, rayPaint);
    }

    // B. Mistik İç Rün Halkası
    final ringPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.25 + 0.25 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawCircle(center, radius * 0.62, ringPaint);

    // C. Halka Üzerinde Dönen Rün Noktaları
    const int dotCount = 8;
    for (int d = 0; d < dotCount; d++) {
      final double dotAngle = (d / dotCount) * 2 * pi - pulse * 0.6;
      final Offset dotPos = Offset(
        center.dx + cos(dotAngle) * radius * 0.62,
        center.dy + sin(dotAngle) * radius * 0.62,
      );
      canvas.drawCircle(
        dotPos,
        2.2,
        Paint()..color = Colors.white.withValues(alpha: 0.6 + 0.4 * pulse),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChestRunicAuraPainter oldDelegate) => true;
}

// =============================================================================
// 4. RATING RANK FANFARE STAMP (S/A/B TIER STAMP JUICE & SLAM SHOCKWAVE)
// =============================================================================

/// Zindan başarı derecesini mühürleyen sinematik damga bileşeni
class DungeonRankStampFanfare extends StatefulWidget {
  const DungeonRankStampFanfare({
    super.key,
    required this.rankTier,
    this.size = 88.0,
    this.delay = const Duration(milliseconds: 320),
    this.onImpact,
  });

  final DungeonRankTier rankTier;
  final double size;
  final Duration delay;
  final VoidCallback? onImpact;

  @override
  State<DungeonRankStampFanfare> createState() => _DungeonRankStampFanfareState();
}

class _DungeonRankStampFanfareState extends State<DungeonRankStampFanfare>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slamCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _opacityAnim;
  late final Animation<double> _shockwaveAnim;
  bool _hasTriggeredImpact = false;

  @override
  void initState() {
    super.initState();
    _slamCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // Ağır vuruş ve sekiş eğrisi (Squash & Bounce)
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 3.4, end: 0.88)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.88, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
    ]).animate(_slamCtrl);

    _opacityAnim = CurvedAnimation(
      parent: _slamCtrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    );

    _shockwaveAnim = CurvedAnimation(
      parent: _slamCtrl,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );

    _slamCtrl.addListener(() {
      if (_slamCtrl.value >= 0.55 && !_hasTriggeredImpact) {
        _hasTriggeredImpact = true;
        VictorySoundCueCoordinator.triggerHaptic(VictoryCueType.rankStampImpact);
        widget.onImpact?.call();
      }
    });

    Future.delayed(widget.delay, () {
      if (mounted) {
        _slamCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _slamCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color pColor = widget.rankTier.primaryColor;
    final Color sColor = widget.rankTier.secondaryColor;

    return AnimatedBuilder(
      animation: _slamCtrl,
      builder: (context, _) {
        if (_slamCtrl.value <= 0.01) return const SizedBox.shrink();

        return Stack(
          alignment: Alignment.center,
          children: [
            // 1. Çarpma Şok Dalga Halkası (Impact Shockwave Wavefront)
            if (_hasTriggeredImpact)
              CustomPaint(
                size: Size(widget.size * 2.2, widget.size * 2.2),
                painter: _StampShockwavePainter(
                  progress: _shockwaveAnim.value,
                  color: pColor,
                ),
              ),

            // 2. Mühür Gövdesi ve İkonografisi
            Transform.scale(
              scale: _scaleAnim.value,
              child: Opacity(
                opacity: _opacityAnim.value.clamp(0.0, 1.0),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF1E102E).withValues(alpha: 0.95),
                        const Color(0xFF0C0714).withValues(alpha: 0.98),
                      ],
                    ),
                    border: Border.all(
                      color: pColor,
                      width: 3.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: pColor.withValues(alpha: 0.55),
                        blurRadius: 16.0,
                        spreadRadius: 2.0,
                      ),
                      BoxShadow(
                        color: sColor.withValues(alpha: 0.35),
                        blurRadius: 8.0,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // İç Çift Hat Çemberi
                      Container(
                        width: widget.size * 0.82,
                        height: widget.size * 0.82,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: pColor.withValues(alpha: 0.45),
                            width: 1.2,
                          ),
                        ),
                      ),

                      // Rank Harf Glifi
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white,
                            pColor,
                            sColor,
                          ],
                        ).createShader(bounds),
                        child: Text(
                          widget.rankTier.label,
                          style: TextStyle(
                            fontSize: widget.size * 0.44,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.85),
                                offset: const Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StampShockwavePainter extends CustomPainter {
  const _StampShockwavePainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;
    final r = maxR * progress;
    final alpha = (1.0 - progress).clamp(0.0, 1.0);

    final wavePaint = Paint()
      ..color = color.withValues(alpha: alpha * 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1.0 - progress) * 6.0;

    canvas.drawCircle(center, r, wavePaint);

    // Radyal patlama kıvılcımları
    const int sparkCount = 8;
    for (int i = 0; i < sparkCount; i++) {
      final double ang = (i / sparkCount) * 2 * pi;
      final Offset sparkPos = Offset(
        center.dx + cos(ang) * (r * 1.05),
        center.dy + sin(ang) * (r * 1.05),
      );
      canvas.drawCircle(
        sparkPos,
        (1.0 - progress) * 2.8,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StampShockwavePainter oldDelegate) => true;
}

// =============================================================================
// 5. EXP BAR FILL JUICE (ANIMATED COUNTER & LIQUID ENERGY WAVE)
// =============================================================================

/// Deneyim puanı dolum barı ve kutlama animasyonu
class DungeonExpJuiceBar extends StatefulWidget {
  const DungeonExpJuiceBar({
    super.key,
    required this.gainedXp,
    this.currentXp = 0,
    this.maxXp = 1000,
    this.level = 1,
    this.width = 300.0,
    this.height = 20.0,
    this.delay = const Duration(milliseconds: 1200),
    this.onLevelUp,
  });

  final int gainedXp;
  final int currentXp;
  final int maxXp;
  final int level;
  final double width;
  final double height;
  final Duration delay;
  final VoidCallback? onLevelUp;

  @override
  State<DungeonExpJuiceBar> createState() => _DungeonExpJuiceBarState();
}

class _DungeonExpJuiceBarState extends State<DungeonExpJuiceBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fillCtrl;
  late final Animation<double> _fillAnim;
  bool _levelUpTriggered = false;

  @override
  void initState() {
    super.initState();
    _fillCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fillAnim = CurvedAnimation(
      parent: _fillCtrl,
      curve: Curves.easeOutCubic,
    );

    _fillCtrl.addListener(() {
      final double totalProjected = widget.currentXp + widget.gainedXp * _fillAnim.value;
      if (totalProjected >= widget.maxXp && !_levelUpTriggered) {
        _levelUpTriggered = true;
        VictorySoundCueCoordinator.triggerHaptic(VictoryCueType.levelUpFlourish);
        widget.onLevelUp?.call();
      }
    });

    Future.delayed(widget.delay, () {
      if (mounted) {
        _fillCtrl.forward();
        VictorySoundCueCoordinator.triggerHaptic(VictoryCueType.expBarCharge);
      }
    });
  }

  @override
  void dispose() {
    _fillCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fillAnim,
      builder: (context, _) {
        final double progressFactor = _fillAnim.value;
        final int displayGained = (widget.gainedXp * progressFactor).round();
        final double startRatio = (widget.currentXp / widget.maxXp).clamp(0.0, 1.0);
        final double endRatio = ((widget.currentXp + widget.gainedXp) / widget.maxXp).clamp(0.0, 1.0);
        final double currentFillRatio = (startRatio + (endRatio - startRatio) * progressFactor).clamp(0.0, 1.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Sayısal sayaç ve Seviye etiketi
            SizedBox(
              width: widget.width,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFF60A5FA).withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'LV. ${widget.level}',
                          style: const TextStyle(
                            color: Color(0xFF93C5FD),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'EXP: ${(widget.currentXp + displayGained).clamp(0, widget.maxXp)} / ${widget.maxXp}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '+$displayGained XP',
                    style: TextStyle(
                      color: const Color(0xFF34D399),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.8),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),

            // Likit Dolum Barı
            Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(widget.height / 2),
                border: Border.all(
                  color: const Color(0xFF334155),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.height / 2),
                child: Stack(
                  children: [
                    // Arka Plan İlerleme Dolgusu
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: currentFillRatio,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF059669),
                              Color(0xFF10B981),
                              Color(0xFF34D399),
                              Color(0xFF6EE7B7),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.7),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Dalgalanan Işık Şeridi (Shimmer Sweep)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ExpLiquidShimmerPainter(
                          progress: _fillCtrl.value,
                          fillRatio: currentFillRatio,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ExpLiquidShimmerPainter extends CustomPainter {
  const _ExpLiquidShimmerPainter({
    required this.progress,
    required this.fillRatio,
  });

  final double progress;
  final double fillRatio;

  @override
  void paint(Canvas canvas, Size size) {
    if (fillRatio <= 0.0) return;

    final double activeWidth = size.width * fillRatio;
    final double sweepX = (progress * 2.0 - 0.5) * activeWidth;

    final sweepPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.45),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(sweepX, 0, 40, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, activeWidth, size.height), sweepPaint);

    // Dolum Başlığı Kıvılcımı
    final double sparkX = activeWidth;
    final sparkPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    canvas.drawCircle(Offset(sparkX, size.height / 2), size.height * 0.38, sparkPaint);
  }

  @override
  bool shouldRepaint(covariant _ExpLiquidShimmerPainter oldDelegate) => true;
}

// =============================================================================
// VICTORY CARD (GELİŞMİŞ ZİYAFET & KUTLAMA KARTI)
// =============================================================================

class VictoryCard extends StatefulWidget {
  const VictoryCard({
    super.key,
    required this.animation,
    required this.badges,
    this.intenseGlow = false,
    this.rankTier,
    this.rankString,
    this.enableCoinBurst = true,
    this.enableShimmerShower = true,
    this.enableChestAura = false,
    this.chestRarity = ChestRarity.legendary,
    this.currentXp,
    this.gainedXp,
    this.maxXp,
    this.level,
    this.onSoundCue,
  });

  final Animation<double> animation;
  final List<Widget> badges;
  final bool intenseGlow;
  final DungeonRankTier? rankTier;
  final String? rankString;
  final bool enableCoinBurst;
  final bool enableShimmerShower;
  final bool enableChestAura;
  final ChestRarity chestRarity;
  final int? currentXp;
  final int? gainedXp;
  final int? maxXp;
  final int? level;
  final void Function(VictoryCueType cue)? onSoundCue;

  @override
  State<VictoryCard> createState() => _VictoryCardState();
}

class _VictoryCardState extends State<VictoryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;
  List<Timer>? _scheduledTimers;

  DungeonRankTier? get _effectiveRank {
    if (widget.rankTier != null) return widget.rankTier;
    if (widget.rankString != null) {
      return DungeonRankTier.fromString(widget.rankString);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: kGlowPulseDurationMs),
    )..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);

    // Ses ve dokunsal zamanlama sekansı
    _scheduledTimers = VictorySoundCueCoordinator.scheduleVictorySequence(
      onSoundCue: widget.onSoundCue,
    );
  }

  @override
  void dispose() {
    if (_scheduledTimers != null) {
      for (final t in _scheduledTimers!) {
        t.cancel();
      }
    }
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: widget.animation,
      child: Center(
        child: SizedBox(
          width: kVictoryBgWidth,
          height: kVictoryBgHeight,
          child: AnimatedBuilder(
            animation: _glowAnim,
            builder: (context, _) {
              final double glowMin =
                  widget.intenseGlow ? kGlowOpacityMin * 2.2 : kGlowOpacityMin;
              final double glowMax =
                  widget.intenseGlow ? kGlowOpacityMax * 2.5 : kGlowOpacityMax;
              final double glowOpacity =
                  glowMin + _glowAnim.value * (glowMax - glowMin);

              return Stack(
                alignment: Alignment.center,
                children: [
                  // ── 0. Işıltı ve Yıldız Yağmuru
                  if (widget.enableShimmerShower)
                    const Positioned.fill(
                      child: ShimmerParticleShower(
                        particleCount: 26,
                        primaryColor: Color(0xFFFFDF70),
                      ),
                    ),

                  // ── 1. Altın Hüzmeler
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RaysPainter(
                        pulse: _glowAnim.value,
                        rotation: _glowCtrl.value * 2 * pi * kRayRotationFraction,
                        color: kGlowColor,
                      ),
                    ),
                  ),

                  // ── 2. Yumuşak Aura Işıması
                  IgnorePointer(
                    child: Container(
                      width: kVictoryBgWidth,
                      height: kVictoryBgHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(kFrameInnerRadius),
                        boxShadow: [
                          BoxShadow(
                            color: kGlowColor.withValues(alpha: glowOpacity),
                            blurRadius: kAuraBlurRadius,
                            spreadRadius: -12,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── 3. Zafer Arka Plan Resmi
                  SizedBox(
                    width: kVictoryBgWidth,
                    height: kVictoryBgHeight,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(kFrameInnerRadius),
                      child: Image.asset(
                        'assets/dungeon/victory_bg.png',
                        width: kVictoryBgWidth,
                        height: kVictoryBgHeight,
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),

                  // ── 4. Rozetler
                  Positioned(
                    top: kBadgePositionTop,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      width: kBadgeStripeWidth,
                      height: kBadgeStripeHeight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: widget.badges,
                      ),
                    ),
                  ),

                  // ── 5. Altın Sikke Fıskiyesi & Patlaması
                  if (widget.enableCoinBurst)
                    const Positioned.fill(
                      child: GoldCoinBurstOverlay(
                        coinCount: 38,
                        spawnCenter: Offset(190.0, 195.0),
                      ),
                    ),

                  // ── 6. Derece Damgası (Rating Rank Fanfare Stamp)
                  if (_effectiveRank != null)
                    Positioned(
                      top: 48.0,
                      right: 28.0,
                      child: DungeonRankStampFanfare(
                        rankTier: _effectiveRank!,
                        size: 78.0,
                      ),
                    ),

                  // ── 7. Deneyim Barı (Exp Fill Juice Bar)
                  if (widget.gainedXp != null)
                    Positioned(
                      bottom: 24.0,
                      child: DungeonExpJuiceBar(
                        gainedXp: widget.gainedXp!,
                        currentXp: widget.currentXp ?? 0,
                        maxXp: widget.maxXp ?? 1000,
                        level: widget.level ?? 1,
                        width: 320.0,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _RaysPainter — ALTIN IŞIK HÜZMELERİ (MERKEZDEN YAYILAN GÜNEŞ IŞINLARI)
// =============================================================================
class _RaysPainter extends CustomPainter {
  final double pulse;
  final double rotation;
  final Color color;

  const _RaysPainter({
    required this.pulse,
    required this.rotation,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double diagonal = sqrt(size.width * size.width + size.height * size.height) / 2;
    final double innerRadius = diagonal * kRayInnerRadiusFactor;
    final double outerRadius = diagonal * kRayOuterRadiusFactor;

    for (int i = 0; i < kRayCount; i++) {
      final double baseAngle = (i / kRayCount) * 2 * pi + rotation;
      final double variance = 0.6 + 0.4 * sin(i * 1.7 + pulse * pi);
      final double opacity =
          (kRayOpacityMin + pulse * (kRayOpacityMax - kRayOpacityMin)) *
              variance;

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * 0.80),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.00, 0.62, 1.00],
          transform: GradientRotation(baseAngle),
        ).createShader(Rect.fromCircle(center: center, radius: diagonal));

      final Offset p1 = Offset(
        center.dx + cos(baseAngle - kRayHalfAngle) * innerRadius,
        center.dy + sin(baseAngle - kRayHalfAngle) * innerRadius,
      );
      final Offset p2 = Offset(
        center.dx + cos(baseAngle + kRayHalfAngle) * innerRadius,
        center.dy + sin(baseAngle + kRayHalfAngle) * innerRadius,
      );
      final Offset p3 = Offset(
        center.dx + cos(baseAngle + kRayHalfAngle * 1.9) * outerRadius,
        center.dy + sin(baseAngle + kRayHalfAngle * 1.9) * outerRadius,
      );
      final Offset p4 = Offset(
        center.dx + cos(baseAngle - kRayHalfAngle * 1.9) * outerRadius,
        center.dy + sin(baseAngle - kRayHalfAngle * 1.9) * outerRadius,
      );

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..lineTo(p4.dx, p4.dy)
        ..close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) =>
      old.pulse != pulse || old.rotation != rotation;
}

// =============================================================================
// VICTORY BADGE (KUTLAMA ROZETİ)
// =============================================================================
class VictoryBadge extends StatelessWidget {
  const VictoryBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.sub,
  });

  final String icon;
  final String label;
  final String value;
  final Color color;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kBadgeWidth,
      height: kBadgeHeight,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: kBadgePaddingVertical,
          horizontal: kBadgePaddingHorizontal,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(kBadgeBorderRadius),
          border: Border.all(
            color: color.withValues(alpha: 0.55),
            width: kBadgeBorderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: kBadgeShadowBlur,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: color.withValues(alpha: 0.20),
              blurRadius: kBadgeShadowBlur2,
              spreadRadius: 0,
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: kBadgeIconFontSize)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: kBadgeValueFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: kBadgeLabelFontSize,
                  letterSpacing: 0.5,
                ),
              ),
              if (sub != null) ...[
                Text(
                  sub!,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: kBadgeSubFontSize,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// DEFEAT EFFECT CONSTANTS & CARDS (YENİLGİ KARTI VE KASVETLİ AURA)
// =============================================================================
const Color kDefeatGlowColor = Color(0xFFB91C1C);
const Color kDefeatRayColor = Color(0xFF7F1D1D);
const double kDefeatGlowOpacityMin = 0.03;
const double kDefeatGlowOpacityMax = 0.10;
const double kDefeatAuraBlurRadius = 20.0;
const int kDefeatRayCount = 14;
const double kDefeatRayOpacityMin = 0.015;
const double kDefeatRayOpacityMax = 0.08;
const double kDefeatRayHalfAngle = 0.035;
const double kDefeatRayInnerRadiusFactor = 0.34;
const double kDefeatRayOuterRadiusFactor = 0.74;
const double kDefeatRayRotationFraction = 0.04;
const double kDefeatStripeTop = 190.0;
const double kDefeatStripeHeight = 82.0;

class DefeatCard extends StatefulWidget {
  const DefeatCard({
    super.key,
    required this.animation,
    required this.notices,
  });

  final Animation<double> animation;
  final List<String> notices;

  @override
  State<DefeatCard> createState() => _DefeatCardState();
}

class _DefeatCardState extends State<DefeatCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fxCtrl;
  late final Animation<double> _fxAnim;

  @override
  void initState() {
    super.initState();
    _fxCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _fxAnim = CurvedAnimation(parent: _fxCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _fxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: widget.animation,
      child: Center(
        child: SizedBox(
          width: kVictoryBgWidth,
          height: kVictoryBgHeight,
          child: AnimatedBuilder(
            animation: _fxAnim,
            builder: (context, _) {
              final glowOpacity = kDefeatGlowOpacityMin +
                  _fxAnim.value *
                      (kDefeatGlowOpacityMax - kDefeatGlowOpacityMin);

              return Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DefeatRaysPainter(
                        pulse: _fxAnim.value,
                        rotation:
                            _fxCtrl.value * 2 * pi * kDefeatRayRotationFraction,
                        color: kDefeatRayColor,
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Container(
                      width: kVictoryBgWidth,
                      height: kVictoryBgHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(kFrameInnerRadius),
                        boxShadow: [
                          BoxShadow(
                            color: kDefeatGlowColor.withValues(alpha: glowOpacity),
                            blurRadius: kDefeatAuraBlurRadius,
                            spreadRadius: -12,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: kVictoryBgWidth,
                    height: kVictoryBgHeight,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(kFrameInnerRadius),
                      child: Image.asset(
                        'assets/dungeon/defeatdungeon_bg.png',
                        width: kVictoryBgWidth,
                        height: kVictoryBgHeight,
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                  Positioned(
                    top: kDefeatStripeTop,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      height: kDefeatStripeHeight,
                      child: Center(
                        child: Container(
                          width: kBadgeStripeWidth,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          color: const Color(0xCC06080C),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: widget.notices
                                .map(
                                  (line) => Text(
                                    line,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFFFCA5A5),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DefeatRaysPainter extends CustomPainter {
  const _DefeatRaysPainter({
    required this.pulse,
    required this.rotation,
    required this.color,
  });

  final double pulse;
  final double rotation;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final diagonal = sqrt(size.width * size.width + size.height * size.height) / 2;
    final innerRadius = diagonal * kDefeatRayInnerRadiusFactor;
    final outerRadius = diagonal * kDefeatRayOuterRadiusFactor;

    for (int i = 0; i < kDefeatRayCount; i++) {
      final baseAngle = (i / kDefeatRayCount) * 2 * pi + rotation;
      final variance = 0.7 + 0.3 * sin(i * 1.4 + pulse * pi);
      final opacity =
          (kDefeatRayOpacityMin +
                  pulse * (kDefeatRayOpacityMax - kDefeatRayOpacityMin)) *
              variance;

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: opacity * 0.75),
            color.withValues(alpha: opacity * 0.35),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.72, 1.0],
          transform: GradientRotation(baseAngle),
        ).createShader(Rect.fromCircle(center: center, radius: diagonal));

      final p1 = Offset(
        center.dx + cos(baseAngle - kDefeatRayHalfAngle) * innerRadius,
        center.dy + sin(baseAngle - kDefeatRayHalfAngle) * innerRadius,
      );
      final p2 = Offset(
        center.dx + cos(baseAngle + kDefeatRayHalfAngle) * innerRadius,
        center.dy + sin(baseAngle + kDefeatRayHalfAngle) * innerRadius,
      );
      final p3 = Offset(
        center.dx + cos(baseAngle + kDefeatRayHalfAngle * 2.1) * outerRadius,
        center.dy + sin(baseAngle + kDefeatRayHalfAngle * 2.1) * outerRadius,
      );
      final p4 = Offset(
        center.dx + cos(baseAngle - kDefeatRayHalfAngle * 2.1) * outerRadius,
        center.dy + sin(baseAngle - kDefeatRayHalfAngle * 2.1) * outerRadius,
      );

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..lineTo(p4.dx, p4.dy)
        ..close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_DefeatRaysPainter old) =>
      old.pulse != pulse || old.rotation != rotation;
}
