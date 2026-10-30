// =============================================================================
// Central Shader Pipeline & Material Registry: Shader Registry Architecture
// 2027 Cinematic AAA Graphics Pipeline (R5 Standards)
// =============================================================================

import 'dart:ui' show BlendMode;

/// Classification of shader usage within the AAA rendering pipeline.
enum ShaderCategory {
  /// Screen-space and post-render passes (SSAO, ACES tonemap, bloom, blur).
  postprocess,

  /// Particle and dynamic combat effects (GPU particles, trails, flashes, decals).
  vfx,

  /// Global illumination, direct lights, and dynamic point lights.
  lighting,

  /// Massive crowd rendering, VAT mesh deformation, and impostor billboarding.
  crowd,

  /// Environmental terrain, foliage wind displacement, water, and volumetric fog.
  world,
}

/// Compilation stage of the shader pipeline.
enum ShaderStage {
  /// Pixel/fragment rasterization stage.
  fragment,

  /// Vertex transformation and displacement stage.
  vertex,

  /// Compute execution stage for GPU simulation.
  compute,
}

/// Fallback strategy applied when hardware cannot compile or execute the shader.
enum ShaderFallbackStrategy {
  /// Route rendering requests to a lighter, designated fallback shader.
  fallbackShader,

  /// Bypass shader completely (pass-through or disable effect).
  bypass,

  /// Switch to CPU analytical math / software renderer.
  cpuFallback,

  /// Silently drop without rendering.
  noop,
}

/// Device performance tiers used for automated shader feature scaling.
enum DevicePerformanceTier {
  /// Extremely constrained mobile/embedded devices: high-end shaders disabled.
  ultraLow(0),

  /// Low-end mobile devices: SSAO and multi-pass blurs use fallbacks.
  low(1),

  /// Mid-range mobile and integrated GPUs: balanced shader fidelity.
  medium(2),

  /// High-end mobile and dedicated desktop GPUs: full cinematic AAA shaders.
  high(3);

  const DevicePerformanceTier(this.level);
  final int level;

  /// Returns whether this tier satisfies the minimum required tier.
  bool satisfies(DevicePerformanceTier required) => level >= required.level;
}

/// Data types supported in uniform buffer layouts.
enum UniformType {
  /// Single 32-bit floating point value (1 slot).
  float(1),

  /// 2-component vector (2 slots).
  vec2(2),

  /// 3-component vector (3 slots).
  vec3(3),

  /// 4-component vector (4 slots).
  vec4(4),

  /// 4x4 transformation matrix (16 slots).
  mat4(16),

  /// 2D texture sampler binding index.
  sampler2d(0);

  const UniformType(this.slotCount);
  final int slotCount;
}

/// Definition of a single uniform parameter within a shader layout.
class UniformDefinition {
  const UniformDefinition({
    required this.name,
    required this.type,
    required this.floatOffset,
    required this.floatCount,
    this.defaultValue = const <double>[],
    this.description = '',
  });

  /// Name of the uniform variable matching the GLSL declaration.
  final String name;

  /// Type classification of this uniform.
  final UniformType type;

  /// 0-indexed starting float offset in the uniform buffer.
  final int floatOffset;

  /// Total number of consecutive float slots consumed.
  final int floatCount;

  /// Default parameter values if not supplied by the material.
  final List<double> defaultValue;

  /// Human-readable purpose of this uniform.
  final String description;

  @override
  String toString() =>
      'UniformDefinition($name: $type @ offset $floatOffset, count: $floatCount)';
}

/// Definition of a texture sampler unit binding.
class SamplerDefinition {
  const SamplerDefinition({
    required this.name,
    required this.samplerIndex,
    this.defaultTextureKey,
    this.description = '',
  });

  /// Name of the sampler variable in GLSL (e.g. `uSceneTexture`, `uNormalMap`).
  final String name;

  /// Texture unit index (0, 1, 2...).
  final int samplerIndex;

  /// Default texture asset key in AssetBundle if not overridden.
  final String? defaultTextureKey;

  /// Purpose of this texture sampler.
  final String description;

  @override
  String toString() => 'SamplerDefinition($name @ unit $samplerIndex)';
}

/// Complete structural descriptor for a shader in the registry.
class ShaderDescriptor {
  const ShaderDescriptor({
    required this.id,
    required this.assetPath,
    required this.category,
    required this.stage,
    this.description = '',
    this.uniforms = const <UniformDefinition>[],
    this.samplers = const <SamplerDefinition>[],
    this.fallbackId,
    this.fallbackStrategy = ShaderFallbackStrategy.bypass,
    this.minPerformanceTier = DevicePerformanceTier.low,
    this.warmupParameters,
  });

  /// Unique canonical identifier for this shader (e.g. `postprocess/aces_tonemap`).
  final String id;

  /// Asset path registered in pubspec.yaml.
  final String assetPath;

  /// Visual system domain.
  final ShaderCategory category;

  /// Shader compilation stage.
  final ShaderStage stage;

  /// Architectural description.
  final String description;

  /// List of uniform definitions in exact GLSL order.
  final List<UniformDefinition> uniforms;

  /// List of sampler definitions in texture unit order.
  final List<SamplerDefinition> samplers;

  /// Optional ID of a lighter fallback shader.
  final String? fallbackId;

  /// Strategy when execution or compilation fails.
  final ShaderFallbackStrategy fallbackStrategy;

  /// Minimum device tier required to activate this shader.
  final DevicePerformanceTier minPerformanceTier;

  /// Sample float values used to prime the GPU driver pipeline state cache.
  final List<double>? warmupParameters;

  /// Total number of floats required by numeric uniforms.
  int get totalFloatCount {
    if (uniforms.isEmpty) return 0;
    int maxIndex = 0;
    for (final UniformDefinition u in uniforms) {
      final int end = u.floatOffset + u.floatCount;
      if (end > maxIndex) maxIndex = end;
    }
    return maxIndex;
  }

  /// Total number of sampler units bound by this shader.
  int get totalSamplerCount => samplers.length;

  /// Look up a uniform by name.
  UniformDefinition? findUniform(String name) {
    for (final UniformDefinition u in uniforms) {
      if (u.name == name) return u;
    }
    return null;
  }

  /// Look up a sampler by name.
  SamplerDefinition? findSampler(String name) {
    for (final SamplerDefinition s in samplers) {
      if (s.name == name) return s;
    }
    return null;
  }

  @override
  String toString() => 'ShaderDescriptor($id, category: $category, stage: $stage)';
}

/// Material descriptor linking a shader to concrete parameters, textures, and render states.
class MaterialDescriptor {
  const MaterialDescriptor({
    required this.materialId,
    required this.name,
    required this.shaderId,
    required this.category,
    this.properties = const <String, double>{},
    this.samplers = const <String, String>{},
    this.blendMode = BlendMode.srcOver,
    this.isTransparent = false,
    this.depthWrite = true,
    this.cullFace = true,
    this.tags = const <String>[],
  });

  /// Unique identifier of the material (e.g. `mat_dungeon_stone_floor`).
  final String materialId;

  /// Human-readable name.
  final String name;

  /// Shader ID used to render this material.
  final String shaderId;

  /// Domain category.
  final ShaderCategory category;

  /// Numeric uniform property overrides (uniformName -> float value).
  final Map<String, double> properties;

  /// Sampler overrides (samplerName -> assetKey).
  final Map<String, String> samplers;

  /// Canvas blend mode when painting this material.
  final BlendMode blendMode;

  /// Whether the material requires alpha sorting.
  final bool isTransparent;

  /// Whether depth buffer writes are enabled for this material.
  final bool depthWrite;

  /// Whether back-face culling is enabled.
  final bool cullFace;

  /// Semantic tags (e.g. 'pbr', 'boss_vfx', 'impostor').
  final List<String> tags;

  /// Creates a copy of this material with parameter overrides.
  MaterialDescriptor copyWith({
    String? materialId,
    String? name,
    String? shaderId,
    ShaderCategory? category,
    Map<String, double>? properties,
    Map<String, String>? samplers,
    BlendMode? blendMode,
    bool? isTransparent,
    bool? depthWrite,
    bool? cullFace,
    List<String>? tags,
  }) {
    return MaterialDescriptor(
      materialId: materialId ?? this.materialId,
      name: name ?? this.name,
      shaderId: shaderId ?? this.shaderId,
      category: category ?? this.category,
      properties: properties ?? Map<String, double>.from(this.properties),
      samplers: samplers ?? Map<String, String>.from(this.samplers),
      blendMode: blendMode ?? this.blendMode,
      isTransparent: isTransparent ?? this.isTransparent,
      depthWrite: depthWrite ?? this.depthWrite,
      cullFace: cullFace ?? this.cullFace,
      tags: tags ?? List<String>.from(this.tags),
    );
  }

  @override
  String toString() => 'MaterialDescriptor($materialId using $shaderId)';
}

/// Catalog of default built-in shader descriptors matching shaders/ directory.
class ShaderCatalog {
  // Postprocess Shaders
  static const String acesTonemap = 'shaders/postprocess/aces_tonemap.frag';
  static const String ssao = 'shaders/postprocess/ssao.frag';
  static const String ssaoBilateralBlur =
      'shaders/postprocess/ssao_bilateral_blur.frag';
  static const String ssaoCompositeAces =
      'shaders/postprocess/ssao_composite_aces.frag';

  // Lighting Shaders
  static const String dungeonLighting = 'shaders/lighting/dungeon_lighting.frag';
  static const String clusteredCrowdLighting =
      'shaders/lighting/clustered_crowd_lighting.frag';

  // Master Material Shaders
  static const String aion2PbrMaster =
      'shaders/materials/aion2_pbr_master.frag';

  // VFX Shaders
  static const String gpuParticles = 'shaders/vfx/gpu_particles.frag';
  static const String groundDecal = 'shaders/vfx/ground_decal.frag';
  static const String ribbonTrail = 'shaders/vfx/ribbon_trail.frag';
  static const String rimHitFlash = 'shaders/vfx/rim_hit_flash.frag';
  static const String shockwaveRefraction =
      'shaders/vfx/shockwave_refraction.frag';
  static const String forgeFire = 'shaders/vfx/forge_fire.frag';

  // Crowd Shaders
  static const String vatCrowdFrag = 'shaders/crowd/vat_crowd.frag';
  static const String vatCrowdVert = 'shaders/crowd/vat_crowd.vert';
  static const String gpuInstancingVert = 'shaders/crowd/gpu_instancing.vert';

  // World Shaders (Environmental / Landscape)
  static const String windVegetation = 'shaders/world/wind_vegetation.frag';
  static const String waterPuddle = 'shaders/world/water_puddle.frag';
  static const String volumetricFog = 'shaders/world/volumetric_fog.frag';
  static const String atmosphericSky = 'shaders/world/atmospheric_sky.frag';
  static const String puddleSsr = 'shaders/world/puddle_ssr.frag';

  // Social Shaders
  static const String celestialBanner =
      'shaders/social/celestial_banner.frag';
  static const String emblemAura = 'shaders/social/emblem_aura.frag';

  /// Default registry descriptor list for all shaders in the project.
  static final List<ShaderDescriptor> defaultDescriptors = <ShaderDescriptor>[
    // 1. ACES Tonemap
    const ShaderDescriptor(
      id: acesTonemap,
      assetPath: acesTonemap,
      category: ShaderCategory.postprocess,
      stage: ShaderStage.fragment,
      description: 'ACES filmic tonemapping and gamma 2.2 / sRGB correction',
      uniforms: <UniformDefinition>[
        UniformDefinition(
          name: 'uResolution',
          type: UniformType.vec2,
          floatOffset: 0,
          floatCount: 2,
          defaultValue: <double>[1920.0, 1080.0],
        ),
        UniformDefinition(
          name: 'uExposure',
          type: UniformType.float,
          floatOffset: 2,
          floatCount: 1,
          defaultValue: <double>[1.0],
        ),
        UniformDefinition(
          name: 'uExposureMode',
          type: UniformType.float,
          floatOffset: 3,
          floatCount: 1,
          defaultValue: <double>[0.0],
        ),
        UniformDefinition(
          name: 'uFitType',
          type: UniformType.float,
          floatOffset: 4,
          floatCount: 1,
          defaultValue: <double>[0.0],
        ),
        UniformDefinition(
          name: 'uGammaMode',
          type: UniformType.float,
          floatOffset: 5,
          floatCount: 1,
          defaultValue: <double>[0.0],
        ),
        UniformDefinition(
          name: 'uPreGain',
          type: UniformType.float,
          floatOffset: 6,
          floatCount: 1,
          defaultValue: <double>[1.0],
        ),
        UniformDefinition(
          name: 'uWhitePoint',
          type: UniformType.float,
          floatOffset: 7,
          floatCount: 1,
          defaultValue: <double>[1.0],
        ),
      ],
      samplers: <SamplerDefinition>[
        SamplerDefinition(name: 'uSceneTexture', samplerIndex: 0),
      ],
      fallbackStrategy: ShaderFallbackStrategy.cpuFallback,
      minPerformanceTier: DevicePerformanceTier.ultraLow,
      warmupParameters: <double>[1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0],
    ),

    // 2. SSAO
    const ShaderDescriptor(
      id: ssao,
      assetPath: ssao,
      category: ShaderCategory.postprocess,
      stage: ShaderStage.fragment,
      description: 'Scalable horizon-based screen space ambient occlusion',
      uniforms: <UniformDefinition>[
        UniformDefinition(
          name: 'uResolution',
          type: UniformType.vec2,
          floatOffset: 0,
          floatCount: 2,
          defaultValue: <double>[1920.0, 1080.0],
        ),
        UniformDefinition(
          name: 'uRadius',
          type: UniformType.float,
          floatOffset: 2,
          floatCount: 1,
          defaultValue: <double>[0.5],
        ),
        UniformDefinition(
          name: 'uBias',
          type: UniformType.float,
          floatOffset: 3,
          floatCount: 1,
          defaultValue: <double>[0.025],
        ),
        UniformDefinition(
          name: 'uIntensity',
          type: UniformType.float,
          floatOffset: 4,
          floatCount: 1,
          defaultValue: <double>[1.8],
        ),
        UniformDefinition(
          name: 'uPower',
          type: UniformType.float,
          floatOffset: 5,
          floatCount: 1,
          defaultValue: <double>[2.0],
        ),
        UniformDefinition(
          name: 'uSampleCount',
          type: UniformType.float,
          floatOffset: 6,
          floatCount: 1,
          defaultValue: <double>[16.0],
        ),
        UniformDefinition(
          name: 'uNear',
          type: UniformType.float,
          floatOffset: 7,
          floatCount: 1,
          defaultValue: <double>[0.1],
        ),
        UniformDefinition(
          name: 'uFar',
          type: UniformType.float,
          floatOffset: 8,
          floatCount: 1,
          defaultValue: <double>[100.0],
        ),
      ],
      samplers: <SamplerDefinition>[
        SamplerDefinition(name: 'uDepthTexture', samplerIndex: 0),
        SamplerDefinition(name: 'uNormalTexture', samplerIndex: 1),
      ],
      fallbackId: acesTonemap,
      fallbackStrategy: ShaderFallbackStrategy.bypass,
      minPerformanceTier: DevicePerformanceTier.medium,
      warmupParameters: <double>[
        1.0, 1.0, 0.5, 0.025, 1.8, 2.0, 16.0, 0.1, 100.0,
      ],
    ),

    // 3. SSAO Bilateral Blur
    const ShaderDescriptor(
      id: ssaoBilateralBlur,
      assetPath: ssaoBilateralBlur,
      category: ShaderCategory.postprocess,
      stage: ShaderStage.fragment,
      description: 'Bilateral depth-aware blur for SSAO edge preservation',
      uniforms: <UniformDefinition>[
        UniformDefinition(
          name: 'uResolution',
          type: UniformType.vec2,
          floatOffset: 0,
          floatCount: 2,
          defaultValue: <double>[1920.0, 1080.0],
        ),
        UniformDefinition(
          name: 'uBlurDirection',
          type: UniformType.vec2,
          floatOffset: 2,
          floatCount: 2,
          defaultValue: <double>[1.0, 0.0],
        ),
        UniformDefinition(
          name: 'uSpatialSigma',
          type: UniformType.float,
          floatOffset: 4,
          floatCount: 1,
          defaultValue: <double>[2.5],
        ),
        UniformDefinition(
          name: 'uDepthThreshold',
          type: UniformType.float,
          floatOffset: 5,
          floatCount: 1,
          defaultValue: <double>[0.1],
        ),
      ],
      samplers: <SamplerDefinition>[
        SamplerDefinition(name: 'uAoTexture', samplerIndex: 0),
        SamplerDefinition(name: 'uDepthTexture', samplerIndex: 1),
      ],
      fallbackStrategy: ShaderFallbackStrategy.bypass,
      minPerformanceTier: DevicePerformanceTier.medium,
      warmupParameters: <double>[1.0, 1.0, 1.0, 0.0, 2.5, 0.1],
    ),

    // 4. SSAO Composite ACES
    const ShaderDescriptor(
      id: ssaoCompositeAces,
      assetPath: ssaoCompositeAces,
      category: ShaderCategory.postprocess,
      stage: ShaderStage.fragment,
      description: 'Unified single-pass SSAO modulation and ACES tonemapping',
      uniforms: <UniformDefinition>[
        UniformDefinition(
          name: 'uResolution',
          type: UniformType.vec2,
          floatOffset: 0,
          floatCount: 2,
          defaultValue: <double>[1920.0, 1080.0],
        ),
        UniformDefinition(
          name: 'uExposure',
          type: UniformType.float,
          floatOffset: 2,
          floatCount: 1,
          defaultValue: <double>[1.0],
        ),
        UniformDefinition(
          name: 'uExposureMode',
          type: UniformType.float,
          floatOffset: 3,
          floatCount: 1,
          defaultValue: <double>[0.0],
        ),
        UniformDefinition(
          name: 'uFitType',
          type: UniformType.float,
          floatOffset: 4,
          floatCount: 1,
          defaultValue: <double>[0.0],
        ),
        UniformDefinition(
          name: 'uGammaMode',
          type: UniformType.float,
          floatOffset: 5,
          floatCount: 1,
          defaultValue: <double>[0.0],
        ),
        UniformDefinition(
          name: 'uAoIntensity',
          type: UniformType.float,
          floatOffset: 6,
          floatCount: 1,
          defaultValue: <double>[1.0],
        ),
        UniformDefinition(
          name: 'uAoDirectLightPreserve',
          type: UniformType.float,
          floatOffset: 7,
          floatCount: 1,
          defaultValue: <double>[0.2],
        ),
      ],
      samplers: <SamplerDefinition>[
        SamplerDefinition(name: 'uSceneTexture', samplerIndex: 0),
        SamplerDefinition(name: 'uAoTexture', samplerIndex: 1),
      ],
      fallbackId: acesTonemap,
      fallbackStrategy: ShaderFallbackStrategy.fallbackShader,
      minPerformanceTier: DevicePerformanceTier.low,
      warmupParameters: <double>[1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.2],
    ),

    // 5. Dungeon Lighting
    const ShaderDescriptor(
      id: dungeonLighting,
      assetPath: dungeonLighting,
      category: ShaderCategory.lighting,
      stage: ShaderStage.fragment,
      description: 'Atmospheric multi-light and shadow illumination',
      uniforms: <UniformDefinition>[
        UniformDefinition(
          name: 'uResolution',
          type: UniformType.vec2,
          floatOffset: 0,
          floatCount: 2,
          defaultValue: <double>[1920.0, 1080.0],
        ),
        UniformDefinition(
          name: 'uTime',
          type: UniformType.float,
          floatOffset: 2,
          floatCount: 1,
          defaultValue: <double>[0.0],
        ),
        UniformDefinition(
          name: 'uAmbientColor',
          type: UniformType.vec3,
          floatOffset: 3,
          floatCount: 3,
          defaultValue: <double>[0.04, 0.05, 0.08],
        ),
        UniformDefinition(
          name: 'uAmbientIntensity',
          type: UniformType.float,
          floatOffset: 6,
          floatCount: 1,
          defaultValue: <double>[0.8],
        ),
        UniformDefinition(
          name: 'uLightCount',
          type: UniformType.float,
          floatOffset: 7,
          floatCount: 1,
          defaultValue: <double>[1.0],
        ),
        UniformDefinition(
          name: 'uAoModulation',
          type: UniformType.float,
          floatOffset: 8,
          floatCount: 1,
          defaultValue: <double>[0.6],
        ),
        UniformDefinition(
          name: 'uShadowSoftness',
          type: UniformType.float,
          floatOffset: 9,
          floatCount: 1,
          defaultValue: <double>[1.0],
        ),
        UniformDefinition(
          name: 'uCameraPos',
          type: UniformType.vec3,
          floatOffset: 10,
          floatCount: 3,
          defaultValue: <double>[0.0, 0.0, 200.0],
        ),
        UniformDefinition(
          name: 'uLightPosRadius',
          type: UniformType.vec4,
          floatOffset: 13,
          floatCount: 32,
        ),
        UniformDefinition(
          name: 'uLightColorIntensity',
          type: UniformType.vec4,
          floatOffset: 45,
          floatCount: 32,
        ),
        UniformDefinition(
          name: 'uLightParams',
          type: UniformType.vec4,
          floatOffset: 77,
          floatCount: 32,
        ),
      ],
      samplers: <SamplerDefinition>[
        SamplerDefinition(name: 'uTexture', samplerIndex: 0),
      ],
      fallbackStrategy: ShaderFallbackStrategy.bypass,
      minPerformanceTier: DevicePerformanceTier.ultraLow,
      warmupParameters: <double>[
        1920.0, 1080.0, 0.0, 0.04, 0.05, 0.08, 0.8, 1.0, 0.6, 1.0,
        0.0, 0.0, 200.0,
        // Light 0
        0.0, 0.0, 0.0, 100.0, 1.0, 0.8, 0.4, 1.0, 0.0, 0.0, 0.75, 32.0,
        // Lights 1-7 padded
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
      ],
    ),

    // 6. GPU Particles
    const ShaderDescriptor(
      id: gpuParticles,
      assetPath: gpuParticles,
      category: ShaderCategory.vfx,
      stage: ShaderStage.fragment,
      description: 'Multi-layer procedural GPU combat particle simulation',
      uniforms: <UniformDefinition>[
        UniformDefinition(
          name: 'uResolution',
          type: UniformType.vec2,
          floatOffset: 0,
          floatCount: 2,
          defaultValue: <double>[1920.0, 1080.0],
        ),
        UniformDefinition(
          name: 'uTime',
          type: UniformType.float,
          floatOffset: 2,
          floatCount: 1,
          defaultValue: <double>[0.0],
        ),
        UniformDefinition(
          name: 'uBounds',
          type: UniformType.vec4,
          floatOffset: 3,
          floatCount: 4,
          defaultValue: <double>[0.0, 0.0, 100.0, 100.0],
        ),
        UniformDefinition(
          name: 'uParticleType',
          type: UniformType.float,
          floatOffset: 7,
          floatCount: 1,
          defaultValue: <double>[0.0],
        ),
        UniformDefinition(
          name: 'uLifetimeProgress',
          type: UniformType.float,
          floatOffset: 8,
          floatCount: 1,
          defaultValue: <double>[0.5],
        ),
        UniformDefinition(
          name: 'uColorStart',
          type: UniformType.vec4,
          floatOffset: 9,
          floatCount: 4,
          defaultValue: <double>[1.0, 1.0, 1.0, 1.0],
        ),
        UniformDefinition(
          name: 'uColorEnd',
          type: UniformType.vec4,
          floatOffset: 13,
          floatCount: 4,
          defaultValue: <double>[0.0, 0.0, 0.0, 0.0],
        ),
        UniformDefinition(
          name: 'uVelocity',
          type: UniformType.vec2,
          floatOffset: 17,
          floatCount: 2,
          defaultValue: <double>[0.0, 0.0],
        ),
        UniformDefinition(
          name: 'uTurbulence',
          type: UniformType.float,
          floatOffset: 19,
          floatCount: 1,
          defaultValue: <double>[0.5],
        ),
        UniformDefinition(
          name: 'uEmissiveIntensity',
          type: UniformType.float,
          floatOffset: 20,
          floatCount: 1,
          defaultValue: <double>[2.0],
        ),
        UniformDefinition(
          name: 'uSize',
          type: UniformType.float,
          floatOffset: 21,
          floatCount: 1,
          defaultValue: <double>[10.0],
        ),
        UniformDefinition(
          name: 'uRotation',
          type: UniformType.float,
          floatOffset: 22,
          floatCount: 1,
          defaultValue: <double>[0.0],
        ),
        UniformDefinition(
          name: 'uLayerParam',
          type: UniformType.float,
          floatOffset: 23,
          floatCount: 1,
          defaultValue: <double>[0.0],
        ),
      ],
      fallbackStrategy: ShaderFallbackStrategy.cpuFallback,
      minPerformanceTier: DevicePerformanceTier.low,
      warmupParameters: <double>[
        1.0, 1.0, 0.0, 0.0, 0.0, 10.0, 10.0, 0.0, 0.5, 1.0, 1.0, 1.0, 1.0,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 2.0, 10.0, 0.0, 0.0,
      ],
    ),

    // 7. Ground Decal
    const ShaderDescriptor(
      id: groundDecal,
      assetPath: groundDecal,
      category: ShaderCategory.vfx,
      stage: ShaderStage.fragment,
      description: 'OBB ground decal projection with angle cutoff & RNM normals',
      uniforms: <UniformDefinition>[
        UniformDefinition(
          name: 'uResolution',
          type: UniformType.vec2,
          floatOffset: 0,
          floatCount: 2,
          defaultValue: <double>[1920.0, 1080.0],
        ),
        UniformDefinition(
          name: 'uDecalCenter',
          type: UniformType.vec2,
          floatOffset: 2,
          floatCount: 2,
          defaultValue: <double>[500.0, 500.0],
        ),
        UniformDefinition(
          name: 'uDecalHalfSize',
          type: UniformType.vec2,
          floatOffset: 4,
          floatCount: 2,
          defaultValue: <double>[50.0, 50.0],
        ),
        UniformDefinition(
          name: 'uDecalRotation',
          type: UniformType.float,
          floatOffset: 6,
          floatCount: 1,
          defaultValue: <double>[0.0],
        ),
        UniformDefinition(
          name: 'uOpacity',
          type: UniformType.float,
          floatOffset: 7,
          floatCount: 1,
          defaultValue: <double>[1.0],
        ),
        UniformDefinition(
          name: 'uAlbedoTint',
          type: UniformType.vec4,
          floatOffset: 8,
          floatCount: 4,
          defaultValue: <double>[1.0, 1.0, 1.0, 1.0],
        ),
        UniformDefinition(
          name: 'uNormalStrength',
          type: UniformType.float,
          floatOffset: 12,
          floatCount: 1,
          defaultValue: <double>[1.0],
        ),
        UniformDefinition(
          name: 'uRoughnessMod',
          type: UniformType.float,
          floatOffset: 13,
          floatCount: 1,
          defaultValue: <double>[0.5],
        ),
        UniformDefinition(
          name: 'uDecalType',
          type: UniformType.float,
          floatOffset: 14,
          floatCount: 1,
          defaultValue: <double>[0.0],
        ),
        UniformDefinition(
          name: 'uSurfaceNormal',
          type: UniformType.vec3,
          floatOffset: 15,
          floatCount: 3,
          defaultValue: <double>[0.0, 0.0, 1.0],
        ),
        UniformDefinition(
          name: 'uProjectorNormal',
          type: UniformType.vec3,
          floatOffset: 18,
          floatCount: 3,
          defaultValue: <double>[0.0, 0.0, -1.0],
        ),
        UniformDefinition(
          name: 'uAngleCutoff',
          type: UniformType.float,
          floatOffset: 21,
          floatCount: 1,
          defaultValue: <double>[0.5],
        ),
        UniformDefinition(
          name: 'uEdgeSoftness',
          type: UniformType.float,
          floatOffset: 22,
          floatCount: 1,
          defaultValue: <double>[0.1],
        ),
        UniformDefinition(
          name: 'uTime',
          type: UniformType.float,
          floatOffset: 23,
          floatCount: 1,
          defaultValue: <double>[0.0],
        ),
        UniformDefinition(
          name: 'uProceduralSeed',
          type: UniformType.float,
          floatOffset: 24,
          floatCount: 1,
          defaultValue: <double>[42.0],
        ),
        UniformDefinition(
          name: 'uDepthClip',
          type: UniformType.float,
          floatOffset: 25,
          floatCount: 1,
          defaultValue: <double>[1.0],
        ),
      ],
      samplers: <SamplerDefinition>[
        SamplerDefinition(name: 'uGroundTexture', samplerIndex: 0),
        SamplerDefinition(name: 'uDecalTexture', samplerIndex: 1),
        SamplerDefinition(name: 'uNormalTexture', samplerIndex: 2),
      ],
      fallbackStrategy: ShaderFallbackStrategy.bypass,
      minPerformanceTier: DevicePerformanceTier.medium,
      warmupParameters: <double>[
        1.0, 1.0, 0.0, 0.0, 50.0, 50.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
        0.5, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, -1.0, 0.5, 0.1, 0.0, 42.0, 1.0,
      ],
    ),

    // 8. Ribbon Trail
    const ShaderDescriptor(
      id: ribbonTrail,
      assetPath: ribbonTrail,
      category: ShaderCategory.vfx,
      stage: ShaderStage.fragment,
      description: 'Weapon swing arc ribbon trail with plasma wave distortion',
      uniforms: <UniformDefinition>[
        UniformDefinition(
          name: 'uResolution',
          type: UniformType.vec2,
          floatOffset: 0,
          floatCount: 2,
          defaultValue: <double>[1920.0, 1080.0],
        ),
        UniformDefinition(
          name: 'uTime',
          type: UniformType.float,
          floatOffset: 2,
          floatCount: 1,
          defaultValue: <double>[0.0],
        ),
        UniformDefinition(
          name: 'uBaseColor',
          type: UniformType.vec4,
          floatOffset: 3,
          floatCount: 4,
          defaultValue: <double>[1.0, 0.8, 0.3, 1.0],
        ),
        UniformDefinition(
          name: 'uGlowColor',
          type: UniformType.vec4,
          floatOffset: 7,
          floatCount: 4,
          defaultValue: <double>[1.0, 0.4, 0.1, 1.0],
        ),
        UniformDefinition(
          name: 'uBounds',
          type: UniformType.vec4,
          floatOffset: 11,
          floatCount: 4,
          defaultValue: <double>[0.0, 0.0, 200.0, 200.0],
        ),
        UniformDefinition(
          name: 'uScrollSpeed',
          type: UniformType.float,
          floatOffset: 15,
          floatCount: 1,
          defaultValue: <double>[1.0],
        ),
        UniformDefinition(
          name: 'uDistortionStrength',
          type: UniformType.float,
          floatOffset: 16,
          floatCount: 1,
          defaultValue: <double>[0.1],
        ),
        UniformDefinition(
          name: 'uDistortionFreq',
          type: UniformType.float,
          floatOffset: 17,
          floatCount: 1,
          defaultValue: <double>[4.0],
        ),
        UniformDefinition(
          name: 'uGlowIntensity',
          type: UniformType.float,
          floatOffset: 18,
          floatCount: 1,
          defaultValue: <double>[3.0],
        ),
        UniformDefinition(
          name: 'uFadePower',
          type: UniformType.float,
          floatOffset: 19,
          floatCount: 1,
          defaultValue: <double>[1.5],
        ),
        UniformDefinition(
          name: 'uTransversePower',
          type: UniformType.float,
          floatOffset: 20,
          floatCount: 1,
          defaultValue: <double>[2.0],
        ),
        UniformDefinition(
          name: 'uTextureMix',
          type: UniformType.float,
          floatOffset: 21,
          floatCount: 1,
          defaultValue: <double>[0.0],
        ),
      ],
      samplers: <SamplerDefinition>[
        SamplerDefinition(name: 'uTrailTexture', samplerIndex: 0),
      ],
      fallbackStrategy: ShaderFallbackStrategy.cpuFallback,
      minPerformanceTier: DevicePerformanceTier.low,
      warmupParameters: <double>[
        1.0, 1.0, 0.0, 1.0, 0.8, 0.3, 1.0, 1.0, 0.4, 0.1, 1.0, 0.0, 0.0,
        100.0, 100.0, 1.0, 0.1, 4.0, 3.0, 1.5, 2.0, 0.0,
      ],
    ),

    // 9. Rim Hit Flash
    const ShaderDescriptor(
      id: rimHitFlash,
      assetPath: rimHitFlash,
      category: ShaderCategory.vfx,
      stage: ShaderStage.fragment,
      description: 'Fresnel rim light and edge dilation damage hit flash',
      uniforms: <UniformDefinition>[
        UniformDefinition(
          name: 'uResolution',
          type: UniformType.vec2,
          floatOffset: 0,
          floatCount: 2,
          defaultValue: <double>[1920.0, 1080.0],
        ),
        UniformDefinition(
          name: 'uIntensity',
          type: UniformType.float,
          floatOffset: 2,
          floatCount: 1,
          defaultValue: <double>[1.0],
        ),
        UniformDefinition(
          name: 'uTintColor',
          type: UniformType.vec3,
          floatOffset: 3,
          floatCount: 3,
          defaultValue: <double>[1.0, 1.0, 1.0],
        ),
        UniformDefinition(
          name: 'uRimPower',
          type: UniformType.float,
          floatOffset: 6,
          floatCount: 1,
          defaultValue: <double>[3.0],
        ),
        UniformDefinition(
          name: 'uRimIntensity',
          type: UniformType.float,
          floatOffset: 7,
          floatCount: 1,
          defaultValue: <double>[2.5],
        ),
        UniformDefinition(
          name: 'uInnerFlash',
          type: UniformType.float,
          floatOffset: 8,
          floatCount: 1,
          defaultValue: <double>[0.5],
        ),
        UniformDefinition(
          name: 'uEdgeBleedWidth',
          type: UniformType.float,
          floatOffset: 9,
          floatCount: 1,
          defaultValue: <double>[2.0],
        ),
        UniformDefinition(
          name: 'uEdgeBleedIntensity',
          type: UniformType.float,
          floatOffset: 10,
          floatCount: 1,
          defaultValue: <double>[1.5],
        ),
        UniformDefinition(
          name: 'uBloomMultiplier',
          type: UniformType.float,
          floatOffset: 11,
          floatCount: 1,
          defaultValue: <double>[2.0],
        ),
        UniformDefinition(
          name: 'uNormalMode',
          type: UniformType.float,
          floatOffset: 12,
          floatCount: 1,
          defaultValue: <double>[0.0],
        ),
      ],
      samplers: <SamplerDefinition>[
        SamplerDefinition(name: 'uTexture', samplerIndex: 0),
        SamplerDefinition(name: 'uNormalMap', samplerIndex: 1),
      ],
      fallbackStrategy: ShaderFallbackStrategy.bypass,
      minPerformanceTier: DevicePerformanceTier.ultraLow,
      warmupParameters: <double>[
        1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 3.0, 2.5, 0.5, 2.0, 1.5, 2.0, 0.0,
      ],
    ),

    // 10. Shockwave Refraction
    const ShaderDescriptor(
      id: shockwaveRefraction,
      assetPath: shockwaveRefraction,
      category: ShaderCategory.vfx,
      stage: ShaderStage.fragment,
      description: 'Radial chromatic refraction and distortion shockwave',
      uniforms: <UniformDefinition>[
        UniformDefinition(
          name: 'uResolution',
          type: UniformType.vec2,
          floatOffset: 0,
          floatCount: 2,
          defaultValue: <double>[1920.0, 1080.0],
        ),
        UniformDefinition(
          name: 'uCenter',
          type: UniformType.vec2,
          floatOffset: 2,
          floatCount: 2,
          defaultValue: <double>[0.5, 0.5],
        ),
        UniformDefinition(
          name: 'uProgress',
          type: UniformType.float,
          floatOffset: 4,
          floatCount: 1,
          defaultValue: <double>[0.5],
        ),
        UniformDefinition(
          name: 'uTime',
          type: UniformType.float,
          floatOffset: 5,
          floatCount: 1,
          defaultValue: <double>[0.0],
        ),
        UniformDefinition(
          name: 'uMaxRadius',
          type: UniformType.float,
          floatOffset: 6,
          floatCount: 1,
          defaultValue: <double>[0.4],
        ),
        UniformDefinition(
          name: 'uThickness',
          type: UniformType.float,
          floatOffset: 7,
          floatCount: 1,
          defaultValue: <double>[0.08],
        ),
        UniformDefinition(
          name: 'uRefractionStrength',
          type: UniformType.float,
          floatOffset: 8,
          floatCount: 1,
          defaultValue: <double>[0.05],
        ),
        UniformDefinition(
          name: 'uChromaticAberration',
          type: UniformType.float,
          floatOffset: 9,
          floatCount: 1,
          defaultValue: <double>[0.02],
        ),
        UniformDefinition(
          name: 'uDampening',
          type: UniformType.float,
          floatOffset: 10,
          floatCount: 1,
          defaultValue: <double>[2.0],
        ),
        UniformDefinition(
          name: 'uFrequency',
          type: UniformType.float,
          floatOffset: 11,
          floatCount: 1,
          defaultValue: <double>[8.0],
        ),
        UniformDefinition(
          name: 'uMode',
          type: UniformType.float,
          floatOffset: 12,
          floatCount: 1,
          defaultValue: <double>[0.0],
        ),
        UniformDefinition(
          name: 'uUseNormalMap',
          type: UniformType.float,
          floatOffset: 13,
          floatCount: 1,
          defaultValue: <double>[0.0],
        ),
        UniformDefinition(
          name: 'uTint',
          type: UniformType.vec4,
          floatOffset: 14,
          floatCount: 4,
          defaultValue: <double>[1.0, 1.0, 1.0, 1.0],
        ),
      ],
      samplers: <SamplerDefinition>[
        SamplerDefinition(name: 'uSceneTexture', samplerIndex: 0),
        SamplerDefinition(name: 'uNormalMapTexture', samplerIndex: 1),
      ],
      fallbackStrategy: ShaderFallbackStrategy.bypass,
      minPerformanceTier: DevicePerformanceTier.medium,
      warmupParameters: <double>[
        1.0, 1.0, 0.5, 0.5, 0.5, 0.0, 0.4, 0.08, 0.05, 0.02, 2.0, 8.0, 0.0,
        0.0, 1.0, 1.0, 1.0, 1.0,
      ],
    ),

    // 10b. Forge Fire VFX
    const ShaderDescriptor(
      id: forgeFire,
      assetPath: forgeFire,
      category: ShaderCategory.vfx,
      stage: ShaderStage.fragment,
      description:
          'Volumetric procedural forge fire with dynamic heat intensity and TBDR optimization',
      uniforms: <UniformDefinition>[
        UniformDefinition(
          name: 'uResolution',
          type: UniformType.vec2,
          floatOffset: 0,
          floatCount: 2,
          defaultValue: <double>[400.0, 300.0],
        ),
        UniformDefinition(
          name: 'uTime',
          type: UniformType.float,
          floatOffset: 2,
          floatCount: 1,
          defaultValue: <double>[0.0],
        ),
        UniformDefinition(
          name: 'uHeatIntensity',
          type: UniformType.float,
          floatOffset: 3,
          floatCount: 1,
          defaultValue: <double>[0.5],
        ),
        UniformDefinition(
          name: 'uCoreColor',
          type: UniformType.vec4,
          floatOffset: 4,
          floatCount: 4,
          defaultValue: <double>[1.0, 0.96, 0.82, 1.0],
        ),
        UniformDefinition(
          name: 'uFlameColor',
          type: UniformType.vec4,
          floatOffset: 8,
          floatCount: 4,
          defaultValue: <double>[1.0, 0.62, 0.06, 1.0],
        ),
        UniformDefinition(
          name: 'uEmberColor',
          type: UniformType.vec4,
          floatOffset: 12,
          floatCount: 4,
          defaultValue: <double>[0.88, 0.16, 0.0, 0.8],
        ),
        UniformDefinition(
          name: 'uTurbulence',
          type: UniformType.float,
          floatOffset: 16,
          floatCount: 1,
          defaultValue: <double>[1.0],
        ),
        UniformDefinition(
          name: 'uHeightFactor',
          type: UniformType.float,
          floatOffset: 17,
          floatCount: 1,
          defaultValue: <double>[1.0],
        ),
      ],
      fallbackStrategy: ShaderFallbackStrategy.cpuFallback,
      minPerformanceTier: DevicePerformanceTier.ultraLow,
      warmupParameters: <double>[
        400.0, 300.0, 0.0, 0.5, 1.0, 0.96, 0.82, 1.0, 1.0, 0.62, 0.06, 1.0,
        0.88, 0.16, 0.0, 0.8, 1.0, 1.0,
      ],
    ),

    // 11. Crowd VAT Fragment
    const ShaderDescriptor(
      id: vatCrowdFrag,
      assetPath: vatCrowdFrag,
      category: ShaderCategory.crowd,
      stage: ShaderStage.fragment,
      description: 'Vertex animated texture mesh and 8-angle impostor shading',
      uniforms: <UniformDefinition>[
        UniformDefinition(
          name: 'uLightDir',
          type: UniformType.vec3,
          floatOffset: 0,
          floatCount: 3,
          defaultValue: <double>[0.577, 0.577, 0.577],
        ),
        UniformDefinition(
          name: 'uLightColor',
          type: UniformType.vec3,
          floatOffset: 3,
          floatCount: 3,
          defaultValue: <double>[1.0, 0.95, 0.8],
        ),
        UniformDefinition(
          name: 'uAmbientColor',
          type: UniformType.vec3,
          floatOffset: 6,
          floatCount: 3,
          defaultValue: <double>[0.2, 0.25, 0.3],
        ),
        UniformDefinition(
          name: 'uFogColor',
          type: UniformType.vec3,
          floatOffset: 9,
          floatCount: 3,
          defaultValue: <double>[0.1, 0.12, 0.15],
        ),
        UniformDefinition(
          name: 'uFogStart',
          type: UniformType.float,
          floatOffset: 12,
          floatCount: 1,
          defaultValue: <double>[50.0],
        ),
        UniformDefinition(
          name: 'uFogEnd',
          type: UniformType.float,
          floatOffset: 13,
          floatCount: 1,
          defaultValue: <double>[250.0],
        ),
        UniformDefinition(
          name: 'uAlphaCutoff',
          type: UniformType.float,
          floatOffset: 14,
          floatCount: 1,
          defaultValue: <double>[0.5],
        ),
      ],
      samplers: <SamplerDefinition>[
        SamplerDefinition(name: 'uAlbedoMap', samplerIndex: 0),
        SamplerDefinition(name: 'uImpostorAtlas', samplerIndex: 1),
      ],
      fallbackStrategy: ShaderFallbackStrategy.bypass,
      minPerformanceTier: DevicePerformanceTier.low,
      warmupParameters: <double>[
        0.577, 0.577, 0.577, 1.0, 0.95, 0.8, 0.2, 0.25, 0.3, 0.1, 0.12, 0.15,
        50.0, 250.0, 0.5,
      ],
    ),

    // 12. Crowd VAT Vertex
    const ShaderDescriptor(
      id: vatCrowdVert,
      assetPath: vatCrowdVert,
      category: ShaderCategory.crowd,
      stage: ShaderStage.vertex,
      description: 'Vertex shader sampling VAT position texture for 10K entities',
      uniforms: <UniformDefinition>[
        UniformDefinition(
          name: 'uViewProjection',
          type: UniformType.mat4,
          floatOffset: 0,
          floatCount: 16,
        ),
        UniformDefinition(
          name: 'uVatScale',
          type: UniformType.vec3,
          floatOffset: 16,
          floatCount: 3,
        ),
        UniformDefinition(
          name: 'uVatOffset',
          type: UniformType.vec3,
          floatOffset: 19,
          floatCount: 3,
        ),
        UniformDefinition(
          name: 'uTexDimensions',
          type: UniformType.vec2,
          floatOffset: 22,
          floatCount: 2,
        ),
        UniformDefinition(
          name: 'uCameraPosition',
          type: UniformType.vec3,
          floatOffset: 24,
          floatCount: 3,
        ),
        UniformDefinition(
          name: 'uCameraRight',
          type: UniformType.vec3,
          floatOffset: 27,
          floatCount: 3,
        ),
        UniformDefinition(
          name: 'uCameraUp',
          type: UniformType.vec3,
          floatOffset: 30,
          floatCount: 3,
        ),
        UniformDefinition(
          name: 'uAtlasGrid',
          type: UniformType.vec2,
          floatOffset: 33,
          floatCount: 2,
        ),
      ],
      samplers: <SamplerDefinition>[
        SamplerDefinition(name: 'uPosMap', samplerIndex: 0),
        SamplerDefinition(name: 'uNormMap', samplerIndex: 1),
      ],
      fallbackStrategy: ShaderFallbackStrategy.bypass,
      minPerformanceTier: DevicePerformanceTier.low,
    ),

    // 13. Crowd GPU Instancing Vertex
    const ShaderDescriptor(
      id: gpuInstancingVert,
      assetPath: gpuInstancingVert,
      category: ShaderCategory.crowd,
      stage: ShaderStage.vertex,
      description: 'Hardware GPU instancing vertex transform for LOD2 crowd',
      uniforms: <UniformDefinition>[
        UniformDefinition(
          name: 'uViewProjection',
          type: UniformType.mat4,
          floatOffset: 0,
          floatCount: 16,
        ),
      ],
      fallbackStrategy: ShaderFallbackStrategy.bypass,
      minPerformanceTier: DevicePerformanceTier.medium,
    ),

    // 14. World Wind Vegetation
    const ShaderDescriptor(
      id: windVegetation,
      assetPath: windVegetation,
      category: ShaderCategory.world,
      stage: ShaderStage.fragment,
      description: 'Wind displacement simulation for foliage and trees',
      uniforms: <UniformDefinition>[
        UniformDefinition(
          name: 'uResolution',
          type: UniformType.vec2,
          floatOffset: 0,
          floatCount: 2,
          defaultValue: <double>[1920.0, 1080.0],
        ),
        UniformDefinition(
          name: 'uTime',
          type: UniformType.float,
          floatOffset: 2,
          floatCount: 1,
          defaultValue: <double>[0.0],
        ),
        UniformDefinition(
          name: 'uWindSpeed',
          type: UniformType.float,
          floatOffset: 3,
          floatCount: 1,
          defaultValue: <double>[1.5],
        ),
        UniformDefinition(
          name: 'uWindDirection',
          type: UniformType.vec2,
          floatOffset: 4,
          floatCount: 2,
          defaultValue: <double>[1.0, 0.0],
        ),
        UniformDefinition(
          name: 'uWindStrength',
          type: UniformType.float,
          floatOffset: 6,
          floatCount: 1,
          defaultValue: <double>[0.3],
        ),
        UniformDefinition(
          name: 'uTier',
          type: UniformType.float,
          floatOffset: 7,
          floatCount: 1,
          defaultValue: <double>[2.0],
        ),
      ],
      fallbackStrategy: ShaderFallbackStrategy.bypass,
      minPerformanceTier: DevicePerformanceTier.low,
      warmupParameters: <double>[1.0, 1.0, 0.0, 1.5, 1.0, 0.0, 0.3, 2.0],
    ),

    // 15. World Water Puddle
    const ShaderDescriptor(
      id: waterPuddle,
      assetPath: waterPuddle,
      category: ShaderCategory.world,
      stage: ShaderStage.fragment,
      description: 'Puddle planar reflections and micro-surface ripples',
      uniforms: <UniformDefinition>[
        UniformDefinition(
          name: 'uResolution',
          type: UniformType.vec2,
          floatOffset: 0,
          floatCount: 2,
          defaultValue: <double>[1920.0, 1080.0],
        ),
        UniformDefinition(
          name: 'uTime',
          type: UniformType.float,
          floatOffset: 2,
          floatCount: 1,
          defaultValue: <double>[0.0],
        ),
        UniformDefinition(
          name: 'uRippleSpeed',
          type: UniformType.float,
          floatOffset: 3,
          floatCount: 1,
          defaultValue: <double>[1.0],
        ),
        UniformDefinition(
          name: 'uPuddleRoughness',
          type: UniformType.float,
          floatOffset: 4,
          floatCount: 1,
          defaultValue: <double>[0.1],
        ),
        UniformDefinition(
          name: 'uReflectance',
          type: UniformType.float,
          floatOffset: 5,
          floatCount: 1,
          defaultValue: <double>[0.8],
        ),
      ],
      samplers: <SamplerDefinition>[
        SamplerDefinition(name: 'uReflectionMap', samplerIndex: 0),
        SamplerDefinition(name: 'uNormalMap', samplerIndex: 1),
      ],
      fallbackStrategy: ShaderFallbackStrategy.bypass,
      minPerformanceTier: DevicePerformanceTier.medium,
      warmupParameters: <double>[1.0, 1.0, 0.0, 1.0, 0.1, 0.8],
    ),

    // 16. World Volumetric Fog
    const ShaderDescriptor(
      id: volumetricFog,
      assetPath: volumetricFog,
      category: ShaderCategory.world,
      stage: ShaderStage.fragment,
      description: 'Atmospheric volumetric fog with analytical depth exponential falloff',
      uniforms: <UniformDefinition>[
        UniformDefinition(
          name: 'uResolution',
          type: UniformType.vec2,
          floatOffset: 0,
          floatCount: 2,
          defaultValue: <double>[1920.0, 1080.0],
        ),
        UniformDefinition(
          name: 'uTime',
          type: UniformType.float,
          floatOffset: 2,
          floatCount: 1,
          defaultValue: <double>[0.0],
        ),
        UniformDefinition(
          name: 'uFogDensity',
          type: UniformType.float,
          floatOffset: 3,
          floatCount: 1,
          defaultValue: <double>[0.05],
        ),
        UniformDefinition(
          name: 'uFogColor',
          type: UniformType.vec3,
          floatOffset: 4,
          floatCount: 3,
          defaultValue: <double>[0.1, 0.12, 0.15],
        ),
        UniformDefinition(
          name: 'uHeightFalloff',
          type: UniformType.float,
          floatOffset: 7,
          floatCount: 1,
          defaultValue: <double>[0.2],
        ),
      ],
      fallbackStrategy: ShaderFallbackStrategy.bypass,
      minPerformanceTier: DevicePerformanceTier.medium,
      warmupParameters: <double>[1.0, 1.0, 0.0, 0.05, 0.1, 0.12, 0.15, 0.2],
    ),
  ];
}

/// Central registry managing shader definitions, categories, and material instances.
class ShaderRegistry {
  ShaderRegistry({bool loadDefaults = true}) {
    if (loadDefaults) {
      for (final ShaderDescriptor desc in ShaderCatalog.defaultDescriptors) {
        registerShader(desc);
      }
      _registerDefaultMaterials();
    }
  }

  final Map<String, ShaderDescriptor> _shaders = <String, ShaderDescriptor>{};
  final Map<String, MaterialDescriptor> _materials =
      <String, MaterialDescriptor>{};

  // ---------------------------------------------------------------------------
  // Shader Registration
  // ---------------------------------------------------------------------------

  /// Registers a shader descriptor.
  void registerShader(ShaderDescriptor descriptor) {
    _shaders[descriptor.id] = descriptor;
  }

  /// Unregisters a shader descriptor by ID.
  bool unregisterShader(String id) {
    return _shaders.remove(id) != null;
  }

  /// List of all registered shader descriptors.
  List<ShaderDescriptor> get descriptors => getAllDescriptors();

  /// Look up a shader descriptor by ID or short name (e.g. 'aces_tonemap' or 'shaders/postprocess/aces_tonemap.frag').
  ShaderDescriptor? getShader(String id) {
    if (_shaders.containsKey(id)) return _shaders[id];
    for (final ShaderDescriptor desc in _shaders.values) {
      if (desc.id == id ||
          desc.assetPath == id ||
          desc.assetPath.endsWith('/$id.frag') ||
          desc.assetPath.endsWith('/$id.vert') ||
          desc.assetPath.contains(id) ||
          desc.id.endsWith(id)) {
        return desc;
      }
    }
    return null;
  }

  /// Look up a shader descriptor by ID.
  ShaderDescriptor? getShaderDescriptor(String id) => getShader(id);

  /// Checks if a shader ID is registered.
  bool containsShader(String id) => getShader(id) != null;

  /// Returns all registered shader descriptors.
  List<ShaderDescriptor> getAllDescriptors() =>
      List<ShaderDescriptor>.unmodifiable(_shaders.values);

  /// Returns all shader descriptors in a specific category.
  List<ShaderDescriptor> getDescriptorsByCategory(ShaderCategory category) {
    return _shaders.values.where((ShaderDescriptor d) => d.category == category).toList();
  }

  /// Alias for getDescriptorsByCategory.
  List<ShaderDescriptor> getByCategory(ShaderCategory category) =>
      getDescriptorsByCategory(category);

  /// Total count of registered shaders.
  int get shaderCount => _shaders.length;

  // ---------------------------------------------------------------------------
  // Material Registration
  // ---------------------------------------------------------------------------

  /// Registers a material descriptor.
  void registerMaterial(MaterialDescriptor material) {
    _materials[material.materialId] = material;
  }

  /// Unregisters a material descriptor by ID.
  bool unregisterMaterial(String materialId) {
    return _materials.remove(materialId) != null;
  }

  /// Look up a material descriptor by ID.
  MaterialDescriptor? getMaterial(String materialId) => _materials[materialId];

  /// Checks if a material is registered.
  bool containsMaterial(String materialId) =>
      _materials.containsKey(materialId);

  /// Returns all registered materials.
  List<MaterialDescriptor> getAllMaterials() =>
      List<MaterialDescriptor>.unmodifiable(_materials.values);

  /// Returns materials belonging to a category.
  List<MaterialDescriptor> getMaterialsByCategory(ShaderCategory category) {
    return _materials.values
        .where((MaterialDescriptor m) => m.category == category)
        .toList();
  }

  /// Returns materials that use a specific shader ID.
  List<MaterialDescriptor> getMaterialsByShaderId(String shaderId) {
    return _materials.values
        .where((MaterialDescriptor m) => m.shaderId == shaderId)
        .toList();
  }

  /// Total count of registered materials.
  int get materialCount => _materials.length;

  /// Registers production dark fantasy AAA default materials.
  void _registerDefaultMaterials() {
    // 1. Post-processing Tonemapper
    registerMaterial(
      const MaterialDescriptor(
        materialId: 'mat_postprocess_aces',
        name: 'Cinematic ACES Tonemapping',
        shaderId: ShaderCatalog.acesTonemap,
        category: ShaderCategory.postprocess,
        properties: <String, double>{
          'uExposure': 1.0,
          'uExposureMode': 0.0,
          'uFitType': 0.0,
          'uGammaMode': 0.0,
          'uPreGain': 1.0,
          'uWhitePoint': 1.0,
        },
        tags: <String>['postprocess', 'tonemapping', 'hdr'],
      ),
    );

    // 2. SSAO Composite
    registerMaterial(
      const MaterialDescriptor(
        materialId: 'mat_postprocess_ssao_composite',
        name: 'SSAO Ambient Occlusion Composite',
        shaderId: ShaderCatalog.ssaoCompositeAces,
        category: ShaderCategory.postprocess,
        properties: <String, double>{
          'uExposure': 1.0,
          'uAoIntensity': 1.0,
          'uAoDirectLightPreserve': 0.2,
        },
        tags: <String>['postprocess', 'ssao', 'composite'],
      ),
    );

    // 3. Spell Shockwave
    registerMaterial(
      const MaterialDescriptor(
        materialId: 'mat_spell_shockwave',
        name: 'Arcane Explosion Shockwave',
        shaderId: ShaderCatalog.shockwaveRefraction,
        category: ShaderCategory.vfx,
        properties: <String, double>{
          'uRefractionStrength': 0.08,
          'uChromaticAberration': 0.03,
          'uThickness': 0.06,
          'uFrequency': 10.0,
        },
        isTransparent: true,
        tags: <String>['combat', 'spell', 'shockwave'],
      ),
    );

    // 4. Weapon Blade Trail
    registerMaterial(
      const MaterialDescriptor(
        materialId: 'mat_sword_blade_trail',
        name: 'Golden Blade Ribbon Trail',
        shaderId: ShaderCatalog.ribbonTrail,
        category: ShaderCategory.vfx,
        properties: <String, double>{
          'uGlowIntensity': 3.5,
          'uDistortionStrength': 0.12,
          'uFadePower': 1.8,
        },
        isTransparent: true,
        tags: <String>['combat', 'weapon', 'trail'],
      ),
    );

    // 5. Boss Hit Flash
    registerMaterial(
      const MaterialDescriptor(
        materialId: 'mat_boss_hit_flash',
        name: 'Boss Heavy Damage Rim Flash',
        shaderId: ShaderCatalog.rimHitFlash,
        category: ShaderCategory.vfx,
        properties: <String, double>{
          'uRimPower': 4.0,
          'uRimIntensity': 3.0,
          'uInnerFlash': 0.8,
          'uBloomMultiplier': 2.5,
        },
        isTransparent: true,
        tags: <String>['combat', 'hit_flash', 'feedback'],
      ),
    );

    // 6. Ground Scorch Decal
    registerMaterial(
      const MaterialDescriptor(
        materialId: 'mat_fireball_crater_decal',
        name: 'Fireball Impact Ground Scorch Decal',
        shaderId: ShaderCatalog.groundDecal,
        category: ShaderCategory.vfx,
        properties: <String, double>{
          'uDecalType': 0.0,
          'uNormalStrength': 1.2,
          'uRoughnessMod': 0.8,
          'uAngleCutoff': 0.5,
        },
        isTransparent: true,
        tags: <String>['combat', 'decal', 'ground'],
      ),
    );

    // 7. Crowd 10K Impostor & Mesh
    registerMaterial(
      const MaterialDescriptor(
        materialId: 'mat_crowd_skeleton_warrior',
        name: '10K Distant Horde VAT Mesh & Billboard',
        shaderId: ShaderCatalog.vatCrowdFrag,
        category: ShaderCategory.crowd,
        properties: <String, double>{
          'uFogStart': 60.0,
          'uFogEnd': 300.0,
          'uAlphaCutoff': 0.5,
        },
        tags: <String>['crowd', 'vat', '10k', 'impostor'],
      ),
    );

    // 8. Open World Foliage Wind
    registerMaterial(
      const MaterialDescriptor(
        materialId: 'mat_world_foliage_oak',
        name: 'Open World Whispering Forest Foliage',
        shaderId: ShaderCatalog.windVegetation,
        category: ShaderCategory.world,
        properties: <String, double>{
          'uWindSpeed': 2.0,
          'uWindStrength': 0.4,
        },
        tags: <String>['world', 'foliage', 'wind'],
      ),
    );
  }
}
