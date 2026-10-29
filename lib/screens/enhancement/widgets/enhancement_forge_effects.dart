import 'dart:math' as math;
import 'dart:ui' as ui show PathMetric;

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';

// ============================================================================
// 2027 AION 2 MOBILE STANDARDS — GÜÇLENDİRME OCAĞI (FORGE) VFX SİSTEMİ (AAA)
//
// 1. Örs Darbe Kıvılcımları (Anvil Strike Sparks):
//    Yerçekimi, hava sürtünmesi (aerodynamic drag) ve balistik konik saçılma
//    fiziğine sahip çok katmanlı akkor beyaz -> erimiş altın -> kor turuncu parçacıklar.
// 2. Örs Çekiç Darbe Dalgası (Anvil Hammer Impact Wave):
//    Çekiç temas noktasında anlık patlayan eliptik sıkışma dalgası,
//    dikey akkor ışık keskisi (light chisel) ve radyal kor halesi.
// 3. Isınan Metal Parıltısı & Konveksiyon (Heating Metal Glow & Heat Shimmer):
//    Planck kara cisim ışıması (kara yakut -> akkor akkor sarı) ile termal
//    solunum dalgaları, türbülanslı ısı bükülmesi ve süzülen mikro korlar.
// 4. Başarı Şok Dalgası & Göksel Yıldız Yağmuru (Success Shockwave & Stardust Burst):
//    Genişleyen çift katmanlı altın ve gök mavisi enerji halkaları, prizmatik
//    8-yönlü yıldız huzmeleri ve yukarı süzülen lüks neon seviye dalgası (+N).
// 5. Başarısızlık / Parçalanma Kırılma Efekti (Failure Fracture & Shattered Runes):
//    Karanlık uçurum moru ve kızıl kan çatlak dalgası, örümcek ağı kırılma çizgileri,
//    3D takla atan rün kristali parçacıkları ve dağılan hacimsel duman bulutu.
// 6. Kesintisiz Kontrolcü ve Katman (EnhancementForgeEffectsLayer):
//    Mobil TBDR GPU için RepaintBoundary ile izole edilmiş 60fps VFX motoru.
// ============================================================================

// ────────────────────────────────────────────────────────────────────────────
// 1. ANVIL STRIKE SPARKS (ÖRS DARBE KIVILCIMLARI)
// ────────────────────────────────────────────────────────────────────────────

/// Kıvılcım parçacığı türü — çok katmanlı görsel derinlik sağlar.
enum _SparkKind {
  streak, // Hızlı, uzun akkor ışık çizgisi
  cinder, // Ağır erimiş damlacık (parabolik düşüş)
  microEmber, // Titreşen hafif kor tanesi
}

/// Tek bir kıvılcım parçacığının balistik parametreleri.
class _ForgeSparkData {
  _ForgeSparkData({
    required this.kind,
    required this.angle,
    required this.speed,
    required this.gravity,
    required this.drag,
    required this.maxAge,
    required this.baseSize,
    required this.flickerSpeed,
    required this.colorShift,
  });

  final _SparkKind kind;
  final double angle; // Yön radyan cinsinden (-165° .. -15°)
  final double speed; // Başlangıç fırlatma hızı (px/s)
  final double gravity; // Yerçekimi ivmesi
  final double drag; // Hava sürtünmesi katsayısı
  final double maxAge; // Ömür (0..1 normalized)
  final double baseSize; // Çekirdek boyutu
  final double flickerSpeed; // Mikro titreşim frekansı
  final double colorShift; // Renk geçiş varyasyonu
}

/// Çekiç vuruşu anında örsten saçılan gerçekçi fiziksel kıvılcım demeti.
class AnvilStrikeSparksPainter extends CustomPainter {
  AnvilStrikeSparksPainter({
    required this.progress,
    this.origin = Offset.zero,
    this.primaryColor = AppColors.liquidGold,
    this.secondaryColor = AppColors.coralFlare,
    this.sparkCount = 48,
    this.seed = 42,
  }) : _sparks = _generateSparks(sparkCount, seed);

  final double progress; // 0..1 vuruş ilerlemesi
  final Offset origin;
  final Color primaryColor;
  final Color secondaryColor;
  final int sparkCount;
  final int seed;

  final List<_ForgeSparkData> _sparks;

  static List<_ForgeSparkData> _generateSparks(int count, int seed) {
    final math.Random rnd = math.Random(seed);
    return List<_ForgeSparkData>.generate(count, (int i) {
      final double rKind = rnd.nextDouble();
      final _SparkKind kind = rKind < 0.50
          ? _SparkKind.streak
          : (rKind < 0.85 ? _SparkKind.cinder : _SparkKind.microEmber);

      // Çekiç darbesi genellikle yukarı ve dışarı yayılır (-160° .. -20°)
      final double angle = -math.pi * (0.10 + rnd.nextDouble() * 0.80);

      final double speed = switch (kind) {
        _SparkKind.streak => 160.0 + rnd.nextDouble() * 280.0,
        _SparkKind.cinder => 80.0 + rnd.nextDouble() * 180.0,
        _SparkKind.microEmber => 40.0 + rnd.nextDouble() * 90.0,
      };

      final double gravity = switch (kind) {
        _SparkKind.streak => 180.0 + rnd.nextDouble() * 120.0,
        _SparkKind.cinder => 340.0 + rnd.nextDouble() * 190.0,
        _SparkKind.microEmber => 90.0 + rnd.nextDouble() * 70.0,
      };

      final double drag = switch (kind) {
        _SparkKind.streak => 0.90 + rnd.nextDouble() * 0.40,
        _SparkKind.cinder => 0.45 + rnd.nextDouble() * 0.35,
        _SparkKind.microEmber => 1.40 + rnd.nextDouble() * 0.80,
      };

      final double maxAge = 0.42 + rnd.nextDouble() * 0.58;
      final double baseSize = switch (kind) {
        _SparkKind.streak => 1.6 + rnd.nextDouble() * 2.2,
        _SparkKind.cinder => 2.4 + rnd.nextDouble() * 2.4,
        _SparkKind.microEmber => 1.0 + rnd.nextDouble() * 1.4,
      };

      final double flickerSpeed = 16.0 + rnd.nextDouble() * 26.0;
      final double colorShift = rnd.nextDouble();

      return _ForgeSparkData(
        kind: kind,
        angle: angle,
        speed: speed,
        gravity: gravity,
        drag: drag,
        maxAge: maxAge,
        baseSize: baseSize,
        flickerSpeed: flickerSpeed,
        colorShift: colorShift,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1.0) return;

    final Offset center = origin == Offset.zero
        ? Offset(size.width / 2, size.height * 0.52)
        : origin;

    final Paint corePaint = Paint()..strokeCap = StrokeCap.round;
    final Paint glowPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5);

    for (final _ForgeSparkData s in _sparks) {
      if (progress > s.maxAge) continue;

      // Parçacığın ömür döngüsü t: 0..1
      final double particleT = (progress / s.maxAge).clamp(0.0, 1.0);

      // Hava sürtünmesi (drag) entegrasyonu
      final double effectiveTime = particleT;
      final double dragFactor =
          (1.0 - math.exp(-s.drag * effectiveTime * 3.2)) / s.drag;

      // Yörünge fiziği
      final double vx0 = math.cos(s.angle) * s.speed;
      final double vy0 = math.sin(s.angle) * s.speed;

      final double px = center.dx + vx0 * dragFactor;
      final double py = center.dy +
          vy0 * dragFactor +
          0.5 * s.gravity * (effectiveTime * effectiveTime);

      // Anlık hız vektörü
      final double curVx = vx0 * math.exp(-s.drag * effectiveTime * 3.2);
      final double curVy = vy0 * math.exp(-s.drag * effectiveTime * 3.2) +
          s.gravity * effectiveTime;
      final double curSpeed = math.sqrt(curVx * curVx + curVy * curVy);

      // Soğuma ve sönme (White -> Gold -> Coral -> Charcoal Ember)
      final double flicker =
          0.85 + 0.15 * math.sin(progress * s.flickerSpeed);
      final double fade = (1.0 - particleT) * flicker;
      if (fade <= 0) continue;

      Color sparkColor;
      if (particleT < 0.20) {
        sparkColor = Color.lerp(Colors.white, primaryColor, particleT / 0.20)!;
      } else if (particleT < 0.60) {
        final double blend = (particleT - 0.20) / 0.40;
        sparkColor = Color.lerp(primaryColor, secondaryColor, blend)!;
      } else {
        final double blend = (particleT - 0.60) / 0.40;
        sparkColor = Color.lerp(secondaryColor, const Color(0xFF3E2723), blend)!;
      }

      final double sizeScale = (1.0 - particleT * 0.45) * s.baseSize;
      final double streakMultiplier = s.kind == _SparkKind.streak ? 0.055 : 0.025;
      final double streakLen =
          (curSpeed * streakMultiplier * (1.0 - particleT * 0.5)).clamp(2.5, 20.0);

      final double dirX = curSpeed > 0.001 ? curVx / curSpeed : 0.0;
      final double dirY = curSpeed > 0.001 ? curVy / curSpeed : 0.0;

      final Offset head = Offset(px, py);
      final Offset tail =
          Offset(px - dirX * streakLen, py - dirY * streakLen);

      // 1. Geniş akkor ışıma (Bloom Glow)
      glowPaint
        ..color = sparkColor.withValues(alpha: (fade * 0.55).clamp(0.0, 1.0))
        ..strokeWidth = sizeScale * 2.8;
      canvas.drawLine(tail, head, glowPaint);

      // 2. Akkor çekirdek (Hot Core)
      corePaint
        ..color = (particleT < 0.25 ? Colors.white : sparkColor)
            .withValues(alpha: fade.clamp(0.0, 1.0))
        ..strokeWidth = sizeScale;
      canvas.drawLine(tail, head, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant AnvilStrikeSparksPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.origin != origin ||
      oldDelegate.primaryColor != primaryColor;
}

// ────────────────────────────────────────────────────────────────────────────
// 2. ANVIL HAMMER IMPACT WAVE (ÖRS ÇEKİÇ DARBE ŞOK DALGASI)
// ────────────────────────────────────────────────────────────────────────────

/// Çekiç örse çarptığı anda yüzey boyunca yayılan eliptik sıkışma dalgası ve ışık keskisi.
class AnvilImpactWavePainter extends CustomPainter {
  AnvilImpactWavePainter({
    required this.progress,
    this.origin = Offset.zero,
    this.coreFlashColor = Colors.white,
    this.impactGlow = AppColors.liquidGold,
    this.waveRadius = 140.0,
  });

  final double progress; // 0..1
  final Offset origin;
  final Color coreFlashColor;
  final Color impactGlow;
  final double waveRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 0.85) return;

    final Offset center = origin == Offset.zero
        ? Offset(size.width / 2, size.height * 0.52)
        : origin;

    // Normalleştirilmiş darbe fazı (hızlı patlar, yavaş söner)
    final double t = (progress / 0.85).clamp(0.0, 1.0);
    final double easeOutT = Curves.easeOutQuart.transform(t);
    final double alpha = (1.0 - t).clamp(0.0, 1.0);

    // 1. Dikey Akkor Işık Keskisi (Vertical Contact Flash Chisel)
    if (t < 0.35) {
      final double chiselT = t / 0.35;
      final double chiselHeight = (1.0 - chiselT) * 90.0;
      final double chiselWidth = (1.0 - chiselT) * 7.0;
      final double chiselAlpha = (1.0 - chiselT) * 0.95;

      final Path chiselPath = Path()
        ..moveTo(center.dx, center.dy - chiselHeight)
        ..lineTo(center.dx + chiselWidth * 0.5, center.dy)
        ..lineTo(center.dx, center.dy + chiselHeight * 0.3)
        ..lineTo(center.dx - chiselWidth * 0.5, center.dy)
        ..close();

      canvas.drawPath(
        chiselPath,
        Paint()
          ..color = coreFlashColor.withValues(alpha: chiselAlpha.clamp(0.0, 1.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0),
      );

      canvas.drawPath(
        chiselPath,
        Paint()..color = Colors.white.withValues(alpha: chiselAlpha.clamp(0.0, 1.0)),
      );
    }

    // 2. Örs Yüzeyi Yatay Eliptik Basınç Dalgası (Anisotropic Compression Wave)
    final double currentRadiusX = easeOutT * waveRadius;
    final double currentRadiusY = currentRadiusX * 0.48; // Örs açısına uygun elips
    final Rect waveRect = Rect.fromCenter(
      center: center,
      width: currentRadiusX * 2,
      height: currentRadiusY * 2,
    );

    // Dış kor halesi
    final Paint outerGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (8.0 * (1.0 - t)).clamp(1.5, 8.0)
      ..color = impactGlow.withValues(alpha: (alpha * 0.45).clamp(0.0, 1.0))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    canvas.drawOval(waveRect, outerGlowPaint);

    // İç keskin akkor çekirdek dalgası
    final Paint waveLinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (3.2 * (1.0 - t)).clamp(1.0, 3.2)
      ..color = Color.lerp(Colors.white, impactGlow, t)!
          .withValues(alpha: alpha.clamp(0.0, 1.0));
    canvas.drawOval(waveRect, waveLinePaint);

    // 3. İkincil Yankı Halkası (Secondary Ripple)
    if (t > 0.08) {
      final double rippleT = ((t - 0.08) / 0.92).clamp(0.0, 1.0);
      final double rippleEase = Curves.easeOutCubic.transform(rippleT);
      final double rippleRadiusX = rippleEase * (waveRadius * 0.68);
      final double rippleRadiusY = rippleRadiusX * 0.48;
      final double rippleAlpha = (1.0 - rippleT) * 0.55;

      final Rect rippleRect = Rect.fromCenter(
        center: center,
        width: rippleRadiusX * 2,
        height: rippleRadiusY * 2,
      );

      canvas.drawOval(
        rippleRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * (1.0 - rippleT)
          ..color = AppColors.goldLight.withValues(alpha: rippleAlpha.clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant AnvilImpactWavePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.origin != origin ||
      oldDelegate.impactGlow != impactGlow;
}

// ────────────────────────────────────────────────────────────────────────────
// 3. HEATING METAL GLOW & THERMAL CONVECTION (ISINAN METAL PARILTISI)
// ────────────────────────────────────────────────────────────────────────────

/// Örs üzerindeki eşyanın kızaran/akkorlaşan termal radyasyonunu çizen custom painter.
class HeatingMetalGlowPainter extends CustomPainter {
  HeatingMetalGlowPainter({
    required this.heatIntensity,
    this.centerOffset = Offset.zero,
    this.incandescentCore = Colors.white,
    this.moltenOrange = AppColors.coralFlare,
    this.deepRuby = AppColors.mysticRuby,
  });

  final double heatIntensity; // 0..1 termal soluma derecesi
  final Offset centerOffset;
  final Color incandescentCore;
  final Color moltenOrange;
  final Color deepRuby;

  @override
  void paint(Canvas canvas, Size size) {
    if (heatIntensity <= 0.01) return;

    final Offset center = centerOffset == Offset.zero
        ? Offset(size.width / 2, size.height * 0.52)
        : centerOffset;

    final double radius = 64.0 + heatIntensity * 28.0;
    final Rect glowRect = Rect.fromCircle(center: center, radius: radius);

    // Planck kara cisim sıcaklık gradyanı
    final Paint thermalGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          incandescentCore.withValues(alpha: (0.65 * heatIntensity).clamp(0.0, 1.0)),
          moltenOrange.withValues(alpha: (0.45 * heatIntensity).clamp(0.0, 1.0)),
          deepRuby.withValues(alpha: (0.22 * heatIntensity).clamp(0.0, 1.0)),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.28, 0.65, 1.0],
      ).createShader(glowRect);

    canvas.drawCircle(center, radius, thermalGlowPaint);
  }

  @override
  bool shouldRepaint(covariant HeatingMetalGlowPainter oldDelegate) =>
      oldDelegate.heatIntensity != heatIntensity ||
      oldDelegate.centerOffset != centerOffset;
}

/// Isınan metal parıltısını bir çocuk widget'ın arkasına yerleştiren widget.
class HeatingMetalGlowWidget extends StatelessWidget {
  const HeatingMetalGlowWidget({
    super.key,
    required this.heatIntensity,
    required this.child,
    this.centerOffset = Offset.zero,
  });

  final double heatIntensity;
  final Widget child;
  final Offset centerOffset;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: HeatingMetalGlowPainter(
        heatIntensity: heatIntensity,
        centerOffset: centerOffset,
      ),
      child: child,
    );
  }
}

/// Örs kaidesi etrafında organik soluk alan konveksiyonel ısı dalgası ve
/// erimiş zemin kor parıltısı.
class AmbientForgeGlowPainter extends CustomPainter {
  AmbientForgeGlowPainter({
    required this.breathingPhase,
    this.moltenCore = AppColors.coralFlare,
    this.forgeGold = AppColors.liquidGold,
    this.intensity = 1.0,
  });

  final double breathingPhase; // 0..1 döngü
  final Color moltenCore;
  final Color forgeGold;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height * 0.58);

    // Harmonik soluma darbesi (Thermal breathing cycle)
    final double breath = 0.50 +
        0.35 * math.sin(breathingPhase * math.pi * 2) +
        0.15 * math.sin(breathingPhase * math.pi * 4);
    final double curIntensity = (breath * intensity).clamp(0.1, 1.8);

    // 1. Zemin Erimiş Metal Kor Havuzu (Molten Floor Glow)
    final Rect floorRect = Rect.fromCenter(
      center: center,
      width: size.width * 0.90,
      height: size.height * 0.54,
    );

    final Paint floorPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          moltenCore.withValues(alpha: (0.36 * curIntensity).clamp(0.0, 0.95)),
          forgeGold.withValues(alpha: (0.20 * curIntensity).clamp(0.0, 0.75)),
          AppColors.mysticRuby.withValues(alpha: (0.08 * curIntensity).clamp(0.0, 0.35)),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.36, 0.70, 1.0],
      ).createShader(floorRect);

    canvas.drawOval(floorRect, floorPaint);

    // 2. Yükselen Konveksiyonel Isı Dalgaları (Rising Heat Wavers)
    final Paint wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

    const int waveLines = 6;
    for (int i = 0; i < waveLines; i++) {
      final double normalizedI = (i / waveLines);
      final double waveXBase = size.width * (0.22 + normalizedI * 0.56);
      final double phaseShift = breathingPhase * math.pi * 2 + (i * 1.15);

      final Path waverPath = Path();
      const int steps = 14;
      for (int step = 0; step <= steps; step++) {
        final double tStep = step / steps;
        final double curY = size.height * (0.80 - tStep * 0.50);
        // Sinüs dalgalı ısı sapması
        final double curX = waveXBase +
            math.sin(tStep * math.pi * 3.0 + phaseShift) * (6.0 * (1.0 - tStep * 0.4));

        if (step == 0) {
          waverPath.moveTo(curX, curY);
        } else {
          waverPath.lineTo(curX, curY);
        }
      }

      final double lineAlpha = (0.18 + 0.12 * math.sin(phaseShift)) * curIntensity;
      wavePaint
        ..strokeWidth = (2.2 * (1.0 - normalizedI * 0.3)).clamp(1.0, 3.5)
        ..color = (i.isEven ? forgeGold : moltenCore).withValues(
          alpha: lineAlpha.clamp(0.0, 0.65),
        );

      canvas.drawPath(waverPath, wavePaint);
    }

    // 3. Ortamda Ağır Ağır Yükselen Minik Kıvılcım Taneleri (Floating Micro-Embers)
    final math.Random emberRnd = math.Random(1337);
    final Paint emberPaint = Paint();

    for (int i = 0; i < 12; i++) {
      final double baseX = size.width * (0.22 + emberRnd.nextDouble() * 0.56);
      final double speed = 0.35 + emberRnd.nextDouble() * 0.65;
      final double emberT = (breathingPhase * speed + (i * 0.08)) % 1.0;
      final double ey = size.height * (0.76 - emberT * 0.56);
      final double ex = baseX + math.sin(emberT * math.pi * 4.0 + i) * 14.0;
      final double alpha =
          (math.sin(emberT * math.pi) * 0.85 * curIntensity).clamp(0.0, 1.0);

      emberPaint
        ..color = (i % 3 == 0 ? Colors.white : forgeGold).withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

      canvas.drawCircle(Offset(ex, ey), 1.2 + emberRnd.nextDouble() * 1.5, emberPaint);
    }
  }

  @override
  bool shouldRepaint(covariant AmbientForgeGlowPainter oldDelegate) =>
      oldDelegate.breathingPhase != breathingPhase ||
      oldDelegate.intensity != intensity ||
      oldDelegate.moltenCore != moltenCore;
}

/// Sürekli 60fps çalışan ortam ocak parıltısı sarmalayıcı widget'ı.
class ForgeAmbientHeatShimmer extends StatefulWidget {
  const ForgeAmbientHeatShimmer({
    super.key,
    this.child,
    this.intensity = 1.0,
    this.active = true,
  });

  final Widget? child;
  final double intensity;
  final bool active;

  @override
  State<ForgeAmbientHeatShimmer> createState() => _ForgeAmbientHeatShimmerState();
}

class _ForgeAmbientHeatShimmerState extends State<ForgeAmbientHeatShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    if (widget.active) {
      _ctrl.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant ForgeAmbientHeatShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.active && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (BuildContext context, Widget? child) {
          return CustomPaint(
            painter: AmbientForgeGlowPainter(
              breathingPhase: _ctrl.value,
              intensity: widget.intensity,
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 4. SUCCESS SHOCKWAVE & CELESTIAL STARDUST BURST (BAŞARI VE YILDIZ TOZU)
// ────────────────────────────────────────────────────────────────────────────

/// Başarı kutlamasında yukarı doğru saçılan spiral göksel yıldız tozu taneleri.
class SuccessBurstParticlesPainter extends CustomPainter {
  SuccessBurstParticlesPainter({
    required this.progress,
    this.centerOffset = Offset.zero,
    this.goldColor = AppColors.gold,
    this.cyanColor = AppColors.accentCyan,
    this.particleCount = 36,
    this.seed = 77,
  }) : _motes = _generateMotes(particleCount, seed);

  final double progress; // 0..1
  final Offset centerOffset;
  final Color goldColor;
  final Color cyanColor;
  final int particleCount;
  final int seed;

  final List<_StardustMote> _motes;

  static List<_StardustMote> _generateMotes(int count, int seed) {
    final math.Random rnd = math.Random(seed);
    return List<_StardustMote>.generate(count, (int i) {
      final double angle = rnd.nextDouble() * math.pi * 2;
      final double distMax = 50.0 + rnd.nextDouble() * 120.0;
      final double riseY = -60.0 - rnd.nextDouble() * 100.0;
      final double driftX = (rnd.nextDouble() - 0.5) * 50.0;
      final double size = 1.5 + rnd.nextDouble() * 2.5;
      final double twinkleFreq = 12.0 + rnd.nextDouble() * 18.0;
      final bool isCyan = rnd.nextDouble() > 0.65;

      return _StardustMote(
        angle: angle,
        distMax: distMax,
        riseY: riseY,
        driftX: driftX,
        size: size,
        twinkleFreq: twinkleFreq,
        isCyan: isCyan,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1.0) return;

    final Offset center = centerOffset == Offset.zero
        ? Offset(size.width / 2, size.height * 0.52)
        : centerOffset;

    final Paint motePaint = Paint();
    final double tEase = Curves.easeOutCubic.transform(progress);
    final double fade = (1.0 - progress).clamp(0.0, 1.0);

    for (final _StardustMote m in _motes) {
      final double radialDist = tEase * m.distMax;
      final double px = center.dx +
          math.cos(m.angle) * radialDist +
          tEase * m.driftX;
      final double py = center.dy +
          math.sin(m.angle) * (radialDist * 0.6) +
          tEase * m.riseY;

      final double twinkle =
          0.6 + 0.4 * math.sin(progress * m.twinkleFreq);
      final double alpha = (fade * twinkle).clamp(0.0, 1.0);

      final Color col = m.isCyan ? cyanColor : goldColor;

      motePaint
        ..color = col.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawCircle(Offset(px, py), m.size * (1.0 - progress * 0.3), motePaint);

      // Akkor merkez
      motePaint
        ..color = Colors.white.withValues(alpha: alpha)
        ..maskFilter = null;
      canvas.drawCircle(Offset(px, py), m.size * 0.45, motePaint);
    }
  }

  @override
  bool shouldRepaint(covariant SuccessBurstParticlesPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.centerOffset != centerOffset;
}

class _StardustMote {
  const _StardustMote({
    required this.angle,
    required this.distMax,
    required this.riseY,
    required this.driftX,
    required this.size,
    required this.twinkleFreq,
    required this.isCyan,
  });

  final double angle;
  final double distMax;
  final double riseY;
  final double driftX;
  final double size;
  final double twinkleFreq;
  final bool isCyan;
}

/// Başarı anında genişleyen çok katmanlı altın ve gök mavisi (cyan) enerji halkası.
class SuccessShockwavePainter extends CustomPainter {
  SuccessShockwavePainter({
    required this.progress,
    this.centerOffset = Offset.zero,
    this.primaryGold = AppColors.gold,
    this.cyanEnergy = AppColors.accentCyan,
    this.maxRadius = 220.0,
  });

  final double progress; // 0..1
  final Offset centerOffset;
  final Color primaryGold;
  final Color cyanEnergy;
  final double maxRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1.0) return;

    final Offset center = centerOffset == Offset.zero
        ? Offset(size.width / 2, size.height * 0.52)
        : centerOffset;

    // 1. Radyal Ekran Parıltısı (Screen Flash) — ilk 35%'te parlar, hızla söner
    final double flashAlpha =
        (1.0 - Curves.easeOutQuad.transform((progress / 0.55).clamp(0.0, 1.0))) *
            0.65;
    if (flashAlpha > 0.01) {
      final Rect flashRect =
          Rect.fromCircle(center: center, radius: maxRadius * 1.25);
      final Paint flashPaint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: flashAlpha),
            cyanEnergy.withValues(alpha: flashAlpha * 0.70),
            primaryGold.withValues(alpha: flashAlpha * 0.35),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.25, 0.60, 1.0],
        ).createShader(flashRect);
      canvas.drawCircle(center, maxRadius * 1.25, flashPaint);
    }

    // 2. Dış Altın Şok Dalgası (Primary Outer Shockwave)
    final double outerT = Curves.easeOutQuart.transform(progress);
    final double outerRadius = outerT * maxRadius;
    final double outerAlpha = (1.0 - progress).clamp(0.0, 1.0);
    final double outerThickness = (10.0 * (1.0 - progress)).clamp(1.5, 10.0);

    // Dış hale parlama (Glow)
    canvas.drawCircle(
      center,
      outerRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerThickness * 2.8
        ..color = primaryGold.withValues(alpha: (outerAlpha * 0.45).clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0),
    );

    // Dış çekirdek çizgi (SweepGradient ile dönen ışık efekti)
    canvas.drawCircle(
      center,
      outerRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerThickness
        ..shader = SweepGradient(
          colors: <Color>[
            primaryGold,
            Colors.white,
            primaryGold,
            Colors.white.withValues(alpha: 0.9),
            primaryGold,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: outerRadius + 1)),
    );

    // 3. İç Göksel Cyan Enerji Dalgası (Inner Celestial Cyan Wave)
    final double innerProgress = (progress - 0.08).clamp(0.0, 1.0);
    if (innerProgress > 0) {
      final double innerT = Curves.easeOutCubic.transform(innerProgress);
      final double innerRadius = innerT * (maxRadius * 0.78);
      final double innerAlpha = (1.0 - innerProgress).clamp(0.0, 1.0);

      canvas.drawCircle(
        center,
        innerRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (5.0 * (1.0 - innerProgress)).clamp(1.0, 5.0)
          ..color = cyanEnergy.withValues(alpha: (innerAlpha * 0.75).clamp(0.0, 1.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0),
      );
    }

    // 4. Merkezden fışkıran 8 yönlü prizmatik ışık huzmeleri
    if (progress < 0.6) {
      final double rayT = progress / 0.6;
      final double rayLen = 40.0 + rayT * (maxRadius * 0.85);
      final double rayAlpha = (1.0 - rayT) * 0.8;
      final Paint rayPaint = Paint()
        ..strokeWidth = 2.0 * (1.0 - rayT)
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0)
        ..color = Colors.white.withValues(alpha: rayAlpha.clamp(0.0, 1.0));

      for (int i = 0; i < 8; i++) {
        final double ang = (i * math.pi / 4.0) + (progress * 0.4);
        final Offset start = Offset(
          center.dx + math.cos(ang) * (rayLen * 0.25),
          center.dy + math.sin(ang) * (rayLen * 0.25),
        );
        final Offset end = Offset(
          center.dx + math.cos(ang) * rayLen,
          center.dy + math.sin(ang) * rayLen,
        );
        canvas.drawLine(start, end, rayPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SuccessShockwavePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.centerOffset != centerOffset;
}

/// Başarı anında beliren, yukarı doğru süzülen neon +N seviye dalgası rozeti.
class FloatingLevelSurgeWidget extends StatelessWidget {
  const FloatingLevelSurgeWidget({
    super.key,
    required this.progress,
    required this.levelText,
    this.accentColor = AppColors.gold,
    this.cyanColor = AppColors.accentCyan,
  });

  final double progress; // 0..1
  final String levelText;
  final Color accentColor;
  final Color cyanColor;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0 || progress >= 1.0) return const SizedBox.shrink();

    // Girişte elastik patlama, ardından yukarı süzülme ve sönme
    final double scale = progress < 0.35
        ? Curves.elasticOut.transform(progress / 0.35) * 1.15
        : (1.15 - (progress - 0.35) * 0.22).clamp(0.9, 1.2);

    final double translateY = -48.0 * Curves.easeOutCubic.transform(progress);
    final double alpha = progress > 0.65
        ? (1.0 - (progress - 0.65) / 0.35).clamp(0.0, 1.0)
        : 1.0;

    return Transform.translate(
      offset: Offset(0, translateY),
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: alpha,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Rünik Çember ve Seviye Metni
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
                  gradient: LinearGradient(
                    colors: <Color>[
                      AppColors.carbonVoid.withValues(alpha: 0.90),
                      AppColors.bgSurface.withValues(alpha: 0.95),
                    ],
                  ),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.85),
                    width: 2.0,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.55),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: cyanColor.withValues(alpha: 0.35),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.keyboard_double_arrow_up_rounded,
                      color: cyanColor,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      levelText,
                      style: AppTextStyles.h1.copyWith(
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w900,
                        foreground: Paint()
                          ..shader = LinearGradient(
                            colors: <Color>[
                              Colors.white,
                              accentColor,
                              cyanColor,
                            ],
                          ).createShader(const Rect.fromLTWH(0, 0, 120, 32)),
                        shadows: <Shadow>[
                          Shadow(
                            color: accentColor.withValues(alpha: 0.9),
                            blurRadius: 8,
                          ),
                          Shadow(
                            color: cyanColor.withValues(alpha: 0.8),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 5. FAILURE FRACTURE & SHATTERED RUNES (BAŞARISIZLIK VE RÜN PARÇALANMASI)
// ────────────────────────────────────────────────────────────────────────────

class _RuneShardData {
  _RuneShardData({
    required this.angle,
    required this.speed,
    required this.spinSpeed,
    required this.polygon,
    required this.scale,
    required this.tumbleRate,
    required this.color,
  });

  final double angle;
  final double speed;
  final double spinSpeed;
  final List<Offset> polygon;
  final double scale;
  final double tumbleRate;
  final Color color;
}

class _SmokePuffData {
  _SmokePuffData({
    required this.offset,
    required this.maxRadius,
    required this.driftY,
    required this.driftX,
    required this.phase,
    required this.color,
  });

  final Offset offset;
  final double maxRadius;
  final double driftY;
  final double driftX;
  final double phase;
  final Color color;
}

/// Başarısızlık veya kırılma anında derin mor / kan kırmızısı çatlak şok dalgası,
/// parçalanan rün kristalleri ve dağılan duman bulutu.
class FailureFracturePainter extends CustomPainter {
  FailureFracturePainter({
    required this.progress,
    this.centerOffset = Offset.zero,
    this.crimson = AppColors.mysticRuby,
    this.abyssalViolet = AppColors.accentPurple,
    this.isDestroyed = false,
    this.seed = 88,
  })  : _shards = _generateShards(seed, isDestroyed ? 28 : 18, crimson, abyssalViolet),
        _smokePuffs = _generateSmoke(seed, isDestroyed ? 20 : 12, crimson, abyssalViolet);

  final double progress; // 0..1
  final Offset centerOffset;
  final Color crimson;
  final Color abyssalViolet;
  final bool isDestroyed;
  final int seed;

  final List<_RuneShardData> _shards;
  final List<_SmokePuffData> _smokePuffs;

  static List<_RuneShardData> _generateShards(
    int seed,
    int count,
    Color crimson,
    Color abyssalViolet,
  ) {
    final math.Random rnd = math.Random(seed);
    return List<_RuneShardData>.generate(count, (int i) {
      final double angle = rnd.nextDouble() * math.pi * 2;
      final double speed = 90.0 + rnd.nextDouble() * 240.0;
      final double spin =
          (rnd.nextBool() ? 1.0 : -1.0) * (3.0 + rnd.nextDouble() * 8.0);
      final double scale = 0.85 + rnd.nextDouble() * 1.5;
      final double tumble = 2.0 + rnd.nextDouble() * 5.0;

      // Kristal / rünik kırık çokgeni (üçgen veya dörtgen)
      final int sides = rnd.nextBool() ? 3 : 4;
      final List<Offset> poly = <Offset>[];
      for (int s = 0; s < sides; s++) {
        final double a = (s * math.pi * 2 / sides) + rnd.nextDouble() * 0.5;
        final double r = (4.0 + rnd.nextDouble() * 9.0);
        poly.add(Offset(math.cos(a) * r, math.sin(a) * r));
      }

      final Color shardColor = rnd.nextDouble() > 0.45 ? crimson : abyssalViolet;

      return _RuneShardData(
        angle: angle,
        speed: speed,
        spinSpeed: spin,
        polygon: poly,
        scale: scale,
        tumbleRate: tumble,
        color: shardColor,
      );
    });
  }

  static List<_SmokePuffData> _generateSmoke(
    int seed,
    int count,
    Color crimson,
    Color abyssalViolet,
  ) {
    final math.Random rnd = math.Random(seed + 101);
    return List<_SmokePuffData>.generate(count, (int i) {
      final double a = rnd.nextDouble() * math.pi * 2;
      final double d = 8.0 + rnd.nextDouble() * 28.0;
      final Offset initial = Offset(math.cos(a) * d, math.sin(a) * d);
      final double maxR = 24.0 + rnd.nextDouble() * 34.0;
      final double dy = -25.0 - rnd.nextDouble() * 45.0;
      final double dx = (rnd.nextDouble() - 0.5) * 40.0;
      final double phase = rnd.nextDouble() * math.pi * 2;
      final Color col = rnd.nextDouble() > 0.55
          ? crimson.withValues(alpha: 0.35)
          : abyssalViolet.withValues(alpha: 0.40);

      return _SmokePuffData(
        offset: initial,
        maxRadius: maxR,
        driftY: dy,
        driftX: dx,
        phase: phase,
        color: col,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1.0) return;

    final Offset center = centerOffset == Offset.zero
        ? Offset(size.width / 2, size.height * 0.52)
        : centerOffset;

    // 1. Dağılan Duman Bulutu (Smoke Dissipation)
    for (final _SmokePuffData p in _smokePuffs) {
      final double smokeT = Curves.easeOutCubic.transform(progress);
      final double curRadius = 6.0 + smokeT * p.maxRadius;
      final double px = center.dx + p.offset.dx + smokeT * p.driftX;
      final double py = center.dy + p.offset.dy + smokeT * p.driftY;
      final double alpha = (1.0 - progress).clamp(0.0, 1.0) * 0.45;

      canvas.drawCircle(
        Offset(px, py),
        curRadius,
        Paint()
          ..color = p.color.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0),
      );
    }

    // 2. Kırık Çatlak Şok Dalgası (Jagged Fracture Shockwave)
    final double fractureT = Curves.easeOutQuart.transform(progress);
    final double maxR =
        (size.width < size.height ? size.width : size.height) * (isDestroyed ? 0.65 : 0.55);
    final double radius = fractureT * maxR;
    final double shockAlpha = (1.0 - progress).clamp(0.0, 1.0);

    if (shockAlpha > 0.01) {
      final Path fracturePath = Path();
      const int steps = 20;
      for (int i = 0; i <= steps; i++) {
        final double theta = (i / steps) * math.pi * 2;
        // Pürüzlü, çatlak radyal varyasyon
        final double jitter =
            math.sin(theta * 7.0 + seed) * (10.0 * (1.0 - progress));
        final double r = radius + jitter;
        final double x = center.dx + math.cos(theta) * r;
        final double y = center.dy + math.sin(theta) * r;
        if (i == 0) {
          fracturePath.moveTo(x, y);
        } else {
          fracturePath.lineTo(x, y);
        }
      }
      fracturePath.close();

      // Dış mor/kırmızı çatlak parıltısı
      canvas.drawPath(
        fracturePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (6.5 * (1.0 - progress)).clamp(1.5, 6.5)
          ..color = abyssalViolet.withValues(alpha: (shockAlpha * 0.65).clamp(0.0, 1.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0),
      );

      // İç keskin kırmızı çekirdek
      canvas.drawPath(
        fracturePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (2.4 * (1.0 - progress)).clamp(0.8, 2.4)
          ..color = crimson.withValues(alpha: shockAlpha.clamp(0.0, 1.0)),
      );
    }

    // 3. Parçalanan Rün Kristalleri (Shattered Rune Shards)
    final Paint shardFillPaint = Paint()..style = PaintingStyle.fill;
    final Paint shardBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    for (final _RuneShardData s in _shards) {
      final double shardT = Curves.easeOutQuad.transform(progress);
      final double dist = shardT * s.speed;

      // Yerçekimi aşağı çeker
      final double gravityOffset = 190.0 * (progress * progress);
      final double px = center.dx + math.cos(s.angle) * dist;
      final double py = center.dy + math.sin(s.angle) * dist + gravityOffset;

      // 3D takla açısı ve dönüşü
      final double spinAngle = s.spinSpeed * progress;
      final double tumbleScaleX = math.cos(progress * s.tumbleRate * math.pi);
      final double alpha = (1.0 - progress).clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(spinAngle);
      canvas.scale(tumbleScaleX * s.scale, s.scale);

      final Path polyPath = Path();
      for (int i = 0; i < s.polygon.length; i++) {
        final Offset pt = s.polygon[i];
        if (i == 0) {
          polyPath.moveTo(pt.dx, pt.dy);
        } else {
          polyPath.lineTo(pt.dx, pt.dy);
        }
      }
      polyPath.close();

      // Gövde: Karanlık obsidyen / ametist dolgu
      shardFillPaint.color =
          AppColors.carbonVoid.withValues(alpha: (alpha * 0.95).clamp(0.0, 1.0));
      canvas.drawPath(polyPath, shardFillPaint);

      // Kenar: Parlak mor/crimson ışık çizgisi
      shardBorderPaint.color = s.color.withValues(alpha: alpha);
      canvas.drawPath(polyPath, shardBorderPaint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant FailureFracturePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.centerOffset != centerOffset ||
      oldDelegate.isDestroyed != isDestroyed;
}

// ────────────────────────────────────────────────────────────────────────────
// 6. UNIFIED VFX CONTROLLER & COMPLETE EFFECTS OVERLAY LAYER
// ────────────────────────────────────────────────────────────────────────────

/// Güçlendirme görsel fazı
enum ForgeVfxState {
  idle,
  striking,
  success,
  failure,
  destroyed,
}

/// Tüm VFX olaylarını (örs darbesi, başarı şoku, kırılma) senkronize eden kontrolcü.
class EnhancementForgeVfxController extends ChangeNotifier {
  EnhancementForgeVfxController({
    TickerProvider? vsync,
  }) {
    if (vsync != null) {
      initControllers(vsync);
    }
  }

  late AnimationController _strikeCtrl;
  late AnimationController _resultCtrl;
  bool _initialized = false;

  ForgeVfxState _state = ForgeVfxState.idle;
  ForgeVfxState get state => _state;

  int _surgeLevel = 1;
  int get surgeLevel => _surgeLevel;

  Offset _impactPoint = Offset.zero;
  Offset get impactPoint => _impactPoint;

  Animation<double> get strikeAnimation => _strikeCtrl;
  Animation<double> get resultAnimation => _resultCtrl;

  void initControllers(TickerProvider vsync) {
    if (_initialized) return;
    _strikeCtrl = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 700),
    )..addListener(notifyListeners);

    _resultCtrl = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 1100),
    )..addListener(notifyListeners);

    _initialized = true;
  }

  /// Örs darbesi başlat (kıvılcım patlaması & çekiç darbe dalgası)
  void triggerAnvilStrike({
    Offset? point,
    VoidCallback? onImpact,
    VoidCallback? onComplete,
  }) {
    if (!_initialized) return;
    _state = ForgeVfxState.striking;
    if (point != null) _impactPoint = point;
    onImpact?.call();
    _strikeCtrl.forward(from: 0.0).whenCompleteOrCancel(() {
      onComplete?.call();
    });
  }

  /// Başarı şok dalgası ve seviye yükselişi başlat
  void triggerSuccess({required int newLevel, Offset? point}) {
    if (!_initialized) return;
    _state = ForgeVfxState.success;
    _surgeLevel = newLevel;
    if (point != null) _impactPoint = point;
    _resultCtrl.forward(from: 0.0);
  }

  /// Başarısızlık / kırılma efekti başlat
  void triggerFailure({bool isDestroyed = false, Offset? point}) {
    if (!_initialized) return;
    _state = isDestroyed ? ForgeVfxState.destroyed : ForgeVfxState.failure;
    if (point != null) _impactPoint = point;
    _resultCtrl.forward(from: 0.0);
  }

  /// Ocağı varsayılan duruma sıfırla
  void reset() {
    if (!_initialized) return;
    _strikeCtrl.reset();
    _resultCtrl.reset();
    _state = ForgeVfxState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_initialized) {
      _strikeCtrl.dispose();
      _resultCtrl.dispose();
    }
    super.dispose();
  }
}

/// Tüm ocağın üzerine tek bir RepaintBoundary içinde binen eksiksiz VFX katmanı.
class EnhancementForgeEffectsLayer extends StatelessWidget {
  const EnhancementForgeEffectsLayer({
    super.key,
    required this.vfxState,
    this.strikeProgress = 0.0,
    this.resultProgress = 0.0,
    this.surgeLevel = 1,
    this.impactOffset = Offset.zero,
    this.child,
    this.enableAmbientGlow = true,
  });

  final ForgeVfxState vfxState;
  final double strikeProgress;
  final double resultProgress;
  final int surgeLevel;
  final Offset impactOffset;
  final Widget? child;
  final bool enableAmbientGlow;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          // 1. Zemin Ortam Sıcaklık Işıması (Konveksiyonel Isı Shimmer)
          if (enableAmbientGlow)
            const Positioned.fill(
              child: ForgeAmbientHeatShimmer(),
            ),

          // 2. Ana İçerik
          if (child != null) child!,

          // 3. Örs Darbe Kıvılcımları & Çekiç Darbe Dalgası (Çekiç Vuruşu Fazı)
          if (strikeProgress > 0.0 && strikeProgress < 1.0) ...<Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: AnvilImpactWavePainter(
                    progress: strikeProgress,
                    origin: impactOffset,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: AnvilStrikeSparksPainter(
                    progress: strikeProgress,
                    origin: impactOffset,
                  ),
                ),
              ),
            ),
          ],

          // 4. Başarı Şok Dalgası, Işık Flaşı ve Yıldız Tozu Patlaması
          if (vfxState == ForgeVfxState.success &&
              resultProgress > 0.0 &&
              resultProgress < 1.0) ...<Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: SuccessShockwavePainter(
                    progress: resultProgress,
                    centerOffset: impactOffset,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: SuccessBurstParticlesPainter(
                    progress: resultProgress,
                    centerOffset: impactOffset,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 24,
              child: IgnorePointer(
                child: Center(
                  child: FloatingLevelSurgeWidget(
                    progress: resultProgress,
                    levelText: '+$surgeLevel',
                  ),
                ),
              ),
            ),
          ],

          // 5. Başarısızlık / Parçalanma Şok Dalgası ve Duman
          if ((vfxState == ForgeVfxState.failure ||
                  vfxState == ForgeVfxState.destroyed) &&
              resultProgress > 0.0 &&
              resultProgress < 1.0)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: FailureFracturePainter(
                    progress: resultProgress,
                    centerOffset: impactOffset,
                    isDestroyed: vfxState == ForgeVfxState.destroyed,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 7. LEGACY & REFINED COMPATIBILITY CLASSES
// Mevcut ekran kodları ve testleriyle %100 uyumluluk için korunmuştur.
// ────────────────────────────────────────────────────────────────────────────

/// Item çevresinde başarı şansını gösteren neon arc halkası.
/// [progress] 0..1 — şans yüzdesi; [rotation] 0..1 — hafif dönüş.
class ChanceRingPainter extends CustomPainter {
  const ChanceRingPainter({
    required this.progress,
    required this.rotation,
    required this.color,
    this.trackOpacity = 0.10,
  });

  final double progress;
  final double rotation;
  final Color color;
  final double trackOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2 - 6;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    // Zemin halkası
    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: trackOpacity);
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    // Şans arc'ı — gradient + glow
    final double sweep = math.pi * 2 * progress.clamp(0.0, 1.0);
    final double start = -math.pi / 2 + rotation * math.pi * 2;

    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
      ..color = color.withValues(alpha: 0.45);
    canvas.drawArc(rect, start, sweep, false, glow);

    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        transform: GradientRotation(start),
        colors: <Color>[
          color.withValues(alpha: 0.25),
          color,
          Colors.white.withValues(alpha: 0.9),
        ],
        stops: const <double>[0.0, 0.7, 1.0],
      ).createShader(rect);
    canvas.drawArc(rect, start, sweep, false, arc);

    // Uç noktada parlak nokta
    if (progress > 0.02) {
      final double endAngle = start + sweep;
      final Offset tip = Offset(
        center.dx + radius * math.cos(endAngle),
        center.dy + radius * math.sin(endAngle),
      );
      canvas.drawCircle(
        tip,
        4.5,
        Paint()
          ..color = Colors.white
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(tip, 2.2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant ChanceRingPainter old) =>
      old.progress != progress || old.rotation != rotation || old.color != color;
}

/// Item etrafında dönen küçük ember/enerji parçacıkları.
class OrbitParticlesPainter extends CustomPainter {
  OrbitParticlesPainter({
    required this.t,
    required this.color,
    this.intensity = 1.0,
  });

  final double t; // 0..1 loop
  final Color color;
  final double intensity;

  static final List<_OrbitSpec> _specs = List<_OrbitSpec>.generate(14, (int i) {
    final math.Random rnd = math.Random(i * 97 + 13);
    return _OrbitSpec(
      radiusFactor: 0.62 + rnd.nextDouble() * 0.46,
      speed: (rnd.nextBool() ? 1 : -1) * (0.4 + rnd.nextDouble() * 0.9),
      phase: rnd.nextDouble() * math.pi * 2,
      size: 1.2 + rnd.nextDouble() * 2.0,
      wobble: rnd.nextDouble() * 6,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double base = math.min(size.width, size.height) / 2;

    for (final _OrbitSpec s in _specs) {
      final double angle = s.phase + t * math.pi * 2 * s.speed;
      final double r =
          base * s.radiusFactor + math.sin(t * math.pi * 4 + s.phase) * s.wobble;
      final Offset pos = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle) * 0.86,
      );
      final double alpha =
          (0.25 + 0.5 * (0.5 + 0.5 * math.sin(angle * 2))) * intensity;
      canvas.drawCircle(
        pos,
        s.size * intensity.clamp(0.6, 1.6),
        Paint()
          ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant OrbitParticlesPainter old) =>
      old.t != t || old.color != color || old.intensity != intensity;
}

class _OrbitSpec {
  const _OrbitSpec({
    required this.radiusFactor,
    required this.speed,
    required this.phase,
    required this.size,
    required this.wobble,
  });

  final double radiusFactor;
  final double speed;
  final double phase;
  final double size;
  final double wobble;
}

/// Sonuç anında merkezden dışa saçılan kıvılcım patlaması.
class SparkBurstPainter extends CustomPainter {
  SparkBurstPainter({
    required this.t,
    required this.color,
    this.seed = 7,
  });

  final double t; // 0..1
  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final math.Random rnd = math.Random(seed);
    final double maxR = math.min(size.width, size.height) * 0.62;

    for (int i = 0; i < 28; i++) {
      final double angle = rnd.nextDouble() * math.pi * 2;
      final double speed = 0.45 + rnd.nextDouble() * 0.55;
      final double dist = Curves.easeOutCubic.transform(t) * maxR * speed;
      final Offset pos = Offset(
        center.dx + dist * math.cos(angle),
        center.dy + dist * math.sin(angle),
      );
      final double fade = (1 - t) * (0.5 + rnd.nextDouble() * 0.5);
      final double len = 3 + rnd.nextDouble() * 8 * (1 - t);

      final Paint p = Paint()
        ..color = (rnd.nextDouble() > 0.35 ? color : Colors.white)
            .withValues(alpha: fade.clamp(0.0, 1.0))
        ..strokeWidth = 1.4 + rnd.nextDouble()
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        pos,
        Offset(pos.dx + len * math.cos(angle), pos.dy + len * math.sin(angle)),
        p,
      );
    }

    // Merkez şok halkası
    final double ringR = Curves.easeOutQuart.transform(t) * maxR;
    canvas.drawCircle(
      center,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * (1 - t)
        ..color = color.withValues(alpha: (0.5 * (1 - t)).clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  @override
  bool shouldRepaint(covariant SparkBurstPainter old) =>
      old.t != t || old.color != color;
}

/// Butonun veya kartın üstünden geçen ışık süpürmesi (shimmer sweep).
class ShimmerSweep extends StatelessWidget {
  const ShimmerSweep({
    super.key,
    required this.t,
    required this.borderRadius,
  });

  final double t; // 0..1 loop
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final double w = c.maxWidth;
            final double dx = (t * 2.2 - 0.6) * w;
            return Transform.translate(
              offset: Offset(dx, 0),
              child: Transform.rotate(
                angle: -0.5,
                child: Container(
                  width: w * 0.28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.22),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Güçlendirme ocağı dış çerçevesinde saat yönünde dönen parlayan arc.
class RotatingForgeBorderPainter extends CustomPainter {
  const RotatingForgeBorderPainter({
    required this.rotation,
    required this.color,
    this.borderRadius = AppSpacing.radiusMd,
    this.padding = 1.5,
    this.arcFraction = 0.24,
  });

  final double rotation;
  final Color color;
  final double borderRadius;
  final double padding;
  final double arcFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        padding,
        padding,
        size.width - padding * 2,
        size.height - padding * 2,
      ),
      Radius.circular(borderRadius),
    );
    final Path path = Path()..addRRect(rrect);
    final ui.PathMetric metric = path.computeMetrics().first;
    final double length = metric.length;
    if (length <= 0) return;

    final Paint dimTrack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: 0.18);
    canvas.drawPath(path, dimTrack);

    final double arcLen = length * arcFraction;
    final double start = (rotation % 1.0) * length;
    final Path arcPath = metric.extractPath(start, start + arcLen);

    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(arcPath, glow);

    final Paint core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawPath(arcPath, core);
  }

  @override
  bool shouldRepaint(covariant RotatingForgeBorderPainter old) =>
      old.rotation != rotation || old.color != color;
}

class ForgeRotatingBorderGlow extends StatelessWidget {
  const ForgeRotatingBorderGlow({
    super.key,
    required this.rotation,
    required this.color,
    required this.child,
    this.borderRadius = AppSpacing.radiusMd,
  });

  final double rotation;
  final Color color;
  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: RotatingForgeBorderPainter(
        rotation: rotation,
        color: color,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}

/// Sonuç fazı — tam çerçeve sabit parlar (dönmez).
class StaticForgeBorderPainter extends CustomPainter {
  const StaticForgeBorderPainter({
    required this.color,
    this.borderRadius = AppSpacing.radiusMd,
    this.padding = 1.5,
  });

  final Color color;
  final double borderRadius;
  final double padding;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        padding,
        padding,
        size.width - padding * 2,
        size.height - padding * 2,
      ),
      Radius.circular(borderRadius),
    );
    final Path path = Path()..addRRect(rrect);

    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..color = color.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawPath(path, glow);

    final Paint core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = color.withValues(alpha: 0.95);
    canvas.drawPath(path, core);
  }

  @override
  bool shouldRepaint(covariant StaticForgeBorderPainter old) => old.color != color;
}

class ForgeStaticBorderGlow extends StatelessWidget {
  const ForgeStaticBorderGlow({
    super.key,
    required this.color,
    required this.child,
    this.borderRadius = AppSpacing.radiusMd,
  });

  final Color color;
  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: StaticForgeBorderPainter(
        color: color,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}

/// Sonuç flaşı — tüm forge alanını renkle yıkayıp söner.
class ResultFlash extends StatelessWidget {
  const ResultFlash({
    super.key,
    required this.t,
    required this.color,
  });

  final double t; // 0..1
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (t <= 0 || t >= 1) return const SizedBox.shrink();
    final double alpha = (1 - Curves.easeOutQuad.transform(t)) * 0.50;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: <Color>[
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
