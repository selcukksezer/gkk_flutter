#version 460 core
#include <flutter/runtime_effect.glsl>

// =============================================================================
// Production Wind Vegetation & Foliage Displacement Fragment Shader
// 2027 AAA Studio V3 Cinematic Graphics Standard (R2 Open World Architecture)
// Compatible with Flutter Impeller (Metal / MSL & Vulkan / SPIR-V) & Skia
//
// Capabilities:
// 1. Directional travelling wind gust wavefronts across foliage canopy & grass
// 2. Multi-octave Perlin / Simplex turbulence modeling for high-frequency flutter
// 3. Foliage translucent Subsurface Scattering (SSS) & sun rim glint on wave crests
// 4. Dynamic hardware tier scaling (Eco / Low / Mid / High / Ultra)
// 5. Zero-division safety and aspect-ratio preservation
// =============================================================================

precision highp float;

// -----------------------------------------------------------------------------
// Numeric Uniforms (Indices 0 .. 7, total 8 floats)
// STRICT: Must be declared before any sampler uniforms for Impeller compliance.
// -----------------------------------------------------------------------------
uniform vec2  uResolution;    // [0..1] Viewport resolution in canvas pixels
uniform float uTime;          // [2]    Continuous elapsed simulation time in seconds
uniform float uWindSpeed;     // [3]    Base ambient wind velocity (e.g. 1.5 - 3.5)
uniform vec2  uWindDirection; // [4..5] Normalized 2D wind travel direction (cos, sin)
uniform float uWindStrength;  // [6]    Gust intensity multiplier [0.0, 2.0]
uniform float uTier;          // [7]    Device tier (0=Eco, 1=Low, 2=Mid, 3=High, 4=Ultra)

// Output Fragment Color
out vec4 fragColor;

// Mathematical Constants
const float PI = 3.14159265358979323846;
const float TWO_PI = 6.28318530717958647692;

// -----------------------------------------------------------------------------
// Procedural Hash & Gradient Noise
// -----------------------------------------------------------------------------
vec2 hash22(vec2 p) {
    p = mod(p, 289.0);
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float gradientNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    // Quintic Hermite curve for smooth C1 derivatives
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    float n00 = dot(hash22(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0));
    float n10 = dot(hash22(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
    float n01 = dot(hash22(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
    float n11 = dot(hash22(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));

    return mix(mix(n00, n10, u.x), mix(n01, n11, u.x), u.y);
}

// -----------------------------------------------------------------------------
// Multi-Octave Directional Wind Field Synthesis
// -----------------------------------------------------------------------------
float computeWindField(vec2 uv, vec2 dir, float time, float speed, float tier) {
    // Coordinate along the wind propagation axis
    vec2 travelUv = uv - dir * (time * speed * 0.15);

    // Primary low-frequency gust wave
    float wave1 = sin(dot(travelUv, dir) * 12.0 + time * 1.8) * 0.5 + 0.5;
    float turbulence = gradientNoise(travelUv * 4.0);
    float gust = clamp(wave1 + turbulence * 0.45, 0.0, 1.5);

    // On Mid/High tiers (tier >= 2.0), evaluate secondary micro-flutter harmonics
    if (tier >= 1.5) {
        vec2 flutterUv = travelUv * 9.5 + vec2(time * 0.8, -time * 0.6);
        float microFlutter = gradientNoise(flutterUv) * 0.35;
        gust += microFlutter;
    }

    return gust;
}

// -----------------------------------------------------------------------------
// Main Fragment Execution
// -----------------------------------------------------------------------------
void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 safeRes = max(uResolution, vec2(1.0));
    vec2 uv = fragCoord / safeRes;

    // Aspect ratio correction for isotropic spatial propagation
    float aspect = safeRes.x / safeRes.y;
    vec2 aspectUv = vec2(uv.x * aspect, uv.y);

    // Safe normalized wind direction
    float dirLen = length(uWindDirection);
    vec2 dir = (dirLen > 0.001) ? (uWindDirection / dirLen) : vec2(0.7071, 0.7071);

    float speed = max(uWindSpeed, 0.1);
    float strength = clamp(uWindStrength, 0.0, 3.0);

    // 1. Evaluate directional wind wave intensity
    float windIntensity = computeWindField(aspectUv, dir, uTime, speed, uTier) * strength;

    // 2. Foliage SSS translucent radiance & canopy rim highlight
    // Foliage glows brighter when swept by strong wind gusts (revealing leaf undersides)
    vec3 leafUnderColor = vec3(0.18, 0.42, 0.12); // Translucent lime-green
    vec3 leafSunRim     = vec3(0.55, 0.75, 0.22); // Golden sunlit crest
    vec3 gustAirColor   = vec3(0.65, 0.82, 0.55); // Airborne pollen shimmer

    float leafSway = smoothstep(0.2, 0.9, windIntensity);
    vec3 windRadiance = mix(leafUnderColor, leafSunRim, leafSway);
    windRadiance += gustAirColor * pow(leafSway, 3.0) * 0.4;

    // 3. Subtle ambient dust / pollen spore shimmer along wind wavefront
    float shimmer = pow(clamp(gradientNoise(aspectUv * 16.0 - dir * uTime * 2.5), 0.0, 1.0), 4.0);
    windRadiance += vec3(0.9, 0.95, 0.7) * shimmer * strength * 0.35;

    // 4. Subtle screen-edge vignetting so effect softly frames scene
    float vignette = 1.0 - length((uv - 0.5) * vec2(1.1, 1.3)) * 0.35;
    vignette = clamp(vignette, 0.0, 1.0);

    // 5. Output premultiplied alpha overlay for Flutter canvas blending
    float alpha = clamp(windIntensity * 0.18 * vignette, 0.0, 0.45);
    fragColor = vec4(windRadiance * alpha, alpha);
}
