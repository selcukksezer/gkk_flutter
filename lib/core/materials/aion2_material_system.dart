import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/widgets.dart';

// =============================================================================
// Master Aion 2 PBR Material System
// High-Fantasy AAA Cinematic Standard (Aion 2 Visual Standard)
//
// Core Modules:
// 1. Vector3D & Mathematical Utilities
// 2. Aion2RuneModulationType & Aion2PbrParameters (Data Model + Serialization)
// 3. Aion2MaterialPresets (DragonScale, WingEthereal, GothicDarkStone, PolishedPlateArmor)
// 4. Aion2BrdfEvaluator (Analytical CPU Cook-Torrance BRDF, SSS & Iridescence Physics)
// 5. Aion2MaterialUniformPacker (Exact GLSL 54-float Uniform Buffer Alignment)
// 6. Aion2MaterialController (State, Animation & Shader Binding)
// 7. Aion2ShaderWarmup (Shader Program Pre-warming & Cache Manager)
// 8. Aion2MaterialPreviewPainter & Aion2MaterialPreviewWidget (Production UI Layer)
// =============================================================================

/// 3D Vector for world, view, normal, and light calculations in PBR space.
class Vector3D {
  const Vector3D(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  static const Vector3D zero = Vector3D(0.0, 0.0, 0.0);
  static const Vector3D unitX = Vector3D(1.0, 0.0, 0.0);
  static const Vector3D unitY = Vector3D(0.0, 1.0, 0.0);
  static const Vector3D unitZ = Vector3D(0.0, 0.0, 1.0);

  double get lengthSquared => x * x + y * y + z * z;
  double get length => math.sqrt(lengthSquared);

  Vector3D normalized() {
    final double l = length;
    if (l < 1e-7) return unitZ;
    return Vector3D(x / l, y / l, z / l);
  }

  double dot(Vector3D other) => x * other.x + y * other.y + z * other.z;

  Vector3D cross(Vector3D other) {
    return Vector3D(
      y * other.z - z * other.y,
      z * other.x - x * other.z,
      x * other.y - y * other.x,
    );
  }

  Vector3D operator +(Vector3D o) => Vector3D(x + o.x, y + o.y, z + o.z);
  Vector3D operator -(Vector3D o) => Vector3D(x - o.x, y - o.y, z - o.z);
  Vector3D operator *(double scalar) => Vector3D(x * scalar, y * scalar, z * scalar);
  Vector3D operator /(double scalar) => Vector3D(x / scalar, y / scalar, z / scalar);
  Vector3D operator -() => Vector3D(-x, -y, -z);

  Vector3D componentMultiply(Vector3D o) => Vector3D(x * o.x, y * o.y, z * o.z);

  Vector3D clamped(double minVal, double maxVal) {
    return Vector3D(
      x.clamp(minVal, maxVal),
      y.clamp(minVal, maxVal),
      z.clamp(minVal, maxVal),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vector3D &&
          runtimeType == other.runtimeType &&
          (x - other.x).abs() < 1e-5 &&
          (y - other.y).abs() < 1e-5 &&
          (z - other.z).abs() < 1e-5;

  @override
  int get hashCode => Object.hash(
        (x * 1000).round(),
        (y * 1000).round(),
        (z * 1000).round(),
      );

  @override
  String toString() => 'Vector3D(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

/// Type of temporal modulation applied to emissive runes on fantasy gear.
enum Aion2RuneModulationType {
  /// Continuous smooth sine wave breathing.
  sineBreathing(0.0),

  /// Aion 2 signature ancient draconic heartbeat pattern.
  heartbeatDualPulse(1.0),

  /// Arcane multi-harmonic ethereal superposition shimmer.
  arcaneHarmonic(2.0),

  /// Rapid high-intensity flare and power surge overload.
  overloadSurge(3.0);

  const Aion2RuneModulationType(this.shaderValue);
  final double shaderValue;

  static Aion2RuneModulationType fromShaderValue(double value) {
    final int index = value.round().clamp(0, 3);
    return Aion2RuneModulationType.values[index];
  }
}

/// Complete parameter specification for the Master Aion 2 PBR Material.
@immutable
class Aion2PbrParameters {
  const Aion2PbrParameters({
    this.name = 'CustomPbrMaterial',
    this.baseColor = const ui.Color(0xFFCCCCCC),
    this.metallic = 0.0,
    this.roughness = 0.5,
    this.ao = 1.0,
    this.normalIntensity = 1.0,
    this.clearcoat = 0.0,
    this.clearcoatRoughness = 0.1,
    // Subsurface Scattering (SSS)
    this.sssEnabled = false,
    this.sssWeight = 0.0,
    this.sssDistortion = 0.4,
    this.sssPower = 3.0,
    this.sssScale = 1.5,
    this.sssColor = const ui.Color(0xFF44EEFF),
    this.sssExtinction = 0.25,
    // Thin-film Iridescence
    this.iridescenceEnabled = false,
    this.iridescenceWeight = 0.0,
    this.filmThicknessNm = 450.0,
    this.filmIOR = 1.5,
    this.baseIOR = 1.4,
    this.iridescenceTint = const ui.Color(0xFFFFFFFF),
    this.angleShift = 1.0,
    // Emissive Rune Modulation
    this.emissiveColor = const ui.Color(0xFF00FFCC),
    this.emissiveIntensity = 0.0,
    this.runeSpeed = 1.0,
    this.runeFrequency = 1.0,
    this.runeDutyCycle = 2.0,
    this.runeModulationType = Aion2RuneModulationType.sineBreathing,
    // Mapping & UV
    this.tilingX = 1.0,
    this.tilingY = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
  });

  final String name;

  // Core PBR
  final ui.Color baseColor;
  final double metallic;
  final double roughness;
  final double ao;
  final double normalIntensity;
  final double clearcoat;
  final double clearcoatRoughness;

  // SSS
  final bool sssEnabled;
  final double sssWeight;
  final double sssDistortion;
  final double sssPower;
  final double sssScale;
  final ui.Color sssColor;
  final double sssExtinction;

  // Thin-Film Iridescence
  final bool iridescenceEnabled;
  final double iridescenceWeight;
  final double filmThicknessNm;
  final double filmIOR;
  final double baseIOR;
  final ui.Color iridescenceTint;
  final double angleShift;

  // Emissive Runes
  final ui.Color emissiveColor;
  final double emissiveIntensity;
  final double runeSpeed;
  final double runeFrequency;
  final double runeDutyCycle;
  final Aion2RuneModulationType runeModulationType;

  // UV Transform
  final double tilingX;
  final double tilingY;
  final double offsetX;
  final double offsetY;

  Aion2PbrParameters copyWith({
    String? name,
    ui.Color? baseColor,
    double? metallic,
    double? roughness,
    double? ao,
    double? normalIntensity,
    double? clearcoat,
    double? clearcoatRoughness,
    bool? sssEnabled,
    double? sssWeight,
    double? sssDistortion,
    double? sssPower,
    double? sssScale,
    ui.Color? sssColor,
    double? sssExtinction,
    bool? iridescenceEnabled,
    double? iridescenceWeight,
    double? filmThicknessNm,
    double? filmIOR,
    double? baseIOR,
    ui.Color? iridescenceTint,
    double? angleShift,
    ui.Color? emissiveColor,
    double? emissiveIntensity,
    double? runeSpeed,
    double? runeFrequency,
    double? runeDutyCycle,
    Aion2RuneModulationType? runeModulationType,
    double? tilingX,
    double? tilingY,
    double? offsetX,
    double? offsetY,
  }) {
    return Aion2PbrParameters(
      name: name ?? this.name,
      baseColor: baseColor ?? this.baseColor,
      metallic: (metallic ?? this.metallic).clamp(0.0, 1.0),
      roughness: (roughness ?? this.roughness).clamp(0.04, 1.0),
      ao: (ao ?? this.ao).clamp(0.0, 1.0),
      normalIntensity: (normalIntensity ?? this.normalIntensity).clamp(0.0, 4.0),
      clearcoat: (clearcoat ?? this.clearcoat).clamp(0.0, 1.0),
      clearcoatRoughness: (clearcoatRoughness ?? this.clearcoatRoughness).clamp(0.01, 1.0),
      sssEnabled: sssEnabled ?? this.sssEnabled,
      sssWeight: (sssWeight ?? this.sssWeight).clamp(0.0, 1.0),
      sssDistortion: (sssDistortion ?? this.sssDistortion).clamp(0.0, 2.0),
      sssPower: (sssPower ?? this.sssPower).clamp(0.1, 16.0),
      sssScale: (sssScale ?? this.sssScale).clamp(0.0, 10.0),
      sssColor: sssColor ?? this.sssColor,
      sssExtinction: (sssExtinction ?? this.sssExtinction).clamp(0.0, 10.0),
      iridescenceEnabled: iridescenceEnabled ?? this.iridescenceEnabled,
      iridescenceWeight: (iridescenceWeight ?? this.iridescenceWeight).clamp(0.0, 1.0),
      filmThicknessNm: (filmThicknessNm ?? this.filmThicknessNm).clamp(50.0, 2000.0),
      filmIOR: (filmIOR ?? this.filmIOR).clamp(1.0, 3.5),
      baseIOR: (baseIOR ?? this.baseIOR).clamp(1.0, 3.5),
      iridescenceTint: iridescenceTint ?? this.iridescenceTint,
      angleShift: (angleShift ?? this.angleShift).clamp(0.0, 5.0),
      emissiveColor: emissiveColor ?? this.emissiveColor,
      emissiveIntensity: (emissiveIntensity ?? this.emissiveIntensity).clamp(0.0, 32.0),
      runeSpeed: runeSpeed ?? this.runeSpeed,
      runeFrequency: runeFrequency ?? this.runeFrequency,
      runeDutyCycle: (runeDutyCycle ?? this.runeDutyCycle).clamp(0.1, 10.0),
      runeModulationType: runeModulationType ?? this.runeModulationType,
      tilingX: tilingX ?? this.tilingX,
      tilingY: tilingY ?? this.tilingY,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'baseColor': baseColor.toARGB32(),
      'metallic': metallic,
      'roughness': roughness,
      'ao': ao,
      'normalIntensity': normalIntensity,
      'clearcoat': clearcoat,
      'clearcoatRoughness': clearcoatRoughness,
      'sssEnabled': sssEnabled,
      'sssWeight': sssWeight,
      'sssDistortion': sssDistortion,
      'sssPower': sssPower,
      'sssScale': sssScale,
      'sssColor': sssColor.toARGB32(),
      'sssExtinction': sssExtinction,
      'iridescenceEnabled': iridescenceEnabled,
      'iridescenceWeight': iridescenceWeight,
      'filmThicknessNm': filmThicknessNm,
      'filmIOR': filmIOR,
      'baseIOR': baseIOR,
      'iridescenceTint': iridescenceTint.toARGB32(),
      'angleShift': angleShift,
      'emissiveColor': emissiveColor.toARGB32(),
      'emissiveIntensity': emissiveIntensity,
      'runeSpeed': runeSpeed,
      'runeFrequency': runeFrequency,
      'runeDutyCycle': runeDutyCycle,
      'runeModulationType': runeModulationType.name,
      'tilingX': tilingX,
      'tilingY': tilingY,
      'offsetX': offsetX,
      'offsetY': offsetY,
    };
  }

  factory Aion2PbrParameters.fromJson(Map<String, dynamic> json) {
    Aion2RuneModulationType modType = Aion2RuneModulationType.sineBreathing;
    if (json.containsKey('runeModulationType')) {
      final String rawMod = json['runeModulationType'].toString();
      for (final Aion2RuneModulationType t in Aion2RuneModulationType.values) {
        if (t.name == rawMod) {
          modType = t;
          break;
        }
      }
    }

    return Aion2PbrParameters(
      name: json['name'] as String? ?? 'CustomPbrMaterial',
      baseColor: ui.Color((json['baseColor'] as num?)?.toInt() ?? 0xFFCCCCCC),
      metallic: (json['metallic'] as num?)?.toDouble() ?? 0.0,
      roughness: (json['roughness'] as num?)?.toDouble() ?? 0.5,
      ao: (json['ao'] as num?)?.toDouble() ?? 1.0,
      normalIntensity: (json['normalIntensity'] as num?)?.toDouble() ?? 1.0,
      clearcoat: (json['clearcoat'] as num?)?.toDouble() ?? 0.0,
      clearcoatRoughness: (json['clearcoatRoughness'] as num?)?.toDouble() ?? 0.1,
      sssEnabled: json['sssEnabled'] as bool? ?? false,
      sssWeight: (json['sssWeight'] as num?)?.toDouble() ?? 0.0,
      sssDistortion: (json['sssDistortion'] as num?)?.toDouble() ?? 0.4,
      sssPower: (json['sssPower'] as num?)?.toDouble() ?? 3.0,
      sssScale: (json['sssScale'] as num?)?.toDouble() ?? 1.5,
      sssColor: ui.Color((json['sssColor'] as num?)?.toInt() ?? 0xFF44EEFF),
      sssExtinction: (json['sssExtinction'] as num?)?.toDouble() ?? 0.25,
      iridescenceEnabled: json['iridescenceEnabled'] as bool? ?? false,
      iridescenceWeight: (json['iridescenceWeight'] as num?)?.toDouble() ?? 0.0,
      filmThicknessNm: (json['filmThicknessNm'] as num?)?.toDouble() ?? 450.0,
      filmIOR: (json['filmIOR'] as num?)?.toDouble() ?? 1.5,
      baseIOR: (json['baseIOR'] as num?)?.toDouble() ?? 1.4,
      iridescenceTint: ui.Color((json['iridescenceTint'] as num?)?.toInt() ?? 0xFFFFFFFF),
      angleShift: (json['angleShift'] as num?)?.toDouble() ?? 1.0,
      emissiveColor: ui.Color((json['emissiveColor'] as num?)?.toInt() ?? 0xFF00FFCC),
      emissiveIntensity: (json['emissiveIntensity'] as num?)?.toDouble() ?? 0.0,
      runeSpeed: (json['runeSpeed'] as num?)?.toDouble() ?? 1.0,
      runeFrequency: (json['runeFrequency'] as num?)?.toDouble() ?? 1.0,
      runeDutyCycle: (json['runeDutyCycle'] as num?)?.toDouble() ?? 2.0,
      runeModulationType: modType,
      tilingX: (json['tilingX'] as num?)?.toDouble() ?? 1.0,
      tilingY: (json['tilingY'] as num?)?.toDouble() ?? 1.0,
      offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0.0,
      offsetY: (json['offsetY'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Aion2PbrParameters &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          baseColor == other.baseColor &&
          (metallic - other.metallic).abs() < 1e-4 &&
          (roughness - other.roughness).abs() < 1e-4 &&
          (ao - other.ao).abs() < 1e-4 &&
          (clearcoat - other.clearcoat).abs() < 1e-4 &&
          sssEnabled == other.sssEnabled &&
          (sssWeight - other.sssWeight).abs() < 1e-4 &&
          iridescenceEnabled == other.iridescenceEnabled &&
          (iridescenceWeight - other.iridescenceWeight).abs() < 1e-4 &&
          (emissiveIntensity - other.emissiveIntensity).abs() < 1e-4 &&
          runeModulationType == other.runeModulationType;

  @override
  int get hashCode => Object.hash(
        name,
        baseColor,
        metallic,
        roughness,
        ao,
        clearcoat,
        sssEnabled,
        sssWeight,
        iridescenceEnabled,
        iridescenceWeight,
        emissiveIntensity,
        runeModulationType,
      );
}

/// Official AAA Material Presets for Aion 2 Visual Standard.
class Aion2MaterialPresets {
  Aion2MaterialPresets._();

  /// Preset 1: Ancient Dragon Scale
  ///
  /// Deep iridescent emerald and violet scales with optical thin-film interference.
  /// Characteristic of high-level draconic bosses and crafted Wyrmscale armor.
  static const Aion2PbrParameters dragonScale = Aion2PbrParameters(
    name: 'DragonScale',
    baseColor: ui.Color(0xFF0F3D2E), // Deep draconic emerald
    metallic: 0.78,
    roughness: 0.22,
    ao: 1.0,
    normalIntensity: 1.4,
    clearcoat: 0.65,
    clearcoatRoughness: 0.12,
    // SSS (subtle membrane scatter)
    sssEnabled: true,
    sssWeight: 0.25,
    sssDistortion: 0.35,
    sssPower: 3.5,
    sssScale: 1.2,
    sssColor: ui.Color(0xFF22FF88),
    sssExtinction: 0.6,
    // Thin-film Iridescence (High priority for dragon scales)
    iridescenceEnabled: true,
    iridescenceWeight: 0.90,
    filmThicknessNm: 490.0, // Optical interference creates vivid violet-emerald rainbow
    filmIOR: 1.62,
    baseIOR: 1.45,
    iridescenceTint: ui.Color(0xFFCC88FF),
    angleShift: 1.35,
    // Emissive Rune Pulse
    emissiveColor: ui.Color(0xFF33FFBB),
    emissiveIntensity: 1.8,
    runeSpeed: 0.75,
    runeFrequency: 1.0,
    runeDutyCycle: 2.5,
    runeModulationType: Aion2RuneModulationType.heartbeatDualPulse,
  );

  /// Preset 2: Ethereal Glowing Wings
  ///
  /// Translucent Elyos / Asmodian signature luminous wings.
  /// High subsurface scattering (SSS) transmission with celestial cyan/gold radiance.
  static const Aion2PbrParameters wingEthereal = Aion2PbrParameters(
    name: 'WingEthereal',
    baseColor: ui.Color(0xFFF2F8FF), // Luminous celestial white/ivory
    metallic: 0.04,
    roughness: 0.38,
    ao: 0.85,
    normalIntensity: 0.8,
    clearcoat: 0.20,
    clearcoatRoughness: 0.25,
    // SSS: Extreme transmission for translucent feathered or energy wings
    sssEnabled: true,
    sssWeight: 0.96,
    sssDistortion: 0.55,
    sssPower: 4.5,
    sssScale: 2.8,
    sssColor: ui.Color(0xFF33EEFF), // Ethereal celestial cyan backlight glow
    sssExtinction: 0.15,
    // Iridescence (Soft mother-of-pearl sheen)
    iridescenceEnabled: true,
    iridescenceWeight: 0.40,
    filmThicknessNm: 360.0,
    filmIOR: 1.38,
    baseIOR: 1.33,
    iridescenceTint: ui.Color(0xFFFFEEAA), // Subtle golden sheen
    angleShift: 0.9,
    // Emissive Rune Pulse
    emissiveColor: ui.Color(0xFF55FFFF),
    emissiveIntensity: 2.4,
    runeSpeed: 1.2,
    runeFrequency: 0.85,
    runeDutyCycle: 1.8,
    runeModulationType: Aion2RuneModulationType.arcaneHarmonic,
  );

  /// Preset 3: Gothic Dark Stone
  ///
  /// Ancient abyssal sanctuary & dungeon citadel carved stone.
  /// High microfacet roughness, deep ambient occlusion, with ancient carved
  /// abyssal crimson runes breathing from the rock crevices.
  static const Aion2PbrParameters gothicDarkStone = Aion2PbrParameters(
    name: 'GothicDarkStone',
    baseColor: ui.Color(0xFF26272B), // Weathered dark basalt / obsidian
    metallic: 0.02,
    roughness: 0.86,
    ao: 0.95,
    normalIntensity: 1.6,
    clearcoat: 0.0,
    clearcoatRoughness: 0.5,
    // SSS: None for solid opaque stone
    sssEnabled: false,
    sssWeight: 0.0,
    sssDistortion: 0.0,
    sssPower: 1.0,
    sssScale: 0.0,
    sssColor: ui.Color(0xFF000000),
    sssExtinction: 1.0,
    // Iridescence: None for matte stone
    iridescenceEnabled: false,
    iridescenceWeight: 0.0,
    filmThicknessNm: 0.0,
    filmIOR: 1.0,
    baseIOR: 1.5,
    iridescenceTint: ui.Color(0xFFFFFFFF),
    angleShift: 0.0,
    // Emissive Rune Pulse: Glowing abyssal blood-red runes in stone carvings
    emissiveColor: ui.Color(0xFFFF1A35),
    emissiveIntensity: 3.2,
    runeSpeed: 0.45,
    runeFrequency: 0.5,
    runeDutyCycle: 3.0,
    runeModulationType: Aion2RuneModulationType.sineBreathing,
  );

  /// Preset 4: Polished Plate Armor
  ///
  /// Mirrored sanctified plate armor worn by high-rank templars and abyss lords.
  /// Ultra-low roughness, near-total metallic specular reflectance, mirror clearcoat,
  /// and faint thin-film heat-treatment iridescent fringe.
  static const Aion2PbrParameters polishedPlateArmor = Aion2PbrParameters(
    name: 'PolishedPlateArmor',
    baseColor: ui.Color(0xFFE8ECF5), // Chrome-silver polished steel
    metallic: 0.95,
    roughness: 0.12,
    ao: 1.0,
    normalIntensity: 1.0,
    clearcoat: 0.85,
    clearcoatRoughness: 0.06,
    // SSS: None for solid metal
    sssEnabled: false,
    sssWeight: 0.0,
    sssDistortion: 0.0,
    sssPower: 1.0,
    sssScale: 0.0,
    sssColor: ui.Color(0xFF000000),
    sssExtinction: 1.0,
    // Iridescence: Heat-treated tempered steel prismatic sheen
    iridescenceEnabled: true,
    iridescenceWeight: 0.45,
    filmThicknessNm: 530.0,
    filmIOR: 1.70,
    baseIOR: 2.10,
    iridescenceTint: ui.Color(0xFFFFDD99),
    angleShift: 1.5,
    // Emissive Rune Pulse: Consecrated golden etched runes
    emissiveColor: ui.Color(0xFFFFDF33),
    emissiveIntensity: 2.0,
    runeSpeed: 1.0,
    runeFrequency: 1.2,
    runeDutyCycle: 2.0,
    runeModulationType: Aion2RuneModulationType.sineBreathing,
  );

  /// List of all canonical Aion 2 presets.
  static const List<Aion2PbrParameters> all = <Aion2PbrParameters>[
    dragonScale,
    wingEthereal,
    gothicDarkStone,
    polishedPlateArmor,
  ];
}

/// Analytical CPU PBR BRDF & Optical Physics Evaluator.
///
/// Implements identical mathematical formulations to `aion2_pbr_master.frag`.
/// Used for:
/// - Exact math validation in unit tests
/// - Headless fallback rendering
/// - Pre-baking lighting or offline validation
class Aion2BrdfEvaluator {
  Aion2BrdfEvaluator._();

  static const double pi = math.pi;
  static const double invPi = 1.0 / math.pi;
  static const Vector3D dielectricF0 = Vector3D(0.04, 0.04, 0.04);

  /// Evaluates GGX / Trowbridge-Reitz normal distribution function D.
  static double distributionGGX(Vector3D n, Vector3D h, double roughness) {
    final double a = roughness * roughness;
    final double a2 = a * a;
    final double nDotH = math.max(n.dot(h), 0.0);
    final double nDotH2 = nDotH * nDotH;

    final double denom = nDotH2 * (a2 - 1.0) + 1.0;
    final double denom2 = pi * denom * denom;

    return a2 / math.max(denom2, 1e-6);
  }

  /// Evaluates Schlick-GGX geometric shadowing / masking component.
  static double geometrySchlickGGX(double nDotX, double roughness) {
    final double r = roughness + 1.0;
    final double k = (r * r) / 8.0;

    final double denom = nDotX * (1.0 - k) + k;
    return nDotX / math.max(denom, 1e-6);
  }

  /// Evaluates Smith combined geometric shadowing and masking function G.
  static double geometrySmith(Vector3D n, Vector3D v, Vector3D l, double roughness) {
    final double nDotV = math.max(n.dot(v), 0.0001);
    final double nDotL = math.max(n.dot(l), 0.0);
    final double ggx1 = geometrySchlickGGX(nDotV, roughness);
    final double ggx2 = geometrySchlickGGX(nDotL, roughness);

    return ggx1 * ggx2;
  }

  /// Evaluates Schlick Fresnel reflectance F.
  static Vector3D fresnelSchlick(double cosTheta, Vector3D f0) {
    final double factor = math.pow((1.0 - cosTheta).clamp(0.0, 1.0), 5.0).toDouble();
    return f0 + (const Vector3D(1.0, 1.0, 1.0) - f0) * factor;
  }

  /// Evaluates thin-film optical interference across spectral wavelengths (Red 650nm, Green 532nm, Blue 440nm).
  static Vector3D evaluateThinFilmIridescence({
    required double cosTheta,
    required double thicknessNm,
    required double filmIOR,
    required double baseIOR,
    double angleShift = 1.0,
    Vector3D tint = const Vector3D(1.0, 1.0, 1.0),
  }) {
    final double sinThetaI = math.sqrt(math.max(0.0, 1.0 - cosTheta * cosTheta));
    final double sinThetaT = sinThetaI / math.max(filmIOR, 1.001);
    final double cosThetaT = math.sqrt(math.max(0.0, 1.0 - sinThetaT * sinThetaT));

    // Optical Path Difference: OPD = 2 * n1 * d * cos(theta_t)
    final double opd = 2.0 * filmIOR * thicknessNm * cosThetaT * (1.0 + angleShift * (1.0 - cosTheta));

    // Visible spectral bands in nm
    const double waveR = 650.0;
    const double waveG = 532.0;
    const double waveB = 440.0;

    double phaseR = (2.0 * pi * opd) / waveR;
    double phaseG = (2.0 * pi * opd) / waveG;
    double phaseB = (2.0 * pi * opd) / waveB;

    // Phase inversion check
    final double r01 = (1.0 - filmIOR) / (1.0 + filmIOR);
    final double r12 = (filmIOR - baseIOR) / (filmIOR + baseIOR);
    if (r01 * r12 < 0.0) {
      phaseR += pi;
      phaseG += pi;
      phaseB += pi;
    }

    final double intR = (0.5 + 0.5 * math.cos(phaseR)).clamp(0.0, 1.0);
    final double intG = (0.5 + 0.5 * math.cos(phaseG)).clamp(0.0, 1.0);
    final double intB = (0.5 + 0.5 * math.cos(phaseB)).clamp(0.0, 1.0);

    return Vector3D(intR * tint.x, intG * tint.y, intB * tint.z).clamped(0.0, 1.0);
  }

  /// Evaluates subsurface scattering (SSS) transmission through thin/translucent geometry.
  static Vector3D evaluateSubsurfaceScattering({
    required Vector3D n,
    required Vector3D v,
    required Vector3D l,
    required Vector3D lightRadiance,
    required double weight,
    required double distortion,
    required double power,
    required double scale,
    required Vector3D sssColor,
    required double extinction,
  }) {
    if (weight <= 0.001) {
      return Vector3D.zero;
    }

    final Vector3D sssL = (l + n * distortion).normalized();
    final double inScatter = (-sssL.dot(v)).clamp(0.0, 1.0);
    final double sssIntensity = math.pow(inScatter, power) * scale;
    final double extFactor = math.exp(-extinction);

    return sssColor.componentMultiply(lightRadiance) * (sssIntensity * extFactor * weight);
  }

  /// Evaluates temporal modulation curves for pulsating runic armor.
  static double evaluateRunePulsation({
    required double timeSeconds,
    required double speed,
    required double freq,
    required double dutyCycle,
    required Aion2RuneModulationType modType,
  }) {
    final double t = timeSeconds * speed;
    final double duty = dutyCycle.clamp(0.1, 8.0);

    switch (modType) {
      case Aion2RuneModulationType.sineBreathing:
        final double s = math.sin(t * freq * 2.0 * pi) * 0.5 + 0.5;
        return math.pow(s, duty).toDouble();

      case Aion2RuneModulationType.heartbeatDualPulse:
        final double cycle = (t * freq) - (t * freq).floor();
        double p1 = 0.0;
        if (cycle >= 0.0 && cycle < 0.22) {
          if (cycle < 0.08) {
            p1 = cycle / 0.08;
          } else {
            p1 = 1.0 - (cycle - 0.08) / (0.22 - 0.08);
          }
        }
        double p2 = 0.0;
        if (cycle >= 0.25 && cycle < 0.48) {
          if (cycle < 0.33) {
            p2 = (cycle - 0.25) / (0.33 - 0.25);
          } else {
            p2 = 1.0 - (cycle - 0.33) / (0.48 - 0.33);
          }
        }
        final double combined = (p1 * 1.0 + p2 * 0.6).clamp(0.0, 1.0);
        return math.pow(combined, duty).toDouble();

      case Aion2RuneModulationType.arcaneHarmonic:
        final double h1 = math.sin(t * freq * 1.0 * 2.0 * pi);
        final double h2 = math.sin(t * freq * 2.37 * 2.0 * pi) * 0.5;
        final double h3 = math.sin(t * freq * 4.81 * 2.0 * pi) * 0.25;
        final double combined = (((h1 + h2 + h3) / 1.75) * 0.5 + 0.5).clamp(0.0, 1.0);
        return math.pow(combined, duty).toDouble();

      case Aion2RuneModulationType.overloadSurge:
        final double fastFlicker = ((math.sin((t * 24.0).floor() * 43758.5453) * 10000.0) % 1.0).abs();
        final double surge = math.sin(t * freq * 2.0 * pi) * 0.5 + 0.5;
        return (math.pow(surge, duty) * (0.8 + 0.2 * fastFlicker)).clamp(0.0, 1.0);
    }
  }

  /// Evaluates full PBR radiance matching the shader pipeline.
  static Vector3D evaluateCompletePbr({
    required Vector3D n,
    required Vector3D v,
    required Vector3D l,
    required Aion2PbrParameters params,
    required Vector3D lightColor,
    required double lightIntensity,
    required Vector3D ambientLight,
    double timeSeconds = 0.0,
  }) {
    final Vector3D h = (v + l).normalized();
    final double nDotL = math.max(n.dot(l), 0.0);
    final double nDotV = math.max(n.dot(v), 0.0001);
    final double vDotH = math.max(v.dot(h), 0.0);

    final Vector3D albedo = Aion2MaterialUniformPacker.colorToVector3D(params.baseColor);
    final double roughness = params.roughness.clamp(0.04, 1.0);
    final double metallic = params.metallic.clamp(0.0, 1.0);

    Vector3D f0 = dielectricF0 * (1.0 - metallic) + albedo * metallic;

    // Thin-film Iridescence
    if (params.iridescenceEnabled && params.iridescenceWeight > 0.001) {
      final Vector3D iridColor = evaluateThinFilmIridescence(
        cosTheta: nDotV,
        thicknessNm: params.filmThicknessNm,
        filmIOR: params.filmIOR,
        baseIOR: params.baseIOR,
        angleShift: params.angleShift,
        tint: Aion2MaterialUniformPacker.colorToVector3D(params.iridescenceTint),
      );
      f0 = f0 * (1.0 - params.iridescenceWeight) + iridColor * params.iridescenceWeight;
    }

    final double d = distributionGGX(n, h, roughness);
    final double g = geometrySmith(n, v, l, roughness);
    final Vector3D f = fresnelSchlick(vDotH, f0);

    final Vector3D specularNumerator = f * (d * g);
    final double specularDenominator = 4.0 * nDotV * nDotL + 0.0001;
    final Vector3D specular = specularNumerator / specularDenominator;

    final Vector3D kS = f;
    final Vector3D kD = (const Vector3D(1.0, 1.0, 1.0) - kS) * (1.0 - metallic);
    final Vector3D diffuse = kD.componentMultiply(albedo) * invPi;

    // Clearcoat
    Vector3D clearcoatSpecular = Vector3D.zero;
    if (params.clearcoat > 0.001) {
      final double dc = distributionGGX(n, h, params.clearcoatRoughness);
      final double gc = geometrySmith(n, v, l, params.clearcoatRoughness);
      final Vector3D fc = fresnelSchlick(vDotH, dielectricF0);
      clearcoatSpecular = (fc * (dc * gc)) / (4.0 * nDotV * nDotL + 0.0001) * params.clearcoat;
    }

    final Vector3D lightRadiance = lightColor * lightIntensity;
    final Vector3D directLighting = (diffuse + specular + clearcoatSpecular).componentMultiply(lightRadiance) * nDotL;

    // SSS
    Vector3D sss = Vector3D.zero;
    if (params.sssEnabled && params.sssWeight > 0.001) {
      sss = evaluateSubsurfaceScattering(
        n: n,
        v: v,
        l: l,
        lightRadiance: lightRadiance,
        weight: params.sssWeight,
        distortion: params.sssDistortion,
        power: params.sssPower,
        scale: params.sssScale,
        sssColor: Aion2MaterialUniformPacker.colorToVector3D(params.sssColor),
        extinction: params.sssExtinction,
      );
    }

    // Ambient
    final Vector3D ambientFresnel = fresnelSchlick(nDotV, f0);
    final Vector3D ambientDiffuse = (const Vector3D(1.0, 1.0, 1.0) - ambientFresnel) * (1.0 - metallic);
    final Vector3D ambient = (ambientDiffuse.componentMultiply(albedo) + ambientFresnel * (1.0 - roughness * 0.5))
            .componentMultiply(ambientLight) *
        params.ao;

    // Emissive Rune
    Vector3D emissive = Vector3D.zero;
    if (params.emissiveIntensity > 0.001) {
      final double pulse = evaluateRunePulsation(
        timeSeconds: timeSeconds,
        speed: params.runeSpeed,
        freq: params.runeFrequency,
        dutyCycle: params.runeDutyCycle,
        modType: params.runeModulationType,
      );
      final Vector3D emColor = Aion2MaterialUniformPacker.colorToVector3D(params.emissiveColor);
      emissive = emColor * (params.emissiveIntensity * pulse);
    }

    return directLighting + sss + ambient + emissive;
  }
}

/// Packs material parameters into the exact 54-float uniform buffer required by
/// `shaders/materials/aion2_pbr_master.frag`.
class Aion2MaterialUniformPacker {
  Aion2MaterialUniformPacker._();

  /// Total number of float uniforms declared in the master shader.
  static const int totalFloatCount = 54;

  /// Converts an sRGB Flutter [ui.Color] to linear RGB components.
  static (double, double, double) colorToLinearRgb(ui.Color color) {
    double toLinear(double c) {
      return (c <= 0.04045) ? (c / 12.92) : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    return (
      toLinear(color.r),
      toLinear(color.g),
      toLinear(color.b),
    );
  }

  /// Converts a [ui.Color] to a linear [Vector3D].
  static Vector3D colorToVector3D(ui.Color color) {
    final (double r, double g, double b) = colorToLinearRgb(color);
    return Vector3D(r, g, b);
  }

  /// Builds a [List<double>] containing exactly 54 floats in GLSL uniform declaration order.
  static List<double> buildUniformList({
    required ui.Size viewportSize,
    required double timeSeconds,
    required Vector3D cameraPos,
    required Vector3D lightPos,
    required ui.Color lightColor,
    required double lightIntensity,
    required ui.Color ambientLightColor,
    required Aion2PbrParameters params,
  }) {
    final (double lr, double lg, double lb) = colorToLinearRgb(lightColor);
    final (double ar, double ag, double ab) = colorToLinearRgb(ambientLightColor);
    final (double br, double bg, double bb) = colorToLinearRgb(params.baseColor);
    final (double sssr, double sssg, double sssb) = colorToLinearRgb(params.sssColor);
    final (double ir, double ig, double ib) = colorToLinearRgb(params.iridescenceTint);
    final (double er, double eg, double eb) = colorToLinearRgb(params.emissiveColor);

    return <double>[
      // 0..1: uResolution (vec2)
      viewportSize.width,
      viewportSize.height,

      // 2: uTime (float)
      timeSeconds,

      // 3..5: uCameraPos (vec3)
      cameraPos.x,
      cameraPos.y,
      cameraPos.z,

      // 6: uNormalIntensity (float)
      params.normalIntensity,

      // 7..9: uLightPos (vec3)
      lightPos.x,
      lightPos.y,
      lightPos.z,

      // 10..12: uLightColor (vec3)
      lr,
      lg,
      lb,

      // 13: uLightIntensity (float)
      lightIntensity,

      // 14..16: uAmbientLight (vec3)
      ar,
      ag,
      ab,

      // 17: uAOIntensity (float)
      params.ao,

      // 18..21: uBaseColor (vec4: RGBA)
      br,
      bg,
      bb,
      params.baseColor.a,

      // 22: uMetallic (float)
      params.metallic,

      // 23: uRoughness (float)
      params.roughness,

      // 24: uClearcoat (float)
      params.clearcoat,

      // 25: uClearcoatRoughness (float)
      params.clearcoatRoughness,

      // 26..29: uSSSParams (vec4: x=weight, y=distortion, z=power, w=scale)
      params.sssEnabled ? params.sssWeight : 0.0,
      params.sssDistortion,
      params.sssPower,
      params.sssScale,

      // 30..32: uSSSColor (vec3)
      sssr,
      sssg,
      sssb,

      // 33: uSSSExtinction (float)
      params.sssExtinction,

      // 34..37: uIridescenceParams (vec4: x=weight, y=filmThicknessNm, z=filmIOR, w=baseIOR)
      params.iridescenceEnabled ? params.iridescenceWeight : 0.0,
      params.filmThicknessNm,
      params.filmIOR,
      params.baseIOR,

      // 38..40: uIridescenceTint (vec3)
      ir,
      ig,
      ib,

      // 41: uIridescenceAngleShift (float)
      params.angleShift,

      // 42..45: uEmissiveColor (vec4: RGB + A peak intensity)
      er,
      eg,
      eb,
      params.emissiveIntensity,

      // 46..49: uEmissiveRuneParams (vec4: x=speed, y=frequency, z=dutyCycle, w=modType)
      params.runeSpeed,
      params.runeFrequency,
      params.runeDutyCycle,
      params.runeModulationType.shaderValue,

      // 50..51: uTiling (vec2)
      params.tilingX,
      params.tilingY,

      // 52..53: uOffset (vec2)
      params.offsetX,
      params.offsetY,
    ];
  }

  /// Packs uniforms into a [Float32List] buffer.
  static Float32List packToFloat32List({
    required ui.Size viewportSize,
    required double timeSeconds,
    required Vector3D cameraPos,
    required Vector3D lightPos,
    required ui.Color lightColor,
    required double lightIntensity,
    required ui.Color ambientLightColor,
    required Aion2PbrParameters params,
  }) {
    final List<double> uniforms = buildUniformList(
      viewportSize: viewportSize,
      timeSeconds: timeSeconds,
      cameraPos: cameraPos,
      lightPos: lightPos,
      lightColor: lightColor,
      lightIntensity: lightIntensity,
      ambientLightColor: ambientLightColor,
      params: params,
    );

    final Float32List buffer = Float32List(totalFloatCount);
    for (int i = 0; i < totalFloatCount; i++) {
      buffer[i] = uniforms[i];
    }
    return buffer;
  }
}

/// Manages active PBR material state, real-time animation, lighting, and GPU shader binding.
class Aion2MaterialController extends ChangeNotifier {
  Aion2MaterialController({
    Aion2PbrParameters? initialParameters,
    Vector3D? cameraPosition,
    Vector3D? lightPosition,
    ui.Color? lightColor,
    double? lightIntensity,
    ui.Color? ambientLightColor,
  })  : _params = initialParameters ?? Aion2MaterialPresets.dragonScale,
        _cameraPos = cameraPosition ?? const Vector3D(0.0, 0.0, 2.5),
        _lightPos = lightPosition ?? const Vector3D(1.5, 2.0, 3.0),
        _lightColor = lightColor ?? const ui.Color(0xFFFFF6EE),
        _lightIntensity = lightIntensity ?? 2.5,
        _ambientLightColor = ambientLightColor ?? const ui.Color(0xFF1E2230);

  Aion2PbrParameters _params;
  Vector3D _cameraPos;
  Vector3D _lightPos;
  ui.Color _lightColor;
  double _lightIntensity;
  ui.Color _ambientLightColor;

  double _elapsedTime = 0.0;
  bool _isAnimated = true;

  Aion2PbrParameters get params => _params;
  Vector3D get cameraPos => _cameraPos;
  Vector3D get lightPos => _lightPos;
  ui.Color get lightColor => _lightColor;
  double get lightIntensity => _lightIntensity;
  ui.Color get ambientLightColor => _ambientLightColor;
  double get elapsedTime => _elapsedTime;
  bool get isAnimated => _isAnimated;

  set isAnimated(bool val) {
    if (_isAnimated != val) {
      _isAnimated = val;
      notifyListeners();
    }
  }

  void updateParameters(Aion2PbrParameters newParams) {
    _params = newParams;
    notifyListeners();
  }

  void applyPreset(Aion2PbrParameters preset) {
    _params = preset;
    notifyListeners();
  }

  void setLighting({
    Vector3D? position,
    ui.Color? color,
    double? intensity,
    ui.Color? ambientColor,
  }) {
    if (position != null) _lightPos = position;
    if (color != null) _lightColor = color;
    if (intensity != null) _lightIntensity = intensity;
    if (ambientColor != null) _ambientLightColor = ambientColor;
    notifyListeners();
  }

  void setCameraPosition(Vector3D pos) {
    _cameraPos = pos;
    notifyListeners();
  }

  /// Advances simulation time by [dtSeconds].
  void advanceTime(double dtSeconds) {
    if (!_isAnimated) return;
    _elapsedTime += dtSeconds;
    notifyListeners();
  }

  /// Resets simulation time to 0.0.
  void resetTime() {
    _elapsedTime = 0.0;
    notifyListeners();
  }

  /// Packs uniforms and binds them to the given [ui.FragmentShader].
  ///
  /// Numeric Uniforms (Indices 0..53, total 54 floats):
  /// - 0..1:   uResolution (vec2)
  /// - 2:      uTime (float)
  /// - 3..5:   uCameraPos (vec3)
  /// - 6:      uNormalIntensity (float)
  /// - 7..9:   uLightPos (vec3)
  /// - 10..12: uLightColor (vec3)
  /// - 13:     uLightIntensity (float)
  /// - 14..16: uAmbientLight (vec3)
  /// - 17:     uAOIntensity (float)
  /// - 18..21: uBaseColor (vec4: RGBA)
  /// - 22:     uMetallic (float)
  /// - 23:     uRoughness (float)
  /// - 24:     uClearcoat (float)
  /// - 25:     uClearcoatRoughness (float)
  /// - 26..29: uSSSParams (vec4: weight, distortion, power, scale)
  /// - 30..32: uSSSColor (vec3)
  /// - 33:     uSSSExtinction (float)
  /// - 34..37: uIridescenceParams (vec4: weight, filmThicknessNm, filmIOR, baseIOR)
  /// - 38..40: uIridescenceTint (vec3)
  /// - 41:     uIridescenceAngleShift (float)
  /// - 42..45: uEmissiveColor (vec4: RGB + A peak intensity)
  /// - 46..49: uEmissiveRuneParams (vec4: speed, frequency, dutyCycle, modType)
  /// - 50..51: uTiling (vec2)
  /// - 52..53: uOffset (vec2)
  ///
  /// Sampler Uniforms (Sequential slots 0..3 matching Impeller declaration):
  /// - Slot 0: uAlbedoMap
  /// - Slot 1: uNormalMap
  /// - Slot 2: uMetallicRoughnessAOMap
  /// - Slot 3: uEmissiveRuneMap
  void bindToShader(
    ui.FragmentShader shader,
    ui.Size viewportSize, {
    ui.Image? albedoMap,
    ui.Image? normalMap,
    ui.Image? metallicRoughnessAOMap,
    ui.Image? emissiveRuneMap,
  }) {
    final List<double> uniforms = Aion2MaterialUniformPacker.buildUniformList(
      viewportSize: viewportSize,
      timeSeconds: _elapsedTime,
      cameraPos: _cameraPos,
      lightPos: _lightPos,
      lightColor: _lightColor,
      lightIntensity: _lightIntensity,
      ambientLightColor: _ambientLightColor,
      params: _params,
    );

    for (int i = 0; i < uniforms.length; i++) {
      shader.setFloat(i, uniforms[i]);
    }

    if (albedoMap != null) {
      shader.setImageSampler(0, albedoMap);
    }
    if (normalMap != null) {
      shader.setImageSampler(1, normalMap);
    }
    if (metallicRoughnessAOMap != null) {
      shader.setImageSampler(2, metallicRoughnessAOMap);
    }
    if (emissiveRuneMap != null) {
      shader.setImageSampler(3, emissiveRuneMap);
    }
  }
}

/// Pre-warms and caches the compiled GPU FragmentProgram to avoid runtime shader compilation jank.
class Aion2ShaderWarmup {
  Aion2ShaderWarmup._();

  static const String shaderAssetPath = 'shaders/materials/aion2_pbr_master.frag';

  static ui.FragmentProgram? _cachedProgram;
  static String? _cachedAssetPath;
  static bool _warmupExecuted = false;

  static ui.FragmentProgram? get cachedProgram => _cachedProgram;
  static bool get isWarmedUp => _warmupExecuted && _cachedProgram != null;

  /// Loads and warms up the fragment shader program.
  /// Gracefully catches errors when running in headless test runners without GPU runtime effect support.
  static Future<bool> warmup({
    String assetPath = shaderAssetPath,
    ui.Size previewSize = const ui.Size(256.0, 256.0),
  }) async {
    try {
      if (_cachedProgram == null || _cachedAssetPath != assetPath) {
        _cachedProgram = await ui.FragmentProgram.fromAsset(assetPath);
        _cachedAssetPath = assetPath;
      }
      final ui.FragmentProgram program = _cachedProgram!;

      ui.Image? dummyTexture;
      try {
        dummyTexture = await createSolidTexture();
      } catch (_) {
        // Fallback for headless test environments
      }

      // Execute warmup passes with each canonical preset to compile GPU pipeline permutations
      for (final Aion2PbrParameters preset in Aion2MaterialPresets.all) {
        final ui.FragmentShader shader = program.fragmentShader();
        final List<double> uniforms = Aion2MaterialUniformPacker.buildUniformList(
          viewportSize: previewSize,
          timeSeconds: 0.1,
          cameraPos: const Vector3D(0.0, 0.0, 2.5),
          lightPos: const Vector3D(1.5, 2.0, 3.0),
          lightColor: const ui.Color(0xFFFFFFFF),
          lightIntensity: 2.0,
          ambientLightColor: const ui.Color(0xFF222222),
          params: preset,
        );

        for (int i = 0; i < uniforms.length; i++) {
          shader.setFloat(i, uniforms[i]);
        }

        // Bind dummy texture to all 4 samplers (Slots 0..3) to fully prime the pipeline
        if (dummyTexture != null) {
          shader.setImageSampler(0, dummyTexture); // uAlbedoMap
          shader.setImageSampler(1, dummyTexture); // uNormalMap
          shader.setImageSampler(2, dummyTexture); // uMetallicRoughnessAOMap
          shader.setImageSampler(3, dummyTexture); // uEmissiveRuneMap
        }
      }

      dummyTexture?.dispose();

      _warmupExecuted = true;
      return true;
    } catch (_) {
      // Test environment or non-Impeller headless runner: software evaluation fallback will be used.
      _warmupExecuted = false;
      return false;
    }
  }

  /// Clears cached program and reset warmup status.
  static void clearCache() {
    _cachedProgram = null;
    _cachedAssetPath = null;
    _warmupExecuted = false;
  }

  /// Generates a solid 1x1 texture for shader testing and untextured meshes.
  static Future<ui.Image> createSolidTexture({
    ui.Color color = const ui.Color(0xFFFFFFFF),
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    canvas.drawColor(color, ui.BlendMode.src);
    final ui.Picture picture = recorder.endRecording();
    final ui.Image img = await picture.toImage(1, 1);
    picture.dispose();
    return img;
  }
}

/// CustomPainter rendering either GPU runtime shader or software BRDF preview.
class Aion2MaterialPreviewPainter extends CustomPainter {
  Aion2MaterialPreviewPainter({
    required this.controller,
    this.shader,
    this.albedoMap,
    this.normalMap,
    this.metallicRoughnessAOMap,
    this.emissiveRuneMap,
  }) : super(repaint: controller);

  final Aion2MaterialController controller;
  final ui.FragmentShader? shader;
  final ui.Image? albedoMap;
  final ui.Image? normalMap;
  final ui.Image? metallicRoughnessAOMap;
  final ui.Image? emissiveRuneMap;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final ui.FragmentShader? activeShader = shader;
    final bool hasAllRequiredSamplers = albedoMap != null &&
        normalMap != null &&
        metallicRoughnessAOMap != null &&
        emissiveRuneMap != null;

    if (activeShader != null && hasAllRequiredSamplers) {
      controller.bindToShader(
        activeShader,
        size,
        albedoMap: albedoMap,
        normalMap: normalMap,
        metallicRoughnessAOMap: metallicRoughnessAOMap,
        emissiveRuneMap: emissiveRuneMap,
      );

      final ui.Paint paint = ui.Paint()..shader = activeShader;
      canvas.drawRect(ui.Offset.zero & size, paint);
    } else {
      // Software BRDF preview for test environments or non-GPU pipelines
      final ui.Offset center = ui.Offset(size.width * 0.5, size.height * 0.5);
      final double radius = math.min(size.width, size.height) * 0.45;

      // Analytical spherical normal at sphere center
      const Vector3D n = Vector3D(0.0, 0.0, 1.0);
      final Vector3D v = controller.cameraPos.normalized();
      final Vector3D l = controller.lightPos.normalized();

      final Vector3D radiance = Aion2BrdfEvaluator.evaluateCompletePbr(
        n: n,
        v: v,
        l: l,
        params: controller.params,
        lightColor: Aion2MaterialUniformPacker.colorToVector3D(controller.lightColor),
        lightIntensity: controller.lightIntensity,
        ambientLight: Aion2MaterialUniformPacker.colorToVector3D(controller.ambientLightColor),
        timeSeconds: controller.elapsedTime,
      );

      final (double cr, double cg, double cb) = Aion2MaterialUniformPacker.colorToLinearRgb(controller.params.baseColor);

      final ui.Color previewColor = ui.Color.fromRGBO(
        ((radiance.x + cr * 0.2) * 255.0).round().clamp(0, 255),
        ((radiance.y + cg * 0.2) * 255.0).round().clamp(0, 255),
        ((radiance.z + cb * 0.2) * 255.0).round().clamp(0, 255),
        controller.params.baseColor.a,
      );

      final ui.Paint fallbackPaint = ui.Paint()
        ..color = previewColor
        ..style = ui.PaintingStyle.fill;

      canvas.drawCircle(center, radius, fallbackPaint);
    }
  }

  @override
  bool shouldRepaint(covariant Aion2MaterialPreviewPainter oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.shader != shader ||
        oldDelegate.albedoMap != albedoMap ||
        oldDelegate.normalMap != normalMap ||
        oldDelegate.metallicRoughnessAOMap != metallicRoughnessAOMap ||
        oldDelegate.emissiveRuneMap != emissiveRuneMap;
  }
}

/// Production widget displaying interactive real-time preview of the Aion 2 PBR Material.
class Aion2MaterialPreviewWidget extends StatefulWidget {
  const Aion2MaterialPreviewWidget({
    super.key,
    required this.controller,
    this.width = 200.0,
    this.height = 200.0,
    this.shaderAssetPath = Aion2ShaderWarmup.shaderAssetPath,
  });

  final Aion2MaterialController controller;
  final double width;
  final double height;
  final String shaderAssetPath;

  @override
  State<Aion2MaterialPreviewWidget> createState() => _Aion2MaterialPreviewWidgetState();
}

class _Aion2MaterialPreviewWidgetState extends State<Aion2MaterialPreviewWidget>
    with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  Ticker? _ticker;

  @override
  void initState() {
    super.initState();
    _initShader();
    _startAnimationTicker();
  }

  Future<void> _initShader() async {
    final bool warmed = await Aion2ShaderWarmup.warmup(
      assetPath: widget.shaderAssetPath,
      previewSize: ui.Size(widget.width, widget.height),
    );

    if (warmed && mounted) {
      setState(() {
        _shader = Aion2ShaderWarmup.cachedProgram?.fragmentShader();
      });
    }
  }

  void _startAnimationTicker() {
    _ticker = createTicker((Duration elapsed) {
      if (mounted && widget.controller.isAnimated) {
        widget.controller.advanceTime(0.01666);
      }
    });
    _ticker?.start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: CustomPaint(
        painter: Aion2MaterialPreviewPainter(
          controller: widget.controller,
          shader: _shader,
        ),
      ),
    );
  }
}
