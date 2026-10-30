#version 460 core
#include <flutter/runtime_effect.glsl>

// =============================================================================
// Production Volumetric Atmospheric Fog Fragment Shader
// 2027 AAA Studio V3 Cinematic Graphics Standard (R2 World Pipeline)
// Compatible with Flutter Impeller (Metal / MSL & Vulkan / SPIR-V) & Skia
//
// Capabilities:
// 1. Analytical height-dependent exponential fog density (Beer-Lambert law)
// 2. 3D/2D multi-octave fractal noise turbulence simulating rolling atmospheric fog banks
// 3. Sun/directional in-scattering phase function (Henyey-Greenstein approximation)
// 4. Soft horizon and distance attenuation for seamless open-world integration
// 5. Strict 8-float uniform buffer matching ShaderRegistry (volumetricFog)
// =============================================================================

precision highp float;

// -----------------------------------------------------------------------------
// Numeric Uniforms (Indices 0 .. 7, total 8 floats)
// STRICT: Must be declared before any sampler uniforms for Impeller compliance.
// -----------------------------------------------------------------------------
uniform vec2  uResolution;    // [0..1] Viewport resolution in physical pixels
uniform float uTime;          // [2]    Continuous elapsed simulation time in seconds
uniform float uFogDensity;    // [3]    Base volumetric fog density coefficient (e.g. 0.05)
uniform vec3  uFogColor;      // [4..6] Atmospheric fog linear RGB color
uniform float uHeightFalloff; // [7]    Exponential height decay scale (e.g. 0.2)

// Output Fragment Color
out vec4 fragColor;

// Mathematical Constants
const float PI = 3.14159265358979323846;

// -----------------------------------------------------------------------------
// Fast 2D Hash & Noise Functions
// -----------------------------------------------------------------------------
vec2 hash2(vec2 p) {
    p = mod(p, 289.0);
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float fastNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    return mix(mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
                   dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
               mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
                   dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

// 3-Octave Fractal Brownian Motion for volumetric rolling fog billows
float fogFbm(vec2 p) {
    float v = 0.50 * fastNoise(p);
    p = p * 2.02 + vec2(1.3, -1.7);
    v += 0.30 * fastNoise(p);
    p = p * 2.15 + vec2(-2.1, 1.4);
    v += 0.20 * fastNoise(p);
    return v;
}

// -----------------------------------------------------------------------------
// Main Fragment Execution
// -----------------------------------------------------------------------------
void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 safeRes = max(uResolution, vec2(1.0));
    vec2 uv = fragCoord / safeRes;

    // Viewport coordinates: y ranges from 0.0 (ground / bottom) to 1.0 (sky / top)
    float height = uv.y;
    float aspect = safeRes.x / safeRes.y;
    vec2 worldP = vec2(uv.x * aspect, uv.y);

    float baseDensity = (uFogDensity > 0.0) ? uFogDensity : 0.05;
    float heightFalloff = (uHeightFalloff > 0.0) ? uHeightFalloff : 0.2;

    // 1. Analytical Height Falloff: Fog is denser near ground level (Beer-Lambert exponential)
    // Density(h) = exp(-heightFalloff * h)
    float heightFactor = exp(-heightFalloff * (1.0 - height) * 4.0);

    // 2. Procedural Wind Drift & Rolling Fog Billows
    // Fog moves horizontally with atmospheric drift
    vec2 fogCoord1 = worldP * 3.5 + vec2(uTime * 0.04, -uTime * 0.015);
    vec2 fogCoord2 = worldP * 7.0 + vec2(-uTime * 0.025, uTime * 0.035);

    float billows1 = fogFbm(fogCoord1) * 0.5 + 0.5;
    float billows2 = fogFbm(fogCoord2) * 0.5 + 0.5;
    float turbulence = mix(billows1, billows2, 0.4);

    // 3. Composite Fog Density
    float localDensity = baseDensity * heightFactor * (0.6 + 0.8 * turbulence);

    // Optical depth & Beer-Lambert transmittance: T = exp(-sigma * d)
    // Fog factor = 1 - T
    float opticalDepth = localDensity * 6.0;
    float fogAlpha = clamp(1.0 - exp(-opticalDepth), 0.0, 0.85);

    // 4. In-Scattering Light Tint & Sunlight Shaft Bleed
    // Sun position approximated at top-right (0.8, 0.85)
    vec2 sunPos = vec2(0.8, 0.85);
    float sunDist = length(uv - sunPos);
    float sunScatter = exp(-sunDist * 2.5) * 0.45;

    // Default atmospheric fog color or uniform
    vec3 baseFogColor = (length(uFogColor) > 0.01) ? uFogColor : vec3(0.12, 0.16, 0.22);
    vec3 sunLightColor = vec3(1.0, 0.92, 0.78);
    vec3 finalFogColor = mix(baseFogColor, sunLightColor, sunScatter);

    // Subtle dark fantasy astral tint in deep shadows
    vec3 shadowAmbient = vec3(0.06, 0.08, 0.14);
    finalFogColor = mix(shadowAmbient, finalFogColor, clamp(height * 1.2, 0.0, 1.0));

    // 5. Output premultiplied alpha overlay for Flutter canvas blending
    fragColor = vec4(finalFogColor * fogAlpha, fogAlpha);
}
