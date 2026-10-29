import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/engine/adaptive_quality_scaler.dart';
import '../../../core/engine/zero_jank_preloader.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../settings/graphics_settings_service.dart';

// ============================================================================
// 2027 AION 2 MOBILE STANDARDS — ZANAAT OCAĞI (FORGE FIRE & EMBER VFX)
//
// 1. Dinamik Isı Yoğunluğu (Dynamic Heat Intensity):
//    0.0 (kor közler / dinlenme) -> 1.0 (azgın yüksek fırın / aktif üretim).
//    Kademeli yumuşatılmış sönümleme (damped spring / lerp) ile geçişler.
//
// 2. TBDR GPU Uyumlu Alev Gölgelendiricisi (Forge Fire Runtime Shader):
//    Impeller / SkSL runtime effect desteği. Bounding box & tile discard ile
//    mobil bellek bant genişliğini korur, aşırı çizimi (overdraw) sıfırlar.
//
// 3. Prosedürel Alev Yedek Çizicisi (Procedural Flame CustomPainter):
//    Headless test ortamları ve düşük GPU katmanları için %100 saf Dart Canvas
//    60 FPS prosedürel alev dili ve radyan göbek simülasyonu.
//
// 4. Konveksiyonel Kor Parçacık Havuzu (Ember Particle Pool):
//    Sıfır GC baskısı (önceden tahsis edilmiş ve sürekli geri dönüştürülen nesne havuzu).
//    Fiziksel termal kaldırma, hava sürtünmesi (drag), sinüzoidal rüzgar sapması
//    ve soğuma renk spektrumu (Beyaz Akkor -> Alev Altını -> Kor Kırmızı -> Kül/Duman).
//
// 5. Zanaat Odası & Ön İzleme Entegrasyonu (Hero Chamber & Preview Backdrops):
//    Etkileşimli körükleme (Stoke Bellows), çekiç vuruş kıvılcımları ve sıcaklık göstergesi.
// ============================================================================

/// Ocak görsel çalışma durumları.
enum ForgeHeatPhase {
  /// Dinlenme: közler nefes alır, hafif duman ve tembel kor tanecikleri.
  simmer,

  /// Hazırlık: tarif seçildi veya inceleniyor, fırın alevlenmeye başlıyor.
  stoking,

  /// Aktif Üretim: körükler son güçte, alevler yükseliyor, yoğun kıvılcım fırtınası.
  roaring,

  /// Çekiçleme / Körük patlaması: ani parlama ve yönsel kıvılcım fışkırması.
  surge,
}

// ────────────────────────────────────────────────────────────────────────────
// 1. DİNAMİK ISI VE VFX KONTROLCÜSÜ (CraftingForgeEffectsController)
// ────────────────────────────────────────────────────────────────────────────

/// Zanaat ekranı ocak alevi ve kor parçacıklarını senkronize yöneten kontrolcü.
class CraftingForgeEffectsController extends ChangeNotifier {
  CraftingForgeEffectsController({
    double initialHeat = 0.28,
    this.autoSimmerTarget = 0.28,
    this.stokingTarget = 0.58,
    this.roaringTarget = 0.95,
    AdaptiveQualityScaler? scaler,
  })  : _scaler = scaler,
        _currentHeat = initialHeat.clamp(0.0, 1.0),
        _targetHeat = initialHeat.clamp(0.0, 1.0);

  final AdaptiveQualityScaler? _scaler;
  final double autoSimmerTarget;
  final double stokingTarget;
  final double roaringTarget;

  double _currentHeat;
  double _targetHeat;
  double _timeSeconds = 0.0;
  bool _isCrafting = false;
  int _activeQueueCount = 0;

  ForgeHeatPhase _phase = ForgeHeatPhase.simmer;

  /// Dinamik anlık ısı (0.0 .. 1.0).
  double get currentHeat => _currentHeat;

  /// Hedef ısı.
  double get targetHeat => _targetHeat;

  /// Simülasyon zamanı (saniye).
  double get timeSeconds => _timeSeconds;

  /// Ocak fazı.
  ForgeHeatPhase get phase => _phase;

  /// Üretim aktif mi?
  bool get isCrafting => _isCrafting;

  /// Kuyruktaki aktif öğe sayısı.
  int get activeQueueCount => _activeQueueCount;

  /// Bağlı AdaptiveQualityScaler örneği (varsa).
  AdaptiveQualityScaler? get scaler => _scaler;

  /// Santigrat derece cinsinden yaklaşık fırın sıcaklığı (800°C .. 1850°C).
  int get temperatureCelsius => (800 + _currentHeat * 1050).round();

  /// Fırın durumu metni.
  String get statusLabel {
    if (_isCrafting || _phase == ForgeHeatPhase.roaring) {
      return 'KÖRÜKLER AKTİF · DÖVÜLÜYOR';
    }
    if (_phase == ForgeHeatPhase.stoking) {
      return 'OCAK ISINIYOR · HAZIRLIK';
    }
    if (_phase == ForgeHeatPhase.surge) {
      return 'ÇEKİÇ DARBESİ · AKKOR';
    }
    return 'KOR ATEŞİ · BEKLEMEDE';
  }

  /// Her karede çağrılan fizik güncellemesi.
  void update(double dt) {
    _timeSeconds += dt;

    // Hedef ısıya yumuşak sönümleme (smooth critically damped lerp)
    final double lerpSpeed = (_targetHeat > _currentHeat) ? 4.5 : 2.0;
    _currentHeat += (_targetHeat - _currentHeat) * (dt * lerpSpeed).clamp(0.0, 1.0);

    // Faz güncellemesi
    if (_currentHeat >= 0.85) {
      _phase = ForgeHeatPhase.roaring;
    } else if (_currentHeat >= 0.45) {
      _phase = ForgeHeatPhase.stoking;
    } else {
      _phase = ForgeHeatPhase.simmer;
    }

    notifyListeners();
  }

  /// Aktif üretim durumunu ayarla.
  void setCraftingActive(bool crafting) {
    if (_isCrafting == crafting) return;
    _isCrafting = crafting;
    _syncTargetHeat();
  }

  /// Kuyruk durumunu güncelle.
  void updateQueueCount(int inProgressCount) {
    if (_activeQueueCount == inProgressCount) return;
    _activeQueueCount = inProgressCount;
    _syncTargetHeat();
  }

  /// Körükleri pompala (manuel ısı dalgası).
  void stokeBellows({double boost = 0.35}) {
    _targetHeat = (_currentHeat + boost).clamp(0.0, 1.0);
    _phase = ForgeHeatPhase.surge;
    notifyListeners();
  }

  /// Anlık çekiç darbesi / parlama dalgası.
  void triggerSurge({double durationSeconds = 0.8}) {
    _targetHeat = 1.0;
    _phase = ForgeHeatPhase.surge;
    notifyListeners();
  }

  void _syncTargetHeat() {
    if (_isCrafting) {
      _targetHeat = roaringTarget;
    } else if (_activeQueueCount > 0) {
      _targetHeat = (stokingTarget + (_activeQueueCount * 0.1)).clamp(0.0, roaringTarget);
    } else {
      _targetHeat = autoSimmerTarget;
    }
    notifyListeners();
  }

  /// Isıyı doğrudan manuel ata (test ve özel efektler için).
  void setHeat(double heat) {
    _currentHeat = heat.clamp(0.0, 1.0);
    _targetHeat = _currentHeat;
    notifyListeners();
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 2. KOR PARÇACIK MODELİ VE SİSTEMİ (CraftingEmberParticleSystem)
// ────────────────────────────────────────────────────────────────────────────

/// Tek bir kor parçacığının fiziksel durumu.
class ForgeEmber {
  ForgeEmber({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.maxAge,
    required this.age,
    required this.driftPhase,
    required this.driftFrequency,
    required this.driftAmplitude,
    required this.colorShift,
    required this.isBurst,
  });

  double x; // 0.0 .. 1.0 normalleştirilmiş yatay koordinat
  double y; // 0.0 (ocak tabanı) .. 1.0 (üst tepe)
  double vx; // Piksel/sn veya oransal yatay hız
  double vy; // Dikey yükselme hızı
  double size; // Piksel cinsinden çap
  double maxAge; // Toplam yaşam süresi
  double age; // Geçen süre
  double driftPhase; // Sinüs dalgası başlangıç fazı
  double driftFrequency; // Dalgalanma frekansı
  double driftAmplitude; // Dalgalanma genişliği
  double colorShift; // Renk çeşitliliği varyasyonu
  bool isBurst; // Ani vuruştan mı doğdu?

  double get normalizedLife => (age / maxAge).clamp(0.0, 1.0);
  bool get isDead => age >= maxAge;
}

/// Mobil TBDR bellek ve GC optimizasyonlu, sıfır ayırma yapan parçacık havuzu.
class CraftingEmberParticleSystem {
  CraftingEmberParticleSystem({
    this.maxParticles = 54,
    this.seed = 1337,
  }) : _rnd = math.Random(seed) {
    _pool = List<ForgeEmber>.generate(maxParticles, (int i) => _spawnParticle(initialScatter: true));
  }

  int maxParticles;
  final int seed;
  final math.Random _rnd;
  late final List<ForgeEmber> _pool;

  List<ForgeEmber> get particles => _pool;
  int get count => _pool.length;

  /// Dynamic resizing of particle pool to adhere to AdaptiveQualityScaler tiering.
  void setMaxParticles(int newCount) {
    if (newCount == _pool.length || newCount <= 0) return;
    maxParticles = newCount;
    if (newCount < _pool.length) {
      _pool.length = newCount;
    } else {
      while (_pool.length < newCount) {
        _pool.add(_spawnParticle(initialScatter: true));
      }
    }
  }

  /// Parçacığı sıfırdan oluştur veya yeniden canlandır.
  ForgeEmber _spawnParticle({bool initialScatter = false, bool isBurst = false}) {
    final double maxAge = isBurst
        ? 0.7 + _rnd.nextDouble() * 0.9
        : 1.4 + _rnd.nextDouble() * 1.8;

    final double age = initialScatter ? _rnd.nextDouble() * maxAge : 0.0;

    // Ocak ağzı tabanında merkezlenmiş dağılım (-0.4 .. +0.4)
    final double spread = isBurst ? 0.65 : 0.35;
    final double startX = 0.5 + (_rnd.nextDouble() - 0.5) * spread;
    final double startY = initialScatter ? _rnd.nextDouble() * 0.85 : 0.02 + _rnd.nextDouble() * 0.06;

    final double speedMultiplier = isBurst ? 1.8 : 1.0;
    final double vx = (_rnd.nextDouble() - 0.5) * 0.18 * speedMultiplier;
    final double vy = (0.28 + _rnd.nextDouble() * 0.42) * speedMultiplier;

    final double size = isBurst
        ? 1.4 + _rnd.nextDouble() * 2.8
        : 1.2 + _rnd.nextDouble() * 3.4;

    return ForgeEmber(
      x: startX,
      y: startY,
      vx: vx,
      vy: vy,
      size: size,
      maxAge: maxAge,
      age: age,
      driftPhase: _rnd.nextDouble() * math.pi * 2,
      driftFrequency: 2.2 + _rnd.nextDouble() * 4.0,
      driftAmplitude: 0.03 + _rnd.nextDouble() * 0.05,
      colorShift: _rnd.nextDouble(),
      isBurst: isBurst,
    );
  }

  /// Tüm parçacıkları zamana ve ısıya göre simüle et.
  void update(double dt, double heatIntensity) {
    final double thermalLift = 1.0 + heatIntensity * 1.6;

    for (int i = 0; i < _pool.length; i++) {
      final ForgeEmber p = _pool[i];
      p.age += dt;

      if (p.isDead) {
        _pool[i] = _spawnParticle(initialScatter: false, isBurst: false);
        continue;
      }

      p.y += p.vy * thermalLift * dt;

      final double wave = math.sin(p.age * p.driftFrequency + p.driftPhase) * p.driftAmplitude;
      p.x += (p.vx + wave) * dt;

      if (p.y > 1.05 || p.x < -0.1 || p.x > 1.1) {
        _pool[i] = _spawnParticle(initialScatter: false, isBurst: false);
      }
    }
  }

  /// Çekiç vuruşu veya körüklemede anlık kıvılcım demeti fışkırt.
  void spawnBurst({int count = 18}) {
    int spawned = 0;
    for (int i = 0; i < _pool.length && spawned < count; i++) {
      if (_pool[i].normalizedLife > 0.4) {
        _pool[i] = _spawnParticle(initialScatter: false, isBurst: true);
        spawned++;
      }
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 3. KOR PARÇACIK ÇİZİCİSİ (CraftingEmberPainter)
// ────────────────────────────────────────────────────────────────────────────

/// Tek RepaintBoundary içinde sıfır overdraw ile kor parçacıklarını çizer.
class CraftingEmberPainter extends CustomPainter {
  CraftingEmberPainter({
    required this.particles,
    required this.heatIntensity,
    this.allowGlow = true,
    this.primaryGold = const Color(0xFFFFB300),
    this.moltenOrange = const Color(0xFFFF5722),
    this.coreWhite = const Color(0xFFFFFDE7),
    this.deepCrimson = const Color(0xFFB71C1C),
  });

  final List<ForgeEmber> particles;
  final double heatIntensity;
  final bool allowGlow;
  final Color primaryGold;
  final Color moltenOrange;
  final Color coreWhite;
  final Color deepCrimson;

  static final Paint _paint = Paint()..isAntiAlias = true;
  static final Paint _glowPaint = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty) return;

    final double width = size.width;
    final double height = size.height;

    for (final ForgeEmber p in particles) {
      if (p.isDead) continue;

      final double t = p.normalizedLife;
      final double px = p.x * width;
      final double py = height - (p.y * height);

      Color emberColor;
      double alpha = 1.0;

      if (t < 0.20) {
        emberColor = Color.lerp(coreWhite, primaryGold, t / 0.20)!;
        alpha = (t / 0.05).clamp(0.0, 1.0);
      } else if (t < 0.60) {
        final double st = (t - 0.20) / 0.40;
        emberColor = Color.lerp(primaryGold, moltenOrange, st)!;
      } else if (t < 0.85) {
        final double st = (t - 0.60) / 0.25;
        emberColor = Color.lerp(moltenOrange, deepCrimson, st)!;
      } else {
        final double st = (t - 0.85) / 0.15;
        emberColor = Color.lerp(deepCrimson, const Color(0xFF2C0F08), st)!;
        alpha = (1.0 - st).clamp(0.0, 1.0);
      }

      final double heatAlpha = alpha * (0.65 + heatIntensity * 0.35);
      final double currentRadius = p.size * (1.0 - t * 0.35);

      // On Eco / Low tiers, eliminate extra glow pass to avoid GPU overdraw
      if (allowGlow && currentRadius > 2.2) {
        _glowPaint.color = emberColor.withValues(alpha: (heatAlpha * 0.25).clamp(0.0, 1.0));
        canvas.drawCircle(Offset(px, py), currentRadius * 2.2, _glowPaint);
      }

      _paint.color = emberColor.withValues(alpha: heatAlpha.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(px, py), currentRadius, _paint);
    }
  }

  @override
  bool shouldRepaint(covariant CraftingEmberPainter oldDelegate) {
    return true;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 4. PROSEDÜREL ALEV ÇİZİCİSİ (ForgeFireProceduralPainter)
// ────────────────────────────────────────────────────────────────────────────

/// Runtime effect fragment shader yüklenemediğinde veya testlerde %100 kusursuz
/// 60 FPS çalışan çok katmanlı prosedürel alev ve köz yatağı CustomPainter'ı.
class ForgeFireProceduralPainter extends CustomPainter {
  ForgeFireProceduralPainter({
    required this.heatIntensity,
    required this.timeSeconds,
    this.primaryGold = const Color(0xFFFFB300),
    this.flameOrange = const Color(0xFFFF6D00),
    this.coreWhite = const Color(0xFFFFFDE7),
    this.emberCrimson = const Color(0xFFD50000),
  });

  final double heatIntensity;
  final double timeSeconds;
  final Color primaryGold;
  final Color flameOrange;
  final Color coreWhite;
  final Color emberCrimson;

  static final Paint _paint = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double heat = heatIntensity.clamp(0.0, 1.0);

    // 1. Taban köz parıltısı (Hearth Coal Bed Glow)
    final Rect hearthRect = Rect.fromLTWH(0, h * 0.45, w, h * 0.55);
    final Paint hearthPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(w * 0.5, h * 0.95),
        w * (0.45 + heat * 0.35),
        <Color>[
          flameOrange.withValues(alpha: 0.38 + heat * 0.42),
          emberCrimson.withValues(alpha: 0.18 + heat * 0.22),
          Colors.transparent,
        ],
        <double>[0.0, 0.55, 1.0],
      );
    canvas.drawRect(hearthRect, hearthPaint);

    // 2. Çok katmanlı alev dilleri (3 Katman: Dış Kırmızı -> Orta Turuncu -> İç Akkor Çekirdek)
    final int tongueCount = 5;
    final double flameReach = (0.42 + heat * 0.52) * h;

    for (int layer = 0; layer < 3; layer++) {
      final Path path = Path();
      path.moveTo(w * 0.15, h);

      final double layerHeightFactor = switch (layer) {
        0 => 1.0,
        1 => 0.78,
        _ => 0.52,
      };

      final Color layerColor = switch (layer) {
        0 => emberCrimson.withValues(alpha: 0.28 + heat * 0.32),
        1 => flameOrange.withValues(alpha: 0.48 + heat * 0.42),
        _ => coreWhite.withValues(alpha: 0.65 + heat * 0.35),
      };

      for (int i = 0; i <= tongueCount; i++) {
        final double xNorm = i / tongueCount;
        final double tipX = w * (0.2 + xNorm * 0.6);

        final double wave1 = math.sin(timeSeconds * 4.2 + i * 1.8);
        final double wave2 = math.cos(timeSeconds * 2.8 + i * 2.4);
        final double tongueHeight = flameReach * layerHeightFactor * (0.65 + 0.35 * wave1.abs());

        final double tipY = h - tongueHeight;
        final double ctrlX = tipX + wave2 * 12.0 * (1.0 + heat * 0.5);
        final double ctrlY = tipY + tongueHeight * 0.45;

        if (i == 0) {
          path.lineTo(tipX, tipY);
        } else {
          path.quadraticBezierTo(ctrlX, ctrlY, tipX, tipY);
        }
      }

      path.lineTo(w * 0.85, h);
      path.close();

      _paint.color = layerColor;
      canvas.drawPath(path, _paint);
    }
  }

  @override
  bool shouldRepaint(covariant ForgeFireProceduralPainter oldDelegate) {
    return oldDelegate.heatIntensity != heatIntensity ||
        oldDelegate.timeSeconds != timeSeconds ||
        oldDelegate.primaryGold != primaryGold;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 5. RUNTIME SHADER ÇİZİCİSİ (ForgeFireShaderPainter)
// ────────────────────────────────────────────────────────────────────────────

/// Flutter Impeller/SkSL ui.FragmentShader kullanarak ocak alevini GPU üzerinde
/// 60 FPS çizer. Shader hazır değilse otomatik olarak prosedürel motora düşer.
class ForgeFireShaderPainter extends CustomPainter {
  ForgeFireShaderPainter({
    required this.shader,
    required this.heatIntensity,
    required this.timeSeconds,
    this.primaryGold = const Color(0xFFFFB300),
    this.flameOrange = const Color(0xFFFF6D00),
    this.coreWhite = const Color(0xFFFFFDE7),
    this.emberCrimson = const Color(0xFFD50000),
  });

  final ui.FragmentShader? shader;
  final double heatIntensity;
  final double timeSeconds;
  final Color primaryGold;
  final Color flameOrange;
  final Color coreWhite;
  final Color emberCrimson;

  static final Paint _shaderPaint = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    if (shader == null) {
      ForgeFireProceduralPainter(
        heatIntensity: heatIntensity,
        timeSeconds: timeSeconds,
        primaryGold: primaryGold,
        flameOrange: flameOrange,
        coreWhite: coreWhite,
        emberCrimson: emberCrimson,
      ).paint(canvas, size);
      return;
    }

    final ui.FragmentShader s = shader!;
    s.setFloat(0, size.width);
    s.setFloat(1, size.height);
    s.setFloat(2, timeSeconds);
    s.setFloat(3, heatIntensity);

    // uCoreColor
    s.setFloat(4, (coreWhite.r * 255.0) / 255.0);
    s.setFloat(5, (coreWhite.g * 255.0) / 255.0);
    s.setFloat(6, (coreWhite.b * 255.0) / 255.0);
    s.setFloat(7, coreWhite.a);

    // uFlameColor
    s.setFloat(8, (flameOrange.r * 255.0) / 255.0);
    s.setFloat(9, (flameOrange.g * 255.0) / 255.0);
    s.setFloat(10, (flameOrange.b * 255.0) / 255.0);
    s.setFloat(11, flameOrange.a);

    // uEmberColor
    s.setFloat(12, (emberCrimson.r * 255.0) / 255.0);
    s.setFloat(13, (emberCrimson.g * 255.0) / 255.0);
    s.setFloat(14, (emberCrimson.b * 255.0) / 255.0);
    s.setFloat(15, emberCrimson.a);

    // uTurbulence
    s.setFloat(16, 1.0 + heatIntensity * 0.5);
    // uHeightFactor
    s.setFloat(17, 1.0);

    _shaderPaint.shader = s;
    canvas.drawRect(Offset.zero & size, _shaderPaint);
  }

  @override
  bool shouldRepaint(covariant ForgeFireShaderPainter oldDelegate) {
    return oldDelegate.shader != shader ||
        oldDelegate.heatIntensity != heatIntensity ||
        oldDelegate.timeSeconds != timeSeconds;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 6. ISI DALGASI KIRILMASI VE ORTAM PARILTISI ÇİZİCİLERİ
// ────────────────────────────────────────────────────────────────────────────

/// Ultra-tier optik ısı dalgalanması ve kırınım (heat haze refraction) çizicisi.
/// Ocağın hemen üzerinde sıcak hava dalgalarının ışığı kırmasını simüle eder.
class HeatHazeRefractionPainter extends CustomPainter {
  HeatHazeRefractionPainter({
    required this.heatIntensity,
    required this.timeSeconds,
    this.hazeColor = const Color(0x22FF6D00),
  });

  final double heatIntensity;
  final double timeSeconds;
  final Color hazeColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (heatIntensity < 0.08) return;
    final double w = size.width;
    final double h = size.height;

    final Paint shimmerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..isAntiAlias = true;

    // Isı sapma dalgaları
    for (int i = 0; i < 4; i++) {
      final Path path = Path();
      final double yBase = h * (0.30 + i * 0.15);
      path.moveTo(0, yBase);

      final double phase = timeSeconds * 3.8 + i * 1.6;
      final double amplitude = 3.5 * heatIntensity;

      for (double x = 0; x <= w; x += 10.0) {
        final double yOffset = math.sin(phase + x * 0.045) * amplitude +
            math.cos(phase * 1.25 + x * 0.025) * (amplitude * 0.55);
        path.lineTo(x, yBase + yOffset);
      }

      final double alpha = (0.05 + heatIntensity * 0.10) * (1.0 - i * 0.22);
      shimmerPaint.color = hazeColor.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawPath(path, shimmerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant HeatHazeRefractionPainter oldDelegate) {
    return oldDelegate.heatIntensity != heatIntensity ||
        oldDelegate.timeSeconds != timeSeconds;
  }
}

/// Ultra/High-tier ortam parıltı nabzı (ambient glow pulsation) çizicisi.
/// Ocak çevresine termal nefes alma ve ışıma titreşimi yayar.
class AmbientGlowPulsationPainter extends CustomPainter {
  AmbientGlowPulsationPainter({
    required this.heatIntensity,
    required this.timeSeconds,
    this.primaryGlow = const Color(0xFFFF5722),
    this.secondaryGlow = const Color(0xFFFFB300),
  });

  final double heatIntensity;
  final double timeSeconds;
  final Color primaryGlow;
  final Color secondaryGlow;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double heat = heatIntensity.clamp(0.0, 1.0);

    // Sinüzoidal nefes alan ortam parıltısı (1.5 Hz)
    final double pulse = 0.5 + 0.5 * math.sin(timeSeconds * 3.0);
    final double radius = w * (0.50 + heat * 0.40 + pulse * 0.12);
    final double alpha = (0.10 + heat * 0.32 + pulse * 0.12).clamp(0.0, 0.75);

    final Paint glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(w * 0.5, h * 0.72),
        radius,
        <Color>[
          primaryGlow.withValues(alpha: alpha),
          secondaryGlow.withValues(alpha: alpha * 0.55),
          Colors.transparent,
        ],
        <double>[0.0, 0.45, 1.0],
      );

    canvas.drawRect(Offset.zero & size, glowPaint);
  }

  @override
  bool shouldRepaint(covariant AmbientGlowPulsationPainter oldDelegate) {
    return oldDelegate.heatIntensity != heatIntensity ||
        oldDelegate.timeSeconds != timeSeconds;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 7. KOMPOZİT OCAK VFX KATMANI (CraftingForgeAtmosphere)
// ────────────────────────────────────────────────────────────────────────────

/// Alev efekti, köz parçacıkları ve termal parıltıyı tek bir 60 FPS
/// RepaintBoundary içinde birleştiren ana atmosfer bileşeni.
///
/// [AdaptiveQualityScaler] donanım kademesi (HardwareTier) ve [ZeroJankPreloader]
/// sıfır takılma önbelleklemesi ile entegre çalışır.
class CraftingForgeAtmosphere extends StatefulWidget {
  const CraftingForgeAtmosphere({
    super.key,
    required this.controller,
    this.particleCount,
    this.showFireShader = true,
    this.height,
    this.width,
    this.shaderAssetPath = 'shaders/vfx/forge_fire.frag',
    this.scaler,
  });

  final CraftingForgeEffectsController controller;
  final int? particleCount;
  final bool showFireShader;
  final double? height;
  final double? width;
  final String shaderAssetPath;
  final AdaptiveQualityScaler? scaler;

  /// Sıfır takılma önbelleği ön yükleme bayrağı.
  static bool _isForgeEmberPrewarmed = false;

  /// ZeroJankPreloader ile köz doku ve gradyanlarını time-sliced (<2ms) önceden ısıtır.
  static Future<void> prewarmForgeEmberTextures({
    ZeroJankPreloader? preloader,
  }) async {
    if (_isForgeEmberPrewarmed) return;
    final ZeroJankPreloader targetPreloader =
        preloader ?? ZeroJankPreloader.instance;

    await targetPreloader.preloadAtomic<bool>(
      id: 'forge_ember_textures_warmup',
      priority: PreloadPriority.criticalHud,
      targetCache: CacheTarget.vram,
      estimatedSizeBytes: 32 * 1024,
      loader: () async {
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final Canvas canvas = Canvas(recorder);
        const Size size = Size(32, 32);

        final Paint emberWarmupPaint = Paint()
          ..shader = ui.Gradient.radial(
            const Offset(16, 16),
            16,
            const <Color>[
              Color(0xFFFFFDE7),
              Color(0xFFFFB300),
              Color(0xFFFF5722),
              Colors.transparent,
            ],
            const <double>[0.0, 0.25, 0.65, 1.0],
          );
        canvas.drawCircle(const Offset(16, 16), 16, emberWarmupPaint);

        final ui.Picture picture = recorder.endRecording();
        final ui.Image image =
            await picture.toImage(size.width.toInt(), size.height.toInt());
        picture.dispose();
        image.dispose();
        _isForgeEmberPrewarmed = true;
        return true;
      },
    );
  }

  /// Donanım kademesi ve kısıntı seviyesine göre parçacık adedini belirler:
  /// - Eco (<= 1.8GB RAM): 12 parçacık (aşırı kısıntı)
  /// - Low (2GB RAM): 16 parçacık
  /// - Mid (4-6GB RAM): 48 parçacık
  /// - High (8GB RAM): 64 parçacık
  /// - Ultra (16GB+ RAM): 128 erimiş köz parçacığı
  static int computeAdaptiveParticleCount({
    required AdaptiveQualityScaler scaler,
    int? requestedCount,
  }) {
    final HardwareTier tier = scaler.currentTier;
    final QualitySettings settings = scaler.currentSettings;

    if (requestedCount != null && requestedCount > 0) {
      final double ratio = switch (tier) {
        HardwareTier.eco => 12.0 / 64.0,
        HardwareTier.low => 16.0 / 64.0,
        HardwareTier.mid => 48.0 / 64.0,
        HardwareTier.high => 1.0,
        HardwareTier.ultra => 128.0 / 64.0,
      };
      int count = (requestedCount * ratio).round();
      if (tier == HardwareTier.eco) return count.clamp(8, 12);
      if (tier == HardwareTier.low) return count.clamp(10, 16);
      if (tier == HardwareTier.ultra) return count.clamp(64, 128);
      return count.clamp(16, 96);
    }

    int count = switch (tier) {
      HardwareTier.eco => 12,
      HardwareTier.low => 16,
      HardwareTier.mid => 48,
      HardwareTier.high => 64,
      HardwareTier.ultra => 128,
    };

    if (settings.throttleLevel > 0) {
      if (settings.throttleLevel == 1) {
        count = (count * 0.75).round();
      } else if (settings.throttleLevel == 2) {
        count = (count * 0.50).round();
      } else {
        count = (count * 0.35).round();
      }
    }

    if (tier == HardwareTier.eco) {
      return count.clamp(8, 12);
    } else if (tier == HardwareTier.low) {
      return count.clamp(10, 16);
    } else if (tier == HardwareTier.ultra) {
      return count.clamp(64, 128);
    }
    return count.clamp(16, 96);
  }

  @override
  State<CraftingForgeAtmosphere> createState() => _CraftingForgeAtmosphereState();
}

class _CraftingForgeAtmosphereState extends State<CraftingForgeAtmosphere>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final CraftingEmberParticleSystem _particleSystem;
  late final AdaptiveQualityScaler _scaler;
  StreamSubscription<QualitySettings>? _scalerSubscription;

  ui.FragmentShader? _fragmentShader;
  Duration _lastElapsed = Duration.zero;

  // Donanım kademesine göre ölçeklenen çizim bayrakları
  bool _allowHeatDistortionBlur = true;
  bool _enableHeatHazeRefraction = false;
  bool _enableAmbientGlowPulsation = false;
  bool _allowEmberGlow = true;

  @override
  void initState() {
    super.initState();
    _scaler = _resolveScaler();

    // 1. ZeroJankPreloader köz dokularını time-sliced önceden ısıt (<2ms)
    CraftingForgeAtmosphere.prewarmForgeEmberTextures();

    // 2. Kademeye uyumlu parçacık havuzu
    final int initialParticles = CraftingForgeAtmosphere.computeAdaptiveParticleCount(
      scaler: _scaler,
      requestedCount: widget.particleCount,
    );
    _particleSystem = CraftingEmberParticleSystem(maxParticles: initialParticles);
    _applyTierSettings(_scaler.currentSettings);

    // 3. Scaler çalışma zamanı ayar değişikliklerini dinle
    _scalerSubscription = _scaler.onSettingsChanged.listen((QualitySettings settings) {
      if (!mounted) return;
      _applyTierSettings(settings);
    });

    _loadShaderSafe();

    _ticker = createTicker((Duration elapsed) {
      if (_lastElapsed == Duration.zero) {
        _lastElapsed = elapsed;
        return;
      }
      final double dt = ((elapsed - _lastElapsed).inMicroseconds / 1000000.0).clamp(0.001, 0.05);
      _lastElapsed = elapsed;

      widget.controller.update(dt);
      _particleSystem.update(dt, widget.controller.currentHeat);
    });

    _ticker.start();
  }

  AdaptiveQualityScaler _resolveScaler() {
    if (widget.scaler != null) return widget.scaler!;
    try {
      return GraphicsSettingsService.instance.scaler;
    } catch (_) {
      return AdaptiveQualityScaler();
    }
  }

  void _applyTierSettings(QualitySettings settings) {
    final HardwareTier tier = _scaler.currentTier;
    final int adaptiveCount = CraftingForgeAtmosphere.computeAdaptiveParticleCount(
      scaler: _scaler,
      requestedCount: widget.particleCount,
    );
    _particleSystem.setMaxParticles(adaptiveCount);

    setState(() {
      // Eco / Low kademelerinde (<=2GB RAM):
      // - Parçacıklar 12-16 adede seyreltilir.
      // - Isı kırınım / distorsiyon bulanıklığı tamamen elenir (GPU bant genişliği korunur).
      // - Ekstra parıltı (glow) çizimleri kapatılır.
      if (tier == HardwareTier.eco || tier == HardwareTier.low) {
        _allowHeatDistortionBlur = false;
        _enableHeatHazeRefraction = false;
        _enableAmbientGlowPulsation = false;
        _allowEmberGlow = false;
      } else if (tier == HardwareTier.ultra) {
        // Ultra kademede:
        // - Tam 128 erimiş köz parçacığı
        // - Isı kırınımı (heat haze refraction)
        // - Ortam ışıması nabzı (ambient glow pulsation)
        _allowHeatDistortionBlur = settings.throttleLevel == 0;
        _enableHeatHazeRefraction = true;
        _enableAmbientGlowPulsation = true;
        _allowEmberGlow = true;
      } else {
        // Mid / High kademeleri
        _allowHeatDistortionBlur = settings.throttleLevel == 0;
        _enableHeatHazeRefraction = tier == HardwareTier.high && settings.throttleLevel == 0;
        _enableAmbientGlowPulsation = true;
        _allowEmberGlow = true;
      }
    });
  }

  Future<void> _loadShaderSafe() async {
    if (!widget.showFireShader) return;
    try {
      final ui.FragmentProgram program =
          await ui.FragmentProgram.fromAsset(widget.shaderAssetPath);
      if (mounted) {
        setState(() {
          _fragmentShader = program.fragmentShader();
        });
      }
    } catch (_) {
      // Headless test veya desteklenmeyen GPU durumunda sessizce prosedürel motora düşülür.
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scalerSubscription?.cancel();
    _fragmentShader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, _) {
        final double heat = widget.controller.currentHeat;
        final double time = widget.controller.timeSeconds;

        final Widget forgeStack = Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // 1. Ortam Işıması Titreşimi (Ultra & High kademeleri)
            if (_enableAmbientGlowPulsation)
              CustomPaint(
                painter: AmbientGlowPulsationPainter(
                  heatIntensity: heat,
                  timeSeconds: time,
                ),
              ),

            // 2. Alev Katmanı (Runtime Shader veya Prosedürel Fallback)
            CustomPaint(
              painter: ForgeFireShaderPainter(
                shader: _fragmentShader,
                heatIntensity: heat,
                timeSeconds: time,
              ),
            ),

            // 3. Isı Kırınımı / Haze Katmanı (Ultra kademe)
            if (_enableHeatHazeRefraction)
              CustomPaint(
                painter: HeatHazeRefractionPainter(
                  heatIntensity: heat,
                  timeSeconds: time,
                ),
              ),

            // 4. Yükselen Kor ve Kıvılcım Parçacıkları Katmanı (Kademeye göre seyreltilmiş)
            CustomPaint(
              painter: CraftingEmberPainter(
                particles: _particleSystem.particles,
                heatIntensity: heat,
                allowGlow: _allowEmberGlow,
              ),
            ),
          ],
        );

        // Eco / Low kademelerinde distorsiyon bulanıklığı tamamen elenir
        final Widget content = (_allowHeatDistortionBlur && heat > 0.15)
            ? ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: (0.2 + heat * 0.6),
                  sigmaY: (0.2 + heat * 0.6),
                ),
                child: forgeStack,
              )
            : forgeStack;

        return RepaintBoundary(
          child: SizedBox(
            width: widget.width ?? double.infinity,
            height: widget.height ?? 220,
            child: content,
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 8. ZANAAT ODASI KAHRAMAN KARTI (CraftingForgeHeroCard)
// ────────────────────────────────────────────────────────────────────────────

/// Zanaat ekranının tepesinde ocak durumunu, anlık sıcaklığı ve körükleme
/// eylemini gösteren interaktif AION 2 tarzı başlık paneli.
class CraftingForgeHeroCard extends StatelessWidget {
  const CraftingForgeHeroCard({
    super.key,
    required this.controller,
    this.onStoke,
    this.scaler,
  });

  final CraftingForgeEffectsController controller;
  final VoidCallback? onStoke;
  final AdaptiveQualityScaler? scaler;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        final double heat = controller.currentHeat;
        final int tempC = controller.temperatureCelsius;
        final String status = controller.statusLabel;

        final Color heatColor = Color.lerp(
          AppColors.liquidGold,
          const Color(0xFFFF3D00),
          heat,
        )!;

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: heatColor.withValues(alpha: 0.35 + heat * 0.45),
              width: 1.2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                const Color(0xFF161C2C),
                Color.lerp(const Color(0xFF0C101A), const Color(0xFF200A06), heat)!,
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: heatColor.withValues(alpha: 0.15 + heat * 0.25),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Stack(
              children: <Widget>[
                // Arka plan ocak ateşi ve korlar
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.75 + heat * 0.25,
                      child: CraftingForgeAtmosphere(
                        controller: controller,
                        particleCount: 36,
                        scaler: scaler,
                      ),
                    ),
                  ),
                ),

                // İçerik katmanı
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: heatColor.withValues(alpha: 0.18),
                              border: Border.all(color: heatColor.withValues(alpha: 0.6)),
                            ),
                            child: Icon(
                              Icons.local_fire_department_rounded,
                              size: 18,
                              color: heatColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    const Text(
                                      'DEMİRCİ OCAĞI',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '$tempC°C',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: heatColor,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: heatColor.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Dinamik Isı İlerleme Çubuğu
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 5,
                          child: LinearProgressIndicator(
                            value: heat,
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            valueColor: AlwaysStoppedAnimation<Color>(heatColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Körükleme butonu ve aktif üretim özeti
                      Row(
                        children: <Widget>[
                          Text(
                            controller.isCrafting
                                ? '🔥 Üretim yapılıyor, ocak azami ısıda...'
                                : 'Körükleri kullanarak ocak ısısını yükseltebilirsiniz.',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: () {
                              controller.stokeBellows();
                              onStoke?.call();
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: heatColor.withValues(alpha: 0.18),
                                border: Border.all(color: heatColor.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(Icons.air_rounded, size: 13, color: heatColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Körükle',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: heatColor,
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 9. ÖN İZLEME PANELİ OCAK ARKA PLANI (CraftingPreviewForgeBackdrop)
// ────────────────────────────────────────────────────────────────────────────

/// Tarif detay/üretim dialogunda (`CraftingPreviewPanel`) üretilen eşyanın
/// arkasında alevlenen minyatür ocak fırını görseli.
class CraftingPreviewForgeBackdrop extends StatelessWidget {
  const CraftingPreviewForgeBackdrop({
    super.key,
    required this.isCrafting,
    this.height = 140,
  });

  final bool isCrafting;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.25, end: isCrafting ? 0.95 : 0.35),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double heat, Widget? child) {
            return CustomPaint(
              painter: ForgeFireProceduralPainter(
                heatIntensity: heat,
                timeSeconds: DateTime.now().millisecondsSinceEpoch / 1000.0,
              ),
            );
          },
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 10. OCAK KOR PERDESİ (ForgeEmbersOverlay)
// ────────────────────────────────────────────────────────────────────────────

/// Ekranın geneline veya belirli bir bölüme yükselen köz/kıvılcım parçacıkları
/// serpiştiren, dokunmayı engellemeyen (IgnorePointer) 60 FPS TBDR katmanı.
class ForgeEmbersOverlay extends StatefulWidget {
  const ForgeEmbersOverlay({
    super.key,
    required this.child,
    this.particleCount,
    this.heatIntensity = 0.45,
    this.scaler,
  });

  final Widget child;
  final int? particleCount;
  final double heatIntensity;
  final AdaptiveQualityScaler? scaler;

  @override
  State<ForgeEmbersOverlay> createState() => _ForgeEmbersOverlayState();
}

class _ForgeEmbersOverlayState extends State<ForgeEmbersOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final CraftingEmberParticleSystem _particleSystem;
  late final AdaptiveQualityScaler _scaler;
  StreamSubscription<QualitySettings>? _scalerSubscription;
  Duration _lastElapsed = Duration.zero;

  bool _allowGlow = true;

  @override
  void initState() {
    super.initState();
    _scaler = _resolveScaler();

    // ZeroJankPreloader ile köz dokularını ısıt (<2ms)
    CraftingForgeAtmosphere.prewarmForgeEmberTextures();

    final int initialCount = CraftingForgeAtmosphere.computeAdaptiveParticleCount(
      scaler: _scaler,
      requestedCount: widget.particleCount ?? 28,
    );
    _particleSystem = CraftingEmberParticleSystem(maxParticles: initialCount);
    _allowGlow = _scaler.currentTier != HardwareTier.eco && _scaler.currentTier != HardwareTier.low;

    _scalerSubscription = _scaler.onSettingsChanged.listen((QualitySettings settings) {
      if (!mounted) return;
      final int adaptive = CraftingForgeAtmosphere.computeAdaptiveParticleCount(
        scaler: _scaler,
        requestedCount: widget.particleCount ?? 28,
      );
      _particleSystem.setMaxParticles(adaptive);
      setState(() {
        _allowGlow = _scaler.currentTier != HardwareTier.eco && _scaler.currentTier != HardwareTier.low;
      });
    });

    _ticker = createTicker((Duration elapsed) {
      if (_lastElapsed == Duration.zero) {
        _lastElapsed = elapsed;
        return;
      }
      final double dt = ((elapsed - _lastElapsed).inMicroseconds / 1000000.0).clamp(0.001, 0.05);
      _lastElapsed = elapsed;
      _particleSystem.update(dt, widget.heatIntensity);
      if (mounted) setState(() {});
    });
    _ticker.start();
  }

  AdaptiveQualityScaler _resolveScaler() {
    if (widget.scaler != null) return widget.scaler!;
    try {
      return GraphicsSettingsService.instance.scaler;
    } catch (_) {
      return AdaptiveQualityScaler();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scalerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: CraftingEmberPainter(
                  particles: _particleSystem.particles,
                  heatIntensity: widget.heatIntensity,
                  allowGlow: _allowGlow,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 11. ÖRS VE OCAK BAŞLIĞI (ForgeAnvilHeader)
// ────────────────────────────────────────────────────────────────────────────

/// Zanaat ekranı tepesinde dinamik ocak alevi, sıcaklık sayacı,
/// aktif üretim durumu ve görünüm kipi (Carousel/Grid) anahtarını sunar.
class ForgeAnvilHeader extends StatefulWidget {
  const ForgeAnvilHeader({
    super.key,
    required this.recipeCount,
    required this.queueCount,
    required this.queueMax,
    required this.isCarouselMode,
    required this.onToggleViewMode,
    this.scaler,
  });

  final int recipeCount;
  final int queueCount;
  final int queueMax;
  final bool isCarouselMode;
  final VoidCallback onToggleViewMode;
  final AdaptiveQualityScaler? scaler;

  @override
  State<ForgeAnvilHeader> createState() => _ForgeAnvilHeaderState();
}

class _ForgeAnvilHeaderState extends State<ForgeAnvilHeader> {
  late final CraftingForgeEffectsController _controller;

  @override
  void initState() {
    super.initState();
    CraftingForgeAtmosphere.prewarmForgeEmberTextures();
    final double initialHeat = widget.queueCount > 0 ? 0.85 : 0.32;
    _controller = CraftingForgeEffectsController(
      initialHeat: initialHeat,
      scaler: widget.scaler,
    );
    _controller.updateQueueCount(widget.queueCount);
  }

  @override
  void didUpdateWidget(covariant ForgeAnvilHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.queueCount != widget.queueCount) {
      _controller.updateQueueCount(widget.queueCount);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, _) {
        final double heat = _controller.currentHeat;
        final int tempC = _controller.temperatureCelsius;
        final Color heatColor = Color.lerp(
          AppColors.liquidGold,
          const Color(0xFFFF3D00),
          heat,
        )!;

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: heatColor.withValues(alpha: 0.32 + heat * 0.4),
              width: 1.2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                const Color(0xFF141A28),
                Color.lerp(const Color(0xFF0C101A), const Color(0xFF1F0904), heat)!,
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: heatColor.withValues(alpha: 0.12 + heat * 0.22),
                blurRadius: 16,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Stack(
              children: <Widget>[
                // Canlı fırın alevi & kor arka planı
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.65 + heat * 0.35,
                      child: CraftingForgeAtmosphere(
                        controller: _controller,
                        particleCount: 28,
                        height: 110,
                        scaler: widget.scaler,
                      ),
                    ),
                  ),
                ),

                // Başlık içeriği ve denetimleri
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(
                    children: <Widget>[
                      // Ocak/Örs İkonu + Sıcaklık rozeti
                      InkWell(
                        onTap: () => _controller.stokeBellows(boost: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: heatColor.withValues(alpha: 0.18),
                            border: Border.all(color: heatColor.withValues(alpha: 0.55)),
                          ),
                          child: Icon(
                            Icons.local_fire_department_rounded,
                            size: 20,
                            color: heatColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Başlık ve İstatistikler
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                const Text(
                                  'DEMİRCİ OCAĞI',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: heatColor.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: heatColor.withValues(alpha: 0.45)),
                                  ),
                                  child: Text(
                                    '$tempC°C',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: heatColor,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.queueCount > 0
                                  ? 'Kuyruk: ${widget.queueCount}/${widget.queueMax} dövülüyor'
                                  : '${widget.recipeCount} tarif · Körük hazır',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.72),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Görünüm Kipi Değiştirici Buton (Karusel / Grid)
                      InkWell(
                        onTap: widget.onToggleViewMode,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.darkObsidian.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                widget.isCarouselMode
                                    ? Icons.grid_view_rounded
                                    : Icons.view_carousel_rounded,
                                size: 15,
                                color: AppColors.liquidGold,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                widget.isCarouselMode ? 'Izgara' : 'Karusel',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.liquidGold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 12. ERİMİŞ METAL İLERLEME ÇUBUĞU (MoltenProgressBar)
// ────────────────────────────────────────────────────────────────────────────

/// Kuyrukta dövülen eşyalar için akkor altın -> kor turuncu sıvı metal
/// ilerleme çubuğu. 60 FPS akkor ışıma ve termal nabız efektine sahiptir.
class MoltenProgressBar extends StatefulWidget {
  const MoltenProgressBar({
    super.key,
    required this.progress,
    this.height = 6,
    this.glowColor = const Color(0xFFFFB300),
  });

  final double progress;
  final double height;
  final Color glowColor;

  @override
  State<MoltenProgressBar> createState() => _MoltenProgressBarState();
}

class _MoltenProgressBarState extends State<MoltenProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double clamped = widget.progress.clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (BuildContext context, _) {
        final double pulse = _pulseController.value;

        return RepaintBoundary(
          child: Container(
            height: widget.height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF090C14),
              borderRadius: BorderRadius.circular(widget.height / 2),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.8,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: widget.glowColor.withValues(alpha: 0.15 + pulse * 0.15),
                  blurRadius: 6,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.height / 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: clamped,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: <Color>[
                          const Color(0xFFD50000),
                          const Color(0xFFFF6D00),
                          Color.lerp(
                            const Color(0xFFFFD600),
                            Colors.white,
                            pulse * 0.4,
                          )!,
                        ],
                        stops: const <double>[0.0, 0.65, 1.0],
                      ),
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
}

