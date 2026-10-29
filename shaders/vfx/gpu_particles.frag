#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// -----------------------------------------------------------------------------
// AAA Multi-Layer GPU Particle System Fragment Shader (2027 Cinematic Pipeline)
// Compatible with Flutter Impeller & SkSL Runtime Effect Pipelines
//
// Particle Types:
// 0.0 = Spell / Arcane Energy Orb (glowing core, plasma turbulence, chromatic halo)
// 1.0 = Weapon Impact / Sparks (velocity-stretched incandescent streak, spark flicker)
// 2.0 = Blood Splatter (viscous droplet SDF, subsurface scattering, wet specular glint)
// 3.0 = Magic Runes (procedural geometric rune glyphs, concentric rings, pulsating aura)
// 4.0 = Shockwave / Energy Blast (expanding blast ring, turbulent wavefront, Gaussian falloff)
// -----------------------------------------------------------------------------

// Float & Vector Uniforms (Indices 0 .. 23, total 24 floats)
// STRICT: Must precede all sampler uniforms in Flutter runtime effects.
uniform vec2 uResolution;          // 0..1:   Viewport or particle bounding box resolution (pixels)
uniform float uTime;               // 2:      Global simulation time (seconds)
uniform vec4 uBounds;              // 3..6:   Particle quad AABB: vec4(minX, minY, width, height)
uniform float uParticleType;       // 7:      0=Spell, 1=Spark, 2=Blood, 3=Rune, 4=Shockwave
uniform float uLifetimeProgress;   // 8:      Normalized particle age in [0.0, 1.0]
uniform vec4 uColorStart;          // 9..12:  Starting RGBA color (HDR values > 1.0 supported)
uniform vec4 uColorEnd;            // 13..16: Ending RGBA color (HDR values > 1.0 supported)
uniform vec2 uVelocity;            // 17..18: Particle 2D velocity vector (pixels/sec)
uniform float uTurbulence;         // 19:     Simplex / Curl turbulence perturbation intensity
uniform float uEmissiveIntensity;  // 20:     HDR radiance boost for bloom threshold passes (e.g. 1.0 - 5.0)
uniform float uSize;               // 21:     Particle radius/size in pixels
uniform float uRotation;           // 22:     Particle rotation angle in radians
uniform float uLayerParam;         // 23:     Custom layer parameter (glyph index, blood viscosity, etc.)

out vec4 fragColor;

// -----------------------------------------------------------------------------
// Fast 2D Hash & Simplex Noise for Procedural Plasma & Turbulence
// -----------------------------------------------------------------------------
vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return vec2(-1.0) + 2.0 * fract(sin(p) * 43758.5453123);
}

float simplexNoise(vec2 p) {
    const float K1 = 0.366025404; // (sqrt(3)-1)/2
    const float K2 = 0.211324865; // (3-sqrt(3))/6
    vec2 i = floor(p + vec2((p.x + p.y) * K1));
    vec2 a = p - i + vec2((i.x + i.y) * K2);
    vec2 o = (a.x > a.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec2 b = a - o + vec2(K2);
    vec2 c = a - vec2(1.0 - 2.0 * K2);
    vec3 h = max(vec3(0.5) - vec3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
    vec3 n = h * h * h * h * vec3(dot(a, hash2(i)), dot(b, hash2(i + o)), dot(c, hash2(i + vec2(1.0))));
    return dot(n, vec3(70.0));
}

// -----------------------------------------------------------------------------
// 2D Rotation Helper
// -----------------------------------------------------------------------------
vec2 rotate2D(vec2 p, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// -----------------------------------------------------------------------------
// Type 0: Spell / Arcane Energy Orb
// -----------------------------------------------------------------------------
vec4 renderSpellOrb(vec2 p, float dist, float age) {
    // Plasma swirl with customizable harmonic frequency
    float freq = 3.5 + uLayerParam * 1.5;
    float noiseVal = simplexNoise(p * freq + vec2(uTime * 2.0, -uTime * 1.5)) * uTurbulence;
    float distortedDist = dist + noiseVal * 0.15;

    // Glowing core with exponential falloff
    float core = exp(-distortedDist * 4.5);
    float halo = exp(-distortedDist * 1.8) * 0.5;
    float glow = clamp(core + halo, 0.0, 2.0);

    // Color gradient over age
    vec4 col = mix(uColorStart, uColorEnd, smoothstep(0.0, 1.0, age));

    // Dynamic core chromatic shift
    vec3 coreColor = mix(col.rgb, vec3(1.0, 1.0, 1.0), clamp(core * 1.5, 0.0, 1.0));
    
    // Smooth radial edge falloff to eliminate quad border clipping
    float radialFalloff = smoothstep(1.0, 0.75, dist);
    
    // Lifetime alpha with soft onset and quadratic fade-out
    float fadeIn = smoothstep(0.0, 0.06, age);
    float alpha = clamp(glow * col.a * (1.0 - age * age) * fadeIn * radialFalloff, 0.0, 1.0);

    return vec4(coreColor * (1.0 + uEmissiveIntensity * core), alpha);
}

// -----------------------------------------------------------------------------
// Type 1: Weapon Impact & Sparks (Velocity-aligned elongated streak)
// -----------------------------------------------------------------------------
vec4 renderSpark(vec2 p, float age) {
    // Align coordinates with velocity vector
    float speed = length(uVelocity);
    vec2 dir = speed > 0.001 ? uVelocity / speed : vec2(1.0, 0.0);
    
    // Stretch along motion axis
    float stretchFactor = clamp(1.0 + speed * 0.005 + uLayerParam * 0.5, 1.0, 6.0);
    vec2 alignedP = vec2(dot(p, dir) / stretchFactor, dot(p, vec2(-dir.y, dir.x)));

    // Incandescent spark profile
    float dist = length(alignedP);
    float sparkCore = exp(-dist * 8.0);
    float sparkTail = exp(-abs(alignedP.x + 0.3) * 3.0) * exp(-abs(alignedP.y) * 12.0);
    float intensity = clamp(sparkCore * 1.5 + sparkTail, 0.0, 3.0);

    // High frequency spark flicker
    float flicker = 0.85 + 0.15 * sin(uTime * 50.0 + alignedP.x * 10.0);
    intensity *= flicker;

    // Hot color: starts white-yellow, shifts to deep red/orange
    vec4 col = mix(uColorStart, uColorEnd, age);
    vec3 hotRgb = mix(col.rgb, vec3(1.2, 1.1, 0.9), clamp(sparkCore * 2.0, 0.0, 1.0));
    
    // Smooth radial edge falloff
    float radialFalloff = smoothstep(1.0, 0.8, length(p));
    
    // Lifetime alpha with fast onset
    float fadeIn = smoothstep(0.0, 0.04, age);
    float alpha = clamp(intensity * col.a * (1.0 - age) * fadeIn * radialFalloff, 0.0, 1.0);

    return vec4(hotRgb * (1.0 + uEmissiveIntensity), alpha);
}

// -----------------------------------------------------------------------------
// Type 2: Viscous Blood Splatter (Metaball Droplet SDF + Wet Specular Glint)
// -----------------------------------------------------------------------------
vec4 renderBloodDroplet(vec2 p, float age) {
    // Main droplet SDF with teardrop distortion based on velocity
    float speed = length(uVelocity);
    vec2 dir = speed > 0.001 ? uVelocity / speed : vec2(0.0, 1.0);
    float travel = dot(p, dir);
    float crossP = dot(p, vec2(-dir.y, dir.x));

    // Teardrop profile: wider at head, tapered at tail modulated by viscosity
    float viscosity = clamp(1.0 + uLayerParam * 0.5, 0.4, 3.0);
    float taper = 1.0 - 0.4 * travel * viscosity;
    float dropletDist = length(vec2(crossP / max(taper, 0.2), travel));

    // Satellite micro-droplet
    vec2 satPos = p - dir * 0.65;
    float satDist = length(satPos) * 2.2;
    float expSum = exp(-clamp(dropletDist, 0.0, 10.0) * 6.0) + exp(-clamp(satDist, 0.0, 10.0) * 6.0);
    float smoothDist = -log(max(expSum, 1e-6)) / 6.0;

    // Hard surface edge with anti-aliasing
    float dropletAlpha = 1.0 - smoothstep(0.45, 0.55, smoothDist);

    // Directional normal and specular highlight (wet glint)
    vec2 normal2D = normalize(p + vec2(0.05, 0.05));
    vec2 lightDir = normalize(vec2(0.6, -0.8));
    float specular = pow(max(dot(normal2D, lightDir), 0.0), 16.0) * 1.4;

    // Subsurface rim translucency
    float rim = pow(smoothstep(0.2, 0.5, smoothDist), 2.0) * 0.5;

    // Deep crimson color with dark core and brighter translucent rim
    vec4 col = mix(uColorStart, uColorEnd, age);
    vec3 bloodRgb = col.rgb * (0.6 + rim) + vec3(specular * (1.0 + uEmissiveIntensity * 0.2));
    
    // Smooth radial edge falloff
    float radialFalloff = smoothstep(1.0, 0.85, length(p));
    
    // Lifetime alpha with fast onset
    float fadeIn = smoothstep(0.0, 0.04, age);
    float finalAlpha = clamp(dropletAlpha * col.a * (1.0 - age * 0.3) * fadeIn * radialFalloff, 0.0, 1.0);

    return vec4(bloodRgb, finalAlpha);
}

// -----------------------------------------------------------------------------
// Type 3: Magic Runes (Procedural Glyphs, Concentric Rings & Pulsating Aura)
// -----------------------------------------------------------------------------
vec4 renderMagicRune(vec2 p, float age) {
    float dist = length(p);
    float angle = (dist > 0.00001) ? atan(p.y, p.x) : 0.0;

    // 1. Concentric Ring Rings SDF
    float ring1 = abs(dist - 0.72) - 0.02;
    float ring2 = abs(dist - 0.52) - 0.015;
    float ringAura = exp(-abs(dist - 0.72) * 12.0) + exp(-abs(dist - 0.52) * 14.0);

    // 2. Outer Tick Marks (segmented dashes)
    float ticks = cos(angle * 12.0);
    float tickMask = (dist > 0.65 && dist < 0.80) ? smoothstep(0.7, 0.9, ticks) : 0.0;

    // 3. Central Mystical Sigil / Hexagram Pattern
    float sigilLines = 0.0;
    // Rotating N-fold star modulated by layerParam
    float starFolds = (uLayerParam > 0.5) ? (4.0 + mod(floor(uLayerParam), 4.0) * 2.0) : 6.0;
    float rotAngle = angle + uTime * 0.5;
    float starFold = cos(rotAngle * starFolds);
    if (dist < 0.48) {
        float innerCross = min(abs(p.x), abs(p.y));
        sigilLines = smoothstep(0.03, 0.01, innerCross) * 0.8;
        sigilLines += smoothstep(0.6, 0.85, starFold) * smoothstep(0.48, 0.35, dist);
    }

    // Combine rune components
    float glyphIntensity = ringAura + tickMask * 0.9 + sigilLines;

    // Pulsating mystical breathing
    float pulse = 0.85 + 0.15 * sin(uTime * 4.0 + dist * 5.0);
    glyphIntensity *= pulse;

    // Core central flare
    float centerGlow = exp(-dist * 5.0) * 0.7;
    glyphIntensity += centerGlow;

    // Color gradient and life fade
    vec4 col = mix(uColorStart, uColorEnd, age);
    float lifeFade = sin(clamp(age, 0.0, 1.0) * 3.14159265); // Fade in and out
    
    // Smooth radial edge falloff
    float radialFalloff = smoothstep(1.0, 0.85, dist);
    float alpha = clamp(glyphIntensity * col.a * lifeFade * radialFalloff, 0.0, 1.0);

    vec3 runeRgb = col.rgb * (1.0 + uEmissiveIntensity * 1.5);
    return vec4(runeRgb, alpha);
}

// -----------------------------------------------------------------------------
// Type 4: Shockwave & Energy Blast
// -----------------------------------------------------------------------------
vec4 renderShockwave(vec2 p, float age) {
    float dist = length(p);
    
    // Expanding ring radius according to age
    float waveRadius = smoothstep(0.0, 1.0, age) * 0.85;
    float ringDist = abs(dist - waveRadius);

    // Wavefront thickness with turbulence
    float turb = simplexNoise(p * 5.0 + vec2(uTime * 3.0, -uTime * 2.0)) * uTurbulence * 0.05;
    float waveThickness = (uLayerParam > 0.0) ? (16.0 / max(uLayerParam, 0.2)) : 16.0;
    float ring = exp(-pow((ringDist + turb) * waveThickness, 2.0));

    // Color & emission
    vec4 col = mix(uColorStart, uColorEnd, age);
    float fadeIn = smoothstep(0.0, 0.08, age);
    float radialFalloff = smoothstep(1.0, 0.88, dist);
    float alpha = clamp(ring * col.a * (1.0 - age) * fadeIn * radialFalloff, 0.0, 1.0);
    vec3 waveRgb = col.rgb * (1.0 + uEmissiveIntensity * ring);

    return vec4(waveRgb, alpha);
}

// -----------------------------------------------------------------------------
// Fragment Main Entry Point
// -----------------------------------------------------------------------------
void main() {
    vec2 coord = FlutterFragCoord().xy;

    // Compute normalized coordinates p in [-1.0, 1.0] relative to uBounds or uResolution
    vec2 p;
    if (uBounds.z > 0.0 && uBounds.w > 0.0) {
        // Bounding box localized quad rendering
        vec2 local = (coord - uBounds.xy) / uBounds.zw;
        p = local * 2.0 - vec2(1.0);
    } else {
        // Fallback to screen resolution coordinates
        float scaleRadius = (uSize > 0.0) ? uSize : (min(uResolution.x, uResolution.y) * 0.5);
        p = (coord - uResolution * 0.5) / max(scaleRadius, 1.0);
    }

    // Apply rotation
    if (abs(uRotation) > 0.0001) {
        p = rotate2D(p, uRotation);
    }

    float dist = length(p);
    float age = clamp(uLifetimeProgress, 0.0, 1.0);

    vec4 result = vec4(0.0);

    // Branch to specific particle layer procedural synthesis
    if (uParticleType < 0.5) {
        // 0.0 = Spell / Arcane Energy Orb
        result = renderSpellOrb(p, dist, age);
    } else if (uParticleType < 1.5) {
        // 1.0 = Weapon Impact / Sparks
        result = renderSpark(p, age);
    } else if (uParticleType < 2.5) {
        // 2.0 = Blood Splatter
        result = renderBloodDroplet(p, age);
    } else if (uParticleType < 3.5) {
        // 3.0 = Magic Runes
        result = renderMagicRune(p, age);
    } else {
        // 4.0 = Shockwave / Energy Blast
        result = renderShockwave(p, age);
    }

    // Discard zero-alpha fragments to optimize fillrate
    if (result.a <= 0.001) {
        discard;
    }

    // Output premultiplied alpha for Flutter Impeller & Skia canvas blending
    fragColor = vec4(result.rgb * result.a, result.a);
}
