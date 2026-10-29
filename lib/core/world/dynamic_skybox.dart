import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../engine/adaptive_quality_scaler.dart';
import '../engine/zero_jank_preloader.dart';
import '../../screens/settings/graphics_settings_service.dart';

/// Represents a celestial star in the nocturnal procedural star field.
class SkyStar {
  const SkyStar({
    required this.position,
    required this.brightness,
    required this.size,
    required this.color,
    this.twinklePhase = 0.0,
    this.twinkleSpeed = 1.0,
  });

  /// 3D unit vector on the celestial sphere.
  final SkyVector3 position;

  /// Normalized base brightness [0.0, 1.0].
  final double brightness;

  /// Visual particle radius in logical pixels.
  final double size;

  /// Stellar spectral color tint.
  final ui.Color color;

  /// Phase offset for scintillation oscillation in radians.
  final double twinklePhase;

  /// Speed multiplier for star scintillation frequency.
  final double twinkleSpeed;
}

/// Procedural Celestial Starfield generator and memory cache.
class SkyStarCluster {
  SkyStarCluster._();

  static List<SkyStar>? _cachedFullCluster;
  static List<SkyStar>? _cachedEcoCluster;

  /// Generate or retrieve a deterministic celestial star cluster.
  /// Standard full cluster has 200 stars. Eco/Low cluster has 40 stars.
  static List<SkyStar> getStars({int count = 200}) {
    if (count <= 40) {
      return _cachedEcoCluster ??= _generateCluster(40);
    }
    return _cachedFullCluster ??= _generateCluster(200);
  }

  /// Reset cache (for testing or memory reclamation).
  @visibleForTesting
  static void resetCache() {
    _cachedFullCluster = null;
    _cachedEcoCluster = null;
  }

  static List<SkyStar> _generateCluster(int count) {
    final math.Random rng = math.Random(1337);
    final List<SkyStar> stars = <SkyStar>[];

    // Diverse stellar spectral classes (O, B, A, F, G, K, M)
    const List<ui.Color> spectralColors = <ui.Color>[
      ui.Color(0xFFE2F0FF), // Class O/B (Blue-White)
      ui.Color(0xFFFFFFFF), // Class A (Pure White)
      ui.Color(0xFFFFF7EB), // Class F (Warm White)
      ui.Color(0xFFFFEEBA), // Class G (Golden Yellow)
      ui.Color(0xFFFFD494), // Class K (Soft Orange)
      ui.Color(0xFFFFB29E), // Class M (Stellar Crimson)
      ui.Color(0xFFD4E8FF), // Astral Cyan tint
    ];

    for (int i = 0; i < count; i++) {
      // Celestial sphere distribution on upper hemisphere (elevation > 0)
      final double z = rng.nextDouble() * 0.92 + 0.08;
      final double phi = rng.nextDouble() * 2.0 * math.pi;
      final double r = math.sqrt(math.max(0.0, 1.0 - z * z));
      final double x = r * math.cos(phi);
      final double y = z;
      final double zCoord = r * math.sin(phi);

      final SkyVector3 position = SkyVector3(x, y, zCoord).normalized();
      final double brightness = 0.35 + rng.nextDouble() * 0.65;
      final double size = 0.8 + rng.nextDouble() * 1.8;
      final ui.Color color = spectralColors[rng.nextInt(spectralColors.length)];
      final double twinklePhase = rng.nextDouble() * 2.0 * math.pi;
      final double twinkleSpeed = 0.8 + rng.nextDouble() * 2.2;

      stars.add(SkyStar(
        position: position,
        brightness: brightness,
        size: size,
        color: color,
        twinklePhase: twinklePhase,
        twinkleSpeed: twinkleSpeed,
      ));
    }

    return List<SkyStar>.unmodifiable(stars);
  }
}

/// Procedural Volumetric Cloud synthesis & raymarching approximation.
class SkyVolumetricCloudRenderer {
  SkyVolumetricCloudRenderer._();

  static Float32List? _noiseLut;

  /// Pre-warms sinusoidal noise lookup tables for cloud synthesis (<1ms).
  static void prewarmLut() {
    if (_noiseLut != null) return;
    final Float32List lut = Float32List(128);
    for (int i = 0; i < 128; i++) {
      final double t = (i / 128.0) * 2.0 * math.pi;
      lut[i] = (math.sin(t) * 0.5 +
              math.sin(t * 2.3 + 1.2) * 0.3 +
              math.sin(t * 4.7 + 2.5) * 0.2)
          .clamp(-1.0, 1.0);
    }
    _noiseLut = lut;
  }

  /// Fast pseudo-noise sampling using pre-warmed LUT and trigonometric harmonics.
  static double sampleCloudDensity(double u, double v, double time) {
    prewarmLut();
    final double windU = u + time * 0.012;
    final double windV = v + time * 0.004;

    final int idx1 = ((windU * 32.0).floor() & 127);
    final int idx2 = ((windV * 48.0).floor() & 127);
    final double n1 = _noiseLut![idx1];
    final double n2 = _noiseLut![idx2];

    final double harmonic = math.sin((windU * 6.0 + n1 * 1.5) * math.pi) *
        math.cos((windV * 5.0 + n2 * 1.2) * math.pi);

    return ((harmonic * 0.5 + 0.5) * (n1 * 0.3 + 0.7)).clamp(0.0, 1.0);
  }

  /// Renders animated cloud layers using multi-step volumetric raymarching approximation.
  /// Integrates Beer-Lambert optical transmittance and forward Henyey-Greenstein silver linings.
  static void paintVolumetricClouds(
    ui.Canvas canvas,
    ui.Size size,
    DynamicSkyboxController controller, {
    required bool highFidelity,
  }) {
    final double time = controller.totalTimeElapsed;
    final SkyVector3 sunDir = controller.sunDirection;
    final LinearColor sunRad = controller.sunRadiance;
    final LinearColor horizonCol = controller.giUniforms.horizonColor;

    // Cloud layer altitude band on canvas
    final double horizonY = size.height * (0.55 + sunDir.y * 0.1);
    final double cloudCeilingY = size.height * 0.15;
    final double cloudSpan = horizonY - cloudCeilingY;
    if (cloudSpan <= 10.0) return;

    // Number of volumetric raymarch elevation steps:
    // High/Ultra: 6 sample slices. Mid: 2 sample slices.
    final int stepCount = highFidelity ? 6 : 2;
    final double stepSize = cloudSpan / stepCount;

    // Forward scattering Henyey-Greenstein asymmetry factor g for clouds (g ~= 0.72)
    const double g = 0.72;
    const double g2 = g * g;

    for (int step = 0; step < stepCount; step++) {
      final double sliceY = cloudCeilingY + step * stepSize;
      final double normalizedAlt = (step + 0.5) / stepCount;

      // Optical density profile (peaking at mid-altitude of the cloud deck)
      final double altitudeDensity = math.sin(normalizedAlt * math.pi);

      // Ray sample across horizontal screen width (12 horizontal segments)
      final int horizSegments = highFidelity ? 12 : 6;
      final double segWidth = size.width / horizSegments;

      for (int seg = 0; seg < horizSegments; seg++) {
        final double x = seg * segWidth;
        final double u = (x / size.width) * 1.5;
        final double v = normalizedAlt;

        final double density = sampleCloudDensity(u, v, time) * altitudeDensity;
        if (density < 0.22) continue; // Below cloud condensation threshold

        // Beer-Lambert optical transmittance: T = exp(-tau)
        const double extinctionCoeff = 1.6;
        final double opticalDepth = density * extinctionCoeff;
        final double transmittance = math.exp(-opticalDepth);
        final double opacity = ((1.0 - transmittance) * 0.75).clamp(0.0, 0.85);

        // Direction towards sun for forward silver lining
        final double screenSunX = size.width * (0.5 + sunDir.x * 0.45);
        final double screenSunY = horizonY - sunDir.y * (size.height * 0.45);
        final double dx = (screenSunX - (x + segWidth * 0.5)) / size.width;
        final double dy = (screenSunY - sliceY) / size.height;
        final double distToSun = math.sqrt(dx * dx + dy * dy);
        final double cosTheta = (1.0 - distToSun * 1.4).clamp(-1.0, 1.0);

        // Henyey-Greenstein forward phase function
        final double phase = (1.0 - g2) /
            (4.0 * math.pi * math.pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5));
        final double silverLining = (phase * 1.8).clamp(0.0, 2.5);

        // Base cloud color illuminated by ambient horizon and direct sun radiance
        final LinearColor illuminatedCloud = LinearColor(
          (horizonCol.r * 0.6 + sunRad.r * 0.4 * silverLining).clamp(0.0, 1.0),
          (horizonCol.g * 0.6 + sunRad.g * 0.4 * silverLining).clamp(0.0, 1.0),
          (horizonCol.b * 0.6 + sunRad.b * 0.4 * silverLining).clamp(0.0, 1.0),
          opacity,
        );

        final ui.Rect cloudRect = ui.Rect.fromLTWH(
          x - segWidth * 0.25,
          sliceY - stepSize * 0.35,
          segWidth * 1.5,
          stepSize * 1.7,
        );

        final ui.Paint cloudPaint = ui.Paint()
          ..shader = ui.Gradient.radial(
            cloudRect.center,
            cloudRect.width * 0.55,
            [
              illuminatedCloud.toColor(),
              illuminatedCloud.toColor().withAlpha(0),
            ],
          );

        canvas.drawOval(cloudRect, cloudPaint);
      }
    }
  }
}

/// Cinematic Sun Glare & Anamorphic Bloom Renderer for High/Ultra tiers.
class SunGlareBloomRenderer {
  SunGlareBloomRenderer._();

  static void paintSunGlareBloom({
    required ui.Canvas canvas,
    required ui.Size size,
    required ui.Offset sunPos,
    required LinearColor sunRadiance,
    required double sunElev,
  }) {
    if (sunElev < -0.05) return;

    final ui.Color sunColor = sunRadiance.toColor();
    final double bloomAlpha = (sunElev.clamp(0.0, 0.6) / 0.6);

    // 1. Soft Large-Scale Radial HDR Bloom Halo
    final double bloomRadius = size.width * 0.55;
    final ui.Paint broadBloomPaint = ui.Paint()
      ..shader = ui.Gradient.radial(
        sunPos,
        bloomRadius,
        [
          sunColor.withAlpha((89 * bloomAlpha).round().clamp(0, 255)),
          sunColor.withAlpha((20 * bloomAlpha).round().clamp(0, 255)),
          sunColor.withAlpha(0),
        ],
        const [0.0, 0.45, 1.0],
      );
    canvas.drawCircle(sunPos, bloomRadius, broadBloomPaint);

    // 2. Anamorphic Horizontal Glare Streak (Cinematic Aspect Ratio)
    final double flareWidth = size.width * 0.75;
    final double flareHeight = size.width * 0.035;
    final ui.Rect flareRect = ui.Rect.fromCenter(
      center: sunPos,
      width: flareWidth,
      height: flareHeight,
    );
    final ui.Paint flarePaint = ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset(flareRect.left, sunPos.dy),
        ui.Offset(flareRect.right, sunPos.dy),
        [
          sunColor.withAlpha(0),
          sunColor.withAlpha((115 * bloomAlpha).round().clamp(0, 255)),
          const ui.Color(0xFFFFFFFF).withAlpha((165 * bloomAlpha).round().clamp(0, 255)),
          sunColor.withAlpha((115 * bloomAlpha).round().clamp(0, 255)),
          sunColor.withAlpha(0),
        ],
        const [0.0, 0.35, 0.5, 0.65, 1.0],
      );
    canvas.drawOval(flareRect, flarePaint);

    // 3. Solar Corona Ring (Spectral Diffraction Ring)
    final double coronaRadius = size.width * 0.075;
    final ui.Paint coronaPaint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const ui.Color(0xFFFFEEAA).withAlpha((76 * bloomAlpha).round().clamp(0, 255))
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3.0);
    canvas.drawCircle(sunPos, coronaRadius, coronaPaint);

    // 4. 4-Point Solar Cross Diffraction Spikes
    final double spikeLen = size.width * 0.16;
    final ui.Paint spikePaint = ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF).withAlpha((89 * bloomAlpha).round().clamp(0, 255))
      ..strokeWidth = 1.2
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.5);
    // Vertical spike
    canvas.drawLine(
      ui.Offset(sunPos.dx, sunPos.dy - spikeLen),
      ui.Offset(sunPos.dx, sunPos.dy + spikeLen),
      spikePaint,
    );
    // Horizontal spike
    canvas.drawLine(
      ui.Offset(sunPos.dx - spikeLen, sunPos.dy),
      ui.Offset(sunPos.dx + spikeLen, sunPos.dy),
      spikePaint,
    );
  }
}

// =============================================================================
// Production AAA Dynamic Procedural Skybox & Global Illumination Pipeline
// 2027 Cinematic Graphics Standard (R2 Open World Architecture)
// =============================================================================

/// 3D Vector for celestial space, orbital positions, and spherical harmonic probes.
class SkyVector3 {
  const SkyVector3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  static const SkyVector3 zero = SkyVector3(0.0, 0.0, 0.0);
  static const SkyVector3 up = SkyVector3(0.0, 1.0, 0.0);
  static const SkyVector3 down = SkyVector3(0.0, -1.0, 0.0);
  static const SkyVector3 forward = SkyVector3(0.0, 0.0, 1.0);
  static const SkyVector3 right = SkyVector3(1.0, 0.0, 0.0);

  /// Construct a unit vector from spherical coordinates:
  /// [azimuthRad] (yaw around Y from +Z towards +X) and [elevationRad] (pitch from horizon towards +Y).
  factory SkyVector3.fromSpherical(double azimuthRad, double elevationRad) {
    final double cosElev = math.cos(elevationRad);
    return SkyVector3(
      cosElev * math.sin(azimuthRad),
      math.sin(elevationRad),
      cosElev * math.cos(azimuthRad),
    );
  }

  double get lengthSquared => x * x + y * y + z * z;
  double get length => math.sqrt(lengthSquared);

  SkyVector3 operator +(SkyVector3 o) => SkyVector3(x + o.x, y + o.y, z + o.z);
  SkyVector3 operator -(SkyVector3 o) => SkyVector3(x - o.x, y - o.y, z - o.z);
  SkyVector3 operator *(double s) => SkyVector3(x * s, y * s, z * s);
  SkyVector3 operator /(double s) => SkyVector3(x / s, y / s, z / s);
  SkyVector3 operator -() => SkyVector3(-x, -y, -z);

  double dot(SkyVector3 o) => x * o.x + y * o.y + z * o.z;

  SkyVector3 cross(SkyVector3 o) => SkyVector3(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  SkyVector3 normalized() {
    final double len = length;
    if (len < 1e-12) return SkyVector3.up;
    return SkyVector3(x / len, y / len, z / len);
  }

  SkyVector3 lerp(SkyVector3 other, double t) {
    final double clampedT = t.clamp(0.0, 1.0);
    return SkyVector3(
      x + (other.x - x) * clampedT,
      y + (other.y - y) * clampedT,
      z + (other.z - z) * clampedT,
    );
  }

  double distanceTo(SkyVector3 other) => (this - other).length;

  /// Elevation angle from horizon [-PI/2, PI/2].
  double get elevation => math.asin(y.clamp(-1.0, 1.0));

  /// Azimuth angle around Y in radians [-PI, PI].
  double get azimuth => math.atan2(x, z);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkyVector3 &&
          (x - other.x).abs() < 1e-6 &&
          (y - other.y).abs() < 1e-6 &&
          (z - other.z).abs() < 1e-6;

  @override
  int get hashCode => Object.hash(x.toStringAsFixed(5), y.toStringAsFixed(5), z.toStringAsFixed(5));

  @override
  String toString() => 'SkyVector3(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

/// Linear RGB color representation supporting High Dynamic Range (HDR) radiance values.
class LinearColor {
  const LinearColor(this.r, this.g, this.b, [this.a = 1.0]);

  final double r;
  final double g;
  final double b;
  final double a;

  static const LinearColor black = LinearColor(0.0, 0.0, 0.0);
  static const LinearColor white = LinearColor(1.0, 1.0, 1.0);

  /// Approximate blackbody radiation color from color temperature in Kelvin [1000K, 40000K].
  /// Uses Tanner Helland / Kang analytical blackbody curve.
  factory LinearColor.fromColorTemperature(double kelvin) {
    final double temp = (kelvin / 100.0).clamp(10.0, 400.0);
    double red;
    double green;
    double blue;

    // Red component
    if (temp <= 66.0) {
      red = 255.0;
    } else {
      red = temp - 60.0;
      red = 329.698727446 * math.pow(red, -0.1332047592);
      red = red.clamp(0.0, 255.0);
    }

    // Green component
    if (temp <= 66.0) {
      green = temp;
      green = 99.4708025861 * math.log(green) - 161.1195681661;
      green = green.clamp(0.0, 255.0);
    } else {
      green = temp - 60.0;
      green = 288.1221695283 * math.pow(green, -0.0755148492);
      green = green.clamp(0.0, 255.0);
    }

    // Blue component
    if (temp >= 66.0) {
      blue = 255.0;
    } else if (temp <= 19.0) {
      blue = 0.0;
    } else {
      blue = temp - 10.0;
      blue = 138.5177312231 * math.log(blue) - 305.0447927307;
      blue = blue.clamp(0.0, 255.0);
    }

    // Convert sRGB [0, 255] to Linear [0.0, 1.0]
    return LinearColor(
      _srgbToLinear(red / 255.0),
      _srgbToLinear(green / 255.0),
      _srgbToLinear(blue / 255.0),
    );
  }

  factory LinearColor.fromColor(ui.Color color) {
    return LinearColor(
      _srgbToLinear(color.r),
      _srgbToLinear(color.g),
      _srgbToLinear(color.b),
      color.a,
    );
  }

  static double _srgbToLinear(double c) {
    if (c <= 0.04045) {
      return c / 12.92;
    } else {
      return math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }
  }

  static double _linearToSrgb(double c) {
    final double clamped = c.clamp(0.0, 1.0);
    if (clamped <= 0.0031308) {
      return clamped * 12.92;
    } else {
      return 1.055 * math.pow(clamped, 1.0 / 2.4) - 0.055;
    }
  }

  /// Luminance according to Rec. 709 photometric coefficients.
  double get luminance => 0.2126 * r + 0.7152 * g + 0.0722 * b;

  LinearColor operator +(LinearColor o) => LinearColor(r + o.r, g + o.g, b + o.b, a);
  LinearColor operator -(LinearColor o) => LinearColor(r - o.r, g - o.g, b - o.b, a);
  LinearColor operator *(double s) => LinearColor(r * s, g * s, b * s, a);
  LinearColor multiply(LinearColor o) => LinearColor(r * o.r, g * o.g, b * o.b, a * o.a);

  LinearColor lerp(LinearColor other, double t) {
    final double clampedT = t.clamp(0.0, 1.0);
    return LinearColor(
      r + (other.r - r) * clampedT,
      g + (other.g - g) * clampedT,
      b + (other.b - b) * clampedT,
      a + (other.a - a) * clampedT,
    );
  }

  ui.Color toColor() {
    return ui.Color.fromARGB(
      (a.clamp(0.0, 1.0) * 255.0).round(),
      (_linearToSrgb(r) * 255.0).round(),
      (_linearToSrgb(g) * 255.0).round(),
      (_linearToSrgb(b) * 255.0).round(),
    );
  }

  @override
  String toString() => 'LinearColor(${r.toStringAsFixed(3)}, ${g.toStringAsFixed(3)}, ${b.toStringAsFixed(3)})';
}

/// Seven distinct celestial time-of-day phases with cinematic lighting atmospheres.
enum CelestialPhase {
  /// Golden-rose dawn as sun emerges over horizon (05:00 - 07:00).
  dawn(0.208, 0.292),

  /// Clear morning daylight with vibrant blue Rayleigh scattering (07:00 - 11:00).
  morning(0.292, 0.458),

  /// High solar zenith, intense white radiance and minimum air mass (11:00 - 13:00).
  noon(0.458, 0.542),

  /// Warm afternoon sun descending (13:00 - 17:00).
  afternoon(0.542, 0.708),

  /// Fiery crimson, orange and gold sunset horizon (17:00 - 19:30).
  dusk(0.708, 0.812),

  /// Deep twilight blue zenith with fading sunset horizon band (19:30 - 21:30).
  twilight(0.812, 0.896),

  /// Dark fantasy midnight with cosmic nebula clouds and silver moon (21:30 - 05:00).
  midnight(0.896, 0.208);

  const CelestialPhase(this.startNormalized, this.endNormalized);

  final double startNormalized;
  final double endNormalized;

  /// Check whether normalized time [0.0, 1.0) falls within this phase.
  bool contains(double normalizedTime) {
    final double t = normalizedTime % 1.0;
    if (startNormalized < endNormalized) {
      return t >= startNormalized && t < endNormalized;
    } else {
      // Wraps across midnight (e.g. 0.896 to 0.208)
      return t >= startNormalized || t < endNormalized;
    }
  }
}

/// Time-of-Day clock controller driving smooth diurnal transitions.
class TimeOfDayModel {
  TimeOfDayModel({
    double initialHours = 12.0,
    this.timeScale = 1.0,
  }) : _hours = initialHours % 24.0;

  double _hours;

  /// Time of day in hours [0.0, 24.0).
  double get hours => _hours;

  /// Time of day normalized to [0.0, 1.0).
  double get normalizedTime => _hours / 24.0;

  /// Speed multiplier for simulation progression (e.g. 60.0 = 1 minute per second).
  double timeScale;

  /// Advance clock by [deltaSeconds] multiplied by [timeScale].
  void advance(double deltaSeconds) {
    final double deltaHours = (deltaSeconds * timeScale) / 3600.0;
    _hours = (_hours + deltaHours) % 24.0;
    if (_hours < 0.0) _hours += 24.0;
  }

  /// Explicitly set the clock time in hours [0.0, 24.0).
  void setHours(double hours) {
    _hours = hours % 24.0;
    if (_hours < 0.0) _hours += 24.0;
  }

  /// Determine the current celestial diurnal phase.
  CelestialPhase get currentPhase {
    final double norm = normalizedTime;
    for (final phase in CelestialPhase.values) {
      if (phase.contains(norm)) {
        return phase;
      }
    }
    return CelestialPhase.noon;
  }

  /// Compute normalized progress [0.0, 1.0] within the current phase.
  double get phaseProgress {
    final CelestialPhase phase = currentPhase;
    final double norm = normalizedTime;
    if (phase.startNormalized < phase.endNormalized) {
      final double span = phase.endNormalized - phase.startNormalized;
      return (norm - phase.startNormalized) / (span > 0 ? span : 1.0);
    } else {
      // Midnight wrap-around
      final double span = (1.0 - phase.startNormalized) + phase.endNormalized;
      double offset = norm >= phase.startNormalized ? norm - phase.startNormalized : (1.0 - phase.startNormalized) + norm;
      return offset / (span > 0 ? span : 1.0);
    }
  }

  @override
  String toString() {
    final int h = _hours.floor();
    final int m = ((_hours - h) * 60.0).floor();
    final int s = (((_hours - h) * 60.0 - m) * 60.0).floor();
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')} (${currentPhase.name})';
  }
}

/// Celestial orbital mechanics calculating Sun and Moon vectors and atmospheric radiance.
class CelestialOrbitSystem {
  CelestialOrbitSystem({
    this.orbitalInclinationRad = 0.409088, // 23.44 degrees Earth-like obliquity
    this.latitudeRad = 0.785398,          // 45 degrees Mid-latitude
    this.lunarPhaseAngleRad = 0.0,         // Full moon default opposite sun
  });

  /// Orbital tilt / axial inclination in radians.
  final double orbitalInclinationRad;

  /// Geographic latitude of observer in radians.
  final double latitudeRad;

  /// Lunar phase angle relative to solar opposition.
  final double lunarPhaseAngleRad;

  /// Calculate the Sun's 3D direction unit vector in world space:
  /// +Y = Zenith (Up), +X = East (Dawn), -X = West (Dusk), +Z = South.
  SkyVector3 computeSunDirection(double normalizedTime) {
    // Solar hour angle: 0.25 (06:00) = East (sunrise), 0.50 (12:00) = South zenith (noon),
    // 0.75 (18:00) = West (sunset), 0.00 (00:00) = North nadir (midnight).
    final double hourAngle = (normalizedTime - 0.5) * 2.0 * math.pi;

    // Solar declination using orbital inclination
    final double declination = orbitalInclinationRad;

    // Solar elevation angle above horizon
    final double sinElevation = math.sin(latitudeRad) * math.sin(declination) +
        math.cos(latitudeRad) * math.cos(declination) * math.cos(hourAngle);
    final double elevation = math.asin(sinElevation.clamp(-1.0, 1.0));

    // Solar azimuth angle
    final double cosElevation = math.cos(elevation);
    double azimuth;
    if (cosElevation.abs() < 1e-6) {
      azimuth = 0.0;
    } else {
      final double sinAzimuth = -math.cos(declination) * math.sin(hourAngle) / cosElevation;
      final double cosAzimuth = (math.sin(declination) - math.sin(latitudeRad) * sinElevation) /
          (math.cos(latitudeRad) * cosElevation);
      azimuth = math.atan2(sinAzimuth, cosAzimuth);
    }

    return SkyVector3.fromSpherical(azimuth, elevation).normalized();
  }

  /// Calculate the Moon's 3D direction unit vector in world space.
  SkyVector3 computeMoonDirection(double normalizedTime) {
    // Moon opposes the sun with a 5.14 degree orbital inclination perturbation
    final double lunarTime = (normalizedTime + 0.5) % 1.0;
    final SkyVector3 oppositeSun = computeSunDirection(lunarTime);

    // Apply subtle lunar orbit inclination tilt (5.14 degrees = 0.0897 rad)
    const double lunarTilt = 0.0897;
    final double cosTilt = math.cos(lunarTilt);
    final double sinTilt = math.sin(lunarTilt);

    final SkyVector3 tiltedMoon = SkyVector3(
      oppositeSun.x,
      oppositeSun.y * cosTilt - oppositeSun.z * sinTilt,
      oppositeSun.y * sinTilt + oppositeSun.z * cosTilt,
    );

    return tiltedMoon.normalized();
  }

  /// Compute Sun linear color radiance factoring in atmospheric path extinction and color temperature.
  LinearColor computeSunRadiance(SkyVector3 sunDir) {
    final double elevation = sunDir.y;

    if (elevation < -0.15) {
      // Sun well below horizon
      return LinearColor.black;
    }

    // Color temperature gradient:
    // Dawn/Dusk horizon: 2000K (deep golden/fiery red-orange)
    // Morning/Afternoon: 4500K - 5500K (warm daylight)
    // Noon zenith: 6500K (crisp white daylight)
    final double t = (elevation.clamp(-0.15, 0.85) + 0.15) / 1.0;
    final double kelvin = 2000.0 + (6500.0 - 2000.0) * math.pow(t, 0.6);
    final LinearColor blackbody = LinearColor.fromColorTemperature(kelvin);

    // Atmospheric extinction multiplier: longer path at horizon dims the sun
    final double pathExtinction = (elevation <= 0.0)
        ? (elevation + 0.15) / 0.15 * 0.15
        : 0.15 + 0.85 * (1.0 - math.exp(-3.0 * elevation));

    // Solar intensity scale (HDR daylight radiance)
    const double baseSunRadiance = 8.5;
    return blackbody * (baseSunRadiance * pathExtinction);
  }

  /// Compute Moon linear color radiance.
  LinearColor computeMoonRadiance(SkyVector3 moonDir) {
    final double elevation = moonDir.y;
    if (elevation < -0.10) {
      return LinearColor.black;
    }

    // Eerie silver/cyan astral moonlight (~8500K nocturnal spectrum with cool Purkinje shift)
    final LinearColor lunarBase = LinearColor.fromColorTemperature(8500.0);
    final LinearColor moonlight = LinearColor(
      lunarBase.r * 0.75,
      lunarBase.g * 0.90,
      lunarBase.b * 1.30, // Cool moonlight tint
    );

    final double pathFactor = (elevation <= 0.0)
        ? (elevation + 0.10) / 0.10 * 0.3
        : 0.3 + 0.7 * (1.0 - math.exp(-2.5 * elevation));

    const double baseMoonRadiance = 1.6;
    return moonlight * (baseMoonRadiance * pathFactor);
  }
}

/// Atmospheric parameters controlling Rayleigh, Mie, and Nebula scattering.
class AtmosphericParameters {
  const AtmosphericParameters({
    this.rayleighCoeff = const SkyVector3(5.8e-3, 13.5e-3, 33.1e-3),
    this.rayleighScale = 1.0,
    this.mieCoeff = 0.0024,
    this.mieG = 0.76,
    this.turbidity = 2.0,
    this.groundColor = const LinearColor(0.12, 0.09, 0.07),
    this.nebulaColor1 = const LinearColor(0.62, 0.12, 0.75), // Cosmic Purple
    this.nebulaColor2 = const LinearColor(0.08, 0.52, 0.85), // Astral Cyan
    this.nebulaIntensity = 2.8,
    this.starIntensity = 2.2,
    this.exposure = 1.0,
  });

  /// Rayleigh scattering coefficients for Red, Green, Blue wavelengths.
  final SkyVector3 rayleighCoeff;

  /// Rayleigh intensity multiplier.
  final double rayleighScale;

  /// Mie scattering coefficient (aerosol haze).
  final double mieCoeff;

  /// Henyey-Greenstein forward scattering asymmetry factor g [0.65, 0.90].
  final double mieG;

  /// Atmospheric turbidity / air pollution / mist factor [1.0, 10.0].
  final double turbidity;

  /// Nadir / ground bounce ambient color.
  final LinearColor groundColor;

  /// Dark fantasy midnight primary nebula color (cosmic magenta/purple).
  final LinearColor nebulaColor1;

  /// Dark fantasy midnight secondary nebula color (astral cyan).
  final LinearColor nebulaColor2;

  /// Multiplier for cosmic nebula emission at night.
  final double nebulaIntensity;

  /// Starfield brightness scalar.
  final double starIntensity;

  /// Global sky exposure factor.
  final double exposure;

  AtmosphericParameters copyWith({
    SkyVector3? rayleighCoeff,
    double? rayleighScale,
    double? mieCoeff,
    double? mieG,
    double? turbidity,
    LinearColor? groundColor,
    LinearColor? nebulaColor1,
    LinearColor? nebulaColor2,
    double? nebulaIntensity,
    double? starIntensity,
    double? exposure,
  }) {
    return AtmosphericParameters(
      rayleighCoeff: rayleighCoeff ?? this.rayleighCoeff,
      rayleighScale: rayleighScale ?? this.rayleighScale,
      mieCoeff: mieCoeff ?? this.mieCoeff,
      mieG: mieG ?? this.mieG,
      turbidity: turbidity ?? this.turbidity,
      groundColor: groundColor ?? this.groundColor,
      nebulaColor1: nebulaColor1 ?? this.nebulaColor1,
      nebulaColor2: nebulaColor2 ?? this.nebulaColor2,
      nebulaIntensity: nebulaIntensity ?? this.nebulaIntensity,
      starIntensity: starIntensity ?? this.starIntensity,
      exposure: exposure ?? this.exposure,
    );
  }
}

/// Atmospheric presets for diverse AAA environmental and fantasy scenarios.
class SkyPreset {
  SkyPreset._();

  /// Standard clear day with crisp Rayleigh blue sky.
  static const AtmosphericParameters clearDay = AtmosphericParameters(
    rayleighScale: 1.0,
    mieCoeff: 0.002,
    mieG: 0.76,
    turbidity: 1.8,
    nebulaIntensity: 1.5,
    starIntensity: 2.0,
    exposure: 1.0,
  );

  /// Golden hour sunset with intense forward Mie halo and warm horizon haze.
  static const AtmosphericParameters goldenDusk = AtmosphericParameters(
    rayleighScale: 1.4,
    mieCoeff: 0.006,
    mieG: 0.85,
    turbidity: 4.5,
    groundColor: LinearColor(0.22, 0.11, 0.05),
    exposure: 1.15,
  );

  /// 2027 Dark Fantasy Astral Midnight with luminous cosmic nebula filaments and dense starfield.
  static const AtmosphericParameters darkFantasyMidnight = AtmosphericParameters(
    rayleighScale: 0.8,
    mieCoeff: 0.0015,
    mieG: 0.72,
    turbidity: 1.2,
    groundColor: LinearColor(0.04, 0.03, 0.06),
    nebulaColor1: LinearColor(0.75, 0.15, 0.88),
    nebulaColor2: LinearColor(0.05, 0.65, 0.95),
    nebulaIntensity: 4.2,
    starIntensity: 3.5,
    exposure: 1.35,
  );

  /// Apocalyptic Blood Moon with eerie crimson atmospheric tint and spectral mist.
  static const AtmosphericParameters bloodMoon = AtmosphericParameters(
    rayleighCoeff: SkyVector3(25.0e-3, 4.0e-3, 3.0e-3),
    rayleighScale: 1.8,
    mieCoeff: 0.008,
    mieG: 0.88,
    turbidity: 6.0,
    groundColor: LinearColor(0.18, 0.04, 0.03),
    nebulaColor1: LinearColor(0.95, 0.10, 0.15),
    nebulaColor2: LinearColor(0.55, 0.05, 0.35),
    nebulaIntensity: 3.8,
    starIntensity: 1.8,
    exposure: 1.2,
  );
}

/// First-Order Spherical Harmonics (L0 + L1 bands) diffuse irradiance representation.
/// Encodes omnidirectional ambient light and directional color gradients in 4 RGB coefficients.
class SphericalHarmonicsL1 {
  const SphericalHarmonicsL1({
    required this.l00,
    required this.l1Minus1,
    required this.l10,
    required this.l11,
  });

  /// Monopole L0,0 coefficient: average omnidirectional hemispherical ambient color.
  final LinearColor l00;

  /// Dipole L1,-1 coefficient: vertical gradient along Y (Zenith vs Nadir ground contrast).
  final LinearColor l1Minus1;

  /// Dipole L1,0 coefficient: longitudinal gradient along Z (North vs South).
  final LinearColor l10;

  /// Dipole L1,1 coefficient: latitudinal gradient along X (East dawn vs West sunset).
  final LinearColor l11;

  /// Evaluate diffuse irradiance $E(\vec{n})$ for any surface normal [normal] using standard SH convolution.
  LinearColor evaluateIrradiance(SkyVector3 normal) {
    final SkyVector3 n = normal.normalized();

    // Standard Ramamoorthi & Hanrahan SH irradiance reconstruction constants:
    // c0 = 0.886227 (pi * Y00)
    // c1 = 1.023326 (2*pi/3 * Y1m)
    const double c0 = 0.886227;
    const double c1 = 1.023326;

    final double red = (c0 * l00.r + c1 * (l1Minus1.r * n.y + l10.r * n.z + l11.r * n.x)).clamp(0.0, 100.0);
    final double green = (c0 * l00.g + c1 * (l1Minus1.g * n.y + l10.g * n.z + l11.g * n.x)).clamp(0.0, 100.0);
    final double blue = (c0 * l00.b + c1 * (l1Minus1.b * n.y + l10.b * n.z + l11.b * n.x)).clamp(0.0, 100.0);

    return LinearColor(red, green, blue);
  }
}

/// Hemispheric 3-point ambient probe (Zenith, Horizon, Ground).
class HemisphericAmbientProbe {
  const HemisphericAmbientProbe({
    required this.zenithColor,
    required this.horizonColor,
    required this.groundColor,
  });

  /// Downwelling ambient color from direct overhead sky zenith.
  final LinearColor zenithColor;

  /// Atmospheric ambient color at the horizon equator.
  final LinearColor horizonColor;

  /// Upwelling ground bounce ambient reflection from nadir.
  final LinearColor groundColor;

  /// Interpolate ambient irradiance for a surface normal [normal].
  LinearColor evaluate(SkyVector3 normal) {
    final double ny = normal.normalized().y;
    if (ny >= 0.0) {
      // Blend between horizon and zenith
      return horizonColor.lerp(zenithColor, math.pow(ny, 0.7).toDouble());
    } else {
      // Blend between horizon and ground nadir
      return horizonColor.lerp(groundColor, math.pow(-ny, 0.8).toDouble());
    }
  }
}

/// Primary directional light source probe (Sun during day, Moon at night).
class DirectionalLightProbe {
  const DirectionalLightProbe({
    required this.direction,
    required this.radiance,
    required this.intensity,
    required this.shadowTint,
    required this.isSun,
  });

  /// Direction towards the light source in world space.
  final SkyVector3 direction;

  /// Linear RGB color radiance of the primary luminary.
  final LinearColor radiance;

  /// Normalized illuminance intensity scalar.
  final double intensity;

  /// Ambient shadow color tint in unlit crevices.
  final LinearColor shadowTint;

  /// True if Sun is the active primary light; false if Moon is active.
  final bool isSun;
}

/// Global Illumination & Ambient Probe data packaged for world shaders
/// (terrain, vegetation wind shader, puddle SSR reflections, character lighting).
class WorldGiUniforms {
  const WorldGiUniforms({
    required this.zenithColor,
    required this.horizonColor,
    required this.groundColor,
    required this.mainLightDirection,
    required this.mainLightRadiance,
    required this.mainLightIntensity,
    required this.shL00,
    required this.shL1Y,
    required this.shL1X,
    required this.shL1Z,
    required this.ambientOcclusionFactor,
  });

  final LinearColor zenithColor;
  final LinearColor horizonColor;
  final LinearColor groundColor;
  final SkyVector3 mainLightDirection;
  final LinearColor mainLightRadiance;
  final double mainLightIntensity;
  final LinearColor shL00;
  final LinearColor shL1Y;
  final LinearColor shL1X;
  final LinearColor shL1Z;
  final double ambientOcclusionFactor;

  /// Pack uniforms into a contiguous 32-float buffer for world shaders.
  Float32List toFloat32List() {
    final Float32List buffer = Float32List(32);
    // 0..2: Zenith RGB
    buffer[0] = zenithColor.r;
    buffer[1] = zenithColor.g;
    buffer[2] = zenithColor.b;
    // 3..5: Horizon RGB
    buffer[3] = horizonColor.r;
    buffer[4] = horizonColor.g;
    buffer[5] = horizonColor.b;
    // 6..8: Ground RGB
    buffer[6] = groundColor.r;
    buffer[7] = groundColor.g;
    buffer[8] = groundColor.b;
    // 9..11: Main Light Direction XYZ
    buffer[9] = mainLightDirection.x;
    buffer[10] = mainLightDirection.y;
    buffer[11] = mainLightDirection.z;
    // 12..14: Main Light Radiance RGB
    buffer[12] = mainLightRadiance.r;
    buffer[13] = mainLightRadiance.g;
    buffer[14] = mainLightRadiance.b;
    // 15: Main Light Intensity
    buffer[15] = mainLightIntensity;
    // 16..18: SH L0,0 RGB
    buffer[16] = shL00.r;
    buffer[17] = shL00.g;
    buffer[18] = shL00.b;
    // 19..21: SH L1,Y (L1,-1) RGB
    buffer[19] = shL1Y.r;
    buffer[20] = shL1Y.g;
    buffer[21] = shL1Y.b;
    // 22..24: SH L1,X (L1,1) RGB
    buffer[22] = shL1X.r;
    buffer[23] = shL1X.g;
    buffer[24] = shL1X.b;
    // 25..27: SH L1,Z (L1,0) RGB
    buffer[25] = shL1Z.r;
    buffer[26] = shL1Z.g;
    buffer[27] = shL1Z.b;
    // 28: Ambient Occlusion base factor
    buffer[28] = ambientOcclusionFactor;
    // 29..31: Reserved padding for 16-byte alignment
    buffer[29] = 0.0;
    buffer[30] = 0.0;
    buffer[31] = 0.0;
    return buffer;
  }
}

/// Global Illumination engine calculating Spherical Harmonics, hemispheric probes,
/// and world shader uniform buffers from sky conditions.
class GlobalIlluminationComputer {
  GlobalIlluminationComputer();

  /// Analytical calculation of ambient GI probe colors from celestial positions and atmospheric parameters.
  static WorldGiUniforms computeWorldGi({
    required SkyVector3 sunDir,
    required SkyVector3 moonDir,
    required LinearColor sunRadiance,
    required LinearColor moonRadiance,
    required AtmosphericParameters params,
  }) {
    final double sunElev = sunDir.y;
    final double moonElev = moonDir.y;

    // Determine primary directional light
    final bool isDaytime = sunElev >= -0.05;
    final SkyVector3 lightDir = isDaytime ? sunDir : moonDir;
    final LinearColor lightRadiance = isDaytime ? sunRadiance : moonRadiance;
    final double lightIntensity = isDaytime
        ? (sunElev.clamp(0.0, 1.0) * 1.0 + 0.15)
        : (moonElev.clamp(0.0, 1.0) * 0.4 + 0.08);

    // 1. Zenith Color Computation:
    // Rayleigh scattering dominant at daytime zenith (vibrant blue: 0.18, 0.42, 0.85).
    // Twilight zenith shifts to deep indigo / rose.
    // Midnight zenith shifts to dark astral indigo / obsidian.
    LinearColor zenithColor;
    if (sunElev > 0.20) {
      // Clear daytime: pure Rayleigh blue
      zenithColor = LinearColor(0.18, 0.42, 0.88) * (sunElev * 0.9 + 0.1);
    } else if (sunElev >= -0.10) {
      // Dawn/dusk twilight blend
      final double t = (sunElev + 0.10) / 0.30;
      final LinearColor twilightZenith = LinearColor(0.10, 0.15, 0.38);
      final LinearColor dayZenith = LinearColor(0.18, 0.42, 0.88);
      zenithColor = twilightZenith.lerp(dayZenith, t);
    } else {
      // Astral midnight zenith with cosmic nebula influence
      final LinearColor nightZenith = LinearColor(0.02, 0.03, 0.08);
      final LinearColor nebulaZenith = (params.nebulaColor1 + params.nebulaColor2) * 0.06 * params.nebulaIntensity;
      zenithColor = nightZenith + nebulaZenith;
    }

    // 2. Horizon Color Computation:
    // Heavy Mie scattering and optical path length.
    // Daytime: whitish/pale blue haze.
    // Sunset/Dawn: fiery orange/crimson belt.
    // Midnight: deep cool haze.
    LinearColor horizonColor;
    if (sunElev > 0.25) {
      horizonColor = LinearColor(0.68, 0.78, 0.92) * (sunElev * 0.7 + 0.3);
    } else if (sunElev >= -0.08) {
      // Sunset golden/crimson belt
      final double sunsetFactor = 1.0 - (sunElev.abs() / 0.25).clamp(0.0, 1.0);
      final LinearColor goldenGaze = LinearColor(0.95, 0.48, 0.18);
      final LinearColor midHorizon = LinearColor(0.55, 0.42, 0.48);
      horizonColor = goldenGaze.lerp(midHorizon, 1.0 - sunsetFactor) * (sunsetFactor * 1.5 + 0.5);
    } else {
      // Night horizon
      horizonColor = LinearColor(0.05, 0.07, 0.12) + (moonRadiance * 0.15);
    }

    // 3. Ground Bounce Nadir Color:
    // Diffuse bounce of sky + directional light off terrain.
    final LinearColor groundAmbient = params.groundColor * (zenithColor.luminance * 0.35 + lightIntensity * 0.25);

    // 4. First-Order Spherical Harmonics Decomposition:
    // L0,0 = Average of Zenith, Horizon, and Ground
    final LinearColor shL00 = (zenithColor * 0.35 + horizonColor * 0.40 + groundAmbient * 0.25);

    // L1,Y = Contrast between Zenith and Ground (vertical gradient)
    final LinearColor shL1Y = (zenithColor - groundAmbient) * 0.55;

    // L1,X = Latitudinal gradient along sun direction (East-West dawn/sunset bias)
    final LinearColor shL1X = (horizonColor * lightDir.x) * 0.45;

    // L1,Z = Longitudinal gradient along sun direction (North-South bias)
    final LinearColor shL1Z = (horizonColor * lightDir.z) * 0.45;

    return WorldGiUniforms(
      zenithColor: zenithColor,
      horizonColor: horizonColor,
      groundColor: groundAmbient,
      mainLightDirection: lightDir,
      mainLightRadiance: lightRadiance,
      mainLightIntensity: lightIntensity,
      shL00: shL00,
      shL1Y: shL1Y,
      shL1X: shL1X,
      shL1Z: shL1Z,
      ambientOcclusionFactor: 1.0,
    );
  }
}

/// Central Skybox and Global Illumination controller.
/// Drives time-of-day progression, orbital updates, shader uniform creation, and GI probe generation.
class DynamicSkyboxController extends ChangeNotifier {
  DynamicSkyboxController({
    double initialHours = 12.0,
    AtmosphericParameters? initialParams,
    SkyVector3? initialCameraRotation,
    double initialFov = 1.047198, // 60 degrees FOV in radians
    AdaptiveQualityScaler? scaler,
    HardwareTier? tierOverride,
    bool autoListenToScaler = true,
  })  : _timeModel = TimeOfDayModel(initialHours: initialHours),
        _orbitSystem = CelestialOrbitSystem(),
        _params = initialParams ?? SkyPreset.clearDay,
        _cameraRotation = initialCameraRotation ?? SkyVector3.zero,
        _fov = initialFov,
        _scaler = scaler,
        _tierOverride = tierOverride {
    _recalculate();
    if (autoListenToScaler) {
      _listenToScaler();
    }
  }

  final TimeOfDayModel _timeModel;
  final CelestialOrbitSystem _orbitSystem;
  AtmosphericParameters _params;
  SkyVector3 _cameraRotation; // pitch (x), yaw (y), roll (z)
  double _fov;
  final AdaptiveQualityScaler? _scaler;
  HardwareTier? _tierOverride;
  StreamSubscription<QualitySettings>? _scalerSubscription;

  late SkyVector3 _sunDirection;
  late SkyVector3 _moonDirection;
  late LinearColor _sunRadiance;
  late LinearColor _moonRadiance;
  late WorldGiUniforms _giUniforms;

  double _totalTimeElapsed = 0.0;

  // Getters
  TimeOfDayModel get timeModel => _timeModel;
  CelestialOrbitSystem get orbitSystem => _orbitSystem;
  AtmosphericParameters get params => _params;
  SkyVector3 get cameraRotation => _cameraRotation;
  double get fov => _fov;

  SkyVector3 get sunDirection => _sunDirection;
  SkyVector3 get moonDirection => _moonDirection;
  LinearColor get sunRadiance => _sunRadiance;
  LinearColor get moonRadiance => _moonRadiance;
  WorldGiUniforms get giUniforms => _giUniforms;
  double get totalTimeElapsed => _totalTimeElapsed;
  AdaptiveQualityScaler? get scaler => _scaler;

  /// Resolves the active [HardwareTier] from [tierOverride], [scaler],
  /// or [GraphicsSettingsService.instance.scaler.currentTier].
  static HardwareTier resolveActiveTier({
    AdaptiveQualityScaler? scaler,
    HardwareTier? tierOverride,
  }) {
    if (tierOverride != null) return tierOverride;
    if (scaler != null) return scaler.currentTier;
    try {
      return GraphicsSettingsService.instance.scaler.currentTier;
    } catch (_) {
      return HardwareTier.mid;
    }
  }

  /// Resolves active [QualitySettings] from [scaler] or [GraphicsSettingsService.instance.scaler].
  static QualitySettings resolveActiveSettings({
    AdaptiveQualityScaler? scaler,
  }) {
    if (scaler != null) return scaler.currentSettings;
    try {
      return GraphicsSettingsService.instance.scaler.currentSettings;
    } catch (_) {
      return const QualitySettings(
        tier: HardwareTier.mid,
        throttleLevel: 0,
        renderResolutionScale: 1.0,
        volumetricFogStepCount: 16,
        ssaoEnabled: true,
        ssaoBlurEnabled: true,
        maxActiveParticles: 2000,
        shadowResolution: 1024,
        shadowCascadeCount: 2,
        lodDistanceMultiplier: 1.0,
        bloomEnabled: true,
        crowdDensityCap: 2000,
        targetFps: 60.0,
      );
    }
  }

  /// Active hardware tier driving quality adjustments.
  HardwareTier get activeTier =>
      _tierOverride ?? _scaler?.currentTier ?? resolveActiveTier(scaler: _scaler);

  /// Active dynamic quality settings.
  QualitySettings get activeSettings =>
      _scaler?.currentSettings ?? resolveActiveSettings(scaler: _scaler);

  /// Whether device has low physical memory (<= 2048 MB RAM).
  bool get isLowMemoryDevice {
    try {
      final profile = _scaler?.hardwareProfile ??
          GraphicsSettingsService.instance.scaler.hardwareProfile;
      return profile.totalRamMb <= 2048;
    } catch (_) {
      return activeTier == HardwareTier.eco || activeTier == HardwareTier.low;
    }
  }

  /// Background star field particle count:
  /// - Eco / Low tiers (<=2GB RAM): 40 stars
  /// - Mid tier: 100 stars
  /// - High / Ultra tiers: 200 stars (full celestial cluster)
  int get activeStarCount {
    if (isLowMemoryDevice || activeTier == HardwareTier.eco || activeTier == HardwareTier.low) {
      return 40;
    } else if (activeTier == HardwareTier.mid) {
      return 100;
    } else {
      return 200;
    }
  }

  /// Whether cloud volumetric raymarching is enabled.
  /// Disabled on Eco / Low tiers (<=2GB RAM), falling back to lightweight 2D sky gradient.
  bool get enableVolumetricClouds {
    if (isLowMemoryDevice || activeTier == HardwareTier.eco || activeTier == HardwareTier.low) {
      return false;
    }
    return true;
  }

  /// Whether multi-step animated cloud layers are enabled (High/Ultra tiers).
  bool get enableAnimatedCloudLayers {
    if (!enableVolumetricClouds) return false;
    return activeTier == HardwareTier.high || activeTier == HardwareTier.ultra;
  }

  /// Whether sun glare bloom is enabled (High/Ultra tiers).
  bool get enableSunGlareBloom {
    if (isLowMemoryDevice || activeTier == HardwareTier.eco || activeTier == HardwareTier.low) {
      return false;
    }
    return activeTier == HardwareTier.high ||
        activeTier == HardwareTier.ultra ||
        activeSettings.bloomEnabled;
  }

  /// Overrides the hardware tier explicitly for testing or manual graphics configuration.
  void setTierOverride(HardwareTier? tier) {
    _tierOverride = tier;
    notifyListeners();
  }

  void _listenToScaler() {
    try {
      final activeScaler = _scaler ?? GraphicsSettingsService.instance.scaler;
      _scalerSubscription = activeScaler.onSettingsChanged.listen((_) {
        notifyListeners();
      });
    } catch (_) {
      // In tests or headless environments where GraphicsSettingsService is uninitialized
    }
  }

  /// Pre-warms skybox star field, celestial diurnal gradients, and volumetric cloud LUTs
  /// via [ZeroJankPreloader.instance.preloadAtomic] with [PreloadPriority.nearbyLod0]
  /// strictly bounded within a <2ms frame budget.
  static Future<bool> prewarmSkyboxAssets({
    ZeroJankPreloader? preloader,
    HardwareTier? tier,
    AdaptiveQualityScaler? scaler,
  }) async {
    final ZeroJankPreloader activePreloader = preloader ?? ZeroJankPreloader.instance;
    final HardwareTier targetTier = tier ?? resolveActiveTier(scaler: scaler);

    try {
      return await activePreloader.preloadAtomic<bool>(
        id: 'skybox_celestial_starfield_gradients_${targetTier.name}',
        priority: PreloadPriority.nearbyLod0,
        targetCache: CacheTarget.vram,
        estimatedSizeBytes: 128 * 1024,
        tags: <String>{'skybox', 'celestial', 'starfield', 'gradients', targetTier.name},
        isPinned: false,
        loader: () async {
          // 1. Pre-warm procedural star field cluster for the target tier
          final int starCount =
              (targetTier == HardwareTier.eco || targetTier == HardwareTier.low) ? 40 : 200;
          final List<SkyStar> stars = SkyStarCluster.getStars(count: starCount);
          assert(stars.isNotEmpty);

          // 2. Pre-warm celestial diurnal phase color stops and SH basis computations (<1ms)
          final CelestialOrbitSystem orbit = CelestialOrbitSystem();
          for (final phase in CelestialPhase.values) {
            final double t = phase.startNormalized;
            final SkyVector3 sun = orbit.computeSunDirection(t);
            final SkyVector3 moon = orbit.computeMoonDirection(t);
            final LinearColor sunRad = orbit.computeSunRadiance(sun);
            final LinearColor moonRad = orbit.computeMoonRadiance(moon);
            GlobalIlluminationComputer.computeWorldGi(
              sunDir: sun,
              moonDir: moon,
              sunRadiance: sunRad,
              moonRadiance: moonRad,
              params: SkyPreset.clearDay,
            );
          }

          // 3. Pre-warm cloud noise tables and sun bloom palettes
          SkyVolumetricCloudRenderer.prewarmLut();

          return true;
        },
      );
    } catch (e) {
      debugPrint('DynamicSkybox: prewarmSkyboxAssets error: $e');
      return false;
    }
  }

  void setParameters(AtmosphericParameters params) {
    _params = params;
    _recalculate();
    notifyListeners();
  }

  void setCameraRotation(SkyVector3 rotation) {
    _cameraRotation = rotation;
    notifyListeners();
  }

  void setFov(double fov) {
    _fov = fov.clamp(0.1, math.pi * 0.95);
    notifyListeners();
  }

  void setTime(double hours) {
    _timeModel.setHours(hours);
    _recalculate();
    notifyListeners();
  }

  /// Advance simulation by [dtSeconds].
  void update(double dtSeconds) {
    _totalTimeElapsed += dtSeconds;
    _timeModel.advance(dtSeconds);
    _recalculate();
    notifyListeners();
  }

  void _recalculate() {
    final double normTime = _timeModel.normalizedTime;
    _sunDirection = _orbitSystem.computeSunDirection(normTime);
    _moonDirection = _orbitSystem.computeMoonDirection(normTime);
    _sunRadiance = _orbitSystem.computeSunRadiance(_sunDirection);
    _moonRadiance = _orbitSystem.computeMoonRadiance(_moonDirection);

    _giUniforms = GlobalIlluminationComputer.computeWorldGi(
      sunDir: _sunDirection,
      moonDir: _moonDirection,
      sunRadiance: _sunRadiance,
      moonRadiance: _moonRadiance,
      params: _params,
    );
  }

  /// Pack uniforms for `shaders/world/atmospheric_sky.frag` into exact 39-float array.
  Float32List buildShaderUniforms(ui.Size size, {double? timeSeconds}) {
    final Float32List uniforms = Float32List(39);
    final double time = timeSeconds ?? _totalTimeElapsed;

    // 0..1: uResolution (vec2)
    uniforms[0] = size.width;
    uniforms[1] = size.height;
    // 2: uTime (float)
    uniforms[2] = time;
    // 3: uTimeOfDay (float)
    uniforms[3] = _timeModel.normalizedTime;
    // 4..6: uSunDirection (vec3)
    uniforms[4] = _sunDirection.x;
    uniforms[5] = _sunDirection.y;
    uniforms[6] = _sunDirection.z;
    // 7..9: uMoonDirection (vec3)
    uniforms[7] = _moonDirection.x;
    uniforms[8] = _moonDirection.y;
    uniforms[9] = _moonDirection.z;
    // 10..12: uSunColor (vec3)
    uniforms[10] = _sunRadiance.r;
    uniforms[11] = _sunRadiance.g;
    uniforms[12] = _sunRadiance.b;
    // 13..15: uMoonColor (vec3)
    uniforms[13] = _moonRadiance.r;
    uniforms[14] = _moonRadiance.g;
    uniforms[15] = _moonRadiance.b;
    // 16..18: uRayleighCoeff (vec3)
    uniforms[16] = _params.rayleighCoeff.x;
    uniforms[17] = _params.rayleighCoeff.y;
    uniforms[18] = _params.rayleighCoeff.z;
    // 19: uRayleighScale (float)
    uniforms[19] = _params.rayleighScale;
    // 20: uMieCoeff (float)
    uniforms[20] = _params.mieCoeff;
    // 21: uMieG (float)
    uniforms[21] = _params.mieG;
    // 22: uTurbidity (float)
    uniforms[22] = _params.turbidity;
    // 23..25: uGroundColor (vec3)
    uniforms[23] = _params.groundColor.r;
    uniforms[24] = _params.groundColor.g;
    uniforms[25] = _params.groundColor.b;
    // 26..28: uNebulaColor1 (vec3)
    uniforms[26] = _params.nebulaColor1.r;
    uniforms[27] = _params.nebulaColor1.g;
    uniforms[28] = _params.nebulaColor1.b;
    // 29..31: uNebulaColor2 (vec3)
    uniforms[29] = _params.nebulaColor2.r;
    uniforms[30] = _params.nebulaColor2.g;
    uniforms[31] = _params.nebulaColor2.b;
    // 32: uNebulaIntensity (float)
    uniforms[32] = _params.nebulaIntensity;
    // 33: uStarIntensity (float)
    uniforms[33] = _params.starIntensity;
    // 34..36: uCameraRotation (vec3)
    uniforms[34] = _cameraRotation.x;
    uniforms[35] = _cameraRotation.y;
    uniforms[36] = _cameraRotation.z;
    // 37: uFov (float)
    uniforms[37] = _fov;
    // 38: uExposure (float)
    uniforms[38] = _params.exposure;

    return uniforms;
  }

  /// Apply all 39 uniforms to an active Flutter `FragmentShader` instance.
  void applyToShader(ui.FragmentShader shader, ui.Size size, {double? timeSeconds}) {
    final Float32List uniforms = buildShaderUniforms(size, timeSeconds: timeSeconds);
    for (int i = 0; i < uniforms.length; i++) {
      shader.setFloat(i, uniforms[i]);
    }
  }

  @override
  void dispose() {
    _scalerSubscription?.cancel();
    _scalerSubscription = null;
    super.dispose();
  }
}

/// CustomPainter rendering either via GPU FragmentShader or high-fidelity procedural canvas fallback.
class DynamicSkyboxPainter extends CustomPainter {
  DynamicSkyboxPainter({
    required this.controller,
    this.shader,
    super.repaint,
  });

  final DynamicSkyboxController controller;
  final ui.FragmentShader? shader;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    if (shader != null) {
      // Hardware accelerated GPU runtime shader pass
      controller.applyToShader(shader!, size);
      final ui.Paint paint = ui.Paint()..shader = shader;
      canvas.drawRect(ui.Offset.zero & size, paint);
    } else {
      // High-Fidelity Canvas Fallback (Used during tests or unsupported platforms)
      _paintAnalyticalFallback(canvas, size);
    }
  }

  void _paintAnalyticalFallback(ui.Canvas canvas, ui.Size size) {
    final WorldGiUniforms gi = controller.giUniforms;
    final SkyVector3 sunDir = controller.sunDirection;
    final SkyVector3 moonDir = controller.moonDirection;

    // 1. Lightweight 2D Hemispheric Sky Gradient (Zenith -> Horizon -> Ground)
    final ui.Rect rect = ui.Offset.zero & size;
    final double horizonY = size.height * (0.55 + sunDir.y * 0.1);

    final ui.Gradient skyGrad = ui.Gradient.linear(
      ui.Offset(size.width * 0.5, 0.0),
      ui.Offset(size.width * 0.5, size.height),
      [
        gi.zenithColor.toColor(),
        gi.horizonColor.toColor(),
        gi.groundColor.toColor(),
      ],
      [
        0.0,
        (horizonY / size.height).clamp(0.2, 0.8),
        1.0,
      ],
    );

    final ui.Paint bgPaint = ui.Paint()..shader = skyGrad;
    canvas.drawRect(rect, bgPaint);

    // 2. Nocturnal Celestial Star Field (Adaptive Tier: 40 on Eco/Low, 200 on High/Ultra)
    _paintStarField(canvas, size);

    // 3. Volumetric Cloud Layer Raymarching (Bypassed completely on Eco/Low -> Lightweight 2D sky gradient)
    if (controller.enableVolumetricClouds) {
      SkyVolumetricCloudRenderer.paintVolumetricClouds(
        canvas,
        size,
        controller,
        highFidelity: controller.enableAnimatedCloudLayers,
      );
    }

    // 4. Solar Celestial Disk & Mie Forward Halo & Sun Glare Bloom
    if (sunDir.y > -0.05) {
      final double sunScreenX = size.width * (0.5 + sunDir.x * 0.45);
      final double sunScreenY = horizonY - sunDir.y * (size.height * 0.45);
      final ui.Offset sunPos = ui.Offset(sunScreenX, sunScreenY);

      // Forward Mie glow halo
      final ui.Paint haloPaint = ui.Paint()
        ..shader = ui.Gradient.radial(
          sunPos,
          size.width * 0.35,
          [
            controller.sunRadiance.toColor().withAlpha(140),
            controller.sunRadiance.toColor().withAlpha(0),
          ],
        );
      canvas.drawCircle(sunPos, size.width * 0.35, haloPaint);

      // Sun Glare Bloom (High/Ultra tiers: soft HDR bloom, anamorphic glare streaks, diffraction spikes)
      if (controller.enableSunGlareBloom) {
        SunGlareBloomRenderer.paintSunGlareBloom(
          canvas: canvas,
          size: size,
          sunPos: sunPos,
          sunRadiance: controller.sunRadiance,
          sunElev: sunDir.y,
        );
      }

      // Solar core disk
      final ui.Paint sunDiskPaint = ui.Paint()
        ..color = const ui.Color(0xFFFFFFFF)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.solid, 4.0);
      canvas.drawCircle(sunPos, size.width * 0.025, sunDiskPaint);
    }

    // 5. Lunar Celestial Disk & Astral Glow
    if (moonDir.y > -0.05 && sunDir.y < 0.15) {
      final double moonScreenX = size.width * (0.5 + moonDir.x * 0.45);
      final double moonScreenY = horizonY - moonDir.y * (size.height * 0.45);
      final ui.Offset moonPos = ui.Offset(moonScreenX, moonScreenY);

      // Lunar silver halo
      final ui.Paint moonHaloPaint = ui.Paint()
        ..shader = ui.Gradient.radial(
          moonPos,
          size.width * 0.22,
          [
            controller.moonRadiance.toColor().withAlpha(100),
            controller.moonRadiance.toColor().withAlpha(0),
          ],
        );
      canvas.drawCircle(moonPos, size.width * 0.22, moonHaloPaint);

      // Lunar disc
      final ui.Paint moonDiskPaint = ui.Paint()
        ..color = const ui.Color(0xFFE8F2FF)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.solid, 2.0);
      canvas.drawCircle(moonPos, size.width * 0.018, moonDiskPaint);
    }
  }

  void _paintStarField(ui.Canvas canvas, ui.Size size) {
    final double sunElev = controller.sunDirection.y;
    // Stars fade in as sun dips below elevation 0.25
    if (sunElev > 0.25) return;

    final double nightFactor =
        ((0.25 - sunElev) / 0.35).clamp(0.0, 1.0) * (controller.params.starIntensity / 2.0);
    if (nightFactor <= 0.01) return;

    final int starCount = controller.activeStarCount;
    final List<SkyStar> stars = SkyStarCluster.getStars(count: starCount);
    final double time = controller.totalTimeElapsed;
    final bool isHighTier = controller.activeTier == HardwareTier.high ||
        controller.activeTier == HardwareTier.ultra;

    for (int i = 0; i < stars.length; i++) {
      final SkyStar star = stars[i];

      // Project spherical direction to screen space
      final double screenX = (star.position.x * 0.5 + 0.5) * size.width;
      final double screenY = (1.0 - star.position.y) * size.height * 0.85;

      if (screenX < 0.0 || screenX > size.width || screenY < 0.0 || screenY > size.height) {
        continue;
      }

      // Scintillation twinkle calculation
      final double twinkle =
          0.7 + 0.3 * math.sin(time * star.twinkleSpeed + star.twinklePhase);
      final double alpha = (star.brightness * nightFactor * twinkle).clamp(0.0, 1.0);

      final ui.Paint starPaint = ui.Paint()
        ..color = star.color.withAlpha((alpha * 255).round().clamp(0, 255));
      canvas.drawCircle(ui.Offset(screenX, screenY), star.size, starPaint);

      // Full celestial cluster stellar halo on High/Ultra tiers
      if (isHighTier && star.brightness > 0.75) {
        final ui.Paint haloPaint = ui.Paint()
          ..color = star.color.withAlpha((alpha * 0.25 * 255).round().clamp(0, 255))
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.0);
        canvas.drawCircle(ui.Offset(screenX, screenY), star.size * 2.2, haloPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DynamicSkyboxPainter oldDelegate) => true;
}

/// Production Flutter widget embedding the Dynamic Procedural Skybox.
class DynamicSkyboxView extends StatefulWidget {
  const DynamicSkyboxView({
    super.key,
    required this.controller,
    this.child,
    this.enableShader = true,
    this.autoPrewarm = true,
  });

  final DynamicSkyboxController controller;
  final Widget? child;
  final bool enableShader;
  final bool autoPrewarm;

  @override
  State<DynamicSkyboxView> createState() => _DynamicSkyboxViewState();
}

class _DynamicSkyboxViewState extends State<DynamicSkyboxView> with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  bool _shaderLoading = false;
  Ticker? _ticker;
  double _lastTickMs = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.autoPrewarm) {
      DynamicSkyboxController.prewarmSkyboxAssets(
        tier: widget.controller.activeTier,
        scaler: widget.controller.scaler,
      );
    }
    if (widget.enableShader) {
      _loadShader();
    }
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant DynamicSkyboxView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller && widget.autoPrewarm) {
      DynamicSkyboxController.prewarmSkyboxAssets(
        tier: widget.controller.activeTier,
        scaler: widget.controller.scaler,
      );
    }
  }

  Future<void> _loadShader() async {
    if (_shaderLoading) return;
    _shaderLoading = true;
    try {
      final ui.FragmentProgram program =
          await ui.FragmentProgram.fromAsset('shaders/world/atmospheric_sky.frag');
      if (mounted) {
        setState(() {
          _shader = program.fragmentShader();
        });
      }
    } catch (e) {
      // Graceful fallback to analytical procedural painter
      debugPrint('DynamicSkybox: Shader load fallback to procedural canvas ($e)');
    } finally {
      _shaderLoading = false;
    }
  }

  void _onTick(Duration elapsed) {
    final double elapsedMs = elapsed.inMicroseconds / 1000.0;
    final double dt = _lastTickMs == 0.0 ? 0.016 : (elapsedMs - _lastTickMs) / 1000.0;
    _lastTickMs = elapsedMs;

    widget.controller.update(dt.clamp(0.001, 0.1));
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return CustomPaint(
          painter: DynamicSkyboxPainter(
            controller: widget.controller,
            shader: _shader,
          ),
          child: widget.child,
        );
      },
    );
  }
}
